# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set _xil_proj_name_ "top"

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"

# Create project
create_project ${_xil_proj_name_} ./${_xil_proj_name_} -part xczu28dr-ffvg1517-2-e

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "xilinx.com:zcu111:part0:1.4" -objects $obj
set_property -name "corecontainer.enable" -value "1" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_core_container" -value "1" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "platform.board_id" -value "zcu216" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY" -objects $obj

# Set IP repository paths
set obj [get_filesets sources_1]
set_property "ip_repo_paths" "[file normalize "$origin_dir/../../ip"]" $obj

# Rebuild user ip_repo's index before adding any source files
update_ip_catalog -rebuild

# Set 'sources_1' fileset object
#set obj [get_filesets sources_1]
#set files [list \
#	[ file normalize "$origin_dir/../../hdl/lo_spi_mux_v2.vhd"]	\
#]
#add_files -norecurse -fileset $obj $files

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set files [list \
	[ file normalize "$origin_dir/timing.xdc"] 	\
	[ file normalize "$origin_dir/ios.xdc"] 	\
]
add_files -fileset $obj $files

# Source Block Design.
set file "[file normalize "$origin_dir/bd_2023-1.tcl"]"
source $file

# Update compile order.
#update_compile_order -fileset sources_1

# Set sources_1 fileset object
set obj [get_filesets sources_1]

# Create HDL Wrapper.
make_wrapper -files [get_files d_1.bd] -top

# Add files to sources_1 fileset
set files [list \
  [file normalize "${origin_dir}/top/top.srcs/sources_1/bd/d_1/hdl/d_1_wrapper.v" ]\
]
add_files -fileset $obj $files

set_property strategy "Flow_PerfOptimized_high" [get_runs synth_1]
#set_property strategy "Flow_AlternateRoutability" [get_runs synth_1]

#set_property strategy "Performance_ExtraTimingOpt" [get_runs impl_1]
#set_property strategy "Performance_Explore" [get_runs impl_1]
#set_property strategy "Flow_RunPostRoutePhysOpt" [get_runs impl_1]
set_property strategy "Performance_NetDelay_high" [get_runs impl_1]
#set_property strategy "Performance_EarlyBlockPlacement" [get_runs impl_1]
