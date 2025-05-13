# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  ipgui::add_param $IPINST -name "N_AVG"
  ipgui::add_param $IPINST -name "N_BUF"
  set N_WGT [ipgui::add_param $IPINST -name "N_WGT"]
  set_property tooltip {log2(length of weights array)} ${N_WGT}
  ipgui::add_param $IPINST -name "B"

}

proc update_PARAM_VALUE.B { PARAM_VALUE.B } {
	# Procedure called to update B when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.B { PARAM_VALUE.B } {
	# Procedure called to validate B
	return true
}

proc update_PARAM_VALUE.N_AVG { PARAM_VALUE.N_AVG } {
	# Procedure called to update N_AVG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N_AVG { PARAM_VALUE.N_AVG } {
	# Procedure called to validate N_AVG
	return true
}

proc update_PARAM_VALUE.N_BUF { PARAM_VALUE.N_BUF } {
	# Procedure called to update N_BUF when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N_BUF { PARAM_VALUE.N_BUF } {
	# Procedure called to validate N_BUF
	return true
}

proc update_PARAM_VALUE.N_WGT { PARAM_VALUE.N_WGT } {
	# Procedure called to update N_WGT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N_WGT { PARAM_VALUE.N_WGT } {
	# Procedure called to validate N_WGT
	return true
}


proc update_MODELPARAM_VALUE.N_AVG { MODELPARAM_VALUE.N_AVG PARAM_VALUE.N_AVG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N_AVG}] ${MODELPARAM_VALUE.N_AVG}
}

proc update_MODELPARAM_VALUE.N_BUF { MODELPARAM_VALUE.N_BUF PARAM_VALUE.N_BUF } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N_BUF}] ${MODELPARAM_VALUE.N_BUF}
}

proc update_MODELPARAM_VALUE.B { MODELPARAM_VALUE.B PARAM_VALUE.B } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.B}] ${MODELPARAM_VALUE.B}
}

proc update_MODELPARAM_VALUE.N_WGT { MODELPARAM_VALUE.N_WGT PARAM_VALUE.N_WGT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N_WGT}] ${MODELPARAM_VALUE.N_WGT}
}

