///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2024
//  Version        : 4
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 

*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

module qick_processor # (
   parameter DEBUG          =  0 ,
   parameter DUAL_CORE      =  0 ,
   parameter LFSR           =  0 ,
   parameter DIVIDER        =  1 ,
   parameter ARITH          =  1 ,
   parameter TIME_READ      =  1 ,
   parameter FIFO_DEPTH     =  8 ,
   parameter PMEM_AW        =  8 ,
   parameter DMEM_AW        =  8 ,
   parameter WMEM_AW        =  8 ,
   parameter REG_AW         =  4 ,
   parameter IN_PORT_QTY    =  1 ,
   parameter OUT_TRIG_QTY   =  1 ,
   parameter OUT_DPORT_QTY  =  1 ,
   parameter OUT_DPORT_DW   =  4 ,
   parameter OUT_WPORT_QTY  =  1 
)(
// Time, Core and AXI CLK & RST.
   input   wire            t_clk_i        ,
   input   wire            t_rst_ni       ,
   input   wire            c_clk_i        ,
   input   wire            c_rst_ni       ,
   input   wire            ps_clk_i       ,
   input   wire            ps_rst_ni      ,
// External Control  
   input wire              ext_flag_i     , 
   input  wire             proc_start_i   ,
   input  wire             proc_stop_i    ,
   input  wire             core_start_i   ,
   input  wire             core_stop_i    ,
   input  wire             time_rst_i     ,
   input  wire             time_init_i    ,
   input  wire             time_updt_i    ,
   input  wire  [31:0]     time_updt_dt_i ,
   output wire  [47:0]     time_abs_o     ,
// External PERIPHERALS    
   output wire  [31:0]     periph_a_dt_o  ,
   output wire  [31:0]     periph_b_dt_o  ,
   output wire  [31:0]     periph_c_dt_o  ,
   output wire  [31:0]     periph_d_dt_o  ,
   output wire  [4 :0]     periph_op_o    ,
//QNET_DT   
   output wire             qnet_en_o      ,
   input wire              qnet_rdy_i     , 
   input wire   [31:0]     qnet_dt_i [2]  , 
   input  wire             qnet_vld_i     ,
   input wire              qnet_flag_i    , 
//QCOM_DT   
   output wire             qcom_en_o      ,
   input wire              qcom_rdy_i     , 
   input wire   [31:0]     qcom_dt_i [2]  , 
   input  wire             qcom_vld_i     ,
   input wire              qcom_flag_i    , 
// QP1
   output wire             qp1_en_o       ,
   input  wire             qp1_rdy_i      , 
   input  wire  [31:0]     qp1_dt_i [2]   ,
   input  wire             qp1_vld_i      ,
   input  wire             qp1_flag_i     , 
// QP2
   output wire             qp2_en_o       ,
   input  wire             qp2_rdy_i      , 
   input  wire  [31:0]     qp2_dt_i [2]   ,
   input  wire             qp2_vld_i      ,

// DMA AXIS FOR READ AND WRITE MEMORY             
   input  wire  [255:0]    s_dma_axis_tdata_i   ,
   input  wire             s_dma_axis_tlast_i   ,
   input  wire             s_dma_axis_tvalid_i  ,
   output wire             s_dma_axis_tready_o  ,
   output wire  [255:0]    m_dma_axis_tdata_o   ,
   output wire             m_dma_axis_tlast_o   ,
   output wire             m_dma_axis_tvalid_o  ,
   input  wire             m_dma_axis_tready_i  ,
// AXI-Lite DATA Slave I/F.
   TYPE_IF_AXI_REG.slave  IF_s_axireg          ,
// DATA INPUT INTERFACE
   input   wire            port_tvalid_i[IN_PORT_QTY ] ,
   input   wire [63:0]     port_tdata_i [IN_PORT_QTY ] ,
// TRIGGERS 
   output  wire            port_trig_o  [OUT_TRIG_QTY] ,
// DATA OUTPUT INTERFACE
   output  wire                    port_tvalid_o[OUT_DPORT_QTY] ,
   output  wire [OUT_DPORT_DW-1:0] port_tdata_o [OUT_DPORT_QTY] ,
// AXI Stream Master I/F.
   output  wire [167:0]    m_axis_tdata  [OUT_WPORT_QTY] ,
   output  wire            m_axis_tvalid [OUT_WPORT_QTY] ,
   input   wire            m_axis_tready [OUT_WPORT_QTY] ,
   
// DEBUG INTERFACE   
   input   wire [ 3:0]     dport_di        ,
   output  wire [31:0]     ps_debug_do    ,
   output  wire [31:0]     t_debug_do     ,
   output  wire [31:0]     t_fifo_do      ,
   output  wire [31:0]     c_time_usr_do  ,
   output  wire [31:0]     c_debug_do     ,
   output  wire [31:0]     c_time_ref_do  ,
   output  wire [31:0]     c_proc_do      ,
   output  wire [31:0]     c_port_do      ,
   output  wire [31:0]     c_core_do      );

// SIGNALS
///////////////////////////////////////////////////////////////////////////////
// When signal start with t_ is in t_clk Domain
// When signal start with c_ is in c_clk Domain

// TIME
wire [47:0]    time_abs               ; // Absolute Time Counter Value "out_abs_time"
reg  [47:0]    c_time_ref_dt           ; // Reference time "ref_time"
wire [31:0]    c_time_usr  ; // User time "current_user_time"

// AXI REGISTERS
wire [15:0]    xreg_TPROC_CTRL  , xreg_TPROC_CFG       ;
wire [15:0]    xreg_MEM_ADDR    , xreg_MEM_LEN         ;
wire [31:0]    xreg_MEM_DT_I    , xreg_MEM_DT_O        ;
reg  [31:0]    xreg_TPROC_STATUS, xreg_TPROC_DEBUG     ;
reg  [31:0]    xreg_TPROC_W_DT [2];
wire [ 7:0]    xreg_CORE_CFG;
wire [ 7:0]    xreg_READ_SEL ;
reg  [31:0]    xreg_TPROC_R_DT [2];

// AXIS-INPUT
reg  [63:0]    in_port_dt_r [ IN_PORT_QTY ]  ; // Data registerd from Input Port, Register with t_valid = 1
wire [15:0]    port_dt_new ;

// CTRL Instruction ( TIME, FLAG, ARITH, DIV, NET, CUSTOM )
wire [31:0]    core_usr_a_dt, core_usr_b_dt, core_usr_c_dt, core_usr_d_dt ;
wire [ 4:0]    core_usr_operation ; // 4 bits for internal 5 bits for external

// Control
reg            t_core_rst_prev_net; // NET Request to RESET the Processor and go to previous state

///// DUAL CORE
reg [31:0] core1_w_dt [2];

// Memory Operations
wire [1:0]     ext_core_sel;
wire [1:0]     ext_mem_sel;
wire           ext_mem_we;
wire [15:0]    ext_mem_addr;
wire [167:0]   ext_mem_w_dt;
wire [167:0]   ext_mem_r_dt, ext_mem_r_0_dt, ext_mem_r_1_dt;

// PERIPHERALS
wire           div_rdy, arith_rdy;
wire [63:0]    arith_result;
wire [31:0]    div_remainder, div_quotient;
wire [31:0]    core0_lfsr;
wire [31:0]    core1_lfsr;

// DEBUG SIGNALS
wire [31:0]    axi_mem_ds ;
wire [31:0]    core_r_d0 [2], core_r_d1 [2], core_r_d2[2], core_r_d3[2] ;
wire [31:0]    core_ds ;


///////////////////////////////////////////////////////////////////////////////
// CONTROL Signals
///////////////////////////////////////////////////////////////////////////////

wire [2:0] time_st_ds, core_st_ds;
wire [6:0] ctrl_t_ds, ctrl_c_ds;
qproc_ctrl # (
   .TIME_READ ( TIME_READ )
) QPROC_CTRL (
   .t_clk_i         ( t_clk_i            ),
   .t_rst_ni        ( t_rst_ni           ),
   .c_clk_i         ( c_clk_i            ),
   .c_rst_ni        ( c_rst_ni           ),
   .proc_start_i    ( proc_start_i       ),
   .proc_stop_i     ( proc_stop_i        ),
   .core_start_i    ( core_start_i       ),
   .core_stop_i     ( core_stop_i        ),
   .time_rst_i      ( time_rst_i         ),
   .time_updt_i     ( time_updt_i        ),
   .time_updt_dt_i  ( time_updt_dt_i     ),
   .int_time_en     ( int_time_pen       ),
   .int_time_cmd    ( core_usr_operation[3:0] ),
   .int_time_dt     ( core_usr_b_dt      ),
   .PS_TPROC_CTRL   ( xreg_TPROC_CTRL    ),
   .PS_TPROC_CFG    ( xreg_TPROC_CFG[10:9]),
   // .xreg_TPROC_CTRL ( xreg_TPROC_CTRL    ),
   // .xreg_TPROC_CFG  ( xreg_TPROC_CFG     ),
   .xreg_TPROC_W_DT ( xreg_TPROC_W_DT[0] ),
   .all_fifo_full_i ( all_fifo_full      ),
   .core_rst_o      ( core_rst           ),
   .core_en_o       ( core_en_s          ),
   .time_rst_o      ( time_rst           ),
   .time_en_o       ( time_en            ),
   .time_abs_o      ( time_abs           ),
   .c_time_ref_o    ( c_time_ref_dt      ),
   .c_time_usr_o    ( c_time_usr         ),
   .time_st_do      ( time_st_ds),
   .core_st_do      ( core_st_ds),
   .t_debug_do      ( ctrl_t_ds),
   .c_debug_do      ( ctrl_c_ds)
);

assign fifo_ok    = ~(some_fifo_full)  | xreg_TPROC_CFG[11] ;  // With 1 in TPROC_CFG[11] Continue
assign core_en = core_en_s  & fifo_ok;

///////////////////////////////////////////////////////////////////////////////
// Processor STATUS 
///////////////////////////////////////////////////////////////////////////////
wire [ 3:0] core0_src_dt, core1_src_dt;
wire        arith_clr, div_clr, qnet_clr, qcom_clr, qp1_clr, qp2_clr, port_clr ;
reg         arith_rdy_r , div_rdy_r , qnet_rdy_r , qcom_rdy_r , qp1_rdy_r , qp2_rdy_r;
reg         arith_dt_new, div_dt_new, qnet_dt_new, qcom_dt_new, qp1_dt_new, qp2_dt_new ;
reg  [31:0] qnet_dt_r [2], qcom_dt_r [2], qp1_dt_r[2], qp2_dt_r[2] ;

wire [7:0] core0_cfg, core1_cfg;
wire [7:0] core0_ctrl, core1_ctrl;

assign core0_src_dt = core0_cfg[3:0];
assign core1_src_dt = core1_cfg[3:0];

assign arith_clr    = core0_ctrl[0] | core1_ctrl[0] ;
assign div_clr      = core0_ctrl[1] | core1_ctrl[1] ;
assign qnet_clr     = core0_ctrl[2] | core1_ctrl[2] ;
assign qcom_clr     = core0_ctrl[3] | core1_ctrl[3] ;
assign qp1_clr      = core0_ctrl[4] | core1_ctrl[4] ;
assign qp2_clr      = core0_ctrl[5] | core1_ctrl[5] ;
assign port_clr     = core0_ctrl[6] | core1_ctrl[6] ;

wire [31:0] sreg_status;
assign sreg_status[0]      = arith_rdy ;
assign sreg_status[1]      = arith_dt_new ;
assign sreg_status[2]      = div_rdy ;
assign sreg_status[3]      = div_dt_new ;
assign sreg_status[4]      = qnet_rdy_r  ;
assign sreg_status[5]      = qnet_dt_new ;
assign sreg_status[6]      = qcom_rdy_r ;
assign sreg_status[7]      = qcom_dt_new ;
assign sreg_status[8]      = qp1_rdy_r ;
assign sreg_status[9]      = qp1_dt_new ;
assign sreg_status[10]     = qp2_rdy_r ;
assign sreg_status[11]     = qp2_dt_new ;
assign sreg_status[12]     = 1'b0 ;
assign sreg_status[13]     = 1'b0 ;
assign sreg_status[14]     = some_fifo_full ;
assign sreg_status[15]     = |port_dt_new;
assign sreg_status[31:16]  = port_dt_new ;



// With rising edge of RDY detect new values
always_ff @(posedge c_clk_i) begin
   if (core_rst) begin
      arith_rdy_r    <= 1'b1 ;
      div_rdy_r      <= 1'b1 ;
      qnet_rdy_r     <= 1'b1 ;
      qcom_rdy_r     <= 1'b1 ;
      qp1_rdy_r      <= 1'b1 ;
      qp2_rdy_r      <= 1'b1 ;
      arith_dt_new   <= 1'b0 ;
      div_dt_new     <= 1'b0 ;
      qnet_dt_new    <= 1'b0 ;
      qcom_dt_new    <= 1'b0 ;
      qp1_dt_new     <= 1'b0 ;
      qp2_dt_new     <= 1'b0 ;
      qnet_dt_r      <= '{default:'0} ;
      qcom_dt_r      <= '{default:'0} ;
      qp1_dt_r       <= '{default:'0} ;
      qp2_dt_r       <= '{default:'0} ;
   end else begin 
      arith_rdy_r    <= arith_rdy   ;
      div_rdy_r      <= div_rdy     ;
      qnet_rdy_r     <= qnet_rdy_i  ;
      qcom_rdy_r     <= qcom_rdy_i  ;
      qp1_rdy_r      <= qp1_rdy_i;     
      qp2_rdy_r      <= qp2_rdy_i;     
      // Arith Control
      if       ( arith_rdy & ~arith_rdy_r ) arith_dt_new  <= 1 ;
      else if  (~arith_rdy &  arith_rdy_r ) arith_dt_new  <= 0 ;
      else if  ( arith_clr )                arith_dt_new  <= 0 ;
      // DIV Control
      if       ( div_rdy & ~div_rdy_r ) div_dt_new    <= 1 ;
      else if  (~div_rdy &  div_rdy_r ) div_dt_new    <= 0 ;
      else if  ( div_clr )              div_dt_new  <= 0 ;
      // QNET Control
      if       ( qnet_vld_i ) begin 
         qnet_dt_new   <= 1 ;
         qnet_dt_r     <= qnet_dt_i ;
      end else if  ( qnet_clr ) qnet_dt_new  <= 0 ;
      // QCOM Control
      if       ( qcom_vld_i ) begin 
         qcom_dt_new   <= 1 ;
         qcom_dt_r     <= qcom_dt_i ;
      end else if  ( qcom_clr ) qcom_dt_new  <= 0 ;
      // Q-PERIPHERAL 1 Control
      if       ( qp1_vld_i ) begin 
         qp1_dt_new   <= 1 ;
         qp1_dt_r     <= qp1_dt_i ;
      end else if  ( qp1_clr ) qp1_dt_new  <= 0 ;
      // Q-PERIPHERAL 2 Control
      if       ( qp2_vld_i ) begin 
         qp2_dt_new   <= 1 ;
         qp2_dt_r     <= qp2_dt_i ;
      end else if  ( qp1_clr ) qp2_dt_new  <= 0 ;
     
   end
end


///////////////////////////////////////////////////////////////////////////////
// FLAG
///////////////////////////////////////////////////////////////////////////////

// EXTERNAL Flag
///////////////////////////////////////////////////////////////////////////////
sync_reg # (.DW ( 1 ) ) sync_flag_ext_c (
   .dt_i      ( ext_flag_i ) ,
   .clk_i     ( c_clk_i    ) ,
   .rst_ni    ( c_rst_ni   ) ,
   .dt_o      ( ext_flag_r ) );


// INTERNAL Flag
///////////////////////////////////////////////////////////////////////////////

assign axi_flag_set   = xreg_TPROC_CTRL[13] ;
assign axi_flag_clr   = xreg_TPROC_CTRL[14] ;
assign int_flag_set   = (int_flag_pen & core_usr_operation[0]);
assign int_flag_clr   = (int_flag_pen & core_usr_operation[1]);
assign int_flag_inv   = (int_flag_pen & core_usr_operation[2]);

reg axi_flag_r, int_flag_r ;
always_ff @(posedge c_clk_i) begin
   if (core_rst) begin
      axi_flag_r        <= 0;
      int_flag_r        <= 0;
   end else begin 
      if       ( axi_flag_set )  axi_flag_r  <= 1 ; // SET EXTERNAL FLAG
      else if  ( axi_flag_clr )  axi_flag_r  <= 0 ; // CLEAR EXTERNAL FLAG
      if       ( int_flag_set )  int_flag_r  <= 1 ; // SET   INTERNAL FLAG
      else if  ( int_flag_clr )  int_flag_r  <= 0 ; // CLEAR INTERNAL FLAG
      else if  ( int_flag_inv )  int_flag_r  <= ~int_flag_r ; // Flip INTERNAL FLAG
   end
end


///////////////////////////////////////////////////////////////////////////////
// INSTANCES
///////////////////////////////////////////////////////////////////////////////

// IN PORT DATA REGISTER
///////////////////////////////////////////////////////////////////////////////
qproc_inport_reg # (
   .PORT_QTY    (IN_PORT_QTY) 
) IN_PORT_REG (
   .c_clk_i       ( c_clk_i       ) ,
   .c_rst_ni      ( c_rst_ni      ) ,
   .c_clear       ( port_clr      ) ,
   .port_tvalid_i ( port_tvalid_i ) ,
   .port_tdata_i  ( port_tdata_i  ) ,
   .port_tnew_o   ( port_dt_new    ) ,
   .port_tdata_o  ( in_port_dt_r  ) );

// MEM CONTROL
///////////////////////////////////////////////////////////////////////////////
assign ext_mem_r_dt = ext_mem_r_0_dt ; // From Core0

qproc_mem_ctrl # (
   .PMEM_AW ( PMEM_AW ),
   .DMEM_AW ( DMEM_AW ),
   .WMEM_AW ( WMEM_AW )
) QMEM_CTRL (
   .ps_clk_i         ( ps_clk_i              ) ,
   .ps_rst_ni        ( ps_rst_ni             ) ,
   .ext_core_sel_o   ( ext_core_sel          ) ,
   .ext_mem_sel_o    ( ext_mem_sel           ) ,
   .ext_mem_we_o     ( ext_mem_we            ) ,
   .ext_mem_addr_o   ( ext_mem_addr          ) ,
   .ext_mem_w_dt_o   ( ext_mem_w_dt          ) ,
   .ext_mem_r_dt_i   ( ext_mem_r_dt          ) ,
   .s_axis_tdata_i   ( s_dma_axis_tdata_i    ) ,
   .s_axis_tlast_i   ( s_dma_axis_tlast_i    ) ,
   .s_axis_tvalid_i  ( s_dma_axis_tvalid_i   ) ,
   .s_axis_tready_o  ( s_dma_axis_tready_o   ) ,
   .m_axis_tdata_o   ( m_dma_axis_tdata_o    ) ,
   .m_axis_tlast_o   ( m_dma_axis_tlast_o    ) ,
   .m_axis_tvalid_o  ( m_dma_axis_tvalid_o   ) ,
   .m_axis_tready_i  ( m_dma_axis_tready_i   ) ,
   .MEM_CTRL         ( xreg_TPROC_CFG[6:0]   ) ,
   .MEM_ADDR         ( xreg_MEM_ADDR         ) ,
   .MEM_LEN          ( xreg_MEM_LEN          ) ,
   .MEM_DT_I         ( xreg_MEM_DT_I         ) ,
   .MEM_DT_O         ( xreg_MEM_DT_O         ) ,
   .DEBUG_O          ( axi_mem_ds)            );


// AXI REGISTERS
///////////////////////////////////////////////////////////////////////////////
qproc_axi_reg QPROC_xREG (
   .ps_aclk          ( ps_clk_i            ) , 
   .ps_aresetn       ( ps_rst_ni           ) , 
   .IF_s_axireg      ( IF_s_axireg         ) ,
   .TPROC_CTRL       ( xreg_TPROC_CTRL     ) ,
   .TPROC_CFG        ( xreg_TPROC_CFG      ) ,
   .MEM_ADDR         ( xreg_MEM_ADDR       ) ,
   .MEM_LEN          ( xreg_MEM_LEN        ) ,
   .MEM_DT_I         ( xreg_MEM_DT_I       ) ,
   .TPROC_W_DT1      ( xreg_TPROC_W_DT [0] ) ,
   .TPROC_W_DT2      ( xreg_TPROC_W_DT [1] ) ,
   .CORE_CFG         ( xreg_CORE_CFG       ) ,
   .READ_SEL         ( xreg_READ_SEL       ) ,
   .MEM_DT_O         ( xreg_MEM_DT_O       ) ,
   .TPROC_R_DT1      ( xreg_TPROC_R_DT[0]  ) ,
   .TPROC_R_DT2      ( xreg_TPROC_R_DT[1]  ) ,
   .TIME_USR         ( c_time_usr        ) ,
   .TPROC_STATUS     ( xreg_TPROC_STATUS   ) ,
   .TPROC_DEBUG      ( xreg_TPROC_DEBUG    ) );

// AXI_REG TPROC_R_DT source selection
///////////////////////////////////////////////////////////////////////////////
wire [ 3:0] tproc_src_dt;
assign tproc_src_dt = xreg_READ_SEL[3:0];

always_ff @ (posedge ps_clk_i, negedge ps_rst_ni) begin
   if (!ps_rst_ni) begin
      xreg_TPROC_R_DT       <= '{default:'0} ;
   end else begin
       case (tproc_src_dt)
          4'd0 : xreg_TPROC_R_DT = xreg_TPROC_W_DT ; 
          4'd1 : xreg_TPROC_R_DT = core0_w_dt ;
          4'd2 : xreg_TPROC_R_DT = core1_w_dt ;
          4'd3 : xreg_TPROC_R_DT = {div_quotient  ,div_remainder };
          4'd4 : xreg_TPROC_R_DT = '{arith_result[31:0], arith_result[63:32]};
          4'd5 : xreg_TPROC_R_DT = qnet_dt_r ;
          4'd6 : xreg_TPROC_R_DT = qcom_dt_r;
          4'd7 : xreg_TPROC_R_DT = qp1_dt_r;
          4'd8 : xreg_TPROC_R_DT = qp2_dt_r;
          4'd9 : xreg_TPROC_R_DT = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
          4'd10: xreg_TPROC_R_DT = '{core0_lfsr, core1_lfsr}; 
          default: xreg_TPROC_R_DT = '{default:'0} ;
       endcase
   end
end



///////////////////////////////////////////////////////////////////////////////
// PERIPHERALS
///////////////////////////////////////////////////////////////////////////////

wire [7:0] usr_ctrl_s;
// Internal Peripherals Enable (MSB=0 - 8 possible Peripherals) 
assign int_time_pen  = usr_en & (usr_ctrl_s[7:4] == 4'b0000 );
assign int_flag_pen  = usr_en & (usr_ctrl_s[7:4] == 4'b0001 );
assign int_arith_pen = usr_en & (usr_ctrl_s[7:4] == 4'b0010 );
assign int_div_pen   = usr_en & (usr_ctrl_s[7:4] == 4'b0011 );
//assign int_A_pen     = usr_en & (usr_ctrl_s[7:4] == 4'b0100 );
//assign int_B_pen     = usr_en & (usr_ctrl_s[7:4] == 4'b0101 );
//assign int_C_pen     = usr_en & (usr_ctrl_s[7:4] == 4'b0110 );
//assign int_D_pen     = usr_en & (usr_ctrl_s[7:4] == 4'b0111 );

// External Peripherals Enable (MSB=1 - 4 possible Peripherals) 
assign ext_net_pen  = usr_en & (usr_ctrl_s[7:5] == 3'b100 );
assign ext_com_pen  = usr_en & (usr_ctrl_s[7:5] == 3'b101 );
assign ext_p1_pen   = usr_en & (usr_ctrl_s[7:5] == 3'b110 );
assign ext_p2_pen   = usr_en & (usr_ctrl_s[7:5] == 3'b111 );

assign core_usr_operation = usr_ctrl_s[4:0];

// DIVIDER
///////////////////////////////////////////////////////////////////////////////
generate
   if (DIVIDER == 1) begin : QPER_DIV
      wire [31:0] div_remainder_s, div_quotient_s;
      reg [31:0] div_remainder_r, div_quotient_r;
      div_r #(
         .DW     ( 32 ) 
      ) DIV (
         .clk_i           ( c_clk_i ) ,
         .rst_ni          ( c_rst_ni ) ,
         .start_i         ( int_div_pen ) ,
         .A_i             ( core_usr_d_dt ) ,
         .B_i             ( core_usr_b_dt ) ,
         .ready_o         ( div_rdy  ) ,
         .div_remainder_o ( div_remainder_s ) ,
         .div_quotient_o  ( div_quotient_s ) );

      always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
         if (!c_rst_ni) begin
            div_remainder_r    <= 0 ;
            div_quotient_r     <= 0 ;
         end else begin 
            div_remainder_r   <= div_remainder_s ;
            div_quotient_r    <= div_quotient_s ;
         end
      end      
         assign div_remainder    = div_remainder_r;
         assign div_quotient     = div_quotient_r;
   end else begin : DIVIDER_NO
      assign div_rdy          = 0;
      assign div_remainder    = 0;
      assign div_quotient     = 0;
   end
endgenerate

// ARITH
///////////////////////////////////////////////////////////////////////////////
generate
   if (ARITH == 1) begin : QPER_ARITH
      arith ARITH (
         .clk_i          ( c_clk_i ) ,
         .rst_ni         ( c_rst_ni ) ,
         .start_i        ( int_arith_pen ) ,
         .A_i            ( core_usr_a_dt ) ,
         .B_i            ( core_usr_b_dt ) ,
         .C_i            ( core_usr_c_dt ) ,
         .D_i            ( core_usr_d_dt ) ,
         .alu_op_i       ( core_usr_operation[3:0] ) ,
         .ready_o        ( arith_rdy ) ,
         .arith_result_o ( arith_result ) );
   end else begin : ARITH_NO
      assign arith_rdy        = 0;
      assign arith_result     = 0;
   end
endgenerate




///////////////////////////////////////////////////////////////////////////////
// T PROCESSOR CORE
wire [1:0] core0_lfsr_cfg;
assign core0_lfsr_cfg = xreg_CORE_CFG[1:0];

// Core0 FLAG source selection
///////////////////////////////////////////////////////////////////////////////
wire [3:0] core0_src_flg;
assign core0_src_flg = core0_cfg[7:4];
reg flag_c0;
always_comb begin
   case (core0_src_flg)
      4'b000 : flag_c0  = int_flag_r ;
      4'b001 : flag_c0  = axi_flag_r ;
      4'b010 : flag_c0  = ext_flag_r ;
      4'b011 : flag_c0  = div_dt_new | arith_dt_new ;
      4'b100 : flag_c0  = |port_dt_new   ;
      4'b101 : flag_c0  = qnet_flag_i;
      4'b110 : flag_c0  = qcom_flag_i ;
      4'b111 : flag_c0  = qp1_flag_i ;
      default: flag_c0  = 0 ;
   endcase
end

// Core0 CORE_R_DT sreg(s7) source selection
///////////////////////////////////////////////////////////////////////////////
reg [31:0] core0_r_dt [2], core0_w_dt [2];
always_comb begin
   case (core0_src_dt)
      4'b0000 : core0_r_dt = xreg_TPROC_W_DT ; 
      4'b0001 : core0_r_dt = '{arith_result[31:0], arith_result[63:32]} ;
      4'b0010 : core0_r_dt = qnet_dt_r ; 
      4'b0011 : core0_r_dt = qcom_dt_r;
      4'b0100 : core0_r_dt = qp1_dt_r;
      4'b0101 : core0_r_dt = qp2_dt_r;
      4'b0110 : core0_r_dt = core1_w_dt;
      4'b0111 : core0_r_dt = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
      //DEBUG
      4'b1000: core0_r_dt = core_r_d0;
      4'b1001: core0_r_dt = core_r_d1;
      4'b1010: core0_r_dt = core_r_d2;
      4'b1011: core0_r_dt = core_r_d3;
      default: core0_r_dt = xreg_TPROC_W_DT ;
   endcase
end

PORT_DT        out_port_data  ; // Port Data from the CORE

qproc_core # (
   .LFSR        (  LFSR  ),
   .IN_PORT_QTY (  IN_PORT_QTY  ),
   .PMEM_AW     (   PMEM_AW  ),
   .DMEM_AW     (   DMEM_AW  ),
   .WMEM_AW     (   WMEM_AW  ),
   .REG_AW      (   REG_AW  )
) CORE_0 (
   .c_clk_i          ( c_clk_i           ) ,
   .c_rst_ni         ( c_rst_ni          ) ,
   .ps_clk_i         ( ps_clk_i          ) ,
   .ps_rst_ni        ( ps_rst_ni         ) ,
   .en_i             ( core_en           ) ,    
   .restart_i        ( core_rst          ) ,    
// CORE CTRL
   .lfsr_cfg_i       ( core0_lfsr_cfg    ) ,    
   .core_status_o    (       ) ,    
   .core_debug_o     (       ) ,    
   .lfsr_o           ( core0_lfsr        ) ,    
   .port_dt_i        ( in_port_dt_r      ) , //ALL The port Values
   .flag_i           ( flag_c0           ) ,
   .sreg_cfg_o       ( core0_cfg         ) ,
   .sreg_ctrl_o      ( core0_ctrl        ) ,
   .sreg_arith_i     ( arith_result[31:0] ) ,
   .sreg_div_i       ( {div_quotient  ,div_remainder }  ) ,
   .sreg_status_i    ( sreg_status       ) ,
   .sreg_core_r_dt_i ( core0_r_dt        ) ,
   .sreg_time_dt_i   ( c_time_usr          ) , 
   .sreg_core_w_dt_o ( core0_w_dt        ) ,
   .usr_en_o         ( usr_en            ) ,
   .usr_ctrl_o       ( usr_ctrl_s        ) ,
   .usr_dt_a_o       ( core_usr_a_dt     ) ,
   .usr_dt_b_o       ( core_usr_b_dt     ) ,
   .usr_dt_c_o       ( core_usr_c_dt     ) ,
   .usr_dt_d_o       ( core_usr_d_dt     ) ,
   .ps_mem_sel_i     ( ext_mem_sel       ) ,
   .ps_mem_we_i      ( ext_mem_we        ) ,
   .ps_mem_addr_i    ( ext_mem_addr      ) ,
   .ps_mem_w_dt_i    ( ext_mem_w_dt      ) ,
   .ps_mem_r_dt_o    ( ext_mem_r_0_dt    ) ,
   .port_we_o        ( port_we           ) ,
   .port_o           ( out_port_data     ) ,
   .core_do          ( core_ds           ) );



///////////////////////////////////////////////////////////////////////////////
///// DUAL CORE
wire [1 :0] core1_lfsr_cfg;
assign core1_lfsr_cfg = xreg_CORE_CFG[3:2];

generate
   if ( DUAL_CORE == 1) begin : DUAL_CORE_YES
      reg  [31:0] core1_r_dt [2];
      always_comb begin
         case (core1_src_dt)
            4'b0000 : core1_r_dt = xreg_TPROC_W_DT ; 
            4'b0001 : core1_r_dt = '{arith_result[31:0], arith_result[63:32]} ;
            4'b0010 : core1_r_dt = qnet_dt_r ; 
            4'b0011 : core1_r_dt = qcom_dt_r;
            4'b0100 : core1_r_dt = qp1_dt_r;
            4'b0101 : core1_r_dt = qp2_dt_r;
            4'b0110 : core1_r_dt = core1_w_dt;
            4'b0111 : core1_r_dt = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
            default : core1_r_dt = '{default:'0} ;
         endcase
      end
      qproc_core # (
         .LFSR        (  LFSR  ),
         .IN_PORT_QTY (  IN_PORT_QTY  ),
         .PMEM_AW     (  PMEM_AW  ),
         .DMEM_AW     (  DMEM_AW  ),
         .WMEM_AW     (  WMEM_AW  ),
         .REG_AW      (  REG_AW   )
      ) CORE_1 (
         .c_clk_i          ( c_clk_i           ) ,
         .c_rst_ni         ( c_rst_ni          ) ,
         .ps_clk_i         ( ps_clk_i          ) ,
         .ps_rst_ni        ( ps_rst_ni         ) ,
         .en_i             ( core_en           ) ,    
         .restart_i        ( core_rst          ) ,    
         .port_dt_i        ( in_port_dt_r      ) , 
         .sreg_arith_i     ( {arith_result[31:0],arith_result[63:32]}  ) ,
         .sreg_div_i       ( {div_quotient  ,div_remainder }  ) ,
         .sreg_status_i    ( sreg_status       ) ,
         .sreg_core_r_dt_i ( core1_r_dt        ) ,
         .sreg_core_w_dt_o ( core1_w_dt        ) ,
         .sreg_time_dt_i   ( c_time_usr          ) , 
         .sreg_cfg_o       ( core1_cfg          ) ,
         .usr_dt_a_o       ( ) ,
         .usr_dt_b_o       ( ) ,
         .usr_dt_c_o       ( ) ,
         .usr_dt_d_o       ( ) ,
         .usr_ctrl_o       ( ) ,
         .ps_mem_sel_i     ( ) ,
         .ps_mem_we_i      ( ) ,
         .ps_mem_addr_i    ( ) ,
         .ps_mem_w_dt_i    ( ) ,
         .ps_mem_r_dt_o    ( ) ,
         .port_we_o        ( ) ,
         .port_o           ( ) ,
         .core_do          ( ) );
   end else begin : DUAL_CORE_NO
      assign core1_lfsr     = '{default:'0} ;
      assign core1_w_dt     = '{default:'0} ;
      assign core1_cfg      = '{default:'0} ;
      assign core1_ctrl     = '{default:'0} ;
      assign ext_mem_r_1_dt = '{default:'0} ;
   end
endgenerate





wire [31:0] fifo_dt_ds, axi_fifo_ds;
wire [15:0] c_fifo_ds, t_fifo_ds ;

qproc_dispatcher # (
   .DEBUG          ( DEBUG         ),
   .FIFO_DEPTH     ( FIFO_DEPTH    ),
   .IN_PORT_QTY    ( IN_PORT_QTY   ),
   .OUT_TRIG_QTY   ( OUT_TRIG_QTY  ),
   .OUT_DPORT_QTY  ( OUT_DPORT_QTY ),
   .OUT_DPORT_DW   ( OUT_DPORT_DW  ),
   .OUT_WPORT_QTY  ( OUT_WPORT_QTY )
) DISPATCHER (
   .c_clk_i        ( c_clk_i       ) ,
   .c_rst_ni       ( c_rst_ni      ) ,
   .t_clk_i        ( t_clk_i       ) ,
   .t_rst_ni       ( t_rst_ni      ) ,
   .core_en        ( core_en       ) ,  
   .core_rst       ( core_rst      ) ,  
   .time_en        ( time_en       ) ,  
   .time_rst       ( time_rst      ) ,   
   .c_time_ref_dt  ( c_time_ref_dt ) ,
   .time_abs_i     ( time_abs      ) ,
   .all_fifo_full  ( all_fifo_full )    ,
   .some_fifo_full ( some_fifo_full )    ,
   .port_we        ( port_we       ) ,  
   .out_port_data  ( out_port_data ) ,    
   .port_trig_o    ( port_trig_o   ) ,
   .port_tvalid_o  ( port_tvalid_o ) ,
   .port_tdata_o   ( port_tdata_o  ) ,
   .m_axis_tdata   ( m_axis_tdata  ) ,
   .m_axis_tvalid  ( m_axis_tvalid ) ,
   .m_axis_tready  ( m_axis_tready ) ,
   .fifo_dt_do     ( fifo_dt_ds    ) ,
   .axi_fifo_do    ( axi_fifo_ds    ) ,
   .c_fifo_do      ( c_fifo_ds    ) ,
   .t_fifo_do      ( t_fifo_ds     )
);


///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////








///////////////////////////////////////////////////////////////////////////////
// NO REGISTERED OUTPUT


///////////////////////////////////////////////////////////////////////////////
// OUT PERIPHERLAS (QNET, QCOM, P1 and P2)
assign qnet_en_o  = ext_net_pen ;
assign qcom_en_o  = ext_com_pen ;
assign qp1_en_o   = ext_p1_pen  ;
assign qp2_en_o   = ext_p2_pen  ;

assign periph_a_dt_o = core_usr_a_dt;
assign periph_b_dt_o = core_usr_b_dt;
assign periph_c_dt_o = core_usr_c_dt;
assign periph_d_dt_o = core_usr_d_dt;
assign periph_op_o   = core_usr_operation;


///////////////////////////////////////////////////////////////////////////////
///// External Control
assign time_abs_o = time_abs ;




///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////



//wire [ 3:0] c_fifo_data_dt;
//wire [31:0] c_fifo_data_time;


localparam DEBUG_AXI = (DEBUG > 0) ? 1 : 0;
localparam DEBUG_REG = (DEBUG > 1) ? 1 : 0;
localparam DEBUG_OUT = (DEBUG > 2) ? 1 : 0;


generate

///// DEBUG AXI_REG
///////////////////////////////////////////////////////////////////////////////
   if (DEBUG_AXI == 1) begin : AXI_DB
      wire [31:0] axi_status_ds, axi_port_ds;

      assign axi_status_ds[31:26]   = { qp2_rdy_r , qp1_rdy_r , qcom_rdy_r , qnet_rdy_r, arith_rdy_r, div_rdy_r };
      assign axi_status_ds[25:20]   = { qp2_dt_new, qp1_dt_new, qcom_dt_new, qnet_dt_new, div_dt_new, |port_dt_new };
      assign axi_status_ds[19:16]   = { flag_c0, qp1_flag_i, qcom_flag_i, qnet_flag_i };
      assign axi_status_ds[15:13]   = { ext_flag_r, axi_flag_r, int_flag_r };
      assign axi_status_ds[12: 8]   = { core0_src_flg[2:0], core0_src_dt[1:0]};
      assign axi_status_ds[ 7: 4]   = { time_en , time_st_ds[2:0] };
      assign axi_status_ds[ 3: 0]   = { core_en , core_st_ds[2:0]};

      assign axi_port_ds[31:28]   = dport_di; 
      assign axi_port_ds[27]      = port_trig_o[0] ;
      assign axi_port_ds[26:24]   = port_dt_new[2:0] ;
      assign axi_port_ds[23: 0]   = in_port_dt_r[0][23:0] ;
   
      always_ff @ (posedge ps_clk_i, negedge ps_rst_ni) begin
         if (!ps_rst_ni) begin
            xreg_TPROC_STATUS    <= '{default:'0} ;
            xreg_TPROC_DEBUG     <= '{default:'0} ;
         end else begin
            xreg_TPROC_STATUS <= axi_status_ds;
            case (tproc_src_dt[1:0])
               4'd0 : xreg_TPROC_DEBUG <= axi_fifo_ds ; 
               4'd1 : xreg_TPROC_DEBUG <= axi_mem_ds ;
               4'd2 : xreg_TPROC_DEBUG <= c_time_ref_dt ; 
               4'd3 : xreg_TPROC_DEBUG <= axi_port_ds ;
            endcase
        end
      end
   end else begin
      // NO DEBUG AXI_REG
      assign xreg_TPROC_STATUS  = 0 ;
      assign xreg_TPROC_DEBUG   = 0 ;
   end

///// DEBUG CORE_R_DT
///////////////////////////////////////////////////////////////////////////////
   if (DEBUG_REG == 1) begin : REG_DB
      assign core_r_d0 = core0_w_dt ;
      assign core_r_d1 = '{ in_port_dt_r[0], {15'd0, port_trig_o[0], 12'd0,dport_di} } ;
      assign core_r_d2 = '{c_time_ref_dt[31:0], 32'd0} ;
   end else begin
      // NO DEBUG CORE_R_DT
      assign core_r_d0 = '{default:'0} ;
      assign core_r_d1 = '{default:'0} ;
      assign core_r_d2 = '{default:'0} ;
      assign core_r_d3 = '{default:'0} ;
   end


///// DEBUG OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
   if (DEBUG_OUT == 1) begin : OUT_DB
      ///// PS_CLOCK Debug Signals   
      assign ps_debug_do[31:28]  = {IF_s_axireg.axi_arready, IF_s_axireg.axi_rready, IF_s_axireg.axi_awready, IF_s_axireg.axi_wready};
      assign ps_debug_do[27:24]  = {IF_s_axireg.axi_arvalid, IF_s_axireg.axi_rvalid, IF_s_axireg.axi_awvalid, IF_s_axireg.axi_wvalid};
      assign ps_debug_do[23:12]  = {IF_s_axireg.axi_araddr[5:0], IF_s_axireg.axi_awaddr[5:0]};
      assign ps_debug_do[11 :0]  = {IF_s_axireg.axi_rdata[5:0], IF_s_axireg.axi_wdata[5:0]};

      ///// T_CLOCK Debug Signals   
      assign t_debug_do[31:16]   = t_fifo_ds;
      assign t_debug_do[15:12]   = 4'd0;
      assign t_debug_do[11:10]   = { time_rst, time_en };
      assign t_debug_do[ 9: 3]   = ctrl_t_ds;
      assign t_debug_do[ 2: 0]   = { time_st_ds[2:0] };

      assign t_fifo_do           = fifo_dt_ds ;

      ///// C_CLOCK Debug Signals
      assign c_time_usr_do       = c_time_usr ;

      assign c_debug_do[31:16]   = c_fifo_ds;
      assign c_debug_do[15:13]   = { some_fifo_full, all_fifo_full } ;
      assign c_debug_do[13:12]   = { 2'd0 } ;
      assign c_debug_do[11: 10]   = { core_rst, core_en } ;
      assign c_debug_do[ 9: 3]    = ctrl_c_ds;
      assign c_debug_do[ 2: 0]   = { core_st_ds[2:0] };

      assign c_time_ref_do       = c_time_ref_dt ;

      assign c_port_do[31:28]    = out_port_data.p_addr[3:0] ;
      assign c_port_do[27:16]    = out_port_data.p_data[11:0];
      assign c_port_do[15: 0]    = out_port_data.p_time[15:0];

      assign c_proc_do[31:30]    = {  flag_c0, |port_dt_new } ;
      assign c_proc_do[29:18]    = sreg_status[11:0];
      assign c_proc_do[17:11]    = core0_ctrl[6:0] ;
      assign c_proc_do[10: 8]    = core0_src_dt[2:0] ;
      assign c_proc_do[ 7: 2]    = { int_flag_r, axi_flag_r, int_flag_clr, int_flag_set, axi_flag_clr, axi_flag_set } ;
      assign c_proc_do[ 1: 0]    = { time_ref_inc, time_ref_set } ;
      assign c_core_do           = core_ds ;

      assign time_ref_set    = ( int_time_pen & core_usr_operation[2]) ;
      assign time_ref_inc    = ( int_time_pen & core_usr_operation[3]) ;
      
   end else begin
         // DEBUG OUT
      assign ps_debug_do         = 0 ;
      assign t_debug_do          = 0 ;
      assign t_fifo_do           = 0 ;
      assign c_time_usr_do       = 0 ;
      assign c_debug_do          = 0 ;
      assign c_time_ref_do       = 0 ;
      assign c_port_do           = 0 ;
      assign c_proc_do           = 0 ;
      assign c_core_do           = 0 ;
   end
endgenerate


endmodule

