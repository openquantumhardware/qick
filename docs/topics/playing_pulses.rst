How to play pulses
==================

There are three steps to playing a pulse:

Loading a waveform
------------------

(You skip this step for rectangular "const" pulses, which have no envelope.)

Each signal generator has an internal waveform memory, which stores the I/Q data for the pulse envelope.
Multiple waveforms can be stored in the same signal generator, and a single waveform can be used for different pulses (e.g. a Gaussian waveform can be used for Gaussian pulses and the ramp-up/ramp-down of flat-top pulses with different flat-top duration, each with its own gain and carrier frequency).

:meth:`.AbsQickProgram.add_envelope()` writes an arbitrary waveform to the specified channel's waveform memory.
:meth:`.AbsQickProgram.add_gauss()`, :meth:`.AbsQickProgram.add_triangle()`, and :meth:`.AbsQickProgram.add_DRAG()` write commonly-used standard pulse waveforms, with duration units of fabric clock cycles. The name is used in the next step.

Setting registers
-----------------

There are a lot of parameters that need to be specified when playing a pulse - more than can be specified inline in a tProcessor instruction.
So all the parameters must be written to registers first, and when we fire the pulse we just tell the tProcessor which registers to read.

:meth:`.QickProgram.set_pulse_registers()` writes the settings for a pulse to registers.
All arguments to this method must be integers in the native units of the signal generator.
This can happen immediately before you fire the pulse, but if a signal generator is only used for one type of pulse you will save time for the tProcessor by setting registers in initialization, before the program loop.
If you have some parameters that change from pulse to pulse, and some that never change, you can write the fixed parameters in initialization using :meth:`.QickProgram.default_pulse_registers()` and the varying parameters in the body with :meth:`.QickProgram.set_pulse_registers()`.

If you want to modify pulse parameters on the fly (for example, you might want to sweep the frequency of the qubit drive pulse), you will set the registers in two steps (you can see an example in the demo :repofile:`qick_demos/02_Sweeping_variables.ipynb` ):

First, use :meth:`.QickProgram.set_pulse_registers()` to write initial values for all parameters. You could do this in initialization, or right before the following step.
Second, overwrite the register(s) you want to update.
You need to get the page and address of the register using :meth:`.QickProgram.ch_page()` and :meth:`.QickProgram.sreg()`.
Then you can use assembly instructions to change the value of that register.

Firing the pulse
----------------

:meth:`.QickProgram.pulse()` fires a pulse on the specified channel at the specified time, using whatever values are loaded in the registers.

Often you will want to trigger the readout at the same time: :meth:`.QickProgram.measure()` is a wrapper around :meth:`.QickProgram.trigger()` and :meth:`.QickProgram.pulse()`.
But it's good to remember and understand the building blocks inside this wrapper.
