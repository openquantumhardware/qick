///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_ctrl.sv
//!
//! @brief   Start/stop/reset and time-base control for the QICK tProcessor
//!          v2 core, across the AXI-Lite (PS), network (xcom) and internal
//!          (core) request sources.
//!
//! @details
//!
//!
//! Owns two independent FSMs:
//! * Core control  (c_clk_i domain): RST_STOP -> RST_RUN -> RUN -> STOP,
//!   plus a single-instruction STEP path. Holds the reset/enable pulses in
//!   RST_* until the datapath FIFOs drain (`all_fifo_full_i`), and pauses
//!   `core_en_o` while `some_fifo_full_i` (unless TPROC_CFG bit 11 is set).
//! * Time control  (t_clk_i domain): RST_STOP/RST_RUN -> RUN, plus an UPDT
//!   path that reseeds the time base (via qproc_time_ctrl) from either the
//!   core (`int_time_*`) or the PS (`xreg_tproc_w_dt_i`).
//!
//! The two FSMs run in different clock domains; `PS_TPROC_CTRL`/`_CFG` are
//! synchronized PS(unknown)->c_clk_i, and the resulting core-domain pulses
//! (plus `core_rst_o`) are synchronized c_clk_i->t_clk_i by a single
//! `cdc_reg_sync`, mirroring the original `sync_reg` instance.
//!
//! Ported from firmware/ip/qick_processor/src/qproc_ctrl.sv (FSMs and CDC
//! structure unchanged). `sync_reg` -> `cdc_reg_sync` (same 2-flop-per-bit
//! synchronizer, documented as its replacement); `sync_ab_en`/
//! `qproc_time_ctrl` are the already-ported lib cores. All previously
//! implicit nets were made explicit and `PS_TPROC_CTRL`/`PS_TPROC_CFG`/
//! `xreg_TPROC_*` renamed to the repo's lowercase signal convention
//! (`ps_tproc_ctrl_i`/`ps_tproc_cfg_i`/`xreg_tproc_*`).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qproc_ctrl #(
    parameter int TIME_READ = 1
) (
    // Time, core and AXI clk & rst
    input  logic        t_clk_i,
    input  logic        t_rst_ni,
    input  logic        c_clk_i,
    input  logic        c_rst_ni,
    // External control
    input  logic        proc_start_i,
    input  logic        proc_stop_i,
    input  logic        core_start_i,
    input  logic        core_stop_i,
    input  logic        time_rst_i,
    input  logic        time_updt_i,
    input  logic [31:0] time_updt_dt_i,
    // Core control
    input  logic        int_time_en,   // int_time_pen
    input  logic [3:0]  int_time_cmd,  // core_usr_operation
    input  logic [31:0] int_time_dt,   // core_usr_operation
    // AXI control
    input  logic [15:0] ps_tproc_ctrl_i,
    input  logic [11:9] ps_tproc_cfg_i,
    input  logic [31:0] xreg_tproc_w_dt_i,
    // qproc state
    input  logic        all_fifo_full_i,
    input  logic        some_fifo_full_i,
    // Core state
    output logic         core_rst_o,
    output logic         core_en_o,
    // Time state
    output logic         time_rst_o,
    output logic         time_en_o,
    output logic [47:0]  time_abs_o,
    output logic [47:0]  c_time_ref_o,
    output logic [31:0]  c_time_usr_o, // User time "current_user_time"
    // Debug
    output logic [2:0]   time_st_do,
    output logic [2:0]   core_st_do,
    output logic [6:0]   t_debug_do,
    output logic [6:0]   c_debug_do
);

    //-------------------------------------------------------
    // Code moved from qproc_axi_reg due to issue #33
    (* ASYNC_REG = "TRUE" *) logic [15:0] tproc_ctrl_cdc, tproc_ctrl_sync;
    logic [15:0] tproc_ctrl_2r;
    logic [15:0] xreg_tproc_ctrl;

    (* ASYNC_REG = "TRUE" *) logic [11:9] tproc_cfg_cdc, tproc_cfg_sync;
    logic [11:9] xreg_tproc_cfg;

    // From PS_CLK to C_CLK
    always_ff @(posedge c_clk_i) begin
        if (!c_rst_ni) begin
            tproc_ctrl_cdc  <= 0;
            tproc_ctrl_sync <= 0;
            tproc_ctrl_2r   <= 0;
            tproc_cfg_cdc   <= 0;
        end else begin
            tproc_ctrl_cdc  <= ps_tproc_ctrl_i;
            tproc_ctrl_sync <= tproc_ctrl_cdc;
            tproc_ctrl_2r   <= tproc_ctrl_sync;
            tproc_cfg_cdc   <= ps_tproc_cfg_i;
            tproc_cfg_sync  <= tproc_cfg_cdc;
        end
    end

    // xreg_tproc_ctrl is only asserted for ONE clock (rising-edge pulse).
    assign xreg_tproc_ctrl = tproc_ctrl_sync & ~tproc_ctrl_2r;
    assign xreg_tproc_cfg  = tproc_cfg_sync;
    //-------------------------------------------------------


    // Control
    logic [31:0] time_updt_dt; // New incremental time value

    ///////////////////////////////////////////////////////////////////////////
    // Control signals
    ///////////////////////////////////////////////////////////////////////////
    logic proc_start_io, proc_stop_io;
    logic time_stop_p, time_run_p, time_rst_stop_p, time_rst_run_p, time_update_p, time_step_p;
    logic core_stop_p, core_run_p, core_rst_stop_p, core_rst_run_p, core_step_p;
    logic time_rst_core, time_updt_core, time_ref_set, time_ref_inc;
    logic time_rst_net, time_updt_net, core_start_net, core_stop_net;
    logic c_time_rst_run, c_time_updt;
    logic ctrl_c_rst_stop, ctrl_c_rst_run, ctrl_c_stop, ctrl_c_run, ctrl_c_step;

    /// IO ctrl
    assign proc_start_io = proc_start_i & xreg_tproc_cfg[10];
    assign proc_stop_io  = proc_stop_i  & xreg_tproc_cfg[10];

    /// Python
    assign time_stop_p     = xreg_tproc_ctrl[3] | xreg_tproc_ctrl[9] | proc_stop_io; // STOP  | P_FREEZE
    assign time_run_p      = xreg_tproc_ctrl[7] | xreg_tproc_ctrl[8];                // RUN   | P_PAUSE
    assign time_rst_stop_p = xreg_tproc_ctrl[6];                                     // T_RST | START | P_RST
    assign time_rst_run_p  = xreg_tproc_ctrl[0] | xreg_tproc_ctrl[2] | proc_start_io; // START | T_RST
    assign time_update_p   = xreg_tproc_ctrl[1];
    assign time_step_p     = xreg_tproc_ctrl[10] | xreg_tproc_ctrl[12];

    // STOP | C_STOP | P_PAUSE
    assign core_stop_p     = xreg_tproc_ctrl[3] | xreg_tproc_ctrl[5] | xreg_tproc_ctrl[8] | proc_stop_io;
    assign core_run_p      = xreg_tproc_ctrl[7] | xreg_tproc_ctrl[9];                // RUN | P_FREEZE
    assign core_rst_stop_p = xreg_tproc_ctrl[6];                                     // P_RST
    assign core_rst_run_p  = xreg_tproc_ctrl[2] | xreg_tproc_ctrl[4] | proc_start_io; // START | C_START
    assign core_step_p     = xreg_tproc_ctrl[10] | xreg_tproc_ctrl[11];

    /// qproc-core
    assign time_rst_core  = int_time_en & int_time_cmd[0];
    assign time_updt_core = int_time_en & int_time_cmd[1];
    assign time_ref_set   = int_time_en & int_time_cmd[2];
    assign time_ref_inc   = int_time_en & int_time_cmd[3];

    /// Net ctrl
    assign time_rst_net   = time_rst_i   & ~xreg_tproc_cfg[9];
    assign time_updt_net  = time_updt_i  & ~xreg_tproc_cfg[9];
    assign core_start_net = core_start_i & ~xreg_tproc_cfg[9];
    assign core_stop_net  = core_stop_i  & ~xreg_tproc_cfg[9];

    assign c_time_rst_run = time_rst_run_p | time_rst_core;
    assign c_time_updt    = time_update_p  | time_updt_core;



    ///////////////////////////////////////////////////////////////////////////
    // Core control
    ///////////////////////////////////////////////////////////////////////////

    // Store time_updt_dt from processor or Python in offset_dt_r
    logic [31:0] offset_dt_r;
    always_ff @(posedge c_clk_i)
        if (!c_rst_ni) begin
            offset_dt_r <= 0;
        end else begin
            if      (time_updt_core) offset_dt_r <= int_time_dt;      // Update from core
            else if (time_update_p)  offset_dt_r <= xreg_tproc_w_dt_i; // Update from Python
        end

    assign ctrl_c_rst_stop = core_rst_stop_p;
    assign ctrl_c_rst_run  = core_start_net | core_rst_run_p;
    assign ctrl_c_stop     = core_stop_net | core_stop_p;
    assign ctrl_c_run      = core_run_p;
    assign ctrl_c_step     = core_step_p;


    // Core control state machine
    ///////////////////////////////////////////////////////////////////////////
    typedef enum logic [2:0] {
        C_RST_STOP,
        C_RST_STOP_WAIT,
        C_RST_RUN,
        C_RST_RUN_WAIT,
        C_STOP,
        C_RUN,
        C_STEP,
        C_END_STEP
    } core_st_t;
    core_st_t core_st_nxt, core_st;

    // Sequential state machine
    always_ff @(posedge c_clk_i)
        if (!c_rst_ni) core_st <= C_RST_STOP;
        else           core_st <= core_st_nxt;

    // State change and out
    always_comb begin
        core_en_o   = 0;
        core_rst_o  = 0;
        core_st_nxt = core_st;
        // Common transitions
        if      (ctrl_c_stop)     core_st_nxt = C_STOP;
        else if (ctrl_c_run)      core_st_nxt = C_RUN;
        else if (ctrl_c_rst_run)  core_st_nxt = C_RST_RUN;
        else if (ctrl_c_rst_stop) core_st_nxt = C_RST_STOP;
        else if (ctrl_c_step)     core_st_nxt = C_STEP;
        // State transitions and out
        case (core_st)
            C_RST_RUN: begin
                core_rst_o = 1;
                if (all_fifo_full_i) core_st_nxt = C_RST_RUN_WAIT;
            end
            C_RST_RUN_WAIT:
                if (!all_fifo_full_i) core_st_nxt = C_RUN;
            C_RST_STOP: begin
                core_rst_o = 1;
                if (all_fifo_full_i) core_st_nxt = C_RST_STOP_WAIT;
            end
            C_RST_STOP_WAIT:
                if (!all_fifo_full_i) core_st_nxt = C_STOP;
            C_RUN: begin
                core_en_o = 1;
            end
            C_STOP: begin
            end
            C_STEP: begin
                core_en_o   = 1;
                core_st_nxt = C_END_STEP;
            end
            C_END_STEP: begin
                if (!ctrl_c_step) core_st_nxt = C_STOP;
            end
            default: ;
        endcase
        // Pause core on dispatcher FIFO full; with 1 in TPROC_CFG[11] continue
        if (some_fifo_full_i & ~xreg_tproc_cfg[11]) begin
            core_en_o = 0;
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Time control
    ///////////////////////////////////////////////////////////////////////////

    // T_CLK domain synchronization
    ///////////////////////////////////////////////////////////////////////////
    logic core_rst_ack, t_time_rst_stop, t_time_rst_run, t_time_update, t_time_stop, t_time_run, t_time_step;
    logic t_core_rst_prev_net; // Net request to reset the processor and go to previous state

    cdc_reg_sync #(.DW (7)) cdc_ctrl_ps_t_i (
        .clk_i  (t_clk_i),
        .rst_ni (t_rst_ni),
        .dt_i   ({core_rst_o, time_rst_stop_p, c_time_rst_run, c_time_updt, time_stop_p, time_run_p, time_step_p}),
        .dt_o   ({core_rst_ack, t_time_rst_stop, t_time_rst_run, t_time_update, t_time_stop, t_time_run, t_time_step})
    );


    always_ff @(posedge t_clk_i)
        if (!t_rst_ni) begin
            t_core_rst_prev_net <= 1'b0; // Net request to reset the processor
            time_updt_dt        <= 32'd0; // Store time_updt_dt from offset_dt_r(core,Python) or time_updt_dt_i(net)
        end else begin
            if (t_time_update)
                time_updt_dt <= offset_dt_r;
            else
                time_updt_dt <= time_updt_dt_i;
            if      (time_rst_net) t_core_rst_prev_net <= 1'b1;
            else if (core_rst_ack) t_core_rst_prev_net <= 1'b0;
        end

    logic ctrl_t_rst_stop, ctrl_t_rst_run, ctrl_t_updt, ctrl_t_run, ctrl_t_stop, ctrl_t_step;
    assign ctrl_t_rst_stop = t_time_rst_stop;
    assign ctrl_t_rst_run  = time_rst_net | t_time_rst_run;
    assign ctrl_t_updt     = time_updt_net | t_time_update;
    assign ctrl_t_run      = t_time_run;
    assign ctrl_t_stop     = t_time_stop;
    assign ctrl_t_step     = t_time_step;

    // Time control state machine
    ///////////////////////////////////////////////////////////////////////////
    typedef enum logic [2:0] {
        T_RST_STOP,
        T_RST_RUN,
        T_UPDT,
        T_RUN,
        T_STOP,
        T_STEP
    } time_ctrl_st_t;
    time_ctrl_st_t time_st_nxt, time_st;

    // Sequential state machine
    always_ff @(posedge t_clk_i)
        if (!t_rst_ni) time_st <= T_RST_STOP;
        else           time_st <= time_st_nxt;

    // State change and out
    logic time_updt;
    always_comb begin
        time_en_o   = 0;
        time_rst_o  = 0;
        time_updt   = 0;
        time_st_nxt = time_st;
        // Common transitions
        if       (ctrl_t_rst_stop) time_st_nxt = T_RST_STOP;
        if       (ctrl_t_rst_run)  time_st_nxt = T_RST_RUN;
        else if  (ctrl_t_updt)     time_st_nxt = T_UPDT;
        else if  (ctrl_t_run)      time_st_nxt = T_RUN;
        else if  (ctrl_t_stop)     time_st_nxt = T_STOP;
        else if  (ctrl_t_step)     time_st_nxt = T_STEP;
        case (time_st)
            T_RST_STOP: begin
                time_en_o   = 1;
                time_rst_o  = 1;
                time_st_nxt = T_STOP;
            end
            T_RST_RUN: begin
                time_en_o   = 1;
                time_rst_o  = 1;
                time_st_nxt = T_RUN;
            end
            T_UPDT: begin
                time_en_o   = 1;
                time_updt   = 1;
                time_st_nxt = T_RUN;
            end
            T_RUN: begin
                time_en_o = 1;
            end
            T_STEP: begin
                time_en_o   = 1;
                time_st_nxt = T_STOP;
            end
            default: ;
        endcase
    end


    // Time REF
    ///////////////////////////////////////////////////////////////////////////
    always_ff @(posedge c_clk_i, negedge c_rst_ni) begin
        if (!c_rst_ni)          c_time_ref_o <= '{default: '0};
        else if (core_rst_o)    c_time_ref_o <= '{default: '0};
        else if (time_ref_set)  c_time_ref_o <= {16'd0, int_time_dt};
        else if (time_ref_inc)  c_time_ref_o <= c_time_ref_o + {16'd0, int_time_dt};
    end

    // Time ABS
    ///////////////////////////////////////////////////////////////////////////
    qproc_time_ctrl qtime_ctrl_i (
        .t_clk_i     (t_clk_i),
        .t_rst_ni    (t_rst_ni),
        .time_en_i   (time_en_o),
        .time_rst_i  (time_rst_o),
        .time_init_i (1'b0),
        .time_updt_i (time_updt),
        .updt_dt_i   (time_updt_dt),
        .time_abs_o  (time_abs_o)
    );

    assign c_debug_do = {2'b00, ctrl_c_step, ctrl_c_stop, ctrl_c_run, ctrl_c_rst_run, ctrl_c_rst_stop};
    assign t_debug_do = {ctrl_t_updt, 1'b0, ctrl_t_step, ctrl_t_stop, ctrl_t_run, ctrl_t_rst_run, ctrl_t_rst_stop};

    ///////////////////////////////////////////////////////////////////////////
    // Time read
    (* ASYNC_REG = "TRUE" *) logic [47:0] c_time_abs_r; // Absolute time counter value, registered
    logic [47:0] t_time_abs_r;
    logic        c_time_en, t_time_en;

    generate
        if (TIME_READ == 1) begin : gen_time_read
            sync_ab_en sync_ab_en_i (
                .clk_a_i  (c_clk_i),
                .rst_a_ni (c_rst_ni),
                .clk_b_i  (t_clk_i),
                .rst_b_ni (t_rst_ni),
                .a_en_o   (c_time_en),
                .b_en_o   (t_time_en)
            );

            // Register time_abs
            ///////////////////////////////////////////////////////////////////////////
            always_ff @(posedge t_clk_i) begin
                if      (!t_rst_ni)  t_time_abs_r <= 0;
                else if (t_time_en)  t_time_abs_r <= time_abs_o;
            end

            always_ff @(posedge c_clk_i) begin
                if      (!c_rst_ni)  c_time_abs_r <= 0;
                else if (c_time_en)  c_time_abs_r <= t_time_abs_r;
            end

            assign c_time_usr_o = (c_time_abs_r - c_time_ref_o);

        end else begin : gen_no_time_read
            assign c_time_usr_o = 0;
        end
    endgenerate

    assign time_st_do = {time_st[2:0]};
    assign core_st_do = {core_st[2:0]};

endmodule
