import leds_status_regmap_pkg::*;

module leds_status 
#(
     parameter integer unsigned N_LED         = 3           ,
     parameter integer unsigned IP_FREQ       = 100000000   ,
     parameter integer unsigned NB_CNTR       = 32
     )
(
    input logic                         i_clk               ,
    input logic                         i_rst               ,
    axi4lite_intf.slave                 s_axil              ,

    output logic [N_LED-1   : 0]        o_led_mode          ,
    output logic [N_LED-1   : 0]        o_led_status        ,
    output logic [N_LED-1   : 0]        o_led_gnss          ,
    output logic [N_LED-1   : 0]        o_led_track
);

    logic [8-1       : 0] led_id_mode  ;
    logic [8-1       : 0] led_id_status;
    logic [8-1       : 0] led_id_gnss  ;
    logic [8-1       : 0] led_id_track ;
    logic [NB_CNTR-1 : 0] blink_time   ;
    logic                 i_gen_rst    ;

    leds_status_regmap_pkg::leds_status_regmap__out_t csr_outputs;

    leds_status_regmap u_csr(
        .clk      ( i_clk       ) ,
        .rst      ( i_rst       ) ,
        .s_axil   ( s_axil      ) ,
        .hwif_out ( csr_outputs )
    );

    assign i_gen_rst     = (i_rst | csr_outputs.rst.pulse_rst.value | csr_outputs.rst.toggle_rst.value );
    assign blink_time    = csr_outputs.led_registers.blink_time.btime.value;

    assign led_id_mode   = csr_outputs.led_registers.led_id.mode.value;
    assign led_id_status = csr_outputs.led_registers.led_id.status.value;
    assign led_id_gnss   = csr_outputs.led_registers.led_id.gnss.value;
    assign led_id_track  = csr_outputs.led_registers.led_id.track.value;

    // MODE LED
    manager_led#(
      .N_LED   ( N_LED   ),
      .IP_FREQ ( IP_FREQ ),
      .NB_CNTR ( NB_CNTR )
    ) u_mode_manager_led (
      .i_clk              ( i_clk            ),
      .i_rst              ( i_gen_rst        ),
      .i_blink_time       ( blink_time       ),
      .i_mode             ( led_id_mode[1:0] ),
      .i_led              ( led_id_mode[5:3] ),
      .o_led              ( o_led_mode       ) 
    );

    // STATUS LED
    manager_led#(
      .N_LED   ( N_LED   ),
      .IP_FREQ ( IP_FREQ ),
      .NB_CNTR ( NB_CNTR )
    ) u_status_manager_led (
      .i_clk              ( i_clk              ),
      .i_rst              ( i_gen_rst          ),
      .i_blink_time       ( blink_time         ),
      .i_mode             ( led_id_status[1:0] ),
      .i_led              ( led_id_status[5:3] ),
      .o_led              ( o_led_status       ) 
    );

    // GNSS LED
    manager_led#(
      .N_LED   ( N_LED   ),
      .IP_FREQ ( IP_FREQ ),
      .NB_CNTR ( NB_CNTR )
    ) u_gnss_manager_led (
      .i_clk              ( i_clk            ),
      .i_rst              ( i_gen_rst        ),
      .i_blink_time       ( blink_time       ),
      .i_mode             ( led_id_gnss[1:0] ),
      .i_led              ( led_id_gnss[5:3] ),
      .o_led              ( o_led_gnss       ) 
    );

    // TRACK LED
    manager_led#(
      .N_LED   ( N_LED   ),
      .IP_FREQ ( IP_FREQ ),
      .NB_CNTR ( NB_CNTR )
    ) u_track_manager_led (
      .i_clk              ( i_clk             ),
      .i_rst              ( i_gen_rst         ),
      .i_blink_time       ( blink_time        ),
      .i_mode             ( led_id_track[1:0] ),
      .i_led              ( led_id_track[5:3] ),
      .o_led              ( o_led_track       ) 
    );

endmodule
