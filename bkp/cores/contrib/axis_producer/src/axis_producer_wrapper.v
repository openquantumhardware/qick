//TODO: USAR start_address Y end_address EN READMEMB EN VEZ DE PARAMETROS
//START_ADDR_OFFSET Y END_ADDR

module axis_producer_wrapper
#(
    parameter integer unsigned              MEM_NB_DATA       = 32,
    parameter integer unsigned              MEM_NB_ADDR       = 4,
    parameter                               MEM_BIN_FILE      = "",
    parameter integer unsigned              NB_DATA           = 32,
    parameter [MEM_NB_ADDR-1:0]             START_ADDR_OFFSET = {MEM_NB_ADDR{1'b0}},
    parameter [MEM_NB_ADDR-1:0]             END_ADDR          = {{MEM_NB_ADDR-1{1'b0}}, 1'b1}
)
(
    input  wire               i_clk,
    input  wire               i_rst,

    input  wire               i_maxi_ready,
    output wire               o_maxi_valid,
    output wire [NB_DATA-1:0] o_maxi_data,

    output wire               o_event_last_addr
);

    axis_producer
    #(
        .MEM_NB_DATA        (MEM_NB_DATA        ),
        .MEM_NB_ADDR        (MEM_NB_ADDR        ),
        .MEM_BIN_FILE       (MEM_BIN_FILE       ),
        .NB_DATA            (NB_DATA            ),
        .START_ADDR_OFFSET  (START_ADDR_OFFSET  ),
        .END_ADDR           (END_ADDR           )
    )
    u_axis_producer
    (
        .i_clk              (i_clk              ),
        .i_rst              (i_rst              ),

        .i_maxi_ready       (i_maxi_ready       ),
        .o_maxi_valid       (o_maxi_valid       ),
        .o_maxi_data        (o_maxi_data        ),

        .o_event_last_addr  (o_event_last_addr  )
    );

endmodule
