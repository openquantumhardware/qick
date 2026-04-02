# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"


}

proc update_PARAM_VALUE.FREQ_0 { PARAM_VALUE.FREQ_0 } {
	# Procedure called to update FREQ_0 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FREQ_0 { PARAM_VALUE.FREQ_0 } {
	# Procedure called to validate FREQ_0
	return true
}

proc update_PARAM_VALUE.FREQ_1 { PARAM_VALUE.FREQ_1 } {
	# Procedure called to update FREQ_1 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FREQ_1 { PARAM_VALUE.FREQ_1 } {
	# Procedure called to validate FREQ_1
	return true
}

proc update_PARAM_VALUE.FREQ_2 { PARAM_VALUE.FREQ_2 } {
	# Procedure called to update FREQ_2 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FREQ_2 { PARAM_VALUE.FREQ_2 } {
	# Procedure called to validate FREQ_2
	return true
}

proc update_PARAM_VALUE.FREQ_3 { PARAM_VALUE.FREQ_3 } {
	# Procedure called to update FREQ_3 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FREQ_3 { PARAM_VALUE.FREQ_3 } {
	# Procedure called to validate FREQ_3
	return true
}


proc update_MODELPARAM_VALUE.FREQ_0 { MODELPARAM_VALUE.FREQ_0 PARAM_VALUE.FREQ_0 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FREQ_0}] ${MODELPARAM_VALUE.FREQ_0}
}

proc update_MODELPARAM_VALUE.FREQ_1 { MODELPARAM_VALUE.FREQ_1 PARAM_VALUE.FREQ_1 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FREQ_1}] ${MODELPARAM_VALUE.FREQ_1}
}

proc update_MODELPARAM_VALUE.FREQ_2 { MODELPARAM_VALUE.FREQ_2 PARAM_VALUE.FREQ_2 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FREQ_2}] ${MODELPARAM_VALUE.FREQ_2}
}

proc update_MODELPARAM_VALUE.FREQ_3 { MODELPARAM_VALUE.FREQ_3 PARAM_VALUE.FREQ_3 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FREQ_3}] ${MODELPARAM_VALUE.FREQ_3}
}

