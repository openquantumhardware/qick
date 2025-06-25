# Copyright (C) 2022 Xilinx, Inc
# SPDX-License-Identifier: BSD-3-Clause

set overlay_name "xcom_simple"
set design_name "xcom_simple"

# open block design
open_project ./${overlay_name}/${overlay_name}.xpr
open_bd_design ./${overlay_name}/${overlay_name}.srcs/sources_1/bd/${design_name}/${design_name}.bd

# set platform properties
set_property platform.default_output_type "sd_card" [current_project]
set_property platform.design_intent.embedded "true" [current_project]
set_property platform.design_intent.server_managed "false" [current_project]
set_property platform.design_intent.external_host "false" [current_project]
set_property platform.design_intent.datacenter "false" [current_project]

# call implement
launch_runs impl_1 -to_step write_bitstream -jobs 14
wait_on_run impl_1

# move and rename bitstream to final location
file copy -force ./${overlay_name}/${overlay_name}.runs/impl_1/${design_name}_wrapper.bit ${overlay_name}.bit

# copy hwh files
file copy -force ./${overlay_name}/${overlay_name}.gen/sources_1/bd/${design_name}/hw_handoff/${design_name}.hwh ${overlay_name}.hwh

# generate xsa
write_hw_platform -force -include_bit ./${overlay_name}.xsa
validate_hw_platform ./${overlay_name}.xsa

