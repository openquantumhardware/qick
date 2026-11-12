`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

// bram_simple_sp against a reference model, one clock cycle at a time: every
// cycle the testbench drives the port, the model applies the same operation,
// and on the next edge o_doa must show what the model predicted (read data,
// written data for a write, the old value when i_ena is low).
module bram_simple_sp_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "bram_simple_sp_ut";
    svunit_testcase svunit_ut;

    localparam int unsigned NB_DATA = 32;
    localparam int unsigned NB_ADDR = 4;
    localparam int unsigned WORDS   = 2**NB_ADDR;
    localparam string       IMAGE   = "bram_simple_sp_init.mem";

    logic               tb_clk;
    logic               tb_ena;
    logic               tb_wea;
    logic [NB_ADDR-1:0] tb_addra;
    logic [NB_DATA-1:0] tb_dia;
    logic [NB_DATA-1:0] tb_doa;

    clk_gen #(.FREQ(100e6)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_ena, tb_wea, tb_addra, tb_dia;
        input  tb_doa;
    endclocking

    bram_simple_sp #(
        .NB_DATA      (NB_DATA),
        .NB_ADDR      (NB_ADDR),
        .MEM_BIN_FILE (IMAGE)
    ) dut (
        .i_clk   (tb_clk),
        .i_ena   (tb_ena),
        .i_wea   (tb_wea),
        .i_addra (tb_addra),
        .i_dia   (tb_dia),
        .o_doa   (tb_doa)
    );

    // Reference model: memory contents, and the o_doa expected after the edge
    // just simulated (unknown until the first enabled cycle).
    logic [NB_DATA-1:0] model [WORDS];
    logic [NB_DATA-1:0] doa_expected;
    bit                 doa_known;
    int                 n_checked;

    initial $readmemb(IMAGE, model);

    // One clock cycle: drive the port, check the result of the previous cycle,
    // then predict the result of this one.
    task automatic cycle(input logic ena, input logic wea,
                         input logic [NB_ADDR-1:0] addr, input logic [NB_DATA-1:0] din);
        cb.tb_ena   <= ena;
        cb.tb_wea   <= wea;
        cb.tb_addra <= addr;
        cb.tb_dia   <= din;
        @(cb);
        if (doa_known) begin
            `FAIL_UNLESS_LOG(cb.tb_doa === doa_expected,
                $sformatf("o_doa 0x%08h, expected 0x%08h", cb.tb_doa, doa_expected))
            n_checked++;
        end
        if (ena) begin
            doa_expected = wea ? din : model[addr];
            doa_known    = 1'b1;
            if (wea) model[addr] = din;
        end
    endtask

    // Idle cycles that check the previous result (tests end with one).
    task automatic idle(input int n = 1);
        repeat (n) cycle(1'b0, 1'b0, '0, '0);
    endtask

    // Idle cycles without checks, for setup and teardown: SVUnit marks the
    // test running before setup(), and a failed check there would block in
    // give_up() outside the test's fork, hanging the run.
    task automatic quiet(input int n = 1);
        repeat (n) begin
            cb.tb_ena <= 1'b0;
            cb.tb_wea <= 1'b0;
            @(cb);
        end
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        quiet(2);
        doa_known = 1'b0;  // o_doa keeps the last test's value; not checked
        n_checked = 0;
    endtask

    task teardown();
        quiet(2);
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
