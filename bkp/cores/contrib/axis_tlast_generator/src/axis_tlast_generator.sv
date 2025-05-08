module axis_tlast_generator
#(
    parameter integer unsigned          NB_PACKET_SIZE = 16
)
(
    input  logic                        i_clk               ,
    input  logic                        i_rst               ,
    input  logic [NB_PACKET_SIZE  -1:0] i_packet_size       ,

    axi4_stream_if.slave                i_axis              ,
    axi4_stream_if.master               o_axis              ,
    output logic                        o_count_in_process
);

    logic [NB_PACKET_SIZE -1:0] packet_size  = 1'b1;
    logic counter_last_msg;

    always_ff @ (posedge i_clk) packet_size <= i_packet_size;

    common_counter #(
        .NB_MAX_COUNT ( NB_PACKET_SIZE ),
        .REGISTER_START_COUNT ( 0 ),
        .INCLUSIVE_COUNT ( 0 )
    )
    u_event_cnt (
        .i_clk              ( i_clk ),
        .i_rst              ( i_rst ),
        .i_start_count      ( 1'b1 ),
        .i_enable           ( i_axis.tvalid && o_axis.tready ),
        .i_rf_max_count     ( packet_size ),
        .o_counter          ( ), //unconnected
        .o_count_done       ( counter_last_msg ),
        .o_count_in_process ( o_count_in_process )
    );

    // AXIS INTERFACE AND OUTPUT ASSIGNMENTS

    assign i_axis.tready = o_axis.tready;
    assign o_axis.tdata  = i_axis.tdata ;
    assign o_axis.tvalid = i_axis.tvalid;
    assign o_axis.tlast  = counter_last_msg;

endmodule
