tProc v2 ASM Cheatsheet
=======================

This cheatsheet is for the **tProcessor v2** (64-bit instructions, 32-bit registers).
For the complete reference manual, see :doc:`/tprocv2_trm`.

Quick Reference
---------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Operation
     - Assembly Code
   * - Load immediate to register
     - ``REG_WR r0 imm #100``
   * - Copy register to register
     - ``REG_WR r1 op -op(r0)``
   * - Load from DMEM
     - ``REG_WR r0 dmem [&10]``
   * - Store to DMEM
     - ``DMEM_WR [&10] imm #42``
   * - Load waveform from WMEM
     - ``REG_WR r_wave wmem [&5]``
   * - Store waveform to WMEM
     - ``WMEM_WR [&5]``
   * - Write data port
     - ``DPORT_WR p0 imm 1 @1000``
   * - Write trigger
     - ``TRIG p0 set @150``
   * - Write wave port
     - ``WPORT_WR p1 r_wave @1000``
   * - Read input port
     - ``DPORT_RD p0``
   * - Conditional jump
     - ``JUMP LABEL -if(NZ)``
   * - Call subroutine
     - ``CALL MY_SUB``
   * - Return from subroutine
     - ``RET``
   * - Wait for time
     - ``WAIT time @1000``
   * - Wait for division
     - ``WAIT div_dt``
   * - Wait for ARITH
     - ``WAIT arith_dt``
   * - Wait for input data
     - ``WAIT port_dt``
   * - Start division
     - ``DIV r1 r2``
   * - Start multiply (ARITH)
     - ``ARITH T r1 r2``
   * - Multiply-accumulate
     - ``ARITH PTP r1 r2 r3 r4``  ``; (r1+r2)*r3+r4``
   * - Set internal flag
     - ``FLAG set``
   * - Clear internal flag
     - ``FLAG clr``
   * - Reset time
     - ``TIME rst``
   * - Increment reference time
     - ``TIME inc_ref #100``
   * - Clear peripheral flag
     - ``CLEAR arith``
   * - No operation
     - ``NOP``

Condition Codes
---------------

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * - Code
     - Condition
     - Use Case
   * - ``-if(Z)``
     - Zero (result == 0)
     - Check if counter reached zero
   * - ``-if(NZ)``
     - Non-zero (result != 0)
     - Loop while counter > 0
   * - ``-if(S)``
     - Negative (result < 0)
     - Check threshold crossing
   * - ``-if(NS)``
     - Non-negative (result >= 0)
     - Opposite of S
   * - ``-if(F)``
     - Flag set
     - Wait for external trigger
   * - ``-if(NF)``
     - Flag clear
     - Wait for flag to clear

Address Modes
-------------

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - Mode
     - Syntax
     - Example
   * - Literal (DMEM)
     - ``[&addr]``
     - ``DMEM_WR [&10] imm #5``
   * - Register (DMEM)
     - ``[rX]``
     - ``DMEM_WR [r0] imm #5``
   * - Indexed literal (DMEM)
     - ``[rX + &offset]``
     - ``DMEM_WR [r1+&4] imm #5``
   * - Indexed register (DMEM)
     - ``[rX + rY]``
     - ``DMEM_WR [r2+r3] imm #5``
   * - Literal (WMEM)
     - ``[&addr]``
     - ``WMEM_WR [&10]``
   * - Register (WMEM)
     - ``[rX]``
     - ``WMEM_WR [r0]``

Python Examples
---------------

**Basic program loading:**

.. code-block:: python

   from qick import *
   from qick.tprocv2_assembler import Assembler

   soc = QickSoc()

   asm_code = \"\"\"
       .ADDR 0x00
       REG_WR r0 imm #100
       DPROT_WR p0 reg r0 @1000
       .END
   \"\"\"

   p_bin = Assembler.str_asm2bin(asm_code)
   soc.tproc.load_mem(prog_mem=p_bin)
   soc.tproc.start()

**Waveform loading and playback:**

.. code-block:: python

   # Load waveform to WMEM
   soc.tproc.load_wave(0, {
       'freq': 100_000_000,   # 100 MHz
       'phase': 0,
       'gain': 32768,          # 1.0 (max)
       'length': 1024,
       'conf': 0
   })

   # Assembly program to play waveform
   asm_code = \"\"\"
       .ADDR 0x00
       REG_WR r_wave wmem [&0]
       WPORT_WR p1 r_wave @1000
       .END
   \"\"\"

**Feedback example (read ADC, conditional output):**

.. code-block:: python

   asm_feedback = \"\"\"
       .ADDR 0x00
       REG_WR r0 imm #100
       REG_WR s_out_time imm #1000
   LOOP:
       WAIT port_dt
       DPORT_RD p0
       REG_WR r1 op -op(s_port_l)
       TEST -op(r1 - #32768) -uf
       REG_WR r_wave wmem [&0] -if(NS)
       REG_WR r_wave wmem [&1] -if(S)
       WPORT_WR p1 r_wave @s_out_time
       REG_WR s_out_time op -op(s_out_time + #2000)
       REG_WR r0 op -op(r0 - #1) -uf
       JUMP LOOP -if(NZ)
       .END
   \"\"\"

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - Complete tProcessor v2 reference manual
* :doc:`/firmware` - Firmware overview and channel assignments
* :doc:`/sg_v6` - Signal Generator v6 documentation
* :doc:`/readout` - Readout system documentation
