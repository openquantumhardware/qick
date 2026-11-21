///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  qtt_tag_calc
//  Faithful port from qick_time_tagger's qtt_tag_calc.sv.
//  Per-ADC-channel threshold comparator + timestamp tagger: filters the
//  incoming SMP_CK samples/clock, compares (optionally slope-compensated)
//  against a threshold, encodes which of the SMP_CK samples crossed first
//  (priority_encoder), and optionally refines the crossing time with a
//  sub-sample interpolation (x_inter).
///////////////////////////////////////////////////////////////////////////////

module qtt_tag_calc # (
   parameter int CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter int CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter int SMP_DW       = 16 , //Sample  Data width
   parameter int SMP_CK       = 8    // Samples per Clock
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
reg  signed [SMP_DW-1:0]  adc_smp       [SMP_CK] ;
reg  signed [SMP_DW-1:0]  adc_prev_smp  [SMP_CK];
reg  signed [SMP_DW-1:0]  adc_prev_smp_0 ;
reg  signed [SMP_DW-1:0]  adc_2prev_smp [SMP_CK];
reg  signed [SMP_DW-1:0]  adc_2prev_smp_0;
reg  signed [SMP_DW:0]  ftr_smp       [SMP_CK];
reg  signed [SMP_DW:0]  ftr_prev_smp  [SMP_CK];
reg  signed [SMP_DW:0]  cmp_smp       [SMP_CK];
reg  signed [SMP_DW:0]  cmp_prev_smp  [SMP_CK];

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
wire                 enc_zero;
wire                 trigger_cmp_s, trigger_cmp;
wire                 inhibit_end;

// Signed comparison values.
wire  signed [SMP_DW:0]  cmp_smp_s [SMP_CK];
wire  signed [SMP_DW:0]  cmp_thr_s ;
wire  [SMP_CK-1:0] cmp_flg ;
assign cmp_thr_s = {cmp_th_i, 1'b0};

// Control State Machine
//////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_ARMED, ST_INTER, ST_INHIBIT } trig_cal_st_e;
(* fsm_encoding = "one_hot" *) trig_cal_st_e trig_cal_st;
trig_cal_st_e trig_calc_st_nxt;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if    ( !rst_ni   )  trig_cal_st  <= ST_IDLE;
   else                 trig_cal_st  <= trig_calc_st_nxt;
end

reg inhibit;
always_comb begin
   trig_calc_st_nxt  = trig_cal_st;
   inhibit           = 1'b1;
   unique case (trig_cal_st)
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
reg  [7:0] inhibit_cnt;
wire [7:0] inhibit_cnt_p1;
assign inhibit_cnt_p1 = inhibit_cnt + 1'b1;

always_ff @(posedge clk_i) begin
   if    (!rst_ni) inhibit_cnt <= 0;
   else
      if (arm_i & inhibit) inhibit_cnt <= inhibit_cnt_p1;
      else                 inhibit_cnt <= 0;
end

// >= and not ==: the counter runs while the interpolator works too (ST_INTER), and the interpolator now starts two clocks
// later (pipelined operands, see "Interpolator operands"), so a dead time shorter than the interpolation would have
// passed the compared value before ST_INHIBIT and waited for the 8-bit counter to wrap (about 256 clocks).
assign inhibit_end  = ( inhibit_cnt >= cmp_inh_i ) ;

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


generate
   for (genvar i=0; i<SMP_CK; i++) begin: gen_smp
      // Input Samples
      always_comb begin
         if   (cfg_invert_i)  adc_smp[i]  = -dt_i[SMP_DW*i+:SMP_DW];
         else                 adc_smp[i]  =  dt_i[SMP_DW*i+:SMP_DW];

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
      // Filter Previous Input Samples (the sample before ftr_smp[i]). Needed by the slope comparison (CMP_SLOPE=1)
      // and by the interpolator; synthesis removes it when neither is used.
      always_ff @(posedge clk_i) begin
         if   (cfg_filter_i)  ftr_prev_smp[i]  <= adc_prev_smp[i] + adc_2prev_smp[i];
         else                 ftr_prev_smp[i]  <= {adc_prev_smp[i], 1'b0};
      end

      // Threshold Comparison
      always_comb begin
         cmp_smp[i]      = ftr_smp[i];
         if   (CMP_SLOPE == 1 && cfg_slope_i)   cmp_prev_smp[i] = ftr_prev_smp[i];
         else                                   cmp_prev_smp[i] = 0;
      end
      assign cmp_smp_s[i] = cmp_smp[i] - cmp_prev_smp[i];
      assign cmp_flg[i]   = (cmp_smp_s[i] > cmp_thr_s);
      always_ff @(posedge clk_i)  cmp_s[i] <= cmp_flg[i];
   end
endgenerate



// Interpolator operands
///////////////////////////////////////////////////////////////////////////////
// cmp_s is ftr_smp registered once, so when enc_s points at the crossing lane, ftr_smp already holds the NEXT
// clock's samples. The operands are therefore computed per lane and registered with the same delay as cmp_s
// (legacy source: x_inter was fed ftr_smp[enc_s] directly, i.e. the wrong batch unless the signal was held).
//
//    num = 2*threshold - previous sample      (0 when the previous sample is already at or above the threshold)
//    den = first sample above - previous sample
//
// with everything at the scale of ftr_smp (twice the sample). The fraction is floor(2^k * num / den), always
// below 2^k because the first sample above the threshold is strictly above it. Legacy fed x_inter the previous
// sample as 0 when CMP_SLOPE=0, and the threshold at half the scale of the samples.
localparam int XW = SMP_DW + 1;                  // bits of num/den: both are in [0, 2^(SMP_DW+1))

// The operands take three registered stages (the first version computed the subtraction, the clamp and the lane
// selection in ONE clock: 9 logic levels with 3 CARRY8 against 1.8 ns at the 552.96 MHz of the RFSoC4x2, WNS -0.32 ns
// in 4x2/tpv2_std). The interpolator is only started once, per tag, so the extra latency costs two clocks of dead time:
//   stage 1 (aligned with cmp_s)           raw differences per lane
//   stage 2 (cmp_s delayed once)           clamp per lane (num <= 0 -> 0, den <= 0 -> 1)
//   stage 3 (cmp_s delayed twice)          selection of the crossing lane; start_r launches the interpolator
reg  signed [SMP_DW+1:0] xnum_d [SMP_CK];
reg  signed [SMP_DW+1:0] xden_d [SMP_CK];
reg  [XW-1:0]  xnum_r [SMP_CK];
reg  [XW-1:0]  xden_r [SMP_CK];
reg  [XW-1:0]  x_num_r, x_den_r;
reg  [2:0]     enc_s_d;
reg            trig_d, start_r;
wire [XW-1:0]  x_num, x_den;

generate
   for (genvar i=0; i<SMP_CK; i++) begin: gen_xop
      wire signed [SMP_DW+1:0] thr_e  = cmp_thr_s;         // sign-extended to SMP_DW+2 bits
      wire signed [SMP_DW+1:0] cur_e  = ftr_smp[i];
      wire signed [SMP_DW+1:0] prv_e  = ftr_prev_smp[i];
      always_ff @(posedge clk_i) begin
         xnum_d[i] <= thr_e - prv_e;
         xden_d[i] <= cur_e - prv_e;
         xnum_r[i] <= (xnum_d[i] > 0) ? xnum_d[i][XW-1:0] : '0;
         xden_r[i] <= (xden_d[i] > 0) ? xden_d[i][XW-1:0] : {{(XW-1){1'b0}}, 1'b1};   // den >= 1: never divide by 0
      end
   end
endgenerate

always_ff @(posedge clk_i) begin
   enc_s_d  <= enc_s;
   x_num_r  <= xnum_r[enc_s_d];
   x_den_r  <= xden_r[enc_s_d];
   if (!rst_ni) begin
      trig_d   <= 1'b0;
      start_r  <= 1'b0;
   end else begin
      trig_d   <= trigger_cmp;
      start_r  <= trig_d;
   end
end
assign x_num = x_num_r;
assign x_den = x_den_r;

// Time Tag
///////////////////////////////////////////////////////////////////////////////

assign enc_zero    = ~|enc_s ;
assign enc_m1      = enc_s - 1'b1 ;
// BUG FIX (deviates from the legacy source): the legacy condition was
// (cfg_inter_i & enc_zero), a 3-bit AND with a 1-bit value, which is true only when
// cfg_inter_i[0] is set. With an even interpolation depth (2, 4, 6) a crossing at lane 0
// was reported at sample 7 of the CURRENT clock instead of the previous one, one clock late.
assign time_ck_s    = ((|cfg_inter_i) & enc_zero) ? time_ck_2r    : time_ck_r;
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
// BUG FIX (this port deviates from the legacy source here): the legacy
// qtt_tag_calc.sv passed OUT="TNO_REG" (not the string "NO_REG"), which
// the encoder treats as "anything else" -> registered (2-cycle) output,
// adding one extra cycle before enc_s/trigger_cmp become valid. ftr_smp[i]/
// ftr_prev_smp[i] are NOT held/latched at the crossing moment -- they are
// plain per-lane registers overwritten with a fresh, unrelated SMP_CK-wide
// batch every single cycle. That extra cycle of encoder delay means
// curr_i/prev_i (ftr_smp[enc_s]/ftr_prev_smp[enc_s], read at whatever cycle
// enc_s finally becomes valid) end up reading a later, unrelated batch
// instead of the pair of samples that actually straddled the threshold --
// a real pipeline-misalignment bug, not just a preserved quirk. This is
// almost certainly the root cause independently found and fixed by Andrin
// (mainline QICK) via ILA/hardware debugging: the interpolator consistently
// returning zero. OUT="NO_REG" (this port) keeps enc_s/trigger_cmp
// combinational with cmp_s. Note that cmp_s is itself ftr_smp registered once,
// so ftr_smp[enc_s] would still be one batch ahead: the interpolator operands
// are registered per lane (see "Interpolator operands" above) to line up with it.
priority_encoder  # (
   .DW  ( 3 ) ,
   .OUT ("NO_REG")
) encoder (
   .clk_i         ( clk_i         ) ,
   .rst_ni        ( rst_ni        ) ,
   .one_hot_dt_i  ( cmp_s         ) ,
   .bin_dt_o      ( enc_s         ) ,
   .vld_o         ( trigger_cmp_s )
);

generate
   if (CMP_INTER > 0 )  begin: gen_inter
      x_inter #(
         .DW  ( XW ) ,
         .IW  ( CMP_INTER )
      ) interpolator (
         .clk_i      ( clk_i                 ) ,
         .rst_ni     ( rst_ni                ) ,
         .start_i    ( start_r               ) ,
         .cfg_inter_i( cfg_inter_i           ) ,
         .thr_i      ( x_num                 ) ,
         .curr_i     ( x_den                 ) ,
         .prev_i     ( '0                    ) ,
         .end_o      ( x_inter_end           ) ,
         .ready_o    (                       ) ,
         .x_int_o    ( thr_inter_smp         ) );
      end else begin : gen_no_inter
         assign x_inter_end   = trigger_cmp;
         assign thr_inter_smp = '0;
      end
endgenerate

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign debug_do   = 0;

// OUT
///////////////////////////////////////////////////////////////////////////////
wire[6:0] trig_time_inter_s;

localparam int ZFP = 6-CMP_INTER;
assign  trig_time_inter_s  = {{ ZFP {1'b0}}, trig_time_inter_r};

// Interpolation of 0..7 bits: the ck-counter field shrinks by one bit per
// interpolation bit appended at the bottom, so trig_time_adc_r always lands
// just above the interpolation bits.
assign tag_dt_o =
   ( cfg_inter_i ) == 3'b000 ? { trig_time_ck_r[28:0], trig_time_adc_r } :
   ( cfg_inter_i ) == 3'b001 ? { trig_time_ck_r[27:0], trig_time_adc_r, trig_time_inter_s[0] } :
   ( cfg_inter_i ) == 3'b010 ? { trig_time_ck_r[26:0], trig_time_adc_r, trig_time_inter_s[1:0] } :
   ( cfg_inter_i ) == 3'b011 ? { trig_time_ck_r[25:0], trig_time_adc_r, trig_time_inter_s[2:0] } :
   ( cfg_inter_i ) == 3'b100 ? { trig_time_ck_r[24:0], trig_time_adc_r, trig_time_inter_s[3:0] } :
   ( cfg_inter_i ) == 3'b101 ? { trig_time_ck_r[23:0], trig_time_adc_r, trig_time_inter_s[4:0] } :
   ( cfg_inter_i ) == 3'b110 ? { trig_time_ck_r[22:0], trig_time_adc_r, trig_time_inter_s[5:0] } :
                                { trig_time_ck_r[21:0], trig_time_adc_r, trig_time_inter_s[6:0] } ;
// tag_vld_o is the push strobe of the tag FIFO, which samples tag_dt_o in the cycle it pulses. x_inter_end
// pulses in the cycle in which trig_time_inter_r is loaded (at the END of that cycle), so the strobe is delayed
// one clock: with x_inter_end itself each tag carried the fraction of the PREVIOUS tag (legacy behaviour; on
// the RFSoC4x2 this made the tag time step by one sample). The coarse count and the sample index are loaded at
// trigger_cmp, earlier than that. The next trigger cannot come before the dead time has elapsed (5 clocks or
// more), so the word is stable during the delayed strobe.
reg x_inter_end_r;
always_ff @(posedge clk_i) begin
   if (!rst_ni) x_inter_end_r <= 1'b0;
   else         x_inter_end_r <= x_inter_end;
end
assign  tag_vld_o    = arm_i & x_inter_end_r;
assign  trig_o       = trigger_cmp;
assign  cmp_o        = trigger_cmp_s;

endmodule
