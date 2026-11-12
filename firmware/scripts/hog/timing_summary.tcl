# Timing summary of the routed design next to the bitstream in bin/.
#
# Sourced by Top/<group>/<project>/post-bitstream.tcl, which Hog sources at the end of
# its own post-bitstream step, inside the impl_1 run: the routed design is the current
# design and Hog's variables are in scope (group_name, proj_name, dst_dir, describe).
#
# Hog's timing_ok.txt / timing_error.txt has only WNS, TNS, WHS, THS and TPWS, and the
# routed timing summary of the run is not among the reports it copies to bin/. This
# writes, in dst_dir:
#   reports/timing_summary_routed.rpt  the full report_timing_summary;
#   timing_summary.md                  the totals, the worst slack of every clock pair,
#                                      the failing paths grouped by the block they start
#                                      and end in, and the Min/Max Skew checks (the
#                                      RX_BITSLICE CNTVALUEIN skew of the xcom_async PHY).
#
# A block is the IP instance a path starts or ends in; outside any IP, the first
# qick_timing_depth (default 2) levels of the cell name. qick_timing_max is the number of
# failing paths read per path group (default 10000, a few seconds on a standard design);
# a group that reaches it says ">=".

if {[current_design -quiet] eq ""} {
    Msg CriticalWarning "timing_summary: no open design; no timing summary in $dst_dir"
    return
}
if {![info exists qick_timing_depth]} { set qick_timing_depth 2 }
if {![info exists qick_timing_max]}   { set qick_timing_max 10000 }

# The block of a path end: the outermost hierarchical cell above it that is an IP instance
# (it carries x_core_info: a block design IP, an .xci in an RTL top), else the first
# qick_timing_depth levels of its name.
proc qick_timing_block {obj depth} {
    global qick_timing_ip
    set cell [get_cells -quiet -of_objects [get_pins -quiet $obj]]
    if {$cell eq ""} { return "port [get_property NAME $obj]" }
    set levels [split [get_property NAME $cell] /]
    for {set i 0} {$i < [llength $levels] - 1} {incr i} {
        set name [join [lrange $levels 0 $i] /]
        if {![dict exists $qick_timing_ip $name]} {
            dict set qick_timing_ip $name \
                [expr {[get_property -quiet x_core_info [get_cells -quiet $name]] ne ""}]
        }
        if {[dict get $qick_timing_ip $name]} { return $name }
    }
    return [join [lrange $levels 0 [expr {$depth - 1}]] /]
}
set qick_timing_ip [dict create]

proc qick_timing_ns {value} {
    if {$value eq ""} { return "-" }
    return [format "%+.3f" $value]
}

file mkdir "$dst_dir/reports"
set qick_rpt [file normalize "$dst_dir/reports/timing_summary_routed.rpt"]
report_timing_summary -max_paths 10 -file $qick_rpt
set fh [open $qick_rpt r]
set qick_rpt_text [read $fh]
close $fh

set qick_md [list]
lappend qick_md "## $group_name/$proj_name timing summary, $describe"
lappend qick_md ""
lappend qick_md "Vivado [version -short], [get_property PART [current_design]], [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]. Full report: `reports/timing_summary_routed.rpt`."
lappend qick_md ""

# Totals: the line under the WNS(ns) ... TPWS Total Endpoints header of the Design Timing Summary.
set qick_met "unknown (no Design Timing Summary in the report)"
if {[regexp -line {^\s+WNS\(ns\)\s+TNS\(ns\).*\n.*\n(.*)$} $qick_rpt_text -> qick_tot]} {
    lassign $qick_tot wns tns tns_n tns_t whs ths ths_n ths_t wpws tpws tpws_n tpws_t
    set qick_met [expr {($tns_n == 0 && $ths_n == 0 && $tpws_n == 0) ? "met" : "**NOT met**"}]
    lappend qick_md "| Check | Worst slack (ns) | Total (ns) | Failing endpoints | Endpoints |"
    lappend qick_md "| --- | --- | --- | --- | --- |"
    lappend qick_md "| Setup | [qick_timing_ns $wns] | $tns | $tns_n | $tns_t |"
    lappend qick_md "| Hold | [qick_timing_ns $whs] | $ths | $ths_n | $ths_t |"
    lappend qick_md "| Pulse width | [qick_timing_ns $wpws] | $tpws | $tpws_n | $tpws_t |"
    lappend qick_md ""
}
lappend qick_md "Timing $qick_met."
lappend qick_md ""

# Worst path of every path group (a clock pair, or a group such as async_default), worst first.
foreach {check flag} {Setup -setup Hold -hold} {
    set rows [list]
    foreach p [get_timing_paths -quiet $flag -sort_by group -max_paths 1 -nworst 1] {
        set slack [get_property SLACK $p]
        if {$slack eq ""} { continue }
        lappend rows [list $slack [get_property GROUP $p] \
                          [get_property STARTPOINT_CLOCK $p] [get_property ENDPOINT_CLOCK $p]]
    }
    lappend qick_md "### $check slack per path group, worst first"
    lappend qick_md ""
    lappend qick_md "| Path group | From clock | To clock | Worst slack (ns) |"
    lappend qick_md "| --- | --- | --- | --- |"
    foreach r [lsort -real -index 0 $rows] {
        lassign $r slack group from to
        lappend qick_md "| $group | $from | $to | [qick_timing_ns $slack] |"
    }
    lappend qick_md ""
}

# Failing paths (one per endpoint) grouped by start block, end block and clock pair.
foreach {check flag} {Setup -setup Hold -hold} {
    set groups [dict create]
    set capped [dict create]
    foreach p [get_timing_paths -quiet $flag -sort_by group -max_paths $qick_timing_max -nworst 1 \
                   -slack_lesser_than 0] {
        set key [list [qick_timing_block [get_property STARTPOINT_PIN $p] $qick_timing_depth] \
                     [qick_timing_block [get_property ENDPOINT_PIN $p] $qick_timing_depth] \
                     [get_property STARTPOINT_CLOCK $p] [get_property ENDPOINT_CLOCK $p]]
        set slack [get_property SLACK $p]
        if {[dict exists $groups $key]} {
            lassign [dict get $groups $key] n worst
            dict set groups $key [list [incr n] [expr {min($worst, $slack)}]]
        } else {
            dict set groups $key [list 1 $slack]
        }
        dict incr capped [get_property GROUP $p]
    }
    if {[dict size $groups] == 0} { continue }
    set full [dict keys [dict filter $capped value $qick_timing_max]]
    set rows [list]
    dict for {key v} $groups { lappend rows [concat $v $key] }
    lappend qick_md "### Failing $check paths by block, worst first"
    lappend qick_md ""
    lappend qick_md "| From block | To block | From clock | To clock | Endpoints | Worst slack (ns) |"
    lappend qick_md "| --- | --- | --- | --- | --- | --- |"
    foreach r [lsort -real -index 1 $rows] {
        lassign $r n worst from_b to_b from_c to_c
        lappend qick_md "| $from_b | $to_b | $from_c | $to_c | $n | [qick_timing_ns $worst] |"
    }
    lappend qick_md ""
    if {[llength $full] > 0} {
        lappend qick_md "Path groups read up to the cap of $qick_timing_max failing endpoints (counts are >=): [join $full {, }]."
        lappend qick_md ""
    }
}

# Min/Max Skew checks of the pulse width section: Check Corner LibPin RefPin Required Actual Slack Location Pin.
# Every failing one, and the worst of each kind (check, lib pin, reference pin): a DDR4
# controller alone has dozens of the same kind.
set skews [list]
foreach l [regexp -all -inline -line {^(?:Min|Max) Skew\s.*$} $qick_rpt_text] {
    lappend skews [regexp -all -inline {\S+} $l]
}
if {[llength $skews] > 0} {
    set shown [list]
    set kinds [dict create]
    foreach s [lsort -real -index 7 $skews] {
        set kind [lrange $s 0 1]
        lappend kind {*}[lrange $s 3 4]
        if {[lindex $s 7] < 0 || ![dict exists $kinds $kind]} {
            lappend shown $s
            dict set kinds $kind 1
        }
    }
    lappend qick_md "### Skew checks (pulse width section): failing ones and the worst of each kind"
    lappend qick_md ""
    lappend qick_md "| Check | Corner | Lib pin | Reference pin | Required (ns) | Actual (ns) | Slack (ns) | Pin |"
    lappend qick_md "| --- | --- | --- | --- | --- | --- | --- | --- |"
    foreach s $shown {
        lassign $s c1 c2 corner lib ref req act slack loc pin
        lappend qick_md "| $c1 $c2 | $corner | $lib | $ref | $req | $act | [qick_timing_ns $slack] | $pin |"
    }
    lappend qick_md ""
    lappend qick_md "[llength $skews] skew checks in all, [expr {[llength $skews] - [llength $shown]}] more in the full report."
    lappend qick_md ""
}

set fh [open "$dst_dir/timing_summary.md" w]
puts $fh [join $qick_md "\n"]
close $fh
Msg Info "timing_summary: wrote $dst_dir/timing_summary.md (timing $qick_met)"
