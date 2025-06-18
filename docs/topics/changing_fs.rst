Changing sample rates
=====================

You may want to use DAC and ADC sample rates (often abbreviated as "fs") different from what's compiled into the firmware.
This may be useful for optimizing DAC output power, or for avoiding Nyquist zone boundaries of the DAC or ADC.

It is therefore possible, with limitations, to apply custom sample rates when loading firmware.
The firmware configuration (as printed by :class:`.QickConfig`, and used to convert pulse/readout frequencies to firmware units) will be updated to reflect your changes, so you should be able to use QICK as if the firmware had been compiled with your custom rates.

This feature is experimental and may have unpredictable side effects.
In particular, it is possible that large changes in sample rates will lead to instability in the firmware logic, which may have subtle effects or crash the OS completely.
It is also possible that some exotic custom firmwares might have sample rate restrictions that the QICK software doesn't adequately check for.

Limitations
-----------

* All channels in a given DAC or ADC tile share the same sample rate.
* Sample rates can only be set to certain discrete values, determined by the tile PLL.
* The minimum and maximum sample rates are subject to various constraints which depend on the RFSoC chip, the generator or readout block, and the clock distribution scheme in the firmware.
* The firmware may be designed so some tiles share a logic clock.
  If this is the case, those tiles must have their sample rates scaled by the same factor.
* The QICK software won't allow you to increase any sample rate, because the firmware logic may become unstable if run faster than originally compiled.

API
---

Use :meth:`.QickSoc.valid_sample_rates()` to list all the valid sample rates for a given tile:

>>> soc.valid_sample_rates(tiletype='dac', tile=0)
array([ 500.62222222,  501.76      ,  502.69090909,  503.46666667,
...

Use :meth:`.QickSoc.round_sample_rate()` to round a value of your choice to the nearest valid sample rate:

>>> soc.round_sample_rate(tiletype='dac', tile=0, fs_target=5000)
5017.6

If you print the firmware configuration, there is a line that lists tiles that share clocks:

>>> print(soccfg)
...
Groups of related clocks: [tProc timing clock, DAC tile 0, DAC tile 1], [ADC tile 0, ADC tile 2]
...

The optional ``dac_sample_rates`` and ``adc_sample_rates`` parameters to :class:`.QickSoc()` are used to set custom sample rates.
These parameters should be dictionaries specifying the desired sample rates.
You can omit either parameter to leave that side of the RFSoC alone; similarly you can omit individual tiles from either dictionary.

The values you supply will be rounded to valid values, but you will get an error or warning if the rounded value was too far from what you supplied.

>>> soc = QickSoc('/data/fw/2024-09-29_111_tprocv2r21_standard/qick_111.bit',
...     dac_sample_rates={0: 5017.6, 1: 5017.6},
...     adc_sample_rates={0: 3072.0, 2: 3072.0})

You might find :meth:`.QickSoc.get_sample_rates()` convenient to get the sample rates of the currently loaded firmware, in the format needed for ``dac_sample_rates`` and ``adc_sample_rates``.

>>> soc.get_sample_rates()
{'dac': {0: 6144.0, 1: 6144.0}, 'adc': {0: 4096.0, 2: 4096.0}}

