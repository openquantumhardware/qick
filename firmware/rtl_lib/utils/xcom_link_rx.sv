///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom_link_rx.sv
// Project: QICK
// Description: Receiver interface for the XCOM block
//
//Inputs:
// - i_clk       clock signal
// - i_rstn      active low reset signal
// - i_id        this input configures the ID of the board in the network. It
//               can be configured manually or automatically.
// - i_ack       it is a one clock duration signal indicating an
//               acknowledgement from the tproc/pynq side. This means the
//               tproc/pynq side can receive and process the data arriving in
//               the XCOM link
// - i_xcom_data serial data received. This is the general data input of the
//               XCOM block
// - i_xcom_clk  serial clock for reception. This is the general clock input of
//               the XCOM block
//Outputs:
// - o_req       signal indicating valid data arrived. This signal is to
//               indicate to the tproc/pynq side there are new valid data to
//               process.
// - o_cmd       command to be executed by the tproc/pynq
// - o_data      data received, to be processed by the tproc/pynq
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/01/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_link_rx #(
   parameter DELAY_SRC = "IDATAIN", // Delay input (DATAIN, IDATAIN)
   parameter int USE_IDDR = 0       // Use IDDR implementation, but it doesn´t work with the TX clock boost feature
)(
   input  logic            i_clk          ,
   input  logic            i_rstn         ,
   input  logic            i_ps_clk       ,
   input  logic            i_ps_rstn      ,
   input  logic  [4-1:0]   i_id           ,
   input  logic            i_pha          ,
   input  logic            i_auto_pha     ,
   input  logic [32-1:0]   i_xcom_tx_rx_ddr ,
   // Command Processing
   input  logic            i_ack          ,
   output logic            o_req          ,
   output logic  [4-1:0]   o_cmd          ,
   output logic [32-1:0]   o_data         ,
   // Xwire COM
   input  logic            i_xcom_data    ,
   input  logic            i_xcom_clk     ,
   // XCOM RX DEBUG
   output logic  [5-1:0]   o_dbg_state
);


logic          s_no_data, s_timeout, s_data_last ;
logic          s_broadcast, s_local_id;

logic [ 8-1:0] s_header_shreg ;
logic [ 8-1:0] s_header       ;
logic [32-1:0] s_data_shreg ;
logic          s_new_data;
logic          s_new_bit;

logic          s_rx_idle, s_rx_header, s_rx_req ;

typedef enum logic [3-1:0]{ IDLE   = 3'b000,
                            HEADER = 3'b001,
                            DATA   = 3'b010,
                            REQ    = 3'b011,
                            ACK    = 3'b100
} state_t;
state_t state_r, state_n;

// logic [6-1:0] s_rx_pack_size;
logic [2-1:0] s_rx_data_size;

// Timeout counter, up to 32 clock cycles. This gives roughly 64 ns with
// a t_clk = 500 MHz
logic [5-1:0] timeout_cntr_r, timeout_cntr_n;
// logic [6-1:0] bit_cntr_r, bit_cntr_n        ; // Receive up to 40 bits
logic [1:0] data_cntr_r, data_cntr_n       ; // Receive up to 4 data words

// Auto Phase Control
logic [3:0] s_auto_pha;
logic       s_pha;

logic ddr_last_toggle;
logic ddr_last_toggle_pos;


logic [8:0] idly_cntvalueout;
logic [1:0] s_iddr_dly_busy;
logic s_iddr_dly_ce;
logic s_iddr_dly_inc;

IDELAYE3 #(
      .CASCADE           ("NONE"),              // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      // .DELAY_FORMAT   ("TIME"),                 // Units of the DELAY_VALUE (COUNT, TIME)
      .DELAY_FORMAT      ("COUNT"),             // Units of the DELAY_VALUE (COUNT, TIME)
      .DELAY_SRC         (DELAY_SRC),
      // .DELAY_SRC      ("IDATAIN"),              // Delay input (DATAIN, IDATAIN)
      // .DELAY_SRC      ("DATAIN"),               // Delay input (DATAIN, IDATAIN)
      // .DELAY_TYPE        ("FIXED"),             // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      .DELAY_TYPE        ("VARIABLE"),          // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      .DELAY_VALUE       (0),                   // Input delay value setting
      .IS_CLK_INVERTED   (1'b0),                // Optional inversion for CLK
      .IS_RST_INVERTED   (1'b0),                // Optional inversion for RST
      .REFCLK_FREQUENCY  (300.0),               // IDELAYCTRL clock input frequency in MHz (200.0-800.0)
      .SIM_DEVICE        ("ULTRASCALE_PLUS"),   // Set the device version for simulation functionality (ULTRASCALE,
                                                // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
      .UPDATE_MODE       ("ASYNC")              // Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                                // SYNC)
   )
   idelaye3_xcom_data (
      // Outputs
      .CASC_OUT         (),                     // 1-bit output: Cascade delay output to ODELAY input cascade
      .CNTVALUEOUT      (idly_cntvalueout),     // 9-bit output: Counter value output
      .DATAOUT          (i_xcom_data_delay),    // 1-bit output: Delayed data output
      // Inputs
      .CASC_IN          (1'b0),                 // 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
      .CASC_RETURN      (1'b0),                 // 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
      .CLK              (i_ps_clk),             // 1-bit input: Clock input (UNUSED IN FIXED MODE)
      .CE               (s_iddr_dly_ce),        // 1-bit input: Active-High enable increment/decrement input
      .INC              (s_iddr_dly_inc),       // 1-bit input: Increment / Decrement tap delay input
      .LOAD             (1'b0),                 // 1-bit input: Load DELAY_VALUE input
      .CNTVALUEIN       (9'd0),                 // 9-bit input: Counter value input
      .EN_VTC           (1'b0),                 // 1-bit input: Keep delay constant over VT
      .IDATAIN          ((DELAY_SRC == "IDATAIN") ? i_xcom_data : 1'b0), // 1-bit input: Data input from the IOBUF
      .DATAIN           ((DELAY_SRC == "DATAIN")  ? i_xcom_data : 1'b0), // 1-bit input: Data input from the logic
      .RST              (~i_rstn)               // 1-bit input: Asynchronous Reset to the DELAY_VALUE
   );

logic [3:0] data0_reg_pos, data0_reg_neg;
logic [3:0] data1_reg_pos, data1_reg_neg;


// DDR - RX Serial to Paralel
///////////////////////////////////////////////////////////////////////////////
generate
   if (USE_IDDR == 0) begin : gen_fabric_ddr
      logic [3:0] ddr_data0_reg_pos, ddr_data0_reg_neg;
      logic [3:0] ddr_data1_reg_pos, ddr_data1_reg_neg;
      always_ff @ (posedge i_xcom_clk) begin
         if (s_pha == 0)
            if (ddr_last_toggle == 0) begin
               ddr_data0_reg_pos <= {ddr_data0_reg_pos[2:0], i_xcom_data_delay};
            end else begin
               ddr_data1_reg_pos <= {ddr_data1_reg_pos[2:0], i_xcom_data_delay};
            end
         else
            if (ddr_last_toggle_pos == 0) begin
               ddr_data0_reg_pos <= {ddr_data0_reg_pos[2:0], i_xcom_data_delay};
            end else begin
               ddr_data1_reg_pos <= {ddr_data1_reg_pos[2:0], i_xcom_data_delay};
            end
      end
      always_ff @ (negedge i_xcom_clk) begin
         if (s_pha == 0)
            if (ddr_last_toggle == 0) begin
               ddr_data0_reg_neg <= {ddr_data0_reg_neg[2:0], i_xcom_data_delay};
            end else begin
               ddr_data1_reg_neg <= {ddr_data1_reg_neg[2:0], i_xcom_data_delay};
            end
         else
            if (ddr_last_toggle_pos == 0) begin
               ddr_data0_reg_neg <= {ddr_data0_reg_neg[2:0], i_xcom_data_delay};
            end else begin
               ddr_data1_reg_neg <= {ddr_data1_reg_neg[2:0], i_xcom_data_delay};
            end
      end

      // Use Fabric Registers
      assign data0_reg_pos = ddr_data0_reg_pos;
      assign data0_reg_neg = ddr_data0_reg_neg;
      assign data1_reg_pos = ddr_data1_reg_pos;
      assign data1_reg_neg = ddr_data1_reg_neg;
   end
   else begin : gen_iddre1
      logic iddr_data_reg_h;
      logic iddr_data_reg_l;

      // IDDRE1: Dedicated Double Data Rate (DDR) Input Register
      //         Virtex UltraScale+
      // Xilinx HDL Language Template, version 2023.1

      IDDRE1 #(
         .DDR_CLK_EDGE     ("OPPOSITE_EDGE"),   // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
         .IS_C_INVERTED    (1'b0),              // Optional inversion for C
         .IS_CB_INVERTED   (1'b1)               // Optional inversion for CB
      )
      iddre1_inst (
         .R                (1'b0),              // 1-bit input: Active-High Async Reset
         .CB               (i_xcom_clk),        // 1-bit input: Inversion of High-speed clock C
         .C                (i_xcom_clk),        // 1-bit input: High-speed clock
         .D                (i_xcom_data_delay), // 1-bit input: Serial Data Input
         .Q1               (iddr_data_reg_h),   // 1-bit output: Registered parallel output 1
         .Q2               (iddr_data_reg_l)    // 1-bit output: Registered parallel output 2
      );


      logic [3:0] iddr_data0_reg_pos, iddr_data0_reg_neg;
      logic [3:0] iddr_data1_reg_pos, iddr_data1_reg_neg;

      always_ff @ (posedge i_xcom_clk) begin
         if (s_pha == 0)
            if (ddr_last_toggle == 0) begin
               iddr_data0_reg_pos[3:1] <= iddr_data0_reg_pos[2:0];
            end else begin
               iddr_data1_reg_pos[3:1] <= iddr_data1_reg_pos[2:0];
            end
         else
            if (ddr_last_toggle_pos == 0) begin
               iddr_data0_reg_pos[3:1] <= iddr_data0_reg_pos[2:0];
            end else begin
               iddr_data1_reg_pos[3:1] <= iddr_data1_reg_pos[2:0];
            end
      end
      always_ff @ (negedge i_xcom_clk) begin
         if (s_pha == 0)
            if (ddr_last_toggle == 0) begin
               iddr_data0_reg_neg[3:1] <= iddr_data0_reg_neg[2:0];
            end else begin
               iddr_data1_reg_neg[3:1] <= iddr_data1_reg_neg[2:0];
            end
         else
            if (ddr_last_toggle_pos == 0) begin
               iddr_data0_reg_neg[3:1] <= iddr_data0_reg_neg[2:0];
            end else begin
               iddr_data1_reg_neg[3:1] <= iddr_data1_reg_neg[2:0];
            end
      end

      assign iddr_data0_reg_pos[0] = iddr_data_reg_h;
      assign iddr_data0_reg_neg[0] = iddr_data_reg_l;
      assign iddr_data1_reg_pos[0] = iddr_data_reg_h;
      assign iddr_data1_reg_neg[0] = iddr_data_reg_l;

      // Use IDDR registers
      assign data0_reg_pos = iddr_data0_reg_pos;
      assign data0_reg_neg = iddr_data0_reg_neg;
      assign data1_reg_pos = iddr_data1_reg_pos;
      assign data1_reg_neg = iddr_data1_reg_neg;
   end
endgenerate


// DDR Bit Counter
///////////////////////////////////////////////////////////////////////////////
logic ddr_bit_cntr_rstn;
assign ddr_bit_cntr_rstn = i_rstn & ~s_timeout;

logic [3:0] ddr_bit_cntr;
always_ff @ (negedge i_xcom_clk, negedge ddr_bit_cntr_rstn) begin
   if (!ddr_bit_cntr_rstn) begin
      ddr_bit_cntr  <= 'd1;
   end else begin
      ddr_bit_cntr  <= {ddr_bit_cntr[2:0], ddr_bit_cntr[3]};
   end
end

logic ddr_first_bits;
assign ddr_first_bits = ddr_bit_cntr[0];
logic ddr_last_bits;
assign ddr_last_bits  = ddr_bit_cntr[3];


always_ff @ (negedge i_xcom_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      ddr_last_toggle  <= 1'b0;
   end else begin
      if (ddr_last_bits) begin
         ddr_last_toggle  <= ~ddr_last_toggle;
      end
   end
end

always_ff @ (posedge i_xcom_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      ddr_last_toggle_pos  <= 1'b0;
   end else begin
      ddr_last_toggle_pos  <= ddr_last_toggle;
   end
end


logic ddr_last_sync, ddr_last_pos_sync;
logic ddr_last_sync_d, ddr_last_pos_sync_d;
cdc_bit_sync
u_ddr_last_sync (
  .i_clk      ( i_clk            ),
  .i_rstn     ( i_rstn           ),
  .i_async    ( ddr_last_toggle  ),
  .o_sync     ( ddr_last_sync    )
);
cdc_bit_sync
u_ddr_last_pos_sync (
  .i_clk      ( i_clk            ),
  .i_rstn     ( i_rstn           ),
  .i_async    ( ddr_last_toggle_pos  ),
  .o_sync     ( ddr_last_pos_sync    )
);

always_ff @ (posedge i_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      ddr_last_sync_d  <= 1'b0;
      ddr_last_pos_sync_d  <= 1'b0;
   end else begin
      ddr_last_sync_d  <= ddr_last_sync;
      ddr_last_pos_sync_d  <= ddr_last_pos_sync ;
   end
end

logic ddr_last_sync_edge;
assign ddr_last_sync_edge = ddr_last_sync ^ ddr_last_sync_d;
logic ddr_last_pos_sync_edge;
assign ddr_last_pos_sync_edge = ddr_last_pos_sync ^ ddr_last_pos_sync_d;


// DDR Data CDC
///////////////////////////////////////////////////////////////////////////////
logic [ 7:0] ddr_data_cdc ;
logic        ddr_data_dv  ;

always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      ddr_data_cdc   <= '0;
      ddr_data_dv    <= 1'b0;
   end else begin
      if (~s_pha) begin
         ddr_data_dv      <= ddr_last_sync_edge;
         if (ddr_last_sync_edge) begin
            if (~ddr_last_toggle) begin
               ddr_data_cdc   <= {data1_reg_pos[3], data1_reg_neg[3],
                                    data1_reg_pos[2], data1_reg_neg[2],
                                    data1_reg_pos[1], data1_reg_neg[1],
                                    data1_reg_pos[0], data1_reg_neg[0]};
            end else begin
               ddr_data_cdc   <= {data0_reg_pos[3], data0_reg_neg[3],
                                    data0_reg_pos[2], data0_reg_neg[2],
                                    data0_reg_pos[1], data0_reg_neg[1],
                                    data0_reg_pos[0], data0_reg_neg[0]};
            end
         end
      end
      else begin
         ddr_data_dv      <= ddr_last_pos_sync_edge;
         if (ddr_last_pos_sync_edge) begin
            if (~ddr_last_toggle_pos) begin
               ddr_data_cdc   <= {data1_reg_neg[3], data1_reg_pos[3],
                                    data1_reg_neg[2], data1_reg_pos[2],
                                    data1_reg_neg[1], data1_reg_pos[1],
                                    data1_reg_neg[0], data1_reg_pos[0]};
            end else begin
               ddr_data_cdc   <= {data0_reg_neg[3], data0_reg_pos[3],
                                    data0_reg_neg[2], data0_reg_pos[2],
                                    data0_reg_neg[1], data0_reg_pos[1],
                                    data0_reg_neg[0], data0_reg_pos[0]};
            end
         end
      end
   end
end

assign s_new_data = ddr_data_dv;

always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      s_data_shreg    <= '0;
      s_header_shreg  <= '0;
   end else begin
      if (s_new_data) begin
         if ( s_rx_header ) begin
            s_header_shreg <= ddr_data_cdc;
            s_data_shreg   <= '0;
         end else
            s_data_shreg   <= {s_data_shreg[31-8:0], ddr_data_cdc};
      end
   end
end
assign s_header = s_new_data & s_rx_header ? ddr_data_cdc : s_header_shreg;

// New Bit Monitor
///////////////////////////////////////////////////////////////////////////////

logic          s_xcom_clk_dly;
logic          s_xcom_clk_sync;

cdc_bit_sync sync_xcom_clk(
  .i_clk      ( i_clk           ),
  .i_rstn     ( i_rstn          ),
  .i_async    ( i_xcom_clk      ),
  .o_sync     ( s_xcom_clk_sync )
);

always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      s_xcom_clk_dly  <= 1'b0;
   end else begin
      s_xcom_clk_dly  <= s_xcom_clk_sync;
   end
end

assign s_new_bit   = s_xcom_clk_dly ^ s_xcom_clk_sync;

// Auto Phase Control
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      s_auto_pha  <= 4'h0;
      s_pha       <= 1'b0;
   end
   else begin
      if (i_auto_pha) begin
         if (s_rx_idle) begin
            s_auto_pha  <= {s_auto_pha[2:0], s_xcom_clk_sync};
            s_pha       <= s_auto_pha[3];
         end
         else begin
            s_auto_pha <= {4{s_auto_pha[3]}};
         end
      end
      else begin
         s_pha <= i_pha;
      end
   end
end


///// DDR RX STATE
///////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge i_clk) begin
   if   ( !i_rstn ) state_r  <= IDLE;
   else             state_r  <= state_n;
end

always_comb begin
   state_n     = state_r;
   s_rx_idle   = 1'b0;
   s_rx_header = 1'b0;
   s_rx_req    = 1'b0;
   case (state_r)
      IDLE:  begin
         s_rx_idle = 1'b1;
         if ( s_new_bit ) begin //detects first bit transition
            state_n     = HEADER;
         end
      end
      HEADER:  begin
         s_rx_header = 1'b1;
         if ( s_timeout  ) state_n = IDLE; // TimeOut
         if ( s_new_data ) begin
            if      ( s_no_data  ) state_n = REQ  ; // Package has No Data
            else                   state_n = DATA ; // Package has Data
         end
      end
      DATA:  begin
         if ( s_timeout   ) state_n = IDLE; // TimeOut
         if ( s_data_last ) state_n = REQ;  // Last Data Received
      end
      REQ:  begin
         if ( s_timeout  ) state_n = IDLE; // TimeOut
         if ( s_broadcast | s_local_id ) begin
            s_rx_req = 1'b1;
            if (i_ack ) state_n = ACK;
         end else
            state_n = IDLE;
      end
      ACK:  begin
         if ( s_timeout  ) state_n = IDLE; // TimeOut
         if (!i_ack) state_n = IDLE;
      end
      default: state_n = state_r;
   endcase
end


// RX Length Decoding
///////////////////////////////////////////////////////////////////////////////
always_comb begin
   case ( s_header_shreg [6:5] )
      // 2'b00  : s_rx_pack_size = 6'd8  ; //8-bit header + no data
      2'b01  : s_rx_data_size = 'd1-1 ; //8-bit header + 8-bit data
      2'b10  : s_rx_data_size = 'd2-1 ; //8-bit header + 16-bit data
      2'b11  : s_rx_data_size = 'd4-1 ; //8-bit header + 32-bit data
      default: s_rx_data_size = 'd0   ; //8-bit header + no data
   endcase
end


///////////////////////////////////////////////////////////////////////////////
// RX Measurement
always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      data_cntr_r    <= 2'd0;
      timeout_cntr_r <= '0;
   end else begin
      data_cntr_r    <= data_cntr_n;
      timeout_cntr_r <= timeout_cntr_n;
   end
end

//next-state logic
assign data_cntr_n    = (s_new_data) ? ((s_rx_header) ? 2'd0 : data_cntr_r + 1'b1) : data_cntr_r;
assign timeout_cntr_n = (s_new_bit)  ? '0                   : (s_rx_idle) ? '0   : timeout_cntr_r + 1'b1;

assign s_data_last   = s_new_data & (data_cntr_r == s_rx_data_size) ; // Last Data Received
assign s_no_data     = (s_header[6:5] == 2'b00) ; // cmd with no data
assign s_broadcast   = (s_header[3:0] == 4'd0); //broadcast
assign s_local_id    = (s_header[3:0] == i_id) ;
assign s_timeout     = &timeout_cntr_r ; // New Data was not received in time

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_state  = {2'b00,state_r};
assign o_req        = s_rx_req;
assign o_cmd        = s_header_shreg[7:4];
assign o_data       = s_data_shreg;


///////////////////////////////////////////////////////////////////////////////
// IDELAY Control
///////////////////////////////////////////////////////////////////////////////

always_ff @(posedge i_ps_clk) begin
   if ( !i_ps_rstn ) begin
      s_iddr_dly_ce <= 0;
      s_iddr_dly_inc <= 0;
      s_iddr_dly_busy <= 0;
   end else begin
      if (s_iddr_dly_busy == 0 && idly_cntvalueout != i_xcom_tx_rx_ddr[16+:9]) begin
         s_iddr_dly_ce  <= 1;
         s_iddr_dly_inc <= (idly_cntvalueout < i_xcom_tx_rx_ddr[16+:9]) ? 1 : 0;
         s_iddr_dly_busy <= 1;
      end
      else begin
         s_iddr_dly_busy <= {s_iddr_dly_busy[0], 1'b0};
         s_iddr_dly_ce  <= 0;
         s_iddr_dly_inc <= 0;
      end
   end
end

endmodule
