# clk_axi  = 100 Mhz
# c_clk    = 200 Mhz 
# t_clk    = 250 Mhz 


## Generated Clocks
set clk_axi  [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_test_i/zynq_ultra_ps_e_0/pl_clk0] ] ]
set c_clk    [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_test_i/qick_processor_0/c_clk_i]  ] ]
set t_clk    [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_test_i/qick_processor_0/t_clk_i]  ] ]

set_clock_groups -name async_clks -asynchronous \
-group [get_clocks [get_clocks $clk_axi ]] \
-group [get_clocks [get_clocks $c_clk   ]] \
-group [get_clocks [get_clocks $t_clk   ]] 

