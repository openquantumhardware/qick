///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Gray Code Counter
//  Faithful port from qick_time_tagger's _qtt_mem.sv (module gcc).
//  Feeds the async-FIFO / pulse-CDC pointer synchronizers (fifo_dc,
//  sync_pulse): counts in binary internally, presents the count gray-coded
//  so that only one bit changes at a time across the CDC boundary.
///////////////////////////////////////////////////////////////////////////////

module gcc # (
   parameter int DW  = 32
)(
   input  wire          clk_i          ,
   input  wire          rst_ni         ,
   input  wire          async_clear_i  ,
   output wire          clear_o        ,
   input  wire          cnt_en_i       ,
   output wire [DW-1:0] count_bin_o    ,
   output wire [DW-1:0] count_gray_o   ,
   output wire [DW-1:0] count_bin_p1_o ,
   output wire [DW-1:0] count_gray_p1_o
);

reg  [DW-1:0] count_bin  ;    // count turned into binary number
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
