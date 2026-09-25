How to ensure frequency matching
================================

Generators (SG-v6) and readouts have different frequency units because they run on different clocks (DAC clock vs ADC clock, with different sampling rates).
For coherent measurements, the upconversion frequency (DAC) and downconversion frequency (ADC) must be **exactly equal**.
If they are not, the acquired data will show a sliding phase, making it impossible to get consistent results.

Frequency Matching Methods
--------------------------

There are two ways to ensure frequency matching in QICK:

**Method 1: Match during conversion (recommended)**

When converting a frequency to an integer register value, specify both the channel you are configuring and the channel you want to frequency-match to:

.. code-block:: python

   from qick import *

   soc = QickSoc()
   soccfg = soc

   # Convert frequency for generator 0, matching to readout 0 (freq2reg takes MHz)
   freq_reg = soccfg.freq2reg(100.0, gen_ch=0, ro_ch=0)

   # Or for readout, matching to generator 0
   freq_reg = soccfg.freq2reg_adc(100.0, ro_ch=0, gen_ch=0)

**Method 2: Pre-round the frequency**

Round the frequency to the closest value that is valid on both channels:

.. code-block:: python

   # Get the nearest frequency (in MHz) that works for both gen_ch=0 and ro_ch=0
   matched_freq = soccfg.adcfreq(100.0, gen_ch=0, ro_ch=0)
   freq_reg = soccfg.freq2reg(matched_freq, gen_ch=0)

In tProc v2 programs (AveragerProgramV2)
----------------------------------------

Both sides of the pair must be matched: the pulse to the readout, and the readout to the generator.

.. code-block:: python

   self.add_pulse(ch=GEN_CH, name="p", style="const", freq=f, length=0.5,
                  phase=0, gain=0.5, ro_ch=RO_CH)        # pulse matched to the readout
   self.add_readoutconfig(ch=RO_CH, name="ro", freq=f,
                          gen_ch=GEN_CH)                  # readout matched to the generator

For a muxed generator the pulse has no ``freq``; pass ``ro_ch`` to ``declare_gen()`` instead, and ``gen_ch`` to each ``declare_readout()``.

``gen_ch`` alone is not enough. Without ``ro_ch``, ``add_pulse()`` rounds ``f`` only to the generator's own step, while ``add_readoutconfig(gen_ch=...)`` rounds it to the coarser common step. The two frequencies then differ by a few Hz: for example, on the RFSoC4x2 the generator step is 2.3 Hz, the common step 20.6 Hz, and at 100 MHz the difference is 9.2 Hz. That turns the demodulated phase once every ~0.1 s, so each run of the same program returns I/Q at a different angle, even though the phase looks stable within a run.

Rounding ``f`` first with ``soccfg.adcfreq(f, gen_ch=GEN_CH, ro_ch=RO_CH)`` works too, as long as every pulse and readout config uses that rounded value.

Trade-offs
----------

Frequency matching **reduces frequency resolution**, because the smallest step is now the least common multiple (LCM) of the two channels' frequency steps.

- Typical resolution: ~10 Hz, which is sufficient for most qubit experiments
- To disable matching (if you need finer resolution), specify `None` as the other channel:

.. code-block:: python

   # No matching - highest resolution
   freq_reg = soccfg.freq2reg(100.0, gen_ch=0, ro_ch=None)

Multiple Generators
-------------------

If you have two generators that need to be phase-locked (e.g., for qubit drive and cavity drive), both should be frequency-matched to the same readout:

.. code-block:: python

   # Match both generators to readout 0
   freq_reg_drive = soccfg.freq2reg(100.0, gen_ch=0, ro_ch=0)
   freq_reg_cavity = soccfg.freq2reg(100.0, gen_ch=1, ro_ch=0)

If they are matched to different readouts (or not matched), they will have slightly different frequencies and the phase between them will drift.

Best Practices
--------------

- In most QICK firmwares, all generators and readouts have the same sampling frequency, so matching to channel 0 works for everything.
- Make it a habit to always specify the matched channel explicitly.
- Use `soccfg.freq2reg()` for generator channels and `soccfg.freq2reg_adc()` for readout channels, always passing the other channel to match against.

Related Documentation
---------------------

* :doc:`/firmware/generators/sg_v6` - Signal Generator v6
* :doc:`/firmware/readouts/index` - Readout system
* :doc:`/firmware/index` - Clock domains and sample rates
* :doc:`changing_fs` - Custom sample rates
