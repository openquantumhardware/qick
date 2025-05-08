module common_counter_wrapper
#(
    parameter integer NB_MAX_COUNT          = 32,
    parameter integer REGISTER_START_COUNT  =  0,
    parameter integer INCLUSIVE_COUNT       =  0
)
(
    input   wire                           i_clk,
    input   wire                           i_rst,
    input   wire                           i_start_count,
    input   wire                           i_enable,
    input   wire   [NB_MAX_COUNT-1   : 0]  i_rf_max_count,

    output  wire   [NB_MAX_COUNT-1   : 0]  o_counter,
    output  wire                           o_count_done,
    output  wire                           o_count_in_process
);

    common_counter
    #(
        .NB_MAX_COUNT           ( NB_MAX_COUNT          ),
        .REGISTER_START_COUNT   ( REGISTER_START_COUNT  )
    )
    u_common_counter
    (
        .i_clk                  ( i_clk                 ),
        .i_rst                  ( i_rst                 ),
        .i_start_count          ( i_start_count         ),
        .i_enable               ( i_enable              ),
        .i_rf_max_count         ( i_rf_max_count        ),

        .o_counter              ( o_counter             ),
        .o_count_done           ( o_count_done          ),
        .o_count_in_process     ( o_count_in_process    )
    );

endmodule
