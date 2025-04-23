/***********************************************
 * 
 *  Copyright (C) 2022 - Stratum Labs
 * 
 *  Project: ADS-B
 *  Author: Leandro Echevarria <leo.echevarria@stratum-labs.com>
 * 
 *  File: sigma_delta_generator.sv
 *  Description: generates a configurable enable pattern using
 *  sigma-delta modulo logic based on inputs i_delta and i_sigma
 * 
 * 
 * ********************************************/

module sigma_delta_generator
#(
    parameter                           NB_SIGMA_DELTA = 16
)
(
    input  logic                        i_clk              ,
    input  logic                        i_rst              ,
    
    input  logic                        i_enable           ,
    input  logic [NB_SIGMA_DELTA  -1:0] i_delta            ,
    input  logic [NB_SIGMA_DELTA  -1:0] i_sigma            ,

    output logic                        o_enable
);

    logic [(NB_SIGMA_DELTA+1) -1:0] sigma_delta_counter     ;
    logic [(NB_SIGMA_DELTA+1) -1:0] sigma_delta_counter_next;
    
    assign sigma_delta_counter_next = sigma_delta_counter + i_delta;

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            sigma_delta_counter <= '0;
        end else begin
            if (i_enable) sigma_delta_counter <= sigma_delta_counter_next;
            
            if (sigma_delta_counter_next >= i_sigma) begin
                sigma_delta_counter <= sigma_delta_counter_next - i_sigma;
            end
        end
    end 

    // OUTPUT ASSIGNMENTS
    assign o_enable = ~i_rst & i_enable & (sigma_delta_counter < i_delta);

endmodule
