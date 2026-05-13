`timescale 1ns / 1ps
//
// resonator_emulator.sv  --  TESTBENCH-ONLY MODULE.
//
// Stands in for a real superconducting resonator/qubit.  Plays back a
// Python-generated I/Q dataset (iq_shots.mem -- one int32 per line,
// packed {Q[15:0], I[15:0]}, identical to axis_dyn_readout_v1.m1_axis
// output format) and emits the response as MODULATED ADC samples.
//
// Signal flow it supports:
//   axis_signal_gen_v6 -> DAC -> resonator_emulator -> ADC
//                                    (this module)         |
//                                                          v
//                                       axis_dyn_readout_v1 -> m1_axis -> adaptive_sweep
//
// What it does each ro_clk:
//   1. Snoops the drive `pinc` from the SG waveform queue
//      (sgt_sg_0_axis_tdata[31:0] in the testbench scope) -- this is
//      the same Q32 phase-increment word the tProc programmed into
//      axis_signal_gen_v6.
//   2. Converts pinc -> drive frequency Hz -> bin index (matching the
//      Python notebook's measure_iq() bin lookup).
//   3. Picks (I_t, Q_t) from iq_shots.mem at addr = bin*N_SHOTS +
//      shot_cursor[bin], then advances shot_cursor mod N_SHOTS.
//   4. Modulates onto the carrier:
//         ADC[t] = 2*( I_t*cos(phi) - Q_t*sin(phi) )
//      where phi advances by `pinc_drive` per ADC sample.  The factor
//      of 2 compensates for the readout's I/Q downconversion gain of
//      1/2 (low-pass filtering of cos^2 / sin^2 terms).
//   5. Packs 8 consecutive int16 ADC samples into m_adc_axis_tdata
//      (which the testbench routes into axis_adc_ro_tdata).
//
// After the readout's downconvert + FIR/decimation, m1_axis recovers
// (I_t, Q_t) -- which is exactly what adaptive_sweep snoops.
//
// For a debug bypass that skips the readout DSP entirely, see the
// "BYPASS Mux" block in tb_qick.sv -- it streams iq_shots.mem directly
// into axis_ro_avg_* without going through this module.
//
module resonator_emulator #(
    // Python-data layout (must match the .mem file header)
    parameter integer N_SWEEP        = 1000,
    parameter integer N_SHOTS        = 1000,
    parameter real    F_START_HZ     = 3.0e9,
    parameter real    F_STEP_HZ      = 1.001001e6,
    parameter integer IQ_SCALE       = 16384,        // 2^14
    parameter real    F_DAC_HZ       = 6.144e9,      // SG sample rate
    parameter string  MEM_FILE       = "../../../../src/tb/test_adaptive_sweep/iq_shots.mem"
)(
    // ---- clocks / reset ----
    input  logic                     clk_sg,           // sg_clk: snoop drive pinc
    input  logic                     clk_adc,          // adc_fs: produce ADC samples (unused; we batch on ro_clk)
    input  logic                     clk_ro,           // ro_clk: emit packed 8-sample ADC vector
    input  logic                     rst_n,
    input  logic                     enable,           // 0 -> outputs idle/zero

    // ---- DRIVE-side snoop (waveform queue feeding axis_signal_gen_v6) ----
    input  logic [159:0]             sg_queue_tdata,   // [31:0]=pinc, etc.
    input  logic                     sg_queue_tvalid,
    input  logic                     sg_queue_tready,

    // ---- ADC output (drives axis_adc_ro_tdata) ----
    output logic [8*16-1:0]          m_adc_axis_tdata, // 8 real int16 samples / ro_clk
    output logic                     m_adc_axis_tvalid
);

    // -------------------------------------------------------------
    // Storage: one int32 per shot, layout = bin*N_SHOTS + shot_cursor
    // -------------------------------------------------------------
    localparam integer TABLE_DEPTH = N_SWEEP * N_SHOTS;
    logic [31:0] iq_mem [0:TABLE_DEPTH-1];
    integer      shot_cursor [0:N_SWEEP-1];

    initial begin : load_mem
        integer i;
        for (i = 0; i < N_SWEEP; i = i + 1) shot_cursor[i] = 0;
        $display("[resonator_emulator] loading %s (%0d entries)", MEM_FILE, TABLE_DEPTH);
        $readmemh(MEM_FILE, iq_mem);
    end

    // -------------------------------------------------------------
    // Snoop drive pinc on every accepted sg-queue entry
    // -------------------------------------------------------------
    logic [31:0] pinc_drive_r;
    integer      bin_r;

    always_ff @(posedge clk_sg) begin
        if (!rst_n) begin
            pinc_drive_r <= 32'd0;
            bin_r        <= 0;
        end else if (sg_queue_tvalid && sg_queue_tready) begin
            pinc_drive_r <= sg_queue_tdata[31:0];
            begin : bin_calc
                real f_hz, off_hz, bin_real;
                f_hz     = real'(sg_queue_tdata[31:0]) * F_DAC_HZ / (1.0 * (1 << 32));
                off_hz   = f_hz - F_START_HZ;
                bin_real = off_hz / F_STEP_HZ;
                if (bin_real < 0.0)              bin_r <= 0;
                else if (bin_real > (N_SWEEP-1)) bin_r <= N_SWEEP - 1;
                else                              bin_r <= $rtoi(bin_real + 0.5);
            end
        end
    end

    // -------------------------------------------------------------
    // Sin/cos LUT for modulation (10-bit index, Q15 amplitude)
    // -------------------------------------------------------------
    localparam integer LUT_BITS  = 10;
    localparam integer LUT_DEPTH = (1 << LUT_BITS);
    logic signed [15:0] sin_lut [0:LUT_DEPTH-1];
    logic signed [15:0] cos_lut [0:LUT_DEPTH-1];

    initial begin : build_lut
        integer i;
        real    a;
        for (i = 0; i < LUT_DEPTH; i = i + 1) begin
            a            = 2.0 * 3.141592653589793 * real'(i) / real'(LUT_DEPTH);
            sin_lut[i]   = $rtoi(32767.0 * $sin(a));
            cos_lut[i]   = $rtoi(32767.0 * $cos(a));
        end
    end

    // -------------------------------------------------------------
    // Latched (I_t, Q_t) target for the current bin / shot.
    // Refreshed each ro_clk so each m1_axis decimation window sees a
    // fresh shot from the Python table.
    // -------------------------------------------------------------
    logic signed [15:0] i_target_r, q_target_r;

    always_ff @(posedge clk_ro) begin
        if (!rst_n) begin
            i_target_r <= 0;
            q_target_r <= 0;
        end else if (enable) begin
            integer addr;
            addr       = bin_r * N_SHOTS + shot_cursor[bin_r];
            i_target_r <= $signed(iq_mem[addr][15:0]);
            q_target_r <= $signed(iq_mem[addr][31:16]);
            shot_cursor[bin_r] <= (shot_cursor[bin_r] + 1) % N_SHOTS;
        end
    end

    // -------------------------------------------------------------
    // Modulation: ADC[t] = 2*(I*cos - Q*sin) per ADC sample, 8 lanes
    // packed per ro_clk.  Phase accumulator advances by pinc_drive_r
    // per ADC sample.
    // -------------------------------------------------------------
    function automatic logic signed [15:0] sin_q (input logic [31:0] ph);
        sin_q = sin_lut[ph[31 -: LUT_BITS]];
    endfunction
    function automatic logic signed [15:0] cos_q (input logic [31:0] ph);
        cos_q = cos_lut[ph[31 -: LUT_BITS]];
    endfunction

    logic [31:0]        phase_acc;
    logic [8*16-1:0]    adc_pack;
    integer             k;
    logic signed [31:0] re_prod, im_prod, sum_signed;
    logic signed [15:0] sample_int16;

    always_ff @(posedge clk_ro) begin
        if (!rst_n) begin
            phase_acc        <= 32'd0;
            m_adc_axis_tdata <= '0;
            m_adc_axis_tvalid<= 1'b0;
        end else if (enable) begin
            logic [31:0] ph_local;
            ph_local = phase_acc;
            for (k = 0; k < 8; k = k + 1) begin
                re_prod    = $signed(i_target_r) * $signed(cos_q(ph_local));
                im_prod    = $signed(q_target_r) * $signed(sin_q(ph_local));
                sum_signed = ((re_prod - im_prod) >>> 14);   // *2 / 32768 == >>>14
                if      (sum_signed >  16'sh7FFF) sample_int16 = 16'sh7FFF;
                else if (sum_signed < -16'sh8000) sample_int16 = -16'sh8000;
                else                              sample_int16 = sum_signed[15:0];
                adc_pack[k*16 +: 16] = sample_int16;
                ph_local = ph_local + pinc_drive_r;
            end
            phase_acc        <= ph_local;
            m_adc_axis_tdata <= adc_pack;
            m_adc_axis_tvalid<= 1'b1;
        end else begin
            m_adc_axis_tvalid<= 1'b0;
        end
    end

endmodule
