tProc v2
========

tProc v2 is the latest generation of the QICK timed processor. It keeps the
same basic role as tProc v1--sequencing pulses, triggers, readout windows, and
feedback--but reorganizes both the firmware interface and the Python programming
model.

This page is a short migration guide for users who already know tProc v1 and
want to understand the most important changes before writing tProc v2 programs.


Hardware sweeping
------------------

In tProc v1 programs, hardware sweeps often required an ``update()`` method
with explicit register math. For example, a gain sweep might update the
generator gain register with ``mathi()`` after each shot:

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

tProc v2 provides higher-level sweep helpers. A program can declare a loop,
attach a swept parameter to that loop, and then query the compiled program for
the actual sweep points:

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

Common swept parameters include:

* Frequency
* Length
* Time
* Gain

For frequency, length, and gain sweeps, use ``get_pulse_param()`` to query the
compiled sweep points:

.. code-block:: python

   freqs = prog.get_pulse_param("qubit_pulse", "freq", as_array=True)
   lengths = prog.get_pulse_param("qubit_pulse", "length", as_array=True)
   gains = prog.get_pulse_param("qubit_pulse", "gain", as_array=True)

For timing sweeps, tag the timed instruction and use ``get_time_param()``:

.. code-block:: python

   times = prog.get_time_param("time_tag", "t", as_array=True)

Timing
-------

In tProc v2, pulse and trigger times are written in user-facing units, usually
microseconds. The Python API converts these values to tProc timing-clock cycles
when the program is compiled.

Some tProc v1 timing names have also changed:

* ``sync_all`` is now ``delay_auto()``.
* ``synci`` is now ``delay()``.
* ``wait_auto()`` keeps the same basic purpose, but works with the tProc v2
  timing model.


Play pulse
----------

In tProc v1, pulse parameters were often loaded into generator registers before
playing a pulse. In tProc v2, pulse settings are stored as waveforms in waveform
memory. A pulse can contain one or more waveforms, and playing a pulse sends the
corresponding waveform memory entry to the generator.

This makes it easier to define several pulses during initialization and choose
which one to play in the program body.

For example, a typical tProc v2 program does the following:

* Declare the generator and readout channels.
* Add pulse definitions in ``_initialize()``.
* Play those pulses in ``_body()`` with ``pulse()``.
* Use ``trigger()`` and acquisition methods when readout data is needed.

Units
-----

tProc v2 APIs generally use natural units:

* Times and pulse lengths are in microseconds.
* Frequencies are in MHz.
* Phases are in degrees.
* Gains are normalized values, usually from ``-1`` to ``1``.

The compiler rounds these values to the nearest supported hardware
representation. To inspect the rounded values actually used by a compiled
program, use helper methods such as ``get_pulse_param()`` and
``get_time_param()``.
