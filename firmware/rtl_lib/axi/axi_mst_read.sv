`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axi_mst_read
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axi_mst_read.sv
//!
//! @brief   AXI4 master read channel of axis_buffer_ddr: one burst read from DDR into a FIFO, streamed out on AXI4-Stream.
//!
//! @details
//! Faithful port of the legacy axi_mst_read (openquantumhardware/qick firmware/ip/
//! axis_buffer_ddr/src/axi_mst_read.sv) on qick:mem:fifo_axi and
//! qick:cdc:cdc_bit_sync (the legacy synchronizer_n: two stages, synchronous
//! reset). A rising `start_reg` reads `length_reg` beats from
//! `TARGET_SLAVE_BASE_ADDR + addr_reg` in INCR bursts of at most 256 beats that
//! never cross a 4 kB boundary; the data goes through a 64-deep FIFO to m_axis
//! (tvalid = FIFO not empty, no tlast). `start_reg` must fall again before a
//! new read starts. `length_reg` = 0 reads nothing.
//!
//! Differences from the legacy RTL (which issued one burst of length_reg
//! beats): a length above 256 was truncated to 8 bits in arlen, length 0 read
//! 256 beats, and a burst could cross a 4 kB boundary (an AXI violation). For
//! a length of 1 to 256 beats that does not cross 4 kB the behaviour is the
//! legacy one, clock by clock.
//!
//! 1.0.2: the end-of-burst update uses beats_r, beats_n registered: remaining_r
//! and addr_reg_r hold from ADDR_ST on, so beats_r equals beats_n in DATA_ST and
//! the clocks do not change (216/tpv2_std_rfbv2 failed setup on remaining_r).
//!
//! @author  QICK Development Team
//!
//! @version 1.0.2
///////////////////////////////////////////////////////////////////////////////
module axi_mst_read
   #(
      // Parameters of AXI Master I/F.
      parameter logic [31:0] TARGET_SLAVE_BASE_ADDR = 32'h40000000 ,
      parameter int ID_WIDTH                  = 1            ,
      parameter int DATA_WIDTH                = 512
   )
   (
      input    wire                       rstn        ,
      input    wire                       clk            ,

      // AXI Master Interface.
      output   wire  [ID_WIDTH-1:0]       m_axi_arid     ,
      output   wire  [31:0]               m_axi_araddr   ,
      output   wire  [7:0]                m_axi_arlen    ,
      output   wire  [2:0]                m_axi_arsize   ,
      output   wire  [1:0]                m_axi_arburst  ,
      output   wire                       m_axi_arlock   ,
      output   wire  [3:0]                m_axi_arcache  ,
      output   wire  [2:0]                m_axi_arprot   ,
      output   wire  [3:0]                m_axi_arregion ,
      output   wire  [3:0]                m_axi_arqos    ,
      output   wire                       m_axi_arvalid  ,
      input    wire                       m_axi_arready  ,

      input    wire  [ID_WIDTH-1:0]       m_axi_rid      ,
      input    wire  [DATA_WIDTH-1:0]     m_axi_rdata    ,
      input    wire  [1:0]                m_axi_rresp    ,
      input    wire                       m_axi_rlast    ,
      input    wire                       m_axi_rvalid   ,
      output   wire                       m_axi_rready   ,

      // AXIS Master Interfase.
      output   wire                       m_axis_tvalid  ,
      output   wire  [DATA_WIDTH-1:0]     m_axis_tdata   ,
      output   wire  [DATA_WIDTH/8-1:0]   m_axis_tstrb   ,
      output   wire                       m_axis_tlast   ,
      input    wire                       m_axis_tready  ,

      // Registers.
      input    wire                       start_reg      ,
      input    wire  [31:0]               addr_reg    ,
      input    wire  [31:0]               length_reg     ,

      // Debug
      output   wire   [31:0]              mst_read_probe_dbg1
   );

/*************/
/* Internals */
/*************/

localparam int BYTES_PER_AXI_TRANSFER   = DATA_WIDTH/8;
localparam int WSH                      = $clog2(BYTES_PER_AXI_TRANSFER);

// States.
typedef enum   {  INIT_ST        ,
                  START_ST    ,
                  READ_REGS_ST   ,
                  ADDR_ST        ,
                  DATA_ST        ,
                  END_ST
               } state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// FSM Signals.
reg            read_regs_state      ;

// start_reg resync.
wire           start_reg_resync  ;

// Registers.
reg      [31:0]      addr_reg_r        ;   // Address of the next burst.
reg      [31:0]      remaining_r       ;   // Beats still to read.

// Fifo.
wire           fifo_full         ;
wire           fifo_empty        ;

// AXI Master.
reg               axi_arvalid_i     ;

// Address.
wire  [31:0]      addr_base         ;

// Burst length: at most 256 beats (arlen is 8 bits) and never across a 4 kB boundary.
logic [31:0]      beats_to_4k       ;
logic [31:0]      beats_n           ;
logic [31:0]      beats_r           ;
wire  [7:0]       burst_length      ;

/****************/
/* Architecture */
/****************/

// start_reg_resync.
cdc_bit_sync start_reg_resync_i (
   .i_clk   (clk),
   .i_rstn  (rstn),
   .i_async (start_reg),
   .o_sync  (start_reg_resync)
);

// Single-clock fifo.
fifo_axi
   #(
      // Data width.
      .B       (DATA_WIDTH  ),

      // Fifo depth.
      .N       (64       )
   )
   fifo_i
   (
      .rstn    (rstn       ),
      .clk     (clk        ),

      // Write I/F.
      .wr_en  (m_axi_rvalid   ),
      .din    (m_axi_rdata ),

      // Read I/F.
      .rd_en  (m_axis_tready  ),
      .dout   (m_axis_tdata   ),

      // Flags.
      .full    (fifo_full     ),
      .empty  (fifo_empty     )
   );

assign m_axi_rready     = ~fifo_full;
assign m_axis_tvalid    = ~fifo_empty;

// Burst length (the legacy RTL issued one burst of LENGTH_REG beats, truncated to 8 bits and not split at 4 kB).
assign beats_to_4k      = 32'((14'd4096 - 14'(addr_reg_r[11:0])) >> WSH);
always_comb begin
   beats_n = remaining_r;
   if (beats_n > 32'd256)
      beats_n = 32'd256;
   if (beats_n > beats_to_4k)
      beats_n = (beats_to_4k == 32'd0) ? 32'd1 : beats_to_4k;
end
assign burst_length     = 8'(beats_n - 32'd1);

always_ff @(posedge clk) beats_r <= beats_n;

// Base address.
assign addr_base        = addr_reg_r;

// Registers.
always @(posedge clk) begin
   if (rstn == 1'b0) begin
      // State register.
      state          <= INIT_ST;

      // Registers.
      addr_reg_r     <= 0;
      remaining_r    <= 0;
   end
   else begin
      // State register.
      case (state)
         INIT_ST:
            state <= START_ST;

         START_ST:
            if (start_reg_resync == 1'b1)
               state <= READ_REGS_ST;

         READ_REGS_ST:
            state <= ADDR_ST;

         ADDR_ST:
            if (remaining_r == 32'd0)
               state <= END_ST;
            else if (m_axi_arready == 1'b1)
               state <= DATA_ST;

         DATA_ST:
            if (m_axi_rvalid == 1'b1 && m_axi_rlast == 1'b1 && fifo_full == 1'b0) begin
               // Next burst, or done when this one was the last.
               state <= (remaining_r == beats_r) ? END_ST : ADDR_ST;
               remaining_r <= remaining_r - beats_r;
               addr_reg_r  <= addr_reg_r + (beats_r << WSH);
            end

         END_ST:
            if (start_reg_resync == 1'b0)
               state <= START_ST;

         default: ;
      endcase

      // Registers.
      if (read_regs_state == 1'b1) begin
         addr_reg_r     <= addr_reg + TARGET_SLAVE_BASE_ADDR;
         remaining_r    <= length_reg;
      end

   end
end

// Read Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_arid = 0;

// Burst length (must substract 1).
assign m_axi_arlen   = burst_length;

// Size set to transfer complete data bits per beat (64 bytes/transfer).
assign m_axi_arsize  =  (BYTES_PER_AXI_TRANSFER == 1     )? 3'b000   :
                        (BYTES_PER_AXI_TRANSFER == 2     )? 3'b001   :
                        (BYTES_PER_AXI_TRANSFER == 4     )? 3'b010   :
                        (BYTES_PER_AXI_TRANSFER == 8     )? 3'b011   :
                        (BYTES_PER_AXI_TRANSFER == 16    )? 3'b100   :
                        (BYTES_PER_AXI_TRANSFER == 32    )? 3'b101   :
                        (BYTES_PER_AXI_TRANSFER == 64    )? 3'b110   :
                        (BYTES_PER_AXI_TRANSFER == 128   )? 3'b111   :
                                                            3'b000   ;

// Set arburst to INCR type.
assign m_axi_arburst    = 2'b01;

// Normal access.
assign m_axi_arlock     = 1'b0;

// Device Non-bufferable.
assign m_axi_arcache    = 4'b0000;

// Data, non-secure, unprivileged.
assign m_axi_arprot     = 3'b010;

// Not-used.
assign m_axi_arregion   = 4'b0000;

// Not-used qos.
assign m_axi_arqos      = 4'b0000;

// FSM outputs.
always_comb begin
   // Default.
   read_regs_state   = 1'b0;
   axi_arvalid_i     = 1'b0;

    case (state)
      //INIT_ST:

      //START_ST:

      READ_REGS_ST:
         read_regs_state   = 1'b1;

      ADDR_ST:
         axi_arvalid_i     = (remaining_r != 32'd0);

      //DATA_ST:

      //END_ST:

      default: ;

    endcase
end

// Assign outputs.
assign m_axi_araddr     = addr_base;
assign m_axi_arvalid    = axi_arvalid_i;

assign m_axis_tstrb     = '1;
assign m_axis_tlast     = 1'b0;


// DEBUG

assign mst_read_probe_dbg1[31:24]   = {burst_length[7:0]};
assign mst_read_probe_dbg1[23:16]   = {3'b000, m_axi_rlast, m_axi_rvalid, m_axis_tready, fifo_full, fifo_empty};
assign mst_read_probe_dbg1[15:8]    = {7'b0000_000, start_reg_resync};
assign mst_read_probe_dbg1[7:0]     = {state};


endmodule
