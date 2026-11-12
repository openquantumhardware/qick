///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Priority Encoder
//  Faithful port from qick_time_tagger's _qtt_ips.sv (module priority_encoder).
//  Encodes the lowest-index set bit of a one-hot/one-cold input vector to
//  binary, with a valid flag. OUT selects combinational ("NO_REG", 1-cycle
//  read) or registered (anything else, 2-cycle read) output.
///////////////////////////////////////////////////////////////////////////////

module priority_encoder # (
   parameter int    DW  = 5 ,
   parameter string OUT = "NO_REG"
)(
   input   wire                clk_i          ,
   input   wire                rst_ni         ,
   input   wire [2**DW-1:0]    one_hot_dt_i   ,
   output  reg  [DW-1:0]       bin_dt_o       ,
   output  reg                 vld_o          );

localparam int ONE_HOT_DW = 2**DW;

integer i ;
reg valid;
reg [DW-1 : 0] bin_dt ;

always_comb begin
  valid = 1'b0;
  bin_dt = 0;
  for (i = 0 ; i < ONE_HOT_DW; i=i+1)
    if (!valid & one_hot_dt_i[i]) begin
      valid  = 1'b1;
      bin_dt = i;
   end
end

generate
   if (OUT == "NO_REG") begin: gen_no_output_register // 1 clock cycle read
      assign vld_o     = valid ;
      assign bin_dt_o  = bin_dt ;
   end else begin: gen_output_register // 2 clock cycle read
      reg          vld_r    = {DW{1'b0}};
      reg [DW-1:0] bin_dt_r = {DW{1'b0}};
      always @(posedge clk_i) vld_r    <= valid;
      always @(posedge clk_i) bin_dt_r <= bin_dt;
      assign vld_o    = vld_r ;
      assign bin_dt_o = bin_dt_r ;
   end
endgenerate

endmodule
