Timing
======

* Every generator contains a timed FIFO queue.
  There is only one master clock time `t_master`, which is shared by all timed queues.

  * Treat :meth:`.QickProgram.trigger` as a generator channel, i.e. equivalent to :meth:`.QickProgram.pulse` in terms of clocks.

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

  * :meth:`.QickProgram.wait_all` calculates the end of all readout pulses and waits until that time + ``t``.

* sync commands increment the master time offset (used by all gen channels).
  The effect is to push back the play time of subsequent commands by that increment.

  * ``sync_i(t)`` is the generic form of sync.

  * The safer version :meth:`.QickProgram.sync_all` calculates the end of the last pulse played + ``t``, and sets the master time offset to that value.

