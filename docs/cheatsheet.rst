QICK software quick reference
=================================================

Quick reference
###############

.. list-table::
   :widths: 50 50
   :header-rows: 1

   * - Python calls
     -
   * - ``soc.tproc.single_write(addr=imm, data=variable)``
     - writes the value ``variable`` to the data memory address ``imm``.

.. list-table::
   :widths: 50 50
   :header-rows: 1

   * - ASM_Program calls
     -
   * - ``p.memri(p, r, imm, 'comment')``
     -  reads the data memory at the address specified by ``imm`` and writes the result into page ``p``, register ``r``.
   * - ``p.regwi(p,r,value)``
     - writes the ``value`` to page ``p``, register ``r``.
   * - ``p.bitwi(p, rDst, rSrc, operation, value)``
     - performs the bitwise ``operation`` on the contents of page ``p``, register ``rSrc`` and ``value`` and writes the result in page ``p``, register ``rDst``.  ``rSrc`` and ``rDst`` may be the same or different.
   * - ``p.bitw(p, rDst, rSrc1, operation, rSrc2``
     - performs the bitwise ``operation`` on two source registers (``rSrc1`` and ``rSrc2``) and puts the result in the destination register ``rDst``, where all three registers are on the same page ``p``.
   * - ``p.seti(channel, p, rSrc, time)``
     - takes the value at page ``p``, register ``rSrc`` and sends it to ``channel`` that the specified ``time``.
   * - ``p.label(labelName)``
     - marks this location in the program, for use by the ``loopz`` and ``condj`` commands.
   * - ``p.set(channel, p, ra, rb,rc,rd,re,time)``
     - sends the values on page ``p`` registers ``ra``, ``rb``, ``rc``, ``rd``, ``re`` to ``channel`` at ``time``. The registers ``ra`` through ``re`` contain, in order, 16-bit values of frequency, phase, address, gain, and ( ``nsamp`` , ``outsel`` , ``mode`` , ``stdysel`` ).
   * - ``p.sync(p,r)``
     - synchronizes the internal time offset to the value specified by page ``p``,register ``r``.
   * - ``p.synci(p,timeOffset)``
     - synchronizes the internal time offset by ``timeOffset``.

.. list-table::
   :widths: 50 50
   :header-rows: 1

   * - QickProgram bitwise operations
     -
   * - ``<<``
     - shifts bits left by ``value`` bits, ignores ``rSrc``
   * - ``|``
     - or
   * - ``&``
     - and
   * - ``^``
     - exclusive or
   * - ``~``
     - not ``value``, ignores ``rSrc``

tProcessor register information
###############################

The tproc contains 8 pages of 32 registers each, making 256 registers in total. Each register is 32 bits wide.

Timing
######

* Every generator contains a timed FIFO queue.
  There is only one master clock time `t_master`, which is shared by all timed queues.

  * Treat :meth:`~qick.qick_asm.QickProgram.trigger` as a generator channel, i.e. equivalent to :meth:`~qick.qick_asm.QickProgram.pulse` in terms of clocks.

* The tproc executes commands as soon as possible, meaning it has no concept of the master time (aside from wait commands, explained later).
  It only cares about what point it is at in your code.
  There is a master time offset `t_off`, which is incremented by sync commands.
  When executed by the tproc, ``trigger(t)`` and ``pulse(t)`` commands are appended to the appropriate queue with a timestamp of ``t_off + t``.

* A generator plays pulses in the order received.
  It waits to play each pulse until the previous pulse is complete and the master clock time equals (or exceeds) the command timestamp.

* ``pulse(ch,t)`` will play the pulse at ``t`` relative to the clock as defined by the sync command that has been most recently executed by the tproc, UNLESS it is delayed by a wait command (the generator can't play a pulse before the tproc executes the command) or another pulse command (the generator can't cut one pulse short to play the next one).
  In that case, it will play at time ``t`` or at the end of the wait time/previous pulse, whatever is latest.

  * To make life easier, you can just always call ``pulse(ch, t=0)``, which will just play the pulse at the next earliest possible time. Then insert simple waits between pulses using ``sync_all(t=wait_time)``.

* wait commands pause the tproc (i.e. pauses execution of commands).
  They do not affect the master time.
  Any commands lower down in your code, even if scheduled for some time (defined by the master time) during the wait period, will execute, at the earliest, immediately after the end of the wait period.

  * wait commands are necessary to use with readout/data acquisition timing management, as the tproc does not know when pulses/readout finish and you need to force it to wait for readout to finish.
    In other words, you should have a wait at the end of a loop (or the tproc will tell the software to read data from the buffer too soon), or before a ``read`` command (e.g. for feedback).
    `This is the only reason to use wait commands.`

  * ``waiti(t)`` is the generic form of wait, which pauses the tproc until the master clock time equals ``t_off + t``. Note ``waiti`` has a channel argument, but the channel argument does nothing!

  * :meth:`~qick.qick_asm.QickProgram.wait_all` calculates the end of all readout pulses and waits until that time + ``t``.

* sync commands increment the master time offset (used by all gen channels).
  The effect is to push back the play time of subsequent commands by that increment.

  * ``sync_i(t)`` is the generic form of sync.

  * The safer version :meth:`~qick.qick_asm.QickProgram.sync_all` calculates the end of the last pulse played + ``t``, and sets the master time offset to that value.



Signal generator options
########################

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
