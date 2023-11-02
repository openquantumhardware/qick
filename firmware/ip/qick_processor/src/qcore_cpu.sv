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

module qcore_cpu # (
   parameter LFSR           =  1 ,
   parameter PMEM_AW        =  8 ,
   parameter DMEM_AW        =  8 ,
   parameter WMEM_AW        =  8 ,
   parameter REG_AW         =  4 
)(
   input   wire                  clk_i          ,
   input   wire                  rst_ni         ,
   input   wire                  restart_i      ,
   input   wire                  en_i           ,
   input   wire [1:0]            lfsr_cfg_i          , // CONFIGURATION (LFSR)
   output  wire [31:0]           lfsr_o   ,
// DEBUG       
   output  wire [31:0]           core_do        , // Core Signal Debug
// CONDITIONS       
   input   wire                  flag_i     , // External Condition
// DATA INPUT
   output wire [7:0]       sreg_cfg_o           ,
   output wire [7:0]       sreg_ctrl_o           ,
   input  wire [31:0]      sreg_arith_i         ,
   input  wire [31:0]      sreg_div_i      [2]  ,
   input  wire [31:0]      sreg_status_i        , 
   input  wire [31:0]      sreg_core_r_dt_i[2]  ,
   input  wire [31:0]      sreg_port_dt_i  [2]  ,
   input  wire [31:0]      sreg_time_dt_i       , 
   output wire [31:0]      sreg_core_w_dt_o[2]  ,
   output  wire [31:0]           usr_dt_a_o     , // Data A from Current Instruction (rsD0)
   output  wire [31:0]           usr_dt_b_o     , // Data B from Current Instruction (rsD1)
   output  wire [31:0]           usr_dt_c_o     , // Data C from Current Instruction (rsA0)
   output  wire [31:0]           usr_dt_d_o     , // Data D from Current Instruction (rsA1m)
   output  wire [9:0]            usr_ctrl_o     , // CONTROL from Current Instruction 
// PROGRAM MEMORY    
   output  wire [PMEM_AW-1:0]    pmem_addr_o    ,
   output  wire                  pmem_en_o      ,
   input   wire [71:0]           pmem_dt_i      ,
// DATA MEMORY    
   output  wire                  dmem_we_o      ,
   output  wire [DMEM_AW-1:0]    dmem_addr_o    ,
   output  wire [31:0]           dmem_w_dt_o    ,
   input   wire [31:0]           dmem_r_dt_i    ,
// WAVE MEMORY
   output  wire                  wmem_we_o      ,
   output  wire [WMEM_AW-1:0]    wmem_addr_o    ,
   output  wire [167:0]          wmem_w_dt_o    ,
   input   wire [167:0]          wmem_r_dt_i    ,
//OUTPUT PORTS
   output  wire                  port_we_o      ,
   output  wire                  port_re_o      ,
   output PORT_DT                port_o               
         );

///////////////////////////////////////////////////////////////////////////////
// Signal Declaration

// Address Signals
reg  [10:0]      r_id_imm_addr, r_rd_imm_addr ;
//reg  [WMEM_AW-1:0]      r_rd_rsA0_addr, r_rd_rsA1_addr ;
reg  [WMEM_AW-1:0]      r_rd_rsA1_addr ;
wire [PMEM_AW-1:0]      reg_addr;
//Data Signals
reg [31 :0]    r_id_imm_dt, r_rd_imm_dt, r_x1_imm_dt;
reg [31 :0]    r_x1_alu_dt      ;
// Data Signals
wire [31:0]    x1_alu_dt   ;
wire           x1_alu_fZ, x1_alu_fC, x1_alu_fS   ;
wire [WMEM_AW-1:0]  x1_wave_addr ;
// Pipeline registers.
reg  [PMEM_AW-1 : 0] PC_curr, PC_nxt, PC_prev ;
reg [2:0]            cfg_pc_nxt;

wire           id_pc_change;
reg            r_id_pc_change ;
reg  [5:0]     r_id_rs_A_addr     [2] ; // Address in the RegBank
reg  [6:0]     r_id_rs_D_addr     [2] ; // Address in the RegBank
wire [31:0]    reg_D_fwd_dt      [2] ; 
wire [31:0]    reg_A_fwd_dt      [2] ; 
wire [31:0]    reg_time ;

// PROCESSOR STATUS 
///////////////////////////////////////////////////////////////////////////////
wire halt, flush, stall, bubble_id, bubble_rd;

assign halt    = ~en_i ;
assign flush   = id_pc_change | r_id_pc_change ;
assign stall   = bubble_id | bubble_rd;
assign fetch_en = ~stall & ~halt;


///////////////////////////////////////////////////////////////////////////////////////////////////
// IF    - 1  FIRST Stage IF_  ( Instruction FECTH )
///////////////////////////////////////////////////////////////////////////////////////////////////

wire [ 15 : 0 ] if_op_code ;
wire [ 55 : 0 ] if_op_data ;
reg  [ 15 : 0 ] r_if_op_code ;
reg  [ 55 : 0 ] r_if_op_data ;
reg r_mem_rst;
assign if_op_code       = pmem_dt_i [ 71 : 56 ] ;
assign if_op_data       = pmem_dt_i [ 55 :  0 ] ;

// empty memory Pipeline
always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin
      r_mem_rst      <= 1;
      r_if_op_code   <= 0;
      r_if_op_data   <= 0;
   end else if (restart_i) begin
      r_mem_rst      <= 1;
      r_if_op_code   <= 0;
      r_if_op_data   <= 0;
   end else begin 
      r_mem_rst      <= 0;
      if (pmem_en_o) begin
         if (flush) begin
            r_if_op_code <= 0;
            r_if_op_data <= 0;
         end else begin 
            r_if_op_code <= if_op_code;
            r_if_op_data <= if_op_data;
         end
      end
   end
   
end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// ID    - 2  SECOND STAGE ID_  INSTRUCTION DECODER
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

// CONTROL
///////////////////////////////////////////////////////////
wire [2:0]  id_HEADER          ;
wire        id_AI    ;
wire [1:0]  id_DF      ;
wire [2:0]  id_COND;
wire id_SO, id_TO;

assign id_HEADER   = r_if_op_code [ 15 : 13 ] ;
assign id_AI       = r_if_op_code [ 12 ]      ;
assign id_DF       = r_if_op_code [ 11 : 10]  ;
assign id_COND     = r_if_op_code [ 9 : 7 ]   ;
assign id_SO       = r_if_op_code [ 6 ]       ;
assign id_TO       = r_if_op_code [ 5 ]       ;


reg id_type_cfg, id_type_br, id_type_ctrl;
reg id_type_wr, id_type_wrd, id_type_wrw, id_type_wra ;
reg id_type_wp, id_type_wpd, id_type_wpw ;
reg id_type_wm, id_type_wmd, id_type_wmw;

reg id_cfg_port_src, id_cfg_alu_src, id_cfg_dt_imm          ;
reg [3:0] id_cfg_alu_op ; 
reg [1:0] id_cfg_reg_src ;
reg cfg_dual_regs_en, cfg_flag_en, cfg_dual_port_en, cfg_dual_wmem_en      ;
reg cfg_dual_regs_we, cfg_dual_port_we, cfg_dual_wmem_we                   ;
reg id_flag_we; 
reg id_dmem_we , id_wmem_we ;
reg id_dreg_we , id_r_wave_we ;
reg id_dport_re, id_dport_we, id_wport_we ;

reg id_call, id_ret                                                        ;

reg [9:0] id_usr_ctrl;
reg id_cond_ok, id_exec_ok, id_branch_cond_ok;
reg alu_fZ_r, alu_fS_r;

always_comb begin : DECODER
   id_type_cfg       = ( id_HEADER == CFG    ) ;
   id_type_br        = ( id_HEADER == BRANCH  ) ;
   id_type_wr        = ( id_HEADER == REG_WR  ) ;
   id_type_wm        = ( id_HEADER == MEM_WR  ) ;
   id_type_wp        = ( id_HEADER == PORT_WR ) ;
   id_type_ctrl      = ( id_HEADER == CTRL    ) ;
   id_type_wra       = id_type_wr & (~id_SO & ~id_TO)  ; // Write Data Register from ALU
   id_type_wrd       = id_type_wr & ~(id_SO & ~id_TO)  ; // Write Data Register (ALU, MEM, or IMM)
   id_type_wrw       = id_type_wr &  (id_SO & ~id_TO)  ; // Write Wave Data Register 
   id_type_wmd       = id_type_wm & ~id_SO             ; // Write Data Memory
   id_type_wmw       = id_type_wm &  id_SO             ; // Write Wave Memory
   id_type_wpd       = id_type_wp & ~id_SO             ; // Write Data Port
   id_type_wpw       = id_type_wp &  id_SO             ; // Write Wave Port


   id_cfg_port_src   =  r_if_op_code[8] ;
   id_cfg_dt_imm     =  &id_DF | ( (id_type_wm | id_type_cfg) & id_TO ) | (id_type_wpd & id_cfg_port_src) ; // Immediate input Data
   id_cfg_alu_src    = ( id_DF == 2'b10)                   ; //With DI=10 Source =1 
   id_cfg_alu_op     =   id_type_wra         ? r_if_op_code[3:0] : {1'b0, r_if_op_code[1:0], 1'b0 } ;
   id_cfg_reg_src    =   id_type_wrd         ? r_if_op_code[6:5] : {2{r_if_op_code [2]}}     ; // When Writing WAVE Second OPTION
   cfg_dual_regs_en  = ( id_type_wrw | id_type_wm | id_type_wp | id_type_br | id_type_cfg )  ; // Is Possible to 
   cfg_flag_en       = cfg_dual_regs_en | id_type_wr                                         ; // Is Possible to Update Flag
   cfg_dual_port_en  = id_type_wrw | id_type_wmw                                             ; // Is Possible to Dual PORT WRITE
   cfg_dual_wmem_en  = id_type_wrw | id_type_wpw                                             ; // Is Possible to Dual WaveForm MEM WRITE
   cfg_dual_regs_we  = cfg_dual_regs_en   & r_if_op_code[3]                                  ; // Dual REGISTER WRITE ENABLE
   cfg_dual_port_we  = cfg_dual_port_en   & r_if_op_code[7]                                  ; // Dual PORT     WRITE ENABLE
   cfg_dual_wmem_we  = cfg_dual_wmem_en   & r_if_op_code[9]                                  ; // Dual WMEM     WRITE ENABLE
   id_flag_we        = id_exec_ok & cfg_flag_en   & r_if_op_code[4]                                  ; // Flag      WRITE ENABLE
   id_dreg_we        = id_exec_ok         & ( id_type_wrd   | cfg_dual_regs_we )              ; // DREG      WRITE ENABLE
   id_r_wave_we      = id_type_wrw                                                           ; // WREG      WRITE ENABLE (The 167 Bits)
   id_dmem_we        = id_exec_ok         & ( id_type_wmd )                                  ; // DMEM      WRITE ENABLE
   id_wmem_we        = id_type_wmw  | cfg_dual_wmem_we   & r_if_op_code[9]                   ; // WMEM      WRITE ENABLE
   id_dport_we       = id_type_wpd        & r_if_op_code[7]                                  ; // DPORT     WRITE ENABLE
   id_dport_re       = id_type_wpd        & ~r_if_op_code[7]                                 ; // DPORT     READ  ENABLE
   id_wport_we       = id_type_wpw | cfg_dual_port_we                                        ; // WPORT     WRITE ENABLE
   id_call           = id_branch_cond_ok  & id_SO & ~id_TO                                   ; // Execute CALL Instruction (Push)
   id_ret            = id_type_br         & id_SO &  id_TO                                   ; // Execute RET  Instruction (Pull)
   id_usr_ctrl       = id_type_ctrl ? {r_if_op_code [9:0]} : 10'b0000000000  ;
end
 
reg [ 31 : 0 ]  id_imm_dt   ;
reg [15:0] id_imm_addr     ;
reg [5 :0] id_rs_A_addr [2];
reg [6 :0] id_rs_D_addr [2];
reg [6 :0] id_rd_addr      ;
wire [PMEM_AW-1:0] pc_stack;

///////////////////////////////////////////////////////////////////////////////
// DATA
always_comb
   unique case (id_DF)
      2'b00 : id_imm_dt = id_imm_addr  ; // Data Immediate is 16 Bits Address Space
      2'b01 : id_imm_dt = { {16{r_if_op_data[22]}} , r_if_op_data [22:7]}  ; // Data Immediate is 16 Bits SIGNED
      2'b10 : id_imm_dt = { { 8{r_if_op_data[30]}} , r_if_op_data [30:7]}  ; // Data Immediate is 24 Bits SIGNED
      2'b11 : id_imm_dt = r_if_op_data [38:7]                  ; // Data Immediate is 32 Bits
   endcase

///////////////////////////////////////////////////////////////////////////////
// ADDRESS
always_comb begin
   id_imm_addr     = r_if_op_data [ 55 : 45 ] ;
   id_rs_A_addr[0] = r_if_op_data [ 50 : 45 ] ;
   id_rs_A_addr[1] = r_if_op_data [ 44 : 39 ] ;
   id_rs_D_addr[0] = r_if_op_data [ 37 : 31 ] ;
   id_rs_D_addr[1] = r_if_op_data [ 29 : 23 ] ;
   id_rd_addr      = r_if_op_data [  6 :  0 ] ;
end
assign id_reg.we        = id_dreg_we      ;
assign id_reg.r_wave_we = id_r_wave_we    ;
assign id_reg.addr      = id_rd_addr      ;
assign id_reg.src       = id_cfg_reg_src  ;
assign id_reg.port_re   = id_dport_re     ;

assign id_ctrl.cfg_addr_imm  = id_AI            ;
assign id_ctrl.cfg_dt_imm    = id_cfg_dt_imm    ;
assign id_ctrl.cfg_port_src  = id_cfg_port_src  ;
assign id_ctrl.cfg_port_type = id_type_wpd      ;
assign id_ctrl.cfg_port_time = id_type_wp & id_TO ;
assign id_ctrl.cfg_cond      = id_COND          ;
assign id_ctrl.cfg_alu_src   = id_cfg_alu_src   ;
assign id_ctrl.cfg_alu_op    = id_cfg_alu_op    ;
assign id_ctrl.usr_ctrl      = id_usr_ctrl      ;
assign id_ctrl.flag_we       = id_flag_we       ;
assign id_ctrl.dmem_we       = id_dmem_we       ;
assign id_ctrl.wmem_we       = id_wmem_we       ;
assign id_ctrl.port_we       = id_wport_we | id_dport_we ;


// CONDITION  
/////////////////////////////////////////////////

reg id_cond_used, id_flag_used ;
always_comb begin
   unique case ( id_COND )
      3'b000: id_cond_ok =  1           ; // ALWAYS
      3'b001: id_cond_ok =  alu_fZ_r    ; //EQ - Z
      3'b010: id_cond_ok =  alu_fS_r    ; //LT - S 
      3'b011: id_cond_ok = ~alu_fZ_r    ; //NZ -not(Z)
      3'b100: id_cond_ok = ~alu_fS_r    ; //NS -not(S)
      3'b101: id_cond_ok =  flag_i  ; // External Flag
      3'b110: id_cond_ok = ~flag_i  ; // NOT External Flag
      3'b111: id_cond_ok =  0       ; // RFU
   endcase
   id_cond_used      = id_type_wrd | id_type_wmd | id_type_br  |id_type_cfg           ; // Conditional Instruction
   id_flag_used      = id_cond_used & |id_COND                                        ; // Condition should be checked
   id_exec_ok        = id_cond_ok | ~id_cond_used                                     ; // Execute Instruction
   id_branch_cond_ok = id_type_br & id_exec_ok                                        ; // Execute BRANCH
end


// PC_ADDR CLACULATION
/////////////////////////////////////////////////
always_comb begin 
   cfg_pc_nxt  =  2'b00;                             // Move to Next Address
   if ( id_ret )              cfg_pc_nxt  = 2'b11;   // Return from CALL RET is NOT conditional 
   else if (id_branch_cond_ok)        
      if (id_AI)              cfg_pc_nxt  = 2'b01 ;  // Jump to IMM Address
      else                    cfg_pc_nxt  = 2'b10;   // Jump to REG Address 
end

wire  id_jmp_reg_used;
assign id_jmp_reg_used = (cfg_pc_nxt  == 2'b10) ;

assign id_pc_change = |cfg_pc_nxt;

always_comb
   unique case (cfg_pc_nxt )
      2'b00: PC_nxt   = PC_curr + 1   ;
      2'b01: PC_nxt   = id_imm_addr   ;
      2'b10: PC_nxt   = reg_addr      ;
      2'b11: PC_nxt   = pc_stack      ;
   endcase

always @(posedge clk_i) begin
   if (!rst_ni) begin
      PC_curr     <= 0;
      PC_prev     <= 0;
   end else begin
   if (restart_i) begin
      PC_curr     <= 0;
      PC_prev     <= 0;
   end else if (fetch_en) begin
         PC_curr <= PC_nxt;
         PC_prev <= PC_curr;
      end
   end
end


 
// X1    - 4  FOURTH STAGE - ADDRESS CALCULATION - EXECUTE_1
///////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] x1_rsD0_dt, x1_rsD1_dt ;
wire [31:0] x1_rsA1_dt, x1_rsA0_dt ;
wire [31:0] rs_A_dt [2] ;
wire [31:0] rs_D_dt [2] ;


assign x1_rsA0_dt = x1_ctrl.cfg_addr_imm ? r_rd_imm_addr :  reg_A_fwd_dt[0] ;
assign x1_rsA1_dt = reg_A_fwd_dt[1] ;
assign x1_rsD0_dt = reg_D_fwd_dt[0] ;
assign x1_rsD1_dt = reg_D_fwd_dt[1] ;

// ARITHMETIC UNIT
/////////////////////////////////////////////////
reg  [31:0] x1_alu_in_A, x1_alu_in_B ;
assign x1_alu_in_A     = x1_rsD0_dt; 
assign x1_alu_in_B     = x1_ctrl.cfg_alu_src  ?  r_rd_imm_dt : x1_rsD1_dt    ;

// DATA MEMORY 
/////////////////////////////////////////////////
wire [DMEM_AW-1:0]  x1_mem_addr   ;
wire [31:0]          x1_mem_w_dt ;
assign x1_mem_addr  = x1_rsA0_dt + x1_rsA1_dt ;
assign x1_mem_w_dt  = x1_ctrl.cfg_dt_imm   ?  r_rd_imm_dt : x1_alu_dt ; 

// WAVE MEMORY
///////////////////////////////////////////////////////////////////////////////
assign x1_wave_addr   = x1_rsA0_dt[WMEM_AW-1:0] ;

// PORT
///////////////////////////////////////////////////////////////////////////////
wire [3:0] x1_port_w_addr;
assign x1_port_w_addr   =  r_rd_rsA1_addr[3:0] ;


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// X2    - 5  FIFTH STAGE X2_  -  EXECUTE_2
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

reg  [167:0]  reg_wave_dt  ;

// Input to Register Bank   
reg  [31:0]  x2_reg_w_dt     ;

always_comb begin
// Data Input
   case (x2_reg.src)
      2'b00: x2_reg_w_dt = r_x1_alu_dt ;
      2'b01: x2_reg_w_dt = dmem_r_dt_i ;
      2'b10: x2_reg_w_dt = r_x1_alu_dt ;
      2'b11: x2_reg_w_dt = r_x1_imm_dt ;
      
   endcase
end


// WAVE  
/////////////////////////////////////////////////
wire [167:0] x2_wave_w_dt;
assign x2_wave_w_dt = x2_ctrl.cfg_port_src ? reg_wave_dt : wmem_r_dt_i ;

// PORT
/////////////////////////////////////////////////
wire [167:0] x2_port_w_dt  ;
reg [3:0] r_x1_port_w_addr;


reg [31:0] r_x1_port_dt;

assign x2_port_w_dt  = x2_ctrl.cfg_port_type ? r_x1_port_dt : x2_wave_w_dt ;


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// INSTANCES
///////////////////////////////////////////////////////////////////////////////

CTRL_REG    id_reg, rd_reg, x1_reg, x2_reg, wr_reg  ;
CTRL_FLOW   id_ctrl, rd_ctrl, x1_ctrl, x2_ctrl   ;

wire [31 : 0] wr_reg_dt;

qcore_ctrl_hazard ctrl_hzrd (
   .clk_i            ( clk_i           ) ,
   .rst_ni           ( rst_ni          ) ,
   .halt_i           ( halt            ) ,
   .rs_A_addr_i      ( r_id_rs_A_addr      ) ,
   .rs_A_dt_i        ( rs_A_dt    ) ,
   .rs_D_addr_i      ( r_id_rs_D_addr      ) ,
   .rs_D_dt_i        ( rs_D_dt    ) ,
   // Register Write Enable 
   .id_reg_i         ( id_reg          ) ,
   .rd_reg_i         ( rd_reg          ) ,
   .x1_reg_i         ( x1_reg          ) ,
   .x2_reg_i         ( x2_reg          ) ,
   .wr_reg_i         ( wr_reg          ) ,
   .wr_reg_dt_i      ( wr_reg_dt       ) ,
   // Wave Register 
   .id_wmem_we   ( id_wmem_we       ) , //r_wave will be READ
   // FLAG 
   .id_flag_used     ( id_flag_used        ) , // SELECCIONAR CORRECTAMENTE WR/MEM_WR and JUMPD
   .flag_we          ( rd_ctrl.flag_we | x1_ctrl.flag_we       ) ,
   // PC JUMP 
   .id_jmp_i         ( id_jmp_reg_used       ) ,
   // ALU (00) Data in each Pipeline Stage
   .x1_alu_dt_i      ( x1_alu_dt       ) ,
   .x2_alu_dt_i      ( r_x1_alu_dt     ) ,
   // DMEM (01) in each Pipeline Stage
   .x2_dmem_dt_i      (dmem_r_dt_i) ,
   // Imm Data in each Pipeline Stage
   .rd_imm_dt_i      ( r_id_imm_dt     ) ,
   .x1_imm_dt_i      ( r_rd_imm_dt     ) ,
   .x2_imm_dt_i      ( r_x1_imm_dt     ) ,
   // Data Memory Write Enable 
   .reg_A_dt_o       ( reg_A_fwd_dt     ) ,
   .reg_D_dt_o       ( reg_D_fwd_dt     ) ,
   .bubble_id_o      ( bubble_id     ) ,
   .bubble_rd_o      ( bubble_rd       ) );

// REG BANK
/////////////////////////////////////////////////
qcore_reg_bank # (
   .LFSR            (LFSR) ,
   .PMEM_AW         (PMEM_AW) ,
   .REG_AW          (REG_AW)
) reg_bank (
   .clk_i            ( clk_i          ) ,
   .halt_i           ( halt           ) ,
   .rst_ni           ( rst_ni         ) ,
   .clear_i          ( restart_i      ) ,
   .lfsr_cfg_i       ( lfsr_cfg_i     ) ,
   .reg_arith_i      ( sreg_arith_i   ) ,
   .reg_div_i        ( sreg_div_i     ) ,
   .reg_port_i       ( sreg_port_dt_i ) ,
   .tproc_ext_i      ( sreg_core_r_dt_i       ) ,
   .status_i         ( sreg_status_i       ) ,
   .reg_cfg_o        ( sreg_cfg_o       ) ,
   .reg_ctrl_o       ( sreg_ctrl_o       ) ,
   .time_dt_i        ( sreg_time_dt_i      ) ,
   .wave_we_i        ( x2_reg.r_wave_we ) ,
   .we_i             ( x2_reg.we      ) ,
   .w_addr_i         ( x2_reg.addr    ) ,
   .w_dt_i           ( x2_reg_w_dt    ) ,
   .wave_dt_i        ( x2_wave_w_dt      ) ,
   .rs_A_addr_i      ( r_id_rs_A_addr   ) ,
   .rs_D_addr_i      ( r_id_rs_D_addr   ) ,
   .w_dt_o           ( wr_reg_dt      ) ,
   .rs_A_dt_o        ( rs_A_dt        ) ,
   .rs_D_dt_o        ( rs_D_dt        ) ,
   .sreg_dt_o        ( sreg_core_w_dt_o       ) ,
   .out_addr_o       ( reg_addr       ) ,
   .out_time_o       ( reg_time       ) ,
   .out_wreg_o       ( reg_wave_dt      ) ,
   .lfsr_o           ( lfsr_o         ) );//

// ALU - 2 Inputs 
/////////////////////////////////////////////////
AB_alu alu (
   .clk_i        ( clk_i            ) ,
   .A_i          ( x1_alu_in_A      ) ,
   .B_i          ( x1_alu_in_B      ) ,
   .alu_op_i     ( x1_ctrl.cfg_alu_op   ) ,
   .Z_o          ( x1_alu_fZ        ) ,
   .C_o          ( x1_alu_fC        ) ,
   .S_o          ( x1_alu_fS        ) ,
   .alu_result_o ( x1_alu_dt        ) );


wire pc_stack_full;
// PC STACK 
/////////////////////////////////////////////////
/////////////////////////////////////////////////
LIFO  # (
   .WIDTH  ( PMEM_AW   )  , 
   .DEPTH  ( 8          )  
) pc_stack_inst  ( 
   .clk_i   ( clk_i    ) ,
   .rst_ni  ( rst_ni   ) ,
   .data_i  ( PC_prev  ) ,
   .push    ( id_call & fetch_en  ) ,
   .pop     ( id_ret & fetch_en  ) ,
   .data_o  ( pc_stack ) ,
   .full_o  ( pc_stack_full ) );




///////////////////////////////////////////////////////////////////////////////
// PIPELINE  
///////////////////////////////////////////////////////////////////////////////


// DATA & ADDRESS PIPELINE 
always_ff @ (posedge clk_i) begin
   if (!rst_ni) begin
      // CONTROL SIGNALS
      r_id_pc_change       <= 0  ;
      rd_ctrl              <= '{default:'0};
      x1_ctrl              <= '{default:'0};
      x2_ctrl              <= '{default:'0};
      rd_reg               <= '{default:'0};
      x1_reg               <= '{default:'0};
      x2_reg               <= '{default:'0};
      wr_reg               <= '{default:'0};
      //Address Signals
      r_id_imm_addr        <= 0  ;
      r_rd_imm_addr        <= 0  ;
//      r_rd_rsA0_addr       <= 0  ;
      r_rd_rsA1_addr       <= 0  ;
      r_id_rs_A_addr       <= '{default:'0};
      r_id_rs_D_addr       <= '{default:'0};
      //Data Signals
      r_id_imm_dt          <= 0  ;
      r_rd_imm_dt          <= 0  ;
      r_x1_imm_dt          <= 0  ;
      r_x1_alu_dt          <= 0  ;
      r_x1_port_dt       <= 0  ;
      alu_fZ_r             <= 0  ;
      alu_fS_r             <= 0  ;
   end else if (restart_i ) begin
      r_id_pc_change       <= 0  ;
      rd_ctrl              <= '{default:'0};
      x1_ctrl              <= '{default:'0};
      x2_ctrl              <= '{default:'0};
      rd_reg               <= '{default:'0};
      x1_reg               <= '{default:'0};
      x2_reg               <= '{default:'0};
      wr_reg               <= '{default:'0};
      r_id_imm_addr        <= 0  ;
      r_rd_imm_addr        <= 0  ;
//      r_rd_rsA0_addr       <= 0  ;
      r_rd_rsA1_addr       <= 0  ;
      r_id_rs_A_addr       <= '{default:'0};
      r_id_rs_D_addr       <= '{default:'0};
      r_id_imm_dt          <= 0  ;
      r_rd_imm_dt          <= 0  ;
      r_x1_imm_dt          <= 0  ;
      r_x1_alu_dt          <= 0  ;
      r_x1_port_dt       <= 0  ;
      alu_fZ_r             <= 0  ;
      alu_fS_r             <= 0  ;
      r_x1_port_w_addr     <= 0  ;
   end else begin
      if (~halt) begin

/////////////////////////////////////////////////////////
// READING
         if (bubble_id ) begin    // Insert Bubble
            if (bubble_rd) begin    // Insert Bubble
               rd_ctrl                 <= rd_ctrl;
               rd_reg                  <= rd_reg;
            end else begin 
               rd_ctrl                 <= '{default:'0}     ;
               rd_reg                  <= '{default:'0}     ;
            end
         end else begin
            //Control Signals
            rd_ctrl                 <= id_ctrl            ;
            rd_reg                  <= id_reg            ;
            r_id_pc_change          <= id_pc_change ;
            //Data Signals
            r_id_rs_A_addr          <= id_rs_A_addr;
            r_id_rs_D_addr          <= id_rs_D_addr ;
            r_id_imm_addr           <= id_imm_addr    ;
            r_id_imm_dt             <= id_imm_dt      ;
         end
/////////////////////////////////////////////////////////
// EXECUTE 1 
         if (bubble_rd) begin    // Insert Bubble
            x1_ctrl                 <= '{default:'0}     ;
            x1_reg                  <= '{default:'0}     ;
         end else begin
            x1_ctrl              <= rd_ctrl           ;
            x1_reg               <= rd_reg            ;
         end
         //Address Signals
//         r_rd_rsA0_addr          <= r_id_rs_A_addr[0]   ;
         r_rd_rsA1_addr          <= r_id_rs_A_addr[1]   ;
         r_rd_imm_addr           <= r_id_imm_addr     ;
         //Data Signals
         r_rd_imm_dt             <= r_id_imm_dt       ;
/////////////////////////////////////////////////////////
// EXECUTE 2
         //Data Signals
         r_x1_imm_dt                <= r_rd_imm_dt       ;
         r_x1_alu_dt                <= x1_alu_dt         ;
         r_x1_port_dt               <= x1_rsA0_dt        ;
         r_x1_port_w_addr           <= x1_port_w_addr    ;
         if (x1_ctrl.flag_we) begin 
            alu_fZ_r                <= x1_alu_fZ         ;
            alu_fS_r                <= x1_alu_fS         ;
         end
         //Control Signals
         x2_reg                  <= x1_reg         ;
         x2_ctrl                 <= x1_ctrl ;
/////////////////////////////////////////////////////////
// WRITE 
         //Control Signals
         wr_reg                  <= x2_reg ;
      end //(~HALT)
   end //NotRST
end //ALWAYS

/////////////////////////////////////////////////////////////////////////////////////////
// OUTPUTS
/////////////////////////////////////////////////////////////////////////////////////////

// PROGRAM MEMORY
assign pmem_en_o        = fetch_en | r_mem_rst;
assign pmem_addr_o      = PC_curr         ; // Disable next instruction with pc_jump

//DATA MEMORY
assign dmem_we_o        = halt ? 0 : x1_ctrl.dmem_we;
assign dmem_addr_o      = x1_mem_addr        ;
assign dmem_w_dt_o      = x1_mem_w_dt        ;

//WAVE MEMORY
assign wmem_we_o        = halt ? 0 : x1_ctrl.wmem_we;
assign wmem_addr_o      = x1_wave_addr      ;
assign wmem_w_dt_o      = reg_wave_dt      ;

// PERIPH OUT
// assign <output> = <1-bit_select> ? <input1> : <input0>;
assign usr_ctrl_o      = halt ? 0 : x1_ctrl.usr_ctrl ;
assign usr_dt_a_o      = x1_rsD0_dt ; 
assign usr_dt_b_o      = x1_ctrl.cfg_dt_imm ? r_rd_imm_dt : x1_rsD1_dt ;
assign usr_dt_c_o      = x1_rsA0_dt ; 
assign usr_dt_d_o      = x1_rsA1_dt;

// PORT OUTPUT
assign port_we_o        = halt ? 0 : x2_ctrl.port_we ;
assign port_re_o        = halt ? 0 : x2_reg.port_re ;

assign port_o.p_time    = x2_ctrl.cfg_port_time ? r_x1_imm_dt : reg_time;
assign port_o.p_type    = x2_ctrl.cfg_port_type ;
assign port_o.p_addr    = r_x1_port_w_addr     ;
assign port_o.p_data    = x2_port_w_dt       ;

// DEBUG
assign core_do [31:24] = {restart_i, stall, flush, id_flag_we, alu_fZ_r, alu_fS_r, x2_ctrl.port_we, x2_reg.port_re};
assign core_do [23:16] = {id_type_ctrl, id_type_cfg, id_type_br, id_type_wr, id_type_wm, id_type_wp, 1'b0, pc_stack_full } ;
assign core_do [15:8]  = r_x1_alu_dt[7:0]  ;
assign core_do [7:0]   = port_o.p_time[7:0] ;

endmodule