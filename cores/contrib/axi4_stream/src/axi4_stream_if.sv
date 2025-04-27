/***********************************************
 *
 *  Copyright (C) 2022 - Stratum Labs
 *
 *  Project:    Common
 *  Author:     Leandro Echevarría <leo.echevarria@stratum-labs.com>
 *
 *  File: axi4_stream_if.sv
 *  Description: AXI4-Stream interface including SystemVerilog assertions
 *
 *  References:
 *  - AXI4-Stream protocol specification: https://developer.arm.com/documentation/ihi0051/a/
 *  - AXI4-Stream protocol assertions: https://developer.arm.com/documentation/dui0534/b/
 *
 * ********************************************/

interface axi4_stream_if
#(
    parameter integer unsigned  N_BYTES_TDATA   = 4,
    parameter integer unsigned  N_BITS_TUSER    = N_BYTES_TDATA,
    parameter integer unsigned  N_BITS_TID      = 8,
    parameter integer unsigned  N_BITS_TDEST    = 4,
    parameter bit               HAS_TSTRB       = 1'b0,
    parameter bit               HAS_TKEEP       = 1'b0,
    parameter bit               HAS_TID         = 1'b0,
    parameter bit               HAS_TDEST       = 1'b0,
    parameter bit               HAS_TUSER       = 1'b0,
    parameter integer unsigned  BYTE_SIZE       = 8
)
(
    input logic i_clk,
    input logic i_rst // per protocol this should be active low, but we are using active high
);

    generate
        if (N_BYTES_TDATA == 0) begin : g_check_n_bytes_tdata_nonzero
            $fatal(1, "The number of bytes in the tdata vector cannot be zero.");
        end
    endgenerate

    generate
        if ((N_BITS_TID + N_BITS_TDEST) > 24) begin : g_check_id_dest_width
            $fatal(1, "The sum of N_BITS_TID (%0d) and N_BITS_TDEST (%0d) must not exceed 24.",
                    N_BITS_TID, N_BITS_TDEST);
        end
    endgenerate

    // Protocol signals
    logic                                       tvalid          ; // Master -> Slave
    logic                                       tready          ; // Master <- Slave
    logic   [(N_BYTES_TDATA*BYTE_SIZE)-1:0]     tdata           ; // Master -> Slave
    logic   [N_BYTES_TDATA-1:0]                 tstrb           ; // Master -> Slave [OPTIONAL]
    logic   [N_BYTES_TDATA-1:0]                 tkeep           ; // Master -> Slave [OPTIONAL]
    logic                                       tlast           ; // Master -> Slave
                                                                  // [OPTIONAL BUT MUST EXIST AND EITHER BE DRIVEN LOW OR HIGH]
    logic   [N_BITS_TID-1:0]                    tid             ; // Master -> Slave [OPTIONAL]
    logic   [N_BITS_TDEST-1:0]                  tdest           ; // Master -> Slave [OPTIONAL]
    logic   [N_BITS_TUSER-1:0]                  tuser           ; // Master -> Slave [OPTIONAL]

    modport master
    (
        output  tvalid          ,
        input   tready          ,
        output  tdata           ,
        output  tstrb           ,
        output  tkeep           ,
        output  tlast           ,
        output  tid             ,
        output  tdest           ,
        output  tuser
    );

    modport slave
    (
        input  tvalid           ,
        output tready           ,
        input  tdata            ,
        input  tstrb            ,
        input  tkeep            ,
        input  tlast            ,
        input  tid              ,
        input  tdest            ,
        input  tuser
    );

    // ASSERTIONS
    `ifdef SYNTHESIS
    `elsif VERILATOR
    `else
    
        modport tb_master(clocking m_cb);
        modport tb_slave(clocking s_cb);

        clocking m_cb @(posedge i_clk);
            default input #1step output #2;
            input  tvalid          ;
            output tready          ;
            input  tdata           ;
            input  tstrb           ;
            input  tkeep           ;
            input  tlast           ;
            input  tid             ;
            input  tdest           ;
            input  tuser           ;
        endclocking

        clocking s_cb @(posedge i_clk);
            default input #1step output #2;
            output tvalid          ;
            input  tready          ;
            output tdata           ;
            output tstrb           ;
            output tkeep           ;
            output tlast           ;
            output tid             ;
            output tdest           ;
            output tuser           ;
        endclocking

        `include "svunit_assert_macros.svh"

        property VALID_RST;
        @(posedge i_clk) i_rst == 1'b1 |=> tvalid == 1'b0;
        endproperty `ASSERT_CONCURRENT_LOG( VALID_RST,
                    "VALID_RST: tvalid must be LOW while reset is asserted");

        property AXI4STREAM_ERRM_TVALID_RESET;
        @(posedge i_clk) (!i_rst & $past(i_rst)) |-> tvalid == 1'b0; //Vivado < 2021.2 does not support $fell
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TVALID_RESET,
                    "AXI4STREAM_ERRM_TVALID_RESET: tvalid was not low for the first cycle after reset went low");

        property AXI4STREAM_ERRM_TVALID_STABLE;
        @(posedge i_clk) disable iff (i_rst) (tvalid && !tready) |=> tvalid;
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TVALID_STABLE,
                    "AXI4STREAM_ERRM_TVALID_STABLE: tvalid was deasserted even though the data was not consumed");

        property AXI4STREAM_ERRM_TDATA_STABLE;
        @(posedge i_clk) disable iff (i_rst) (tvalid && !tready) |=> $stable(tdata);
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TDATA_STABLE,
                    "AXI4STREAM_ERRM_TDATA_STABLE: tdata was not stable when tvalid was asserted and tready was low");

        property AXI4STREAM_ERRM_TLAST_STABLE;
        @(posedge i_clk) disable iff (i_rst) (tvalid && !tready) |=> $stable(tlast);
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TLAST_STABLE,
                    "AXI4STREAM_ERRM_TLAST_STABLE: tlast was not stable when tvalid was asserted and tready was low");

        property AXI4STREAM_ERRM_TDATA_X;
        @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tdata);
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TDATA_X,
                    "AXI4STREAM_ERRM_TDATA_X: part (or all) of tdata was 1'bX while tvalid was high");

        property AXI4STREAM_ERRM_TLAST_X;
        @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tlast);
        endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TLAST_X,
                    "AXI4STREAM_ERRM_TLAST_X: tlast was 1'bX while tvalid was high");

        generate
        if (HAS_TSTRB == 1'b1) begin : g_tstrb_assertions

            property AXI4STREAM_ERRM_TSTRB_STABLE;
            @(posedge i_clk) (!i_rst && tvalid && !tready) |=> $stable(tstrb);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TSTRB_STABLE,
                    "AXI4STREAM_ERRM_TSTRB_STABLE: tstrb was not stable when tvalid was asserted and tready was low");

            property AXI4STREAM_ERRM_TSTRB_X;
            @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tstrb);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TSTRB_X,
                        "AXI4STREAM_ERRM_TSTRB_X: part (or all) of tstrb was 1'bX while tvalid was high");

        end
        if (HAS_TKEEP == 1'b1) begin : g_tkeep_assertions

            property AXI4STREAM_ERRM_TKEEP_STABLE;
            @(posedge i_clk) (!i_rst && tvalid && !tready) |=> $stable(tkeep);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TKEEP_STABLE,
                        "AXI4STREAM_ERRM_TKEEP_STABLE: tkeep changed while data was not consumed");

            property AXI4STREAM_ERRM_TKEEP_X;
            @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tkeep);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TKEEP_X,
                        "AXI4STREAM_ERRM_TKEEP_X: part (or all) of tkeep was 1'bX while tvalid was high");

        end
        if (HAS_TID == 1'b1) begin : g_tid_assertions

            property AXI4STREAM_ERRM_TID_STABLE;
            @(posedge i_clk) (!i_rst && tvalid && !tready) |=> $stable(tid);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TID_STABLE,
                        "AXI4STREAM_ERRM_TID_STABLE: tid was not stable when tvalid was asserted and tready was low");

            property AXI4STREAM_ERRM_TID_X;
            @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tid);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TID_X,
                        "AXI4STREAM_ERRM_TID_X: part (or all) of tid was 1'bX while tvalid was high");

        end
        if (HAS_TDEST == 1'b1) begin : g_tdest_assertions

            property AXI4STREAM_ERRM_TDEST_STABLE;
            @(posedge i_clk) (!i_rst && tvalid && !tready) |=> $stable(tdest);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TDEST_STABLE,
                    "AXI4STREAM_ERRM_TDEST_STABLE: tdest was not stable when tvalid was asserted and tready was low");

            property AXI4STREAM_ERRM_TDEST_X;
            @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tdest);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TDEST_X,
                        "AXI4STREAM_ERRM_TDEST_X: part (or all) of tdest was 1'bX while tvalid was high");

        end
        if (HAS_TUSER == 1'b1) begin : g_tuser_assertions

            property AXI4STREAM_ERRM_TUSER_STABLE;
            @(posedge i_clk) (!i_rst && tvalid && !tready) |=> $stable(tuser);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TUSER_STABLE,
                    "AXI4STREAM_ERRM_TUSER_STABLE: tuser was not stable when tvalid was asserted and tready was low");

            property AXI4STREAM_ERRM_TUSER_X;
            @(posedge i_clk) (!i_rst && tvalid) |-> !$isunknown(tuser);
            endproperty `ASSERT_CONCURRENT_LOG( AXI4STREAM_ERRM_TUSER_X,
                        "AXI4STREAM_ERRM_TUSER_X: part (or all) of tuser was 1'bX while tvalid was high");

        end
        endgenerate

    `endif //SYNTHESIS

    // TODO: some way of checking that tvalid is never 1'bX or 1'bZ after a reset
    // TODO: verification functions such as time-sensitive write and reads
    // TODO: add some tests

endinterface: axi4_stream_if
