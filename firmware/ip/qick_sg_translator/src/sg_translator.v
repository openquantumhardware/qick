/*
TRANSLATE from tProc_v2 to diferente Signals Souorces.

// tProc-v2 OUT
// |-----------|-----------|-----------|-----------|-----------|-----------|	
// | 167..152  |  151..120 |  119..88  |   87..64  |   63..32  |   31..0   |	
// |-----------|-----------|-----------|-----------|-----------|-----------|	
// |    CONF   |    LENGHT |    GAIN   |    ENV    |    PHASE  |    FREQ   |	
// |    16-bit |    32-bit |    32-bit |    24-bit |    32-bit |    32-bit | 
// |-----------|-----------|-----------|-----------|-----------|-----------|	


*/
module sg_translator # (
    OUT_TYPE = 0 //(0:gen_v6, 0:int4_v1, 0:mux4_v1, )
) (
// Reset and clock.
   input  wire aresetn  ,
   input  wire	aclk     ,
// IN WAVE PORT
   input  wire [167:0]  s_axis_tdata         ,
   input  wire          s_axis_tvalid        ,
   output wire          s_axis_tready        ,
   // OUT DATA gen_v6 (SEL:0)   
   output wire [159:0]  m_gen_v6_axis_tdata  ,
   output wire          m_gen_v6_axis_tvalid ,
   input  wire          m_gen_v6_axis_tready ,
   // OUT DATA int4_v1 (SEL:1)   
   output wire [87:0]   m_int4_axis_tdata    ,
   output wire          m_int4_axis_tvalid   ,
   input  wire          m_int4_axis_tready   ,
   // OUT DATA mux4_v1 (SEL:2)   
   output wire [39:0]   m_mux4_axis_tdata    ,
   output wire          m_mux4_axis_tvalid   ,
   input  wire          m_mux4_axis_tready       
);

// GET Data from tPtoc_v2
///////////////////////////////////////////////////////////////////////////////
wire [31:0] freq, phase, gain, nsamp ;
wire [23:0] addr ;
wire [23:0] conf ;

wire [1:0] outsel ;
wire mode, stdysel, phrst;

assign conf    = s_axis_tdata[167:152] ;
assign nsamp   = s_axis_tdata[151:120] ;
assign gain	   = s_axis_tdata[119: 88] ;
assign addr	   = s_axis_tdata[ 87: 64] ;
assign phase   = s_axis_tdata[ 63: 32] ;
assign freq	   = s_axis_tdata[ 31:  0] ;

assign phrst	= conf[4]   ;
assign stdysel = conf[3]   ;
assign mode	   = conf[2]   ;
assign outsel  = conf[1:0] ;


assign gen_v6_en = (OUT_TYPE == 0) ;
assign int4_en   = (OUT_TYPE == 1) ;
assign mux4_en   = (OUT_TYPE == 2) ;

// OUTPUTS

///////////////////////////////////////////////////////////////////////////////
assign s_axis_tready =  ( gen_v6_en ) ? m_gen_v6_axis_tready : (
                        ( int4_en   ) ? m_int4_axis_tready   : (
                        ( mux4_en   ) ? m_mux4_axis_tready   : 0 )); 
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// axis_signal_gen_v6	
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|	
// | 159 .. 149 |   148 |     147 |  146 | 145 .. 144 | 143 .. 128 | 127 .. 112 | 111 .. 96 | 95 .. 80 | 79 .. 64 | 63 .. 32 | 31 .. 0 |	
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|	
// |       xxxx | phrst | stdysel | mode |     outsel |      nsamp |       xxxx |      gain |     xxxx |     addr |    phase |    freq |	
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|	
assign m_gen_v6_axis_tdata[159:149]  = 0            ;
assign m_gen_v6_axis_tdata[148]      = phrst        ;
assign m_gen_v6_axis_tdata[147]      = stdysel      ;
assign m_gen_v6_axis_tdata[146]      = mode         ;
assign m_gen_v6_axis_tdata[145:144]  = outsel       ;
assign m_gen_v6_axis_tdata[143:128]  = nsamp [15:0] ;
assign m_gen_v6_axis_tdata[127:112]  = 0            ;
assign m_gen_v6_axis_tdata[111: 96]  = gain  [15:0] ;
assign m_gen_v6_axis_tdata[ 95: 80]  = 0            ;
assign m_gen_v6_axis_tdata[ 79: 64]  = addr  [15:0] ;
assign m_gen_v6_axis_tdata[ 63: 32]  = phase [31:0] ;
assign m_gen_v6_axis_tdata[ 31:  0]  = freq  [31:0] ;

assign m_gen_v6_axis_tvalid = gen_v6_en ? s_axis_tvalid : 0 ;


///////////////////////////////////////////////////////////////////////////////
// axis_sg_int4_v1
// |-------|---------|------|----------|----------|----------|----------|----------|---------|	
// |   84  |   83    |   82 | 81 .. 80 | 79 .. 64 | 63 .. 48 | 47 .. 32 | 31 .. 16 | 15 .. 0 |	
// |-------|---------|------|----------|----------|----------|----------|----------|---------|	
// | phrst | stdysel | mode |   outsel |    nsamp |     gain |     addr |    phase |    freq |	
// | 1-bit | 1-bit   | 1-bit|   2-bit  |   16-bit |   16-bit |   16-bit |  16-bit  |   16-bit|	
// |-------|---------|------|----------|----------|----------|----------|----------|---------|	
assign m_int4_axis_tdata[87:85]  = 0            ;
assign m_int4_axis_tdata[84]     = phrst        ;
assign m_int4_axis_tdata[83]     = stdysel      ;
assign m_int4_axis_tdata[82]     = mode         ;
assign m_int4_axis_tdata[81:80]  = outsel       ;
assign m_int4_axis_tdata[79:64]  = nsamp [15:0] ;
assign m_int4_axis_tdata[63:48]  = gain  [15:0] ;
assign m_int4_axis_tdata[47:32]  = addr  [15:0] ;
assign m_int4_axis_tdata[31:16]  = phase [15:0] ;
assign m_int4_axis_tdata[15:0 ]  = freq  [15:0] ;

assign m_int4_axis_tvalid = int4_en ? s_axis_tvalid : 0 ;

///////////////////////////////////////////////////////////////////////////////
// axis_sg_mux_4_v1	
// |----------|---------|	
// | 39 .. 32 | 31 .. 0 |	
// |----------|---------|	
// |     mask |   nsamp |	
// |----------|---------|	
assign m_mux4_axis_tdata[39:32]  = conf   [7: 0]   ;
assign m_mux4_axis_tdata[31:0]   = nsamp  [31:0]   ;

assign m_mux4_axis_tvalid = mux4_en ? s_axis_tvalid : 0 ;

endmodule
