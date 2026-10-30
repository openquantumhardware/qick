///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dmem_single_rw
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dmem_single_rw.sv
//!
//! @brief   Performs a single synchronous read or write to the data memory.
//!
//! @details
//!
//!
//! Controlled by an exec/exec_ack handshake:
//!
//!
//! - Caller asserts exec_i with rw_i, addr_i, din_i valid.
//! - Module completes the operation and asserts exec_ack_o.
//! - Caller deasserts exec_i to return to idle.
//!
//! rw_i = 0 : read  (INIT → READ0 → READ1 → ACK)
//! rw_i = 1 : write (INIT → WRITE → ACK)
//!
//! The data memory (e.g. bram_tdp) has a SYNCHRONOUS, registered read:
//! the output 'bram.dout' is valid ONE clock after 'bram.en' + 'bram.addr'
//! are presented. To accommodate this latency the read uses two pipeline
//! cycles:
//!
//!
//! - READ0 : assert bram.en and present bram.addr (start the read)
//! - READ1 : bram.dout is now valid -> capture it into dout_r
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dmem_single_rw #(
    //! address width  (must match bram_if NB_ADDR)
    parameter int N = 10,
    //! data width     (must match bram_if NB_DATA)
    parameter int B = 16
)(
    input  logic        clk,
    input  logic        rstn,

    // Operation select
    input  logic        rw_i,      // 0 = read, 1 = write

    // Exec handshake
    input  logic        exec_i,
    output logic        exec_ack_o,

    // Address and data
    input  logic [N-1:0] addr_i,
    input  logic [B-1:0] din_i,
    output logic [B-1:0] do_o,

    // BRAM interface (master)
    bram_if.master      bram
);

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        INIT_ST  = 3'd0,
        READ0_ST = 3'd1,
        READ1_ST = 3'd2,
        WRITE_ST = 3'd3,
        ACK_ST   = 3'd4
    } state_t;

    state_t state;

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------
    logic        init_state;
    logic        re_en;     // BRAM read enable: present addr+en (READ0 & READ1)
    logic        re_cap;    // capture bram.dout into dout_r (READ1 only)
    logic        we_int;    // BRAM write enable (WRITE)
    logic        ack_int;   // exec_ack assertion (ACK)

    logic [N-1:0] addr_r;
    logic [B-1:0] din_r;
    logic [B-1:0] dout_r;

    //--------------------------------------------------------------------------
    // FSM: sequential
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state  <= INIT_ST;
            addr_r <= '0;
            din_r  <= '0;
            dout_r <= '0;
        end else begin
            unique case (state)
                INIT_ST: begin
                    if (exec_i) begin
                        if (!rw_i) state <= READ0_ST;
                        else       state <= WRITE_ST;
                    end
                end
                READ0_ST: state <= READ1_ST;
                READ1_ST: state <= ACK_ST;
                WRITE_ST: state <= ACK_ST;
                ACK_ST:
                    if (!exec_i) state <= INIT_ST;
                default: state <= INIT_ST;
            endcase

            // Latch address and data in INIT while exec not yet asserted
            if (init_state) begin
                addr_r <= addr_i;
                din_r  <= din_i;
            end

            // Capture BRAM read output.
            // The synchronous BRAM registers its output one cycle after
            // en+addr are presented (in READ0), so the data is valid here
            // in READ1 -> capture it now.
            if (re_cap)
                dout_r <= bram.dout;
        end
    end

    //--------------------------------------------------------------------------
    // FSM: combinational outputs
    //--------------------------------------------------------------------------
    always_comb begin
        init_state = 1'b0;
        re_en      = 1'b0;
        re_cap     = 1'b0;
        we_int     = 1'b0;
        ack_int    = 1'b0;

        unique case (state)
            INIT_ST:  init_state = 1'b1;
            // Present address + enable to start the synchronous read.
            READ0_ST: re_en      = 1'b1;
            // Keep enable/address asserted and capture the now-valid dout.
            READ1_ST: begin
                re_en  = 1'b1;
                re_cap = 1'b1;
            end
            WRITE_ST: we_int     = 1'b1;
            ACK_ST:   ack_int    = 1'b1;
            default:  ;
        endcase
    end

    //--------------------------------------------------------------------------
    // BRAM interface drive
    //--------------------------------------------------------------------------
    assign bram.en    = re_en | we_int;          // enabled in READ0, READ1, WRITE
    assign bram.we    = we_int;
    assign bram.we_be = we_int ? '1 : '0;
    assign bram.addr  = addr_r;
    assign bram.din   = din_r;

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------
    assign exec_ack_o = ack_int;
    assign do_o       = dout_r;

endmodule

