# Copy the block design's hardware handoff (.hwh) next to the bitstream in bin/.
#
# Sourced by Top/<group>/<project>/post-bitstream.tcl, which Hog sources at the end of
# its own post-bitstream step: Hog's variables are in scope, in particular proj_dir
# (Projects/<group>/<project>), proj_name, dst_dir (bin/<group>/<project>-<describe>)
# and describe (version and SHA).
#
# Hog copies the .bit with the version and SHA in its name, but not the .hwh, which
# PYNQ needs next to the .bit with the same base name. Copied here, both come from the
# same build and carry the same name.

set fh [open "./Top/$group_name/$proj_name/proj.tcl" r]
set qick_proj [read $fh]
close $fh
if {![regexp {make_wrapper -files \[get_files ([A-Za-z0-9_]+)\.bd\]} $qick_proj -> qick_bd]} {
    Msg CriticalWarning "copy_hwh: no make_wrapper of a .bd in proj.tcl; no .hwh copied"
    return
}
set qick_hwh [file normalize "$proj_dir/$proj_name.gen/sources_1/bd/$qick_bd/hw_handoff/$qick_bd.hwh"]
set qick_dst [file normalize "$dst_dir/$proj_name-$describe.hwh"]
if {[file exists $qick_hwh]} {
    file copy -force $qick_hwh $qick_dst
    Msg Info "copy_hwh: copied $qick_hwh into $qick_dst"
} else {
    Msg CriticalWarning "copy_hwh: $qick_hwh not found; no .hwh next to the bitstream"
}
