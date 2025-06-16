# Copyright (C) 2021 Xilinx, Inc
# SPDX-License-Identifier: BSD-3-Clause


# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  set COUNTER_WIDTH [ipgui::add_param $IPINST -name "COUNTER_WIDTH" -parent ${Page_0}]
  set_property tooltip {Counter has to be wide enough to counter to latch value} ${COUNTER_WIDTH}
  ipgui::add_param $IPINST -name "LATCH_VALUE" -parent ${Page_0}


}

proc update_PARAM_VALUE.COUNTER_WIDTH { PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to update COUNTER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COUNTER_WIDTH { PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to validate COUNTER_WIDTH
	return true
}

proc update_PARAM_VALUE.LATCH_VALUE { PARAM_VALUE.LATCH_VALUE } {
	# Procedure called to update LATCH_VALUE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LATCH_VALUE { PARAM_VALUE.LATCH_VALUE } {
	# Procedure called to validate LATCH_VALUE
	return true
}


proc update_MODELPARAM_VALUE.LATCH_VALUE { MODELPARAM_VALUE.LATCH_VALUE PARAM_VALUE.LATCH_VALUE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LATCH_VALUE}] ${MODELPARAM_VALUE.LATCH_VALUE}
}

proc update_MODELPARAM_VALUE.COUNTER_WIDTH { MODELPARAM_VALUE.COUNTER_WIDTH PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COUNTER_WIDTH}] ${MODELPARAM_VALUE.COUNTER_WIDTH}
}

