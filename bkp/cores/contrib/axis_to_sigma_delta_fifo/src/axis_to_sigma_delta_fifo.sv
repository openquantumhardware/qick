module axis_to_sigma_delta_fifo
#(
    parameter integer unsigned          DEPTH           = 16,
    parameter integer unsigned          NB_SIGMA_DELTA  = 8
)
(
    input  logic                        i_clk               ,
    input  logic                        i_rst               ,

    input  logic                        i_rd_enable         ,

    input  logic [NB_SIGMA_DELTA-1:0]   i_rf_sigma          ,
    input  logic [NB_SIGMA_DELTA-1:0]   i_rf_delta          ,

    output logic                        o_rf_underflow      ,

    axi4_stream_if.slave                i_axis              ,
    data_stream_if.master               o_stream
);

    logic sigma_delta_enable;

    axi4_stream_if
    #(
        .N_BYTES_TDATA  ( i_axis.N_BYTES_TDATA  )
    ) 
    fifo_output_if
    (
        .i_clk          ( i_clk                 ),
        .i_rst          ( i_rst                 )
    );

    axi4_stream_fifo
    #(
        .DEPTH          ( DEPTH                 )
    )
    u_axi4_stream_fifo
    (
        .i_clk          ( i_clk                 ),
        .i_rst          ( i_rst                 ),
        .i_axis         ( i_axis                ),
        .o_axis         ( fifo_output_if        )
    );

    sigma_delta_generator
    #(
        .NB_SIGMA_DELTA ( NB_SIGMA_DELTA        )
    )
    u_sigma_delta_generator
    (
        .i_clk          ( i_clk                 ),
        .i_rst          ( i_rst                 ),
        .i_enable       ( i_rd_enable           ),
        .i_sigma        ( i_rf_sigma            ),
        .i_delta        ( i_rf_delta            ),
        .o_enable       ( sigma_delta_enable    )
    );

    assign fifo_output_if.tready = sigma_delta_enable;

    always_ff @ (posedge i_clk) o_stream.valid <= (fifo_output_if.tvalid && fifo_output_if.tready);

    always_ff @ (posedge i_clk) begin
        if (fifo_output_if.tvalid && fifo_output_if.tready) begin
            o_stream.data <= fifo_output_if.tdata;
            o_stream.last <= fifo_output_if.tlast;
        end
    end

    always_ff @ (posedge i_clk) o_rf_underflow <= sigma_delta_enable && !fifo_output_if.tvalid;

endmodule
