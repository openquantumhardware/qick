`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_tdp_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "bram_tdp_ut";
  svunit_testcase svunit_ut;

  localparam CLK_A_FREQ = 150e6; //[Hz]
  localparam CLK_B_FREQ = 200e6; //[Hz]

  // Parameters of our BRAM
  localparam int unsigned NB_DATA = 32;
  localparam int unsigned NB_ADDR = 10;

  logic tb_a_clk  = 1'b0;
  logic tb_b_clk  = 1'b0;
  logic tb_rstn = 1'b1;

  // Auxiliary variable to capture read data
  logic [NB_DATA-1:0] read_val;

  initial begin
    $dumpfile("bram_tdp.vcd");
    $dumpvars();
  end

  // Clock generator
  clk_gen #(
    .FREQ      ( CLK_A_FREQ   )
  ) u_clk_a_gen (
    .i_enable  ( 1'b1              ),
    .o_clk     ( tb_a_clk            )
  );

  clk_gen #(
    .FREQ      ( CLK_B_FREQ   )
  ) u_clk_b_gen (
    .i_enable  ( 1'b1              ),
    .o_clk     ( tb_b_clk            )
  );

  //default clocking cb @(posedge tb_a_clk);
  //endclocking

  //===================================
  // Instantiate interfaces
  //===================================
  bram_if #(
    .NB_DATA(NB_DATA),
    .NB_ADDR(NB_ADDR)
  ) port_a_if (
    .i_clk ( tb_a_clk  ),
    .i_rst ( ~tb_rstn ) // Asume active-high reset in the interface
  );

  bram_if #(
    .NB_DATA(NB_DATA),
    .NB_ADDR(NB_ADDR)
  ) port_b_if (
    .i_clk ( tb_b_clk  ),
    .i_rst ( ~tb_rstn )
  );

  //===================================
  // UUT: True Dual-Port BRAM
  //===================================
  bram_tdp #(
    .NB_DATA(NB_DATA),
    .NB_ADDR(NB_ADDR)
  ) u_bram_tdp (
    .clka  (tb_a_clk),
    .rsta  (~tb_rstn),
    .ena   (port_a_if.slave.en),
    .wea   (port_a_if.slave.we),
    .addra (port_a_if.slave.addr),
    .dia   (port_a_if.slave.din),
    .doa   (port_a_if.slave.dout),

    .clkb  (tb_b_clk),
    .rstb  (~tb_rstn),
    .enb   (port_b_if.slave.en),
    .web   (port_b_if.slave.we),
    .addrb (port_b_if.slave.addr),
    .dib   (port_b_if.slave.din),
    .dob   (port_b_if.slave.dout)
  );

  //===================================
  // Build
  //===================================
  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup for running the Unit Tests
  //===================================
  task setup();
    svunit_ut.setup();
    
    // Init signals to avoid "X"
    port_a_if.en   <= 1'b0;
    port_a_if.we   <= 1'b0;
    port_a_if.we_be<= '1;
    port_a_if.addr <= '0;
    port_a_if.din  <= '0;

    port_b_if.en   <= 1'b0;
    port_b_if.we   <= 1'b0;
    port_b_if.we_be<= '1;
    port_b_if.addr <= '0;
    port_b_if.din  <= '0;
  
    @(port_a_if.tb_cb);
    tb_rstn <= 1'b0;
    repeat(2) @(port_a_if.tb_cb);
    tb_rstn <= 1'b1;
    repeat(5) @(port_a_if.tb_cb);
  endtask

  //===================================
  // Teardown
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // SVUNIT Tests
  //===================================
  `SVUNIT_TESTS_BEGIN
    `include "tests.sv"
  `SVUNIT_TESTS_END 

endmodule
