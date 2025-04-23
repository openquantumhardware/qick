//! @title Aurora interface top
//! @author Leoni Sergio Daniel sdleoni@invap.com.ar
//! @version 0.1.0
//! @date 24/05/2024

//! @details This module is a general top of peripheral XCVR Component.
module aurora_if 
#(
    parameter NB_LANE            = 2,
    parameter NB_AXIS_DATA       = 64,
    parameter PMA_RST_RELEASE    = 400,
    parameter PB_RST_RELEASE     = 1000,

    parameter FIFO_DEPTH         = 1024
)
(
    input logic clk_i,
    input logic srst_i,

    input logic gt_refclk1_p,
    input logic gt_refclk1_n,
    input logic low_clk_in,
    ////////////////////////////////////////////////////////////////

    output logic                            axis_m_tvalid,
    input  logic                            axis_m_tready,
    output logic [NB_AXIS_DATA   - 1 : 0 ]  axis_m_tdata,
    output logic [NB_AXIS_DATA/8 - 1 : 0 ]  axis_m_tkeep,
    output logic                            axis_m_tlast,

    input  logic                            axis_s_tvalid,
    output logic                            axis_s_tready,
    input  logic [NB_AXIS_DATA   - 1 : 0 ]  axis_s_tdata,
    input  logic [NB_AXIS_DATA/8 - 1 : 0 ]  axis_s_tkeep,
    input  logic                            axis_s_tlast,

    output logic                    hard_err_o,
    output logic                    soft_err_o,
    output logic                    channel_up_o,
    output logic [0 : NB_LANE - 1 ] lane_up_o,
    output logic                    pll_not_locked_out_o,
    output logic [NB_LANE - 1 : 0 ] gt_powergood_o,
    
    ////////////////////////////////////////////////////////////////
    output logic                    prog_empty_fifo_tx_o,
    output logic                    prog_full_fifo_tx_o,
    output logic                    prog_empty_fifo_rx_o,
    output logic                    prog_full_fifo_rx_o,
    ////////////////////////////////////////////////////////////////
    input  logic [0 : NB_LANE - 1 ] rxp_i,
    input  logic [0 : NB_LANE - 1 ] rxn_i,

    output logic [0 : NB_LANE - 1 ] txp_o,
    output logic [0 : NB_LANE - 1 ] txn_o,

    // interface axil register
    axi4lite_intf.slave             s_axil

);

localparam integer unsigned NB_COUNTER_FIFO = $clog2(FIFO_DEPTH);

integer unsigned    rst_control_counter = 0;

logic               rst_w;
logic               r_rst_pb;
logic               r_pma_rst;

//port axis cdc to aurora
logic [NB_AXIS_DATA   - 1 : 0 ] m_axis_aurora_tdata_w;
logic [NB_AXIS_DATA/8 - 1 : 0 ] m_axis_aurora_tkeep_w;
logic                           m_axis_aurora_tvalid_w;
logic                           m_axis_aurora_tready_w;
logic                           m_axis_aurora_tlast_w;

//port axis aurora to cdc
logic [NB_AXIS_DATA   - 1 : 0 ] s_axis_aurora_tdata_w;
logic [NB_AXIS_DATA/8 - 1 : 0 ] s_axis_aurora_tkeep_w;
logic                           s_axis_aurora_tvalid_w;
logic                           s_axis_aurora_tlast_w;

logic user_clk;

logic                   hard_err_w;
logic                   soft_err_w;
logic                   channel_up_w;
logic [0 : NB_LANE - 1] lane_up_w;
logic                   pll_not_locked_out_w;
logic [NB_LANE - 1 : 0] gt_powergood_w;
logic                   sys_reset_out;

logic                    hard_err_cdc_w;
logic                    soft_err_cdc_w;
logic                    channel_up_cdc_w;
logic [0 : NB_LANE - 1 ] lane_up_cdc_w;
logic                    pll_not_locked_out_cdc_w;
logic [NB_LANE - 1 : 0 ] gt_powergood_cdc_w;

logic                    prog_empty_fifo_tx_w;
logic                    prog_full_fifo_tx_w;
logic                    prog_empty_fifo_rx_w;
logic                    prog_full_fifo_rx_w;
//////////////////////////////aurora to module/////////////////////////////
xpm_fifo_axis #(
   .CASCADE_HEIGHT      ( 0                   ) ,
   .CDC_SYNC_STAGES     ( 2                   ) ,
   .CLOCKING_MODE       ( "independent_clock" ) ,
   .ECC_MODE            ( "no_ecc"            ) ,
   .FIFO_DEPTH          ( FIFO_DEPTH          ) ,
   .FIFO_MEMORY_TYPE    ( "auto"              ) ,
   .PACKET_FIFO         ( "false"             ) ,
   .PROG_EMPTY_THRESH   ( 10                  ) ,
   .PROG_FULL_THRESH    ( FIFO_DEPTH - 5      ) ,
   .RD_DATA_COUNT_WIDTH ( NB_COUNTER_FIFO + 1 ) ,
   .RELATED_CLOCKS      ( 0                   ) ,
   .SIM_ASSERT_CHK      ( 0                   ) ,
   .TDATA_WIDTH         ( NB_AXIS_DATA        ) ,
   .TDEST_WIDTH         ( 1                   ) ,
   .TID_WIDTH           ( 1                   ) ,
   .TUSER_WIDTH         ( 1                   ) ,
    // |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 0                           |
    // |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 0                            |
    // |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
    // |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 0                          |
    // |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 0                           |
    // |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0  
   .USE_ADV_FEATURES    ( "1E0E"              ) ,
   .WR_DATA_COUNT_WIDTH ( NB_COUNTER_FIFO + 1 )
)
xpm_fifo_aurora_to_module_axis_inst (
   .almost_empty_axis  (                        ) , // Not used
   .almost_full_axis   (                        ) , // Not used
   .dbiterr_axis       (                        ) , // Not used
   .m_axis_tdata       ( axis_m_tdata           ) ,
   .m_axis_tdest       (                        ) ,
   .m_axis_tid         (                        ) ,
   .m_axis_tkeep       ( axis_m_tkeep           ) ,
   .m_axis_tlast       ( axis_m_tlast           ) ,
   .m_axis_tstrb       (                        ) ,
   .m_axis_tuser       (                        ) ,
   .m_axis_tvalid      ( axis_m_tvalid          ) ,
   .m_axis_tready      ( axis_m_tready          ) ,
   .m_aclk             ( clk_i                  ) ,
   .prog_empty_axis    ( prog_empty_fifo_rx_w   ) ,
   .prog_full_axis     ( prog_full_fifo_rx_w    ) ,
   .rd_data_count_axis (                        ) , // Not used
   .sbiterr_axis       (                        ) , // Not used
   .wr_data_count_axis (                        ) , // Not used
   .injectdbiterr_axis ( 1'b0                   ) ,
   .injectsbiterr_axis ( 1'b0                   ) ,
   .s_aclk             ( user_clk               ) ,
   .s_aresetn          ( ~sys_reset_out         ) ,
   .s_axis_tdata       ( s_axis_aurora_tdata_w  ) ,
   .s_axis_tdest       (                        ) ,
   .s_axis_tid         (                        ) ,
   .s_axis_tkeep       ( s_axis_aurora_tkeep_w  ) ,
   .s_axis_tlast       ( s_axis_aurora_tlast_w  ) ,
   .s_axis_tstrb       (                        ) ,
   .s_axis_tuser       (                        ) ,
   .s_axis_tvalid      ( s_axis_aurora_tvalid_w ) ,
   .s_axis_tready      (                        )
);  
////////////////////////////////module to aurora/////////////////////////////
xpm_fifo_axis #(
    .CASCADE_HEIGHT      ( 0                   ) ,
    .CDC_SYNC_STAGES     ( 2                   ) ,
    .CLOCKING_MODE       ( "independent_clock" ) ,
    .ECC_MODE            ( "no_ecc"            ) ,
    .FIFO_DEPTH          ( FIFO_DEPTH          ) ,
    .FIFO_MEMORY_TYPE    ( "auto"              ) ,
    .PACKET_FIFO         ( "false"             ) ,
    .PROG_EMPTY_THRESH   ( 10                  ) ,
    .PROG_FULL_THRESH    ( FIFO_DEPTH - 5      ) ,
    .RD_DATA_COUNT_WIDTH ( NB_COUNTER_FIFO + 1 ) ,
    .RELATED_CLOCKS      ( 0                   ) ,
    .SIM_ASSERT_CHK      ( 0                   ) ,
    .TDATA_WIDTH         ( NB_AXIS_DATA        ) ,
    .TDEST_WIDTH         ( 1                   ) ,
    .TID_WIDTH           ( 1                   ) ,
    .TUSER_WIDTH         ( 1                   ) ,
     // |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 0                           |
     // |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 0                            |
     // |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
     // |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 0                          |
     // |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 0                           |
     // |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0  
    .USE_ADV_FEATURES    ( "1E0E"              ) ,
    .WR_DATA_COUNT_WIDTH ( NB_COUNTER_FIFO + 1 )
)
xpm_fifo_module_to_aurora_axis_inst (
   .almost_empty_axis  (                        ) , // Not used
   .almost_full_axis   (                        ) , // Not used
   .dbiterr_axis       (                        ) , // Not used
   .m_axis_tdata       ( m_axis_aurora_tdata_w  ) ,
   .m_axis_tdest       (                        ) ,
   .m_axis_tid         (                        ) ,
   .m_axis_tkeep       ( m_axis_aurora_tkeep_w  ) ,
   .m_axis_tlast       ( m_axis_aurora_tlast_w  ) ,
   .m_axis_tstrb       (                        ) ,
   .m_axis_tuser       (                        ) ,
   .m_axis_tvalid      ( m_axis_aurora_tvalid_w ) ,
   .m_axis_tready      ( m_axis_aurora_tready_w ) ,
   .m_aclk             ( user_clk               ) ,
   .prog_empty_axis    ( prog_empty_fifo_tx_w   ) ,
   .prog_full_axis     ( prog_full_fifo_tx_w    ) ,
   .rd_data_count_axis (                        ) , // Not used
   .sbiterr_axis       (                        ) , // Not used
   .wr_data_count_axis (                        ) , // Not used
   .injectdbiterr_axis ( 1'b0                   ) ,
   .injectsbiterr_axis ( 1'b0                   ) ,
   .s_aclk             ( clk_i                  ) ,
   .s_aresetn          ( ~(srst_i | rst_w)      ) ,
   .s_axis_tdata       ( axis_s_tdata           ) ,
   .s_axis_tdest       (                        ) ,
   .s_axis_tid         (                        ) ,
   .s_axis_tkeep       ( axis_s_tkeep           ) ,
   .s_axis_tlast       ( axis_s_tlast           ) ,
   .s_axis_tstrb       (                        ) ,
   .s_axis_tuser       (                        ) ,
   .s_axis_tvalid      ( axis_s_tvalid          ) ,
   .s_axis_tready      ( axis_s_tready          )
);
///////////////////////////////////////////////////////////////////////////

aurora_64b66b
u_aurora_64b66b
(
    // TX AXI4-S Interface
    .s_axi_tx_tdata                 (m_axis_aurora_tdata_w  ),
    .s_axi_tx_tlast                 (m_axis_aurora_tlast_w  ),
    .s_axi_tx_tkeep                 (m_axis_aurora_tkeep_w  ),
    .s_axi_tx_tvalid                (m_axis_aurora_tvalid_w ),
    .s_axi_tx_tready                (m_axis_aurora_tready_w ),

    // RX AXI4-S Interface
    .m_axi_rx_tdata                 (s_axis_aurora_tdata_w  ),
    .m_axi_rx_tlast                 (s_axis_aurora_tlast_w  ),
    .m_axi_rx_tkeep                 (s_axis_aurora_tkeep_w ),
    .m_axi_rx_tvalid                (s_axis_aurora_tvalid_w ),

    // GTX Serial I/O
    .rxp                            (rxp_i                  ),
    .rxn                            (rxn_i                  ),
    .txp                            (txp_o                  ),
    .txn                            (txn_o                  ),

    //GTX Reference Clock Interface
    .gt_refclk1_p                   (gt_refclk1_p           ),
    .gt_refclk1_n                   (gt_refclk1_n           ),
    .gt_refclk1_out                 (                       ),

    // Error Detection Interface
    .hard_err                       (hard_err_w          ),
    .soft_err                       (soft_err_w          ),
    // Status
    .channel_up                     (channel_up_w        ),
    .lane_up                        (lane_up_w           ),

    // System Interface
    .user_clk_out                   (user_clk               ),
    .mmcm_not_locked_out            (pll_not_locked_out_w),

    .sync_clk_out                   (                       ),

    .reset_pb                       (r_rst_pb               ),
    .pma_init                       (r_pma_rst              ),

    .gt_rxcdrovrden_in              (1'b0                   ),
    .power_down                     (1'b0                   ),
    .loopback                       (3'b0                   ),

    .gt_pll_lock                    (                       ),

    .gt0_drpaddr                    ('0                     ),
    .gt0_drpdi                      ('0                     ),
    .gt0_drpdo                      (                       ),
    .gt0_drprdy                     (                       ),
    .gt0_drpwe                      ('0                     ),
    .gt0_drpen                      ('0                     ),

    .gt_qpllclk_quad1_out           (),
    .gt_qpllrefclk_quad1_out        (),
    .gt_qplllock_quad1_out          (),
    .gt_qpllrefclklost_quad1_out    (),

    .init_clk                       (low_clk_in             ),
    .link_reset_out                 (link_reset_out_w    ),
    .gt_powergood                   (gt_powergood_w         ),

    .sys_reset_out                  (sys_reset_out          ),
    .gt_reset_out                   (gt_reset_out_w      ),

    .tx_out_clk                     (                       )
);

always_ff @(posedge clk_i)
begin
    if ((srst_i | rst_w) == 1'b1) begin
        rst_control_counter = 0;
        r_rst_pb    = 1'b1;
        r_pma_rst   = 1'b1;
    end else begin
        if(rst_control_counter < PMA_RST_RELEASE) begin
            rst_control_counter = rst_control_counter + 1;
            r_rst_pb    = 1'b1;
            r_pma_rst   = 1'b1;
        end else if(rst_control_counter < PB_RST_RELEASE) begin
            rst_control_counter = rst_control_counter + 1;
            r_rst_pb    = 1'b1;
            r_pma_rst   = 1'b0;
        end else begin
            rst_control_counter = rst_control_counter; 
            r_rst_pb    = 1'b0;
            r_pma_rst   = 1'b0;
        end
    end
end

xpm_cdc_single#(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1)
)xpm_cdc_hard_err(
    .dest_clk       (clk_i),
    .dest_out       (hard_err_cdc_w),
    .src_clk        (user_clk),
    .src_in         (hard_err_w)
);

xpm_cdc_single#(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1)
)xpm_cdc_soft_err(
    .dest_clk       (clk_i),
    .dest_out       (soft_err_cdc_w),
    .src_clk        (user_clk),
    .src_in         (soft_err_w)
);

xpm_cdc_single#(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1)
)xpm_cdc_channel_up(
    .dest_clk       (clk_i),
    .dest_out       (channel_up_cdc_w),
    .src_clk        (user_clk),
    .src_in         (channel_up_w)
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1),
    .WIDTH          (NB_LANE)
)xpm_cdc_lane_up(
    .dest_clk       (clk_i),
    .dest_out       (lane_up_cdc_w),
    .src_clk        (user_clk),
    .src_in         (lane_up_w)
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1),
    .WIDTH          (NB_LANE)
)xpm_cdc_gt_powergood(
    .dest_clk       (clk_i),
    .dest_out       (gt_powergood_cdc_w),
    .src_clk        (user_clk),
    .src_in         (gt_powergood_w)
);

xpm_cdc_single#(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (1)
)xpm_cdc_pll_not_locked_out(
    .dest_clk       (clk_i),
    .dest_out       (pll_not_locked_out_cdc_w),
    .src_clk        (user_clk),
    .src_in         (pll_not_locked_out_w)
);

import aurora_regmap_pkg::*;
aurora_regmap_pkg::aurora_regmap__in_t  csr_in;
aurora_regmap_pkg::aurora_regmap__out_t csr_out;
aurora_regmap u_aurora_regmap
(
    .clk        ( clk_i ),
    .rst        ( srst_i ),
    .s_axil     ( s_axil ),
    .hwif_in    ( csr_in ),
    .hwif_out   ( csr_out )
);

assign csr_in.aurora_regs.error_reg.hard_err.next               = hard_err_cdc_w;
assign csr_in.aurora_regs.error_reg.soft_err.next               = soft_err_cdc_w;

assign csr_in.aurora_regs.status_reg.lane_up.next                = lane_up_cdc_w;
assign csr_in.aurora_regs.status_reg.channel_up.next             = channel_up_cdc_w;
assign csr_in.aurora_regs.status_reg.mmcm_not_locked_out.next    = pll_not_locked_out_cdc_w;
assign csr_in.aurora_regs.status_reg.gt_powergood.next           = gt_powergood_cdc_w;

assign csr_in.fifo_rx.status_reg.empty_status.next              = prog_empty_fifo_rx_w;
assign csr_in.fifo_rx.status_reg.full_status.next               = prog_full_fifo_rx_w;

assign csr_in.fifo_tx.status_reg.empty_status.next              = prog_empty_fifo_tx_w;
assign csr_in.fifo_tx.status_reg.full_status.next               = prog_full_fifo_tx_w;

assign rst_w = csr_out.rst_reg.pulse_rst.value | csr_out.rst_reg.toggle_rst.value;

assign hard_err_o           = hard_err_cdc_w;
assign soft_err_o           = soft_err_cdc_w;
assign channel_up_o         = channel_up_cdc_w;
assign lane_up_o            = lane_up_cdc_w;
assign pll_not_locked_out_o = pll_not_locked_out_cdc_w;
assign gt_powergood_o       = gt_powergood_cdc_w;

assign prog_empty_fifo_tx_o = prog_empty_fifo_tx_w;
assign prog_full_fifo_tx_o  = prog_full_fifo_tx_w;
assign prog_empty_fifo_rx_o = prog_empty_fifo_rx_w;
assign prog_full_fifo_rx_o  = prog_full_fifo_rx_w;

endmodule