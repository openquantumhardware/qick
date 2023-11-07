///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 11-2023
//  Version        : 2
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
   parameter DIVIDER        =  0 ,
   parameter ARITH          =  0 ,
   parameter TIME_READ      =  0 ,
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
   output wire  [4 :0]     periph_addr_o  ,
   output wire  [4 :0]     periph_op_o    ,
// CUSTOM   
   input  wire             periph_rdy_i   , 
   input  wire  [31:0]     periph_dt_i [2],
   input  wire             periph_vld_i   ,
   input  wire             periph_flag_i  , 
//QNET_DT   
   input wire              qnet_rdy_i     , 
   input wire   [31:0]     qnet_dt_i [2]  , 
   input  wire             qnet_vld_i     ,
   input wire              qnet_flag_i    , 
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
wire [47:0]    time_abs_r ; // Absolute Time Counter Value "out_abs_time"
reg  [47:0]    c_time_ref_dt; //  Reference time "ref_time"
wire [31:0]    t_time_usr, c_time_usr; // User time "current_user_time"
reg  [31:0]    time_updt_dt;


// FIFOS & DISPATCHER
wire           port_we        ; // Write Enable Signal from the CORE > To the FIFOs
PORT_DT        out_port_data  ; // Port Data from the CORE 
// .p_type > Select between WAVE or DATA (TRIG is DATA with high address)
// .p_addr > Select Port Addr (Bit 3 select between DATA and TRIGGER (Addr 0 to 7 are Data, Addr 8 to 15 are Trigger)
// .p_time > c_fifo_time_in_r 
// .p_data > c_fifo_data_in_r

reg  [ 47:0]       c_fifo_time_in_r ; // TIME from the CORE > To the FIFOs
reg  [167:0]       c_fifo_data_in_r ; // DATA from the CORE > To the FIFOs

wire [47:0]               t_fifo_wave_time  [OUT_WPORT_QTY-1:0]; // TIME from the FIFO > To the Comparator
wire [167:0]              t_fifo_wave_dt    [OUT_WPORT_QTY-1:0]; // DATA from the FIFO > TO the WPORT
wire [47:0]               W_RESULT          [OUT_WPORT_QTY-1:0]; // Comparison between t_fifo_wave_time and time_abs_r
reg  [OUT_WPORT_QTY-1:0]  wave_t_gr;                             // Sign bit of W_RESULT
reg  [OUT_WPORT_QTY-1:0]  c_fifo_wave_push, c_fifo_wave_push_r, c_fifo_wave_push_s; 
reg  [OUT_WPORT_QTY-1:0]  wave_pop, wave_pop_prev;
reg  [OUT_WPORT_QTY-1:0]  wave_pop_r, wave_pop_r2, wave_pop_r3, wave_pop_r4;

wire [47:0]               t_fifo_data_time  [OUT_DPORT_QTY-1:0]; // TIME from the FIFO > To the Comparator
wire [OUT_DPORT_DW-1 :0]  t_fifo_data_dt    [OUT_DPORT_QTY-1:0]; // DATA from the FIFO > TO the DPORT
wire [47:0]               D_RESULT          [OUT_DPORT_QTY-1:0]; // Comparison between t_fifo_data_time and time_abs_r
reg  [OUT_DPORT_QTY-1:0]  data_t_gr;                             // Sign bit of D_RESULT
reg  [OUT_DPORT_QTY-1:0]  c_fifo_data_push, c_fifo_data_push_r, c_fifo_data_push_s ; 
reg                       data_pop[OUT_DPORT_QTY], data_pop_prev[OUT_DPORT_QTY];
reg                       data_pop_r[OUT_DPORT_QTY], data_pop_r2[OUT_DPORT_QTY], data_pop_r3[OUT_DPORT_QTY], data_pop_r4[OUT_DPORT_QTY];

wire [47:0]               t_fifo_trig_time  [OUT_TRIG_QTY]; // TIME from the FIFO > To the Comparator
wire                      t_fifo_trig_dt    [OUT_TRIG_QTY]; // DATA from the FIFO > TO the WPORT
wire [47:0]               T_RESULT          [OUT_TRIG_QTY]; // Comparison between t_fifo_trig_time and time_abs_r
reg  [OUT_TRIG_QTY-1:0]   trig_t_gr; // Sign bit of T_RESULT
reg  [OUT_TRIG_QTY-1:0]   c_fifo_trig_push, c_fifo_trig_push_r, c_fifo_trig_push_s ; 
reg                     trig_pop[OUT_TRIG_QTY], trig_pop_prev[OUT_TRIG_QTY];
reg                     trig_pop_r[OUT_TRIG_QTY], trig_pop_r2[OUT_TRIG_QTY], trig_pop_r3[OUT_TRIG_QTY], trig_pop_r4[OUT_TRIG_QTY];

reg  [OUT_TRIG_QTY-1:0]   c_fifo_trig_empty ;
wire [OUT_TRIG_QTY-1:0]   t_fifo_trig_empty, c_fifo_trig_full ;
reg  [OUT_DPORT_QTY-1:0]  c_fifo_data_empty ;
wire [OUT_DPORT_QTY-1:0]  t_fifo_data_empty, c_fifo_data_full ;
reg  [OUT_WPORT_QTY-1:0]  c_fifo_wave_empty;
wire [OUT_WPORT_QTY-1:0]  t_fifo_wave_empty , c_fifo_wave_full   ;
wire dfifo_full, wfifo_full;

// REGISTERS
wire [15:0]    xreg_TPROC_CTRL  , xreg_TPROC_CFG       ;
wire [15:0]    xreg_MEM_ADDR    , xreg_MEM_LEN         ;
wire [31:0]    xreg_MEM_DT_I    , xreg_MEM_DT_O        ;
reg  [31:0]    xreg_TPROC_STATUS, xreg_TPROC_DEBUG     ;
reg  [31:0]    xreg_TPROC_W_DT [2];
wire [ 7:0]    xreg_CORE_CFG;
wire [ 7:0]    xreg_READ_SEL ;
reg  [31:0]    xreg_TPROC_R_DT [2];


reg  [63:0]             in_port_dt_r [ IN_PORT_QTY ]; // Data registerd from Input Port, Register with t_valid = 1
wire [IN_PORT_QTY-1:0 ] port_new ; // New Data in Port, is one with rising edge of t_valid
wire                    port_clr; // Clear the port_new signal.

// User data from CTRL Instruction ( TIME, FLAG, ARITH, DIV, NET, CUSTOM )
wire [31:0]    core_usr_a_dt, core_usr_b_dt, core_usr_c_dt, core_usr_d_dt ;
wire [ 4:0]    core_usr_addr, core_usr_operation;
wire           div_rdy, arith_rdy;

// DEBUG SIGNALS
wire [ 7:0]       mem_ctrl_status_ds;
wire [16:0]       mem_ctrl_debug_ds;
reg core_rst_net_req; // Makes the TPROC to reset.

///// DUAL CORE
reg [31:0] core1_w_dt [2];

// Memory Operations
wire [1:0]       ext_core_sel;
wire [1:0]       ext_mem_sel;
wire             ext_mem_we;
wire [15:0]      ext_mem_addr;
wire [167:0]     ext_mem_w_dt;
wire [167:0]     ext_mem_r_dt, ext_mem_r_0_dt, ext_mem_r_1_dt;


///////////////////////////////////////////////////////////////////////////////
// PROCESSOR CONTROL
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
assign time_rst_core   = ( core_usr_addr[0] & core_usr_operation[0]) ;
assign time_updt_core  = ( core_usr_addr[0] & core_usr_operation[1]) ;
assign time_ref_set    = ( core_usr_addr[0] & core_usr_operation[2]) ;
assign time_ref_inc    = ( core_usr_addr[0] & core_usr_operation[3]) ;
/// NET CTRL
assign time_rst_net   = time_rst_i   & ~xreg_TPROC_CFG[9] ;
assign time_init_net  = time_init_i  & ~xreg_TPROC_CFG[9] ;
assign time_updt_net  = time_updt_i  & ~xreg_TPROC_CFG[9] ;
assign core_start_net = core_start_i & ~xreg_TPROC_CFG[9] ;
assign core_stop_net  = core_stop_i  & ~xreg_TPROC_CFG[9] ;

assign c_time_rst_run = time_rst_run_p | time_rst_core  ;
assign c_time_updt    = time_update_p  | time_updt_core ;



///////////////////////////////////////////////////////////////////////////////
// CORE CONTROL
///////////////////////////////////////////////////////////////////////////////
// C_CLK DOMAIN
sync_reg # (.DW ( 7 ) ) sync_ctrl_ps_c (
   .dt_i      ( {core_rst_prev_p, t_core_rst_prev_net, core_rst_run_p, core_rst_stop_p, core_run_p, core_stop_p, core_step_p}  ) ,
   .clk_i     ( c_clk_i   ) ,
   .rst_ni    ( c_rst_ni  ) ,
   .dt_o      ( {c_core_rst_prev_p, c_core_rst_prev_net, c_core_rst_run, c_core_rst_stop, c_core_run, c_core_stop, c_core_step}  ) );

// Store Time_Update_Data from PROCESSOR and PYTHON
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

enum {C_RST_STOP=0, C_RST_STOP_WAIT=1, C_RST_RUN=2, C_RST_RUN_WAIT=3, C_STOP=4, C_RUN=5, C_STEP=6, C_END_STEP=7} core_st_nxt, core_st;

always_ff @(posedge c_clk_i)
   if (!c_rst_ni)   core_st  <= C_RST_STOP;
   else             core_st  <= core_st_nxt;
     
reg c_core_en, core_rst;
wire core_en;
assign core_en = c_core_en  & fifo_ok; 

always_comb begin
   c_core_en      = 0;
   core_rst       = 0;
   core_st_nxt = core_st;
   //COMMON TRANSITIONS
   if       ( ctrl_c_stop    )  core_st_nxt = C_STOP;
   else if  ( ctrl_c_run     )  core_st_nxt = C_RUN;
   else if  ( ctrl_c_rst_run )  core_st_nxt = C_RST_RUN;
   else if  ( ctrl_c_step    )  core_st_nxt = C_STEP;
   
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
// T_CLK DOMAIN
sync_reg # (.DW ( 7 ) ) sync_ctrl_ps_t (
   .dt_i      ( {core_rst, time_rst_stop_p, c_time_rst_run, c_time_updt, time_stop_p, time_run_p, time_step_p} ) ,
   .clk_i     ( t_clk_i   ) ,
   .rst_ni    ( t_rst_ni  ) ,
   .dt_o      ( {core_rst_ack, t_time_rst_stop, t_time_rst_run, t_time_update, t_time_stop, t_time_run, t_time_step }  ) );


reg t_core_rst_prev_net;
always_ff @(posedge t_clk_i)
   if (!t_rst_ni) begin
      t_core_rst_prev_net  <= 1'b0; // Request to RESET the Processor
      time_updt_dt      <= 32'd0; // Signal to TIME_CTRL
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

enum {T_RST_STOP=0, T_RST_RUN=1, T_UPDT=2,  T_INIT=3, T_RUN=4, T_STOP=5, T_STEP=6} time_st_nxt, time_st;

always_ff @(posedge t_clk_i)
   if (!t_rst_ni)   time_st  <= T_RST_STOP;
   else             time_st  <= time_st_nxt;

reg time_rst, time_updt, time_en, time_init ;
always_comb begin
   time_en     = 0;
   time_rst    = 0;
   time_init    = 0;
   time_updt    = 0;
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


///////////////////////////////////////////////////////////////////////////////
// Time REF
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)            c_time_ref_dt    <= '{default:'0} ;
   else if  (core_rst)       c_time_ref_dt    <= '{default:'0} ;
   else if  (time_ref_set )  c_time_ref_dt    <=  {16'd0, core_usr_b_dt} ;
   else if  (time_ref_inc )  c_time_ref_dt    <=  c_time_ref_dt + {16'd0, core_usr_b_dt} ;
end


///////////////////////////////////////////////////////////////////////////////
// STATUS 
///////////////////////////////////////////////////////////////////////////////
wire [ 2:0] core0_src_dt, core1_src_dt;
wire        status_clr, arith_clr, div_clr, qnet_clr, periph_clr ;
reg         arith_rdy_r, div_rdy_r, qnet_rdy_r, periph_rdy_r;
reg         arith_dt_new, div_dt_new, qnet_dt_new, periph_dt_new ;
reg  [31:0] qnet_dt_r [2] ;
reg  [31:0] periph_dt_r [2] ;

wire [7:0] core0_cfg, core1_cfg;
wire [7:0] core0_ctrl, core1_ctrl;

assign core0_src_dt = core0_cfg[2:0];
assign core1_src_dt = core1_cfg[2:0];

assign arith_clr    = core0_ctrl[0] | core1_ctrl[0] ;
assign div_clr      = core0_ctrl[1] | core1_ctrl[1] ;
assign qnet_clr     = core0_ctrl[2] | core1_ctrl[2] ;
assign periph_clr   = core0_ctrl[3] | core1_ctrl[3] ;
assign port_clr     = core0_ctrl[4] | core1_ctrl[4] ;


// With rising edge of RDY detect new values
always_ff @(posedge c_clk_i) begin
   if (core_rst) begin
      arith_rdy_r   <= 1'b1 ;
      div_rdy_r     <= 1'b1 ;
      qnet_rdy_r    <= 1'b1 ;
      periph_rdy_r  <= 1'b1 ;
      arith_dt_new  <= 1'b0 ;
      div_dt_new    <= 1'b0 ;
      qnet_dt_new   <= 1'b0 ;
      periph_dt_new <= 1'b0 ;
      qnet_dt_r     <= '{default:'0} ;
      periph_dt_r   <= '{default:'0} ;
   end else begin 
      arith_rdy_r  <= arith_rdy   ;
      div_rdy_r    <= div_rdy     ;
      qnet_rdy_r   <= qnet_rdy_i  ;
      periph_rdy_r <= periph_rdy_i;     
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
      // PERIPH Control
      if       ( periph_vld_i ) begin
         periph_dt_new <= 1 ;
         periph_dt_r   <= periph_dt_i ;
      end else if  ( periph_clr ) periph_dt_new  <= 0 ;
     
   end
end

wire [31:0] sreg_status;
assign sreg_status[0]  =  arith_dt_new ;
assign sreg_status[1]  =  div_dt_new   ;
assign sreg_status[2]  =  qnet_dt_new  ;
assign sreg_status[3]  =  periph_dt_new;
assign sreg_status[4]  =  arith_rdy_r  ;
assign sreg_status[5]  =  div_rdy_r    ;
assign sreg_status[6]  =  qnet_rdy_r   ;
assign sreg_status[7]  =  periph_rdy_r ;
assign sreg_status[8]  =  c_fifo_data_full ;
assign sreg_status[9]  =  c_fifo_data_empty ;
assign sreg_status[10] =  c_fifo_wave_full ;
assign sreg_status[11] =  c_fifo_wave_empty ;
assign sreg_status[15:12] =  0;
assign sreg_status[31:16] = port_dt_new ;


///////////////////////////////////////////////////////////////////////////////
// EXTERNAL, AXI & INTERNAL FLAG
sync_reg # (.DW ( 3 ) ) sync_flag_ext_c (
   .dt_i      ( { ext_flag_i, periph_flag_i, qnet_flag_i}  ) ,
   .clk_i     ( c_clk_i   ) ,
   .rst_ni    ( c_rst_ni  ) ,
   .dt_o      ( { ext_flag_r, periph_flag_r, qnet_flag_r } ) 
);

assign flag_set_p      = xreg_TPROC_CTRL[13] ;
assign flag_clr_p      = xreg_TPROC_CTRL[14] ;

sync_reg # (.DW ( 6 ) ) sync_flag_ps_c (
   .dt_i      ( {flag_set_p, flag_clr_p}  ) ,
   .clk_i     ( c_clk_i   ) ,
   .rst_ni    ( c_rst_ni  ) ,
   .dt_o      ( {axi_flag_set, axi_flag_clr}  ) );

assign int_flag_set   = (core_usr_addr[1] & core_usr_operation[0]);
assign int_flag_clr   = (core_usr_addr[1] & core_usr_operation[1]);

reg axi_flag_r, int_flag_r ;
always_ff @(posedge c_clk_i) begin
   if (core_rst) begin
      axi_flag_r        <= 0;
      int_flag_r        <= 0;
   end else begin 
      if       ( axi_flag_set   )     axi_flag_r     <= 1 ; // SET EXTERNAL FLAG
      else if  ( axi_flag_clr   )     axi_flag_r     <= 0 ; // CLEAR EXTERNAL FLAG
      if       ( int_flag_set   )     int_flag_r     <= 1 ; // SET   INTERNAL FLAG
      else if  ( int_flag_clr   )     int_flag_r     <= 0 ; // CLEAR INTERNAL FLAG
   end
end

///////////////////////////////////////////////////////////////////////////////
// FLAG source selection
wire [2:0]core0_src_flg;
assign core0_src_flg = core0_cfg[5:3];
reg flag_c0;
always_comb begin
   case (core0_src_flg)
      3'b000 : flag_c0  = int_flag_r ;
      3'b001 : flag_c0  = axi_flag_r ;
      3'b010 : flag_c0  = ext_flag_r ;
      3'b011 : flag_c0  = div_dt_new  ;
      3'b100 : flag_c0  = arith_dt_new  ;
      3'b101 : flag_c0  = |port_dt_new ;
      3'b110 : flag_c0  = qnet_flag_r ;
      3'b111 : flag_c0  = periph_flag_r ;
      default: flag_c0  = 0 ;
   endcase
end

// CLOCK DOMAIN CHANGE
(* ASYNC_REG = "TRUE" *) reg [OUT_TRIG_QTY-1:0] fifo_trig_empty_cdc;
(* ASYNC_REG = "TRUE" *) reg [OUT_DPORT_QTY-1:0] fifo_data_empty_cdc;
(* ASYNC_REG = "TRUE" *) reg [OUT_WPORT_QTY-1:0] fifo_wave_empty_cdc;
always_ff @(posedge c_clk_i) begin
   fifo_trig_empty_cdc      <= t_fifo_trig_empty;
   fifo_data_empty_cdc      <= t_fifo_data_empty;
   fifo_wave_empty_cdc      <= t_fifo_wave_empty;
   c_fifo_trig_empty        <= fifo_trig_empty_cdc;
   c_fifo_data_empty        <= fifo_data_empty_cdc;
   c_fifo_wave_empty        <= fifo_wave_empty_cdc;
end

///////////////////////////////////////////////////////////////////////////////
// SREG CORE_R_DT (s7) source selection
reg [31:0] core0_r_dt [2], core0_w_dt [2];
always_comb begin
   case (core0_src_dt)
      3'b000 : core0_r_dt = xreg_TPROC_W_DT ; 
      3'b001 : core0_r_dt = core0_w_dt ; 
      3'b010 : core0_r_dt = core1_w_dt ; 
      3'b011 : core0_r_dt = '{arith_result[31:0], arith_result[63:32]};
      3'b100 : core0_r_dt = qnet_dt_r ;
      3'b101 : core0_r_dt = periph_dt_r;
      3'b110 : core0_r_dt = '{32'd7, 32'd7};
      3'b111 : core0_r_dt = xreg_TPROC_R_DT ;
      default: core0_r_dt = '{default:'0} ;
   endcase
end


///////////////////////////////////////////////////////////////////////////////
// AXI_REG TPROC_R_DT source selection
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
          4'd6 : xreg_TPROC_R_DT = periph_dt_r;
          4'd7 : xreg_TPROC_R_DT = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
          4'd8 : xreg_TPROC_R_DT = '{core0_lfsr, core1_lfsr}; 
          4'd9: xreg_TPROC_R_DT = '{32'd9,32'd9}; 
          default: xreg_TPROC_R_DT = '{default:'0} ;
       endcase
   end
end


///////////////////////////////////////////////////////////////////////////////
// INSTANCES
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// IN PORT DATA REGISTER
wire [15:0] port_dt_new ;
localparam ZFP = 16 - IN_PORT_QTY; // Zero Fill for Input Port
assign port_dt_new = { {ZFP{1'b0}} , port_new };

qproc_inport_reg # (
   .PORT_QTY    (IN_PORT_QTY) 
) IN_PORT_REG (
   .c_clk_i       ( c_clk_i       ) ,
   .c_rst_ni      ( c_rst_ni      ) ,
   .c_clear       ( port_clr      ) ,
   .port_tvalid_i ( port_tvalid_i ) ,
   .port_tdata_i  ( port_tdata_i  ) ,
   .port_tnew_o   ( port_new      ) ,
   .port_tdata_o  ( in_port_dt_r  ) );

///////////////////////////////////////////////////////////////////////////////
// Time ABS
qproc_time_ctrl QTIME_CTRL ( 
   .t_clk_i       ( t_clk_i      ) ,
   .t_rst_ni      ( t_rst_ni     ) ,
   .time_en_i     ( time_en      )  ,
   .time_rst_i    ( time_rst     ) ,
   .time_init_i   ( time_init    ) ,
   .time_updt_i   ( time_updt    ) ,
   .updt_dt_i     ( time_updt_dt ) ,
   .time_abs_o    ( time_abs_r   ) );

///////////////////////////////////////////////////////////////////////////////
// DIVIDER
wire [31:0] div_remainder, div_quotient;

generate
   if (DIVIDER == 1) begin : DIVIDER_YES
      wire [31:0] div_remainder_s, div_quotient_s;
      reg [31:0] div_remainder_r, div_quotient_r;
      div_r #(
         .DW     ( 32 ) ,
         .N_PIPE ( 32 )
      ) div_r_inst (
         .clk_i           ( c_clk_i ) ,
         .rst_ni          ( c_rst_ni ) ,
         .start_i         ( core_usr_addr[3] ) ,
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

///////////////////////////////////////////////////////////////////////////////
// ARITH
wire [63:0] arith_result;

generate
   if (ARITH == 1) begin : ARITH_YES
      arith arith_inst (
         .clk_i          ( c_clk_i ) ,
         .rst_ni         ( c_rst_ni ) ,
         .start_i        ( core_usr_addr[2] ) ,
         .A_i            ( core_usr_a_dt ) ,
         .B_i            ( core_usr_b_dt ) ,
         .C_i            ( core_usr_c_dt ) ,
         .D_i            ( core_usr_d_dt ) ,
         .alu_op_i       ( core_usr_operation ) ,
         .ready_o        ( arith_rdy ) ,
         .arith_result_o ( arith_result ) );
   end else begin : ARITH_NO
      assign arith_result     = 0;
   end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// TIME READ
generate
   if ( TIME_READ == 1) begin : TIME_READ_YES
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
wire [31:0] core0_lfsr;
wire [1:0] core0_lfsr_cfg;
assign core0_lfsr_cfg = xreg_CORE_CFG[1:0];

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
   .core_status_o    ( core0_status      ) ,    
   .core_debug_o     ( core0_debug       ) ,    
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
   .usr_dt_a_o       ( core_usr_a_dt     ) ,
   .usr_dt_b_o       ( core_usr_b_dt     ) ,
   .usr_dt_c_o       ( core_usr_c_dt     ) ,
   .usr_dt_d_o       ( core_usr_d_dt     ) ,
   .usr_ctrl_o       ( {core_usr_operation, core_usr_addr}  ) ,
   .ps_mem_sel_i     ( ext_mem_sel       ) ,
   .ps_mem_we_i      ( ext_mem_we        ) ,
   .ps_mem_addr_i    ( ext_mem_addr      ) ,
   .ps_mem_w_dt_i    ( ext_mem_w_dt      ) ,
   .ps_mem_r_dt_o    ( ext_mem_r_0_dt    ) ,
   .port_we_o        ( port_we           ) ,
   .port_o           ( out_port_data     ) ,
   .core_do          ( core0_ds          ) );


///////////////////////////////////////////////////////////////////////////////
///// DUAL CORE
wire [31:0] core1_lfsr;
wire [1 :0] core1_lfsr_cfg;
assign core1_lfsr_cfg = xreg_CORE_CFG[3:2];

generate
   if ( DUAL_CORE == 1) begin : DUAL_CORE_YES
      reg  [31:0] core1_r_dt [2];
      always_comb begin
         case (core1_src_dt)
            3'b000 : core1_r_dt = xreg_TPROC_W_DT ; 
            3'b001 : core1_r_dt = core0_w_dt ;
            3'b010 : core1_r_dt = core1_w_dt ; 
            3'b011 : core1_r_dt = xreg_TPROC_R_DT;
            3'b100 : core1_r_dt = '{arith_result[31:0], arith_result[63:32]};
            3'b101 : core1_r_dt = qnet_dt_r ;
            3'b110 : core1_r_dt = periph_dt_r;
            3'b111 : core1_r_dt = '{32'd7, 32'd7};
            default: core1_r_dt = '{default:'0} ;
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


///////////////////////////////////////////////////////////////////////////////
// AXI REGISTERS
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


///////////////////////////////////////////////////////////////////////////////
// MEM CONTROL
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
   .STATUS_O         ( mem_ctrl_status_ds    ) ,
   .DEBUG_O          ( mem_ctrl_debug_ds)    );


///////////////////////////////////////////////////////////////////////////////
/// FIFO & DISPATCHER
///////////////////////////////////////////////////////////////////////////////
assign all_tfifo_empty = &c_fifo_trig_empty ;
assign all_dfifo_empty = &c_fifo_data_empty ;
assign all_wfifo_empty = &c_fifo_wave_empty ;
assign all_fifo_empty  = all_tfifo_empty & all_dfifo_empty & all_wfifo_empty ;   

assign all_tfifo_full = &c_fifo_trig_full ;
assign all_dfifo_full = &c_fifo_data_full ;
assign all_wfifo_full = &c_fifo_wave_full ;
assign all_fifo_full  = all_dfifo_full & all_wfifo_full ;   

assign tfifo_full = |c_fifo_trig_full ;
assign dfifo_full = |c_fifo_data_full ; 
assign wfifo_full = |c_fifo_wave_full ; 

wire fifo_ok;
assign fifo_ok    = ~(tfifo_full | dfifo_full | wfifo_full)  | xreg_TPROC_CFG[11];  // With 1 CONTINUE

///////////////////////////////////////////////////////////////////////////////
/// FIFO CTRL-REG
always_comb begin
   c_fifo_wave_push    = 0;
   c_fifo_data_push    = 0;
   c_fifo_trig_push    = 0;
   if (port_we)
      if (out_port_data.p_type)
         if ( out_port_data.p_addr[3] == 1'b1 ) //TRIGGER
            c_fifo_trig_push [out_port_data.p_addr[2:0] ] = 1'b1 ;
         else // DATA
            c_fifo_data_push [out_port_data.p_addr[2:0] ] = 1'b1 ;
      else
         c_fifo_wave_push [out_port_data.p_addr] = 1'b1 ;
   if (core_en) begin 
      c_fifo_trig_push_s = c_fifo_trig_push_r;
      c_fifo_data_push_s = c_fifo_data_push_r;
      c_fifo_wave_push_s = c_fifo_wave_push_r;
   end else begin
      c_fifo_trig_push_s = '{default:'0} ;
      c_fifo_data_push_s = '{default:'0} ;
      c_fifo_wave_push_s = '{default:'0} ;
   end
end  

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      c_fifo_data_in_r       <= '{default:'0} ;
      c_fifo_time_in_r       <= '{default:'0} ;
      c_fifo_trig_push_r     <= '{default:'0} ;
      c_fifo_data_push_r     <= '{default:'0} ;
      c_fifo_wave_push_r     <= '{default:'0} ;
   end else if (core_en) begin
      c_fifo_trig_push_r     <= c_fifo_trig_push ;
      c_fifo_data_push_r     <= c_fifo_data_push ;
      c_fifo_wave_push_r     <= c_fifo_wave_push ;
         if (c_fifo_trig_push | c_fifo_data_push | c_fifo_wave_push) begin
         c_fifo_data_in_r       <= out_port_data.p_data ;
         c_fifo_time_in_r       <= {16'd0, out_port_data.p_time} + c_time_ref_dt;
      end
   end
end


always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   if (!t_rst_ni) begin
      trig_pop_r     <= '{default:'0} ;
      trig_pop_r2    <= '{default:'0} ;
      trig_pop_r3    <= '{default:'0} ;
      trig_pop_r4    <= '{default:'0} ;
      data_pop_r     <= '{default:'0} ;
      data_pop_r2    <= '{default:'0} ;
      data_pop_r3    <= '{default:'0} ;
      data_pop_r4    <= '{default:'0} ;
      wave_pop_r     <= '{default:'0} ;
      wave_pop_r2    <= '{default:'0} ;
      wave_pop_r3    <= '{default:'0} ;
      wave_pop_r4    <= '{default:'0} ;
   end else begin
      trig_pop_r     <= trig_pop;
      trig_pop_r2    <= trig_pop_r;
      trig_pop_r3    <= trig_pop_r2;
      trig_pop_r4    <= trig_pop_r3;
      data_pop_r     <= data_pop;
      data_pop_r2    <= data_pop_r;
      data_pop_r3    <= data_pop_r2;
      data_pop_r4    <= data_pop_r3;
      wave_pop_r     <= wave_pop;
      wave_pop_r2    <= wave_pop_r;
      wave_pop_r3    <= wave_pop_r2;
      wave_pop_r4    <= wave_pop_r3;
   end
end


///////////////////////////////////////////////////////////////////////////////
/// TRIGGER PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_tfifo;
generate
   for (ind_tfifo=0; ind_tfifo < OUT_TRIG_QTY; ind_tfifo=ind_tfifo+1) begin: TRIG_FIFO
      // TRIGGER FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (1+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) trig_fifo_inst ( 
         .wr_clk_i   ( c_clk_i      ) ,
         .wr_rst_ni  ( c_rst_ni     ) ,
         .wr_en_i    ( 1'b1     ) ,
         .push_i     ( c_fifo_trig_push_s[ind_tfifo] ) ,
         .data_i     ( {c_fifo_data_in_r[0],c_fifo_time_in_r}  ) ,
         .rd_clk_i   ( t_clk_i      ) ,
         .rd_rst_ni  ( t_rst_ni     ) ,
         .rd_en_i    ( time_en    ) ,
         .pop_i      ( trig_pop        [ind_tfifo] ) ,
         .data_o     ( {t_fifo_trig_dt[ind_tfifo], t_fifo_trig_time[ind_tfifo]} ) ,
         .flush_i    ( core_rst     ),
         .async_empty_o ( t_fifo_trig_empty [ind_tfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_trig_full  [ind_tfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
      ADDSUB_MACRO #(
            .DEVICE     ("7SERIES"),        // Target Device: "7SERIES" 
            .LATENCY    ( 1   ),            // Desired clock cycle latency, 0-2
            .WIDTH      ( 48  )             // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( T_RESULT[ind_tfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_r[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .A          ( t_fifo_trig_time[ind_tfifo] ), // Input B bus, width defined by WIDTH parameter
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : TRIG_DISPATCHER
         trig_t_gr[ind_tfifo]  = T_RESULT[ind_tfifo][47];
         trig_pop[ind_tfifo] = 0;
         trig_pop_prev[ind_tfifo] = trig_pop_r[ind_tfifo] | trig_pop_r2[ind_tfifo] | trig_pop_r3[ind_tfifo] | trig_pop_r4[ind_tfifo];
         if (time_en & ~t_fifo_trig_empty[ind_tfifo] )
            if ( trig_t_gr[ind_tfifo] & ~trig_pop_prev[ind_tfifo] ) 
               trig_pop      [ind_tfifo] = 1'b1 ;
      end //ALWAYS
   end //FOR      
endgenerate      


///////////////////////////////////////////////////////////////////////////////
/// WAVE PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_wfifo;
generate
   for (ind_wfifo=0; ind_wfifo < OUT_WPORT_QTY; ind_wfifo=ind_wfifo+1) begin: WAVE_FIFO
      // WaveForm FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (168+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) wave_fifo_inst ( 
         .wr_clk_i   ( c_clk_i   ) ,
         .wr_rst_ni  ( c_rst_ni  ) ,
         .wr_en_i    ( 1'b1   ) ,
         .push_i     ( c_fifo_wave_push_s   [ind_wfifo] ) ,
         .data_i     ( {c_fifo_data_in_r,c_fifo_time_in_r}     ) ,
         .rd_clk_i   ( t_clk_i   ) ,
         .rd_rst_ni  ( t_rst_ni  ) ,
         .rd_en_i    ( time_en ) ,
         .pop_i      ( wave_pop         [ind_wfifo] ) ,
         .data_o     ( {t_fifo_wave_dt[ind_wfifo],t_fifo_wave_time[ind_wfifo]} ) ,
         .flush_i    ( core_rst ),
         .async_empty_o ( t_fifo_wave_empty [ind_wfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_wave_full  [ind_wfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
         ADDSUB_MACRO #(
            .DEVICE     ( "7SERIES" ),                   // Target Device: "7SERIES" 
            .LATENCY    ( 1         ),                   // Desired clock cycle latency, 0-2
            .WIDTH      ( 48        )                    // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( W_RESULT[ind_wfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_r[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .A          ( t_fifo_wave_time[ind_wfifo] ), // Input B bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : WAVE_DISPATCHER
         wave_t_gr[ind_wfifo]  = W_RESULT[ind_wfifo][47];
         wave_pop[ind_wfifo]   = 0;
         wave_pop_prev[ind_wfifo] = wave_pop_r[ind_wfifo] | wave_pop_r2[ind_wfifo] | wave_pop_r3[ind_wfifo]| wave_pop_r4[ind_wfifo];
         if (time_en & ~t_fifo_wave_empty[ind_wfifo])
            if ( wave_t_gr[ind_wfifo] & ~wave_pop_prev[ind_wfifo] ) 
               wave_pop      [ind_wfifo] = 1'b1 ;
      end //ALWAYS
   end // FOR
endgenerate

///////////////////////////////////////////////////////////////////////////////
/// DATA PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_dfifo;
generate
   for (ind_dfifo=0; ind_dfifo < OUT_DPORT_QTY; ind_dfifo=ind_dfifo+1) begin: DATA_FIFO
      // DATA FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (OUT_DPORT_DW+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) data_fifo_inst ( 
         .wr_clk_i   ( c_clk_i      ) ,
         .wr_rst_ni  ( c_rst_ni     ) ,
         .wr_en_i    ( 1'b1      ) ,
         .push_i     ( c_fifo_data_push_s[ind_dfifo] ) ,
         .data_i     ( {c_fifo_data_in_r[OUT_DPORT_DW-1:0],c_fifo_time_in_r}  ) ,
         .rd_clk_i   ( t_clk_i      ) ,
         .rd_rst_ni  ( t_rst_ni     ) ,
         .rd_en_i    ( time_en    ) ,
         .pop_i      ( data_pop        [ind_dfifo] ) ,
         .data_o     ( {t_fifo_data_dt[ind_dfifo], t_fifo_data_time[ind_dfifo]} ) ,
         .flush_i    ( core_rst     ),
         .async_empty_o ( t_fifo_data_empty [ind_dfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_data_full  [ind_dfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
      ADDSUB_MACRO #(
            .DEVICE     ("7SERIES"),        // Target Device: "7SERIES" 
            .LATENCY    ( 1   ),            // Desired clock cycle latency, 0-2
            .WIDTH      ( 48  )             // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( D_RESULT[ind_dfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_r[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .A          ( t_fifo_data_time[ind_dfifo] ), // Input B bus, width defined by WIDTH parameter
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : DATA_DISPATCHER
         data_t_gr[ind_dfifo]  = D_RESULT[ind_dfifo][47];
         data_pop[ind_dfifo] = 0;
         data_pop_prev[ind_dfifo] = data_pop_r[ind_dfifo] | data_pop_r2[ind_dfifo] | data_pop_r3[ind_dfifo] | data_pop_r4[ind_dfifo];
         if (time_en & ~t_fifo_data_empty[ind_dfifo] )
            if ( data_t_gr[ind_dfifo] & ~data_pop_prev[ind_dfifo] ) 
               data_pop      [ind_dfifo] = 1'b1 ;
      end //ALWAYS
   end //FOR      
endgenerate      


///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// OUT TRIGGERS
reg port_trig_r [OUT_TRIG_QTY];
integer ind_tport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_tport=0; ind_tport < OUT_TRIG_QTY; ind_tport=ind_tport+1) begin: OUT_TRIG_PORT
      if (!t_rst_ni) 
         port_trig_r[ind_tport]   <= 1'b0;
      else if (time_rst) 
         port_trig_r[ind_tport]   <= 1'b0;
      else 
        if (trig_pop_r[ind_tport]) port_trig_r[ind_tport] <= t_fifo_trig_dt[ind_tport] ;
   end
end
assign port_trig_o  = port_trig_r;

///////////////////////////////////////////////////////////////////////////////
// OUT DATA
reg [OUT_DPORT_DW-1:0]  port_dt_r [OUT_DPORT_QTY];
integer ind_dport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_dport=0; ind_dport < OUT_DPORT_QTY; ind_dport=ind_dport+1) begin: OUT_DATA_PORT
      if (!t_rst_ni) 
         port_dt_r[ind_dport]   <= '{default:'0} ;
      else if (time_rst) 
         port_dt_r[ind_dport]   <= '{default:'0} ;
      else 
        if (data_pop_r[ind_dport]) port_dt_r[ind_dport] <= t_fifo_data_dt[ind_dport] ;
   end
end
assign port_tvalid_o = data_pop_r;
assign port_tdata_o  = port_dt_r;


///////////////////////////////////////////////////////////////////////////////
// OUT WAVES
// REGISTERED OUTPUT
reg               m_axis_tvalid_r  [ OUT_WPORT_QTY] ;
reg [167:0]       m_axis_tdata_r   [ OUT_WPORT_QTY] ;
integer ind_wport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_wport=0; ind_wport < OUT_WPORT_QTY; ind_wport=ind_wport+1) begin: OUT_WAVE_PORT
      if (!t_rst_ni) begin
         m_axis_tvalid_r[ind_wport]  <= 1'b0 ;
         m_axis_tdata_r [ind_wport]  <= '{default:'0} ;
      end else if (time_rst) begin 
         m_axis_tvalid_r[ind_wport]  <= 1'b0 ;
         m_axis_tdata_r [ind_wport]  <= '{default:'0} ;
      end else begin  
         m_axis_tvalid_r[ind_wport] <= wave_pop_r      [ind_wport] ;
         m_axis_tdata_r[ind_wport]  <= t_fifo_wave_dt [ind_wport] ;
      end
   end
end

assign m_axis_tvalid   = m_axis_tvalid_r ;
assign m_axis_tdata    = m_axis_tdata_r  ;

///////////////////////////////////////////////////////////////////////////////
// NO REGISTERED OUTPUT


///////////////////////////////////////////////////////////////////////////////
// OUT PERIPHERLAS (PERIPH AND QNET)
assign periph_a_dt_o = core_usr_a_dt;
assign periph_b_dt_o = core_usr_b_dt;
assign periph_c_dt_o = core_usr_c_dt;
assign periph_d_dt_o = core_usr_d_dt;
assign periph_addr_o = core_usr_addr;
assign periph_op_o   = core_usr_operation;

///////////////////////////////////////////////////////////////////////////////
///// External Control
assign time_abs_o = time_abs_r ;




///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if (DEBUG == 0) begin : DEBUG_NO
      // DEBUG AXI_REG
      assign xreg_TPROC_STATUS  = 0 ;
      assign xreg_TPROC_DEBUG   = 0 ;
      // DEBUG OUT
      assign ps_debug_do        = 0 ;
      assign t_time_usr_do      = 0 ;
      assign t_debug_do         = 0 ;
      assign t_fifo_do          = 0 ;
      assign c_debug_do         = 0 ;
      assign c_time_ref_do      = 0 ;
      assign c_port_do          = 0 ;
      assign c_core_do          = 0 ;
   end else if   (DEBUG == 1) begin : DEBUG_REG
      // DEBUG AXI_REG
      assign xreg_TPROC_STATUS[31 : 30]   = mem_ctrl_status_ds[1:0] ;
      assign xreg_TPROC_STATUS[29 : 24]   = {6'd0} ;
      assign xreg_TPROC_STATUS[23 : 20]   = { fifo_ok       , wfifo_full     , dfifo_full    , tfifo_full };
      assign xreg_TPROC_STATUS[19 : 16]   = { all_fifo_full , all_wfifo_full , all_dfifo_full, all_tfifo_full };
      assign xreg_TPROC_STATUS[15 : 12]   = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty };
      assign xreg_TPROC_STATUS[11 :  8]   = { flag_c0, axi_flag_r, ext_flag_r, int_flag_r};
      assign xreg_TPROC_STATUS[7  :  4]   = { time_en , time_st[2:0] };
      assign xreg_TPROC_STATUS[3  :  0]   = { core_en , core_st[2:0]};
      assign xreg_TPROC_DEBUG[31: 16]     = mem_ctrl_debug_ds;
      assign xreg_TPROC_DEBUG[15: 8]      = { c_time_ref_dt[7:0]};
      assign xreg_TPROC_DEBUG[ 7: 4]      = { t_fifo_data_dt[0][3:0]};
      assign xreg_TPROC_DEBUG[ 3: 0]      = { t_fifo_data_time[0][3:0]};
      // DEBUG OUT
      assign ps_debug_do       = 0 ;
      assign t_time_usr_do     = 0 ;
      assign t_fifo_do         = 0 ;
      assign t_debug_do        = 0 ;
      assign c_debug_do        = 0 ;
      assign c_time_ref_do     = 0 ;
      assign c_port_do         = 0 ;
      assign c_core_do         = 0 ;
   end else begin : DEBUG_OUT
      // DEBUG AXI_REG
      assign xreg_TPROC_STATUS[31 : 30]   = mem_ctrl_status_ds[1:0] ;
      assign xreg_TPROC_STATUS[29 : 24]   = {6'd0} ;
      assign xreg_TPROC_STATUS[23 : 20]   = { fifo_ok       , wfifo_full     , dfifo_full    , tfifo_full };
      assign xreg_TPROC_STATUS[19 : 16]   = { all_fifo_full , all_wfifo_full , all_dfifo_full, all_tfifo_full };
      assign xreg_TPROC_STATUS[15 : 12]   = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty };
      assign xreg_TPROC_STATUS[11 :  8]   = { flag_c0, axi_flag_r, ext_flag_r, int_flag_r};
      assign xreg_TPROC_STATUS[7  :  4]   = { time_en , time_st[2:0] };
      assign xreg_TPROC_STATUS[3  :  0]   = { core_en , core_st[2:0]};
      assign xreg_TPROC_DEBUG[31: 16]     = mem_ctrl_debug_ds;
      assign xreg_TPROC_DEBUG[15: 8]      = { c_time_ref_dt[7:0]};
      assign xreg_TPROC_DEBUG[ 7: 4]      = { t_fifo_data_dt[0][3:0]};
      assign xreg_TPROC_DEBUG[ 3: 0]      = { t_fifo_data_time[0][3:0]};

      ///// PS_CLOCK Debug Signals   
      assign ps_debug_do[31:28]     = {IF_s_axireg.axi_arready, IF_s_axireg.axi_rready, IF_s_axireg.axi_awready, IF_s_axireg.axi_wready};
      assign ps_debug_do[27:24]     = {IF_s_axireg.axi_arvalid, IF_s_axireg.axi_rvalid, IF_s_axireg.axi_awvalid, IF_s_axireg.axi_wvalid};
      assign ps_debug_do[23:12]     = {IF_s_axireg.axi_araddr[5:0], IF_s_axireg.axi_awaddr[5:0]};
      assign ps_debug_do[11 :0]     = {IF_s_axireg.axi_rdata[5:0], IF_s_axireg.axi_wdata[5:0]};
      ///// T_CLOCK Debug Signals   
      assign t_time_usr_do          = t_time_usr ;
      assign t_fifo_do              = {t_fifo_data_time[0][23:0], t_fifo_data_dt[0][7:0]} ;

      assign t_debug_do[31:27] = { wave_pop_r2[0], data_pop_r2[1], data_pop_r2[0], trig_pop_r2[1], trig_pop_r2[0]  } ;
      assign t_debug_do[26:25] = { c_fifo_wave_empty[1], c_fifo_wave_empty[0] };
      assign t_debug_do[24:23] = { c_fifo_data_empty[1], c_fifo_data_empty[0] };
      assign t_debug_do[22:21] = { c_fifo_trig_empty[1], c_fifo_trig_empty[0] };
      assign t_debug_do[20:17] = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty };
      assign t_debug_do[16:11] = { 6'd0 } ;
      assign t_debug_do[10: 9] = { time_rst, time_en } ;
      assign t_debug_do[ 8: 3] = { ctrl_t_step, ctrl_t_stop, ctrl_t_run, ctrl_t_updt, ctrl_t_init, ctrl_t_rst_run }  ;
      assign t_debug_do[ 2: 0] = { time_st[2:0] };

      ///// C_CLOCK Debug Signals
      assign c_debug_do[31:27] = { c_fifo_wave_push_s[0], c_fifo_data_push_s[1], c_fifo_data_push_s[0], c_fifo_trig_push_s[1], c_fifo_trig_push_s[0]  } ;
      assign c_debug_do[26:25] = { c_fifo_wave_full[1], c_fifo_wave_full[0] };
      assign c_debug_do[24:23] = { c_fifo_data_full[1], c_fifo_data_full[0] };
      assign c_debug_do[22:21] = { c_fifo_trig_full[1], c_fifo_trig_full[0] };
      assign c_debug_do[20:17] = { all_fifo_full, all_wfifo_full, all_dfifo_full, all_tfifo_full };
      assign c_debug_do[16:14] = { wfifo_full, dfifo_full, tfifo_full } ;
      assign t_debug_do[13:11] = { 3'd0 } ;
      assign c_debug_do[10: 9] = { time_rst, time_en } ;
      assign c_debug_do[ 8: 3] = { ctrl_t_step, ctrl_t_stop, ctrl_t_run, ctrl_t_updt, ctrl_t_init, ctrl_t_rst_run }  ;
      assign c_debug_do[ 2: 0] = { time_st[2:0] };

      assign c_proc_do[31:29] = {  flag_c0, |port_dt_new, 1'b0 } ;
      assign c_proc_do[28:17] = sreg_status[11:0];
      assign c_proc_do[16: 8] = core0_cfg[8:0] ;
      assign c_proc_do[ 7: 2] = { int_flag_r, axi_flag_r, int_flag_clr, int_flag_set, axi_flag_clr, axi_flag_set } ;
      assign c_proc_do[ 1: 0] = { time_ref_inc, time_ref_set } ;

      assign c_core_do = core0_ds;
      
   end
endgenerate

endmodule
