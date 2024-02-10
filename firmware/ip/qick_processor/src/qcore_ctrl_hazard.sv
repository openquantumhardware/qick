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
   input   wire [31:0]        wr_reg_dt_i       ,
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
reg         stall_rd_c; //Give time to Update core_r_dt 
reg         stall_rd_p; // Give time to update PORT_L & PORT_H when DPORT_RD 
reg         stall_id_w   ; // Give time to update R_WAVE 
reg         stall_id_f   ; // Give time to update FLAG
reg         stall_id_j   ; // Give time to update REG_ADDR when JUMP
reg [ 1:0]  w_stall_D_rd ; // Give time to update R_WAVE when REG_WR r_wave
reg [ 1:0]  d_stall_D_rd ; // Give time to READ MEMORY 
reg [ 1:0]  stall_A_rd   ; // Give time to READ MEMORY 

wire        wto_r_wave     ; // r_wave - wreg is being updated

// DATA FORWARDING
reg [ 1:0]  fwd_D_X1, fwd_D_X2, fwd_D_WR ;
reg [31:0]  reg_D_nxt [2] ;

// ADDRESS FORWARDING
reg [31:0]  reg_A_nxt [2] ;

reg [3:0] rfrom_core_r, rfrom_port;  
///////////////////////////////////////////////////////////////////////////////
// REG_WR    after    REG_WR  
genvar ind_D;
generate
   for (ind_D=0; ind_D <2 ; ind_D=ind_D+1) begin
      // 1) REG_WR from WaveRegister   after   REG_WR r_wave 
      always_comb begin
         w_stall_D_rd[ind_D]   = rs_D_addr_i[ind_D][6:5] == 2'b10 & (wto_r_wave) ; //WREG Read and modified  
      end

      // 2d) REG_WR from DataRegister   after   REG_WR DataRegister 
      always_comb begin
         reg_D_nxt[ind_D] = rs_D_dt_i[ind_D];
         d_stall_D_rd[ind_D] = 1'b0;
         if (w_stall_D_rd[ind_D]) begin
            fwd_D_X1[ind_D] = 1'b0;
            fwd_D_X2[ind_D] = 1'b0;
            fwd_D_WR[ind_D] = 1'b0;
         end else begin
            fwd_D_X1[ind_D] = ( (rs_D_addr_i[ind_D] ==  x1_reg_i.addr ) & x1_reg_i.we ); //Data is in X1 STage
            fwd_D_X2[ind_D] = ( (rs_D_addr_i[ind_D] ==  x2_reg_i.addr ) & x2_reg_i.we ); //Data is in X2 STage
            fwd_D_WR[ind_D] = ( (rs_D_addr_i[ind_D] ==  wr_reg_i.addr ) & wr_reg_i.we ); //Data is in WR STage
         end
            if ( fwd_D_X1[ind_D] )     //Data is in X1 STage
               unique case (x1_reg_i.src)
                  2'b00 : reg_D_nxt[ind_D]  = x1_alu_dt_i  ; // Data Comes from ALU 
                  2'b01 : d_stall_D_rd[ind_D] = 1'b1       ; // Data Comes from DATA MEMORY
                  2'b11 : reg_D_nxt[ind_D]  = x1_imm_dt_i  ; // Data Comes from Imm 
               endcase
            else if ( fwd_D_X2[ind_D] )     //Data is in X2 STage
               unique case (x2_reg_i.src)
                  2'b00 : reg_D_nxt[ind_D] = x2_alu_dt_i  ; // Data Comes from ALU 
                  2'b01 : reg_D_nxt[ind_D] = x2_dmem_dt_i ; // Data Comes from DATA MEMORY
                  2'b11 : reg_D_nxt[ind_D] = x2_imm_dt_i  ; // Data Comes from Imm 
               endcase
            else  if ( fwd_D_WR[ind_D] )     //Data was Written
               reg_D_nxt[ind_D] = wr_reg_dt_i;
      end // always_comb
      always_comb begin
         rfrom_core_r[ind_D] = (rs_D_addr_i[ind_D][6:1] == 6'b00_0011) ; //sfr _00_ Address 6 or 7
         rfrom_port[ind_D]   = (rs_D_addr_i[ind_D][6:1] == 6'b00_0100) ; //sfr _00_ Address 8 or 9
      end
   end //for
endgenerate

genvar ind_A;
generate
   for (ind_A=0; ind_A <2 ; ind_A=ind_A+1) begin
      // 2a) REG_WR from AddresRegister   after   REG_WR to AddresRegister 
      always_comb begin
         reg_A_nxt[ind_A] = rs_A_dt_i[ind_A];
         stall_A_rd[ind_A] = 1'b0;
            if ( ( {1'b0,rs_A_addr_i[ind_A]} ==  x1_reg_i.addr ) & x1_reg_i.we )     //Data is in X1 STage
               unique case (x1_reg_i.src)
                  2'b00 : reg_A_nxt[ind_A] = x1_alu_dt_i   ; // Data Comes from ALU 
                  2'b01 : stall_A_rd[ind_A] = 1'b1         ; // Data Comes from DATA MEMORY
                  2'b11 : reg_A_nxt[ind_A] = x1_imm_dt_i   ; // Data Comes from Imm 
               endcase
            else if ( ( {1'b0,rs_A_addr_i[ind_A]} ==  x2_reg_i.addr ) & x2_reg_i.we )     //Data is in X2 STage
               unique case (x2_reg_i.src)
                  2'b00 : reg_A_nxt[ind_A] = x2_alu_dt_i  ; // Data Comes from ALU 
                  2'b01 : reg_A_nxt[ind_A] = x2_dmem_dt_i ; // Data Comes from DATA MEMORY
                  2'b11 : reg_A_nxt[ind_A] = x2_imm_dt_i  ; // Data Comes from Imm 
               endcase
            else  if ( ( {1'b0,rs_A_addr_i[ind_A]} ==  wr_reg_i.addr ) & wr_reg_i.we )     //Data was Written
               reg_A_nxt[ind_A] = wr_reg_dt_i;
      end // always_comb
      always_comb begin
         rfrom_core_r[ind_A+2] = (rs_A_addr_i[ind_A][5:1] == 5'b0_0011) ; //sfr _00_ Address 6 or 7
         rfrom_port[ind_A+2]   = (rs_A_addr_i[ind_A][5:1] == 5'b0_0100) ; //sfr _00_ Address 9 or 9
      end

   end //for
endgenerate


///////////////////////////////////////////////////////////////////////////////
// 3) WMEM_WR    after    REG_WR r_wave or wreg wr

///// WREG IS BEING UPDATED
assign wto_r_wave = rd_reg_i.r_wave_we | x1_reg_i.r_wave_we | x2_reg_i.r_wave_we ;
assign wto_wreg   = rd_reg_i.addr[6:5] == 2'b10 | x1_reg_i.addr[6:5] == 2'b10 | x2_reg_i.addr[6:5] == 2'b10;

always_comb begin
   stall_id_w    = 1'b0    ;
   if (id_wmem_we) begin           // Wave Register will be READED WMEM_WR 
      if ( wto_r_wave | wto_wreg )   // r_wave Register is going to be UPDATED
         stall_id_w    = 1'b1    ; 
   end
end


///////////////////////////////////////////////////////////////////////////////
// 4) CORE_R_DT read after S_CONF Write 
always_comb begin
   stall_rd_c    = 1'b0    ;
   if (|rfrom_core_r & wto_s_cfg ) begin // Core_r Read
      stall_rd_c    = 1'b1    ;
   end
end

  
// 5 Flag Used
///////////////////////////////////////////////////////////////////////////////
// -if()   after   -uf    >>>  STALL 
// -if()   after   s_cfg    >>>  STALL 
// -if()   after   FLAG set or clr

///// PERIPHERAL IS BEING USED
assign wto_qp  = rd_periph_use | x1_periph_use | x2_periph_use;

///// SFR CFG OR CTRL IS BEING UPDATED
assign wto_s_cfg = (rd_reg_i.addr == 7'b0000010) | (x1_reg_i.addr == 7'b0000010) | (x2_reg_i.addr == 7'b0000010) | (wr_reg_i.addr == 7'b0000010) ;

always_comb begin
   stall_id_f    = 1'b0    ;
   if (id_flag_used) begin // FLAG IS USED
      if ( flag_we )             // a) ALU Flag is being UPDATED
         stall_id_f    = 1'b1    ;
      else if (wto_s_cfg)        // b) SRC Flag could be Updated or clear    
         stall_id_f    = 1'b1    ;
      else if (wto_qp)           // c) Perip[heral was used >> may check for Ready in s_status  
         stall_id_f    = 1'b1    ;
   end
end


///////////////////////////////////////////////////////////////////////////////
// 6) JUMP after    WRITE_REG r_addr   >>>  STALL 
wire wto_s_addr;
assign wto_s_addr = (rd_reg_i.addr == 7'b00_01111) | (x1_reg_i.addr == 7'b00_01111) | (x2_reg_i.addr == 7'b00_01111) ;

always_comb begin
   stall_id_j    = 1'b0    ;
   if (id_jmp_i) begin           // Jump Instruction
      if ( wto_s_addr )          // REG_ADDR is going to be UPDATED
         stall_id_j    = 1'b1    ; 
   end
end

///////////////////////////////////////////////////////////////////////////////
// 7) DPORT_RD >>> STALL (Too much logic to check if reg will be used just after)
assign    port_re    = rd_reg_i.port_re | x1_reg_i.port_re | x2_reg_i.port_re ;   
always_comb begin
   stall_rd_p    = 1'b0    ;
   if (|rfrom_port & port_re ) begin
      stall_rd_p    = 1'b1    ;
   end
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
assign bubble_id_o   = stall_id_j | stall_id_f | stall_id_w  ;
assign bubble_rd_o   = |stall_A_rd | |d_stall_D_rd | |w_stall_D_rd  | stall_rd_c | stall_rd_p;

endmodule
