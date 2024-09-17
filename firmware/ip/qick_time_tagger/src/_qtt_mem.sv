///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024-5-1
//  Versión        : 2
///////////////////////////////////////////////////////////////////////////////
// BRAM_DP_DC_EN
// gcc
// FIFO_DC
// BRAM_SC
// TAG_FIFO_TC

//////////////////////////////////////////////////////////////////////////////
// BRAM
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
module BRAM_DP_DC_EN # ( 
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 ,
   parameter RAM_OUT = "NO_REG" // Select "NO_REG" or "REG" 
) ( 
   input  wire               clk_a_i   ,
   input  wire               en_a_i    ,
   input  wire               we_a_i    ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i    ,
   output wire [MEM_DW-1:0]  dt_a_o    ,
   input  wire               clk_b_i   ,
   input  wire               en_b_i    ,
   input  wire               we_b_i    ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   input  wire [MEM_DW-1:0]  dt_b_i    ,
   output wire [MEM_DW-1:0]  dt_b_o    );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] mem [RAM_SIZE];
reg [MEM_DW-1:0] mem_dt_a = {MEM_DW{1'b0}};
reg [MEM_DW-1:0] mem_dt_b = {MEM_DW{1'b0}};

always @(posedge clk_a_i)
   if (en_a_i) begin
      mem_dt_a <= mem[addr_a_i] ;
      if (we_a_i)
         mem[addr_a_i] <= dt_a_i;
   end
always @(posedge clk_b_i)
   if (en_b_i)
      if (we_b_i)
         mem[addr_b_i] <= dt_b_i;
      else
         mem_dt_b <= mem[addr_b_i] ;

generate
   if (RAM_OUT == "NO_REG") begin: no_output_register // 1 clock cycle read
      assign dt_a_o = mem_dt_a ;
      assign dt_b_o = mem_dt_b ;
   end else begin: output_register // 2 clock cycle read
      reg [MEM_DW-1:0] mem_dt_a_r = {MEM_DW{1'b0}};
      reg [MEM_DW-1:0] mem_dt_b_r = {MEM_DW{1'b0}};
      always @(posedge clk_a_i) if (en_a_i) mem_dt_a_r <= mem_dt_a;
      always @(posedge clk_b_i) if (en_b_i) mem_dt_b_r <= mem_dt_b;
      assign dt_a_o = mem_dt_a_r ;
      assign dt_b_o = mem_dt_b_r ;
   end
endgenerate

endmodule






//GRAY CODE COUNTER
//////////////////////////////////////////////////////////////////////////////
module gcc # (
   parameter DW  = 32
)(
   input  wire          clk_i          ,
   input  wire          rst_ni         ,
   input  wire          async_clear_i  ,
   output wire          clear_o  ,
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

reg clear_rcd, clear_r;
always_ff @(posedge clk_i, negedge rst_ni)
   if(!rst_ni) begin
      clear_rcd       <= 0;
      clear_r         <= 0;
   end else begin
      clear_rcd       <= async_clear_i;
      clear_r         <= clear_rcd;
   end
   
assign count_bin_p1 = count_bin + 1'b1 ; 

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

//////////////////////////////////////////////////////////////////////////////
module FIFO_DC # (
   parameter FIFO_DW = 32 , 
   parameter FIFO_AW = 18 
) ( 
   input  wire                   wr_clk_i    ,
   input  wire                   wr_rst_ni   ,
   input  wire                   wr_en_i     ,
   input  wire                   push_i      ,
   input  wire [FIFO_DW - 1:0]   data_i      ,
   input  wire                   rd_clk_i    ,
   input  wire                   rd_rst_ni   ,
   input  wire                   rd_en_i     ,
   input  wire                   pop_i       ,
   output wire  [FIFO_DW - 1:0]  data_o      ,
   input  wire                   flush_i     ,
   output wire                   async_empty_o  ,
   output wire                   async_full_o   );

// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value
wire [FIFO_AW-1:0] rd_gptr_p1   ;
wire [FIFO_AW-1:0] wr_gptr_p1   ;
wire [FIFO_AW-1:0] rd_ptr, wr_ptr, rd_gptr, wr_gptr  ;
wire clr_wr, clr_rd;

// Sample Pointers
reg [FIFO_AW-1:0] wr_gptr_rcd, wr_gptr_r; 
always_ff @(posedge rd_clk_i) begin
   wr_gptr_rcd      <= wr_gptr;
   wr_gptr_r        <= wr_gptr_rcd;
end

reg [FIFO_AW-1:0] rd_gptr_rcd, rd_gptr_r; 
always_ff @(posedge wr_clk_i) begin
   rd_gptr_rcd      <= rd_gptr;
   rd_gptr_r        <= rd_gptr_rcd;
end


reg clr_fifo_req, clr_fifo_ack;
reg clr_rd_rdc, clr_rd_r;
always_ff @(posedge wr_clk_i, negedge wr_rst_ni) begin
   if (!wr_rst_ni) begin
      clr_fifo_req <= 0 ;
      clr_fifo_ack <= 0 ;
      clr_rd_rdc <= 0 ;
      clr_rd_r <= 0 ;
   end else begin
      clr_rd_rdc      <= clr_rd;
      clr_rd_r        <= clr_rd_rdc;
      if      ( flush_i      )      clr_fifo_req <= 1 ;
      else if ( clr_fifo_ack )      clr_fifo_req <= 0 ;
      if      ( clear_all    )      clr_fifo_ack <= 1 ;
      else if ( clr_fifo_ack & clear_none) clr_fifo_ack <= 0 ;
   end
end

assign clear_all  =  clr_rd_r &  clr_wr;
assign clear_none = !clr_rd_r & !clr_wr;

wire busy;
assign busy = clr_fifo_ack | clr_fifo_req ;

wire [FIFO_DW - 1:0] mem_dt;

wire async_empty, async_full;

//SYNC with POP (RD_CLK)
assign async_empty   = (rd_gptr == wr_gptr_r) ;   

//SYNC with PUSH (WR_CLK)
assign async_full    = (rd_gptr_r == wr_gptr_p1) ;

wire do_pop, do_push;
assign do_pop  = pop_i & !async_empty;
assign do_push = push_i & !async_full;

assign async_empty_o = async_empty | busy; // While RESETTING, Shows EMPTY
assign async_full_o  = async_full  | busy;
assign data_o  = mem_dt;

//Gray Code Counters
gcc #(
   .DW	( FIFO_AW )
) gcc_wr_ptr  (
   .clk_i            ( wr_clk_i     ) ,
   .rst_ni           ( wr_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req ) ,
   .clear_o          ( clr_wr       ) ,
   .cnt_en_i         ( do_push      ) ,
   .count_bin_o      ( wr_ptr       ) ,
   .count_gray_o     ( wr_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( wr_gptr_p1   ) );

gcc #(
   .DW	( FIFO_AW )
) gcc_rd_ptr (
   .clk_i            ( rd_clk_i     ) ,
   .rst_ni           ( rd_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req ) ,
   .clear_o          ( clr_rd       ) ,
   .cnt_en_i         ( do_pop       ) ,
   .count_bin_o      ( rd_ptr       ) ,
   .count_gray_o     ( rd_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( rd_gptr_p1   ) );

// Data
BRAM_DP_DC_EN  # (
   .MEM_AW  ( FIFO_AW     )  , 
   .MEM_DW  ( FIFO_DW     )  ,
   .RAM_OUT ( "NO_REG" ) // Select "NO_REG" or "REG" 
) fifo_mem ( 
   .clk_a_i    ( wr_clk_i  ) ,
   .en_a_i     ( wr_en_i   ) ,
   .we_a_i     ( do_push   ) ,
   .addr_a_i   ( wr_ptr    ) ,
   .dt_a_i     ( data_i    ) ,
   .dt_a_o     ( ) ,
   .clk_b_i    ( rd_clk_i  ) ,
   .en_b_i     ( rd_en_i   ) ,
   .we_b_i     ( 1'b0      ) ,
   .addr_b_i   ( rd_ptr    ) ,
   .dt_b_i     (     ) ,
   .dt_b_o     ( mem_dt    ) );
   
endmodule

//////////////////////////////////////////////////////////////////////////////
module BRAM_SC # ( 
   parameter MEM_AW  = 18 , 
   parameter MEM_DW  = 32 
) ( 
   input  wire               clk_i   ,
   input  wire               we_a_i    ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i    ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   output wire [MEM_DW-1:0]  dt_b_o    );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] mem [RAM_SIZE];
reg [MEM_DW-1:0] mem_dt_b = {MEM_DW{1'b0}};

// Port A WRITE only - Port B READ only
always @(posedge clk_i) begin
   mem_dt_b <= mem[addr_b_i] ;
   if (we_a_i)   mem[addr_a_i] <= dt_a_i;
end

assign dt_b_o = mem_dt_b ;

endmodule





///////////////////////////////////////////////////////////////////////////////

  

