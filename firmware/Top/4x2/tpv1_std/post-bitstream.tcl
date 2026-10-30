# HOG sources this script at the end of its post-bitstream step: copy the BD's .hwh
# next to the bitstream in bin/, with the same name (see scripts/hog/copy_hwh.tcl), and
# write the timing summary of the routed design there (scripts/hog/timing_summary.tcl).
source [file normalize "./scripts/hog/copy_hwh.tcl"]
source [file normalize "./scripts/hog/timing_summary.tcl"]
