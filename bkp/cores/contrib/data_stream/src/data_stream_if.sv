interface data_stream_if
#(
    parameter integer unsigned NB_DATA = 32
)
(
    input logic i_clk,
    input logic i_rst
);

    logic               valid;
    logic [NB_DATA-1:0] data ;
    logic               last ;

    modport master
    (
        output valid,
        output data ,
        output last
    );

    modport slave
    (
        input  valid,
        input  data ,
        input  last
    );

    clocking m_cb @(posedge i_clk);
        default input #1step output #2;
        input  valid          ;
        input  data           ;
        input  last           ;
    endclocking

    clocking s_cb @(posedge i_clk);
        default input #1step output #2;
        output valid          ;
        output data           ;
        output last           ;
    endclocking

    // ASSERTIONS
    `ifdef SYNTHESIS
    `elsif VERILATOR
    `else
        `include "svunit_assert_macros.svh"

        property VALID_RST_ASSERTION;
        @(posedge i_clk) i_rst == 1'b1 |=> valid == 1'b0;
        endproperty `ASSERT_CONCURRENT_LOG( VALID_RST_ASSERTION,
                    "VALID_RST_ASSERTION: valid must be LOW every cycle after reset is asserted");

        property VALID_RST_DEASSERTION;
        @(posedge i_clk) (~i_rst & $past(i_rst)) |-> valid == 1'b0; //Vivado < 2021.2 does not support $fell
        endproperty `ASSERT_CONCURRENT_LOG( VALID_RST_DEASSERTION,
                    "VALID_RST_DEASSERTION: valid was not low for the first cycle after reset went low");

        property DATA_X;
        @(posedge i_clk) (~i_rst && valid) |-> ~$isunknown(data);
        endproperty `ASSERT_CONCURRENT_LOG( DATA_X,
                    "DATA_X: part (or all) of data was 1'bX while valid was high");

        property LAST_X;
        @(posedge i_clk) (~i_rst && valid) |-> ~$isunknown(last);
        endproperty `ASSERT_CONCURRENT_LOG( LAST_X,
                    "LAST_X: last was 1'bX while valid was high");

    `endif //SYNTHESIS

endinterface: data_stream_if
