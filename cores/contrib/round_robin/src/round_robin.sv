module round_robin
#(
    parameter bit ASCENDING    = 1'b1,
    parameter bit TLAST_IS_EOF = 1'b0
)
(
    input logic           i_clk,
    input logic           i_rst,

    axi4_stream_if.slave  i_axis,
    axi4_stream_if.master o_axis
);
    initial begin
        if (i_axis.N_BYTES_TDATA % o_axis.N_BYTES_TDATA != 0) begin : g_check_n_channels
            $fatal(1, "Input data size %0d is not divisible into channels of size %0d",
                $bits(i_axis.tdata), $bits(o_axis.tdata));
        end
    end

    // generate
        // // Surround in generate as a workaround for Vivado's bug reading
        // // interface parameters
        // localparam N_CHANNELS = i_axis.N_BYTES_TDATA/o_axis.N_BYTES_TDATA;
    // endgenerate

    // Generate produce hierarchical access error during synthesis, thanks
    // vivado
    localparam N_CHANNELS = i_axis.N_BYTES_TDATA/o_axis.N_BYTES_TDATA;
    // Lets anounce the actual parameter value just in case
    initial begin
        $info("Round robin calculated N_CHANNELS is %0d", N_CHANNELS);
        $info("Input interface byte size is %0d and Output byte size is %0d",
            i_axis.N_BYTES_TDATA,
            o_axis.N_BYTES_TDATA
            );
    end
        

    /////////////// CHANNEL MUX DRIVER  //////////////
    logic [$clog2(N_CHANNELS)-1:0] channel_counter;
    logic counter_en      ;
    logic counter_clr     ;

    always_ff @ (posedge i_clk) begin
            if (counter_en & o_axis.tready) channel_counter <= channel_counter + 1;
            if (counter_clr)  channel_counter <= '0;
    end
 
    ///////////// ELASTIC BUFFER (SKID BUFFER) FSM ///////////
    enum logic [1:0] {EMPTY, DISTRIBUTING, LASTHALF, LASTFULL} state, next_state;

    always_ff @ (posedge i_clk) begin
        state <= next_state;
        if (i_rst) state <= EMPTY;
    end

    always_comb begin

        // This assignment covers all the incomplete cases
        next_state = state;

        case (state)
            EMPTY: if (i_axis.tvalid) next_state = DISTRIBUTING;

            DISTRIBUTING: begin
                if ((channel_counter == N_CHANNELS-2) & o_axis.tready) begin
                    next_state = LASTHALF;
                end
            end

            LASTHALF: begin
                case ({i_axis.tvalid, o_axis.tready})
                    2'b01: next_state = EMPTY;
                    2'b10: next_state = LASTFULL;
                    2'b11: next_state = DISTRIBUTING;
                endcase
            end
            LASTFULL: if (o_axis.tready) next_state = DISTRIBUTING;
        endcase
    end

    logic input_reg_enable;
    logic s_axis_tready   ;
    logic m_axis_tvalid   ;
    logic m_axis_tlast    ;
    logic buff_selector   ;
    logic output_reg_enable;

    always_comb begin
        buff_selector = 1'b0;
        case (state)
            EMPTY: begin
                input_reg_enable = 1'b1;
                s_axis_tready    = 1'b1;
                m_axis_tvalid    = 1'b0;
                m_axis_tlast     = 'X;
                counter_en       = 1'b0;
            end
            DISTRIBUTING: begin
                input_reg_enable = 1'b0;
                s_axis_tready    = 1'b0;
                m_axis_tvalid    = 1'b1;
                m_axis_tlast     = 1'b0;
                counter_en       = 1'b1;
            end
            LASTHALF: begin
                input_reg_enable = 1'b1;
                s_axis_tready    = 1'b1;
                m_axis_tvalid    = 1'b1;
                m_axis_tlast     = 1'b1;
                counter_en       = 1'b0;
            end
            LASTFULL: begin
                input_reg_enable = 1'b0;
                s_axis_tready    = 1'b0;
                m_axis_tvalid    = 1'b1;
                m_axis_tlast     = 1'b1;
                counter_en       = 1'b0;
                buff_selector    = 1'b1;
            end
        endcase
    end

    assign counter_clr = (next_state == DISTRIBUTING & next_state != state);
    assign output_reg_enable = (next_state == LASTFULL & next_state != state);

    /////////////// DATAPATH //////////////

    logic [N_CHANNELS-1:0][8*o_axis.N_BYTES_TDATA-1:0] input_data_d;
    logic                                              input_last_d;
    logic [8*o_axis.N_BYTES_TDATA-1:0]                 output_data;
    logic [8*o_axis.N_BYTES_TDATA-1:0]                 output_data_d;
    logic                                              output_last_d;

    always_ff @ (posedge i_clk) begin
        if (input_reg_enable) begin
            input_data_d <= i_axis.tdata;
            input_last_d <= i_axis.tlast;
        end
    end

    assign output_data = input_data_d[channel_counter];

    always_ff @ (posedge i_clk) begin
        if (output_reg_enable) begin
            output_data_d <= output_data;
            output_last_d <= input_last_d;
        end
    end

    ///////////// OUTPUT PORT ASSIGNMENT //////////
    logic selected_tuser;

    assign selected_tuser = buff_selector ? output_last_d : input_last_d;

    assign i_axis.tready = s_axis_tready;
    assign o_axis.tdata  = buff_selector ? output_data_d : output_data;
    assign o_axis.tvalid = m_axis_tvalid;

    generate
        if (TLAST_IS_EOF) begin : gen_tlast_behav
            assign o_axis.tlast  = m_axis_tlast & selected_tuser;
        end
        else begin
            assign o_axis.tlast  = m_axis_tlast;
            assign o_axis.tuser  = {o_axis.N_BYTES_TDATA{selected_tuser}};
        end
    endgenerate

endmodule
