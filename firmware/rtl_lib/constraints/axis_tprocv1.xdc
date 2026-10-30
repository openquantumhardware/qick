###############################################################################
# Functional (scoped) constraints for axis_tprocv1 IP core.
#
# Intentionally minimal.
#
# - Clock definitions and the asynchronous clock-group relationship live in
#   axis_tprocv1_ooc.xdc (applied only during standalone OOC synthesis).
# - When this IP is instantiated inside a block design, the top-level design
#   constraints drive all timing; the two clock domains (s_axi_aclk, aclk) are
#   already declared asynchronous, and CDC is handled in RTL by the
#   cdc_gray_sync synchronizers and the dual-clock BRAM (bram_tdp).
#
# No multicycle_path / false_path exceptions are declared here on purpose:
# every internal path is a normal single-cycle path within its own clock
# domain, and cross-domain paths are covered by the async clock groups. Adding
# blanket exceptions by cell/pin name would (a) fail to match real hierarchical
# names and raise critical warnings, and (b) risk masking a genuine timing
# violation. If timing fails to close after P&R on a specific, understood path,
# add a targeted exception here then — not preemptively.
###############################################################################
