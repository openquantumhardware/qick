///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 

DATA HAZARD 
Data hazards are caused when the execution of one instruction depends on the results of a previous instruction
that is still being processed in the pipeline. 

-DATA FORWARDING 
The Data Forwaring occurs when Data from different pipeline stages should be used in the read stage (RD) of the Pipeline.

This block compares the Source of the instruction in RD Stage with the Destination address of all the instruction in the pipeline 
to see if the Data used in the current instruction is going to be written and is in the Pipeline

-STALLING
The Stalling occurs when Data still not processed should be used in the read stage (RD) of the Pipeline.
This block compares the Source of the instruction in RD Stage with all the possible incomes of data 
to see if the Data used in the current instruction is being processed. 

Possible Sources are >
-A) DSW_REG
-B) DMEM
-C) R_WAVE
-D) CORE_R_DT
-E) IN_PORT_DT
-F) STATUS
-G) time_usr
-H) s_addr
-I) Flags ( -if() )
-J) Random Number

*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

   
module qcore_ctrl_hazard (
   input   wire               clk_i             ,
   input   wire               rst_ni            ,
   input   wire               halt_i            ,
   input   wire [5:0]         rs_A_addr_i [2]   ,
   input   wire [31:0]        rs_A_dt_i   [2]   ,
   input   wire [6:0]         rs_D_addr_i [2]   ,
   input   wire [31:0]        rs_D_dt_i   [2]   ,
   // Register 
   input CTRL_REG             id_reg_i          ,
   input CTRL_REG             rd_reg_i          ,
   input CTRL_REG             x1_reg_i          ,
   input CTRL_REG             x2_reg_i          ,
   input CTRL_REG             wr_reg_i          ,
   // Peripheral
   input   wire               rd_periph_use     ,
   input   wire               x1_periph_use     ,
   input   wire               x2_periph_use     ,
   // Wave Register
   input wire                 id_wmem_we        ,
   // Flag 
   input wire                 id_flag_used      ,
   input wire                 flag_we           ,
   // JUMP 
   input wire                 id_jmp_i          ,
   // ALU (00) Data in each Pipeline Stage
   input   wire [31:0]        x1_alu_dt_i       ,
   input   wire [31:0]        x2_alu_dt_i       ,
   // DMEM (01) in each Pipeline Stage
   input   wire [31:0]        x2_dmem_dt_i      ,
   // IMM Data (11) in each Pipeline Stage
   input   wire [31:0]        rd_imm_dt_i       ,
   input   wire [31:0]        x1_imm_dt_i       ,
   input   wire [31:0]        x2_imm_dt_i       ,
   // New Data to avoid Hazard
   output  wire [31:0]        reg_A_dt_o [2]    ,      
   output  wire [31:0]        reg_D_dt_o [2]    ,      
   // Bubble in RD and Wait for DATA
   output  wire               bubble_id_o       ,       
   output  wire               bubble_rd_o       );


// DATA HAZARD

// STALLING 
reg         stall_id_w   ; // Give time to update R_WAVE 
reg         stall_id_f   ; // Give time to update FLAG
reg         stall_id_j   ; // Give time to update S_ADDR when JUMP
reg         stall_id_rand     ; // Gives time to update rand number

reg         stall_rd_core_rdt ; // Gives time to update core_r_dt after Peripheral or S_CTRL
reg         stall_rd_port     ; // Gives time to update PORT_L & PORT_H after DPORT_RD 
reg         stall_rd_status   ; // Gives time to update STATUS after Peripheral or S_CTRL
reg         stall_rd_stime    ; // Gives time to update s_out_time after TIME instruction
reg [ 1:0]  w_stall_D_rd      ; // Gives time to update R_WAVE when REG_WR r_wave
reg [ 1:0]  d_stall_D_rd      ; // Gives time to READ MEMORY 
reg [ 1:0]  stall_A_rd        ; // Gives time to READ MEMORY 

// DATA FORWARDING
reg [ 1:0]  fwd_D_X1, fwd_D_X2 ;
reg [31:0]  reg_D_nxt [2] ;

// ADDRESS FORWARDING
reg [ 1:0]  fwd_A_X1, fwd_A_X2 ;
reg [31:0]  reg_A_nxt [2] ;

reg [1:0] rfrom_rand_r, rfrom_core_r, rfrom_port_r, rfrom_status_r, rfrom_stime_r;  


assign rfrom_rand       = |rfrom_rand_r    ; // READ FROM CORE_R_DT(s6, s7)
assign rfrom_core_rdt   = |rfrom_core_r    ; // READ FROM CORE_R_DT(s6, s7)
assign rfrom_port       = |rfrom_port_r    ; // READ FROM IN_PORT  (s8, s9))
assign rfrom_status     = |rfrom_status_r  ; // READ FROM STATUS   (s10)
assign rfrom_stime      = |rfrom_stime_r   ; // READ FROM TIME_USR (s11)
assign port_re          = rd_reg_i.port_re | x1_reg_i.port_re | x2_reg_i.port_re ; //PORT READ COMMAND  

// WREG IS BEING UPDATED
assign wto_r_wave = rd_reg_i.r_wave_we | x1_reg_i.r_wave_we | x2_reg_i.r_wave_we ;
assign wto_wreg   = rd_reg_i.addr[6:5] == 2'b10 | x1_reg_i.addr[6:5] == 2'b10 | x2_reg_i.addr[6:5] == 2'b10;
// PERIPHERAL IS BEING UPDATED
assign wto_qp  = rd_periph_use | x1_periph_use | x2_periph_use;
// SFR CFG OR CTRL IS BEING UPDATED
assign wto_s_cfg = (rd_reg_i.addr == 7'b0000010) | (x1_reg_i.addr == 7'b0000010) | (x2_reg_i.addr == 7'b0000010) | (wr_reg_i.addr == 7'b0000010) ;
// SFR S_ADDR IS BEING UPDATED
assign wto_s_addr = (rd_reg_i.addr == 7'b00_01111) | (x1_reg_i.addr == 7'b00_01111) | (x2_reg_i.addr == 7'b00_01111) ;
// SFR S_RAND RAND IS BEING UPDATED
assign wto_s_rand = (rd_reg_i.addr == 7'b00_00001) | (x1_reg_i.addr == 7'b00_00001) | (x2_reg_i.addr == 7'b00_00001) ;


// (A and B) READ dreg, sreg, wreg or DMEM
///////////////////////////////////////////////////////////////////////////////
// REG_WR    after    REG_WR  
genvar ind_D;
generate
   for (ind_D=0; ind_D <2 ; ind_D=ind_D+1) begin
      // Check for read
      always_comb begin
         rfrom_rand_r[ind_D]   = (rs_D_addr_i[ind_D][6:0] == 7'b00_00001) ; //sfr(s1) _00_000001 
         rfrom_status_r[ind_D] = (rs_D_addr_i[ind_D][6:0] == 7'b00_01010) ; //sfr(s10) _00_001010
         rfrom_stime_r[ind_D]  = (rs_D_addr_i[ind_D][6:0] == 7'b00_01011) ; //sfr(s11) _00_001011
         rfrom_core_r[ind_D]   = (rs_D_addr_i[ind_D][6:1] == 6'b00_0011) ; //sfr _00_ Address 6 or 7
         rfrom_port_r[ind_D]   = (rs_D_addr_i[ind_D][6:1] == 6'b00_0100) ; //sfr _00_ Address 8 or 9
      end
      // 1- Use DataRegister   after   REG_WR to Register 
      always_comb begin
         reg_D_nxt[ind_D] = rs_D_dt_i[ind_D];
         d_stall_D_rd[ind_D] = 1'b0;
         fwd_D_X1[ind_D] = ( (rs_D_addr_i[ind_D] ==  x1_reg_i.addr ) & x1_reg_i.we ); //Data is in X1 STage
         fwd_D_X2[ind_D] = ( (rs_D_addr_i[ind_D] ==  x2_reg_i.addr ) & x2_reg_i.we ); //Data is in X2 STage
            if ( fwd_D_X1[ind_D] )     //Data is in X1 STage
               unique case (x1_reg_i.src)
                  2'b00 : reg_D_nxt[ind_D]    = x1_alu_dt_i  ; // Data Comes from ALU 
                  2'b01 : d_stall_D_rd[ind_D] = 1'b1       ; // Data Comes from DATA MEMORY
                  2'b11 : reg_D_nxt[ind_D]    = x1_imm_dt_i  ; // Data Comes from Imm 
               endcase
            else if ( fwd_D_X2[ind_D] )     //Data is in X2 STage
               unique case (x2_reg_i.src)
                  2'b00 : reg_D_nxt[ind_D] = x2_alu_dt_i  ; // Data Comes from ALU 
                  2'b01 : reg_D_nxt[ind_D] = x2_dmem_dt_i ; // Data Comes from DATA MEMORY
                  2'b11 : reg_D_nxt[ind_D] = x2_imm_dt_i  ; // Data Comes from Imm 
               endcase
      end // always_comb
      // 2) Use  WREG  after   REG_WR r_wave  
      always_comb begin
         w_stall_D_rd[ind_D]   = rs_D_addr_i[ind_D][6:5] == 2'b10 & (wto_r_wave) ; //WREG Read and modified  
      end
   end //for
endgenerate

genvar ind_A;
generate
   for (ind_A=0; ind_A <2 ; ind_A=ind_A+1) begin
      // 1-ADDRESS) REG_WR from AddresRegister   after   REG_WR to Register 
      always_comb begin
         reg_A_nxt[ind_A] = rs_A_dt_i[ind_A];
         stall_A_rd[ind_A] = 1'b0;
         fwd_A_X1[ind_A] = ( ( {1'b0,rs_A_addr_i[ind_A]} ==  x1_reg_i.addr ) & x1_reg_i.we ); //Address is in X1 STage
         fwd_A_X2[ind_A] = ( ( {1'b0,rs_A_addr_i[ind_A]} ==  x2_reg_i.addr ) & x2_reg_i.we ); //Address is in X2 STage
         if ( fwd_A_X1[ind_A] )     //Address is in X1 STage
            unique case (x1_reg_i.src)
               2'b00 : reg_A_nxt[ind_A]  = x1_alu_dt_i   ; // Address Comes from ALU 
               2'b01 : stall_A_rd[ind_A] = 1'b1          ; // Address Comes from DATA MEMORY
               2'b11 : reg_A_nxt[ind_A]  = x1_imm_dt_i   ; // Address Comes from Imm 
            endcase
         else if ( fwd_A_X2[ind_A] )     //Address is in X2 STage
            unique case (x2_reg_i.src)
               2'b00 : reg_A_nxt[ind_A] = x2_alu_dt_i  ; // Address Comes from ALU 
               2'b01 : reg_A_nxt[ind_A] = x2_dmem_dt_i ; // Address Comes from DATA MEMORY
               2'b11 : reg_A_nxt[ind_A] = x2_imm_dt_i  ; // Address Comes from Imm 
            endcase
      end // always_comb
   end //for
endgenerate

// (C) READ r_wave
///////////////////////////////////////////////////////////////////////////////
// 3) WMEM_WR    after    REG_WR r_wave or wreg wr
always_comb begin
   stall_id_w    = 1'b0    ;
   if ( id_wmem_we )
      if ( wto_r_wave | wto_wreg )
         stall_id_w    = 1'b1    ; 
end

// (D) CORE_R_DT
///////////////////////////////////////////////////////////////////////////////
// 4) CORE_R_DT read after S_CONF Write 
always_comb begin
   stall_rd_core_rdt    = 1'b0    ;
   if (rfrom_core_rdt)
      if ( wto_qp | wto_s_cfg) 
         stall_rd_core_rdt    = 1'b1    ;
end

// (E) IN_PORT
///////////////////////////////////////////////////////////////////////////////
// 5) IN_PORT read after DPORT_RD
always_comb begin
   stall_rd_port    = 1'b0    ;
   if ( rfrom_port )
      if ( port_re )
         stall_rd_port    = 1'b1    ;
end

// (F) STATUS
///////////////////////////////////////////////////////////////////////////////
// 6) STATUS read after S_CTRL Write or Write to Peripheral
always_comb begin
   stall_rd_status    = 1'b0    ;
   if (rfrom_status ) 
      if ( wto_qp | wto_s_cfg) 
         stall_rd_status    = 1'b1    ;
end

// (G) TIME_USR
///////////////////////////////////////////////////////////////////////////////
// 7) TIME_USR read after Peripheral (TIME inc_ref is Peripheral)
always_comb begin
   stall_rd_stime    = 1'b0    ;
   if ( rfrom_stime ) 
      if ( wto_qp ) 
         stall_rd_stime    = 1'b1    ;
end

// (H) S_ADDR 
///////////////////////////////////////////////////////////////////////////////
// 8) JUMP after    WRITE_REG s_addr   >>>  STALL 
always_comb begin
   stall_id_j    = 1'b0    ;
   if (wto_s_addr )
      if (id_jmp_i )
         stall_id_j    = 1'b1    ; 
end

// (I) Flag Used
///////////////////////////////////////////////////////////////////////////////
// 9)  -if()   after   -uf    >>>  STALL 
// 10) -if()   after   s_cfg    >>>  STALL 
// 11) -if()   after   FLAG set or clr

always_comb begin
   stall_id_f    = 1'b0    ;
   if (id_flag_used) begin // FLAG IS USED
      if ( flag_we )             // a) ALU Flag is being UPDATED
         stall_id_f    = 1'b1    ;
      else if ( wto_s_cfg )        // b) SRC Flag could be Updated or clear    
         stall_id_f    = 1'b1    ;
      else if ( wto_qp )           // c) Peripheral was used
         stall_id_f    = 1'b1    ;
   end
end

// (J) RAND Used  
///////////////////////////////////////////////////////////////////////////////
// 12) RAND Read after READ >>>  STALL 
// 13) RAND Read after WRITE >>>  STALL 
always_comb begin
   stall_id_rand    = 1'b0    ;
   if (wto_s_rand | rfrom_rand )
         stall_id_rand    = 1'b1    ; 
end

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
// Data Forwarding REGISTER 
reg  [31:0]    reg_A     [2] ;
reg  [31:0]    reg_D     [2] ;

//Register DATA & ADDRESS OUT
always_ff @ (posedge clk_i, negedge rst_ni)
   if (!rst_ni) begin
      reg_A          <= '{default:'0};
      reg_D          <= '{default:'0};
   end else begin
      if (~halt_i) begin 
         reg_A          <= reg_A_nxt ;
         reg_D          <= reg_D_nxt ;
      end
   end
   
assign reg_A_dt_o    = reg_A;
assign reg_D_dt_o    = reg_D;
assign bubble_id_o   = stall_id_j | stall_id_f | stall_id_w  | stall_id_rand;
assign bubble_rd_o   = |stall_A_rd | |d_stall_D_rd | |w_stall_D_rd  | stall_rd_stime | stall_rd_status | stall_rd_port | stall_rd_core_rdt ;

endmodule