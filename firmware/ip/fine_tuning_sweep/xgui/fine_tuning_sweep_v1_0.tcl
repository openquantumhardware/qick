# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "MAX_AVG" -parent ${Page_0}


}

proc update_PARAM_VALUE.MAX_AVG { PARAM_VALUE.MAX_AVG } {
	# Procedure called to update MAX_AVG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_AVG { PARAM_VALUE.MAX_AVG } {
	# Procedure called to validate MAX_AVG
	return true
}


proc update_MODELPARAM_VALUE.MAX_AVG { MODELPARAM_VALUE.MAX_AVG PARAM_VALUE.MAX_AVG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_AVG}] ${MODELPARAM_VALUE.MAX_AVG}
}

