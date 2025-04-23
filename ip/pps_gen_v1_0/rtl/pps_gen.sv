module pps_gen (
  // System signals
  input  logic        i_clk,
  input  logic        i_rst,

  // PPS signals
  input  logic        i_pps,          // GPS PPS input
  input  logic        i_en,        // PPS enable 0 -> GPS, 1 -> False PPS
  output logic        o_pps,          // PPS output
  output logic [26:0] o_clk_cnt_pps,  // Clock counter for PPS
  output logic        o_false_pps_led // False PPS LED indicator
);

  // Constants
  localparam CLK_FREQ = 125000000; // 125 MHz clock frequency

  // PPS related signals
  logic [26:0] one_sec_cnt;      // Clock counter for one second
  logic [26:0] clk_cnt_pps;      // Clock counter between PPS pulses
  logic        pps;              // Internal PPS signal
  logic        false_pps = 1'b0; // False PPS signal

  // State machine for PPS edge detection
  typedef enum logic [1:0] {ZERO, EDGE, ONE} pps_st_t;
  pps_st_t pps_st_reg, pps_st_next;
  logic    one_clk_pps; // Single clock cycle PPS pulse

  // PPS MUX
  assign pps = (i_en == 1'b1) ? false_pps : i_pps;

  // False PPS LED indicator
  assign o_false_pps_led = (i_en == 1'b1) ? false_pps : 1'b0;

  // PPS output and clock counter output
  assign o_pps = one_clk_pps;
  assign o_clk_cnt_pps = clk_cnt_pps;

  // False PPS generation and clock counter
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      one_sec_cnt <= 27'b0;
      clk_cnt_pps <= 27'b0;
    end else begin
      // Clock counter for one second
      if (one_sec_cnt == CLK_FREQ - 1) begin
        one_sec_cnt <= 27'b0;
      end else begin
        one_sec_cnt <= one_sec_cnt + 1;
      end

      // False PPS is high for 200 ms
      if (one_sec_cnt < CLK_FREQ / 5) begin
        false_pps <= 1'b1;
      end else begin
        false_pps <= 1'b0;
      end

      // Clock counter between PPS pulses
      if (one_clk_pps) begin
        clk_cnt_pps <= 27'b0;
      end else begin
        clk_cnt_pps <= clk_cnt_pps + 1;
      end
    end
  end

  // State register for PPS edge detection
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      pps_st_reg <= ZERO;
    end else begin
      pps_st_reg <= pps_st_next;
    end
  end

  // Next-state and output logic for PPS edge detection
  always_comb begin
    pps_st_next = pps_st_reg;
    one_clk_pps = 1'b0;

    case (pps_st_reg)
      ZERO: begin
        if (pps == 1'b1) begin
          pps_st_next = EDGE;
        end
      end
      EDGE: begin
        one_clk_pps = 1'b1;
        if (pps == 1'b1) begin
          pps_st_next = ONE;
        end else begin
          pps_st_next = ZERO;
        end
      end
      ONE: begin
        if (pps == 1'b0) begin
          pps_st_next = ZERO;
        end
      end
    endcase
  end

endmodule
