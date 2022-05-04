QICK software quick reference
=================================================

Quick reference
########

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
########

The tproc contains 8 pages of 32 registers each, making 256 registers in total. Each register is 32 bits wide.

Signal generator options
########

Use ``stdysel`` to select what value is output continuously by the signal generator after the generation of a pulse.

* 0: the last calculated sample of the pulse
* 1: a zero value

Use ``mode`` to select whether the output is periodic or one-shot.  Here is what happens after generating the specified number of samples.  Look in the queue to see if there is a new waveform to generate.  If there is a new waveform in the queue, remove it from the queue and generate it.  If there is not, use the value of ``mode`` to decide what to do.

* 0:  stop
* 1:  generate the current waveform

Then continue looking for a new waveform.

Use ``outsel`` to select the output source.  The output is complex.  Tables define envelopes for I and Q.

* 0:  product of table and DDS
* 1:  DDS
* 2:  from the table for the real part, and zeros for the imaginary part
* 3:  always zero