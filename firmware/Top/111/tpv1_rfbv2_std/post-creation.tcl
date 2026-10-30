# HOG executes this script at the very end of CreateProject,
# after setting the top module — use it to override the top
# with the BD wrapper, which is the actual design top.

set_property top "d_1_wrapper" [get_filesets sources_1]
update_compile_order -fileset sources_1
