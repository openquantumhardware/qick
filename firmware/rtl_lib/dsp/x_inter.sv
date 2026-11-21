///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  X-Interpolator
//  Faithful port from qick_time_tagger's _qtt_ips.sv (module x_inter).
//  Bit-serial restoring divider used to refine a threshold-crossing
//  timestamp between two filtered samples: computes, over cfg_inter_i
//  cycles, x_int_o = floor( ((thr_i - prev_i) << cfg_inter_i) / (curr_i - prev_i) ),
//  valid for prev_i <= thr_i <= curr_i.
///////////////////////////////////////////////////////////////////////////////

module x_inter #(
   parameter int DW = 16 ,
   parameter int IW = 4
) (
   input  wire             clk_i   ,
   input  wire             rst_ni  ,
   input  wire             start_i ,
   input  wire [2:0]       cfg_inter_i      ,
   input  wire [DW-1:0]    curr_i  ,
   input  wire [DW-1:0]    prev_i  ,
   input  wire [DW-1:0]    thr_i   ,
   output wire             end_o   ,
   output wire             ready_o ,
   output wire [IW-1:0]    x_int_o );

// Registers
reg [IW+DW-1:0] sub_temp, r_temp, r_temp_nxt;
reg [DW-1:0]   in_b       ;
reg [IW-1:0]   q_temp;
reg [2:0]      ind_bit;
reg            working, qtb;

wire [2:0]     ind_bit_m1 ;
wire           div_start, div_end;

assign ind_bit_m1 = ind_bit - 1'b1;
assign div_start  = start_i;
assign div_end    = (ind_bit==0) ;


// State Machine
///////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_WORKING } div_st_e;
div_st_e div_st, div_st_nxt;
always_ff @(posedge clk_i)
   if (!rst_ni)     div_st  <= ST_IDLE;
   else             div_st  <= div_st_nxt;

always_comb begin
   div_st_nxt  = div_st;
   working     = 1'b0;
   unique case (div_st)
      ST_IDLE: begin
         if ( div_start )    div_st_nxt = ST_WORKING;
      end
      ST_WORKING: begin
         working = 1'b1;
         if ( div_end ) begin
            div_st_nxt = ST_IDLE;
         end
      end
   endcase
end

always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin
      ind_bit     <= -1;
      q_temp      <= 0 ;
      r_temp      <= 0 ;
      in_b        <= 0 ;
   end else if (div_start) begin
      ind_bit     <= cfg_inter_i;
      q_temp      <= 0 ;
      r_temp      <= ( (thr_i - prev_i)  << cfg_inter_i);
      in_b        <= ( curr_i - prev_i );
   end else if (working) begin
      ind_bit            <= ind_bit_m1;
      r_temp             <= r_temp_nxt   ;
      q_temp[ind_bit_m1] <= qtb   ;
  end
end

///////////////////////////////////////////////////////////////////////////
always_comb begin
   qtb         = 1'b0;
   r_temp_nxt  = r_temp ;
   sub_temp    = in_b << ind_bit_m1  ;
   if (r_temp >= sub_temp ) begin
      qtb        = 1'b1 ;
      r_temp_nxt = r_temp  - sub_temp ;
   end else
      r_temp_nxt = r_temp;
end

// OUT
///////////////////////////////////////////////////////////////////////////
assign x_int_o = q_temp;
assign ready_o = ~working;
assign end_o   = div_end;

endmodule
