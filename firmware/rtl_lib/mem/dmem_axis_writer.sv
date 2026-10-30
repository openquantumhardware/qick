///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dmem_axis_writer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dmem_axis_writer.sv
//!
//! @brief   Receives an AXI4-Stream burst (delimited by tlast) and writes each beat
//!
//! @details
//!
//!
//! sequentially to BRAM starting at addr_i. Controlled by exec/exec_ack
//! handshake from dmem_ctrl.
//!
//! FSM:
//! INIT_ST  : wait for exec_i; latch addr_i as address counter
//! WRITE_ST : assert tready; write each valid beat to BRAM;
//! advance address on each accepted beat;
//! when tlast & tvalid → transition to ACK
//! ACK_ST   : assert exec_ack_o for one cycle
//! END_ST   : wait for exec_i to deassert before returning to INIT
//!
//! Pipeline: one register stage (data_r, addr_cnt_r, we_int_r) delays
//! the BRAM write by one cycle to match the address pipeline.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dmem_axis_writer #(
    //! address width (must match bram_if NB_ADDR)
    parameter int N = 10,
    //! data width    (must match bram_if NB_DATA and axis TDATA_WIDTH)
    parameter int B = 16
)(
    input  logic        clk,
    input  logic        rstn,

    // Exec handshake (from dmem_ctrl)
    input  logic        exec_i,
    output logic        exec_ack_o,

    // Start address
    input  logic [N-1:0] addr_i,

    // BRAM interface (master, write-only)
    bram_if.master      bram,

    // AXI4-Stream slave input
    axi4_stream_if.slave axis
);

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        INIT_ST  = 2'd0,
        WRITE_ST = 2'd1,
        ACK_ST   = 2'd2,
        END_ST   = 2'd3
    } state_t;

    state_t state;

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------
    logic        init_state;
    logic        write_state;
    logic        ack_int;

    // Address counter and pipeline register
    logic [N-1:0] addr_cnt;
    logic [N-1:0] addr_cnt_r;

    // Data pipeline register
    logic [B-1:0] data_r;

    // Write enable pipeline
    logic        we_int;
    logic        we_int_r;

    //--------------------------------------------------------------------------
    // FSM: sequential
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state      <= INIT_ST;
            addr_cnt   <= '0;
            addr_cnt_r <= '0;
            data_r     <= '0;
            we_int_r   <= 1'b0;
        end else begin
            unique case (state)
                INIT_ST:
                    if (exec_i) state <= WRITE_ST;

                WRITE_ST:
                    if (axis.tlast && axis.tvalid)
                        state <= ACK_ST;

                ACK_ST:
                    state <= END_ST;

                END_ST:
                    if (!exec_i) state <= INIT_ST;

                default: state <= INIT_ST;
            endcase

            // Address counter: latch start on INIT, advance on each valid beat
            if (init_state)
                addr_cnt <= addr_i;
            else if (axis.tvalid && axis.tready)
                addr_cnt <= addr_cnt + 1'b1;

            // Pipeline stage: register address, data and write enable
            addr_cnt_r <= addr_cnt;
            data_r     <= axis.tdata[B-1:0];
            we_int_r   <= we_int;
        end
    end

    //--------------------------------------------------------------------------
    // FSM: combinational outputs
    //--------------------------------------------------------------------------
    always_comb begin
        init_state  = 1'b0;
        write_state = 1'b0;
        ack_int     = 1'b0;

        unique case (state)
            INIT_ST:  init_state  = 1'b1;
            WRITE_ST: write_state = 1'b1;
            ACK_ST:   ack_int     = 1'b1;
            default:  ;
        endcase
    end

    //--------------------------------------------------------------------------
    // Write enable: combinational gating with write_state and tvalid
    //--------------------------------------------------------------------------
    assign we_int = axis.tvalid & axis.tready;

    //--------------------------------------------------------------------------
    // AXI4-Stream slave: assert tready during write state
    //--------------------------------------------------------------------------
    assign axis.tready = write_state;

    //--------------------------------------------------------------------------
    // BRAM interface (write-only, pipelined by one cycle)
    //--------------------------------------------------------------------------
    assign bram.en    = we_int_r;
    assign bram.we    = we_int_r;
    assign bram.we_be = we_int_r ? '1 : '0;
    assign bram.addr  = addr_cnt_r;
    assign bram.din   = data_r;

    //--------------------------------------------------------------------------
    // Exec handshake
    //--------------------------------------------------------------------------
    assign exec_ack_o = ack_int;

endmodule
