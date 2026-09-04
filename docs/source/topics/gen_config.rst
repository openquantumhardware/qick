Pulse configuration options 
===========================

Use ``stdysel`` to select what value is output continuously by the signal generator after the generation of a pulse.

* 0: the last calculated sample of the pulse
* 1: a zero value

Use ``mode`` to select whether the output is periodic or one-shot.  Here is what happens after generating the specified number of samples.  Look in the queue to see if there is a new waveform to generate.  If there is a new waveform in the queue, remove it from the queue and generate it.  If there is not, use the value of ``mode`` to decide what to do.

* 0:  stop
* 1:  repeat the current waveform

Then continue looking for a new waveform.

Use ``outsel`` to select the output source.  The output is complex.  Tables define envelopes for I and Q.

* 0:  product of table and DDS
* 1:  DDS
* 2:  from the table for the real part, and zeros for the imaginary part
* 3:  always zero

