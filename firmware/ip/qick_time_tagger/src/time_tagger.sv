///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR : Basic Time Tagger for axi Stream  
/* Description: 
    
*/
//////////////////////////////////////////////////////////////////////////////

module time_tagger # (
   parameter CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter SMP_DW       = 16 , //Sample  Data width
   parameter SMP_CK       = 8    // Samples per Clock
)(
   input  wire                      clk_i       ,
   input  wire                      rst_ni      ,
   input  wire                      cfg_filter_i      ,
   input  wire                      cfg_slope_i      ,
   input  wire [2:0]                cfg_inter_i      ,
   input  wire                      arm_i       , // Arm Trigger (ONE works)
   input  wire [SMP_DW-1:0]         cmp_th_i    , // Threhold Data
   input  wire [7:0]                cmp_inh_i   , // Inhibit Clock Pulses
   input  wire [SMP_CK*SMP_DW-1:0]  adc_dt      ,
   output wire                      rdy_o       ,
   output wire                      trig_o      ,
   output wire [28:0]               trig_time_ck_o ,
   output wire [2:0]                trig_time_adc_o ,
   output wire [4:0]                trig_time_int_o   );



// Control State Machine
//////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_ARMED, ST_TRIGGER, ST_INTER, ST_INHIBIT } TYPE_TRIG_ST;
(* fsm_encoding = "one_hot" *) TYPE_TRIG_ST time_trig_st;
TYPE_TRIG_ST time_trig_st_nxt;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if    ( !rst_ni   )  time_trig_st  <= ST_IDLE;
   else                 time_trig_st  <= time_trig_st_nxt;
end
reg trig_wr, inhibit, working, cmp_en;

always_comb begin
   time_trig_st_nxt  = time_trig_st;
   trig_wr           = 1'b0;
   inhibit           = 1'b0;
   working           = 1'b1;
   cmp_en            = 1'b0;
   case (time_trig_st)
      ST_IDLE: begin
         working           = 1'b0;
         if (arm_i) time_trig_st_nxt = ST_ARMED;
      end
      ST_ARMED: begin
         cmp_en            = 1'b1;
         if      (!arm_i)
            time_trig_st_nxt = ST_IDLE;
         else if (trig_event) begin 
            if (|cfg_inter_i )    
               time_trig_st_nxt = ST_INTER;
            else 
               time_trig_st_nxt = ST_TRIGGER;
         end
      end
      ST_INTER: begin
         inhibit           = 1'b1;
         if      (trig_inter_end)  time_trig_st_nxt = ST_TRIGGER; // IF INHIBIT IS SHORTER, TAKES MORE TIME
      end
      ST_TRIGGER: begin
         trig_wr          = 1'b1;
         if (inhibit_zero)    time_trig_st_nxt = ST_ARMED;
         else                 time_trig_st_nxt = ST_INHIBIT;
      end
      ST_INHIBIT : begin
         inhibit           = 1'b1;
         if (inhibit_end) time_trig_st_nxt = ST_ARMED;
      end
   endcase
end

// Time Counter 
//////////////////////////////////////////////////////////////////////////
reg [31:0] time_cnt;
always_ff @(posedge clk_i) begin
   if    (!rst_ni) time_cnt <= 0;
   else
      if (working) time_cnt <= time_cnt + 1'b1;
      else         time_cnt <= 0;
end

// Inhibit Counter 
//////////////////////////////////////////////////////////////////////////
reg [7:0] inhibit_cnt, inhibit_cnt_p1 ;
assign inhibit_cnt_p1 = inhibit_cnt + 1'b1;

always_ff @(posedge clk_i) begin
   if    (!rst_ni) inhibit_cnt <= 0;
   else
      if (inhibit) inhibit_cnt <= inhibit_cnt_p1;
      else         inhibit_cnt <= 0;
end

assign inhibit_end  = ( inhibit_cnt_p1 == cmp_inh_i ) ;
assign inhibit_zero = ~|cmp_inh_i;

wire [31:0] time_ck_s;
wire [2:0] time_adc_s;
wire [6:0] time_int_s;

 
thr_cmp  #( 
   .CMP_SLOPE  ( CMP_SLOPE ) ,
   .CMP_INTER  ( CMP_INTER ) ,
   .SMP_DW     (16) ,
   .SMP_CK     (8) 
) CMP (
   .clk_i         ( clk_i ) ,
   .rst_ni        ( rst_ni ) ,
   .en_i          ( cmp_en ) ,
   .cfg_filter_i  ( cfg_filter_i ) ,
   .cfg_slope_i   ( cfg_slope_i ) ,
   .cfg_inter_i   ( cfg_inter_i ), 
   .time_ck_i     ( time_cnt ),
   .th_i          ( cmp_th_i ) ,
   .dt_i          ( adc_dt ) ,
   .trig_inter_end_o ( trig_inter_end ) ,
   .trig_time_ck_o   ( time_ck_s) ,
   .trig_time_adc_o  ( time_adc_s) ,
   .trig_time_int_o  ( time_int_s) ,
   .trig_vld_o       ( trig_event ) );

// Register 
//////////////////////////////////////////////////////////////////////////

assign rdy_o         = 1'b1;
assign trig_o        = trig_wr;
assign trig_time_ck_o = time_ck_s;
assign trig_time_adc_o   = time_adc_s;
assign trig_time_int_o = time_int_s;



endmodule



