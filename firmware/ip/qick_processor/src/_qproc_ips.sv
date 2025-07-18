///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 3-2024
//  Version        : 3
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  qick_processor tProc_v2
/* Description: 
IPs used in the design of the qick_processor

* SYNCHRONIZATION REGISTER
* DUAL PORT RAM
* LIFO
* GRAY CODE COUNTER
* FIFO DUAL CLOCK
* TWO inputs ALU
* DSP ARITH BLOCK
* DIVIDER REGISTERED
* INTERLEAVING DUACL CLOCK EN
- DIVISION Pipelined 32 BIT integer
- gray_2_bin
- bin_2_gray

*/
//////////////////////////////////////////////////////////////////////////////

`define USE_XPM_MACROS

///////////////////////////////////////////////////////////////////////////////
/// SYNC - Clock Domain Data Syncronization
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
// DUAL PORT RAM
///////////////////////////////////////////////////////////////////////////////
module bram_dual_port_dc # (
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 ,
   parameter RAM_OUT  = "NO_REGISTERED" // Select "NO_REGISTERED" or "REGISTERED" 
) ( 
   input  wire               clk_a_i  ,
   input  wire               en_a_i   ,
   input  wire               we_a_i   ,
   input  wire [MEM_AW-1:0]  addr_a_i ,
   input  wire [MEM_DW-1:0]  dt_a_i   ,
   output wire [MEM_DW-1:0]  dt_a_o   ,
   input  wire               clk_b_i  ,
   input  wire               en_b_i   ,
   input  wire               we_b_i   ,
   input  wire [MEM_AW-1:0]  addr_b_i ,
   input  wire [MEM_DW-1:0]  dt_b_i   ,
   output wire [MEM_DW-1:0]  dt_b_o   );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] RAM [RAM_SIZE];
reg [MEM_DW-1:0] ram_dt_a = {MEM_DW{1'b0}};
reg [MEM_DW-1:0] ram_dt_b = {MEM_DW{1'b0}};

initial begin
   for (int i=0; i < RAM_SIZE; i=i+1) begin
      RAM[i] = 'd0;
   end
end

always @(posedge clk_a_i)
   if (en_a_i) begin
      ram_dt_a <= RAM[addr_a_i] ;
      if (we_a_i)
         RAM[addr_a_i] <= dt_a_i;
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

`ifndef USE_XPM_MACROS
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
`endif


`ifdef USE_XPM_MACROS

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
   input  wire                   flush_i        ,
   output logic  [FIFO_DW - 1:0] data_o         ,
   output logic                  async_empty_o  ,
   output logic                  async_full_o   
);

   // XPM_FIFO instantiation template for Asynchronous FIFO configurations
   // Refer to the targeted device family architecture libraries guide for XPM_FIFO documentation
   // =======================================================================================================================

   // Parameter usage table, organized as follows:
   // +---------------------------------------------------------------------------------------------------------------------+
   // | Parameter name       | Data type          | Restrictions, if applicable                                             |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Description                                                                                                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // +---------------------------------------------------------------------------------------------------------------------+
   // | CASCADE_HEIGHT       | Integer            | Range: 0 - 64. Default value = 0.                                       |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | 0- No Cascade Height, Allow Vivado Synthesis to choose.                                                             |
   // | 1 or more - Vivado Synthesis sets the specified value as Cascade Height.                                            |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | CDC_SYNC_STAGES      | Integer            | Range: 2 - 8. Default value = 2.                                        |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies the number of synchronization stages on the CDC path                                                      |
   // |                                                                                                                     |
   // |   Must be < 5 if FIFO_WRITE_DEPTH = 16                                                                              |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | DOUT_RESET_VALUE     | String             | Default value = 0.                                                      |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Reset value of read data path.                                                                                      |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | ECC_MODE             | String             | Allowed values: no_ecc, en_ecc. Default value = no_ecc.                 |
   // |---------------------------------------------------------------------------------------------------------------------|
   // |                                                                                                                     |
   // |   "no_ecc" - Disables ECC                                                                                           |
   // |   "en_ecc" - Enables both ECC Encoder and Decoder                                                                   |
   // |                                                                                                                     |
   // | NOTE: ECC_MODE should be "no_ecc" if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.|
   // +---------------------------------------------------------------------------------------------------------------------+
   // | FIFO_MEMORY_TYPE     | String             | Allowed values: auto, block, distributed. Default value = auto.         |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Designate the fifo memory primitive (resource type) to use.                                                         |
   // |                                                                                                                     |
   // |   "auto"- Allow Vivado Synthesis to choose                                                                          |
   // |   "block"- Block RAM FIFO                                                                                           |
   // |   "distributed"- Distributed RAM FIFO                                                                               |
   // |                                                                                                                     |
   // | NOTE: There may be a behavior mismatch if Block RAM or Ultra RAM specific features, like ECC or Asymmetry, are selected with FIFO_MEMORY_TYPE set to "auto".|
   // +---------------------------------------------------------------------------------------------------------------------+
   // | FIFO_READ_LATENCY    | Integer            | Range: 0 - 10. Default value = 1.                                       |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Number of output register stages in the read data path.                                                             |
   // |                                                                                                                     |
   // |   If READ_MODE = "fwft", then the only applicable value is 0.                                                       |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | FIFO_WRITE_DEPTH     | Integer            | Range: 16 - 4194304. Default value = 2048.                              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Defines the FIFO Write Depth, must be power of two.                                                                 |
   // |                                                                                                                     |
   // |   In standard READ_MODE, the effective depth = FIFO_WRITE_DEPTH-1                                                   |
   // |   In First-Word-Fall-Through READ_MODE, the effective depth = FIFO_WRITE_DEPTH+1                                    |
   // |                                                                                                                     |
   // | NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.                                             |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | FULL_RESET_VALUE     | Integer            | Range: 0 - 1. Default value = 0.                                        |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Sets full, almost_full and prog_full to FULL_RESET_VALUE during reset                                               |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | PROG_EMPTY_THRESH    | Integer            | Range: 3 - 4194301. Default value = 10.                                 |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies the minimum number of read words in the FIFO at or below which prog_empty is asserted.                    |
   // |                                                                                                                     |
   // |   Min_Value = 3 + (READ_MODE_VAL*2)                                                                                 |
   // |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2)                                                              |
   // |                                                                                                                     |
   // | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
   // | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
   // | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | PROG_FULL_THRESH     | Integer            | Range: 5 - 4194301. Default value = 10.                                 |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies the maximum number of write words in the FIFO at or above which prog_full is asserted.                    |
   // |                                                                                                                     |
   // |   Min_Value = 3 + (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))+CDC_SYNC_STAGES                              |
   // |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                           |
   // |                                                                                                                     |
   // | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
   // | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
   // | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | RD_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies the width of rd_data_count. To reflect the correct value, the width should be log2(FIFO_READ_DEPTH)+1.    |
   // |                                                                                                                     |
   // |   FIFO_READ_DEPTH = FIFO_WRITE_DEPTH*WRITE_DATA_WIDTH/READ_DATA_WIDTH                                               |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | READ_DATA_WIDTH      | Integer            | Range: 1 - 4096. Default value = 32.                                    |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Defines the width of the read data port, dout                                                                       |
   // |                                                                                                                     |
   // |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
   // |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
   // |                                                                                                                     |
   // | NOTE:                                                                                                               |
   // |                                                                                                                     |
   // |   READ_DATA_WIDTH should be equal to WRITE_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
   // |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | READ_MODE            | String             | Allowed values: std, fwft. Default value = std.                         |
   // |---------------------------------------------------------------------------------------------------------------------|
   // |                                                                                                                     |
   // |   "std"- standard read mode                                                                                         |
   // |   "fwft"- First-Word-Fall-Through read mode                                                                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | RELATED_CLOCKS       | Integer            | Range: 0 - 1. Default value = 0.                                        |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies if the wr_clk and rd_clk are related having the same source but different clock ratios                    |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | SIM_ASSERT_CHK       | Integer            | Range: 0 - 1. Default value = 0.                                        |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | 0- Disable simulation message reporting. Messages related to potential misuse will not be reported.                 |
   // | 1- Enable simulation message reporting. Messages related to potential misuse will be reported.                      |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
   // | prog_full, overflow features.                                                                                       |
   // |                                                                                                                     |
   // |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
   // |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
   // |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
   // |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
   // |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
   // |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
   // |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
   // |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
   // |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
   // |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | WAKEUP_TIME          | Integer            | Range: 0 - 2. Default value = 0.                                        |
   // |---------------------------------------------------------------------------------------------------------------------|
   // |                                                                                                                     |
   // |   0 - Disable sleep                                                                                                 |
   // |   2 - Use Sleep Pin                                                                                                 |
   // |                                                                                                                     |
   // | NOTE: WAKEUP_TIME should be 0 if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.   |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | WRITE_DATA_WIDTH     | Integer            | Range: 1 - 4096. Default value = 32.                                    |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Defines the width of the write data port, din                                                                       |
   // |                                                                                                                     |
   // |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
   // |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
   // |                                                                                                                     |
   // | NOTE:                                                                                                               |
   // |                                                                                                                     |
   // |   WRITE_DATA_WIDTH should be equal to READ_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
   // |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | WR_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Specifies the width of wr_data_count. To reflect the correct value, the width should be log2(FIFO_WRITE_DEPTH)+1.   |
   // +---------------------------------------------------------------------------------------------------------------------+

   // Port usage table, organized as follows:
   // +---------------------------------------------------------------------------------------------------------------------+
   // | Port name      | Direction | Size, in bits                         | Domain  | Sense       | Handling if unused     |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Description                                                                                                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // +---------------------------------------------------------------------------------------------------------------------+
   // | almost_empty   | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to|
   // | empty.                                                                                                              |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | almost_full    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.|
   // +---------------------------------------------------------------------------------------------------------------------+
   // | data_valid     | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).        |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | dbiterr        | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.|
   // +---------------------------------------------------------------------------------------------------------------------+
   // | din            | Input     | WRITE_DATA_WIDTH                      | wr_clk  | NA          | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write Data: The input data bus used when writing the FIFO.                                                          |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | dout           | Output    | READ_DATA_WIDTH                       | rd_clk  | NA          | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read Data: The output data bus is driven when reading the FIFO.                                                     |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | empty          | Output    | 1                                     | rd_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Empty Flag: When asserted, this signal indicates that the FIFO is empty.                                            |
   // | Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.     |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | full           | Output    | 1                                     | wr_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Full Flag: When asserted, this signal indicates that the FIFO is full.                                              |
   // | Write requests are ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive       |
   // | to the contents of the FIFO.                                                                                        |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | injectdbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or                  |
   // | UltraRAM macros.                                                                                                    |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | injectsbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or                  |
   // | UltraRAM macros.                                                                                                    |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | overflow       | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected,              |
   // | because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.                      |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | prog_empty     | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal              |
   // | to the programmable empty threshold value.                                                                          |
   // | It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.              |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | prog_full      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal            |
   // | to the programmable full threshold value.                                                                           |
   // | It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.          |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | rd_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read clock: Used for read operation. rd_clk must be a free running clock.                                           |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | rd_data_count  | Output    | RD_DATA_COUNT_WIDTH                   | rd_clk  | NA          | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read Data Count: This bus indicates the number of words read from the FIFO.                                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | rd_en          | Input     | 1                                     | rd_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO.        |
   // |                                                                                                                     |
   // |   Must be held active-low when rd_rst_busy is active high.                                                          |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | rd_rst_busy    | Output    | 1                                     | rd_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.                     |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | rst            | Input     | 1                                     | wr_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying reset, but reset must be released only after the clock(s) is/are stable.|
   // +---------------------------------------------------------------------------------------------------------------------+
   // | sbiterr        | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.                             |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | sleep          | Input     | 1                                     | NA      | Active-high | Tie to 1'b0            |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Dynamic power saving: If sleep is High, the memory/fifo block is in power saving mode.                              |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | underflow      | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected                     |
   // | because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.                                   |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | wr_ack         | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.    |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | wr_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write clock: Used for write operation. wr_clk must be a free running clock.                                         |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | wr_data_count  | Output    | WR_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write Data Count: This bus indicates the number of words written into the FIFO.                                     |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | wr_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO.        |
   // |                                                                                                                     |
   // |   Must be held active-low when rst or wr_rst_busy is active high.                                                   |
   // +---------------------------------------------------------------------------------------------------------------------+
   // | wr_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | Required               |
   // |---------------------------------------------------------------------------------------------------------------------|
   // | Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.                   |
   // +---------------------------------------------------------------------------------------------------------------------+

   logic rd_rst_busy, wr_rst_busy;
   logic wr_full, rd_empty, rd_empty_d1, rd_empty_d2;
   logic [FIFO_DW - 1:0] dout;

   // Hold full high during Flush or Reset
   assign async_full_o = wr_full | flush_i | wr_rst_busy;

   // Delay empty 2 clocks
   always_ff @(posedge rd_clk_i) begin
      rd_empty_d1 <= rd_empty;
      rd_empty_d2 <= rd_empty_d1;
   end
   assign async_empty_o = rd_empty_d2;

   // Clear data output when empty
   always_ff @(posedge rd_clk_i) begin
      data_o      <= rd_empty ? 'd0 : dout;
   end
   // assign data_o = rd_empty ? 'd0 : dout;


   // xpm_fifo_async: Asynchronous FIFO
   // Xilinx Parameterized Macro, version 2023.1
   xpm_fifo_async #(
      .CASCADE_HEIGHT            (0),           // DECIMAL
      .CDC_SYNC_STAGES           (2),           // DECIMAL
      .DOUT_RESET_VALUE          ("0"),         // String
      .ECC_MODE                  ("no_ecc"),    // String
      .FIFO_MEMORY_TYPE          ("auto"),      // String
      .FIFO_READ_LATENCY         (1),           // DECIMAL
      .FIFO_WRITE_DEPTH          (2**FIFO_AW),  // DECIMAL
      .FULL_RESET_VALUE          (1),           // DECIMAL
      .PROG_EMPTY_THRESH         (10),          // DECIMAL
      .PROG_FULL_THRESH          (10),          // DECIMAL
      .RD_DATA_COUNT_WIDTH       (1),           // DECIMAL
      .READ_DATA_WIDTH           (FIFO_DW),     // DECIMAL
      // .READ_MODE                 ("std"),       // String
      .READ_MODE                 ("fwft"),      // String
      .RELATED_CLOCKS            (0),           // DECIMAL
      .SIM_ASSERT_CHK            (0),           // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES          ("0000"),      // String
      .WAKEUP_TIME               (0),           // DECIMAL
      .WRITE_DATA_WIDTH          (FIFO_DW),     // DECIMAL
      .WR_DATA_COUNT_WIDTH       (1)            // DECIMAL
   )
   xpm_fifo_async_inst (
      .almost_empty              (),                                             // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                                                                 // only one more read can be performed before the FIFO goes to empty.

      .almost_full               (),                                             // 1-bit output: Almost Full: When asserted, this signal indicates that
                                                                                 // only one more write can be performed before the FIFO is full.

      .data_valid                (),                                             // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                                                                 // that valid data is available on the output bus (dout).

      .dbiterr                   (),                                             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                                                                 // a double-bit error and data in the FIFO core is corrupted.

      .dout                      (dout),                                         // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                                                                 // when reading the FIFO.

      .empty                     (rd_empty),                                     // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                                                                 // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                                                                 // initiating a read while empty is not destructive to the FIFO.

      .full                      (wr_full),                                      // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                                                                 // FIFO is full. Write requests are ignored when the FIFO is full,
                                                                                 // initiating a write when the FIFO is full is not destructive to the
                                                                                 // contents of the FIFO.

      .overflow                  (),                                             // 1-bit output: Overflow: This signal indicates that a write request
                                                                                 // (wren) during the prior clock cycle was rejected, because the FIFO is
                                                                                 // full. Overflowing the FIFO is not destructive to the contents of the
                                                                                 // FIFO.

      .prog_empty                (),                                             // 1-bit output: Programmable Empty: This signal is asserted when the
                                                                                 // number of words in the FIFO is less than or equal to the programmable
                                                                                 // empty threshold value. It is de-asserted when the number of words in
                                                                                 // the FIFO exceeds the programmable empty threshold value.

      .prog_full                 (),                                             // 1-bit output: Programmable Full: This signal is asserted when the
                                                                                 // number of words in the FIFO is greater than or equal to the
                                                                                 // programmable full threshold value. It is de-asserted when the number of
                                                                                 // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count             (),                                             // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                                                                 // number of words read from the FIFO.

      .rd_rst_busy               (rd_rst_busy),                                  // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                                                                 // domain is currently in a reset state.

      .sbiterr                   (),                                             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                                                                 // and fixed a single-bit error.

      .underflow                 (),                                             // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                                                                 // the previous clock cycle was rejected because the FIFO is empty. Under
                                                                                 // flowing the FIFO is not destructive to the FIFO.

      .wr_ack                    (),                                             // 1-bit output: Write Acknowledge: This signal indicates that a write
                                                                                 // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count             (),                                             // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                                                                 // the number of words written into the FIFO.

      .wr_rst_busy               (wr_rst_busy),                                  // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                                                                 // write domain is currently in a reset state.

      .din                       (data_i),                                       // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                                                                 // writing the FIFO.

      .injectdbiterr             (1'b0),                                         // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                                                                 // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr             (1'b0),                                         // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                                                                 // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_clk                    (rd_clk_i),                                     // 1-bit input: Read clock: Used for read operation. rd_clk must be a free
                                                                                 // running clock.

      .rd_en                     (~rd_rst_busy & rd_en_i & (pop_i | flush_i)),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                                                                 // signal causes data (on dout) to be read from the FIFO. Must be held
                                                                                 // active-low when rd_rst_busy is active high.

      .rst                       (~wr_rst_ni | flush_i),                         // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                                                                 // unstable at the time of applying reset, but reset must be released only
                                                                                 // after the clock(s) is/are stable.

      .sleep                     (1'b0),                                         // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
                                                                                 // block is in power saving mode.

      .wr_clk                    (wr_clk_i),                                     // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                                                                 // free running clock.

      .wr_en                     (~wr_rst_busy & wr_rst_ni & wr_en_i & push_i)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                                                                 // signal causes data (on din) to be written to the FIFO. Must be held
                                                                                 // active-low when rst or wr_rst_busy is active high.
   );

   // End of xpm_fifo_async_inst instantiation

endmodule

`else

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

`endif


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

wire[3:0] shift ;
assign shift = B_i[3:0];

wire [31:0] neg_B, a_plus_b, a_minus_b, abs_b;
wire [31:0] msh_a, lsh_a, swap_a;  
wire [31:0] a_cat_b, a_sl_b, a_lsr_b, a_asr_b ;

assign neg_B      = -B_i ;
assign a_plus_b   = A_i + B_i;
assign a_minus_b  = A_i + neg_B;
assign abs_b      = B_i[31] ? neg_B : B_i;
assign msh_a      = {16'b00000000_00000000, A_i[31:16]} ;
assign lsh_a      = {16'b00000000_00000000, A_i[15: 0]} ;
assign swap_a     = {A_i[15:0], A_i[31:16]} ;
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
         3'b010: result = A_i & B_i ;
         3'b011: result = a_asr_b   ;
         3'b100: result = abs_b     ;
         3'b101: result = msh_a     ;
         3'b110: result = lsh_a     ;
         3'b111: result = swap_a    ;
      endcase
   else
      // LOGIC
      case ( alu_op_i[3:1] )
         3'b000: result = ~A_i      ;
         3'b001: result = A_i | B_i ;
         3'b010: result = A_i ^ B_i ;
         3'b011: result = a_cat_b   ;
         3'b100: result = 0         ;
         3'b101: result = {31'b0, ^A_i} ;
         3'b110: result =  a_sl_b   ;
         3'b111: result =  a_lsr_b  ;
      endcase
end

assign zero_flag  = (result == 0) ;
assign carry_flag = result[32];
assign sign_flag  = result[31];

assign alu_result_o  = result[31:0] ;
assign Z_o           = zero_flag    ;
assign C_o           = carry_flag   ;
assign S_o           = sign_flag    ;

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


///////////////////////////////////////////////////////////////////////////////
// DIVIDER REGISTERED
///////////////////////////////////////////////////////////////////////////////
module div_r #(
   parameter DW = 32
) (
   input  wire             clk_i           ,
   input  wire             rst_ni          ,
   input  wire             start_i         ,
   input  wire [DW-1:0]    A_i             ,
   input  wire [DW-1:0]    B_i             ,
   output wire             ready_o         ,
   output reg  [DW-1:0]    div_quotient_o  ,
   output reg  [DW-1:0]    div_remainder_o );

// Registers
reg [DW-1:0] inB        ;
reg [DW-1:0] r_temp, q_temp;
reg [4:0]    ind_bit; 

reg working;

reg qtb;
reg [2*DW-1 :0] sub_temp  ;
reg [DW-1   :0] r_temp_nxt  ;

wire [31:0] ind_bit_m1;


assign ind_bit_m1 = ind_bit - 1'b1;
assign div_start  = start_i;
assign div_end    = (ind_bit==0) ;

// State Machine
///////////////////////////////////////////////////////////////////////////
enum {IDLE, WORKING} div_st, div_st_nxt;

always_ff @(posedge clk_i)
   if (!rst_ni)     div_st  <= IDLE;
   else             div_st  <= div_st_nxt;


always_comb begin
   div_st_nxt  = div_st;
   working     = 1'b0;
   case (div_st)
      IDLE: begin
         if ( div_start )    div_st_nxt = WORKING;
      end
      WORKING: begin
         working = 1'b1;
         if ( div_end ) div_st_nxt = IDLE;
      end
   endcase
end

always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin        
      ind_bit     <= 31;
      q_temp      <= 0 ;
      r_temp      <= 0 ;
   end else if (div_start) begin
      ind_bit     <= 31;
      q_temp      <= 0 ;
      r_temp      <= A_i ;
      inB         <= B_i ;
   end else if (div_end) begin
      ind_bit     <= 31;
      q_temp      <= 0 ;
      r_temp      <= A_i ;
      inB         <= B_i ;
   end else if (working) begin
      ind_bit         <= ind_bit_m1;
      r_temp          <= r_temp_nxt   ;
      q_temp[ind_bit_m1] <= qtb   ;
  end
end // Always

///////////////////////////////////////////////////////////////////////////
// COMBINATORIAL PART
always_comb begin
   qtb         = 1'b0;
   r_temp_nxt  = r_temp ;
   sub_temp    = inB << ind_bit_m1  ;
   if (r_temp_nxt >= sub_temp ) begin
      qtb        = 1'b1 ;
      r_temp_nxt = r_temp_nxt  - sub_temp ;
   end
end

///////////////////////////////////////////////////////////////////////////
// OUT REG
always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin        
      div_quotient_o  <= 0;
      div_remainder_o <= 0 ;
   end else if (div_end) begin
      div_quotient_o  <= q_temp;
      div_remainder_o <= r_temp_nxt ;
  end
end // Always

assign ready_o = ~working;

endmodule


///////////////////////////////////////////////////////////////////////////////
// LFSR
///////////////////////////////////////////////////////////////////////////////
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

///////////////////////////////////////////////////////////////////////////////
// INTERLEAVING DUACL CLOCK EN
///////////////////////////////////////////////////////////////////////////////
/*
sync_ab_en sync_pulse_inst (
   .clk_a_i    (  ) ,
   .rst_a_ni   (  ) ,
   .clk_b_i    (  ) ,
   .rst_b_ni   (  ) ,
   .a_en_o     (  ) ,
   .b_en_o     (  ) );
  */ 
module sync_ab_en (
   input  wire    clk_a_i    ,
   input  wire    rst_a_ni   ,
   input  wire    clk_b_i    ,
   input  wire    rst_b_ni   ,
   output wire    a_en_o     ,
   output wire    b_en_o     
);
/// REQ Time from C to T
///////////////////////////////////////////////////////////////////////////////
reg a_pulse_req;
always_ff @ (posedge clk_a_i, negedge rst_a_ni) begin
   if ( !rst_a_ni  ) begin
      a_pulse_req   <= 1'b0;
   end else
      if      (  a_pulse_ack ) a_pulse_req <= 1'b0; 
      else if ( !a_pulse_ack ) a_pulse_req <= 1'b1; 
end

/// Generate B PULSE
///////////////////////////////////////////////////////////////////////////////
(* ASYNC_REG = "TRUE" *) reg pulse_req_cdc, b_pulse_req ;
reg pulse_b_req_r;
always_ff @(posedge clk_b_i)
   if(!rst_b_ni) begin
      pulse_req_cdc  <= 0;
      b_pulse_req    <= 0;
   end else begin 
      pulse_req_cdc  <= a_pulse_req;
      b_pulse_req    <= pulse_req_cdc;
      pulse_b_req_r  <= b_pulse_req;
   end

assign pulse_b = b_pulse_req ^ pulse_b_req_r;

/// ACK
///////////////////////////////////////////////////////////////////////////////
reg b_pulse_ack;
always_ff @ (posedge clk_a_i, negedge rst_a_ni) begin
   if ( !rst_a_ni  ) begin
      b_pulse_ack   <= 1'b0;
   end else
      if      (  b_pulse_req ) b_pulse_ack <= 1'b1; 
      else if ( !b_pulse_req ) b_pulse_ack <= 1'b0; 
end

(* ASYNC_REG = "TRUE" *) reg pulse_ack_cdc, a_pulse_ack ;
always_ff @(posedge clk_a_i)
   if(!rst_a_ni) begin
      pulse_ack_cdc  <= 0;
      a_pulse_ack    <= 0;
   end else begin 
      pulse_ack_cdc  <= b_pulse_ack;
      a_pulse_ack    <= pulse_ack_cdc;
   end

assign pulse_a = a_pulse_req ~^ a_pulse_ack ;

assign a_en_o  = pulse_a;
assign b_en_o  = pulse_b;

endmodule

/*
////////////////////////////////////////////////////////////////////////////////
// DIVISION Pipelined 32 BIT integer
///////////////////////////////////////////////////////////////////////////////
module div_p #(
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
module bin_2_gray # (
   parameter DW  = 32
)(
   input  wire [DW-1:0] count_bin_i    , 
   output wire [DW-1:0] count_gray_o   );
assign count_gray_o   = count_bin_i ^ {1'b0,count_bin_i[DW-1:1]};
endmodule

module gray_2_bin # (
   parameter DW  = 32
)(
   input  wire [DW-1:0] count_gray_i   ,
   output  reg [DW-1:0] count_bin_o    );
integer ind;
always_comb begin
   count_bin_o[DW-1] = count_gray_i[DW-1];
   for (ind=DW-2 ; ind>=0; ind=ind-1) begin
      count_bin_o[ind] = count_bin_o[ind+1]^count_gray_i[ind];
   end
end

endmodule
*/


