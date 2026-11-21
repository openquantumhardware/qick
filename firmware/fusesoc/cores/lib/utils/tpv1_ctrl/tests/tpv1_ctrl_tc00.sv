`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component : tpv1_ctrl_unit_test
// Origin    : Unit testbench for tpv1_ctrl.sv (tProcV1 control state machine).
//
// Description:
//   Exercises the multi-cycle control FSM of the tProcessor. The DUT is a pure
//   Moore FSM: it generates all datapath control signals based on the current
//   state and a set of condition inputs. The TB drives opcode + condition flags
//   and checks that the correct sequence of control signals is produced.
//
// Test strategy:
//   Each test covers one instruction family end-to-end:
//     - Drive opcode into DECODE_ST
//     - Step through every FSM state of that instruction
//     - Assert the expected control signals at each state
//     - Confirm FSM returns to the correct next state (DECODE/FETCH)
//
// Key timing convention:
//   - Processor pipeline: FETCH_ST latches IR and advances PC, then DECODE_ST
//     dispatches to instruction-specific states.
//   - 4-cycle ALU instructions (MATH/BITW variants): states _0.._3, write-back
//     happens on _3.
//   - FIFO-blocking instructions (SETI/SET/WAITI/WAIT): _1 state holds until
//     ~fifo_full.
//   - LOOPNZ: pc_en is gated by ~alu_zero; CONDJ: pc_en gated by cond_flag.
//
// Opcode reference (from tpv1_ctrl.sv header):
//   I-Type: PUSHI=0x10, POPI=0x11, MATHI=0x12, SETI=0x13, SYNCI=0x14,
//           WAITI=0x15, BITWI=0x16, MEMRI=0x17, MEMWI=0x18, REGWI=0x19, SETBI=0x1A
//   J-Type: LOOPNZ=0x30, CONDJ=0x31, END=0x3F
//   R-Type: MATH=0x50, SET=0x51, SYNC=0x52, READ=0x53, WAIT=0x54,
//           BITW=0x55, MEMR=0x56, MEMW=0x57, SETB=0x58
//------------------------------------------------------------------------------
module tpv1_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;
    import tproc_pkg::*;

    string name = "tpv1_ctrl_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real CLOCK_FREQUENCY = 100e6; // 100 MHz

    // Opcode constants (mirrors tpv1_ctrl.sv localparams)
    localparam logic [7:0] OP_PUSHI  = 8'b00010000;
    localparam logic [7:0] OP_POPI   = 8'b00010001;
    localparam logic [7:0] OP_MATHI  = 8'b00010010;
    localparam logic [7:0] OP_SETI   = 8'b00010011;
    localparam logic [7:0] OP_SYNCI  = 8'b00010100;
    localparam logic [7:0] OP_WAITI  = 8'b00010101;
    localparam logic [7:0] OP_BITWI  = 8'b00010110;
    localparam logic [7:0] OP_MEMRI  = 8'b00010111;
    localparam logic [7:0] OP_MEMWI  = 8'b00011000;
    localparam logic [7:0] OP_REGWI  = 8'b00011001;
    localparam logic [7:0] OP_SETBI  = 8'b00011010;
    localparam logic [7:0] OP_LOOPNZ = 8'b00110000;
    localparam logic [7:0] OP_CONDJ  = 8'b00110001;
    localparam logic [7:0] OP_END    = 8'b00111111;
    localparam logic [7:0] OP_MATH   = 8'b01010000;
    localparam logic [7:0] OP_SET    = 8'b01010001;
    localparam logic [7:0] OP_SYNC   = 8'b01010010;
    localparam logic [7:0] OP_READ   = 8'b01010011;
    localparam logic [7:0] OP_WAIT   = 8'b01010100;
    localparam logic [7:0] OP_BITW   = 8'b01010101;
    localparam logic [7:0] OP_MEMR   = 8'b01010110;
    localparam logic [7:0] OP_MEMW   = 8'b01010111;
    localparam logic [7:0] OP_SETB   = 8'b01011000;
    localparam logic [7:0] OP_UNKNOWN= 8'hFF;

    //--------------------------------------------------------------------------
    // Interface & Testbench Signals
    //--------------------------------------------------------------------------
    logic        tb_clk         = 1'b0;
    logic        tb_rstn        = 1'b0;

    logic        tb_start       = 1'b0;
    logic [7:0]  tb_opcode      = '0;
    logic        tb_alu_zero    = 1'b0;
    logic        tb_cond_flag   = 1'b0;
    logic        tb_stack_full  = 1'b0;
    logic        tb_stack_empty = 1'b0;
    logic        tb_fifo_full   = 1'b0;
    logic        tb_waitt       = 1'b0;

    // DUT outputs
    logic        tb_ir_en;
    logic        tb_pc_src;
    logic        tb_pc_en;
    logic        tb_pc_rst;
    logic [1:0]  tb_alu_src_b;
    logic        tb_alut_src_b;
    logic [2:0]  tb_reg_src;
    logic        tb_reg_wen;
    logic        tb_stack_en;
    logic        tb_stack_op;
    logic        tb_fifo_wr_en;
    logic        tb_dmem_we;
    logic        tb_addr_src;
    logic        tb_t_en;
    logic        tb_t_sync_en;
    logic        tb_waitt_ack;

    //--------------------------------------------------------------------------
    // VCD Waveform Generation
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tpv1_ctrl.vcd");
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
        output tb_rstn;
        output tb_start;
        output tb_opcode;
        output tb_alu_zero;
        output tb_cond_flag;
        output tb_stack_full;
        output tb_stack_empty;
        output tb_fifo_full;
        output tb_waitt;
        input  tb_ir_en;
        input  tb_pc_src;
        input  tb_pc_en;
        input  tb_pc_rst;
        input  tb_alu_src_b;
        input  tb_alut_src_b;
        input  tb_reg_src;
        input  tb_reg_wen;
        input  tb_stack_en;
        input  tb_stack_op;
        input  tb_fifo_wr_en;
        input  tb_dmem_we;
        input  tb_addr_src;
        input  tb_t_en;
        input  tb_t_sync_en;
        input  tb_waitt_ack;
    endclocking

    //--------------------------------------------------------------------------
    // Unit Under Test (DUT)
    //--------------------------------------------------------------------------
    tpv1_ctrl u_dut (
        .clk         (tb_clk),
        .rstn        (tb_rstn),
        .start       (tb_start),
        .opcode      (tb_opcode),
        .ir_en       (tb_ir_en),
        .pc_src      (tb_pc_src),
        .pc_en       (tb_pc_en),
        .pc_rst      (tb_pc_rst),
        .alu_src_b   (tb_alu_src_b),
        .alu_zero    (tb_alu_zero),
        .alut_src_b  (tb_alut_src_b),
        .reg_src     (tb_reg_src),
        .reg_wen     (tb_reg_wen),
        .cond_flag   (tb_cond_flag),
        .stack_en    (tb_stack_en),
        .stack_op    (tb_stack_op),
        .stack_full  (tb_stack_full),
        .stack_empty (tb_stack_empty),
        .fifo_wr_en  (tb_fifo_wr_en),
        .fifo_full   (tb_fifo_full),
        .dmem_we     (tb_dmem_we),
        .addr_src    (tb_addr_src),
        .t_en        (tb_t_en),
        .t_sync_en   (tb_t_sync_en),
        .waitt       (tb_waitt),
        .waitt_ack   (tb_waitt_ack)
    );

    //--------------------------------------------------------------------------
    // Concurrent Assertions
    //--------------------------------------------------------------------------

    // waitt_ack and fifo_wr_en must never assert simultaneously
    property no_waitt_ack_and_fifo_wr;
        @(posedge tb_clk) disable iff (!tb_rstn)
        !(tb_waitt_ack && tb_fifo_wr_en);
    endproperty
    `ASSERT_CONCURRENT(no_waitt_ack_and_fifo_wr);

    // reg_wen must only assert when reg_src is valid (not X)
    property reg_wen_implies_valid_src;
        @(posedge tb_clk) disable iff (!tb_rstn)
        tb_reg_wen |-> !$isunknown(tb_reg_src);
    endproperty
    `ASSERT_CONCURRENT(reg_wen_implies_valid_src);

    // t_en is always 1 except in START_MC_ST: never deassert unexpectedly
    // (deasserts only for 1 cycle during startup)
    property t_en_default_high;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (!tb_t_en) |=> (tb_t_en);  // if deasserted, must re-assert next cycle
    endproperty
    `ASSERT_CONCURRENT(t_en_default_high);

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure (Build, Setup, Teardown)
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_rstn        <= 1'b0;
        cb.tb_start       <= 1'b0;
        cb.tb_opcode      <= '0;
        cb.tb_alu_zero    <= 1'b0;
        cb.tb_cond_flag   <= 1'b0;
        cb.tb_stack_full  <= 1'b0;
        cb.tb_stack_empty <= 1'b0;
        cb.tb_fifo_full   <= 1'b0;
        cb.tb_waitt       <= 1'b0;
        repeat(3) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        cb.tb_rstn  <= 1'b0;
        cb.tb_start <= 1'b0;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    // bring_to_decode: start the processor and advance to the first
    // instruction-specific state after DECODE_ST.
    //
    // Timing:
    //   The opcode must be stable when the FSM is in DECODE_ST so it can
    //   dispatch correctly. In the real datapath the IR is loaded during
    //   FETCH_ST (ir_en=1). We mirror that here by driving the opcode one
    //   cycle before DECODE_ST (i.e. during the FETCH→DECODE transition).
    //
    //   INIT_ST    : start asserted
    //   PC_RST_ST  : pc_rst=1
    //   START_MC_ST: t_en=0
    //   FETCH_ST   : ir_en=1, pc_en=1  ← opcode driven here
    //   DECODE_ST  : FSM sees opcode, dispatches
    //   <first instr state> ← task returns here, ready to sample
    task bring_to_decode(input logic [7:0] op);
        cb.tb_start  <= 1'b1;
        @(cb);              // for simulation sync
        @(cb);              // INIT_ST     → PC_RST_ST
        @(cb);              // PC_RST_ST   → START_MC_ST
        @(cb);              // START_MC_ST → FETCH_ST
        cb.tb_opcode <= op; // IR load: opcode valid before DECODE_ST samples it
        @(cb);              // FETCH_ST    → DECODE_ST
        @(cb);              // DECODE_ST   → first instruction state
    endtask

    // step: advance one clock cycle and sample outputs.
    task step();
        @(cb);
    endtask

    // drive_start: add two @(cb) for simulation sync
    task drive_start(logic value);
        cb.tb_start <= value;
        @(cb);
        @(cb); // Needed for the clocking block to sample the new state
    endtask

    //--------------------------------------------------------------------------
    // Test Cases Block Insertion
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "tpv1_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule
