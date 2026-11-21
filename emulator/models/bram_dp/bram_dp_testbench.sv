`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: HRL Clinic
// Engineer: Abraham Rock
// 
// Create Date: 10/06/2025 02:55:41 PM
// Design Name: 
// Module Name: bmem_testbench
// Project Name: 
// Target Devices: n/a
// Tool Versions: 
// Description: testbench the outputs of the open source and ip blocks
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// use with bram_dp_behav (OSS)
// found in firmware > openhdl

// use with bram_dp_xpm (IP)
// found in firmware > hdl


module bram_dp_testbench #(parameter int ADDR_WIDTH = $clog2(1024),
                        parameter int DATA_WIDTH = 32)();
    
    // common inputs
    logic RSTA, CLKA, ENA, WEA, DOA_DV;
    logic RSTB, CLKB, ENB, WEB, DOB_DV;
    logic [ADDR_WIDTH-1:0] ADDRA, ADDRB;
    logic [DATA_WIDTH-1:0] DIA, DIB;
    
    // OSS Outputs
    logic [DATA_WIDTH-1:0] DOA_OSS, DOB_OSS;
    
    // IP Outputs
    logic [DATA_WIDTH-1:0] DOA_IP, DOB_IP;
    
    // open source module
    // bram_dp_behav #(.OUTPUT_REG(1), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    //                 oss_dut(    RSTA, CLKA, ENA, REA, WEA, ADDRA, DIA, DOA_DV, DOA_OSS,
    //                             RSTB, CLKB, ENB, REB, WEB, ADDRB, DIB, DOB_DV, DOB_OSS);

    bram_dp_behav #(.OUT_REG_ENA(1), .N(ADDR_WIDTH), .B(DATA_WIDTH))
                ip_dut(CLKA, CLKB, ENA, ENB, WEA, WEB, ADDRA, ADDRB, DIA, DIB, DOA_OSS, DOB_OSS);
                                
    // IP module
    bram_dp_xpm #(.OUT_REG_ENA(1), .N(ADDR_WIDTH), .B(DATA_WIDTH))
                    ip_dut(CLKA, CLKB, ENA, ENB, WEA, WEB, ADDRA, ADDRB, DIA, DIB, DOA_IP, DOB_IP);
    
    // Generate Clock
    always begin
        CLKA = 1;
        #5;
        CLKA = 0;
        #5;
    end

    always begin
        #9;
        CLKB = 1;
        #9;
        CLKB = 0;
        #9;
    end
    
    // Pulse Reset and set some logic
    initial begin
        RSTA = 1; RSTB = 1;
        #22;
        RSTA = 0; RSTB=0;
        ENA = 1; ENB = 1;
        REA = 0; WEA = 0;
        REB = 0; WEB = 0;
    end
    
    // clk through binary signal inputs and assert outputs
    // bit vector for one port
    localparam TOT_VEC_WIDTH = DATA_WIDTH + ADDR_WIDTH + 2;
    
    // individual vectors for a port and b port
    logic [TOT_VEC_WIDTH-1:0] vec_port_a, vec_port_b;
    
    always @(posedge CLKA) begin
        if (~RSTA) begin
            vec_port_a <= vec_port_a + 1;
        end else begin
            vec_port_a <= 0;
        end
    end
    
    always @(posedge CLKB) begin
        if (~RSTB) begin
            vec_port_b <= vec_port_b + 1;
        end else begin
            vec_port_b <= 0;
        end
    end
    
    // assign inputs to our counter
    assign WEA = vec_port_a[0];                             assign WEB = vec_port_b[0];
    assign REA = vec_port_a[1];                             assign REB = vec_port_b[1];
    assign ADDRA = vec_port_a[ADDR_WIDTH+1:2];              assign ADDRB = vec_port_b[ADDR_WIDTH+1:2];
    assign DIA = vec_port_a[TOT_VEC_WIDTH-1:ADDR_WIDTH+2];  assign DIB = vec_port_b[TOT_VEC_WIDTH-1:ADDR_WIDTH+2];
    
    // check if outputs are equivalent on falling edge
    // Port A
    always @(negedge CLKA) begin
        if (~RSTA) begin
            assert (DOA_OSS == DOA_IP) else begin
                $error("Error: DOA_OSS = %h and DOA_IP = %h", DOA_OSS, DOA_IP);
            end
        end
    end
    
    // Port B
    always @(negedge CLKB) begin
        if (~RSTB) begin
            assert (DOB_OSS == DOB_IP) else begin
                $error("Error: DOB_OSS = %h and DOB_IP = %h", DOB_OSS, DOB_IP);
            end
        end
    end
    
endmodule
