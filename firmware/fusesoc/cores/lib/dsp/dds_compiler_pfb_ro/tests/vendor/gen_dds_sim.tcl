# Generate the DDS Compiler simulation model of dds_compiler_pfb_ro from the
# committed .xci. usage: vivado -mode batch -source gen_dds_sim.tcl -tclargs <workdir>
# import_ip copies the .xci into the project, so every output lands under
# <workdir>/proj.
set work [file normalize [lindex $argv 0]]
create_project -force ddssim $work/proj -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
import_ip $work/dds_compiler_pfb_ro.xci
generate_target simulation [get_ips]
