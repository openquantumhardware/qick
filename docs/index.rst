.. Sphinx Apidoc Turorial documentation master file, created by
   sphinx-quickstart on Fri Jan  8 20:52:00 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. toctree::
   :maxdepth: 2
   :hidden:

   quick_start
   modules
   topics/index
   firmware

   contact

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
We fully support the ZCU111, ZCU216, and RFSoC4x2 evaluation boards, and generally recommend using the newer generation of RFSoCs (ZCU216 and RFSoC4x2) for better overall performance.

Getting started with QICK
-------------------------

* First, for a global overview of the QICK and its capabilities, read `our instrumentation paper introducing the QICK <https://arxiv.org/abs/2110.00557>`_.

* If you have an RFSoC board and you want to configure it as a QICK board, follow :doc:`our quick start guide </quick_start>`.

* After you configure your board, you can test it with `our demo notebooks <https://github.com/openquantumhardware/qick/tree/main/qick_demos>`_.
  These are intended as a tutorial.
  The first demos explain important features of the QICK system and walk you through how to write working QICK programs.
  The later demos provide examples of useful measurements you might make with the QICK.
  We recommend that new users read and understand all of the demos.

More examples and resources
---------------------------

Other examples and tutorials (compatibility with the current QICK software is not guaranteed):

* `IEEE Quantum Week 2023 <https://github.com/openquantumhardware/QCE2023_public>`_
* `US QIS Summer School 2024 <https://github.com/openquantumhardware/QIS_SummerSchool_2024>`_
* `IEEE Quantum Week 2024 <https://github.com/openquantumhardware/QCE2024>`_

Talk to us
------------

You can get in touch with the QICK core team and the user community through our :doc:`community contact channels </contact>`.

QICK software
-------------

`Source code <https://github.com/openquantumhardware/qick/tree/main/qick_lib>`_ and :doc:`API documentation </modules>`

:doc:`/topics/index`

QICK firmware
-------------

Source code and instructions for compiling it yourself: `qick/firmware <https://github.com/openquantumhardware/qick/tree/main/firmware>`_

:doc:`/firmware`

Extensions beyond the core software and firmware
------------------------------------------------

If you want your board's state to persist between notebooks or scripts, you should install Pyro4 on your board and run QICK in a Pyro server: see `our Pyro4 demo notebooks <https://github.com/openquantumhardware/qick/blob/main/pyro4/00_nameserver.ipynb>`_

If you would like to save the instrument configuration for every measurement using `QCoDeS <https://microsoft.github.io/Qcodes/>`_, you can also install `this QCoDeS driver <https://github.com/aalto-qcd/qcodes_qick>`_.

If you're interested in using QICK to control and read out NV centers or other quantum defects, you might be interested in `QICK-DAWG <https://github.com/sandialabs/qick-dawg>`_ which extends QICK with pulses and measurement programs specific to that application.

If you want to use QICK for control and readout of solid-state spin qubits, `SpinQICK <https://github.com/HRL-Laboratories/spinqick>`_ extends the QICK API and provides high-level experiment code.

QICK papers
-------------

* For a list of academic papers produced using the QICK system, check out :doc:`our papers page </papers>`

.. toctree::
   :maxdepth: 2

   papers
