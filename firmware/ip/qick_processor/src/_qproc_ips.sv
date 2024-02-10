///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  qick_processor tProc_v2
/* Description: 
IPs used in the design of the qick_processor
*/
//////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// DUAL PORT RAM
///////////////////////////////////////////////////////////////////////////////
module bram_dual_port_dc # (
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 ,
   parameter RAM_OUT  = "NO_REGISTERED" // Select "NO_REGISTERED" or "REGISTERED" 
) ( 
   input  wire               clk_a_i  ,
   input  wire               en_a_i  ,
   input  wire               we_a_i  ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i  ,
   output wire [MEM_DW-1:0]  dt_a_o  ,
   input  wire               clk_b_i  ,
   input  wire               en_b_i  ,
   input  wire               we_b_i  ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   input  wire [MEM_DW-1:0]  dt_b_i  ,
   output wire [MEM_DW-1:0]  dt_b_o  );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] RAM [RAM_SIZE];
reg [MEM_DW-1:0] ram_dt_a = {MEM_DW{1'b0}};
reg [MEM_DW-1:0] ram_dt_b = {MEM_DW{1'b0}};

always @(posedge clk_a_i)
   if (en_a_i) begin
      ram_dt_a <= RAM[addr_a_i] ;
      if (we_a_i)
         RAM[addr_a_i] <= dt_a_i;
      //else
      //   ram_dt_a <= RAM[addr_a_i] ;
   end
always @(posedge clk_b_i)
   if (en_b_i)
      if (we_b_i)
         RAM[addr_b_i] <= dt_b_i;
      else
         ram_dt_b <= RAM[addr_b_i] ;

generate
   if (RAM_OUT == "NO_REGISTERED") begin: no_output_register // 1 clock cycle read
      assign dt_a_o = ram_dt_a ;
      assign dt_b_o = ram_dt_b ;
   end else begin: output_register // 2 clock cycle read
      reg [MEM_DW-1:0] ram_dt_a_r = {MEM_DW{1'b0}};
      reg [MEM_DW-1:0] ram_dt_b_r = {MEM_DW{1'b0}};
      always @(posedge clk_a_i) ram_dt_a_r <= ram_dt_a;
      always @(posedge clk_b_i) ram_dt_b_r <= ram_dt_b;
      assign dt_a_o = ram_dt_a_r ;
      assign dt_b_o = ram_dt_b_r ;
   end
endgenerate

endmodule


///////////////////////////////////////////////////////////////////////////////
// LIFO
///////////////////////////////////////////////////////////////////////////////
module LIFO # (
   parameter WIDTH = 16 , 
   parameter DEPTH = 8    // MAX 8
) ( 
   input  wire                   clk_i    ,
   input  wire                   rst_ni   ,
   input  wire  [WIDTH - 1:0]    data_i   ,
   input  wire                   push     ,
   input  wire                   pop      ,
   output wire  [WIDTH - 1:0]    data_o   ,
   output wire                   full_o   );

wire [2:0]        ptr_p1, ptr_m1 ;
reg  [2:0]        ptr            ;
reg  [WIDTH-1:0]  stack [DEPTH]  ;

assign ptr_p1 = ptr + 1'b1;
assign ptr_m1 = ptr - 1'b1;

// Pointer
always_ff @(posedge clk_i) begin
   if (!rst_ni)      ptr <= 0;
   else if (push & !full_o) ptr <= ptr_p1;
   else if (pop  & !empty_o) ptr <= ptr_m1;
end

// Data
always_ff @(posedge clk_i) begin
   if (!rst_ni)   stack      <= '{default:'0} ;
   if(push & !full_o)       stack[ptr] <= data_i ;
end

assign empty_o = !(|ptr)      ;
assign full_o  = !(|(ptr ^ DEPTH));
assign data_o = stack[ptr_m1];

endmodule


///////////////////////////////////////////////////////////////////////////////
/// SYNC - Clock Domain Change
///////////////////////////////////////////////////////////////////////////////
module sync_reg # (
   parameter DW  = 32
)(
   input  wire [DW-1:0] dt_i     , 
   input  wire          clk_i    ,
   input  wire          rst_ni   ,
   output wire [DW-1:0] dt_o     );
   
// FAST REGISTER GRAY TRANSFORM OF INPUT
(* ASYNC_REG = "TRUE" *) reg [DW-1:0] data_cdc, data_r ;
always_ff @(posedge clk_i)
   if(!rst_ni) begin
      data_cdc  <= 0;
      data_r    <= 0;
   end else begin 
      data_cdc  <= dt_i;
      data_r    <= data_cdc;
      end
assign dt_o = data_r ;

endmodule

///////////////////////////////////////////////////////////////////////////////
//GRAY CODE COUNTER
///////////////////////////////////////////////////////////////////////////////
module gcc # (
   parameter DW  = 32
)(
   input  wire          clk_i          ,
   input  wire          rst_ni         ,
   input  wire          async_clear_i  ,
   output wire          clear_o        ,
   input  wire          cnt_en_i       ,
   output wire [DW-1:0] count_bin_o    , 
   output wire [DW-1:0] count_gray_o   ,
   output wire [DW-1:0] count_bin_p1_o , 
   output wire [DW-1:0] count_gray_p1_o);
   
reg [DW-1:0] count_bin  ;    // count turned into binary number
wire [DW-1:0] count_bin_p1; // count_bin+1

reg [DW-1:0] count_bin_r, count_gray_r;

integer ind;
always_comb begin
   count_bin[DW-1] = count_gray_r[DW-1];
   for (ind=DW-2 ; ind>=0; ind=ind-1) begin
      count_bin[ind] = count_bin[ind+1]^count_gray_r[ind];
   end
end

(* ASYNC_REG = "TRUE" *) reg clear_cdc, clear_r;
always_ff @(posedge clk_i, negedge rst_ni)
   if(!rst_ni) begin
      clear_cdc       <= 0;
      clear_r         <= 0;
   end else begin
      clear_cdc       <= async_clear_i;
      clear_r         <= clear_cdc;
   end
   
assign count_bin_p1 = count_bin + 1 ; 

reg [DW-1:0] count_bin_2r, count_gray_2r;
always_ff @(posedge clk_i, negedge rst_ni)
   if(!rst_ni) begin
      count_gray_r      <= 1;
      count_bin_r       <= 1;
      count_gray_2r     <= 0;
      count_bin_2r      <= 0;
   end else begin
      if (clear_r) begin
         count_gray_r      <= 1;
         count_bin_r       <= 1;
         count_gray_2r     <= 0;
         count_bin_2r      <= 0;
      end else if (cnt_en_i) begin
         count_gray_r   <= count_bin_p1 ^ {1'b0,count_bin_p1[DW-1:1]};
         count_bin_r    <= count_bin_p1;
         count_gray_2r  <= count_gray_r;
         count_bin_2r   <= count_bin_r;
      
      end
  end

assign clear_o          = clear_r ;
assign count_bin_o      = count_bin_2r ;
assign count_gray_o     = count_gray_2r ;
assign count_bin_p1_o   = count_bin_r ;
assign count_gray_p1_o  = count_gray_r ;

endmodule


///////////////////////////////////////////////////////////////////////////////
// FIFO DUAL CLOCK
///////////////////////////////////////////////////////////////////////////////
module BRAM_FIFO_DC_2 # (
   parameter FIFO_DW = 16 , 
   parameter FIFO_AW = 8 
) ( 
   input  wire                   wr_clk_i       ,
   input  wire                   wr_rst_ni      ,
   input  wire                   wr_en_i        ,
   input  wire                   push_i         ,
   input  wire [FIFO_DW - 1:0]   data_i         ,
   input  wire                   rd_clk_i       ,
   input  wire                   rd_rst_ni      ,
   input  wire                   rd_en_i        ,
   input  wire                   pop_i          ,
   output wire  [FIFO_DW - 1:0]  data_o         ,
   input  wire                   flush_i        ,
   output wire                   async_empty_o  ,
   output wire                   async_full_o   );

// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value
wire [FIFO_AW-1:0]   rd_gptr_p1   ;
wire [FIFO_AW-1:0]   wr_gptr_p1   ;
wire [FIFO_AW-1:0]   rd_gptr, wr_gptr  ;
wire                 clr_wr, clr_rd;
reg                  async_empty_r;
wire                 busy;
wire [FIFO_DW - 1:0] mem_dt;
wire                 async_empty, async_full;

// Sample Pointers
(* ASYNC_REG = "TRUE" *) reg [FIFO_AW-1:0] wr_gptr_cdc, wr_gptr_r; 
always_ff @(posedge rd_clk_i) begin
   wr_gptr_cdc      <= wr_gptr;
   wr_gptr_r        <= wr_gptr_cdc;
   async_empty_r    <= async_empty;
end

(* ASYNC_REG = "TRUE" *) reg [FIFO_AW-1:0] rd_gptr_cdc, rd_gptr_r; 
always_ff @(posedge wr_clk_i) begin
   rd_gptr_cdc      <= rd_gptr;
   rd_gptr_r        <= rd_gptr_cdc;
end

reg clr_fifo_req, clr_fifo_ack;
always_ff @(posedge wr_clk_i, negedge wr_rst_ni) begin
   if (!wr_rst_ni) begin
      clr_fifo_req <= 0 ;
      clr_fifo_ack <= 0 ;
   end else begin
      if (flush_i) 
         clr_fifo_req <= 1 ;
      else if (clr_fifo_ack )
         clr_fifo_req <= 0 ;

      if (clr_rd & clr_wr) 
          clr_fifo_ack <= 1 ;
      else if (clr_fifo_ack & !clr_rd & !clr_wr)
          clr_fifo_ack <= 0 ;
   end
end

assign busy = clr_fifo_ack | clr_fifo_req ;

//SYNC with POP (RD_CLK)
assign async_empty   = (rd_gptr == wr_gptr_r) ;   

//SYNC with PUSH (WR_CLK)
assign async_full    = (rd_gptr_r == wr_gptr_p1) ;

wire do_pop, do_push;
assign do_pop  = pop_i & !async_empty;
assign do_push = wr_en_i & push_i & !async_full;

//assign async_empty_o = async_empty | busy; // While RESETTING, Shows EMPTY
assign async_empty_o = async_empty_r | busy; // While RESETTING, Shows EMPTY

assign async_full_o  = async_full  | busy;
assign data_o  = mem_dt;

gcc #(
   .DW	( FIFO_AW )
) gcc_wr_ptr  (
   .clk_i            ( wr_clk_i     ) ,
   .rst_ni           ( wr_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req      ) ,
   .clear_o          ( clr_wr       ) ,
   .cnt_en_i         ( do_push      ) ,
   .count_bin_o      (     ) ,
   .count_gray_o     ( wr_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( wr_gptr_p1   ) );

gcc #(
   .DW	( FIFO_AW )
) gcc_rd_ptr (
   .clk_i            ( rd_clk_i     ) ,
   .rst_ni           ( rd_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req      ) ,
   .clear_o          ( clr_rd       ) ,
   .cnt_en_i         ( do_pop       ) ,
   .count_bin_o      (     ) ,
   .count_gray_o     ( rd_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( rd_gptr_p1   ) );

// Data
bram_dual_port_dc  # (
   .MEM_AW  ( FIFO_AW     )  , 
   .MEM_DW  ( FIFO_DW     )  ,
   //.RAM_OUT ( "NO_REGISTERED" ) // Select "NO_REGISTERED" or "REGISTERED" 
   .RAM_OUT ( "REGISTERED" ) // Select "NO_REGISTERED" or "REGISTERED" 
) fifo_mem ( 
   .clk_a_i    ( wr_clk_i  ) ,
   .en_a_i     ( wr_en_i   ) ,
   .we_a_i     ( do_push   ) ,
   .addr_a_i   ( wr_gptr    ) ,
   .dt_a_i     ( data_i    ) ,
   .dt_a_o     ( ) ,
   .clk_b_i    ( rd_clk_i  ) ,
   .en_b_i     ( rd_en_i   ) ,
   .we_b_i     ( 1'b0      ) ,
   .addr_b_i   ( rd_gptr    ) ,
   .dt_b_i     (     ) ,
   .dt_b_o     ( mem_dt    ) );
   
endmodule


///////////////////////////////////////////////////////////////////////////////
// TWO inputs ALU
//////////////////////////////////////////////////////////////////////////////
module AB_alu (
   input  wire                clk_i    ,
   input  wire signed [31:0]  A_i      ,
   input  wire signed [31:0]  B_i      ,
   input  wire [3:0]          alu_op_i ,
   output wire                Z_o      ,
   output wire                C_o      ,
   output wire                S_o      ,
   output wire signed [31:0]  alu_result_o );

reg [32:0]  result;
wire zero_flag, carry_flag, sign_flag;

//    << .... Left shift   (i.e. a << 2 shifts a two bits to the left)
//    <<< ... Left shift and fill with zeroes
//    >> .... Right shift (i.e. b >> 1 shifts b one bits to the right)
//    >>> ... Right shift and maintain sign bit
			
/*
reg [2:0] shift;
always_comb begin
      case ( B_i[3:0] )
         4'b0001: shift  = 1  ; // 1
         4'b0010: shift  = 2  ; // 2
         4'b0100: shift  = 4  ; // 4
         4'b1000: shift  = 8  ; // 8 
         default: shift  = 0  ; //Others
     endcase
end
*/
wire[3:0] shift ;
assign shift = B_i[3:0];

wire [31:0] neg_B, a_plus_b, a_minus_b, abs_b;
wire [31:0] msh_a, lsh_a, swap_a;  

assign neg_B      = -B_i ;
assign a_plus_b   = A_i + B_i;
assign a_minus_b  = A_i + neg_B;
assign abs_b      = B_i[31] ? neg_B : B_i;
assign msh_a      = {16'b00000000_00000000, A_i[31:16]} ;
assign lsh_a      = {16'b00000000_00000000, A_i[15: 0]} ;
assign swap_a     = {A_i[15:0], A_i[31:16]} ;

wire [31:0] a_cat_b, a_sl_b, a_lsr_b, a_asr_b ;
assign a_cat_b    = {A_i[15:0], B_i[15:0]};
assign a_sl_b     = A_i <<  shift ;
assign a_lsr_b    = A_i >>  shift ;
assign a_asr_b    = A_i >>> shift ;

always_comb begin
   if (~alu_op_i[0])
      // ARITHMETIC
      case ( alu_op_i[3:1] )
         3'b000: result = a_plus_b  ;
         3'b001: result = a_minus_b ;
         3'b010: result = A_i & B_i   ;
         3'b011: result = a_asr_b ;
         3'b100: result = abs_b ;
         3'b101: result = msh_a    ;
         3'b110: result = lsh_a   ;
         3'b111: result = swap_a   ;
      endcase
   else
      // LOGIC
      case ( alu_op_i[3:1] )
         3'b000: result = ~A_i      ;
         3'b001: result = A_i | B_i ;
         3'b010: result = A_i ^ B_i ;
         3'b011: result = a_cat_b ;
         3'b100: result = 0         ;
         3'b101: result = {31'd0, ^A_i}      ;
         3'b110: result =  a_sl_b  ;
         3'b111: result =  a_lsr_b  ;
      endcase
end

assign zero_flag  = (result == 0) ;
assign carry_flag = result[32];
assign sign_flag  = result[31];

assign alu_result_o  = result[31:0] ;
assign Z_o           = zero_flag ;
assign C_o           = carry_flag ;
assign S_o           = sign_flag ;

endmodule

////////////////////////////////////////////////////////////////////////////////
// DIVISION Pipelined 32 BIT integer
///////////////////////////////////////////////////////////////////////////////
module div_r #(
   parameter DW      = 32 ,
   parameter N_PIPE  = 32 
) (
   input  wire             clk_i           ,
   input  wire             rst_ni          ,
   input  wire             start_i         ,
   input  wire [DW-1:0]    A_i             ,
   input  wire [DW-1:0]    B_i             ,
   output wire             ready_o         ,
   output wire [DW-1:0]    div_quotient_o  ,
   output wire [DW-1:0]    div_remainder_o );

localparam comb_per_reg = DW / N_PIPE;

reg [DW-1     : 0 ] inB     ;
reg [DW-1     : 0 ] q_temp     ;
reg [DW-1     : 0 ] r_temp     [N_PIPE] ;
reg [DW-1     : 0 ] r_temp_nxt [N_PIPE] ;
reg [2*DW-1 : 0 ] sub_temp [N_PIPE] ;

integer ind_comb_stage [N_PIPE];
integer ind_bit[N_PIPE]; 

wire working;
reg  [N_PIPE-1:0] en_r  ;

assign working    = |en_r;


always_ff @ (posedge clk_i, negedge rst_ni) begin
   if (!rst_ni) begin        
      en_r      <= 0 ;
      r_temp[0] <= 0 ;
      inB       <= 0 ;
   end else
      if (start_i) begin
         en_r           <= {en_r[N_PIPE-2:0], 1'b1} ;
         r_temp   [0]   <= A_i ;
         inB            <= B_i ;
      end else if (working)
         en_r           <= {en_r[N_PIPE-2:0], 1'b0} ;
end // Always


///////////////////////////////////////////////////////////////////////////
// FIRST STAGE
always @ (r_temp[0], r_temp_nxt[0], inB) begin
   r_temp_nxt[0] = r_temp[0];
   for (ind_comb_stage[0]=0; ind_comb_stage[0] < comb_per_reg ; ind_comb_stage[0]=ind_comb_stage[0]+1) begin
      ind_bit[0] = (DW-1) - ( ind_comb_stage[0] ) ;
      sub_temp[0] = inB << ind_bit[0] ;
      if (r_temp_nxt[0] >= sub_temp[0]) begin
         q_temp [ind_bit[0]]  = 1'b1 ;
         r_temp_nxt[0] = r_temp_nxt[0] - sub_temp[0];
      end else 
         q_temp [ind_bit[0]] = 1'b0;
   end
end

genvar ind_reg_stage;
for (ind_reg_stage=1; ind_reg_stage < N_PIPE ; ind_reg_stage=ind_reg_stage+1) begin
   // SEQUENCIAL PART
   always_ff @ (posedge clk_i) begin 
      r_temp   [ind_reg_stage]   = r_temp_nxt   [ind_reg_stage-1] ;
   end
   // COMBINATORIAL PART
   always_comb begin
      r_temp_nxt[ind_reg_stage] = r_temp[ind_reg_stage];
      for (ind_comb_stage[ind_reg_stage]=0; ind_comb_stage[ind_reg_stage] < comb_per_reg ; ind_comb_stage[ind_reg_stage]=ind_comb_stage[ind_reg_stage]+1) begin
         ind_bit[ind_reg_stage] = (DW-1) - (ind_comb_stage[ind_reg_stage] + (ind_reg_stage * comb_per_reg)) ;
         sub_temp[ind_reg_stage] = inB << ind_bit[ind_reg_stage] ;
         if (r_temp_nxt[ind_reg_stage] >= sub_temp[ind_reg_stage]) begin
            q_temp [ind_bit[ind_reg_stage]]  = 1'b1 ;
            r_temp_nxt[ind_reg_stage] = r_temp_nxt[ind_reg_stage] - sub_temp[ind_reg_stage];
         end else 
            q_temp [ind_bit[ind_reg_stage]] = 1'b0;
      end
   end
end

assign ready_o          = ~working;
assign div_quotient_o   = q_temp;
assign div_remainder_o  = r_temp_nxt[N_PIPE-1];

endmodule


///////////////////////////////////////////////////////////////////////////////
// DSP ARITH BLOCK
///////////////////////////////////////////////////////////////////////////////
module arith (
   input  wire                clk_i          ,
   input  wire                rst_ni         ,
   input  wire                start_i        ,
   input  wire signed [31:0]  A_i            ,
   input  wire signed [31:0]  B_i            ,
   input  wire signed [31:0]  C_i            ,
   input  wire signed [31:0]  D_i            ,
   input  wire [4:0]          alu_op_i       ,
   output wire                ready_o        ,
   output wire signed [63:0]  arith_result_o );

// DSP OUTPUTS
wire [45:0] arith_result ;
// DSP INPUTS
reg  [3:0] ALU_OP  ;

reg signed [26:0] A_dt ; 
reg signed [17:0] B_dt ; 
reg signed [31:0] C_dt ; 
reg signed [26:0] D_dt ; 
reg working, working_r, working_r2, working_r3 ;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if (!rst_ni) begin
         A_dt        <= 0;
         B_dt        <= 0;
         C_dt        <= 0;
         D_dt        <= 0; 
         ALU_OP      <= 0;
         working     <= 1'b0 ;
         working_r   <= 1'b0 ;
         working_r2  <= 1'b0 ;
         working_r3  <= 1'b0 ;
   end else begin
      working_r  <= working ;
      working_r2  <= working_r ;
      working_r3  <= working_r2 ;
      if (start_i) begin
         A_dt     <= A_i[26:0] ;
         B_dt     <= B_i[17:0] ;
         C_dt     <= C_i[31:0] ;
         D_dt     <= D_i[26:0] ; 
         ALU_OP   <= { alu_op_i[3:0]}  ;
         working  <= 1'b1 ;
      end else if (working_r3) begin
         working            <= 1'b0;
         working_r          <= 1'b0;
         working_r2         <= 1'b0;
         working_r3         <= 1'b0;
         
      end
   end
end


dsp_macro_0 ARITH_DSP (
  .CLK  ( clk_i        ),  // input wire CLK
  .SEL  ( ALU_OP       ),  // input wire [3 : 0] SEL
  .A    ( A_dt[26:0]   ),  // input wire [26 : 0] A
  .B    ( B_dt[17:0]   ),  // input wire [17 : 0] B
  .C    ( C_dt[31:0]   ),  // input wire [31 : 0] C
  .D    ( D_dt[26:0]   ),  // input wire [26 : 0] D
  .P    ( arith_result )   // output wire [45 : 0] P
);

//signed extension of 
assign arith_result_o  = { {18{arith_result[45]}}, arith_result };
// assign ready_o          = ~ ( working | working_r  );
assign ready_o          = ~ ( working  );
endmodule

module LFSR (
   input   wire             clk_i         ,
   input   wire             rst_ni        ,
   input   wire             en_i          ,
   input   wire             load_we_i     ,
   input   wire [31:0]      load_dt_i     ,
   output  wire [31:0]      lfsr_dt_o     );

// LFSR
///////////////////////////////////////////////////////////////////////////////

reg [31:0] reg_lfsr ;

always_ff @(posedge clk_i, negedge rst_ni)
   if (!rst_ni)
      reg_lfsr <= 0;//32'h00000000;
   else begin
      if (load_we_i)
         reg_lfsr <= load_dt_i ;
      else if (en_i) begin
         //reg_lfsr[0] <= ~^{reg_lfsr[31], reg_lfsr[21], reg_lfsr[1:0]};
         reg_lfsr[31:1] <= reg_lfsr[30:0];
         reg_lfsr[0] <= ~^{reg_lfsr[31], reg_lfsr[21], reg_lfsr[1:0]};
      end
   end
assign lfsr_dt_o = reg_lfsr ;

endmodule