`timescale 1ns / 1ps

module amplitude_calculator #(
    parameter MAX_AVG     = 64,
    parameter ACCUM_WIDTH = 52
)(
    input                            clk,
    input                            rst_n,

    input                            s_axis_tvalid,
    input  [31:0]                    s_axis_tdata,

    input                            trigger,
    input  [31:0]                    nsamp,
    input  [$clog2(MAX_AVG)-1:0]     averager_value,

    output reg [ACCUM_WIDTH-1:0]     m_axis_tdata,
    output reg                       m_axis_tvalid,
    output reg                       one_burst_done
);

    // ------------------------------------------------------------------
    //  Stage 0 – latch IQ so the DSP A/B input regs see stable data
    // ------------------------------------------------------------------
    reg signed [15:0] i_s0, q_s0;
    reg               v_s0;

    always @(posedge clk) begin
        if (!rst_n) begin
            i_s0 <= 0; q_s0 <= 0; v_s0 <= 0;
        end else begin
            i_s0 <= s_axis_tdata[31:16];
            q_s0 <= s_axis_tdata[15:0];
            v_s0 <= s_axis_tvalid;
        end
    end

    // ------------------------------------------------------------------
    //  Stage 1 – i*i and q*q (each synthesises into one DSP48 with M-reg)
    // ------------------------------------------------------------------
    (* use_dsp = "yes" *) reg [31:0] ii_s1, qq_s1;
    reg                              v_s1;

    always @(posedge clk) begin
        if (!rst_n) begin
            ii_s1 <= 0; qq_s1 <= 0; v_s1 <= 0;
        end else begin
            ii_s1 <= i_s0 * i_s0;
            qq_s1 <= q_s0 * q_s0;
            v_s1  <= v_s0;
        end
    end

    // ------------------------------------------------------------------
    //  Stage 2 – i*i + q*q  (32-bit add, one CARRY8 chain)
    // ------------------------------------------------------------------
    reg [32:0] power_s2;
    reg        v_s2;

    always @(posedge clk) begin
        if (!rst_n) begin
            power_s2 <= 0; v_s2 <= 0;
        end else begin
            power_s2 <= {1'b0, ii_s1} + {1'b0, qq_s1};
            v_s2     <= v_s1;
        end
    end

    // ------------------------------------------------------------------
    //  Control FSM + accumulator
    //
    //  "run" state is pipelined 3 cycles (run_d2) so the accumulator
    //  only counts power_s2 samples that originated in state==RUN.
    // ------------------------------------------------------------------
    localparam IDLE = 1'b0;
    localparam RUN  = 1'b1;
    reg state;

    reg [31:0]                  sample_cnt;
    reg [$clog2(MAX_AVG)-1:0]   burst_cnt;
    reg [ACCUM_WIDTH-1:0]       accumulator;
    reg [ACCUM_WIDTH-1:0]       sum_reg;
    reg                         finish_delay;
    reg [31:0]                  nsamp_latched;

    reg run_d0, run_d1, run_d2;

    always @(posedge clk) begin
        if (!rst_n) begin
            run_d0 <= 0; run_d1 <= 0; run_d2 <= 0;
        end else begin
            run_d0 <= (state == RUN);
            run_d1 <= run_d0;
            run_d2 <= run_d1;
        end
    end

    wire acc_en = run_d2 & v_s2;

    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= IDLE;
            sample_cnt     <= 0;
            burst_cnt      <= 0;
            accumulator    <= 0;
            sum_reg        <= 0;
            m_axis_tvalid  <= 0;
            m_axis_tdata   <= 0;
            one_burst_done <= 0;
            finish_delay   <= 0;
            nsamp_latched  <= 0;
        end else begin
            m_axis_tvalid  <= 0;
            one_burst_done <= 0;

            case (state)
                IDLE: begin
                    if (trigger) begin
                        state         <= RUN;
                        sample_cnt    <= 0;
                        accumulator   <= 0;
                        nsamp_latched <= nsamp;
                    end
                end

                RUN: begin
                    if (acc_en) begin
                        accumulator <= accumulator + power_s2;
                        sample_cnt  <= sample_cnt + 1;
                        if (sample_cnt == nsamp_latched - 1)
                            finish_delay <= 1;
                    end

                    // Wait for the 3-stage pipeline to drain (acc_en goes
                    // low) before snapping the accumulator into sum_reg.
                    if (finish_delay && !acc_en) begin
                        one_burst_done <= 1;

                        sum_reg   <= sum_reg + accumulator;
                        burst_cnt <= burst_cnt + 1;

                        if (burst_cnt + 1 >= averager_value) begin
                            m_axis_tdata  <= sum_reg + accumulator;
                            m_axis_tvalid <= 1;
                            burst_cnt     <= 0;
                            sum_reg       <= 0;
                        end

                        accumulator  <= 0;
                        sample_cnt   <= 0;
                        finish_delay <= 0;
                        state        <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
