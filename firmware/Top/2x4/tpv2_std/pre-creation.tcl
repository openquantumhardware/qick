# HOG runs this script before it creates the project: package the BD's qick:ip IPs
# from the sources of the current commit (see scripts/hog/package_bd_ips.tcl).
set qick_top_dir [file dirname [file normalize [info script]]]
# The board definition of this project (realdigital.org) is in the repository, not in Vivado's board store.
set_param board.repoPaths [list [file normalize "$qick_top_dir/../../../board_files"]]
source [file normalize "$qick_top_dir/../../../scripts/hog/package_bd_ips.tcl"]
