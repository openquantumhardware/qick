# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  #Adding Group
  set Control [ipgui::add_group $IPINST -name "Control" -parent ${Page_0}]
  ipgui::add_static_text $IPINST -name "CtrlText" -parent ${Control} -text {The Time tagger can be controlled from tProcessor and Python}
  set EXT_ARM [ipgui::add_param $IPINST -name "EXT_ARM" -parent ${Control} -widget checkBox]
  set_property tooltip {External ARM Control} ${EXT_ARM}

  #Adding Group
  set TAG_FIFO [ipgui::add_group $IPINST -name "TAG FIFO" -parent ${Page_0} -display_name {ADC Tags}]
  ipgui::add_param $IPINST -name "ADC_QTY" -parent ${TAG_FIFO} -widget comboBox
  ipgui::add_param $IPINST -name "TAG_FIFO_AW" -parent ${TAG_FIFO}
  #Adding Group
  set Threshold_Comparison [ipgui::add_group $IPINST -name "Threshold Comparison" -parent ${TAG_FIFO}]
  ipgui::add_param $IPINST -name "CMP_SLOPE" -parent ${Threshold_Comparison} -widget checkBox
  ipgui::add_param $IPINST -name "CMP_INTER" -parent ${Threshold_Comparison}


  #Adding Group
  set ADC0_Options [ipgui::add_group $IPINST -name "ADC0 Options" -parent ${Page_0}]
  #Adding Group
  set Samples_Options [ipgui::add_group $IPINST -name "Samples Options" -parent ${ADC0_Options} -display_name {Samples}]
  ipgui::add_param $IPINST -name "SMP_STORE" -parent ${Samples_Options} -widget checkBox
  ipgui::add_param $IPINST -name "SMP_FIFO_AW" -parent ${Samples_Options}

  #Adding Group
  set ARM_Triggers [ipgui::add_group $IPINST -name "ARM Triggers" -parent ${ADC0_Options} -display_name {ARM Info}]
  ipgui::add_param $IPINST -name "ARM_STORE" -parent ${ARM_Triggers} -widget checkBox
  ipgui::add_param $IPINST -name "ARM_FIFO_AW" -parent ${ARM_Triggers}


  #Adding Group
  set Debug [ipgui::add_group $IPINST -name "Debug" -parent ${Page_0}]
  ipgui::add_param $IPINST -name "DEBUG" -parent ${Debug} -widget comboBox



}

proc update_PARAM_VALUE.ADC_QTY { PARAM_VALUE.ADC_QTY } {
	# Procedure called to update ADC_QTY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADC_QTY { PARAM_VALUE.ADC_QTY } {
	# Procedure called to validate ADC_QTY
	return true
}

proc update_PARAM_VALUE.ARM_FIFO_AW { PARAM_VALUE.ARM_FIFO_AW } {
	# Procedure called to update ARM_FIFO_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARM_FIFO_AW { PARAM_VALUE.ARM_FIFO_AW } {
	# Procedure called to validate ARM_FIFO_AW
	return true
}

proc update_PARAM_VALUE.ARM_STORE { PARAM_VALUE.ARM_STORE } {
	# Procedure called to update ARM_STORE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARM_STORE { PARAM_VALUE.ARM_STORE } {
	# Procedure called to validate ARM_STORE
	return true
}

proc update_PARAM_VALUE.CMP_INTER { PARAM_VALUE.CMP_INTER } {
	# Procedure called to update CMP_INTER when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CMP_INTER { PARAM_VALUE.CMP_INTER } {
	# Procedure called to validate CMP_INTER
	return true
}

proc update_PARAM_VALUE.CMP_SLOPE { PARAM_VALUE.CMP_SLOPE } {
	# Procedure called to update CMP_SLOPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CMP_SLOPE { PARAM_VALUE.CMP_SLOPE } {
	# Procedure called to validate CMP_SLOPE
	return true
}

proc update_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to update DEBUG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to validate DEBUG
	return true
}

proc update_PARAM_VALUE.EXT_ARM { PARAM_VALUE.EXT_ARM } {
	# Procedure called to update EXT_ARM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EXT_ARM { PARAM_VALUE.EXT_ARM } {
	# Procedure called to validate EXT_ARM
	return true
}

proc update_PARAM_VALUE.SMP_CK { PARAM_VALUE.SMP_CK } {
	# Procedure called to update SMP_CK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SMP_CK { PARAM_VALUE.SMP_CK } {
	# Procedure called to validate SMP_CK
	return true
}

proc update_PARAM_VALUE.SMP_DW { PARAM_VALUE.SMP_DW } {
	# Procedure called to update SMP_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SMP_DW { PARAM_VALUE.SMP_DW } {
	# Procedure called to validate SMP_DW
	return true
}

proc update_PARAM_VALUE.SMP_FIFO_AW { PARAM_VALUE.SMP_FIFO_AW } {
	# Procedure called to update SMP_FIFO_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SMP_FIFO_AW { PARAM_VALUE.SMP_FIFO_AW } {
	# Procedure called to validate SMP_FIFO_AW
	return true
}

proc update_PARAM_VALUE.SMP_STORE { PARAM_VALUE.SMP_STORE } {
	# Procedure called to update SMP_STORE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SMP_STORE { PARAM_VALUE.SMP_STORE } {
	# Procedure called to validate SMP_STORE
	return true
}

proc update_PARAM_VALUE.TAG_FIFO_AW { PARAM_VALUE.TAG_FIFO_AW } {
	# Procedure called to update TAG_FIFO_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TAG_FIFO_AW { PARAM_VALUE.TAG_FIFO_AW } {
	# Procedure called to validate TAG_FIFO_AW
	return true
}


proc update_MODELPARAM_VALUE.CMP_SLOPE { MODELPARAM_VALUE.CMP_SLOPE PARAM_VALUE.CMP_SLOPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CMP_SLOPE}] ${MODELPARAM_VALUE.CMP_SLOPE}
}

proc update_MODELPARAM_VALUE.CMP_INTER { MODELPARAM_VALUE.CMP_INTER PARAM_VALUE.CMP_INTER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CMP_INTER}] ${MODELPARAM_VALUE.CMP_INTER}
}

proc update_MODELPARAM_VALUE.TAG_FIFO_AW { MODELPARAM_VALUE.TAG_FIFO_AW PARAM_VALUE.TAG_FIFO_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TAG_FIFO_AW}] ${MODELPARAM_VALUE.TAG_FIFO_AW}
}

proc update_MODELPARAM_VALUE.SMP_DW { MODELPARAM_VALUE.SMP_DW PARAM_VALUE.SMP_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SMP_DW}] ${MODELPARAM_VALUE.SMP_DW}
}

proc update_MODELPARAM_VALUE.SMP_CK { MODELPARAM_VALUE.SMP_CK PARAM_VALUE.SMP_CK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SMP_CK}] ${MODELPARAM_VALUE.SMP_CK}
}

proc update_MODELPARAM_VALUE.SMP_STORE { MODELPARAM_VALUE.SMP_STORE PARAM_VALUE.SMP_STORE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SMP_STORE}] ${MODELPARAM_VALUE.SMP_STORE}
}

proc update_MODELPARAM_VALUE.SMP_FIFO_AW { MODELPARAM_VALUE.SMP_FIFO_AW PARAM_VALUE.SMP_FIFO_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SMP_FIFO_AW}] ${MODELPARAM_VALUE.SMP_FIFO_AW}
}

proc update_MODELPARAM_VALUE.DEBUG { MODELPARAM_VALUE.DEBUG PARAM_VALUE.DEBUG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG}] ${MODELPARAM_VALUE.DEBUG}
}

proc update_MODELPARAM_VALUE.ADC_QTY { MODELPARAM_VALUE.ADC_QTY PARAM_VALUE.ADC_QTY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADC_QTY}] ${MODELPARAM_VALUE.ADC_QTY}
}

proc update_MODELPARAM_VALUE.ARM_STORE { MODELPARAM_VALUE.ARM_STORE PARAM_VALUE.ARM_STORE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARM_STORE}] ${MODELPARAM_VALUE.ARM_STORE}
}

proc update_MODELPARAM_VALUE.ARM_FIFO_AW { MODELPARAM_VALUE.ARM_FIFO_AW PARAM_VALUE.ARM_FIFO_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARM_FIFO_AW}] ${MODELPARAM_VALUE.ARM_FIFO_AW}
}

proc update_MODELPARAM_VALUE.EXT_ARM { MODELPARAM_VALUE.EXT_ARM PARAM_VALUE.EXT_ARM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EXT_ARM}] ${MODELPARAM_VALUE.EXT_ARM}
}

