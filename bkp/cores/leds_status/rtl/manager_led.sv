module manager_led 
#(
     parameter integer unsigned N_LED     = 3,
     parameter integer unsigned IP_FREQ   = 100000000,
     parameter integer unsigned NB_CNTR   = 32
     )
(
    input logic                  i_clk    ,
    input logic                  i_rst    ,

    input logic  [NB_CNTR-1 : 0] i_blink_time  ,
    input logic  [2-1 : 0]       i_mode   ,
    input logic  [N_LED-1 : 0]   i_led    ,

    output logic [N_LED-1 : 0]   o_led
    
);

    logic [N_LED-1 : 0]   led_s;
    genvar i;
    generate
    for ( i = 0 ; i < N_LED ; i++ ) begin
      blink_gen# (
        .IP_FREQ ( IP_FREQ ),
        .NB_CNTR ( NB_CNTR )
      ) u_blink_gen(
        .i_clk        ( i_clk        ),
        .i_rst        ( i_rst        ),
        .i_blink_time ( i_blink_time ),
        .i_enable     ( i_led[i]     ),
        .o_blink      ( led_s[i]     )
      );
    end
    endgenerate

    always_comb
    begin
      for ( int j = 0 ; j < N_LED ; j++ ) begin
        if (i_mode == 2'b00) // LED OFF Mode
          o_led[j] = 1'b0;
        else if (i_mode == 2'b01) // LED ON Mode
          o_led[j] = i_led[j];
        else if (i_mode == 2'b11) // LED Blinking Mode
          o_led[j] = led_s[j];
        else
          o_led[j] = 1'b0;
      end
    end

endmodule
