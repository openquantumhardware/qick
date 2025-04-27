# Source metadata
source ./tcl/metadata.tcl

# Create project 
set ip_project [ create_project -name ${design} -force -dir ${proj_dir} -ip ]
set_property top ${top} [current_fileset]
set_property source_mgmt_mode All ${ip_project}

# Read source files from hdl directory
set v_src_files [glob ./hdl/*.v]
set sv_src_files [glob ./hdl/*.sv]
read_verilog ${v_src_files}
read_verilog -sv ${sv_src_files}
update_compile_order -fileset sources_1

# Package project and set properties
ipx::package_project
set ip_core [ipx::current_core]
set_property -dict ${ip_properties} ${ip_core}
set_property SUPPORTED_FAMILIES ${family_lifecycle} ${ip_core}

# Associate AXI/AXIS interfaces and reset with clock
set aclk_intf [ipx::get_bus_interfaces ACLK -of_objects ${ip_core}]
set aclk_assoc_intf [ipx::add_bus_parameter ASSOCIATED_BUSIF $aclk_intf]
set_property value M_AXIS:S_AXIS:S_AXI $aclk_assoc_intf
set aclk_assoc_reset [ipx::add_bus_parameter ASSOCIATED_RESET $aclk_intf]
set_property value ARESETN $aclk_assoc_reset

# Set reset polarity
set aresetn_intf [ipx::get_bus_interfaces ARESETN -of_objects ${ip_core}]
set aresetn_polarity [ipx::add_bus_parameter POLARITY $aresetn_intf]
set_property value ACTIVE_LOW ${aresetn_polarity}

# Save IP and close project
ipx::check_integrity ${ip_core}
ipx::save_core ${ip_core}
close_project
file delete -force ${proj_dir}
