///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dmem_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dmem_ctrl.sv
//!
//! @brief   Arbitrates access to the data memory between three modes:
//!
//! @details
//!
//!
//! sel=0 : single read/write (via dmem_single_rw)
//! sel=1 : AXIS read  — memory → m_axis (via dmem_axis_reader)
//! sel=2 : AXIS write — s_axis → memory (via dmem_axis_writer)
//!
//! While an AXIS transaction is in progress, busy_o is asserted and the
//! single-access interface is locked out.
//!
//! FSM:
//! INIT_ST          : idle; single-access available (sel=0)
//! AXIS_READ_ST     : one-cycle setup before asserting ar_exec
//! AXIS_READ_ACK_ST : wait for dmem_axis_reader to complete (ar_exec_ack)
//! AXIS_WRITE_ST    : one-cycle setup before asserting aw_exec
//! AXIS_WRITE_ACK_ST: wait for dmem_axis_writer to complete (aw_exec_ack)
//! END_ST           : wait for start_reg to deassert before returning
//!
//! Registers (from AXI-Lite or processor):
//! mode_reg  : 0 = AXIS read, 1 = AXIS write
//! start_reg : 1 = start AXIS transaction, 0 = idle
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dmem_ctrl #(
    parameter int N = 16    // kept for future address-width awareness
)(
    input  logic        clk,
    input  logic        rstn,

    // Memory access selector (to address mux in dmem)
    output logic [1:0]  sel_o,      // 0=single, 1=axis_read, 2=axis_write

    // Handshake with dmem_axis_reader
    output logic        ar_exec_o,
    input  logic        ar_exec_ack_i,

    // Handshake with dmem_axis_writer
    output logic        aw_exec_o,
    input  logic        aw_exec_ack_i,

    // Busy flag (single-access locked out)
    output logic        busy_o,

    // Control registers
    input  logic        mode_reg,
    input  logic        start_reg
);

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        INIT_ST           = 3'd0,
        AXIS_READ_ST      = 3'd1,
        AXIS_READ_ACK_ST  = 3'd2,
        AXIS_WRITE_ST     = 3'd3,
        AXIS_WRITE_ACK_ST = 3'd4,
        END_ST            = 3'd6
    } state_t;

    state_t state;

    //--------------------------------------------------------------------------
    // FSM: sequential
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state <= INIT_ST;
        end else begin
            unique case (state)
                INIT_ST: begin
                    if (start_reg) begin
                        if (!mode_reg)
                            state <= AXIS_READ_ST;
                        else
                            state <= AXIS_WRITE_ST;
                    end
                end

                AXIS_READ_ST:
                    state <= AXIS_READ_ACK_ST;

                AXIS_READ_ACK_ST:
                    if (ar_exec_ack_i) state <= END_ST;

                AXIS_WRITE_ST:
                    state <= AXIS_WRITE_ACK_ST;

                AXIS_WRITE_ACK_ST:
                    if (aw_exec_ack_i) state <= END_ST;

                END_ST:
                    if (!start_reg) state <= INIT_ST;

                default: state <= INIT_ST;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // FSM: combinational outputs
    //--------------------------------------------------------------------------
    always_comb begin
        busy_o    = 1'b0;
        ar_exec_o = 1'b0;
        aw_exec_o = 1'b0;
        sel_o     = 2'd0;

        unique case (state)
            INIT_ST: ; // sel=0, all deasserted

            AXIS_READ_ST: begin
                busy_o = 1'b1;
                sel_o  = 2'd1;
            end

            AXIS_READ_ACK_ST: begin
                busy_o    = 1'b1;
                ar_exec_o = 1'b1;
                sel_o     = 2'd1;
            end

            AXIS_WRITE_ST: begin
                busy_o = 1'b1;
                sel_o  = 2'd2;
            end

            AXIS_WRITE_ACK_ST: begin
                busy_o    = 1'b1;
                aw_exec_o = 1'b1;
                sel_o     = 2'd2;
            end

            END_ST: ; // all deasserted, sel=0

            default: ;
        endcase
    end

endmodule
