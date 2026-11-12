///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_time_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_time_ctrl.sv
//!
//! @brief   Absolute time counter for the QICK tProcessor v2 core.
//!
//! @details
//!
//!
//! A small FSM drives a 48-bit counter (`time_abs_o`) that can be reset to
//! 0 (`time_rst_i`), seeded from `updt_dt_i` (`time_init_i`), stepped by a
//! sign-extended `updt_dt_i` (`time_updt_i`), or free-run incrementing by 1
//! each enabled cycle (`time_en_i`).
//!
//! Ported from firmware/ip/qick_processor/src/qproc_time_ctrl.sv (FSM
//! unchanged). The Xilinx `ADDSUB_MACRO` (7SERIES, WIDTH=48, LATENCY=1,
//! always ADD_SUB=1) primitive was replaced by a plain synthesizable
//! adder with the same synchronous-reset/clock-enable/carry-in semantics
//! (`RESULT <= RST ? 0 : (CE ? A + B + CARRYIN : RESULT)`), so the core
//! lints/sims without Vivado's UNISIM library. This also fixes a real
//! discrepancy the legacy file's dead, commented-out RTL-inference
//! alternative had flagged as unverified ("not sure if it does exactly the
//! same"): that alternative dropped the carry-in (`time_c_in`) added during
//! the ST_UPDATE state, which the ADDSUB_MACRO in hardware does add.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qproc_time_ctrl (
    input  logic        t_clk_i,
    input  logic        t_rst_ni,
    input  logic        time_en_i,   // Time runs
    input  logic        time_rst_i,  // Set time to 0
    input  logic        time_init_i, // Set time to current offset
    input  logic        time_updt_i, // Increment time by updt_dt_i
    input  logic [31:0] updt_dt_i,
    output logic [47:0] time_abs_o
);

    ///////////////////////////////////////////////////////////////////////////
    // Time ABS
    logic [47:0] time_abs;

    logic [47:0] time_update_dt;
    assign time_update_dt = {{16{updt_dt_i[31]}}, updt_dt_i}; // Sign-extend updt_dt_i

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RESET,
        ST_INIT,
        ST_LOAD_OFFSET,
        ST_INCREMENT,
        ST_UPDATE
    } time_st_t;
    time_st_t ctrl_time_st, ctrl_time_st_nxt;

    ////////// Sequential logic
    always_ff @(posedge t_clk_i) begin : ctrl_sync_proc
        if (!t_rst_ni) ctrl_time_st <= ST_IDLE;
        else           ctrl_time_st <= ctrl_time_st_nxt;
    end

    ////////// Comb logic - outputs and state
    logic [47:0] time_inc;
    logic        time_cnt_en, time_c_in;

    logic time_cnt_rst;
    assign time_cnt_rst = time_rst_i | time_init_i;


    always_comb begin : ctrl_st_and_output_decode
        time_cnt_en = 1'b0;
        time_inc    = 48'd0;
        time_c_in   = 1'b0;

        ctrl_time_st_nxt = ctrl_time_st; // Default: hold current state
        unique case (ctrl_time_st)
            ST_IDLE: begin
                if      (time_rst_i)  ctrl_time_st_nxt = ST_RESET;
                else if (time_init_i) ctrl_time_st_nxt = ST_INIT;
                else if (time_updt_i) ctrl_time_st_nxt = ST_UPDATE;
                else if (time_en_i)   ctrl_time_st_nxt = ST_INCREMENT;
            end
            ST_RESET: begin
                if (time_en_i) ctrl_time_st_nxt = ST_INCREMENT;
                else           ctrl_time_st_nxt = ST_IDLE;
            end
            ST_INIT: begin
                time_cnt_en      = 1'b1;
                ctrl_time_st_nxt = ST_LOAD_OFFSET;
            end
            ST_LOAD_OFFSET: begin
                time_cnt_en      = 1'b1;
                time_inc         = updt_dt_i;
                ctrl_time_st_nxt = ST_INCREMENT;
            end
            ST_INCREMENT: begin
                time_cnt_en = 1'b1;
                time_inc    = 48'd1;
                if      (time_rst_i)  ctrl_time_st_nxt = ST_RESET;
                else if (time_init_i) ctrl_time_st_nxt = ST_INIT;
                else if (time_updt_i) ctrl_time_st_nxt = ST_UPDATE;
                else if (!time_en_i)  ctrl_time_st_nxt = ST_IDLE;
            end
            ST_UPDATE: begin
                time_cnt_en      = 1'b1;
                time_inc         = time_update_dt;
                time_c_in        = 1'b1;
                ctrl_time_st_nxt = ST_INCREMENT;
            end
            default: ;
        endcase
    end

    // Time operation: RESULT <= RST ? 0 : (CE ? A + B + CARRYIN : RESULT),
    // matching ADDSUB_MACRO(DEVICE="7SERIES", LATENCY=1, WIDTH=48, ADD_SUB=1).
    always_ff @(posedge t_clk_i) begin
        if (time_cnt_rst)
            time_abs <= '0;
        else if (time_cnt_en)
            time_abs <= time_abs + time_inc + {47'd0, time_c_in};
    end

    assign time_abs_o = time_abs;

endmodule
