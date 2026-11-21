`ifndef TPV2_PKG_SV
`define TPV2_PKG_SV

package tpv2_pkg;
  // tProc v2 related constants/definitions.
  // Ported from firmware/ip/qick_processor/src/_qproc_defines.svh.
  // NOTE: the AXI-Lite / DMEM SV interfaces (TYPE_IF_AXI_REG, TYPE_IF_MEM) and
  // the `AXIS_IN_DW` / `AXI_*_WIDTH` macros from the legacy header are not
  // ported here (interfaces cannot live inside a package); the generic
  // qick:interfaces:axi4_lite_if / qick:interfaces:bram_if cores cover that
  // role for the modules ported so far.

  // Instruction HEADER (op_code[15:13])
  localparam bit [2:0] CFG      = 3'b000;
  localparam bit [2:0] BRANCH   = 3'b001;
  localparam bit [2:0] INT_CTRL = 3'b010;
  localparam bit [2:0] EXT_CTRL = 3'b011;
  localparam bit [2:0] REG_WR   = 3'b100;
  localparam bit [2:0] MEM_WR   = 3'b101;
  localparam bit [2:0] PORT_WR  = 3'b110;

  typedef struct packed {
    bit       we;
    bit       r_wave_we;
    bit [6:0] addr;
    bit [1:0] src;
    bit       port_re;
  } CTRL_REG;

  typedef struct packed {
    bit       cfg_addr_imm;
    bit       cfg_dt_imm;
    bit       cfg_port_src;
    bit       cfg_port_type;
    bit       cfg_port_time;
    bit [3:0] cfg_cond;
    bit       cfg_alu_src;
    bit [3:0] cfg_alu_op;
    bit [8:0] usr_ctrl;
    bit       flag_we;
    bit       dmem_we;
    bit       wmem_we;
    bit       port_we;
  } CTRL_FLOW;

  typedef struct packed {
    logic [31:0]  p_time;
    logic         p_type;  // 0-WAVE 1-DATA
    logic [5:0]   p_addr;
    logic [167:0] p_data;
  } PORT_DT;

  typedef struct packed {
    logic [47:0] qtp_time;
    logic [7:0]  qtp_version;
    logic [7:0]  qtp_cfg;
    logic [7:0]  qtp_ctrl;
    logic [7:0]  qtp_dst;
    logic [15:0] qtp_len;
  } QTP_CTRL;

endpackage

`endif
