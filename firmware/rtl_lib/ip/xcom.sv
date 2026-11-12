///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom.sv
// Project: QICK
// Description:
// Transmitter and Receiver interface for the XCOM block.
//
//Inputs:
// - i_ps_clk     clock signal sync to PS
// - i_ps_rstn    active low reset signal sync to PS
// - i_core_clk   clock signal sync to CORE
// - i_core_rstn  active low reset signal sync to CORE
// - i_time_clk   clock signal sync to TIME
// - i_time_rstn  active low reset signal sync to TIME
// QICK PERIPHERAL INTERFACE (i_core_clk)
// - i_core_en    data valid signal coming from the core processor. Indicates
//                a valid data is ready for transmission.
// - i_core_op    opcode from the core. See xcom opcodes in qick_pkg
// - i_core_data1 data1 to be transmitted, coming from the core processor.
// - i_core_data2 data2 to be transmitted, coming from the core processor.
// Qick CONTROL
// - i_sync       synchronization signal. Lets the XCOM synchronize with an
//                external signal. Actuates in coordination with the
//                XCOM_QRST_SYNC command.
// - i xcom_data  serial data received. This is the general data input of the
//                XCOM block
// - i_xcom_clk   serial clock for reception. This is the general clock input of
//                the XCOM block
//
//Outputs:
// QICK PERIPHERAL INTERFACE (i_core_clk)
// - o_core_ready signal indicating the ip is ready to receive new data to
//                transmit
// - o_core_data1 data1 to core
// - o_core_data2 data2 to core
// - o_core_valid signal indicating the ip has valid data to write into the
//                local board
// - o_core_flag  signal indicating to write flag into the core
// Qick CONTROL
// - o_proc_start       start signal to the tproc
// - o_proc_stop        stop signal to the tproc
// - o_time_rst         reset the time reference in processor
// - o_time_update      update the time in processor
// - o_time_update_data data to update the time in processor
// - o_core_start       start signal to the core in tproc
// - o_core_stop        stop signal to the core in tproc
// XCOM
// - o_xcom_id  board ID. This is a signal to see the board ID
//              into external LEDs.
// IO XCOM (i_time_clk)
// - o xcom_data serial data transmitted. This is the general data output of the
//               XCOM block
// - o_xcom_clk  serial clock for transmission. This is the general clock output of
//               the XCOM block  /
// AXI-Lite DATA Slave I/F (i_ps_clk)
// - s_axi      signals of the AXI4-Lite interface to PS
//
// Change history: 10/20/24 - v2 Started by @mdifederico
//                 05/13/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//                 09/08/25 - @lharnaldi add differential I/O ports
//
///////////////////////////////////////////////////////////////////////////////
`include "qick_pkg.sv"
module xcom import qick_pkg::*;
  # (
    parameter int NCH          = 2 ,
    parameter int SYNC         = 1 ,
    parameter int LOOPBACK     = 0 ,  // Enable internal loopback channel
    parameter int DEBUG        = 1
  )(
    input  logic             i_ps_clk           ,
    input  logic             i_ps_rstn          ,
    input  logic             i_core_clk         ,
    input  logic             i_core_rstn        ,
    input  logic             i_time_clk         ,
    input  logic             i_time_rstn        ,
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
    output logic             o_proc_start       , // time_clk domain
    output logic             o_proc_stop        , // time_clk domain
    output logic             o_time_rst         , // time_clk domain
    output logic             o_time_update      , // time_clk domain
    output logic  [32-1:0]   o_time_update_data , // time_clk domain
    output logic             o_core_start       , // core_clk domain
    output logic             o_core_stop        , // core_clk domain
    // XCOM
    output logic   [4-1:0]   o_xcom_id          ,
    // IO XCOM (i_time_clk)
    input  logic [NCH-1:0]   i_xcom_clk_p       ,
    input  logic [NCH-1:0]   i_xcom_clk_n       ,
    input  logic [NCH-1:0]   i_xcom_data_p      ,
    input  logic [NCH-1:0]   i_xcom_data_n      ,
    output logic             o_xcom_clk_p       ,
    output logic             o_xcom_clk_n       ,
    output logic             o_xcom_data_p      ,
    output logic             o_xcom_data_n      ,
    // AXI-Lite DATA Slave I/F (i_ps_clk)
    input  logic   [6-1:0]   s_axi_awaddr       ,
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
    input  logic  [ 6-1:0]   s_axi_araddr       ,
    input  logic  [ 3-1:0]   s_axi_arprot       ,
    input  logic             s_axi_arvalid      ,
    output logic             s_axi_arready      ,
    output logic  [32-1:0]   s_axi_rdata        ,
    output logic  [ 2-1:0]   s_axi_rresp        ,
    output logic             s_axi_rvalid       ,
    input  logic             s_axi_rready       ,
    // DEBUG
    output logic  [32-1:0]   o_dbg_probe1,
    output logic  [32-1:0]   o_dbg_probe2,
    output logic  [41-1:0]   o_dbg_probe3
  );

  // Local Parameters
  localparam int LOOPBACK_EN = LOOPBACK & DEBUG;  // Loopback only if DEBUG is enabled
  localparam int NCH_INT = NCH + LOOPBACK_EN;

  // Signal Declaration
  ///////////////////////////////////////////////////////////////////////////////
  logic [ 8-1:0] s_op ;
  logic [32-1:0] s_data;
  logic [ 4-1:0] s_cmd_cntr;

  logic [ 4-1:0] s_cfg_tick;
  logic          s_cfg_clk_pol;
  logic          s_cfg_clk_pha;
  logic          s_cfg_auto_pha;
  logic          s_cfg_loopback;

  logic [ 4-1:0] s_xcom_id;
  logic [ 4-1:0] s_xcom_id_ps;
  logic [32-1:0] s_xcom_ctrl ;
  logic [32-1:0] s_xcom_ctrl_sync ;
  logic [32-1:0] s_xcom_cfg ;
  logic [32-1:0] s_xcom_cfg_sync ;
  logic [32-1:0] s_axi_data1;
  logic [32-1:0] s_axi_data1_sync;
  logic [32-1:0] s_axi_data2 ;
  logic [32-1:0] s_axi_data2_sync;
  logic [32-1:0] s_axi_addr ;
  logic [32-1:0] s_xcom_tx_rx_ddr ;
  logic          s_core_en;
  logic [ 5-1:0] s_core_op;
  logic [2-1:0][32-1:0] s_core_data ;
  logic [2-1:0][32-1:0] s_ps_data   ;
  logic          s_req_loc;
  logic          s_ack_loc;
  logic          s_req_net;
  logic          s_ack_net;

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

  logic [NCH-1:0]     si_xcom_clk       ;
  logic [NCH-1:0]     si_xcom_data      ;
  logic [NCH_INT-1:0] si_xcom_clk_int   ;
  logic [NCH_INT-1:0] si_xcom_data_int  ;
  logic [1:0]         so_xcom_clk       ;
  logic [1:0]         so_xcom_data      ;

  ///////////////////////////////////////////////////////////////////////////////
  // AXI Registers
  ///////////////////////////////////////////////////////////////////////////////
  // Reg map (qick_pkg::REG_XCOM_*, byte addr / 4 = index into o_slv_regs/i_slv_regs):
  //   0 CTRL  1 CFG  2 AXI_DATA1  3 AXI_DATA2  4 ADDR  5 TX_RX_DDR      -- RW (PS)
  //   6 ID  7 FLAG  8 DATA1  9 DATA2  10 MEM  11 (reserved)
  //   12 RX_DATA  13 TX_DATA  14 STATUS  15 DEBUG                      -- RO (hw)
  localparam int XCOM_NUM_REGS = 16;
  localparam logic [XCOM_NUM_REGS-1:0] XCOM_REG_RO = 16'hFFC0; // regs 6..15 read-only

  logic [32-1:0] o_slv_regs [XCOM_NUM_REGS];
  logic [32-1:0] i_slv_regs [XCOM_NUM_REGS];

  axil_slv #(
    .AXI_AW          ( 6  ),
    .AXI_DW          ( 32 ),
    .NUM_REGS        ( XCOM_NUM_REGS ),
    // CTRL_REG (register 0) is a one-shot command word (strobe + opcode), the same role
    // qick_time_tagger's own CTRL register plays; auto-clear it so xcom_cmd_hold gets a real
    // one-clock pulse instead of a level that never drops (see the comment at s_xcom_ctrl below).
    .AUTO_CLEAR_BIT0 ( 1'b1 )
  ) u_axil_slv(
    .s_axi_aclk      ( i_ps_clk           ),
    .s_axi_aresetn   ( i_ps_rstn          ),
    .s_axi_awaddr    ( s_axi_awaddr [6-1:0] ),
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
  // CTRL_REG[0]/[5:1] (command strobe/opcode) are the exception: before AUTO_CLEAR_BIT0 was enabled above,
  // CTRL_REG never cleared itself, and xcom_cdc synchronises only bit 0 into i_time_clk while passing the
  // opcode bits through unsynchronised, so a bare register readback here made xcom_cmd's level-sensitive FSM
  // re-issue the same command forever (confirmed in simulation: 13 repeats in 300 i_ps_clk cycles). Now that
  // CTRL_REG self-clears, xcom_cmd_hold turns that one-clock pulse into a HOLD-clock one with a stable opcode
  // -- the same treatment qick_time_tagger's own CTRL_REG needed for the same reason; see its header.
  wire        s_xcom_ctrl_held_en;
  wire [4:0]  s_xcom_ctrl_held_op;
  xcom_cmd_hold # (
     .HOLD ( 6 )
  ) u_xcom_cmd_hold (
     .clk_i     ( i_ps_clk               ) ,
     .rst_ni    ( i_ps_rstn              ) ,
     .strobe_i  ( o_slv_regs[0][0]       ) ,
     .op_i      ( o_slv_regs[0][5:1]     ) ,
     .en_o      ( s_xcom_ctrl_held_en    ) ,
     .op_o      ( s_xcom_ctrl_held_op    ) );
  assign s_xcom_ctrl      = {o_slv_regs[0][31:6], s_xcom_ctrl_held_op, s_xcom_ctrl_held_en};
  assign s_xcom_cfg       = o_slv_regs[1];
  assign s_axi_data1      = o_slv_regs[2];
  assign s_axi_data2      = o_slv_regs[3];
  assign s_axi_addr       = o_slv_regs[4];
  assign s_xcom_tx_rx_ddr = o_slv_regs[5];

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
  assign i_slv_regs[11] = '0; // reserved
  assign i_slv_regs[12] = s_dbg_rx_data_ps;
  assign i_slv_regs[13] = s_dbg_tx_data_ps;
  assign i_slv_regs[14] = xreg_status;
  assign i_slv_regs[15] = xreg_debug;

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

  xcom_txrx #(
    .NCH      ( NCH_INT ),
    .LOOPBACK ( LOOPBACK_EN ),
    .SYNC     ( SYNC )
  ) u_xcom_txrx(
    .i_clk             ( i_time_clk         ),
    .i_rstn            ( i_time_rstn        ),
    .i_ps_clk          ( i_ps_clk           ),
    .i_ps_rstn         ( i_ps_rstn          ),
    .i_sync            ( s_sync             ),
    .i_req_loc         ( s_req_loc          ),
    .i_req_net         ( s_req_net          ),
    .i_header          ( s_op               ),
    .i_data            ( s_data             ),
    .i_cmd_cntr        ( s_cmd_cntr         ),
    .o_ack_loc         ( s_ack_loc          ),
    .o_ack_net         ( s_ack_net          ),
    .o_qp_ready        ( s_core_ready       ),
    .o_qp_valid        ( s_core_valid       ),
    .o_qp_flag         ( s_core_flag        ),
    .o_qp_data1        ( s_core_data1       ),
    .o_qp_data2        ( s_core_data2       ),
    .o_proc_start      ( o_proc_start       ),
    .o_proc_stop       ( o_proc_stop        ),
    .o_time_rst        ( o_time_rst         ),
    .o_time_update     ( o_time_update      ),
    .o_time_update_data( o_time_update_data ),
    .o_core_start      ( s_core_start       ),
    .o_core_stop       ( s_core_stop        ),
    .i_cfg_tick        ( s_cfg_tick         ),
    .i_cfg_clk_pol     ( s_cfg_clk_pol      ),
    .i_cfg_clk_pha     ( s_cfg_clk_pha      ),
    .i_cfg_auto_pha    ( s_cfg_auto_pha     ),
    .i_cfg_loopback    ( s_cfg_loopback     ),
    .i_cfg_sync_dis    ( s_cfg_sync_dis     ),
    .i_xcom_tx_rx_ddr  ( s_xcom_tx_rx_ddr   ),
    .o_xcom_id         ( s_xcom_id          ),
    .o_xcom_mem        ( xcom_mem_data      ),
    .i_xcom_data       ( si_xcom_data_int   ),
    .i_xcom_clk        ( si_xcom_clk_int    ),
    .o_xcom_data       ( so_xcom_data       ),
    .o_xcom_clk        ( so_xcom_clk        ),
    .o_dbg_rx_data     ( s_dbg_rx_data      ),
    .o_dbg_tx_data     ( s_dbg_tx_data      ),
    .o_dbg_status      ( s_dbg_status       ),
    .o_dbg_data        ( s_dbg_debug        )
  );

  assign s_cfg_tick     = s_xcom_cfg_sync[4-1:0];
  assign s_cfg_clk_pol  = (LOOPBACK_EN == 0) ? s_xcom_cfg_sync[8] : (s_xcom_cfg_sync[8] & ~s_cfg_loopback);
  assign s_cfg_clk_pha  = s_xcom_cfg_sync[9];
  assign s_cfg_auto_pha = s_xcom_cfg_sync[10];
  assign s_cfg_sync_dis = s_xcom_cfg_sync[28];
  assign s_cfg_loopback = s_xcom_cfg_sync[31];

  diff_in_nb #(
    .NB( NCH )
  ) dt_i_diff_nb(
    .i_diff_p( i_xcom_data_p ),
    .i_diff_n( i_xcom_data_n ),
    .o_se    ( si_xcom_data  )
  );

  diff_in_nb #(
    .NB( NCH )
  ) ck_i_diff_nb(
    .i_diff_p( i_xcom_clk_p ),
    .i_diff_n( i_xcom_clk_n ),
    .o_se    ( si_xcom_clk  )
  );

  diff_out_nb #(
    .NB( 1 )
  ) dt_o_diff_nb(
    .o_diff_p( o_xcom_data_p  ),
    .o_diff_n( o_xcom_data_n  ),
    .i_se    ( so_xcom_data[0])
  );

  diff_out_nb #(
    .NB( 1 )
  ) ck_o_diff_nb(
    .o_diff_p( o_xcom_clk_p   ),
    .o_diff_n( o_xcom_clk_n   ),
    .i_se    ( so_xcom_clk[0] )
  );

  generate
    if (LOOPBACK_EN == 0) begin : gen_no_loopback
      assign si_xcom_data_int = si_xcom_data;
      assign si_xcom_clk_int  = si_xcom_clk;
    end
    else if (LOOPBACK_EN == 1) begin : gen_loopback
      assign si_xcom_data_int[NCH-1:0]    = si_xcom_data;
      assign si_xcom_clk_int[NCH-1:0]     = si_xcom_clk;
      assign si_xcom_data_int[NCH_INT-1]  = so_xcom_data[1];
      assign si_xcom_clk_int[NCH_INT-1]   = so_xcom_clk[1];
    end
  endgenerate

  assign o_xcom_id   = s_xcom_id;
  assign xreg_status = s_dbg_status_ps;

  ///////////////////////////////////////////////////////////////////////////////
  // DEBUG
  ///////////////////////////////////////////////////////////////////////////////
  generate
    if (DEBUG == 0) begin : gen_debug_no
      assign xreg_debug  = '{default:'0} ;
    end else if   (DEBUG == 1) begin : gen_debug_yes
      assign xreg_debug  = s_dbg_debug_ps;
    end
  endgenerate

  // DEBUG PROBES
  //////////////////////////////////////////////////////////////////////////////
  // assign o_dbg_probe1[7:0]   = {s_cfg_loopback, s_cfg_auto_pha, s_cfg_clk_pha, s_cfg_clk_pol, si_xcom_data_int[NCH_INT-1], si_xcom_clk_int[NCH_INT-1],si_xcom_data_int[0], si_xcom_clk_int[0]};
  assign o_dbg_probe1[7:0]   = {s_cfg_loopback, s_cfg_auto_pha, s_cfg_clk_pha, s_cfg_clk_pol, 4'b0000};
  assign o_dbg_probe1[15:8]  = {u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.i_id,
                                 u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.o_cmd,
                                 u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.i_ack,
                                 u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.o_req};
  assign o_dbg_probe1[23:16] = {u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.o_data[7:0]};
  assign o_dbg_probe1[31:24] = {u_xcom_txrx.u_rx_cmd.gen_rx[0].u_xcom_link_rx.o_dbg_state};

  assign o_dbg_probe2[7:0]   = {6'd0, u_xcom_txrx.u_tx_cmd.u_xcom_link_tx.o_ready,
                                 u_xcom_txrx.u_tx_cmd.u_xcom_link_tx.i_valid};
  assign o_dbg_probe2[15:8]  = {u_xcom_txrx.u_tx_cmd.u_xcom_link_tx.i_header};
  assign o_dbg_probe2[23:16] = {u_xcom_txrx.u_tx_cmd.u_xcom_link_tx.i_data[7:0]};
  assign o_dbg_probe2[31:24] = {u_xcom_txrx.u_tx_cmd.o_dbg_state};

  assign o_dbg_probe3[40:0]  = {u_xcom_txrx.u_rx_cmd.o_valid, u_xcom_txrx.u_rx_cmd.o_op,
                                 u_xcom_txrx.u_rx_cmd.o_chid, u_xcom_txrx.u_rx_cmd.o_data};

endmodule
