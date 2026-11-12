# Generate the FIR Compiler simulation model of fir_decim8_dynro from the committed .xci.
# usage: vivado -mode batch -source gen_fir_sim.tcl -tclargs <workdir>   (<workdir>/xci holds the .xci and the .coe)
# import_ip copies the .xci into the project, so every output lands under <workdir>/proj (read_ip would follow the
# gen_directory stored in the .xci). The .xci was customised with an older revision of the IP: upgrade_ip first.
set work [file normalize [lindex $argv 0]]
create_project -force firsim $work/proj -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
import_ip $work/xci/fir_decim8_dynro.xci
upgrade_ip [get_ips]
generate_target simulation [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -force
