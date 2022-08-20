# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "INTERLEAVED_INPUT"

}

proc update_PARAM_VALUE.INTERLEAVED_INPUT { PARAM_VALUE.INTERLEAVED_INPUT } {
	# Procedure called to update INTERLEAVED_INPUT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INTERLEAVED_INPUT { PARAM_VALUE.INTERLEAVED_INPUT } {
	# Procedure called to validate INTERLEAVED_INPUT
	return true
}


proc update_MODELPARAM_VALUE.INTERLEAVED_INPUT { MODELPARAM_VALUE.INTERLEAVED_INPUT PARAM_VALUE.INTERLEAVED_INPUT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INTERLEAVED_INPUT}] ${MODELPARAM_VALUE.INTERLEAVED_INPUT}
}

