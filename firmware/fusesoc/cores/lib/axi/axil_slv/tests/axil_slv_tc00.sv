`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axil_slv_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "axil_slv_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam SYNC_PULSE_FREQ = 5e6; //[Hz]

  localparam NB       = 32;
  localparam AXI_AW   = 6;              // Address width. Adjust as needed.
  localparam AXI_DW   = 32;             // Data width (32 or 64).
  localparam NUM_REGS = 16;              // Configurable number of registers

  localparam time TSU = 1ns; // setup offset from clock edge (xsim-safe)

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;
  logic [AXI_DW-1:0]   tb_o_slv_reg[NUM_REGS];
  logic [AXI_DW-1:0]   tb_i_slv_reg[NUM_REGS];
  logic [AXI_DW-1:0] tb_slv_regs [NUM_REGS];
  logic [NUM_REGS-1:0] tb_i_reg_is_readonly;

  initial begin
    $dumpfile("axil_slv.vcd");
    $dumpvars();
  end

  clk_gen#(.FREQ( CLOCK_FREQUENCY )) u_clk_gen(.i_enable( 1'b1 ), .o_clk( tb_clk ));
  axi4_lite_if#(.DATA_WIDTH(AXI_DW), .ADDR_WIDTH(AXI_AW)) s_axi(.aclk(tb_clk ), .aresetn(tb_rstn));


  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  axil_slv#(
    .AXI_AW   ( 6  ), 
    .AXI_DW   ( 32 ),
    .NUM_REGS ( 16 ) 
  )u_axil_slv(
    .s_axi_aclk   ( s_axi.aclk          ),  // System clock
    .s_axi_aresetn( s_axi.aresetn       ),  // Active-low reset
    .s_axi_awaddr ( s_axi.awaddr  ),  // Write address
    .s_axi_awvalid( s_axi.awvalid ),  // Write address valid
    .s_axi_awready( s_axi.awready ),  // Write address ready
    .s_axi_wdata  ( s_axi.wdata   ),  // Write data
    .s_axi_wstrb  ( s_axi.wstrb   ),  // Write strobes
    .s_axi_wvalid ( s_axi.wvalid  ),  // Write data valid
    .s_axi_wready ( s_axi.wready  ),  // Write data ready
    .s_axi_bresp  ( s_axi.bresp   ),  // Write response
    .s_axi_bvalid ( s_axi.bvalid  ),  // Write response valid
    .s_axi_bready ( s_axi.bready  ),  // Write response ready
    .s_axi_araddr ( s_axi.araddr  ),  // Read address
    .s_axi_arvalid( s_axi.arvalid ),  // Read address valid
    .s_axi_arready( s_axi.arready ),  // Read address ready
    .s_axi_rdata  ( s_axi.rdata   ),  // Read data
    .s_axi_rresp  ( s_axi.rresp   ),  // Read response
    .s_axi_rvalid ( s_axi.rvalid  ),  // Read data valid
    .s_axi_rready ( s_axi.rready  ),  // Read data ready
    .o_slv_regs   ( tb_o_slv_reg     ),  // Writable registers
    .i_slv_regs   ( tb_i_slv_reg     ),  // Read-only register values
    .i_reg_is_readonly ( tb_i_reg_is_readonly )
  );

  always_comb begin
    for (int i = 0; i < NUM_REGS; i++) begin
      tb_i_slv_reg[i] = tb_o_slv_reg[i];
    end
  end

  //===================================
  // Build
  //===================================

  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup for running the Unit Tests
  //===================================
  // AXI write with a chosen wstrb (axi4_lite_if's axi_write always sets all
  // strobes); same handshake as that task.
  task automatic axi_write_strb(input logic [AXI_AW-1:0] addr, input logic [AXI_DW-1:0] data,
                                input logic [AXI_DW/8-1:0] strb);
    @(s_axi.m_cb);
    s_axi.m_cb.awaddr  <= addr;
    s_axi.m_cb.awprot  <= 3'b000;
    s_axi.m_cb.awvalid <= 1'b1;
    s_axi.m_cb.wdata   <= data;
    s_axi.m_cb.wstrb   <= strb;
    s_axi.m_cb.wvalid  <= 1'b1;
    s_axi.m_cb.bready  <= 1'b1;
    fork
      begin do @(s_axi.m_cb); while (!s_axi.m_cb.awready); s_axi.m_cb.awvalid <= 1'b0; end
      begin while (!s_axi.m_cb.wready) @(s_axi.m_cb); s_axi.m_cb.wvalid <= 1'b0; end
    join
    while (!s_axi.m_cb.bvalid) @(s_axi.m_cb);
    s_axi.m_cb.bready <= 1'b0;
    @(s_axi.m_cb);
  endtask

  task setup();
    svunit_ut.setup();

    tb_i_reg_is_readonly = '0;

    s_axi.reset();

    @(posedge tb_clk); #TSU;
    tb_rstn <= 1'b0;
    repeat(5) @(posedge tb_clk); #TSU;
    tb_rstn <= 1'b1;
    repeat(5) @(posedge tb_clk); #TSU;

  endtask

  //===================================
  // Here we deconstruct anything we 
  // need after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_)
  // `SVTEST_END
  //
  // i.e.
  //   `SVTEST(mytest)
  //     <test code>
  //   `SVTEST_END
  //===================================


  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END 

endmodule
