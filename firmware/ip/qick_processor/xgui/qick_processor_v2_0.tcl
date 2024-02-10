# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_static_text $IPINST -name "Version" -parent ${Page_0} -text {Qick_Processor Compilation 2024_1}
  ipgui::add_static_text $IPINST -name "Introduction" -parent ${Page_0} -text {Values for Memory size Port quantity and register amount can be modified in order to make a smaller and Faster processor }
  #Adding Group
  set Process [ipgui::add_group $IPINST -name "Process" -parent ${Page_0} -display_name {Processor Options}]
  set_property tooltip {Process} ${Process}
  ipgui::add_param $IPINST -name "REG_AW" -parent ${Process}
  ipgui::add_static_text $IPINST -name "dreg" -parent ${Process} -text {User can define the amount of 32-bits General Purpouse Data registers. This value impacts on the max freq of the processor.}
  #Adding Group
  set Memory_Configuration [ipgui::add_group $IPINST -name "Memory Configuration" -parent ${Process} -display_name {Core Memory}]
  ipgui::add_param $IPINST -name "PMEM_AW" -parent ${Memory_Configuration}
  set DMEM_AW [ipgui::add_param $IPINST -name "DMEM_AW" -parent ${Memory_Configuration}]
  set_property tooltip {DmemAw} ${DMEM_AW}
  ipgui::add_param $IPINST -name "WMEM_AW" -parent ${Memory_Configuration}

  #Adding Group
  set OUT_Port_Configuration [ipgui::add_group $IPINST -name "OUT Port Configuration" -parent ${Process} -display_name {OUT Configuration}]
  set_property tooltip {OUT Configuration} ${OUT_Port_Configuration}
  ipgui::add_param $IPINST -name "OUT_TRIG_QTY" -parent ${OUT_Port_Configuration}
  ipgui::add_param $IPINST -name "OUT_DPORT_QTY" -parent ${OUT_Port_Configuration}
  ipgui::add_param $IPINST -name "OUT_DPORT_DW" -parent ${OUT_Port_Configuration}
  ipgui::add_param $IPINST -name "OUT_WPORT_QTY" -parent ${OUT_Port_Configuration}
  #Adding Group
  set External_Peripherals [ipgui::add_group $IPINST -name "External Peripherals" -parent ${OUT_Port_Configuration}]
  ipgui::add_param $IPINST -name "QCOM" -parent ${External_Peripherals} -widget checkBox
  ipgui::add_param $IPINST -name "TNET" -parent ${External_Peripherals} -widget checkBox
  ipgui::add_param $IPINST -name "CUSTOM_PERIPH" -parent ${External_Peripherals} -widget comboBox


  #Adding Group
  set IN_Port_Configuration [ipgui::add_group $IPINST -name "IN Port Configuration" -parent ${Process} -display_name {IN Configuration}]
  ipgui::add_param $IPINST -name "IN_PORT_QTY" -parent ${IN_Port_Configuration}
  ipgui::add_param $IPINST -name "EXT_FLAG" -parent ${IN_Port_Configuration} -widget checkBox
  set IO_CTRL [ipgui::add_param $IPINST -name "IO_CTRL" -parent ${IN_Port_Configuration} -widget checkBox]
  set_property tooltip {External Inputs Qick Control Pins} ${IO_CTRL}

  #Adding Group
  set Options [ipgui::add_group $IPINST -name "Options" -parent ${Process} -layout horizontal]
  set LFSR [ipgui::add_param $IPINST -name "LFSR" -parent ${Options} -widget checkBox]
  set_property tooltip {Linear Feedback Shit Register} ${LFSR}
  ipgui::add_param $IPINST -name "ARITH" -parent ${Options} -widget checkBox
  set DIVIDER [ipgui::add_param $IPINST -name "DIVIDER" -parent ${Options} -widget checkBox]
  set_property tooltip {32-bit Integer Divider (Quotient - Reminder)} ${DIVIDER}
  ipgui::add_param $IPINST -name "TIME_READ" -parent ${Options} -widget checkBox


  #Adding Group
  set Debug [ipgui::add_group $IPINST -name "Debug" -parent ${Page_0}]
  ipgui::add_param $IPINST -name "DEBUG" -parent ${Debug} -widget comboBox



}

proc update_PARAM_VALUE.ARITH { PARAM_VALUE.ARITH } {
	# Procedure called to update ARITH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARITH { PARAM_VALUE.ARITH } {
	# Procedure called to validate ARITH
	return true
}

proc update_PARAM_VALUE.CUSTOM_PERIPH { PARAM_VALUE.CUSTOM_PERIPH } {
	# Procedure called to update CUSTOM_PERIPH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CUSTOM_PERIPH { PARAM_VALUE.CUSTOM_PERIPH } {
	# Procedure called to validate CUSTOM_PERIPH
	return true
}

proc update_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to update DEBUG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to validate DEBUG
	return true
}

proc update_PARAM_VALUE.DIVIDER { PARAM_VALUE.DIVIDER } {
	# Procedure called to update DIVIDER when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DIVIDER { PARAM_VALUE.DIVIDER } {
	# Procedure called to validate DIVIDER
	return true
}

proc update_PARAM_VALUE.DMEM_AW { PARAM_VALUE.DMEM_AW } {
	# Procedure called to update DMEM_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DMEM_AW { PARAM_VALUE.DMEM_AW } {
	# Procedure called to validate DMEM_AW
	return true
}

proc update_PARAM_VALUE.DUAL_CORE { PARAM_VALUE.DUAL_CORE } {
	# Procedure called to update DUAL_CORE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DUAL_CORE { PARAM_VALUE.DUAL_CORE } {
	# Procedure called to validate DUAL_CORE
	return true
}

proc update_PARAM_VALUE.EXT_FLAG { PARAM_VALUE.EXT_FLAG } {
	# Procedure called to update EXT_FLAG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EXT_FLAG { PARAM_VALUE.EXT_FLAG } {
	# Procedure called to validate EXT_FLAG
	return true
}

proc update_PARAM_VALUE.FIFO_DEPTH { PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to update FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_DEPTH { PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to validate FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.IN_PORT_QTY { PARAM_VALUE.IN_PORT_QTY } {
	# Procedure called to update IN_PORT_QTY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IN_PORT_QTY { PARAM_VALUE.IN_PORT_QTY } {
	# Procedure called to validate IN_PORT_QTY
	return true
}

proc update_PARAM_VALUE.IO_CTRL { PARAM_VALUE.IO_CTRL } {
	# Procedure called to update IO_CTRL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IO_CTRL { PARAM_VALUE.IO_CTRL } {
	# Procedure called to validate IO_CTRL
	return true
}

proc update_PARAM_VALUE.LFSR { PARAM_VALUE.LFSR } {
	# Procedure called to update LFSR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LFSR { PARAM_VALUE.LFSR } {
	# Procedure called to validate LFSR
	return true
}

proc update_PARAM_VALUE.OUT_DPORT_DW { PARAM_VALUE.OUT_DPORT_DW } {
	# Procedure called to update OUT_DPORT_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OUT_DPORT_DW { PARAM_VALUE.OUT_DPORT_DW } {
	# Procedure called to validate OUT_DPORT_DW
	return true
}

proc update_PARAM_VALUE.OUT_DPORT_QTY { PARAM_VALUE.OUT_DPORT_QTY } {
	# Procedure called to update OUT_DPORT_QTY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OUT_DPORT_QTY { PARAM_VALUE.OUT_DPORT_QTY } {
	# Procedure called to validate OUT_DPORT_QTY
	return true
}

proc update_PARAM_VALUE.OUT_TRIG_QTY { PARAM_VALUE.OUT_TRIG_QTY } {
	# Procedure called to update OUT_TRIG_QTY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OUT_TRIG_QTY { PARAM_VALUE.OUT_TRIG_QTY } {
	# Procedure called to validate OUT_TRIG_QTY
	return true
}

proc update_PARAM_VALUE.OUT_WPORT_QTY { PARAM_VALUE.OUT_WPORT_QTY } {
	# Procedure called to update OUT_WPORT_QTY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OUT_WPORT_QTY { PARAM_VALUE.OUT_WPORT_QTY } {
	# Procedure called to validate OUT_WPORT_QTY
	return true
}

proc update_PARAM_VALUE.PMEM_AW { PARAM_VALUE.PMEM_AW } {
	# Procedure called to update PMEM_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PMEM_AW { PARAM_VALUE.PMEM_AW } {
	# Procedure called to validate PMEM_AW
	return true
}

proc update_PARAM_VALUE.QCOM { PARAM_VALUE.QCOM } {
	# Procedure called to update QCOM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QCOM { PARAM_VALUE.QCOM } {
	# Procedure called to validate QCOM
	return true
}

proc update_PARAM_VALUE.REG_AW { PARAM_VALUE.REG_AW } {
	# Procedure called to update REG_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.REG_AW { PARAM_VALUE.REG_AW } {
	# Procedure called to validate REG_AW
	return true
}

proc update_PARAM_VALUE.TIME_READ { PARAM_VALUE.TIME_READ } {
	# Procedure called to update TIME_READ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIME_READ { PARAM_VALUE.TIME_READ } {
	# Procedure called to validate TIME_READ
	return true
}

proc update_PARAM_VALUE.TNET { PARAM_VALUE.TNET } {
	# Procedure called to update TNET when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TNET { PARAM_VALUE.TNET } {
	# Procedure called to validate TNET
	return true
}

proc update_PARAM_VALUE.WMEM_AW { PARAM_VALUE.WMEM_AW } {
	# Procedure called to update WMEM_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WMEM_AW { PARAM_VALUE.WMEM_AW } {
	# Procedure called to validate WMEM_AW
	return true
}


proc update_MODELPARAM_VALUE.PMEM_AW { MODELPARAM_VALUE.PMEM_AW PARAM_VALUE.PMEM_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PMEM_AW}] ${MODELPARAM_VALUE.PMEM_AW}
}

proc update_MODELPARAM_VALUE.DMEM_AW { MODELPARAM_VALUE.DMEM_AW PARAM_VALUE.DMEM_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DMEM_AW}] ${MODELPARAM_VALUE.DMEM_AW}
}

proc update_MODELPARAM_VALUE.WMEM_AW { MODELPARAM_VALUE.WMEM_AW PARAM_VALUE.WMEM_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WMEM_AW}] ${MODELPARAM_VALUE.WMEM_AW}
}

proc update_MODELPARAM_VALUE.REG_AW { MODELPARAM_VALUE.REG_AW PARAM_VALUE.REG_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.REG_AW}] ${MODELPARAM_VALUE.REG_AW}
}

proc update_MODELPARAM_VALUE.IN_PORT_QTY { MODELPARAM_VALUE.IN_PORT_QTY PARAM_VALUE.IN_PORT_QTY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IN_PORT_QTY}] ${MODELPARAM_VALUE.IN_PORT_QTY}
}

proc update_MODELPARAM_VALUE.OUT_DPORT_QTY { MODELPARAM_VALUE.OUT_DPORT_QTY PARAM_VALUE.OUT_DPORT_QTY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OUT_DPORT_QTY}] ${MODELPARAM_VALUE.OUT_DPORT_QTY}
}

proc update_MODELPARAM_VALUE.OUT_WPORT_QTY { MODELPARAM_VALUE.OUT_WPORT_QTY PARAM_VALUE.OUT_WPORT_QTY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OUT_WPORT_QTY}] ${MODELPARAM_VALUE.OUT_WPORT_QTY}
}

proc update_MODELPARAM_VALUE.LFSR { MODELPARAM_VALUE.LFSR PARAM_VALUE.LFSR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LFSR}] ${MODELPARAM_VALUE.LFSR}
}

proc update_MODELPARAM_VALUE.DIVIDER { MODELPARAM_VALUE.DIVIDER PARAM_VALUE.DIVIDER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DIVIDER}] ${MODELPARAM_VALUE.DIVIDER}
}

proc update_MODELPARAM_VALUE.ARITH { MODELPARAM_VALUE.ARITH PARAM_VALUE.ARITH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARITH}] ${MODELPARAM_VALUE.ARITH}
}

proc update_MODELPARAM_VALUE.TIME_READ { MODELPARAM_VALUE.TIME_READ PARAM_VALUE.TIME_READ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIME_READ}] ${MODELPARAM_VALUE.TIME_READ}
}

proc update_MODELPARAM_VALUE.DUAL_CORE { MODELPARAM_VALUE.DUAL_CORE PARAM_VALUE.DUAL_CORE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DUAL_CORE}] ${MODELPARAM_VALUE.DUAL_CORE}
}

proc update_MODELPARAM_VALUE.IO_CTRL { MODELPARAM_VALUE.IO_CTRL PARAM_VALUE.IO_CTRL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IO_CTRL}] ${MODELPARAM_VALUE.IO_CTRL}
}

proc update_MODELPARAM_VALUE.DEBUG { MODELPARAM_VALUE.DEBUG PARAM_VALUE.DEBUG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG}] ${MODELPARAM_VALUE.DEBUG}
}

proc update_MODELPARAM_VALUE.TNET { MODELPARAM_VALUE.TNET PARAM_VALUE.TNET } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TNET}] ${MODELPARAM_VALUE.TNET}
}

proc update_MODELPARAM_VALUE.CUSTOM_PERIPH { MODELPARAM_VALUE.CUSTOM_PERIPH PARAM_VALUE.CUSTOM_PERIPH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CUSTOM_PERIPH}] ${MODELPARAM_VALUE.CUSTOM_PERIPH}
}

proc update_MODELPARAM_VALUE.OUT_DPORT_DW { MODELPARAM_VALUE.OUT_DPORT_DW PARAM_VALUE.OUT_DPORT_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OUT_DPORT_DW}] ${MODELPARAM_VALUE.OUT_DPORT_DW}
}

proc update_MODELPARAM_VALUE.OUT_TRIG_QTY { MODELPARAM_VALUE.OUT_TRIG_QTY PARAM_VALUE.OUT_TRIG_QTY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OUT_TRIG_QTY}] ${MODELPARAM_VALUE.OUT_TRIG_QTY}
}

proc update_MODELPARAM_VALUE.FIFO_DEPTH { MODELPARAM_VALUE.FIFO_DEPTH PARAM_VALUE.FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_DEPTH}] ${MODELPARAM_VALUE.FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.EXT_FLAG { MODELPARAM_VALUE.EXT_FLAG PARAM_VALUE.EXT_FLAG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EXT_FLAG}] ${MODELPARAM_VALUE.EXT_FLAG}
}

proc update_MODELPARAM_VALUE.QCOM { MODELPARAM_VALUE.QCOM PARAM_VALUE.QCOM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QCOM}] ${MODELPARAM_VALUE.QCOM}
}

