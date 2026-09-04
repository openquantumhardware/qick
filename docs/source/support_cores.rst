========================================================
Support & Utility Cores - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

The three cores on this page -- **axis_constant_iq**, **axis_set_reg**, and
**axis_streamer** -- are small, single-purpose utility blocks that live under
``firmware/ip/`` alongside the readout and signal-generator families but
don't belong to either one. Each is 1-7 RTL files, so rather than a
full page per core (as :doc:`/readout_v2`, :doc:`/sg_v6`, etc. get), they
share this one page, one section each.

.. _support-constant-iq:

------------------------------------------------------------------------
1. axis_constant_iq
------------------------------------------------------------------------

1.1 General Description
^^^^^^^^^^^^^^^^^^^^^^^^

**axis_constant_iq** (``firmware/ip/axis_constant_iq/``, top module
``axis_constant_iq.sv``) is the simplest signal source in QICK: it holds one
constant, software-written complex (I, Q) value and streams it out on
``m_axis`` forever, once armed. As the Python driver's docstring puts it, it
"plays a constant IQ value, which gets mixed with the DAC's built-in
oscillator" -- the block itself has **no DDS and no envelope memory**. All of
the RF frequency content comes from the RFDC's own digital upconverter
(configured through :meth:`.AbsSignalGen.set_mixer_freq`, inherited by this
driver); ``axis_constant_iq`` only supplies the static baseband amplitude/
phase that gets mixed up to that frequency.

This is a deliberate contrast with the two arbitrary/multiplexed generator
families already documented:

* :doc:`/sg_v6` synthesizes a shaped, arbitrary envelope from a DDS + BRAM
  waveform engine, sequenced pulse-by-pulse by tProc-issued descriptors.
* :doc:`/sg_mux8` has no envelope memory either, but does have its own
  per-tone DDS (up to 8 simultaneous tones), and is still sequenced by the
  tProcessor (a streamed mask + duration selects which tones play, when).

``axis_constant_iq`` has neither an internal DDS nor a connection to the
tProcessor's timed-pulse mechanism at all -- there is no ``s_axis`` pulse
input on this block's port list. It is a pure "set and forget" AXI-Lite
block: software writes an I/Q value once (or occasionally), and the DAC
continuously outputs it until the next write.

Internally, ``axis_constant_iq.sv`` instantiates two small support blocks
also under ``src/``:

* ``axil_slv.sv`` -- a generic, reusable AXI4-Lite register-file slave
  (parametrized address/data width and register count). The same block is
  reused, independently instantiated, by :ref:`axis_streamer <support-streamer>`
  below.
* ``sync_nxm.sv`` -- a small parametrized (N-stage, M-bit) synchronizer,
  used here to cross the single-bit ``WE_REG`` "commit" strobe from the
  AXI-Lite clock domain (``s_axi_aclk``) into the sample-stream clock domain
  (``m_axis_aclk``).

Two other files in ``src/`` (``axi4_lite_if.sv``, ``axi4_stream_if.sv``) are
SystemVerilog verification interfaces (their headers describe them as
testbench-oriented, SVUnit-style protocol tasks) -- they are not instantiated
anywhere in ``axis_constant_iq.sv``'s actual datapath.

**Update sequencing.** Software writes the new I and Q values to
``REAL_REG``/``IMAG_REG``, then pulses ``WE_REG`` (write 1, then write 0).
On the ``m_axis_aclk`` side, the synchronized ``we`` signal is edge-detected
(``we_int = ~we_r & we``); on that one-cycle pulse, ``real_r``/``imag_r`` are
loaded from the register values and ``m_axis_tvalid`` latches high for good.
From then on ``m_axis_tdata`` continuously presents ``{imag_r, real_r}``,
identically replicated across all ``NUM_CHANNELS`` parallel output lanes, and
``m_axis_tlast`` is tied to 0 -- this is a genuinely unframed, continuous
stream, never packetized.

1.2 Parameters and Register Map
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Synthesis parameters
   :header-rows: 1
   :widths: 20 15 55

   * - Parameter
     - Default
     - Description
   * - ``IQ_WIDTH``
     - 16
     - Bit width of each of the I and Q components.
   * - ``NUM_CHANNELS``
     - 4
     - Number of identical, parallel ``{Q,I}`` output lanes packed into
       ``m_axis_tdata`` (``2*IQ_WIDTH*NUM_CHANNELS`` bits wide total). All
       lanes always carry the same value -- there is no per-lane
       configuration.

Registers are exposed through the generic ``axil_slv`` block with
``AXI_DW=32``, ``AXI_AW=6``, ``NUM_REGS=4`` -- 4 word-aligned, 32-bit
registers at byte offsets ``0x00``-``0x0C``:

.. list-table:: Register map (word index, byte offset)
   :header-rows: 1
   :widths: 18 12 12 15 43

   * - Register
     - Index
     - Offset
     - Width
     - Description
   * - ``REAL_REG``
     - 0
     - 0x00
     - ``IQ_WIDTH`` bits (signed), low bits of the 32-bit word
     - I component, latched into ``real_r`` on the next ``WE_REG`` strobe.
   * - ``IMAG_REG``
     - 1
     - 0x04
     - ``IQ_WIDTH`` bits (signed), low bits of the 32-bit word
     - Q component, latched into ``imag_r`` on the next ``WE_REG`` strobe.
   * - ``WE_REG``
     - 2
     - 0x08
     - bit ``[0]``
     - Write-enable/commit strobe. Edge-detected in the ``m_axis_aclk``
       domain, so software must write 1 then 0 to commit a new I/Q value.
   * - (reserved)
     - 3
     - 0x0C
     - --
     - Tied to 0 in the RTL (``slv_regs_i[3] = '0``); unused.

1.3 Python Interface
^^^^^^^^^^^^^^^^^^^^^

``axis_constant_iq`` is exposed through
``qick.drivers.generator.AxisConstantIQ``, a subclass of
:class:`.AbsSignalGen` (``bindto = ['user.org:user:axis_constant_iq:1.0',
'QICK:QICK:axis_constant_iq:1.0']``, ``HAS_MIXER = True``). Its
``REGISTERS`` dict maps directly onto the word indices above (``real_reg:
0, imag_reg: 1, we_reg: 2``).

.. code-block:: python

  from qick import *

  soc = QickSoc()
  gen = soc.ci_gens[0]   # AxisConstantIQ instance for this channel

  gen.set_nyquist(2)               # inherited from AbsSignalGen
  gen.set_mixer_freq(500.0)        # MHz -- picks the actual output frequency
  gen.set_iq(i=1.0, q=0.0)         # normalized signed gain, -1..1

``set_iq(i, q)`` scales the normalized ``(i, q)`` gains (range -1 to 1) by
``MAXV = 2**15-2`` into ``np.int16`` values, writes them to
``real_reg``/``imag_reg``, and calls ``update()``, which performs exactly the
1-then-0 write to ``we_reg`` that the RTL's edge detector expects. On
firmware init (``_init_firmware()``), the driver defaults both registers to
``MAXV`` (full-scale) and commits that value immediately.

Because this generator is never sequenced by the tProcessor, the
:meth:`.AbsSignalGen.set_nyquist` and :meth:`.AbsSignalGen.set_mixer_freq`
methods it inherits must be called directly by the user -- their docstrings
note this explicitly ("You should normally only call this method directly
for a constant-IQ output"), since for tProc-controlled generators these are
normally invoked automatically as part of program configuration.

------------------------------------------------------------------------
2. axis_set_reg
------------------------------------------------------------------------

2.1 General Description
^^^^^^^^^^^^^^^^^^^^^^^^

**axis_set_reg** (``firmware/ip/axis_set_reg/src/axis_set_reg.sv``) is a
single-file, single-clock-domain "capture and hold" register. Its own header
comment describes it plainly: *"Simple register that captures AXI-Stream
slave data when tvalid is high."* There is no AXI-Lite interface and no
master AXI-Stream output -- just an AXI-Stream slave input (``s_axis_*``)
and a plain ``dout`` output port, ``DATA_WIDTH`` bits wide (default 16, per
``component.xml``).

The RTL logic is exactly as small as it sounds:

* On every rising edge of ``s_axis_aclk``, if ``s_axis_tvalid`` is high,
  ``dout_r <= s_axis_tdata``; otherwise ``dout_r`` retains its previous
  value.
* ``s_axis_tready`` is tied permanently to 1 -- the block never
  back-pressures its master.
* ``dout`` is just ``dout_r``, combinationally.
* ``s_axis_tstrb``/``s_axis_tlast`` are present on the port list "for
  completeness" (per the header comment) but are not used anywhere in the
  RTL body.

In effect, this block turns a **transient** AXI-Stream beat (valid for one
clock, whenever its master chooses to push one) into a **stable, level-held**
output that persists until the next beat overwrites it.

2.2 Role in the tProc v1 output chain
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There is **no dedicated Python driver class** for ``axis_set_reg`` -- a
search of every driver module under ``qick_lib/qick/drivers/`` turns up no
``SocIP`` subclass with a ``bindto`` matching it. The block is referenced
only by its type-name string, ``"axis_set_reg"``, purely at the
hardware-metadata / connectivity-tracing level, in two places:

* ``qick_lib/qick/ip.py``, ``HardwareMetadata.trace_trigger()`` (around line
  491-514): when this method resolves which tProc port/bit ultimately
  triggers a given buffer, and the block driving that trigger is a
  ``vect2bits``/``qick_vec2bit`` bit-splitter, it follows that splitter's
  ``din`` input back one more hop. If *that* upstream block's type is
  ``axis_set_reg``, it follows one further hop through the ``axis_set_reg``'s
  own ``s_axis`` input to reach the real originating tProc output port. The
  code's own comment spells out the three topologies it has to distinguish,
  one of which is exactly::

      # tproc v1 output port -> axis_set_reg -> vect2bits -> buffer
      # tproc v2 data port -> vect2bits -> buffer
      # tproc v3 trigger port -> buffer

* ``qick_lib/qick/drivers/tproc.py``,
  ``AxisTProc64x32_x8.configure_connections()`` (around line 130-148): while
  enumerating tProc v1's 8 output ports (``m1_axis``..``m8_axis``; port 0 is
  reserved for the DMA), for each output found connected to an
  ``axis_set_reg``, the code traces that ``axis_set_reg``'s ``dout`` signal
  onward and inspects its individual bit taps (``dout0``..``dout15``) to see
  whether any of them fan out directly to a top-level FPGA pin. Any pin found
  this way is recorded in ``cfg['output_pins']``.

Combining what the RTL actually does with what these two call sites are
looking for (as far as is verifiable from source, without an actual built
design's HWH file to inspect): ``axis_set_reg`` sits between a tProc v1
output port and a downstream ``vect2bits`` bit-splitter (or, in some
designs, drives FPGA output pins directly). A tProc v1 output-port write is
a single-beat AXI-Stream transaction -- transient by nature. ``axis_set_reg``
captures that value and holds it as a stable level on ``dout``, which
``vect2bits`` then decomposes into individual, level-held bits -- used, for
example, to hold a buffer's trigger input high, or to drive a digital output
pin, in between tProc writes. The three-way comment in ``ip.py`` also makes
clear this ``axis_set_reg`` step is specific to tProc v1: tProc v2 drives
``vect2bits`` directly from a data port (no intervening register), and
tProc v3 has dedicated trigger ports that go straight to a buffer.

**There is no Python API for this block**, and none is needed for its role:
the metadata layer (``qick.ip``/``qick.drivers.tproc``) discovers the
connectivity automatically, by block type name, when the overlay is loaded --
not through a per-block PYNQ register driver. A QICK user does not interact
with ``axis_set_reg`` directly; they program tProc v1 output-port writes, and
the hardware-metadata tracer figures out which trigger or pin those writes
end up driving.

.. _support-streamer:

------------------------------------------------------------------------
3. axis_streamer
------------------------------------------------------------------------

3.1 General Description
^^^^^^^^^^^^^^^^^^^^^^^^

**axis_streamer** (``firmware/ip/axis_streamer/``) is, per its own header
comment, *"AXI4-Stream buffer with an AXI4-Lite control interface, for DMA
readout of a captured stream."* The top module (``axis_streamer.sv``) wraps
two pieces:

* ``axil_slv.sv`` -- the same generic AXI4-Lite register-file block used by
  :ref:`axis_constant_iq <support-constant-iq>` above (independently
  instantiated here, not shared logic).
* ``streamer.sv`` -- the actual datapath core.

``streamer.sv`` captures an input AXI-Stream (``s_axis``, the "s" clock
domain) into a dual-clock asynchronous FIFO (``fifo_async.sv``, built on a
Xilinx ``xpm_fifo_async`` primitive), and re-emits it on a separate output
AXI-Stream (``m_axis``, the "m" clock domain) in fixed-size packets of
``nsamp_reg`` beats, each terminated by ``tlast``. Its header comment states
the intended use case explicitly: a free-running, un-stallable source (e.g.
an ADC feeding this block) on the input side, and a DMA draining the output
side.

**Clock-domain crossing.** The FIFO itself (an XPM async FIFO) carries the
actual sample data across domains. Every control/status signal that also
needs to cross is individually resynchronized through
``cdc_bit_sync.sv`` (a parametrized N-stage bit synchronizer, 2 stages by
default): ``start_reg`` into the m domain, ``flush_reg`` into the m domain,
the run-state handshake in both directions, and each of the 6 ``STATUS``
bits individually into the AXI-Lite domain. The RTL comments are explicit
that these are deliberately **not coherent as a group** -- each bit/signal
is only individually meaningful, which is why the register interface exposes
decoded status flags rather than a raw FSM state.

**Control FSM** (``streamer.sv``): ``IDLE_ST -> RUN_ST -> WAIT_END_ST ->
END_ST``, gated by ``start_reg`` (a level, not a pulse -- dropping it while
running ends the run) and ``mode_reg`` (0 = one-shot: stop after one packet;
1 = continuous: back-to-back packets). ``flush_reg`` controls what happens to
a partial packet when the run ends: 1 drains it (final beat carries
``tlast``), 0 discards it (though a beat already presented on the bus is
still allowed to complete its handshake -- the RTL comments call this out as
a deliberate deviation from an earlier implementation, to stay AXI-legal).

**Backpressure.** ``s_axis_tready = ~fifo_full``, deliberately *not* gated by
run state -- the header comment describes the block as "a passive tap" that
must never stall its producer. Beats offered while the block is idle are
silently dropped and are **not** counted toward ``lost_reg`` (only beats
dropped while actually running are).

**What ``LOST``/``OVERFLOW`` actually count.** ``lost_reg`` counts *cycles*
in the s-domain during a run where the source offered a beat while the FIFO
was full -- not distinct beats. The RTL comments are careful to note this
only equals "samples dropped" for a source that cannot be stalled (like a
free-running ADC feeding a DMA); for a well-behaved AXI-Stream master that
holds ``tvalid`` across a stall, the same beat is counted repeatedly and
nothing is actually lost -- in that configuration the counter measures
backpressure, not loss.

3.2 Register Map
^^^^^^^^^^^^^^^^^

Registers are exposed through ``axil_slv`` with ``AXI_DW=32``, ``AXI_AW=6``,
``NUM_REGS=6``. The map below is taken directly from ``axis_streamer.sv``'s
own header comment, which documents it explicitly:

.. list-table:: Register map (byte-addressed, 32-bit registers)
   :header-rows: 1
   :widths: 15 12 10 15 48

   * - Register
     - Offset
     - R/W
     - Width
     - Description
   * - ``START``
     - 0x00
     - RW
     - bit ``[0]``
     - Block enable. LEVEL, not a pulse.
   * - ``FLUSH``
     - 0x04
     - RW
     - bit ``[0]``
     - 1 = drain a partial packet with ``tlast`` on stop; 0 = discard it.
   * - ``MODE``
     - 0x08
     - RW
     - bit ``[0]``
     - 0 = one-shot; 1 = continuous.
   * - ``NSAMP``
     - 0x0C
     - RW
     - ``[31:0]``
     - Beats per packet. 0 keeps the block idle.
   * - ``LOST``
     - 0x10
     - RO
     - ``[31:0]``
     - Beats dropped while running, latched when the block stops.
   * - ``STATUS``
     - 0x14
     - RO
     - ``[5:0]``
     - See status bits below.

.. list-table:: STATUS bits
   :header-rows: 1
   :widths: 10 20 70

   * - Bit
     - Name
     - Meaning
   * - 0
     - ``RUNNING``
     - The core is capturing and streaming.
   * - 1
     - ``DONE``
     - One-shot packet finished; clear ``START`` to return to idle.
   * - 2
     - ``IDLE``
     - Safe to reconfigure; ``LOST`` holds the last run's count.
   * - 3
     - ``OVERFLOW``
     - Sticky: samples were lost during this or the last run. Cleared
       automatically when a new run starts.
   * - 4
     - ``FIFO_FULL``
     - Instantaneous, diagnostic only.
   * - 5
     - ``FIFO_EMPTY``
     - Instantaneous, diagnostic only.

The header comment also documents the intended software sequence: write
``NSAMP``/``MODE``/``FLUSH`` only while ``STATUS.IDLE`` is set; write
``START=1``; wait for ``tlast`` (one-shot) or run until you choose to stop
(continuous); write ``START=0``; then **poll** ``STATUS.IDLE`` before
reading ``LOST`` -- stopping is not instantaneous, since ``START`` crosses
several flops, so the core keeps streaming for a few cycles after the write
retires.

3.3 Python Interface -- is ``DataStreamer`` the driver?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**No.** This is worth stating explicitly, because the name similarity is
misleading and the relationship is not 1:1.

Verified by searching every driver module under ``qick_lib/qick/drivers/``
(``generator.py``, ``readout.py``, ``tproc.py``, ``peripherals.py``,
``xcom.py``): none of them defines a ``SocIP``/``DummyIP`` subclass with a
``bindto`` referencing ``axis_streamer``. The only Python artifact anywhere
under ``qick_lib`` that carries the ``axis_streamer`` name is
``qick_lib/qick/rdl_pkgs/axis_streamer_regmap_pkg/`` -- an auto-generated
PeakRDL register-model wrapper (``reg_model/``, ``sim/``, ``tests/``),
generated from an RDL register-map source elsewhere in the repo. That is a
register-level Python model intended for RTL simulation/testbench use (it
ships with its own ``SimTestCase``/``TestCase`` classes), not a PYNQ overlay
driver wired into ``QickSoc``. A repo-wide search also found no reference to
``axis_streamer`` in ``qick_lib/qick/soc.py`` or in any board block-design
file -- so, as far as this repository shows, the core doesn't currently
appear wired into a shipped QICK board bitstream either.

``qick.streamer.DataStreamer`` (``qick_lib/qick/streamer.py``) is a
completely different, higher-level, **purely software** abstraction: a
background Python ``Thread`` that repeatedly calls ``soc.get_tproc_counter()``
and ``soc.get_accumulated()`` to pull already-accumulated I/Q points out of
the averaging buffer (:doc:`/avg_buffer`) while a tProc program runs,
queuing the results for the main thread to consume via ``poll_data()``. It
never touches an MMIO register map and never references any of
``axis_streamer``'s ``START``/``FLUSH``/``MODE``/``NSAMP``/``LOST``/
``STATUS`` registers -- its "streaming" is a software polling loop layered
on top of :doc:`/avg_buffer` and the tProcessor's shot counter, with no
dependency on the ``axis_streamer`` IP block at all.

So: as verified in this codebase, ``axis_streamer`` currently has no
register-level Python counterpart beyond the auto-generated simulation
register model, and ``DataStreamer`` is not that counterpart -- it solves an
unrelated, software-side data-collection problem that happens to share the
word "stream." Driving ``axis_streamer`` from Python today would require
writing a new ``SocIP`` subclass, following the pattern used by
:ref:`axis_constant_iq <support-constant-iq>` above or the readout/generator
drivers.

Related Documentation
----------------------

* :doc:`/sg_v6` -- arbitrary-envelope signal generator; contrast with
  ``axis_constant_iq``'s lack of any DDS or envelope memory.
* :doc:`/sg_mux8` -- fixed-tone multiplexed generator; also contrasted with
  ``axis_constant_iq`` above.
* :doc:`/avg_buffer` -- the buffer that :class:`.DataStreamer` actually
  polls, as opposed to ``axis_streamer``.
* :doc:`/readout_dynamic` -- another block whose Python-side object is
  constructed manually rather than through the normal PYNQ overlay-scan
  mechanism, for comparison with ``axis_set_reg``'s pure metadata-tracing
  role.
