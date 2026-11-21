###############################################################################
# axis_streamer — clock domain crossing constraints (scoped to the IP)
#
# THREE asynchronous clock domains:
#   s_axi_aclk  : AXI4-Lite configuration
#   s_axis_aclk : capture datapath (full rate, e.g. 307.2 MHz)
#   m_axis_aclk : drain datapath, matched to the DMA / HP port (e.g. 100 MHz)
#
# Cross-domain paths and how each is handled:
#
#   START      s_axi  -> m_axis   cdc_bit_sync (streamer_i/u_sync_start)
#   run_state  m_axis -> s_axis   cdc_bit_sync (streamer_i/u_sync_run_state)
#   run_ack    s_axis -> m_axis   cdc_bit_sync (streamer_i/u_sync_run_ack)
#   STATUS[*]  mixed  -> s_axi    cdc_bit_sync x6 (g_status_sync[*].u_sync)
#   MODE       s_axi  -> m_axis   MCP: captured while !start_reg_resync
#   NSAMP[31:0] s_axi -> m_axis   MCP: captured while !start_reg_resync
#   FLUSH      s_axi  -> m_axis   cdc_bit_sync (streamer_i/u_sync_flush)
#   LOST[31:0] s_axis -> s_axi    quasi-static, read only while STATUS.IDLE
#   FIFO ptrs  s_axis <-> m_axis  XPM internal gray synchronisers
#
# ⚠️ PRECEDENCE CAVEAT
#   set_clock_groups -asynchronous is implemented as false paths, which rank
#   ABOVE set_max_delay. On paths covered by a clock group the max_delay
#   constraints below may therefore be reported as overridden. They are kept
#   because this is the house style established by axis_pid, and because
#   set_bus_skew is not a timing exception and IS honoured regardless.
#   AFTER THE FIRST SYNTHESIS, run report_timing on the MCP paths below and
#   confirm they are actually being bounded. If they are not, remove the
#   s_axi <-> m_axis clock group and replace it with explicit set_false_path
#   on everything except the MCP buses.
#
# ⚠️ Verify every cell/pin filter after the first synthesis: the tool renames
#   and flattens hierarchy, and a filter that matches nothing fails SILENTLY.
#   Check with:  llength [get_cells -hier -filter {NAME =~ *u_sync_start*}]
###############################################################################

set s_axi_clk  [get_clocks -include_generated_clocks -of_objects [get_ports s_axi_aclk]]
set s_axis_clk [get_clocks -include_generated_clocks -of_objects [get_ports s_axis_aclk]]
set m_axis_clk [get_clocks -include_generated_clocks -of_objects [get_ports m_axis_aclk]]

set s_axi_period  [get_property -min PERIOD $s_axi_clk]
set s_axis_period [get_property -min PERIOD $s_axis_clk]
set m_axis_period [get_property -min PERIOD $m_axis_clk]

###############################################################################
# 1. Declare the three domains mutually asynchronous.
###############################################################################
set_clock_groups -asynchronous \
    -group $s_axi_clk  \
    -group $s_axis_clk \
    -group $m_axis_clk

###############################################################################
# 2. Bit synchronisers (cdc_bit_sync)
#
#    Bound the source-to-first-flop delay so a slow route cannot eat into the
#    metastability settling window. The first stage inside cdc_bit_sync is
#    sync_r[0], the second sync_r[1] (cdc_bit_sync v2.0); both carry ASYNC_REG.
#    Budget: one destination clock period.
###############################################################################

# START : s_axi -> m_axis
set_max_delay -datapath_only $m_axis_period \
    -to [get_pins -hier -filter {NAME =~ *streamer_i/u_sync_start/sync_r_reg[0]/D}]

# run_state : m_axis -> s_axis
set_max_delay -datapath_only $s_axis_period \
    -to [get_pins -hier -filter {NAME =~ *streamer_i/u_sync_run_state/sync_r_reg[0]/D}]

# run_state_ack : s_axis -> m_axis
set_max_delay -datapath_only $m_axis_period \
    -to [get_pins -hier -filter {NAME =~ *streamer_i/u_sync_run_ack/sync_r_reg[0]/D}]

# FLUSH : s_axi -> m_axis
set_max_delay -datapath_only $m_axis_period \
    -to [get_pins -hier -filter {NAME =~ *streamer_i/u_sync_flush/sync_r_reg[0]/D}]

# STATUS[5:0] : mixed source domains -> s_axi, one synchroniser per bit.
# The bits are deliberately NOT coherent with each other, so no bus skew
# constraint applies here: each is independently meaningful.
set_max_delay -datapath_only $s_axi_period \
    -to [get_pins -hier -filter {NAME =~ *g_status_sync*u_sync/sync_r_reg[0]/D}]

###############################################################################
# 3. Configuration MCP : MODE and NSAMP, s_axi -> m_axis
#
#    The core samples these continuously while start_reg_resync is low, i.e.
#    the capture window is open exactly when software is writing them. They are
#    guaranteed stable by the documented programming sequence (write NSAMP and
#    MODE first, then START), but the BUS SKEW must still be bounded: without
#    it, a bus caught mid-change can be captured with some bits old and some
#    new, latching an NSAMP that was never written.
#
#    Budget: 2 destination periods for the datapath, 1 for the skew.
###############################################################################
set cfg_src [get_cells -hier -filter {NAME =~ *axil_slv_i/*slv_regs*reg*}]
set cfg_dst [get_cells -hier -filter {NAME =~ *streamer_i/nsamp_reg_r_reg* || \
                                      NAME =~ *streamer_i/mode_reg_r_reg*}]

set_max_delay -datapath_only [expr {2 * $m_axis_period}] \
    -from $cfg_src -to $cfg_dst
set_bus_skew  $m_axis_period \
    -from $cfg_src -to $cfg_dst

###############################################################################
# 4. LOST[31:0] : s_axis -> s_axi, no handshake
#
#    lost_reg_r is latched in the s_axis domain when the run ends, and read
#    combinationally through the axil_slv read mux in the s_axi domain. The
#    documented software contract is to read LOST only while STATUS.IDLE is
#    set, at which point it is static. Bound the skew anyway so a read taken
#    early returns a plausible value rather than a mix of two counts.
###############################################################################
set lost_src [get_cells -hier -filter {NAME =~ *streamer_i/lost_reg_r_reg*}]
set lost_dst [get_cells -hier -filter {NAME =~ *axil_slv_i/*rdata*reg*}]

set_max_delay -datapath_only [expr {2 * $s_axi_period}] \
    -from $lost_src -to $lost_dst
set_bus_skew  $s_axi_period \
    -from $lost_src -to $lost_dst
