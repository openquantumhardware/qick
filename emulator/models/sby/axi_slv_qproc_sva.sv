// axi_slv_qproc_sva.sv

// Instantiates both the VHDL and SystemVerilog versions of axi_slv_qproc
// and asserts that their outputs are always the same

module axi_slv_qproc_equiv #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
) (
    input  wire aclk,
    input  wire aresetn,

    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire [2:0]            awprot,
    input  wire                  awvalid,

    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [(DATA_WIDTH/8)-1:0] wstrb,
    input  wire                  wvalid,

    input  wire                  bready,

    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire [2:0]            arprot,
    input  wire                  arvalid,

    input  wire                  rready,

    input  wire [31:0] MEM_DT_O,
    input  wire [31:0] TPROC_R_DT1,
    input  wire [31:0] TPROC_R_DT2,
    input  wire [31:0] TIME_USR,
    input  wire [31:0] TPROC_STATUS,
    input  wire [31:0] TPROC_DEBUG
);

    // VHDL outputs
    wire vhdl_awready;
    wire vhdl_wready;
    wire [1:0] vhdl_bresp;
    wire vhdl_bvalid;
    wire vhdl_arready;
    wire [DATA_WIDTH-1:0] vhdl_rdata;
    wire [1:0] vhdl_rresp;
    wire vhdl_rvalid;
    wire [15:0] vhdl_TPROC_CTRL;
    wire [15:0] vhdl_TPROC_CFG;
    wire [15:0] vhdl_MEM_ADDR;
    wire [15:0] vhdl_MEM_LEN;
    wire [31:0] vhdl_MEM_DT_I;
    wire [31:0] vhdl_TPROC_W_DT1;
    wire [31:0] vhdl_TPROC_W_DT2;
    wire [7:0]  vhdl_CORE_CFG;
    wire [7:0]  vhdl_READ_SEL;

    // SV outputs
    wire sv_awready;
    wire sv_wready;
    wire [1:0] sv_bresp;
    wire sv_bvalid;
    wire sv_arready;
    wire [DATA_WIDTH-1:0] sv_rdata;
    wire [1:0] sv_rresp;
    wire sv_rvalid;
    wire [15:0] sv_TPROC_CTRL;
    wire [15:0] sv_TPROC_CFG;
    wire [15:0] sv_MEM_ADDR;
    wire [15:0] sv_MEM_LEN;
    wire [31:0] sv_MEM_DT_I;
    wire [31:0] sv_TPROC_W_DT1;
    wire [31:0] sv_TPROC_W_DT2;
    wire [7:0]  sv_CORE_CFG;
    wire [7:0]  sv_READ_SEL;

    // VHDL internal signals
    wire [31:0] vhdl_slv_reg0;
    wire [31:0] vhdl_slv_reg1;
    wire [31:0] vhdl_slv_reg2;
    wire [31:0] vhdl_slv_reg3;
    wire [31:0] vhdl_slv_reg4;
    wire [31:0] vhdl_slv_reg5;
    wire [31:0] vhdl_slv_reg6;
    wire [31:0] vhdl_slv_reg7;
    wire [31:0] vhdl_slv_reg8;
    wire [31:0] vhdl_slv_reg9;
    wire [31:0] vhdl_slv_reg10;
    wire [31:0] vhdl_slv_reg11;
    wire [31:0] vhdl_slv_reg12;
    wire [31:0] vhdl_slv_reg13;
    wire [31:0] vhdl_slv_reg14;
    wire [31:0] vhdl_slv_reg15;
    wire vhdl_aw_en;
    wire vhdl_slv_reg_wren;
    wire vhdl_slv_reg_rden;
    wire [31:0] vhdl_reg_data_out;

    // SV internal signals
    wire [31:0] sv_slv_reg0;
    wire [31:0] sv_slv_reg1;
    wire [31:0] sv_slv_reg2;
    wire [31:0] sv_slv_reg3;
    wire [31:0] sv_slv_reg4;
    wire [31:0] sv_slv_reg5;
    wire [31:0] sv_slv_reg6;
    wire [31:0] sv_slv_reg7;
    wire [31:0] sv_slv_reg8;
    wire [31:0] sv_slv_reg9;
    wire [31:0] sv_slv_reg10;
    wire [31:0] sv_slv_reg11;
    wire [31:0] sv_slv_reg12;
    wire [31:0] sv_slv_reg13;
    wire [31:0] sv_slv_reg14;
    wire [31:0] sv_slv_reg15;
    wire sv_aw_en;
    wire sv_slv_reg_wren;
    wire sv_slv_reg_rden;
    wire [31:0] sv_reg_data_out;

    // VHDL
    axi_slv_qproc vhdl_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .awaddr(awaddr),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(vhdl_awready),
        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(vhdl_wready),
        .bresp(vhdl_bresp),
        .bvalid(vhdl_bvalid),
        .bready(bready),
        .araddr(araddr),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(vhdl_arready),
        .rdata(vhdl_rdata),
        .rresp(vhdl_rresp),
        .rvalid(vhdl_rvalid),
        .rready(rready),
        .TPROC_CTRL(vhdl_TPROC_CTRL),
        .TPROC_CFG(vhdl_TPROC_CFG),
        .MEM_ADDR(vhdl_MEM_ADDR),
        .MEM_LEN(vhdl_MEM_LEN),
        .MEM_DT_I(vhdl_MEM_DT_I),
        .TPROC_W_DT1(vhdl_TPROC_W_DT1),
        .TPROC_W_DT2(vhdl_TPROC_W_DT2),
        .CORE_CFG(vhdl_CORE_CFG),
        .READ_SEL(vhdl_READ_SEL),
        .MEM_DT_O(MEM_DT_O),
        .TPROC_R_DT1(TPROC_R_DT1),
        .TPROC_R_DT2(TPROC_R_DT2),
        .TIME_USR(TIME_USR),
        .TPROC_STATUS(TPROC_STATUS),
        .TPROC_DEBUG(TPROC_DEBUG),
        .slv_reg0(vhdl_slv_reg0),
        .slv_reg1(vhdl_slv_reg1),
        .slv_reg2(vhdl_slv_reg2),
        .slv_reg3(vhdl_slv_reg3),
        .slv_reg4(vhdl_slv_reg4),
        .slv_reg5(vhdl_slv_reg5),
        .slv_reg6(vhdl_slv_reg6),
        .slv_reg7(vhdl_slv_reg7),
        .slv_reg8(vhdl_slv_reg8),
        .slv_reg9(vhdl_slv_reg9),
        .slv_reg10(vhdl_slv_reg10),
        .slv_reg11(vhdl_slv_reg11),
        .slv_reg12(vhdl_slv_reg12),
        .slv_reg13(vhdl_slv_reg13),
        .slv_reg14(vhdl_slv_reg14),
        .slv_reg15(vhdl_slv_reg15),
        .aw_en(vhdl_aw_en),
        .slv_reg_wren(vhdl_slv_reg_wren),
        .slv_reg_rden(vhdl_slv_reg_rden),
        .reg_data_out(vhdl_reg_data_out)
    );

        // SystemVerilog
    axi_slv_qproc_sv #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sv_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .awaddr(awaddr),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(sv_awready),
        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(sv_wready),
        .bresp(sv_bresp),
        .bvalid(sv_bvalid),
        .bready(bready),
        .araddr(araddr),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(sv_arready),
        .rdata(sv_rdata),
        .rresp(sv_rresp),
        .rvalid(sv_rvalid),
        .rready(rready),
        .TPROC_CTRL(sv_TPROC_CTRL),
        .TPROC_CFG(sv_TPROC_CFG),
        .MEM_ADDR(sv_MEM_ADDR),
        .MEM_LEN(sv_MEM_LEN),
        .MEM_DT_I(sv_MEM_DT_I),
        .TPROC_W_DT1(sv_TPROC_W_DT1),
        .TPROC_W_DT2(sv_TPROC_W_DT2),
        .CORE_CFG(sv_CORE_CFG),
        .READ_SEL(sv_READ_SEL),
        .MEM_DT_O(MEM_DT_O),
        .TPROC_R_DT1(TPROC_R_DT1),
        .TPROC_R_DT2(TPROC_R_DT2),
        .TIME_USR(TIME_USR),
        .TPROC_STATUS(TPROC_STATUS),
        .TPROC_DEBUG(TPROC_DEBUG),
        .slv_reg0(sv_slv_reg0),
        .slv_reg1(sv_slv_reg1),
        .slv_reg2(sv_slv_reg2),
        .slv_reg3(sv_slv_reg3),
        .slv_reg4(sv_slv_reg4),
        .slv_reg5(sv_slv_reg5),
        .slv_reg6(sv_slv_reg6),
        .slv_reg7(sv_slv_reg7),
        .slv_reg8(sv_slv_reg8),
        .slv_reg9(sv_slv_reg9),
        .slv_reg10(sv_slv_reg10),
        .slv_reg11(sv_slv_reg11),
        .slv_reg12(sv_slv_reg12),
        .slv_reg13(sv_slv_reg13),
        .slv_reg14(sv_slv_reg14),
        .slv_reg15(sv_slv_reg15),
        .aw_en(sv_aw_en),
        .slv_reg_wren(sv_slv_reg_wren),
        .slv_reg_rden(sv_slv_reg_rden),
        .reg_data_out(sv_reg_data_out)
    );

    // Assumptions

    reg past_valid;
    initial past_valid = 1'b0;
    always @(posedge aclk) past_valid <= 1'b1;

    always @* assume (!aresetn == $initstate);

    // Reset
    always @(posedge aclk) if (!aresetn) begin
        assume(!awvalid);
        assume(!wvalid);
        assume(!arvalid);
        assume(!bready);
        assume(!rready);
    end

    (* anyseq *) reg wr_active;
    (* anyseq *) reg rd_active;

    // Constrain valid + ready signals
    wire wr_hs_vhdl = vhdl_awready && vhdl_wready && awvalid && wvalid;
    wire wr_hs_sv   = sv_awready   && sv_wready   && awvalid && wvalid;
    wire wr_hs_both = wr_hs_vhdl && wr_hs_sv;

    wire rd_hs_vhdl = vhdl_arready && arvalid;
    wire rd_hs_sv   = sv_arready   && arvalid;
    wire rd_hs_both = rd_hs_vhdl && rd_hs_sv;

    always @(posedge aclk) if (aresetn) begin
        // Write
        assume(awvalid == wr_active);
        assume(wvalid  == wr_active);
        if (wr_active && !wr_hs_both) begin
            assume($stable(awaddr));
            assume($stable(awprot));
            assume($stable(wdata));
            assume($stable(wstrb));
            assume($past(wr_active));
        end

        // Read
        assume(arvalid == rd_active);
        if (rd_active && !rd_hs_both) begin
            assume($stable(araddr));
            assume($stable(arprot));
            assume($past(rd_active));
        end

        assume(bready);
        assume(rready);
    end

    // Equivalence checks
    always @(posedge aclk) begin
        if (past_valid && aresetn) begin
            // Internal Signals
            assert(vhdl_slv_reg0 === sv_slv_reg0);
            assert(vhdl_slv_reg1 === sv_slv_reg1);
            assert(vhdl_slv_reg2 === sv_slv_reg2);
            assert(vhdl_slv_reg3 === sv_slv_reg3);
            assert(vhdl_slv_reg4 === sv_slv_reg4);
            assert(vhdl_slv_reg5 === sv_slv_reg5);
            assert(vhdl_slv_reg6 === sv_slv_reg6);
            assert(vhdl_slv_reg7 === sv_slv_reg7);
            assert(vhdl_slv_reg8 === sv_slv_reg8);
            assert(vhdl_slv_reg9 === sv_slv_reg9);
            assert(vhdl_slv_reg10 === sv_slv_reg10);
            assert(vhdl_slv_reg11 === sv_slv_reg11);
            assert(vhdl_slv_reg12 === sv_slv_reg12);
            assert(vhdl_slv_reg13 === sv_slv_reg13);
            assert(vhdl_slv_reg14 === sv_slv_reg14);
            assert(vhdl_slv_reg15 === sv_slv_reg15);
            assert(vhdl_aw_en === sv_aw_en);
            assert(vhdl_slv_reg_wren === sv_slv_reg_wren);
            assert(vhdl_slv_reg_rden === sv_slv_reg_rden);
            
            if (vhdl_slv_reg_rden) begin
                assert(vhdl_reg_data_out === sv_reg_data_out);
            end

            // Outputs
            assert(vhdl_awready === sv_awready);
            assert(vhdl_wready === sv_wready);
            assert(vhdl_bresp  === sv_bresp);
            assert(vhdl_bvalid === sv_bvalid);
            assert(vhdl_arready === sv_arready);
            assert(vhdl_rdata  === sv_rdata);
            assert(vhdl_rresp  === sv_rresp);
            assert(vhdl_rvalid === sv_rvalid);
            assert(vhdl_TPROC_CTRL === sv_TPROC_CTRL);
            assert(vhdl_TPROC_CFG  === sv_TPROC_CFG);
            assert(vhdl_MEM_ADDR   === sv_MEM_ADDR);
            assert(vhdl_MEM_LEN    === sv_MEM_LEN);
            assert(vhdl_MEM_DT_I   === sv_MEM_DT_I);
            assert(vhdl_TPROC_W_DT1 === sv_TPROC_W_DT1);
            assert(vhdl_TPROC_W_DT2 === sv_TPROC_W_DT2);
            assert(vhdl_CORE_CFG    === sv_CORE_CFG);
            assert(vhdl_READ_SEL    === sv_READ_SEL);
        end
    end

endmodule