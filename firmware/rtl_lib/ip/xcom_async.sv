///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom_async.sv
// Project: QICK
// Description:
// Top-level IP wrapper for the async 8b/10b embedded-clock inter-board link
// (link_tx/link_rx), packaged as an XCOM-successor peripheral for a
// qick_processor QPeriphA (QP1) port. Mirrors xcom.sv's own shape (AXI-Lite
// regfile + xcom_cdc + xcom_cmd + the command-dispatch/transport core) with
// the transport swapped to xcom_async_txrx (see that module's header for the
// full rationale) and the differential-line PHY replaced by the byte/symbol-
// level interface that link_ch01_top.sv's PHY (rx_one_to_ten/riu_statemach)
// already exposes -- this IP does NOT own the PHY, unlike xcom.sv which owns
// its own diff_in_nb/diff_out_nb IOBUFs. i_time_clk/i_time_rstn play the same
// role xcom_cdc/xcom_cmd already expect, but in this build they must be
// driven with tx_fabric_clk (see xcom_async_txrx.sv's CLOCK DOMAINS note) --
// not a free-running reference clock as in the original XCOM.
//
//Inputs:
// - i_ps_clk/i_ps_rstn      AXI-Lite domain (PS)
// - i_core_clk/i_core_rstn  QPeriphA domain (qick_processor core clock)
// - i_time_clk/i_time_rstn  dispatch/TX domain -- drive with tx_fabric_clk
// - i_rx_clk/i_rx_rstn      RX domain -- drive with rx_fabric_clk
// - i_en/i_rx_en            link enables (PLL-locked & ~logic_rst), from the
//                           PHY integration layer (link_ch01_top.sv style)
// QICK PERIPHERAL INTERFACE (i_core_clk), same contract as xcom.sv/QPeriphA
// - i_core_en/i_core_op/i_core_data1/i_core_data2
// Qick CONTROL
// - i_sync                  external sync input (XCOM_QRST_SYNC coordination)
// Link RX <- PHY (i_rx_clk domain), mirrors link_ch01_top.sv's own link_rx
// port names 1:1 so the PHY integration layer can wire straight through.
// Link TX -> PHY (i_time_clk domain)
// AXI-Lite Slave I/F (i_ps_clk)
//
//Outputs:
// QICK PERIPHERAL INTERFACE (i_core_clk)
// - o_core_ready/o_core_data1/o_core_data2/o_core_valid/o_core_flag
// Qick CONTROL
// - o_proc_start/o_proc_stop/o_time_rst/o_time_update/o_time_update_data
// - o_core_start/o_core_stop
// XCOM
// - o_xcom_id
//
// Change history: 08/19/26 - v1 Started by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module xcom_async import qick_pkg::*;
  # (
    parameter int DEBUG = 1
  )(
    input  logic             i_ps_clk           ,
    input  logic             i_ps_rstn          ,
    input  logic             i_core_clk         ,
    input  logic             i_core_rstn        ,
    input  logic             i_time_clk         , // drive with tx_fabric_clk
    input  logic             i_time_rstn        ,
    input  logic             i_rx_clk           , // drive with rx_fabric_clk
    input  logic             i_rx_rstn          ,
    input  logic             i_en               , // tx_link_en
    input  logic             i_rx_en            , // rx_link_en
    // QICK PERIPHERAL INTERFACE (i_core_clk)
    input  logic             i_core_en          ,
    input  logic   [5-1:0]   i_core_op          ,
    input  logic  [32-1:0]   i_core_data1       ,
    input  logic  [32-1:0]   i_core_data2       ,
    output logic             o_core_ready       ,
    output logic  [32-1:0]   o_core_data1       ,
    output logic  [32-1:0]   o_core_data2       ,
    output logic             o_core_valid       ,
    output logic             o_core_flag        ,
    // Qick CONTROL
    input  logic             i_sync             ,
    output logic             o_proc_start       , // i_time_clk domain
    output logic             o_proc_stop        , // i_time_clk domain
    output logic             o_time_rst         , // i_time_clk domain
    output logic             o_time_update      , // i_time_clk domain
    output logic  [32-1:0]   o_time_update_data , // i_time_clk domain
    output logic             o_core_start       , // core_clk domain
    output logic             o_core_stop        , // core_clk domain
    // XCOM
    output logic   [4-1:0]   o_xcom_id          ,
    // Link TX -> PHY (i_time_clk domain)
    output logic [7:0]       o_tx_byte          ,
    output logic             o_tx_byte_valid    ,
    // Link RX <- PHY (i_rx_clk domain) -- mirrors link_ch01_top.sv's link_rx port names
    input  logic [3:0]       i_rx_mstr_q        ,
    input  logic [3:0]       i_rx_slve_q        ,
    input  logic             i_rx_fifo_empty    ,
    input  logic [8:0]       i_rx_mstr_cntvalout,
    input  logic [8:0]       i_rx_slve_cntvalout,
    input  logic [8:0]       i_rx_btval         ,
    output logic [8:0]       o_rx_mstr_cntvalin ,
    output logic             o_rx_mstr_load     ,
    output logic [8:0]       o_rx_slve_cntvalin ,
    output logic             o_rx_slve_load     ,
    output logic             o_rx_aligned       , // rx_fabric_clk domain
    // AXI-Lite DATA Slave I/F (i_ps_clk)
    input  logic   [7-1:0]   s_axi_awaddr       ,
    input  logic   [3-1:0]   s_axi_awprot       ,
    input  logic             s_axi_awvalid      ,
    output logic             s_axi_awready      ,
    input  logic  [32-1:0]   s_axi_wdata        ,
    input  logic  [ 4-1:0]   s_axi_wstrb        ,
    input  logic             s_axi_wvalid       ,
    output logic             s_axi_wready       ,
    output logic  [ 2-1:0]   s_axi_bresp        ,
    output logic             s_axi_bvalid       ,
    input  logic             s_axi_bready       ,
    input  logic  [ 7-1:0]   s_axi_araddr       ,
    input  logic  [ 3-1:0]   s_axi_arprot       ,
    input  logic             s_axi_arvalid      ,
    output logic             s_axi_arready      ,
    output logic  [32-1:0]   s_axi_rdata        ,
    output logic  [ 2-1:0]   s_axi_rresp        ,
    output logic             s_axi_rvalid       ,
    input  logic             s_axi_rready       ,
    // DEBUG
    output logic  [32-1:0]   o_dbg_probe1,
    output logic  [32-1:0]   o_dbg_probe2
  );

  // Signal Declaration
  ///////////////////////////////////////////////////////////////////////////////
  logic [ 8-1:0] s_op ;
  logic [32-1:0] s_data;
  logic [ 4-1:0] s_cmd_cntr;

  logic          s_cfg_sync_dis;
  logic          s_clear_cnt;

  logic [32-1:0] s_xcom_ctrl ;
  logic [32-1:0] s_xcom_ctrl_sync ;
  logic [32-1:0] s_xcom_cfg ;
  logic [32-1:0] s_xcom_cfg_sync ;
  logic [32-1:0] s_axi_data1;
  logic [32-1:0] s_axi_data1_sync;
  logic [32-1:0] s_axi_data2 ;
  logic [32-1:0] s_axi_data2_sync;
  logic [32-1:0] s_axi_addr ;
  logic          s_core_en;
  logic [ 5-1:0] s_core_op;
  logic [2-1:0][32-1:0] s_core_data ;
  logic [2-1:0][32-1:0] s_ps_data   ;
  logic          s_req_loc;
  logic          s_ack_loc;
  logic          s_req_net;
  logic          s_ack_net;
  logic          s_sync;

  logic          s_core_ready;
  logic          s_core_ready_sync;
  logic          s_core_ready_ack;
  logic          s_core_valid;
  logic          s_core_flag;
  logic          s_xcom_flag_ps;
  logic [32-1:0] s_core_data1;
  logic [32-1:0] s_core_data1_sync;
  logic [32-1:0] s_core_data2;
  logic [32-1:0] s_core_data2_sync;
  logic [32-1:0] s_core_data1_ps;
  logic [32-1:0] s_core_data2_ps;
  logic          s_core_start;
  logic          s_core_stop;

  logic [32-1:0] xcom_mem_data [16];
  logic [32-1:0] axi_mem_data;

  logic [32-1:0] xreg_debug;
  logic [32-1:0] xreg_status;

  logic [32-1:0] s_dbg_rx_data      ;
  logic [32-1:0] s_dbg_tx_data      ;
  logic [32-1:0] s_dbg_status       ;
  logic [32-1:0] s_dbg_debug        ;
  logic [32-1:0] s_dbg_rx_data_ps   ;
  logic [32-1:0] s_dbg_tx_data_ps   ;
  logic [32-1:0] s_dbg_status_ps    ;
  logic [32-1:0] s_dbg_debug_ps     ;
  logic [32-1:0] s_frame_ok_cnt     ;
  logic [32-1:0] s_crc_err_cnt      ;
  logic [32-1:0] s_frame_ok_cnt_ps  ;
  logic [32-1:0] s_crc_err_cnt_ps   ;
  logic [ 4-1:0] s_xcom_id          ;
  logic [ 4-1:0] s_xcom_id_ps       ;

  ///////////////////////////////////////////////////////////////////////////////
  // AXI Registers
  ///////////////////////////////////////////////////////////////////////////////
  // Reg map (byte addr / 4 = index into o_slv_regs/i_slv_regs):
  //   0 CTRL  1 CFG  2 AXI_DATA1  3 AXI_DATA2  4 ADDR  5 (reserved)  -- RW (PS)
  //   6 ID  7 FLAG  8 DATA1  9 DATA2  10 MEM  11 RX_DATA  12 TX_DATA
  //   13 STATUS  14 DEBUG  15 FRAME_OK_CNT  16 CRC_ERR_CNT  17 (reserved)   -- RO (hw)
  // CFG[0]=cfg_sync_dis, CFG[1]=clear_cnt (link_rx frame_ok/crc_err counters)
  localparam int XCOM_NUM_REGS = 18;
  localparam logic [XCOM_NUM_REGS-1:0] XCOM_REG_RO = 18'h3FFC0; // regs 6..17 read-only

  logic [32-1:0] o_slv_regs [XCOM_NUM_REGS];
  logic [32-1:0] i_slv_regs [XCOM_NUM_REGS];

  axil_slv #(
    .AXI_AW    ( 7  ),
    .AXI_DW    ( 32 ),
    .NUM_REGS  ( XCOM_NUM_REGS )
  ) u_xcom_axil_slv(
    .s_axi_aclk      ( i_ps_clk           ),
    .s_axi_aresetn   ( i_ps_rstn          ),
    .s_axi_awaddr    ( s_axi_awaddr       ),
    .s_axi_awprot    ( s_axi_awprot       ),
    .s_axi_awvalid   ( s_axi_awvalid      ),
    .s_axi_awready   ( s_axi_awready      ),
    .s_axi_wdata     ( s_axi_wdata        ),
    .s_axi_wstrb     ( s_axi_wstrb        ),
    .s_axi_wvalid    ( s_axi_wvalid       ),
    .s_axi_wready    ( s_axi_wready       ),
    .s_axi_bresp     ( s_axi_bresp        ),
    .s_axi_bvalid    ( s_axi_bvalid       ),
    .s_axi_bready    ( s_axi_bready       ),
    .s_axi_araddr    ( s_axi_araddr       ),
    .s_axi_arprot    ( s_axi_arprot       ),
    .s_axi_arvalid   ( s_axi_arvalid      ),
    .s_axi_arready   ( s_axi_arready      ),
    .s_axi_rdata     ( s_axi_rdata        ),
    .s_axi_rresp     ( s_axi_rresp        ),
    .s_axi_rvalid    ( s_axi_rvalid       ),
    .s_axi_rready    ( s_axi_rready       ),
    .o_slv_regs      ( o_slv_regs         ),
    .i_slv_regs      ( i_slv_regs         ),
    .i_reg_is_readonly( XCOM_REG_RO       )
  );

  // RW registers (PS-writable; downstream logic just reads the live value)
  assign s_xcom_ctrl = o_slv_regs[0];
  assign s_xcom_cfg  = o_slv_regs[1];
  assign s_axi_data1 = o_slv_regs[2];
  assign s_axi_data2 = o_slv_regs[3];
  assign s_axi_addr  = o_slv_regs[4];

  // AXI read data from Memory (indexed by the ADDR register, not the AXI addr)
  assign axi_mem_data = xcom_mem_data[s_axi_addr[4-1:0]];

  // RO registers (hardware-driven; reads return these, writes are blocked)
  assign i_slv_regs[0]  = '0; // RW slot, unused by axil_slv's read mux
  assign i_slv_regs[1]  = '0;
  assign i_slv_regs[2]  = '0;
  assign i_slv_regs[3]  = '0;
  assign i_slv_regs[4]  = '0;
  assign i_slv_regs[5]  = '0;
  assign i_slv_regs[6]  = {28'h000_0000, s_xcom_id_ps};
  assign i_slv_regs[7]  = {31'd0, s_xcom_flag_ps};
  assign i_slv_regs[8]  = s_core_data1_ps;
  assign i_slv_regs[9]  = s_core_data2_ps;
  assign i_slv_regs[10] = axi_mem_data;
  assign i_slv_regs[11] = s_dbg_rx_data_ps;
  assign i_slv_regs[12] = s_dbg_tx_data_ps;
  assign i_slv_regs[13] = xreg_status;
  assign i_slv_regs[14] = xreg_debug;
  assign i_slv_regs[15] = s_frame_ok_cnt_ps;
  assign i_slv_regs[16] = s_crc_err_cnt_ps;
  assign i_slv_regs[17] = '0; // reserved

  xcom_cdc u_xcom_cdc(
    .i_ps_clk           ( i_ps_clk         ),
    .i_ps_rstn          ( i_ps_rstn        ),
    .i_core_clk         ( i_core_clk       ),
    .i_core_rstn        ( i_core_rstn      ),
    .i_time_clk         ( i_time_clk       ),
    .i_time_rstn        ( i_time_rstn      ),
    // async domain
    .i_sync             ( i_sync           ),
    .s_sync             ( s_sync           ),
    //core domain - time domain
    .i_core_en          ( i_core_en        ),
    .i_core_op          ( i_core_op        ),
    .i_core_data1       ( i_core_data1     ),
    .i_core_data2       ( i_core_data2     ),
    .o_core_en_sync     ( s_core_en        ),
    .o_core_op_sync     ( s_core_op        ),
    .o_core_data1_sync  ( s_core_data1_sync),
    .o_core_data2_sync  ( s_core_data2_sync),
    //time domain - core domain
    .i_core_ready       ( s_core_ready     ),
    .i_core_valid       ( s_core_valid     ),
    .i_core_flag        ( s_core_flag      ),
    .i_core_data1_core  ( s_core_data1     ),
    .i_core_data2_core  ( s_core_data2     ),
    .i_core_start       ( s_core_start     ),
    .i_core_stop        ( s_core_stop      ),
    .o_core_ready_sync  ( s_core_ready_sync),
    .o_core_valid_sync  ( o_core_valid     ),
    .o_core_flag_sync   ( o_core_flag      ),
    .o_core_data1_core  ( o_core_data1     ),
    .o_core_data2_core  ( o_core_data2     ),
    .o_core_start_sync  ( o_core_start     ),
    .o_core_stop_sync   ( o_core_stop      ),
    //PS time domain - time domain
    .i_xcom_ctrl        ( s_xcom_ctrl      ),
    .i_xcom_cfg         ( s_xcom_cfg       ),
    .i_axi_data1        ( s_axi_data1      ),
    .i_axi_data2        ( s_axi_data2      ),
    .o_xcom_ctrl_sync   ( s_xcom_ctrl_sync ),
    .o_xcom_cfg_sync    ( s_xcom_cfg_sync  ),
    .o_axi_data1_sync   ( s_axi_data1_sync ),
    .o_axi_data2_sync   ( s_axi_data2_sync ),
    //core domain - PS time domain
    .o_xcom_flag_sync   ( s_xcom_flag_ps   ),
    .o_xcom_data1_sync  ( s_core_data1_ps  ),
    .o_xcom_data2_sync  ( s_core_data2_ps  ),
    //time domain - PS time domain
    .i_xcom_id          ( s_xcom_id        ),
    .i_xcom_rx_data     ( s_dbg_rx_data    ),
    .i_xcom_tx_data     ( s_dbg_tx_data    ),
    .i_xcom_status      ( s_dbg_status     ),
    .i_xcom_debug       ( s_dbg_debug      ),
    .o_xcom_id_sync     ( s_xcom_id_ps     ),
    .o_xcom_rx_data_sync( s_dbg_rx_data_ps ),
    .o_xcom_tx_data_sync( s_dbg_tx_data_ps ),
    .o_xcom_status_sync ( s_dbg_status_ps  ),
    .o_xcom_debug_sync  ( s_dbg_debug_ps   )
  );

  // frame_ok_cnt/crc_err_cnt: monotonic monitoring counters, same "no
  // synchronizer needed for data buses" convention xcom_cdc already applies
  // to dbg_rx_data/dbg_tx_data/dbg_status/dbg_debug (an occasional torn read
  // self-corrects on the next AXI poll).
  assign s_frame_ok_cnt_ps = s_frame_ok_cnt;
  assign s_crc_err_cnt_ps  = s_crc_err_cnt;

  //Add two registers here to solve the o_qp_ready signal
  //being asserted for too many core_clk cycles after a
  //tproc_en signal.
  always_ff @ (posedge i_core_clk) begin
    if ( !i_core_rstn ) begin
      s_core_ready_ack   <= 1'b0;
    end else begin
      if (i_core_en & s_core_ready_sync) begin
          s_core_ready_ack   <= 1'b1;
      end
      if (s_core_ready_ack & ~s_core_ready_sync) begin
        s_core_ready_ack  <= 1'b0;
      end
    end
  end
  assign o_core_ready = ~s_core_ready_ack & s_core_ready_sync;

  assign s_core_data  = {s_core_data2_sync, s_core_data1_sync};
  assign s_ps_data    = {s_axi_data2_sync, s_axi_data1_sync};

  xcom_cmd u_xcom_cmd(
    .i_clk           ( i_time_clk       ),
    .i_rstn          ( i_time_rstn      ),
    .i_core_en       ( s_core_en        ),
    .i_core_op       ( s_core_op        ),
    .i_core_data     ( s_core_data      ),
    .i_ps_ctrl       ( s_xcom_ctrl_sync[6-1:0] ),
    .i_ps_data       ( s_ps_data        ),
    .o_req_loc       ( s_req_loc        ),
    .i_ack_loc       ( s_ack_loc        ),
    .o_req_net       ( s_req_net        ),
    .i_ack_net       ( s_ack_net        ),
    .o_op            ( s_op             ),
    .o_data          ( s_data           ),
    .o_cmd_cntr      ( s_cmd_cntr       )
  );

  assign s_cfg_sync_dis = s_xcom_cfg_sync[0];
  assign s_clear_cnt    = s_xcom_cfg_sync[1];

  xcom_async_txrx u_xcom_async_txrx(
    .i_clk               ( i_time_clk         ),
    .i_rstn              ( i_time_rstn        ),
    .i_en                ( i_en               ),
    .i_rx_clk             ( i_rx_clk           ),
    .i_rx_rstn            ( i_rx_rstn          ),
    .i_rx_en              ( i_rx_en            ),
    .i_sync               ( s_sync             ),
    .i_req_loc            ( s_req_loc          ),
    .i_req_net            ( s_req_net          ),
    .i_header             ( s_op               ),
    .i_data               ( s_data             ),
    .i_cmd_cntr           ( s_cmd_cntr         ),
    .o_ack_loc            ( s_ack_loc          ),
    .o_ack_net            ( s_ack_net          ),
    .o_qp_ready           ( s_core_ready       ),
    .o_qp_valid           ( s_core_valid       ),
    .o_qp_flag            ( s_core_flag        ),
    .o_qp_data1           ( s_core_data1       ),
    .o_qp_data2           ( s_core_data2       ),
    .o_proc_start         ( o_proc_start       ),
    .o_proc_stop          ( o_proc_stop        ),
    .o_time_rst           ( o_time_rst         ),
    .o_time_update        ( o_time_update      ),
    .o_time_update_data   ( o_time_update_data ),
    .o_core_start         ( s_core_start       ),
    .o_core_stop          ( s_core_stop        ),
    .i_cfg_sync_dis       ( s_cfg_sync_dis     ),
    .o_xcom_id            ( s_xcom_id          ),
    .o_xcom_mem           ( xcom_mem_data      ),
    .o_tx_byte            ( o_tx_byte          ),
    .o_tx_byte_valid      ( o_tx_byte_valid    ),
    .i_rx_mstr_q          ( i_rx_mstr_q        ),
    .i_rx_slve_q          ( i_rx_slve_q        ),
    .i_rx_fifo_empty      ( i_rx_fifo_empty    ),
    .i_rx_mstr_cntvalout  ( i_rx_mstr_cntvalout),
    .i_rx_slve_cntvalout  ( i_rx_slve_cntvalout),
    .i_rx_btval           ( i_rx_btval         ),
    .o_rx_mstr_cntvalin   ( o_rx_mstr_cntvalin ),
    .o_rx_mstr_load       ( o_rx_mstr_load     ),
    .o_rx_slve_cntvalin   ( o_rx_slve_cntvalin ),
    .o_rx_slve_load       ( o_rx_slve_load     ),
    .o_rx_aligned         ( o_rx_aligned       ),
    .i_clear_cnt          ( s_clear_cnt        ),
    .o_dbg_rx_data        ( s_dbg_rx_data      ),
    .o_dbg_tx_data        ( s_dbg_tx_data      ),
    .o_dbg_status         ( s_dbg_status       ),
    .o_dbg_data           ( s_dbg_debug        ),
    .o_frame_ok_cnt       ( s_frame_ok_cnt     ),
    .o_crc_err_cnt        ( s_crc_err_cnt      )
  );

  assign o_xcom_id   = s_xcom_id;
  assign xreg_status = s_dbg_status_ps;

  ///////////////////////////////////////////////////////////////////////////////
  // DEBUG
  ///////////////////////////////////////////////////////////////////////////////
  generate
    if (DEBUG == 0) begin : gen_debug_no
      assign xreg_debug  = '{default:'0} ;
    end else if (DEBUG == 1) begin : gen_debug_yes
      assign xreg_debug  = s_dbg_debug_ps;
    end
  endgenerate

  // DEBUG PROBES
  //////////////////////////////////////////////////////////////////////////////
  assign o_dbg_probe1 = s_dbg_status;
  assign o_dbg_probe2 = s_dbg_debug;

endmodule
