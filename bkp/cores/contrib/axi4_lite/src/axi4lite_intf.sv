interface axi4lite_intf
    #(
        parameter DATA_WIDTH = 32,
        parameter ADDR_WIDTH = 32
    )
    (
        input logic i_clk,
        input logic i_rst
    );

    generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_check_data_width
        $fatal(1, "The AXI4-Lite data bus width must be 32 or 64 bits wide (%0d not supported).", DATA_WIDTH);
    end
    endgenerate

    logic                       AWREADY;
    logic                       AWVALID;
    logic [ADDR_WIDTH-1:0]      AWADDR;
    logic [2:0]                 AWPROT;

    logic                       WREADY;
    logic                       WVALID;
    logic [DATA_WIDTH-1:0]      WDATA;
    logic [DATA_WIDTH/8-1:0]    WSTRB;

    logic                       BREADY;
    logic                       BVALID;
    logic [1:0]                 BRESP;

    logic                       ARREADY;
    logic                       ARVALID;
    logic [ADDR_WIDTH-1:0]      ARADDR;
    logic [2:0]                 ARPROT;

    logic                       RREADY;
    logic                       RVALID;
    logic [DATA_WIDTH-1:0]      RDATA;
    logic [1:0]                 RRESP;

    modport master (
        input  AWREADY,
        output AWVALID,
        output AWADDR,
        output AWPROT,

        input  WREADY,
        output WVALID,
        output WDATA,
        output WSTRB,

        output BREADY,
        input  BVALID,
        input  BRESP,

        input  ARREADY,
        output ARVALID,
        output ARADDR,
        output ARPROT,

        output RREADY,
        input  RVALID,
        input  RDATA,
        input  RRESP
    );

    modport slave (
        output AWREADY,
        input  AWVALID,
        input  AWADDR,
        input  AWPROT,

        output WREADY,
        input  WVALID,
        input  WDATA,
        input  WSTRB,

        input  BREADY,
        output BVALID,
        output BRESP,

        output ARREADY,
        input  ARVALID,
        input  ARADDR,
        input  ARPROT,

        input  RREADY,
        output RVALID,
        output RDATA,
        output RRESP
    );

    // ASSERTIONS
    `ifdef SYNTHESIS
        `elsif VERILATOR
    `else

        modport tb_master(clocking m_cb);
        modport tb_slave(clocking s_cb);

        clocking m_cb @(posedge i_clk);
            default input #1step output #2;

            input  AWREADY;
            output AWVALID;
            output AWADDR;
            output AWPROT;

            input  WREADY;
            output WVALID;
            output WDATA;
            output WSTRB;

            output BREADY;
            input  BVALID;
            input  BRESP;

            input  ARREADY;
            output ARVALID;
            output ARADDR;
            output ARPROT;

            output RREADY;
            input  RVALID;
            input  RDATA;
            input  RRESP;
        endclocking

        clocking s_cb @(posedge i_clk);

            default input #1step output #2;

            output AWREADY;
            input  AWVALID;
            input  AWADDR;
            input  AWPROT;

            output WREADY;
            input  WVALID;
            input  WDATA;
            input  WSTRB;

            input  BREADY;
            output BVALID;
            output BRESP;

            output ARREADY;
            input  ARVALID;
            input  ARADDR;
            input  ARPROT;

            input  RREADY;
            output RVALID;
            output RDATA;
            output RRESP;

        endclocking


    `endif //SYNTHESIS

    task automatic read (
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
begin
    ARADDR = addr;
    ARVALID = 1'b1;
    RREADY = 1'b1;
    wait(ARREADY);
    @(posedge i_clk) #1;
    ARVALID = 1'b0;
    wait(RVALID);
    data = RDATA;
    @(posedge i_clk) #1;
    RREADY = 1'b0;
end
    endtask

    task automatic write (
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
begin
    WDATA = data;
    AWADDR = addr;
    AWVALID = 1'b1;
    WVALID = 1'b1;
    WSTRB = '1;
    BREADY = 1'b1;
    wait(AWREADY && WREADY);
    @(posedge i_clk) #1;
    AWVALID = 1'b0;
    WVALID = 1'b0;
end
    endtask

    task automatic write_field (
        input logic [ADDR_WIDTH        -1:0] addr,
        input logic [DATA_WIDTH        -1:0] data,
        input logic [DATA_WIDTH        -1:0] mask,
        input logic [$clog2(ADDR_WIDTH)  :0] offset
    );
begin
    logic [DATA_WIDTH-1:0] rd_data, wr_data;
    read(addr, rd_data);
    wr_data = (rd_data & ~mask) | ((data << offset) & mask);
    write(addr, wr_data);
end
    endtask

    task automatic read_field (
        input  logic [ADDR_WIDTH        -1:0] addr,
        output logic [DATA_WIDTH        -1:0] data,
        input  logic [DATA_WIDTH        -1:0] mask,
        input  logic [$clog2(ADDR_WIDTH)  :0] offset
    );
begin
    logic [DATA_WIDTH-1:0] tmp_data;
    read(addr, tmp_data);
    data = (tmp_data & mask) >> offset;
end
    endtask


endinterface
