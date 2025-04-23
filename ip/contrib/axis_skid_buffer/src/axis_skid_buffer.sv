/***********************************************
 *
 *  Copyright (C) 2022 - Stratum Labs
 *
 *  Project: Stratum Labs - Common Library
 *  Author: Leandro Echevarria <leo.echevarria@stratum-labs.com>
 *
 *  File: axis_skid_buffer.sv
 *  Description: breaks combinational path in AXI4-Stream tvalid/tready handshake-based communication
 *
 * ********************************************/

module axis_skid_buffer
#(
    parameter integer       NB_DATA = 0
)
(
    input  logic            i_clk       ,
    input  logic            i_rst       ,

    axi4_stream_if.slave    i_axis      ,
    axi4_stream_if.master   o_axis
);
    ////////////////////////////////
    // CHECK SIZE COMPATIBILITY
    ////////////////////////////////
    generate
        if (i_axis.N_BYTES_TDATA != o_axis.N_BYTES_TDATA) begin : g_check_data_width
            $fatal(1, "The number of inputs bytes must match the number of outputs bytes.\n");
        end

        if (NB_DATA != 0) begin : g_deprecate_parameter
            $warning("Parameter NB_DATA is deprecated and will be removed in future versions, the bus width is infered from the interface since version 1.2.");
        end

    endgenerate

    //////////////////////
    // DATAPATH
    //////////////////////

    localparam N_BITS_TUSER = i_axis.N_BITS_TUSER;
    localparam N_BITS_TKEEP = i_axis.N_BYTES_TDATA;
    localparam N_BITS_TSTRB = i_axis.N_BYTES_TDATA;

    logic                                    data_buffer_wren;
    logic [i_axis.N_BYTES_TDATA*8-1:0]       data_buffer_out;
    logic                                    data_out_wren = 1'b1;
    logic                                    use_buffered_data;
    logic [i_axis.N_BYTES_TDATA*8-1:0]       selected_data;
    logic                                    data_buffer_tlast;
    logic [N_BITS_TUSER-1:0]                 data_buffer_tuser;
    logic [N_BITS_TKEEP-1:0]                 data_buffer_tkeep;
    logic [N_BITS_TSTRB-1:0]                 data_buffer_tstrb;
    logic                                    selected_tlast;
    logic [N_BITS_TUSER-1:0]                 selected_tuser;
    logic [N_BITS_TKEEP-1:0]                 selected_tkeep;
    logic [N_BITS_TSTRB-1:0]                 selected_tstrb;

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            data_buffer_out   <= '0;
            data_buffer_tlast <= '0;
        end else begin
            if (data_buffer_wren) begin
                data_buffer_out   <= i_axis.tdata;
                data_buffer_tlast <= i_axis.tlast;
                data_buffer_tuser <= i_axis.tuser;
                data_buffer_tkeep <= i_axis.tkeep;
                data_buffer_tstrb <= i_axis.tstrb;
            end
        end
    end

    assign selected_data  = (use_buffered_data) ? data_buffer_out   : i_axis.tdata;
    assign selected_tlast = (use_buffered_data) ? data_buffer_tlast : i_axis.tlast;
    assign selected_tuser = (use_buffered_data) ? data_buffer_tuser : i_axis.tuser;
    assign selected_tkeep = (use_buffered_data) ? data_buffer_tkeep : i_axis.tkeep;
    assign selected_tstrb = (use_buffered_data) ? data_buffer_tstrb : i_axis.tstrb;

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            o_axis.tdata <= '0;
            o_axis.tlast <= '0;
        end else begin
            if (data_out_wren) begin
                o_axis.tdata <= selected_data;
                o_axis.tlast <= selected_tlast;
                o_axis.tuser <= selected_tuser;
                o_axis.tkeep <= selected_tkeep;
                o_axis.tstrb <= selected_tstrb;
            end
        end
    end

    //////////////////////
    // CONTROL PATH
    //////////////////////

    logic load  ;
    logic flow  ;
    logic fill  ;
    logic flush ;
    logic unload;
    logic insert;
    logic remove;

    typedef enum logic [1:0] {  EMPTY   ,
                                BUSY    ,
                                FULL    ,
                                XXX =   'x} state_e;

    state_e state, state_next;

    assign load     = (state == EMPTY) && (insert == 1'b1) && (remove == 1'b0)  ;
    assign flow     = (state == BUSY ) && (insert == 1'b1) && (remove == 1'b1)  ;
    assign fill     = (state == BUSY ) && (insert == 1'b1) && (remove == 1'b0)  ;
    assign flush    = (state == FULL ) && (insert == 1'b0) && (remove == 1'b1)  ;
    assign unload   = (state == BUSY ) && (insert == 1'b0) && (remove == 1'b1)  ;
    assign insert   = i_axis.tvalid & i_axis.tready                             ;
    assign remove   = o_axis.tvalid & o_axis.tready                             ;

    always_comb begin
        state_next = (load   == 1'b1) ? BUSY  : state     ;
        state_next = (flow   == 1'b1) ? BUSY  : state_next;
        state_next = (fill   == 1'b1) ? FULL  : state_next;
        state_next = (flush  == 1'b1) ? BUSY  : state_next;
        state_next = (unload == 1'b1) ? EMPTY : state_next;
    end

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            state <= EMPTY;
        end else begin
            state <= state_next;
        end
    end

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            i_axis.tready <= 1'b0;
        end else begin
            i_axis.tready <= (state_next != FULL);
        end
    end

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            o_axis.tvalid <= 1'b0;
        end else begin
            o_axis.tvalid <= (state_next != EMPTY);
        end
    end

    always_comb begin
        data_out_wren     = (load  == 1'b1) || (flow == 1'b1) || (flush == 1'b1);
        data_buffer_wren  = (fill  == 1'b1);
        use_buffered_data = (flush == 1'b1);
    end

endmodule
