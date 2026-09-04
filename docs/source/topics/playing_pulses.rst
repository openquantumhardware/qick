How to play pulses with QICK
============================

.. note::
  Earlier revisions of this page built every example around raw
  ``WPORT_WR`` assembly, a fictional ``tproc.load_wave()``/
  ``gen.load_waveform()``/``gen.set_pulse()`` API, and claimed
  :meth:`.QickProgram.pulse` "is designed for the older tProc v1 API" --
  the opposite is true: :meth:`.QickProgram.pulse` (specifically
  :meth:`.QickProgramV2.pulse`) *is* the current, recommended way to play a
  pulse on tProc v2, and every other page in this doc set uses it. This
  page was rewritten to match, verified against ``qick.qick_asm``/
  ``qick.asm_v2`` in the same session that found the problem.

With the tProcessor v2 and Signal Generator v6 (or any of QICK's other
generator cores -- see :doc:`/generators`), playing a pulse involves three
steps, all done through a :class:`.QickProgram` subclass:

.. contents::
   :local:
   :depth: 2

Overview
--------

1. **Declare the generator** (once, in ``_initialize()``) -- see
   :meth:`.QickProgram.declare_gen`.
2. **Load an envelope** (optional -- skip for rectangular "const" pulses)
   and **define the pulse**, giving it a name -- see
   :meth:`.QickProgram.add_envelope` and :meth:`.QickProgram.add_pulse`.
3. **Play it by name at a chosen time** -- see :meth:`.QickProgram.pulse`.

Step 1: Loading a waveform envelope
------------------------------------

(You skip this step for rectangular "const" pulses, which have no envelope.)

Each generator with envelope memory (SG-v6, SG-v4, SG-int4-v2 -- not the
multiplexed SG-Mux8/SG-MixMux8 cores, which play fixed tones instead; see
:doc:`/generators`) stores I/Q envelope data internally. Multiple envelopes
can be stored per generator, and one envelope can be reused across several
pulses (e.g. a Gaussian shape reused for pulses at different frequencies).

Upload envelope samples with :meth:`.QickProgram.add_envelope`, or use one
of the built-in shape generators that call it for you:

.. code-block:: python

   from qick import *

   class MyProgram(AveragerProgramV2):
       def _initialize(self, cfg):
           self.declare_gen(ch=0, nqz=1)

           # Option A: build the envelope yourself and register it
           import numpy as np
           n_samples = 1024
           sigma = n_samples / 6
           idata = 30000 * np.exp(-0.5 * ((np.arange(n_samples) - n_samples/2) / sigma)**2)
           self.add_envelope(ch=0, name="my_gauss", idata=idata.astype(np.int16))

           # Option B: use a built-in shape helper (equivalent to the above)
           self.add_gauss(ch=0, name="my_gauss2", sigma=0.05, length=0.3)

**Built-in envelope shape helpers** (all call ``add_envelope`` internally):

- :meth:`.AbsQickProgram.add_gauss` - Gaussian pulse
- :meth:`.AbsQickProgram.add_triangle` - Triangular pulse
- :meth:`.AbsQickProgram.add_cosine` - Raised-cosine pulse
- :meth:`.AbsQickProgram.add_DRAG` - DRAG pulse for qubit control
- :meth:`.AbsQickProgram.add_envelope` - Custom arbitrary waveform (used above)

Step 2: Defining the pulse
---------------------------

Pulse parameters (frequency, phase, gain, length, envelope, output style)
are set with :meth:`.QickProgram.add_pulse`, which registers a named pulse
you'll play later. The available parameters depend on ``style``:

.. code-block:: python

   # A rectangular pulse -- no envelope needed
   self.add_pulse(ch=0, name="square", style="const",
                   freq=100.0, phase=0, gain=0.5, length=1.0)  # MHz, deg, -1..1, us

   # A shaped pulse, using an envelope registered in Step 1
   self.add_pulse(ch=0, name="shaped", style="arb",
                   freq=100.0, phase=0, gain=0.9, envelope="my_gauss")

   # A flat-top pulse: an envelope for the rise/fall, flat in between
   self.add_pulse(ch=0, name="flattop", style="flat_top",
                   freq=100.0, phase=0, gain=0.7, length=0.5, envelope="my_gauss")

**Dynamic parameter sweeps** (e.g. frequency) don't need a hand-written
loop that rewrites registers each iteration -- pass a :func:`.QickSweep1D`
as the parameter value and use :meth:`.QickProgram.add_loop`:

.. code-block:: python

   self.add_loop("freq_loop", 100)
   self.add_pulse(ch=0, name="chirp", style="const",
                   freq=QickSweep1D("freq_loop", 50.0, 150.0),
                   phase=0, gain=0.5, length=0.1)

See :doc:`/tprocv2_trm`'s Chapter 13 for a complete sweep example, and
:doc:`/tprocv2_trm` for what ``add_pulse``/``pulse`` compile down to under
the hood (the 168-bit ``r_wave`` bus and ``WPORT_WR`` instruction), if you
need that level of detail.

Step 3: Firing the pulse
-------------------------

:meth:`.QickProgram.pulse` schedules a named pulse (defined in Step 2) to
play at a given time, relative to the current shot:

.. code-block:: python

   def _body(self, cfg):
       self.pulse(ch=0, name="square", t=0)

**Triggering a readout at the same time as a pulse** -- pass both to the
same or a separate :meth:`.QickProgramV2.trigger` call at the matching time
(see :doc:`/readout`'s Python Interface section for the full
``declare_readout``/``trigger``/``acquire`` workflow):

.. code-block:: python

   def _body(self, cfg):
       self.trigger(ros=[0], t=0)
       self.pulse(ch=0, name="square", t=0)

**Running the program** (this is what actually drives
``tproc.time_reset()``/``tproc.start()`` for you):

.. code-block:: python

   prog = MyProgram(soccfg, reps=1000, final_delay=10.0, cfg={})
   iq = prog.acquire(soc)

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - tProcessor v2 instruction set and register-level detail
* :doc:`/generators` - Which generator cores support envelopes vs. fixed tones
* :doc:`/sg_v6` - Signal Generator v6 documentation, with more worked examples
* :doc:`/readout` - Declaring and triggering a readout alongside a pulse
* :doc:`/firmware` - Channel assignments and firmware overview
* :doc:`tutorials` - tProc v2 tutorial examples
