`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component : tprocv1_unit_test
// DUT       : tprocv1 (tProcV1 — tproc64x32_x8)
//
// Description:
//   Integration-level testbench for the full tProcV1 processor.
//   Uses axi4_stream_if interfaces with the standard QICK clocking block
//   and task conventions.
//
// Interface role summary:
//   s0_axis..s3_axis : DUT is SLAVE  → TB drives via m_cb (tdata, tvalid)
//                      Never call s_reset() on these — TB is the master.
//   m0_axis..m7_axis : DUT is MASTER → TB drives tready via s_cb
//                      Never call m_reset() on these — DUT is the master.
//                      Sample tdata/tvalid via s_cb.
//
// Key timing constraints:
//   - start → FSM: cdc_gray_sync #(.N(2)) adds 2 cycles; start_and_sync() handles this.
//   - regfile_8p read latency: 2 cycles (pnum_r pipeline).
//   - ALU latency: 2 cycles (dout_r → dout_rr).
//   - axis_set_reg on slave inputs adds 1 cycle of holding latency.
//   - 'program' is a reserved SV keyword: use 'prog' everywhere.
//   - State polling uses observable control signals, not state.name strings
//     (one_hot FSM encoding makes name-based polling unreliable in xsim).
//
// Instruction encoding (64-bit):
//   I-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
//           [45:41] ra | [40:36] rb | [35:31] rc | [30:0] imm
//   J-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
//           [45:41] ra | [40:36] rb | [35:31] rc | [30:16] xxx | [15:0] addr
//   R-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
//           [45:41] ra | [40:36] rb | [35:31] rc | [30:26] rd | [25:21] re |
//           [20:16] rf | [15:11] rg | [10:6] rh | [5:0] xxx
//------------------------------------------------------------------------------
module tprocv1_unit_test;
    import svunit_pkg::svunit_testcase;
    import tproc_pkg::*;
    import alu_pkg::*;

    string name = "tprocv1_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real CLOCK_FREQUENCY = 100e6;
    localparam int  N = 8;   // program memory address width (256 words)
    localparam int  M = 8;   // data memory address width   (256 words)

    // CONDJ oper codes (matching signed_comparator)
    localparam logic [3:0] COND_GT   = 4'b0000;
    localparam logic [3:0] COND_GE   = 4'b0001;
    localparam logic [3:0] COND_LT   = 4'b0010;
    localparam logic [3:0] COND_LE   = 4'b0011;
    localparam logic [3:0] COND_EQ   = 4'b0100;
    localparam logic [3:0] COND_NE   = 4'b0101;

    //--------------------------------------------------------------------------
    // Clock and scalar control signals
    //--------------------------------------------------------------------------
    logic        tb_clk           = 1'b0;
    logic        tb_rstn          = 1'b0;
    logic        tb_start         = 1'b0;
    logic        tb_start_src_reg = 1'b0;
    logic        tb_start_reg     = 1'b0;

    // Program memory (TB is the ROM; DUT drives pmem_addr)
    logic [N-1:0] tb_pmem_addr;
    logic [63:0]  tb_pmem_do;

    // Data memory (TB is the RAM; DUT drives we/addr/di)
    logic          tb_dmem_we;
    logic [M-1:0]  tb_dmem_addr;
    logic [31:0]   tb_dmem_di;
    logic [31:0]   tb_dmem_do;

    //--------------------------------------------------------------------------
    // AXI4-Stream interfaces
    // s0..s3 : DUT is slave  (TB drives tdata/tvalid via m_cb)
    // m0..m7 : DUT is master (TB drives tready via s_cb, samples outputs)
    //--------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(64))  s0_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(64))  s1_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(64))  s2_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(64))  s3_axis (.aclk(tb_clk), .aresetn(tb_rstn));

    axi4_stream_if #(.TDATA_WIDTH(160)) m0_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m1_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m2_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m3_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m4_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m5_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m6_axis (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m7_axis (.aclk(tb_clk), .aresetn(tb_rstn));

    //--------------------------------------------------------------------------
    // Memory Models
    //--------------------------------------------------------------------------
    logic [63:0] pmem_array [0:2**N-1];
    logic [31:0] dmem_array [0:2**M-1];

    // Program memory: combinational read
    always_comb tb_pmem_do = pmem_array[tb_pmem_addr];

    // Data memory: combinational read, synchronous write
    always_comb tb_dmem_do = dmem_array[tb_dmem_addr];

    always_ff @(posedge tb_clk) begin
        if (tb_dmem_we)
            dmem_array[tb_dmem_addr] <= tb_dmem_di;
    end

    //--------------------------------------------------------------------------
    // VCD Waveform Generation
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tprocv1.vcd");
        $dumpvars();
    end

    //--------------------------------------------------------------------------
    // Clock Generator
    //--------------------------------------------------------------------------
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    //--------------------------------------------------------------------------
    // Default Clocking Block
    // Only scalar signals here — AXIS interfaces use their own clocking blocks.
    //--------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_start;
        output tb_start_src_reg;
        output tb_start_reg;
        input  tb_pmem_addr;
        input  tb_dmem_we;
        input  tb_dmem_addr;
        input  tb_dmem_di;
    endclocking

    //--------------------------------------------------------------------------
    // Unit Under Test
    //--------------------------------------------------------------------------
    tprocv1 #(.N(N), .M(M)) u_dut (
        .clk           (tb_clk),
        .rstn          (tb_rstn),
        .start         (tb_start),
        .pmem_addr     (tb_pmem_addr),
        .pmem_do       (tb_pmem_do),
        .dmem_we       (tb_dmem_we),
        .dmem_addr     (tb_dmem_addr),
        .dmem_di       (tb_dmem_di),
        .dmem_do       (tb_dmem_do),
        // DUT slave interfaces — TB is master, connects via modport slave
        .s0_axis       (s0_axis),
        .s1_axis       (s1_axis),
        .s2_axis       (s2_axis),
        .s3_axis       (s3_axis),
        // DUT master interfaces — TB is slave, connects via modport master
        .m0_axis       (m0_axis),
        .m1_axis       (m1_axis),
        .m2_axis       (m2_axis),
        .m3_axis       (m3_axis),
        .m4_axis       (m4_axis),
        .m5_axis       (m5_axis),
        .m6_axis       (m6_axis),
        .m7_axis       (m7_axis),
        .start_src_reg (tb_start_src_reg),
        .start_reg     (tb_start_reg)
    );

    //--------------------------------------------------------------------------
    // Concurrent Assertions
    //--------------------------------------------------------------------------

    // pc_rst and pc_en must never assert simultaneously
    property no_pc_rst_and_en;
        @(posedge tb_clk) disable iff (!tb_rstn)
        !(u_dut.pc_rst_i && u_dut.pc_en_i);
    endproperty
    `ASSERT_CONCURRENT(no_pc_rst_and_en);

    // reg_wen must only assert when reg_src is not X
    property reg_wen_valid_src;
        @(posedge tb_clk) disable iff (!tb_rstn)
        u_dut.reg_wen_i |-> !$isunknown(u_dut.reg_src_i);
    endproperty
    `ASSERT_CONCURRENT(reg_wen_valid_src);

    // t_cnt_en deasserts at most 1 cycle (only during START_MC_ST)
    property t_en_single_deassert;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (!u_dut.t_cnt_en) |=> (u_dut.t_cnt_en);
    endproperty
    `ASSERT_CONCURRENT(t_en_single_deassert);

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        // For this tests m0 is enough, as it is the only excercited here
        assign m0_axis.tlast = 1'b0;
        assign m1_axis.tlast = 1'b0;
        assign m2_axis.tlast = 1'b0;
        assign m3_axis.tlast = 1'b0;
        assign m4_axis.tlast = 1'b0;
        assign m5_axis.tlast = 1'b0;
        assign m6_axis.tlast = 1'b0;
        assign m7_axis.tlast = 1'b0;
    
        // Initialize memories
        for (int i = 0; i < 2**N; i++) pmem_array[i] = {OP_END, 56'b0};
        for (int i = 0; i < 2**M; i++) dmem_array[i] = '0;
    
        // idle explicit BEFORE the reset, blocking, without m_reset() dependency
        s0_axis.tvalid = 1'b0;  s0_axis.tlast = 1'b0;  s0_axis.tdata = '0;
        s0_axis.tstrb  = '1;    s0_axis.tkeep = '0;    s0_axis.tuser = '0;
        s0_axis.tid    = '0;    s0_axis.tdest = '0;
        s1_axis.tvalid = 1'b0;  s1_axis.tlast = 1'b0;  s1_axis.tdata = '0;
        s1_axis.tstrb  = '1;    s1_axis.tkeep = '0;    s1_axis.tuser = '0;
        s1_axis.tid    = '0;    s1_axis.tdest = '0;
        s2_axis.tvalid = 1'b0;  s2_axis.tlast = 1'b0;  s2_axis.tdata = '0;
        s2_axis.tstrb  = '1;    s2_axis.tkeep = '0;    s2_axis.tuser = '0;
        s2_axis.tid    = '0;    s2_axis.tdest = '0;
        s3_axis.tvalid = 1'b0;  s3_axis.tlast = 1'b0;  s3_axis.tdata = '0;
        s3_axis.tstrb  = '1;    s3_axis.tkeep = '0;    s3_axis.tuser = '0;
        s3_axis.tid    = '0;    s3_axis.tdest = '0;

        // Drive tready on all master interfaces (DUT is master, TB is slave)
        m0_axis.s_cb.tready <= 1'b1;
        m1_axis.s_cb.tready <= 1'b1;
        m2_axis.s_cb.tready <= 1'b1;
        m3_axis.s_cb.tready <= 1'b1;
        m4_axis.s_cb.tready <= 1'b1;
        m5_axis.s_cb.tready <= 1'b1;
        m6_axis.s_cb.tready <= 1'b1;
        m7_axis.s_cb.tready <= 1'b1;

        // Scalar signals – start with reset active
        cb.tb_rstn          <= 1'b0;
        cb.tb_start         <= 1'b0;
        cb.tb_start_src_reg <= 1'b0;
        cb.tb_start_reg     <= 1'b0;
    
    
        // Hold reset for a few cycles
        repeat(20) @(cb);
    
        // Deassert reset
        cb.tb_rstn <= 1'b1;
        @(cb);
    
        // Now reset the slave interface masters (TB is master) – aresetn is already high
        s0_axis.m_reset();
        s1_axis.m_reset();
        s2_axis.m_reset();
        s3_axis.m_reset();
    
        // Additional stabilisation
        repeat(3) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        s0_axis.m_reset();
        s1_axis.m_reset();
        s2_axis.m_reset();
        s3_axis.m_reset();
        cb.tb_rstn  <= 1'b0;
        cb.tb_start <= 1'b0;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    //--------------------------------------------------------------------------
    // load_pmem_hex: load program memory from a hex file.
    //   Each line = one 64-bit instruction word in hex.
    //   Unused slots remain as OP_END (set in setup()).
    //--------------------------------------------------------------------------
    task automatic load_pmem_hex(input string filename = "pmem.hex");
        // Clear first so leftover instructions don't interfere
        for (int i = 0; i < 2**N; i++) pmem_array[i] = {OP_END, 56'b0};
        $readmemh(filename, pmem_array);
        $display("[%0t] Loaded program memory from %s", $time, filename);
    endtask
    
    //--------------------------------------------------------------------------
    // load_dmem_hex: load initial data memory contents from a hex file.
    //   Each line = one 32-bit word in hex.
    //--------------------------------------------------------------------------
    task automatic load_dmem_hex(input string filename = "dmem.hex");
        for (int i = 0; i < 2**M; i++) dmem_array[i] = '0;
        $readmemh(filename, dmem_array);
        $display("[%0t] Loaded data memory from %s", $time, filename);
    endtask
    
    //--------------------------------------------------------------------------
    // dump_dmem_hex: write the final data memory contents to a hex file.
    //   Useful for inspecting results after a program runs.
    //--------------------------------------------------------------------------
    task automatic dump_dmem_hex(input string filename, input int num_words = 0);
        int fd;
        int last = (num_words == 0) ? (2**M) : num_words;
        fd = $fopen(filename, "w");
        if (fd == 0) begin
            `FAIL_UNLESS_LOG(1'b0, $sformatf("Could not open %s for writing", filename));
            return;
        end
        for (int i = 0; i < last; i++)
            $fwrite(fd, "%08h\n", dmem_array[i]);
        $fclose(fd);
        $display("[%0t] Dumped %0d data words to %s", $time, last, filename);
    endtask

    // load_prog: fill pmem_array from a fixed-size array.
    // Remaining slots stay as OP_END (set in setup()).
    task automatic load_prog(input logic [63:0] instructions [], input int n);
        for (int i = 0; i < n; i++)
            pmem_array[i] = instructions[i];
    endtask

    //--------------------------------------------------------------------------
    // drive_start: assert/deassert start and wait 2 cycles for cdc_gray_sync.
    // use_input = 1: use the external input (tb_start) with start_src_reg=1
    // use_input = 0: use the input start_reg (tb_start_reg) with start_src_reg=0
    //--------------------------------------------------------------------------
    task drive_start(logic value, bit use_input = 1);
        cb.tb_start_src_reg <= use_input;
        if (use_input) begin
            cb.tb_start     <= value;
            cb.tb_start_reg <= 1'b0;
        end else begin
            cb.tb_start_reg <= value;
            cb.tb_start     <= 1'b0;
        end
        @(cb);
        @(cb); // 2 cycle sync (cdc_gray_sync)
    endtask
    
    //--------------------------------------------------------------------------
    // start_and_sync: launch the processor and waits for FETCH_ST.
    // use_input = 1: uses tb_start; use_input = 0: uses tb_start_reg.
    // Waits for ir_en_i to be active (max 20 cycles) and then advances to DECODE_ST.
    //--------------------------------------------------------------------------
    task automatic start_and_sync(bit use_input = 1);
        // Deactivate both sources
        cb.tb_start     <= 1'b0;
        cb.tb_start_reg <= 1'b0;
        cb.tb_start_src_reg <= use_input;
        // Activate the selected source
        if (use_input) begin
            cb.tb_start <= 1'b1;
        end else begin
            cb.tb_start_reg <= 1'b1;
        end
        // Wait for the processor to reach FETCH_ST (ir_en=1)
        repeat(20) begin
            @(cb);
            if (u_dut.ir_en_i) break;
        end
        @(cb); // one extra cycle to enter DECODE_ST (if necessary)
    endtask

    // wait_for_ir_en: poll until ir_en asserts (processor in FETCH_ST).
    task automatic wait_for_ir_en(input int timeout = 50);
        automatic int cnt = 0;
        while (!u_dut.ir_en_i && cnt < timeout) begin
            @(cb); cnt++;
        end
    endtask

    // wait_for_reg_wen: poll until reg_wen asserts (write-back cycle).
    task automatic wait_for_reg_wen(input int timeout = 50);
        automatic int cnt = 0;
        while (!u_dut.reg_wen_i && cnt < timeout) begin
            @(cb); cnt++;
        end
    endtask

    // wait_for_dmem_we: poll until dmem_we asserts.
    task automatic wait_for_dmem_we(input int timeout = 50);
        automatic int cnt = 0;
        while (!u_dut.dmem_we && cnt < timeout) begin
            @(cb); cnt++;
        end
    endtask

    // wait_for_fifo_wr: poll until fifo_wr_en_mux asserts.
    task automatic wait_for_fifo_wr(input int timeout = 50);
        automatic int cnt = 0;
        while (!u_dut.fifo_wr_en_mux && cnt < timeout) begin
            @(cb); cnt++;
        end
    endtask

    // wait_for_end: poll until FSM is idle for 3 consecutive cycles.
    // END_ST: ir_en=0, pc_en=0, reg_wen=0, stack_en=0, fifo_wr_en=0, pc_rst=0.
    task automatic wait_for_end(input int timeout = 200);
        automatic int cnt       = 0;
        automatic int idle_cnt  = 0;
        while (idle_cnt < 3 && cnt < timeout) begin
            @(cb); cnt++;
            if (!u_dut.ir_en_i  && !u_dut.pc_en_i    &&
                !u_dut.reg_wen_i && !u_dut.stack_en_i  &&
                !u_dut.fifo_wr_en_mux && !u_dut.pc_rst_i)
                idle_cnt++;
            else
                idle_cnt = 0;
        end
    endtask

    //// send_axis_s: send one word on a slave-side interface (DUT is slave, TB is master).
    //// Uses the interface's m_cb clocking block.
    //task automatic send_axis_s(
    //    ref   axi4_stream_if axis_if,
    //    input logic [63:0] data
    //);
    //    axis_if.m_cb.tdata  <= data;
    //    axis_if.m_cb.tvalid <= 1'b1;
    //    // Wait for tready (DUT asserts when axis_set_reg accepts)
    //    @(axis_if.m_cb);
    //    while (!axis_if.m_cb.tready) @(axis_if.m_cb);
    //    @(axis_if.m_cb);
    //    axis_if.m_cb.tvalid <= 1'b0;
    //    axis_if.m_cb.tdata  <= '0;
    //endtask

    //// recv_axis_m: wait for and capture one transaction on a master-side interface
    //// (DUT is master, TB is slave). Uses s_cb to sample tdata/tvalid.
    //task automatic recv_axis_m(
    //    ref   axi4_stream_if axis_if,
    //    output logic [159:0] data
    //);
    //    // tready already held high in setup(); just wait for tvalid
    //    @(axis_if.s_cb);
    //    while (!axis_if.s_cb.tvalid) @(axis_if.s_cb);
    //    data = axis_if.s_cb.tdata;
    //endtask

    //--------------------------------------------------------------------------
    // Test Cases
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "tprocv1_tests.sv"
    `SVUNIT_TESTS_END

endmodule
