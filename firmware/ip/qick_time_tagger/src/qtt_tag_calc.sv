module qtt_tag_calc # (
   parameter CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter SMP_DW       = 16 , //Sample  Data width
   parameter SMP_CK       = 8    // Samples per Clock
) (
   input  wire                      clk_i          ,
   input  wire                      rst_ni         ,
   input  wire                      arm_i          ,
   input  wire                      cfg_invert_i   ,
   input  wire                      cfg_filter_i   ,
   input  wire [2:0]                cfg_inter_i    ,
   input  wire                      cfg_slope_i    ,
   input  wire [28:0]               time_ck_i      ,
   input  wire [SMP_DW-1:0]         cmp_th_i           ,
   input  wire [7:0]                cmp_inh_i            , // Inhibit Clock Pulses
   input  wire [SMP_CK*SMP_DW-1:0]  dt_i           ,
   output wire                      trig_o         ,
   output wire                      cmp_o          ,
   output wire                      tag_vld_o      ,
   output wire [31:0]               tag_dt_o       ,
   output wire [7:0]                debug_do
);

// Signal Declaration
///////////////////////////////////////////////////////////////////////////////
reg  signed [SMP_DW-1:0]  adc_smp       [SMP_CK-1:0] ;
reg  signed [SMP_DW-1:0]  adc_prev_smp  [SMP_CK-1:0];
reg  signed [SMP_DW-1:0]  adc_prev_smp_0 ;
reg  signed [SMP_DW-1:0]  adc_2prev_smp [SMP_CK-1:0];
reg  signed [SMP_DW-1:0]  adc_2prev_smp_0;
reg  signed [SMP_DW:0]  ftr_smp       [SMP_CK-1:0];
reg  signed [SMP_DW:0]  ftr_prev_smp  [SMP_CK-1:0];
reg  signed [SMP_DW:0]  cmp_smp       [SMP_CK-1:0];
reg  signed [SMP_DW:0]  cmp_prev_smp  [SMP_CK-1:0];

reg  [SMP_CK-1:0]    cmp_s ;
wire [ 2:0]          enc_s, enc_m1;   
reg  [28:0]          time_ck_r, time_ck_2r;
wire [28:0]          time_ck_s;
wire [ 2:0]          time_adc_s;
wire [ 6:0]          time_inter_s;
reg  [28:0]          trig_time_ck_r;
reg  [ 2:0]          trig_time_adc_r;
reg  [CMP_INTER-1:0] trig_time_inter_r;
wire [CMP_INTER-1:0] thr_inter_smp;
wire                 x_inter_end;

// Signed comparison values.
wire  signed [SMP_DW:0]  cmp_smp_s [SMP_CK-1:0];
wire  signed [SMP_DW:0]  cmp_thr_s ;
wire  [SMP_CK-1:0] cmp_flg ;
assign cmp_thr_s = {cmp_th_i, 1'b0};

// Control State Machine
//////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_ARMED, ST_INTER, ST_INHIBIT } TYPE_TRIG_ST;
(* fsm_encoding = "one_hot" *) TYPE_TRIG_ST trig_cal_st;
TYPE_TRIG_ST trig_calc_st_nxt;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if    ( !rst_ni   )  trig_cal_st  <= ST_IDLE;
   else                 trig_cal_st  <= trig_calc_st_nxt;
end

reg inhibit;
always_comb begin
   trig_calc_st_nxt  = trig_cal_st;
   inhibit           = 1'b1;
   case (trig_cal_st)
      ST_IDLE: begin
         if (arm_i) trig_calc_st_nxt = ST_ARMED;
      end
      ST_ARMED: begin
         inhibit           = 1'b0;
         if      (!arm_i)               trig_calc_st_nxt = ST_IDLE;
         else if (trigger_cmp_s) begin 
            if   (|cfg_inter_i )       trig_calc_st_nxt = ST_INTER;
            else                       trig_calc_st_nxt = ST_INHIBIT;
         end
      end
      ST_INTER: begin
         if (x_inter_end)  trig_calc_st_nxt = ST_INHIBIT; // IF INHIBIT IS SHORTER, TAKES MORE TIME
      end
      ST_INHIBIT : begin
         if (inhibit_end) trig_calc_st_nxt = ST_ARMED;
      end
   endcase
end

// Inhibit Counter 
//////////////////////////////////////////////////////////////////////////
reg [7:0] inhibit_cnt, inhibit_cnt_p1 ;
assign inhibit_cnt_p1 = inhibit_cnt + 1'b1;

always_ff @(posedge clk_i) begin
   if    (!rst_ni) inhibit_cnt <= 0;
   else
      if (arm_i & inhibit) inhibit_cnt <= inhibit_cnt_p1;
      else                 inhibit_cnt <= 0;
end

assign inhibit_end  = ( inhibit_cnt == cmp_inh_i ) ;

assign trigger_cmp = !inhibit & trigger_cmp_s ;





// Samples Processing
///////////////////////////////////////////////////////////////////////////////

// Store las Sample of current, for prev next.
always_ff @(posedge clk_i) begin
   if    ( !rst_ni   )  begin
      adc_prev_smp_0    <= 0;
      adc_2prev_smp_0   <= 0;
      time_ck_r         <= 0;
      time_ck_2r        <= 0;
   end else begin
      adc_prev_smp_0    <= adc_smp[SMP_CK-1];
      adc_2prev_smp_0   <= adc_smp[SMP_CK-2];
      time_ck_r         <= time_ck_i;
      time_ck_2r        <= time_ck_r;
   end
end


genvar i;
generate
   for (i=0; i<SMP_CK; i++) begin: SMP
      // Input Samples
      always_comb begin
//                     adc_smp[i]   = dt_i[SMP_DW*i+:SMP_DW];
         if   (cfg_invert_i)  adc_smp[i]  <= -dt_i[SMP_DW*i+:SMP_DW];
         else                 adc_smp[i]  <=  dt_i[SMP_DW*i+:SMP_DW];

         if (i==0)   adc_prev_smp[i] = adc_prev_smp_0;
         else        adc_prev_smp[i] = adc_smp[i-1];
         if (i==0)   adc_2prev_smp[i] = adc_2prev_smp_0;
         else        adc_2prev_smp[i] = adc_prev_smp[i-1];
      end   
      // Filter Input Samples
      always_ff @(posedge clk_i) begin 
         if   (cfg_filter_i)  ftr_smp[i]  <= adc_smp[i] + adc_prev_smp[i];
         else                 ftr_smp[i]  <= {adc_smp[i], 1'b0};
      end
      // FilterPrevious Input Samples
      if (CMP_SLOPE ==1 )  begin: SLOPE
         always_ff @(posedge clk_i) begin
            if   (cfg_filter_i)  ftr_prev_smp[i]  <= adc_prev_smp[i] + adc_2prev_smp[i];
            else                 ftr_prev_smp[i]  <= {adc_prev_smp[i], 1'b0};
         end
      end else begin 
         always_ff @(posedge clk_i) begin : NO_SLOPE 
            ftr_prev_smp[i] <= 0;
         end
      end

      // Threshold Comparison 
      always_comb begin
         cmp_smp[i]      = ftr_smp[i];
         if   (cfg_slope_i)   cmp_prev_smp[i] = ftr_prev_smp[i];
         else                 cmp_prev_smp[i] = 0;
      end
      assign cmp_smp_s[i] = cmp_smp[i] - cmp_prev_smp[i];
      assign cmp_flg[i]   = (cmp_smp_s[i] > cmp_thr_s);
      always_ff @(posedge clk_i)  cmp_s[i] = cmp_flg[i];
   end
endgenerate



// Time Tag 
///////////////////////////////////////////////////////////////////////////////

assign enc_zero    = ~|enc_s ;
assign enc_m1      = enc_s - 1'b1 ;
assign time_ck_s    = (cfg_inter_i &  enc_zero) ? time_ck_2r    : time_ck_r;
assign time_adc_s   =  cfg_inter_i              ? enc_m1        : enc_s    ;
assign time_inter_s =  cfg_inter_i              ? thr_inter_smp : 0        ;

always_ff @(posedge clk_i) begin
   if    ( !rst_ni   )  begin
      trig_time_ck_r        <= 0;
      trig_time_adc_r       <= 0;
      trig_time_inter_r     <= 0;
   end else begin
      if (trigger_cmp) begin
         trig_time_ck_r        <= time_ck_s;
         trig_time_adc_r       <= time_adc_s;
      end
      if (x_inter_end)       
         trig_time_inter_r     <= time_inter_s;
   end
end



// INSTANCES
///////////////////////////////////////////////////////////////////////////////
priority_encoder  # (
   .DW  ( 3 ) ,
   .OUT ("TNO_REG")
) ENCODER (
   .clk_i         ( clk_i         ) ,
   .rst_ni        ( rst_ni        ) ,
   .one_hot_dt_i  ( cmp_s         ) ,
   .bin_dt_o      ( enc_s         ) ,
   .vld_o         ( trigger_cmp_s )
);

generate
   if (CMP_INTER > 0 )  begin: INTER
      x_inter #(
         .DW  ( SMP_DW ) ,
         .IW  ( CMP_INTER )
      ) INTERPOLATOR (
         .clk_i      ( clk_i                 ) ,
         .rst_ni     ( rst_ni                ) ,
         .start_i    ( trigger_cmp           ) ,
         .cfg_inter_i( cfg_inter_i           ) ,
         .thr_i      ( cmp_th_i              ) ,
         .curr_i     ( ftr_smp[enc_s]        ) ,
         .prev_i     ( ftr_prev_smp[enc_s]   ) ,
         .end_o      ( x_inter_end           ) ,
         .ready_o    (                       ) ,
         .x_int_o    ( thr_inter_smp         ) );
      end else begin
         assign x_inter_end   = trigger_cmp;
         assign thr_inter_smp = 7'b0;
      end
endgenerate

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign debug_do   = 0;

// OUT
///////////////////////////////////////////////////////////////////////////////
wire[6:0] trig_time_inter_s;

localparam zfp = 6-CMP_INTER;
assign  trig_time_inter_s  = {{ zfp {1'b0}}, trig_time_inter_r}; 

assign tag_dt_o = ( cfg_inter_i ) == 3'b000 ?  { trig_time_ck_r[28:0], trig_time_adc_r }                         : // No Interpolation
                  ( cfg_inter_i ) == 3'b001 ?  { trig_time_ck_r[27:0], trig_time_adc_r, trig_time_inter_s[0] }   : // Interpolation of 1 bit
                  ( cfg_inter_i ) == 3'b010 ?  { trig_time_ck_r[26:0], trig_time_adc_r, trig_time_inter_s[1:0] } : // Interpolation of 2 bit
                  ( cfg_inter_i ) == 3'b011 ?  { trig_time_ck_r[25:0], trig_time_adc_r, trig_time_inter_s[2:0] } : // Interpolation of 3 bit
                  ( cfg_inter_i ) == 3'b100 ?  { trig_time_ck_r[24:0], trig_time_adc_r, trig_time_inter_s[3:0] } : // Interpolation of 4 bit
                  ( cfg_inter_i ) == 3'b101 ?  { trig_time_ck_r[23:0], trig_time_adc_r, trig_time_inter_s[4:0] } : // Interpolation of 5 bit
                  ( cfg_inter_i ) == 3'b110 ?  { trig_time_ck_r[22:0], trig_time_adc_r, trig_time_inter_s[5:0] } : // Interpolation of 6 bit
                                               { trig_time_ck_r[21:0], trig_time_adc_r, trig_time_inter_s[6:0] } ; // Interpolation of 7 bit
assign  tag_vld_o    = arm_i & x_inter_end;
assign  trig_o       = trigger_cmp; 
assign  cmp_o        = trigger_cmp_s; 

endmodule
