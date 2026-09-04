========================================================
Signal Generator v6 (SG-v6) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

The **Signal Generator v6** (SG-v6) is the newest version of QICK's
on-chip waveform engine. It supersedes SG-v5 with a richer feature set,
lower latency, and full compatibility with all QICK-compatible boards
(ZCU216, ZCU111, etc.). The module lives in the ``qick`` firmware
repository under ``firmware/ip/axis_signal_gen_v6/`` and is exposed to Python
through the ``qick.drivers.generator`` class.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

The **Signal Generator v6 (SG-v6)** is the QICK waveform generation module 
implemented in the ``signal_gen_top`` firmware entity. Its architecture combines:

* A **dual-port memory (BRAM)** to store envelope samples.
* A **FIFO** to queue 160-bit waveform descriptors.
* A central ``signal_gen`` block that reads the FIFO, accesses memory, and generates 
  the output through N parallel DDS channels.

The module supports two synthesis-configurable operating modes:

* **DDS Mode** (``GEN_DDS = "TRUE"``): generates complex tones with upconversion.
* **Baseband Mode** (``GEN_DDS = "FALSE"``): outputs only the envelope, without DDS.

And two envelope types:

* **COMPLEX** (``ENVELOPE_TYPE = "COMPLEX"``): separate memories for real and imaginary parts.
* **REAL** (``ENVELOPE_TYPE = "REAL"``): real part only; the imaginary part is forced to zero.

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - Default Value
     - Description
   * - ``N``
     - 16
     - Memory address bus size (number of bits). The effective table depth 
       is **2^N** samples per bank.
   * - ``N_DDS``
     - 16
     - Number of parallel DDS blocks and, therefore, samples emitted per clock 
       cycle on the ``m_axis_tdata_o`` output bus (total width = ``N_DDS × 16`` bits).
   * - ``GEN_DDS``
     - ``"TRUE"``
     - ``"TRUE"`` instantiates DDS blocks for upconversion. ``"FALSE"`` generates only 
       the baseband envelope.
   * - ``ENVELOPE_TYPE``
     - ``"COMPLEX"``
     - ``"COMPLEX"`` instantiates separate BRAMs for real and imaginary parts. ``"REAL"`` 
       uses only the real BRAM and assigns zero to the imaginary part.

--------------------------------------------------------------------
3. Interface Ports
--------------------------------------------------------------------

3.1 Clock and Reset
^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 30 10 50

   * - Signal
     - Direction
     - Description
   * - ``aresetn``
     - input
     - Active-low reset for the main clock domain (``aclk``).
   * - ``aclk``
     - input
     - Main clock. Drives the FIFO, the ``signal_gen`` block, and the output bus.

3.2 S0_AXIS – Envelope Sample Loading
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Slave AXI-Stream interface to transfer envelope samples to the internal BRAM. 
It operates in the ``s0_axis_aclk`` domain, which can be different from ``aclk``.

.. list-table::
   :header-rows: 1
   :widths: 30 10 10 50

   * - Signal
     - Direction
     - Width
     - Description
   * - ``s0_axis_aresetn``
     - input
     - 1
     - Active-low reset for the S0 domain.
   * - ``s0_axis_aclk``
     - input
     - 1
     - S0 domain clock. Can differ from ``aclk`` (dual-clock BRAM).
   * - ``s0_axis_tdata_i``
     - input
     - 32
     - Sample data. Bits [15:0] = real part; bits [31:16] = imaginary part 
       (only written if ``ENVELOPE_TYPE = "COMPLEX"``).
   * - ``s0_axis_tvalid_i``
     - input
     - 1
     - Indicates valid data on the bus (standard AXI-Stream protocol).
   * - ``s0_axis_tready_o``
     - output
     - 1
     - Module indicates availability to receive data.

3.3 S1_AXIS – Waveform Queue
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Slave AXI-Stream interface to queue **160-bit** waveform descriptors. 
Each descriptor defines the parameters for a playback burst.

.. list-table::
   :header-rows: 1
   :widths: 30 10 10 50

   * - Signal
     - Direction
     - Width
     - Description
   * - ``s1_axis_tdata_i``
     - input
     - 160
     - 160-bit waveform descriptor. The ``signal_gen`` block interprets its 
       content internally.
   * - ``s1_axis_tvalid_i``
     - input
     - 1
     - Indicates a valid descriptor. Connected directly to ``fifo_wr_en``.
   * - ``s1_axis_tready_o``
     - output
     - 1
     - Asserted when the internal FIFO is not full (``~fifo_full``).

3.4 M_AXIS – Data Output
^^^^^^^^^^^^^^^^^^^^^^^^^

Master AXI-Stream interface that delivers generated samples to the DAC or the 
next block in the datapath.

.. list-table::
   :header-rows: 1
   :widths: 30 10 10 50

   * - Signal
     - Direction
     - Width
     - Description
   * - ``m_axis_tready_i``
     - input
     - 1
     - Consumer indicates it can accept data.
   * - ``m_axis_tvalid_o``
     - output
     - 1
     - Module indicates that ``m_axis_tdata_o`` contains valid data.
   * - ``m_axis_tdata_o``
     - output
     - ``N_DDS × 16``
     - Output sample bus. With default values (``N_DDS = 16``), the width is 
       **256 bits**, corresponding to 16 samples of 16 bits per cycle.

3.5 Control Registers
^^^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 30 10 10 50

   * - Signal
     - Direction
     - Width
     - Description
   * - ``START_ADDR_REG``
     - input
     - 32
     - Starting address in BRAM where the ``data_writer`` will begin writing 
       samples received via S0_AXIS.
   * - ``WE_REG``
     - input
     - 1
     - BRAM write enable. When asserted, the ``data_writer`` propagates the 
       write to the selected BRAM.

--------------------------------------------------------------------
4. Internal Architecture
--------------------------------------------------------------------

The ``signal_gen_top`` module instantiates and connects four main blocks:

4.1 FIFO (``fifo_xpm``)
^^^^^^^^^^^^^^^^^^^^^^^

* Data width: **160 bits**.
* Depth: **16 entries**.
* Writing occurs directly from S1_AXIS (``fifo_wr_en = s1_axis_tvalid_i``).
* The ``fifo_full`` flag controls the ``s1_axis_tready_o`` signal (backpressure).
* The ``signal_gen`` block manages reading (``fifo_rd_en``).

4.2 Data Writer (``data_writer``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Receives samples via S0_AXIS and writes them to the correct BRAM according to the 
``START_ADDR_REG`` and ``WE_REG`` registers. It generates bank enable signals 
(``mem_ena``, an ``N_DDS``-bit vector), address (``mem_addra``), and data (``mem_dia``).

4.3 BRAM Memories (``bram_dp_xpm``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**N_DDS** BRAM instances are generated (one per DDS channel), each **16 bits wide** 
and **2^N** positions deep.

* **Port A (Write):** ``s0_axis_aclk`` domain. Receives data from the ``data_writer``.
* **Port B (Read):** ``aclk`` domain. The ``signal_gen`` provides the address 
  ``mem_addrb`` and receives data in parallel.

If ``ENVELOPE_TYPE = "COMPLEX"``, a second BRAM per channel is instantiated for 
the imaginary part (data in bits [31:16] of the S0 bus). If ``ENVELOPE_TYPE = "REAL"``, 
the ``mem_dob_imag`` signal is forced to zero.

.. note::

   Both BRAMs (real and imaginary) of a channel share the same read address 
   ``mem_addrb`` and enable pin ``mem_ena[i]``, ensuring coherence between 
   real and imaginary parts.

4.4 Signal Generator (``signal_gen``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The core of the module. It reads descriptors from the FIFO, generates memory 
addresses, and produces output samples by combining the envelope read from BRAM 
with the DDS blocks. The ``GEN_DDS`` parameter controls whether internal DDS 
blocks are instantiated.

--------------------------------------------------------------------
5. Data Flow Diagram
--------------------------------------------------------------------

::

   S0_AXIS ──► data_writer ──► BRAM_real[0..N_DDS-1]  ──┐
                               BRAM_imag[0..N_DDS-1]  ──┤
                                                        ▼
   S1_AXIS ──► fifo_xpm ──────────────────────────► signal_gen ──► M_AXIS
                                                   (+ DDS if GEN_DDS=TRUE)

   Registers: START_ADDR_REG, WE_REG ──► data_writer

--------------------------------------------------------------------
6. Python Usage (QICK)
--------------------------------------------------------------------

.. note::

  Earlier revisions of this section showed a direct-register API
  (``gen.set_freq()``, ``gen.load_waveform()``, ``tproc.load_wave()``, raw
  ``WPORT_WR`` assembly) that does not match the current ``qick_lib``
  driver/assembler -- there is no ``qick.SignalGenerator`` class, and none
  of those methods exist on the actual generator driver
  (``qick.drivers.generator.AxisSignalGen``). The workflow below was
  verified against ``qick.qick_asm``/``qick.asm_v2`` in this repository.

``soc.gens[i]`` gives you the low-level driver for generator array index
``i`` -- this is the same ``i`` you pass to ``declare_gen(ch=i, ...)`` and
``add_pulse(ch=i, ...)``, and the same index :class:`.QickProgram` code
always uses. It is **not** simply "tProc channel - 1": which tProc
waveform port and DAC each array index maps to is board-specific and, on
some boards, not a 1:1 mapping at all (see the worked ZCU216 example in
:doc:`/firmware`'s :ref:`tproc-zcu216-example`). Normal programs never need
to know this mapping -- declare the channel once by its ``soc.gens[]``
index, register any envelopes, add named pulses, then play them by name at
whatever time you choose.

6.1. Basic Configuration and Immediate Playback
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A ``const`` pulse needs no envelope -- the DDS output is gated on for
``length`` at a fixed ``gain``.

.. code-block:: python
  :caption: Basic SG-v6 pulse from Python

  from qick import *

  soc = QickSoc()

  class BasicPulse(AveragerProgramV2):
      def _initialize(self, cfg):
          # gen array index 0 -- see /firmware for how this maps to a
          # DAC on your specific board
          self.declare_gen(ch=0, nqz=1)
          self.add_pulse(ch=0, name="tone", style="const",
                          freq=100.0, phase=0, gain=0.5, length=1.0)  # MHz, deg, -1..1, us

      def _body(self, cfg):
          self.pulse(ch=0, name="tone", t=0)

  prog = BasicPulse(soccfg, reps=1, final_delay=1.0, cfg={})
  prog.acquire(soc)   # no readouts declared -> just runs the pulse once per rep

6.2. Playing a Shaped Pulse with an Envelope
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Shaped pulses (Gaussian, DRAG, etc.) go through
:meth:`.QickProgram.add_envelope` -- the I/Q samples are uploaded to the
generator's internal BRAM once, and referenced by name from any number of
``arb`` (or ``flat_top``) pulses. ``add_envelope`` handles the
``w_env``/length bookkeeping for you.

.. code-block:: python
  :caption: Shaped pulse with a Gaussian envelope

  from qick import *
  import numpy as np

  soc = QickSoc()

  class GaussianPulse(AveragerProgramV2):
      def _initialize(self, cfg):
          self.declare_gen(ch=0, nqz=1)

          n_samples = 1024
          sigma = n_samples / 6
          idata = 30000 * np.exp(-0.5 * ((np.arange(n_samples) - n_samples/2) / sigma)**2)
          self.add_envelope(ch=0, name="gauss", idata=idata.astype(np.int16))

          self.add_pulse(ch=0, name="shaped", style="arb",
                          freq=100.0, phase=0, gain=0.9, envelope="gauss")

      def _body(self, cfg):
          self.pulse(ch=0, name="shaped", t=0)

  prog = GaussianPulse(soccfg, reps=1, final_delay=1.0, cfg={})
  prog.acquire(soc)

6.3. Multiple Pulses and the SG-v6 FIFO
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The SG-v6 can queue up to **16 waveform descriptors** in hardware (see
"FIFO Capacity" under §7 below); in software you just call :meth:`.QickProgram.pulse`
multiple times with different (or repeated) pulse names and times -- the
compiler emits one ``WPORT_WR`` per call, and the SG-v6's own FIFO/playback
logic handles queuing and back-to-back timing.

.. code-block:: python
  :caption: Queueing several pulses on the same channel

  class MultiPulse(AveragerProgramV2):
      def _initialize(self, cfg):
          self.declare_gen(ch=0, nqz=1)
          self.add_pulse(ch=0, name="long", style="const",
                          freq=100.0, phase=0, gain=0.5, length=2.0)
          self.add_pulse(ch=0, name="short", style="const",
                          freq=105.0, phase=0, gain=0.5, length=0.5)

      def _body(self, cfg):
          self.pulse(ch=0, name="long", t=0)
          self.pulse(ch=0, name="short", t=3.0)   # us, relative to this shot's t=0

6.4. Descriptor Fields Reference
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The 168-bit ``r_wave`` bus (written via ``WPORT_WR``) contains six fields.
When using the tProcessor, these fields are written individually via ``w_freq``,
``w_phase``, etc., or as a group via ``r_wave``.

.. list-table:: SG-v6 Descriptor Fields (r_wave composition)
  :header-rows: 1
  :widths: 15 20 15 50

  * - Field
    - Register
    - Bits
    - Description
  * - Frequency
    - ``w_freq``
    - 32
    - DDS frequency control word (0 = DC, 2^31 = Nyquist)
  * - Phase
    - ``w_phase``
    - 32
    - DDS phase offset (2^32 = 360°)
  * - Gain
    - ``w_gain``
    - 32
    - Amplitude scaling (signed 32-bit, max 2^31-1)
  * - Envelope Start
    - ``w_env``
    - 24
    - Start address in envelope memory (for shaped pulses)
  * - Length
    - ``w_length``
    - 32
    - Number of samples to output (for shaped pulses)
  * - Configuration
    - ``w_conf``
    - 16
    - Mode, output selection, etc. (see SG-v6 source)

.. note::

  The 160-bit descriptor sent via S1_AXIS is packed internally by
  :meth:`.Waveform.compile` (``qick.asm_v2``) from the fields you pass to
  :meth:`.QickProgram.add_pulse`/:meth:`.QickProgram.add_envelope` -- you
  don't need to build it by hand.

6.5. Additional Resources
^^^^^^^^^^^^^^^^^^^^^^^^^

For more examples (multi-channel playback, real-time frequency hopping,
envelope chaining, advanced tProc sequencing), refer to:

- **QICK Tutorial Notebooks**: :doc:`/tutorials/06_Generators_And_Readouts`,
  :doc:`/tutorials/07_Advanced_Generators_And_Readouts`
- **tProcessor Documentation**: :doc:`/tprocv2_trm`
- **Firmware Overview**: :doc:`/firmware`
- **Community Examples**: Check the `#qick` channel on the Unitary Fund Discord

--------------------------------------------------------------------
7. Implementation Considerations
--------------------------------------------------------------------

**Clock Domains:**
  The module contains two clock domains (``s0_axis_aclk`` and ``aclk``). Domain 
  crossing is resolved via dual-clock BRAMs. Ensure appropriate timing constraints 
  are applied in the XDC file.

**BRAM Read Latency:**
  The ``bram_dp_xpm`` instances have ``OUT_REG_ENA = 1``, adding one cycle 
  of latency to the read port to improve timing.

**Output Bus Width:**
  The ``m_axis_tdata_o`` bus is ``N_DDS × 16`` bits wide. With the default 
  ``N_DDS = 16``, this equals **256 bits** (32 bytes) per transaction.

**Memory Depth:**
  With parameter ``N = 16``, each BRAM has **65,536 positions** of 16 bits, 
  equivalent to **128 KB** per bank (real or imaginary).

**FIFO Capacity:**
  The waveform FIFO has a capacity for **16 descriptors** of 160 bits. 
  If the producer is faster than the consumer, the ``s1_axis_tready_o`` 
  signal must be managed.

--------------------------------------------------------------------
8. Default Parameters – Quick Summary
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Configuration
     - Value
   * - Samples per cycle (M_AXIS)
     - 16 (``N_DDS = 16``)
   * - Output bus width
     - 256 bits
   * - Table depth per bank
     - 65,536 samples (``N = 16``)
   * - FIFO capacity
     - 16 descriptors of 160 bits
   * - Envelope type
     - Complex (I + Q)
   * - DDS Mode
     - Enabled (upconversion)

--------------------------------------------------------------------
9. Relevant Source Files
--------------------------------------------------------------------

* ``signal_gen_top.v`` – Top module described in this document.
* ``signal_gen.v`` – DDS core and playback logic.
* ``data_writer.v`` – BRAM sample writing from AXI-Stream.
* ``fifo_xpm.v`` – Parameterizable FIFO based on Xilinx XPM primitives.
* ``bram_dp_xpm.v`` – Parameterizable dual-port BRAM (Xilinx XPM).

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/generators` - overview of all QICK signal generator types and when to use each
* :doc:`/tprocv2_trm` - tProcessor v2 for sequencing and triggering
* :doc:`/firmware` - Firmware overview and channel assignments
* :doc:`/sg_mux8`, :doc:`/sg_mixmux8` - multi-tone generators, for playing several simultaneous fixed tones instead of one arbitrary-envelope pulse
* :doc:`/sg_int4_v2` - a lighter single-tone arbitrary generator (see :doc:`/generators` for the tradeoffs)
* :doc:`/sg_v4` - the legacy predecessor to SG-v6
* `SG-v6 source code <https://github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_signal_gen_v6>`_
