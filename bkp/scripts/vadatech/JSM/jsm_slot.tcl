puts "Version: 1.0"

proc jsm_slot {	slot} {
	scan_ir_hw_jtag -tdi 00 -smask 1f 5
	scan_ir_hw_jtag -tdi 00 -smask 1f 5
	scan_ir_hw_jtag -tdi 00 -smask 1f 5
	
	scan_dr_hw_jtag -tdi 00 -tdo c0 -mask ff 8
    	scan_ir_hw_jtag -tdi 03 -mask 1f 5
	scan_dr_hw_jtag -tdi 01 -smask 1f -tdo 00 -mask 00 5
	scan_ir_hw_jtag -tdi 02 -smask 1f 5
	scan_dr_hw_jtag -tdi $slot -smask 1f -tdo 00 -mask 00 5
		
	return "JSM is configured to select slot $slot\n"
}
