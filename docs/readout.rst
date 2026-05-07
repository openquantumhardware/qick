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

The readout system is accessed through the :class:`qick.QickSoc` object.
The average/buffer blocks are available as ``soc.avg_bufs[i]``.

**Basic configuration:**

.. code-block:: python

  from qick import *

  soc = QickSoc()

  # Select readout channel (0 or 1)
  ro = soc.avg_bufs[0]

  # Configure mode: 0 = raw samples, 1 = coherent averaging
  ro.set_avg_mode(0)

  # Set number of samples to capture (max depends on mode)
  ro.set_nsamp(1024)

  # Clear any old data
  ro.clear_buffer()

**Complete example with tProc trigger:**

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler
  import time

  soc = QickSoc()
  tproc = soc.tproc

  # Configure readout
  ro = soc.avg_bufs[0]
  ro.set_avg_mode(0)      # raw mode
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
  time.sleep(0.1)

  # Read data (returns I and Q components as lists of integers)
  data_i, data_q = ro.get_data()
  print(f"Captured {len(data_i)} samples")

**Reading data from multiple acquisitions (averaging mode):**

.. code-block:: python

  # Configure averaging mode
  ro.set_avg_mode(1)      # coherent averaging
  ro.set_nsamp(1024)
  ro.clear_buffer()

  # Repeat experiment N times
  n_averages = 100
  for i in range(n_averages):
      tproc.time_rst()
      tproc.start()
      time.sleep(0.01)    # wait for acquisition

  # After all averages, read accumulated data
  data_i, data_q = ro.get_data()
  # Data is already summed; divide by n_averages if needed
  avg_i = [x / n_averages for x in data_i]
  avg_q = [x / n_averages for x in data_q]

**Raw vs Averaged mode:**

.. list-table::
  :header-rows: 1
  :widths: 20 40 40

  * - Mode
    - Behavior
    - Use case
  * - Raw (0)
    - Each trigger overwrites previous data
    - Single-shot measurements, debugging
  * - Average (1)
    - Each trigger adds to accumulator
    - Noise reduction, coherent averaging

**Reading status and debugging:**

.. code-block:: python

  # Check if buffer is ready
  # (Implementation depends on firmware version)

  # Read raw data from ADC before decimation
  # (Requires additional configuration)

Common Readout Patterns
-----------------------

**Pattern 1: Wait for trigger, read once**

.. code-block:: python

  ro.set_avg_mode(0)
  ro.set_nsamp(1024)
  ro.clear_buffer()

  # Trigger via tProc
  tproc.load_mem(prog_mem=trigger_program)
  tproc.start()
  tproc.time_rst()

  # Poll until data is ready (simplified)
  time.sleep(0.001)  # Adjust based on acquisition length

  data_i, data_q = ro.get_data()

**Pattern 2: Accumulate many shots**

.. code-block:: python

  ro.set_avg_mode(1)
  ro.set_nsamp(1024)
  ro.clear_buffer()

  for shot in range(shots):
      tproc.start()
      tproc.time_rst()
      time.sleep(wait_time)

  data_i, data_q = ro.get_data()

**Pattern 3: Streaming mode (advanced)**

.. code-block:: python

  # For continuous acquisition, configure tProc to trigger repeatedly
  asm_stream = \"\"\"
      .ADDR 0x00
      REG_WR r0 imm #1000
  LOOP:
      TRIG p0 set @100
      TRIG p0 clr @200
      TIME inc_ref #500
      REG_WR r0 op -op(r0 - #1) -uf
      JUMP LOOP -if(NZ)
      .END
  \"\"\"

  # Configure readout for raw mode
  ro.set_avg_mode(0)
  ro.set_nsamp(100)

  # Start streaming
  tproc.load_mem(prog_mem=Assembler.str_asm2bin(asm_stream))
  tproc.start()

  # Read data after each trigger (requires synchronization)

Hardware Considerations
-----------------------

**Clock frequencies:**

- ADC sampling rate: ``soc.fs_adc`` (typically 3072 MHz)
- After decimation by 8: effective rate = ``soc.fs_adc / 8``

**Buffer sizes:**

- Raw mode: Maximum 1024 I/Q pairs (2k total samples)
- Average mode: Maximum 16384 I/Q pairs (32k total)

**Example: Calculating acquisition time**

.. code-block:: python

  n_samples = 1024
  decimation = 8
  adc_rate = soc.fs_adc           # Hz
  sample_period = 1 / (adc_rate / decimation)  # seconds per decimated sample
  acquisition_time = n_samples * sample_period
  print(f"Acquisition takes {acquisition_time * 1e6:.2f} us")

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - tProcessor v2 for triggering and sequencing
* :doc:`/firmware` - Firmware overview and channel assignments
* :doc:`topics/timing` - Timing considerations for readout
* :doc:`topics/freq_matching` - Frequency matching between generators and readouts