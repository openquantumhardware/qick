Accumulated vs. decimated readout
==================================

Every QICK program that reads data back uses one of two acquisition modes, exposed
by :class:`.AcquireMixin` (mixed into :class:`.AveragerProgramV2` and the older
tProc v1 averager classes) as two mutually exclusive methods:

* :meth:`.AcquireMixin.acquire` -- **accumulated** readout.
* :meth:`.AcquireMixin.acquire_decimated` -- **decimated** readout.

They read the same hardware trigger and window, but the readout IP integrates the
samples differently before they ever reach software, and the two methods return
data with different shapes for different purposes. You call one or the other, not
both, for a given run of the tProc program (though you can compile a program once
and call `acquire`/`acquire_decimated` on different runs of it, as long as you
haven't changed the number of readout windows).

Accumulated (``acquire``)
--------------------------

The averager readout (``axis_avg_buffer``/``mr_buffer_et``, depending on channel)
integrates every sample in the readout window in hardware, producing a single
complex (I, Q) point per trigger. ``acquire()`` collects one such point per shot,
per declared readout channel, and returns it averaged over reps (and, if
``rounds>1``, over software rounds too):

* Use this for the vast majority of experiments: anything where you care about
  *one number per shot* -- a qubit state population, a resonator response at one
  frequency, an S-parameter point.
* Supports software thresholding (``threshold``/``angle``) to convert the
  averaged I/Q point into single-shot 0/1 classification before averaging --
  see :meth:`.AcquireMixin.get_shots`.
* Returns much less data than decimated mode, so it comfortably supports large
  sweeps (many reps x many expts).
* Raw (pre-averaging, pre-length-normalization) accumulated data is available via
  :meth:`.AcquireMixin.get_raw`; per-round data via :meth:`.AcquireMixin.get_rounds`.

Decimated (``acquire_decimated``)
-----------------------------------

The decimating readout streams out the *time-domain* I/Q waveform of the readout
window itself (after the readout's own decimation stage, not the raw ADC rate --
see :doc:`/firmware` for the DDC/decimation chain), instead of a single integrated
point.

* Use this to look at the readout waveform directly: verifying that your readout
  window lines up with the pulse you expect to measure, debugging a bad envelope
  or gain setting, or eyeballing a resonator ringdown.
* Returns one waveform per shot per readout trigger -- much larger than
  accumulated mode. Buffer memory limits how much you can capture at once (see
  the ``buf_maxlen`` check in the method's ``RuntimeError`` if you request too
  much); it is not meant for large parameter sweeps.
* No thresholding option -- thresholding operates on the single accumulated
  point, which decimated mode doesn't produce.
* Pair with :meth:`.AcquireMixin.get_time_axis` to get a time axis (in us) for
  plotting.

Common setup
------------

Both methods require the acquisition to be described first, via
:meth:`.AcquireMixin.setup_acquire` (which needs the tProc counter address and
the loop dimensions -- see :meth:`.AcquireMixin.setup_counter` for the subset of
that needed if you have no readouts at all, e.g. a pure-generator program you
still want a progress bar for). Both accept the same ``rounds``, ``start_src``,
``remove_offset``, and ``step_rounds`` arguments; ``step_rounds=True`` in either
case hands control of the round-by-round loop to your own code via
``prepare_round()``/``finish_round()``/``finish_acquire()``, if you need to
interleave other work between rounds.

.. list-table::
  :header-rows: 1
  :widths: 25 35 40

  * -
    - ``acquire()``
    - ``acquire_decimated()``
  * - Data per shot
    - one (I, Q) point per readout
    - one (I, Q) waveform per readout
  * - Typical use
    - experiments, sweeps
    - debugging readout windows/pulses
  * - Thresholding
    - yes (``threshold``/``angle``)
    - no
  * - Data volume
    - small
    - large -- watch buffer limits

See also
--------

* :doc:`/readout` -- the readout hardware itself (DDC, decimation, buffers).
* :doc:`timing` -- how readout windows relate to the tProc's timed queues.
* :doc:`freq_matching` -- keeping generator and readout frequencies in sync.
