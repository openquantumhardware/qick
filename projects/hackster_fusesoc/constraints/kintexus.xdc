
set_property PACKAGE_PIN    	AF9         [get_ports clk]
set_property IOSTANDARD        	LVCMOS33    [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

set_property PACKAGE_PIN    AE8                [get_ports reset]
set_property PACKAGE_PIN    AE10               [get_ports rx]
set_property PACKAGE_PIN    AD10               [get_ports tx]

# set I/O standard
set_property IOSTANDARD        LVCMOS33    	           [get_ports reset]
set_property IOSTANDARD        LVCMOS33                [get_ports rx]
set_property IOSTANDARD        LVCMOS33                [get_ports tx]


