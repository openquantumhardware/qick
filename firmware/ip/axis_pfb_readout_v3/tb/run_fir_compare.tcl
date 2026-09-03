# Vivado batch simulation for the individual FIR IP/model protocol bench.

set proj_name "fir_compare"
set tb_dir [file dirname [file normalize [info script]]]
set proj_dir [file normalize "$tb_dir/fir_sim_work"]
set src_dir [file normalize "$tb_dir/../src"]
set fir_xci [file normalize "$src_dir/pfb/fir/fir_0/fir_0.xci"]

create_project -force $proj_name $proj_dir -part xczu49dr-ffvf1760-2-e
set_property simulator_language Mixed [current_project]
add_files -norecurse $fir_xci
add_files -norecurse [file normalize "$src_dir/verilog/fir_axis_model_sv.sv"]
add_files -norecurse [file normalize "$src_dir/verilog/fir_0_sv.sv"]
add_files -norecurse [file normalize "$tb_dir/tb_fir_compare.sv"]
set_property top tb_fir_compare [get_filesets sim_1]
update_compile_order -fileset sim_1
generate_target simulation [get_files $fir_xci]
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
