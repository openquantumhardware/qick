/***********************************************
 * 
 *  Copyright (C) 2022 - Stratum Labs
 * 
 *  Project: ADS-B
 *  Author: Leandro Echevarria <leo.echevarria@stratum-labs.com>
 * 
 *  File: test_env_0.svh
 *  Description: 
 *  Dummy block - Test environment.
 * 
 * ********************************************/

    //////////////////////////////
    // TEST PARAMETERS
    //////////////////////////////

    localparam CLK_FREQUENCY = 100e6; //[Hz]
    localparam NB_SIGMA_DELTA = 16;

    //////////////////////////////
    // DUT INSTANTIATON
    //////////////////////////////

    logic test_clk;
    logic test_rst = 1'b0;
    logic test_i_enable = 1'b1;

    default clocking cb @(posedge test_clk);
    endclocking

    logic [NB_SIGMA_DELTA-1:0] test_sigma;
    logic [NB_SIGMA_DELTA-1:0] test_delta;
    logic                      test_enable;

    clk_gen
    #(
        .FREQ        ( CLK_FREQUENCY     )
    )
    u_clk_gen
    (
        .i_enable    ( BINARY_HIGH       ),
        .o_clk       ( test_clk          )
    );

    // DUT
    sigma_delta_generator
    #(
        .NB_SIGMA_DELTA     ( NB_SIGMA_DELTA           )
    )
    u_sigma_delta_generator
    (
        .i_clk       ( test_clk          ),
        .i_rst       ( test_rst          ),
        .i_enable    ( test_i_enable     ),
        .i_sigma ( test_sigma    ),
        .i_delta ( test_delta    ),
        .o_enable    ( test_enable )
    );
