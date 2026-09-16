Migrating from tProc v1
========================

.. note::
   Content originally contributed by `Jay Chien <https://github.com/JayChien04717>`_
   (`PR #412 <https://github.com/openquantumhardware/qick/pull/412>`_), adapted here
   for the current docs structure and verified against ``qick.asm_v2``.

tProc v2 keeps the same basic role as tProc v1 — sequencing pulses, triggers,
readout windows, and feedback — but reorganizes both the firmware interface and
the Python programming model. This page is a short migration guide for users
who already know tProc v1 and want to understand the most important changes
before writing tProc v2 programs. For the full picture, see :doc:`playing_pulses`,
:doc:`timing`, and :doc:`units`.

Hardware sweeps
----------------

In tProc v1 programs, hardware sweeps often required an ``update()`` method
with explicit register math. For example, a gain sweep might update the
generator's gain register with ``mathi()`` after each shot:

.. code-block:: python

   class Program(RAveragerProgram):
       def initialize(self):
           self.q_rp = self.ch_page(self.cfg["qubit_ch"])
           self.r_gain = self.sreg(self.cfg["qubit_ch"], "gain")

       def body(self):
           ...

       def update(self):
           self.mathi(self.q_rp, self.r_gain, self.r_gain, "+", self.cfg["step"])

   gain_list, avgi, avgq = prog.acquire(soc)

tProc v2 provides higher-level sweep helpers. A program declares a loop with
:meth:`~.QickProgramV2.add_loop`, attaches a swept parameter to that loop with
:func:`~.QickSweep1D`, and later queries the compiled program for the actual
sweep points:

.. code-block:: python

   class Program(AveragerProgramV2):
       def _initialize(self, cfg):
           self.add_loop("gainloop", cfg["steps"])
           self.add_pulse(
               ch=cfg["qubit_ch"],
               name="qubit_pulse",
               style="const",
               freq=cfg["freq"],
               phase=0,
               gain=QickSweep1D("gainloop", cfg["gain_start"], cfg["gain_stop"]),
               length=cfg["length"],
           )

       def _body(self, cfg):
           self.pulse(ch=cfg["qubit_ch"], name="qubit_pulse", t=0)

   iq_list = prog.acquire(soc, rounds=avg, progress=False)
   gains = prog.get_pulse_param("qubit_pulse", "gain", as_array=True)

Common swept parameters include frequency, length, time, and gain. For
frequency, length, and gain sweeps, use ``get_pulse_param()`` to query the
compiled sweep points:

.. code-block:: python

   freqs = prog.get_pulse_param("qubit_pulse", "freq", as_array=True)
   lengths = prog.get_pulse_param("qubit_pulse", "length", as_array=True)
   gains = prog.get_pulse_param("qubit_pulse", "gain", as_array=True)

For timing sweeps, tag the timed instruction (``delay``, ``delay_auto``, ...)
and use ``get_time_param()``:

.. code-block:: python

   times = prog.get_time_param("time_tag", "t", as_array=True)

Timing
------

In tProc v2, pulse and trigger times are written in user-facing units, usually
microseconds. The Python API converts these values to tProc timing-clock cycles
when the program is compiled. See :doc:`timing` for the underlying clock model.

Some tProc v1 timing calls have renamed equivalents in ``QickProgramV2``:

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - tProc v1
     - tProc v2
     - Notes
   * - ``sync_all()``
     - ``delay_auto()``
     - Advances the reference time to the end of the last pulse/readout, plus an optional margin.
   * - ``synci(t)``
     - ``delay(t)``
     - Advances the reference time by a fixed amount, independent of pulse/readout end times.
   * - (no direct v1 equivalent)
     - ``wait_auto()`` / ``wait(t)``
     - Pauses execution without moving the reference time; see :doc:`timing`.

Playing pulses
--------------

In tProc v1, pulse parameters were typically loaded into generator registers
right before playing a pulse. In tProc v2, pulse settings are stored as
waveforms in waveform memory ahead of time: a pulse can bundle one or more
waveforms, and ``pulse()`` just tells the generator which waveform-memory entry
to play. This makes it easy to define several pulses during initialization and
choose which one to play in the program body. See :doc:`playing_pulses` for the
full workflow.

A typical tProc v2 program:

* Declares the generator and readout channels (``declare_gen()``, ``declare_readout()``).
* Adds pulse definitions in ``_initialize()`` (``add_envelope()``, ``add_pulse()``).
* Plays those pulses in ``_body()`` with ``pulse()``.
* Uses ``trigger()`` and ``acquire()``/``acquire_decimated()`` when readout data is needed.

Units
-----

tProc v2 APIs generally use natural units instead of raw register values:

* Times and pulse lengths are in microseconds.
* Frequencies are in MHz.
* Phases are in degrees.
* Gains are normalized values, usually from ``-1`` to ``1``.

The compiler rounds these values to the nearest supported hardware
representation. To inspect the rounded values actually used by a compiled
program, use ``get_pulse_param()`` and ``get_time_param()``. See :doc:`units`
for the full reference.
