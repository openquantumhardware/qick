# Vivado batch simulation for the FIR IP/model comparison bench.

set proj_name "firs_compare"
set part_name "xczu49dr-ffvf1760-2-e"
set tb_dir [file dirname [file normalize [info script]]]
set proj_dir [file normalize "$tb_dir/firs_sim_work"]
set src_dir [file normalize "$tb_dir/../src"]
set fir_xci_files [glob -nocomplain [file normalize "$src_dir/pfb/fir/fir_*/fir_*.xci"]]

create_project -force $proj_name $proj_dir -part $part_name
set_property simulator_language Mixed [current_project]

# Add all generated FIR IPs used by firs EMULATOR=0.
foreach fir_xci $fir_xci_files {
	add_files -norecurse $fir_xci
}
add_files -norecurse [file normalize "$src_dir/pfb/pfb_ctrl_pkg.vhd"]
add_files -norecurse [file normalize "$src_dir/pfb/pfb_cfg.vhd"]
add_files -norecurse [file normalize "$src_dir/pfb/pfb_framing.vhd"]
add_files -norecurse [file normalize "$src_dir/pfb/pfb_ctrl.vhd"]
add_files -norecurse [file normalize "$src_dir/pfb/zn_nb.vhd"]
add_files -norecurse [file normalize "$src_dir/verilog/fir_axis_model_sv.sv"]
foreach fir_index {0 1 2 3 4 5 6 7} {
	add_files -norecurse [file normalize "$src_dir/verilog/fir_${fir_index}_sv.sv"]
}
add_files -norecurse [file normalize "$src_dir/pfb/firs.sv"]
add_files -norecurse [file normalize "$tb_dir/tb_firs_compare.sv"]

set_property top tb_firs_compare [get_filesets sim_1]
update_compile_order -fileset sim_1
generate_target simulation [get_files -filter {FILE_TYPE == "IP"}]
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
