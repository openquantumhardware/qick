module memory_data_dispatcher
    #(
        parameter integer unsigned NB_LEN          = 8 ,
        parameter integer unsigned NB_BASE_ADDRESS = 8 ,
        parameter string           MEM_BIN_FILE    = "",
        parameter integer unsigned N_MEM           = 2
    )
    (
        input  logic                       i_clk          ,
        input  logic                       i_rst          ,
        input  logic                       i_enable       ,
        input  logic                       i_rf_axil_rd_en,
        input  logic                       i_rf_axil_wr_en,
        bram_if.slave_write                i_bram_if      ,
        axi4_stream_if.slave               i_axis         ,
        axi4lite_intf.slave                i_axil         ,

        data_stream_if.master              o_datas        ,
        output logic [NB_LEN         -1:0] o_counter_value
    );

    localparam integer unsigned MEM_NB_DATA = i_bram_if.NB_DATA;
    localparam integer unsigned NB_DEPTH = i_bram_if.NB_ADDR;
    localparam integer unsigned ADDR_LSB = $clog2(i_axil.DATA_WIDTH/8);
    localparam integer unsigned NB_MAX_COUNT = NB_LEN + 1;
    localparam integer unsigned NB_MEM_INSTANCE = $clog2(N_MEM);

    generate
        if ( N_MEM && ((N_MEM & (N_MEM-1)) != 0) ) begin : g_mem_check
            $fatal(1, "N_MEM must be power of 2");
        end
    endgenerate

    generate
        if (NB_LEN > NB_DEPTH) begin : g_check_len_width
            $fatal(1, "NB_LEN cannot be grater than NB_DEPTH");
        end
    endgenerate

    logic bit_start_couter;
    logic [NB_LEN -1:0] len_d;
    logic [NB_BASE_ADDRESS -1:0] base_address_d;
    logic [NB_DEPTH  -1:0] efective_address;
    logic [NB_MAX_COUNT -1:0] counter_value;
    logic counter_valid_msg;
    logic counter_valid_msg_d;
    logic counter_last_msg;
    logic counter_last_msg_d;
    logic tready;
    logic flag_tready;
    logic transaction;

    typedef struct packed {
        logic [NB_LEN -1:0] len;
        logic [NB_BASE_ADDRESS -1:0] base_address;
    } descriptor_t;
    descriptor_t data;

    bram_if #(.NB_DATA ( MEM_NB_DATA*N_MEM ), .NB_ADDR ( NB_DEPTH ))
    bram_out_if (
        .i_clk ( i_clk ),
        .i_rst ( i_rst )
    );

    assign flag_tready = counter_valid_msg & ~counter_valid_msg_d & ~bit_start_couter;
    assign tready = (i_enable & ~i_rst & ~counter_valid_msg_d & ~flag_tready);
    assign efective_address = (counter_value + base_address_d);
    assign len_d = data.len;
    assign base_address_d = data.base_address;
    assign transaction = (!i_axis.tuser & i_axis.tvalid & tready);

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            data <= '0;
        end else begin
            if (transaction) begin
                data <= i_axis.tdata;
            end
        end
    end

    always_ff @(posedge i_clk) bit_start_couter <= (transaction);

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            counter_valid_msg_d <= 1'b0;
            counter_last_msg_d <= 1'b0;
        end else begin
            counter_valid_msg_d <= counter_valid_msg;
            counter_last_msg_d <= counter_last_msg;
        end
    end

    common_counter#( NB_MAX_COUNT )
        u_event_cnt (
            .i_clk              ( i_clk ),
            .i_rst              ( i_rst ),
            .i_start_count      ( bit_start_couter ),
            .i_enable           ( i_enable ),
            .i_rf_max_count     ( $bits(counter_value)'(len_d) ),
            .o_counter          ( counter_value ),
            .o_count_done       ( counter_last_msg ),
            .o_count_in_process ( counter_valid_msg )
    );

    assign bram_out_if.addr = efective_address;
    assign bram_out_if.re = 1'b1;

    bram_linked #(
        .N_MEM ( N_MEM ),
        .MEM_BIN_FILE ( MEM_BIN_FILE )
        )
    u_bram_linked (
        .i_clk ( i_clk ),
        .i_rst ( i_rst ),
        .i_rf_rd_en ( i_rf_axil_rd_en ),
        .i_rf_wr_en ( i_rf_axil_wr_en ),
        .i_axil ( i_axil ),
        .i_bram_if ( i_bram_if ),
        .o_bram_if ( bram_out_if )
    );

    // OUTPUT ASSIGNMENTS
    assign i_axis.tready = tready;
    assign o_datas.data = bram_out_if.data;
    assign o_datas.valid = counter_valid_msg_d;
    assign o_datas.last = counter_last_msg_d;
    assign o_counter_value = counter_value;

endmodule
