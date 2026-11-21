///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : avg
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    avg.sv
//!
//! @brief   Fixed-point accumulator and photon edge counter for the QICK
//!
//! @details
//!
//! pipeline.
//!
//! Two operating modes selected by photon_mode_reg:
//! 0 - Accumulation mode: stores the sum of I and Q samples over len_reg
//! samples into memory at address addr_reg.
//! 1 - Photon edge counter mode: counts rising edges on the I channel
//! using hysteresis thresholds h_thrsh_reg (high) and l_thrsh_reg (low).
//! Only samples inside the window are looked at. An edge on the first
//! sample is not counted (the signal may already have been high before the
//! window), and an edge on the last sample is (counted in QOUT_ST). Same
//! rules as the legacy edge-counting fix (from QICK-DAWG).
//!
//! Capture is initiated by an external trigger after start_reg is asserted.
//! start_reg must remain high through the entire capture cycle.
//! After WRITE_MEM_ST the FSM holds in WAIT_TRIGGER_ST until trigger_i
//! de-asserts, then returns to TRIGGER_ST ready for the next capture.
//! Asserting start_reg=0 at any point after TRIGGER_ST aborts back to START_ST.
//!
//! Timing at 512 MHz (111/tpv2_std, ADC x2 clock): trigger_i, din_valid_i and
//! din_i are registered once on entry (trigger_i with them, so the first
//! accumulated sample is the one that coincides with the trigger as before),
//! and mem_we_o, mem_addr_o and mem_di_o are registers, not a decode of the
//! state and start_reg. The write reaches the memory two clocks later than in
//! 1.0.0 and the data are the same. `cnt > 1` is the registered flag
//! cnt_gt1: the 32-bit compare drove the enable of the 64 photon flops.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module avg #(
  //! memory address width (depth = 2**N)
  parameter int N = 10,
  //! sample data width in bits
  parameter int B = 16
) (
  input  logic              rstn,
  input  logic              clk,

  // Trigger input
  input  logic              trigger_i,

  // Data input stream
  input  logic              din_valid_i,
  input  logic [2*B-1:0]   din_i,

  // Memory interface
  output logic              mem_we_o,
  output logic [N-1:0]      mem_addr_o,
  output logic [4*B-1:0]    mem_di_o,

  // Configuration registers (must be held stable while start_reg=1)
  input  logic              start_reg,
  input  logic [N-1:0]      addr_reg,
  input  logic [31:0]       len_reg,
  input  logic              photon_mode_reg,
  input  logic [B-1:0]      h_thrsh_reg,
  input  logic [B-1:0]      l_thrsh_reg
);

  // -------------------------------------------------------------------------
  // FSM state encoding
  // -------------------------------------------------------------------------
  typedef enum logic [2:0] {
    INIT_ST         = 3'd0,
    START_ST        = 3'd1,
    TRIGGER_ST      = 3'd2,
    AVG_ST          = 3'd3,
    QOUT_ST         = 3'd4,
    WRITE_MEM_ST    = 3'd5,
    WAIT_TRIGGER_ST = 3'd6
  } state_t;

  (* fsm_encoding = "one_hot" *) state_t state;

  // -------------------------------------------------------------------------
  // FSM output decode signals
  // -------------------------------------------------------------------------
  logic start_state;
  logic trigger_state;
  logic avg_state;
  logic qout_state;
  logic write_mem_state;

  // -------------------------------------------------------------------------
  // Internal registers
  // -------------------------------------------------------------------------
  logic [31:0]           cnt;
  logic [N-1:0]          addr_r;
  logic [31:0]           len_r;
  logic                  photon_mode_r;
  logic signed [B-1:0]   h_thrsh_r;
  logic signed [B-1:0]   l_thrsh_r;

  // Accumulators
  logic signed [2*B-1:0] acc_i;
  logic signed [2*B-1:0] acc_q;
  logic        [4*B-1:0] acc_photon;

  // Photon edge detection
  logic                  high_state;
  logic                  high_state_reg;

  // Input channel splits
  logic signed [B-1:0]   din_ii;
  logic signed [B-1:0]   din_qq;

  // -------------------------------------------------------------------------
  // Input stage: the FIR and the trigger sit far from the accumulators
  // -------------------------------------------------------------------------
  logic                  trigger_r;
  logic                  din_valid_r;
  logic [2*B-1:0]        din_r;
  logic                  cnt_ge1;   // cnt >= 1
  logic                  cnt_gt1;   // cnt >  1

  assign din_ii = din_r[B-1:0];
  assign din_qq = din_r[2*B-1:B];

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      trigger_r   <= 1'b0;
      din_valid_r <= 1'b0;
    end else begin
      trigger_r   <= trigger_i;
      din_valid_r <= din_valid_i;
    end
  end

  always_ff @(posedge clk) din_r <= din_i;

  // -------------------------------------------------------------------------
  // FSM + datapath sequential block
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state          <= INIT_ST;
      cnt            <= '0;
      cnt_ge1        <= 1'b0;
      cnt_gt1        <= 1'b0;
      addr_r         <= '0;
      len_r          <= '0;
      photon_mode_r  <= 1'b0;
      h_thrsh_r      <= '0;
      l_thrsh_r      <= '0;
      high_state     <= 1'b0;
      high_state_reg <= 1'b0;
      acc_i          <= '0;
      acc_q          <= '0;
      acc_photon     <= '0;
    end else begin

      // -----------------------------------------------------------------
      // FSM next-state logic
      // -----------------------------------------------------------------
      unique case (state)
        INIT_ST: begin
          state <= START_ST;
        end

        START_ST: begin
          if (start_reg) state <= TRIGGER_ST;
        end

        TRIGGER_ST: begin
          if (!start_reg)      state <= START_ST;
          else if (trigger_r)  state <= AVG_ST;
        end

        // Transition when the LAST valid sample has been processed.
        // cnt is incremented in the same cycle as the valid sample,
        // so after len_r samples cnt == len_r.
        AVG_ST: begin
          if (!start_reg) begin
            state <= START_ST;   // abort capture if start_reg de-asserts
          end else if (din_valid_r && cnt == len_r) begin
            state <= QOUT_ST;
          end
        end

        QOUT_ST: begin
          if (!start_reg) state <= START_ST;
          else state <= WRITE_MEM_ST;
        end

        WRITE_MEM_ST: begin
          if (!start_reg) state <= START_ST;
          else state <= WAIT_TRIGGER_ST;
        end

        WAIT_TRIGGER_ST: begin
          if (!start_reg)   state <= START_ST;
          else if (!trigger_r) state <= TRIGGER_ST;
        end

        default: begin
          state <= INIT_ST;
        end
      endcase

      // -----------------------------------------------------------------
      // Sample counter
      // Reset in START_ST and TRIGGER_ST (preparing for new capture).
      // Increment on each valid sample in AVG_ST.
      // -----------------------------------------------------------------
      if (start_state || trigger_state) begin
        cnt     <= '0;
        cnt_ge1 <= 1'b0;
        cnt_gt1 <= 1'b0;
      end else if (avg_state) begin
        if (!start_reg) begin
          cnt     <= '0;
          cnt_ge1 <= 1'b0;
          cnt_gt1 <= 1'b0;
        end else if (din_valid_r) begin
          cnt     <= cnt + 1;
          cnt_ge1 <= 1'b1;
          cnt_gt1 <= cnt_ge1;
        end
      end

      // -----------------------------------------------------------------
      // Config register latch (START_ST); address auto-increment
      // -----------------------------------------------------------------
      if (start_state) begin
        addr_r        <= addr_reg;
        len_r         <= (len_reg == '0) ? 32'd1 : len_reg - 1;
        photon_mode_r <= photon_mode_reg;
        h_thrsh_r     <= signed'(h_thrsh_reg);
        l_thrsh_r     <= signed'(l_thrsh_reg);
      end else if (write_mem_state) begin
        addr_r <= addr_r + 1;
      end

      // -----------------------------------------------------------------
      // Accumulator reset (TRIGGER_ST, or abort in AVG_ST), accumulate
      // and edge detection (valid samples in AVG_ST).
      // high_state follows the I channel with hysteresis; high_state_reg
      // is its value one valid sample earlier, so a rising edge
      // (high_state=1, high_state_reg=0) is seen one sample after the
      // crossing.
      // -----------------------------------------------------------------
      if (trigger_state || (avg_state && !start_reg)) begin
        acc_i          <= '0;
        acc_q          <= '0;
        acc_photon     <= '0;
        high_state     <= 1'b0;
        high_state_reg <= 1'b0;
      end else begin
        if (avg_state && din_valid_r) begin
          acc_i <= acc_i + {{B{din_ii[B-1]}}, din_ii};
          acc_q <= acc_q + {{B{din_qq[B-1]}}, din_qq};

          if (din_ii > h_thrsh_r)      high_state <= 1'b1;
          else if (din_ii < l_thrsh_r) high_state <= 1'b0;
          high_state_reg <= high_state;
        end

        // Rising-edge counter. cnt > 1 skips an edge on the first sample
        // (it may have started before the window); qout_state counts an
        // edge on the last sample.
        if ((avg_state && din_valid_r && cnt_gt1) || qout_state) begin
          if (high_state && !high_state_reg)
            acc_photon <= acc_photon + 1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // FSM output decode (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    start_state     = 1'b0;
    trigger_state   = 1'b0;
    avg_state       = 1'b0;
    qout_state      = 1'b0;
    write_mem_state = 1'b0;

    unique case (state)
      START_ST:     start_state     = 1'b1;
      TRIGGER_ST:   trigger_state   = 1'b1;
      AVG_ST:       avg_state       = 1'b1;
      QOUT_ST:      qout_state      = 1'b1;
      WRITE_MEM_ST: write_mem_state = 1'b1;
      default:      ; // INIT_ST, WAIT_TRIGGER_ST: no outputs
    endcase
  end

  // -------------------------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------------------------
  // Registered: the write strobe of WRITE_MEM_ST, qualified with start_reg
  // (not aborted), and the address and data of that cycle. Accumulators are
  // final in WRITE_MEM_ST (the last edge is counted in QOUT_ST).
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) mem_we_o <= 1'b0;
    else       mem_we_o <= write_mem_state && start_reg;
  end

  always_ff @(posedge clk) begin
    mem_addr_o <= addr_r;
    mem_di_o   <= photon_mode_r ? acc_photon : {acc_q, acc_i};
  end

endmodule
