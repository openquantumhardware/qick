module udp10g import udp10g_pkg::*;
(
    /*
     * Clock: 156.25MHz
     * Synchronous reset
     */
    input logic i_clk,
    input logic i_rst,

    /*
     * Ethernet: SFP+
     */
    input  logic        i_sfp0_tx_clk,
    input  logic        i_sfp0_tx_rst,
    output logic [63:0] o_sfp0_txd,
    output logic [7:0]  o_sfp0_txc,
    input  logic        i_sfp0_rx_clk,
    input  logic        i_sfp0_rx_rst,
    input  logic [63:0] i_sfp0_rxd,
    input  logic [7:0]  i_sfp0_rxc,

    /*
     * UDP RX Header
     */
    output logic        m_udp_rx_hdr_valid,
    input  logic        m_udp_rx_hdr_ready,
    output udp_hdr_t    m_udp_rx_hdr,

    /*
     * UDP RX Payload
     */
    axi4_stream_if.master m_axis_udp_rx_payload,

    /*
     * UDP TX Payload
     */
    axi4_stream_if.slave s_axis_udp_tx_payload,

    /*
     * CSR
     */

    axi4lite_intf.slave s_axil_csr
);

    import udp10g_regmap_pkg::*;

    udp10g_regmap__in_t csr_in;
    udp10g_regmap__out_t csr_out;

    // AXI between MAC and Ethernet modules
    logic [63:0] tx_axis_tdata;
    logic [7:0] tx_axis_tkeep;
    logic tx_axis_tvalid;
    logic tx_axis_tready;
    logic tx_axis_tlast;
    logic tx_axis_tuser;

    logic [63:0] rx_axis_tdata;
    logic [7:0] rx_axis_tkeep;
    logic rx_axis_tvalid;
    logic rx_axis_tready;
    logic rx_axis_tlast;
    logic rx_axis_tuser;

    // Ethernet frame between Ethernet modules and UDP stack
    logic rx_eth_hdr_ready;
    logic rx_eth_hdr_valid;
    logic [47:0] rx_eth_dest_mac;
    logic [47:0] rx_eth_src_mac;
    logic [15:0] rx_eth_type;
    logic [63:0] rx_eth_payload_axis_tdata;
    logic [7:0] rx_eth_payload_axis_tkeep;
    logic rx_eth_payload_axis_tvalid;
    logic rx_eth_payload_axis_tready;
    logic rx_eth_payload_axis_tlast;
    logic rx_eth_payload_axis_tuser;

    logic tx_eth_hdr_ready;
    logic tx_eth_hdr_valid;
    logic [47:0] tx_eth_dest_mac;
    logic [47:0] tx_eth_src_mac;
    logic [15:0] tx_eth_type;
    logic [63:0] tx_eth_payload_axis_tdata;
    logic [7:0] tx_eth_payload_axis_tkeep;
    logic tx_eth_payload_axis_tvalid;
    logic tx_eth_payload_axis_tready;
    logic tx_eth_payload_axis_tlast;
    logic tx_eth_payload_axis_tuser;

    logic [63:0] s_udp_payload_axis_tdata ;
    logic [7:0]  s_udp_payload_axis_tkeep ;
    logic        s_udp_payload_axis_tvalid;
    logic        s_udp_payload_axis_tready;
    logic        s_udp_payload_axis_tlast ;

    logic [$bits(csr_out.udp.udp_tx_hdr.options.length.value)-1:0] count_data;
    logic count_in_proc, count_en, count_done;

    always_comb begin
        if (csr_out.debug.ramp.value) begin
            s_udp_payload_axis_tdata     = 64'(count_data);
            s_udp_payload_axis_tkeep     = '1;
            s_udp_payload_axis_tvalid    = 1'b1;
            count_en                     = s_udp_payload_axis_tready;
            s_axis_udp_tx_payload.tready = 1'b0;
            s_udp_payload_axis_tlast     = count_done;
        end
        else begin
            s_udp_payload_axis_tdata     = s_axis_udp_tx_payload.tdata ;
            s_udp_payload_axis_tkeep     = s_axis_udp_tx_payload.tkeep ;
            s_udp_payload_axis_tvalid    = s_axis_udp_tx_payload.tvalid;
            count_en                     = 1'b0;
            s_axis_udp_tx_payload.tready = s_udp_payload_axis_tready;
            s_udp_payload_axis_tlast     = s_axis_udp_tx_payload.tlast ;
        end
    end

    udp10g_regmap u_csr(
        .clk      ( i_clk      ) ,
        .rst      ( i_rst      ) ,
        .s_axil   ( s_axil_csr ) ,
        .hwif_in  ( csr_in     ) ,
        .hwif_out ( csr_out    )
    );

    eth_mac_10g_fifo #(
        .ENABLE_PADDING(1),
        .ENABLE_DIC(1),
        .MIN_FRAME_LENGTH(64),
        .TX_FIFO_DEPTH(4096),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(4096),
        .RX_FRAME_FIFO(1)
    )
    eth_mac_10g_fifo_inst (
        .rx_clk(i_sfp0_rx_clk),
        .rx_rst(i_sfp0_rx_rst),
        .tx_clk(i_sfp0_tx_clk),
        .tx_rst(i_sfp0_tx_rst),
        .logic_clk(i_clk),
        .logic_rst(i_rst),

        .tx_axis_tdata(tx_axis_tdata),
        .tx_axis_tkeep(tx_axis_tkeep),
        .tx_axis_tvalid(tx_axis_tvalid),
        .tx_axis_tready(tx_axis_tready),
        .tx_axis_tlast(tx_axis_tlast),
        .tx_axis_tuser(tx_axis_tuser),

        .rx_axis_tdata(rx_axis_tdata),
        .rx_axis_tkeep(rx_axis_tkeep),
        .rx_axis_tvalid(rx_axis_tvalid),
        .rx_axis_tready(rx_axis_tready),
        .rx_axis_tlast(rx_axis_tlast),
        .rx_axis_tuser(rx_axis_tuser),

        .xgmii_rxd(i_sfp0_rxd),
        .xgmii_rxc(i_sfp0_rxc),
        .xgmii_txd(o_sfp0_txd),
        .xgmii_txc(o_sfp0_txc),

        .tx_fifo_overflow   ( csr_in.eth_mac_10g_fifo.status.tx_fifo_overflow.next   ) ,
        .tx_fifo_bad_frame  ( csr_in.eth_mac_10g_fifo.status.tx_fifo_bad_frame.next  ) ,
        .tx_fifo_good_frame ( csr_in.eth_mac_10g_fifo.status.tx_fifo_good_frame.next ) ,
        .rx_error_bad_frame ( csr_in.eth_mac_10g_fifo.status.rx_error_bad_frame.next ) ,
        .rx_error_bad_fcs   ( csr_in.eth_mac_10g_fifo.status.rx_error_bad_fcs.next   ) ,
        .rx_fifo_overflow   ( csr_in.eth_mac_10g_fifo.status.rx_fifo_overflow.next   ) ,
        .rx_fifo_bad_frame  ( csr_in.eth_mac_10g_fifo.status.rx_fifo_bad_frame.next  ) ,
        .rx_fifo_good_frame ( csr_in.eth_mac_10g_fifo.status.rx_fifo_good_frame.next ) ,

        .ifg_delay(8'd12)
    );

    eth_axis_rx #(
        .DATA_WIDTH(64)
    )
    eth_axis_rx_inst (
        .clk(i_clk),
        .rst(i_rst | csr_out.eth_axis.rx_rst.toggle.value | csr_out.eth_axis.rx_rst.pulse.value),
        // AXI input
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tkeep(rx_axis_tkeep),
        .s_axis_tvalid(rx_axis_tvalid),
        .s_axis_tready(rx_axis_tready),
        .s_axis_tlast(rx_axis_tlast),
        .s_axis_tuser(rx_axis_tuser),
        // Ethernet frame output
        .m_eth_hdr_valid(rx_eth_hdr_valid),
        .m_eth_hdr_ready(rx_eth_hdr_ready),
        .m_eth_dest_mac(rx_eth_dest_mac),
        .m_eth_src_mac(rx_eth_src_mac),
        .m_eth_type(rx_eth_type),
        .m_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
        .m_eth_payload_axis_tkeep(rx_eth_payload_axis_tkeep),
        .m_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
        .m_eth_payload_axis_tready(rx_eth_payload_axis_tready),
        .m_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
        .m_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
        // Status signals
        .busy(csr_in.eth_axis.status.rx_busy.next),
        .error_header_early_termination(csr_in.eth_axis.status.rx_error_header_early_termination.next)
    );

    eth_axis_tx #(
        .DATA_WIDTH(64)
    )
    eth_axis_tx_inst (
        .clk(i_clk),
        .rst(i_rst | csr_out.eth_axis.tx_rst.toggle.value | csr_out.eth_axis.tx_rst.pulse.value),
        // Ethernet frame input
        .s_eth_hdr_valid(tx_eth_hdr_valid),
        .s_eth_hdr_ready(tx_eth_hdr_ready),
        .s_eth_dest_mac(tx_eth_dest_mac),
        .s_eth_src_mac(tx_eth_src_mac),
        .s_eth_type(tx_eth_type),
        .s_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
        .s_eth_payload_axis_tkeep(tx_eth_payload_axis_tkeep),
        .s_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
        .s_eth_payload_axis_tready(tx_eth_payload_axis_tready),
        .s_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
        .s_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
        // AXI output
        .m_axis_tdata(tx_axis_tdata),
        .m_axis_tkeep(tx_axis_tkeep),
        .m_axis_tvalid(tx_axis_tvalid),
        .m_axis_tready(tx_axis_tready),
        .m_axis_tlast(tx_axis_tlast),
        .m_axis_tuser(tx_axis_tuser),
        // Status signals
        .busy(csr_in.eth_axis.status.tx_busy.next)
    );

    assign csr_in.eth_axis_count.count.incr = tx_axis_tvalid & tx_axis_tready;

    udp_complete_64
    udp_complete_inst (
        .clk(i_clk),
        .rst(i_rst | csr_out.udp.rst.toggle.value | csr_out.udp.rst.pulse.value),
        // Ethernet frame input
        .s_eth_hdr_valid(rx_eth_hdr_valid),
        .s_eth_hdr_ready(rx_eth_hdr_ready),
        .s_eth_dest_mac(rx_eth_dest_mac),
        .s_eth_src_mac(rx_eth_src_mac),
        .s_eth_type(rx_eth_type),
        .s_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
        .s_eth_payload_axis_tkeep(rx_eth_payload_axis_tkeep),
        .s_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
        .s_eth_payload_axis_tready(rx_eth_payload_axis_tready),
        .s_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
        .s_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
        // Ethernet frame output
        .m_eth_hdr_valid(tx_eth_hdr_valid),
        .m_eth_hdr_ready(tx_eth_hdr_ready),
        .m_eth_dest_mac(tx_eth_dest_mac),
        .m_eth_src_mac(tx_eth_src_mac),
        .m_eth_type(tx_eth_type),
        .m_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
        .m_eth_payload_axis_tkeep(tx_eth_payload_axis_tkeep),
        .m_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
        .m_eth_payload_axis_tready(tx_eth_payload_axis_tready),
        .m_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
        .m_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
        // IP frame input
        .s_ip_hdr_valid           ( '0 ) ,
        .s_ip_hdr_ready           (    ) , //not used
        .s_ip_dscp                ( '0 ) ,
        .s_ip_ecn                 ( '0 ) ,
        .s_ip_length              ( '0 ) ,
        .s_ip_ttl                 ( '0 ) ,
        .s_ip_protocol            ( '0 ) ,
        .s_ip_source_ip           ( '0 ) ,
        .s_ip_dest_ip             ( '0 ) ,
        .s_ip_payload_axis_tdata  ( '0 ) ,
        .s_ip_payload_axis_tkeep  ( '0 ) ,
        .s_ip_payload_axis_tvalid ( '0 ) ,
        .s_ip_payload_axis_tready (    ) , // not used
        .s_ip_payload_axis_tlast  ( '0 ) ,
        .s_ip_payload_axis_tuser  ( '0 ) ,
        // IP frame output
        .m_ip_hdr_valid           (      ),
        .m_ip_hdr_ready           ( 1'b1 ),
        .m_ip_eth_dest_mac        (      ) ,
        .m_ip_eth_src_mac         (      ) ,
        .m_ip_eth_type            (      ) ,
        .m_ip_version             (      ) ,
        .m_ip_ihl                 (      ) ,
        .m_ip_dscp                (      ) ,
        .m_ip_ecn                 (      ) ,
        .m_ip_length              (      ) ,
        .m_ip_identification      (      ) ,
        .m_ip_flags               (      ) ,
        .m_ip_fragment_offset     (      ) ,
        .m_ip_ttl                 (      ) ,
        .m_ip_protocol            (      ) ,
        .m_ip_header_checksum     (      ) ,
        .m_ip_source_ip           (      ) ,
        .m_ip_dest_ip             (      ) ,
        .m_ip_payload_axis_tdata  (      ) ,
        .m_ip_payload_axis_tkeep  (      ) ,
        .m_ip_payload_axis_tvalid (      ) ,
        .m_ip_payload_axis_tready ( 1'b1 ) ,
        .m_ip_payload_axis_tlast  (      ) ,
        .m_ip_payload_axis_tuser  (      ) ,
        // UDP frame input
        .s_udp_hdr_valid           ( csr_out.udp.udp_tx_hdr.transaction.valid.value   ) ,
        .s_udp_hdr_ready           ( csr_in.udp.udp_tx_hdr.transaction.ready.next     ) ,
        .s_udp_ip_dscp             ( csr_out.udp.udp_tx_hdr.ip_hdr.options.dscp.value ) ,
        .s_udp_ip_ecn              ( csr_out.udp.udp_tx_hdr.ip_hdr.options.ecn.value  ) ,
        .s_udp_ip_ttl              ( csr_out.udp.udp_tx_hdr.ip_hdr.options.ttl.value  ) ,
        .s_udp_ip_source_ip        ( csr_out.udp.udp_tx_hdr.ip_hdr.source.addr.value  ) ,
        .s_udp_ip_dest_ip          ( csr_out.udp.udp_tx_hdr.ip_hdr.dest.addr.value    ) ,
        .s_udp_source_port         ( csr_out.udp.udp_tx_hdr.port.source.value         ) ,
        .s_udp_dest_port           ( csr_out.udp.udp_tx_hdr.port.dest.value           ) ,
        .s_udp_length              ( csr_out.udp.udp_tx_hdr.options.length.value      ) ,
        .s_udp_checksum            ( csr_out.udp.udp_tx_hdr.options.checksum.value    ) ,
        .s_udp_payload_axis_tdata  ( s_udp_payload_axis_tdata  ) ,
        .s_udp_payload_axis_tkeep  ( s_udp_payload_axis_tkeep  ) ,
        .s_udp_payload_axis_tvalid ( s_udp_payload_axis_tvalid ) ,
        .s_udp_payload_axis_tready ( s_udp_payload_axis_tready ) ,
        .s_udp_payload_axis_tlast  ( s_udp_payload_axis_tlast  ) ,
        .s_udp_payload_axis_tuser  ( s_udp_payload_axis_tuser  ) ,
        // UDP frame output
        .m_udp_hdr_valid           ( m_udp_rx_hdr_valid            ) ,
        .m_udp_hdr_ready           ( m_udp_rx_hdr_ready            ) ,
        .m_udp_eth_dest_mac        (                               ) ,
        .m_udp_eth_src_mac         (                               ) ,
        .m_udp_eth_type            (                               ) ,
        .m_udp_ip_version          (                               ) ,
        .m_udp_ip_ihl              (                               ) ,
        .m_udp_ip_dscp             ( m_udp_rx_hdr.ip_hdr.dscp      ) ,
        .m_udp_ip_ecn              ( m_udp_rx_hdr.ip_hdr.ecn       ) ,
        .m_udp_ip_length           (                               ) ,
        .m_udp_ip_identification   (                               ) ,
        .m_udp_ip_flags            (                               ) ,
        .m_udp_ip_fragment_offset  (                               ) ,
        .m_udp_ip_ttl              ( m_udp_rx_hdr.ip_hdr.ttl       ) ,
        .m_udp_ip_protocol         (                               ) ,
        .m_udp_ip_header_checksum  (                               ) ,
        .m_udp_ip_source_ip        ( m_udp_rx_hdr.ip_hdr.source_ip ) ,
        .m_udp_ip_dest_ip          ( m_udp_rx_hdr.ip_hdr.dest_ip   ) ,
        .m_udp_source_port         ( m_udp_rx_hdr.source_port      ) ,
        .m_udp_dest_port           ( m_udp_rx_hdr.dest_port        ) ,
        .m_udp_length              ( m_udp_rx_hdr.length           ) ,
        .m_udp_checksum            ( m_udp_rx_hdr.checksum         ) ,
        .m_udp_payload_axis_tdata  ( m_axis_udp_rx_payload.tdata   ) ,
        .m_udp_payload_axis_tkeep  ( m_axis_udp_rx_payload.tkeep   ) ,
        .m_udp_payload_axis_tvalid ( m_axis_udp_rx_payload.tvalid  ) ,
        .m_udp_payload_axis_tready ( m_axis_udp_rx_payload.tready  ) ,
        .m_udp_payload_axis_tlast  ( m_axis_udp_rx_payload.tlast   ) ,
        .m_udp_payload_axis_tuser  ( m_axis_udp_rx_payload.tuser   ) ,
        // Status signals
        .ip_rx_busy                             ( csr_in.udp.status.ip_rx_busy.next                            ),
        .ip_tx_busy                             ( csr_in.udp.status.ip_tx_busy.next                            ),
        .udp_rx_busy                            ( csr_in.udp.status.udp_rx_busy.next                           ),
        .udp_tx_busy                            ( csr_in.udp.status.udp_tx_busy.next                           ),
        .ip_rx_error_header_early_termination   ( csr_in.udp.status.ip_rx_error_header_early_termination.next  ),
        .ip_rx_error_payload_early_termination  ( csr_in.udp.status.ip_rx_error_payload_early_termination.next ),
        .ip_rx_error_invalid_header             ( csr_in.udp.status.ip_rx_error_invalid_header.next            ),
        .ip_rx_error_invalid_checksum           ( csr_in.udp.status.ip_rx_error_invalid_checksum.next          ),
        .ip_tx_error_payload_early_termination  ( csr_in.udp.status.ip_tx_error_payload_early_termination.next ),
        .ip_tx_error_arp_failed                 ( csr_in.udp.status.ip_tx_error_arp_failed.next                ),
        .udp_rx_error_header_early_termination  ( csr_in.udp.status.udp_rx_error_header_early_termination.next ),
        .udp_rx_error_payload_early_termination ( csr_in.udp.status.udp_rx_error_payload_early_termination.next),
        .udp_tx_error_payload_early_termination ( csr_in.udp.status.udp_tx_error_payload_early_termination.next),
        // Configuration
        .local_mac       ( {csr_out.udp.cfg.local_mac.msb.addr.value, csr_out.udp.cfg.local_mac.lsb.addr.value} ) ,
        .local_ip        ( csr_out.udp.cfg.local_ip.ip.value                                                    ) ,
        .gateway_ip      ( csr_out.udp.cfg.gateway_ip.gateway.value                                             ) ,
        .subnet_mask     ( csr_out.udp.cfg.subnet_mask.mask.value                                               ) ,
        .clear_arp_cache ( csr_out.udp.cfg.arp_cache.clear.value                                                )
    );

    common_counter #(
        .NB_MAX_COUNT($bits(count_data))
    )
    u_ramp_gen
    (
        .i_clk              ( i_clk                                       ) ,
        .i_rst              ( i_rst | ~csr_out.debug.ramp.value           ) ,
        .i_start_count      ( 1'b1                                        ) ,
        .i_enable           ( count_en                                    ) ,
        .i_rf_max_count     ( csr_out.udp.udp_tx_hdr.options.length.value ) ,
        .o_counter          ( count_data                                  ) ,
        .o_count_done       ( count_done                                  ) ,
        .o_count_in_process ( count_in_proc                               )
    );

endmodule
