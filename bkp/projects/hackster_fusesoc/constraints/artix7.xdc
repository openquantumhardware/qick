set_property PACKAGE_PIN    	E3         [get_ports clk]

set_property IOSTANDARD        	LVCMOS33    [get_ports clk]

create_clock -period 10.000 -name sys_clk [get_ports clk]

set_property PACKAGE_PIN    G13                 [get_ports reset]
set_property PACKAGE_PIN    B11                [get_ports rx]
set_property PACKAGE_PIN    A11                [get_ports tx]

# set I/O standard
set_property IOSTANDARD        LVCMOS33    	           [get_ports reset]
set_property IOSTANDARD        LVCMOS33                [get_ports rx]
set_property IOSTANDARD        LVCMOS33                [get_ports tx]
