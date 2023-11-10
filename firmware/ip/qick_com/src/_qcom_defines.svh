///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// GENERAL
`ifndef NET_DEFINES
   `define NET_DEFINES
   // Command Decoding
   parameter _nop         = 5'd0;
   parameter _get_net     = 5'd1;
   parameter _set_net     = 5'd2;
   parameter _sync1_net   = 5'd3;
   parameter _sync2_net   = 5'd4;
   parameter _sync3_net   = 5'd5;
   parameter _sync4_net   = 5'd6;
   parameter _get_off     = 5'd7;
   parameter _updt_off    = 5'd8;
   parameter _set_dt      = 5'd9;
   parameter _get_dt      = 5'd10;
   parameter _rst_time    = 5'd16;
   parameter _start_core  = 5'd17;
   parameter _stop_core   = 5'd18;
   parameter _get_cond    = 5'd24;
   parameter _set_cond    = 5'd25;

   // Processor Command
   parameter qick_rst     = 3'd1;
   parameter qick_init    = 3'd2;
   parameter qick_updt    = 3'd3;
   parameter qick_start   = 3'd4;
   parameter qick_stop    = 3'd5;

typedef enum { X_NOP=0, X_NOW=1, X_TIME=2, X_EXT=3 } TYPE_CTRL_REQ  ; // Execution Time
      
typedef enum { NOP, 
      QICK_TIME_RST, QICK_TIME_INIT, QICK_TIME_UPDT ,       
      QICK_CORE_START , QICK_CORE_STOP       
      } TYPE_CTRL_OP ;

typedef enum {NOT_READY, IDLE, ST_TIMEOUT, ST_ERROR, NET_CMD_RT, 
      LOC_GNET       , NET_GNET_P       , NET_GNET_R      ,
      LOC_SNET       , NET_SNET_P       , NET_SNET_R      ,
      LOC_SYNC1      , NET_SYNC1_P      , NET_SYNC1_R      ,
      LOC_SYNC2      , NET_SYNC2_P      , NET_SYNC2_R      ,
      LOC_SYNC3      , NET_SYNC3_P      , NET_SYNC3_R      ,
      LOC_SYNC4      , NET_SYNC4_P      , NET_SYNC4_R      ,
      LOC_GET_OFF    , NET_GET_OFF_P    , NET_GET_OFF_A    ,
      LOC_UPDT_OFF   , NET_UPDT_OFF_P   , NET_UPDT_OFF_R   ,
      LOC_SET_DT     , NET_SET_DT_P     , NET_SET_DT_R     ,
      LOC_GET_DT     , NET_GET_DT_P     , NET_GET_DT_R     , NET_GET_DT_A      ,
      LOC_RST_TIME   , NET_RST_TIME_P   , NET_RST_TIME_R   , 
      LOC_START_CORE , NET_START_CORE_P , NET_START_CORE_R ,
      LOC_STOP_CORE  , NET_STOP_CORE_P  , NET_STOP_CORE_R  ,
      WAIT_TX_ACK, WAIT_TX_nACK, WAIT_CMD_nACK
      } TYPE_TNET_CMD ;
      
   typedef struct packed {
      bit    RTD    ;
      bit    OFF    ;
      bit    NN     ;
      bit    ID     ;
      bit    DT    ;
      } TYPE_PARAM_WE ;

   typedef struct packed {
      bit [31:0]   T_NCR  ;
      bit [31:0]   T_LCS  ;
      bit [31:0]   T_SYNC  ;
      bit [31:0]   RTD    ;
      bit [31:0]   OFF    ;
      bit [ 9:0]   NN     ;
      bit [ 9:0]   ID     ;
      } TYPE_QPARAM ;

// AXI-Lite DATA Slave I/F.   
interface TYPE_IF_AXI_REG #( );
   logic  [5:0]        axi_awaddr  ;
   logic  [2:0]        axi_awprot  ;
   logic               axi_awvalid ;
   logic               axi_awready ;
   logic  [31:0]       axi_wdata   ;
   logic  [3:0]        axi_wstrb   ;
   logic               axi_wvalid  ;
   logic               axi_wready  ;
   logic  [1:0]        axi_bresp   ;
   logic               axi_bvalid  ;
   logic               axi_bready  ;
   logic  [5:0]        axi_araddr  ;
   logic  [2:0]        axi_arprot  ;
   logic               axi_arvalid ;
   logic               axi_arready ;
   logic  [31:0]       axi_rdata   ;
   logic  [1:0]        axi_rresp   ;
   logic               axi_rvalid  ;
   logic               axi_rready  ;
   
   modport master ( output axi_awaddr,axi_awprot, axi_awvalid,axi_wdata,axi_wstrb,axi_wvalid,axi_bready,axi_araddr,axi_arprot,axi_arvalid,axi_rready,
                    input  axi_awready,axi_wready,axi_bresp,axi_bvalid,axi_arready,axi_rdata,axi_rresp,axi_rvalid );
   modport slave ( input  axi_awaddr,axi_awprot, axi_awvalid,axi_wdata,axi_wstrb,axi_wvalid,axi_bready,axi_araddr,axi_arprot,axi_arvalid,axi_rready,
                    output  axi_awready,axi_wready,axi_bresp,axi_bvalid,axi_arready,axi_rdata,axi_rresp,axi_rvalid );

endinterface
      
`endif

