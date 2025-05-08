/***********************************************
 * 
 *  Copyright (C) 2022 - Stratum Labs
 * 
 *  Project: ADS-B
 *  Author: Leandro Echevarria <leo.echevarria@stratum-labs.com>
 * 
 *  File: tc_000.sv
 *  Description: 
 *  Dummy block - Test case 000. Reset test.
 * 
 * ********************************************/

`timescale 1ns/1ps

import sim_global::*;

module tc_000();

    //////////////////////////////
    // TEST ENVIRONMENT DEFINITIONS
    //////////////////////////////

    `include "test_env_0.svh"

    //////////////////////////////
    // STIMULI
    //////////////////////////////

    initial begin
        test_sigma = 16'd3;
        test_delta = 16'd5;
        test_rst = 1'b1;
        ##10
        test_rst = 1'b0;

        ##1000

        test_sigma = 16'd2;
        test_delta = 16'd5;

        ##1000

        test_sigma = 16'd4;
        test_delta = 16'd10;

        ##1000

        test_sigma = 16'd1;
        test_delta = 16'd3;

        ##1000

        test_sigma = 16'd3;
        test_delta = 16'd4;

        ##1000

        test_sigma = 16'd75;
        test_delta = 16'd100;

        ##1000

        test_sigma = 16'd80;
        test_delta = 16'd100;

        ##1000

        test_sigma = 16'd801;
        test_delta = 16'd1000;

        ##1000

        test_sigma = 16'd777;
        test_delta = 16'd9000;

        ##1000

        $finish;
    end

endmodule