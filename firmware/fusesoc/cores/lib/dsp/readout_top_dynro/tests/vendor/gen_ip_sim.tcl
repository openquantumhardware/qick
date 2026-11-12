# Generate the simulation models of the DDS Compiler and FIR Compiler IPs of the dynamic readout from the committed .xci.
# usage: vivado -mode batch -source gen_ip_sim.tcl -tclargs <workdir>   (<workdir>/xci/dds and /xci/fir hold the .xci files)
# import_ip copies the .xci into the project (read_ip would follow the gen_directory stored in it); the .xci were
# customised with older revisions of the IPs: upgrade_ip first.
set work [file normalize [lindex $argv 0]]
create_project -force ipsim $work/proj -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
import_ip $work/xci/dds/dds_compiler_dyn_readout.xci
import_ip $work/xci/fir/fir_decim8_dynro.xci
upgrade_ip [get_ips]
generate_target simulation [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -force
