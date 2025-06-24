# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  set N [ipgui::add_param $IPINST -name "N" -parent ${Page_0}]
  set_property tooltip {Envelope Memory Size in 2^N Words} ${N}
  ipgui::add_param $IPINST -name "N_DDS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "GEN_DDS" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "ENVELOPE_TYPE" -parent ${Page_0} -widget comboBox


}

proc update_PARAM_VALUE.ENVELOPE_TYPE { PARAM_VALUE.ENVELOPE_TYPE } {
	# Procedure called to update ENVELOPE_TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENVELOPE_TYPE { PARAM_VALUE.ENVELOPE_TYPE } {
	# Procedure called to validate ENVELOPE_TYPE
	return true
}

proc update_PARAM_VALUE.GEN_DDS { PARAM_VALUE.GEN_DDS } {
	# Procedure called to update GEN_DDS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GEN_DDS { PARAM_VALUE.GEN_DDS } {
	# Procedure called to validate GEN_DDS
	return true
}

proc update_PARAM_VALUE.N { PARAM_VALUE.N } {
	# Procedure called to update N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N { PARAM_VALUE.N } {
	# Procedure called to validate N
	return true
}

proc update_PARAM_VALUE.N_DDS { PARAM_VALUE.N_DDS } {
	# Procedure called to update N_DDS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N_DDS { PARAM_VALUE.N_DDS } {
	# Procedure called to validate N_DDS
	return true
}


proc update_MODELPARAM_VALUE.N { MODELPARAM_VALUE.N PARAM_VALUE.N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N}] ${MODELPARAM_VALUE.N}
}

proc update_MODELPARAM_VALUE.N_DDS { MODELPARAM_VALUE.N_DDS PARAM_VALUE.N_DDS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N_DDS}] ${MODELPARAM_VALUE.N_DDS}
}

proc update_MODELPARAM_VALUE.GEN_DDS { MODELPARAM_VALUE.GEN_DDS PARAM_VALUE.GEN_DDS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GEN_DDS}] ${MODELPARAM_VALUE.GEN_DDS}
}

proc update_MODELPARAM_VALUE.ENVELOPE_TYPE { MODELPARAM_VALUE.ENVELOPE_TYPE PARAM_VALUE.ENVELOPE_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENVELOPE_TYPE}] ${MODELPARAM_VALUE.ENVELOPE_TYPE}
}

