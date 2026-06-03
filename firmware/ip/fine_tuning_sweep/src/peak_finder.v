module peak_finder #(
    parameter ACCUM_WIDTH = 52
)(
    input  wire                   clk,
    input  wire                   rstn,

    // OP 3: clear running max before each pass
    input  wire                   reset_max,

    // OP 1: latch the freq the ASM is about to measure
    input  wire                   set_current_freq,
    input  wire [31:0]            current_freq_i,

    // from amplitude_calculator (via CDC)
    input  wire                   amp_valid,
    input  wire [ACCUM_WIDTH-1:0] amp_data,

    // to wrapper for OP 2 read
    output reg  [ACCUM_WIDTH-1:0] max_amplitude,
    output reg  [31:0]            freq_at_max
);

(* mark_debug = "true" *) reg [31:0] current_freq_r;

always @(posedge clk) begin
    if (!rstn) begin
        max_amplitude  <= 0;
        freq_at_max    <= 0;
        current_freq_r <= 0;
    end else begin
        if (set_current_freq)
            current_freq_r <= current_freq_i;

        if (reset_max) begin
            max_amplitude <= 0;
            freq_at_max   <= 0;
        end else if (amp_valid && amp_data > max_amplitude) begin
            max_amplitude <= amp_data;
            freq_at_max   <= current_freq_r;
        end
    end
end

endmodule
