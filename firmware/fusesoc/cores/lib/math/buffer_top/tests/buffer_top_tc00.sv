// ============================================================================
// File: buffer_top_tc00.sv
// Description: SVUnit testbench top-level for buffer_top using axi4_lite_if
//              and axil_slv register bank.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module buffer_top_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "buffer_top_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_CLOCK_FREQ  = 100e6;
    localparam real AXIS_CLOCK_FREQ = 200e6;
    localparam int  N = 10;
    localparam int  B = 16;

    // Parameters for the AXI-Lite register bank
    localparam int  AXI_DW   = 32;
    localparam int  AXI_AW   = 8;
    localparam int  NUM_REGS = 8;

    // AXI4-Lite register byte addresses
    localparam logic [AXI_AW-1:0] BUF_START_REG = 6'h00;
    localparam logic [AXI_AW-1:0] BUF_ADDR_REG  = 6'h04;
    localparam logic [AXI_AW-1:0] BUF_LEN_REG   = 6'h08;
    localparam logic [AXI_AW-1:0] DR_START_REG  = 6'h0C;
    localparam logic [AXI_AW-1:0] DR_ADDR_REG   = 6'h10;
    localparam logic [AXI_AW-1:0] DR_LEN_REG    = 6'h14;

    // =========================================================================
    // Clock & Reset Wires
    // =========================================================================
    logic axi_clk  = 1'b0;
    logic axi_rstn = 1'b1;
    logic axis_clk  = 1'b0;
    logic axis_rstn = 1'b1;

    // =========================================================================
    // Interface instantiation
    // =========================================================================
    axi4_stream_if #(.TDATA_WIDTH(2*B)) m_axis_if (.aclk(axis_clk), .aresetn(axis_rstn));

    axi4_lite_if #(.DATA_WIDTH(AXI_DW), .ADDR_WIDTH(AXI_AW)) ctrl_axil_if (
        .aclk    (axi_clk),
        .aresetn (axi_rstn)
    );

    // =========================================================================
    // AXI-Lite register bank (axil_slv)
    // =========================================================================
    logic [AXI_DW-1:0] slv_regs_out [NUM_REGS];
    logic [AXI_DW-1:0] slv_regs_in  [NUM_REGS] = '{default: '0};

    axil_slv #(
        .AXI_DW       (AXI_DW),
        .AXI_AW       (AXI_AW),
        .NUM_REGS     (NUM_REGS),
        .ENABLE_AW_EN (1'b1)
    ) u_axil_slv (
        .s_axi_aclk    (axi_clk),
        .s_axi_aresetn (axi_rstn),

        .s_axi_awaddr  (ctrl_axil_if.awaddr),
        .s_axi_awprot  (ctrl_axil_if.awprot),
        .s_axi_awvalid (ctrl_axil_if.awvalid),
        .s_axi_awready (ctrl_axil_if.awready),
        .s_axi_wdata   (ctrl_axil_if.wdata),
        .s_axi_wstrb   (ctrl_axil_if.wstrb),
        .s_axi_wvalid  (ctrl_axil_if.wvalid),
        .s_axi_wready  (ctrl_axil_if.wready),
        .s_axi_bresp   (ctrl_axil_if.bresp),
        .s_axi_bvalid  (ctrl_axil_if.bvalid),
        .s_axi_bready  (ctrl_axil_if.bready),
        .s_axi_araddr  (ctrl_axil_if.araddr),
        .s_axi_arprot  (ctrl_axil_if.arprot),
        .s_axi_arvalid (ctrl_axil_if.arvalid),
        .s_axi_arready (ctrl_axil_if.arready),
        .s_axi_rdata   (ctrl_axil_if.rdata),
        .s_axi_rresp   (ctrl_axil_if.rresp),
        .s_axi_rvalid  (ctrl_axil_if.rvalid),
        .s_axi_rready  (ctrl_axil_if.rready),

        .o_slv_regs    (slv_regs_out),
        .i_slv_regs    (slv_regs_in),
        .i_reg_is_readonly ('0)
    );

    // =========================================================================
    // Discrete signals
    // =========================================================================
    logic           tb_trigger_i   = 1'b0;
    logic           tb_din_valid_i = 1'b0;
    logic [2*B-1:0] tb_din_i       = '0;

    // =========================================================================
    // Waveform dump & Clock Gen
    // =========================================================================
    initial begin
        $dumpfile("buffer_top.vcd");
        $dumpvars();
    end

    clk_gen #(.FREQ (AXI_CLOCK_FREQ))  u_sys_clk_gen (.i_enable(1'b1), .o_clk(axi_clk));
    clk_gen #(.FREQ (AXIS_CLOCK_FREQ)) u_axi_clk_gen (.i_enable(1'b1), .o_clk(axis_clk));

    // =========================================================================
    // Clocking Blocks
    // =========================================================================
    default clocking axi_cb @(posedge axi_clk);
        default input #1step output #2;
        output axi_rstn;
    endclocking

    clocking axis_cb @(posedge axis_clk);
        default input #1step output #2;
        output axis_rstn;
        output tb_trigger_i;
        output tb_din_valid_i;
        output tb_din_i;
    endclocking

    // =========================================================================
    // Unit Under Test (UUT)
    // =========================================================================
    buffer_top #(
        .N (N),
        .B (B)
    ) dut (
        .rstn           (axis_rstn),
        .clk            (axis_clk),
        .trigger_i      (tb_trigger_i),
        .din_valid_i    (tb_din_valid_i),
        .din_i          (tb_din_i),
        .m_axis_aclk    (axis_clk),
        .m_axis_aresetn (axis_rstn),

        .m_axis_tvalid  (m_axis_if.tvalid),
        .m_axis_tready  (m_axis_if.tready),
        .m_axis_tdata   (m_axis_if.tdata),
        .m_axis_tlast   (m_axis_if.tlast),

        // REGISTER MAP FROM SLAVE AXI-LITE
        .buf_start_reg  (slv_regs_out[0][0]),      // Reg 0 (Addr 0x00)
        .buf_addr_reg   (slv_regs_out[1][N-1:0]),  // Reg 1 (Addr 0x04)
        .buf_len_reg    (slv_regs_out[2][N-1:0]),  // Reg 2 (Addr 0x08)
        .dr_start_reg   (slv_regs_out[3][0]),      // Reg 3 (Addr 0x0C)
        .dr_addr_reg    (slv_regs_out[4][N-1:0]),  // Reg 4 (Addr 0x10)
        .dr_len_reg     (slv_regs_out[5][N:0])     // Reg 5 (Addr 0x14)
    );

    // =========================================================================
    // Helper Tasks
    // =========================================================================

    task automatic reset_dut();
        axi_cb.axi_rstn   <= 1'b0;
        axis_cb.axis_rstn <= 1'b0;
        repeat(20) @(axi_cb);
        axi_cb.axi_rstn   <= 1'b1;
        axis_cb.axis_rstn <= 1'b1;
        repeat(50) @(axi_cb);
    endtask

    task automatic buf_arm_and_trigger(
        input logic [N-1:0] addr,
        input logic [N-1:0] len
    );
        ctrl_axil_if.axi_write(BUF_ADDR_REG, 32'(addr));
        ctrl_axil_if.axi_write(BUF_LEN_REG,  32'(len));

        ctrl_axil_if.axi_write(BUF_START_REG, 32'h1);

        repeat(4) @(axis_cb);
        axis_cb.tb_trigger_i <= 1'b1;
        @(axis_cb);
        axis_cb.tb_trigger_i <= 1'b0;
    endtask

    task automatic inject_data(input int count, input logic [2*B-1:0] start_val);
        for (int i = 0; i < count; i++) begin
            axis_cb.tb_din_i       <= start_val + i;
            axis_cb.tb_din_valid_i <= 1'b1;
            @(axis_cb);
        end
        axis_cb.tb_din_valid_i <= 1'b0;
        repeat(6) @(axis_cb);
    endtask

    task automatic start_reader(input logic [N-1:0] addr, input logic [N:0] len);
        ctrl_axil_if.axi_write(DR_ADDR_REG, 32'(addr));
        ctrl_axil_if.axi_write(DR_LEN_REG,  32'(len));
        ctrl_axil_if.axi_write(DR_START_REG, 32'h1);
        // CDC: wait for dr_start_reg_resync to arrive to the axis_clk domain
        repeat(5) @(axis_cb);
        ctrl_axil_if.axi_write(DR_START_REG, 32'h0);
    endtask

    task automatic read_m_data(
        input  int             expected_count,
        output logic [2*B-1:0] data[],
        output int             timed_out,
        output int             tlast_errors,
        input  int             timeout_cycles = 500
    );
        int count = 0;
        int timeout = 0;
        timed_out = 0;
        tlast_errors = 0;
        data = new[expected_count];

        m_axis_if.tready <= 1'b1;

        while (count < expected_count) begin
            timeout++;
            if (m_axis_if.tvalid && m_axis_if.tready) begin
                data[count] = m_axis_if.tdata;

                if (count == expected_count - 1) begin
                    if (!m_axis_if.tlast) begin
                        $display("[ERROR] read_m_data: tlast NOT asserted on the last word");
                        tlast_errors++;
                    end
                end else begin
                    if (m_axis_if.tlast) begin
                        $display("[ERROR] read_m_data: tlast asserted EARLY at word %0d", count);
                        tlast_errors++;
                    end
                end
                count++;
            end
            if (timeout > timeout_cycles) begin
                timed_out = 1;
                break;
            end
            @(axis_cb);
        end

        timeout = 0;
        while (m_axis_if.tvalid) begin
            @(axis_cb);
            if (timeout++ > 50) break;
        end

        @(axis_cb);
        m_axis_if.tready <= 1'b0;
        repeat(5) @(axis_cb);
    endtask

    task automatic verify_data(input logic [2*B-1:0] expected[], input logic [2*B-1:0] actual[], input string test_name);
        for (int i = 0; i < expected.size(); i++) begin
            if (expected[i] !== actual[i]) begin
                $display("MISMATCH %s [%0d]: expected 0x%0h got 0x%0h", test_name, i, expected[i], actual[i]);
                `FAIL_IF(1);
            end
        end
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        axis_cb.tb_trigger_i   <= 1'b0;
        axis_cb.tb_din_valid_i <= 1'b0;
        axis_cb.tb_din_i       <= '0;
        m_axis_if.s_cb.tready  <= 1'b0;

        ctrl_axil_if.reset();

        @(axi_cb);
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "buffer_top_tests.sv"
    `SVUNIT_TESTS_END

endmodule
