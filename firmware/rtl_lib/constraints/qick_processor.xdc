#---------------------------------------------------------------------------
# qick_processor False Paths
#---------------------------------------------------------------------------
# Ported from firmware/ip/qick_processor/src/qick_processor.xdc. The legacy
# file targeted literal hierarchy paths (e.g. */QPROC/QPROC_CTRL/...) that
# no longer exist under this name after the rtl_lib port (instances/labels
# were renamed -- e.g. QPROC_CTRL -> qproc_ctrl_i, CORE_0 -> core_0_i,
# CORE_CPU -> core_cpu_i, AXI_DB -> gen_axi_db). Each rule below was
# re-derived by tracing the (unchanged) internal *signal* names through the
# new (renamed) *instance* hierarchy under qick_processor's qproc_i.
#
# IMPORTANT: this file has NOT been validated against an actual synthesized
# netlist (this port has no Vivado synthesis run available) -- before
# relying on it, confirm every `get_cells`/`get_pins` pattern below actually
# resolves (Tcl console: `get_cells -hier -filter {...}` should return a
# non-empty list) and re-check timing with `report_timing_summary` after
# synthesis, especially the two rules marked LOWER CONFIDENCE.
#---------------------------------------------------------------------------

# General synchronizers: any register Vivado infers/we tagged ASYNC_REG
# (cdc_bit_sync/cdc_reg_sync's sync_r, plus the remaining hand-rolled 2-flop
# synchronizers in qcore_reg_bank/qproc_ctrl/qproc_dispatcher) is a CDC
# destination whose setup/hold timing is meaningless -- false-path its D
# pin. Using the ASYNC_REG property (not a name pattern) makes this
# survive any future renaming, unlike the legacy *_cdc_reg* name match
# (which relied on the retired sync_reg module's specific signal names and
# would NOT have matched cdc_bit_sync's `sync_r` anyway).
set_false_path -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {ASYNC_REG == "TRUE"}]]

# c_time_ref_o (qproc_ctrl) -> AXI read-data latch (qproc_axi_reg's axil_slv).
# c_time_ref_o is read back through TPROC_R_DT/TPROC_DEBUG; it changes far
# slower than the AXI read path samples it.
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/c_time_ref_o_reg*}]] \
                -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_axi_reg_i/u_axil_slv/axi_rdata_reg*}]]

# offset_dt_r -> time_updt_dt (both in qproc_ctrl, t_clk_i domain latching a
# c_clk_i-domain value that is held stable across the update handshake).
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/offset_dt_r_reg*}]] \
                -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/time_updt_dt_reg*}]]

# LOWER CONFIDENCE: tproc_cfg_sync[9] (qproc_ctrl, already double-synced by
# the ASYNC_REG rule above) read into further t_clk_i-domain logic.
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/tproc_cfg_sync_reg[9]}]] \
                       -to   [get_clocks -of_objects [get_ports -filter {name =~ t_clk_i}]]

# axil_slv's writable register file (qproc_axi_reg) -> c_clk_i domain reads
# (TPROC_CTRL/CFG/MEM_*/CORE_CFG/READ_SEL consumed by qproc_ctrl/qproc_core/
# qproc_mem_ctrl/qick_processor's peripheral mux).
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_axi_reg_i/u_axil_slv/o_slv_regs_reg*}]] \
                -to   [get_clocks -of_objects [get_ports -filter {name =~ c_clk_i}]]

# Input-port capture register (qproc_inport_reg, c_clk_i) -> AXI TPROC_R_DT
# readback mux register (ps_clk_i, qick_processor.sv).
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/in_port_reg_i/g_port_reg*.port_dt_r_reg*}]] \
                -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/xreg_tproc_r_dt_reg*}]]

# Core0's special-function register bank (qcore_reg_bank, c_clk_i) -> AXI
# TPROC_R_DT readback mux register (ps_clk_i).
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/core_0_i/core_cpu_i/reg_bank_i/sreg_dt_reg*}]] \
                -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/xreg_tproc_r_dt_reg*}]]

# LFSR register (qcore_reg_bank's lfsr sub-instance, either core) -> AXI
# TPROC_R_DT readback mux register.
set_false_path -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/core_*_i/core_cpu_i/reg_bank_i/gen_lfsr.lfsr_i/reg_lfsr_reg*}]] \
                -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/xreg_tproc_r_dt_reg*}]]

# Peripheral (qnet/qcom/qp1/qp2) captured data registers (qick_processor.sv,
# c_clk_i) -> ps_clk_i domain (only read back through TPROC_R_DT, not timed).
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qp?_dt_r_reg*}]] \
                       -to   [get_clocks -of_objects [get_ports -filter {name =~ ps_clk_i}]]

# Doesn't exist unless DUAL_CORE/relevant qnet/qcom paths are present in
# this build -- -quiet suppresses the "no matching pins" warning.
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qnet_dt_r_reg*}]] \
                       -to   [get_clocks -of_objects [get_ports -filter {name =~ ps_clk_i}]]
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qcom_dt_r_reg*}]] \
                       -to   [get_clocks -of_objects [get_ports -filter {name =~ ps_clk_i}]]

# Doesn't exist if parameter DIVIDER = 0 (restoring_divider result registers,
# qick_processor.sv's gen_div block, -> AXI TPROC_R_DT readback mux).
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_div.div_*_r_reg*}]] \
                       -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/xreg_tproc_r_dt_reg*}]]

# LOWER CONFIDENCE: doesn't exist if parameter ARITH = 0 (tpv2_arith's
# internal DSP48 primitive clock, qick_processor.sv's gen_arith block, ->
# AXI TPROC_R_DT readback mux). The exact primitive instance name inside
# tpv2_arith was not independently re-verified against synthesis.
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ CLK} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_arith.arith_i*i_primitive*}]] \
                       -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/xreg_tproc_r_dt_reg*}]]

# Doesn't exist if parameter TIME_READ = 0 (qproc_ctrl's gen_time_read
# block: t_time_abs_r -> c_time_abs_r cross-domain latch).
set_false_path -quiet -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/gen_time_read.t_time_abs_r_reg*}]] \
                       -to   [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/qproc_ctrl_i/gen_time_read.c_time_abs_r_reg*}]]

# Doesn't exist if parameter DEBUG = 0 (qick_processor.sv's gen_axi_db
# block: xreg_tproc_debug/xreg_tproc_status are only meaningfully updated
# once per c_clk_i/t_clk_i-domain event, not timed against ps_clk_i reads).
set_false_path -quiet -from [get_clocks -of_objects [get_ports -filter {name =~ t_clk_i}]] -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_axi_db.xreg_tproc_debug_reg*}]]
set_false_path -quiet -from [get_clocks -of_objects [get_ports -filter {name =~ t_clk_i}]] -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_axi_db.xreg_tproc_status_reg*}]]
set_false_path -quiet -from [get_clocks -of_objects [get_ports -filter {name =~ c_clk_i}]] -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_axi_db.xreg_tproc_debug_reg*}]]
set_false_path -quiet -from [get_clocks -of_objects [get_ports -filter {name =~ c_clk_i}]] -to [get_pins -filter {REF_PIN_NAME =~ D} -of_objects [get_cells -hier -filter {name =~ *qproc_i/gen_axi_db.xreg_tproc_status_reg*}]]
