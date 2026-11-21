//-----------------------------------------------------------------------------
// Title      : Direct Digital Synthesis (DDS) Behavioral Model
// Project    : HRL Clinic 2025-26
//-----------------------------------------------------------------------------
// File       : dds_behavioral_model.sv
// Author     : Jessic Liu
// Date       : 09/16/2025
//-----------------------------------------------------------------------------

// `timescale 1ns / 1ps

module dds_behavioral_model # (
    // Reserve for Parameters
    parameter int       LUT_SIZE        = 256, // Lookup Table size
    parameter int       PHASE_WIDTH     = 32, // phase width
    parameter int       DDS_LATENCY     = 8,  // MUST MATCH DDS Compiler GUI Latency
    parameter int       NEGATIVE_SINE   = 0,  // Invert polarity of sine wave
    parameter int       NEGATIVE_COSINE = 0   // Invert polarity of cosine wave
) (
    input   logic        aclk, // clock at @ ??? MHz
    input   logic        s_axis_phase_tvalid,
    input   logic [71:0] s_axis_phase_tdata,
    output  logic        m_axis_data_tvalid,
    output  logic [31:0] m_axis_data_tdata
);

initial begin
    if (DDS_LATENCY < 2 || DDS_LATENCY > 21) begin
        $fatal(1, "DDS_LATENCY must be between 2 and 21 (inclusive) to match valid latency settings in Xilinx DDS Compiler GUI. Current value: %0d", DDS_LATENCY);
    end
end

logic [PHASE_WIDTH-1:0] phase_inc;     // PINC from AXIS
logic [PHASE_WIDTH-1:0] phase_acc;     // phase accumulator result
logic [PHASE_WIDTH-1:0] phase_seed;    // initial phase
logic        sync;          // strobe bit


// --------- UNPACK s_axis_phase_tdata --------------------------
// s_axis_phase_tdata format
// |------------|------------|------------|------------|
// |    71 .. 65|          64|    63 .. 32|     31 .. 0|
// |------------|------------|------------|------------|
// |       7'h00| sync_reg_r7| phase_v1_r1|        PINC|
// |------------|------------|------------|------------|
// Phase Increment (PINC): 32 bit, phase step per clock the downstream DDS accumulator should add.
// initial phase (phase_v1_r1): 32 bit, phase seed to load into the DDS accumulator on a sync/load event.
// sync_reg_r7: 1, 1-bit strobe telling the DDS to load those values this cycle.

assign phase_inc    = s_axis_phase_tdata[31:0];
assign phase_seed   = s_axis_phase_tdata[63:32];
assign sync         = s_axis_phase_tdata[64];


// --------- PHASE ACCUMULATOR -------------------
always_ff @(posedge aclk) begin
    if(s_axis_phase_tvalid) begin
        if(sync) begin
            phase_acc <= phase_seed; // load seed value on sync strobe
        end else begin
            phase_acc <= phase_acc + phase_inc;
        end
    end
end

// --------- SINE LUT ----------------------------
localparam int LUT_ADDR_BITS = (LUT_SIZE <= 1) ? 1 : $clog2(LUT_SIZE); // set the LUT address bit to be log2(LUT_SIZE)
logic [LUT_ADDR_BITS-1: 0] lut_addr;
assign lut_addr = phase_acc[PHASE_WIDTH-1 -:LUT_ADDR_BITS]; // address = top LUT_ADDR_BIT of phase_acc

// ROM (synchronous read -> 1-cycle latency)
localparam int DEPTH = (1 << LUT_ADDR_BITS);
(* rom_style = "block", ram_style = "block" *)
logic [31:0] rom [0:DEPTH-1];

localparam real TWO_PI = 6.28318530717958647692;

function automatic logic signed [15:0] real_to_q15(input real value);
    real clamped_value;
    int rounded_value;
begin
    if (value >= 1.0) begin
        clamped_value = 0.999969482421875;
    end else if (value < -1.0) begin
        clamped_value = -1.0;
    end else begin
        clamped_value = value;
    end

    if (clamped_value >= 0.0) begin
        rounded_value = $rtoi(clamped_value * 32767.0 + 0.5);
    end else begin
        rounded_value = $rtoi(clamped_value * 32767.0 - 0.5);
    end

    real_to_q15 = rounded_value;
end
endfunction

function automatic logic [31:0] make_rom_word(input int unsigned index);
    real theta;
    logic signed [15:0] sine_q15;
    logic signed [15:0] cosine_q15;
begin
    theta = (TWO_PI * real'(index)) / real'(DEPTH);
    sine_q15 = real_to_q15($sin(theta));
    cosine_q15 = real_to_q15($cos(theta));
    if (NEGATIVE_SINE) sine_q15 = -sine_q15;
    if (NEGATIVE_COSINE) cosine_q15 = -cosine_q15;
    make_rom_word = {sine_q15, cosine_q15};
end
endfunction

initial begin : init_rom
    integer i;
    for (i = 0; i < DEPTH; i++) begin
        rom[i] = make_rom_word(i);
    end
end

 // --------- DATA PIPELINE TO MATCH DDS_LATENCY -----------------
    // data_pipe[0] gets ROM output for current lut_addr (1st stage)
    // data_pipe[DDS_LATENCY-1] drives AXIS tdata (total latency = DDS_LATENCY)
    logic [31:0] data_pipe [0:DDS_LATENCY-1];

    // Stage 0: ROM read
    assign data_pipe[0] = rom[lut_addr];

    integer k;
    always_ff @(posedge aclk) begin
        if (s_axis_phase_tvalid) begin
            // Remaining pipeline stages
            for (k = 1; k < DDS_LATENCY; k++) begin
                data_pipe[k] <= data_pipe[k-1];
            end
        end
    end

    assign m_axis_data_tdata = data_pipe[DDS_LATENCY-1];

    wire [15:0] tdata_real = m_axis_data_tdata[15:0];
    wire [15:0] tdata_imag = m_axis_data_tdata[31:16];

    logic [DDS_LATENCY-1:0] valid_pipe = '0;

    always_ff @(posedge aclk) begin
        if (s_axis_phase_tvalid) begin
            valid_pipe <= {valid_pipe[DDS_LATENCY-2:0], 1'b1}; // shift in 1's when input is valid
        end
    end

    assign m_axis_data_tvalid = valid_pipe[DDS_LATENCY-1] & s_axis_phase_tvalid; // output valid when last stage of pipeline is valid and input is valid

endmodule