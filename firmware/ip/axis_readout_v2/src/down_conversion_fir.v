module down_conversion_fir #(
    // Emulator flag to conditionally instantiate behavioral models in place of VHDL/Xilinx IP.
    // Valid values: 0 = synthesis build (use VHDL/Xilinx IP), non-zero = emulation build (use behavioral models).
    parameter EMULATOR = 0
)(
    // Reset and clock.
    rstn                ,
    clk                 ,

    // S_AXIS for input data.
    s_axis_tready_o     ,
    s_axis_tvalid_i     ,
    s_axis_tdata_i      ,

    // M0_AXIS for output data (before filter and decimation).
    m0_axis_tready_i    ,
    m0_axis_tvalid_o    ,
    m0_axis_tdata_o     ,

    // M1_AXIS for output data.
    m1_axis_tready_i    ,
    m1_axis_tvalid_o    ,
    m1_axis_tdata_o     ,

    // Fifo interface.
    fifo_rd_en_o        ,
    fifo_empty_i        ,
    fifo_dout_i
);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
localparam [15:0] N_DDS = 8;

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

output						s_axis_tready_o;
input						s_axis_tvalid_i;
input		[N_DDS*16-1:0]	s_axis_tdata_i;

input						m0_axis_tready_i;
output						m0_axis_tvalid_o;
output		[N_DDS*32-1:0]	m0_axis_tdata_o;

input						m1_axis_tready_i;
output						m1_axis_tvalid_o;
output		[32-1:0]		m1_axis_tdata_o;

output						fifo_rd_en_o;
input						fifo_empty_i;
input		[82:0]			fifo_dout_i;

/********************/
/* Internal signals */
/********************/
// M0 axis signals (output from down_conversion before FIR)
wire                    m0_axis_tvalid_int;
wire    [N_DDS*32-1:0]  m0_axis_tdata_int;

wire                    fir_s_tready;
wire                    fir_m_tvalid;
wire    [31:0]          fir_m_tdata;

/**********************/
/* Begin Architecture */
/**********************/
// Down-conversion block (product with fast DDS) and FIFO for FIR input.
generate
if (!EMULATOR) begin : gen_synth
    // Down-conversion block (product with fast DDS).
    down_conversion 
        #(
            .N_DDS  (N_DDS)
        )
        down_conversion_i
        (
            // Reset and clock.
            .rstn               (rstn                ),
            .clk                (clk                 ),

            // S_AXIS for input.
            .s_axis_tready_o    (s_axis_tready_o     ),
            .s_axis_tvalid_i    (s_axis_tvalid_i     ),
            .s_axis_tdata_i     (s_axis_tdata_i      ),

            // M_AXIS for output.
            .m_axis_tready_i    (m0_axis_tready_i    ),
            .m_axis_tvalid_o    (m0_axis_tvalid_int  ),
            .m_axis_tdata_o     (m0_axis_tdata_int   ),

            // Fifo interface.
            .fifo_rd_en_o       (fifo_rd_en_o        ),
            .fifo_empty_i       (fifo_empty_i        ),
            .fifo_dout_i        (fifo_dout_i         )
        );

    // FIR: 8x decimation, multi-rate implementation, I/Q (2 channels).
    fir_compiler_0 
        fir_i
        (
           .aclk               (clk                 ),
           .s_axis_data_tvalid (m0_axis_tvalid_int  ),
           .s_axis_data_tready (fir_s_tready        ),
           .s_axis_data_tdata  (m0_axis_tdata_int   ),
           .m_axis_data_tvalid (m1_axis_tvalid_o    ),
           .m_axis_data_tdata  (m1_axis_tdata_o     )
        );
end else begin : gen_emu
    // Down-conversion with behavioral models (EMULATOR=1).
    down_conversion #(
        .EMULATOR (1)
    )
    down_conversion_i
    (
        // Reset and clock.
        .rstn               (rstn                ),
        .clk                (clk                 ),

        // S_AXIS for input.
        .s_axis_tready_o    (s_axis_tready_o     ),
        .s_axis_tvalid_i    (s_axis_tvalid_i     ),
        .s_axis_tdata_i     (s_axis_tdata_i      ),

        // M_AXIS for output.
        .m_axis_tready_i    (m0_axis_tready_i    ),
        .m_axis_tvalid_o    (m0_axis_tvalid_int  ),
        .m_axis_tdata_o     (m0_axis_tdata_int   ),

        // Fifo interface.
        .fifo_rd_en_o       (fifo_rd_en_o        ),
        .fifo_empty_i       (fifo_empty_i        ),
        .fifo_dout_i        (fifo_dout_i         )
    );

    // FIR: Behavioral model for emulation
    fir
        #(
            .TAP_COUNT    (120),
            .DATA_WIDTH   (32),
            .COEF_WIDTH   (16),
            .DECIM        (8),
            .CHANNELS     (2),
            .P_SAMPLES    (8)
        )
        fir_i
        (
            .clk                (clk                 ),
            .nrst               (rstn                ),
            .s_tvalid           (m0_axis_tvalid_int  ),
            .s_tready           (fir_s_tready        ),
            .s_tdata            (m0_axis_tdata_int   ),
            .m_tvalid           (fir_m_tvalid        ),
            .m_tdata            (fir_m_tdata         )
        );

    // Connect FIR output to m1_axis
    assign m1_axis_tvalid_o = fir_m_tvalid;
    assign m1_axis_tdata_o  = fir_m_tdata;
end
endgenerate

endmodule

