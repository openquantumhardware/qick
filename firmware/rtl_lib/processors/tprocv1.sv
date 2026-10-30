///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tprocv1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tprocv1.sv
//!
//! @brief   TODO: one-line description.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
`include "tproc_pkg.sv"

module tprocv1#(
    //! program memory address width (default 16)
    parameter int N = 16,  // Program memory address width
    //! data memory address width (default 10)
    parameter int M = 10   // Data memory address width
  )
  (
    // Clock and reset
    input  logic        clk,
    input  logic        rstn,

    // Start/stop
    input  logic        start,

    // Program Memory Interface
    output logic [N-1:0] pmem_addr,
    input  logic [63:0]  pmem_do,

    // Data Memory Interface
    output logic         dmem_we,
    output logic [M-1:0] dmem_addr,
    output logic [31:0]  dmem_di,
    input  logic [31:0]  dmem_do,

    // AXI4-Stream Slave Interfaces (input data, 64-bit)
    axi4_stream_if.slave s0_axis,
    axi4_stream_if.slave s1_axis,
    axi4_stream_if.slave s2_axis,
    axi4_stream_if.slave s3_axis,

    // AXI4-Stream Master Interfaces (output data, 160-bit)
    axi4_stream_if.master m0_axis,
    axi4_stream_if.master m1_axis,
    axi4_stream_if.master m2_axis,
    axi4_stream_if.master m3_axis,
    axi4_stream_if.master m4_axis,
    axi4_stream_if.master m5_axis,
    axi4_stream_if.master m6_axis,
    axi4_stream_if.master m7_axis,

    // Register control inputs (for external start source selection)
    input  logic         start_src_reg,
    input  logic         start_reg
  );

  import tproc_pkg::*;
  //--------------------------------------------------------------------------
  // Local parameters
  //--------------------------------------------------------------------------
  localparam int NCH = 8;          // Number of channels
  localparam int B   = 32;         // Data bit-width
  localparam int TW  = 48;         // Master clock time width
  localparam int FW  = 5*B + TW + 8; // FIFO width: opcode(8) + time(TW) + 5 regs (5*B)

  //--------------------------------------------------------------------------
  // Internal signals
  //--------------------------------------------------------------------------

  // Resynchronized inputs
  logic start_src_reg_resync, start_reg_resync, start_input_resync;

  // Muxed start
  logic start_i;

  // Instruction fields (from IR)
  logic [7:0]  opcode_i;
  logic [2:0]  page_i;
  logic [2:0]  channel_i;
  logic [3:0]  oper_i;
  logic [31:0] imm_i;

  // Control signals from tpv1_ctrl
  logic        ir_en_i;
  logic        pc_src_i, pc_en_i, pc_rst_i;
  logic [1:0]  alu_src_b_i;
  logic        alut_src_b_i;
  logic [2:0]  reg_src_i;
  logic        reg_wen_i;
  logic        cond_flag_i;
  logic        stack_en_i, stack_op_i;
  logic        stack_full_i, stack_empty_i;
  logic        fifo_wr_en_mux;
  logic        fifo_full_mux;
  logic        dmem_addr_src;
  logic        t_cnt_en;
  logic        t_cnt_sync_en;
  logic        waitt_mux;
  logic        waitt_ack_mux;

  // ALU
  logic [B-1:0] alu_a, alu_b, alu_out;
  logic         alu_zero_i;

  // Stack
  logic [B-1:0] stack_din_i, stack_dout_i;

  // Register file
  logic [4:0] reg_addr0_i, reg_addr1_i, reg_addr2_i, reg_addr3_i;
  logic [4:0] reg_addr4_i, reg_addr5_i, reg_addr6_i, reg_addr7_i;
  logic [B-1:0] reg_din7_i;
  logic [B-1:0] reg_dout0_i, reg_dout1_i, reg_dout2_i, reg_dout3_i;
  logic [B-1:0] reg_dout4_i, reg_dout5_i, reg_dout6_i;

  // Program counter
  logic [15:0] pc_r;
  logic [15:0] pc_i, pc_mux;

  // Instruction register
  logic [63:0] ir_r;

  // FIFO for timed instructions (shared write, per-channel read)
  logic [NCH-1:0] fifo_time_wr_en;
  logic [FW-1:0]  fifo_time_din;
  logic [NCH-1:0] fifo_time_rd_en;
  logic [FW-1:0]  fifo_time_dout [NCH];
  logic [NCH-1:0] fifo_time_full;
  logic [NCH-1:0] fifo_time_empty;

  // Time ALU
  logic [TW-1:0] alut_a, alut_b, alut_out;
  logic [TW-1:0] alut_out_r;

  // Master clock counters
  logic [TW-1:0] t_cnt;
  logic [TW-1:0] t_cnt_sync;

  // Data memory output register
  logic [B-1:0] dmem_do_r;

  // Stack output register
  logic [B-1:0] stack_dout_r;

  // Input from AXIS slaves (extracted data)
  logic [63:0] din0_i, din1_i, din2_i, din3_i;
  logic [63:0] din_mux;
  logic [B-1:0] din_i;

  // Wait handshake per channel
  logic [NCH-1:0] waitt_i;
  logic [NCH-1:0] waitt_ack_i;

  // AXIS master signals per channel (internal)
  logic [159:0] m_axis_tdata_i [NCH];
  logic [NCH-1:0] m_axis_tvalid_i;
  logic [NCH-1:0] m_axis_tready_i;

  //--------------------------------------------------------------------------
  // Synchronizers for external inputs (use cdc_gray_sync)
  //--------------------------------------------------------------------------
  cdc_gray_sync #(.N(2), .M(1)) start_src_reg_resync_i (
    .i_rstn    (rstn),
    .i_clk     (clk),
    .i_d (start_src_reg),
    .o_d(start_src_reg_resync)
  );

  cdc_gray_sync #(.N(2), .M(1)) start_reg_resync_i (
    .i_rstn    (rstn),
    .i_clk     (clk),
    .i_d (start_reg),
    .o_d(start_reg_resync)
  );

  cdc_gray_sync #(.N(2), .M(1)) start_input_resync_i (
    .i_rstn    (rstn),
    .i_clk     (clk),
    .i_d (start),
    .o_d(start_input_resync)
  );

  // Muxed start
  assign start_i = (start_src_reg_resync) ? start_input_resync : start_reg_resync;

  //--------------------------------------------------------------------------
  // Control unit (FSM) - tpv1_ctrl
  //--------------------------------------------------------------------------
  tpv1_ctrl ctrl_i (
    .clk        (clk),
    .rstn       (rstn),
    .start      (start_i),
    .opcode     (opcode_i),
    .ir_en      (ir_en_i),
    .pc_src     (pc_src_i),
    .pc_en      (pc_en_i),
    .pc_rst     (pc_rst_i),
    .alu_src_b  (alu_src_b_i),
    .alu_zero   (alu_zero_i),
    .alut_src_b (alut_src_b_i),
    .reg_src    (reg_src_i),
    .reg_wen    (reg_wen_i),
    .cond_flag  (cond_flag_i),
    .stack_en   (stack_en_i),
    .stack_op   (stack_op_i),
    .stack_full (stack_full_i),
    .stack_empty(stack_empty_i),
    .fifo_wr_en (fifo_wr_en_mux),
    .fifo_full  (fifo_full_mux),
    .dmem_we    (dmem_we),
    .addr_src   (dmem_addr_src),
    .t_en       (t_cnt_en),
    .t_sync_en  (t_cnt_sync_en),
    .waitt      (waitt_mux),
    .waitt_ack  (waitt_ack_mux)
  );

  //--------------------------------------------------------------------------
  // Instruction register fields
  //--------------------------------------------------------------------------
  assign opcode_i   = ir_r[63:56];
  assign page_i     = ir_r[55:53];
  assign channel_i  = ir_r[52:50];
  assign oper_i     = ir_r[49:46];
  assign imm_i      = { {1{ir_r[30]}}, ir_r[30:0] }; // sign-extend 31-bit to 32

  //--------------------------------------------------------------------------
  // Stack - tpv1_stack
  //--------------------------------------------------------------------------
  tpv1_stack #(.B(B)) stack_i (
    .clk   (clk),
    .rstn  (rstn),
    .en    (stack_en_i),
    .op    (stack_op_i),
    .din   (stack_din_i),
    .dout  (stack_dout_i),
    .empty (stack_empty_i),
    .full  (stack_full_i)
  );
  assign stack_din_i = reg_dout0_i;

  //--------------------------------------------------------------------------
  // Register file (8 read ports, 1 write port)
  //--------------------------------------------------------------------------
  regfile_8p #(.B(B)) regfile_i (
    .clk    (clk),
    .rstn   (rstn),
    .addr0  (reg_addr0_i),
    .addr1  (reg_addr1_i),
    .addr2  (reg_addr2_i),
    .addr3  (reg_addr3_i),
    .addr4  (reg_addr4_i),
    .addr5  (reg_addr5_i),
    .addr6  (reg_addr6_i),
    .addr7  (reg_addr7_i),
    .din7   (reg_din7_i),
    .wen7   (reg_wen_i),
    .pnum   (page_i),
    .dout0  (reg_dout0_i),
    .dout1  (reg_dout1_i),
    .dout2  (reg_dout2_i),
    .dout3  (reg_dout3_i),
    .dout4  (reg_dout4_i),
    .dout5  (reg_dout5_i),
    .dout6  (reg_dout6_i)
  );

  // Register addresses from instruction fields
  assign reg_addr0_i = ir_r[40:36];
  assign reg_addr1_i = ir_r[35:31];
  assign reg_addr2_i = ir_r[30:26];
  assign reg_addr3_i = ir_r[25:21];
  assign reg_addr4_i = ir_r[20:16];
  assign reg_addr5_i = ir_r[15:11];
  assign reg_addr6_i = ir_r[10:6];
  assign reg_addr7_i = ir_r[45:41];

  // Mux for register write data
  always_comb begin
    unique case (reg_src_i)
      3'b000: reg_din7_i = imm_i;
      3'b001: reg_din7_i = alu_out;
      3'b010: reg_din7_i = stack_dout_r;
      3'b011: reg_din7_i = din_i;
      3'b100: reg_din7_i = dmem_do_r;
      default: reg_din7_i = imm_i;
    endcase
  end

  //--------------------------------------------------------------------------
  // FIFOs and timed_ictrl per channel
  //--------------------------------------------------------------------------
  generate
    for (genvar i = 0; i < NCH; i++) begin : gen_channel
      // FIFO for timed instructions
      fifo_sync #(.B(FW), .N(16)) fifo_time_i (
        .rstn  (rstn),
        .clk   (clk),
        .wr_en (fifo_time_wr_en[i]),
        .din   (fifo_time_din),
        .rd_en (fifo_time_rd_en[i]),
        .dout  (fifo_time_dout[i]),
        .full  (fifo_time_full[i]),
        .empty (fifo_time_empty[i])
      );

      // Write enable per channel
      assign fifo_time_wr_en[i] = (channel_i == i) ? fifo_wr_en_mux : 1'b0;

      // Timed instruction dispatcher
      tpv1_timed_dispatch tdispatch_i (
        .clk          (clk),
        .rstn         (rstn),
        .t_cnt        (t_cnt),
        .fifo_rd_en   (fifo_time_rd_en[i]),
        .fifo_dout    (fifo_time_dout[i]),
        .fifo_empty   (fifo_time_empty[i]),
        .waitt        (waitt_i[i]),
        .waitt_ack    (waitt_ack_i[i]),
        .m_axis_tdata (m_axis_tdata_i[i]),
        .m_axis_tvalid(m_axis_tvalid_i[i]),
        .m_axis_tready(m_axis_tready_i[i])
      );

      // Wait acknowledge per channel (only the selected one)
      assign waitt_ack_i[i] = (channel_i == i) ? waitt_ack_mux : 1'b0;
    end
  endgenerate

  // FIFO write data (shared across channels)
  assign fifo_time_din = {
    opcode_i,
    alut_out_r,
    reg_dout5_i,
    reg_dout4_i,
    reg_dout3_i,
    reg_dout2_i,
    reg_dout0_i
  };

  // Muxed fifo full and wait for control unit
  assign fifo_full_mux = fifo_time_full[channel_i];
  assign waitt_mux     = waitt_i[channel_i];

  //--------------------------------------------------------------------------
  // AXI4-Stream master ready connections
  //--------------------------------------------------------------------------
  assign m_axis_tready_i[0] = m0_axis.tready;
  assign m_axis_tready_i[1] = m1_axis.tready;
  assign m_axis_tready_i[2] = m2_axis.tready;
  assign m_axis_tready_i[3] = m3_axis.tready;
  assign m_axis_tready_i[4] = m4_axis.tready;
  assign m_axis_tready_i[5] = m5_axis.tready;
  assign m_axis_tready_i[6] = m6_axis.tready;
  assign m_axis_tready_i[7] = m7_axis.tready;

  // Master outputs (drive from internal)
  assign m0_axis.tdata  = m_axis_tdata_i[0];
  assign m0_axis.tvalid = m_axis_tvalid_i[0];
  assign m1_axis.tdata  = m_axis_tdata_i[1];
  assign m1_axis.tvalid = m_axis_tvalid_i[1];
  assign m2_axis.tdata  = m_axis_tdata_i[2];
  assign m2_axis.tvalid = m_axis_tvalid_i[2];
  assign m3_axis.tdata  = m_axis_tdata_i[3];
  assign m3_axis.tvalid = m_axis_tvalid_i[3];
  assign m4_axis.tdata  = m_axis_tdata_i[4];
  assign m4_axis.tvalid = m_axis_tvalid_i[4];
  assign m5_axis.tdata  = m_axis_tdata_i[5];
  assign m5_axis.tvalid = m_axis_tvalid_i[5];
  assign m6_axis.tdata  = m_axis_tdata_i[6];
  assign m6_axis.tvalid = m_axis_tvalid_i[6];
  assign m7_axis.tdata  = m_axis_tdata_i[7];
  assign m7_axis.tvalid = m_axis_tvalid_i[7];

  //--------------------------------------------------------------------------
  // Data memory address mux
  //--------------------------------------------------------------------------
  assign dmem_addr = (dmem_addr_src) ? reg_dout0_i : imm_i;
  assign dmem_di   = reg_dout1_i;

  //--------------------------------------------------------------------------
  // Conditional unit
  //--------------------------------------------------------------------------
  signed_comparator #(.B(B)) signed_comp_i (
    .clk    (clk),
    .rstn   (rstn),
    .din_a  (reg_dout0_i),
    .din_b  (reg_dout1_i),
    .op     (oper_i),
    .flag   (cond_flag_i)
  );

  //--------------------------------------------------------------------------
  // ALU
  //--------------------------------------------------------------------------
  alu #(.B(B)) alu_i (
    .clk    (clk),
    .rstn   (rstn),
    .din_a  (alu_a),
    .din_b  (alu_b),
    .op     (oper_i),
    .zero_a (alu_zero_i),
    .zero_b (),
    .dout   (alu_out)
  );

  assign alu_a = reg_dout0_i;
  always_comb begin
    unique case (alu_src_b_i)
      2'b00: alu_b = imm_i;
      2'b01: alu_b = reg_dout1_i;
      2'b10: alu_b = -1;
      default: alu_b = 0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Slave AXIS readers (s_axis_read)
  //--------------------------------------------------------------------------
  axis_set_reg #(.DATA_WIDTH(64)) s0_axis_read_i (
    .s_axis_aclk    (clk),
    .s_axis_aresetn   (rstn),
    .s_axis_tdata (s0_axis.tdata),
    .s_axis_tvalid(s0_axis.tvalid),
    .s_axis_tready(s0_axis.tready),
    .dout   (din0_i)
  );

  axis_set_reg #(.DATA_WIDTH(64)) s1_axis_read_i (
    .s_axis_aclk    (clk),
    .s_axis_aresetn   (rstn),
    .s_axis_tdata (s1_axis.tdata),
    .s_axis_tvalid(s1_axis.tvalid),
    .s_axis_tready(s1_axis.tready),
    .dout   (din1_i)
  );

  axis_set_reg #(.DATA_WIDTH(64)) s2_axis_read_i (
    .s_axis_aclk    (clk),
    .s_axis_aresetn   (rstn),
    .s_axis_tdata (s2_axis.tdata),
    .s_axis_tvalid(s2_axis.tvalid),
    .s_axis_tready(s2_axis.tready),
    .dout   (din2_i)
  );

  axis_set_reg #(.DATA_WIDTH(64)) s3_axis_read_i (
    .s_axis_aclk    (clk),
    .s_axis_aresetn   (rstn),
    .s_axis_tdata (s3_axis.tdata),
    .s_axis_tvalid(s3_axis.tvalid),
    .s_axis_tready(s3_axis.tready),
    .dout   (din3_i)
  );

  // Mux input data by channel
  always_comb begin
    unique case (channel_i)
      3'd0: din_mux = din0_i;
      3'd1: din_mux = din1_i;
      3'd2: din_mux = din2_i;
      3'd3: din_mux = din3_i;
      default: din_mux = 0;
    endcase
  end

  // Select upper/lower 32 bits based on operation
  assign din_i = (oper_i == 4'b1010) ? din_mux[63:32] : din_mux[31:0];

  //--------------------------------------------------------------------------
  // Time ALU
  //--------------------------------------------------------------------------
  assign alut_a = t_cnt_sync;
  assign alut_b = (alut_src_b_i) ? imm_i : reg_dout1_i;
  assign alut_out = alut_a + alut_b;

  //--------------------------------------------------------------------------
  // Sequential logic (registers)
  //--------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pc_r        <= 0;
      ir_r        <= 0;
      alut_out_r  <= 0;
      t_cnt       <= 0;
      t_cnt_sync  <= 0;
      dmem_do_r   <= 0;
      stack_dout_r<= 0;
    end else begin
      // Program counter
      if (pc_rst_i)
        pc_r <= 0;
      else if (pc_en_i)
        pc_r <= pc_mux;

      // Instruction register
      if (ir_en_i)
        ir_r <= pmem_do;

      // Time ALU output register
      alut_out_r <= alut_out;

      // Master clock counter
      if (pc_rst_i)
        t_cnt <= 0;
      else if (t_cnt_en)
        t_cnt <= t_cnt + 1;

      // Synced master clock
      if (pc_rst_i)
        t_cnt_sync <= 0;
      else if (t_cnt_sync_en)
        t_cnt_sync <= alut_out_r;

      // Data memory read register
      dmem_do_r <= dmem_do;

      // Stack read register
      stack_dout_r <= stack_dout_i;
    end
  end

  // Program counter next value
  assign pc_i    = pc_r + 1;
  assign pc_mux  = (pc_src_i) ? imm_i : pc_i;

  // Outputs
  assign pmem_addr = pc_r;

endmodule
