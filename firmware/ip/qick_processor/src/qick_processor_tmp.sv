///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 3
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 

*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

module qick_processor_tmp # (
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
   output  wire [31:0]     ps_debug_do    ,
   output  wire [31:0]     t_time_usr_do  ,
   output  wire [31:0]     t_debug_do     ,
   output  wire [31:0]     t_fifo_do      ,
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
wire [47:0]    time_abs_r              ; // Absolute Time Counter Value "out_abs_time"
reg  [47:0]    c_time_ref_dt           ; // Reference time "ref_time"
wire [31:0]    t_time_usr, c_time_usr  ; // User time "current_user_time"
reg  [31:0]    time_updt_dt            ; // New incremental time value 

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
wire [31:0]    debug_mem ;
wire [31:0]    core_r_d0 [2], core_r_d1 [2], core_r_d2[2], core_r_d3[2] ;
wire [31:0]    core_ds ;


///////////////////////////////////////////////////////////////////////////////
// CONTROL Signals
///////////////////////////////////////////////////////////////////////////////

/// IO CTRL 
assign proc_start_io  = proc_start_i & xreg_TPROC_CFG[10] ;
assign proc_stop_io   = proc_stop_i  & xreg_TPROC_CFG[10] ;
/// PYTHON
assign time_rst_stop_p = xreg_TPROC_CTRL[6] ; //T_RST | START | P_RST
assign time_rst_run_p  = proc_start_io | xreg_TPROC_CTRL[0] | xreg_TPROC_CTRL[2] ; // START | T_RST 
assign time_update_p   = xreg_TPROC_CTRL[1]  ;
assign time_stop_p     = proc_stop_io | xreg_TPROC_CTRL[3] | xreg_TPROC_CTRL[9] ; // STOP  | P_FREEZE
assign time_run_p      = xreg_TPROC_CTRL[7] | xreg_TPROC_CTRL[8] ; // RUN   | P_PAUSE
assign time_step_p     = xreg_TPROC_CTRL[10] | xreg_TPROC_CTRL[12] ;
assign core_rst_run_p  = proc_start_io | xreg_TPROC_CTRL[2] | xreg_TPROC_CTRL[4]  ; // START | C_START
assign core_rst_stop_p = xreg_TPROC_CTRL[6]  ; // P_RST
assign core_rst_prev_p = xreg_TPROC_CTRL[0]  ; // T_RST
assign core_run_p      = xreg_TPROC_CTRL[7] | xreg_TPROC_CTRL[9]  ; // RUN | P_FREEZE
assign core_stop_p     = proc_stop_io | xreg_TPROC_CTRL[3] | xreg_TPROC_CTRL[5] | xreg_TPROC_CTRL[8]  ; // STOP | C_STOP | P_PAUSE
assign core_step_p     = xreg_TPROC_CTRL[10] | xreg_TPROC_CTRL[11] ;
/// CORE
assign time_rst_core   = ( int_time_pen & core_usr_operation[0]) ;
assign time_updt_core  = ( int_time_pen & core_usr_operation[1]) ;
assign time_ref_set    = ( int_time_pen & core_usr_operation[2]) ;
assign time_ref_inc    = ( int_time_pen & core_usr_operation[3]) ;
/// NET CTRL
assign time_rst_net   = time_rst_i   & ~xreg_TPROC_CFG[9] ;
assign time_init_net  = time_init_i  & ~xreg_TPROC_CFG[9] ;
assign time_updt_net  = time_updt_i  & ~xreg_TPROC_CFG[9] ;
assign core_start_net = core_start_i & ~xreg_TPROC_CFG[9] ;
assign core_stop_net  = core_stop_i  & ~xreg_TPROC_CFG[9] ;

assign c_time_rst_run = time_rst_run_p | time_rst_core  ;
assign c_time_updt    = time_update_p  | time_updt_core ;


assign fifo_ok    = ~(some_fifo_full)  | xreg_TPROC_CFG[11] ;  // With 1 in TPROC_CFG[11] Continue

///////////////////////////////////////////////////////////////////////////////
// CORE CONTROL
///////////////////////////////////////////////////////////////////////////////

// C_CLK DOMAIN Synchronization
///////////////////////////////////////////////////////////////////////////////
sync_reg # (.DW ( 7 ) ) sync_ctrl_ps_c (
   .dt_i      ( {core_rst_prev_p, t_core_rst_prev_net, core_rst_run_p, core_rst_stop_p, core_run_p, core_stop_p, core_step_p}  ) ,
   .clk_i     ( c_clk_i   ) ,
   .rst_ni    ( c_rst_ni  ) ,
   .dt_o      ( {c_core_rst_prev_p, c_core_rst_prev_net, c_core_rst_run, c_core_rst_stop, c_core_run, c_core_stop, c_core_step}  ) );

// Store Time_Update_Data from PROCESSOR or PYTHON in offset_dt_r
reg [31:0] offset_dt_r;
always_ff @(posedge c_clk_i)
   if (!c_rst_ni) begin
      offset_dt_r     <= 0;
   end else begin
      if      ( time_updt_core ) offset_dt_r  <= core_usr_a_dt      ; // Update from CORE
      else if ( time_update_p  ) offset_dt_r  <= xreg_TPROC_W_DT[0] ; // Update from PYTHON
   end

assign ctrl_c_rst_stop = c_core_rst_stop  ;
assign ctrl_c_rst_run  = core_start_net | c_core_rst_run ;
assign ctrl_c_rst_prev = c_core_rst_prev_p | c_core_rst_prev_net;
assign ctrl_c_stop     = core_stop_net | c_core_stop  ;
assign ctrl_c_run      = c_core_run;
assign ctrl_c_step     = c_core_step ;


// Core Control State Machine
///////////////////////////////////////////////////////////////////////////////
reg c_core_en, core_rst;
enum {C_RST_STOP=0, C_RST_STOP_WAIT=1, C_RST_RUN=2, C_RST_RUN_WAIT=3, C_STOP=4, C_RUN=5, C_STEP=6, C_END_STEP=7} core_st_nxt, core_st;

assign core_en = c_core_en  & fifo_ok; 

// Sequential Stante Machine
always_ff @(posedge c_clk_i)
   if (!c_rst_ni)   core_st  <= C_RST_STOP;
   else             core_st  <= core_st_nxt;

// State change and Out
always_comb begin
   c_core_en      = 0;
   core_rst       = 0;
   core_st_nxt = core_st;
   //COMMON TRANSITIONS
   if       ( ctrl_c_stop    )  core_st_nxt = C_STOP;
   else if  ( ctrl_c_run     )  core_st_nxt = C_RUN;
   else if  ( ctrl_c_rst_run )  core_st_nxt = C_RST_RUN;
   else if  ( ctrl_c_step    )  core_st_nxt = C_STEP;
   //State Transitions and Out
   case (core_st)
      C_RST_RUN : begin
         core_rst = 1;            
         if (~ctrl_c_rst_prev & all_fifo_full) core_st_nxt = C_RST_RUN_WAIT; //Keep RST until ACK
      end
      C_RST_RUN_WAIT :  
         if (!all_fifo_full) core_st_nxt = C_RUN;
      C_RST_STOP : begin
         core_rst = 1;            
         if (all_fifo_full) core_st_nxt = C_RST_STOP_WAIT;
      end
      C_RST_STOP_WAIT : 
         if (!all_fifo_full) core_st_nxt = C_STOP;
      C_RUN: begin
         c_core_en = 1;
         if ( ctrl_c_rst_prev )  core_st_nxt = C_RST_RUN;
      end
      C_STOP: begin
         if ( ctrl_c_rst_prev ) core_st_nxt = C_RST_STOP;
        end
      C_STEP: begin
         c_core_en = 1;
         core_st_nxt = C_END_STEP;
      end
      C_END_STEP: begin
         if  (!ctrl_c_step)  core_st_nxt = C_STOP;
      end
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// TIME CONTROL
///////////////////////////////////////////////////////////////////////////////

// T_CLK DOMAIN Synchronization
///////////////////////////////////////////////////////////////////////////////
sync_reg # (.DW ( 7 ) ) sync_ctrl_ps_t (
   .dt_i      ( {core_rst, time_rst_stop_p, c_time_rst_run, c_time_updt, time_stop_p, time_run_p, time_step_p} ) ,
   .clk_i     ( t_clk_i   ) ,
   .rst_ni    ( t_rst_ni  ) ,
   .dt_o      ( {core_rst_ack, t_time_rst_stop, t_time_rst_run, t_time_update, t_time_stop, t_time_run, t_time_step }  ) );


always_ff @(posedge t_clk_i)
   if (!t_rst_ni) begin
      t_core_rst_prev_net  <= 1'b0 ; // NET Request to RESET the Processor
      time_updt_dt         <= 32'd0; // Store Time_Update_Data from offset_dt_r(CORE, PYTHON) OR time_updt_dt_i (NET)
   end else begin 
      if ( t_time_update ) 
         time_updt_dt <= offset_dt_r;
      else
         time_updt_dt <= time_updt_dt_i;
      if      ( time_rst_net   )  t_core_rst_prev_net   <= 1'b1;
      else if ( core_rst_ack   )  t_core_rst_prev_net   <= 1'b0;
   end

assign ctrl_t_rst_stop  = t_time_rst_stop ;
assign ctrl_t_rst_run   = time_rst_net  | t_time_rst_run ;
assign ctrl_t_init      = time_init_net ;
assign ctrl_t_updt      = time_updt_net | t_time_update ;
assign ctrl_t_run       = t_time_run ;
assign ctrl_t_stop      = t_time_stop;
assign ctrl_t_step      = t_time_step ;

// Time Control State Machine
///////////////////////////////////////////////////////////////////////////////
enum {T_RST_STOP=0, T_RST_RUN=1, T_UPDT=2,  T_INIT=3, T_RUN=4, T_STOP=5, T_STEP=6} time_st_nxt, time_st;
// Sequential Stante Machine
always_ff @(posedge t_clk_i)
   if (!t_rst_ni)   time_st  <= T_RST_STOP;
   else             time_st  <= time_st_nxt;
// State change and Out
reg time_rst, time_updt, time_en, time_init ;
always_comb begin
   time_en     = 0;
   time_rst    = 0;
   time_init   = 0;
   time_updt   = 0;
   time_st_nxt = time_st;
   //COMMON TRANSITIONS
   if       ( ctrl_t_rst_stop ) time_st_nxt = T_RST_STOP  ;
   if       ( ctrl_t_rst_run  ) time_st_nxt = T_RST_RUN  ;
   else if  ( ctrl_t_init     ) time_st_nxt = T_INIT ;
   else if  ( ctrl_t_updt     ) time_st_nxt = T_UPDT ;
   else if  ( ctrl_t_run      ) time_st_nxt = T_RUN ;
   else if  ( ctrl_t_stop     ) time_st_nxt = T_STOP ;
   else if  ( ctrl_t_step     ) time_st_nxt = T_STEP ;
   case (time_st)
      T_RST_STOP : begin
         time_en = 1;
         time_rst = 1;
         time_st_nxt = T_STOP ;
      end
      T_RST_RUN : begin
         time_en = 1;
         time_rst = 1;
         time_st_nxt = T_RUN ;
      end
      T_INIT : begin
         time_en = 1;
         time_init = 1;
         time_st_nxt = T_RUN ;
      end
      T_UPDT : begin
         time_en = 1;
         time_updt = 1;
         time_st_nxt = T_RUN ;
      end
      T_RUN: begin
         time_en = 1;
      end
      T_STEP: begin
         time_en = 1;
         time_st_nxt = T_STOP ;
      end
   endcase
end


// Time REF
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)            c_time_ref_dt    <= '{default:'0} ;
   else if  (core_rst)       c_time_ref_dt    <= '{default:'0} ;
   else if  (time_ref_set )  c_time_ref_dt    <=  {16'd0, core_usr_b_dt} ;
   else if  (time_ref_inc )  c_time_ref_dt    <=  c_time_ref_dt + {16'd0, core_usr_b_dt} ;
end



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
assign sreg_status[14]     = 1'b0 ;
assign sreg_status[15]     = some_fifo_full ;
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

// EXTERNAL Flag Control
///////////////////////////////////////////////////////////////////////////////
sync_reg # (.DW ( 1 ) ) sync_flag_ext_c (
   .dt_i      ( ext_flag_i ) ,
   .clk_i     ( c_clk_i    ) ,
   .rst_ni    ( c_rst_ni   ) ,
   .dt_o      ( ext_flag_r ) );

assign flag_set_p      = xreg_TPROC_CTRL[13] ;
assign flag_clr_p      = xreg_TPROC_CTRL[14] ;

// AXI Flag Control
///////////////////////////////////////////////////////////////////////////////
sync_reg # (.DW ( 2 ) ) sync_flag_ps_c (
   .dt_i      ( {flag_set_p, flag_clr_p}  ) ,
   .clk_i     ( c_clk_i   ) ,
   .rst_ni    ( c_rst_ni  ) ,
   .dt_o      ( {axi_flag_set, axi_flag_clr} ) );

assign int_flag_set   = (int_flag_pen & core_usr_operation[0]);
assign int_flag_clr   = (int_flag_pen & core_usr_operation[1]);

// Flag
///////////////////////////////////////////////////////////////////////////////
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
   .port_tnew_o   ( port_dt_new      ) ,
   .port_tdata_o  ( in_port_dt_r  ) );

// MEM CONTROL
///////////////////////////////////////////////////////////////////////////////
assign ext_mem_r_dt = ext_mem_r_0_dt ;

qproc_mem_ctrl # (
   .PMEM_AW ( PMEM_AW ),
   .DMEM_AW ( DMEM_AW ),
   .WMEM_AW ( WMEM_AW )
) Q_MEM_CTRL (
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
   .DEBUG_O          ( debug_mem)            );

// Time ABS
///////////////////////////////////////////////////////////////////////////////
qproc_time_ctrl QTIME_CTRL ( 
   .t_clk_i       ( t_clk_i      ) ,
   .t_rst_ni      ( t_rst_ni     ) ,
   .time_en_i     ( time_en      )  ,
   .time_rst_i    ( time_rst     ) ,
   .time_init_i   ( time_init    ) ,
   .time_updt_i   ( time_updt    ) ,
   .updt_dt_i     ( time_updt_dt ) ,
   .time_abs_o    ( time_abs_r   ) );


// AXI REGISTERS
///////////////////////////////////////////////////////////////////////////////
qproc_axi_reg QPROC_xREG (
   .ps_aclk          ( ps_clk_i            ) , 
   .ps_aresetn       ( ps_rst_ni           ) , 
   .c_clk_i          ( c_clk_i             ) , 
   .c_rst_ni         ( c_rst_ni            ) , 
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
   .TIME_USR         ( c_time_usr          ) ,
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
         .DW     ( 32 ) ,
         .N_PIPE ( 32 )
      ) DIV (
         .clk_i           ( c_clk_i ) ,
         .rst_ni          ( c_rst_ni ) ,
         .start_i         ( int_div_pen ) ,
         .A_i             ( core_usr_a_dt ) ,
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
      assign arith_result     = 0;
   end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// TIME READ
generate
   if ( TIME_READ == 1) begin : QPER_TIME_READ
      assign t_time_usr = (time_abs_r - c_time_ref_dt);
      sync_reg sync_time_usr_c (
         .dt_i       ( t_time_usr   ) ,
         .clk_i      ( c_clk_i      ) ,
         .rst_ni     ( c_rst_ni     ) ,
         .dt_o       ( c_time_usr   ) );
   end else begin : TIME_READ_NO
      assign t_time_usr       = 0;
      assign c_time_usr       = 0;
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
      4'b011 : flag_c0  = div_dt_new & arith_dt_new ;
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
   .sreg_time_dt_i   ( c_time_usr        ) , 
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
         .sreg_time_dt_i   ( c_time_usr        ) , 
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




PORT_DT        out_port_data  ; // Port Data from the CORE



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
   .time_abs_r     ( time_abs_r    ) ,
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
   .debug_fifo (debug_fifo)
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
assign time_abs_o = time_abs_r ;




///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
wire [31:0] debug_status, debug_port;

//assign debug_status[31:26]   = { qp2_rdy_r , qp1_rdy_r , qcom_rdy_r , qnet_rdy_r, arith_rdy_r, div_rdy_r };
assign debug_status[25:20]   = { qp2_dt_new, qp1_dt_new, qcom_dt_new, qnet_dt_new, div_dt_new, |port_dt_new };
assign debug_status[19:16]   = { flag_c0, qp1_flag_i, qcom_flag_i, qnet_flag_i };
assign debug_status[15:13]   = { ext_flag_r, axi_flag_r, int_flag_r };
assign debug_status[12:8]   = { core0_src_flg[3:0], core0_src_dt[1:0]};
assign debug_status[ 7: 4]   = { time_en , time_st[2:0] };
assign debug_status[ 3: 0]   = { core_en , core_st[2:0]};

// assign debug_fifo[31:28]   = t_fifo_data_dt[0][3:0] ;
// assign debug_fifo[27:12]   = t_fifo_data_time[0][15:0] ;
// assign debug_fifo[11: 8]   = { fifo_ok       , wfifo_full     , dfifo_full    , tfifo_full };
// assign debug_fifo[ 7: 4]   = { all_fifo_full , all_wfifo_full , all_dfifo_full, all_tfifo_full };
// assign debug_fifo[ 3: 0]   = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty };

//assign debug_port[31:28]   = port_dt_r[0][3:0] ;
//assign debug_port[27]      = port_trig_r[0] ;
//assign debug_port[26:24]   = port_dt_new[2:0] ;
//assign debug_port[23: 0]   = in_port_dt_r[0][23:0] ;

 
wire [3:0] c_fifo_data_dt;
wire [31:0] c_fifo_data_time;



endmodule
