Readout System - QICK Firmware
==============================

.. contents::
   :local:
   :depth: 2

Overview
--------

The QICK readout system is built around two main IP blocks:

* **Readout Block** - Digital down-conversion (DDC), filtering, and decimation
* **Average + Buffer Block** - Data accumulation and storage

The readout process is triggered by an external signal (typically from tProcessor Channel 0) and can be configured for raw sample capture or coherent averaging.

.. figure:: ../graphics/qsystem-readout.svg
   :width: 100%
   :align: center

Readout Block
-------------

The readout block performs:

1. **Digital Down-Conversion (DDC)** - Mixes the ADC input with a DDS tone
2. **FIR Filtering** - Anti-aliasing filter
3. **Decimation by 8** - Reduces sample rate for easier processing

**Key parameters:**

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Parameter
     - Description
   * - DDS frequency
     - Configured via register (not intended for real-time hopping)
   * - FIR taps
     - Fixed coefficients (compiled into firmware)
   * - Decimation factor
     - Fixed at 8
   * - Input selection
     - Can route raw input, DDS wave, or frequency-shifted signal

The user can select which signal is sent to the FIR stage using an output selection register.

Average + Buffer Block
----------------------

This block receives the decimated data stream and can:

* **Store raw samples** - Capture individual samples for analysis
* **Perform coherent averaging** - Accumulate multiple acquisitions

**Capabilities:**

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Parameter
     - Value
   * - Raw buffer length
     - 1024 samples per component (I/Q) = 2k total
   * - Accumulated buffer length
     - 16384 samples per component (I/Q) = 32k total
   * - Trigger source
     - tProcessor Channel 0 (bit 14 for ADC0, bit 15 for ADC1)

**Trigger mapping:**
- tProc Channel 0, bit 14 → triggers average/buffer for ADC 224 CH0
- tProc Channel 0, bit 15 → triggers average/buffer for ADC 224 CH1

Python Interface
----------------

The readout system is accessed through the :class:`qick.QickSoc` object:

.. code-block:: python

   from qick import *

   soc = QickSoc()

   # Configure readout channel
   soc.avg_bufs[0].set_avg_mode(1)  # 0=raw, 1=average
   soc.avg_bufs[0].set_nsamp(100)    # number of samples to average

   # Trigger readout from tProcessor
   # (See tProc examples for sequencing)

**Complete example with tProc trigger:**

.. code-block:: python

   from qick import *
   from qick.tprocv2_assembler import Assembler

   soc = QickSoc()
   tproc = soc.tproc

   # Configure readout
   ro = soc.avg_bufs[0]
   ro.set_avg_mode(0)  # raw mode
   ro.set_nsamp(1024)
   ro.clear_buffer()

   # tProc program: trigger readout at time 1000
   asm_trigger = \"\"\"
       .ADDR 0x00
       TRIG p0 set @1000    // bit 14 triggers ADC0 readout
       .END
   \"\"\"

   prog_bin = Assembler.str_asm2bin(asm_trigger)
   tproc.load_mem(prog_mem=prog_bin)
   tproc.time_rst()
   tproc.start()

   # Wait for acquisition
   import time
   time.sleep(0.1)

   # Read data
   data_i, data_q = ro.get_data()
   print(f"Captured {len(data_i)} samples")

API Reference
-------------

.. autosummary::
   :toctree: _autosummary

   qick.drivers.readout
   qick.drivers.ReadoutBlock
   qick.drivers.AverageBuffer

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - tProcessor v2 for triggering and sequencing
* :doc:`/firmware` - Firmware overview and channel assignments
* :doc:`topics/timing` - Timing considerations for readout
* :doc:`topics/freq_matching` - Frequency matching between generators and readouts
