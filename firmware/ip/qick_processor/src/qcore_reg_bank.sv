///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 

*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

module qcore_reg_bank # (
   parameter LFSR           =  1 ,
   parameter PMEM_AW        =  8 ,
   parameter REG_AW         =  4 
)(
   input   wire                  clk_i          ,
   input   wire                  halt_i         ,
   input   wire                  rst_ni         ,
   input   wire                  clear_i        ,
   input   wire [1:0]            lfsr_cfg_i     ,
   input   wire [31:0]           reg_arith_i    ,
   input   wire [31:0]           reg_div_i  [2] ,
   input   wire [31:0]           reg_port_i [2] ,
   input   wire [31:0]           tproc_ext_i[2] ,
   input   wire [31:0]           time_dt_i      ,
   input   wire [167:0]          wave_dt_i      ,
   input   wire [31:0]           status_i       ,
   output  wire [7:0]            reg_cfg_o      ,
   output  wire [7:0]            reg_ctrl_o     ,
   input   wire                  wave_we_i      ,
   input   wire                  we_i           ,
   input   wire [ 6 : 0 ]        w_addr_i       ,
   input   wire [31:0]           w_dt_i         ,
   input   wire [ 5 : 0 ]        rs_A_addr_i[2] ,
   input   wire [ 6 : 0 ]        rs_D_addr_i[2] ,
   output  reg  [31:0]           w_dt_o         ,
   output  wire [31:0]           rs_D_dt_o [2]  ,
   output  wire [31:0]           rs_A_dt_o [2]  ,
   output  wire [31:0]           sreg_dt_o [2]  ,       
   output  wire [PMEM_AW-1:0]    out_addr_o     ,
   output  wire [31:0]           out_time_o     ,       
   output  wire [167:0]          out_wreg_o     ,       
   output  wire [31:0]           lfsr_o         );

/*
The memory is a group of REGs (ZERO, RAND, DIV, MULT, REGBANK), and connected with a generate
Input has 8 Bits>
XX-000000 2 Page and 64 Address
00-Special Registers (32 Bits)
01-User Register (32 Bits)
10-Wave Parameter Register (32 Bits)
11-RFU
*/

///////////////////////////////////////////////////////////////////////////////
// PARAMETERS
localparam REG_QTY    = (2 ** (REG_AW) ) ;


///////////////////////////////////////////////////////////////////////////////
// SIGNALS
//LFSR
wire [31:0] lfsr_reg;
reg lfsr_en;
wire lfsr_sel, lfsr_we, lfsr_step;

///////////////////////////////////////////////////////////////////////////////
// SPECIAL REGISTER BANK 00_00000 to 00_11111
reg   [31:0]   sreg_dt [4]; // Four SFR
wire           sreg_en, sreg_we;

reg   [7:0]    sreg_cfg_dt ; // Configuration Register(Lower 16Bit of s2)
reg   [7:0]    sreg_ctrl_dt ; // Control Register (Upper 16Bit of s2)
wire           sreg_cfg_en, sreg_cfg_we;

assign sreg_en   = w_addr_i[6:2] == 5'b00_011 ; //Register 12 to 15 selected 
assign sreg_we   = we_i & sreg_en ;
assign sreg_cfg_en  = w_addr_i      == 7'b00_00010 ; //Register 2 Selected 
assign sreg_cfg_we  = we_i & sreg_cfg_en;

///////////////////////////////////////////////////////////////////////////////
// General Data Registers 01_00000 to 01_11111
reg   [31:0]         dreg_32_dt [REG_QTY];
wire  [REG_AW-1:0]   dreg_32_addr   ;
wire                 dreg_32_en, dreg_32_we;

assign dreg_32_addr  = w_addr_i[REG_AW-1:0] ;
assign dreg_32_en   = w_addr_i[6:5] == 2'b01; //~w_addr_i[6] & ~w_addr_i[5] ;
assign dreg_32_we    = we_i & dreg_32_en ;

///////////////////////////////////////////////////////////////////////////////
// Wave Registers 10_00000 to 10_0110
reg  [31:0]          wreg_32_dt [6] ;
wire [ 2:0]          wreg_32_addr   ;
wire                 wreg_32_en, wreg_32_we;
assign wreg_32_addr  = w_addr_i[2:0] ;
assign wreg_32_en    = w_addr_i[6:5] == 2'b10; //~w_addr_i[6] & w_addr_i[5] ;
assign wreg_32_we    = we_i & wreg_32_en;



   
///////////////////////////////////////////////////////////////////////////////
// DATA, WAVE and SFR REGISTER BANK
always_ff @ (posedge clk_i, negedge rst_ni) begin
   if (!rst_ni) begin 
      dreg_32_dt                 = '{default:'0};
      wreg_32_dt                 = '{default:'0};
      sreg_dt                    = '{default:'0};
      sreg_cfg_dt                = 0;
      sreg_ctrl_dt               = 0;
   end else if (clear_i) begin
      dreg_32_dt                 = '{default:'0};
      wreg_32_dt                 = '{default:'0};
      sreg_dt                    = '{default:'0};
      sreg_cfg_dt                = 0;
      sreg_ctrl_dt               = 0;
   end else begin
      if (~halt_i) begin
         if (dreg_32_we)   
            dreg_32_dt [dreg_32_addr]  = w_dt_i;
         if (wreg_32_we)
            wreg_32_dt [wreg_32_addr]  = w_dt_i;
         else if (wave_we_i) begin
            wreg_32_dt [5]  = wave_dt_i[167:152];
            wreg_32_dt [4]  = wave_dt_i[151:120];
            wreg_32_dt [3]  = wave_dt_i[119: 88];
            wreg_32_dt [2]  = wave_dt_i[ 87: 64];
            wreg_32_dt [1]  = wave_dt_i[ 63: 32];
            wreg_32_dt [0]  = wave_dt_i[ 31:  0];
         end
         if (sreg_we)   
           sreg_dt [w_addr_i[1:0]]  = w_dt_i;
         if (sreg_cfg_we) begin   
           sreg_cfg_dt                  = w_dt_i[7:0];
           sreg_ctrl_dt                 = w_dt_i[23:16];
         end else if (|sreg_ctrl_dt)
           sreg_ctrl_dt                 = 8'd0;
         
       // Not Used Register to GND
           sreg_dt [3][31:16] = '{default:'0};
      end
   end
end

///////////////////////////////////////////////////////////////////////////////
// LFSR 
// cfg_i 00_FreeRunning 10_Change WHen Read 11_Change when writes to 0
generate
   if (LFSR == 1) begin : LFSR_YES
      always_comb
         unique case (lfsr_cfg_i)
            2'b00 : lfsr_en = 1'b0     ;
            2'b01 : lfsr_en = 1'b1     ;
            2'b10 : lfsr_en = lfsr_sel  ;
            2'b11 : lfsr_en = lfsr_step  ;
         endcase
      assign lfsr_sel   = (rs_D_addr_i[0]   == 7'b0000001) ;
      assign lfsr_we    = we_i & (w_addr_i == 7'b0000001) ;
      assign lfsr_step  = we_i & (w_addr_i == 7'b0000000) ;
      LFSR lfsr (
         .clk_i       ( clk_i ) ,
         .rst_ni      ( rst_ni ) ,
         .en_i        ( lfsr_en ) ,
         .load_we_i   ( lfsr_we ) ,
         .load_dt_i   ( w_dt_i ) ,
         .lfsr_dt_o   ( lfsr_reg ) );
   end else begin : LFSR_NO
      assign lfsr_sel   = 0;
      assign lfsr_we    = 0;
      assign lfsr_step  = 0;
      assign lfsr_reg   = 0;
   end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// SFR ASSEMBLY
wire [31:0] sreg_32_dt [16] ;

assign sreg_32_dt[0]  = 0                  ;
assign sreg_32_dt[1]  = lfsr_reg           ;
assign sreg_32_dt[2]  = sreg_cfg_dt  ;
assign sreg_32_dt[3]  = reg_arith_i ;
assign sreg_32_dt[4]  = reg_div_i[0]       ;
assign sreg_32_dt[5]  = reg_div_i[1]       ;
assign sreg_32_dt[6]  = tproc_ext_i [0]    ; 
assign sreg_32_dt[7]  = tproc_ext_i [1]    ;
assign sreg_32_dt[8]  = reg_port_i [0]  ;
assign sreg_32_dt[9]  = reg_port_i [1] ;
assign sreg_32_dt[10] = status_i ;
assign sreg_32_dt[11] = time_dt_i          ;
assign sreg_32_dt[12] = sreg_dt [0]     ; // CORE_W_DT1
assign sreg_32_dt[13] = sreg_dt [1]     ; // CORE_W_DT2
assign sreg_32_dt[14] = sreg_dt [2]     ; // OUT TIME
assign sreg_32_dt[15] = sreg_dt [3]     ; // PC_NXT_ADDR_REG


///////////////////////////////////////////////////////////////////////////////
// out MUX for rsA[0] and rsA[1]
wire  [31:0] data_A   [2];

genvar ind_A;
generate
   for (ind_A=0; ind_A <2 ; ind_A=ind_A+1) begin
      assign data_A[ind_A]   = rs_A_addr_i[ind_A][5] ? dreg_32_dt[rs_A_addr_i[ind_A][REG_AW-1:0]] : sreg_32_dt[rs_A_addr_i[ind_A][3:0]] ;
   end
endgenerate

reg [31:0] data_D [2] ;

///////////////////////////////////////////////////////////////////////////////
// out MUX for rsD[0] and rsD[1]
genvar ind_D;
generate
   for (ind_D=0; ind_D <2 ; ind_D=ind_D+1) begin
      always_comb begin
         case (rs_D_addr_i[ind_D][6:5])
            2'b00 : data_D[ind_D] = sreg_32_dt[ rs_D_addr_i[ind_D][3:0] ]; // 16 Registers
            2'b01 : data_D[ind_D] = dreg_32_dt[ rs_D_addr_i[ind_D][REG_AW-1:0] ];
            2'b10 : data_D[ind_D] = wreg_32_dt[ rs_D_addr_i[ind_D][2:0] ]; // 6 Registers
            2'b11 : data_D[ind_D] = 0 ;
         endcase
      end
   end
endgenerate

// Value Just Written - used for Forwarding
always_ff @ (posedge clk_i, negedge rst_ni) 
   if (!rst_ni) 
      w_dt_o               <= 0;
   else if (~halt_i)
      w_dt_o               <= w_dt_i;


///////////////////////////////////////////////////////////////////////////////
// OUTPUT ASSIGNMENT
assign rs_A_dt_o     =  data_A ;
assign rs_D_dt_o     =  data_D ;

assign lfsr_o        =  lfsr_reg ;
assign reg_cfg_o     = sreg_cfg_dt ;
assign reg_ctrl_o    = sreg_ctrl_dt ;
assign sreg_dt_o[0]  =  sreg_32_dt[12] ;
assign sreg_dt_o[1]  =  sreg_32_dt[13] ;
assign out_time_o    =  sreg_32_dt[14] ;
assign out_addr_o    =  sreg_32_dt[15] [PMEM_AW-1:0];

assign out_wreg_o[167:152] = wreg_32_dt[5][15:0];
assign out_wreg_o[151:120] = wreg_32_dt[4]  ;
assign out_wreg_o[119: 88] = wreg_32_dt[3]  ;
assign out_wreg_o[ 87: 64] = wreg_32_dt[2][23:0] ;
assign out_wreg_o[ 63: 32] = wreg_32_dt[1]  ;
assign out_wreg_o[ 31:  0] = wreg_32_dt[0]  ;
   
endmodule