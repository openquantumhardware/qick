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

    // Slave 0: tProc (8-bit address, base 0x0000_0000)
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

    // Slave 1: Signal Generator (6-bit address, base 0x4000_0000)
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

    // Slave 2: Average Buffer 0 (6-bit address, base 0x4001_0000)
    output logic [5:0]              s_avg0_awaddr,
    output logic [2:0]              s_avg0_awprot,
    output logic                    s_avg0_awvalid,
    input  wire                     s_avg0_awready,
    
    output logic [DATA_WIDTH-1:0]   s_avg0_wdata,
    output logic [DATA_WIDTH/8-1:0] s_avg0_wstrb,
    output logic                    s_avg0_wvalid,
    input  wire                     s_avg0_wready,
    
    input  wire [1:0]               s_avg0_bresp,
    input  wire                     s_avg0_bvalid,
    output logic                    s_avg0_bready,
    
    output logic [5:0]              s_avg0_araddr,
    output logic [2:0]              s_avg0_arprot,
    output logic                    s_avg0_arvalid,
    input  wire                     s_avg0_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_avg0_rdata,
    input  wire [1:0]               s_avg0_rresp,
    input  wire                     s_avg0_rvalid,
    output logic                    s_avg0_rready,

    // Slave 3: Readout (6-bit address, base 0x4002_0000)
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

    // Slave 4: Average Buffer 1 (6-bit address, base 0x4003_0000)
    output logic [5:0]              s_avg1_awaddr,
    output logic [2:0]              s_avg1_awprot,
    output logic                    s_avg1_awvalid,
    input  wire                     s_avg1_awready,
    
    output logic [DATA_WIDTH-1:0]   s_avg1_wdata,
    output logic [DATA_WIDTH/8-1:0] s_avg1_wstrb,
    output logic                    s_avg1_wvalid,
    input  wire                     s_avg1_wready,
    
    input  wire [1:0]               s_avg1_bresp,
    input  wire                     s_avg1_bvalid,
    output logic                    s_avg1_bready,
    
    output logic [5:0]              s_avg1_araddr,
    output logic [2:0]              s_avg1_arprot,
    output logic                    s_avg1_arvalid,
    input  wire                     s_avg1_arready,
    
    input  wire [DATA_WIDTH-1:0]    s_avg1_rdata,
    input  wire [1:0]               s_avg1_rresp,
    input  wire                     s_avg1_rvalid,
    output logic                    s_avg1_rready,

    // Slave 5: Signal Generator 1 (6-bit address, base 0x4001_D000)
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

    // Slave 6: Signal Generator 2 (mux8, 8-bit address, base 0x4001_E000)
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

    // Output select signals (for debugging/monitoring)
    output logic                    tproc_sel,
    output logic                    sg0_sel,
    output logic                    sg1_sel,
    output logic                    sg2_sel,
    output logic                    avg0_sel,
    output logic                    rov2_sel,
    output logic                    avg1_sel
);


    // Base addresses for each slave
    localparam logic [ADDR_WIDTH-1:0] BASE_TPROC  = 40'h04_0026_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_BUF0   = 40'h04_0006_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_BUF1   = 40'h04_0007_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_ROV2   = 40'h04_0008_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_SG0    = 40'h04_001C_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_SG1    = 40'h04_001D_0000;
    localparam logic [ADDR_WIDTH-1:0] BASE_SG2    = 40'h04_001F_0000;  // mux8 config; distinct from harness SG1_BASE(0x1E)



    // // Address masks for each slave (mask out the address bits that are used for selection)
    // localparam logic [ADDR_WIDTH-1:0] MASK_TPROC  = 40'hFF_FFFF_0000;  // 8-bit addr: mask bits 39:8
    // localparam logic [ADDR_WIDTH-1:0] MASK_BUF0   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    // localparam logic [ADDR_WIDTH-1:0] MASK_BUF1   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    // localparam logic [ADDR_WIDTH-1:0] MASK_ROV2   = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    // localparam logic [ADDR_WIDTH-1:0] MASK_SG0    = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    // localparam logic [ADDR_WIDTH-1:0] MASK_SG1    = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14
    // localparam logic [ADDR_WIDTH-1:0] MASK_SG2    = 40'hFF_FFFF_0000;  // 6-bit addr: mask bits 39:14

    // Internal signals for write path
    logic [ADDR_WIDTH-1:0]    write_addr;
    logic [6:0]               write_slave_sel;
    logic [6:0]               write_awready;
    logic [6:0]               write_wready;
    logic [6:0]               write_slave_valid;
    logic [6:0]               write_resp_valid;
    logic [1:0]               write_resp_resp;
    logic [6:0]               write_data_sel;
    
    // Internal signals for read path
    logic [ADDR_WIDTH-1:0]    read_addr;
    logic [6:0]               read_slave_sel;
    logic [6:0]               read_slave_ready;
    logic [6:0]               read_slave_valid;
    logic [6:0]               read_resp_valid;
    logic [DATA_WIDTH-1:0]    read_resp_data;
    logic [1:0]               read_resp_resp;

    function automatic logic [6:0] decode_slave_sel(
        input logic [ADDR_WIDTH-1:0] addr
    );
        logic [6:0] sel;
        begin
            sel = '0;
            unique case (addr[39:16])
                BASE_TPROC[39:16]: sel[0] = 1'b1;
                BASE_SG0[39:16]:   sel[1] = 1'b1;
                BASE_SG1[39:16]:   sel[5] = 1'b1;
                BASE_SG2[39:16]:   sel[6] = 1'b1;

                BASE_BUF0[39:16]:  sel[2] = 1'b1;
                BASE_BUF1[39:16]:  sel[4] = 1'b1;
                BASE_ROV2[39:16]:  sel[3] = 1'b1;
                default: sel = '0;
            endcase
            return sel;
        end
    endfunction


    // ============================================================================
    // Write Address Channel Routing
    // ============================================================================
    
    // Decode write address to select target slave
    always_comb begin
        write_addr = m_axi_awaddr;
        write_slave_sel = decode_slave_sel(m_axi_awaddr);
        write_awready = '0;
        write_slave_valid = '0;

        write_awready[0] = s_tproc_awready;
        write_awready[1] = s_sg0_awready;
        write_awready[2] = s_avg0_awready;
        write_awready[3] = s_rov2_awready;
        write_awready[4] = s_avg1_awready;
        write_awready[5] = s_sg1_awready;
        write_awready[6] = s_sg2_awready;

        write_slave_valid = {7{m_axi_awvalid}} & write_slave_sel;
    end

    
    // Route write address to selected slave
    always_comb begin
        // tProc
        s_tproc_awaddr = m_axi_awaddr[7:0];  // Truncate to 8-bit
        s_tproc_awprot = m_axi_awprot;
        s_tproc_awvalid = write_slave_sel[0] & m_axi_awvalid;
        
        // Signal Generator
        s_sg0_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_sg0_awprot = m_axi_awprot;
        s_sg0_awvalid = m_axi_awvalid & write_slave_sel[1];
        
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
        
        // Signal Generator 1
        s_sg1_awaddr = m_axi_awaddr[5:0];  // Truncate to 6-bit
        s_sg1_awprot = m_axi_awprot;
        s_sg1_awvalid = write_slave_sel[5] & m_axi_awvalid;
        
        // Signal Generator 2 (mux8)
        s_sg2_awaddr = m_axi_awaddr[7:0];  // Truncate to 8-bit
        s_sg2_awprot = m_axi_awprot;
        s_sg2_awvalid = write_slave_sel[6] & m_axi_awvalid;
    end
    
    // Collect write ready from selected slave
    always_comb begin
        m_axi_awready = 1'b0;
        if (write_slave_sel[0]) m_axi_awready = write_awready[0];
        else if (write_slave_sel[1]) m_axi_awready = write_awready[1];
        else if (write_slave_sel[2]) m_axi_awready = write_awready[2];
        else if (write_slave_sel[3]) m_axi_awready = write_awready[3];
        else if (write_slave_sel[4]) m_axi_awready = write_awready[4];
        else if (write_slave_sel[5]) m_axi_awready = write_awready[5];
        else if (write_slave_sel[6]) m_axi_awready = write_awready[6];
    end
    
    // Keep write target stable between AW and W phases for single-beat AXI-Lite writes.
    logic [6:0] write_sel_q;

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
        write_data_sel = write_sel_valid_q ? write_sel_q : decode_slave_sel(m_axi_awaddr);
    end
    
    // ============================================================================
    // Write Data Channel Routing
    // ============================================================================
    
    // Route write data to selected slave
    always_comb begin
        // tProc
        s_tproc_wdata = m_axi_wdata;
        s_tproc_wstrb = m_axi_wstrb;
        s_tproc_wvalid = write_data_sel[0] & m_axi_wvalid;
        
        // Signal Generator
        s_sg0_wdata = m_axi_wdata;
        s_sg0_wstrb = m_axi_wstrb;
        s_sg0_wvalid = write_data_sel[1] & m_axi_wvalid;
        
        // Average Buffer 0
        s_avg0_wdata = m_axi_wdata;
        s_avg0_wstrb = m_axi_wstrb;
        s_avg0_wvalid = write_data_sel[2] & m_axi_wvalid;
        
        // Readout
        s_rov2_wdata = m_axi_wdata;
        s_rov2_wstrb = m_axi_wstrb;
        s_rov2_wvalid = write_data_sel[3] & m_axi_wvalid;
        
        // Average Buffer 1
        s_avg1_wdata = m_axi_wdata;
        s_avg1_wstrb = m_axi_wstrb;
        s_avg1_wvalid = write_data_sel[4] & m_axi_wvalid;
        
        // Signal Generator 1
        s_sg1_wdata = m_axi_wdata;
        s_sg1_wstrb = m_axi_wstrb;
        s_sg1_wvalid = write_data_sel[5] & m_axi_wvalid;
        
        // Signal Generator 2 (mux8)
        s_sg2_wdata = m_axi_wdata;
        s_sg2_wstrb = m_axi_wstrb;
        s_sg2_wvalid = write_data_sel[6] & m_axi_wvalid;
    end
    
    // Collect write ready from selected slave
    always_comb begin
        write_wready[0] = s_tproc_wready;
        write_wready[1] = s_sg0_wready;
        write_wready[2] = s_avg0_wready;
        write_wready[3] = s_rov2_wready;
        write_wready[4] = s_avg1_wready;
        write_wready[5] = s_sg1_wready;
        write_wready[6] = s_sg2_wready;

        m_axi_wready = 1'b0;
        if (write_data_sel[0]) m_axi_wready = write_wready[0];
        else if (write_data_sel[1]) m_axi_wready = write_wready[1];
        else if (write_data_sel[2]) m_axi_wready = write_wready[2];
        else if (write_data_sel[3]) m_axi_wready = write_wready[3];
        else if (write_data_sel[4]) m_axi_wready = write_wready[4];
        else if (write_data_sel[5]) m_axi_wready = write_wready[5];
        else if (write_data_sel[6]) m_axi_wready = write_wready[6];
    end

    
    // ============================================================================
    // Write Response Channel Routing
    // ============================================================================
    
    // Collect write responses from all slaves
    always_comb begin
        write_resp_valid = '0;
        write_resp_resp = '0;
        write_resp_valid[0] = s_tproc_bvalid;
        write_resp_valid[1] = s_sg0_bvalid;
        write_resp_valid[2] = s_avg0_bvalid;
        write_resp_valid[3] = s_rov2_bvalid;
        write_resp_valid[4] = s_avg1_bvalid;
        write_resp_valid[5] = s_sg1_bvalid;
        write_resp_valid[6] = s_sg2_bvalid;
    end
    
    // Route write response from selected slave
    logic [6:0] write_resp_pending;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_resp_pending <= '0;
        end else begin
            // Mark which slave is pending write response after W beat is accepted.
            for (int i = 0; i < 7; i++) begin

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
        if (write_resp_pending[0] && write_resp_valid[0]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_tproc_bresp;
        end else if (write_resp_pending[1] && write_resp_valid[1]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_sg0_bresp;
        end else if (write_resp_pending[2] && write_resp_valid[2]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_avg0_bresp;
        end else if (write_resp_pending[3] && write_resp_valid[3]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_rov2_bresp;
        end else if (write_resp_pending[4] && write_resp_valid[4]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_avg1_bresp;
        end else if (write_resp_pending[5] && write_resp_valid[5]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_sg1_bresp;
        end else if (write_resp_pending[6] && write_resp_valid[6]) begin
            m_axi_bvalid = 1'b1;
            m_axi_bresp = s_sg2_bresp;
        end
    end
    
    // Route bready to selected slave
    always_comb begin
        // tProc
        s_tproc_bready = m_axi_bready & write_resp_pending[0];
        
        // Signal Generator
        s_sg0_bready = m_axi_bready & write_resp_pending[1];
        
        // Average Buffer 0
        s_avg0_bready = m_axi_bready & write_resp_pending[2];
        
        // Readout
        s_rov2_bready = m_axi_bready & write_resp_pending[3];
        
        // Average Buffer 1
        s_avg1_bready = m_axi_bready & write_resp_pending[4];
        
        // Signal Generator 1
        s_sg1_bready = m_axi_bready & write_resp_pending[5];
        
        // Signal Generator 2 (mux8)
        s_sg2_bready = m_axi_bready & write_resp_pending[6];
    end

    
    // ============================================================================
    // Read Address Channel Routing
    // ============================================================================
    
    // Decode read address to select target slave
    always_comb begin
        read_addr = m_axi_araddr;
        read_slave_sel = decode_slave_sel(m_axi_araddr);
        read_slave_ready = '0;
        read_slave_valid = '0;

        read_slave_ready[0] = s_tproc_arready;
        read_slave_ready[1] = s_sg0_arready;
        read_slave_ready[2] = s_avg0_arready;
        read_slave_ready[3] = s_rov2_arready;
        read_slave_ready[4] = s_avg1_arready;
        read_slave_ready[5] = s_sg1_arready;
        read_slave_ready[6] = s_sg2_arready;

        read_slave_valid = {7{m_axi_arvalid}} & read_slave_sel;
    end

    
    // Route read address to selected slave
    always_comb begin
        // tProc
        s_tproc_araddr = m_axi_araddr[7:0];  // Truncate to 8-bit
        s_tproc_arprot = m_axi_arprot;
        s_tproc_arvalid = read_slave_sel[0] & m_axi_arvalid;
        
        // Signal Generator
        s_sg0_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_sg0_arprot = m_axi_arprot;
        s_sg0_arvalid = m_axi_arvalid & read_slave_sel[1];
        
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
        
        // Signal Generator 1
        s_sg1_araddr = m_axi_araddr[5:0];  // Truncate to 6-bit
        s_sg1_arprot = m_axi_arprot;
        s_sg1_arvalid = read_slave_sel[5] & m_axi_arvalid;
        
        // Signal Generator 2 (mux8)
        s_sg2_araddr = m_axi_araddr[7:0];  // Truncate to 8-bit
        s_sg2_arprot = m_axi_arprot;
        s_sg2_arvalid = read_slave_sel[6] & m_axi_arvalid;
    end
    
    // Collect read ready from selected slave
    always_comb begin
        m_axi_arready = 1'b0;
        if (read_slave_sel[0]) m_axi_arready = read_slave_ready[0];
        else if (read_slave_sel[1]) m_axi_arready = read_slave_ready[1];
        else if (read_slave_sel[2]) m_axi_arready = read_slave_ready[2];
        else if (read_slave_sel[3]) m_axi_arready = read_slave_ready[3];
        else if (read_slave_sel[4]) m_axi_arready = read_slave_ready[4];
        else if (read_slave_sel[5]) m_axi_arready = read_slave_ready[5];
        else if (read_slave_sel[6]) m_axi_arready = read_slave_ready[6];
    end

    
    // ============================================================================
    // Read Data Channel Routing
    // ============================================================================
    
    // Collect read responses from all slaves
    always_comb begin
        read_resp_valid = '0;
        read_resp_data = '0;
        read_resp_resp = '0;
        read_resp_valid[0] = s_tproc_rvalid;
        read_resp_valid[1] = s_sg0_rvalid;
        read_resp_valid[2] = s_avg0_rvalid;
        read_resp_valid[3] = s_rov2_rvalid;
        read_resp_valid[4] = s_avg1_rvalid;
        read_resp_valid[5] = s_sg1_rvalid;
        read_resp_valid[6] = s_sg2_rvalid;
    end
    
    // Route read response from selected slave
    logic [6:0] read_resp_pending;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            read_resp_pending <= '0;
        end else begin
            // Mark which slave is pending response
            for (int i = 0; i < 7; i++) begin

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
        if (read_resp_pending[0] && read_resp_valid[0]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_tproc_rdata;
            m_axi_rresp = s_tproc_rresp;
        end else if (read_resp_pending[1] && read_resp_valid[1]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_sg0_rdata;
            m_axi_rresp = s_sg0_rresp;
        end else if (read_resp_pending[2] && read_resp_valid[2]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_avg0_rdata;
            m_axi_rresp = s_avg0_rresp;
        end else if (read_resp_pending[3] && read_resp_valid[3]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_rov2_rdata;
            m_axi_rresp = s_rov2_rresp;
        end else if (read_resp_pending[4] && read_resp_valid[4]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_avg1_rdata;
            m_axi_rresp = s_avg1_rresp;
        end else if (read_resp_pending[5] && read_resp_valid[5]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_sg1_rdata;
            m_axi_rresp = s_sg1_rresp;
        end else if (read_resp_pending[6] && read_resp_valid[6]) begin
            m_axi_rvalid = 1'b1;
            m_axi_rdata = s_sg2_rdata;
            m_axi_rresp = s_sg2_rresp;
        end
    end
    
    // Route rready to selected slave
    always_comb begin
        // tProc
        s_tproc_rready = m_axi_rready & read_resp_pending[0];
        
        // Signal Generator
        s_sg0_rready = m_axi_rready & read_resp_pending[1];
        
        // Average Buffer 0
        s_avg0_rready = m_axi_rready & read_resp_pending[2];
        
        // Readout
        s_rov2_rready = m_axi_rready & read_resp_pending[3];
        
        // Average Buffer 1
        s_avg1_rready = m_axi_rready & read_resp_pending[4];
        
        // Signal Generator 1
        s_sg1_rready = m_axi_rready & read_resp_pending[5];
        
        // Signal Generator 2 (mux8)
        s_sg2_rready = m_axi_rready & read_resp_pending[6];
    end

    // Assign select signals for debugging/monitoring
    assign tproc_sel = write_slave_sel[0] | read_slave_sel[0];
    assign sg0_sel = write_slave_sel[1] | read_slave_sel[1];
    assign sg1_sel = write_slave_sel[5] | read_slave_sel[5];
    assign sg2_sel = write_slave_sel[6] | read_slave_sel[6];

    assign avg0_sel = write_slave_sel[2] | read_slave_sel[2];
    assign rov2_sel = write_slave_sel[3] | read_slave_sel[3];
    assign avg1_sel = write_slave_sel[4] | read_slave_sel[4];

endmodule