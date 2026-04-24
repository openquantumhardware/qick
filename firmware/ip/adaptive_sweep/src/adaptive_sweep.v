`timescale 1ns / 1ps

module adaptive_sweep #(
  parameter [31:0] FREQ_0 = 32'd54613333,   // 100 MHz
  parameter [31:0] FREQ_1 = 32'd27306667,   //  50 MHz
  parameter [31:0] FREQ_2 = 32'd109226667,  // 200 MHz
  parameter [31:0] FREQ_3 = 32'd81920000    // 150 MHz
)(
  input  wire clk,
  input  wire rst_n,

  // QICK Peripheral
  input  wire        qtag_en_i,
  input  wire [4:0]  qtag_op_i,
  input  wire [31:0] qtag_dt1_i,
  input  wire [31:0] qtag_dt2_i,
  input  wire [31:0] qtag_dt3_i,
  input  wire [31:0] qtag_dt4_i,
  output reg         qtag_rdy_o,
  output reg  [31:0] qtag_dt1_o,
  output reg  [31:0] qtag_dt2_o,
  output reg         qtag_vld_o
);
  reg en_d;
  wire en_rise;

  assign en_rise = qtag_en_i & ~en_d;

  always @(posedge clk) begin
    if (!rst_n)
      en_d <= 1'b0;
    else
      en_d <= qtag_en_i;
  end

  // Main logic
  always @(posedge clk) begin
    if (!rst_n) begin
      qtag_rdy_o  <= 1'b1;
      qtag_vld_o  <= 1'b0;
      qtag_dt1_o  <= 32'd0;
      qtag_dt2_o  <= 32'd0;
    end else begin
      qtag_vld_o <= 1'b0;

      if (en_rise) begin
        case (qtag_op_i)
          5'd0: begin
            qtag_dt1_o  <= FREQ_0;     
            qtag_dt2_o  <= 32'd100;    
            qtag_vld_o  <= 1'b1;
          end
          5'd1: begin
            qtag_dt1_o  <= FREQ_1;    
            qtag_dt2_o  <= 32'd50;
            qtag_vld_o  <= 1'b1;
          end
          5'd2: begin
            qtag_dt1_o  <= FREQ_2;    
            qtag_dt2_o  <= 32'd200;
            qtag_vld_o  <= 1'b1;
          end
          5'd3: begin
            qtag_dt1_o  <= FREQ_3;   
            qtag_dt2_o  <= 32'd150;
            qtag_vld_o  <= 1'b1;
          end
          default: begin
          end
        endcase
      end
    end
  end

endmodule