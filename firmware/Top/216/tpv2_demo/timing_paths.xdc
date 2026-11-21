# timing_paths.xdc: false paths through IP boundary pins. Split out of timing.xdc so it stays
# in synthesis (these pins exist in the top-level netlist) while timing.xdc is nosynth.

# readout triggers
#set_false_path -through [get_cells d_1_i/qick_vec2bit_1]
set_false_path -through [get_pins -hier -filter {name =~ */qick_processor_0/trig_*_o}]

# reset
set_false_path  -through [get_pins -hier -filter {name =~ */rst_dac2/peripheral_aresetn[0]}]
