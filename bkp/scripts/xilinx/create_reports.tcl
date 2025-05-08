set proj_dir [get_property DIRECTORY [current_project]]
set report_dir "${proj_dir}/../../../fpga/reports/post_write_bitstream"

# delete folders
exec rm -rf ${proj_dir}/../../../fpga/reports

# create folders
exec mkdir -p ${proj_dir}/../../../fpga/reports/post_write_bitstream

# open implementation design
open_run impl_1 -name impl_1

# generate reports post implementation and copy to specific directory
report_utilization -file $report_dir/utilization.rpt

report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -warn_on_violation -file $report_dir/timing_summary.rpt -rpx $report_dir/timing_summary.rpx

report_methodology -file $report_dir/methodology.rpt -rpx $report_dir/methodology.rpx

report_drc -file $report_dir/drc.rpt -rpx $report_dir/drc.rpx -ruledecks {default} -upgrade_cw
