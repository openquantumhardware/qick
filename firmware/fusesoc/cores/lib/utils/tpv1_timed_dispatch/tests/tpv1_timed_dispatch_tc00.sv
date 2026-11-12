`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component : tpv1_timed_dispatch_unit_test
// Origin    : Converted from VHDL timed_ictrl (tProcV1 timed instruction
//             dispatcher). See tpv1_timed_dispatch.sv for full architectural notes.
//
// Description:
//   Unit testbench for the timed instruction dispatcher (tpv1_timed_dispatch).
//   The DUT reads 216-bit instruction words from a FIFO, waits until the
//   embedded 48-bit timestamp (t_inst) is reached by the master clock counter
//   (t_cnt), then dispatches the instruction via one of two mechanisms:
//
//     (a) AXI-Stream output (m_axis_tdata/tvalid/tready) for set/seti/setb/setbi
//     (b) Wait handshake (waitt / waitt_ack) for wait/waiti opcodes
//
//   Instruction word layout (216 bits):
//     [31:0]    p0  - parameter 0
//     [63:32]   p1  - parameter 1
//     [95:64]   p2  - parameter 2
//     [127:96]  p3  - parameter 3
//     [159:128] p4  - parameter 4
//     [207:160] t   - 48-bit timestamp
//     [215:208] op  - 8-bit opcode
//
//   Recognized opcodes:
//     0x15 (waiti) / 0x54 (wait) -> WAIT_ACK_ST: assert waitt, wait for ack
//     0x13 (seti)                 -> SETI_ST:     tvalid, tdata={128'b0, p0}
//     0x1A (setbi)                -> SETBI_ST:    tvalid, tdata={128'b0, p0}, wait tready
//     0x51 (set)                  -> SET_ST:      tvalid, tdata={p4,p3,p2,p1,p0}
//     0x58 (setb)                 -> SETB_ST:     tvalid, tdata={p4,p3,p2,p1,p0}, wait tready
//     other                       -> READ_ST:     silently consume and read next
//
//   FSM state transitions:
//     READ_ST --(~fifo_empty)--> WAIT_ST
//     WAIT_ST --(t_inst<=t_cnt, opcode dispatch)--> WAIT_ACK_ST|SETI_ST|...
//     WAIT_ACK_ST --(waitt_ack)--> READ_ST
//     SETI_ST  / SET_ST  --> READ_ST (single-cycle output)
//     SETBI_ST / SETB_ST --(m_axis_tready)--> READ_ST
//
// Naming note:
//   The module name 'tpv1_timed_dispatch' is preserved for consistency with the
//   existing QICK repository references. An alternative descriptive name
//   would be 'tpv1_timed_dispatch'.
//------------------------------------------------------------------------------
module tpv1_timed_dispatch_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tpv1_timed_dispatch_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real CLOCK_FREQUENCY = 100e6; // 100 MHz

    // Opcode constants (matching VHDL bit literals)
    localparam logic [7:0] OP_WAITI = 8'h15;
    localparam logic [7:0] OP_WAIT  = 8'h54;
    localparam logic [7:0] OP_SETI  = 8'h13;
    localparam logic [7:0] OP_SETBI = 8'h1A;
    localparam logic [7:0] OP_SET   = 8'h51;
    localparam logic [7:0] OP_SETB  = 8'h58;
    localparam logic [7:0] OP_NOP   = 8'hFF; // Any unrecognized opcode

    //--------------------------------------------------------------------------
    // Interface & Testbench Signals
    //--------------------------------------------------------------------------
    logic          tb_clk          = 1'b0;
    logic          tb_rstn         = 1'b0;

    // Master clock counter
    logic [47:0]   tb_t_cnt        = '0;

    // FIFO interface (TB drives the FIFO side)
    logic          tb_fifo_rd_en;           // DUT output
    logic [215:0]  tb_fifo_dout    = '0;   // TB drives
    logic          tb_fifo_empty   = 1'b1; // TB drives

    // Wait handshake
    logic          tb_waitt;               // DUT output
    logic          tb_waitt_ack    = 1'b0; // TB drives

    // AXI-Stream master (DUT is master)
    logic [159:0]  tb_m_axis_tdata;        // DUT output
    logic          tb_m_axis_tvalid;       // DUT output
    logic          tb_m_axis_tready = 1'b1; // TB drives (default: always ready)

    //--------------------------------------------------------------------------
    // VCD Waveform Generation
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tpv1_timed_dispatch.vcd");
        $dumpvars();
    end

    //--------------------------------------------------------------------------
    // Clock Generator Instance
    //--------------------------------------------------------------------------
    clk_gen #(
        .FREQ (CLOCK_FREQUENCY)
    ) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    //--------------------------------------------------------------------------
    // Default Clocking Block
    //--------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        // TB drives
        output tb_rstn;
        output tb_t_cnt;
        output tb_fifo_dout;
        output tb_fifo_empty;
        output tb_waitt_ack;
        output tb_m_axis_tready;
        // DUT drives
        input  tb_fifo_rd_en;
        input  tb_waitt;
        input  tb_m_axis_tdata;
        input  tb_m_axis_tvalid;
    endclocking

    //--------------------------------------------------------------------------
    // Unit Under Test (DUT)
    //--------------------------------------------------------------------------
    tpv1_timed_dispatch u_dut (
        .clk            (tb_clk),
        .rstn           (tb_rstn),
        .t_cnt          (tb_t_cnt),
        .fifo_rd_en     (tb_fifo_rd_en),
        .fifo_dout      (tb_fifo_dout),
        .fifo_empty     (tb_fifo_empty),
        .waitt          (tb_waitt),
        .waitt_ack      (tb_waitt_ack),
        .m_axis_tdata   (tb_m_axis_tdata),
        .m_axis_tvalid  (tb_m_axis_tvalid),
        .m_axis_tready  (tb_m_axis_tready)
    );

    //--------------------------------------------------------------------------
    // Concurrent Assertions
    //--------------------------------------------------------------------------

    // fifo_rd_en must only assert when DUT is in READ_ST
    // (i.e. never assert tvalid and rd_en simultaneously)
    property no_rd_and_tvalid;
        @(posedge tb_clk) disable iff (!tb_rstn)
        !(tb_fifo_rd_en && tb_m_axis_tvalid);
    endproperty
    `ASSERT_CONCURRENT(no_rd_and_tvalid);

    // waitt and tvalid must never assert simultaneously
    property no_waitt_and_tvalid;
        @(posedge tb_clk) disable iff (!tb_rstn)
        !(tb_waitt && tb_m_axis_tvalid);
    endproperty
    `ASSERT_CONCURRENT(no_waitt_and_tvalid);

    // tvalid must deassert once tready is seen (for blocking variants)
    property tvalid_clears_after_tready;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_m_axis_tvalid && tb_m_axis_tready) |=> !tb_m_axis_tvalid;
    endproperty
    `ASSERT_CONCURRENT(tvalid_clears_after_tready);

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure (Build, Setup, Teardown)
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_rstn          <= 1'b0;
        cb.tb_t_cnt         <= '0;
        cb.tb_fifo_dout     <= '0;
        cb.tb_fifo_empty    <= 1'b1;
        cb.tb_waitt_ack     <= 1'b0;
        cb.tb_m_axis_tready <= 1'b1;
        repeat(3) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        cb.tb_rstn          <= 1'b0;
        cb.tb_fifo_dout     <= '0;
        cb.tb_fifo_empty    <= 1'b1;
        cb.tb_waitt_ack     <= 1'b0;
        cb.tb_m_axis_tready <= 1'b1;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    // build_word: pack a 216-bit FIFO word from its fields
    function automatic logic [215:0] build_word(
        input logic [31:0]  p0,
        input logic [31:0]  p1,
        input logic [31:0]  p2,
        input logic [31:0]  p3,
        input logic [31:0]  p4,
        input logic [47:0]  t,
        input logic [7:0]   opcode
    );
        return {opcode, t, p4, p3, p2, p1, p0};
    endfunction

    // present_instruction: place word on FIFO output and deassert empty.
    // Waits until DUT asserts fifo_rd_en, then removes the word.
    task present_instruction(input logic [215:0] word);
        cb.tb_fifo_dout  <= word;
        cb.tb_fifo_empty <= 1'b0;
        @(cb);
        // Wait for DUT to read (fifo_rd_en asserted)
        while (!tb_fifo_rd_en) @(cb);
        cb.tb_fifo_empty <= 1'b1;
        cb.tb_fifo_dout  <= '0;
        @(cb);
    endtask

    // advance_time: set t_cnt to a given value to trigger timestamp match
    task advance_time(input logic [47:0] t_target);
        cb.tb_t_cnt <= t_target;
        @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Test Cases Block Insertion
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "tpv1_timed_dispatch_tests.sv"
    `SVUNIT_TESTS_END

endmodule

