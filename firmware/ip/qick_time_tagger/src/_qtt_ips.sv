///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5_31
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
/// Clock Domain Register Change
///////////////////////////////////////////////////////////////////////////////
/*
sync_reg # (
   .DW (  )
) sync_tx_i (
   .dt_i      (  ) ,
   .clk_i     (  ) ,
   .rst_ni    (  ) ,
   .dt_o      (  ) );
*/

module sync_reg # (
   parameter DW  = 32
)(
   input  wire [DW-1:0] dt_i     , 
   input  wire          clk_i  ,
   input  wire          rst_ni  ,
   output wire [DW-1:0] dt_o     );
   
(* ASYNC_REG = "TRUE" *) reg [DW-1:0] data_rcd, data_r ;
always_ff @(posedge clk_i)
   if(!rst_ni) begin
      data_rcd  <= 0;
      data_r    <= 0;
   end else begin 
      data_rcd  <= dt_i;
      data_r    <= data_rcd;
      end
assign dt_o = data_r ;

endmodule

///////////////////////////////////////////////////////////////////////////////
/// Priority Encoder 
///////////////////////////////////////////////////////////////////////////////
module priority_encoder # (
   parameter DW       = 5 ,
   parameter OUT      = "NO_REG"
)(
   input   wire                clk_i          ,
   input   wire                rst_ni         ,
   input   wire [2**DW-1:0]    one_hot_dt_i   , 
   output  reg [DW-1:0]       bin_dt_o       , 
   output  reg               vld_o          );

localparam ONE_HOT_DW =    2**DW;

integer i ;
reg valid;
reg [DW-1 : 0] bin_dt ;

always_comb begin
  valid = 1'b0;
  bin_dt = 0;
  for (i = 0 ; i < ONE_HOT_DW; i=i+1)
    if (!valid & one_hot_dt_i[i]) begin
      valid  = 1'b1;
      bin_dt = i;
   end
end

generate
   if (OUT == "NO_REG") begin: no_output_register // 1 clock cycle read
      assign vld_o     = valid ;
      assign bin_dt_o  = bin_dt ;
   end else begin: output_register // 2 clock cycle read
      reg          vld_r    = {DW{1'b0}};
      reg [DW-1:0] bin_dt_r = {DW{1'b0}};
      always @(posedge clk_i) vld_r    <= valid;
      always @(posedge clk_i) bin_dt_r <= bin_dt;
      assign vld_o    = vld_r ;
      assign bin_dt_o = bin_dt_r ;
   end
endgenerate

endmodule


///////////////////////////////////////////////////////////////////////////////
/// Sincronice Chain of Pulses 
///////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
/*
sync_pulse # (
   .QUEUE_AW ( ) 
   .BLOCK    ( ) 
) sync_p_i ( 
   .a_clk_i    (  ) ,
   .a_rst_ni   (  ) ,
   .a_pulse_i  (  ) ,
   .b_clk_i    (  ) ,
   .b_rst_ni   (  ) ,
   .b_pulse_o  (  ) ,
   .pulse_full (  ) );
*/
module sync_pulse # (
   parameter QUEUE_AW = 4 ,
   parameter BLOCK   = 0 
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
   if (BLOCK) begin
      // BLOCK IF QUEUE FULL
      reg [QUEUE_AW-1:0] rd_gptr_rcd, rd_gptr_r; 
      always_ff @(posedge a_clk_i) begin
         rd_gptr_rcd      <= rd_gptr;
         rd_gptr_r        <= rd_gptr_rcd;
      end
      assign pulse_full    = (rd_gptr_r == wr_gptr_p1) ;
   end else begin
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
   .DW	( QUEUE_AW )
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
   .DW	( QUEUE_AW )
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

/*
pulse_cdc pulse_cdc_inst (
   .clk_a_i   (  ) ,
   .rst_a_ni  (  ) ,
   .pulse_a_i (  ) ,
   .rdy_a_o   (  ) ,
   .clk_b_i   (  ) ,
   .rst_b_ni  (  ) ,
   .pulse_b_o (  ) );
*/
module pulse_cdc (
   input  wire clk_a_i     ,
   input  wire rst_a_ni    ,
   input  wire pulse_a_i   ,
   output wire rdy_a_o     ,
   input  wire clk_b_i     ,
   input  wire rst_b_ni    ,
   output wire pulse_b_o   );

/// REQ
///////////////////////////////////////////////////////////////////////////////
reg a_pulse_req;
always_ff @ (posedge clk_a_i, negedge rst_a_ni) begin
   if ( !rst_a_ni  ) begin
      a_pulse_req   <= 1'b0;
   end else
      if      ( pulse_a_i   ) a_pulse_req <= 1'b1; 
      else if ( a_pulse_ack ) a_pulse_req <= 1'b0; 
end

(* ASYNC_REG = "TRUE" *) reg pulse_req_cdc, b_pulse_req ;
reg pulse_b_req_r, pulse_b;
always_ff @(posedge clk_b_i, negedge rst_b_ni)
   if(!rst_b_ni) begin
      pulse_req_cdc   <= 0;
      b_pulse_req     <= 0;
      pulse_b_req_r   <= 0;
      pulse_b         <= 0;
   end else begin 
      pulse_req_cdc  <= a_pulse_req;
      b_pulse_req    <= pulse_req_cdc;
      pulse_b_req_r  <= b_pulse_req;
      pulse_b        <= b_pulse_req & !pulse_b_req_r;
   end

/// ACK
///////////////////////////////////////////////////////////////////////////////
reg b_pulse_ack;
always_ff @ (posedge clk_a_i, negedge rst_a_ni) begin
   if ( !rst_a_ni  ) begin
      b_pulse_ack   <= 1'b0;
   end else
      if      (  b_pulse_req ) b_pulse_ack <= 1'b1; 
      else if ( !b_pulse_req ) b_pulse_ack <= 1'b0; 
end

(* ASYNC_REG = "TRUE" *) reg pulse_ack_cdc, a_pulse_ack ;
always_ff @(posedge clk_a_i, negedge rst_a_ni)
   if(!rst_a_ni) begin
      pulse_ack_cdc  <= 0;
      a_pulse_ack         <= 0;
   end else begin 
      pulse_ack_cdc  <= b_pulse_ack;
      a_pulse_ack    <= pulse_ack_cdc;
   end

assign pulse_b_o = pulse_b;
assign rdy_a_o   = !(a_pulse_req | a_pulse_ack);

endmodule


///////////////////////////////////////////////////////////////////////////////
// X-Interpolator
///////////////////////////////////////////////////////////////////////////////
module x_inter #(
   parameter DW = 16 ,
   parameter IW = 4
) (
   input  wire             clk_i   ,
   input  wire             rst_ni  ,
   input  wire             start_i ,
   input  wire [2:0]       cfg_inter_i      ,
   input  wire [DW-1:0]    curr_i  ,
   input  wire [DW-1:0]    prev_i  ,
   input  wire [DW-1:0]    thr_i   ,
   output wire             end_o   ,
   output wire             ready_o ,
   output wire [IW-1:0]    x_int_o );

// Registers
reg [IW+DW-1:0] sub_temp, r_temp, r_temp_nxt;
reg [DW-1:0]   inB        ;
reg [IW-1:0]   q_temp;
reg [2:0]      ind_bit; 
reg            working, qtb;

wire [2:0]     ind_bit_m1 ;

assign ind_bit_m1 = ind_bit - 1'b1;
assign div_start  = start_i;
assign div_end    = (ind_bit==0) ;


// State Machine
///////////////////////////////////////////////////////////////////////////
enum {IDLE, WORKING} div_st, div_st_nxt;
always_ff @(posedge clk_i)
   if (!rst_ni)     div_st  <= IDLE;
   else             div_st  <= div_st_nxt;

always_comb begin
   div_st_nxt  = div_st;
   working     = 1'b0;
   case (div_st)
      IDLE: begin
         if ( div_start )    div_st_nxt = WORKING;
      end
      WORKING: begin
         working = 1'b1;
         if ( div_end ) begin
            div_st_nxt = IDLE;
         end
      end
   endcase
end

always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin        
      ind_bit     <= -1;
      q_temp      <= 0 ;
      r_temp      <= 0 ;
      inB         <= 0 ;
   end else if (div_start) begin
      ind_bit     <= cfg_inter_i;
      q_temp      <= 0 ;
      r_temp      <= ( (thr_i - prev_i)  << cfg_inter_i);
      inB         <= ( curr_i - prev_i );
   end else if (working) begin
      ind_bit            <= ind_bit_m1;
      r_temp             <= r_temp_nxt   ;
      q_temp[ind_bit_m1] <= qtb   ;
  end
end

///////////////////////////////////////////////////////////////////////////
always_comb begin
   qtb         = 1'b0;
   r_temp_nxt  = r_temp ;
   sub_temp    = inB << ind_bit_m1  ;
   if (r_temp >= sub_temp ) begin
      qtb        = 1'b1 ;
      r_temp_nxt = r_temp  - sub_temp ;
   end else
      r_temp_nxt = r_temp;
end

/*
// In case wnat to use a DSP 
wire [IW+DW-1:0] d_sub_a;
reg [IW+DW-1:0] r_temp_nxt_dsp, sub_temp_dsp;
ADDSUB_MACRO #(
      .DEVICE  ("7SERIES"), // Target Device: "7SERIES" 
      .LATENCY (0),        // Desired clock cycle latency, 0-2
      .WIDTH   (IW+DW)          // Input / output bus width, 1-48
   ) ADDSUB_MACRO_inst (
      .CARRYOUT   ( ), // 1-bit carry-out output signal
      .RESULT     ( d_sub_a   ),// Add/sub result output, width defined by WIDTH parameter
      .A          ( r_temp    ),// Input A bus, width defined by WIDTH parameter
      .ADD_SUB    ( 1'b0      ),// 1-bit add/sub input, high selects add, low selects subtract
      .B          ( sub_temp_dsp  ),// Input B bus, width defined by WIDTH parameter
      .CARRYIN    ( 1'b0      ),// 1-bit carry-in input
      .CE         ( 1'b1      ),// 1-bit clock enable input
      .CLK        ( clk_i     ),// 1-bit clock input
      .RST        ( ~rst_ni)    // 1-bit active high synchronous reset
);

always_comb begin
   qtb         = 1'b0;
   sub_temp_dsp    = inB << ind_bit_m1  ;
   if (d_sub_a[IW+DW-1] == r_temp[IW+DW-1]) begin  // (r_temp >= sub_temp ) begin
      qtb        = 1'b1 ;
      r_temp_nxt_dsp = d_sub_a ;
   end else
      r_temp_nxt_dsp = r_temp;
end
*/

///////////////////////////////////////////////////////////////////////////
// OUT REG
//always_ff @ (posedge clk_i) begin
//   if      (!rst_ni) x_int_o  <= 0;
//   else if (div_end) x_int_o  <= q_temp;
//end

assign x_int_o = q_temp;
assign ready_o = ~working;
assign end_o   = div_end;



endmodule

