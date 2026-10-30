///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  tag_gen
//  Faithful port from qick_time_tagger's tag_gen.sv.
//  Instantiates one qtt_tag_calc per ADC channel; trig_o/cmp_o (the
//  single-bit debug/status taps) are wired from channel 0 only, matching
//  the legacy source exactly.
///////////////////////////////////////////////////////////////////////////////

module tag_gen # (
   parameter int ADC_QTY      = 1  , // Number of ADC Inputs
   parameter int CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter int CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter int SMP_DW       = 16 , //Sample  Data width
   parameter int SMP_CK       = 8    // Samples per Clock
) (
   input  wire                      clk_i             ,
   input  wire                      rst_ni            ,
   input  wire                      cfg_invert_i   ,
   input  wire                      cfg_filter_i      ,
   input  wire [2:0]                cfg_inter_i       ,
   input  wire                      cfg_slope_i       ,
   input  wire [28:0]               time_ck_i         ,
   input  wire [SMP_DW-1:0]         cmp_th_i              ,
   input  wire [7:0]                cmp_inh_i            , // Inhibit Clock Pulses
   input  wire                      en_i              ,
   input  wire [SMP_CK*SMP_DW-1:0]  adc_dt_i [ADC_QTY],
   output wire                      trig_o   ,
   output wire                      cmp_o   ,
   output wire [ADC_QTY-1:0]        tag_vld_o         ,
   output wire [31:0]               tag_dt_o [ADC_QTY]
);

wire [ADC_QTY-1:0]        trig_s, cmp_s ;

generate
   for (genvar ind=0; ind<ADC_QTY; ind++) begin: gen_adc
      qtt_tag_calc # (
         .CMP_SLOPE     ( CMP_SLOPE ),
         .CMP_INTER     ( CMP_INTER ),
         .SMP_DW        ( SMP_DW    ),
         .SMP_CK        ( SMP_CK    )
      ) tag_calc (
         .clk_i         ( clk_i        ),
         .rst_ni        ( rst_ni       ),
         .arm_i         ( en_i         ),
         .cfg_invert_i  ( cfg_invert_i ),
         .cfg_filter_i  ( cfg_filter_i ),
         .cfg_inter_i   ( cfg_inter_i  ),
         .cfg_slope_i   ( cfg_slope_i  ),
         .time_ck_i     ( time_ck_i    ),
         .cmp_th_i      ( cmp_th_i     ),
         .cmp_inh_i     ( cmp_inh_i    ),
         .dt_i          ( adc_dt_i [ind]),
         .trig_o        ( trig_s   [ind]),
         .cmp_o         ( cmp_s   [ind]),
         .tag_vld_o     ( tag_vld_o[ind]),
         .tag_dt_o      ( tag_dt_o [ind]),
        .debug_do       (              )
      );
   end
endgenerate

assign trig_o = trig_s[0];
assign cmp_o  = cmp_s[0];

endmodule
