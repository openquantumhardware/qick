# Create project.
create_project ipgen ./ipgen -part xczu49dr-ffvf1760-2-e

# Set language options.
set_property simulator_language Mixed [current_project]
set_property target_language Verilog [current_project]

# Create IPs.
source fir.tcl

# Generate instantiation templates.
generate_target instantiation_template [get_ips *]

