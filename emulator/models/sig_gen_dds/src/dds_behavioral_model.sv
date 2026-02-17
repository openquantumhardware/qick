//-----------------------------------------------------------------------------
// Title      : Direct Digital Synthesis (DDS) Behavioral Model
// Project    : HRL Clinic 2025-26
//-----------------------------------------------------------------------------
// File       : dds_behavioral_model.sv
// Author     : Jessic Liu
// Date       : 09/16/2025
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module dds_behavioral_model # (
    // Reserve for Parameters
    parameter int       LUT_SIZE        = 256, // Lookup Table size
    parameter int       PHASE_WIDTH     = 32, // phase width
    parameter string    INIT_FILE       = "sine_full32.hex", // ROM for LUT
    parameter int       DDS_LATENCY     = 10   // MUST MATCH DDS Compiler GUI Latency
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
logic [31:0] m_axis_data_tdata_temp = '0;


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

    integer k;
    always_ff @(posedge aclk) begin
        // Stage 0: ROM read
        data_pipe[0] <= rom[lut_addr];

        // Remaining stages
        for (k = 1; k < DDS_LATENCY; k++) begin
            data_pipe[k] <= data_pipe[k-1];
        end
    end

    assign m_axis_data_tdata = data_pipe[DDS_LATENCY-1];

    // --------- TVALID BEHAVIOR -------------------------------
    // Requirement (from your sim observations):
    //   1) On the *very first* s_axis_phase_tvalid=1, there is a DDS_LATENCY-cycle delay
    //      before m_axis_data_tvalid goes high.
    //   2) After that first startup, m_axis_data_tvalid follows s_axis_phase_tvalid
    //      with *no additional latency*.
    //   3) If s_axis_phase_tvalid is low, m_axis_data_tvalid must be low.
    //
    // Implementation:
    //   - valid_pipe: delay line for s_axis_phase_tvalid (used only during startup).
    //   - started: once the first delayed-valid goes high, tvalid switches to
    //     directly follow s_axis_phase_tvalid (no more latency).

    logic [DDS_LATENCY-1:0] valid_pipe = '0;
    logic                   started    = 1'b0;

    always_ff @(posedge aclk) begin
        if (!started) begin
            // During startup: build a delayed version of s_axis_phase_tvalid
            valid_pipe <= {valid_pipe[DDS_LATENCY-2:0], s_axis_phase_tvalid};

            // When the delayed valid finally goes high once, we've completed
            // the initial DDS_LATENCY cycles of "startup".
            if (valid_pipe[DDS_LATENCY-1]) begin
                started <= 1'b1;
            end
        end
        else begin
            // After startup, we don't care about the pipeline content anymore.
            // We just leave it alone (or you could set it to all 1's or 0's).
            valid_pipe <= valid_pipe;
        end
    end

    // Before startup: tvalid is the delayed version (first high after DDS_LATENCY cycles).
    // After startup: tvalid = s_axis_phase_tvalid (no extra latency, and still 0 when input is 0).
    assign m_axis_data_tvalid = started ? s_axis_phase_tvalid
                                        : valid_pipe[DDS_LATENCY-1];



endmodule