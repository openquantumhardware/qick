========================================================
Signal Generator Mux8 (axis_sg_mux8_v1) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

**axis_sg_mux8_v1** is a fixed-tone, 8-way multiplexed signal generator: it
plays up to 8 simultaneous, independently-configured DDS tones per channel,
as opposed to the single-tone arbitrary generators (:doc:`/sg_v6` and its
siblings) which play one tone at a time but can shape it with an arbitrary
envelope. There is no envelope memory here -- a "pulse" on this generator is
just "play some subset of the 8 pre-programmed tones for N samples". The
module lives in the ``qick`` firmware repository under
``firmware/ip/axis_sg_mux8_v1/`` and is exposed to Python through
``qick.drivers.generator.AxisSgMux8V1``.

A related core, **axis_sg_mixmux8_v1**, adds a DAC-side digital mixer on top
of the same 8-tone architecture; it is documented separately and is not
covered further here.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

``axis_sg_mux8_v1`` (top module ``axis_sg_mux8_v1.v``, core datapath
``sg_mux8.v``) instantiates 8 independent tone slots (``N_OUT = 8``, a
``localparam`` in ``sg_mux8.v`` -- not exposed as a synthesis parameter, so
changing the tone count requires editing the RTL). Each slot has its own
frequency (``PINCx_REG``), phase (``POFFx_REG``) and gain (``GAINx_REG``)
register, all configured once over AXI-Lite. Unlike a pulse on an arbitrary
generator, a "pulse" here does not carry frequency/phase/gain -- those are
static per-tone settings -- it only selects *which* of the 8 tones are
audible (an 8-bit ``mask``) and *for how many samples*, streamed in over
``s_axis`` from the tProcessor.

Each tone slot is built from:

* **phase_ctrl.sv** -- a phase-coherent NCO controller (see
  :ref:`sgmux8-phase-coherence` below).
* ``N_DDS`` parallel instances of the Xilinx DDS Compiler IP
  (``dds_compiler_0``, one phase accumulator/sine table per parallel sample
  lane -- see :ref:`sgmux8-synth-params`).
* A signed 16x16 multiply against that tone's ``GAINx_REG``, applied
  identically to all ``N_DDS`` parallel-lane samples of the tone.

The 8 tones' (gain-scaled) samples are then summed lane-by-lane across all
``N_DDS`` parallel output positions and requantized back to 16 bits (see
:ref:`sgmux8-summer`) to produce the final ``m_axis`` output.

**Compared to the mux4 generators** (``AxisSgMux4V1``/``V2``/``V3``, driver
classes in ``qick.drivers.generator``): those support only 4 simultaneous
tones rather than 8, and (for V1/V2) drive a DAC-side digital mixer
(``HAS_MIXER = True``) that this core does not have
(``AxisSgMux8V1.HAS_MIXER = False`` -- see the Python Interface section).
The mux4 RTL is out of scope for this document.

.. _sgmux8-synth-params:

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - RTL Default
     - Description
   * - ``N_DDS``
     - 2
     - Number of parallel DDS/sample lanes per tone, i.e. how many output
       samples each tone (and the final summed waveform) produces per
       ``aclk`` cycle. ``m_axis_tdata`` is ``N_DDS*16`` bits wide (16 bits
       per sample lane). Real board bitstreams use larger values -- e.g. the
       ZCU216 tProc-v2 reference design (``firmware/projects/qick_tprocv2_216_demo``)
       instantiates this core with ``N_DDS = 16``.

The number of simultaneous tones (``N_OUT = 8``) is a fixed ``localparam``
in ``sg_mux8.v``, not a synthesis parameter -- there is no generic to change
the tone count without editing the RTL.

The per-tone DDS core (``dds_compiler_0``, Xilinx DDS Compiler) is
configured (per its ``.xci``) with 32-bit phase width, 16-bit output width,
``Output_Selection = Sine`` (a single real output per lane, not sin+cos),
and a fixed pipeline latency of 10 cycles.

--------------------------------------------------------------------
3. Datapath
--------------------------------------------------------------------

.. _sgmux8-phase-coherence:

3.1 Per-Tone Frequency/Phase Generation (``phase_ctrl.sv``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each tone's phase is *not* computed by a simple running accumulator that
adds ``PINC`` every cycle. Instead ``phase_ctrl.sv`` keeps a free-running,
never-reset 32-bit sample counter ``cnt_n`` (incremented by ``N_DDS`` every
``aclk`` cycle) and computes each parallel lane's absolute phase directly
from it:

.. code-block:: text

   phase[lane i] = (cnt_n + i) * PINC + POFF   (mod 2^32)

(implemented as ``pinc*cnt_n`` via a dedicated 32x32 pipelined multiplier,
``mult_32x32.v``, plus ``pinc*i`` for the within-cycle lane offset). Because
phase is recomputed from an absolute, ever-incrementing counter rather than
accumulated incrementally, the tone stays phase-coherent across
configuration changes -- there's no accumulator to reset or discontinue.

``PINC_REG``/``POFF_REG`` updates are staged: the AXI-Lite-written values
only take effect when ``WE_REG`` is pulsed 0->1->0 (resynchronized into the
``aclk`` domain by a ``synchronizer_n``). Notably, **``GAIN_REG`` is *not*
gated by ``WE_REG``** -- in ``dds_top.v`` the gain multiplicand is a plain
continuous assignment (``assign gain = GAIN_REG;``), so a gain write takes
effect on its own timing rather than being staged together with the next
``WE_REG`` pulse like frequency/phase are. In normal driver usage (see
Python Interface) this is not observable, since ``PINCx``/``POFFx``/``GAINx``
are all written before the single ``WE_REG`` pulse that follows -- but it is
a real asymmetry in the RTL, worth knowing if you ever write registers by
hand and expect all three to update atomically together.

.. _sgmux8-summer:

3.2 Gain Scaling and 8-Tone Summation (``sg_mux8.v``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Inside ``dds_top.v``, each tone's 16-bit signed DDS sample is multiplied by
that tone's 16-bit signed gain and requantized to 16 bits (bits ``[30:15]``
of the 32-bit product -- a Q15 scale, consistent with the driver's
``MAXV = 2**15-2`` gain convention).

The 8 tones are masked (a disabled tone's contribution is forced to
``16'h0000``, not just zero-gained) and then summed lane-by-lane (across
each of the ``N_DDS`` parallel sample positions) through a pipelined,
3-stage binary adder tree (8 -> 4 -> 2 -> 1), growing to a 19-bit signed
intermediate to avoid overflow when all 8 tones are active simultaneously.
The final 19-bit sum is then requantized back down to 16 bits, with the
right-shift amount chosen by ``qsel`` -- the number of tones currently
enabled in the mask (a popcount of the 8 mask bits):

.. list-table:: Output requantization shift (``sg_mux8.v``)
   :header-rows: 1
   :widths: 20 20 60

   * - Active tones (``qsel``)
     - Shift applied
     - Notes
   * - 1
     - none (bits ``[15:0]``)
     -
   * - 2
     - >> 1 (bits ``[16:1]``)
     -
   * - 3 or 4
     - >> 2 (bits ``[17:2]``)
     - Same shift for 3 and 4 tones -- not an exact per-count division.
   * - 5, 6, 7, 8 (or 0)
     - >> 3 (bits ``[18:3]``)
     - Coarsest bucket; also the ``qsel`` default/fallback case.

This is a coarse, power-of-two headroom scheme (not an exact
divide-by-tone-count normalization) -- e.g. 3 active tones are divided by 4,
not 3, and anywhere from 5 to 8 active tones are all divided by 8.

3.3 Streaming Control -- Mask and Duration (``ctrl.sv``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Frequency/phase/gain are static, slow-path AXI-Lite settings. What the
tProcessor actually streams in per pulse, over ``s_axis`` (40 bits wide,
queued in a 16-entry FIFO), is just:

.. list-table:: S_AXIS descriptor word (40 bits, ``ctrl.sv``)
   :header-rows: 1
   :widths: 20 15 65

   * - Field
     - Bits
     - Description
   * - ``mask``
     - ``[39:32]`` (8 bits)
     - One bit per tone (bit *i* enables tone *i*). Tones not in the mask
       are muted for this burst (see 3.2).
   * - ``nsamp``
     - ``[31:0]`` (32 bits)
     - Number of output samples (cycles) to hold this mask before the FSM
       looks for the next queued descriptor.

``ctrl.sv``'s FSM (``READ_ST -> CNT0_ST -> CNT_ST -> READ_ST``) dequeues one
descriptor, holds the output enabled (``m_axis_tvalid`` asserted, mask
applied) for ``nsamp`` cycles, then immediately starts the next queued
descriptor if the FIFO is non-empty -- so back-to-back mask/length
descriptors play with no gap between them, and the output only drops
(``en``/``m_axis_tvalid`` deasserted) once the FIFO runs dry. Several small
``latency_reg`` shift-register instances (in ``ctrl.sv``, ``dds_top.v`` and
``sg_mux8.v``) exist purely to align the ``mask``/enable control signals
with the multi-stage DDS -> multiply -> summer pipeline; this document does
not attempt to enumerate the combined end-to-end pipeline latency, since
that was not directly measured/simulated in this pass.

In a full tProc-v2 design (verified against
``firmware/projects/qick_tprocv2_216_demo/bd_2023-1.tcl``), the tProcessor
does not drive this 40-bit format directly -- an ``sg_translator`` IP sits
between the tProc's common per-generator wave descriptor and this core's
``s_axis``, repacking it into the ``{mask, nsamp}`` format above.

--------------------------------------------------------------------
4. Register Map
--------------------------------------------------------------------

All registers are accessed through a standard 32-bit-word AXI-Lite slave
(``axi_slv.v``, 8-bit address bus, 64 x 32-bit word register file -- only
the first 25 words are used by this core). Byte offset = word index x 4.

.. list-table::
   :header-rows: 1
   :widths: 22 12 14 52

   * - Register
     - Byte offset
     - Width
     - Description
   * - ``PINC0_REG`` .. ``PINC7_REG``
     - 0x00 .. 0x1C
     - 32 bits
     - Per-tone DDS frequency tuning word (one register per tone, word
       index = tone number).
   * - ``POFF0_REG`` .. ``POFF7_REG``
     - 0x20 .. 0x3C
     - 32 bits
     - Per-tone phase offset.
   * - ``GAIN0_REG`` .. ``GAIN7_REG``
     - 0x40 .. 0x5C
     - 32-bit AXI-Lite slot; **only bits [15:0] reach the datapath**
     - Per-tone signed gain. The AXI-Lite register itself is a full 32-bit
       word (like every other register in this block's ``axi_slv``), but
       the ``GAINx_REG`` ports on ``sg_mux8.v``/``dds_top.v`` are declared
       only 16 bits wide, so the upper 16 bits written over AXI-Lite are
       silently dropped before they reach the multiplier. This was
       confirmed by reading the port declarations in ``sg_mux8.v`` and
       ``dds_top.v`` (16-bit) against ``axi_slv.v`` (32-bit output ports).
   * - ``WE_REG``
     - 0x60
     - 1 bit (bit 0 of a 32-bit word)
     - Write-enable pulse. Toggling 0->1->0 latches the currently-written
       ``PINCx``/``POFFx`` values into the phase-coherent controllers of
       all 8 tones simultaneously (``GAINx`` is not gated by this bit --
       see 3.1).

--------------------------------------------------------------------
5. Python Interface
--------------------------------------------------------------------

The driver is ``qick.drivers.generator.AxisSgMux8V1``
(``bindto = ['user.org:user:axis_sg_mux8_v1:1.0', 'QICK:QICK:axis_sg_mux8_v1:1.0']``),
a thin subclass of ``AbsMuxSignalGen`` with:

.. code-block:: python

   HAS_MIXER = False
   B_DDS = 32
   N_TONES = 8
   HAS_GAIN = True
   HAS_PHASE = True
   B_PHASE = 32

``AbsMuxSignalGen._init_config()`` builds the register-name-to-word-index
map programmatically from these flags -- ``pinc{i}_reg`` at words 0-7,
``poff{i}_reg`` at words 8-15 (since ``HAS_PHASE``), ``gain{i}_reg`` at
words 16-23 (since ``HAS_GAIN``), then ``we_reg`` at word 24 -- which
matches the RTL register map in section 4 exactly (verified by reading both
sides).

**Normal usage** goes through :meth:`.QickProgram.declare_gen` and the
per-pulse ``mask``/``length`` parameters, not direct register access:

.. code-block:: python
  :caption: Configuring and playing tones on a mux8 generator

  from qick import *

  soc = QickSoc()
  # ch = the index of the axis_sg_mux8_v1 channel in soc['gens']

  class MyProgram(QickProgram):
      def initialize(self):
          # Declare up to 8 tones; unlisted mask indices play silence.
          self.declare_gen(ch=ch, nqz=2,
                            mux_freqs=[100.0, 150.0, 220.5],   # MHz
                            mux_gains=[1.0, 0.8, 0.5],          # -1..1
                            mux_phases=[0, 0, 90])              # degrees

      def body(self):
          # Play tones 0 and 2 together for 1000 samples.
          self.pulse(ch=ch, style='const', mask=[0, 2], length=1000)

``declare_gen`` calls :meth:`.QickProgram.calc_muxgen_regs` to convert the
float MHz/gain/degrees values into raw ``freq_int``/``gain_int``/
``phase_int`` register values (via :meth:`.QickProgram.freq2reg` /
:meth:`.QickProgram.deg2reg`, using ``B_DDS = 32``/``B_PHASE = 32``, and
``gain_int = round(gain * MAXV)`` with ``MAXV = 2**15-2``), which
``config_gens()`` then pushes into the generator via
``AxisSgMux8V1.set_tones_int()`` (which loops over the tones, writes
``pincX_REG``/``gainX_REG``/``poffX_REG`` for each configured tone and
zeroes the gain of any unconfigured tone up to ``N_TONES``, then pulses
``we_reg``). The pulse's ``mask``/``length`` parameters are packed by
``MultiplexedGenManager`` (``qick.asm_v1``/``qick.asm_v2``) into the
40-bit ``{mask, nsamp}`` descriptor described in section 3.3.

.. note::

   ``AbsMuxSignalGen.set_tones()`` (a debug-only convenience method, not
   normally called by user code) calls ``self.set_all_int(tones)`` --
   but ``set_all_int`` is not defined anywhere on ``AbsMuxSignalGen`` or
   its base classes (only ``set_tones_int`` is). This looks like a
   leftover/typo in the current driver source (``qick_lib/qick/drivers/generator.py``)
   and would raise an ``AttributeError`` if called; use
   ``set_tones_int()`` directly, or the normal ``declare_gen()`` path
   above, instead.

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/sg_v6` -- the single-tone arbitrary-envelope generator, for
  contrast with this fixed-tone mux design.
* :doc:`/tprocv2_trm` -- tProcessor v2 instruction reference, including the
  wave-descriptor mechanism translated by ``sg_translator`` into this core's
  mask/length format.
* :doc:`/firmware` -- firmware overview and channel assignments.
* `axis_sg_mux8_v1 source code <https://github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_sg_mux8_v1>`_
