///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    buffer.sv
//!
//! @brief   Raw-sample capture FSM for the QICK axis_avg_buffer pipeline.
//!
//! @details
//!
//! Captures len_reg consecutive I/Q samples verbatim into memory starting
//! at addr_reg -- the sibling of `avg` (which accumulates/counts instead
//! of storing samples verbatim).
//!
//! Capture is initiated by an external trigger after start_reg is asserted.
//! start_reg must remain high through the entire capture cycle.
//! After MEMW_ST the FSM holds in WAIT_TRIGGER_ST until trigger_i
//! de-asserts, then returns to TRIGGER_ST ready for the next capture.
//! Asserting start_reg=0 at any point after TRIGGER_ST aborts back to
//! START_ST (matches `avg`'s abort behavior; the legacy FSM had no abort
//! path out of MEMW_ST).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////

module buffer #(
  //! memory address width (depth = 2**N)
  parameter int N = 10,
  //! sample data width in bits
  parameter int B = 16
) (
  input  logic            rstn,
  input  logic            clk,

  // Trigger input
  input  logic            trigger_i,

  // Data input stream
  input  logic            din_valid_i,
  input  logic [2*B-1:0]  din_i,

  // Memory interface
  output logic            mem_we_o,
  output logic [N-1:0]    mem_addr_o,
  output logic [2*B-1:0]  mem_di_o,

  // Configuration registers (must be held stable while start_reg=1)
  input  logic            start_reg,
  input  logic [N-1:0]    addr_reg,
  input  logic [N-1:0]    len_reg
);

  // -------------------------------------------------------------------------
  // FSM state encoding
  // -------------------------------------------------------------------------
  typedef enum logic [2:0] {
    INIT_ST         = 3'd0,
    START_ST        = 3'd1,
    TRIGGER_ST      = 3'd2,
    MEMW_ST         = 3'd3,
    WAIT_TRIGGER_ST = 3'd4
  } state_t;

  (* fsm_encoding = "one_hot" *) state_t state;

  // -------------------------------------------------------------------------
  // FSM output decode signals
  // -------------------------------------------------------------------------
  logic start_state;
  logic trigger_state;
  logic memw_state;

  // -------------------------------------------------------------------------
  // Internal registers
  // -------------------------------------------------------------------------
  logic [N-1:0] cnt;
  logic [N-1:0] addr_r;
  logic [N-1:0] len_r;

  // -------------------------------------------------------------------------
  // FSM + datapath sequential block
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state  <= INIT_ST;
      cnt    <= '0;
      addr_r <= '0;
      len_r  <= '0;
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
          if (!start_reg)     state <= START_ST;
          else if (trigger_i) state <= MEMW_ST;
        end

        // Transition when the LAST valid sample has been written.
        // cnt is incremented in the same cycle as the valid sample,
        // so after len_r samples cnt == len_r.
        MEMW_ST: begin
          if (!start_reg) begin
            state <= START_ST;   // abort capture if start_reg de-asserts
          end else if (din_valid_i && cnt == len_r) begin
            state <= WAIT_TRIGGER_ST;
          end
        end

        WAIT_TRIGGER_ST: begin
          if (!start_reg)       state <= START_ST;
          else if (!trigger_i)  state <= TRIGGER_ST;
        end

        default: begin
          state <= INIT_ST;
        end
      endcase

      // -----------------------------------------------------------------
      // Sample counter
      // Reset in START_ST and TRIGGER_ST (preparing for new capture).
      // Increment on each valid sample in MEMW_ST.
      // -----------------------------------------------------------------
      if (start_state || trigger_state) begin
        cnt <= '0;
      end else if (memw_state) begin
        if (!start_reg) begin
          cnt <= '0;
        end else if (din_valid_i) begin
          cnt <= cnt + 1;
        end
      end

      // -----------------------------------------------------------------
      // Config register latch (START_ST); address auto-increment
      // -----------------------------------------------------------------
      if (start_state) begin
        addr_r <= addr_reg;
        len_r  <= (len_reg == '0) ? 1 : len_reg - 1;
      end else if (memw_state && din_valid_i) begin
        addr_r <= addr_r + 1;
      end
    end
  end

  // -------------------------------------------------------------------------
  // FSM output decode (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    start_state   = 1'b0;
    trigger_state = 1'b0;
    memw_state    = 1'b0;

    unique case (state)
      START_ST:   start_state   = 1'b1;
      TRIGGER_ST: trigger_state = 1'b1;
      MEMW_ST:    memw_state    = 1'b1;
      default:    ; // INIT_ST, WAIT_TRIGGER_ST: no outputs
    endcase
  end

  // -------------------------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------------------------
  assign mem_we_o   = memw_state && din_valid_i && start_reg; // only write when start_reg is still high (not aborted)
  assign mem_addr_o = addr_r;
  assign mem_di_o   = din_i;

endmodule
