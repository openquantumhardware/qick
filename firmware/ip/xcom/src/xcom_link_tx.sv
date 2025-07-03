///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
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
    // Config 
    input  logic [ 4-1:0] i_cfg_tick , 
    // Transmittion 
    input  logic          i_valid    ,
    input  logic [ 8-1:0] i_header   ,
    input  logic [32-1:0] i_data     ,
    output logic          o_ready    ,
    // Xwire COM
    output logic          o_data     ,
    output logic          o_clk      
);

    logic s_last;
    //Out Shift Register For Par 2 Ser. (Data encoded on tx_dt)
    logic [40-1:0] tx_data_r, tx_data_n ; 
    // Data and Clock
    logic tx_clk_r, tx_clk_n; 
    //Number of bits transmited  (Total Defined in s_tx_pkt_size)
    logic  [ 6-1:0] tx_bit_cnt_r, tx_bit_cnt_n;
    logic  [ 6-1:0] tx_pkt_size_r, tx_pkt_size_n;

    // Number of tx_clk per Data 
    logic  [ 4-1:0] tick_cnt; 
    logic   tick_en ; 
    logic   tick_clk ; 
    logic   tick_dt ; 

    logic [ 6-1:0] s_tx_pkt_size ;
    logic [40-1:0] tx_buff;

    typedef enum logic [2-1:0]{ TX_IDLE = 2'b00, 
                                TX_DATA = 2'b01, 
                                TX_CLK  = 2'b10, 
                                TX_END  = 2'b11
    } state_t;
    state_t state_r, state_n;
    logic   s_ready;


    // TICK GENERATOR
    ///////////////////////////////////////////////////////////////////////////////
    always_ff @ (posedge i_clk) begin
        if (!i_rstn) begin
            tick_cnt    <= 0;
            tick_clk    <= 1'b0;
            tick_dt     <= 1'b0;
        end else begin 
            if (tick_en) begin
                if (tick_cnt == i_cfg_tick) begin
                    tick_dt  <= 1'b1;
                    tick_cnt <= 4'b0001;
                end else begin 
                    tick_dt  <= 1'b0;
                    tick_cnt <= tick_cnt + 1'b1 ;
                end
                if (tick_cnt == i_cfg_tick>>1) tick_clk <= 1'b1;
                else                           tick_clk <= 1'b0;
            end else begin 
                tick_cnt    <= i_cfg_tick>>1;
                tick_dt     <= 1'b0;
                tick_clk    <= 1'b0;
            end
        end
    end

    // TX Encode Header
    ///////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (i_header[6:5])
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
                    state_n = TX_DATA;
                end     
            end
            TX_DATA:  begin
                if ( tick_dt ) begin
                    if ( s_last ) state_n = TX_END;
                    else          state_n = TX_CLK;
                end
            end
            TX_CLK:  begin
                if ( tick_clk ) state_n = TX_DATA;
            end
            TX_END    :  begin
                if ( tick_clk ) state_n = TX_IDLE;
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
    assign tx_data_n     = (i_valid & s_ready) ? tx_buff       : (tick_dt)  ? tx_data_r << 1      : tx_data_r;
    assign tx_bit_cnt_n  = (i_valid & s_ready) ? 6'b0000_01    : (tick_dt)  ? tx_bit_cnt_r + 1'b1 : tx_bit_cnt_r;
    assign tx_pkt_size_n = (i_valid & s_ready) ? s_tx_pkt_size : tx_pkt_size_r;
    assign tx_clk_n      = (s_ready)           ? 1'b0          : (tick_clk) ? ~tx_clk_r           : tx_clk_r;

    ///////////////////////////////////////////////////////////////////////////////
    // OUTPUTS
    ///////////////////////////////////////////////////////////////////////////////

    assign o_ready = s_ready;
    assign o_data  = tx_data_r[40-1] ;
    assign o_clk   = tx_clk_r;

endmodule
