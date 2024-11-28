How to ensure frequency matching
================================

Generators and readouts have different frequency units, and the frequencies used in the two systems must be exactly equal.
If they are not, there will be a small difference between the upconversion and downconversion frequencies - this will manifest as a sliding phase, and so you will not see a consistent phase between acquisitions.

There are two ways to ensure frequency matching:

* When converting a frequency to an integer value (often with :meth:`.QickConfig.freq2reg()` or :meth:`.AbsQickProgram.declare_readout()`), specify not only the channel you are configuring, but the channel you want to be frequency-matched to.
* Before doing any conversion, round the frequency to the closest frequency that is valid on both channels using :meth:`.QickConfig.adcfreq()`.

Frequency-matching makes your frequency resolution worse, since the smallest possible frequency step is now the LCM of the two channels' frequency steps.
Usually this doesn't matter - O(10 Hz) resolution is ample for most applications - but you can disable frequency-matching by specifying None as the other channel.

You may have a generator that does not itself drive any readouts, but needs to be phase-locked to a generator that does.
In this case you will want to frequency-match both generators to that readout, otherwise the two generators will have slightly different frequencies and you will have a sliding phase between them.

If you have multiple generators (or readouts) of the same type and sampling frequency, it doesn't matter which you use to specify the matched channel.
In many QICK firmwares, all generator and readout channels are the same and it's OK to just use ch 0 for the matched channel.
But it's a good habit to do this consistently correctly.
