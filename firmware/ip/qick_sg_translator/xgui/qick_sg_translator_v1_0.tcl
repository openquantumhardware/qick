# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  ipgui::add_param $IPINST -name "OUT_TYPE"

}

proc update_PARAM_VALUE.OUT_TYPE { PARAM_VALUE.OUT_TYPE } {
	# Procedure called to update OUT_TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OUT_TYPE { PARAM_VALUE.OUT_TYPE } {
	# Procedure called to validate OUT_TYPE
	return true
}


proc update_MODELPARAM_VALUE.OUT_TYPE { MODELPARAM_VALUE.OUT_TYPE PARAM_VALUE.OUT_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OUT_TYPE}] ${MODELPARAM_VALUE.OUT_TYPE}
}

