# timing_paths.xdc: false paths through IP boundary pins. Split out of timing.xdc so it stays
# in synthesis (these pins exist in the top-level netlist) while timing.xdc is nosynth.

# readout triggers
#set_false_path -through [get_cells d_1_i/qick_vec2bit_1]
set_false_path -through [get_pins -hier -filter {name =~ */qick_processor_0/trig_*_o}]

# reset
set_false_path -through [get_pins -hier -filter {name =~ */rst_dac2/peripheral_aresetn[0]}]
set_false_path -through [get_pins -hier -filter {name =~ */rst_dac0/peripheral_aresetn[0]}]

## PMOD outputs
#set_false_path -to [get_ports PMOD0_*]
## PMOD inputs
#set_false_path -from [get_ports PMOD1_*]
## DDR4 reset output
#set_false_path -to [get_ports ddr4_sdram_c0_reset_n]