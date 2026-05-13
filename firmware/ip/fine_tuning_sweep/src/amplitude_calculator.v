`timescale 1ns / 1ps  

module amplitude_calculator #(
    //parameter MAX_NSAMP = 1024,
    parameter MAX_AVG   = 64,
    parameter ACCUM_WIDTH = 64
)(
    input clk,
    input rst_n,

    input s_axis_tvalid,
    input [31:0] s_axis_tdata,

    input trigger,
    input [31:0] nsamp, //$clog2(MAX_NSAMP)-1:0 // QICK sisteminde 32 bit.
    input [$clog2(MAX_AVG)-1:0] averager_value,

    output reg [ACCUM_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    output reg one_burst_done
);

    wire signed [15:0] i = s_axis_tdata[31:16];
    wire signed [15:0] q = s_axis_tdata[15:0];

    wire [31:0] power = (i * i) + (q * q);

    localparam IDLE = 0;
    localparam RUN  = 1;

    reg state;

    reg [31:0] sample_cnt;
    reg [$clog2(MAX_AVG)-1:0]   burst_cnt;

    reg [ACCUM_WIDTH-1:0] accumulator; 
    reg [ACCUM_WIDTH-1:0] sum_reg;     

    reg finish_delay;
    
    reg [31:0] nsamp_latched;
    
    always @(posedge clk ) begin
        if (!rst_n) begin
            state <= IDLE;
            sample_cnt <= 0;
            burst_cnt <= 0;
            accumulator <= 0;
            sum_reg <= 0;
            m_axis_tvalid <= 0;
            m_axis_tdata <= 0;
            one_burst_done <= 0;
            finish_delay <= 0;
        end else begin
            m_axis_tvalid <= 0;
            one_burst_done <= 0;

            case (state)
                IDLE: begin
                    if (trigger) begin
                        state <= RUN;
                        sample_cnt <= 0;
                        accumulator <= 0;
                        
                        nsamp_latched<=nsamp;
                    end
                end

                RUN: begin
                    if (s_axis_tvalid) begin
                        accumulator <= accumulator + power;
                        sample_cnt <= sample_cnt + 1;

                        if (sample_cnt == nsamp_latched - 1) begin
                            finish_delay <= 1;
                        end
                    end

                    if (finish_delay) begin
                        one_burst_done <= 1;

                        sum_reg <= sum_reg + accumulator;
                        burst_cnt <= burst_cnt + 1;

                        if (burst_cnt + 1 >= averager_value) begin
                            m_axis_tdata  <= sum_reg + accumulator; 
                            m_axis_tvalid <= 1;

                            burst_cnt <= 0;
                            sum_reg <= 0;
                        end

                        accumulator <= 0;
                        sample_cnt <= 0;
                        finish_delay <= 0;
                        state <= IDLE; 
                    end
                end
            endcase
        end
    end

endmodule