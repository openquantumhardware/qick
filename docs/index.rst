.. Sphinx Apidoc Turorial documentation master file, created by
   sphinx-quickstart on Fri Jan  8 20:52:00 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. toctree::
   :maxdepth: 2
   :hidden:

   quick_start
   modules
   cheatsheet
   firmware

Welcome to the QICK documentation!
=================================================

.. figure:: ../graphics/QICK.jpg
   :width: 100%
   :align: center

.. figure:: ../graphics/ZCU216Board.jpg
   :width: 100%
   :align: center

The Quantum Instrumentation Control Kit (QICK for short) is a Xilinx RFSoC-based qubit controller which supports the direct synthesis of control and readout pulses.
The QICK consists of a digital board hosting an RFSoC (RF System-on-Chip) FPGA, custom firmware and software, and an optional companion custom-designed analog front-end board.
All of the schematics, firmware, and software are open-source and available on `Github <https://github.com/openquantumhardware/qick>`_.
Our team primarily supports the ZCU111, ZCU216, and RFSoC4x2 evaluation boards.
We generally recommend using the newer generation of RFSoCs (ZCU216 and RFSoC4x2) for better overall performance.

Getting started with QICK
-------------------------

* First, for a global overview of the QICK and its capabilities, read `our instrumentation paper introducing the QICK <https://arxiv.org/abs/2110.00557>`_.

* If you have an RFSoC board and you want to configure it as a QICK board, follow :doc:`our quick start guide </quick_start>`.

* After you configure your board, you can test it with `our library of loopback demos <https://github.com/openquantumhardware/qick/tree/main/qick_demos>`_. You can also check out `our library of oscilloscope and loopback demos made for our tutorial at IEEE Quantum Week 2023 <https://github.com/openquantumhardware/QCE2023_public>`_.

Getting help
------------

* Chat with us in the #qick channel on the `Unitary Fund Discord <http://discord.unitary.fund/>`_.

QICK software
-------------

Source code: `qick/qick_lib <https://github.com/openquantumhardware/qick/tree/main/qick_lib>`_

:doc:`API documentation </modules>`

:doc:`/cheatsheet`

QICK firmware
-------------

Source code and instructions for compiling it yourself: `qick/firmware <https://github.com/openquantumhardware/qick/tree/main/firmware>`_

:doc:`/firmware`

You also may want to learn more about how the QICK tProcessor works.
In this case, you can reference the `QICK assembly language documentation <https://github.com/openquantumhardware/qick/blob/main/firmware/tProcessor_64_and_Signal_Generator_V4.pdf>`_.
Note that this documentation is not up to date with the current version of the QICK tProcessor.
It is made available here as a learning tool for those interested in learning the principles of the tProcessor.
Those who have more specific questions can contact us.

QICK papers
-------------

* For a list of academic papers produced using the QICK system, check out :doc:`our papers page </papers>`

.. toctree::
   :maxdepth: 2

   papers
