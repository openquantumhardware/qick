///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Sincronice Chain of Pulses
//  Faithful port from qick_time_tagger's _qtt_ips.sv (module sync_pulse).
//  CDC for a stream of single-cycle pulses on clock A, delivered one at a
//  time as single-cycle pulses on clock B, using a pair of gray-code
//  counters (gcc) as the pointer queue. BLOCK=1 makes a_pulse_i backpressure
//  (drop) when the queue is full instead of silently overrunning it.
///////////////////////////////////////////////////////////////////////////////

module sync_pulse # (
   parameter int QUEUE_AW = 4 ,
   parameter bit BLOCK    = 0
) (
   input  wire                   a_clk_i    ,
   input  wire                   a_rst_ni   ,
   input  wire                   a_pulse_i  ,
   input  wire                   b_clk_i    ,
   input  wire                   b_rst_ni   ,
   input  wire                   b_en_i     ,
   output reg                    b_pulse_o  ,
   output wire                   pulse_full );

wire [QUEUE_AW-1:0] wr_gptr_p1, rd_gptr_p1 ;
wire [QUEUE_AW-1:0] wr_gptr, rd_gptr  ;
wire                 pulse_empty ;

// Pulse Counters
reg [QUEUE_AW-1:0] wr_gptr_cdc, wr_gptr_r;
always_ff @(posedge b_clk_i) begin
   wr_gptr_cdc      <= wr_gptr;
   wr_gptr_r        <= wr_gptr_cdc;
end

//Check for Out Pulses
assign pulse_empty   = (rd_gptr   == wr_gptr_r) ;


///// DEBUG
generate
   if (BLOCK) begin: gen_block
      // BLOCK IF QUEUE FULL
      reg [QUEUE_AW-1:0] rd_gptr_rcd, rd_gptr_r;
      always_ff @(posedge a_clk_i) begin
         rd_gptr_rcd      <= rd_gptr;
         rd_gptr_r        <= rd_gptr_rcd;
      end
      assign pulse_full    = (rd_gptr_r == wr_gptr_p1) ;
   end else begin: gen_no_block
      assign pulse_full    = 1'b0;
   end
endgenerate

always @(posedge b_clk_i) begin
   if      ( !b_rst_ni    ) b_pulse_o <= 1'b0;
   else if ( b_pulse_o    ) b_pulse_o <= 1'b0;
   else if ( !pulse_empty & b_en_i) b_pulse_o <= 1'b1;
end

//Gray Code Counters
gcc #(
   .DW   ( QUEUE_AW )
) gcc_wr_ptr  (
   .clk_i            ( a_clk_i     ) ,
   .rst_ni           ( a_rst_ni    ) ,
   .async_clear_i    ( 1'b0 ) ,
   .clear_o          (      ) ,
   .cnt_en_i         ( a_pulse_i & ~pulse_full ) ,
   .count_bin_o      (      ) ,
   .count_gray_o     ( wr_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( wr_gptr_p1   ) );

gcc #(
   .DW   ( QUEUE_AW )
) gcc_rd_ptr (
   .clk_i            ( b_clk_i     ) ,
   .rst_ni           ( b_rst_ni    ) ,
   .async_clear_i    ( 1'b0 ) ,
   .clear_o          (      ) ,
   .cnt_en_i         ( b_pulse_o       ) ,
   .count_bin_o      (        ) ,
   .count_gray_o     ( rd_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( rd_gptr_p1   ) );

endmodule
