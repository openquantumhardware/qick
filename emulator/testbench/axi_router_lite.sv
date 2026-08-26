// AXI4-Lite Router Core
// Generic router that supports any number of AXI4-Lite slave interfaces
// Routes transactions from a single AXI4-Lite master based on target address.

module axi_router_lite_core #(
    parameter int NUM_SLAVES = 9,
    parameter int ADDR_WIDTH = 40,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDRS [NUM_SLAVES] = '{default: '0},
    parameter int ADDR_WIDTHS [NUM_SLAVES] = '{default: 8}
)(
    input  wire                     aclk,
    input  wire                     aresetn,

    // Master interface (input)
    input  wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    input  wire [2:0]               m_axi_awprot,
    input  wire                     m_axi_awvalid,
    output logic                    m_axi_awready,

    input  wire [DATA_WIDTH-1:0]    m_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    input  wire                     m_axi_wvalid,
    output logic                    m_axi_wready,

    output logic [1:0]              m_axi_bresp,
    output logic                    m_axi_bvalid,
    input  wire                     m_axi_bready,

    input  wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    input  wire [2:0]               m_axi_arprot,
    input  wire                     m_axi_arvalid,
    output logic                    m_axi_arready,

    output logic [DATA_WIDTH-1:0]   m_axi_rdata,
    output logic [1:0]              m_axi_rresp,
    output logic                    m_axi_rvalid,
    input  wire                     m_axi_rready,

    // Slave interfaces (output)
    // Write address channel
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] s_awaddr,
    output logic [NUM_SLAVES-1:0][2:0]            s_awprot,
    output logic [NUM_SLAVES-1:0]                 s_awvalid,
    input  wire  [NUM_SLAVES-1:0]                 s_awready,

    // Write data channel
    output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]   s_wdata,
    output logic [NUM_SLAVES-1:0][DATA_WIDTH/8-1:0] s_wstrb,
    output logic [NUM_SLAVES-1:0]                   s_wvalid,
    input  wire  [NUM_SLAVES-1:0]                   s_wready,

    // Write response channel
    input  wire  [NUM_SLAVES-1:0][1:0]  s_bresp,
    input  wire  [NUM_SLAVES-1:0]       s_bvalid,
    output logic [NUM_SLAVES-1:0]       s_bready,

    // Read address channel
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] s_araddr,
    output logic [NUM_SLAVES-1:0][2:0]            s_arprot,
    output logic [NUM_SLAVES-1:0]                 s_arvalid,
    input  wire  [NUM_SLAVES-1:0]                 s_arready,

    // Read data channel
    input  wire  [NUM_SLAVES-1:0][DATA_WIDTH-1:0] s_rdata,
    input  wire  [NUM_SLAVES-1:0][1:0]            s_rresp,
    input  wire  [NUM_SLAVES-1:0]                 s_rvalid,
    output logic [NUM_SLAVES-1:0]                 s_rready
);

    function automatic logic [NUM_SLAVES-1:0] decode_slave_sel(
        input logic [ADDR_WIDTH-1:0] addr
    );
        logic [NUM_SLAVES-1:0] sel;
        begin
            sel = '0;
            for (int i = 0; i < NUM_SLAVES; i++) begin
                if (addr[ADDR_WIDTH-1:16] == BASE_ADDRS[i][ADDR_WIDTH-1:16]) begin
                    sel[i] = 1'b1;
                end
            end
            return sel;
        end
    endfunction


    // Internal signals for write path
    logic [NUM_SLAVES-1:0] write_slave_sel;
    logic [NUM_SLAVES-1:0] write_awready;
    logic [NUM_SLAVES-1:0] write_wready;
    logic [NUM_SLAVES-1:0] write_resp_valid;
    logic [NUM_SLAVES-1:0] write_data_sel;

    // Internal signals for read path
    logic [NUM_SLAVES-1:0] read_slave_sel;
    logic [NUM_SLAVES-1:0] read_slave_ready;
    logic [NUM_SLAVES-1:0] read_resp_valid;

    // ============================================================================
    // Write Address Channel Routing
    // ============================================================================

    always_comb begin
        write_slave_sel = decode_slave_sel(m_axi_awaddr);
        write_awready = s_awready;
        m_axi_awready = 1'b0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (write_slave_sel[i]) m_axi_awready = write_awready[i];
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_awaddr[i] = m_axi_awaddr;
            s_awprot[i] = m_axi_awprot;
            s_awvalid[i] = m_axi_awvalid & write_slave_sel[i];
        end
    end

    // Keep write target stable between AW and W phases for single-beat AXI-Lite writes.
    logic [NUM_SLAVES-1:0] write_sel_q;
    logic write_sel_valid_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_sel_q       <= '0;
            write_sel_valid_q <= 1'b0;
        end else begin
            if (m_axi_wvalid && m_axi_wready) begin
                write_sel_valid_q <= 1'b0;
            end else if (!write_sel_valid_q && m_axi_awvalid && m_axi_awready) begin
                write_sel_q       <= write_slave_sel;
                write_sel_valid_q <= 1'b1;
            end
        end
    end

    always_comb begin
        write_data_sel = write_sel_valid_q ? write_sel_q : decode_slave_sel(m_axi_awaddr);
    end

    // ============================================================================
    // Write Data Channel Routing
    // ============================================================================

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_wdata[i] = m_axi_wdata;
            s_wstrb[i] = m_axi_wstrb;
            s_wvalid[i] = m_axi_wvalid & write_data_sel[i];
        end
    end

    always_comb begin
        write_wready = s_wready;
        m_axi_wready = 1'b0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (write_data_sel[i]) m_axi_wready = write_wready[i];
        end
    end

    // ============================================================================
    // Write Response Channel Routing
    // ============================================================================

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            write_resp_valid[i] = s_bvalid[i];
        end
    end

    logic [NUM_SLAVES-1:0] write_resp_pending;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_resp_pending <= '0;
        end else begin
            for (int i = 0; i < NUM_SLAVES; i++) begin
                if (write_data_sel[i] && m_axi_wvalid && m_axi_wready) begin
                    write_resp_pending[i] <= 1'b1;
                end else if (write_resp_pending[i] && write_resp_valid[i] && m_axi_bready) begin
                    write_resp_pending[i] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        m_axi_bvalid = 1'b0;
        m_axi_bresp = '0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (write_resp_pending[i] && write_resp_valid[i]) begin
                m_axi_bvalid = 1'b1;
                m_axi_bresp = s_bresp[i];
                break;
            end
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_bready[i] = m_axi_bready & write_resp_pending[i];
        end
    end

    // ============================================================================
    // Read Address Channel Routing
    // ============================================================================

    always_comb begin
        read_slave_sel = decode_slave_sel(m_axi_araddr);
        read_slave_ready = s_arready;
        m_axi_arready = 1'b0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (read_slave_sel[i]) m_axi_arready = read_slave_ready[i];
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_araddr[i] = m_axi_araddr;
            s_arprot[i] = m_axi_arprot;
            s_arvalid[i] = m_axi_arvalid & read_slave_sel[i];
        end
    end

    // ============================================================================
    // Read Data Channel Routing
    // ============================================================================

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            read_resp_valid[i] = s_rvalid[i];
        end
    end

    logic [NUM_SLAVES-1:0] read_resp_pending;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            read_resp_pending <= '0;
        end else begin
            for (int i = 0; i < NUM_SLAVES; i++) begin
                if (read_slave_sel[i] && m_axi_arvalid && m_axi_arready) begin
                    read_resp_pending[i] <= 1'b1;
                end else if (read_resp_pending[i] && read_resp_valid[i] && m_axi_rready) begin
                    read_resp_pending[i] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        m_axi_rvalid = 1'b0;
        m_axi_rdata = '0;
        m_axi_rresp = '0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (read_resp_pending[i] && read_resp_valid[i]) begin
                m_axi_rvalid = 1'b1;
                m_axi_rdata = s_rdata[i];
                m_axi_rresp = s_rresp[i];
                break;
            end
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_rready[i] = m_axi_rready & read_resp_pending[i];
        end
    end

endmodule


// AXI4-Lite Router with Named Slave Interfaces
// Instantiates the core router and maps interfaces to descriptive names

module axi_router_lite #(
    parameter int ADDR_WIDTH = 40,
    parameter int DATA_WIDTH = 32
)(
    input  wire                     aclk,
    input  wire                     aresetn,

    // Master Interface
    input  wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    input  wire [2:0]               m_axi_awprot,
    input  wire                     m_axi_awvalid,
    output logic                    m_axi_awready,

    input  wire [DATA_WIDTH-1:0]    m_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    input  wire                     m_axi_wvalid,
    output logic                    m_axi_wready,

    output logic [1:0]              m_axi_bresp,
    output logic                    m_axi_bvalid,
    input  wire                     m_axi_bready,

    input  wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    input  wire [2:0]               m_axi_arprot,
    input  wire                     m_axi_arvalid,
    output logic                    m_axi_arready,

    output logic [DATA_WIDTH-1:0]   m_axi_rdata,
    output logic [1:0]              m_axi_rresp,
    output logic                    m_axi_rvalid,
    input  wire                     m_axi_rready,

    // Slave 0: tProc
    output logic [7:0]              s_tproc_awaddr,
    output logic [2:0]              s_tproc_awprot,
    output logic                    s_tproc_awvalid,
    input  wire                     s_tproc_awready,

    output logic [DATA_WIDTH-1:0]   s_tproc_wdata,
    output logic [DATA_WIDTH/8-1:0] s_tproc_wstrb,
    output logic                    s_tproc_wvalid,
    input  wire                     s_tproc_wready,

    input  wire [1:0]               s_tproc_bresp,
    input  wire                     s_tproc_bvalid,
    output logic                    s_tproc_bready,

    output logic [7:0]              s_tproc_araddr,
    output logic [2:0]              s_tproc_arprot,
    output logic                    s_tproc_arvalid,
    input  wire                     s_tproc_arready,

    input  wire [DATA_WIDTH-1:0]    s_tproc_rdata,
    input  wire [1:0]               s_tproc_rresp,
    input  wire                     s_tproc_rvalid,
    output logic                    s_tproc_rready,

    // Slave 1: Signal Generator 0
    output logic [5:0]              s_sg0_awaddr,
    output logic [2:0]              s_sg0_awprot,
    output logic                    s_sg0_awvalid,
    input  wire                     s_sg0_awready,

    output logic [DATA_WIDTH-1:0]   s_sg0_wdata,
    output logic [DATA_WIDTH/8-1:0] s_sg0_wstrb,
    output logic                    s_sg0_wvalid,
    input  wire                     s_sg0_wready,

    input  wire [1:0]               s_sg0_bresp,
    input  wire                     s_sg0_bvalid,
    output logic                    s_sg0_bready,

    output logic [5:0]              s_sg0_araddr,
    output logic [2:0]              s_sg0_arprot,
    output logic                    s_sg0_arvalid,
    input  wire                     s_sg0_arready,

    input  wire [DATA_WIDTH-1:0]    s_sg0_rdata,
    input  wire [1:0]               s_sg0_rresp,
    input  wire                     s_sg0_rvalid,
    output logic                    s_sg0_rready,

    // Slave 2: Readout Buffer 0
    output logic [5:0]              s_buf0_awaddr,
    output logic [2:0]              s_buf0_awprot,
    output logic                    s_buf0_awvalid,
    input  wire                     s_buf0_awready,

    output logic [DATA_WIDTH-1:0]   s_buf0_wdata,
    output logic [DATA_WIDTH/8-1:0] s_buf0_wstrb,
    output logic                    s_buf0_wvalid,
    input  wire                     s_buf0_wready,

    input  wire [1:0]               s_buf0_bresp,
    input  wire                     s_buf0_bvalid,
    output logic                    s_buf0_bready,

    output logic [5:0]              s_buf0_araddr,
    output logic [2:0]              s_buf0_arprot,
    output logic                    s_buf0_arvalid,
    input  wire                     s_buf0_arready,

    input  wire [DATA_WIDTH-1:0]    s_buf0_rdata,
    input  wire [1:0]               s_buf0_rresp,
    input  wire                     s_buf0_rvalid,
    output logic                    s_buf0_rready,

    // Slave 3: Readout v2
    output logic [5:0]              s_rov2_awaddr,
    output logic [2:0]              s_rov2_awprot,
    output logic                    s_rov2_awvalid,
    input  wire                     s_rov2_awready,

    output logic [DATA_WIDTH-1:0]   s_rov2_wdata,
    output logic [DATA_WIDTH/8-1:0] s_rov2_wstrb,
    output logic                    s_rov2_wvalid,
    input  wire                     s_rov2_wready,

    input  wire [1:0]               s_rov2_bresp,
    input  wire                     s_rov2_bvalid,
    output logic                    s_rov2_bready,

    output logic [5:0]              s_rov2_araddr,
    output logic [2:0]              s_rov2_arprot,
    output logic                    s_rov2_arvalid,
    input  wire                     s_rov2_arready,

    input  wire [DATA_WIDTH-1:0]    s_rov2_rdata,
    input  wire [1:0]               s_rov2_rresp,
    input  wire                     s_rov2_rvalid,
    output logic                    s_rov2_rready,

    // Slave 4: Readout Buffer 1
    output logic [5:0]              s_buf1_awaddr,
    output logic [2:0]              s_buf1_awprot,
    output logic                    s_buf1_awvalid,
    input  wire                     s_buf1_awready,

    output logic [DATA_WIDTH-1:0]   s_buf1_wdata,
    output logic [DATA_WIDTH/8-1:0] s_buf1_wstrb,
    output logic                    s_buf1_wvalid,
    input  wire                     s_buf1_wready,

    input  wire [1:0]               s_buf1_bresp,
    input  wire                     s_buf1_bvalid,
    output logic                    s_buf1_bready,

    output logic [5:0]              s_buf1_araddr,
    output logic [2:0]              s_buf1_arprot,
    output logic                    s_buf1_arvalid,
    input  wire                     s_buf1_arready,

    input  wire [DATA_WIDTH-1:0]    s_buf1_rdata,
    input  wire [1:0]               s_buf1_rresp,
    input  wire                     s_buf1_rvalid,
    output logic                    s_buf1_rready,

    // Slave 5: Signal Generator 1
    output logic [5:0]              s_sg1_awaddr,
    output logic [2:0]              s_sg1_awprot,
    output logic                    s_sg1_awvalid,
    input  wire                     s_sg1_awready,

    output logic [DATA_WIDTH-1:0]   s_sg1_wdata,
    output logic [DATA_WIDTH/8-1:0] s_sg1_wstrb,
    output logic                    s_sg1_wvalid,
    input  wire                     s_sg1_wready,

    input  wire [1:0]               s_sg1_bresp,
    input  wire                     s_sg1_bvalid,
    output logic                    s_sg1_bready,

    output logic [5:0]              s_sg1_araddr,
    output logic [2:0]              s_sg1_arprot,
    output logic                    s_sg1_arvalid,
    input  wire                     s_sg1_arready,

    input  wire [DATA_WIDTH-1:0]    s_sg1_rdata,
    input  wire [1:0]               s_sg1_rresp,
    input  wire                     s_sg1_rvalid,
    output logic                    s_sg1_rready,

    // Slave 6: Signal Generator 2
    output logic [7:0]              s_sg2_awaddr,
    output logic [2:0]              s_sg2_awprot,
    output logic                    s_sg2_awvalid,
    input  wire                     s_sg2_awready,

    output logic [DATA_WIDTH-1:0]   s_sg2_wdata,
    output logic [DATA_WIDTH/8-1:0] s_sg2_wstrb,
    output logic                    s_sg2_wvalid,
    input  wire                     s_sg2_wready,

    input  wire [1:0]               s_sg2_bresp,
    input  wire                     s_sg2_bvalid,
    output logic                    s_sg2_bready,

    output logic [7:0]              s_sg2_araddr,
    output logic [2:0]              s_sg2_arprot,
    output logic                    s_sg2_arvalid,
    input  wire                     s_sg2_arready,

    input  wire [DATA_WIDTH-1:0]    s_sg2_rdata,
    input  wire [1:0]               s_sg2_rresp,
    input  wire                     s_sg2_rvalid,
    output logic                    s_sg2_rready,

    // Slave 7: PFB Readout
    output logic [7:0]              s_pfb_ro_awaddr,
    output logic [2:0]              s_pfb_ro_awprot,
    output logic                    s_pfb_ro_awvalid,
    input  wire                     s_pfb_ro_awready,

    output logic [DATA_WIDTH-1:0]   s_pfb_ro_wdata,
    output logic [DATA_WIDTH/8-1:0] s_pfb_ro_wstrb,
    output logic                    s_pfb_ro_wvalid,
    input  wire                     s_pfb_ro_wready,

    input  wire [1:0]               s_pfb_ro_bresp,
    input  wire                     s_pfb_ro_bvalid,
    output logic                    s_pfb_ro_bready,

    output logic [7:0]              s_pfb_ro_araddr,
    output logic [2:0]              s_pfb_ro_arprot,
    output logic                    s_pfb_ro_arvalid,
    input  wire                     s_pfb_ro_arready,

    input  wire [DATA_WIDTH-1:0]    s_pfb_ro_rdata,
    input  wire [1:0]               s_pfb_ro_rresp,
    input  wire                     s_pfb_ro_rvalid,
    output logic                    s_pfb_ro_rready,

    // Slave 8: Readout Buffer 2
    output logic [5:0]              s_buf2_awaddr,
    output logic [2:0]              s_buf2_awprot,
    output logic                    s_buf2_awvalid,
    input  wire                     s_buf2_awready,

    output logic [DATA_WIDTH-1:0]   s_buf2_wdata,
    output logic [DATA_WIDTH/8-1:0] s_buf2_wstrb,
    output logic                    s_buf2_wvalid,
    input  wire                     s_buf2_wready,

    input  wire [1:0]               s_buf2_bresp,
    input  wire                     s_buf2_bvalid,
    output logic                    s_buf2_bready,

    output logic [5:0]              s_buf2_araddr,
    output logic [2:0]              s_buf2_arprot,
    output logic                    s_buf2_arvalid,
    input  wire                     s_buf2_arready,

    input  wire [DATA_WIDTH-1:0]    s_buf2_rdata,
    input  wire [1:0]               s_buf2_rresp,
    input  wire                     s_buf2_rvalid,
    output logic                    s_buf2_rready,

    // Output select signals (for debugging/monitoring)
    output logic                    tproc_sel,
    output logic                    sg0_sel,
    output logic                    sg1_sel,
    output logic                    sg2_sel,
    output logic                    buf0_sel,
    output logic                    rov2_sel,
    output logic                    buf1_sel,
    output logic                    pfb_ro_sel,
    output logic                    buf2_sel
);

    // Slave configuration
    localparam int NUM_SLAVES = 9;
    localparam logic [ADDR_WIDTH-1:0] BASE_ADDRS[NUM_SLAVES] = '{
        40'h04_0026_0000,  // [0] tProc
        40'h04_001C_0000,  // [1] SG0
        40'h04_0006_0000,  // [2] BUF0
        40'h04_0008_0000,  // [3] ROV2
        40'h04_0007_0000,  // [4] BUF1
        40'h04_001D_0000,  // [5] SG1
        40'h04_001E_0000,  // [6] SG2
        40'h04_0009_0000,  // [7] PFB_RO
        40'h04_0004_0000   // [8] BUF2
    };

    localparam int ADDR_WIDTHS[NUM_SLAVES] = '{
        8,  // [0] tProc
        6,  // [1] SG0
        6,  // [2] BUF0
        6,  // [3] ROV2
        6,  // [4] BUF1
        6,  // [5] SG1
        8,  // [6] SG2
        8,  // [7] PFB_RO
        6   // [8] BUF2
    };

    // Core router signals
    logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] s_awaddr_core;
    logic [NUM_SLAVES-1:0][2:0]            s_awprot_core;
    logic [NUM_SLAVES-1:0]                 s_awvalid_core;
    logic [NUM_SLAVES-1:0]                 s_awready_core;

    logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]   s_wdata_core;
    logic [NUM_SLAVES-1:0][DATA_WIDTH/8-1:0] s_wstrb_core;
    logic [NUM_SLAVES-1:0]                   s_wvalid_core;
    logic [NUM_SLAVES-1:0]                   s_wready_core;

    logic [NUM_SLAVES-1:0][1:0]  s_bresp_core;
    logic [NUM_SLAVES-1:0]       s_bvalid_core;
    logic [NUM_SLAVES-1:0]       s_bready_core;

    logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] s_araddr_core;
    logic [NUM_SLAVES-1:0][2:0]            s_arprot_core;
    logic [NUM_SLAVES-1:0]                 s_arvalid_core;
    logic [NUM_SLAVES-1:0]                 s_arready_core;

    logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0] s_rdata_core;
    logic [NUM_SLAVES-1:0][1:0]            s_rresp_core;
    logic [NUM_SLAVES-1:0]                 s_rvalid_core;
    logic [NUM_SLAVES-1:0]                 s_rready_core;

    // Instantiate core router
    axi_router_lite_core #(
        .NUM_SLAVES(NUM_SLAVES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BASE_ADDRS(BASE_ADDRS),
        .ADDR_WIDTHS(ADDR_WIDTHS)
    ) core_router (
        .aclk(aclk),
        .aresetn(aresetn),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .s_awaddr(s_awaddr_core),
        .s_awprot(s_awprot_core),
        .s_awvalid(s_awvalid_core),
        .s_awready(s_awready_core),
        .s_wdata(s_wdata_core),
        .s_wstrb(s_wstrb_core),
        .s_wvalid(s_wvalid_core),
        .s_wready(s_wready_core),
        .s_bresp(s_bresp_core),
        .s_bvalid(s_bvalid_core),
        .s_bready(s_bready_core),
        .s_araddr(s_araddr_core),
        .s_arprot(s_arprot_core),
        .s_arvalid(s_arvalid_core),
        .s_arready(s_arready_core),
        .s_rdata(s_rdata_core),
        .s_rresp(s_rresp_core),
        .s_rvalid(s_rvalid_core),
        .s_rready(s_rready_core)
    );

    // Map core signals to named slave interfaces
    // Slave 0: tProc
    assign s_tproc_awaddr = s_awaddr_core[0][7:0];
    assign s_tproc_awprot = s_awprot_core[0];
    assign s_tproc_awvalid = s_awvalid_core[0];
    assign s_awready_core[0] = s_tproc_awready;
    assign s_tproc_wdata = s_wdata_core[0];
    assign s_tproc_wstrb = s_wstrb_core[0];
    assign s_tproc_wvalid = s_wvalid_core[0];
    assign s_wready_core[0] = s_tproc_wready;
    assign s_bresp_core[0] = s_tproc_bresp;
    assign s_bvalid_core[0] = s_tproc_bvalid;
    assign s_tproc_bready = s_bready_core[0];
    assign s_tproc_araddr = s_araddr_core[0][7:0];
    assign s_tproc_arprot = s_arprot_core[0];
    assign s_tproc_arvalid = s_arvalid_core[0];
    assign s_arready_core[0] = s_tproc_arready;
    assign s_rdata_core[0] = s_tproc_rdata;
    assign s_rresp_core[0] = s_tproc_rresp;
    assign s_rvalid_core[0] = s_tproc_rvalid;
    assign s_tproc_rready = s_rready_core[0];

    // Slave 1: SG0
    assign s_sg0_awaddr = s_awaddr_core[1][5:0];
    assign s_sg0_awprot = s_awprot_core[1];
    assign s_sg0_awvalid = s_awvalid_core[1];
    assign s_awready_core[1] = s_sg0_awready;
    assign s_sg0_wdata = s_wdata_core[1];
    assign s_sg0_wstrb = s_wstrb_core[1];
    assign s_sg0_wvalid = s_wvalid_core[1];
    assign s_wready_core[1] = s_sg0_wready;
    assign s_bresp_core[1] = s_sg0_bresp;
    assign s_bvalid_core[1] = s_sg0_bvalid;
    assign s_sg0_bready = s_bready_core[1];
    assign s_sg0_araddr = s_araddr_core[1][5:0];
    assign s_sg0_arprot = s_arprot_core[1];
    assign s_sg0_arvalid = s_arvalid_core[1];
    assign s_arready_core[1] = s_sg0_arready;
    assign s_rdata_core[1] = s_sg0_rdata;
    assign s_rresp_core[1] = s_sg0_rresp;
    assign s_rvalid_core[1] = s_sg0_rvalid;
    assign s_sg0_rready = s_rready_core[1];

    // Slave 2: BUF0
    assign s_buf0_awaddr = s_awaddr_core[2][5:0];
    assign s_buf0_awprot = s_awprot_core[2];
    assign s_buf0_awvalid = s_awvalid_core[2];
    assign s_awready_core[2] = s_buf0_awready;
    assign s_buf0_wdata = s_wdata_core[2];
    assign s_buf0_wstrb = s_wstrb_core[2];
    assign s_buf0_wvalid = s_wvalid_core[2];
    assign s_wready_core[2] = s_buf0_wready;
    assign s_bresp_core[2] = s_buf0_bresp;
    assign s_bvalid_core[2] = s_buf0_bvalid;
    assign s_buf0_bready = s_bready_core[2];
    assign s_buf0_araddr = s_araddr_core[2][5:0];
    assign s_buf0_arprot = s_arprot_core[2];
    assign s_buf0_arvalid = s_arvalid_core[2];
    assign s_arready_core[2] = s_buf0_arready;
    assign s_rdata_core[2] = s_buf0_rdata;
    assign s_rresp_core[2] = s_buf0_rresp;
    assign s_rvalid_core[2] = s_buf0_rvalid;
    assign s_buf0_rready = s_rready_core[2];

    // Slave 3: ROV2
    assign s_rov2_awaddr = s_awaddr_core[3][5:0];
    assign s_rov2_awprot = s_awprot_core[3];
    assign s_rov2_awvalid = s_awvalid_core[3];
    assign s_awready_core[3] = s_rov2_awready;
    assign s_rov2_wdata = s_wdata_core[3];
    assign s_rov2_wstrb = s_wstrb_core[3];
    assign s_rov2_wvalid = s_wvalid_core[3];
    assign s_wready_core[3] = s_rov2_wready;
    assign s_bresp_core[3] = s_rov2_bresp;
    assign s_bvalid_core[3] = s_rov2_bvalid;
    assign s_rov2_bready = s_bready_core[3];
    assign s_rov2_araddr = s_araddr_core[3][5:0];
    assign s_rov2_arprot = s_arprot_core[3];
    assign s_rov2_arvalid = s_arvalid_core[3];
    assign s_arready_core[3] = s_rov2_arready;
    assign s_rdata_core[3] = s_rov2_rdata;
    assign s_rresp_core[3] = s_rov2_rresp;
    assign s_rvalid_core[3] = s_rov2_rvalid;
    assign s_rov2_rready = s_rready_core[3];

    // Slave 4: BUF1
    assign s_buf1_awaddr = s_awaddr_core[4][5:0];
    assign s_buf1_awprot = s_awprot_core[4];
    assign s_buf1_awvalid = s_awvalid_core[4];
    assign s_awready_core[4] = s_buf1_awready;
    assign s_buf1_wdata = s_wdata_core[4];
    assign s_buf1_wstrb = s_wstrb_core[4];
    assign s_buf1_wvalid = s_wvalid_core[4];
    assign s_wready_core[4] = s_buf1_wready;
    assign s_bresp_core[4] = s_buf1_bresp;
    assign s_bvalid_core[4] = s_buf1_bvalid;
    assign s_buf1_bready = s_bready_core[4];
    assign s_buf1_araddr = s_araddr_core[4][5:0];
    assign s_buf1_arprot = s_arprot_core[4];
    assign s_buf1_arvalid = s_arvalid_core[4];
    assign s_arready_core[4] = s_buf1_arready;
    assign s_rdata_core[4] = s_buf1_rdata;
    assign s_rresp_core[4] = s_buf1_rresp;
    assign s_rvalid_core[4] = s_buf1_rvalid;
    assign s_buf1_rready = s_rready_core[4];

    // Slave 5: SG1
    assign s_sg1_awaddr = s_awaddr_core[5][5:0];
    assign s_sg1_awprot = s_awprot_core[5];
    assign s_sg1_awvalid = s_awvalid_core[5];
    assign s_awready_core[5] = s_sg1_awready;
    assign s_sg1_wdata = s_wdata_core[5];
    assign s_sg1_wstrb = s_wstrb_core[5];
    assign s_sg1_wvalid = s_wvalid_core[5];
    assign s_wready_core[5] = s_sg1_wready;
    assign s_bresp_core[5] = s_sg1_bresp;
    assign s_bvalid_core[5] = s_sg1_bvalid;
    assign s_sg1_bready = s_bready_core[5];
    assign s_sg1_araddr = s_araddr_core[5][5:0];
    assign s_sg1_arprot = s_arprot_core[5];
    assign s_sg1_arvalid = s_arvalid_core[5];
    assign s_arready_core[5] = s_sg1_arready;
    assign s_rdata_core[5] = s_sg1_rdata;
    assign s_rresp_core[5] = s_sg1_rresp;
    assign s_rvalid_core[5] = s_sg1_rvalid;
    assign s_sg1_rready = s_rready_core[5];

    // Slave 6: SG2
    assign s_sg2_awaddr = s_awaddr_core[6][7:0];
    assign s_sg2_awprot = s_awprot_core[6];
    assign s_sg2_awvalid = s_awvalid_core[6];
    assign s_awready_core[6] = s_sg2_awready;
    assign s_sg2_wdata = s_wdata_core[6];
    assign s_sg2_wstrb = s_wstrb_core[6];
    assign s_sg2_wvalid = s_wvalid_core[6];
    assign s_wready_core[6] = s_sg2_wready;
    assign s_bresp_core[6] = s_sg2_bresp;
    assign s_bvalid_core[6] = s_sg2_bvalid;
    assign s_sg2_bready = s_bready_core[6];
    assign s_sg2_araddr = s_araddr_core[6][7:0];
    assign s_sg2_arprot = s_arprot_core[6];
    assign s_sg2_arvalid = s_arvalid_core[6];
    assign s_arready_core[6] = s_sg2_arready;
    assign s_rdata_core[6] = s_sg2_rdata;
    assign s_rresp_core[6] = s_sg2_rresp;
    assign s_rvalid_core[6] = s_sg2_rvalid;
    assign s_sg2_rready = s_rready_core[6];

    // Slave 7: PFB_RO
    assign s_pfb_ro_awaddr = s_awaddr_core[7][7:0];
    assign s_pfb_ro_awprot = s_awprot_core[7];
    assign s_pfb_ro_awvalid = s_awvalid_core[7];
    assign s_awready_core[7] = s_pfb_ro_awready;
    assign s_pfb_ro_wdata = s_wdata_core[7];
    assign s_pfb_ro_wstrb = s_wstrb_core[7];
    assign s_pfb_ro_wvalid = s_wvalid_core[7];
    assign s_wready_core[7] = s_pfb_ro_wready;
    assign s_bresp_core[7] = s_pfb_ro_bresp;
    assign s_bvalid_core[7] = s_pfb_ro_bvalid;
    assign s_pfb_ro_bready = s_bready_core[7];
    assign s_pfb_ro_araddr = s_araddr_core[7][7:0];
    assign s_pfb_ro_arprot = s_arprot_core[7];
    assign s_pfb_ro_arvalid = s_arvalid_core[7];
    assign s_arready_core[7] = s_pfb_ro_arready;
    assign s_rdata_core[7] = s_pfb_ro_rdata;
    assign s_rresp_core[7] = s_pfb_ro_rresp;
    assign s_rvalid_core[7] = s_pfb_ro_rvalid;
    assign s_pfb_ro_rready = s_rready_core[7];

    // Slave 8: BUF2
    assign s_buf2_awaddr = s_awaddr_core[8][5:0];
    assign s_buf2_awprot = s_awprot_core[8];
    assign s_buf2_awvalid = s_awvalid_core[8];
    assign s_awready_core[8] = s_buf2_awready;
    assign s_buf2_wdata = s_wdata_core[8];
    assign s_buf2_wstrb = s_wstrb_core[8];
    assign s_buf2_wvalid = s_wvalid_core[8];
    assign s_wready_core[8] = s_buf2_wready;
    assign s_bresp_core[8] = s_buf2_bresp;
    assign s_bvalid_core[8] = s_buf2_bvalid;
    assign s_buf2_bready = s_bready_core[8];
    assign s_buf2_araddr = s_araddr_core[8][5:0];
    assign s_buf2_arprot = s_arprot_core[8];
    assign s_buf2_arvalid = s_arvalid_core[8];
    assign s_arready_core[8] = s_buf2_arready;
    assign s_rdata_core[8] = s_buf2_rdata;
    assign s_rresp_core[8] = s_buf2_rresp;
    assign s_rvalid_core[8] = s_buf2_rvalid;
    assign s_buf2_rready = s_rready_core[8];

    // Debugging/monitoring select signals
    assign tproc_sel = s_awvalid_core[0] | s_arvalid_core[0];
    assign sg0_sel = s_awvalid_core[1] | s_arvalid_core[1];
    assign buf0_sel = s_awvalid_core[2] | s_arvalid_core[2];
    assign rov2_sel = s_awvalid_core[3] | s_arvalid_core[3];
    assign buf1_sel = s_awvalid_core[4] | s_arvalid_core[4];
    assign sg1_sel = s_awvalid_core[5] | s_arvalid_core[5];
    assign sg2_sel = s_awvalid_core[6] | s_arvalid_core[6];
    assign pfb_ro_sel = s_awvalid_core[7] | s_arvalid_core[7];
    assign buf2_sel = s_awvalid_core[8] | s_arvalid_core[8];

endmodule
