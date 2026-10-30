///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dmem_axis_reader
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dmem_axis_reader.sv
//!
//! @brief   Reads 'len_i' words from BRAM starting at 'addr_i' and streams them
//!
//! @details
//!
//!
//! out via AXI4-Stream. Controlled by exec/exec_ack handshake from dmem_ctrl.
//!
//! FSM:
//! INIT_ST  : wait for exec_i
//! LOAD0_ST : latch addr_i and len_i; present first address to BRAM
//! LOAD1_ST : wait one cycle for BRAM read latency; advance address
//! SEND_ST  : stream data — advance address on each tready; assert tlast
//! on last word; transition to ACK when last word accepted
//! ACK_ST   : assert exec_ack_o for one cycle
//! END_ST   : wait for exec_i to deassert before returning to INIT
//!
//! Backpressure: when tready is low, sel_r holds the last BRAM output in
//! data_r so the address does not advance and data is not lost.
//!
//! tlast is asserted when cnt == len_r-1 during SEND_ST.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dmem_axis_reader #(
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

    // Start address and length
    input  logic [N-1:0] addr_i,
    input  logic [N-1:0] len_i,

    // BRAM interface (master, read-only)
    bram_if.master      bram,

    // AXI4-Stream master output
    axi4_stream_if.master axis
);

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        INIT_ST  = 3'd0,
        LOAD0_ST = 3'd1,
        LOAD1_ST = 3'd2,
        SEND_ST  = 3'd3,
        ACK_ST   = 3'd4,
        END_ST   = 3'd5
    } state_t;

    state_t state;

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------
    logic        load0_state;
    logic        load1_state;
    logic        send_state;
    logic        ack_int;

    logic [N-1:0] addr_r;
    logic [N-1:0] len_r;
    logic [N-1:0] cnt;

    // Backpressure hold register
    logic        sel_r;    // 0 = output BRAM directly, 1 = output data_r
    logic [B-1:0] data_r;
    logic         data_en;

    //--------------------------------------------------------------------------
    // FSM: sequential
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state  <= INIT_ST;
            addr_r <= '0;
            len_r  <= '0;
            cnt    <= '0;
            sel_r  <= 1'b0;
            data_r <= '0;
        end else begin
            unique case (state)
                INIT_ST:
                    if (exec_i) state <= LOAD0_ST;

                LOAD0_ST:
                    state <= LOAD1_ST;

                LOAD1_ST:
                    state <= SEND_ST;

                SEND_ST:
                    if (cnt == len_r - 1 && axis.tready)
                        state <= ACK_ST;

                ACK_ST:
                    state <= END_ST;

                END_ST:
                    if (!exec_i) state <= INIT_ST;

                default: state <= INIT_ST;
            endcase

            // Address register: latch on LOAD0, advance on LOAD1 or accepted beat
            if (load0_state)
                addr_r <= addr_i;
            else if (load1_state || (send_state && axis.tready))
                addr_r <= addr_r + 1'b1;

            // Length latch
            if (load0_state)
                len_r <= len_i;

            // Beat counter
            if (load0_state)
                cnt <= '0;
            else if (send_state && axis.tready)
                cnt <= cnt + 1'b1;

            // Backpressure hold: when tready low in SEND, hold last value
            if (send_state && !axis.tready)
                sel_r <= 1'b1;
            else
                sel_r <= 1'b0;

            // Data hold register
            if (data_en)
                data_r <= bram.dout;
        end
    end

    //--------------------------------------------------------------------------
    // FSM: combinational outputs
    //--------------------------------------------------------------------------
    always_comb begin
        load0_state = 1'b0;
        load1_state = 1'b0;
        send_state  = 1'b0;
        ack_int     = 1'b0;

        unique case (state)
            LOAD0_ST: load0_state = 1'b1;
            LOAD1_ST: load1_state = 1'b1;
            SEND_ST:  send_state  = 1'b1;
            ACK_ST:   ack_int     = 1'b1;
            default:  ;
        endcase
    end

    //--------------------------------------------------------------------------
    // Data enable: update hold register when tready or no backpressure
    //--------------------------------------------------------------------------
    assign data_en = axis.tready | ~sel_r;

    //--------------------------------------------------------------------------
    // BRAM interface (read-only)
    //--------------------------------------------------------------------------
    assign bram.en    = 1'b1;
    assign bram.we    = 1'b0;
    assign bram.we_be = '0;
    assign bram.addr  = addr_r;
    assign bram.din   = '0;

    //--------------------------------------------------------------------------
    // AXI4-Stream outputs
    //--------------------------------------------------------------------------
    assign axis.tdata  = sel_r ? data_r : bram.dout;
    assign axis.tlast  = (cnt == len_r - 1) & send_state;
    assign axis.tvalid = send_state;

    //--------------------------------------------------------------------------
    // Exec handshake
    //--------------------------------------------------------------------------
    assign exec_ack_o = ack_int;

endmodule
