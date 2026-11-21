`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_switch
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_switch.sv
//!
//! @brief   Reorders the PFB readouts' FIR outputs into the order the FFT
//!          expects, frame by frame.
//!
//! @details
//! Faithful port of the legacy pfb_switch + pfb_reorder + pfb_swap (openquantumhardware/qick
//! firmware/ip/axis_pfb_readout_v4/src/pfb/, identical in v3), merged into
//! one module; the two legacy VHDL FIFOs are qick:mem:fifo (the port of the
//! same fifo.vhd). With 2L words of B bits per clock:
//!
//! - Reorder: the even words (FIRs 0, 2, ...) go to the low half and the odd
//!   ones to the high half, through 4 registers. Every other clock the output
//!   is {low half of word n-2, low half of word n-3} or {high half of word
//!   n-3, high half of word n-4}; the alternation restarts on the clock after
//!   a delayed tlast. tlast is delayed 3 clocks; tvalid is constant 1.
//! - Swap: two FIFOs (N/L deep) take the reordered words alternately. After
//!   reset both are drained; on a tlast the block starts writing, and after a
//!   first frame (NP = N/(2L) clocks ending in tlast) it reads them back
//!   alternately in groups of NP/2 words, one frame behind. A tlast missing
//!   at the end of a frame sends it back to draining and re-syncing. tlast is
//!   the input's delayed one clock; tvalid is constant 1.
//! - Synchronous, active-low reset of the swap state machine and FIFOs; the
//!   reorder registers have none.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_switch #(
    parameter int B = 32,   //! Word width (one I/Q FIR output)
    parameter int L = 4,    //! Input lanes; 2L words per clock
    parameter int N = 64    //! PFB channels
) (
    input  logic               aresetn,
    input  logic               aclk,

    // verilog_lint: waive-start unused
    input  logic               s_axis_tvalid,   //! Not used (continuous stream)
    // verilog_lint: waive-stop unused
    input  logic               s_axis_tlast,
    input  logic [2*L*B-1:0]   s_axis_tdata,

    output logic               m_axis_tvalid,
    output logic               m_axis_tlast,
    output logic [2*L*B-1:0]   m_axis_tdata
);

    localparam int W       = 2 * L * B;
    localparam int NP      = N / (2 * L);
    localparam int NP_LOG2 = $clog2(NP);

    // ------------------------------------------------------------------
    // Reorder
    // ------------------------------------------------------------------
    logic [W-1:0] din_sort;
    logic [W-1:0] data_r1 = '0, data_r2 = '0, data_r3 = '0, data_r4 = '0;
    logic         last_r1 = 1'b0, last_r2 = 1'b0, last_r3 = 1'b0;
    logic         sel = 1'b0;
    logic [W-1:0] ro_data;

    for (genvar i = 0; i < L; i++) begin : g_sort
        assign din_sort[i*B       +: B] = s_axis_tdata[2*i*B     +: B];
        assign din_sort[L*B + i*B +: B] = s_axis_tdata[(2*i+1)*B +: B];
    end

    always_ff @(posedge aclk) begin
        data_r1 <= din_sort;
        data_r2 <= data_r1;
        data_r3 <= data_r2;
        data_r4 <= data_r3;
        last_r1 <= s_axis_tlast;
        last_r2 <= last_r1;
        last_r3 <= last_r2;
        sel     <= last_r3 ? 1'b0 : ~sel;
    end

    assign ro_data = sel ? {data_r3[L*B +: L*B], data_r4[L*B +: L*B]}
                         : {data_r2[0   +: L*B], data_r3[0   +: L*B]};

    // ------------------------------------------------------------------
    // Swap
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {RST_ST, SYNC_ST, RW0_ST, RW1_ST} state_t;
    state_t               state;
    logic                 rst_state, wr_en, rw1_state;
    logic                 wr_sel, rd_sel, rd_sel_r, tlast_r;
    logic [NP_LOG2-1:0]   cnt;
    logic [NP_LOG2-2:0]   cnt_sel;
    logic [W-1:0]         fifo0_dout, fifo1_dout;
    logic                 fifo0_empty, fifo1_empty;

    assign rst_state = (state == RST_ST);
    assign wr_en     = (state == RW0_ST) || (state == RW1_ST);
    assign rw1_state = (state == RW1_ST);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state    <= RST_ST;
            cnt      <= '0;
            wr_sel   <= 1'b0;
            rd_sel   <= 1'b0;
            rd_sel_r <= 1'b0;
            tlast_r  <= 1'b0;
        end else begin
            case (state)
                RST_ST:  if (fifo0_empty && fifo1_empty)  state <= SYNC_ST;
                SYNC_ST: if (last_r3)                     state <= RW0_ST;
                RW0_ST:  if (&cnt && last_r3)             state <= RW1_ST;
                RW1_ST:  if (&cnt && !last_r3)            state <= RST_ST;
                default:                                  state <= RST_ST;
            endcase
            // cnt_sel is not reset (as in the legacy block): it clears on
            // the first clock without wr_en, which follows every reset.
            cnt      <= wr_en ? cnt + 1'b1     : '0;
            cnt_sel  <= wr_en ? cnt_sel + 1'b1 : '0;
            wr_sel   <= wr_en ? ~wr_sel : 1'b0;
            if (rw1_state) begin
                if (&cnt_sel) rd_sel <= ~rd_sel;
            end else begin
                rd_sel <= 1'b0;
            end
            rd_sel_r <= rd_sel;
            tlast_r  <= last_r3;
        end
    end

    fifo #(.B(W), .N(N / L)) u_fifo0 (
        .rstn  (aresetn),
        .clk   (aclk),
        .wr_en (wr_en && !wr_sel),
        .din   (ro_data),
        .rd_en (rst_state || (rw1_state && !rd_sel)),
        .dout  (fifo0_dout),
        .full  (),
        .empty (fifo0_empty)
    );

    fifo #(.B(W), .N(N / L)) u_fifo1 (
        .rstn  (aresetn),
        .clk   (aclk),
        .wr_en (wr_en && wr_sel),
        .din   (ro_data),
        .rd_en (rst_state || (rw1_state && rd_sel)),
        .dout  (fifo1_dout),
        .full  (),
        .empty (fifo1_empty)
    );

    assign m_axis_tvalid = 1'b1;
    assign m_axis_tlast  = tlast_r;
    assign m_axis_tdata  = rd_sel_r ? fifo1_dout : fifo0_dout;

endmodule
