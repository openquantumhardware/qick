========================================================
Averager + Buffer (axis_avg_buffer) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

The **Averager + Buffer** (``axis_avg_buffer``) is the IP block that sits
downstream of a readout (:doc:`/readout`) and turns its decimated I/Q stream
into the two kinds of data a QICK program can pull back over PS-PL DMA:
accumulated points (:meth:`.AcquireMixin.acquire`) and raw decimated
waveforms (:meth:`.AcquireMixin.acquire_decimated`) -- see
:doc:`topics/readout_modes` for the software-level distinction. The module
lives in the ``qick`` firmware repository under
``firmware/ip/axis_avg_buffer/`` and is exposed to Python through
``qick.drivers.readout.AxisAvgBuffer`` (and its ``V1pt1``/``V1pt2``/
``AxisWeightedBuffer`` subclasses).

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

``axis_avg_buffer`` (``axis_avg_buffer.v``) takes one AXI-Stream input
(``s_axis``, the readout's decimated I/Q, ``2*B`` bits wide -- I in the low
``B`` bits, Q in the high ``B`` bits) and drives three independent output
streams from a single hardware ``trigger``:

* **m0_axis** -- the *averaged* buffer: one accumulated (I, Q) point per
  trigger, stored in a dedicated BRAM and DMA'd out on request. This is what
  ``acquire()`` reads.
* **m1_axis** -- the *raw* buffer: every decimated sample captured
  individually during the trigger window, stored in a second BRAM and DMA'd
  out separately. This is what ``acquire_decimated()`` reads.
* **m2_axis** -- the same accumulated point as m0, but streamed out live (via
  a small async FIFO, no BRAM round-trip) instead of waiting for a DMA
  request. This feeds an input port of the tProcessor directly, for
  real-time feedback (e.g. thresholding a readout result to steer the next
  part of the program without going through software).

Internally the block is two independent, symmetric halves -- ``avg_top``
(drives m0 + m2) and ``buffer_top`` (drives m1) -- both built from the same
pattern: a small FSM that writes captured/accumulated data into a dual-port
BRAM, and a second FSM (``data_reader``) that reads it back out over AXI-Stream
on request. Both halves share the same ``trigger`` and are independently
enabled/addressed/sized -- you can run one without the other.

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - RTL Default
     - Description
   * - ``B``
     - 16
     - Bit width of one I or one Q sample coming in on ``s_axis``
       (``s_axis_tdata`` is ``2*B`` bits: I in bits ``[B-1:0]``, Q in bits
       ``[2*B-1:B]``).
   * - ``N_AVG``
     - 10
     - Address width of the averaged-buffer BRAM. Depth (max number of
       accumulated points that can be stored per trigger burst) is
       ``2**N_AVG``. Exposed to Python as ``cfg['avg_maxlen']``.
   * - ``N_BUF``
     - 10
     - Address width of the raw-buffer BRAM. Depth (max number of raw
       samples per trigger) is ``2**N_BUF``. Exposed to Python as
       ``cfg['buf_maxlen']``.

The accumulator itself is ``2*B`` bits signed per component (``acc_i``,
``acc_q``), and the averaged-buffer word is ``4*B`` bits (``{acc_q, acc_i}``,
i.e. 64 bits total for the default ``B=16``) -- this is why the Python driver
reads ``avg_buff`` as ``np.int64`` and ``buf_buff`` (``2*B`` bits per raw
sample) as ``np.int32``/``np.int16`` (see :ref:`avgbuf-python`). Real board
configurations typically instantiate larger ``N_AVG``/``N_BUF`` than the RTL
default (see ``soc.cfg['readouts'][i]['avg_maxlen']``/``buf_maxlen']`` for
the values on your board -- read them at runtime rather than assuming a
number, since they vary by board and by readout channel).

--------------------------------------------------------------------
3. Averaged Buffer Datapath (m0_axis / m2_axis)
--------------------------------------------------------------------

The ``avg`` FSM (``avg.sv``) has two mutually exclusive modes, selected by
``AVG_PHOTON_MODE_REG``:

* **Accumulate mode** (``AVG_PHOTON_MODE_REG=0``, the default): on every
  valid input sample while triggered, ``acc_i += I`` and ``acc_q += Q``
  (plain running sums, no length normalization in hardware -- that division
  happens in software, see :meth:`.AcquireMixin.acquire`'s length
  normalization). After ``AVG_LEN_REG`` samples, the accumulated
  ``{acc_q, acc_i}`` word is written to BRAM at ``AVG_ADDR_REG`` and the FSM
  waits for the next trigger (auto-incrementing the write address each time,
  so consecutive triggers fill consecutive slots).
* **Edge-counter / "photon" mode** (``AVG_PHOTON_MODE_REG=1``): instead of
  summing I/Q, the block compares the I component against two signed
  thresholds (``AVG_H_THRSH_REG``, ``AVG_L_THRSH_REG``) and counts *rising
  edges* through the high threshold (a Schmitt-trigger-style hysteresis: a
  new edge only counts once I has dropped back below the low threshold and
  risen through the high threshold again). This is the ``EDGE_COUNTER``
  feature the Python driver flags via ``cfg['has_edge_counter']`` -- useful
  for photon-counting / single-photon-detector style readouts where you want
  a pulse count rather than an integrated amplitude.

FSM states: ``INIT -> START -> TRIGGER -> AVG -> QOUT -> WRITE_MEM ->
WAIT_TRIGGER -> (TRIGGER or START)``. ``AVG_START_REG`` gates whether the
block is armed at all; the actual capture only begins once the external
``trigger`` pulse arrives while armed, and the FSM returns to
``WAIT_TRIGGER``/``TRIGGER`` afterward so back-to-back triggers (e.g. once
per rep in a loop) each get their own BRAM slot without re-arming from
software.

The averaged-buffer BRAM is read out by a ``data_reader`` FSM controlled by
``AVG_DR_START_REG``/``AVG_DR_ADDR_REG``/``AVG_DR_LEN_REG``, independent of
the write side -- you can read back completed points while the FSM is
capturing new ones elsewhere in the buffer. ``m2_axis`` taps the same
accumulated word through a small async FIFO the instant it's computed
(``QOUT_ST``/``WRITE_MEM_ST``), without going through the BRAM/data_reader
path at all -- that's what makes it usable for low-latency in-program
feedback.

--------------------------------------------------------------------
4. Raw Buffer Datapath (m1_axis)
--------------------------------------------------------------------

``buffer_top``/``buffer.sv`` is structurally the same pattern (FSM + BRAM +
``data_reader``) but simpler: every individual decimated (I, Q) sample seen
while triggered (governed by ``BUF_START_REG``/``BUF_ADDR_REG``/
``BUF_LEN_REG``) is written to BRAM as-is, one sample per address, no
accumulation. Read-back uses its own independent
``BUF_DR_START_REG``/``BUF_DR_ADDR_REG``/``BUF_DR_LEN_REG`` registers. This
is the raw time-domain waveform :meth:`.AcquireMixin.acquire_decimated`
returns.

--------------------------------------------------------------------
5. Register Map
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - Register
     - Width
     - Description
   * - ``AVG_START_REG``
     - 1 bit
     - 0: averager disabled. 1: armed, waiting for/capturing on ``trigger``.
   * - ``AVG_ADDR_REG``
     - ``N_AVG`` bits
     - BRAM write address for the next accumulated point.
   * - ``AVG_LEN_REG``
     - 32 bits
     - Number of input samples to accumulate before writing out one point.
   * - ``AVG_PHOTON_MODE_REG``
     - 1 bit
     - 0: accumulate I/Q. 1: edge-counter mode (see above).
   * - ``AVG_H_THRSH_REG`` / ``AVG_L_THRSH_REG``
     - ``B`` bits (signed)
     - High/low thresholds for edge-counter mode.
   * - ``AVG_DR_START_REG``
     - 1 bit
     - 1: stream accumulated data out on ``m0_axis``.
   * - ``AVG_DR_ADDR_REG`` / ``AVG_DR_LEN_REG``
     - ``N_AVG`` bits
     - Start address / sample count for the ``m0_axis`` read-back.
   * - ``BUF_START_REG``
     - 1 bit
     - 0: raw buffer disabled. 1: armed, waiting for/capturing on ``trigger``.
   * - ``BUF_ADDR_REG`` / ``BUF_LEN_REG``
     - ``N_BUF`` bits
     - BRAM write address / number of raw samples to capture.
   * - ``BUF_DR_START_REG``
     - 1 bit
     - 1: stream raw data out on ``m1_axis``.
   * - ``BUF_DR_ADDR_REG`` / ``BUF_DR_LEN_REG``
     - ``N_BUF`` bits
     - Start address / sample count for the ``m1_axis`` read-back.

.. _avgbuf-python:

--------------------------------------------------------------------
6. Python Interface
--------------------------------------------------------------------

Most QICK programs never call this driver directly -- :meth:`.AcquireMixin.acquire`
and :meth:`.AcquireMixin.acquire_decimated` drive it for you. Use the driver
directly only when you need low-level control (custom triggering schemes,
reading a buffer mid-experiment, etc.). It is reached as
``soc.avg_bufs[readout_index]``.

.. code-block:: python

  from qick import *

  soc = QickSoc()
  buf = soc.avg_bufs[0]

  # Set the downconversion frequency on the readout that feeds this buffer.
  buf.set_freq(100.0, gen_ch=0)   # MHz

  # --- Accumulated (averaged) capture ---
  buf.config_avg(address=0, length=1)   # 1 accumulated point per trigger
  buf.enable(avg=True, buf=False)
  # ... run your tProc program, which fires `trigger` ...
  iq = buf.transfer_avg(address=0, length=1)   # -> shape (1, 2): [[I, Q]]

  # --- Raw (decimated) capture ---
  buf.config_buf(address=0, length=1024)
  buf.enable(avg=False, buf=True)
  # ... run your tProc program ...
  iq = buf.transfer_buf(address=0, length=1024)   # -> shape (1024, 2)

``transfer_avg``/``transfer_buf`` return the data already reshaped as
``(n_samples, 2)`` arrays of raw integers (not length-normalized or
offset-corrected -- that's what :meth:`.AcquireMixin._average_buf` and
:meth:`.AcquireMixin._ro_offset` do on top of this). Both work around a
known IP bug (fixed in newer IP versions, tracked by the driver's
``FIRST_OUT_SAMPLE_BUG_FIX`` flag) where the first sample of a transfer
always reads back as the sample at address 0, by silently requesting two
extra samples and discarding them.

Related Documentation
----------------------

* :doc:`/readout` -- the readout block that feeds this buffer's ``s_axis``.
* :doc:`topics/readout_modes` -- ``acquire()`` vs. ``acquire_decimated()``.
* :doc:`/tprocv2_trm` -- the tProcessor trigger that starts a capture, and
  the m2_axis feedback port.
* :doc:`/mr_buffer_et` -- the alternate multi-rate buffer used for
  DDR4/streaming readout of the *undecimated* data stream, as opposed to
  this block's decimated raw buffer.
