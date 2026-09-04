==================================================================
Interpolated Signal Generator v2 (axis_sg_int4_v2) - QICK Firmware
==================================================================

.. contents::
  :local:
  :depth: 2

**axis_sg_int4_v2** is a single-tone, arbitrary-envelope waveform generator.
Unlike :doc:`/sg_v6`, which runs its DDS and envelope memory at the DAC's
full parallel sample rate, ``axis_sg_int4_v2`` stores the envelope at 1/4 of
the output rate and reconstructs the missing samples with a **4x
interpolation FIR filter** -- hence "int4". The module lives in the ``qick``
firmware repository under ``firmware/ip/axis_sg_int4_v2/`` and is exposed to
Python through ``qick.drivers.generator.AxisSgInt4V2``.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

Where "int4" comes from
^^^^^^^^^^^^^^^^^^^^^^^^

The Xilinx FIR Compiler instance ``fir_0`` inside ``signal_gen.v`` is
configured with ``Filter_Type = Interpolation`` and ``Interpolation_Rate =
4`` (read from ``firmware/ip/axis_sg_int4_v2/src/fir_0/fir_0.xci``). Each
cycle it consumes one complex envelope sample read from a single-rate BRAM
and produces **4** interpolated I/Q sample pairs, which are fed in parallel
to **4** DDS instances (``N_DDS = 4``, a ``localparam`` in
``axis_sg_int4_v2.v``). This matches the Python driver's own docstring for
the shared base class ``AbsIntSignalGen``: *"AXIS Signal Generator with
envelope x4 interpolation"* (``qick_lib/qick/drivers/generator.py``, and
``FS_INTERPOLATION = 4`` on that class -- though as of this reading that
attribute is defined but not actually read anywhere else in the driver
stack, so treat it as documentation rather than as something that changes
behavior).

This is the key architectural difference from :doc:`/sg_v6` (and the older
``axis_signal_gen_v4``/``v5``, referred to together as SG-v4/v5/v6 in the
Python driver): SG-v6 stores the envelope **pre-expanded**, with one BRAM
pair (real/imag) per parallel DDS lane (``N_DDS`` pairs, default 16), so
``maxlen = 2**N * N_DDS`` samples of table are actually stored. This int4
generator instead keeps a **single** real BRAM and a **single** imag BRAM
(see ``signal_gen_top.v``, instances ``mem_real_i``/``mem_imag_i``) holding
only ``2**N`` raw samples, and lets the FIR do the x4 expansion on the fly --
which is why the Python driver's ``AbsIntSignalGen._init_config`` computes
``self.cfg['maxlen'] = 2**env_n`` (no ``* n_dds`` factor), with the comment
*"Table is interpolated. Length is given only by parameter N."* Both designs
still emit ``N_DDS`` output samples per clock on ``m_axis_tdata_o``; int4
just trades BRAM area for a FIR filter to get there from a quarter-rate
table.

Like SG-v6, this generator is single-output (one complex tone per channel,
via its own DDS + envelope multiplier) -- it is not multiplexed like
``axis_sg_mux4_v1``, which drives several simultaneous tones from one
channel.

.. note::

   Unlike SG-v6, ``axis_sg_int4_v2`` has **no** ``GEN_DDS``/``ENVELOPE_TYPE``
   synthesis parameters: it always instantiates the DDS+multiplier path (no
   baseband-only mode) and always builds separate real/imag BRAMs (no
   real-only envelope mode). Confirmed by the absence of those parameters in
   ``axis_sg_int4_v2.v``/``signal_gen_top.v``/``signal_gen.v``, in contrast
   to ``firmware/ip/axis_signal_gen_v6/src/signal_gen_top.v`` which has both.

Because the DDS only needs to synthesize the frequency band around the
interpolated (quarter-rate) envelope, this generator relies on the RFDC's
own on-chip mixer for final upconversion: ``AbsIntSignalGen.HAS_MIXER =
True`` (whereas SG-v4/v5/v6's ``AxisSignalGen.HAS_MIXER = False``). In
practice this means ``QickProgram.declare_gen()`` requires a ``mixer_freq``
argument for this channel (``qick_lib/qick/qick_asm.py``, ``declare_gen``:
*"generator %d has a digital mixer, but no mixer_freq was defined"*), which
is not the case for SG-v6.

Version note (v1 -> v2)
^^^^^^^^^^^^^^^^^^^^^^^^

A brief diff against the sibling ``firmware/ip/axis_sg_int4_v1/`` shows the
two share essentially the same RTL structure (same module names, same
FIR/interpolation-by-4 configuration, same descriptor field layout). The one
substantive change is DDS/phase resolution: v1's ``dds_compiler_0`` is
configured with ``Phase_Width = 16`` (``Frequency_Resolution = 3906.25``,
i.e. Hz-scale steps), while v2's is configured with ``Phase_Width = 32``
(``Frequency_Resolution = 0.06``) -- a large increase in tuning resolution.
This propagates through the whole datapath: the ``freq``/``phase`` fields of
the waveform descriptor grow from 16 to 32 bits each, and the descriptor
itself grows from 85 bits (v1, ``s1_axis_tdata`` is ``[84:0]``) to 160 bits
(v2, ``s1_axis_tdata`` is ``[159:0]``) to carry the wider fields plus
padding. This is exactly mirrored in the Python driver: ``AxisSgInt4V1`` sets
``B_DDS = B_PHASE = 16`` ("Interpolated generator with 16-bit frequency and
phase"), ``AxisSgInt4V2`` sets ``B_DDS = B_PHASE = 32`` ("Interpolated
generator with 32-bit frequency and phase").

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - RTL Default
     - Description
   * - ``N``
     - 12 (``axis_sg_int4_v2.v``)
     - Envelope memory address width. Table depth is ``2**N`` raw (complex)
       samples; ``signal_gen_top.v``/``signal_gen.v`` themselves default to
       ``N = 16`` when instantiated standalone, but the top-level wrapper
       overrides this to 12. Real deployments commonly override it further
       per channel -- e.g. ``firmware/projects/qick_tprocv2_216_standard/
       bd_2023-1.tcl`` instantiates different ``axis_sg_int4_v2`` copies with
       ``CONFIG.N`` values of 13 and 14 -- so always read the deployed value
       from ``soc.cfg['gens'][i]['maxlen']`` rather than assuming a default.
   * - ``N_DDS``
     - 4 (fixed)
     - Number of parallel DDS lanes / interpolated output samples per clock.
       Declared as a ``parameter`` on ``signal_gen_top``/``signal_gen``, but
       the top-level ``axis_sg_int4_v2.v`` wrapper pins it to a
       ``localparam`` value of 4 -- it is not exposed as a customizable IP
       parameter the way SG-v6's ``N_DDS`` is.

--------------------------------------------------------------------
3. Datapath
--------------------------------------------------------------------

The pipeline, in order (all in ``signal_gen.v`` unless noted):

1. **ctrl (``ctrl.sv``)** -- an FSM (states ``READ_ST``/``CNT_ST``) pops one
   160-bit descriptor from the waveform FIFO into ``fifo_dout_r``, then holds
   its fields active for ``nsamp`` clock cycles (each cycle advances the
   envelope read address by 1 and advances each of the 4 DDS phase
   accumulators by ``pinc``, with per-lane phase offsets ``pinc*0..pinc*3``
   so the 4 parallel DDS outputs are phase-continuous with each other).  When
   the count expires, it either fetches the next queued descriptor or, if
   ``mode`` = periodic, keeps replaying the current one.
2. **Envelope memory (``mem_real_i``/``mem_imag_i``, ``bram.v``/dual-port
   BRAM in ``signal_gen_top.v``)** -- one real and one imag BRAM, ``N`` bits
   of address, 16 bits of data each, read at 1 address per clock (write side
   is in the ``s0_axis_aclk`` domain via ``data_writer``, read side in
   ``aclk``).
3. **Interpolation FIR (``fir_0``)** -- Xilinx FIR Compiler, interpolation
   filter, rate 4, cycle latency 11 (+1 registered output = 12 per the
   comment in ``signal_gen.v``). Expands the 1 complex envelope sample/clock
   into 4 (``env_dout``, ``N_DDS*32`` bits wide).
4. **DDS (``dds_compiler_0``, x4 instances)** -- Xilinx DDS Compiler,
   ``Phase_Width = 32``, ``Output_Width = 16`` (both real and imag), latency
   10 cycles.
5. **Complex multiply** -- each of the 4 lanes multiplies its DDS output
   (I, Q) against the corresponding interpolated envelope sample:
   ``real = I_dds*I_env - Q_dds*Q_env``, ``imag = I_dds*Q_env + Q_dds*I_env``,
   each 32-bit partial product truncated to the top 16 bits (a
   round-to-nearest-ish scheme: the accumulator's bit 30 is duplicated into
   bit 31 before truncation, i.e. ``{p[30], p[30:0]}``, then bits ``[31:16]``
   are kept). This 16-bit result is the "product" ``outsel``.
6. **Output source mux (``src_la``)** -- per lane, selects between the
   product (0), the raw DDS output (1), the raw interpolated complex
   envelope sample -- both real and imag, unlike the readout's "input"
   mode which is real-only -- for ``outsel = 2``
   (``{env_imag_la[i], env_real_la[i]}``), or an all-zero word (3, the
   implicit default of the mux).
7. **Gain multiply + rounding** -- the muxed sample is multiplied by a
   16-bit signed ``gain`` register (latency-aligned via a 19-cycle
   ``latency_reg``), and the 32-bit product is rounded down to 16 bits per
   component (``prodg_y_full_*_r[30 -: 16]``, i.e. keep bits 30 down to 15 --
   a right-shift-by-15 round rather than a symmetric round-to-nearest).
8. **Output register** -- while the waveform is active (``en_la_r``), the
   rounded, gain-scaled sample (``round_r``) is driven on
   ``m_axis_tdata_o``. Once inactive, the output holds the value selected by
   ``stdysel``: the last active sample (``stdysel = "last"``, code 0 -- and
   specifically the 4th of the last active clock's 4 lanes, broadcast to all
   4 output lanes, since ``last_r[i] <= round[N_DDS-1]`` for every ``i``) or
   all zeros (``stdysel = "zero"``, code 1).

.. note::

   ``params2pulse()`` in ``qick_lib/qick/asm_v2.py`` has an explicit
   workaround specific to this generator family (``axis_sg_int4_v1`` and
   ``axis_sg_int4_v2``, but not SG-v6): for ``flat_top`` pulses, an extra
   zero-gain, minimum-length ``"dds"``-outsel waveform is appended after the
   ramp-down, with the comment *"workaround for FIR bug: we play a
   zero-gain min-length DDS pulse after the ramp-down, which brings the FIR
   to zero."* This is presumably needed because the interpolation FIR (step
   3 above) has state/history that would otherwise bleed into the following
   pulse; SG-v6 has no FIR in its envelope path and needs no such
   workaround.

--------------------------------------------------------------------
4. Waveform Descriptor (S1_AXIS)
--------------------------------------------------------------------

``s1_axis_tdata`` is a 160-bit word pushed into a 160-bit-wide, 16-entry
FIFO (``fifo_i`` in ``signal_gen_top.v``, same depth as SG-v6's). Field
layout, read directly from the header comment and bit-slice assignments in
``ctrl.sv``:

.. list-table:: Waveform descriptor fields
   :header-rows: 1
   :widths: 15 15 15 55

   * - Field
     - Bits
     - Width
     - Description
   * - ``freq``
     - ``[31:0]``
     - 32
     - DDS frequency tuning word for all 4 lanes (phase increment per
       clock, before the x4 per-lane phase offset).
   * - ``phase``
     - ``[63:32]``
     - 32
     - DDS phase offset.
   * - ``addr``
     - ``[79:64]``
     - 16
     - Start address of the envelope in ``mem_real``/``mem_imag``.
   * - (unused)
     - ``[95:80]``
     - 16
     - Not read by ``ctrl.sv``.
   * - ``gain``
     - ``[111:96]``
     - 16
     - Signed output gain.
   * - (unused)
     - ``[127:112]``
     - 16
     - Not read by ``ctrl.sv``.
   * - ``nsamp``
     - ``[143:128]``
     - 16
     - Number of clock cycles (each emitting ``N_DDS`` = 4 output samples)
       the descriptor stays active in one-shot mode.
   * - ``outsel``
     - ``[145:144]``
     - 2
     - Output source select: 0 product, 1 dds, 2 input (envelope), 3 zero.
   * - ``mode``
     - 146
     - 1
     - 0 one-shot (stop after ``nsamp``), 1 periodic (replay).
   * - ``stdysel``
     - 147
     - 1
     - 0 last (hold last sample), 1 zero.
   * - ``phrst``
     - 148
     - 1
     - Reset the DDS phase accumulator when this descriptor loads.
   * - (unused)
     - ``[159:149]``
     - 11
     - Not read by ``ctrl.sv``.

This layout is bit-for-bit identical to SG-v6's 160-bit descriptor (same
field widths, same bit positions -- compare the header comment in this
IP's ``ctrl.sv`` against ``firmware/ip/axis_signal_gen_v6/src/ctrl.sv``).
Confirmed in the routing firmware itself: in
``firmware/projects/qick_tprocv2_216_standard/bd_2023-1.tcl``, the
``axis_sg_int4_v2_0`` instance's ``s1_axis`` is wired to
``sg_translator_5/m_gen_v6_axis`` -- i.e. it uses the **same**
``sg_translator`` output path (``OUT_TYPE = 0``, "gen_v6") as SG-v6, not the
dedicated, 88-bit, 16-bit-freq/phase ``int4_v1`` translation path
(``OUT_TYPE = 1``) that ``axis_sg_int4_v1`` uses. ``sg_translator``
(``firmware/ip/qick_sg_translator/src/sg_translator.v``) is the block that
sits between the tProcessor's generic 168-bit wave-memory word (``freq``,
``phase``, ``env``, ``gain``, ``length``, ``conf``) and this generator's
160-bit ``s1_axis`` -- it truncates the tProc's 32-bit ``length`` field down
to the 16-bit ``nsamp`` here, but passes ``freq``/``phase`` through
unmodified at full 32-bit width (unlike the truncation ``int4_v1`` needs).

--------------------------------------------------------------------
5. Register Map (S_AXI, AXI-Lite)
--------------------------------------------------------------------

``axi_slv.vhd`` implements a 32-bit AXI-Lite slave with a 6-bit address bus
(16 possible word-aligned registers), of which only two are wired to the
rest of the IP:

.. list-table::
   :header-rows: 1
   :widths: 20 15 15 50

   * - Register
     - Offset
     - Width
     - Description
   * - ``START_ADDR_REG``
     - 0x00
     - 32 bits
     - Starting address in envelope memory for the next block of samples
       written via ``S0_AXIS``.
   * - ``WE_REG``
     - 0x04
     - bit 0
     - Envelope-memory write enable. The ``data_writer`` FSM
       (``data_writer.vhd``) waits in ``INIT_ST`` until this is asserted,
       latches ``START_ADDR_REG`` as the write pointer, then streams
       ``S0_AXIS`` samples into ``mem_real``/``mem_imag`` (32-bit words:
       bits ``[15:0]`` real, ``[31:16]`` imag), auto-incrementing the
       address each valid beat.

This matches ``AbsIntSignalGen.REGISTERS = {'start_addr_reg': 0, 'we_reg':
1}`` in the Python driver (note: these are *register indices*, i.e.
``we_reg`` is word offset 1 = byte offset 0x04, not bit 1 of word 0).

--------------------------------------------------------------------
6. Python Interface
--------------------------------------------------------------------

The class hierarchy (``qick_lib/qick/drivers/generator.py``):

* ``AbsSignalGen`` -- common signal-gen config: ``MAXV``, ``set_nyquist()``,
  ``set_mixer_freq()``/``get_mixer_freq()`` (only usable if ``HAS_MIXER``).
* ``AbsArbSignalGen(AbsSignalGen)`` -- adds the envelope-memory ``load()``
  method (DMA transfer + ``START_ADDR_REG``/``WE_REG`` pulsing), plus
  ``SAMPS_PER_CLK`` (1 for this generator -- envelope samples are loaded
  one per clock, unlike SG-v6's 16) and ``MAXV_SCALE``.
* ``AbsPulsedSignalGen(AbsSignalGen)`` -- adds tProcessor-port discovery
  (``TPROC_PORT = 's1_axis'``) for tProc-triggered playback.
* ``AbsIntSignalGen(AbsArbSignalGen, AbsPulsedSignalGen)`` -- the shared
  base for both int4 versions: ``HAS_MIXER = True``,
  ``FS_INTERPOLATION = 4``, ``MAXV_SCALE = 0.9`` (reduced from the default
  1.0 "to prevent interpolation overshoot: the output of the interpolation
  filter may exceed the max value of the input points," per the class
  docstring), ``REGISTERS = {'start_addr_reg': 0, 'we_reg': 1}``, and
  ``maxlen = 2**N`` (table is interpolated -- see Section 1).
* ``AxisSgInt4V2(AbsIntSignalGen)`` -- ``bindto = ['user.org:user:
  axis_sg_int4_v2:1.0', 'QICK:QICK:axis_sg_int4_v2:1.0']``,
  ``B_DDS = B_PHASE = 32``.

Normal QICK programs don't touch these registers directly -- they go through
:meth:`.QickProgram.declare_gen` (to set Nyquist zone and, for this
generator, the required ``mixer_freq``) and
:meth:`.QickProgramV2.add_pulse` (style ``"arb"`` or ``"flat_top"``, using
an envelope loaded with :meth:`.QickProgram.add_envelope`).

.. code-block:: python
  :caption: Configuring and playing a pulse on an int4-v2 channel

  from qick import *
  import numpy as np

  soc = QickSoc()
  gen_ch = 0  # must be an axis_sg_int4_v2 channel, e.g. soc['gens'][gen_ch]['type'] == 'axis_sg_int4_v2'

  class MyProgram(QickProgramV2):
      def _initialize(self, cfg):
          # this generator has a mixer (HAS_MIXER=True), so mixer_freq is required
          self.declare_gen(ch=gen_ch, nqz=1, mixer_freq=500.0, ro_ch=0)

          # envelope samples are int16; length is checked against the
          # deployed maxlen = 2**N for this channel
          n = 400
          sigma = n / 8
          env = 32767 * np.exp(-0.5 * ((np.arange(n) - n/2) / sigma)**2)
          self.add_envelope(ch=gen_ch, name="gauss", idata=env.astype(np.int16))

          self.add_pulse(ch=gen_ch, name="pulse1", style="arb",
                          freq=100.0, phase=0, gain=0.5,
                          envelope="gauss", outsel="product")

      def _body(self, cfg):
          self.pulse(ch=gen_ch, name="pulse1", t=0)

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/sg_v6` -- SG-v6, the full-rate/full-BRAM sibling generator this
  page repeatedly compares against.
* :doc:`/tprocv2_trm` -- tProcessor v2 sequencing (``WPORT_WR``/``add_pulse``
  path that ultimately fills this generator's ``S1_AXIS`` via
  ``qick_sg_translator``).
* :doc:`/firmware` -- Firmware overview and channel assignments.
* :doc:`topics/gen_config` -- ``outsel``/``mode``/``stdysel`` semantics
  (shared across all pulsed generators in this doc set).
* :doc:`topics/freq_matching` -- keeping generator and readout frequencies
  in sync (relevant here because of the required ``mixer_freq``).
* `axis_sg_int4_v2 source code <https://github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_sg_int4_v2>`_
