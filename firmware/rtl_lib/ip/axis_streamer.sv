`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_streamer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_streamer.sv
//!
//! @brief   AXI4-Stream buffer with an AXI4-Lite control interface, for DMA
//!          readout of a captured stream.
//!
//! @details
//! Wraps the streamer core with an axil_slv register block.
//!
//! Register map (byte-addressed, 32-bit registers):
//!   0x00 START  RW  [0]     block enable, LEVEL not pulse
//!   0x04 FLUSH  RW  [0]     1 = drain a partial packet with tlast, 0 = discard
//!   0x08 MODE   RW  [0]     0 = one-shot, 1 = continuous
//!   0x0C NSAMP  RW  [31:0]  beats per packet, 0 keeps the block idle
//!   0x10 LOST   RO  [31:0]  beats dropped while running, latched when stopping
//!   0x14 STATUS RO  [5:0]   see below
//!
//! STATUS bits:
//!   [0] RUNNING    the core is capturing and streaming
//!   [1] DONE       one-shot packet finished, clear START to return to idle
//!   [2] IDLE       safe to reconfigure, and LOST holds the last run's count
//!   [3] OVERFLOW   sticky, samples were lost during this or the last run,
//!                  cleared automatically when a new run starts
//!   [4] FIFO_FULL  instantaneous, diagnostic only
//!   [5] FIFO_EMPTY instantaneous, diagnostic only
//!
//! SOFTWARE SEQUENCE
//!   write NSAMP, MODE, FLUSH  (only while STATUS.IDLE is set)
//!   write START = 1
//!   one-shot   : wait for the DMA to see tlast, or poll STATUS.DONE
//!   continuous : run until you choose to stop
//!   write START = 0
//!   poll STATUS.IDLE, then read LOST
//!
//!   STOPPING IS NOT INSTANTANEOUS: START crosses several flops, so the core
//!   keeps streaming for a few cycles after the write retires. Always poll
//!   STATUS.IDLE instead of assuming the output stopped.
//!
//!   LOST is only meaningful while STATUS.IDLE is set. It is latched in the
//!   s_axis domain and read from the s_axi domain with no handshake, so a read
//!   taken mid-run can return a torn value. STATUS.OVERFLOW is the flag to poll
//!   during a run; LOST is the exact count afterwards.
//!
//! WHAT LOST MEANS TO SOFTWARE
//!   With the intended source, a free-running converter that cannot be
//!   stalled, LOST is the number of samples that were dropped, and
//!       samples produced == samples received by the DMA + LOST
//!   A non-zero LOST therefore means the record has gaps and the DMA did not
//!   keep up. See the streamer core header for what the counter measures when
//!   the source honours tready instead.
//!
//! CLOCK DOMAIN CROSSINGS
//!   Config out (s_axi -> core): START is synchronised inside the core. MODE,
//!   FLUSH and NSAMP are NOT synchronised: the core samples them continuously
//!   while stopped, which is a multi-cycle path. They are guaranteed stable by
//!   the software sequence above (they are written before START), but the path
//!   MUST be constrained in the XDC with set_max_delay -datapath_only plus
//!   set_bus_skew, or a bus caught mid-change can be captured with mixed bits.
//!
//!   Status in (core -> s_axi): every STATUS bit is synchronised individually
//!   below. They are therefore NOT coherent with each other. That is fine for
//!   status polling and is why the register exposes decoded flags rather than
//!   the raw FSM encoding, whose bits could otherwise be seen in an invalid
//!   intermediate combination.
//!
//! @author  @lharnaldi
//!
//! @version 3.0
///////////////////////////////////////////////////////////////////////////////

module axis_streamer #(
    parameter int B_TDATA = 16,   //! input AXIS tdata width
    parameter int B_TUSER = 8,    //! input AXIS tuser width
    parameter int B_AXIS  = 32,   //! output AXIS tdata width
    parameter int N_FIFO  = 16,   //! internal FIFO depth, see CAPTURE DEPTH
    //! ! Untyped and defaulted to a plain string literal on purpose — see the
    //! streamer core header. "auto" lets Vivado pick the primitive.
    parameter FIFO_MEM_TYPE = "auto"
) (
    // AXI4-Lite slave, configuration
    input  logic                s_axi_aclk,
    input  logic                s_axi_aresetn,

    input  logic [5:0]          s_axi_awaddr,
    input  logic [2:0]          s_axi_awprot,
    input  logic                s_axi_awvalid,
    output logic                s_axi_awready,

    input  logic [31:0]         s_axi_wdata,
    input  logic [3:0]          s_axi_wstrb,
    input  logic                s_axi_wvalid,
    output logic                s_axi_wready,

    output logic [1:0]          s_axi_bresp,
    output logic                s_axi_bvalid,
    input  logic                s_axi_bready,

    input  logic [5:0]          s_axi_araddr,
    input  logic [2:0]          s_axi_arprot,
    input  logic                s_axi_arvalid,
    output logic                s_axi_arready,

    output logic [31:0]         s_axi_rdata,
    output logic [1:0]          s_axi_rresp,
    output logic                s_axi_rvalid,
    input  logic                s_axi_rready,

    // AXI4-Stream slave, input
    input  logic                s_axis_aresetn,
    input  logic                s_axis_aclk,
    input  logic                s_axis_tvalid,
    output logic                s_axis_tready,
    input  logic [B_TDATA-1:0]  s_axis_tdata,
    input  logic [B_TUSER-1:0]  s_axis_tuser,

    // AXI4-Stream master, output
    input  logic                m_axis_aresetn,
    input  logic                m_axis_aclk,
    output logic                m_axis_tvalid,
    input  logic                m_axis_tready,
    output logic [B_AXIS-1:0]   m_axis_tdata,
    output logic                m_axis_tlast,

    output logic [31:0]         dbg_probe
);

    // ------------------------------------------------------------------------
    // Register map
    // ------------------------------------------------------------------------
    localparam int NUM_REGS = 6;
    localparam int R_START  = 0;
    localparam int R_FLUSH  = 1;
    localparam int R_MODE   = 2;
    localparam int R_NSAMP  = 3;
    localparam int R_LOST   = 4;
    localparam int R_STATUS = 5;

    //! Status bit positions, mirrored in the RDL and the Python driver.
    localparam int ST_RUNNING = 0;
    localparam int ST_DONE    = 1;
    localparam int ST_IDLE    = 2;
    localparam int ST_OVF     = 3;
    localparam int ST_FULL    = 4;
    localparam int ST_EMPTY   = 5;

    localparam int N_STATUS = 6;

    logic [31:0]         slv_regs_o [NUM_REGS];
    logic [31:0]         slv_regs_i [NUM_REGS];
    logic [NUM_REGS-1:0] reg_ro;

    logic                start_reg;
    logic                flush_reg;
    logic                mode_reg;
    logic [31:0]         nsamp_reg;
    logic [31:0]         lost_reg;

    logic [N_STATUS-1:0] core_status;    //! raw, mixed clock domains
    logic [N_STATUS-1:0] status_sync;    //! each bit resynchronised to s_axi

    assign start_reg = slv_regs_o[R_START][0];
    assign flush_reg = slv_regs_o[R_FLUSH][0];
    assign mode_reg  = slv_regs_o[R_MODE][0];
    assign nsamp_reg = slv_regs_o[R_NSAMP];

    //! Read-only registers read back from i_slv_regs instead of the write port.
    assign reg_ro = (1 << R_LOST) | (1 << R_STATUS);

    always_comb begin
        for (int k = 0; k < NUM_REGS; k++) begin
            slv_regs_i[k] = slv_regs_o[k];
        end
        slv_regs_i[R_LOST]   = lost_reg;
        slv_regs_i[R_STATUS] = {{(32-N_STATUS){1'b0}}, status_sync};
    end

    // ------------------------------------------------------------------------
    // Status resynchronisation into the AXI-Lite domain
    // ------------------------------------------------------------------------
    //! One synchroniser per bit. Each flag is independently meaningful, so no
    //! coherency between them is required or implied.
    generate
        for (genvar gi = 0; gi < N_STATUS; gi++) begin : g_status_sync
            cdc_bit_sync #(.NSTAGES(2)) u_sync (
                .i_clk   (s_axi_aclk    ),
                .i_rstn  (s_axi_aresetn ),
                .i_async (core_status[gi]),
                .o_sync  (status_sync[gi])
            );
        end
    endgenerate

    // ------------------------------------------------------------------------
    // AXI4-Lite register block
    // ------------------------------------------------------------------------
    axil_slv #(
        .AXI_DW   (32       ),
        .AXI_AW   (6        ),
        .NUM_REGS (NUM_REGS )
    ) axil_slv_i (
        .s_axi_aclk        (s_axi_aclk   ),
        .s_axi_aresetn     (s_axi_aresetn),
        .s_axi_awaddr      (s_axi_awaddr ),
        .s_axi_awprot      (s_axi_awprot ),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),
        .s_axi_wdata       (s_axi_wdata  ),
        .s_axi_wstrb       (s_axi_wstrb  ),
        .s_axi_wvalid      (s_axi_wvalid ),
        .s_axi_wready      (s_axi_wready ),
        .s_axi_bresp       (s_axi_bresp  ),
        .s_axi_bvalid      (s_axi_bvalid ),
        .s_axi_bready      (s_axi_bready ),
        .s_axi_araddr      (s_axi_araddr ),
        .s_axi_arprot      (s_axi_arprot ),
        .s_axi_arvalid     (s_axi_arvalid),
        .s_axi_arready     (s_axi_arready),
        .s_axi_rdata       (s_axi_rdata  ),
        .s_axi_rresp       (s_axi_rresp  ),
        .s_axi_rvalid      (s_axi_rvalid ),
        .s_axi_rready      (s_axi_rready ),

        .o_slv_regs        (slv_regs_o   ),
        .i_slv_regs        (slv_regs_i   ),
        .i_reg_is_readonly (reg_ro       )
    );

    // ------------------------------------------------------------------------
    // Streamer core
    // ------------------------------------------------------------------------
    streamer #(
        .B_TDATA       (B_TDATA      ),
        .B_TUSER       (B_TUSER      ),
        .B_AXIS        (B_AXIS       ),
        .N_FIFO        (N_FIFO       ),
        .FIFO_MEM_TYPE (FIFO_MEM_TYPE)
    ) streamer_i (
        .s_axis_aresetn (s_axis_aresetn),
        .s_axis_aclk    (s_axis_aclk   ),
        .s_axis_tvalid  (s_axis_tvalid ),
        .s_axis_tready  (s_axis_tready ),
        .s_axis_tdata   (s_axis_tdata  ),
        .s_axis_tuser   (s_axis_tuser  ),

        .m_axis_aresetn (m_axis_aresetn),
        .m_axis_aclk    (m_axis_aclk   ),
        .m_axis_tvalid  (m_axis_tvalid ),
        .m_axis_tready  (m_axis_tready ),
        .m_axis_tdata   (m_axis_tdata  ),
        .m_axis_tlast   (m_axis_tlast  ),

        .start_reg      (start_reg     ),
        .flush_reg      (flush_reg     ),
        .mode_reg       (mode_reg      ),
        .nsamp_reg      (nsamp_reg     ),
        .lost_reg       (lost_reg      ),

        .o_status       (core_status   ),
        .dbg_probe      (dbg_probe     )
    );

endmodule

