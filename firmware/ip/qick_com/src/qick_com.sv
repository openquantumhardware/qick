`include "_qcom_defines.svh"

module qick_com # (
   parameter DEBUG     = 1
)(
// Core and AXI CLK & RST
   input  wire             c_clk_i        ,
   input  wire             c_rst_ni       ,
   input  wire             ps_clk_i       ,
   input  wire             ps_rst_ni      ,
   input  wire             sync_i         ,
  
// QCOM INTERFACE
   input  wire             qcom_en_i       ,
   input  wire  [4:0]      qcom_op_i       ,
   input  wire  [31:0]     qcom_dt1_i      ,
   output reg              qcom_rdy_o      ,
   output reg   [31:0]     qcom_dt1_o      ,
   output reg   [31:0]     qcom_dt2_o      ,
   output reg              qcom_vld_o      ,
   output reg              qcom_flag_o     ,
// TPROC CONTROL
   output reg              qproc_start_o   ,
// PMOD COM
   input  wire  [ 3:0]     pmod_i         ,
   output wire  [ 3:0]     pmod_o         ,
// AXI-Lite DATA Slave I/F
   input  wire  [ 5:0]     s_axi_awaddr   ,
   input  wire  [ 2:0]     s_axi_awprot   ,
   input  wire             s_axi_awvalid  ,
   output wire             s_axi_awready  ,
   input  wire  [31:0]     s_axi_wdata    ,
   input  wire  [ 3:0]     s_axi_wstrb    ,
   input  wire             s_axi_wvalid   ,
   output wire             s_axi_wready   ,
   output wire  [ 1:0]     s_axi_bresp    ,
   output wire             s_axi_bvalid   ,
   input  wire             s_axi_bready   ,
   input  wire  [ 5:0]     s_axi_araddr   ,
   input  wire  [ 2:0]     s_axi_arprot   ,
   input  wire             s_axi_arvalid  ,
   output wire             s_axi_arready  ,
   output wire  [31:0]     s_axi_rdata    ,
   output wire  [ 1:0]     s_axi_rresp    ,
   output wire             s_axi_rvalid   ,
   input  wire             s_axi_rready   ,         
///// DEBUG   
   output wire [31:0]      qcom_do        
   );


///////////////////////////////////////////////////////////////////////////////
///// AXI LITE PORT /////
TYPE_IF_AXI_REG        IF_s_axireg()   ;
assign IF_s_axireg.axi_awaddr  = s_axi_awaddr ;
assign IF_s_axireg.axi_awprot  = s_axi_awprot ;
assign IF_s_axireg.axi_awvalid = s_axi_awvalid;
assign IF_s_axireg.axi_wdata   = s_axi_wdata  ;
assign IF_s_axireg.axi_wstrb   = s_axi_wstrb  ;
assign IF_s_axireg.axi_wvalid  = s_axi_wvalid ;
assign IF_s_axireg.axi_bready  = s_axi_bready ;
assign IF_s_axireg.axi_araddr  = s_axi_araddr ;
assign IF_s_axireg.axi_arprot  = s_axi_arprot ;
assign IF_s_axireg.axi_arvalid = s_axi_arvalid;
assign IF_s_axireg.axi_rready  = s_axi_rready ;
assign s_axi_awready = IF_s_axireg.axi_awready;
assign s_axi_wready  = IF_s_axireg.axi_wready ;
assign s_axi_bresp   = IF_s_axireg.axi_bresp  ;
assign s_axi_bvalid  = IF_s_axireg.axi_bvalid ;
assign s_axi_arready = IF_s_axireg.axi_arready;
assign s_axi_rdata   = IF_s_axireg.axi_rdata  ;
assign s_axi_rresp   = IF_s_axireg.axi_rresp  ;
assign s_axi_rvalid  = IF_s_axireg.axi_rvalid ;


///////////////////////////////////////////////////////////////////////////////
// SYNC 
reg sync_r2 ;
sync_reg # (
   .DW ( 1 )
) sync_sync (
   .dt_i      ( sync_i     ) ,
   .clk_i     ( c_clk_i    ) ,
   .rst_ni    ( c_rst_ni   ) ,
   .dt_o      ( sync_r     ) );
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)    sync_r2   <= 1'b0; 
   else              sync_r2   <= sync_r;
end

assign sync_t10 = sync_r2 & !sync_r ;

///////////////////////////////////////////////////////////////////////////////
// ######   #     # 
// #     #   #   #  
// #     #    # #   
// ######      #    
// #   #      # #   
// #    #    #   #  
// #     #  #     # 
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// RX Decoding
wire [32:0] rx_data;       // Data Received
wire [ 2:0] rx_header;     // Header Received
reg  [ 1:0] reg_sel ;      // Write Register Selection
reg  [31:0] new_dt ;       // New Data to Register reg_sel
wire [ 1:0] reg_wr_size;   // Write Size 1, 8, 16, or 32 Bits
reg rx_wreg, rx_sync;

assign reg_wr_size = rx_header[2:1];

always_comb begin
   reg_sel  = {1'b0, rx_data[32]};
   new_dt   = rx_data[31:0];
   rx_sync  = 1'b0;
   rx_wreg  = 1'b0;
   case ( reg_wr_size )
      2'b00 : begin // 1 BIT
         rx_wreg     = 1'b1;
         reg_sel  = 2'b11;
      end
      2'b01 : begin // 8 BITS
         if ( rx_header[0] ) 
            rx_sync = 1'b1 ;
         else begin
            rx_wreg     = 1'b1;
            reg_sel     = {1'b0, rx_data[8]};
            new_dt      = {24'd0, rx_data[7:0]};           
         end
      end
      2'b10 : begin // 16 BITS
         rx_wreg     = 1'b1;
         reg_sel     = {1'b0, rx_data[16]};
         new_dt      = {16'd0, rx_data[15:0]};
      end
      2'b11 : begin // 32 BIT
         rx_wreg     = 1'b1;
         reg_sel     = {1'b0, rx_data[32]};
         new_dt      = rx_data[31:0];
      end
      default : begin // :P
         rx_wreg     = 1'b1;
         reg_sel     = {1'b0, rx_data[32]};
         new_dt      = rx_data[31:0];
      end
   endcase
end

assign rx_wreg_en = rx_vld & rx_wreg;

///////////////////////////////////////////////////////////////////////////////
// Register Update
reg        qflag_dt, rx_wreg_r ;
reg [31:0] qreg1_dt, qreg2_dt;
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      qflag_dt    <= 1'b0; 
      qreg1_dt    <= '{default:'0} ; 
      qreg2_dt    <= '{default:'0} ; 
      rx_wreg_r   <= 1'b0; 
   end else begin 
      rx_wreg_r <= rx_wreg_en ;
      if ( rx_wreg_en )
         case ( reg_sel )
            2'b00 : qreg1_dt <= new_dt;      // Reg_dt1
            2'b01 : qreg2_dt <= new_dt;      // Reg_dt2
            2'b11 : qflag_dt <= rx_header[0]; // FLAG
         endcase
   end
end


///////////////////////////////////////////////////////////////////////////////
// RX
typedef enum { RX_IDLE, RX_CMD } TYPE_RX_ST ;
   (* fsm_encoding = "secuential" *) TYPE_RX_ST qcom_rx_st;
   TYPE_RX_ST qcom_rx_st_nxt;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qcom_rx_st  <= RX_IDLE;
   else                     qcom_rx_st  <= qcom_rx_st_nxt;
end

always_comb begin
   qcom_rx_st_nxt   = qcom_rx_st; // Default Current
   case (qcom_rx_st)
      RX_IDLE  : 
         if ( rx_vld ) qcom_rx_st_nxt = RX_CMD;     
      RX_CMD   : begin
         qcom_rx_st_nxt = RX_IDLE;     
      end
   endcase
end


///////////////////////////////////////////////////////////////////////////////
// #######  #     # 
//    #      #   #  
//    #       # #   
//    #        #    
//    #       # #   
//    #      #   #  
//    #     #     # 
///////////////////////////////////////////////////////////////////////////////
reg cmd_end, qproc_start;

///////////////////////////////////////////////////////////////////////////////
// Register Inputs
reg  [ 3:0] c_op_r ;
reg  [31:0] c_dt_r ;
reg         c_sync_r;

assign qcom_sync_i = ( qcom_op_i[3:0] == 4'b0110 );

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      c_op_r   <= '{default:'0} ; 
      c_dt_r   <= '{default:'0} ; 
      c_sync_r <= 1'b0; 
   end else begin 
      if (qcom_en_i) begin
         c_op_r   <= qcom_op_i[3:0];
         c_dt_r   <= qcom_dt1_i;
         c_sync_r <= qcom_sync_i;
      end
   end
end

///////////////////////////////////////////////////////////////////////////////
// TX Control state
typedef enum { TX_IDLE, TX_SEND, TX_WSYNC, TX_WRDY, TX_WCMD } TYPE_TX_ST ;
(* fsm_encoding = "secuential" *) TYPE_TX_ST qcom_tx_st;
TYPE_TX_ST qcom_tx_st_nxt;

reg         tx_sync ;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qcom_tx_st  <= TX_IDLE;
   else                     qcom_tx_st  <= qcom_tx_st_nxt;
end
reg        tx_vld, qready;
reg [ 3:0] tx_header;
reg [31:0] tx_data;

always_comb begin
   qcom_tx_st_nxt   = qcom_tx_st; // Default Current
   tx_vld    = 1'b0;
   tx_header = 3'b000;
   tx_data   = 31'd0;
   qready   = 1'b0;
   tx_sync  = 1'b0;
   case (qcom_tx_st)
      TX_IDLE   :  begin
         qready   = 1'b1;
         if ( qcom_en_i )
            if ( qcom_sync_i )
               qcom_tx_st_nxt = TX_WSYNC;     
            else
               qcom_tx_st_nxt = TX_SEND;     
      end
      TX_WSYNC   :  begin
         if ( sync_t10 ) qcom_tx_st_nxt = TX_SEND;     
      end
      TX_SEND :  begin
         tx_vld      = 1'b1;
         tx_header   = c_op_r;
         tx_data     = c_dt_r;
         if   ( c_sync_r ) qcom_tx_st_nxt = TX_WCMD;     
         else              qcom_tx_st_nxt = TX_WRDY;     
      end
      TX_WRDY   :  begin
         if ( tx_ready ) qcom_tx_st_nxt = TX_IDLE;     
      end
      TX_WCMD   :  begin
      tx_sync  = 1'b1;
         if ( cmd_end ) qcom_tx_st_nxt = TX_IDLE;     
      end
      
   endcase
end




///////////////////////////////////////////////////////////////////////////////
// QICK PROCESSOR RESTART
assign qcom_sync = tx_sync | rx_sync;

///////////////////////////////////////////////////////////////////////////////
typedef enum { QRST_IDLE, QRST_WSYNC, QRST_CMD } TYPE_QCTRL_ST ;
   (* fsm_encoding = "secuential" *) TYPE_QCTRL_ST qctrl_st;
   TYPE_QCTRL_ST qctrl_st_nxt;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qctrl_st  <= QRST_IDLE;
   else                     qctrl_st  <= qctrl_st_nxt;
end


always_comb begin
   qctrl_st_nxt   = qctrl_st; // Default Current
   qproc_start = 1'b0;
   cmd_end    = 1'b0;
   case (qctrl_st)
      QRST_IDLE  : 
         if ( qcom_sync ) qctrl_st_nxt = QRST_WSYNC;     
      QRST_WSYNC : 
         if ( sync_t10  ) qctrl_st_nxt = QRST_CMD;     
      QRST_CMD   : begin
         qproc_start = 1'b1;
         cmd_end     = 1'b1;
         qctrl_st_nxt = QRST_IDLE;     
      end
   endcase
end



///////////////////////////////////////////////////////////////////////////////
// INSTANCES 
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// AXI Register.
wire [ 3:0] xreg_QCOM_CTRL, xreg_QCOM_CFG;
wire [31:0] xreg_RAXI_DT1;
wire        xreg_QCOM_FLAG, xreg_QCOM_STATUS;
wire [31:0] xreg_QCOM_DT_1, xreg_QCOM_DT_2 ;
reg  [31:0] xreg_QCOM_TX_DT, xreg_QCOM_RX_DT;
reg  [15:0] xreg_QCOM_DEBUG;

assign   xreg_QCOM_FLAG    = qflag_dt;
assign   xreg_QCOM_DT_1    = qreg1_dt;
assign   xreg_QCOM_DT_2    = qreg2_dt;
assign   xreg_QCOM_STATUS  = tx_ready;

qcom_axi_reg QCOM_xREG (
   .ps_aclk        ( ps_clk_i         ) , 
   .ps_aresetn     ( ps_rst_ni        ) , 
   .IF_s_axireg    ( IF_s_axireg      ) ,
   .QCOM_CTRL      ( xreg_QCOM_CTRL   ) ,
   .QCOM_CFG       ( xreg_QCOM_CFG    ) ,
   .RAXI_DT1       ( xreg_RAXI_DT1    ) ,
   .QCOM_FLAG      ( xreg_QCOM_FLAG   ) ,
   .QCOM_DT_1      ( xreg_QCOM_DT_1   ) ,
   .QCOM_DT_2      ( xreg_QCOM_DT_2   ) ,
   .QCOM_STATUS    ( xreg_QCOM_STATUS ) ,
   .QCOM_TX_DT     ( xreg_QCOM_TX_DT  ) ,
   .QCOM_RX_DT     ( xreg_QCOM_RX_DT  ) ,
   .QCOM_DEBUG     ( xreg_QCOM_DEBUG  ) );
   
///////////////////////////////////////////////////////////////////////////////
wire [3:0] tick_cfg ;
assign tick_cfg = xreg_QCOM_CFG[3:0];

qcom_link QCOM_LINK (
   .c_clk_i      ( c_clk_i       ) ,
   .c_rst_ni     ( c_rst_ni      ) ,
   .tick_cfg     ( tick_cfg      ) ,
   .tx_vld_i     ( tx_vld        ) ,
   .tx_ready_o   ( tx_ready      ) ,
   .tx_header_i  ( tx_header     ) ,
   .tx_data_i    ( tx_data       ) ,
   .rx_vld_o     ( rx_vld        ) ,
   .rx_header_o  ( rx_header     ) ,
   .rx_data_o    ( rx_data       ) ,
   .pmod_i       ( pmod_i        ) ,
   .pmod_o       ( pmod_o        ) ,
   .qcom_link_do (   ) 
);


///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////

assign qcom_rdy_o    = qready;
assign qcom_dt1_o    = qreg1_dt;
assign qcom_dt2_o    = qreg2_dt;
assign qcom_vld_o    = rx_wreg_r;
assign qcom_flag_o   = qflag_dt;
assign qcom_do       = 0;
assign qproc_start_o = qproc_start;



///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if (DEBUG == 0) begin : DEBUG_NO
      // DEBUG AXI_REG
    assign xreg_QCOM_TX_DT  = '{default:'0} ;
    assign xreg_QCOM_RX_DT  = '{default:'0} ;
    assign xreg_QCOM_DEBUG  = '{default:'0} ;

   end else if   (DEBUG == 1) begin : DEBUG_YES
      // DEBUG AXI_REG
      always_ff @ (posedge ps_clk_i, negedge ps_rst_ni) begin
         if (!ps_rst_ni) begin
            xreg_QCOM_TX_DT       <= '{default:'0} ;
            xreg_QCOM_RX_DT       <= '{default:'0} ;
            xreg_QCOM_DEBUG       <= '{default:'0} ;
         end else begin
            xreg_QCOM_TX_DT       <= c_dt_r;
            xreg_QCOM_RX_DT       <= new_dt;
            xreg_QCOM_DEBUG       <= {1'b0,  tx_header[2:0], qcom_tx_st[2:0], reg_wr_size[1:0], reg_sel[1:0], rx_header[2:0], qcom_rx_st[1:0] };
         end
      end
   end
endgenerate


endmodule


