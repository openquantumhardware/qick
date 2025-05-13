///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_qctrl.sv
// Project: QICK 
// Description: 
// Control block to instruct the tproc to start/stop internal processing.
// 
//Inputs:
// - i_clk       clock signal
// - i_rstn      active low reset signal
// - i_sync      synchronization signal. Lets the core synchronize with an
//               external signal. 
// - i_ctrl_req  control requirement signal.
// - i_ctrl_data control code to execute when there is a i_ctrl_req
//               requirement.  
// - i sync_req  synchronization requirement signal. 
//Outputs:
//The ouput signals in this core instruct the tproc to start/stop internal
//processing
// - o_proc_start processor start signal
// - o_proc_stop  processor stop signal
// - o_time_start time start signal
// - o_time_stop  time stop signal
// - o_core_start core start signal
// - o_core_stop  core stop signal
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/13/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_qctrl (
   input  logic         i_clk        ,
   input  logic         i_rstn       ,
   input  logic         i_sync       ,
   input  logic         i_ctrl_req   ,
   input  logic [3-1:0] i_ctrl_data  ,
   input  logic         i_sync_req   ,
// TPROC CONTROL
   output logic         o_proc_start ,
   output logic         o_proc_stop  ,
   output logic         o_time_rst   ,
   output logic         o_time_update,
   output logic         o_core_start ,
   output logic         o_core_stop     
);

logic [3-1:0] qctrl_cnt;
logic         qctrl_en;
logic         qctrl_pulse_end;
logic         s_proc_start, s_proc_stop;
logic         s_core_start, s_core_stop;
logic         s_time_rst, s_time_update;
logic         i_sync_dly ;
logic         s_sync ;

typedef enum logic [2-1:0]{ IDLE      = 2'b00, 
                            WSYNC     = 2'b01, 
                            EXEC_RST  = 2'b10, 
                            EXEC_CTRL = 2'b11 
} state_t;
state_t state_r, state_n;

// PULSE SYNC 
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if (!i_rstn) i_sync_dly <= 1'b0; 
   else         i_sync_dly <= i_sync;
end

assign s_sync = !i_sync_dly & i_sync ;

assign qctrl_pulse_end = (qctrl_cnt == '1);

// PROCESSOR CONTROL
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if   ( !i_rstn ) state_r <= IDLE;
   else             state_r <= state_n;
end

always_comb begin
   state_n       = state_r; 
   s_proc_start  = 1'b0;
   s_proc_stop   = 1'b0;
   s_time_rst    = 1'b0;
   s_time_update = 1'b0;
   s_core_start  = 1'b0;
   s_core_stop   = 1'b0;
   qctrl_en      = 1'b0;
   case (state_r)
      IDLE: 
         if      ( i_sync_req ) state_n = WSYNC;
         else if ( i_ctrl_req ) state_n = EXEC_CTRL;     

      WSYNC: begin
         if ( s_sync ) state_n = EXEC_RST;     
      end

      EXEC_RST: begin
         s_proc_start = 1'b1;
         qctrl_en     = 1'b1;
         if ( qctrl_pulse_end ) state_n = IDLE;     
      end

      EXEC_CTRL: begin
         qctrl_en  = 1'b1;
         case ( i_ctrl_data )
            3'b010  : s_time_rst    = 1'b1;
            3'b011  : s_time_update = 1'b1;
            3'b100  : s_core_start  = 1'b1;
            3'b101  : s_core_stop   = 1'b1;
            3'b110  : s_proc_start  = 1'b1;
            3'b111  : s_proc_stop   = 1'b1;
         endcase
         if ( qctrl_pulse_end ) state_n = IDLE;     
      end

      default: state_n = state_r;
   endcase
end

always_ff @ (posedge i_clk) begin
   if      ( !i_rstn  ) qctrl_cnt  <= 0;
   else if ( qctrl_en ) qctrl_cnt  <= qctrl_cnt+1'b1;
   else                 qctrl_cnt  <= 0;
end

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_proc_start  = s_proc_start;
assign o_proc_stop   = s_proc_stop;
assign o_core_start  = s_core_start;
assign o_core_stop   = s_core_stop;
assign o_time_rst    = s_time_rst;
assign o_time_update = s_time_update;

endmodule
