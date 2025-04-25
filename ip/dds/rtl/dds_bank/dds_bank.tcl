

set ProjectName  "dds_bank"
set PartDev      "xc7z010clg400-1" 

set TclPath      [file dirname [file normalize [info script]]]
set ProjectPath  $TclPath/build
put $TclPath
put $ProjectPath

create_project $ProjectName $ProjectPath -part $PartDev
set_property target_language VHDL [current_project]
set_property  ip_repo_paths  $TclPath/ip_repo [current_project]
update_ip_catalog


# adding dds compilers

create_ip -name axis_dds_bank -vendor stratum -library user -version 1.0 -module_name ddsb
set_property -dict [list CONFIG.NCH {12} CONFIG.AXIS_TDATA_WIDTH {16}] [get_ips ddsb]
generate_target {instantiation_template} [get_files $ProjectPath/$ProjectName.srcs/sources_1/ip/ddsb/ddsb.xci]
generate_target all [get_files  $ProjectPath/$ProjectName.srcs/sources_1/ip/ddsb/ddsb.xci]



set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $TclPath/rtl_tb/read_data_file.vhd
add_files -fileset sim_1 -norecurse $TclPath/rtl_tb/write_data_file.vhd
add_files -fileset sim_1 -norecurse $TclPath/rtl_tb/dds_bank_tb.vhd
add_files -fileset sim_1 -norecurse $TclPath/waveform/dds_bank_tb_behav.wcfg

set_property top dds_bank_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
