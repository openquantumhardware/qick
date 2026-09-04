===============================================================================
PFB Readouts (axis_pfb_readout_v2 / v3 / v4) - QICK Firmware
===============================================================================

.. contents::
  :local:
  :depth: 2

**axis_pfb_readout_v2**, **axis_pfb_readout_v3**, and **axis_pfb_readout_v4**
are QICK's polyphase-filter-bank (PFB) readouts: unlike every other readout
documented so far (:doc:`/readout_v2`, :doc:`/readout_dynamic`), a PFB readout
channelizes its ADC input into many fixed-frequency slices of the band *in
hardware*, then lets software/tProc pick which slice(s) to route to its
output port(s) and fine-tune each with its own DDS. One PFB readout instance
therefore behaves like several single-tone readouts operating simultaneously
on disjoint (or shared) parts of the spectrum, rather than one tunable
downconverter. All three modules live under ``firmware/ip/`` --
``axis_pfb_readout_v2/``, ``axis_pfb_readout_v3/``, ``axis_pfb_readout_v4/``
-- and are exposed to Python through ``qick.drivers.readout.AbsPFBReadout``
and its ``AxisPFBReadoutV2``/``V3``/``V4`` subclasses.

.. note::
  Like most of the cores in this doc set, this is **legacy RTL that has not
  been ported to the newer fusesoc build system** -- it exists only in the
  ``firmware/ip/`` tree, not under a fusesoc core description. That does not
  make it dead code: it is real, currently-shipping firmware. The flagship
  ZCU216 "tpv2_std" board design (``firmware/Top/216/tpv2_std/bd_2023-1.tcl``,
  tracked on branch ``feature/114-integrate-hog-fusesoc``, since it predates
  this branch's docs-only history) instantiates one **axis_pfb_readout_v4**
  alongside two ``axis_dyn_readout_v1`` (:doc:`/readout_dynamic`) -- see
  :ref:`readout-pfb-zcu216` below.

.. _readout-pfb-general:

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

All three versions share the same overall pipeline:

1. **Polyphase filter bank + FFT** -- a bank of parallel FIR filters
   (``firs.sv``/``firs``) followed by an FFT splits the input band into N
   equally-spaced, overlapping channels, each centered on a different fixed
   frequency (an integer multiple of ``fs/N``, where ``fs`` is the ADC sample
   rate seen by the PFB). This stage is a fixed, compiled-in channelizer --
   its channel count and spacing are synthesis-time constants, not runtime
   registers.
2. **Per-channel or per-output DDS mixing** -- a second, small, *programmable*
   DDS fine-tunes each selected channel by up to +/- half a channel width, so
   the final demodulation frequency is (fixed PFB channel center) + (DDS
   offset), rather than only landing on one of the N coarse PFB bins.
3. **Output routing/selection** -- a subset of the N PFB channels (up to
   NOUT of them) is routed to the block's NOUT physical AXI-Stream output
   ports, which is what actually gets built (see :ref:`readout-pfb-zcu216`)
   -- each output port typically feeds its own :doc:`/avg_buffer` instance
   downstream, one PFB readout thus driving multiple avg_buffers.

Where the three versions differ is **N** (PFB channel count), **NOUT**
(selectable/routed output count), and **whether the fine-tuning DDS sits
before or after output selection** -- all verified directly from RTL below,
not inferred from naming.

.. list-table:: axis_pfb_readout_v2 / v3 / v4 -- top-level comparison
   :header-rows: 1
   :widths: 22 20 20 38

   * -
     - v2
     - v3
     - v4
   * - PFB channels (N)
     - 8 (``ssrfft_8x8``, ``NFFT=2*L`` with ``L=4``)
     - 64 (``pfb_top``/``pfb_readout`` default parameter ``N=64``,
       ``ssrfft_8x64``)
     - 64 (same ``pfb_readout``/``pfb`` core as v3, unchanged)
   * - Selectable outputs (NOUT)
     - 4 (``m0``-``m3``)
     - 4 (``m0``-``m3``, ``localparam NOUT = 4`` in ``pfb_top.sv``)
     - 8 (``m0``-``m7``, ``localparam NOUT = 8`` in ``pfb_top.sv``)
   * - DDS placement
     - Per PFB channel (all 8 channels always have a live DDS mixer;
       ``DDS_ON_OUTPUT = False`` in the driver)
     - Per output (4 independent, phase-coherent DDS blocks, one per
       selected output; ``DDS_ON_OUTPUT = True``)
     - Per output (8 independent DDS blocks, same structure as v3, just
       doubled)
   * - Output-channel selection
     - ``pfb_mux.sv``: a 3-bit ``CH[0-3]SEL_REG`` per output picks 1 of the 8
       already-DDS-mixed channels
     - ``pfb_chsel.sv`` (one instance per output, inside ``pfb_top``): a
       16-bit ``ID[0-3]_REG`` (packet + index into the 64-channel TDM
       stream) picks which raw PFB channel feeds that output's DDS
     - Same ``pfb_chsel.sv`` mechanism as v3, with 8 instances (``ID[0-7]_REG``)
   * - AXI-Lite address width
     - 6 bits (``s_axi_awaddr[5:0]``, 13 registers)
     - 6 bits (``s_axi_awaddr[5:0]``, 12 registers)
     - 8 bits (``s_axi_awaddr[7:0]``, 24 registers -- widened because NOUT
       doubled)

--------------------------------------------------------------------
2. axis_pfb_readout_v2
--------------------------------------------------------------------

2.1 Datapath
^^^^^^^^^^^^

``axis_pfb_readout_v2.v`` instantiates a single block, ``pfb_dds_mux``
(``pfb_dds_mux.sv``), which chains three sub-blocks:

1. **pfb** (``pfb.sv``) -- ``firs`` (the polyphase FIR bank, ``L=4`` input
   lanes) feeds an ``ssrfft_8x8`` core (``NFFT=SSR=2*L=8``, ``B=16``), which
   is then run through ``pimod`` (a "pi modulation" / spectral-reordering
   stage). Output is 8 interleaved 32-bit (16-bit I + 16-bit Q) lanes on one
   256-bit-wide AXI-Stream word (``tdata_pfb``) -- **8 fixed PFB channels**,
   each centered on ``i * fs/16`` for channel ``i`` (the ``ssrfft_8x8``
   parameterization: 8-point FFT over the PFB's overlapped, 50%-overlap
   50%-decimated stream).
2. **ddsprod_v** (``ddsprod_v.sv``) -- instantiates 8 ``ddsprod`` blocks
   (``ddsprod.sv``), one per PFB channel, **always active regardless of
   which outputs are actually used**. Each ``ddsprod`` complex-multiplies its
   channel's PFB output against a per-channel programmable DDS
   (``dds_0``/``FREQ[0-7]_REG``), and its output mux (shared 2-bit
   ``OUTSEL_REG`` across all 8 channels) picks between the demodulated
   product, the raw (delay-matched) PFB channel input, or the raw DDS tone --
   the same product/input/dds encoding pattern used by the single-tone
   readouts (:doc:`/readout_v2`).
3. **pfb_mux** (``pfb_mux.sv``) -- a pure combinational 8-to-1 mux, replicated
   4 times (one per output). Each output's 3-bit ``CH[0-3]SEL_REG`` selects
   which of the 8 already-DDS-mixed channels appears on that output
   (``m0``-``m3``).

Because the DDS sits *before* the output mux (per-channel, not per-output),
v2's 4 outputs can only ever carry (a subset of) the 8 channel-DDS results
computed once, shared if two outputs pick the same channel -- there is no way
to independently re-tune the same PFB channel differently on two outputs
simultaneously.

2.2 Register Map
^^^^^^^^^^^^^^^^^

Register offsets below are as wired in ``axi_slv.vhd`` (``slv_reg0``
.. ``slv_reg12``) and match ``AxisPFBReadoutV2._init_config()``'s
``REGISTERS`` dict in ``qick_lib/qick/drivers/readout.py`` exactly.

.. list-table::
   :header-rows: 1
   :widths: 22 12 66

   * - Register
     - Width
     - Description
   * - ``FREQ[0-7]_REG``
     - 32 bits each
     - Per-PFB-channel DDS tuning word (one per of the 8 fixed channels,
       *not* per output).
   * - ``OUTSEL_REG``
     - 2 bits
     - Shared by all 8 channel DDS muxes. 0: product (demodulated). 1: input
       (bypass, raw PFB channel). 2: dds (raw local-oscillator tone).
   * - ``CH0SEL_REG`` .. ``CH3SEL_REG``
     - 3 bits each
     - Maps output port N (0-3) to one of the 8 DDS-mixed PFB channels
       (0-7).

--------------------------------------------------------------------
3. axis_pfb_readout_v3
--------------------------------------------------------------------

3.1 Datapath
^^^^^^^^^^^^

``axis_pfb_readout_v3.v`` instantiates ``pfb_readout`` (``pfb_readout.v``,
parameterized ``N=64`` channels, ``L=4`` input lanes), which chains:

1. **pfb_top** (``pfb_top.sv``) -- instantiates the shared ``pfb`` channelizer
   core (50%-overlap PFB into an ``ssrfft_8x64``-based 64-point FFT --
   channel ``i`` centered at ``i * fs/64``), whose 64-channel output stream is
   time-division-multiplexed across ``L=8`` parallel lanes (``2*L`` from the
   overlap structure), i.e. 8 channels appear per clock, taking 64/8 = 8
   clocks ("packets") to cycle through all 64 channels. ``pfb_top``
   instantiates **NOUT = 4** ``pfb_chsel`` blocks in a ``generate`` loop, one
   per output -- each is a TDM channel-extractor: it watches the 8-lane
   stream for its configured ``(packet, index)`` pair (from that output's
   ``ID[0-3]_REG``) and latches the matching 32-bit (I,Q) sample onto its
   output. Unlike v2, **no DDS mixing happens at this stage** -- ``pfb_top``
   only selects a raw PFB channel per output; it has no ``FREQ``/``PINC``
   registers of its own.
2. **ddsprod_v** (a *different*, 4-output-specific ``ddsprod_v.sv`` from
   v2's 8-channel one) -- instantiates 4 independent ``ddsprod`` blocks, one
   per output, **after** channel selection. Each output gets its own
   phase-coherent DDS (``PINC[0-3]_REG``/``POFF[0-3]_REG``) applied to
   whichever raw PFB channel that output's ``pfb_chsel`` picked. Because the
   DDS is per-output rather than per-channel, the *same* PFB channel can be
   routed to two different outputs and independently fine-tuned/phased on
   each -- the opposite tradeoff from v2.

v3 has **no ``OUTSEL_REG``**/output-mode-selection mux at all (confirmed:
``ddsprod.sv`` in v3/v4 has no ``OUTSEL_REG`` port, unlike v2's; the Python
driver sets ``HAS_OUTSEL = False`` for ``AxisPFBReadoutV3``) -- each output
always carries the demodulated product, nothing else.

3.2 Register Map
^^^^^^^^^^^^^^^^^

Confirmed against ``axi_slv.vhd`` (``slv_reg0``..``slv_reg11``, 12 registers,
6-bit address bus) and ``AxisPFBReadoutV3._init_config()``, which builds the
same offsets programmatically (``id%d_reg`` at 0-3, then ``freq%d_reg``/
``phase%d_reg`` pairs at 4/5, 6/7, 8/9, 10/11). Note the RTL register names
(``ID``/``PINC``/``POFF``) differ from the Python driver's friendlier names
(``id``/``freq``/``phase``) for the same bits -- ``PINC`` = phase increment
(frequency tuning word), ``POFF`` = phase offset.

.. list-table::
   :header-rows: 1
   :widths: 22 12 66

   * - Register (RTL / driver name)
     - Width
     - Description
   * - ``ID[0-3]_REG`` / ``id[0-3]_reg``
     - 16 bits
     - Selects which of the 64 PFB channels feeds output N. Lower 8 bits =
       "packet" (``pfb_ch // 8``, 0-7), upper 8 bits = "index" within that
       packet's 8-lane word (``pfb_ch % 8``, 0-7) -- computed by
       ``AxisPFBReadoutV3.set_freq_int()`` as
       ``id_val = (index << 8) + packet``.
   * - ``PINC[0-3]_REG`` / ``freq[0-3]_reg``
     - 32 bits
     - Per-output DDS frequency (fine-tuning on top of the selected PFB
       channel's fixed center frequency).
   * - ``POFF[0-3]_REG`` / ``phase[0-3]_reg``
     - 32 bits
     - Per-output DDS phase offset.

--------------------------------------------------------------------
4. axis_pfb_readout_v4
--------------------------------------------------------------------

4.1 Is v4 RTL-identical to v3?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**No.** This was verified directly by diffing the RTL trees, not assumed from
the Python driver. ``axis_pfb_readout_v4`` reuses the *same* shared
sub-modules as v3 (``pfb_top.sv``, ``pfb_chsel.sv``, ``pfb.sv``,
``pfb_switch.v``, ``pfb_reorder.sv``, ``pfb_ctrl.vhd``, ``pfb_cfg.vhd`` are
byte-for-byte identical between the two IP directories -- confirmed with
``diff``), but the **top-level wrapper and its NOUT-sized instance arrays are
doubled from 4 to 8**:

* ``pfb_top.sv``'s own header comment changes from *"The number of outputs is
  fixed to 4 in this case"* (v3) to *"...fixed to 8 in this case"* (v4), and
  its ``localparam NOUT`` literally changes from ``4`` to ``8``, adding 4 more
  ``pfb_chsel`` generate-loop instances, 4 more ``ID[4-7]_REG`` ports, and 4
  more ``m[4-7]_axis_tdata`` outputs.
* ``ddsprod_v.sv`` goes from ``localparam N = 4`` (4 ``ddsprod`` instances) to
  ``localparam N = 8`` (8 instances), with matching ``PINC[4-7]_REG``/
  ``POFF[4-7]_REG`` ports.
* ``axis_pfb_readout_v4.v``'s top level exposes 8 AXI-Stream masters
  (``m0_axis``..``m7_axis``) instead of v3's 4, and its AXI-Lite address bus
  widens from 6 bits (``s_axi_awaddr[5:0]``) to 8 bits
  (``s_axi_awaddr[7:0]``) to fit the doubled register count (24 vs. 12).
* The underlying 64-channel PFB channelizer itself (``pfb.sv`` and everything
  it instantiates, including the ``ssrfft_8x64`` FFT core) is **unchanged**
  between v3 and v4 -- both still channelize the same 64 fixed bins from the
  same ADC input; only how many of those channels can be simultaneously
  routed out (and independently DDS-tuned) differs.

So v4 is best described as *v3 with NOUT widened from 4 to 8*, not a
repackaging with identical RTL, and not an independent redesign of the
channelizer. This matches the Python driver docstring/registration exactly
(``AxisPFBReadoutV4(AxisPFBReadoutV3)`` overrides only ``NOUT = 8``, and its
docstring says *"This is identical to AxisPFBReadoutV3, but with 8 outputs
instead of 4"*) -- a case where the Python driver's claim and the RTL diff
independently agree.

One thing this investigation could **not** determine, and does not guess at:
*why* v4 exists as a separate IP core (with its own VLNV,
``QICK:QICK:axis_pfb_readout_v4:1.0``) rather than v3 simply being
re-synthesized with a ``NOUT`` parameter -- unlike ``N`` (PFB channel count,
a real Verilog ``parameter`` on ``axis_pfb_readout_v3``/``v4``'s module
header), ``NOUT`` is a ``localparam`` hard-coded inside ``pfb_top.sv``/
``ddsprod_v.sv``, not exposed as a module parameter, so making it
configurable would have required a nontrivial refactor of the fixed-width
port lists and register maps in both files -- forking to a new top-level
(and giving it a new IP core name) was evidently the path taken instead, but
no comment or commit message read in this session confirms that reasoning.

4.2 Register Map
^^^^^^^^^^^^^^^^^

Same layout as v3, doubled: ``ID[0-7]_REG`` (16 bits each) at offsets 0-7,
then ``PINC[0-7]_REG``/``POFF[0-7]_REG`` (32 bits each) pairs at offsets
8/9, 10/11, ... 22/23 -- 24 registers total, matching
``AxisPFBReadoutV4``'s inherited ``_init_config()`` (which just runs v3's
same offset-generation loop with ``self.NOUT = 8``) and the widened 8-bit
AXI-Lite address bus in ``axis_pfb_readout_v4.v``/``axi_slv.v``.

--------------------------------------------------------------------
5. Python Interface
--------------------------------------------------------------------

5.1 ``AbsPFBReadout`` (shared base class)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``qick.drivers.readout.AbsPFBReadout(SocIP, AbsReadout)`` factors out what
all three versions have in common:

* ``B_DDS = 32`` and a fixed ``IQ_OFFSET = -0.5`` -- the driver source
  comments this as *"based on testing this seems like it might really be some
  weird value like -0.48, even though this makes no sense"*, i.e. an
  empirically-determined constant, not one derived from a specific rounding
  operation in RTL (unlike, say, ``axis_dyn_readout_v1``'s offset -- see
  :doc:`/readout_dynamic`).
* ``_init_config()`` derives ``DOWNSAMPLING = NCH // 2`` (the PFB's
  50%-overlap decimation) and ``CH_OFFSET = NCH // 2`` (the index of the PFB
  channel centered at DC), and publishes ``pfb_nch``, ``pfb_nout``,
  ``pfb_ch_offset``, ``pfb_dds_on_output`` into ``self.cfg`` for
  ``QickConfig``/``calc_ro_regs()`` to use.
* ``configure_connections()`` traces the block's ``s_axis`` input back
  through the RFDC (or, on boards with dual-ADC combiners like ZCU111/
  RFSoC4x2, through an intervening ``axis_combiner``) to determine which
  physical ADC feeds this readout.
* ``configure()`` further divides ``f_dds``/multiplies ``fdds_div`` by
  ``DOWNSAMPLING``, since the DDS's effective tuning range is reduced by both
  the RFDC's decimation and the PFB's own 50%-overlap decimation.
* ``set_ch(f, out_ch, sel='product', gen_ch=None, phase=0)`` is the
  debug-only, direct-register equivalent of ``declare_readout()`` for a PFB
  output -- not used in normal programs, same caveat as
  :meth:`.AbsReadout.set_all` on the single-tone readouts.

5.2 Version-specific subclasses
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Driver class attributes (from ``qick_lib/qick/drivers/readout.py``)
   :header-rows: 1
   :widths: 26 16 16 16 26

   * -
     - ``NCH``
     - ``NOUT``
     - ``DDS_ON_OUTPUT``
     - ``HAS_OUTSEL``
   * - ``AxisPFBReadoutV2``
     - 8 (class constant)
     - 4 (class constant)
     - ``False``
     - ``True``
   * - ``AxisPFBReadoutV3``
     - read from the bitstream's ``N`` generic (``description['parameters']['N']``)
     - 4 (class constant)
     - ``True``
     - ``False``
   * - ``AxisPFBReadoutV4``
     - inherited from V3 (bitstream generic)
     - 8 (class constant, only override vs. V3)
     - ``True`` (inherited)
     - ``False`` (inherited)

``AxisPFBReadoutV2.set_freq_int(cfg)`` writes two registers per call: the
output's ``ch%dsel_reg`` (which of the 8 channels to route) and that
channel's ``freq%d_reg`` (the DDS tuning word) -- note this *overwrites* the
shared per-channel DDS setting, so the driver's own comment warns *"it's
assumed that channel collisions have already been checked ... a collision
will break the previously set channel"* if two outputs are pointed at the
same input channel with different frequencies.

``AxisPFBReadoutV3.set_freq_int(cfg)`` validates ``pfb_ch``/``out_ch`` are
in-range, computes the ``(packet, index)`` pair for the ``ID`` register from
``pfb_ch``, and writes ``id``/``freq``/``phase`` for that output -- since the
DDS is per-output here, there's no collision risk analogous to v2's, and the
driver comment says so explicitly ("No need to check for collisions as they
are all truly independent"). ``AxisPFBReadoutV4`` inherits this method
unchanged; only ``NOUT`` differs.

.. code-block:: python
  :caption: Debug-only direct configuration of one PFB output (normally done via declare_readout())

  from qick import *

  soc = QickSoc()
  pfb = soc.readouts[i]   # an AxisPFBReadoutV3 or AxisPFBReadoutV4 instance

  # Route PFB channel 5 to output 2, demodulated at 100 MHz.
  pfb.set_ch(f=100.0, out_ch=2, sel='product')

Normal QICK programs never call ``set_ch``/``set_freq_int`` directly --
:meth:`.QickProgram.declare_readout` picks the PFB channel/output assignment
and frequency for you (via ``QickConfig.calc_ro_regs()``), exactly as
described in :doc:`/readout`'s Python Interface section for the single-tone
readouts.

.. _readout-pfb-zcu216:

--------------------------------------------------------------------
6. Real-World Usage: ZCU216 "tpv2_std"
--------------------------------------------------------------------

The flagship ZCU216 board design (``firmware/Top/216/tpv2_std/bd_2023-1.tcl``,
tracked on branch ``feature/114-integrate-hog-fusesoc``) instantiates
**one** ``axis_pfb_readout_v4_0`` (VLNV ``QICK:QICK:axis_pfb_readout_v4:1.0``)
alongside **two** ``axis_dyn_readout_v1`` instances (:doc:`/readout_dynamic`)
and **ten** ``axis_avg_buffer`` instances (:doc:`/avg_buffer`) -- tracing the
block-diagram connections (``connect_bd_intf_net``) confirms exactly how that
10 breaks down, rather than assuming it's all attributable to one core:

* ``axis_pfb_readout_v4_0`` exposes 8 outputs, ``m0_axis``..``m7_axis`` (its
  full ``NOUT=8``, confirmed by 8 separate
  ``axis_pfb_readout_v4_0_m[0-7]_axis`` nets in the .tcl). Each output feeds
  its own ``axis_broadcaster`` (``axis_broadcaster_2`` through
  ``axis_broadcaster_9``), which in turn drives its own dedicated
  ``axis_avg_buffer`` (``axis_avg_buffer_2`` through ``axis_avg_buffer_9``) --
  **8 of the 10 avg_buffers on this board are fed by the single PFB readout
  instance**, one per PFB output channel.
* The remaining 2 avg_buffers (``axis_avg_buffer_0``, ``axis_avg_buffer_1``)
  are fed the same way (via their own broadcasters,
  ``axis_broadcaster_0``/``axis_broadcaster_1``) by the two
  ``axis_dyn_readout_v1`` instances' single ``m1_axis`` outputs.

So the buffer count (10) is not a property of "how many readout instances
there are" (there are 3: 1 PFB + 2 dynamic) -- it's driven by *output ports*:
1 (per dynamic readout) x 2 + 8 (per PFB readout, its full NOUT) x 1 = 10.
This is exactly the PFB-vs-single-tone distinction from
:ref:`readout-pfb-general` above made concrete on real, currently-shipping
hardware: one PFB readout instance does the job of 8 single-tone readout +
buffer pairs, at the cost of those 8 channels sharing one fixed 64-way
channelizer (they can only demodulate PFB bins independently fine-tuned by
up to +/- half a bin, not arbitrary frequencies across the whole band
simultaneously).

The PFB readout's AXI-Lite control port (``axis_pfb_readout_v4_0/s_axi``) is
mapped in the address space at offset ``0x000400101000``, range ``0x1000``
(the .tcl's ``assign_bd_address`` call) -- a full 4 KiB page is reserved even
though the register map itself only spans 24 x 4 = 96 bytes (see
:ref:`readout-pfb-general`'s address-width comparison), consistent with the
AXI-Lite page-granularity convention used elsewhere in this address map
(not specific to the PFB readout).

--------------------------------------------------------------------
Related Documentation
--------------------------------------------------------------------

* :doc:`/readout` -- readout system overview; note its own single-tone
  framing applies to :doc:`/readout_v2` and :doc:`/readout_dynamic`, not to
  the PFB family described here.
* :doc:`/readout_v2` -- the single-tone, PYNQ-register-configured readout
  the PFB readouts are architecturally different from (one tunable
  demodulator vs. a fixed multi-channel bank).
* :doc:`/readout_dynamic` -- the tProc-configured single-tone readouts
  (``axis_readout_v3``/``axis_dyn_readout_v1``) that share the ZCU216 board
  design with ``axis_pfb_readout_v4`` (see :ref:`readout-pfb-zcu216`).
* :doc:`/avg_buffer` -- the buffer IP downstream of each PFB output; a PFB
  readout with NOUT outputs typically drives NOUT separate avg_buffer
  instances, as shown on the ZCU216.
* :doc:`topics/freq_matching` -- keeping generator and readout frequencies
  in sync.
