# Generate the FIR Compiler simulation models of fir_pfb_ro_0..7 from the
# committed .xci files. usage: vivado -mode batch -source gen_fir_sim.tcl -tclargs <workdir>
# import_ip copies each .xci into the project, so every output lands under
# <workdir>/proj (read_ip would follow the gen_directory stored in the .xci).
set work [file normalize [lindex $argv 0]]
create_project -force firsim $work/proj -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
for {set i 0} {$i < 8} {incr i} {
    import_ip $work/xci/fir_pfb_ro_$i/fir_pfb_ro_$i.xci
}
generate_target simulation [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -force
