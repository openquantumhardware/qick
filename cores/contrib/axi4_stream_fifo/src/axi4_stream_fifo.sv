module axi4_stream_fifo
#(
    parameter integer unsigned      DEPTH   = 16
)
(
    input  logic                    i_clk       ,
    input  logic                    i_rst       ,

    axi4_stream_if.slave            i_axis      ,
    axi4_stream_if.master           o_axis
);

    localparam integer unsigned NB_BYTE = 8;

    generate
        if (i_axis.N_BYTES_TDATA != o_axis.N_BYTES_TDATA) begin : g_check_data_width
            $fatal(1, "Both input and output ports must be the same width in this AXI4-Stream FIFO");
        end
    endgenerate

    //add extra i vs o checks

    axis_fifo #(
        .DEPTH                  ( DEPTH                         ),
        .DATA_WIDTH             ( NB_BYTE*i_axis.N_BYTES_TDATA  ),
        .KEEP_ENABLE            ( i_axis.HAS_TKEEP              ),
        .LAST_ENABLE            ( 1'b1                          ),
        .ID_ENABLE              ( i_axis.HAS_TID                ),
        .ID_WIDTH               ( i_axis.N_BITS_TID             ),
        .DEST_ENABLE            ( i_axis.HAS_TDEST              ),
        .DEST_WIDTH             ( i_axis.N_BITS_TDEST           ),
        .USER_ENABLE            ( i_axis.HAS_TUSER              ),
        .USER_WIDTH             ( i_axis.N_BITS_TUSER           ),
        .RAM_PIPELINE           ( 5                             ),
        .OUTPUT_FIFO_ENABLE     ( 1                             ),
        .FRAME_FIFO             ( 1'b0                          ),
        .USER_BAD_FRAME_VALUE   ( 1'b1                          ),
        .USER_BAD_FRAME_MASK    ( 1'b1                          ),
        .DROP_OVERSIZE_FRAME    ( 1'b0                          ),
        .DROP_BAD_FRAME         ( 1'b0                          ),
        .DROP_WHEN_FULL         ( 1'b0                          )
    )
    u_axis_fifo
    (
        .clk                    ( i_clk                         ),
        .rst                    ( i_rst                         ),
        .s_axis_tdata           ( i_axis.tdata                  ),
        .s_axis_tkeep           ( i_axis.tkeep                  ),
        .s_axis_tvalid          ( i_axis.tvalid                 ),
        .s_axis_tready          ( i_axis.tready                 ),
        .s_axis_tlast           ( i_axis.tlast                  ),
        .s_axis_tid             ( i_axis.tid                    ),
        .s_axis_tdest           ( i_axis.tdest                  ),
        .s_axis_tuser           ( i_axis.tuser                  ),
        .m_axis_tdata           ( o_axis.tdata                  ),
        .m_axis_tkeep           ( o_axis.tkeep                  ),
        .m_axis_tvalid          ( o_axis.tvalid                 ),
        .m_axis_tready          ( o_axis.tready                 ),
        .m_axis_tlast           ( o_axis.tlast                  ),
        .m_axis_tid             ( o_axis.tid                    ),
        .m_axis_tdest           ( o_axis.tdest                  ),
        .m_axis_tuser           ( o_axis.tuser                  ),
        .status_overflow        (                               ),
        .status_bad_frame       (                               ),
        .status_good_frame      (                               )
    );

endmodule
