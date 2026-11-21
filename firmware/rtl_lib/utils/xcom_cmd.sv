///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom_cmd.sv
// Project: QICK
// Description:
// Wrapper and synchronizer block for the XCOM core.
//
//Inputs:
// - i_clk        clock signal
// - i_rstn       active low reset signal
// - i_core_en    data valid signal coming from the core processor. Indicates
//                a valid data is ready for transmission.
// - i_core_op    opcode from the core. See xcom opcodes in qick_pkg
// - i_core_data  data to be transmitted, coming from the core processor.
// - i ps_ctrl    port used to send opcode and data valid signal from Python.
//                bits [5:1] determines the operation to be done. See xcom
//                           opcodes in qick_pkg.
//                bit 0      data valid signal coming from Python. Indicates
//                           a valid data is ready for transmission.
// - i_ps_data    the data to be transmitted, coming from Python
// - i_ack_loc    acknowledge signal to LOCAL commands. This signal is
//                generated internally in the core xcom_txrx.
// - i_ack_net    acknowledge signal to NETWORK commands. This signal is
//                generated internally in the core xcom_txrx.
//
//Outputs:
// - o_req_loc    signal requesting a LOCAL command.
// - o_req_net    signal requesting a NETWORK command.
// - o_op         opcode transmitted
// - o_data       data transmittted
// - o_cmd_cntr   command counter for debug
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/06/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//                 11/24/25 - @lharnaldi - Bug fix. Change the selection
//                            of valid signals using i_core_en
//                            or i_ps_ctrl[0].
//
// BUG FIX (2026-09-22): i_ps_ctrl[0] used to feed s_valid as a raw level. Upstream, xcom's CTRL_REG had
// no self-clear and i_ps_ctrl[0] crosses into i_clk (i_time_clk) through a plain 2-flop synchroniser
// (xcom_cdc's cdc_bit_sync) with no edge detection of its own, so as long as the level stayed high (which,
// before the CTRL_REG fix, was forever) req_ack_cmd's request/acknowledge FSM re-entered IDLE and
// immediately re-issued the SAME command, over and over -- confirmed in simulation (xcom's own bench,
// driven over its AXI4-Lite port): 13 repeats in 300 clocks. i_core_en does not have this problem (it is
// already a one-cycle pulse from the tProc peripheral bus), but i_ps_ctrl[0] needed a real one-shot: it is
// now edge-detected (ps_ctrl0_r / ps_valid_pulse below), same pattern as qtt_cmd.sv's p_en_r_t01. This
// only fixes ONE of the two things wrong with the AXI command path -- the other is that xcom.sv's CTRL_REG
// (register 0) did not self-clear at all, so the edge above never repeated for a second command either;
// see xcom.sv (AUTO_CLEAR_BIT0) and xcom_cmd_hold (which also holds CTRL_REG's opcode bits stable, since
// they cross into i_time_clk with no synchroniser at all).
///////////////////////////////////////////////////////////////////////////////
module xcom_cmd(
  input  logic                  i_clk            ,
  input  logic                  i_rstn           ,
  // Command from tProcessor
  input  logic                  i_core_en       ,
  input  logic [ 5-1:0]         i_core_op       ,
  input  logic [2-1:0][32-1:0]  i_core_data     ,
  // Command from Python
  input  logic [ 6-1:0]         i_ps_ctrl        ,
  input  logic [2-1:0][32-1:0]  i_ps_data        ,
  // Command Execution
  output logic                  o_req_loc        ,
  input  logic                  i_ack_loc        ,
  output logic                  o_req_net        ,
  input  logic                  i_ack_net        ,
  output logic [ 8-1:0]         o_op             ,
  output logic [32-1:0]         o_data           ,
  output logic [ 4-1:0]         o_cmd_cntr
);

  logic          s_ack;
  logic          s_valid;
  logic  [5-1:0] s_op;
  logic  [4-1:0] s_addr;
  logic [32-1:0] s_data;

  // i_ps_ctrl[0] reaches i_clk through a plain level synchroniser (no edge detection of its own, see the
  // BUG FIX note above): turn it into a one-shot pulse here so a command is accepted exactly once per rising
  // edge, regardless of how long the source held the level high.
  logic ps_ctrl0_r;
  always_ff @(posedge i_clk) begin
     if (!i_rstn) ps_ctrl0_r <= 1'b0;
     else         ps_ctrl0_r <= i_ps_ctrl[0];
  end
  wire ps_valid_pulse = i_ps_ctrl[0] & ~ps_ctrl0_r;

  //I/O selection - PS valid bit selects PS path
  assign s_valid = ps_valid_pulse | i_core_en;
  assign s_op    = i_ps_ctrl[0] ? i_ps_ctrl[5:1]    : i_core_op;
  assign s_addr  = i_ps_ctrl[0] ? i_ps_data[0][3:0] : i_core_data[0][3:0];
  assign s_data  = i_ps_ctrl[0] ? i_ps_data[1]      : i_core_data[1];
  assign s_ack   = i_ack_loc ? i_ack_loc : i_ack_net;

  // Command Request
  ///////////////////////////////////////////////////////////////////////////////
  req_ack_cmd u_req_ack_cmd(
    .i_clk      ( i_clk       ),
    .i_rstn     ( i_rstn      ),
    .i_valid    ( s_valid     ),
    .i_op       ( s_op        ),
    .i_addr     ( s_addr      ),
    .i_data     ( s_data      ),
    .i_ack      ( s_ack       ),
    .o_req_loc  ( o_req_loc   ),
    .o_req_net  ( o_req_net   ),
    .o_op       ( o_op        ),
    .o_data     ( o_data      ),
    .o_cmd_cntr ( o_cmd_cntr  )
  );

endmodule
