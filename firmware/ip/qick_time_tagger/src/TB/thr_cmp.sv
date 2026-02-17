module thr_cmp # (
   parameter CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter SMP_DW       = 16 , //Sample  Data width
   parameter SMP_CK       = 8    // Samples per Clock
) (
   input  wire                      clk_i             ,
   input  wire                      rst_ni            ,
   input  wire                      en_i              ,
   input  wire                      cfg_filter_i      ,
   input  wire [2:0]                cfg_inter_i       ,
   input  wire                      cfg_slope_i       ,
   input  wire [28:0]               time_ck_i         ,
   input  wire [SMP_DW-1:0]         th_i              ,
   input  wire [SMP_CK*SMP_DW-1:0]  dt_i              ,
   output wire [28:0]               trig_time_ck_o    ,
   output wire [2:0]                trig_time_adc_o   ,
   output wire [6:0]                trig_time_int_o   ,
   output wire                      trig_inter_end_o  ,
   output wire                      trig_vld_o        );

reg  [15:0]  adc_smp       [SMP_CK-1:0];
reg  [15:0]  adc_prev_smp  [SMP_CK-1:0];
reg  [15:0]  adc_2prev_smp [SMP_CK-1:0];
reg  [15:0]  ftr_smp       [SMP_CK-1:0];
reg  [15:0]  ftr_prev_smp  [SMP_CK-1:0];
reg  [15:0]  cmp_smp       [SMP_CK-1:0];
reg  [15:0]  cmp_prev_smp  [SMP_CK-1:0];
reg [15:0] cmp_rslt       [SMP_CK-1:0];

wire [SMP_CK-1:0] cmp_s    ;
wire [2:0] enc_s, enc_m1;   
wire [15:0] triggered_sample;

reg  [SMP_DW-1:0]  adc_prev_smp_0, adc_2prev_smp_0;
reg  [15:0] adc_smp_r [SMP_CK-1:0] ;
reg  [15:0] adc_smp_2r [SMP_CK-1:0];
reg adc_prev_smp_r, adc_prev_smp_2r;

reg [28:0] time_ck_r, time_ck_2r;
wire [28:0] time_ck_s;

wire [ 2:0] time_adc_s;
wire [ 6:0] time_inter_s;

reg [28:0] trig_time_ck_r;
reg [2:0] trig_time_adc_r;
reg [CMP_INTER-1:0] trig_time_inter_r;

wire[CMP_INTER-1:0] thr_inter_smp;
wire x_inter_end;

// TYPE
///////////////////////////////////////////////////////////////////////////////

// Store las Sample of current, for prev next.
always_ff @(posedge clk_i) begin
   if    ( !rst_ni   )  begin
      adc_prev_smp_0    <= 0;
      adc_2prev_smp_0   <= 0;
      adc_prev_smp_r    <= 0;
      adc_smp_r         <= '{default:'0};
      adc_prev_smp_2r   <= 0;
      adc_smp_2r        <= '{default:'0};
      time_ck_r         <= 0;
      time_ck_2r        <= 0;
   end else begin
      adc_prev_smp_0    <= adc_smp[SMP_CK-1];
      adc_2prev_smp_0   <= adc_smp[SMP_CK-2];
      adc_prev_smp_r    <= adc_prev_smp_0[SMP_CK-1];
      adc_smp_r         <= adc_smp;
      adc_prev_smp_2r   <= adc_prev_smp_r;
      adc_smp_2r        <= adc_smp_r;
      time_ck_r         <= time_ck_i;
      time_ck_2r        <= time_ck_r;
   end
end

genvar i;
generate
   for (i=0; i<SMP_CK; i++) begin: SMP
      // Input Samples
      always_comb begin
                     adc_smp[i]   = dt_i[SMP_DW*i+:SMP_DW];
         if (i==0)   adc_prev_smp[i] = adc_prev_smp_0;
         else        adc_prev_smp[i] = adc_smp[i-1];
         if (i==0)   adc_2prev_smp[i] = adc_2prev_smp_0;
         else        adc_2prev_smp[i] = adc_prev_smp[i-1];
      end   
      // Filtered Input Samples
      if (CMP_SLOPE ==1 )  begin: SLOPE
         always_ff @(posedge clk_i) begin
         //always_comb begin
            if   (cfg_filter_i)  ftr_smp[i]  <= adc_smp[i] + adc_prev_smp[i];
            else                 ftr_smp[i]  <= {adc_smp[i], 1'b0};
            if   (cfg_filter_i)  ftr_prev_smp[i]  <= adc_prev_smp[i] + adc_2prev_smp[i];
            else                 ftr_prev_smp[i]  <= {adc_prev_smp[i], 1'b0};
         end
      end else begin
         always_ff @(posedge clk_i) begin : NO_SLOPE
         //always_comb begin
            ftr_smp[i]       <= {adc_smp[i], 1'b0};
            ftr_prev_smp[i]  <= {adc_prev_smp[i], 1'b0};
         end
      end

      // Threshold Comparison 
      always_comb begin
         cmp_smp[i]      = ftr_smp[i];
         if   (cfg_slope_i)   cmp_prev_smp[i] = ftr_prev_smp[i];
         else                 cmp_prev_smp[i] = 0;
      end
      always_ff @(posedge clk_i)  cmp_rslt[i] = cmp_smp[i] - cmp_prev_smp[i] - th_i ;
      assign cmp_s[i] = ~cmp_rslt[i][15] ;
   end
endgenerate

assign enc_zero    = ~|enc_s ;
assign enc_m1      = enc_s-1 ;

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
   
assign time_ck_s    = (cfg_inter_i &  enc_zero) ? time_ck_2r    : time_ck_r;
assign time_adc_s   =  cfg_inter_i              ? enc_m1        : enc_s    ;
assign time_inter_s =  cfg_inter_i              ? thr_inter_smp : 0        ;

//assign triggered_sample = time_vld_o ? adc_smp_2r[time_adc_o] : 0;
assign trigger_cmp = en_i & trigger_cmp_s ;

priority_encoder  # (
   .DW  (3)
) p_enc (
   .clk_i         ( clk_i     ) ,
   .rst_ni        ( rst_ni    ) ,
   .one_hot_dt_i  ( cmp_s     ) ,
   .bin_dt_o      ( enc_s  ) ,
   .vld_o         ( trigger_cmp_s ) );

generate
   if (CMP_INTER > 0 )  begin: INTER
      x_inter #(
         .DW  ( SMP_DW ) ,
         .IW  ( CMP_INTER )
      ) x_inter (
         .clk_i      ( clk_i                 ) ,
         .rst_ni     ( rst_ni                ) ,
         .start_i    ( trigger_cmp           ) ,
         .cfg_inter_i( cfg_inter_i           ) ,
         .thr_i      ( th_i ) ,
         .curr_i     ( ftr_smp[enc_s]        ) ,
         .prev_i     ( ftr_prev_smp[enc_s]   ) ,
         .end_o      ( x_inter_end           ) ,
         .ready_o    (  ) ,
         .x_int_o    ( thr_inter_smp         ) );
      end else begin
         assign x_inter_end   = trigger_cmp;
         assign thr_inter_smp = 7'b0;
      end
endgenerate
localparam zfp = 6-CMP_INTER;
assign  trig_inter_end_o = x_inter_end;
assign  trig_time_ck_o   = trig_time_ck_r; 
assign  trig_time_adc_o  = trig_time_adc_r; 
assign  trig_time_int_o  = {{ zfp {1'b0}}, trig_time_inter_r}; 
assign  trig_vld_o       = trigger_cmp_s; 

endmodule
