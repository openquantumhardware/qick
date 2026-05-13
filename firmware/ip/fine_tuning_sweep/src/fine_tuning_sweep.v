`timescale 1ns / 1ps

module fine_tuning_sweep #(
    parameter MAX_AVG = 64
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        qtag_en_i,
    input  wire [4:0]  qtag_op_i,
    input  wire [31:0] qtag_dt1_i,
    input  wire [31:0] qtag_dt2_i,
    input  wire [31:0] qtag_dt3_i,
    input  wire [31:0] qtag_dt4_i,
    output reg         qtag_rdy_o,
    output reg  [31:0] qtag_dt1_o,
    output reg  [31:0] qtag_dt2_o,
    output reg         qtag_vld_o,

    input  wire        trigger,
    input  wire [31:0] nsamp,
    input  wire        s_axis_tvalid,
    input  wire [31:0] s_axis_tdata
);

    reg sticky_finish;
    reg sticky_freq_valid;
    
    wire [31:0] freq_word;
    wire        freq_valid;
    wire        finish;
    
    reg en_d;
    wire en_rise;

    reg [31:0] reg_start_freq;
    reg [31:0] reg_stop_freq;
    reg [$clog2(MAX_AVG)-1:0] reg_averager_value;
    
    reg [31:0] reg_first_sweep_step;
    reg [31:0] reg_second_sweep_step;
    reg [31:0] reg_second_sweep_window;

    wire w_start_pulse;

    assign en_rise = qtag_en_i & ~en_d;
    
    wire w_read_pulse  = en_rise & (qtag_op_i == 5'd2);
    assign w_start_pulse = en_rise & (qtag_op_i == 5'd1);
    
    always @(posedge clk) begin
        if (!rst_n) begin
            sticky_finish     <= 1'b0;
            sticky_freq_valid <= 1'b0;
        end else begin
            if (w_start_pulse) begin
                sticky_finish     <= 1'b0;
                sticky_freq_valid <= 1'b0;
            end else begin
                // FINISH logic 
                if (finish) sticky_finish <= 1'b1;

                // FREQ_VALID logic
                if (freq_valid) begin
                    sticky_freq_valid <= 1'b1; 
                end else if (w_read_pulse) begin
                    sticky_freq_valid <= 1'b0; // CLEAR to 0 when software reads
                end
            end
        end
    end

    always @(posedge clk ) begin
        if (!rst_n)
            en_d <= 1'b0;
        else
            en_d <= qtag_en_i;
    end

    always @(posedge clk ) begin
        if (!rst_n) begin
            qtag_rdy_o              <= 1'b1;
            qtag_vld_o              <= 1'b0;
            qtag_dt1_o              <= 32'd0;
            qtag_dt2_o              <= 32'd0;            
            reg_start_freq          <= 32'd0;
            reg_stop_freq           <= 32'd0;
            reg_averager_value      <= 0;
            reg_first_sweep_step    <= 32'd0;
            reg_second_sweep_step   <= 32'd0;
            reg_second_sweep_window <= 32'd0;
        end else begin
            qtag_vld_o <= 1'b0; // Default to 0 unless reading back data

            if (en_rise) begin
                case (qtag_op_i)
                    5'd0: begin
                        // OPCODE 0: Set basic sweep bounds and averaging
                        reg_start_freq     <= qtag_dt1_i;
                        reg_stop_freq      <= qtag_dt2_i;
                        reg_averager_value <= qtag_dt3_i[$clog2(MAX_AVG)-1:0];
                        reg_first_sweep_step    <= qtag_dt4_i;
                    end
                    5'd1: begin
                        // OPCODE 1: Start Processing
                        // Handled by w_start_pulse. No register updates needed.
                    end
                    5'd2: begin
                        // OPCODE 2: Read Results
                        qtag_dt1_o <= freq_word;
                        qtag_dt2_o <= {30'd0, sticky_freq_valid, sticky_finish}; 
                        qtag_vld_o <= 1'b1;             
                    end
                    5'd3: begin
                        // NEW OPCODE 3: Set sweep step sizes and window
                        //reg_first_sweep_step    <= qtag_dt1_i;
                        reg_second_sweep_step   <= qtag_dt2_i;
                        reg_second_sweep_window <= qtag_dt3_i;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end
    
    wire [63:0] w_amplitude_data;  
    wire        w_amplitude_valid;
    wire        w_one_burst_done;
      
    peak_finder #(        
        .ADC_DAC_freq  (64'd491520000), 
        .MAX_AVG       (64),
        .ACCUM_WIDTH   (64)
    ) u_peak_finder_v2 (
        .clk                 (clk),               
        .rstn                (rst_n),             

        .start               (w_start_pulse),             
        .start_freq          (reg_start_freq),        
        .stop_freq           (reg_stop_freq),         
        
        // NEW CONNECTIONS
        .first_sweep_step    (reg_first_sweep_step),
        .second_sweep_step   (reg_second_sweep_step),
        .second_sweep_window (reg_second_sweep_window),

        .amplitude_valid     (w_amplitude_valid), 
        .amplitude_data      (w_amplitude_data),  
        .one_sample_done     (w_one_burst_done),  

        .freq_word           (freq_word),         
        .freq_valid          (freq_valid),        
        .finish              (finish)             
    );

    amplitude_calculator #(
        .MAX_AVG       (64),
        .ACCUM_WIDTH   (64)
    ) u_amplitude_calculator (
        .clk            (clk),                
        .rst_n          (rst_n),              

        .s_axis_tvalid  (s_axis_tvalid),      
        .s_axis_tdata   (s_axis_tdata),       

        .trigger        (trigger),            
        .nsamp          (nsamp),              
        .averager_value (reg_averager_value),     

        .m_axis_tdata   (w_amplitude_data),   
        .m_axis_tvalid  (w_amplitude_valid),  
        .one_burst_done (w_one_burst_done)    
    );

endmodule