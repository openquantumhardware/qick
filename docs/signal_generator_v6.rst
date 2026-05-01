========================================================
Signal Generator v6 – QICK
========================================================

.. contents::
   :local:
   :depth: 2

.. image:: _static/qick_sg_v6.png
   :alt: QICK Signal Generator v6 block diagram
   :align: center
   :width: 700px

The **Signal Generator v6** (SG-v6) is the newest version of QICK’s
on-chip waveform engine. It supersedes SG-v5 with a richer feature set,
lower latency, and full compatibility with all QICK-compatible boards
(ZCU216, ZCU111, etc.). The module lives in the ``qick`` firmware
repository under ``firmware/ip/axis_signal_gen_v6/`` and is exposed to Python
through the :class:`qick.drivers.generator` class.

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

The module is exposed through the :class:`qick.SignalGenerator` class. Below 
is a minimal usage example:

.. code-block:: python
   :caption: Basic Example – Generating and playing a tone

   from qick import QickSoc

   q = QickSoc()
   q.initialize()

   sg = q.get_signal_generator(0)

   # Load a Gaussian envelope (real and imaginary parts)
   sg.load_waveform(envelope_i, envelope_q, start_addr=0)

   # Configure waveform descriptor and queue
   sg.set_pulse(freq=100e6, phase=0, gain=0.5, length=100)
   sg.trigger()

   q.close()

.. note::

   The 160-bit descriptor sent via S1_AXIS is generated internally by the 
   QICK Python class. For bit-format details, see the source code for 
   ``qick.SignalGenerator.pack_waveform()``.

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
