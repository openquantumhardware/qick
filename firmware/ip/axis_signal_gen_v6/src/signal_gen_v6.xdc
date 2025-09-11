# False Path of Synchronizers
set_false_path -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name=~*data_int_reg_reg[0]*}]]
#set_false_path -to [get_cells -hier -filter {name=~*_cdc_reg*}]

set_false_path \
    -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *axi_slv_i/slv_reg*}]] \
    -to [get_clocks -of_objects [get_nets s0_axis_aclk]]
