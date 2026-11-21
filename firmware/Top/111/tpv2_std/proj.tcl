# proj.tcl of this project, used in two ways with the same files:
#
#  * With Hog (./Hog/Do CREATE <board>/<project>): Hog has already created the project from hog.conf and list/*, and
#    sources this script from list/others.src to add the block design (post-creation.tcl sets the top afterwards).
#  * Without Hog (a public build, no fusesoc, no Hog): from the firmware/ directory,
#        vivado -mode batch -source Top/<board>/<project>/proj.tcl      (or `source` it in the Tcl console)
#    there is no project yet, so the part, the board part and the IP repository come from hog.conf and the constraints and sources from
#    list/constraints.con, list/src.src and list/ips.src (the single source of all of them), and the project is created in
#    Projects/<board>/<project>.
#    The IP repository (ip/) holds the packaged IPs, which are a product of the fusesoc flow and ship with the release.
#    Then run synthesis and implementation (launch_runs impl_1 -to_step write_bitstream, or "Generate Bitstream").

set origin_dir [file dirname [file normalize [info script]]]
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# [section] key=value pairs of a Hog configuration file, as a dict
proc qick_hog_conf {path section} {
    set conf [dict create]
    set in_section 0
    set fh [open $path r]
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        if {[regexp {^\[(.*)\]$} $line -> name]} {
            set in_section [expr {$name eq $section}]
        } elseif {$in_section && [regexp {^([^=]+)=(.*)$} $line -> key value]} {
            dict set conf [string trim $key] [string trim $value]
        }
    }
    close $fh
    return $conf
}

# Standalone: no Hog project is open, create it from the same files Hog reads
set qick_standalone [expr {[llength [get_projects -quiet]] == 0}]
if {$qick_standalone} {
    set qick_fw_dir   [file normalize $origin_dir/../../..]
    set qick_proj     [file tail $origin_dir]
    set qick_board    [file tail [file dirname $origin_dir]]
    set qick_out_dir  $qick_fw_dir/Projects/$qick_board/$qick_proj
    set qick_conf     [qick_hog_conf $origin_dir/hog.conf main]
    if {[file exists $qick_out_dir]} {
        error "proj.tcl: $qick_out_dir exists; remove it (or open its .xpr) before creating the project again"
    }
    # board definitions shipped with the repository (RFSoC 4x2 / 2x4); Xilinx's own boards come from Vivado's store
    if {[file isdirectory $qick_fw_dir/board_files]} {
        set_param board.repoPaths [list $qick_fw_dir/board_files]
    }
    create_project $qick_proj $qick_out_dir -part [dict get $qick_conf PART]
    if {[dict exists $qick_conf BOARD_PART]} {
        set_property board_part [dict get $qick_conf BOARD_PART] [current_project]
    }
    if {[dict exists $qick_conf TARGET_LANGUAGE]} {
        set_property target_language [dict get $qick_conf TARGET_LANGUAGE] [current_project]
    }
    set qick_repos {}
    foreach r [dict get $qick_conf IP_REPO_PATHS] {
        lappend qick_repos [file normalize $qick_fw_dir/$r]
    }
    set_property ip_repo_paths $qick_repos [current_fileset]
    update_ip_catalog -rebuild

    # The hand-written Hog lists, one file per line, relative to firmware/, then a library (VHDL) and flags:
    #   list/constraints.con -> constraints, list/src.src -> sources, list/ips.src -> IP (.xci) files
    # (list/qick_ip_*.src only track the IPs' own RTL for Hog's version and are not used by a build)
    foreach {qick_list qick_fileset} {constraints.con constrs_1 src.src sources_1 ips.src sources_1} {
        if {![file exists $origin_dir/list/$qick_list]} continue
        set fh [open $origin_dir/list/$qick_list r]
        while {[gets $fh line] >= 0} {
            set line [string trim $line]
            if {$line eq "" || [string index $line 0] eq "#"} continue
            set words [split $line]
            set path [file normalize $qick_fw_dir/[lindex $words 0]]
            if {"source" in $words} continue
            add_files -fileset $qick_fileset -norecurse $path
            set lib [lindex $words 1]
            if {$lib ne "" && $lib ni {nosynth noimpl nosim 93 lib} && [string match -nocase *.vhd* $path]} {
                set_property LIBRARY $lib [get_files $path]
            }
            if {"nosynth" in $words} { set_property USED_IN_SYNTHESIS false [get_files $path] }
            if {"noimpl"  in $words} { set_property USED_IN_IMPLEMENTATION false [get_files $path] }
            if {"nosim"   in $words} { set_property USED_IN_SIMULATION false [get_files $path] }
        }
        close $fh
    }
}

# The block design script: the bd_<version>.tcl of this directory (bd_2023-1.tcl, bd_2025.2.tcl). A project that keeps scripts
# for several Vivado versions gets the one of the version that is running.
set qick_bd_files [glob -nocomplain -directory $origin_dir bd_*.tcl]
set qick_bd ""
foreach f $qick_bd_files {
    if {[regexp {bd_(\d+)[.-](\d+)\.tcl$} [file tail $f] -> yr rel] && "$yr.$rel" eq [version -short]} {
        set qick_bd $f
    }
}
if {$qick_bd eq "" && [llength $qick_bd_files] == 1} {
    set qick_bd [lindex $qick_bd_files 0]
}
if {$qick_bd eq ""} {
    error "proj.tcl: no unique bd_*.tcl for Vivado [version -short] in $origin_dir (found: $qick_bd_files)"
}
puts "proj.tcl: block design [file tail $qick_bd]"

# Source the Block Design TCL
source $qick_bd

# Generate the BD output products now, before Hog records the files the scripts
# added (CheckExtraFiles, end of CREATE). Hog takes their md5 first and generates the
# BD targets after; in that order the wrapper is rewritten (new date in its header)
# and the IPs' .coe appear after the record, so Hog's pre-synthesis check reports
# them and sets the bitstream's version to 0. Generated here, nothing changes after.
generate_target all [get_files d_1.bd]

# Generate the BD wrapper
make_wrapper -files [get_files d_1.bd] -top

# Add the wrapper from the Vivado-generated location (.gen/)
set wrapper [get_files -of_objects [get_filesets sources_1] \
    -filter {NAME =~ "*/d_1/hdl/d_1_wrapper.v"}]
if {$wrapper eq ""} {
    set proj_dir  [get_property DIRECTORY [current_project]]
    set proj_name [get_property NAME      [current_project]]
    set wrapper_path [file normalize \
        "$proj_dir/${proj_name}.gen/sources_1/bd/d_1/hdl/d_1_wrapper.v"]
    add_files -norecurse -fileset [get_filesets sources_1] $wrapper_path
}

# Synthesis and implementation strategies
set_property strategy "Flow_PerfOptimized_high"   [get_runs synth_1]
set_property strategy "Performance_NetDelay_high" [get_runs impl_1]

# What Hog does in post-creation.tcl, for the standalone project
if {$qick_standalone} {
    set_property top "d_1_wrapper" [get_filesets sources_1]
    update_compile_order -fileset sources_1
    puts "proj.tcl: project created in $qick_out_dir"
}
