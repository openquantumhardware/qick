`timescale 1ns / 1ps

module adaptive_sweep#(
    parameter [31:0] INIT_START = 32'd100, // Initial start frequency
    parameter [31:0] INIT_END = 32'd200, // Initial end frequency
    parameter [31:0] INIT_STEP = 32'd1, // Frequency step per point
    parameter [31:0] SHRINK = 32'd10 // Shrink from each side per 
)(
    input wire clk,
    input wire rst_n,
    
    //QICK Peripheral
    input wire qtag_en_i ,
    input wire [4:0] qtag_op_i ,
    input wire [31:0] qtag_dt1_i,
    input wire [31:0] qtag_dt2_i,
    input wire [31:0] qtag_dt3_i,
    input wire [31:0] qtag_dt4_i,
    output reg qtag_rdy_o,
    output reg [31:0] qtag_dt1_o,
    output reg [31:0] qtag_dt2_o,
    output reg qtag_vld_o,
    output reg qtag_flag_o
    
);

    localparam [4:0] OP_GET_NEXT = 5'd1, OP_GET_STEP = 5'd2, OP_RESET = 5'd3;

    // ---- State Registers ----
    reg [31:0] curr_start;
    reg [31:0] curr_end;
    reg [31:0] curr_step;
    reg [31:0] iter_count;
    reg done;

    // ---- Next-value wires ----
    wire [31:0] next_start;
    wire [31:0] next_end;
    wire next_done;

    assign next_start = curr_start + SHRINK;
    assign next_end = curr_end   - SHRINK;
    assign next_done = (next_start >= next_end) ? 1'b1 : 1'b0;

    // ---- Enable edge detection ----
    reg en_d;
    wire en_rise;

    assign en_rise = qtag_en_i & ~en_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            en_d <= 1'b0;
        else
            en_d <= qtag_en_i;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_start <= INIT_START;
            curr_end <= INIT_END;
            curr_step <= INIT_STEP;
            iter_count <= 32'd0;
            done <= 1'b0;
            qtag_rdy_o <= 1'b1;
            qtag_vld_o <= 1'b0;
            qtag_dt1_o <= 32'd0;
            qtag_dt2_o <= 32'd0;
            qtag_flag_o <= 1'b0;
        end else begin
            qtag_vld_o <= 1'b0;

            if (en_rise) begin
                case (qtag_op_i)
                    OP_GET_NEXT: begin
                        qtag_dt1_o <= curr_start;
                        qtag_dt2_o <= curr_end;
                        qtag_vld_o <= 1'b1;
                        qtag_flag_o <= ~next_done;

                        if (!done) begin
                            curr_start <= next_start;
                            curr_end <= next_end;
                            done <= next_done;
                            iter_count <= iter_count + 32'd1;
                        end
                    end

                    OP_GET_STEP: begin
                        qtag_dt1_o <= curr_step;
                        qtag_dt2_o <= iter_count;
                        qtag_flag_o <= ~done;
                        qtag_vld_o <= 1'b1;
                    end

                    OP_RESET: begin
                        curr_start <= INIT_START;
                        curr_end <= INIT_END;
                        curr_step <= INIT_STEP;
                        iter_count <= 32'd0;
                        done <= 1'b0;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
