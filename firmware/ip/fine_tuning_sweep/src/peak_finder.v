module peak_finder#(                
    parameter first_sweep  = 5000000,  // 10 MHz step
    parameter second_sweep = 1000000,    // 1 MHz step
    parameter second_window = 5000000,   //+-5MHz fine tuning aral???
    parameter ADC_DAC_freq = 64'd614400000, //491.52 MHz
    //parameter N_SAMP = 256, // averaging yapmak için gerekli, sample say?s? kadar olmal?
    //parameter ACCUM_WIDTH = 32 + $clog2(N_SAMP)
    //parameter averager_value = 3,
    //parameter ACCUM_WIDTH = (((32 + $clog2(N_SAMP) + $clog2(averager_value))+7)/8)*8
    //parameter MAX_NSAMP = 1024,
    parameter MAX_AVG   = 64,
    parameter ACCUM_WIDTH = 64
)(
    input start,
    input [31:0] start_freq,   // CW format
    input [31:0] stop_freq,    // CW format
    input [31:0] first_sweep_step,

    input [31:0] second_sweep_step,
    input [31:0] second_sweep_window,
    //input [$clog2(MAX_AVG)-1:0] averager_value,
    //input [31:0] N_SAMP, //$clog2(MAX_NSAMP)-1:0] 32 bit yapt?m çünkü QICK sisteminde 32 bit.
    
    input amplitude_valid,
    input [ACCUM_WIDTH-1:0] amplitude_data,

    input clk,
    input rstn,

    output reg [31:0] freq_word,
    output reg freq_valid,
    
    output reg finish,
    
    input one_sample_done
);

localparam IDLE      = 3'd0;
localparam SEND_FREQ = 3'd1;
localparam WAIT_MEAS = 3'd2;
localparam FINE_INIT = 3'd3;
//localparam FINE_SWEEP = 3'd4;

localparam DDS_MULT  = 64'd16;
localparam DDS_CLK   = ADC_DAC_freq;      // 491.52 MHz
localparam TWO32     = 64'd4294967296;     // 2^32

reg [2:0] state;

reg [31:0] cw_current;
reg [31:0] cw_stop;
reg [31:0] cw_step;

//reg [31:0] fine_start;
//reg [31:0] fine_stop;
//reg [31:0] cw_step_fine;
reg fine_tune;

reg [ACCUM_WIDTH-1:0] max_amplitude;
reg [31:0] freq_at_max;

reg [63:0] temp;
reg freq_valid_d;
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        state <= IDLE;
        freq_valid <= 0;
        freq_word <= 0;
        cw_current <= 0;
        cw_stop <= 0;
        cw_step <= 0;
        max_amplitude <= 0;
        freq_at_max <= 0;
        freq_valid_d<=0;
//        fine_start<=0;
//        fine_stop<=0;
//        cw_step_fine<=0;
        fine_tune<=0;
        finish<=0;
    end
    else begin
        freq_valid <= freq_valid_d;
        freq_valid_d<=0;
        finish<=0;
        case(state)
        
        IDLE: begin
            if(start) begin
                cw_current <= start_freq;
                cw_stop    <= stop_freq;
                cw_step    <= first_sweep_step; //32'd2184533; //32'd5461333;//(first_sweep * TWO32) / (DDS_MULT * DDS_CLK);

                max_amplitude <= 0;
                freq_at_max   <= 0;
                
                //cw_step_fine <= (second_sweep * TWO32) / (DDS_MULT * DDS_CLK);
                
                state <= SEND_FREQ;
            end
        end

        
        SEND_FREQ: begin
            freq_word  <= cw_current;
            freq_valid_d <= 1;
            //freq_valid<=freq_valid_d;
            state <= WAIT_MEAS;
        end

        
        WAIT_MEAS: begin
            if (one_sample_done) begin
                freq_word  <= cw_current;
                freq_valid_d <= 1;
            end
            if(amplitude_valid) begin
                
                if(amplitude_data > max_amplitude) begin
                    max_amplitude <= amplitude_data;
                    freq_at_max   <= cw_current;
                end

                
                if(cw_current + cw_step >= cw_stop) begin
                    // give output max amplitude frequency
                    //freq_word  <= freq_at_max;
                    //freq_valid <= 1;
                    //state      <= IDLE;
                    if (fine_tune) begin
                        freq_word  <= freq_at_max;
                        freq_valid_d <= 1;
                        finish<=1;
                        state      <= IDLE;
                        fine_tune<=0;
                    end else begin
                        state <= FINE_INIT;
                        freq_valid_d<=0;
                    end
                end
                else begin
                    cw_current <= cw_current + cw_step;
                    state <= SEND_FREQ;
                end
            end
        end
        
        FINE_INIT: begin
            //temp = (second_window * TWO32) / (DDS_MULT * DDS_CLK);
            cw_step <= second_sweep_step; //32'd436906;//32'd546133;//(second_sweep * TWO32) / (DDS_MULT * DDS_CLK);
            
            cw_stop  <= (freq_at_max + second_sweep_window > stop_freq) ? stop_freq : freq_at_max + second_sweep_window; //32'd19107198; //32'd19653332; //freq_at_max + temp;

            cw_current <= (freq_at_max - second_sweep_window < start_freq) ? start_freq : freq_at_max - second_sweep_window; //32'd14738132;//32'd14192000; //freq_at_max - temp;
            fine_tune<=1;
            max_amplitude <= 0; // buras? s?f?rlamasa da olabilir. Daha çok design choice gibi
            
            state <= SEND_FREQ;
        end

        endcase
    end
end

endmodule //