# Generate the simulation models of the eight FIR Compilers and the DDS Compiler of the PFB readout from the committed .xci.
# usage: vivado -mode batch -source gen_ip_sim.tcl -tclargs <workdir>   (<workdir>/xci/<ip>/<ip>.xci)
# import_ip copies the .xci into the project (read_ip would follow the gen_directory stored in it); upgrade_ip first, the
# .xci were customised with older revisions of the IPs.
set work [file normalize [lindex $argv 0]]
create_project -force ipsim $work/proj -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
for {set i 0} {$i < 8} {incr i} { import_ip $work/xci/fir_pfb_ro_$i/fir_pfb_ro_$i.xci }
import_ip $work/xci/dds_compiler_pfb_ro/dds_compiler_pfb_ro.xci
upgrade_ip [get_ips]
generate_target simulation [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -force
