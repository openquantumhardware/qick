# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DMEM_N" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PMEM_N" -parent ${Page_0}


}

proc update_PARAM_VALUE.DMEM_N { PARAM_VALUE.DMEM_N } {
	# Procedure called to update DMEM_N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DMEM_N { PARAM_VALUE.DMEM_N } {
	# Procedure called to validate DMEM_N
	return true
}

proc update_PARAM_VALUE.PMEM_N { PARAM_VALUE.PMEM_N } {
	# Procedure called to update PMEM_N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PMEM_N { PARAM_VALUE.PMEM_N } {
	# Procedure called to validate PMEM_N
	return true
}


proc update_MODELPARAM_VALUE.PMEM_N { MODELPARAM_VALUE.PMEM_N PARAM_VALUE.PMEM_N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PMEM_N}] ${MODELPARAM_VALUE.PMEM_N}
}

proc update_MODELPARAM_VALUE.DMEM_N { MODELPARAM_VALUE.DMEM_N PARAM_VALUE.DMEM_N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DMEM_N}] ${MODELPARAM_VALUE.DMEM_N}
}

