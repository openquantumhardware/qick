========================================================
Signal Generator v4 (SG-v4) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

**axis_signal_gen_v4** is QICK's original tProc-controlled arbitrary-waveform
generator: a single real-valued output lane fed by ``N_DDS`` parallel
DDS-plus-mixer channels, each pairing one complex multiplier with its own
envelope BRAM. It is the direct predecessor of :doc:`/sg_v6`, and the two
share the same Python driver class (``qick.drivers.generator.AxisSignalGen``)
-- its docstring states plainly that the class "Supports AxisSignalGen
V4+V5+V6, since they have the same software interface (ignoring registers
that are not used)". The module lives in the ``qick`` firmware repository
under ``firmware/ip/axis_signal_gen_v4/``.

Unlike SG-v6, SG-v4 does not appear in any currently-shipped board project
in this repository (no ``firmware/Projects/**`` block-design script
instantiates ``axis_signal_gen_v4``); it is documented here as the legacy
core the Python driver still supports, and to make the concrete differences
from SG-v6 explicit for anyone reading old designs or the driver's
backward-compatibility code paths.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

The core is built from four RTL blocks (``axis_signal_gen_v4.v`` instantiates
the first two; ``signal_gen_top.v`` instantiates the rest):

* ``axi_slv`` (``axi_slv.vhd``) -- the AXI4-Lite configuration register file.
* ``signal_gen_top`` (``signal_gen_top.v``) -- wires up the waveform FIFO,
  the envelope-loading state machine, the per-lane BRAMs, and the
  ``signal_gen`` core.
* ``data_writer`` (``data_writer.vhd``) -- an FSM that streams envelope
  samples from ``s0_axis`` into the interleaved per-lane BRAMs.
* ``signal_gen`` (``signal_gen.v``, with ``ctrl.sv`` as its descriptor-decode
  FSM) -- reads queued waveform descriptors, drives ``N_DDS`` parallel
  ``dds_compiler_0`` instances, multiplies each against its envelope sample,
  and muxes/rounds the result onto ``m_axis``.

``AxisSignalGen.HAS_MIXER = False`` in the Python driver: there is no
DAC-side digital mixer downstream of this block (unlike the interpolated
``axis_sg_int4_v*`` generators) -- all upconversion is done by the per-lane
DDS itself, which is why :meth:`.QickProgram.declare_gen` never asks for a
``mixer_freq`` on this channel.

Two source files in ``firmware/ip/axis_signal_gen_v4/src/`` -- ``dither.v``
and ``random_gen.v`` -- are **not part of the active datapath**; see
:ref:`sgv4-dithering` below.

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
     - 12
     - Envelope memory address width. Each of the ``N_DDS`` lanes owns a
       real-part BRAM and an imaginary-part BRAM, each ``2**N`` samples
       deep x 16 bits wide. With the default, that's 4096 samples/lane,
       65536 samples total across the interleaved lanes -- this is what the
       Python driver reports as ``cfg['maxlen']`` (``2**N * N_DDS``, in
       ``AxisSignalGen._init_config``). SG-v6's top-level default for the
       same parameter is ``N = 16`` (see :doc:`/sg_v6`); the value actually
       burned into a given bitstream depends on how the block design
       instantiated the core, so read ``soc.gens[i]['maxlen']`` at runtime
       rather than assuming either default.
   * - ``N_DDS``
     - 16
     - Number of parallel DDS + complex-multiplier lanes, and therefore
       samples emitted per ``aclk`` cycle on ``m_axis_tdata`` (bus width
       ``N_DDS * 16`` bits). Exposed to Python as ``SAMPS_PER_CLK = 16`` on
       the driver class.

SG-v4 has no ``GEN_DDS`` or ``ENVELOPE_TYPE`` synthesis parameters --
``axis_signal_gen_v4.v`` declares only ``N`` and ``N_DDS``. Both DDS lanes
and imaginary-part BRAMs are therefore always present; there is no
baseband-only or real-only-envelope build option (both were added in
SG-v6 -- see :ref:`sgv4-vs-sgv6`). Correspondingly,
``AbsPulsedSignalGen._init_config`` falls back to the class default
``HAS_DDS = True`` and ``AbsArbSignalGen._init_config`` falls back to
``COMPLEX_ENVELOPE = True`` for this core, since neither ``GEN_DDS`` nor
``ENVELOPE_TYPE`` is present in its parameter dict.

--------------------------------------------------------------------
3. Datapath
--------------------------------------------------------------------

3.1 Waveform descriptor queue (``s1_axis``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``s1_axis_tdata`` is a 160-bit waveform descriptor, pushed straight into a
16-entry, 160-bit-wide FIFO (``fifo.vhd``, ``.B(160)``, ``.N(16)``) with
``fifo_wr_en = s1_axis_tvalid`` and ``s1_axis_tready = ~fifo_full`` -- there
is no register staging on the write side, unlike ``axis_readout_v2``'s
``WE_REG``-pulsed descriptor push (:doc:`/readout_v2`). ``ctrl.sv`` decodes
the descriptor at the head of the FIFO:

.. list-table:: Waveform descriptor fields (``ctrl.sv`` header comment)
   :header-rows: 1
   :widths: 15 15 15 55

   * - Field
     - Bits
     - Width
     - Description
   * - ``freq``
     - ``[31:0]``
     - 32
     - DDS frequency tuning word for this pulse.
   * - ``phase``
     - ``[63:32]``
     - 32
     - DDS phase offset for this pulse.
   * - ``addr``
     - ``[79:64]``
     - 16
     - Envelope-memory start address to read for this pulse (**not** the
       same register as ``START_ADDR_REG`` below -- that one is only used
       when bulk-loading samples over ``s0_axis``).
   * - ``gain``
     - ``[111:96]``
     - 16
     - Signed output gain.
   * - ``nsamp``
     - ``[143:128]``
     - 16
     - Number of ``aclk`` cycles (each emitting ``N_DDS`` samples) to stay
       in the active ``CNT_ST`` state before returning to ``READ_ST``.
   * - ``outsel``
     - ``[145:144]``
     - 2
     - Per-pulse output-source select: 0 = product (DDS x envelope), 1 =
       DDS only, 2 = envelope only, 3 = zero. **Not the same control as the
       ``OUTSEL_REG`` AXI register** described in :ref:`sgv4-regmap` --
       despite the similar name, that register picks the real/imaginary
       component of whatever this field selects, chip-wide, not per pulse.
   * - ``mode``
     - ``146``
     - 1
     - 0: play for ``nsamp`` cycles and stop. 1: play continuously
       (periodic).
   * - ``stdysel``
     - ``147``
     - 1
     - Steady-value select; see :ref:`sgv4-steady` below.
   * - ``phrst``
     - ``148``
     - 1
     - Documented in the header comment table but **not read anywhere in
       ``ctrl.sv``'s body** -- ``fifo_dout_r[148]`` is never referenced.
       Setting this bit has no effect in SG-v4. SG-v6's ``ctrl_sg_v6.sv``
       *does* wire the equivalent bit (``phrst_int = fifo_dout_r[148]``)
       into a synchronous phase-accumulator reset -- see
       :ref:`sgv4-vs-sgv6`.

The FSM (``READ_ST`` / ``CNT_ST``) reads a new descriptor whenever it's idle
and the FIFO isn't empty (or ``mode`` is periodic), then holds in
``CNT_ST`` for ``nsamp`` cycles. ``gain``, the 2-bit ``src`` (outsel),
``stdysel``, and the enable flag are each pushed through long shift-register
pipelines (4 stages inside ``ctrl.sv``, then a further 13-19 stages inside
``signal_gen.v``) to stay aligned with the DDS and multiplier latency before
they reach the output mux.

3.2 Envelope loading (``s0_axis``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``data_writer`` (``data_writer.vhd``) is a small FSM
(``INIT -> READ_START_ADDR -> WAIT_TVALID -> RW_TDATA``) that writes
32-bit samples arriving on ``s0_axis_tdata`` (bits ``[15:0]`` = real,
``[31:16]`` = imaginary) into the per-lane BRAM pair. It keeps one flat
running address (``mem_addr_full``); the low ``ceil(log2(N_DDS))`` = 4 bits
select which of the ``N_DDS`` lanes' ``mem_ena`` to assert, and the
remaining ``N`` bits become that lane's BRAM address -- i.e. samples are
written round-robin across the 16 lanes. ``WE_REG`` is resynchronized into
the ``s0_axis_aclk`` domain with a 2-stage ``synchronizer_n`` before it can
move the FSM out of ``INIT``, and the counter is reloaded from
``START_ADDR_REG`` each time a new write burst starts.

Each lane's real and imaginary BRAMs are separate ``bram_dp`` instances
(the shared dual-port BRAM primitive under ``firmware/hdl/``, not the
single-port ``bram.v`` file that ships in this IP's own ``src/`` -- that
file is unused, see :ref:`sgv4-dithering`). Write port A runs on
``s0_axis_aclk``; read port B runs on ``aclk`` and is driven by
``signal_gen``.

3.3 Per-lane DDS and complex multiply
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each of the ``N_DDS`` lanes instantiates its own ``dds_compiler_0`` core,
phase-offset from its neighbors by ``pinc * i`` (lane ``i`` represents time
step ``i`` within the current ``N_DDS``-wide parallel block, so the 16
lanes together form one coherent, phase-continuous tone). ``signal_gen.v``
then computes the **full complex product** of the DDS output (I, Q) against
the envelope sample (I, Q) read back from BRAM:

.. code-block:: text

   prod_real = dds_I * env_I - dds_Q * env_Q
   prod_imag = dds_I * env_Q + dds_Q * env_I

That's four 16x16 multiplies per lane, even though (per
:ref:`sgv4-outsel-note` below) only one of ``prod_real``/``prod_imag`` is
ever driven onto the output. SG-v6 removed the two multiplies needed for
``prod_imag`` entirely, since it never produces a usable imaginary output
(see :ref:`sgv4-vs-sgv6`).

.. _sgv4-outsel-note:

3.4 Output source mux, real/imag select, and rounding
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``dout_mux[i]`` picks one 32-bit ``{imag, real}`` word per the per-pulse
``outsel`` descriptor field (product / DDS-only / envelope-only / zero,
see 3.1), and that word is scaled by ``gain`` (one more signed 16x16
multiply) and rounded (bits ``[30:15]`` of the 32-bit gained product, i.e.
truncation after the gain multiply, no separate rounding-add term). The
final 16-bit sample driven onto ``m_axis_tdata[i*16 +: 16]`` picks between
the rounded real and imaginary halves using **``OUTSEL_REG``**, a
chip-wide AXI-Lite register (0 = real, 1 = imaginary) -- *not* the
per-pulse ``outsel`` descriptor field. Because ``m_axis_tdata`` only
carries one 16-bit sample per lane per cycle (not a 32-bit I/Q pair), a
single generator instance can only ever emit the real *or* the imaginary
component of its internal complex datapath, chosen once for the whole
core via this register, not per pulse.

.. _sgv4-steady:

3.5 Enable / steady-value gating
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``m_axis_tdata[i] = (~en & stdysel) ? 0 : round_r_mux[i]``. When the
generator is disabled (between pulses, or after a one-shot ``mode=0``
pulse finishes) and ``stdysel`` is set, the output is forced to zero;
otherwise the (possibly stale, still-pipelined) ``round_r_mux`` value
passes through unchanged. SG-v4 has no dedicated "hold the last sample"
state -- see :ref:`sgv4-vs-sgv6` for how SG-v6 differs here.

.. _sgv4-dithering:

3.6 Dithering RTL is present but disconnected
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``firmware/ip/axis_signal_gen_v4/src/`` contains ``dither.v`` (adds
LFSR-generated pseudo-random noise, scaled by a register-controlled shift
amount, ahead of a bit-truncation -- a standard dithering-before-requantize
technique) and ``random_gen.v`` (a parameterizable-width Fibonacci-tap
LFSR). Neither module is instantiated anywhere in
``signal_gen_top.v``/``signal_gen.v``; the only place ``dither`` is
referenced is inside its own file, instantiating ``random_gen``. The
``RNDQ_REG`` register (see :ref:`sgv4-regmap`) is wired all the way from
``axi_slv`` down through ``signal_gen_top`` into ``signal_gen.v``'s port
list, but ``signal_gen.v``'s body never reads it. This is corroborated on
the Python side: ``AxisSignalGen.rndq()`` is annotated
``"TODO: remove this function. This functionality was removed from IP
block."``, and the register is set once to a placeholder value (``10``) in
``_init_firmware`` and never touched again. Treat SG-v4's dithering support
as vestigial source code, not a working feature. (A separate,
independently-maintained register-description package in this repo,
``firmware/fusesoc/cores/ip/axis_signal_gen_v4/rdl/``, describes
``RNDQ_REG`` the same way: "Deprecated (rounding-select removed). Retained
as a dummy for register-map / driver bindto compatibility (no functional
effect)" -- consistent with what the RTL shows, though that package
describes a different, non-synthesized register model and should not be
read as documenting this IP's actual register file.)

.. _sgv4-regmap:

--------------------------------------------------------------------
4. Register Map
--------------------------------------------------------------------

``axi_slv.vhd`` implements a generic 16-register, 6-bit-address AXI4-Lite
block (word-addressed offsets ``0x00``-``0x3C``), but only wires the first
four registers to anything; the remaining twelve are plain, unconnected
flip-flops (writable and readable, but with no effect on the datapath).

.. list-table::
   :header-rows: 1
   :widths: 22 12 15 51

   * - Register
     - Offset
     - Width
     - Description
   * - ``START_ADDR_REG``
     - ``0x00``
     - 32 bits
     - Flat start address (lane-interleaved) for the next bulk envelope
       write over ``s0_axis``. Loaded into ``data_writer``'s address
       counter when ``WE_REG`` rises.
   * - ``WE_REG``
     - ``0x04``
     - 1 bit (``slv_reg1[0]``)
     - Envelope-memory write enable. Level-sensitive, resynchronized into
       the ``s0_axis_aclk`` domain.
   * - ``RNDQ_REG``
     - ``0x08``
     - 32 bits
     - Comment in ``axi_slv.vhd``: "Noise amplitude for dithering." Not
       actually connected to any dithering logic -- see
       :ref:`sgv4-dithering`.
   * - ``OUTSEL_REG``
     - ``0x0C``
     - 1 bit (``slv_reg3[0]``)
     - Chip-wide real/imaginary output select (0 = real, 1 = imaginary);
       see :ref:`sgv4-outsel-note`. **Not present in the Python driver's
       ``REGISTERS`` dict** (``AxisSignalGen.REGISTERS = {'start_addr_reg':
       0, 'we_reg': 1, 'rndq_reg': 2}``), so it can't be written from
       Python -- it stays at its post-reset value, which is ``0`` (real
       component) since all ``slv_reg`` are cleared to zero on
       ``aresetn``.

All registers are simple ``std_logic_vector`` flops written a full 32 bits
at a time (byte-strobed) on the ``s_axi_aclk`` domain; there is no
write-pulse/handshake semantics beyond the level of ``WE_REG`` itself.

.. _sgv4-vs-sgv6:

--------------------------------------------------------------------
5. Differences from SG-v6
--------------------------------------------------------------------

The two cores share a Python driver and a wire-compatible 160-bit
descriptor format, but the RTL differs in several concrete ways:

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Aspect
     - SG-v4
     - SG-v6
   * - Complex product
     - Computes both real and imaginary parts of DDS x envelope (4
       multiplies/lane); only one is ever output.
     - Computes only the real part (2 multiplies/lane); the imaginary
       partial products are commented out of ``signal_gen.v`` entirely.
   * - Real/imag output select
     - Chip-wide ``OUTSEL_REG`` AXI register (not exposed by the Python
       driver).
     - Removed -- ``axi_slv_sg_v6.vhd`` only implements
       ``START_ADDR_REG``/``WE_REG``.
   * - Baseband-only mode
     - Not available -- DDS lanes are always instantiated.
     - ``GEN_DDS = "FALSE"`` synthesis parameter removes the DDS
       compilers, for baseband-envelope-only builds.
   * - Real-only envelope
     - Not available -- both real and imaginary BRAMs are always
       instantiated per lane.
     - ``ENVELOPE_TYPE = "REAL"`` synthesis parameter drops the imaginary
       BRAM and forces ``mem_dob_imag`` to zero.
   * - ``phrst`` descriptor bit
     - Defined in the descriptor format comment (bit 148) but never read
       in ``ctrl.sv``. No effect.
     - Read (``phrst_int = fifo_dout_r[148]``) and used to reset the phase
       accumulator synchronously with a new descriptor load.
   * - Dithering
     - ``dither.v``/``random_gen.v`` present in ``src/`` but not
       instantiated; ``RNDQ_REG`` exists but is unconnected. Vestigial.
     - Files and register removed entirely.
   * - Idle/steady output
     - Forces output to zero when disabled and ``stdysel`` is set;
       otherwise the last pipelined value passes through as-is (no
       explicit hold).
     - Adds an explicit ``last_r`` register that latches the final sample
       whenever enabled, so the idle output can hold that value
       (``stdysel=0``) or force zero (``stdysel=1``).
   * - Register pipelining style
     - Manually chained ``reg`` stages (``_r1``, ``_r2``, ... up to
       ``_r19`` in places).
     - A reusable parameterized ``latency_reg`` module for each delay
       line.
   * - Top-level ``N`` default
     - 12 (4096 samples/lane).
     - 16 (65536 samples/lane).

From a QICK-program-writer's point of view these are resource/feature
differences, not API differences: both bind to the same
``qick.drivers.generator.AxisSignalGen`` class
(``bindto = ['user.org:user:axis_signal_gen_v4:1.0', ...
'axis_signal_gen_v6:1.0', ...]``), so :meth:`.QickProgram.declare_gen`,
:meth:`.QickProgram.add_envelope`, and pulse-playback instructions work
identically on either version -- you simply lose the ability to select the
imaginary output, use per-pulse phase reset, or run in baseband/real-only
modes on SG-v4.

--------------------------------------------------------------------
6. Python Interface
--------------------------------------------------------------------

SG-v4 is reached through the same class hierarchy as every other QICK
pulsed generator (``qick.drivers.generator``):

* ``AbsSignalGen`` -- ``MAXV = 2**15-2``; Nyquist-zone and (if
  ``HAS_MIXER``) mixer-frequency helpers.
* ``AbsArbSignalGen(AbsSignalGen)`` -- adds the envelope DMA path
  (``load()``, over ``s0_axis``) and ``_wr_enable``/``_wr_disable``
  (``START_ADDR_REG``/``WE_REG``).
* ``AbsPulsedSignalGen(AbsSignalGen)`` -- adds the tProc-facing ``s1_axis``
  port and DDS/phase width config (``B_DDS``, ``B_PHASE``, ``HAS_DDS``).
* ``AxisSignalGen(AbsArbSignalGen, AbsPulsedSignalGen)`` -- the concrete
  class, with ``bindto`` covering the v4/v5/v6 IP-core VLNV strings,
  ``HAS_MIXER = False``, ``SAMPS_PER_CLK = 16``, ``B_DDS = B_PHASE = 32``.

Because ``ENVELOPE_TYPE``/``GEN_DDS`` aren't present in SG-v4's synthesis
parameters, ``cfg['complex_env']`` and ``cfg['has_dds']`` fall back to the
class defaults (``True``/``True``) for this core.

Most QICK programs never touch this driver directly -- pulses are declared
through :meth:`.QickProgram.declare_gen` and
:meth:`.QickProgram.add_envelope`/:meth:`.QickProgram.add_gauss`, and
played via the normal tProc pulse instructions, exactly as for SG-v6. The
one thing worth calling out for SG-v4 specifically is that ``OUTSEL_REG``
is not reachable from Python (see :ref:`sgv4-regmap`): if you need the
imaginary component of the DDS x envelope product out of an SG-v4
channel, there is no driver method for it -- you would have to write the
register through the low-level MMIO interface yourself.

.. code-block:: python
  :caption: Loading an envelope and playing an SG-v4 pulse

  from qick import *
  import numpy as np

  soc = QickSoc()
  gen_ch = 0   # an SG-v4 channel on this board

  soc.declare_gen(ch=gen_ch, nqz=1)   # no mixer_freq: HAS_MIXER is False

  # Gaussian envelope, real part only (imaginary defaults to zero if omitted)
  length = 100
  sigma = length / 5
  idata = 30000 * np.exp(-0.5 * ((np.arange(length) - length/2) / sigma)**2)
  soc.add_envelope(ch=gen_ch, name="gauss", idata=idata.astype(np.int16))

  soc.set_pulse_registers(ch=gen_ch, style="arb", envelope="gauss",
                           freq=soc.freq2reg(100.0, gen_ch=gen_ch),
                           phase=0, gain=30000, length=length)

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/sg_v6` -- the successor core; see :ref:`sgv4-vs-sgv6` above for
  the concrete RTL differences.
* :doc:`/tprocv2_trm` -- tProcessor sequencing/triggering that queues
  waveform descriptors into this core's ``s1_axis``.
* :doc:`/firmware` -- firmware overview and channel assignments.
* :doc:`/readout_v2` -- a similarly-legacy, single-tone predecessor core on
  the readout (ADC) side, for comparison.
