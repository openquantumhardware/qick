///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom_link_tx.sv
// Project: QICK
// Description:
// Transmitter interface for the XCOM block
//
//Inputs:
// - i_clk      clock signal
// - i_rstn     active low reset signal
// - i_cfg_tick this input is connected to the AXI_CFG register and
//              determines the duration of the xcom_clk output signal.
//              xcom_clk will be CFG_AXI clock cycles in states 1 and 0.
//              Possible values ranges from 0 to 7 with 0 equal to two
//              clock cycles and 7 equal to 15 clock cycles
// - i_valid    it is a one clock duration signal indicating a valid data has
//              arrived and is ready to be send through the xcom ip
// - i header   this is the header to be sent to the slave.
//              bit 7 is sometimes used to indicate a synchronization in other
//              places in the XCOM hierarchy
//              bits [6:5] determines the data length to transmit:
//               00 no data
//               01 8-bit data
//               10 16-bit data
//               11 32-bit data
//              bit 4 not used in this block
//              bits [3:0] not used in this block. Sometimes used as mem_id
//              and sometimes used as board ID in the XCOM hierarchy
// - i_data     the data to be transmitted
//Outputs:
// - o_ready    signal indicating the ip is ready to receive new data to
//              transmit
// - o_data     serial data transmitted. This is the general output of the
//              XCOM block
// - o_clk      serial clock for transmission. This is the general output of
//              the XCOM block
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 04/30/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                          in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_link_tx (
    input  logic          i_clk      ,
    input  logic          i_rstn     ,
    input  logic          i_ps_clk,
    input  logic          i_ps_rstn,
    // Config
    input  logic [ 4-1:0] i_cfg_tick ,
    input  logic          i_cfg_clk_pol,
    input  logic          i_cfg_clk_boost,
    input  logic [8:0]    i_oddr_dly_value,
    // Transmittion
    input  logic          i_valid    ,
    input  logic [ 8-1:0] i_header   ,
    input  logic [32-1:0] i_data     ,
    output logic          o_ready    ,
    // Xwire COM
    output logic [1:0]    o_data     ,
    output logic [1:0]    o_clk
);

    logic s_last;

    //Out Shift Register For Par 2 Ser. (Data encoded on tx_dt)
    logic [40-1:0] tx_data_r, tx_data_n;
    logic tx_data_out_r;

    // Clock
    logic tx_clk_r, tx_clk_n;
    logic tx_clk_out_r;

    //Number of bits transmited  (Total Defined in s_tx_pkt_size)
    logic  [ 6-1:0] tx_bit_cnt_r, tx_bit_cnt_n;
    logic  [ 6-1:0] tx_pkt_size_r, tx_pkt_size_n;

    // Number of tx_clk per Data
    logic  [ 5-1:0] tick_cnt;
    logic   tick_en ;
    logic   tick_clk ;
    logic   tick_dt ;

    logic [ 6-1:0] s_tx_pkt_size ;
    logic [40-1:0] tx_buff;

    typedef enum logic [2-1:0]{ TX_IDLE = 2'b00,
                                TX_DATA = 2'b01,
                                TX_CLK  = 2'b10
    } state_t;
    state_t state_r, state_n;
    logic   s_ready;


    // TICK GENERATOR
    ///////////////////////////////////////////////////////////////////////////////

    // Weird mapping, removes msb from cfg_tick, adds 1 and multiplies by 2
    // needs to increase width of cfg_tick_int by 1 bit
    logic [4-1:0] cfg_tick_limit;
    assign cfg_tick_limit = i_cfg_tick < 'd10 ? i_cfg_tick : 'd10;
    logic [5-1:0] cfg_tick_int;
    assign cfg_tick_int = {cfg_tick_limit+4'd1, 1'b0};

    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tick_cnt    <= 0;
            tick_clk    <= 1'b0;
            tick_dt     <= 1'b0;
        end else begin
            if (tick_en) begin
                if (i_cfg_clk_boost) begin
                    tick_clk <= 1'b1;
                    tick_dt  <= 1'b1;
                end
                else begin
                    if (tick_cnt == cfg_tick_int) begin
                        tick_dt  <= 1'b1;
                        tick_cnt <= 4'b0001;
                    end else begin
                        tick_dt  <= 1'b0;
                        tick_cnt <= tick_cnt + 1'b1 ;
                    end
                    if (tick_cnt == cfg_tick_int>>1) tick_clk <= 1'b1;
                    else                             tick_clk <= 1'b0;
                end
            end else begin
                tick_cnt    <= 4'b0001;
                tick_dt     <= 1'b0;
                tick_clk    <= 1'b0;
            end
        end
    end

    // TX Encode Header
    ///////////////////////////////////////////////////////////////////////////////
    always_comb begin
        unique case (i_header[6:5])
            2'b00  : begin // NO DATA
                s_tx_pkt_size = 7;
                tx_buff      = {i_header, 32'd0};
            end
            2'b01  : begin // 8-bit DATA
                s_tx_pkt_size = 15;
                tx_buff      = {i_header, i_data[8-1:0], 24'd0};
            end
            2'b10  : begin // 16-bit DATA
                s_tx_pkt_size = 23;
                tx_buff      = {i_header, i_data[16-1:0], 16'd0};
            end
            2'b11  : begin //32-bit DATA
                s_tx_pkt_size = 39;
                tx_buff      = {i_header, i_data};
            end
        endcase
    end

    assign s_last  = (tx_bit_cnt_r == tx_pkt_size_r) ;

    ///////////////////////////////////////////////////////////////////////////////
    ///// TX STATE
    //state register
    always_ff @ (posedge i_clk) begin
        if   ( !i_rstn )  state_r  <= TX_IDLE;
        else              state_r  <= state_n;
    end

    //next-state logic
    always_comb begin
        state_n = state_r;
        tick_en = 1'b1;
        s_ready = 1'b0;
        case (state_r)
            TX_IDLE:  begin
                s_ready = 1'b1;
                tick_en = 1'b0;
                if ( i_valid ) begin
                    state_n = TX_CLK;
                end
            end
            TX_DATA:  begin
                if ( tick_dt ) begin
                    if ( s_last ) state_n = TX_IDLE;
                    else          state_n = TX_CLK;
                end
            end
            TX_CLK:  begin
                if ( tick_clk ) state_n = TX_DATA;
            end
            default: state_n = state_r;
        endcase
    end

    // TX Registers
    ///////////////////////////////////////////////////////////////////////////////
    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tx_clk_r      <= 1'b0;
            tx_data_r     <= '0;
            tx_bit_cnt_r  <= '0;
            tx_pkt_size_r <= '0;
        end else begin
            tx_clk_r      <= tx_clk_n;
            tx_data_r     <= tx_data_n;
            tx_bit_cnt_r  <= tx_bit_cnt_n;
            tx_pkt_size_r <= tx_pkt_size_n;
        end
    end

    //next-state logic
    assign tx_pkt_size_n = (i_valid & s_ready) ? s_tx_pkt_size : tx_pkt_size_r;
    assign tx_bit_cnt_n  = (i_valid & s_ready) ? 6'b0000_00    : (tick_dt)  ? tx_bit_cnt_r + 1'b1 : tx_bit_cnt_r;
    assign tx_data_n     = (i_valid & s_ready) ? tx_buff       : (tick_dt)  ? tx_data_r << 1      : tx_data_r;
    assign tx_clk_n      = (s_ready)           ? i_cfg_clk_pol : (tick_clk) ? ~tx_clk_r           : tx_clk_r;

    ///////////////////////////////////////////////////////////////////////////////
    // OUTPUTS
    ///////////////////////////////////////////////////////////////////////////////


    // TX outputs implementation with ODDRE1
    ///////////////////////////////////////////////////////////////////////////////

    logic tx_clk_d_r, tx_data_d_r;

    // NOTE: adding a small delay to the data and clock registers to avoid the ODDRE1 simulation glitch described in the Xilinx forums:
    // Ultrascale+ ODDRE1 Simulation Glitch?
    //      https://adaptivesupport.amd.com/s/question/0D54U00007p3DCKSA2/ultrascale-oddre1-simulation-glitch?language=en_US
    always @ (posedge i_clk) begin
        // if (!i_rstn) begin
        //     tx_clk_d_r  <= 1'b0;
        //     tx_data_d_r <= 1'b0;
        // end else begin
            tx_clk_d_r  <= #0.1 tx_clk_r;
            tx_data_d_r <= #0.1 tx_data_r[40-1];
        // end
    end

    // ODELAYE3: Output Fixed or Variable Delay Element
    //           Virtex UltraScale+
    // Xilinx HDL Language Template, version 2023.1

    logic tx_data_out_pre_odly;

    logic [8:0] odly_cntvalueout;
    logic s_oddr_dly_ce;
    logic s_oddr_dly_inc;
    logic [1:0] s_oddr_dly_busy;

    ODELAYE3 #(
        .CASCADE("NONE"),               // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
        .DELAY_FORMAT("COUNT"),         // (COUNT, TIME)
        .DELAY_TYPE("VARIABLE"),        // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
        .DELAY_VALUE(0),                // Output delay tap setting
        .IS_CLK_INVERTED(1'b0),         // Optional inversion for CLK
        .IS_RST_INVERTED(1'b0),         // Optional inversion for RST
        .REFCLK_FREQUENCY(300.0),       // IDELAYCTRL clock input frequency in MHz (200.0-800.0).
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .UPDATE_MODE("ASYNC")           // Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                        // SYNC)
    )
    odelaye3_xcom_data (
        // Outputs
        .CASC_OUT               (),                     // 1-bit output: Cascade delay output to IDELAY input cascade
        .CNTVALUEOUT            (odly_cntvalueout),     // 9-bit output: Counter value output
        .DATAOUT                (tx_data_out_r),        // 1-bit output: Delayed data from ODATAIN input port
        // Inputs
        .CASC_IN                (1'b0),                 // 1-bit input: Cascade delay input from slave IDELAY
                                                          //              CASCADE_OUT
        .CASC_RETURN            (1'b0),                 // 1-bit input: Cascade delay returning from slave IDELAY
                                                          //              DATAOUT
        .CLK                    (i_ps_clk),             // 1-bit input: Clock input
        .CE                     (s_oddr_dly_ce),        // 1-bit input: Active-High enable increment/decrement input
        .INC                    (s_oddr_dly_inc),       // 1-bit input: Increment/Decrement tap delay input
        .LOAD                   (1'b0),                 // 1-bit input: Load DELAY_VALUE input
        .CNTVALUEIN             (9'd0),                 // 9-bit input: Counter value input
        .EN_VTC                 (1'b0),                 // 1-bit input: Keep delay constant over VT
        .ODATAIN                (tx_data_out_pre_odly), // 1-bit input: Data input
        .RST                    (~i_rstn)               // 1-bit input: Asynchronous Reset to the DELAY_VALUE
    );

    // ODDRE1: Dedicated Double Data Rate (DDR) Output Register
    //         Virtex UltraScale+
    // Xilinx HDL Language Template, version 2023.1
    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    )
    oddre1_tx_data (
        .Q          (tx_data_out_pre_odly),    // 1-bit output: Data output to IOB
        .C          (i_clk),            // 1-bit input: High-speed clock input
        .D1         (tx_data_d_r),      // 1-bit input: Parallel data input 1
        .D2         (tx_data_d_r),      // 1-bit input: Parallel data input 2
        .SR         (1'b0)              // 1-bit input: Active-High Async Reset
    );

    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    )
    oddre1_tx_clk (
        .Q          (tx_clk_out_r),     // 1-bit output: Data output to IOB
        .C          (i_clk),            // 1-bit input: High-speed clock input
        .D1         (tx_clk_d_r),       // 1-bit input: Parallel data input 1
        .D2         (tx_clk_d_r),       // 1-bit input: Parallel data input 2
        .SR         (1'b0)              // 1-bit input: Active-High Async Reset
    );


    ///////////////////////////////////////////////////////////////////////////////

    logic  [ 6-1:0] tx_oddr_bit_cnt_r, tx_oddr_bit_cnt_n;
    logic  [ 6-1:0] tx_oddr_pkt_size_r, tx_oddr_pkt_size_n;


    logic tx_oddr_tick;

    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tx_oddr_bit_cnt_r  <= '0;
            tx_oddr_pkt_size_r <= '0;
        end else begin
            tx_oddr_bit_cnt_r  <= tx_oddr_bit_cnt_n;
            tx_oddr_pkt_size_r <= tx_oddr_pkt_size_n;
        end
    end

    //next-state logic
    assign tx_oddr_pkt_size_n = (i_valid & s_ready) ? s_tx_pkt_size : tx_oddr_pkt_size_r;
    assign tx_oddr_bit_cnt_n  = (i_valid & s_ready) ? 6'b0000_00
                              : (tx_oddr_tick)       ? tx_oddr_bit_cnt_r + 1'b1
                                                      : tx_oddr_bit_cnt_r;

    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tx_oddr_tick   <= 1'b0;
        end else begin
            if (tick_en) begin
                if (i_cfg_tick == 'd0) begin
                    tx_oddr_tick  <= 1'b1;
                end
                else if (i_cfg_tick == 'd1) begin
                    tx_oddr_tick  <= ~tx_oddr_tick;
                end
            end
            else begin
                tx_oddr_tick   <= 1'b0;
            end
        end
    end

    logic [20-1:0] tx_oddr_data1_r, tx_oddr_data2_r;
    logic [20-1:0] tx_oddr_data1_n, tx_oddr_data2_n;

    wire [20-1:0] tx_oddr_bits1 = {tx_buff[40-1],  tx_buff[40-3],  tx_buff[40-5],  tx_buff[40-7],  tx_buff[40-9],
                                   tx_buff[40-11], tx_buff[40-13], tx_buff[40-15], tx_buff[40-17], tx_buff[40-19],
                                   tx_buff[40-21], tx_buff[40-23], tx_buff[40-25], tx_buff[40-27], tx_buff[40-29],
                                   tx_buff[40-31], tx_buff[40-33], tx_buff[40-35], tx_buff[40-37], tx_buff[40-39]};
    wire [20-1:0] tx_oddr_bits2 = {tx_buff[40-2],  tx_buff[40-4],  tx_buff[40-6],  tx_buff[40-8],  tx_buff[40-10],
                                   tx_buff[40-12], tx_buff[40-14], tx_buff[40-16], tx_buff[40-18], tx_buff[40-20],
                                   tx_buff[40-22], tx_buff[40-24], tx_buff[40-26], tx_buff[40-28], tx_buff[40-30],
                                   tx_buff[40-32], tx_buff[40-34], tx_buff[40-36], tx_buff[40-38], tx_buff[40-40]};

    assign tx_oddr_data1_n  = (i_valid & s_ready) ? tx_oddr_bits1
                             : (tx_oddr_tick)      ? tx_oddr_data1_r << 1
                                                    : tx_oddr_data1_r;
    assign tx_oddr_data2_n  = (i_valid & s_ready) ? tx_oddr_bits2
                             : (tx_oddr_tick)      ? tx_oddr_data2_r << 1
                                                    : tx_oddr_data2_r;

    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tx_oddr_data1_r <= '0;
            tx_oddr_data2_r <= '0;
        end else begin
            if (i_cfg_tick == 'd0) begin
                tx_oddr_data1_r <= tx_oddr_data1_n;
                tx_oddr_data2_r <= tx_oddr_data2_n;
            end
            else if (i_cfg_tick == 'd1) begin
                tx_oddr_data1_r <= tx_oddr_data1_n;
                tx_oddr_data2_r <= tx_oddr_data2_n;
            end
        end
    end


    logic tx_oddr_clk1_r, tx_oddr_clk2_r;

    always @ (posedge i_clk) begin
        if (!i_rstn) begin
            tx_oddr_clk1_r  <= 1'b0;
            tx_oddr_clk2_r  <= 1'b0;
        end
        else begin
            if (tick_en) begin
                if (i_cfg_tick == 'd0) begin
                    tx_oddr_clk1_r  <= 1'b1;
                    tx_oddr_clk2_r  <= 1'b0;
                end
                else if (i_cfg_tick == 'd1) begin
                    tx_oddr_clk1_r  <= ~tx_oddr_clk1_r;
                    tx_oddr_clk2_r  <= ~tx_oddr_clk2_r;
                end
            end
            else begin
                tx_oddr_clk1_r  <= 1'b0;
                tx_oddr_clk2_r  <= 1'b0;
            end
        end
    end

    logic tx_oddr_data_o, tx_oddr_clk_o;

    // ODDRE1: Dedicated Double Data Rate (DDR) Output Register
    //         Virtex UltraScale+
    // Xilinx HDL Language Template, version 2023.1
    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    )
    oddre1_tx_oddr_data (
        .Q          (tx_oddr_data_o),   // 1-bit output: Data output to IOB
        .C          (i_clk),            // 1-bit input: High-speed clock input
        .D1         (tx_oddr_data1_r[20-1]),  // 1-bit input: Parallel data input 1
        .D2         (tx_oddr_data2_r[20-1]),  // 1-bit input: Parallel data input 2
        .SR         (1'b0)              // 1-bit input: Active-High Async Reset
    );

    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                        // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    )
    oddre1_tx_oddr_clk (
        .Q          (tx_oddr_clk_o),    // 1-bit output: Data output to IOB
        .C          (i_clk),            // 1-bit input: High-speed clock input
        .D1         (tx_oddr_clk1_r),   // 1-bit input: Parallel data input 1
        .D2         (tx_oddr_clk2_r),   // 1-bit input: Parallel data input 2
        .SR         (1'b0)              // 1-bit input: Active-High Async Reset
    );


    assign o_ready = s_ready;

    // Outputs for XCOM to PADs
    assign o_data[0]  = tx_data_out_r;
    // assign #100ps o_data[0]  = tx_data_out_r;
    assign o_clk[0]   = tx_clk_out_r;

    // Outputs for loopback testing
    assign o_data[1]  = tx_data_r[40-1];
    // assign #100ps o_data[1]  = tx_data_r[40-1];
    assign o_clk[1]   = tx_clk_r;



    always_ff @(posedge i_ps_clk) begin
        if ( !i_ps_rstn ) begin
            s_oddr_dly_ce <= 0;
            s_oddr_dly_inc <= 0;
            s_oddr_dly_busy <= 0;
        end
        else begin
            if (s_oddr_dly_busy == 0 && odly_cntvalueout != i_oddr_dly_value) begin
                s_oddr_dly_ce  <= 1;
                s_oddr_dly_inc <= (odly_cntvalueout < i_oddr_dly_value) ? 1 : 0;
                s_oddr_dly_busy <= 1;
            end
            else begin
                s_oddr_dly_busy <= {s_oddr_dly_busy[0], 1'b0};
                s_oddr_dly_ce  <= 0;
                s_oddr_dly_inc <= 0;
            end
        end
    end


endmodule
