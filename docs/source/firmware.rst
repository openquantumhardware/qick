Firmware
========

This page provides an overview of the QICK firmware components.

System Overview
---------------

The QICK firmware includes the following components:

* **tProcessor v2** - Real-time co-processor for sequencing and feedback
* **Signal Generator v6 (SG-v6)** - DDS-based waveform generators for DAC outputs
* **Readout System** - ADC data acquisition with DDC, filtering, and averaging

.. list-table::
   :header-rows: 1

   * - Component
     - Quantity
     - Documentation
   * - tProcessor v2
     - 1 instance (64-bit instructions, 32-bit registers)
     - :doc:`/tprocv2_trm`
   * - Signal generators
     - Board-dependent -- each board's standard firmware provisions its own
       mix of :doc:`/sg_v6`, :doc:`/sg_int4_v2`, :doc:`/sg_mixmux8`,
       :doc:`/sg_mux8`; see :ref:`std-firmware-per-board`
     - :doc:`/generators`, :doc:`/sg_v6`
   * - Readouts
     - Board-dependent -- single-tone (:doc:`/readout_v2`,
       :doc:`/readout_dynamic`) and/or channelized (:doc:`/readout_pfb`);
       see :ref:`std-firmware-per-board`
     - :doc:`/readout`, :doc:`/readout_dynamic`, :doc:`/readout_pfb`,
       :doc:`/avg_buffer`
   * - tProc trigger outputs (``trig_N_o`` pins)
     - Board-dependent single-bit pins -- PMOD bits plus one per averaging
       buffer, plus DDR4/multi-rate-buffer triggers where present; see
       :ref:`tproc-ports`
     - :doc:`/tprocv2_trm`

Sampling frequency of ADC blocks is given by the variable ``soc.fs_adc``.
Sampling frequency of DACs is stored in variable ``soc.fs_dac``.
Fast-speed buffers were removed to save memory space. Raw data can be captured after x8 down-sampling.

Signal Generator v6 (SG-v6)
---------------------------

Output channels driving DACs use the **Signal Generator v6**, which has the following features:

* Supports uploading I/Q envelopes
* 32-bit resolution for both frequency and phase
* Configurable DDS with streaming mode (frequency can change sample-to-sample)
* 16 parallel samples per clock cycle (256-bit output bus)
* Maximum envelope length: 65536 samples per channel

For complete documentation, see :doc:`/sg_v6`. If your board uses a
different generator core (multiplexed, interpolated, or the legacy v4), see
:doc:`/generators` for the full family and which one fits which experiment.

Readout System
--------------

QICK ships several readout IP variants for the DDC/decimation stage --
:doc:`/readout_v2` (PYNQ-register-configured, single tone),
:doc:`/readout_dynamic` (``axis_readout_v3``/``axis_dyn_readout_v1``,
tProc-configured per shot, single tone), and :doc:`/readout_pfb`
(``axis_pfb_readout_v2``/``v3``/``v4``, a fixed polyphase-filter-bank
channelizer that fans one ADC input out to several simultaneous demodulated
channels). Which one(s) a given board's standard firmware uses, and how many,
is a per-board decision -- see :ref:`std-firmware-per-board`. All variants
feed the same downstream block, **Average + Buffer** (:doc:`/avg_buffer`):

**Readout Block** (architecture varies by variant -- see the pages above):

* Digital down-conversion (DDC)
* FIR filtering
* Decimation

**Average + Buffer Block:**

* Raw sample storage
* Coherent averaging
* Triggered by a dedicated single-bit ``trig_N_o`` pin from the
  tProcessor -- one per averaging buffer instance, *not* part of the same
  channel-numbered AXI-Stream space as the readout's own configuration; see
  :ref:`tproc-ports`

For complete documentation, see :doc:`/readout_v2`, :doc:`/readout_dynamic`,
and :doc:`/readout_pfb` (the DDC/decimation stage, in its several variants)
and :doc:`/avg_buffer` (the averaged/raw buffer IP and its register map).

The tProcessor v2
-----------------

The tProcessor (timing Processor) is a hard real-time co-processor inside the QICK FPGA.
It runs user-written programs that control waveform generation, data acquisition, and feedback with nanosecond precision.

For **complete documentation**, see:

* :doc:`/tprocv2_trm` - Full reference manual (architecture, instruction set, programming examples)
* :doc:`topics/asmv2_cheatsheet` - Quick reference for assembly programming

**Quick links to tProcessor topics:**

* :ref:`tproc-quick-ref` - Most common instructions and condition codes
* :ref:`tproc-registers` - Complete register bank reference
* :ref:`tproc-examples` - Copy-paste ready code examples
* :ref:`tproc-peripherals` - ARITH (multiply), DIV, LFSR

.. _std-firmware-per-board:

Standard ("_std") Firmware Per Board
-------------------------------------

QICK does not use one universal channel layout. For each supported board,
the ``qick`` firmware repository ships a **standard reference design**
("_std", under ``firmware/Top/<board>/tpv2_std/``) that provisions a
different mix of generator and readout IP suited to that board's DAC/ADC tile
count and I/O capacity. A board's *other* firmware builds (e.g. the ZCU216
"_demo" project) can provision yet another mix again. There is no fixed
"channel N is always generator type X" rule across boards -- what follows is
each board's own layout, traced directly from that board's block-design
source (``bd_2023-1.tcl``, on branch ``feature/114-integrate-hog-fusesoc``)
rather than assumed:

.. list-table::
   :header-rows: 1
   :widths: 18 10 12 12 10 12 12 10 12

   * - Board (``tpv2_std`` unless noted)
     - :doc:`/sg_v6`
     - :doc:`/sg_int4_v2`
     - :doc:`/sg_mixmux8`
     - :doc:`/sg_mux8`
     - :doc:`/readout_dynamic` (dyn v1)
     - :doc:`/readout_pfb` (v4)
     - :doc:`/avg_buffer`
     - :doc:`/mr_buffer_et`
   * - ZCU111 (``firmware/Top/111``)
     - 8
     - 0
     - 0
     - 0
     - 4
     - 0
     - 4
     - 1
   * - RFSoC4x2 (``firmware/Top/4x2``)
     - 2
     - 0
     - 0
     - 0
     - 3
     - 0
     - 2
     - 1
   * - ZCU216 (``firmware/Top/216/tpv2_std``, flagship / QICKbox)
     - 4
     - 11
     - 1
     - 0
     - 2
     - 1
     - 10
     - 1
   * - ZCU216 ``tpv2_demo`` (not "_std")
     - 2
     - 2
     - 1
     - 1
     - 1 (plus 1 ``axis_readout_v2`` + 1 ``axis_readout_v3``)
     - 0 (1 ``axis_pfb_readout_v3`` instead)
     - 7
     - 1

Counts are per-board instance counts of each IP core, obtained by grepping
each board's ``bd_2023-1.tcl`` for its ``create_bd_cell`` lines -- not a
per-channel numbering scheme. See :ref:`tproc-zcu216-example` below for how
the ZCU216 ``tpv2_std`` numbers above translate into an actual tProc
channel/DAC/ADC map.

.. note::
   If using the Xilinx XM500 daughter board (ZCU111), be aware of DAC/ADC
   tile filters (a physical hardware property of that daughtercard, not of
   the firmware's channel numbering):

   - DAC 229 CH0/CH1: **High-pass** (1 GHz) → output ≥ 1 GHz
   - DAC 229 CH2/CH3: **Low-pass** (1 GHz) → output ≤ 1 GHz
   - ADC 224 CH0/CH1: **Low-pass** (1 GHz) → input ≤ 1 GHz
   - DAC 228 channels: **No filters**

   This note was not re-verified against the ZCU111 ``tpv2_std`` block
   design in this pass (only the ZCU216 design was traced in detail); treat
   the DAC/ADC tile numbers as Xilinx's own physical labels, independent of
   whichever tProc channel happens to feed them.

.. _tproc-ports:

tProc Waveform Ports vs. Trigger Outputs
-------------------------------------------

In tProc v2, two architecturally separate sets of ``qick_processor`` ports
are involved in driving generators/readouts and firing triggers -- unlike
tProc v1, where a single AXIS-channel numbering space carried both (this
page previously described tProc v2 hardware using that older model; the
distinction below is the correction):

* **Waveform/config ports** (``m0_axis``..``mN_axis``, driven by
  ``WPORT_WR``/:meth:`.QickProgram.pulse`) are full AXI-Stream ports that
  carry generator pulse commands and dynamic-readout per-shot configuration
  words. How many exist is a synthesis parameter of ``qick_processor``
  (``CONFIG.OUT_WPORT_QTY``) -- **16** on ZCU216 ``tpv2_std``, matching its
  16 total DAC channels/generator instances (4 SG-v6 + 1 SG-mixmux8 + 11
  SG-int4-v2, per the table above).
* **Trigger outputs** (``trig_0_o``..``trig_N_o``) are independent
  **single-bit** pins, each wired with a plain ``connect_bd_net`` (not an
  AXI-Stream ``connect_bd_intf_net``) directly to one PMOD bit or one IP
  block's ``trigger`` input. How many exist is a separate synthesis
  parameter (``CONFIG.OUT_TRIG_QTY``) -- **20** on ZCU216 ``tpv2_std``. They
  are not part of the same numbering space as the waveform ports, and (also
  unlike tProc v1) they are not bits packed inside a generator channel's
  data word either.

Both counts were read directly off ``qick_processor_0``'s ``CONFIG.*``
properties in the ZCU216 ``tpv2_std`` ``bd_2023-1.tcl`` this session; they
are synthesis-time parameters, so other boards' firmware can and do
instantiate different totals (verify per board rather than assuming these
numbers).

**Full ``trig_N_o`` mapping, ZCU216 ``tpv2_std`` (verified via
``connect_bd_net`` on ``qick_processor_0/trig_*_o``):**

.. list-table::
   :header-rows: 1
   :widths: 20 40

   * - Trigger pin(s)
     - Drives
   * - ``trig_0_o`` .. ``trig_7_o``
     - ``PMOD0_0_LS`` .. ``PMOD0_7_LS`` (all 8 PMOD0 bits)
   * - ``trig_8_o``
     - ``mr_buffer_et_0/trigger`` (see :doc:`/mr_buffer_et`)
   * - ``trig_9_o``
     - ``ddr4/trigger`` (DDR4 streaming capture)
   * - ``trig_10_o`` .. ``trig_19_o``
     - ``axis_avg_buffer_0/trigger`` .. ``axis_avg_buffer_9/trigger`` --
       one dedicated trigger bit per averaging buffer instance

This replaces the old, incomplete claim that readout triggers were "bit 14"
and "bit 15" of a channel-0 data word -- on ZCU216 ``tpv2_std`` there are 20
independent trigger pins, only 8 of which are PMOD, and the remaining 12
individually fire the board's 10 avg_buffers, its one ``mr_buffer_et``, and
its DDR4 capture path. A board with a different avg_buffer count (see
:ref:`std-firmware-per-board`) will have a different ``OUT_TRIG_QTY`` and a
correspondingly different mapping -- always confirm against that board's own
``bd_*.tcl`` (or, from Python, treat the driver-level trigger/arm calls as
the source of truth rather than the raw pin numbers).

There is also a third, separate set of ports: **feedback inputs**
(``s0_axis``..``s9_axis`` on ``qick_processor_0``, ``CONFIG.IN_PORT_QTY=10``
on ZCU216 ``tpv2_std``), each individually wired (via a per-channel clock
converter) to one averaging buffer's ``m2_axis`` live-feedback output --
i.e. one real-time feedback input per avg_buffer, again not "2 input
channels" as this page previously claimed.

.. _tproc-zcu216-example:

Worked Example: ZCU216 ``tpv2_std``
--------------------------------------

The ZCU216 ``tpv2_std`` design is traced here in full (it is the flagship
board and what ships in the QICKbox). All of the following was read from
``firmware/Top/216/tpv2_std/bd_2023-1.tcl`` (branch
``feature/114-integrate-hog-fusesoc``) in this session -- generator counts
match :ref:`std-firmware-per-board` above.

**DAC side -- tProc waveform port to DAC channel:**

The RFDC (``usp_rf_data_converter_0``) has 4 DAC tiles, 4 channels each
(``s00``..``s33``, 16 channels total). ``qick_processor_0``'s core clock
(``t_clk_i``) is tied to DAC tile 2's sample clock; SG-int4-v2 and
SG-mixmux8 (tiles 1-3) run on that same clock, so their tProc ports connect
straight through. DAC tile 0 (the 4 SG-v6 channels) runs on its own,
independent sample clock, so those 4 ports cross through a
clock-domain-crossing block (``axis_cdcsync_v1_0``, RTL parameter ``N=4``)
first.

.. list-table::
   :header-rows: 1
   :widths: 12 18 20 20 15

   * - tProc port
     - CDC/demux stage
     - Generator instance
     - Generator type
     - DAC tile:ch
   * - ``m0_axis``
     - ``axis_cdcsync_v1_0`` (4-ch CDC, core clk → DAC-tile-0 clk)
     - ``axis_signal_gen_v6_0``
     - SG-v6
     - tile 0 : 0
   * - ``m1_axis``
     - ``axis_cdcsync_v1_0``
     - ``axis_signal_gen_v6_1``
     - SG-v6
     - tile 0 : 1
   * - ``m2_axis``
     - ``axis_cdcsync_v1_0``
     - ``axis_signal_gen_v6_2``
     - SG-v6
     - tile 0 : 2
   * - ``m3_axis``
     - ``axis_cdcsync_v1_0``
     - ``axis_signal_gen_v6_3``
     - SG-v6
     - tile 0 : 3
   * - ``m4_axis``
     - ``axis_tmux_v1_0`` (address-tagged 3-way demux; direct to
       generator, or via ``axis_cdcsync_v1_2`` for the other two)
     - ``axis_sg_mixmux8_v1_0``
     - SG-mixmux8
     - tile 1 : 0
   * - ``m5_axis``
     - direct (same clock domain as tProc core)
     - ``axis_sg_int4_v2_0``
     - SG-int4-v2
     - tile 1 : 1
   * - ``m6_axis``
     - direct
     - ``axis_sg_int4_v2_1``
     - SG-int4-v2
     - tile 1 : 2
   * - ``m7_axis``
     - direct
     - ``axis_sg_int4_v2_2``
     - SG-int4-v2
     - tile 1 : 3
   * - ``m8_axis``
     - direct
     - ``axis_sg_int4_v2_3``
     - SG-int4-v2
     - tile 2 : 0
   * - ``m9_axis``
     - direct
     - ``axis_sg_int4_v2_4``
     - SG-int4-v2
     - tile 2 : 1
   * - ``m10_axis``
     - direct
     - ``axis_sg_int4_v2_5``
     - SG-int4-v2
     - tile 2 : 2
   * - ``m11_axis``
     - direct
     - ``axis_sg_int4_v2_6``
     - SG-int4-v2
     - tile 2 : 3
   * - ``m12_axis``
     - direct
     - ``axis_sg_int4_v2_7``
     - SG-int4-v2
     - tile 3 : 0
   * - ``m13_axis``
     - direct
     - ``axis_sg_int4_v2_8``
     - SG-int4-v2
     - tile 3 : 1
   * - ``m14_axis``
     - direct
     - ``axis_sg_int4_v2_9``
     - SG-int4-v2
     - tile 3 : 2
   * - ``m15_axis``
     - direct
     - ``axis_sg_int4_v2_10``
     - SG-int4-v2
     - tile 3 : 3

Every ``qick_processor_0/mN_axis`` port passes through a ``sg_translator``
instance before reaching its generator (18 ``sg_translator`` instances exist
in total: 16 feed the generators above, ``sg_translator_16``/``_17`` feed the
two dynamic readouts' config ports instead -- see below). Register slices
(``axis_register_slice_0``-``_7``) also sit inline on the SG-v6 path, but
these stay on one clock (they don't add a second CDC hop) -- they're
ordinary pipeline stages for timing closure, confirmed by both sides sharing
the same clock net in the .tcl.

``m4_axis`` is the one port that isn't a clean 1-generator mapping: RTL for
``axis_tmux_v1`` (``firmware/ip/axis_tmux_v1/src/tmux.sv``) shows it demuxes
one AXI-Stream input to one of *N* outputs by an address tag carried in the
data word itself (the top 8 bits), not a fixed per-port assignment. On this
board (``CONFIG.N=3``), that lets tProc channel 4 carry pulse commands for
the SG-mixmux8 generator *and* per-shot config words for both dynamic
readouts, distinguished by that tag -- one of the demuxed outputs goes
straight to ``sg_translator_4`` (mixmux8, same clock domain), and the other
two cross into the ADC-tile-2 clock domain via a second CDC block,
``axis_cdcsync_v1_2`` (``N=2``), before reaching ``sg_translator_16``/``_17``
and then ``axis_dyn_readout_v1_0``/``_1``'s ``s0_axis`` config ports.

**On the CDC blocks' purpose:** ``axis_cdcsync_v1`` (RTL:
``firmware/ip/axis_cdcsync_v1/src/cdcsync.sv``) exposes independent
input-side and output-side clock/reset pairs for up to ``N`` parallel
same-width streams -- it is a clock-domain-crossing bridge, confirmed by
tracing each instance's ``aclk`` nets in this board's .tcl (input side tied
to the tProc core clock, output side tied to the destination tile's own
clock). It is **not** part of the ``xcom`` multi-board synchronization
mechanism (:doc:`topics/xcom`) despite the similar name -- that is a wholly
separate IP block with its own network/serial interface. Both CDC instances
on this board exist purely because DAC tile 0 and the ADC-tile-2-clocked
readout logic run on clocks independent of the tProc's own core clock, not
for any cross-board purpose.

**ADC side -- readout instances:**

* ``axis_dyn_readout_v1_0`` -- ADC input from tile 2, channel 0
  (``usp_rf_data_converter_0/m20_axis``).
* ``axis_pfb_readout_v4_0`` -- ADC input from tile 2, channel 1
  (``m21_axis``); channelizes into 8 outputs, ``m0_axis``..``m7_axis``.
* ``axis_dyn_readout_v1_1`` -- ADC input from tile 2, channel 2
  (``m22_axis``).

Each dynamic readout's decimated output (``m1_axis``) and each of the PFB
readout's 8 channelized outputs feed their own ``axis_broadcaster``, which
fans out to (a) one dedicated ``axis_avg_buffer`` (1:1 -- 10 total: 2 for the
dynamic readouts + 8 for the PFB readout's 8 channels) and (b) a shared
10-input AXI-Stream switch (``axis_switch_ddr``) feeding the single DDR4
capture path, letting software pick which one of the 10 channels streams to
DDR4. Separately, the two dynamic readouts' *undecimated* outputs
(``m0_axis``) feed a 2-input switch (``axis_switch_mr``) into the single
shared ``mr_buffer_et_0`` instance. This matches, and was cross-checked
against, the independently-traced fan-out in :doc:`/readout_pfb`'s
":ref:`readout-pfb-zcu216`" section.

Checking Your Own Board's Configuration
------------------------------------------

Every table on this page describes one specific board's firmware build,
traced from that build's source. Your board may be a different one, or the
same board with a different firmware build -- do not assume generator
counts, readout counts, or channel/trigger mappings from this page apply to
your setup. Instead, read them from the running system:

* ``soc.gens`` -- list of generator drivers, in board-config order (index
  is *not* guaranteed to equal the tProc waveform-port number -- see
  :ref:`tproc-zcu216-example` for why that mapping can be non-trivial).
* ``soc.readouts`` -- list of readout drivers (mix of
  :doc:`/readout_v2`/:doc:`/readout_dynamic`/:doc:`/readout_pfb` types,
  board-dependent).
* ``soc.avg_bufs`` -- list of :doc:`/avg_buffer` drivers.
* ``print(soccfg)`` -- full human-readable dump of the board's configuration,
  including per-channel generator/readout types and every buffer's
  ``avg_maxlen``/``buf_maxlen``.

Timing
------

- **FPGA clock:** 384 MHz → period = 2.6 ns
- **DAC speed:** 384 × 16 = 6144 MHz → resolution ~163 ps
- **ADC speed:** 384 × 8 = 3072 MHz, decimated by 8 → resolution ~2.6 ns
- **Minimum DAC pulse length:** 16 samples (shorter pulses can be zero-padded)

Firmware Parameters
-------------------

.. note::
   This table previously carried tProc-**v1**-era figures (8k-instruction
   program memory, 256-sample stack, 16-bit gain) copied into this page
   unchanged. tProc v2's real numbers, confirmed against
   :doc:`/tprocv1` and :doc:`/tprocv2_trm` in this session, are quite
   different -- notably the **stack is 8 entries deep, not 256**, and
   program/data memory sizes are synthesis parameters
   (``PMEM_AW``/``DMEM_AW``), not a fixed "8k"/"4096". As with everything
   else on this page, treat board-specific sizes as something to read from
   ``soccfg`` (or ``soc.tproc.cfg``), not to assume.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Value
   * - Pulse memory length (per SG-v6)
     - 65536 samples ×2 (I/Q) = 128k total (``N=16`` default -- see
       :doc:`/sg_v6`)
   * - Decimated ADC buffer
     - Board-dependent, ``2**N_BUF`` samples per component (I,Q) -- see
       :doc:`/avg_buffer`
   * - Accumulated ADC buffer
     - Board-dependent, ``2**N_AVG`` samples per component (I,Q) -- see
       :doc:`/avg_buffer`
   * - tProc v2 program/data memory
     - Synthesis parameters (``PMEM_AW``/``DMEM_AW``), board-dependent --
       see :doc:`/tprocv2_trm`
   * - tProc v2 stack size
     - **8** entries (fixed, not a synthesis parameter) -- see
       :doc:`/tprocv2_trm`
   * - Phase conversion
     - :math:`\Delta \phi = 2\pi/2^{32}` or :math:`360/2^{32}` degrees
   * - Gain range (tProc v2 / ``w_gain``)
     - 32-bit signed -- verified against RTL (``qcore_reg_bank.sv``) and
       ``asm_v2.py``'s ``Waveform.compile()`` in :doc:`/tprocv2_trm`

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - Complete tProcessor v2 reference manual
* :doc:`/generators` - Full generator-core family (SG-v6, SG-int4-v2, SG-mixmux8, SG-mux8)
* :doc:`/sg_v6` - Signal Generator v6 documentation
* :doc:`/readout` - Readout system overview
* :doc:`/readout_dynamic` - tProc-configured single-tone readouts (axis_readout_v3 / axis_dyn_readout_v1)
* :doc:`/readout_pfb` - Polyphase-filter-bank channelized readouts (axis_pfb_readout_v2/v3/v4)
* :doc:`/avg_buffer` - Averaged/raw buffer IP downstream of every readout variant
* :doc:`/mr_buffer_et` - Multi-rate buffer (DDR4/streaming) shared readout path
* :doc:`topics/asmv2_cheatsheet` - tProc v2 assembly quick reference
* :doc:`topics/tutorials` - tProc v2 tutorial examples
* `Signal Generator v6 source <https://github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_signal_gen_v6>`_
