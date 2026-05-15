==========================
QICK Tutorials (Jupyter)
==========================

This section contains practical tutorials for learning QICK and the tProc v2.
The tutorials are available as Jupyter notebooks and can be run directly on the RFSoC board.

Prerequisites
=============

- RFSoC board (ZCU111, ZCU216, or RFSoC4x2) with firmware loaded
- QICK installed (see :doc:`../quick_start`)
- Access to Jupyter notebook on the board

Tutorials
=========

.. toctree::
   :maxdepth: 1
   :caption: Basic Tutorials (00-05)

   ../tutorials/00_Getting_Started
   ../tutorials/01_Basic_Sequencing
   ../tutorials/02_Parameter_Sweeps
   ../tutorials/03_Advanced_Timing
   ../tutorials/04_Real_Time_Feedback
   ../tutorials/05_Dynamic_Parameters_Subroutines

.. toctree::
   :maxdepth: 1
   :caption: Intermediate Tutorials (06-09)

   ../tutorials/06_Generators_And_Readouts
   ../tutorials/07_Advanced_Generators_And_Readouts
   ../tutorials/08_Hardware_Buffers
   ../tutorials/09_Appendix_Tips_And_Limits

.. toctree::
   :maxdepth: 1
   :caption: Advanced Tutorials (10-14)

   ../tutorials/10_Multi_Board_Synchronization
   ../tutorials/11_Streaming_And_RealTime_Processing
   ../tutorials/12_DSP_Blocks_And_Correlators
   ../tutorials/13_Custom_Firmware_Integration
   ../tutorials/14_XCOM_Network_Synchronization
   ../tutorials/README

Running the Tutorials
=====================

1. Connect to your RFSoC board via SSH or JupyterHub
2. Navigate to the ``docs/source/tutorials/`` directory
3. Open the desired notebook
4. **IMPORTANT**: Change the ``BITSTREAM_PATH`` variable in the first cell to point to your firmware file
5. Run the cells in order

Remote Execution
================

To run the tutorials from a remote PC:

1. Start the proxy server on the board: ``python -m qick.pyro``
2. In your notebook, use: ``from qick.pyro import make_proxy; soc = make_proxy("board_ip_address")``
3. Follow the notebook instructions, replacing the local connection with the proxy connection

Tutorial Descriptions
=====================

Basic Tutorials
---------------

- **00_Getting_Started**: Connect to the board, inspect hardware configuration
- **01_Basic_Sequencing**: Define pulses, create sequences, acquire data
- **02_Parameter_Sweeps**: 1D and 2D parameter sweeps
- **03_Advanced_Timing**: ``delay`` vs ``wait``, auto-timing, avoiding collisions
- **04_Real_Time_Feedback**: Conditional pulses, active reset, thresholding
- **05_Dynamic_Parameters_Subroutines**: Virtual-Z gates, subroutines, dynamic updates

Intermediate Tutorials
----------------------

- **06_Generators_And_Readouts**: Basic waveform generators, readout resonators, I/Q mixing
- **07_Advanced_Generators_And_Readouts**: Muxed generators, PFB readout, dynamic readouts, fast dynamic readout, electrical delay calibration, IQ offsets, performance benchmarks
- **08_Hardware_Buffers**: DDR4 and MR buffers, data capture
- **09_Appendix_Tips_And_Limits**: Common errors, limits, debugging tips

Advanced Tutorials
------------------

- **10_Multi_Board_Synchronization**: Synchronize multiple boards using external clock and external start signals
- **11_Streaming_And_RealTime_Processing**: IQ streaming, on-FPGA averaging, real-time decimation
- **12_DSP_Blocks_And_Correlators**: FIR filters, DDS tuning, hardware correlators
- **13_Custom_Firmware_Integration**: Adding custom Verilog/VHDL, AXI-lite interface, rebuilding
- **14_XCOM_Network_Synchronization**: Full mesh network for multi-board synchronization and low-latency communication (requires FMC transceiver board)

See Also
========

- :doc:`../quick_start` - Quick installation guide
- :doc:`asmv2_cheatsheet` - tProc v2 cheatsheet
- :doc:`timing` - More details on timeline management