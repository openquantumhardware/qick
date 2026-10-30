`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component : regfile_8p_unit_test
// Origin    : Converted from VHDL regfile_8p (QICK register file with pages)
//             See regfile_8p.sv for full architectural notes.
//
// Description:
//   Unit testbench for the 8‑page register file (regfile_8p).
//   Tests cover:
//     - Reset state (all outputs zero)
//     - Write and read back (single page)
//     - Register 0 always reads zero
//     - Page selection (write to one page, read from another)
//     - Write enable gating (writes only to selected page)
//     - Pipelined read latency (one cycle)
//     - Concurrent read ports (all independent)
//------------------------------------------------------------------------------
module regfile_8p_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "regfile_8p_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real CLOCK_FREQUENCY = 100e6; // 100 MHz
    localparam B = 16;    // data width
    localparam N = 5;     // address width (32 registers per page)

    //--------------------------------------------------------------------------
    // Testbench Signals
    //--------------------------------------------------------------------------
    logic          tb_clk = 1'b0;
    logic          tb_rstn = 1'b0;
    logic [4:0]    tb_addr0, tb_addr1, tb_addr2, tb_addr3;
    logic [4:0]    tb_addr4, tb_addr5, tb_addr6, tb_addr7;
    logic [B-1:0]  tb_din7;
    logic          tb_wen7;
    logic [2:0]    tb_pnum;
    logic [B-1:0]  tb_dout0, tb_dout1, tb_dout2, tb_dout3;
    logic [B-1:0]  tb_dout4, tb_dout5, tb_dout6;

    //--------------------------------------------------------------------------
    // VCD Waveform Generation
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("regfile_8p.vcd");
        $dumpvars();
    end

    //--------------------------------------------------------------------------
    // Clock Generator Instance
    //--------------------------------------------------------------------------
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    //--------------------------------------------------------------------------
    // Default Clocking Block
    //--------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_addr0, tb_addr1, tb_addr2, tb_addr3;
        output tb_addr4, tb_addr5, tb_addr6, tb_addr7;
        output tb_din7;
        output tb_wen7;
        output tb_pnum;
        input  tb_dout0, tb_dout1, tb_dout2, tb_dout3;
        input  tb_dout4, tb_dout5, tb_dout6;
    endclocking

    //--------------------------------------------------------------------------
    // Unit Under Test (DUT)
    //--------------------------------------------------------------------------
    regfile_8p #(.B(B)) u_dut (
        .clk   (tb_clk),
        .rstn  (tb_rstn),
        .addr0 (tb_addr0),
        .addr1 (tb_addr1),
        .addr2 (tb_addr2),
        .addr3 (tb_addr3),
        .addr4 (tb_addr4),
        .addr5 (tb_addr5),
        .addr6 (tb_addr6),
        .addr7 (tb_addr7),
        .din7  (tb_din7),
        .wen7  (tb_wen7),
        .pnum  (tb_pnum),
        .dout0 (tb_dout0),
        .dout1 (tb_dout1),
        .dout2 (tb_dout2),
        .dout3 (tb_dout3),
        .dout4 (tb_dout4),
        .dout5 (tb_dout5),
        .dout6 (tb_dout6)
    );

    //--------------------------------------------------------------------------
    // Concurrent Assertions
    //--------------------------------------------------------------------------

    // Read port 0 must always be zero when addr0 == 0 (checked in the DUT)
    // We'll check that the DUT enforces this.
    property reg0_zero_read;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_addr0 == 0) |=> (tb_dout0 == 0);
    endproperty
    `ASSERT_CONCURRENT(reg0_zero_read);

    // Write and read should not happen on same address in same cycle? Actually,
    // the DUT reads the old value when write and read address are equal
    // (read before write). We can check that with a simple test.

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_rstn <= 1'b0;
        cb.tb_addr0 <= 0; cb.tb_addr1 <= 0; cb.tb_addr2 <= 0; cb.tb_addr3 <= 0;
        cb.tb_addr4 <= 0; cb.tb_addr5 <= 0; cb.tb_addr6 <= 0; cb.tb_addr7 <= 0;
        cb.tb_din7 <= 0;
        cb.tb_wen7 <= 1'b0;
        cb.tb_pnum <= 0;
        repeat(3) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        cb.tb_rstn <= 1'b0;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    // Write a value to a register (completa la escritura en 2 ciclos)
    task write_reg(input int page, input int addr, input logic [B-1:0] data);
      // Preparar señales (se actualizan en NBA después del flanco actual)
      cb.tb_pnum  <= page;
      cb.tb_addr7 <= addr;
      cb.tb_din7  <= data;
      cb.tb_wen7  <= 1'b1;
      @(cb);                      // Ciclo 1: DUT muestrea las señales y escribe
      cb.tb_wen7  <= 1'b0;        // Desactivar para el próximo ciclo
      @(cb);                      // Ciclo 2: estabilización (opcional, pero útil)
    endtask 
    
    // Read from a register (puerto 0).
    // Total read latency = 2 cycles:
    //   Cycle 1: regfile samples addr → data enters dout_p[i] registers
    //   Cycle 2: pnum_r valid → output mux selects correct page → dout0 stable
    task read_reg0(input int page, input int addr, output logic [B-1:0] data);
        cb.tb_pnum  <= page;
        cb.tb_addr0 <= addr;
        @(cb);   // Cycle 1: regfile clocks addr
        @(cb);   // Cycle 2: pnum_r mux resolves
        data = tb_dout0;
    endtask
    
    // Lectura simultánea de los 7 puertos.
    // Same 2-cycle latency applies to all ports.
    task read_all_ports(
        input  int page,
        input  int a0, int a1, int a2, int a3, int a4, int a5, int a6,
        output logic [B-1:0] d0, d1, d2, d3, d4, d5, d6
    );
        cb.tb_pnum  <= page;
        cb.tb_addr0 <= a0;
        cb.tb_addr1 <= a1;
        cb.tb_addr2 <= a2;
        cb.tb_addr3 <= a3;
        cb.tb_addr4 <= a4;
        cb.tb_addr5 <= a5;
        cb.tb_addr6 <= a6;
        @(cb);   // Cycle 1: regfile clocks addrs
        @(cb);   // Cycle 2: pnum_r mux resolves
        d0 = tb_dout0;
        d1 = tb_dout1;
        d2 = tb_dout2;
        d3 = tb_dout3;
        d4 = tb_dout4;
        d5 = tb_dout5;
        d6 = tb_dout6;
    endtask

    //--------------------------------------------------------------------------
    // Test Cases Block Insertion
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "regfile_8p_tests.sv"
    `SVUNIT_TESTS_END

endmodule
