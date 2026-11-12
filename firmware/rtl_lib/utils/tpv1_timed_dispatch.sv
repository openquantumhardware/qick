///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv1_timed_dispatch
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv1_timed_dispatch.sv
//!
//! @brief     Timed-instruction dispatcher control for the QICK tProcV1 processor.
//!
//! @details
//!
//! Reads 216-bit instruction words from a FIFO, waits until the embedded
//! 48-bit timestamp (t_inst) is reached by the master clock counter (t_cnt),
//! then dispatches the instruction via AXI-Stream or a wait handshake.
//!
//! Instruction word layout (216 bits):
//! [31:0]    p0  - parameter 0
//! [63:32]   p1  - parameter 1
//! [95:64]   p2  - parameter 2
//! [127:96]  p3  - parameter 3
//! [159:128] p4  - parameter 4
//! [207:160] t   - 48-bit dispatch timestamp
//! [215:208] op  - 8-bit opcode
//!
//! Recognized opcodes:
//! 0x15 (waiti) / 0x54 (wait) -> WAIT_ACK_ST : assert waitt, wait for ack
//! 0x13 (seti)                 -> SETI_ST     : tvalid, tdata={128'b0,p0}
//! 0x1A (setbi)                -> SETBI_ST    : tvalid, tdata={128'b0,p0}, wait tready
//! 0x51 (set)                  -> SET_ST      : tvalid, tdata={p4,p3,p2,p1,p0}
//! 0x58 (setb)                 -> SETB_ST     : tvalid, tdata={p4,p3,p2,p1,p0}, wait tready
//! other                       -> READ_ST     : silently consume, read next word
//!
//! FSM state transitions:
//! READ_ST     --(~fifo_empty)--------------------------> WAIT_ST
//! WAIT_ST     --(t_inst<=t_cnt, opcode dispatch)-------> WAIT_ACK_ST|SETI_ST|SETBI_ST|SET_ST|SETB_ST|READ_ST
//! WAIT_ACK_ST --(waitt_ack)----------------------------> READ_ST
//! SETI_ST                  --(single cycle)------------> READ_ST
//! SET_ST                   --(single cycle)------------> READ_ST
//! SETBI_ST    --(m_axis_tready)------------------------> READ_ST
//! SETB_ST     --(m_axis_tready)------------------------> READ_ST
//!
//! Naming note:
//! 'timed_ictrl' is preserved for consistency with existing QICK repository
//! references. An alternative descriptive name is 'tpv1_timed_dispatch'.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module tpv1_timed_dispatch (
    // Clock and reset
    input  logic        clk,
    input  logic        rstn,
    // Master clock counter
    input  logic [47:0] t_cnt,
    // FIFO interface
    output logic        fifo_rd_en,
    input  logic [215:0] fifo_dout,
    input  logic        fifo_empty,
    // Wait handshake
    output logic        waitt,
    input  logic        waitt_ack,
    // AXI-Stream master output
    output logic [159:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready
);

    //--------------------------------------------------------------------------
    // FSM State Encoding
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        READ_ST     = 3'd0,
        WAIT_ST     = 3'd1,
        WAIT_ACK_ST = 3'd2,
        SETI_ST     = 3'd3,
        SETBI_ST    = 3'd4,
        SET_ST      = 3'd5,
        SETB_ST     = 3'd6
    } fsm_t;

    fsm_t state;

    //--------------------------------------------------------------------------
    // Opcode Constants
    //--------------------------------------------------------------------------
    localparam logic [7:0] OP_WAITI = 8'h15;
    localparam logic [7:0] OP_WAIT  = 8'h54;
    localparam logic [7:0] OP_SETI  = 8'h13;
    localparam logic [7:0] OP_SETBI = 8'h1A;
    localparam logic [7:0] OP_SET   = 8'h51;
    localparam logic [7:0] OP_SETB  = 8'h58;

    //--------------------------------------------------------------------------
    // Instruction Latch & Field Extraction (combinational from latch)
    //--------------------------------------------------------------------------
    logic [215:0] inst_reg;
    logic [31:0]  p0_i, p1_i, p2_i, p3_i, p4_i;
    logic [47:0]  t_inst;
    logic [7:0]   opcode_i;

    assign p0_i     = inst_reg[31:0];
    assign p1_i     = inst_reg[63:32];
    assign p2_i     = inst_reg[95:64];
    assign p3_i     = inst_reg[127:96];
    assign p4_i     = inst_reg[159:128];
    assign t_inst   = inst_reg[207:160];
    assign opcode_i = inst_reg[215:208];

    //--------------------------------------------------------------------------
    // Internal Output Signals
    //--------------------------------------------------------------------------
    logic rd_en_i;
    logic tvalid_i;
    logic waitt_i;
    logic src_i;    // 0: 32-bit payload ({128'b0, p0}), 1: 160-bit payload

    //--------------------------------------------------------------------------
    // FSM: Sequential State Register
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state    <= READ_ST;
            inst_reg <= '0;
        end else begin
            unique case (state)
                READ_ST: begin
                    if (!fifo_empty) begin
                        inst_reg <= fifo_dout; // Latch the instruction
                        state    <= WAIT_ST;
                    end
                end

                WAIT_ST: begin
                    if (t_inst <= t_cnt) begin
                        unique case (opcode_i)
                            OP_WAITI,
                            OP_WAIT  : state <= WAIT_ACK_ST;
                            OP_SETI  : state <= SETI_ST;
                            OP_SETBI : state <= SETBI_ST;
                            OP_SET   : state <= SET_ST;
                            OP_SETB  : state <= SETB_ST;
                            default  : state <= READ_ST;
                        endcase
                    end
                end

                WAIT_ACK_ST: begin
                    if (waitt_ack)
                        state <= READ_ST;
                end

                SETI_ST: state <= READ_ST;

                SETBI_ST: begin
                    if (m_axis_tready)
                        state <= READ_ST;
                end

                SET_ST: state <= READ_ST;

                SETB_ST: begin
                    if (m_axis_tready)
                        state <= READ_ST;
                end

                default: state <= READ_ST;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // FSM: Combinational Output Logic
    //--------------------------------------------------------------------------
    always_comb begin
        rd_en_i  = 1'b0;
        tvalid_i = 1'b0;
        waitt_i  = 1'b0;
        src_i    = 1'b0;

        unique case (state)
            READ_ST:     rd_en_i  = 1'b1;
            WAIT_ST:     ; // no outputs
            WAIT_ACK_ST: waitt_i  = 1'b1;
            SETI_ST:     begin tvalid_i = 1'b1; src_i = 1'b0; end
            SETBI_ST:    begin tvalid_i = 1'b1; src_i = 1'b0; end
            SET_ST:      begin tvalid_i = 1'b1; src_i = 1'b1; end
            SETB_ST:     begin tvalid_i = 1'b1; src_i = 1'b1; end
            default:     ; // safe defaults already assigned above
        endcase
    end

    //--------------------------------------------------------------------------
    // Output Assignments
    //--------------------------------------------------------------------------
    assign fifo_rd_en    = rd_en_i;
    assign waitt         = waitt_i;
    assign m_axis_tvalid = tvalid_i;
    assign m_axis_tdata  = src_i ? {p4_i, p3_i, p2_i, p1_i, p0_i} : {128'b0, p0_i};

endmodule

