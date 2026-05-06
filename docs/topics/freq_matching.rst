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
   soccfg = soc.config

   # Convert frequency for generator 0, matching to readout 0
   freq_reg = soccfg.freq2reg(100e6, gen_ch=0, ro_ch=0)

   # Or for readout, matching to generator 0
   freq_reg = soccfg.freq2reg(100e6, ro_ch=0, gen_ch=0)

**Method 2: Pre-round the frequency**

Round the frequency to the closest value that is valid on both channels:

.. code-block:: python

   # Get the nearest frequency that works for both gen_ch=0 and ro_ch=0
   matched_freq = soccfg.adcfreq(100e6, gen_ch=0, ro_ch=0)
   freq_reg = soccfg.freq2reg(matched_freq, gen_ch=0)

Trade-offs
----------

Frequency matching **reduces frequency resolution**, because the smallest step is now the least common multiple (LCM) of the two channels' frequency steps.

- Typical resolution: ~10 Hz, which is sufficient for most qubit experiments
- To disable matching (if you need finer resolution), specify `None` as the other channel:

.. code-block:: python

   # No matching - highest resolution
   freq_reg = soccfg.freq2reg(100e6, gen_ch=0, ro_ch=None)

Multiple Generators
-------------------

If you have two generators that need to be phase-locked (e.g., for qubit drive and cavity drive), both should be frequency-matched to the same readout:

.. code-block:: python

   # Match both generators to readout 0
   freq_reg_drive = soccfg.freq2reg(100e6, gen_ch=0, ro_ch=0)
   freq_reg_cavity = soccfg.freq2reg(100e6, gen_ch=1, ro_ch=0)

If they are matched to different readouts (or not matched), they will have slightly different frequencies and the phase between them will drift.

Best Practices
--------------

- In most QICK firmwares, all generators and readouts have the same sampling frequency, so matching to channel 0 works for everything.
- Make it a habit to always specify the matched channel explicitly.
- Use `soccfg.freq2reg()` consistently for all frequency conversions.

Related Documentation
---------------------

* :doc:`/sg_v6` - Signal Generator v6
* :doc:`/readout` - Readout system
* :doc:`/firmware` - Clock domains and sample rates
* :doc:`topics/changing_fs` - Custom sample rates
