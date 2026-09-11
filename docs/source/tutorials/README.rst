==========================
QICK Tutorials (Jupyter)
==========================

This section contains practical tutorials for learning QICK and the tProc v2.
The tutorials are available as Jupyter notebooks and can be run directly on the RFSoC board.

Prerequisites
=============

- RFSoC board (ZCU111, ZCU216, or RFSoC4x2) with firmware loaded
- QICK installed (see :doc:`../quick_start`)
- Firmware bitstream file (`.bit` and its matching `.hwh`) for your board
- Access to Jupyter notebook on the board

List of Tutorials: tProc v2
===========================

These notebooks must be run with a tProc v2 firmware.
Some notebooks may have additional firmware or hardware requirements:

* Notebooks 00–09 are self-contained and work on any QICK setup
* Notebooks 10–15 require additional hardware resources (multi-board, streaming, DSP48, QICKBox)
* Notebook 13 requires a licensed Vivado installation for custom firmware compilation
* Notebook 14 (XCOM) requires additional hardware: FMC transceiver board and external hub
* Notebook 15 requires a QICKBox with RF (and optionally Balun) daughtercards installed

Basic Tutorials
---------------

.. toctree::
   :maxdepth: 1
   :hidden:

   00_Getting_Started
   01_Basic_Sequencing
   02_Parameter_Sweeps
   03_Advanced_Timing
   04_Real_Time_Feedback
   05_Dynamic_Parameters_Subroutines

.. list-table::
   :header-rows: 1

   * - #
     - Notebook
     - Description
   * - 00
     - :doc:`00_Getting_Started`
     - Connect to the board, inspect hardware configuration
   * - 01
     - :doc:`01_Basic_Sequencing`
     - Define pulses, create sequences, acquire data
   * - 02
     - :doc:`02_Parameter_Sweeps`
     - 1D and 2D parameter sweeps
   * - 03 
     - :doc:`03_Advanced_Timing`
     - ``delay`` vs ``wait``, auto-timing, avoiding collisions
   * - 04
     - :doc:`04_Real_Time_Feedback`
     - Conditional pulses, active reset, thresholding
   * - 05
     - :doc:`05_Dynamic_Parameters_Subroutines`
     - Virtual-Z gates, subroutines, dynamic updates

Intermediate Tutorials
----------------------

.. toctree::
   :maxdepth: 1
   :hidden:

   06_Generators_And_Readouts
   07_Advanced_Generators_And_Readouts
   08_Hardware_Buffers
   09_Appendix_Tips_And_Limits

.. list-table::
   :header-rows: 1

   * - #
     - Notebook
     - Description
   * - 06
     - :doc:`06_Generators_And_Readouts`
     - Basic waveform generators, readout resonators, I/Q mixing
   * - 07
     - :doc:`07_Advanced_Generators_And_Readouts`
     - Muxed generators, PFB readout, dynamic readouts, fast dynamic readout, electrical delay calibration, IQ offsets, performance benchmarks
   * - 08
     - :doc:`08_Hardware_Buffers`
     - DDR4 and MR buffers, data capture
   * - 09
     - :doc:`09_Appendix_Tips_And_Limits`
     - Common errors, limits, debugging tips

Advanced Tutorials
------------------

.. toctree::
   :maxdepth: 1
   :hidden:

   10_Multi_Board_Synchronization
   11_Streaming_And_RealTime_Processing
   12_DSP_Blocks_And_Correlators
   13_Custom_Firmware_Integration
   14_XCOM_Network_Synchronization
   15_QICKBox_RF_Daughtercards

.. list-table::
   :header-rows: 1

   * - #
     - Notebook
     - Description
   * - 10
     - :doc:`10_Multi_Board_Synchronization`
     - Synchronize multiple boards using external clock and external start signals
   * - 11
     - :doc:`11_Streaming_And_RealTime_Processing`
     - IQ streaming, on-FPGA averaging, real-time decimation
   * - 12
     - :doc:`12_DSP_Blocks_And_Correlators`
     - FIR filters, DDS tuning, hardware correlators
   * - 13
     - :doc:`13_Custom_Firmware_Integration`
     - Adding custom Verilog/VHDL, AXI-lite interface, rebuilding
   * - 14
     - :doc:`14_XCOM_Network_Synchronization`
     - Full mesh network for multi-board synchronization and low-latency communication (requires FMC transceiver board)
   * - 15
     - :doc:`15_QICKBox_RF_Daughtercards`
     - QICKBox RF/Balun daughtercards: attenuators, ADMV8818 tunable filters, saturation checks (requires QICKBox with RF daughtercards)

List of Tutorials: tProc v1
===========================

These notebooks will run on the "standard" tProc v1-based firmware bitstream that is distributed with the QICK library.

.. toctree::
   :maxdepth: 1
   :hidden:

   tprocv1/00_Send_receive_pulse
   tprocv1/01_Phase_coherent_readout
   tprocv1/02_Sweeping_variables
   tprocv1/03_Conditional_logic
   tprocv1/04_Reading_Math_Writing
   tprocv1/05_PhaseCoherence_QickProgram
   tprocv1/06_qubit_demos
   tprocv1/07_Sweep_ND_variables
   tprocv1/08_Special_buffers
   tprocv1/09_photon_counting

.. list-table::
   :header-rows: 1

   * - #
     - Notebook
   * - 00
     - :doc:`tprocv1/00_Send_receive_pulse`
   * - 01
     - :doc:`tprocv1/01_Phase_coherent_readout`
   * - 02
     - :doc:`tprocv1/02_Sweeping_variables`
   * - 03
     - :doc:`tprocv1/03_Conditional_logic`
   * - 04
     - :doc:`tprocv1/04_Reading_Math_Writing`
   * - 05
     - :doc:`tprocv1/05_PhaseCoherence_QickProgram`
   * - 06
     - :doc:`tprocv1/06_qubit_demos`
   * - 07
     - :doc:`tprocv1/07_Sweep_ND_variables`
   * - 08
     - :doc:`tprocv1/08_Special_buffers`
   * - 09
     - :doc:`tprocv1/09_photon_counting`

Running the Tutorials
=====================

1. Connect to your RFSoC board via SSH or JupyterHub
2. Navigate to the ``docs/source/tutorials/`` directory
3. Open the desired notebook
4. **IMPORTANT**: Change the ``BITSTREAM_PATH`` variable in the first cell to point to your firmware file
5. Run the cells in order

.. note::

  Don't have an RFSoC board handy? Tutorials 00-07 are also available
  ported to the **QICK emulator** (``QickEmu``, a Verilator-based
  software simulation of the firmware) at
  ``emulator/notebooks/tutorial/*_emu.ipynb`` in the
  `qick repository <https://github.com/openquantumhardware/qick/tree/main/emulator>`_,
  and can be run **directly in Google Colab** with no local install --
  each notebook's first "Colab Setup" cell clones the repo and installs
  Verilator for you. See the emulator's
  `README <https://github.com/openquantumhardware/qick/tree/main/emulator#running-in-google-colab-no-install>`_
  for details. Each emulator notebook's intro cell notes what had to be
  adapted or skipped versus the hardware original.

Remote Execution
================

.. TODO: needs to explain starting the nameserver; I also suspect this is using make_proxy incorrectly and losing the soccfg object
   we should update the pyro notebook and add that in here

For remote execution (e.g., from a PC), you'll need to start the QICK proxy server on the board first:

.. code-block:: bash

   python -m qick.pyro

Then in your notebook, use:

.. code-block:: python

   from qick.pyro import make_proxy
   soc = make_proxy("board_ip_address")

Common Setup Cell (copy this to any notebook)
=============================================

.. code-block:: python

   # Configuration
   BITSTREAM_PATH = "/path/to/your/firmware.bit"  # ← CHANGE THIS

   # Optional: remote execution
   USE_PROXY = False
   PROXY_IP = "192.168.1.100"

   # Connection
   from qick import QickSoc
   import numpy as np
   import matplotlib.pyplot as plt
   
   if USE_PROXY:
       from qick.pyro import make_proxy
       soc = make_proxy(PROXY_IP)
       print(f"Connected to proxy at {PROXY_IP}")
   else:
       soc = QickSoc(bitfile=BITSTREAM_PATH)
       print("Connected directly to RFSoC")
   
   print(f"Firmware: {soc.get_cfg()['fw_version']}")
   print(f"tProc cores: {soc.num_tprocs}")

Troubleshooting
===============

* If you see "Bitstream not found", check `BITSTREAM_PATH`
* If tProc commands fail, try `soc.reset_gens()` and `soc.reset_adcs()`
* For proxy connection issues, verify the board IP and that the proxy is running
* If no signal in readout, check DAC→ADC loopback cables, verify `gen_ch` is correct
* Phase rotates with frequency, run electrical delay calibration (see [notebook 07](./07_Advanced_Generators_And_Readouts.ipynb))

See Also
========

- :doc:`../quick_start` - Quick installation guide
- :doc:`../topics/asmv2_cheatsheet` - tProc v2 cheatsheet
- :doc:`../topics/timing` - More details on timeline management
