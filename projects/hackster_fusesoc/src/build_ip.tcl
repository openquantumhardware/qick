# Start a new project or open an existing one in Vivado

# Open the IP Integrator design tool
create_bd_design "design_1"

# Add an AXI BRAM Controller
set axi_bram_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0]

# Configure the AXI BRAM Controller for AXI4-Lite interface
set_property CONFIG.PROTOCOL {AXI4LITE} [get_bd_cells $axi_bram_ctrl]

# Add a Block RAM (BRAM)
set bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 bram_0]

# Connect the BRAM Controller to the BRAM
connect_bd_intf_net -intf_net S_AXI $axi_bram_ctrl/BRAM_PORTA $bram/BRAM_PORTA

# Make AXI interface, clock, and reset external
# Expose the AXI interface to external ports
make_bd_intf_pins_external [get_bd_intf_pins $axi_bram_ctrl/S_AXI]

# Expose the clock to an external port
make_bd_pins_external [get_bd_pins $axi_bram_ctrl/s_axi_aclk]

# Expose the reset to an external port
make_bd_pins_external [get_bd_pins $axi_bram_ctrl/s_axi_aresetn]

# Assign addresses
assign_bd_address

# Save and validate the design
validate_bd_design 
save_bd_design

# Optional: Generate the output products for the design
# If you want to synthesize or implement the design directly, you can also add:
# generate_target all [get_files design_1.bd]


# Generate the HDL wrapper for the design and capture the generated filename
set wrapper_file [make_wrapper -files [get_files design_1.bd] -top]

# Add the generated wrapper file to the project
add_files $wrapper_file

# Update the project hierarchy to include the new wrapper file
update_compile_order -fileset sources_1