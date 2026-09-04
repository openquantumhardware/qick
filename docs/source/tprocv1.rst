========================================================
tProcessor v1 (axis_tproc64x32_x8) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

The **tProcessor v1** (``axis_tproc64x32_x8``) is the original QICK real-time
co-processor: an 8-channel, 64-bit-instruction / 32-bit-register core that
runs a user-written program to sequence pulses, trigger readouts, and react
to feedback with cycle-level timing. The module lives in the ``qick``
firmware repository under ``firmware/ip/axis_tproc64x32_x8_v1/`` and is
exposed to Python through ``qick.drivers.tproc.AxisTProc64x32_x8``; programs
are written with ``qick.asm_v1.QickProgram``.

.. note::
  **This is legacy hardware.** tProc v1 is still real, supported hardware --
  many older QICK boards run it, and this page documents it accurately for
  that reason -- but it is **not** the recommended starting point for a new
  design. New designs should use the tProcessor v2 (``qick_processor``); see
  :doc:`/tprocv2_trm`.

  A few concrete, RTL-verified differences that explain why v2 superseded
  v1:

  * **Instruction width / program memory.** v1 instructions are 64 bits, and
    with the default ``PMEM_N=16`` parameter the usable program memory is
    2\ :sup:`13` = 8192 instructions (64 KB) -- see
    :ref:`tprocv1-pmem-depth` for how that number is derived from the RTL.
    v2 instructions are 72 bits, with program memory depth set independently
    by the ``PMEM_AW`` parameter (default 2\ :sup:`8` = 256 words; production
    designs typically configure much more).
  * **Register organization.** v1 has a single flat, paged register file: 8
    pages x 32 general-purpose 32-bit registers (256 registers total,
    register 0 hardwired to 0 on every page), and no separate special-purpose
    register bank -- see :ref:`tprocv1-regfile`. v2 splits registers into
    three purpose-built banks (general-purpose ``DREG``, special-function
    ``SREG``, and waveform-parameter ``WREG``) described in
    :ref:`tproc-registers` of the v2 manual.
  * **Instruction set richness.** v1 has a fixed set of ~20 instructions
    (see :ref:`tprocv1-isa`) covering arithmetic, bitwise ops, memory,
    stack, and timed output -- there is no hardware division, no
    multiply-accumulate unit, no LFSR, and no subroutine ``CALL``/``RET``
    (only an 8-bit-deep, 256-word return/data stack shared for both
    ``pushi``/``popi`` and loop bookkeeping). v2 adds a division unit, a
    multiply-accumulate unit, an LFSR, and a 256-deep PC-call stack (see the
    v2 manual's :ref:`tproc-quick-ref`).

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

``axis_tproc64x32_x8`` (top-level RTL: ``axis_tproc64x32_x8.v``) wraps the
core datapath (``tproc64x32_x8.v``) together with an AXI-Lite configuration
slave (``axi_slv_custom.sv``) and a data-memory arbiter (``data_mem/``) that
lets the PS access the tProc's data memory both by single AXI-Lite
read/write and by bulk AXI-Stream DMA.

The core itself (``tproc64x32_x8.v``) is a single-issue, microcoded processor
built from separate blocks for each function:

* **Control FSM** (``ctrl.sv``) -- a one-hot state machine that fetches,
  decodes, and sequences every instruction (most instructions take 2-4
  clock cycles; see :ref:`tprocv1-isa`). The instruction-format comments at
  the top of ``ctrl.sv`` are the authoritative bit-level encoding reference
  and were cross-checked against the ``instructions`` dictionary in
  ``qick_lib/qick/asm_v1.py`` for this page.
* **Register file** (``regfile/regfile_8p.vhd`` + ``regfile.vhd``) -- 8
  independent 32-register banks ("pages"), selected by a 3-bit page field
  in the instruction; see :ref:`tprocv1-regfile`.
* **ALU** (``alu/alu.v`` + ``math.vhd`` + ``bitw.vhd``) -- bitwise and
  arithmetic operations on 32-bit operands, plus a second, independent adder
  (in ``tproc64x32_x8.v``, not a separate file) dedicated to computing
  absolute output times for the timed-instruction dispatcher.
* **Stack** (``stack.vhd``) -- a single 256-word x 32-bit BRAM-backed
  push/pop stack, used by ``pushi``/``popi`` (and internally by ``loopnz``
  for its decrement-and-branch loop counter).
* **Per-channel timed-output dispatcher** (``fifo/fifo.vhd`` +
  ``timed_ictrl.vhd``, instantiated 8x, one per output channel) -- see
  :ref:`tprocv1-output`.
* **Data memory** (``bram_dp`` instance in ``axis_tproc64x32_x8.v`` +
  arbiter in ``data_mem/``) -- a dual-port, 32-bit BRAM shared between the
  core's own ``memr``/``memw`` instructions and PS access; see
  :ref:`tprocv1-dmem`.

The processor has:

* **8 timed output channels** (``m1_axis`` .. ``m8_axis``, 160 bits wide
  each) -- typically wired to signal generators and/or trigger/marker pins.
  A 9th port pair (``s0_axis``/``m0_axis``, 32 bits) is dedicated to the
  data-memory DMA path, not to timed output.
* **4 input channels** (``s1_axis`` .. ``s4_axis``, 64 bits wide each) --
  typically wired to readout feedback data, read into a register with the
  ``read`` instruction.

--------------------------------------------------------------------
2. Synthesis Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Parameter
     - RTL Default
     - Description
   * - ``PMEM_N``
     - 16
     - Program-memory address width, in the sense of the ``pmem_addr`` output
       port width. As explained in :ref:`tprocv1-pmem-depth`, the *usable*
       instruction depth is 2\ :sup:`PMEM_N-3`, not 2\ :sup:`PMEM_N` -- with
       the default value of 16 that is 8192 64-bit instructions (64 KB).
       Exposed to Python as ``soc.tproc.PMEM_N``; the actual program-memory
       *size* used by the driver, however, is read back from the
       instantiated memory object's byte length
       (``self.mem.mmio.length // 8``), not computed from ``PMEM_N``.
   * - ``DMEM_N``
     - 10
     - Data-memory address width (log2 of the number of 32-bit words). With
       the default value, data memory is 2\ :sup:`10` = 1024 samples (4 KB).
       Exposed to Python as ``soc.tproc.DMEM_N`` and ``soc.tproc.cfg['dmem_size']
       = 2**DMEM_N``.

.. note::
  An older, public copy of the firmware overview (``main_qick``'s
  ``docs/firmware.rst``, explicitly flagged by that page's own PDF link as
  possibly out of date) cites "4096 samples, 16 KB" for the tProc v1 data
  memory -- inconsistent with the ``DMEM_N=10`` default recorded in this
  repository's ``component.xml``. This is most likely a different
  per-board synthesis configuration (``DMEM_N`` is a generic, so it can
  legitimately differ between board builds), not an error in either
  document, but it could not be verified from source in this session.
  Always read ``soc.tproc.cfg['dmem_size']`` at runtime rather than
  assuming a number. By contrast, that same older document's "8k
  instructions / 64 KB" program-memory figure and "256 samples / 1 KB"
  stack-size figure both match this session's RTL analysis exactly (see
  :ref:`tprocv1-pmem-depth` and :ref:`tprocv1-regfile`).

The AXI-Lite configuration slave (``axi_slv_custom.sv``) additionally has a
fixed, non-parameterized ``NREG = 64`` (64 x 32-bit = 256 bytes) reserved for
registers at the bottom of its address space; see :ref:`tprocv1-regmap`.

--------------------------------------------------------------------
3. Datapath / Architecture
--------------------------------------------------------------------

.. _tprocv1-pmem-depth:

3.1. Program Memory and Program Counter
-----------------------------------------

The program counter (``pc_r`` in ``tproc64x32_x8.v``) is a 16-bit register
that increments by 1 each fetch (``pc_i = pc_r + 1``) or is loaded with a
jump target for ``loopnz``/``condj``. Instructions are 64 bits wide and
fetched over a dedicated ``pmem_do`` bus.

The core's ``pmem_addr`` output is ``pc_r`` directly (matching the
``PMEM_N``-bit port width when ``PMEM_N=16``). However, the top-level
wrapper (``axis_tproc64x32_x8.v``) then re-derives the *external* memory
address as::

    assign pmem_addr = {pmem_addr_int[PMEM_N-4:0], 3'b000};   // x8 (64-bit -> byte)

This keeps only the **low (PMEM_N-3) bits** of the program counter (13 bits
for the default ``PMEM_N=16``) and left-shifts them by 3 to form a
byte-oriented address for an 8-byte-wide (64-bit) instruction word, so the
result still fits in a ``PMEM_N``-bit bus. The top 3 bits of the 16-bit `pc_r`
are simply never forwarded to the external memory address. This is
confirmed by the testbench's program-memory BRAM instantiation
(``src/tb/tb.sv``), which drives its address port with
``{3'b000, pmem_addr[PMEM_N-1:3]}`` -- i.e. the same low 13 bits, zero-padded
back up to 16. The practical consequence: **with the default ``PMEM_N=16``,
only 2**:sup:`13` = 8192 64-bit instructions (64 KB) of program memory are
actually addressable**, regardless of the nominal 16-bit range of the PC.
This matches the driver's own comment that ``PMEM_N`` is merely "the log2 of
the number of 64-bit words, though the actual memory is usually smaller"
(``qick_lib/qick/drivers/tproc.py``), and matches the "8k instructions / 64
KB" figure in the older public firmware overview.

3.2. Instruction Fetch / Decode (Control FSM)
------------------------------------------------

``ctrl.sv`` implements a one-hot FSM with states for each instruction's
multi-cycle sequence (e.g. ``MATHI0_ST`` .. ``MATHI3_ST`` for a 4-cycle
immediate math op, ``SETI0_ST``/``SETI1_ST`` for a 2-cycle timed-output
write). Most instructions take 2-4 clock cycles to decode, operate, and
write back; instructions that push into a per-channel output FIFO
(``seti``/``set``/``setbi``/``setb``, ``waiti``/``wait``) additionally stall
in a wait state if that channel's FIFO is full (or, for the blocking
``setbi``/``setb``/``wait``/``waiti`` forms, until the dispatcher
acknowledges).

.. _tprocv1-regfile:

3.3. Register File
---------------------

The register file (``regfile/regfile_8p.vhd``, wrapping 8 instances of
``regfile.vhd``) provides **8 pages x 32 registers = 256 total 32-bit
registers**, selected by a 3-bit page field (instruction bits ``55:53``) and
5-bit register-address fields (e.g. bits ``40:36`` for ``ra``). It has 7
parallel read ports and 1 write port, with one clock cycle of read latency;
the page-select input itself is pipelined by one cycle to stay aligned with
the muxed read data. **Register 0 on every page is hardwired to always read
0** (``regfile.vhd``: ``if unsigned(addrN) = 0 then doutN <= (others => '0')``),
which the Python driver and assembler exploit as a convenient "discard" /
"always zero" operand (e.g. in ``QickProgram``'s pulse-register allocation,
unused fields of a ``set`` call are pointed at register 0 of the page).

3.4. ALU and Time Adder
---------------------------

``alu.v`` combines two sub-blocks, muxed by the top bit of the 4-bit
``oper`` field (delayed 3 cycles to match each sub-block's own pipeline
latency):

* ``bitw.vhd`` (``oper[3]=0``): and / or / xor / not / shift-left /
  shift-right.
* ``math.vhd`` (``oper[3]=1``): add / subtract / multiply.

A second, separate adder in ``tproc64x32_x8.v`` (``alut_a + alut_b``, not
part of ``alu.v``) computes absolute output times for timed instructions:
it adds the free-running 48-bit master clock (``t_cnt_sync``, the
synchronization point most recently set by ``sync``/``synci``) to either a
register value or an immediate (selected by ``alut_src_b``), producing the
``t`` field that gets pushed into a channel's output FIFO alongside
``seti``/``set``/``waiti``/``wait``.

3.5. Stack
-------------

``stack.vhd`` is a single 256-word x 32-bit BRAM-backed stack (8-bit stack
pointer ``sp``, initialized to all-ones/255 on reset -- i.e. "empty"; ``full``
is asserted when ``sp`` reaches 0). It backs ``pushi``/``popi`` directly, and
is also used internally by ``loopnz`` as its decrement-and-test loop
register mechanism is register-file-based rather than stack-based (loopnz
decrements a register, not the stack -- the stack itself is only touched by
explicit ``pushi``/``popi``). This 1 KB stack is the same figure ("256
samples of 32 bits, 1k Byte total") given in the older public firmware
overview.

.. _tprocv1-output:

3.6. Timed Output Port Mechanism
------------------------------------

Each of the 8 output channels has its own 16-deep FIFO (``fifo/fifo.vhd``)
and its own ``timed_ictrl.vhd`` dispatcher instance. When the core executes
``seti``/``set``/``setbi``/``setb``, it packages an opcode byte, the
computed absolute output time (48 bits), and up to 5 register values (for
``set``/``setb``, corresponding to ``{re,rd,rc,rb,ra}``; for ``seti``/
``setbi``, only one register/immediate matters) into a 216-bit word
(``FW = 5*32 + 48 + 8``) and pushes it into that channel's FIFO.

Independently, each channel's ``timed_ictrl`` FSM continuously watches the
free-running master clock (``t_cnt``) against the timestamp at the head of
its FIFO; when the target time is reached, it drives the channel's AXI-Stream
output (``m1_axis`` .. ``m8_axis``, 160 bits wide): the low 32 bits carry a
``seti``/``setbi`` value (zero-padded to 160 bits), while a ``set``/``setb``
drives the full 160-bit ``{p4,p3,p2,p1,p0}`` word. This is the mechanism
behind the "``p.seti()``"/"``p.set()``" style output calls referenced in the
older ASM cheatsheet: ``seti``/``set`` are non-blocking (the core only stalls
if the target FIFO is already full), while ``setbi``/``setb`` additionally
block the core until the dispatcher confirms the AXI-Stream write went out
(``m_axis_tready``).

``waiti``/``wait`` use the same per-channel FIFO/dispatcher path, but instead
of driving an output, the dispatcher raises a ``waitt`` flag once ``t_cnt``
reaches the target time, which the core FSM waits on (``WAIT_ACK_ST``)
before resuming -- i.e. these instructions block core execution until a
given absolute time, without touching an output port.

3.7. Input Ports
--------------------

4 slave AXIS input channels (``s1_axis`` .. ``s4_axis`` at the top level,
64 bits wide) are read into a register with the R-type ``read`` instruction.
The ``oper`` field selects which half of the 64-bit input word is captured:
``oper == 4'b1010`` selects the upper 32 bits, any other value selects the
lower 32 bits (``din_i = (oper==4'b1010) ? din_mux[63:32] : din_mux[31:0]``
in ``tproc64x32_x8.v``).

.. _tprocv1-dmem:

3.8. Data Memory
--------------------

Data memory is a dual-port 32-bit BRAM (``bram_dp``, depth 2\ :sup:`DMEM_N`).
One port is dedicated to the core's own ``memr``/``memw``/``memri``/``memwi``
instructions. The other port is shared, through the arbiter in
``data_mem/data_mem.v``, between:

* **Single AXI-Lite access** -- addresses above the 256-byte register window
  (see :ref:`tprocv1-regmap`) map directly onto data-memory samples.
* **Bulk AXI-Stream DMA**, gated by ``MEM_MODE_REG`` (0=read from memory to
  ``m0_axis``, 1=write from ``s0_axis`` to memory), ``MEM_START_REG``,
  ``MEM_ADDR_REG`` (start address) and ``MEM_LEN_REG`` (sample count); the
  DMA transaction runs until ``LEN_REG`` samples have moved (read side) or
  ``s_axis_tlast`` is asserted (write side).

When neither AXI-Lite single access nor an active DMA transaction is in
flight, the arbiter is idle and grants no memory port cycles beyond what the
core itself uses.

--------------------------------------------------------------------

.. _tprocv1-isa:

4. Instruction Set
--------------------------------------------------------------------

All instructions are 64 bits, in one of three formats (bit-field layout is
transcribed from the header comments in ``ctrl.sv`` and cross-checked
against the ``instructions`` dict in ``qick_lib/qick/asm_v1.py``):

.. list-table:: Instruction Formats
   :header-rows: 1
   :widths: 15 15 70

   * - Format
     - Bits ``63:56``
     - Remaining fields
   * - I-Type
     - opcode
     - ``page`` (55:53), ``channel`` (52:50), ``oper`` (49:46), ``ra``
       (45:41), ``rb`` (40:36), ``rc`` (35:31), 31-bit sign-extended
       ``imm`` (30:0)
   * - J-Type
     - opcode
     - ``page`` (55:53), ``oper`` (49:46), up to 3 register fields
       (45:31), 16-bit jump ``addr`` (15:0)
   * - R-Type
     - opcode
     - ``page`` (55:53), ``channel`` (52:50), ``oper`` (49:46), up to 7
       register fields (45:6)

.. list-table:: Instruction Set
   :header-rows: 1
   :widths: 12 10 12 66

   * - Mnemonic
     - Format
     - Opcode
     - Description
   * - ``pushi``
     - I
     - ``0b00010000``
     - Push register ``ra`` (page ``p``) onto the stack; load immediate
       ``imm`` into register ``rb``.
   * - ``popi``
     - I
     - ``0b00010001``
     - Pop the stack into register ``r`` (page ``p``).
   * - ``mathi``
     - I
     - ``0b00010010``
     - ``ra = rb <op> imm``; ``op`` in ``{+, -, *}`` (``oper`` field).
   * - ``seti``
     - I
     - ``0b00010011``
     - Schedule register ``r`` (page ``p``) to be written to output
       ``channel`` at time ``imm`` (non-blocking; see
       :ref:`tprocv1-output`).
   * - ``synci``
     - I
     - ``0b00010100``
     - Rebase the internal time-sync reference to immediate ``imm``.
   * - ``waiti``
     - I
     - ``0b00010101``
     - Block the core on ``channel`` until master clock reaches ``imm``.
   * - ``bitwi``
     - I
     - ``0b00010110``
     - ``ra = rb <op> imm``; ``op`` in ``{&, \|, ^, ~, <<, >>}``.
   * - ``memri``
     - I
     - ``0b00010111``
     - ``r = mem[imm]`` (page ``p``).
   * - ``memwi``
     - I
     - ``0b00011000``
     - ``mem[imm] = r`` (page ``p``).
   * - ``regwi``
     - I
     - ``0b00011001``
     - ``r = imm`` (page ``p``).
   * - ``setbi``
     - I
     - ``0b00011010``
     - Blocking variant of ``seti``.
   * - ``loopnz``
     - J
     - ``0b00110000``
     - If register ``r`` != 0: decrement ``r`` and jump to ``addr``; else
       fall through.
   * - ``condj``
     - J
     - ``0b00110001``
     - Jump to ``addr`` if ``ra <op> rb`` is true; ``op`` in
       ``{>, >=, <, <=, ==, !=}`` (0-5, see the condition-code list at the
       end of this section).
   * - ``end``
     - J
     - ``0b00111111``
     - Halt: jump to the terminal state until the tProc is restarted.
   * - ``math``
     - R
     - ``0b01010000``
     - ``ra = rb <op> rc``; ``op`` in ``{+, -, *}``.
   * - ``set``
     - R
     - ``0b01010001``
     - Schedule 5 registers ``{re,rd,rc,rb,ra}`` (freq/phase/addr/gain/mode,
       by convention) to be written to output ``channel`` at time ``rt``
       (non-blocking).
   * - ``sync``
     - R
     - ``0b01010010``
     - Rebase the internal time-sync reference to register ``r``.
   * - ``read``
     - R
     - ``0b01010011``
     - Read input ``channel`` (upper or lower 32 bits, by ``oper``) into
       register ``r``.
   * - ``wait``
     - R
     - ``0b01010100``
     - Block the core on ``channel`` until master clock reaches register
       ``r``.
   * - ``bitw``
     - R
     - ``0b01010101``
     - ``ra = rb <op> rc``; ``op`` in ``{&, \|, ^, ~, <<, >>}``.
   * - ``memr``
     - R
     - ``0b01010110``
     - ``ra = mem[rb]``.
   * - ``memw``
     - R
     - ``0b01010111``
     - ``mem[rb] = ra``.
   * - ``setb``
     - R
     - ``0b01011000``
     - Blocking variant of ``set``.

.. _tprocv1-condcodes:

Math/bitwise ``op`` codes (shared 4-bit field for ``mathi``/``math``,
``bitwi``/``bitw``): ``+``\=0b1000, ``-``\=0b1001, ``*``\=0b1010 (math);
``&``\=0b0000, ``\|``\=0b0001, ``^``\=0b0010, ``~``\=0b0011, ``<<``\=0b0100,
``>>``\=0b0101 (bitwise). ``condj`` condition codes: ``>``\=0, ``>=``\=1,
``<``\=2, ``<=``\=3, ``==``\=4, ``!=``\=5 (implemented in ``cond.vhd``,
comparing registers ``ra``/``rb`` on the current page).

--------------------------------------------------------------------

.. _tprocv1-regmap:

5. Register Map
--------------------------------------------------------------------

The AXI-Lite configuration slave (``axi_slv_custom.sv``) reserves a fixed
64-word (256-byte) window for registers at the bottom of its address space
(``NREG = 64``); addresses at or above 256 bytes are forwarded to data
memory instead (byte-address minus 256, converted to a sample address).
Only 6 of the 64 reserved words are actually wired to anything; the rest
read/write as plain, unused storage:

.. list-table::
   :header-rows: 1
   :widths: 22 12 12 54

   * - Register
     - Word Offset
     - Byte Address
     - Description
   * - ``START_SRC_REG``
     - 0
     - 0x00
     - Bit 0: 0 = start from ``START_REG`` (internal), 1 = start from the
       external ``start`` input pin.
   * - ``START_REG``
     - 1
     - 0x04
     - Bit 0: 0 = init/stopped, 1 = start (edge-triggered: the FSM only
       fires on a low-to-high transition, per the Python driver's
       ``start()``, which pulses it 0 then 1).
   * - ``MEM_MODE_REG``
     - 2
     - 0x08
     - Bit 0: 0 = AXIS read (memory -> ``m0_axis``), 1 = AXIS write
       (``s0_axis`` -> memory).
   * - ``MEM_START_REG``
     - 3
     - 0x0C
     - Bit 0: 0 = stopped, 1 = execute the configured AXIS DMA operation.
   * - ``MEM_ADDR_REG``
     - 4
     - 0x10
     - Starting data-memory sample address for the AXIS DMA operation.
   * - ``MEM_LEN_REG``
     - 5
     - 0x14
     - Sample count for the AXIS DMA operation.

Data memory (single-access mode) is addressed starting at byte offset 256
(word offset 64): ``mem[addr] <-> axi_addr = 256 + 4*addr``. The Python
driver's ``single_read``/``single_write`` implement this directly as
``mmio.array[addr + NREG]`` (``NREG=64`` words).

--------------------------------------------------------------------

6. Python Interface
--------------------------------------------------------------------

6.1. Driver (``qick.drivers.tproc.AxisTProc64x32_x8``)
----------------------------------------------------------

``bindto = ['user.org:user:axis_tproc64x32_x8:1.0', 'QICK:QICK:axis_tproc64x32_x8:1.0']``
-- this identifies the v1 core in a QICK overlay's block-design metadata and
is what makes ``pynq``/``qick.QickSoc`` attach this driver class rather than
the v2 driver (``Axis_QICK_Proc``, ``bindto`` matching ``qick_processor``,
documented in :doc:`/tprocv2_trm`). It is reached as ``soc.tproc``.

.. code-block:: python

  from qick import *

  soc = QickSoc()
  tproc = soc.tproc          # AxisTProc64x32_x8 instance

  # Load a compiled program (list/array of 64-bit instruction words).
  tproc.load_bin_program(binprog, load_mem=True)

  # Set the start trigger source, then start.
  tproc.start_src("internal")
  tproc.start()

  # ... program runs in real time on the FPGA fabric ...

  # Force-stop by overwriting program memory with `end` instructions.
  tproc.reset()
  # Restore the program that was running before reset().
  tproc.reload_program()

Notable methods:

* ``start()`` -- pulses ``start_reg`` 0 then 1 (edge-triggered; has no
  effect if the start source is set to external).
* ``reset()`` -- force-stops the core by overwriting **only the high 32-bit
  half of every program word** (``mem.mmio.array[1::2] = 0x3F000000``) with
  the ``end`` opcode (``0b00111111``, matching ``ctrl.sv``'s ``END_ST``
  encoding), leaving the low half untouched. This is a fast (~1 ms),
  targeted overwrite rather than a full program-memory clear, and relies on
  the opcode living in bits ``63:56`` of the 64-bit instruction word (i.e.
  the high 32-bit half when the word is split for a 32-bit-wide memory
  port).
* ``load_bin_program()`` / ``reload_program()`` -- write (or rewrite, after
  a ``reset()``) the cached program to program memory via a direct
  ``mmio`` array copy (not DMA -- program memory is memory-mapped, unlike
  data memory).
* ``single_read(addr)`` / ``single_write(addr, data)`` -- single-sample AXI-Lite
  access to data memory, offset by ``NREG`` (see :ref:`tprocv1-regmap`).
* ``load_dmem(buff_in, addr)`` / ``read_dmem(addr, length)`` -- bulk data-memory
  transfer via the AXI-Lite/DMA arbiter (:ref:`tprocv1-dmem`): configures
  ``mem_mode_reg``/``mem_addr_reg``/``mem_len_reg``/``mem_start_reg`` and
  drives an AXI DMA channel.
* ``start_src(src)`` -- ``"internal"``/``"external"``, sets ``start_src_reg``.

6.2. Assembler (``qick.asm_v1.QickProgram``)
-------------------------------------------------

``QickProgram`` builds a program as a list of instruction dicts
(``self.prog_list``), with one Python method auto-generated per entry in the
``instructions`` class dict via ``__getattr__`` -- e.g. calling
``prog.regwi(page, reg, imm)`` looks up ``instructions['regwi']`` and calls
``append_instruction('regwi', page, reg, imm)``. This is a thin,
direct-to-bytecode assembler: ``compile()`` resolves ``label()`` targets and
packs each instruction dict into a 64-bit word per the same bit layout
documented in :ref:`tprocv1-isa`, then checks the result against
``tproccfg['pmem_size']`` (read from the driver's ``cfg['pmem_size']``, i.e.
the true, board-specific memory size -- not a hardcoded 8192).

Register allocation is done by ``_allocate_registers()``: each generator or
tProc-controlled-readout channel is assigned a fixed block of registers
(``PULSE_REGISTERS``, 10 names such as ``freq``/``phase``/``addr``/``gain``/
``mode``/``t``) on one of the 8 pages, packing 2 channels per page (3 if
there are more than 15 channels total), with channel 0 alone on page 0 to
leave room for loop/shot counters used by averaging program base classes.
``ch_page()``/``sreg()`` (and the ``_ro`` variants for readout channels) look
up the page and register number for a given channel/parameter name.
``safe_regwi()`` works around the 31-bit immediate limit of the ``regwi``
I-type encoding (:ref:`tprocv1-isa`) by splitting values >= 2\ :sup:`30`
into a ``regwi`` + ``bitwi`` (shift) + optional ``mathi`` (remainder)
sequence.

High-level helpers (``set_pulse_registers``/``pulse``, ``trigger``,
``measure``, ``sync_all``, ``wait_all``, ``reset_phase``, ...) build on top
of the raw instructions to implement the same pulse-sequencing API surface
used across QICK's higher-level ``QickProgram`` classes (v1 and v2 share
the ``AbsQickProgram``/``AcquireMixin`` base in ``qick.qick_asm``, but the
instruction-level implementation, register layout, and compiled bytecode
are entirely different between the two).

6.3. Contrast with tProc v2
--------------------------------

Where v2's ``QickProgramV2`` (``qick.asm_v2``) works with named registers
across three purpose-built banks (``r0..r31``, ``s0..s15``, ``w0..w5`` --
see the v2 manual's :ref:`tproc-registers`) and a richer instruction set
(division, multiply-accumulate, an LFSR, subroutine calls via a 256-deep PC
stack), v1 programming is lower-level: a single flat, paged 32-register
file with no dedicated special-function registers, arithmetic limited to
add/subtract/multiply and the 6 bitwise ops in :ref:`tprocv1-isa`, and no
call/return mechanism (only the single shared push/pop stack). Timed output
in v1 always goes through the ``seti``/``set``/``setbi``/``setb`` family
described in :ref:`tprocv1-output`, addressed by output-channel number,
whereas v2 uses named wave/trigger/data ports with a page-based waveform
register bank (``r_wave``) purpose-built for signal-generator parameters.

--------------------------------------------------------------------

Related Documentation
----------------------

* :doc:`/tprocv2_trm` -- the current tProcessor (v2), recommended for new
  designs.
* :doc:`/firmware` -- system-level firmware overview (signal generators,
  readout, channel assignments).
* :doc:`/avg_buffer` -- Averager + Buffer readout block, whose ``trigger``
  input is typically driven from a v1 tProc output channel bit.
* `tProcessor_64_and_Signal_Generator_V4.pdf
  <https://github.com/openquantumhardware/qick/blob/main/firmware/tProcessor_64_and_Signal_Generator_V4.pdf>`_
  -- an older learning-oriented write-up of the v1 tProcessor and the
  signal generator it was originally paired with. The upstream ``qick``
  repository's own firmware overview explicitly flags this PDF as **not**
  up to date with the current RTL; treat it as background reading only; the
  bit-level facts on this page were verified directly against the RTL and
  Python driver in this repository, not against that PDF.
