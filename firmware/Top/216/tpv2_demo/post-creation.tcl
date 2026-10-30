# HOG runs this script at the very end of CreateProject,
# after setting its default top module name.
# Override it with the BD wrapper, which is the actual design top.

set_property top "d_1_wrapper" [get_filesets sources_1]
update_compile_order -fileset sources_1
