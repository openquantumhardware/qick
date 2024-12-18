Time units
==========

Time durations are generally specified in units of clock cycles.
The relevant clocks are the tProcessor clock and the fabric clocks of the generators and readouts.
In general these can all be different (and can even vary among generators or readouts).

For convenience, the :meth:`.QickConfig.us2cycles()` and :meth:`.QickConfig.cycles2us()` methods will convert between floating-point times and integer cycles.
You should be careful to specify which clock you are using, and set the appropriate parameter in :meth:`.QickConfig.us2cycles()`:

Pulse parameters (the length parameter to :meth:`.QickProgram.set_pulse_registers()`, the length and sigma parameters to :meth:`.AbsQickProgram.add_gauss()`) use the generator clock and you should specify ``gen_ch``.
Readout parameters (the length parameter to :meth:`.AbsQickProgram.declare_readout()`) use the readout clock and you should specify ``ro_ch``.
All other values will use the tProc clock. This includes ``sync`` and ``wait`` commands, and any sort of delay (``t``, ``adc_trig_offset``). Don't use a channel ID parameter.
