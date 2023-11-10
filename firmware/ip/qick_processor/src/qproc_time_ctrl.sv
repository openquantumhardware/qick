///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 11-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 
   Controls the Time Counter. time_abs_o
*/
//////////////////////////////////////////////////////////////////////////////

module qproc_time_ctrl ( 
   input  wire            t_clk_i      ,
   input  wire            t_rst_ni     ,
   input  wire            time_en_i    , // Time RUNS
   input  wire            time_rst_i   , // Set Time to 0
   input  wire            time_init_i  , // Set Time to current OFFSET
   input  wire            time_updt_i  , // Increment Time updt_dt_i
   input  wire  [31:0]    updt_dt_i    , 
   output wire  [47:0]    time_abs_o   );

// Time ABS
///////////////////////////////////////////////////////////////////////////////
reg [47:0] time_abs;

wire[47:0] time_update_dt;
assign time_update_dt = { { 16{updt_dt_i[31]} } ,updt_dt_i}; //Sign Extend updt_dt_i


enum {ST_IDLE, ST_RESET, ST_INIT, ST_LOAD_OFFSET, ST_INCREMENT, ST_UPDATE } ctrl_time_st, ctrl_time_st_nxt;

////////// Sequential Logic
always @ (posedge t_clk_i) begin : CTRL_SYNC_PROC
   if (!t_rst_ni)    ctrl_time_st <=  ST_IDLE;
   else              ctrl_time_st <=  ctrl_time_st_nxt;
end

////////// Comb Logic - Outputs and State
reg  [47:0] time_inc;
reg  [47:0] initial_offset;
wire [47:0] updated_offset ;
reg time_cnt_en, time_c_in;

wire time_cnt_rst;
assign time_cnt_rst = time_rst_i | time_init_i ;


always_comb begin : CTRL_ST_AND_OUTPUT_DECODE
   time_cnt_en = 1'b0;
   time_inc    = 1'b0;
   time_c_in   = 1'b0;

   ctrl_time_st_nxt  = ctrl_time_st; // Default Current State
   case (ctrl_time_st)
      ST_IDLE : begin
         if      ( time_rst_i  )  ctrl_time_st_nxt = ST_RESET;
         else if ( time_init_i )  ctrl_time_st_nxt = ST_INIT;
         else if ( time_updt_i )  ctrl_time_st_nxt = ST_UPDATE;
         else if ( time_en_i   )  ctrl_time_st_nxt = ST_INCREMENT;
      end
      ST_RESET : begin
         if ( time_en_i )
            ctrl_time_st_nxt = ST_INCREMENT;
         else
            ctrl_time_st_nxt = ST_IDLE;
      end
      ST_INIT : begin
         time_cnt_en       = 1'b1;
         ctrl_time_st_nxt  = ST_LOAD_OFFSET;
      end
      ST_LOAD_OFFSET : begin
         time_cnt_en       = 1'b1;
         time_inc          = updt_dt_i ;
         ctrl_time_st_nxt  = ST_INCREMENT;
      end
      ST_INCREMENT : begin
         time_cnt_en  = 1'b1;
         time_inc     = 48'd1 ;
         if       ( time_rst_i   )  ctrl_time_st_nxt = ST_RESET;
         else if  ( time_init_i  )  ctrl_time_st_nxt = ST_INIT;
         else if  ( time_updt_i  )  ctrl_time_st_nxt = ST_UPDATE;
         else if  ( !time_en_i   )  ctrl_time_st_nxt = ST_IDLE;
      end
      ST_UPDATE : begin
         time_cnt_en  = 1'b1;
         time_inc     = time_update_dt ;
         time_c_in    = 1'b1;
         ctrl_time_st_nxt = ST_INCREMENT;
      end
   endcase 
end


// Time Operation
   ADDSUB_MACRO #(
         .DEVICE     ("7SERIES"),        // Target Device: "7SERIES" 
         .LATENCY    ( 1   ),            // Desired clock cycle latency, 0-2
         .WIDTH      ( 48  )             // Input / output bus width, 1-48
      ) TIME_ADDER (
         .CARRYOUT   (                   ), // 1-bit carry-out output signal
         .RESULT     ( time_abs          ), // Add/sub result output, width defined by WIDTH parameter
         .B          ( time_abs          ), // Input A bus, width defined by WIDTH parameter
         .ADD_SUB    ( 1'b1              ), // 1-bit add/sub input, high selects add, low selects subtract
         .A          ( time_inc          ), // Input B bus, width defined by WIDTH parameter
         .CARRYIN    ( time_c_in         ), // 1-bit carry-in input
         .CE         ( time_cnt_en | time_cnt_rst        ), // 1-bit clock enable input
         .CLK        ( t_clk_i           ), // 1-bit clock input
         .RST        ( time_cnt_rst      )  // 1-bit active high synchronous reset
      );
   
assign time_abs_o = time_abs;

endmodule

