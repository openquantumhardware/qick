# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"


}

proc update_PARAM_VALUE.COUNT_WIDTH { PARAM_VALUE.COUNT_WIDTH } {
	# Procedure called to update COUNT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COUNT_WIDTH { PARAM_VALUE.COUNT_WIDTH } {
	# Procedure called to validate COUNT_WIDTH
	return true
}

proc update_PARAM_VALUE.IQ_WIDTH { PARAM_VALUE.IQ_WIDTH } {
	# Procedure called to update IQ_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IQ_WIDTH { PARAM_VALUE.IQ_WIDTH } {
	# Procedure called to validate IQ_WIDTH
	return true
}

proc update_PARAM_VALUE.KW_TOL { PARAM_VALUE.KW_TOL } {
	# Procedure called to update KW_TOL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.KW_TOL { PARAM_VALUE.KW_TOL } {
	# Procedure called to validate KW_TOL
	return true
}

proc update_PARAM_VALUE.LUT_AW { PARAM_VALUE.LUT_AW } {
	# Procedure called to update LUT_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LUT_AW { PARAM_VALUE.LUT_AW } {
	# Procedure called to validate LUT_AW
	return true
}

proc update_PARAM_VALUE.LUT_DEPTH { PARAM_VALUE.LUT_DEPTH } {
	# Procedure called to update LUT_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LUT_DEPTH { PARAM_VALUE.LUT_DEPTH } {
	# Procedure called to validate LUT_DEPTH
	return true
}

proc update_PARAM_VALUE.POW_WIDTH { PARAM_VALUE.POW_WIDTH } {
	# Procedure called to update POW_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POW_WIDTH { PARAM_VALUE.POW_WIDTH } {
	# Procedure called to validate POW_WIDTH
	return true
}

proc update_PARAM_VALUE.RO_FIFO_DEPTH_LOG2 { PARAM_VALUE.RO_FIFO_DEPTH_LOG2 } {
	# Procedure called to update RO_FIFO_DEPTH_LOG2 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RO_FIFO_DEPTH_LOG2 { PARAM_VALUE.RO_FIFO_DEPTH_LOG2 } {
	# Procedure called to validate RO_FIFO_DEPTH_LOG2
	return true
}

proc update_PARAM_VALUE.SUM_WIDTH { PARAM_VALUE.SUM_WIDTH } {
	# Procedure called to update SUM_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SUM_WIDTH { PARAM_VALUE.SUM_WIDTH } {
	# Procedure called to validate SUM_WIDTH
	return true
}

proc update_PARAM_VALUE.X_WIDTH { PARAM_VALUE.X_WIDTH } {
	# Procedure called to update X_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.X_WIDTH { PARAM_VALUE.X_WIDTH } {
	# Procedure called to validate X_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.LUT_DEPTH { MODELPARAM_VALUE.LUT_DEPTH PARAM_VALUE.LUT_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LUT_DEPTH}] ${MODELPARAM_VALUE.LUT_DEPTH}
}

proc update_MODELPARAM_VALUE.LUT_AW { MODELPARAM_VALUE.LUT_AW PARAM_VALUE.LUT_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LUT_AW}] ${MODELPARAM_VALUE.LUT_AW}
}

proc update_MODELPARAM_VALUE.X_WIDTH { MODELPARAM_VALUE.X_WIDTH PARAM_VALUE.X_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.X_WIDTH}] ${MODELPARAM_VALUE.X_WIDTH}
}

proc update_MODELPARAM_VALUE.IQ_WIDTH { MODELPARAM_VALUE.IQ_WIDTH PARAM_VALUE.IQ_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IQ_WIDTH}] ${MODELPARAM_VALUE.IQ_WIDTH}
}

proc update_MODELPARAM_VALUE.SUM_WIDTH { MODELPARAM_VALUE.SUM_WIDTH PARAM_VALUE.SUM_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SUM_WIDTH}] ${MODELPARAM_VALUE.SUM_WIDTH}
}

proc update_MODELPARAM_VALUE.POW_WIDTH { MODELPARAM_VALUE.POW_WIDTH PARAM_VALUE.POW_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POW_WIDTH}] ${MODELPARAM_VALUE.POW_WIDTH}
}

proc update_MODELPARAM_VALUE.COUNT_WIDTH { MODELPARAM_VALUE.COUNT_WIDTH PARAM_VALUE.COUNT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COUNT_WIDTH}] ${MODELPARAM_VALUE.COUNT_WIDTH}
}

proc update_MODELPARAM_VALUE.RO_FIFO_DEPTH_LOG2 { MODELPARAM_VALUE.RO_FIFO_DEPTH_LOG2 PARAM_VALUE.RO_FIFO_DEPTH_LOG2 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RO_FIFO_DEPTH_LOG2}] ${MODELPARAM_VALUE.RO_FIFO_DEPTH_LOG2}
}

proc update_MODELPARAM_VALUE.KW_TOL { MODELPARAM_VALUE.KW_TOL PARAM_VALUE.KW_TOL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.KW_TOL}] ${MODELPARAM_VALUE.KW_TOL}
}

