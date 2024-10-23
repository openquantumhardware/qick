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
module qproc_ctrl (
// Time, Core and AXI CLK & RST.
   input   wire        t_clk_i         ,
   input   wire        t_rst_ni        ,
   input   wire        c_clk_i         ,
   input   wire        c_rst_ni        ,
   input   wire        ps_clk_i        ,
   input   wire        ps_rst_ni       ,
// External Control  
   input  wire         proc_start_i    ,
   input  wire         proc_stop_i     ,
   input  wire         core_start_i    ,
   input  wire         core_stop_i     ,
   input  wire         time_rst_i      ,
   input  wire         time_updt_i     ,
   input  wire  [31:0] time_updt_dt_i  ,
// Core Control  
   input  wire         int_time_en      , //int_time_pen
   input  wire  [3:0]  int_time_cmd     , //core_usr_operation
   input  wire  [3:0]  int_time_dt     , //core_usr_operation
// AXI  Control  
   input wire [15:0]   xreg_TPROC_CTRL ,
   input wire [15:0]   xreg_TPROC_CFG  ,
   input wire [31:0]   xreg_TPROC_W_DT ,
// QPROC_STATE  
   input wire          all_fifo_full_i ,
// CORE ST
   output reg         core_rst_o        ,
   output reg         core_en_o         ,
// TIME ST
   output reg          time_rst_o        ,
   output reg          time_en_o         ,
   output wire  [47:0]  time_abs_o      ,
   output reg   [47:0]  c_time_ref_o  ,
// DEBUG
   output reg   [ 2:0]  time_st_do ,
   output reg   [ 2:0]  core_st_do ,
   output reg   [ 6:0]  t_debug_do ,
   output reg   [ 6:0]  c_debug_do
);


// Control
reg            t_core_rst_prev_net; // NET Request to RESET the Processor and go to previous state
reg  [31:0]    time_updt_dt            ; // New incremental time value

///////////////////////////////////////////////////////////////////////////////
// CONTROL Signals
///////////////////////////////////////////////////////////////////////////////

/// IO CTRL 
assign proc_start_io  = proc_start_i & xreg_TPROC_CFG[10] ;
assign proc_stop_io   = proc_stop_i  & xreg_TPROC_CFG[10] ;

/// PYTHON
assign time_stop_p     = xreg_TPROC_CTRL[3] | xreg_TPROC_CTRL[9] | proc_stop_io ; // STOP  | P_FREEZE
assign time_run_p      = xreg_TPROC_CTRL[7] | xreg_TPROC_CTRL[8] ; // RUN   | P_PAUSE
assign time_rst_stop_p = xreg_TPROC_CTRL[6] ; //T_RST | START | P_RST
assign time_rst_run_p  = xreg_TPROC_CTRL[0] | xreg_TPROC_CTRL[2] | proc_start_io ; // START | T_RST 
assign time_update_p   = xreg_TPROC_CTRL[1]  ;
assign time_step_p     = xreg_TPROC_CTRL[10] | xreg_TPROC_CTRL[12] ;

assign core_stop_p     = xreg_TPROC_CTRL[3] | xreg_TPROC_CTRL[5] | xreg_TPROC_CTRL[8] | proc_stop_io; // STOP | C_STOP | P_PAUSE
assign core_run_p      = xreg_TPROC_CTRL[7] | xreg_TPROC_CTRL[9] ; // RUN | P_FREEZE
assign core_rst_stop_p = xreg_TPROC_CTRL[6]  ; // P_RST
assign core_rst_run_p  = xreg_TPROC_CTRL[2] | xreg_TPROC_CTRL[4] | proc_start_io ; // START | C_START
assign core_rst_prev_p = xreg_TPROC_CTRL[0]  ; // T_RST
assign core_step_p     = xreg_TPROC_CTRL[10] | xreg_TPROC_CTRL[11] ;

/// QPROC-CORE
assign time_rst_core   = ( int_time_en & int_time_cmd[0]) ;
assign time_updt_core  = ( int_time_en & int_time_cmd[1]) ;
assign time_ref_set    = ( int_time_en & int_time_cmd[2]) ;
assign time_ref_inc    = ( int_time_en & int_time_cmd[3]) ;

/// NET CTRL
assign time_rst_net   = time_rst_i   & ~xreg_TPROC_CFG[9] ;
assign time_updt_net  = time_updt_i  & ~xreg_TPROC_CFG[9] ;
assign core_start_net = core_start_i & ~xreg_TPROC_CFG[9] ;
assign core_stop_net  = core_stop_i  & ~xreg_TPROC_CFG[9] ;

assign c_time_rst_run = time_rst_run_p | time_rst_core  ;
assign c_time_updt    = time_update_p  | time_updt_core ;



///////////////////////////////////////////////////////////////////////////////
// CORE CONTROL
///////////////////////////////////////////////////////////////////////////////

// Store Time_Update_Data from PROCESSOR or PYTHON in offset_dt_r
reg [31:0] offset_dt_r;
always_ff @(posedge c_clk_i)
   if (!c_rst_ni) begin
      offset_dt_r     <= 0;
   end else begin
      if      ( time_updt_core ) offset_dt_r  <= int_time_dt      ; // Update from CORE
      else if ( time_update_p  ) offset_dt_r  <= xreg_TPROC_W_DT ; // Update from PYTHON
   end

assign ctrl_c_rst_stop = core_rst_stop_p  ;
assign ctrl_c_rst_run  = core_start_net | core_rst_run_p ;
assign ctrl_c_stop     = core_stop_net | core_stop_p  ;
assign ctrl_c_run      = core_run_p;
assign ctrl_c_step     = core_step_p ;


// Core Control State Machine
///////////////////////////////////////////////////////////////////////////////
enum {C_RST_STOP=0, C_RST_STOP_WAIT=1, C_RST_RUN=2, C_RST_RUN_WAIT=3, C_STOP=4, C_RUN=5, C_STEP=6, C_END_STEP=7} core_st_nxt, core_st;

//assign core_en = c_core_en  & fifo_ok; 

// Sequential Stante Machine
always_ff @(posedge c_clk_i)
   if (!c_rst_ni)   core_st  <= C_RST_STOP;
   else             core_st  <= core_st_nxt;

// State change and Out
always_comb begin
   core_en_o      = 0;
   core_rst_o       = 0;
   core_st_nxt = core_st;
   //COMMON TRANSITIONS
   if       ( ctrl_c_stop    )  core_st_nxt = C_STOP;
   else if  ( ctrl_c_run     )  core_st_nxt = C_RUN;
   else if  ( ctrl_c_rst_run )  core_st_nxt = C_RST_RUN;
   else if  ( ctrl_c_rst_stop)  core_st_nxt = C_RST_STOP;
   else if  ( ctrl_c_step    )  core_st_nxt = C_STEP;
   //State Transitions and Out
   case (core_st)
      C_RST_RUN : begin
         core_rst_o = 1;            
         if (all_fifo_full_i) core_st_nxt = C_RST_RUN_WAIT;
      end
      C_RST_RUN_WAIT :  
         if (!all_fifo_full_i) core_st_nxt = C_RUN;
      C_RST_STOP : begin
         core_rst_o = 1;            
         if (all_fifo_full_i) core_st_nxt = C_RST_STOP_WAIT;
      end
      C_RST_STOP_WAIT : 
         if (!all_fifo_full_i) core_st_nxt = C_STOP;
      C_RUN: begin
         core_en_o = 1;
      end
      C_STOP: begin
        end
      C_STEP: begin
         core_en_o = 1;
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
assign ctrl_t_updt      = time_updt_net | t_time_update ;
assign ctrl_t_run       = t_time_run ;
assign ctrl_t_stop      = t_time_stop;
assign ctrl_t_step      = t_time_step ;

// Time Control State Machine
///////////////////////////////////////////////////////////////////////////////
enum {T_RST_STOP=0, T_RST_RUN=1, T_UPDT=2,  T_RUN=3, T_STOP=4, T_STEP=5} time_st_nxt, time_st;
// Sequential Stante Machine
always_ff @(posedge t_clk_i)
   if (!t_rst_ni)   time_st  <= T_RST_STOP;
   else             time_st  <= time_st_nxt;
// State change and Out
reg time_updt ;
always_comb begin
   time_en_o     = 0;
   time_rst_o    = 0;
   time_updt   = 0;
   time_st_nxt = time_st;
   //COMMON TRANSITIONS
   if       ( ctrl_t_rst_stop ) time_st_nxt = T_RST_STOP  ;
   if       ( ctrl_t_rst_run  ) time_st_nxt = T_RST_RUN  ;
   else if  ( ctrl_t_updt     ) time_st_nxt = T_UPDT ;
   else if  ( ctrl_t_run      ) time_st_nxt = T_RUN ;
   else if  ( ctrl_t_stop     ) time_st_nxt = T_STOP ;
   else if  ( ctrl_t_step     ) time_st_nxt = T_STEP ;
   case (time_st)
      T_RST_STOP : begin
         time_en_o = 1;
         time_rst_o = 1;
         time_st_nxt = T_STOP ;
      end
      T_RST_RUN : begin
         time_en_o = 1;
         time_rst_o = 1;
         time_st_nxt = T_RUN ;
      end
      T_UPDT : begin
         time_en_o = 1;
         time_updt = 1;
         time_st_nxt = T_RUN ;
      end
      T_RUN: begin
         time_en_o = 1;
      end
      T_STEP: begin
         time_en_o = 1;
         time_st_nxt = T_STOP ;
      end
   endcase
end


// Time REF
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)            c_time_ref_o    <= '{default:'0} ;
   else if  (core_rst)       c_time_ref_o    <= '{default:'0} ;
   else if  (time_ref_set )  c_time_ref_o    <=  {16'd0, int_time_dt} ;
   else if  (time_ref_inc )  c_time_ref_o    <=  c_time_ref_o + {16'd0, int_time_dt} ;
end

// Time ABS
///////////////////////////////////////////////////////////////////////////////
qproc_time_ctrl QTIME_CTRL ( 
   .t_clk_i       ( t_clk_i      ) ,
   .t_rst_ni      ( t_rst_ni     ) ,
   .time_en_i     ( time_en_o    ) ,
   .time_rst_i    ( time_rst_o   ) ,
   .time_updt_i   ( time_updt    ) ,
   .updt_dt_i     ( time_updt_dt ) ,
   .time_abs_o    ( time_abs     ) );
   
assign c_debug_do   = { 1'b0, ctrl_c_step, ctrl_c_stop, ctrl_c_run, ctrl_c_rst_run, ctrl_c_rst_stop }  ;
assign t_debug_do   = { ctrl_t_updt, 1'b0, ctrl_t_step, ctrl_t_stop, ctrl_t_run, ctrl_t_rst_run, ctrl_t_rst_stop }  ;

endmodule
