///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : mr_buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    mr_buffer.sv
//!
//! @brief   Multi-channel buffer with AXI4-Stream interfaces
//!
//! @details
//!
//!
//! Uses axis_to_bram_trig for writing and bram_to_axis_nt for
//! reading
//! mr_buffer – SystemVerilog conversion
//! Replaces VHDL data_writer   -> axis_to_bram_trig
//! data_reader     -> bram_to_axis
//! synchronizer    -> cdc_gray_sync
//!
//! Design overview:
//! mr_buffer captures NM parallel channels of B bits each into NM independent
//! BRAMs (depth = 2**N per BRAM) on the write side (s_axis_aclk domain).
//! On the read side (m_axis_aclk domain), bram_to_axis_nt serialises all
//! NM*2**N words into a single B-bit AXI4-Stream:
//!
//! Output word order (TOTAL_WORDS = NM * 2**N words per read burst):
//! word 0            : ch0 @ addr 0
//! word 1            : ch1 @ addr 0
//! ...
//! word NM-1         : ch(NM-1) @ addr 0
//! word NM           : ch0 @ addr 1
//! ...
//! word NM*2**N - 1  : ch(NM-1) @ addr (2**N - 1)  ← tlast here
//!
//! IMPORTANT: every call to start_reader() starts a burst of exactly
//! TOTAL_WORDS beats ending with tlast=1.  Always consume all TOTAL_WORDS
//! beats before calling stop_reader(), otherwise the next start_reader() will
//! see stale data from the previous incomplete burst still in the output FIFO.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module mr_buffer #(
  parameter int NM = 8,          // Number of memories (parallel channels)
  parameter int N  = 8,          // Address width of each memory (2^N depth)
  parameter int B  = 16          // Data width of each memory (bits)
) (
  // Trigger (asynchronous, will be synchronised to s_axis_aclk)
  input  logic                trigger,

  // AXI4-Stream Slave interface (input data)
  input  logic                s_axis_aclk,
  input  logic                s_axis_aresetn,
  output logic                s_axis_tready,
  input  logic [NM*B-1:0]     s_axis_tdata,
  input  logic [(NM*B/8)-1:0] s_axis_tstrb,
  input  logic                s_axis_tlast,
  input  logic                s_axis_tvalid,

  // AXI4-Stream Master interface (output data)
  input  logic                m_axis_aclk,
  input  logic                m_axis_aresetn,
  output logic                m_axis_tvalid,
  output logic [B-1:0]        m_axis_tdata,
  output logic [(B/8)-1:0]    m_axis_tstrb,
  output logic                m_axis_tlast,
  input  logic                m_axis_tready,

  // Control registers (from AXI4-Lite, synchronous to their respective clocks)
  input  logic                dw_capture_reg,   // synchronised to s_axis_aclk
  input  logic                dr_start_reg,     // synchronised to m_axis_aclk
  input  logic [31:0]         debug_reg, // Debug bits:
                                 //   debug_reg[0] -> trigger_dbg (force trigger)
                                 //   debug_reg[1] -> s_axis_tready_force

  // Debug probes (optional, for ILA)
  output logic [31:0]         s_dbg_probe,
  output logic [31:0]         m_dbg_probe,
  output logic                o_capture_done
);

  // -------------------------------------------------------------------------
  // Synchronisers (cdc_gray_sync with M=1 for single-bit signals)
  // -------------------------------------------------------------------------
  logic dw_capture_reg_resync, dr_start_reg_resync, trigger_resync;

  cdc_gray_sync #(.N(2), .M(1)) sync_dw_capture (
    .i_clk  (s_axis_aclk),
    .i_rstn (s_axis_aresetn),
    .i_d    (dw_capture_reg),
    .o_d    (dw_capture_reg_resync)
  );

  cdc_gray_sync #(.N(2), .M(1)) sync_dr_start (
    .i_clk  (m_axis_aclk),
    .i_rstn (m_axis_aresetn),
    .i_d    (dr_start_reg),
    .o_d    (dr_start_reg_resync)
  );

  logic trigger_or_dbg;
  assign trigger_or_dbg = trigger | debug_reg[0];

  cdc_gray_sync #(.N(2), .M(1)) sync_trigger (
    .i_clk  (s_axis_aclk),
    .i_rstn (s_axis_aresetn),
    .i_d    (trigger_or_dbg),
    .o_d    (trigger_resync)
  );

  // -------------------------------------------------------------------------
  // Debug force signals
  // -------------------------------------------------------------------------
  logic s_axis_tready_force;
  assign s_axis_tready_force = debug_reg[1];

  // -------------------------------------------------------------------------
  // Internal signals for the generate loop
  // -------------------------------------------------------------------------
  logic         ena     [NM];       // BRAM port A enable
  logic         wea     [NM];       // BRAM port A write enable
  logic [N-1:0] addra   [NM];       // BRAM port A address
  logic [B-1:0] dia     [NM];       // BRAM port A write data
  logic [B-1:0] doa     [NM];       // BRAM port A read data (unused)

  // Read side (common for all BRAMs)
  logic         enb;                // BRAM port B enable
  logic         web;                // BRAM port B write enable (always 0 for reads)
  logic [N-1:0] addrb;              // BRAM port B address
  logic [B-1:0] dib;                // BRAM port B write data (unused)
  logic [B-1:0] dob     [NM];       // BRAM port B read data from each memory

  // Concatenated output of all BRAMs (read by bram_to_axis_nt)
  logic [NM*B-1:0] dob_c;

  // Slice input data for each channel
  logic [B-1:0] s_axis_tdata_i [NM];
  // Internal tready from each axis_to_bram_trig
  logic [NM-1:0] s_axis_tready_i;

  // AXI output signals
  logic         m_axis_tvalid_int;
  logic [B-1:0] m_axis_tdata_int;
  logic         m_axis_tlast_int;
  logic [NM-1:0]cap_done_ch;  // capture done from each channel

  // -------------------------------------------------------------------------
  // Generate NM channels: BRAM + axis_to_bram_trig
  // -------------------------------------------------------------------------
  generate
    for (genvar i = 0; i < NM; i++) begin : gen_channel
      // Slice input data
      assign s_axis_tdata_i[i] = s_axis_tdata[(i+1)*B-1 : i*B];

      // axis_to_bram_trig – writes to BRAM port A
      axis_to_bram_trig #(
        .N (N),
        .B (B)
      ) u_axis_to_bram_trig (
        .rstn          ( s_axis_aresetn        ),
        .clk           ( s_axis_aclk           ),
        .trigger       ( trigger_resync        ),
        .s_axis_tready ( s_axis_tready_i[i]    ),
        .s_axis_tdata  ( s_axis_tdata_i[i]     ),
        .s_axis_tvalid ( s_axis_tvalid         ),
        .s_axis_tlast  ( s_axis_tlast          ),
        .mem_en        ( ena[i]                ),
        .mem_we        ( wea[i]                ),
        .mem_addr      ( addra[i]              ),
        .mem_di        ( dia[i]                ),
        .capture_reg   ( dw_capture_reg_resync ),
        .o_capture_done ( cap_done_ch[i] )
      );

      // True dual‑port BRAM
      bram_tdp #(
        .NB_ADDR(N),
        .NB_DATA(B)
      ) u_bram (
        .clka  ( s_axis_aclk ),
        .rsta  ( ~s_axis_aresetn ),
        .ena   ( ena[i]      ),
        .wea   ( wea[i]      ),
        .addra ( addra[i]    ),
        .dia   ( dia[i]      ),
        .doa   ( doa[i]      ),
        .clkb  ( m_axis_aclk ),
        .rstb  ( ~m_axis_aresetn ),
        .enb   ( enb         ),
        .web   ( web         ),
        .addrb ( addrb       ),
        .dib   ( dib         ),
        .dob   ( dob[i]      )
      );
    end
  endgenerate

  assign o_capture_done = &cap_done_ch;

  // Combine tready from all channels
  assign s_axis_tready = (&s_axis_tready_i) | s_axis_tready_force;

  // -------------------------------------------------------------------------
  // Read side: concatenate all BRAM outputs and feed to bram_to_axis_nt
  // -------------------------------------------------------------------------
  generate
    for (genvar i = 0; i < NM; i++) begin : gen_concat
      assign dob_c[(i+1)*B-1 : i*B] = dob[i];
    end
  endgenerate

  // bram_to_axis_nt – reads from the wide concatenated BRAM port B
  // Reads ALL addresses (0 to 2^N-1) and ALL channels (0 to NM-1)
  bram_to_axis_nt #(
    .NT (NM),
    .N  (N),
    .B  (B)
  ) u_bram_to_axis_nt (
    .rstn            ( m_axis_aresetn      ),
    .clk             ( m_axis_aclk         ),
    .mem_en          ( enb                 ),
    .mem_we          ( web                 ),
    .mem_addr        ( addrb               ),
    .mem_dout        ( dob_c               ),
    .mem_din         (                     ),  // not used for reads
    .m_axis_tready   ( m_axis_tready       ),
    .m_axis_tvalid   ( m_axis_tvalid_int   ),
    .m_axis_tlast    ( m_axis_tlast_int    ),
    .m_axis_tdata    ( m_axis_tdata_int    ),
    .start_reg       ( dr_start_reg_resync )
  );

  // Output assignments
  assign m_axis_tvalid = m_axis_tvalid_int;
  assign m_axis_tdata  = m_axis_tdata_int;
  assign m_axis_tlast  = m_axis_tlast_int;
  assign m_axis_tstrb  = {(B/8){1'b1}};

  // -------------------------------------------------------------------------
  // Debug probes (same as VHDL, for ILA)
  // -------------------------------------------------------------------------
  assign s_dbg_probe[7:0]   = {3'b000, dw_capture_reg_resync, trigger_resync,
                                 wea[0], s_axis_tvalid, s_axis_tready_i[0]};
  assign s_dbg_probe[15:8]  = s_axis_tdata_i[0][7:0];
  assign s_dbg_probe[23:16] = addra[0][7:0];
  assign s_dbg_probe[31:24] = dia[0][7:0];

  assign m_dbg_probe[7:0]   = {3'b000, dr_start_reg_resync, web, m_axis_tlast_int,
                                 m_axis_tvalid_int, m_axis_tready};
  assign m_dbg_probe[15:8]  = m_axis_tdata_int[7:0];
  assign m_dbg_probe[23:16] = addrb[7:0];
  assign m_dbg_probe[31:24] = dob_c[7:0];

endmodule
