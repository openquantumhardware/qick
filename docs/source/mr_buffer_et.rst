========================================================
Multi-Rate Buffer (mr_buffer_et) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

The **Multi-Rate buffer with External Trigger** (``mr_buffer_et``) is a
small on-chip capture buffer that taps a readout's *undecimated* data
stream -- the downconverted but not-yet-decimated samples, straight out of
the digital mixer, before the readout's FIR/decimate-by-N stage. This is in
contrast to :doc:`/avg_buffer`'s raw buffer and the DDR4 buffer
(``axis_buffer_ddr_v1``), which both see the *decimated* stream. Because it
sits upstream of decimation, ``mr_buffer_et`` sees the full ADC-rate signal
(useful for looking at spurs, noise, or transient/settling behavior that
decimation would filter out), at the cost of a much smaller capture depth
(on-chip BRAM, not DDR4). The module lives in the ``qick`` firmware
repository under ``firmware/ip/mr_buffer_et/`` and is exposed to Python
through ``qick.drivers.readout.MrBufferEt``.

.. note::

   The RTL under ``firmware/ip/mr_buffer_et/src/`` (``mr_buffer_et.sv``) is
   a SystemVerilog rewrite whose file header identifies it as VLNV
   ``qick:ip:mr_buffer_et:1.2.0`` / ``@version 1.2``. However, as of this
   writing the packaged ``component.xml`` in the same directory (Xilinx IP
   packager metadata) still lists the legacy VHDL sources
   (``mr_buffer_v1_0.vhd`` and friends) and reports IP version ``1.1``, and
   the Python driver's ``bindto`` list (``qick_lib/qick/drivers/readout.py``)
   only recognizes VLNVs ending in ``:1.0`` and ``:1.1``. Board designs
   checked in this repository (e.g.
   ``firmware/projects/qick_tprocv2_111_standard/bd_2023-1.tcl``) also
   instantiate ``QICK:QICK:mr_buffer_et:1.1``. This document describes the
   behavior of the SystemVerilog source in ``src/`` (which is what a fresh
   IP-XACT repackage would pick up), and calls out anywhere that source
   adds behavior (the ``STATUS``/``capture_done`` register, notably) that
   the current driver does not yet use. It was **not** verified against the
   actual synthesized bitstream of any specific board release -- the two
   register fields the driver does use (``dw_capture_reg``,
   ``dr_start_reg``) are unchanged between the VHDL and SystemVerilog
   implementations, so this is not expected to matter in practice.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

``mr_buffer_et`` (top level ``mr_buffer_et.sv``, wrapping the core
``mr_buffer.sv``) captures ``NM`` parallel channels of ``B`` bits each into
``NM`` independent BRAMs (depth ``2**N`` per BRAM) at full write-side rate
(``s_axis_aclk``). A capture is armed in software (``dw_capture_reg=1``)
and then started by an external hardware ``trigger`` input; once the
window fills, the captured data is drained out as a single ``B``-bit
AXI4-Stream on the read side (``m_axis_aclk``) when software pulses
``dr_start_reg=1``. Per the module's own header comment
(``firmware/ip/mr_buffer_et/src/mr_buffer_et.sv``), the intended flow is:

1. SW writes ``dw_capture_reg=1`` -- arm the writer.
2. External ``trigger`` fires -- BRAMs fill with ``2**N`` samples/channel.
3. SW writes ``dr_start_reg=1`` -- stream the whole window out.
4. AXI-DMA S2MM drains ``M_AXIS`` to memory (read burst = ``NM*2**N``
   beats, ending in ``tlast``).

The ``NM`` parallel input channels exist because the source data arrives
faster than one sample per fabric clock: per the QICK demo notebook
(``qick_demos/08_Special_buffers.ipynb``), the MR buffer "is fed by the
downconverted but undecimated data stream coming out of the readout, so
you get 8 samples per fabric tick, or 1 sample per ADC tick." This lines
up with the RTL: ``axis_dyn_readout_v1``'s downsampling ratio is 8
(``DOWNSAMPLING = 8`` on ``AxisDynReadoutV1`` in
``qick_lib/qick/drivers/readout.py``), and the default synthesis parameter
is ``NM=8`` -- so in typical firmware images, one fabric-clock beat of the
undecimated stream carries all ``NM`` samples that will land at ``ADC
rate`` in real time, and ``mr_buffer_et`` writes all ``NM`` of them into
``NM`` separate BRAMs in that same beat.

In board designs (see e.g.
``firmware/projects/qick_tprocv2_111_standard/bd_2023-1.tcl``),
``mr_buffer_et`` sits downstream of a many-to-one AXI4-Stream switch
(``axis_switch_mr``) whose inputs are the ``m0_axis`` ports of the board's
dynamic readouts (``axis_dyn_readout_v1``) -- the undecimated tap; compare
with the ``m1_axis`` port of the same readouts, which is the decimated
stream that feeds :doc:`/avg_buffer`. Its own ``m00_axis`` output feeds an
AXI-DMA (``axi_dma_mr``) that drains captured data to PS-side (CPU)
memory. In that same board design the instance is parameterized with
``B=32`` (a packed 16-bit I / 16-bit Q sample) and ``N=10`` (1024-deep
per-channel BRAM), leaving ``NM`` at its RTL default of 8 -- giving a
total capacity of ``8*1024 = 8192`` I/Q samples.

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - RTL Default
     - Description
   * - ``NM``
     - 8
     - Number of parallel memories/channels captured per write-side clock
       (``mr_buffer_et.sv``). Each channel is written into its own BRAM.
   * - ``N``
     - 8
     - Address width of each channel's BRAM; depth is ``2**N`` samples.
   * - ``B``
     - 16
     - Data width, in bits, of one sample in one channel
       (``s_axis_tdata`` is ``NM*B`` bits wide overall; ``m_axis_tdata`` is
       ``B`` bits wide, one channel's sample per beat on read-back).
   * - ``C_S_AXI_DW``
     - 32
     - AXI4-Lite data width (control-register bus).
   * - ``C_S_AXI_AW``
     - 6
     - AXI4-Lite address width. With 16 32-bit registers this must be at
       least ``$clog2(4) + $clog2(16) = 6`` bits, which is exactly what the
       RTL uses.
   * - ``DEBUG``
     - 0
     - When 1, ``s_dbg_probe``/``m_dbg_probe`` (32 bits each) are driven out
       for an ILA; when 0 they are tied to zero.

The RTL defaults above (``NM=8``, ``N=8``, ``B=16``) are not what real
boards use -- e.g. ``qick_tprocv2_111_standard`` overrides ``B=32`` and
``N=10`` (see Section 1) while leaving ``NM`` at its default of 8. Total
capture depth is always ``cfg['maxlen'] = NM * 2**N`` samples (this is
also how the Python driver computes it -- see Section 5).

--------------------------------------------------------------------
3. Datapath
--------------------------------------------------------------------

3.1 Write side -- ``axis_to_bram_trig`` (one instance per channel)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``mr_buffer.sv`` slices the wide ``s_axis_tdata`` (``NM*B`` bits) into
``NM`` per-channel ``B``-bit slices and instantiates one
``axis_to_bram_trig`` plus one true-dual-port BRAM (``bram_tdp``) per
channel. Each ``axis_to_bram_trig`` (``firmware/ip/mr_buffer_et/src/axis_to_bram_trig.sv``)
runs a 4-state FSM:

``INIT_ST -> TRIGGER_ST -> CAPTURE_ST -> END_ST``

* **INIT_ST**: idle; waits for ``capture_reg=1`` (the synchronized
  ``dw_capture_reg``); counters held cleared.
* **TRIGGER_ST**: armed, waiting for a ``trigger`` pulse (the arm can still
  be cancelled here by dropping ``capture_reg``).
* **CAPTURE_ST**: accepts AXI4-Stream input (``s_axis_tready`` asserted)
  and moves data from a small internal FIFO into the channel's BRAM.
  Retires to ``END_ST`` either when the capture window fills (``2**N``
  samples written) or ``capture_reg`` drops (an abort).
* **END_ST**: stops accepting new stream beats but keeps draining whatever
  is still queued in the FIFO into BRAM, so the tail of a capture is never
  lost when ``capture_reg`` drops mid-stream. Holds ``o_capture_done=1``
  (a level, not a sticky bit) until software de-asserts ``capture_reg`` and
  the internal FIFO is empty, at which point it returns to ``INIT_ST``.

An internal 16-deep synchronous FIFO (``fifo_sync``, first-word-fall-through)
decouples the AXI4-Stream handshake from the BRAM write pipeline; the
module's own header comments state the write-side invariants explicitly:
every beat actually accepted (``tvalid && tready``, not ``tvalid`` alone)
is written to the FIFO exactly once, every word popped from the FIFO while
the window still has room is committed to BRAM (the write pipeline is
driven off ``fifo_rd_en`` itself, so a state transition can't cancel an
in-flight write), and once the window is full further FIFO words are still
popped (and discarded) rather than stalling, so the FSM can still reach
``fifo_empty`` and retire. ``s_axis_tready`` from all ``NM`` channels is
AND-reduced (``mr_buffer.sv``) into the block's single ``s_axis_tready``
output -- all channels must have room, since they're written from the same
wide input word.

``o_capture_done`` from each of the ``NM`` per-channel FSMs is AND-reduced
in ``mr_buffer.sv`` into ``o_capture_done``, which crosses into
``s_axi_aclk`` through a 2-stage ``cdc_bit_sync`` and lands in the
AXI4-Lite ``STATUS`` register (register index 2, bit 0 -- see Section 4).

3.2 Read side -- ``bram_to_axis_nt`` (shared, reads all channels)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On the read side, all ``NM`` BRAMs' port-B outputs are concatenated into
one wide bus and fed to a single ``bram_to_axis_nt`` instance
(``firmware/ip/mr_buffer_et/src/bram_to_axis_nt.sv``), which walks every
address (0 to ``2**N-1``) and every channel (0 to ``NM-1``) at each
address, serializing the whole window onto the ``B``-bit
``m_axis_tdata``/``m_axis_tvalid``/``m_axis_tlast`` output. Output word
order for one read burst (``TOTAL_WORDS = NM*2**N``):

::

   word 0            : ch0 @ addr 0
   word 1            : ch1 @ addr 0
   ...
   word NM-1         : ch(NM-1) @ addr 0
   word NM           : ch0 @ addr 1
   ...
   word NM*2**N - 1  : ch(NM-1) @ addr (2**N - 1)   <- tlast here

FSM: ``INIT_ST -> READ_ST -> WRITE_ST -> ... -> READ_LAST_ST ->
WRITE_LAST_ST -> FIFO_ST -> END_ST -> INIT_ST``, started by ``start_reg``
(the synchronized ``dr_start_reg``). ``READ_ST``/``WRITE_ST`` alternate,
reading one BRAM address then cycling the channel selector through all
``NM`` channels at that address before advancing to the next address;
``READ_LAST_ST``/``WRITE_LAST_ST`` handle the final address, tagging the
very last channel's word with ``tlast``. Output beats are queued through
another internal FIFO (16 deep, widened by one bit to carry the ``tlast``
tag alongside the data, so ``tlast`` can never drift out of step with its
beat).

The module's own header documents a real bug fixed between v1.0 and v1.1
of this file that's worth knowing about if you ever touch this RTL: v1.0
retired ``FIFO_ST`` on the FIFO's ``empty`` flag and gated
``m_axis_tvalid`` on the FSM state, but Xilinx's XPM ``empty`` flag
deasserts a cycle or two *after* a write, so the FSM could sample
``empty=1`` while the final words (including the ``tlast`` beat) were
still in flight, strand them, and hang a downstream AXI-DMA waiting for a
``tlast`` that never came. v1.1 fixes this with an exact flight counter
(``fifo_level``, incremented/decremented directly from the write/read
strobes rather than from the XPM status flags) that ``FIFO_ST`` uses to
decide when the burst has truly drained, and by only gating
``m_axis_tvalid`` off in ``INIT_ST`` (never mid-burst).

3.3 Clock-domain crossings
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Three control signals cross clock domains via ``cdc_gray_sync`` (a 2-stage,
per-bit synchronizer -- despite the name, it does not gray-decode; see
``cdc_gray_sync.sv``, used here with ``N=2``, ``M=1``):

* ``dw_capture_reg`` (AXI-Lite domain) -> ``s_axis_aclk``.
* ``trigger`` OR'd with the debug force-trigger bit (``debug_reg[0]``) ->
  ``s_axis_aclk``.
* ``dr_start_reg`` (AXI-Lite domain) -> ``m_axis_aclk``.

and ``o_capture_done`` (from ``s_axis_aclk``, the write-side FSMs) crosses
back into ``s_axi_aclk`` via a 2-stage ``cdc_bit_sync`` in
``mr_buffer_et.sv`` before landing in the ``STATUS`` register.

3.4 Debug forcing
^^^^^^^^^^^^^^^^^

The 32-bit ``debug_reg`` (register 15, RW) has two functional bits
(``mr_buffer.sv``): bit 0 ORs a software-forced pulse into the hardware
``trigger`` input before CDC, and bit 1 forces ``s_axis_tready`` high
regardless of the AND-reduced per-channel ready signals
(``s_axis_tready = (&s_axis_tready_i) | s_axis_tready_force``) -- useful
for driving the input stream during bring-up without a real trigger
source or without every channel individually asserting ready.

--------------------------------------------------------------------
4. Register Map
--------------------------------------------------------------------

The AXI4-Lite interface is a generic 16-register, 32-bit-per-register
slave (``axil_slv.sv``, ``NUM_REGS=16``, ``AXI_DW=32``); with
``C_S_AXI_AW=6`` the register index is address bits ``[5:2]`` (byte
address = register index * 4). Only register 2 is marked read-only in
hardware (``RO_MASK = 16'b0000_0000_0000_0100``, i.e. bit 2); all other
registers are plain read/write and reset to 0 (``mr_buffer_et.sv`` does
not override ``axil_slv``'s default zero ``REG_INIT_VAL``).

.. list-table::
   :header-rows: 1
   :widths: 15 20 15 50

   * - Index
     - Register
     - Width
     - Description
   * - 0
     - ``dw_capture_reg``
     - 1 bit (RW)
     - 1 = arm the writer (capture-enable). Must be de-asserted and
       re-asserted to allow a new capture (per the driver's own
       docstring comment in ``qick_lib/qick/drivers/readout.py``).
   * - 1
     - ``dr_start_reg``
     - 1 bit (RW)
     - 1 = start the reader (drain the captured window out on
       ``m_axis``). Must be de-asserted and re-asserted to allow a new
       transfer.
   * - 2
     - ``STATUS`` (``capture_done``)
     - 1 bit (RO)
     - Bit 0 mirrors ``o_capture_done`` (synchronized into
       ``s_axi_aclk``): high once the write-side FSMs have all reached
       ``END_ST``. **Not currently read by the Python driver** -- see the
       note in Section 5.
   * - 3-14
     - reserved
     - --
     - Unused; reads as 0.
   * - 15
     - ``debug_reg``
     - 32 bits (RW)
     - Bit 0: force ``trigger``. Bit 1: force ``s_axis_tready`` high (see
       Section 3.4). Remaining bits unused.

--------------------------------------------------------------------
5. Python Interface
--------------------------------------------------------------------

The block is exposed through ``qick.drivers.readout.MrBufferEt``
(``bindto`` covers VLNVs ``user.org:user:mr_buffer_et:1.0``/``1.1`` and
``QICK:QICK:mr_buffer_et:1.0``/``1.1`` -- see the version note at the top
of this page). ``QickSoc`` auto-discovers at most one ``MrBufferEt``
instance that is actually wired to a readout (multiple would raise
``RuntimeError``, see ``qick_lib/qick/qick.py``) and exposes it as
``soc.mr_buf``, plus two convenience methods on ``QickSoc`` itself:

.. code-block:: python

  from qick import *

  soc = QickSoc()

  # Arm the buffer for readout channel RO_CH (selects the right switch
  # input, then toggles capture off/on so a fresh capture always starts
  # from a clean state).
  soc.arm_mr(ch=RO_CH)

  # Trigger it from a program -- add mr=True to any trigger() call,
  # or call it once in initialize() since later triggers are ignored
  # until the buffer is re-armed.
  prog = QickProgram(soccfg)
  prog.declare_readout(ch=RO_CH, freq=FREQ, length=100, gen_ch=GEN_CH)
  prog.trigger(mr=True)
  prog.end()
  prog.config_all(soc)
  soc.tproc.start()

  # Read back the captured window: an (n_samples, 2) array of int16, [:,0]=I, [:,1]=Q
  iq = soc.get_mr()

``soc.arm_mr(ch)`` calls ``mr_buf.set_switch()`` (routes the shared
``axis_switch_mr`` to the given readout channel -- or, if the board has no
switch, just asserts that the requested channel is the one hardwired in)
followed by ``mr_buf.disable()``/``mr_buf.enable()`` (toggle
``dw_capture_reg`` 0->1 to arm a fresh capture). ``soc.get_mr(start=None)``
calls ``mr_buf.transfer(start)``, which sets ``dr_start_reg=1``, DMAs the
whole ``NM*2**N``-sample window into a preallocated buffer
(``self.buff``, a ``pynq.allocate``'d ``np.int16`` array of shape
``2*cfg['maxlen']``) via the traced-out AXI-DMA (``self.dma``), clears
``dr_start_reg``, and returns ``np.copy(self.buff).reshape((-1,2))[start:]``.

``cfg['maxlen']`` is computed as ``2**N * NM`` from the synthesis
generics read out of the block description (``_init_config``), matching
the ``TOTAL_WORDS`` quantity from Section 3.2.

.. note::

   The driver's ``REGISTERS`` dict only defines ``dw_capture_reg`` (index
   0) and ``dr_start_reg`` (index 1) -- it does not read the ``STATUS``
   register (index 2) described in Section 4, so ``capture_done`` is not
   currently surfaced to Python; ``transfer()`` relies on the AXI-DMA
   S2MM transfer completing (``self.dma.recvchannel.wait()``) rather than
   polling hardware capture-done status.

.. note::

   ``_init_config`` sets ``cfg['junk_len'] = 8`` if the bound IP type
   string contains ``mr_buffer_et:1.0``, else ``0`` -- a workaround for a
   firmware bug (fixed in IP version 1.1, per git history) where the first
   several samples of a transfer read back as stale/junk data.
   ``transfer(start=None)`` defaults ``start`` to this ``junk_len`` and
   skips that many samples from the front of the returned array. Note
   that the demo notebook (``qick_demos/08_Special_buffers.ipynb``)
   describes this as "the first 8 samples are always stale" without the
   version conditional -- treat the driver's version-gated
   ``cfg['junk_len']`` as the authoritative value for a given board's
   bound IP version.

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/avg_buffer` -- the buffer that captures the *decimated* stream
  from the same readouts (accumulated and raw-decimated modes);
  ``mr_buffer_et`` instead captures the undecimated stream.
* :doc:`/readout_v2` and :doc:`/readout_dynamic` -- the readouts whose
  undecimated output (``m0_axis`` on the dynamic readouts) feeds this
  block via ``axis_switch_mr``.
* :doc:`/tprocv2_trm` -- the tProcessor trigger port that starts a
  capture, via ``prog.trigger(mr=True)``.

.. note::

   ``AxisBufferDdrV1`` (``qick.drivers.readout.AxisBufferDdrV1``, RTL
   under ``firmware/ip/axis_buffer_ddr_v1/``) is the other DDR4-adjacent
   buffer block and is easy to confuse with ``mr_buffer_et``, but the two
   are quite different. Per its own driver docstring, ``AxisBufferDdrV1``
   "is fed by the downconverted+decimated data stream coming out of the
   readout" -- i.e. the *same* stream that feeds :doc:`/avg_buffer`, not
   the undecimated stream ``mr_buffer_et`` sees -- and it streams
   continuously into off-chip DDR4 memory (via an AXI memory-mapped port,
   ``rstart_reg``/``wstart_reg``/``wnburst_reg`` etc.) rather than a small
   on-chip BRAM, giving it a vastly larger (multi-GiB) but still
   finite/wraparound capture depth. Its Python surface is
   ``soc.arm_ddr4()``/``soc.get_ddr4()`` rather than
   ``soc.arm_mr()``/``soc.get_mr()``.
