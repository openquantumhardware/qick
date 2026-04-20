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
    parameter string    INIT_FILE       = "sine_cos_full32.hex", // ROM for LUT
    parameter int       DDS_LATENCY     = 10,  // MUST MATCH DDS Compiler GUI Latency
    // First-order Taylor correction on the phase LUT quantization.
    //   sin(theta + d) ~= sin(theta) + cos(theta) * d
    //   cos(theta + d) ~= cos(theta) - sin(theta) * d
    // Lifts SFDR from ~48 dB (8-bit LUT only) to well beyond 90 dB, matching
    // the Xilinx dds_compiler "Noise_Shaping=Auto" behavior.  Pipeline latency
    // is unchanged (correction is combinational at the output stage), so the
    // RO_LATENCY_PAD shift-register in tb_qick_emu_verilator does NOT need to
    // be recalibrated.  Set to 1'b0 to revert to the raw LUT-only output.
    parameter bit       TAYLOR_CORRECT  = 1'b1
) (
    input   logic        aclk, // clock at @ ??? MHz
    input   logic        s_axis_phase_tvalid,
    input   logic [71:0] s_axis_phase_tdata,
    output  logic        m_axis_data_tvalid,
    output  logic [31:0] m_axis_data_tdata
);

logic [PHASE_WIDTH-1:0] phase_inc;     // PINC from AXIS
logic [PHASE_WIDTH-1:0] phase_acc = 0;     // phase accumulator result
logic [PHASE_WIDTH-1:0] phase_seed;    // initial phase
logic        sync;          // strobe bit
// logic [31:0] m_axis_data_tdata_temp = '0;


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

assign m_axis_data_tvalid = 1;

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
logic signed [31:0] rom [0:DEPTH-1];

initial begin : init_rom
        integer i;
        for (i = 0; i < DEPTH; i++) rom[i] = '0;
        $readmemh(INIT_FILE, rom);
        $display("ROM init from %s: DEPTH=%0d, WIDTH=32", INIT_FILE, DEPTH);
    end

 // --------- DATA PIPELINE TO MATCH DDS_LATENCY -----------------
    // data_pipe[0] gets ROM output for current lut_addr (1st stage)
    // data_pipe[DDS_LATENCY-1] drives AXIS tdata (total latency = DDS_LATENCY)
    logic signed [31:0] data_pipe [0:DDS_LATENCY-1];

    // Fractional phase (bits below the LUT address) shadows data_pipe so the
    // Taylor correction at the output stage uses the matching phase slice.
    localparam int PHASE_FRAC_W = PHASE_WIDTH - LUT_ADDR_BITS;   // 24 with defaults
    logic [PHASE_FRAC_W-1:0] frac_pipe [0:DDS_LATENCY-1];
    logic [PHASE_FRAC_W-1:0] frac_in;
    assign frac_in = phase_acc[PHASE_FRAC_W-1:0];

    integer k;
    always_ff @(posedge aclk) begin
        // Stage 0: ROM read + fractional-phase capture
        data_pipe[0] <= rom[lut_addr];
        frac_pipe[0] <= frac_in;

        // Remaining stages
        for (k = 1; k < DDS_LATENCY; k++) begin
            data_pipe[k] <= data_pipe[k-1];
            frac_pipe[k] <= frac_pipe[k-1];
        end
    end

    // --------- FIRST-ORDER TAYLOR CORRECTION ----------------------
    // Output LUT entry is {sin[31:16], cos[15:0]} in Q1.15.
    //   theta_true   = 2*pi * phase_acc / 2^PHASE_WIDTH
    //                = theta_k + d,  where d = 2*pi * frac / 2^PHASE_WIDTH
    //   sin_Q15_true ~= sin_Q15 + cos_Q15 * d
    //                = sin_Q15 + (cos_Q15 * frac * TWO_PI_Q15) >> (PHASE_WIDTH+15)
    // For PHASE_WIDTH=32 and TWO_PI_Q15 = round(2*pi * 2^15) = 205887, the
    // required right shift is 47.  Peak |correction| <= 2*pi * 2^15 / 256 ~= 804,
    // so the final add to sin_Q15 always fits in Q1.15.
    localparam logic [17:0] TWO_PI_Q15 = 18'd205887;
    localparam int          CORR_SHIFT = PHASE_WIDTH + 15;      // 47 with defaults

    logic signed [15:0]      sin_coarse, cos_coarse;
    logic [PHASE_FRAC_W-1:0] frac_out;
    assign sin_coarse = data_pipe[DDS_LATENCY-1][31:16];
    assign cos_coarse = data_pipe[DDS_LATENCY-1][15:0];
    assign frac_out   = frac_pipe[DDS_LATENCY-1];

    // Two-stage multiply keeps operand widths modest.  Each multiplication
    // pre-extends both operands to the full result width so the product is
    // never truncated (Verilog multiplication uses max(operand_w), not context).
    localparam int FSCALE_W   = PHASE_FRAC_W + 18;              // 42
    localparam int FSCALE_S_W = FSCALE_W + 1;                   // 43 (signed wrap)
    localparam int CORR_W     = FSCALE_S_W + 16;                // 59

    logic [FSCALE_W-1:0]      frac_scaled;                      // frac * TWO_PI_Q15
    assign frac_scaled = frac_out * TWO_PI_Q15;

    logic signed [CORR_W-1:0] cos_wide, sin_wide, frac_signed;
    assign cos_wide    = $signed(cos_coarse);
    assign sin_wide    = $signed(sin_coarse);
    assign frac_signed = $signed({{(CORR_W-FSCALE_W){1'b0}}, frac_scaled});

    logic signed [CORR_W-1:0] corr_sin_full, corr_cos_full;
    assign corr_sin_full = cos_wide * frac_signed;              // cos_Q15 * frac * 2pi * 2^15
    assign corr_cos_full = sin_wide * frac_signed;              // sin_Q15 * frac * 2pi * 2^15

    // Round-to-nearest before the arithmetic right shift.
    logic signed [CORR_W-1:0] round_bias;
    assign round_bias = {{(CORR_W-CORR_SHIFT){1'b0}}, 1'b1, {(CORR_SHIFT-1){1'b0}}};

    logic signed [CORR_W-1:0] corr_sin_rnd, corr_cos_rnd;
    assign corr_sin_rnd = corr_sin_full + round_bias;
    assign corr_cos_rnd = corr_cos_full + round_bias;

    logic signed [15:0] sin_corr, cos_corr;
    assign sin_corr = (corr_sin_rnd >>> CORR_SHIFT);
    assign cos_corr = (corr_cos_rnd >>> CORR_SHIFT);

    // Saturate to Q1.15.  Near cos = -1 the correction can push cos_coarse +
    // cos_corr a few LSBs below -32768 (and analogously for sin near +/-1),
    // which wraps the signed 16-bit back to large positive numbers and shows
    // up as isolated sign-flip glitches in the output.
    logic signed [16:0] sin_sum, cos_sum;
    assign sin_sum = $signed({sin_coarse[15], sin_coarse}) + $signed({sin_corr[15], sin_corr});
    assign cos_sum = $signed({cos_coarse[15], cos_coarse}) - $signed({cos_corr[15], cos_corr});

    logic signed [15:0] sin_sat, cos_sat;
    assign sin_sat = (sin_sum >  17'sd32767)  ?  16'sd32767 :
                     (sin_sum < -17'sd32768)  ? -16'sd32768 :
                                                 sin_sum[15:0];
    assign cos_sat = (cos_sum >  17'sd32767)  ?  16'sd32767 :
                     (cos_sum < -17'sd32768)  ? -16'sd32768 :
                                                 cos_sum[15:0];

    logic signed [15:0] sin_out, cos_out;
    assign sin_out = TAYLOR_CORRECT ? sin_sat : sin_coarse;
    assign cos_out = TAYLOR_CORRECT ? cos_sat : cos_coarse;

    assign m_axis_data_tdata = {sin_out, cos_out};


    logic [DDS_LATENCY-1:0] valid_pipe = '0;
    logic                   started    = 1'b0;

    always_ff @(posedge aclk) begin
        if (!started) begin
            valid_pipe <= {valid_pipe[DDS_LATENCY-2:0], s_axis_phase_tvalid};

            // When the delayed valid finally goes high once, we've completed
            // the initial DDS_LATENCY cycles of "startup".
            if (valid_pipe[DDS_LATENCY-1]) begin
                started <= 1'b1;
            end
        end
        // else begin
        //     valid_pipe <= valid_pipe;
        // end
    end

    // Before startup: tvalid is the delayed version (first high after DDS_LATENCY cycles).
    // After startup: tvalid = s_axis_phase_tvalid (no extra latency, and still 0 when input is 0).
    assign m_axis_data_tvalid = started ? s_axis_phase_tvalid
                                        : valid_pipe[DDS_LATENCY-1];



endmodule
