module axi_slv_avg_buf_sv_sva;
    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 6;

// shared 1-bit logic signals
logic aclk;
logic aresetn;
logic awvalid;
logic wvalid;
logic bready;
logic arvalid;
logic rready;

// n-bit shared inputs
logic [ADDR_WIDTH-1:0] awaddr;
logic [2:0] awprot;
logic [DATA_WIDTH-1:0] wdata;
logic [(DATA_WIDTH/8)-1:0] wstrb;
logic [ADDR_WIDTH-1:0] araddr;
logic [2:0] arprot;

// sv outputs
logic awready_sv;
logic wready_sv;
logic [1:0] bresp_sv;
logic bvalid_sv;
logic arready_sv;
logic [DATA_WIDTH-1:0] rdata_sv;
logic [1:0] rresp_sv;
logic rvalid_sv;
logic                         AVG_START_REG_sv;
logic [31:0]                  AVG_ADDR_REG_sv;
logic [31:0]                  AVG_LEN_REG_sv;
logic                         AVG_PHOTON_MODE_REG_sv;
logic [31:0]                  AVG_H_THRSH_REG_sv;
logic [31:0]                  AVG_L_THRSH_REG_sv;
logic                         AVG_DR_START_REG_sv;
logic [31:0]                  AVG_DR_ADDR_REG_sv;
logic [31:0]                  AVG_DR_LEN_REG_sv;
logic                         BUF_START_REG_sv;
logic [31:0]                  BUF_ADDR_REG_sv;
logic [31:0]                  BUF_LEN_REG_sv;
logic                         BUF_DR_START_REG_sv;
logic [31:0]                  BUF_DR_ADDR_REG_sv;
logic [31:0]                  BUF_DR_LEN_REG_sv;

// vhdl outputs
logic awready_vhd;
logic wready_vhd;
logic [1:0] bresp_vhd;
logic bvalid_vhd;
logic arready_vhd;
logic [DATA_WIDTH-1:0] rdata_vhd;
logic [1:0] rresp_vhd;
logic rvalid_vhd;
logic                         AVG_START_REG_vhd;
logic [31:0]                  AVG_ADDR_REG_vhd;
logic [31:0]                  AVG_LEN_REG_vhd;
logic                         AVG_PHOTON_MODE_REG_vhd;
logic [31:0]                  AVG_H_THRSH_REG_vhd;
logic [31:0]                  AVG_L_THRSH_REG_vhd;
logic                         AVG_DR_START_REG_vhd;
logic [31:0]                  AVG_DR_ADDR_REG_vhd;
logic [31:0]                  AVG_DR_LEN_REG_vhd;
logic                         BUF_START_REG_vhd;
logic [31:0]                  BUF_ADDR_REG_vhd;
logic [31:0]                  BUF_LEN_REG_vhd;
logic                         BUF_DR_START_REG_vhd;
logic [31:0]                  BUF_DR_ADDR_REG_vhd;
logic [31:0]                  BUF_DR_LEN_REG_vhd;

axi_slv_avg_buf_sv #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(6)
    ) dut (
    .aclk(aclk),
    .aresetn(aresetn),

    // Write Address Channel
    .awaddr(awaddr),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready_sv),

    // Write Data Channel
    .wdata(wdata),
    .wstrb(wstrb),
    .wvalid(wvalid),
    .wready(wready_sv),

    // Write Response Channel
    .bresp(bresp_sv),
    .bvalid(bvalid_sv),
    .bready(bready),

    // Read Address Channel
    .araddr(araddr),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready_sv),

    // Read Data Channel
    .rdata(rdata_sv),
    .rresp(rresp_sv),
    .rvalid(rvalid_sv),
    .rready(rready),

    // User Registers
    .AVG_START_REG(AVG_START_REG_sv),
    .AVG_ADDR_REG(AVG_ADDR_REG_sv),
    .AVG_LEN_REG(AVG_LEN_REG_sv),
    .AVG_PHOTON_MODE_REG(AVG_PHOTON_MODE_REG_sv),
    .AVG_H_THRSH_REG(AVG_H_THRSH_REG_sv),
    .AVG_L_THRSH_REG(AVG_L_THRSH_REG_sv),
    .AVG_DR_START_REG(AVG_DR_START_REG_sv),
    .AVG_DR_ADDR_REG(AVG_DR_ADDR_REG_sv),
    .AVG_DR_LEN_REG(AVG_DR_LEN_REG_sv),
    .BUF_START_REG(BUF_START_REG_sv),
    .BUF_ADDR_REG(BUF_ADDR_REG_sv),
    .BUF_LEN_REG(BUF_LEN_REG_sv),
    .BUF_DR_START_REG(BUF_DR_START_REG_sv),
    .BUF_DR_ADDR_REG(BUF_DR_ADDR_REG_sv),
    .BUF_DR_LEN_REG(BUF_DR_LEN_REG_sv)
);

axi_slv_avg_buf ref (
    .aclk(aclk),
    .aresetn(aresetn),

    // Write Address Channel
    .awaddr(awaddr),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready_vhd),

    // Write Data Channel
    .wdata(wdata),
    .wstrb(wstrb),
    .wvalid(wvalid),
    .wready(wready_vhd),

    // Write Response Channel
    .bresp(bresp_vhd),
    .bvalid(bvalid_vhd),
    .bready(bready),

    // Read Address Channel
    .araddr(araddr),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready_vhd),

    // Read Data Channel
    .rdata(rdata_vhd),
    .rresp(rresp_vhd),
    .rvalid(rvalid_vhd),
    .rready(rready),

    // User Registers
    .AVG_START_REG(AVG_START_REG_vhd),
    .AVG_ADDR_REG(AVG_ADDR_REG_vhd),
    .AVG_LEN_REG(AVG_LEN_REG_vhd),
    .AVG_PHOTON_MODE_REG(AVG_PHOTON_MODE_REG_vhd),
    .AVG_H_THRSH_REG(AVG_H_THRSH_REG_vhd),
    .AVG_L_THRSH_REG(AVG_L_THRSH_REG_vhd),
    .AVG_DR_START_REG(AVG_DR_START_REG_vhd),
    .AVG_DR_ADDR_REG(AVG_DR_ADDR_REG_vhd),
    .AVG_DR_LEN_REG(AVG_DR_LEN_REG_vhd),
    .BUF_START_REG(BUF_START_REG_vhd),
    .BUF_ADDR_REG(BUF_ADDR_REG_vhd),
    .BUF_LEN_REG(BUF_LEN_REG_vhd),
    .BUF_DR_START_REG(BUF_DR_START_REG_vhd),
    .BUF_DR_ADDR_REG(BUF_DR_ADDR_REG_vhd),
    .BUF_DR_LEN_REG(BUF_DR_LEN_REG_vhd)
);

    // assume statements
always @(posedge aclk) begin
    if ($initstate) begin
        assume(!aresetn);
    end
end

    // assert statements
    always @(posedge aclk) begin 
        if ((aresetn == 1) && (rvalid_sv == 1) && (rvalid_vhd == 1) && (rready == 1)) begin 
            assert (awready_sv === awready_vhd);
            assert (wready_sv === wready_vhd);
            assert (bresp_sv === bresp_vhd);
            assert (arready_sv == arready_vhd);
            assert (bvalid_sv === bvalid_vhd);
            assert (rdata_sv === rdata_vhd);
            assert (rresp_sv === rresp_vhd);
            assert (rvalid_sv === rvalid_vhd);
            assert (AVG_START_REG_sv == AVG_START_REG_vhd);
            assert (AVG_ADDR_REG_sv === AVG_ADDR_REG_vhd);
            assert (AVG_LEN_REG_sv === AVG_LEN_REG_vhd);
            assert (AVG_PHOTON_MODE_REG_sv === AVG_PHOTON_MODE_REG_vhd);
            assert (AVG_H_THRSH_REG_sv === AVG_H_THRSH_REG_vhd);
            assert (AVG_L_THRSH_REG_sv === AVG_L_THRSH_REG_vhd);
            assert (AVG_DR_START_REG_sv === AVG_DR_START_REG_vhd);
            assert (AVG_DR_ADDR_REG_sv === AVG_DR_ADDR_REG_vhd);
            assert (AVG_DR_LEN_REG_sv === AVG_DR_LEN_REG_vhd);
            assert (BUF_START_REG_sv === BUF_START_REG_vhd);
            assert (BUF_ADDR_REG_sv === BUF_ADDR_REG_vhd);
            assert (BUF_LEN_REG_sv === BUF_LEN_REG_vhd);
            assert (BUF_DR_START_REG_sv === BUF_DR_START_REG_vhd);
            assert (BUF_DR_ADDR_REG_sv === BUF_DR_ADDR_REG_vhd);
            assert (BUF_DR_LEN_REG_sv === BUF_DR_LEN_REG_vhd);
        end
    end


endmodule