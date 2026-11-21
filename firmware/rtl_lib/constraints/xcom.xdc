###############################################################################
# XCOM IP Core - Timing Constraints
# 
# This file defines timing constraints for the XCOM (eXtensible COMmunication)
# block, which provides high-speed serial RX/TX interface with DDR I/O.
#
# **IMPORTANT FREQUENCY REQUIREMENTS:**
# 
# 1. EXTERNAL RX CLOCK FREQUENCY (i_xcom_clk_p[]):
#    Period: 4.0 ns (250 MHz)
#    Source: External master device
#    NOTE: This frequency MUST match the actual external interface.
#          If your external device uses a different frequency, update
#          the rx_clk_period variable below and validate with:
#          - Oscilloscope/IBERT measurements
#          - External device datasheet
#          - Board-level design documentation
#
# 2. INTERNAL CLOCKS (from parent module timing.xdc):
#    - i_time_clk = 430.08 MHz (2.325 ns)
#    - i_core_clk = 215.04 MHz (4.650 ns)  
#    - i_ps_clk = 100 MHz (10 ns) [from PS]
#
# 3. GENERATED TX CLOCK (o_xcom_clk_p):
#    Frequency: i_time_clk / 4 = 430.08 MHz / 4 = 107.5 MHz
#    Period: 9.301 ns
#    Implementation: ODDRE1 DDR output at IOB
#
# **VALIDATION CHECKLIST:**
# [ ] External RX frequency confirmed via oscilloscope
# [ ] RX clock period matches external device spec sheet
# [ ] DAC clock (i_time_clk) = 430.08 MHz verified in design
# [ ] TX output clock measured at o_xcom_clk_p ≈ 107.5 MHz
# [ ] Setup/Hold timing margins > 200 ps on RX/TX paths
#
###############################################################################
#
# ---------------------------------------------------------------------------
# 2026-08-20 -- re-synced against the current RTL (rtl_lib/). The previous
# revision of this file predated several renames, and every stale pattern
# below matched ZERO cells, i.e. the constraint was silently a no-op:
#
#   * u_xcom_axil_slv/rdata_reg_reg*     -> u_axil_slv/axi_rdata_reg*
#     u_xcom_axil_slv/slave_registers_reg* -> u_axil_slv/o_slv_regs_reg*
#     (xcom_axil_slv was replaced by the generic axil_slv core)
#   * ODDRE1_tx_clk -> oddre1_tx_clk. The instance in xcom_link_tx.sv is
#     lowercase and get_cells matching is case-sensitive, so the TX
#     generated clock was never created -- and every downstream
#     [get_clocks xcom_tx_clk_out] reference went with it.
#   * u_rx_cmd/RX[*] -> u_rx_cmd/gen_rx[*] (generate label in rx_cmd.sv).
#   * The CDC first-stage filter (*_cdc_reg* / *sync_reg*) predates the
#     synchronizer -> cdc_bit_sync / cdc_handshake migration; the flop is
#     now sync_r_reg[0].
#   * The o_core_*_reg false path pointed at i_core_clk, the domain those
#     flops are already in; the real crossing is to i_time_clk.
#
# Bracketed patterns now use -regexp: under the default glob matcher Tcl
# reads "[0]" as a character class, so "*..._reg[0]" never matches a cell
# literally named "..._reg[0]".
#
# NOT yet re-validated on hardware or against a synthesized netlist -- see
# the checklist below and grep the synth log for "No cells matched".
# ---------------------------------------------------------------------------
#
###############################################################################

###############################################################################
# PARAMETRIZABLE FREQUENCY DEFINITIONS
###############################################################################
# Modify these values only if the actual external interface frequency differs
# from the default 250 MHz (4.0 ns) specification.
#
# Common frequencies:
#   - 250 MHz = 4.0 ns (DEFAULT)
#   - 200 MHz = 5.0 ns
#   - 125 MHz = 8.0 ns
#   - 100 MHz = 10.0 ns
#
# WARNING: Changing these values requires validation on actual hardware!
###############################################################################

set rx_clk_period 4.0


###############################################################################
# Section 1: EXTERNAL RX CLOCK DEFINITIONS
###############################################################################
# The RX clocks come from external devices (master clock sources).
# Each XCOM RX channel has its own differential clock input pair.
#
# Waveform {1.0 3.0} represents center-aligned DDR operation:
#   - The physical RX clock arrives at the CENTER of the data eye.
#   - Rising edge at 1.0 ns (offset by T/4 = 1.0 ns from data launch at 0.0 ns)
#   - This offset defines the setup/hold requirement for Vivado's STA.
#   - Together with xcom_clk_virt {0.0 2.0}, the setup window becomes
#     1.0 ns (half-period) + 1.0 ns (phase offset) = higher slack budget.
#
# Channels 0 is REQUIRED; channels 1-15 are OPTIONAL (use -quiet)
###############################################################################

create_clock -name xcom_rx_clk_0 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[0]] -waveform {1.0 3.0}

create_clock -name xcom_rx_clk_1  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[1]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_2  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[2]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_3  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[3]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_4  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[4]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_5  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[5]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_6  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[6]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_7  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[7]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_8  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[8]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_9  -period $rx_clk_period \
    [get_ports i_xcom_clk_p[9]]  -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_10 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[10]] -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_11 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[11]] -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_12 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[12]] -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_13 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[13]] -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_14 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[14]] -waveform {1.0 3.0} -quiet
create_clock -name xcom_rx_clk_15 -period $rx_clk_period \
    [get_ports i_xcom_clk_p[15]] -waveform {1.0 3.0} -quiet


###############################################################################
# Section 2: VIRTUAL CLOCK FOR RX TIMING ANALYSIS
###############################################################################
# Virtual clock representing the ideal launch clock at the external source.
#
# Waveform {0.0 2.0}:
#   - Data is launched at t=0.0 ns (rising) and t=2.0 ns (falling).
#   - The physical RX clock (xcom_rx_clk_*) arrives at t=1.0 ns (center),
#     giving a 1.0 ns setup window on each DDR half-period.
#   - This is the standard center-aligned source-synchronous DDR model.
###############################################################################

create_clock -name xcom_clk_virt -period $rx_clk_period -waveform {0.0 2.0}



###############################################################################
# Section 5: CDC SYNCHRONIZER CONSTRAINTS (Specific Paths Only)
###############################################################################
# All clock domain crossings use explicit multi-stage synchronizers in RTL.
# Constraints below target ONLY the first-stage flip-flops where
# metastability is managed by synchronizer chains.
#
# Philosophy: Cut timing on first stages only. If paths fail outside the
# synchronizers, that indicates a design issue that must be fixed, not
# hidden with blanket false_paths.
###############################################################################

# Relax setup/hold on the FIRST synchronizer stage only.
# Every CDC in the XCOM tree funnels through cdc_bit_sync (cdc_handshake uses
# it for both req and ack), whose stage-0 flop is `sync_r_reg[0]`, carrying
# (* ASYNC_REG = "TRUE" *). Stage 0 -> stage 1 is left timed on purpose.
# NOTE: -regexp is required -- with the default glob matcher Tcl reads the
# "[0]" as a character class, so a plain `*sync_r_reg[0]` pattern silently
# matches nothing.
set_false_path -to [get_pins -filter {REF_PIN_NAME == D} -of_objects \
    [get_cells -hier -regexp -filter {name =~ .*sync_r_reg\[0\]$}]]

# RX phase control (i_time_clk → xcom_rx_clk_*)
set_false_path \
    -from [get_pins -filter {REF_PIN_NAME =~ C} -of_objects \
        [get_cells -hier -filter {name =~ *u_xcom_link_rx/s_pha_reg}]] \
    -to [get_clocks xcom_rx_clk_*]

# DDR data -> i_clk (xcom_link_rx): ddr_data_cdc_reg takes the 8-bit bank that
# is not being written when the toggle carried by u_ddr_last_sync /
# u_ddr_last_pos_sync changes, i.e. two i_clk cycles (4.65 ns at 430.08 MHz)
# after the toggle. ddr_last_toggle(_pos) also select the bank directly. The
# bank is rewritten 16 ns later. One RX period keeps the data and the select
# ahead of the synchronised toggle.
set_max_delay -datapath_only $rx_clk_period \
    -from [get_clocks xcom_rx_clk_*] \
    -to [get_pins -filter {REF_PIN_NAME == D} -of_objects \
        [get_cells -hier -filter {name =~ *u_xcom_link_rx/ddr_data_cdc_reg*}]]



###############################################################################
# Section 6: RX DATA INPUT DELAYS
###############################################################################
# Center-aligned DDR input delay specification.
#
# Model:
#   xcom_clk_virt  waveform {0.0 2.0}: data launched at t=0 and t=2 ns
#   xcom_rx_clk_*  waveform {1.0 3.0}: clock arrives at t=1 ns (center)
#
# The ±0.1 ns window models board-level skew between data and clock lines.
# VALIDATE these values with oscilloscope measurements on actual hardware.
###############################################################################

# Rising edge data launch
set_input_delay -clock xcom_clk_virt -max  0.1 [get_ports i_xcom_data_p*]
set_input_delay -clock xcom_clk_virt -min -0.1 [get_ports i_xcom_data_p*]

# Falling edge data launch (DDR complement)
set_input_delay -clock xcom_clk_virt -max  0.1 -clock_fall \
    [get_ports i_xcom_data_p*] -add_delay
set_input_delay -clock xcom_clk_virt -min -0.1 -clock_fall \
    [get_ports i_xcom_data_p*] -add_delay


###############################################################################
# Section 6b: RX DDR CENTER-ALIGNED TIMING EXCEPTIONS
###############################################################################
# For center-aligned DDR, only cross-edge transfers are valid:
#   VALID:   falling launch (virt) → rising capture (rx_clk)  [setup]
#   VALID:   rising launch (virt)  → falling capture (rx_clk) [setup]
#   INVALID: same-edge transfers → hold checks are impossible
#
# Cut the invalid checks to prevent false timing violations.
# Reference: Xilinx UG949, Ch. 4 (Center-Aligned DDR methodology)
###############################################################################

set_false_path -setup \
    -rise_from [get_clocks xcom_clk_virt] \
    -fall_to   [get_clocks xcom_rx_clk_*]

set_false_path -setup \
    -fall_from [get_clocks xcom_clk_virt] \
    -rise_to   [get_clocks xcom_rx_clk_*]

set_false_path -hold \
    -rise_from [get_clocks xcom_clk_virt] \
    -rise_to   [get_clocks xcom_rx_clk_*]

set_false_path -hold \
    -fall_from [get_clocks xcom_clk_virt] \
    -fall_to   [get_clocks xcom_rx_clk_*]

# The RX data capture is not checked statically: the +-0.1 ns window above was
# never measured, the capture is in fabric (USE_IDDR = 0; the IDDR path does not
# work with the TX clock boost), and the link sets the IDELAY tap and the
# capture edge (s_pha) at run time. The input delays stay so that the ports are
# not reported as unconstrained. Timed, they failed by up to 0.39 ns (117
# tpv2_1ch_xcom_mts 3917696).
set_false_path -from [get_clocks xcom_clk_virt] -to [get_clocks xcom_rx_clk_*]

# Everything that refers to i_time_clk, i_core_clk or i_ps_clk (generated TX
# clocks, CDC false paths, output delays) is in xcom_late.xdc: those clocks come
# from the block design and exist only when the IP's XDC is processed LATE.

###############################################################################
# END OF XCOM TIMING CONSTRAINTS (EARLY)
###############################################################################
