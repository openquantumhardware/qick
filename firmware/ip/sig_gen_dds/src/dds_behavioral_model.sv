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
    parameter string    INIT_FILE       = "sine_full32.hex" // ROM for LUT
) (
    input   logic        aclk, // clock at @ ??? MHz
    input   logic        s_axis_phase_tvalid,
    input   logic [71:0] s_axis_phase_tdata,
    output  logic        m_axis_data_tvalid,
    output  logic [31:0] m_axis_data_tdata
);

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
logic signed [31:0] rom [0:DEPTH-1];

initial begin : init_rom
        integer i;
        for (i = 0; i < DEPTH; i++) rom[i] = '0;
        $readmemh(INIT_FILE, rom);
        $display("ROM init from %s: DEPTH=%0d, WIDTH=32", INIT_FILE, DEPTH);
    end

// registered read
logic signed [31:0] lut_dout_q;
always_ff @(posedge aclk) begin
    lut_dout_q <= rom[lut_addr];
end

always_ff @(posedge aclk) begin
    m_axis_data_tvalid <= s_axis_phase_tvalid;
    m_axis_data_tdata  <= lut_dout_q;
end


endmodule