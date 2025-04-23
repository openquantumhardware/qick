/***********************************************
 *
 *  Copyright (C) 2022 - Stratum Labs
 *
 *  Project: Stratum Labs - Common Library
 *  Author: Leandro Echevarria <leo.echevarria@stratum-labs.com>
 *
 *  File: data_to_axis_fifo.sv
 *  Description: adds back-pressure to data/valid stream
 *  by means of a FIFO buffer and adapting the outputs to AXI-4 Stream
 *
 * ********************************************/

module data_to_axis_fifo
#(
    parameter integer unsigned      DEPTH   = 16
)
(
    input  logic                    i_clk       ,
    input  logic                    i_rst       ,

    data_stream_if.slave            i_datas     ,
    axi4_stream_if.master           o_axis      ,

    output logic                    o_empty     ,
    output logic                    o_full
);

    generate
        if ((i_datas.NB_DATA/8.0) != o_axis.N_BYTES_TDATA) begin : g_check_data_width
            $fatal(1, "Both input and output ports must be the same width in this Data to AXIS FIFO");
        end
    endgenerate

    logic fifo_s_tready;

    axis_fifo #(
        .DEPTH                  ( DEPTH                         ),
        .DATA_WIDTH             ( i_datas.NB_DATA               ),
        .KEEP_ENABLE            ( o_axis.HAS_TKEEP              ),
        .LAST_ENABLE            ( 1'b1                          ),
        .ID_ENABLE              ( o_axis.HAS_TID                ),
        .ID_WIDTH               ( o_axis.N_BITS_TID             ),
        .DEST_ENABLE            ( o_axis.HAS_TDEST              ),
        .DEST_WIDTH             ( o_axis.N_BITS_TDEST           ),
        .USER_ENABLE            ( o_axis.HAS_TUSER              ),
        .USER_WIDTH             ( o_axis.N_BITS_TUSER           ),
        .RAM_PIPELINE           ( 1                             ),
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
        .s_axis_tdata           ( i_datas.data                  ),
        .s_axis_tkeep           ( '1                            ),
        .s_axis_tvalid          ( i_datas.valid                 ),
        .s_axis_tready          ( fifo_s_tready                 ),
        .s_axis_tlast           ( i_datas.last                  ),
        .s_axis_tid             ( '0                            ),
        .s_axis_tdest           ( '0                            ),
        .s_axis_tuser           ( '0                            ),
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

    // OUTPUT ASSIGNMENTS
    assign o_empty = !o_axis.tvalid;
    assign o_full  = !fifo_s_tready;

endmodule
