module utc_time 
#(
     parameter integer unsigned         NB_MAX_COUNT            = 32,
     parameter integer unsigned         NB_TIMEOUT              =  24,
     parameter integer unsigned         TIMEOUT_MAX             =  4e6,
     parameter integer unsigned         CLK_FREQ                = 40e6,
     parameter integer unsigned         NB_CLK_COUNT            = $clog2(CLK_FREQ)
     )
(
    input logic                         i_clk               ,
    input logic                         i_rst               ,

    input logic                         i_csr_rst           ,
    input logic                         i_csr_clk           ,

    input logic                         i_pps               ,

    output logic [NB_MAX_COUNT-1   : 0] o_pps_count         ,

    axi4lite_intf.slave                 s_axil              ,
    axi4_stream_if.slave                i_axis              ,

    output adsb_pkg::time_t             o_time_data         ,
    output logic                        o_valid             ,
    output logic                        o_nmea_absent       ,
    output logic                        o_nmea_checksum_err ,
    output logic [NB_CLK_COUNT-1 : 0]   o_timeoffset        ,
    output logic [3:0]                  o_dbg_state,
    output logic [7:0]                  o_i_data_dbg,
    output logic                        dgb_nmea_zda_decoder_rdy,
    output logic [7:0]                  dbg_checksum,
    output logic [7:0]                  dbg_checksum_recv_deco,
    output logic dbg_newdata,
    output logic dbg_checksum_bit_selector,
    output logic dbg_nmea_zda_decoder_badframe,
    output [11:0] dbg_timedata_index,
    output [47:0] dbg_nmea_header
);

    logic [NB_MAX_COUNT-1   : 0]        clk_btw_pps_max_count;
    logic [NB_MAX_COUNT-1   : 0]        pps_cntr_reg;
    logic [NB_MAX_COUNT-1   : 0]        pps_cntr_next;
    logic [NB_MAX_COUNT-1   : 0]        clk_btw_pps_reg;
    logic [NB_MAX_COUNT-1   : 0]        clk_btw_pps_next;
    logic                               i_gen_rst;
    logic                               sw_maxcntr_en;

    logic                               nmea_absent_count_done;
    logic [NB_CLK_COUNT-1   : 0]        time_offset_nozda_counter;

    adsb_pkg::time_t                    nmea_data;
    adsb_pkg::time_t                    last_valid_nmea_data;
    logic                               nmea_valid;

    logic                               nmea_zda_decoder_badframe;
    logic                               nmea_zda_decoder_timeout;
    logic                               nmea_zda_decoder_checksum_error;

     assign i_gen_rst = (i_rst |
                         csr_outputs.rst.pulse_rst.value |
                         csr_outputs.rst.toggle_rst.value );

    import utc_time_regmap_pkg::*;

    utc_time_regmap_pkg::utc_time_regmap__in_t  csr_inputs;
    utc_time_regmap_pkg::utc_time_regmap__out_t csr_outputs;


    utc_time_regmap u_csr(
        .clk      ( i_csr_clk   ) ,
        .rst      ( i_csr_rst   ) ,
        .s_axil   ( s_axil      ) ,
        .hwif_in  ( csr_inputs  ) ,
        .hwif_out ( csr_outputs )
    );

    assign sw_maxcntr_en = csr_outputs.ctrl_logic_registers.sw_maxcntr_enable.maxcntr_enable.value;
    assign clk_btw_pps_max_count = csr_outputs.ctrl_logic_registers.max_count.max_count.value;
    assign csr_inputs.status_registers.clk_btw_pps.clk_btw_pps.next = pps_cntr_reg;

    //register
    always_ff @(posedge i_clk)
    begin
      if(i_gen_rst) begin
        clk_btw_pps_reg <= {NB_MAX_COUNT{1'b0}};
        pps_cntr_reg    <= {NB_MAX_COUNT{1'b0}};
      end
      else begin 
        clk_btw_pps_reg <= clk_btw_pps_next; 
        pps_cntr_reg    <= pps_cntr_next; 
      end
    end

    //next state
    always_comb
    begin
      if ( i_pps || (sw_maxcntr_en && ( clk_btw_pps_reg == clk_btw_pps_max_count ))) begin
        clk_btw_pps_next = {NB_MAX_COUNT{1'b0}};
        pps_cntr_next    = clk_btw_pps_reg;
      end else begin 
        clk_btw_pps_next = clk_btw_pps_reg + 1'b1;
        pps_cntr_next    = pps_cntr_reg; 
      end
    end

    //time offset for no zda counter
    always_ff @(posedge i_clk)
    begin
      if(i_rst || ~nmea_absent_count_done) time_offset_nozda_counter <= '0;
      if(nmea_absent_count_done && i_pps) time_offset_nozda_counter <= time_offset_nozda_counter + 1;
    end

    common_counter
    #(
        .NB_MAX_COUNT       ( NB_CLK_COUNT                                          )
    )
    nmea_absent_counter
    (
        .i_clk              ( i_clk                                                 ),
        .i_rst              ( i_gen_rst || nmea_valid                               ),
        .i_start_count      ( 1'b1                                                  ),
        .i_enable           ( 1'b1 & ~nmea_absent_count_done                        ),
        .i_rf_max_count     ( NB_CLK_COUNT'(CLK_FREQ)                               ),

        .o_counter          (),
        .o_count_done       ( nmea_absent_count_done                                ),
        .o_count_in_process ()
    );

    nmea_zda_decoder
    #(
      .NB_TIMEOUT           ( NB_TIMEOUT                                            ),
      .TIMEOUT_MAX          ( TIMEOUT_MAX                                           )
    ) 
    u_nmea_zda_decoder
    (
      .i_clk                ( i_clk                                                 ),
      .i_rst                ( i_gen_rst                                             ),
      .i_axis               ( i_axis                                                ),
      .o_rf_badframe        ( nmea_zda_decoder_badframe                             ),
      .o_rf_timeout         ( nmea_zda_decoder_timeout                              ),
      .o_rf_checksum_error  ( nmea_zda_decoder_checksum_error                       ),
      .o_time_data          ( nmea_data                                             ),
      .o_valid              ( nmea_valid                                            ),
      .o_dbg_state          ( o_dbg_state ),
      .o_i_data_dbg         ( o_i_data_dbg ),
      .dbg_checksum(dbg_checksum),
      .dbg_checksum_recv_deco(dbg_checksum_recv_deco),
      .dbg_newdata(dbg_newdata),
      .dbg_timedata_index(dbg_timedata_index),
      .dbg_nmea_header(dbg_nmea_header)
    );

    assign  csr_inputs.status_registers.error.badframe.next         = nmea_zda_decoder_badframe;
    assign  csr_inputs.status_registers.error.timeout.next          = nmea_zda_decoder_timeout;
    assign  csr_inputs.status_registers.error.checksum_error.next   = nmea_zda_decoder_checksum_error;

    assign  o_pps_count         = clk_btw_pps_reg;
    assign  o_time_data         = nmea_data;
    assign  o_valid             = nmea_valid;

    assign  o_nmea_absent       = nmea_absent_count_done;
    assign  o_nmea_checksum_err = nmea_zda_decoder_checksum_error;
    assign  o_timeoffset        = time_offset_nozda_counter;

    assign dbg_nmea_zda_decoder_badframe = nmea_zda_decoder_badframe;
endmodule
