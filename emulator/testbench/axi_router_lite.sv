// AXI4-Lite Router
// Routes transactions from a single AXI4-Lite master to multiple AXI4-Lite slaves
// based on the target address.
//
// This module is used for simulation and emulator only.

module axi_router_lite #(
    parameter int ADDR_WIDTH = 40,
    parameter int DATA_WIDTH = 32
)(
    // Clock and Reset
    input  wire                     aclk,
    input  wire                     aresetn,

    // Single AXI4-Lite Master Interface (Input)
    // This is the master that initiates transactions
    input  wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    input  wire [2:0]               m_axi_awprot,
    input  wire                     m_axi_awvalid,
    output logic                     m_axi_awready,
    
    input  wire [DATA_WIDTH-1:0]    m_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    input  wire                     m_axi_wvalid,
    output logic                     m_axi_wready,
    
    output logic [1:0]               m_axi_bresp,
    output logic                     m_axi_bvalid,
    input  wire                     m_axi_bready,
    
    input  wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    input  wire [2:0]               m_axi_arprot,
    input  wire                     m_axi_arvalid,
    output logic                     m_axi_arready,
    
    output logic [DATA_WIDTH-1:0]    m_axi_rdata,
    output logic [1:0]               m_axi_rresp,
    output logic                     m_axi_rvalid,
    input  wire                     m_axi_rready,

    // Slave 0: tProc (8-bit address, base 0x0000_0000)
    output logic [7:0]               s_tproc_awaddr,
    output logic [2:0]               s_tproc_awprot,
    output logic                     s_tproc_awvalid,
    input  wire                     s_tproc_awready,
    
    output logic [DATA_WIDTH-1:0]    s_tproc_wdata,
    output logic [DATA_WIDTH/8-1:0]  s_tproc_wstrb,
    output logic                     s_tproc_wvalid,
    input  wire                     s_tproc_wready,
    
    input  wire [1:0]               s_tproc_bresp,
    input  wire                     s_tproc_bvalid,
    output logic                     s_tproc_bready,
    
    output logic [7:0]               s_tproc_araddr,
    output logic [2:0]               s_tproc_arprot,
    output logic                     s_tproc_arvalid,
    input  wire                     s_tproc_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_tproc_rdata,
    input  wire [1:0]               s_tproc_rresp,
    input  wire                     s_tproc_rvalid,
    output logic                     s_tproc_rready,

    // Slave 1: Signal Generator (6-bit address, base 0x4000_0000)
    output logic [5:0]               s_sg_awaddr,
    output logic [2:0]               s_sg_awprot,
    output logic                     s_sg_awvalid,
    input  wire                     s_sg_awready,
    
    output logic [DATA_WIDTH-1:0]    s_sg_wdata,
    output logic [DATA_WIDTH/8-1:0]  s_sg_wstrb,
    output logic                     s_sg_wvalid,
    input  wire                     s_sg_wready,
    
    input  wire [1:0]               s_sg_bresp,
    input  wire                     s_sg_bvalid,
    output logic                     s_sg_bready,
    
    output logic [5:0]               s_sg_araddr,
    output logic [2:0]               s_sg_arprot,
    output logic                     s_sg_arvalid,
    input  wire                     s_sg_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_sg_rdata,
    input  wire [1:0]               s_sg_rresp,
    input  wire                     s_sg_rvalid,
    output logic                     s_sg_rready,

    // Slave 2: Average Buffer 0 (6-bit address, base 0x4001_0000)
    output logic [5:0]               s_avg0_awaddr,
    output logic [2:0]               s_avg0_awprot,
    output logic                     s_avg0_awvalid,
    input  wire                     s_avg0_awready,
    
    output logic [DATA_WIDTH-1:0]    s_avg0_wdata,
    output logic [DATA_WIDTH/8-1:0]  s_avg0_wstrb,
    output logic                     s_avg0_wvalid,
    input  wire                     s_avg0_wready,
    
    input  wire [1:0]               s_avg0_bresp,
    input  wire                     s_avg0_bvalid,
    output logic                     s_avg0_bready,
    
    output logic [5:0]               s_avg0_araddr,
    output logic [2:0]               s_avg0_arprot,
    output logic                     s_avg0_arvalid,
    input  wire                     s_avg0_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_avg0_rdata,
    input  wire [1:0]               s_avg0_rresp,
    input  wire                     s_avg0_rvalid,
    output logic                     s_avg0_rready,

    // Slave 3: Readout (6-bit address, base 0x4002_0000)
    output logic [5:0]               s_rov2_awaddr,
    output logic [2:0]               s_rov2_awprot,
    output logic                     s_rov2_awvalid,
    input  wire                     s_rov2_awready,
    
    output logic [DATA_WIDTH-1:0]    s_rov2_wdata,
    output logic [DATA_WIDTH/8-1:0]  s_rov2_wstrb,
    output logic                     s_rov2_wvalid,
    input  wire                     s_rov2_wready,
    
    input  wire [1:0]               s_rov2_bresp,
    input  wire                     s_rov2_bvalid,
    output logic                     s_rov2_bready,
    
    output logic [5:0]               s_rov2_araddr,
    output logic [2:0]               s_rov2_arprot,
    output logic                     s_rov2_arvalid,
    input  wire                     s_rov2_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_rov2_rdata,
    input  wire [1:0]               s_rov2_rresp,
    input  wire                     s_rov2_rvalid,
    output logic                     s_rov2_rready,

    // Slave 4: Average Buffer 1 (6-bit address, base 0x4003_0000)
    output logic [5:0]               s_avg1_awaddr,
    output logic [2:0]               s_avg1_awprot,
    output logic                     s_avg1_awvalid,
    input  wire                     s_avg1_awready,
    
    output logic [DATA_WIDTH-1:0]    s_avg1_wdata,
    output logic [DATA_WIDTH/8-1:0]  s_avg1_wstrb,
    output logic                     s_avg1_wvalid,
    input  wire                     s_avg1_wready,
    
    input  wire [1:0]               s_avg1_bresp,
    input  wire                     s_avg1_bvalid,
    output logic                     s_avg1_bready,
    
    output logic [5:0]               s_avg1_araddr,
    output logic [2:0]               s_avg1_arprot,
    output logic                     s_avg1_arvalid,
    input  wire                     s_avg1_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_avg1_rdata,
    input  wire [1:0]               s_avg1_rresp,
    input  wire                     s_avg1_rvalid,
    output logic                     s_avg1_rready,

    // Output select signals (for debugging/monitoring)
    output logic                     tproc_sel,
    output logic                     sg_sel,
    output logic                     avg0_sel,
    output logic                     rov2_sel,
    output logic                     avg1_sel
);

    // Base addresses for each slave
    localparam logic [ADDR_WIDTH-1:0] BASE_TPROC  = 40'h04_0026_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_SG     = 40'h04_001C_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_SG1    = 40'h04_001D_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_AVG0   = 40'h04_0006_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_AVG1   = 40'h04_0007_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_ROV2   = 40'h04_0008_0000;

    // Address masks for each slave (mask out the address bits that are used for selection)
    localparam logic [ADDR_WIDTH-1:0] MASK_TPROC  = 40'hFF_FFFF_0000;  // 8-bit addr: mask bits 39:8
    localparam logic [ADDR_WIDTH-1:0] MASK_SG     = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    localparam logic [ADDR_WIDTH-1:0] MASK_AVG0   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    localparam logic [ADDR_WIDTH-1:0] MASK_ROV2   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    localparam logic [ADDR_WIDTH-1:0] MASK_AVG1   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14

    // Internal signals for write path
    logic [ADDR_WIDTH-1:0]    write_addr;
    logic [4:0]               write_slave_sel;
    logic [4:0]               write_awready;
    logic [4:0]               write_wready;
    logic [4:0]               write_slave_valid;
    logic [4:0]               write_resp_valid;
    logic [1:0]               write_resp_resp;
    logic [4:0]               write_data_sel;
    
    // Internal signals for read path
    logic [ADDR_WIDTH-1:0]    read_addr;
    logic [4:0]               read_slave_sel;
    logic [4:0]               read_slave_ready;
    logic [4:0]               read_slave_valid;
    logic [4:0]               read_resp_valid;
    logic [DATA_WIDTH-1:0]    read_resp_data;
    logic [1:0]               read_resp_resp;

    // ============================================================================
    // Write Address Channel Routing
    // ============================================================================
    
    // Decode write address to select target slave
    always_comb begin
        write_addr = m_axi_awaddr;
        write_slave_sel = '0;
        write_awready = '0;
        write_slave_valid = '0;
        
        // tProc (base 0x0000_0000, 8-bit addr)
        if ((m_axi_awaddr & MASK_TPROC) == BASE_TPROC) begin
            write_slave_sel[0] = 1'b1;
            write_awready[0] = s_tproc_awready;
            write_slave_valid[0] = m_axi_awvalid & 1'b1;  // Always valid for tProc
        end
        
        // Signal Generator (base 0x4000_0000, 6-bit addr)
        if ((m_axi_awaddr & MASK_SG) == BASE_SG) begin
            write_slave_sel[1] = 1'b1;
            write_awready[1] = s_sg_awready;
            write_slave_valid[1] = m_axi_awvalid & 1'b1;
        end
        
        // Average Buffer 0 (base 0x4001_0000, 6-bit addr)
        if ((m_axi_awaddr & MASK_AVG0) == BASE_AVG0) begin
            write_slave_sel[2] = 1'b1;
            write_awready[2] = s_avg0_awready;
            write_slave_valid[2] = m_axi_awvalid & 1'b1;
        end
        
        // Readout (base 0x4002_0000, 6-bit addr)
        if ((m_axi_awaddr & MASK_ROV2) == BASE_ROV2) begin
            write_slave_sel[3] = 1'b1;
            write_awready[3] = s_rov2_awready;
            write_slave_valid[3] = m_axi_awvalid & 1'b1;
        end
        
        // Average Buffer 1 (base 0x4003_0000, 6-bit addr)
        if ((m_axi_awaddr & MASK_AVG1) == BASE_AVG1) begin
            write_slave_sel[4] = 1'b1;
            write_awready[4] = s_avg1_awready;
            write_slave_valid[4] = m_axi_awvalid & 1'b1;
        end
    end
    
    // Route write address to selected slave
    always_comb begin
        // tProc
        s_tproc_awaddr = m_axi_awaddr[7:0];  // Truncate to 8-bit
        s_tproc_awprot = m_axi_awprot;
        s_tproc_awvalid = m_axi_awvalid & write_slave_sel[0];
        
        // Signal Generator
        s_sg_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_sg_awprot = m_axi_awprot;
        s_sg_awvalid = m_axi_awvalid & write_slave_sel[1];
        
        // Average Buffer 0
        s_avg0_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_avg0_awprot = m_axi_awprot;
        s_avg0_awvalid = m_axi_awvalid & write_slave_sel[2];
        
        // Readout
        s_rov2_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_rov2_awprot = m_axi_awprot;
        s_rov2_awvalid = m_axi_awvalid & write_slave_sel[3];
        
        // Average Buffer 1
        s_avg1_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_avg1_awprot = m_axi_awprot;
        s_avg1_awvalid = m_axi_awvalid & write_slave_sel[4];
    end
    
    // Collect write ready from selected slave
    always_comb begin
        m_axi_awready = 1'b0;
        for (int i = 0; i < 5; i++) begin
            if (write_slave_sel[i]) begin
                m_axi_awready = write_awready[i];
            end
        end
    end

    // Keep write target stable between AW and W phases for single-beat AXI-Lite writes.
    logic [4:0] write_sel_q;
    logic       write_sel_valid_q;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_sel_q       <= '0;
            write_sel_valid_q <= 1'b0;
        end else begin
            // Clear on any accepted W beat. This handles both split AW/W and
            // same-cycle AW+W handshakes without leaving stale selection.
            if (m_axi_wvalid && m_axi_wready) begin
                write_sel_valid_q <= 1'b0;
            end else if (!write_sel_valid_q && m_axi_awvalid && m_axi_awready) begin
                write_sel_q       <= write_slave_sel;
                write_sel_valid_q <= 1'b1;
            end
        end
    end

    always_comb begin
        write_data_sel = write_sel_valid_q ? write_sel_q : write_slave_sel;
    end
    
    // ============================================================================
    // Write Data Channel Routing
    // ============================================================================
    
    // Route write data to selected slave
    always_comb begin
        // tProc
        s_tproc_wdata = m_axi_wdata;
        s_tproc_wstrb = m_axi_wstrb;
        s_tproc_wvalid = m_axi_wvalid & write_data_sel[0];
        
        // Signal Generator
        s_sg_wdata = m_axi_wdata;
        s_sg_wstrb = m_axi_wstrb;
        s_sg_wvalid = m_axi_wvalid & write_data_sel[1];
        
        // Average Buffer 0
        s_avg0_wdata = m_axi_wdata;
        s_avg0_wstrb = m_axi_wstrb;
        s_avg0_wvalid = m_axi_wvalid & write_data_sel[2];
        
        // Readout
        s_rov2_wdata = m_axi_wdata;
        s_rov2_wstrb = m_axi_wstrb;
        s_rov2_wvalid = m_axi_wvalid & write_data_sel[3];
        
        // Average Buffer 1
        s_avg1_wdata = m_axi_wdata;
        s_avg1_wstrb = m_axi_wstrb;
        s_avg1_wvalid = m_axi_wvalid & write_data_sel[4];
    end
    
    // Collect write ready from selected slave
    always_comb begin
        write_wready[0] = s_tproc_wready;
        write_wready[1] = s_sg_wready;
        write_wready[2] = s_avg0_wready;
        write_wready[3] = s_rov2_wready;
        write_wready[4] = s_avg1_wready;

        m_axi_wready = 1'b0;
        for (int i = 0; i < 5; i++) begin
            if (write_data_sel[i]) begin
                m_axi_wready = write_wready[i];
            end
        end
    end
    
    // ============================================================================
    // Write Response Channel Routing
    // ============================================================================
    
    // Collect write responses from all slaves
    always_comb begin
        write_resp_valid = '0;
        write_resp_resp = '0;
        for (int i = 0; i < 5; i++) begin
            case (i)
                0: write_resp_valid[0] = s_tproc_bvalid;
                1: write_resp_valid[1] = s_sg_bvalid;
                2: write_resp_valid[2] = s_avg0_bvalid;
                3: write_resp_valid[3] = s_rov2_bvalid;
                4: write_resp_valid[4] = s_avg1_bvalid;
            endcase
        end
    end
    
    // Route write response from selected slave
    logic [4:0] write_resp_pending;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_resp_pending <= '0;
        end else begin
            // Mark which slave is pending write response after W beat is accepted.
            for (int i = 0; i < 5; i++) begin
                if (write_data_sel[i] && m_axi_wvalid && m_axi_wready) begin
                    write_resp_pending[i] <= 1'b1;
                end else if (write_resp_pending[i] && write_resp_valid[i] && m_axi_bready) begin
                    write_resp_pending[i] <= 1'b0;
                end
            end
        end
    end
    
    // Select response from pending slave
    always_comb begin
        m_axi_bvalid = 1'b0;
        m_axi_bresp = '0;
        for (int i = 0; i < 5; i++) begin
            if (write_resp_pending[i] && write_resp_valid[i]) begin
                m_axi_bvalid = write_resp_valid[i];
                case (i)
                    0: m_axi_bresp = s_tproc_bresp;
                    1: m_axi_bresp = s_sg_bresp;
                    2: m_axi_bresp = s_avg0_bresp;
                    3: m_axi_bresp = s_rov2_bresp;
                    4: m_axi_bresp = s_avg1_bresp;
                endcase
            end
        end
    end
    
    // Route bready to selected slave
    always_comb begin
        // tProc
        s_tproc_bready = m_axi_bready & write_resp_pending[0];
        
        // Signal Generator
        s_sg_bready = m_axi_bready & write_resp_pending[1];
        
        // Average Buffer 0
        s_avg0_bready = m_axi_bready & write_resp_pending[2];
        
        // Readout
        s_rov2_bready = m_axi_bready & write_resp_pending[3];
        
        // Average Buffer 1
        s_avg1_bready = m_axi_bready & write_resp_pending[4];
    end
    
    // ============================================================================
    // Read Address Channel Routing
    // ============================================================================
    
    // Decode read address to select target slave
    always_comb begin
        read_addr = m_axi_araddr;
        read_slave_sel = '0;
        read_slave_ready = '0;
        read_slave_valid = '0;
        
        // tProc (base 0x0000_0000, 8-bit addr)
        if ((m_axi_araddr & MASK_TPROC) == BASE_TPROC) begin
            read_slave_sel[0] = 1'b1;
            read_slave_ready[0] = s_tproc_arready;
            read_slave_valid[0] = m_axi_arvalid & 1'b1;  // Always valid for tProc
        end
        
        // Signal Generator (base 0x4000_0000, 6-bit addr)
        if ((m_axi_araddr & MASK_SG) == BASE_SG) begin
            read_slave_sel[1] = 1'b1;
            read_slave_ready[1] = s_sg_arready;
            read_slave_valid[1] = m_axi_arvalid & 1'b1;
        end
        
        // Average Buffer 0 (base 0x4001_0000, 6-bit addr)
        if ((m_axi_araddr & MASK_AVG0) == BASE_AVG0) begin
            read_slave_sel[2] = 1'b1;
            read_slave_ready[2] = s_avg0_arready;
            read_slave_valid[2] = m_axi_arvalid & 1'b1;
        end
        
        // Readout (base 0x4002_0000, 6-bit addr)
        if ((m_axi_araddr & MASK_ROV2) == BASE_ROV2) begin
            read_slave_sel[3] = 1'b1;
            read_slave_ready[3] = s_rov2_arready;
            read_slave_valid[3] = m_axi_arvalid & 1'b1;
        end
        
        // Average Buffer 1 (base 0x4003_0000, 6-bit addr)
        if ((m_axi_araddr & MASK_AVG1) == BASE_AVG1) begin
            read_slave_sel[4] = 1'b1;
            read_slave_ready[4] = s_avg1_arready;
            read_slave_valid[4] = m_axi_arvalid & 1'b1;
        end
    end
    
    // Route read address to selected slave
    always_comb begin
        // tProc
        s_tproc_araddr = m_axi_araddr[7:0];  // Truncate to 8-bit
        s_tproc_arprot = m_axi_arprot;
        s_tproc_arvalid = m_axi_arvalid & read_slave_sel[0];
        
        // Signal Generator
        s_sg_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_sg_arprot = m_axi_arprot;
        s_sg_arvalid = m_axi_arvalid & read_slave_sel[1];
        
        // Average Buffer 0
        s_avg0_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_avg0_arprot = m_axi_arprot;
        s_avg0_arvalid = m_axi_arvalid & read_slave_sel[2];
        
        // Readout
        s_rov2_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_rov2_arprot = m_axi_arprot;
        s_rov2_arvalid = m_axi_arvalid & read_slave_sel[3];
        
        // Average Buffer 1
        s_avg1_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_avg1_arprot = m_axi_arprot;
        s_avg1_arvalid = m_axi_arvalid & read_slave_sel[4];
    end
    
    // Collect read ready from selected slave
    always_comb begin
        m_axi_arready = 1'b0;
        for (int i = 0; i < 5; i++) begin
            if (read_slave_sel[i]) begin
                m_axi_arready = read_slave_ready[i];
            end
        end
    end
    
    // ============================================================================
    // Read Data Channel Routing
    // ============================================================================
    
    // Collect read responses from all slaves
    always_comb begin
        read_resp_valid = '0;
        read_resp_data = '0;
        read_resp_resp = '0;
        for (int i = 0; i < 5; i++) begin
            case (i)
                0: read_resp_valid[0] = s_tproc_rvalid;
                1: read_resp_valid[1] = s_sg_rvalid;
                2: read_resp_valid[2] = s_avg0_rvalid;
                3: read_resp_valid[3] = s_rov2_rvalid;
                4: read_resp_valid[4] = s_avg1_rvalid;
            endcase
        end
    end
    
    // Route read response from selected slave
    logic [4:0] read_resp_pending;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            read_resp_pending <= '0;
        end else begin
            // Mark which slave is pending response
            for (int i = 0; i < 5; i++) begin
                if (read_slave_sel[i] && m_axi_arvalid && m_axi_arready) begin
                    read_resp_pending[i] <= 1'b1;
                end else if (read_resp_pending[i] && read_resp_valid[i] && m_axi_rready) begin
                    read_resp_pending[i] <= 1'b0;
                end
            end
        end
    end
    
    // Select response from pending slave
    always_comb begin
        m_axi_rvalid = 1'b0;
        m_axi_rdata = '0;
        m_axi_rresp = '0;
        for (int i = 0; i < 5; i++) begin
            if (read_resp_pending[i] && read_resp_valid[i]) begin
                m_axi_rvalid = read_resp_valid[i];
                case (i)
                    0: begin
                        m_axi_rdata = s_tproc_rdata;
                        m_axi_rresp = s_tproc_rresp;
                    end
                    1: begin
                        m_axi_rdata = s_sg_rdata;
                        m_axi_rresp = s_sg_rresp;
                    end
                    2: begin
                        m_axi_rdata = s_avg0_rdata;
                        m_axi_rresp = s_avg0_rresp;
                    end
                    3: begin
                        m_axi_rdata = s_rov2_rdata;
                        m_axi_rresp = s_rov2_rresp;
                    end
                    4: begin
                        m_axi_rdata = s_avg1_rdata;
                        m_axi_rresp = s_avg1_rresp;
                    end
                endcase
            end
        end
    end
    
    // Route rready to selected slave
    always_comb begin
        // tProc
        s_tproc_rready = m_axi_rready & read_resp_pending[0];
        
        // Signal Generator
        s_sg_rready = m_axi_rready & read_resp_pending[1];
        
        // Average Buffer 0
        s_avg0_rready = m_axi_rready & read_resp_pending[2];
        
        // Readout
        s_rov2_rready = m_axi_rready & read_resp_pending[3];
        
        // Average Buffer 1
        s_avg1_rready = m_axi_rready & read_resp_pending[4];
    end

    // Assign select signals for debugging/monitoring
    assign tproc_sel = write_slave_sel[0] | read_slave_sel[0];
    assign sg_sel = write_slave_sel[1] | read_slave_sel[1];
    assign avg0_sel = write_slave_sel[2] | read_slave_sel[2];
    assign rov2_sel = write_slave_sel[3] | read_slave_sel[3];
    assign avg1_sel = write_slave_sel[4] | read_slave_sel[4];

endmodule