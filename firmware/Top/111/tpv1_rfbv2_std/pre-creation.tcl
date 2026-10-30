# HOG runs this script before it creates the project: package the BD's qick:ip IPs
# from the sources of the current commit (see scripts/hog/package_bd_ips.tcl).
set qick_top_dir [file dirname [file normalize [info script]]]
source [file normalize "$qick_top_dir/../../../scripts/hog/package_bd_ips.tcl"]
