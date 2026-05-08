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
   :caption: Tutorials

   ../tutorials/00_Getting_Started
   ../tutorials/01_Basic_Sequencing
   ../tutorials/02_Parameter_Sweeps
   ../tutorials/03_Advanced_Timing
   ../tutorials/04_Real_Time_Feedback
   ../tutorials/05_Dynamic_Parameters_Subroutines
   ../tutorials/06_Hardware_Buffers
   ../tutorials/07_Appendix_Tips_And_Limits

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

See Also
========

- :doc:`../quick_start` - Quick installation guide
- :doc:`asmv2_cheatsheet` - tProc v2 cheatsheet
- :doc:`timing` - More details on timeline management
