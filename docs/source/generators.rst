Signal Generators - QICK Firmware
==================================

.. contents::
  :local:
  :depth: 2

Overview
--------

QICK ships several signal-generator IP cores. They all connect to the
tProcessor the same way (one AXI-Stream waveform port per channel, driven
by ``WPORT_WR``/:meth:`.QickProgram.pulse`) and the same way to a DAC, but
they trade off differently between **flexibility** (arbitrary pulse shapes)
and **simultaneity** (how many tones at once). Picking the right one for a
channel is a hardware/firmware decision (which core is instantiated on that
DAC channel in your board's bitstream) -- as a user you mostly just need to
know which kind of channel you have and how to talk to it, both covered
below.

.. list-table:: Generator family at a glance
  :header-rows: 1
  :widths: 22 15 15 48

  * - Core
    - Tones
    - Envelope
    - Typical use
  * - :doc:`/sg_v6`
    - 1 (arbitrary shape)
    - Yes, full rate
    - The default choice for shaped pulses (Gaussian, DRAG, flat-top) --
      qubit drive, readout drive.
  * - :doc:`/sg_int4_v2`
    - 1 (arbitrary shape)
    - Yes, 4x-interpolated
    - Same use case as SG-v6 on boards/channels where this lighter-weight
      core is instantiated instead; has a DAC-side mixer (``HAS_MIXER``).
  * - :doc:`/sg_v4`
    - 1 (arbitrary shape)
    - Yes, full rate
    - Legacy predecessor to SG-v6; not used in any board design currently
      in this repository. Documented for driver/backward-compatibility
      reference, not for new designs.
  * - :doc:`/sg_mux8`
    - up to 8 (fixed CW)
    - No
    - Playing several simultaneous fixed tones from one channel -- e.g. a
      frequency comb, or driving several resonators/qubits at once without
      one DAC channel per tone.
  * - :doc:`/sg_mixmux8`
    - up to 8 (fixed CW)
    - No
    - Same as SG-Mux8, plus a shared DAC-side mixer so the whole comb can be
      placed anywhere (including outside the first Nyquist zone) via one
      ``mixer_freq``.

Arbitrary-envelope vs. multiplexed: which do I need?
-----------------------------------------------------

**Use an arbitrary-envelope generator** (SG-v6, SG-int4-v2, or the legacy
SG-v4) when you need to *shape* a pulse -- a Gaussian, a DRAG pulse, a
flat-top pulse with rounded edges, or any other waveform you can compute in
Python. These cores have envelope memory (BRAM) you upload I/Q samples into
with :meth:`.QickProgram.add_envelope`, and play back with an ``arb`` or
``flat_top`` pulse style. Only one tone plays at a time per channel.

**Use a multiplexed generator** (SG-Mux8 or SG-MixMux8) when you need
*several simultaneous CW tones* from one DAC channel and don't need to
shape each tone's envelope -- only its amplitude, phase, and which subset
of tones is on for how long. This is the common case for a frequency comb
or for driving multiple fixed resonances (e.g. several readout resonators)
through a single physical channel. Pick SG-MixMux8 over plain SG-Mux8 if
you need the comb somewhere the DAC's un-mixed first Nyquist zone can't
reach on its own.

If you need *both* -- multiple simultaneous tones *and* per-tone arbitrary
shaping -- no single QICK generator core does that; you need one
arbitrary-envelope channel per shaped tone.

Common Python workflow
-----------------------

Every generator in this family is configured the same way, regardless of
which core is behind a given channel: declare it once with
:meth:`.QickProgram.declare_gen`, define named pulses with
:meth:`.QickProgram.add_pulse` (and :meth:`.QickProgram.add_envelope` first,
if it needs a shape), then play them with :meth:`.QickProgram.pulse`. See
:doc:`/sg_v6`'s "Python Usage" section for worked examples (single pulse,
shaped pulse, multiple queued pulses), and :doc:`/sg_mixmux8`'s Python
section for the multiplexed-generator variant (``mux_freqs``/``mux_gains``
instead of one ``freq``/``gain`` per pulse).

Related Documentation
----------------------

* :doc:`/sg_v6` - the flagship arbitrary-envelope generator (start here)
* :doc:`/sg_int4_v2`, :doc:`/sg_v4` - other single-tone arbitrary generators
* :doc:`/sg_mux8`, :doc:`/sg_mixmux8` - multiplexed (multi-tone) generators
* :doc:`/firmware` - which generator core is on which channel, on the
  reference board
* :doc:`topics/gen_config` - shared pulse configuration options
  (``outsel``/``mode``/``stdysel``)
* :doc:`topics/freq_matching` - keeping generator and readout frequencies
  in sync
* :doc:`/readout` - the readout-side counterpart to this page
