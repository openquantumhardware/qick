Technical Topics
================

This section contains detailed technical reference material for advanced users.

These topics assume you have completed the basic tutorials (00-05) and are familiar with:
- QICK program structure (`_initialize`, `_body`)
- Pulse definition and sequencing
- Basic readout configuration

.. toctree::
   :maxdepth: 1
   :caption: Core Concepts

   freq_matching
   timing
   playing_pulses
   gen_config
   units
   reference_clock
   changing_fs

.. toctree::
   :maxdepth: 1
   :caption: Quick Reference

   asmv2_cheatsheet
   tutorials

.. toctree::
   :maxdepth: 1
   :caption: Advanced Topics

   xcom
   XCOM-commands
   pyro4

Topic Descriptions
==================

**freq_matching**
    How frequency matching works between generators and readouts in tProc v2 vs. v1.

**timing**
    Detailed explanation of timeline management, delays, and synchronization.

**playing_pulses**
    How to define and play pulses with different styles (const, arb, flat_top).

**gen_config**
    Complete reference for generator configuration parameters.

**units**
    Understanding QICK's time, frequency, and amplitude units.

**reference_clock**
    Configuring external reference clocks and clock distribution.

**changing_fs**
    How to change the FPGA sampling frequency for different bandwidths.

**asmv2_cheatsheet**
    Quick reference for tProc v2 assembly instructions.

**tutorials**
    Link to the full Jupyter notebook tutorials.

**xcom**
    XCOM: Full mesh network for multi-board synchronization and low-latency communication. Covers hardware requirements, communication protocol, command set, and Python interface.

**XCOM-commands**
    Complete reference of all XCOM commands, including NET commands (for network communication) and LOC commands (for local control).

**pyro4**
    Pyro4: Network-based multi-board connection for distributed control and data acquisition.

When to Use Each Topic
======================

- **New to timing concepts?** Start with :doc:`timing`
- **Confused about frequencies?** Read :doc:`freq_matching`
- **Need to shape pulses?** See :doc:`playing_pulses`
- **Changing hardware config?** Check :doc:`gen_config` and :doc:`changing_fs`
- **Using external clock?** Refer to :doc:`reference_clock`
- **Writing assembly code?** Keep :doc:`asmv2_cheatsheet` handy
- **Synchronizing multiple boards?** Read :doc:`xcom` for the network-based solution
- **Need XCOM command details?** See :doc:`XCOM-commands` for the complete command reference