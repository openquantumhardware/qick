========================================================================
Dynamic Readouts (axis_readout_v3 / axis_dyn_readout_v1) - QICK Firmware
========================================================================

.. contents::
  :local:
  :depth: 2

**axis_readout_v3** and **axis_dyn_readout_v1** are the *dynamic* counterparts
of :doc:`/readout_v2`: digital down-converter (DDC) IP blocks that sit
between the RFDC's ADC output and :doc:`/avg_buffer`, but whose
frequency/phase/output-selection/length are set **by the tProcessor, in real
time, once per shot**, instead of being written ahead of time as PYNQ
registers from software. Both modules live under ``firmware/ip/`` (in
``axis_readout_v3/`` and ``axis_dyn_readout_v1/`` respectively) and are
exposed to Python through ``qick.drivers.readout.AxisReadoutV3`` and
``AxisDynReadoutV1``.

They are covered together on one page because they share the same control
architecture (a nearly-identical FSM, ``ctrl.sv``/``ctrl_dyn_ro_v1.sv``, and
the same tProc-driven configuration mechanism) and the same Python-driver
pattern (``AbsDynReadout``); the numeric parameters of their datapaths
(samples/clock, decimation ratio, rounding) differ, and those differences are
called out explicitly below.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

Both blocks perform the same three-stage job as ``axis_readout_v2``
(down-convert with an on-chip DDS, FIR low-pass filter, decimate), but they
have **no AXI-Lite control interface at all** -- neither module's top-level
port list (``axis_readout_v3.v``, ``axis_dyn_readout_v1.v``) includes an
``S_AXI``/register bus. Instead, each block exposes an extra AXI-Stream slave
port, ``s0_axis``, driven directly by a tProcessor output port. The
tProcessor pushes one 88-bit configuration word per ``s0_axis`` transaction;
the block's control FSM decodes that word into DDS frequency/phase and
readout-length/output-select settings and applies them immediately. This is
the hardware side of what :meth:`.QickProgram.declare_readout` calls a
readout "controlled by tProc" (see :ref:`readout-dyn-python` below) --
config­uration happens per-shot, at run time, as part of the tProc program
itself, rather than once via a PYNQ register write before the program starts.

* **axis_readout_v3** -- the dynamic counterpart of ``axis_readout_v2``'s
  datapath: 4 real ADC samples/clock in, FIR decimation by 4, 1 complex
  sample/clock out (``m_axis``, the only output).
* **axis_dyn_readout_v1** -- a newer, wider block: 8 real ADC samples/clock
  in (``N_DDS=8``), FIR decimation by 8. Unlike v3, it exposes **two**
  outputs: ``m0_axis``, the down-converted-but-not-yet-decimated stream (8
  complex samples/clock, still subject to the output-selection mux), and
  ``m1_axis``, the final decimated stream (1 complex sample/clock) that feeds
  :doc:`/avg_buffer`.

Both are single-tone readouts (one DDS-driven downconversion frequency at a
time per channel) -- like ``axis_readout_v2`` and unlike the PFB-based
readouts, they do not channelize multiple simultaneous tones.

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table:: axis_readout_v3 vs. axis_dyn_readout_v1 -- key parameters
   :header-rows: 1
   :widths: 30 20 20 30

   * - Parameter
     - axis_readout_v3
     - axis_dyn_readout_v1
     - Notes
   * - Input samples/clock (``N``/``N_DDS``)
     - 4
     - 8
     - Parallel real ADC lanes into the down-conversion multiplier; also the
       number of DDS instances (``dds_0``/``dds_compiler_0``).
   * - FIR decimation ratio
     - 4
     - 8
     - Xilinx FIR Compiler 7.2, ``Filter_Type=Decimation``. Exposed to Python
       as ``DOWNSAMPLING`` on the driver class (``4`` / ``8``).
   * - FIR coefficients
     - 107 taps (``fir_0/fir.coe``)
     - 120 taps (``fir.coe``)
     - Symmetric low-pass, fixed/compiled into the bitstream (not
       runtime-loadable).
   * - FIR coefficient/data width
     - 16 bits
     - 16 bits
     - ``Coefficient_Width``/``Data_Width`` on both FIR IPs.
   * - FIR output width (per I/Q component)
     - 18 bits
     - 16 bits
     - See :ref:`readout-dyn-rounding` for how each top level turns this into
       the final 16-bit I/Q.
   * - DDS phase/output width
     - 32-bit phase, 16-bit output
     - 32-bit phase, 16-bit output
     - Same on both (``dds_0``/``dds_compiler_0``, ``Phase_Width=32``,
       ``Output_Width=16``).
   * - DDS latency
     - 10 cycles
     - 8 cycles
     - IP-configured pipeline latency of the DDS compiler core.
   * - Config-descriptor FIFO depth
     - 8 entries
     - 8 entries
     - ``fifo #(.B(88), .N(8))`` in both top levels -- up to 8 pending
       ``s0_axis`` configuration words can be queued.
   * - Config descriptor width
     - 88 bits
     - 88 bits
     - See :ref:`readout-dyn-descriptor`.

--------------------------------------------------------------------
3. Datapath
--------------------------------------------------------------------

3.1 axis_readout_v3
^^^^^^^^^^^^^^^^^^^^

``axis_readout_v3.v`` instantiates a single 88-bit-wide, 8-deep FIFO (fed by
``s0_axis``) and one ``down_conversion_fir`` block:

1. **down_conversion** (``down_conversion.sv``) -- reads one descriptor at a
   time out of the FIFO via an internal ``ctrl`` FSM (see
   :ref:`readout-dyn-fsm`), drives 4 parallel ``dds_0`` DDS cores from it,
   and complex-multiplies each of the 4 real ADC samples/clock
   (``s1_axis_tdata``) against its DDS output. Latency-matched shift
   registers (``latency_reg``) keep the raw-input and DDS-only paths aligned
   in time with the product path so all three can be muxed together.
2. **down_conversion_fir** (``down_conversion_fir.sv``) -- feeds the 4
   parallel 32-bit (16+16 I/Q) product-domain samples/clock into ``fir_0``
   (decimation by 4), producing one complex sample/clock on ``m_axis``.

``down_conversion_fir.sv`` documents the block's overall latency in comments:
16 cycles through ``down_conversion``, 114 more through the FIR.

3.2 axis_dyn_readout_v1
^^^^^^^^^^^^^^^^^^^^^^^^

``axis_dyn_readout_v1.v`` wraps a ``readout_top`` module, which instantiates
the same FIFO (88 bits x 8 deep) and a ``down_conversion_fir`` block built
from 8-lane versions of the same pieces:

1. **down_conversion** (``down_conversion.v``) -- same structure as v3's
   (shared ``ctrl_dyn_ro_v1`` FSM, per-lane DDS + complex multiply), but with
   ``N_DDS=8`` lanes and no latency-matching shift registers on the
   DDS/input mux paths (the mux paths are only delay-matched by fixed
   pipeline register counts, not by a parametrized ``latency_reg`` block as
   in v3). This stage's output is exposed directly as ``m0_axis`` (8 complex
   samples/clock, pre-filter/pre-decimation, still passed through the
   output-selection mux).
2. **fir_compiler_0**, wrapped by ``down_conversion_fir.v`` -- an 8x
   decimation, multi-rate FIR core (``Number_Paths=2``, one path per I/Q
   component) that consumes ``m0_axis`` directly and produces the final
   1-complex-sample/clock stream on ``m1_axis``.

.. _readout-dyn-fsm:

3.3 Shared control FSM (``ctrl.sv`` / ``ctrl_dyn_ro_v1.sv``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Both blocks' control logic is built from what is essentially the same
two-state FSM (``READ_ST``/``CNT_ST``, one-hot encoded):

* In ``READ_ST``, the FSM asserts ``fifo_rd_en`` and, once a descriptor is
  available (``~fifo_empty``) or the previously-loaded descriptor's
  ``mode`` bit is 1 ("periodic"), latches it and moves to ``CNT_ST``.
* In ``CNT_ST`` it holds that descriptor's frequency/phase/output-select
  settings for ``nsamp-2`` clock cycles (counted by a free-running counter,
  ``cnt``), then returns to ``READ_ST`` to look for (or wait for) the next
  descriptor.

From the latched ``freq``/``phase`` fields the FSM computes, per DDS lane
``i``, a phase-coherent phase word ``phase_v1[i] = i*pinc + running_phase``,
where the running phase accumulates ``pinc*N`` per clock (``N`` = 4 or 8, the
number of lanes) and resets to the descriptor's ``phase`` field whenever
``sync`` (a new descriptor being loaded) coincides with the descriptor's
``phrst`` bit being set. This is what makes the DDS phase-coherent across
consecutive tProc-issued descriptors except where the program explicitly
requests a phase reset.

**One difference between the two FSMs**: ``ctrl.sv`` (axis_readout_v3) also
computes an output-enable signal ``en`` (asserted once a descriptor has been
loaded and the FIFO isn't empty, deasserted in periodic mode's gaps). However,
tracing it through ``down_conversion.sv`` shows this signal is latency-matched
(``en_latency_reg_i``) but **never wired to anything that gates the
datapath** -- ``down_conversion.sv`` computes its outputs unconditionally
(the source comment there reads *"Always on output (not using en like in
signal_gen_v6)"*), and ``m_axis_tvalid`` is hardwired to 1. So in the current
axis_readout_v3 RTL, ``en`` is a vestigial signal with no observable effect.
Consistent with that, ``ctrl_dyn_ro_v1.sv`` (used by axis_dyn_readout_v1) has
the entire ``en``/output-enable logic commented out and does not produce an
``en`` port at all -- one confirmed, RTL-verified difference between the two
control modules, not just a naming variant.

.. _readout-dyn-descriptor:

3.4 Configuration descriptor (the ``s0_axis`` word)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Both ``ctrl.sv`` and ``ctrl_dyn_ro_v1.sv`` carry an identical header comment
describing the 88-bit ``s0_axis_tdata``/FIFO word layout:

.. list-table:: Configuration descriptor (``s0_axis_tdata``, 88 bits)
   :header-rows: 1
   :widths: 20 15 65

   * - Field
     - Bits
     - Description
   * - (reserved)
     - ``[87:84]``
     - Unused ("xxxx" in the source comment).
   * - ``phrst``
     - ``[83]``
     - 1: reset the phase-coherent DDS accumulator when this descriptor is
       loaded. 0: keep accumulating phase from the previous descriptor.
   * - ``mode``
     - ``[82]``
     - 0: hold this descriptor's settings for ``nsamp`` cycles, then load the
       next one. 1: periodic -- keep re-loading (repeating) this descriptor
       without waiting for a new one to arrive on ``s0_axis``.
   * - ``outsel``
     - ``[81:80]``
     - Output source select (see :ref:`readout-dyn-outsel`).
   * - ``nsamp``
     - ``[79:64]``
     - Number of clock cycles (not decimated output samples) this
       descriptor's settings are held for, in one-shot mode.
   * - ``phase``
     - ``[63:32]``
     - DDS phase offset.
   * - ``freq``
     - ``[31:0]``
     - DDS tuning word (downconversion frequency).

This is the same freq/phase/nsamp/outsel/mode field set as
``axis_readout_v2``'s register-composed descriptor (see
:doc:`/readout_v2`'s 83-bit FIFO word), plus one extra field, ``phrst``, that
``axis_readout_v2`` does not have -- and it arrives as a single AXI-Stream
push from the tProcessor rather than being assembled from five separate
PYNQ registers and committed with a ``WE_REG`` pulse.

.. _readout-dyn-outsel:

3.5 Output source selection
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Both blocks' output multiplexers (``dout_mux`` in ``down_conversion.sv`` /
``down_conversion.v``) use the same encoding for the 2-bit ``outsel`` field:

.. list-table::
   :header-rows: 1
   :widths: 15 25 60

   * - ``outsel``
     - Value
     - Description
   * - 0
     - product
     - The demodulated signal: ADC input x DDS (the normal downconverted
       output).
   * - 1
     - dds
     - The raw local-oscillator (DDS) tone, delay-matched -- for calibration
       or debugging.
   * - 2
     - input
     - Bypass: the raw real ADC sample (delay-matched), with the imaginary
       part forced to zero.
   * - 3
     - zero
     - Always outputs zero.

This matches the ``outsel`` encoding used by :meth:`.QickProgram.cfg2reg` for
tProc-v2 pulses/readout configs (``"product"``/``"dds"``/``"input"``/``"zero"``
-> 0/1/2/3) -- the same field format is shared between signal generators and
these dynamic readouts.

.. _readout-dyn-rounding:

3.6 Rounding and the I/Q DC offset
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The two blocks round their internal fixed-point products differently, and
this shows up directly in the Python driver's ``IQ_OFFSET`` constant
(``AbsReadout.IQ_OFFSET``, used by :meth:`.AcquireMixin` for offset
correction):

* **axis_readout_v3** (``down_conversion.sv``): the complex-multiply result
  is truncated with a plain bit-slice
  (``prod_y_real_round[i] = prod_y_real[i][30 -: 16]``, no rounding
  correction added), and the FIR's own output rounding mode is
  ``Symmetric_Rounding_to_Zero`` (18-bit output). The top level
  (``down_conversion_fir.sv``) then takes bits ``[16:1]`` of each 18-bit
  FIR output component to form the final 16-bit I/Q. This truncation-based
  chain is why the Python driver sets ``IQ_OFFSET = -0.5`` for
  ``AxisReadoutV3``.
* **axis_dyn_readout_v1** (``down_conversion.v``): the complex-multiply
  explicitly adds a rounding constant before truncating
  (``py_round_real[i] = py_full_real_r[i] + RND_0P5`` where
  ``RND_0P5 = 2**15``, then keeps bits ``[31:16]``), and the FIR core's
  output width is configured to 16 bits directly (no further truncation at
  the top level -- ``m1_axis_tdata_o`` is wired straight from
  ``fir_compiler_0``'s output). This explicit rounding is consistent with
  the Python driver's ``IQ_OFFSET = 0.0`` for ``AxisDynReadoutV1``.

--------------------------------------------------------------------
4. Why There's No Register Map
--------------------------------------------------------------------

Unlike ``axis_readout_v2`` (:doc:`/readout_v2`), neither ``axis_readout_v3``
nor ``axis_dyn_readout_v1`` has an AXI-Lite slave port in its top-level
Verilog -- there is no ``FREQ_REG``/``PHASE_REG``/``NSAMP_REG``/
``OUTSEL_REG``/``MODE_REG``/``WE_REG`` set to document, and no register map
section to write for this page. The blocks' only I/O is AXI-Stream:

.. list-table:: axis_readout_v3 top-level ports
   :header-rows: 1
   :widths: 20 15 15 50

   * - Port
     - Direction
     - Width
     - Description
   * - ``s0_axis``
     - slave
     - 88 bits
     - Configuration descriptors, pushed by the tProcessor (see
       :ref:`readout-dyn-descriptor`). Backpressured by the 8-entry FIFO
       (``s0_axis_tready = ~fifo_full``).
   * - ``s1_axis``
     - slave
     - 4x16 bits
     - ADC input, 4 real samples/clock.
   * - ``m_axis``
     - master
     - 32 bits
     - Decimated complex (I, Q) output, 1 sample/clock, to
       :doc:`/avg_buffer`.

.. list-table:: axis_dyn_readout_v1 top-level ports
   :header-rows: 1
   :widths: 20 15 15 50

   * - Port
     - Direction
     - Width
     - Description
   * - ``s0_axis``
     - slave
     - 88 bits
     - Configuration descriptors, pushed by the tProcessor.
   * - ``s1_axis``
     - slave
     - 8x16 bits
     - ADC input, 8 real samples/clock.
   * - ``m0_axis``
     - master
     - 8x32 bits
     - Down-converted output, before FIR/decimation, 8 complex samples/clock.
   * - ``m1_axis``
     - master
     - 32 bits
     - Decimated complex (I, Q) output, 1 sample/clock, to
       :doc:`/avg_buffer`.

Because there is no register interface, there is also no PYNQ overlay driver
in the usual sense -- see :ref:`readout-dyn-python`.

.. _readout-dyn-python:

--------------------------------------------------------------------
5. Python Interface
--------------------------------------------------------------------

5.1 No PYNQ driver: ``AbsDynReadout``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Every other readout driver in ``qick.drivers.readout``
(``AxisReadoutV2``, ``AxisPFBReadoutV2/V3/V4``) inherits from ``SocIP``,
which itself inherits from PYNQ's ``DefaultIP`` and is matched to firmware
blocks by IP-registry ``bindto`` strings (e.g.
``bindto = ['user.org:user:axis_readout_v2:1.0', ...]``) when
``Overlay.load()`` scans the bitstream. That mechanism only works for blocks
that expose AXI-Lite registers.

``AxisReadoutV3`` and ``AxisDynReadoutV1`` instead inherit from
``AbsDynReadout(AbsReadout, DummyIP)`` -- neither class defines a
``bindto``, so PYNQ's overlay loader never instantiates them automatically.
``DummyIP`` (``qick.ip.DummyIP``) exists specifically for "firmware IP blocks
without register access" -- it just swallows the constructor's
``description`` argument so the class can still fit into ``QickIP``'s
``__init__`` chain. As the source comments in both
``AbsDynReadout``/``AxisReadoutV3``/``AxisDynReadoutV1`` put it: *"This isn't
a PYNQ driver, since the block has no registers for PYNQ control. We still
need this class to represent the block and its connectivity."*

Because these objects never get created by the overlay loader, something
else has to create them. That happens in
``AxisAvgBuffer.configure_connections()`` (``qick.drivers.readout``): when an
``axis_avg_buffer`` traces its upstream ``s_axis`` connection back to an
``axis_readout_v3`` or ``axis_dyn_readout_v1`` block, it manually constructs
the matching ``AxisReadoutV3``/``AxisDynReadoutV1`` instance and calls its
``configure_connections()`` -- the comment there reads *"the dynamic readout
blocks have no registers, so they don't get PYNQ drivers, so we initialize
them here."* ``AbsDynReadout.configure_connections()`` also traces the
block's ``s0_axis`` connection back through the tProcessor (or an
intervening ``axis_tmux_v1`` time-multiplexer) to determine which tProc
output port (``tproc_ctrl``, and optionally ``tmux_ch``) drives this
readout's configuration -- this is what lets software later target the right
tProc port when it sends a configuration.

5.2 ``declare_readout()``: static vs. dynamic
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

:meth:`.QickProgram.declare_readout` (``qick.qick_asm``) is where this
distinction surfaces at the program-authoring level. It looks at whether the
readout's config dict has a ``tproc_ctrl`` entry (set by
``AbsDynReadout.configure_connections()`` above, absent for
``axis_readout_v2``/PFB readouts):

.. code-block:: python

   if 'tproc_ctrl' not in ro_cfg: # readout is controlled by PYNQ
       if freq is None:
           raise RuntimeError("readout %d is static (PYNQ-configured) - "
                               "frequency must be set in declaration"%(ch))
       cfg['freq'] = freq
       cfg['gen_ch'] = gen_ch
       cfg['ro_config'] = self.soccfg.calc_ro_regs(ro_cfg, phase, sel)
   else: # readout is controlled by tProc
       if phase!=0 or sel!='product' or freq is not None or gen_ch is not None:
           raise RuntimeError("readout %d is dynamic (tProc-configured) - "
                               "freq/phase/sel parameters are set using tProc "
                               "instructions, not in declaration"%(ch))

For a dynamic readout, ``declare_readout()`` only reserves the channel
(readout length, edge-counting, weights) and deliberately *refuses* to accept
``freq``/``phase``/``sel``/``gen_ch`` -- those are set later, per-shot, by
tProc instructions, not once at declaration time.

5.3 Setting frequency/phase/outsel from a tProc v2 program
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On tProc v2 (``qick.asm_v2.QickProgramV2``), the program builds one
``ReadoutManager`` per dynamic readout channel
(``self._ro_mgrs = [ReadoutManager(self, iCh) if 'tproc_ctrl' in ch else None
...]``). Two program methods drive it:

* :meth:`.QickProgramV2.add_readoutconfig` (``ch``, ``name``, ``freq``,
  ``phase``, ``outsel``, ``phrst``, ...) computes the register values (DDS
  frequency/phase words, and a packed ``outsel``/``mode``/``phrst``
  configuration word via ``cfg2reg``) and stores them as a named "pulse" in
  the program.
* :meth:`.QickProgramV2.send_readoutconfig` (``ch``, ``name``, ``t``) emits
  the instructions (``ConfigReadout``) that push that pre-computed word to
  the readout's ``tproc_ctrl`` port at time ``t``, using the same
  ``WPORT_WR`` wave-memory-write mechanism used to schedule signal-generator
  pulses (see :doc:`/sg_v6`'s tProc-sequencing section). This is the
  run-time source of the ``s0_axis`` descriptor word described in
  :ref:`readout-dyn-descriptor`.

.. code-block:: python
  :caption: Configuring a dynamic readout's frequency from a tProc v2 program

  from qick import *

  soc = QickSoc()
  prog = QickProgramV2(soc)

  ro_ch = 0
  prog.declare_readout(ch=ro_ch, length=1.0)  # no freq/phase/sel here

  # Define the readout config once, up front.
  prog.add_readoutconfig(ch=ro_ch, name="myro", freq=100.0, phase=0, outsel="product")

  # ... later, inside the timed part of the program ...
  prog.send_readoutconfig(ch=ro_ch, name="myro", t=0)   # push freq/phase/outsel to the readout
  prog.trigger(ros=[ro_ch], t=0.5)                       # arm the buffer to capture

tProc v1 programs (``qick.asm_v1``) have an equivalent ``ReadoutManager`` and
follow the same two-step (build descriptor, then instruction-schedule it)
pattern; the descriptor format on the wire is identical since it's produced
by the same firmware control FSM.

Related Documentation
----------------------

* :doc:`/readout` -- readout system overview.
* :doc:`/readout_v2` -- the static, PYNQ-register-configured readout these
  blocks are the dynamic counterpart of.
* :doc:`/avg_buffer` -- the buffer downstream of ``m_axis``/``m1_axis``.
* :doc:`/tprocv2_trm` -- tProcessor instruction reference, including
  ``WPORT_WR`` and the timing model used by ``send_readoutconfig()``.
* :doc:`/sg_v6` -- the signal-generator counterpart of tProc-scheduled,
  ``WPORT_WR``-driven configuration.
* :doc:`topics/freq_matching` -- keeping generator and readout frequencies in
  sync.
