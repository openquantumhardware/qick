============================================
QICK tProcessor v2 Detailed Reference Manual
============================================

:Version: 2.0
:Compatibility: QICK Firmware (>= v0.0.1)
:Abstract: This manual explains the architecture, instruction set, and programming model of the tProcessor v2, with emphasis on real‑time control for quantum experiments. It is written for firmware developers and advanced QICK users.

.. contents:: Table of Contents
   :depth: 2

1. What is the tProcessor and why does it exist?
=================================================

The tProcessor (timing Processor) is a specialized CPU inside the QICK FPGA. Its sole purpose is to **execute a sequence of actions with extremely precise timing** – down to a few nanoseconds. A standard processor (like an ARM CPU) cannot guarantee such timing because it runs an operating system and unpredictable interrupts. The tProcessor is a **hard real‑time co‑processor** dedicated to waveform generation and feedback.

Key design principles:

* **Deterministic execution** – Every instruction takes a known number of clock cycles.
* **Time‑aware instructions** – You specify *when* an output should change, not just *what* to output.
* **Dual tasks** – One instruction can do two things (e.g., compute a new value and write a port).
* **Low latency to outputs** – Approximately 5 clock cycles from instruction to physical pin.

In a typical experiment, the tProcessor:

1. Waits for a trigger or a specific time.
2. Configures DACs to generate a pulse (frequency, phase, gain).
3. Reads ADC data (feedback).
4. Adjusts subsequent pulses based on that data.

2. Architectural Overview (with explanations)
==============================================

2.1. The three clock domains – why they matter
-----------------------------------------------

The tProcessor has **three separate clock domains**. This is unusual and important to understand.

.. list-table::
   :header-rows: 1

   * - Domain
     - Signal name
     - Typical frequency
     - Purpose
     - What happens here
   * - **Time domain**
     - ``t_clk``
     - 384 MHz – 6 GHz (DAC rate)
     - Counting time and updating outputs
     - Dispatcher FIFOs, comparators, physical ports
   * - **Core domain**
     - ``c_clk``
     - ≤ ``t_clk`` (often 350 MHz)
     - Executing instructions
     - CPU pipeline, ALU, registers, memories
   * - **PS domain**
     - ``ps_clk``
     - 100 MHz
     - Communication with ARM processor
     - AXI‑Lite and AXI‑Stream interfaces

**Why three clocks?**  
The DAC runs very fast (GHz). The CPU cannot run that fast (it would consume too much power and fail timing). So we separate:
- The **CPU** runs at a comfortable speed.
- The **time counter** runs at the DAC speed.
- The **dispatcher** compares the two and updates outputs exactly when needed.

**Rule to remember:**  
``t_clk`` must be **faster than or equal to** ``c_clk``. Never slower.

2.2. The pipeline – how instructions execute
---------------------------------------------

The CPU uses a 5‑stage pipeline. This means up to 5 instructions are in flight at once.

.. code-block::

   Stage 1: FETCH    ──> Read instruction from PMEM
   Stage 2: DECODE   ──> Interpret opcode, read registers
   Stage 3: READ     ──> Get data from forwarding or memory
   Stage 4: EXECUTE  ──> ALU operation, address calculation
   Stage 5: WRITE    ──> Write result to register or FIFO

**Why does this matter to you?**  
- **Branch instructions** (JUMP, CALL) cause a 2‑cycle penalty because the pipeline must be flushed.
- **Dual‑task instructions** (``-wr``, ``-wp``) execute in parallel – no extra cycles.
- **Data hazards** (using a result immediately after computing it) are handled by forwarding hardware, but you should still be careful with very tight loops.

2.3. The dispatcher – the secret to precise timing
---------------------------------------------------

The dispatcher is a separate hardware block that continuously monitors the current time (``t_abs``) and a set of FIFOs. Each FIFO entry contains:

* A 48‑bit absolute output time (``t_abs_out``)
* A data value (32‑bit for DPORT, 168‑bit for WPORT, 1‑bit for TRIG)

When the current time reaches or passes the scheduled time, the dispatcher **immediately** updates the output port. The CPU does not need to poll or wait – it just pushes data and moves on.

**Latency breakdown:**

1. CPU writes to FIFO: 1 cycle
2. Data travels to dispatcher (clock domain crossing): 1 cycle
3. Dispatcher comparator: 1 cycle
4. Output register update: 1 cycle
5. Physical pin propagation: 1 cycle (FPGA specific)

**Total:** about 5 cycles of ``t_clk``.  
At 384 MHz, 5 cycles ≈ 13 ns. This is your minimum time between a write instruction and the output changing.

3. Memory Hierarchy (explained)
===============================

The tProcessor has **three separate memories**, each optimized for a different purpose.

3.1. PMEM – Program Memory
--------------------------

- **Width:** 64 bits per instruction
- **Size:** 256 to 65536 instructions (configurable)
- **Access:** CPU reads only; PS can write via DMA (to load programs)

**Why 64 bits?**  
One instruction needs to encode:
- The operation (e.g., ``REG_WR``)
- Source and destination registers
- Immediate values (up to 32 bits)
- Options (conditions, dual tasks)
- Addressing modes

All this fits in 64 bits. Earlier versions used 72 bits, but we optimized the encoding.

**Practical limit:**  
At 350 MHz, 65536 instructions execute in about 187 µs (if no branches). For longer sequences, you must loop or use subroutines.

3.2. DMEM – Data Memory
-----------------------

- **Width:** 32 bits per word
- **Size:** 256 to 65536 words
- **Access:** CPU read/write; PS read/write via DMA

**Use cases:**
- Storing waveform lookup tables (e.g., envelopes)
- Accumulating results (e.g., averaging ADC reads)
- Holding configuration parameters that change rarely

**Addressing modes (important for efficient code):**

.. list-table::
   :header-rows: 1

   * - Mode
     - Syntax
     - Example
     - When to use
   * - Literal
     - ``[&addr]``
     - ``DMEM_WR [&10] imm #5``
     - Fixed addresses (constants)
   * - Register
     - ``[rX]``
     - ``DMEM_WR [r1] op -op(r0)``
     - Indexed access (loops)
   * - Indexed literal
     - ``[rX + &offset]``
     - ``DMEM_WR [r2+&4] imm #1``
     - Array access with base pointer
   * - Indexed register
     - ``[rX + rY]``
     - ``DMEM_WR [r3+r4] imm #0``
     - 2D arrays or dynamic indexing

3.3. WMEM – Waveform Parameter Memory
--------------------------------------

- **Width:** 168 bits per entry
- **Size:** 256 to 2048 entries
- **Access:** CPU read only (to load into ``r_wave``); PS write only (via DMA to preload waveforms)

Each WMEM entry contains **six parameters** that define a complete waveform:

.. code-block::

   Bits:   [167:136]   [135:104]   [103:72]   [71:48]   [47:16]   [15:0]
          ──────────────────────────────────────────────────────────────
            w_freq       w_phase     w_gain     w_env     w_length   w_conf
            32 bits      32 bits     32 bits    24 bits   32 bits    16 bits

**Why group them together?**  
Writing a single 168‑bit value to a Wave Port (``WPORT_WR``) updates all six parameters **atomically**. This ensures that the DAC does not see a partial update (e.g., new frequency with old gain), which could cause glitches.

**Typical workflow:**

1. Pre‑compute all waveforms in Python.
2. Write them to WMEM using ``soc.tproc.load_wave()``.
3. In the tProc program, quickly switch between waveforms by reading from WMEM into ``r_wave`` and then writing to WPORT.

4. Registers – Detailed Explanation
===================================

4.1. Data registers (``r0`` – ``r31``)
---------------------------------------

These are your **scratchpad**. Use them for:

- Loop counters
- Temporary results
- Pointers (addresses)
- Data to be written to ports

**Aliasing** (``.ALIAS myvar r5``) is highly recommended. It makes code self‑documenting.

Example:

.. code-block:: none

   .ALIAS pulse_counter r0
   .ALIAS base_address   r1
   .ALIAS temp_result    r2

   REG_WR pulse_counter imm #100   // Clear to understand

4.2. Special function registers (sreg) – what each one does
------------------------------------------------------------

**``s_zero`` (always 0)**  
Useful for clearing registers or as a source for operations: ``REG_WR r1 op -op(r2 + s_zero)``

**``s_rand`` (pseudo‑random)**  
Generated by a Linear Feedback Shift Register (LFSR). The polynomial is ``x^31 + x^21 + x^1 + x^0`` (maximum length).  
Configuration modes (via ``core_cfg`` register):

- Mode 0: Stop (keep current value)
- Mode 1: Free running (changes every clock)
- Mode 2: Change when read
- Mode 3: Change when written

**Typical use:** Inject noise or randomize a parameter in a feedback loop.

**``s_cfg`` – Configuration register**  
Controls two things:

- **Bits 3:0** (``DT_SRC``): Selects what data is read into ``s_core_r1`` and ``s_core_r2``.
- **Bits 7:4** (``FLAG_SRC``): Selects which flag is used for ``-if(F)`` conditions.

See the table below for possible values.

**``s_status`` – Status register**  
Each bit indicates a condition. You will poll this frequently.

Important bits:

- Bit 0: ``ARITH_RDY`` – ARITH unit has a valid result.
- Bit 1: ``ARITH_DT_NEW`` – ARITH produced a new result (cleared by reading or ``CLEAR arith``).
- Bit 2: ``DIV_RDY`` – Divider finished.
- Bit 3: ``DIV_DT_NEW`` – New division result available.
- Bit 4: ``QNET_RDY`` – QNET interface ready.
- Bit 15: ``FIFO_FULL`` – Any FIFO is full (backpressure).
- Bits 31:16: ``PORT_DT_NEW`` – New data arrived on input ports.

**Pattern to wait for a peripheral:**

.. code-block:: none

   // Start ARITH operation
   ARITH T r1 r2
   // Wait for it to complete
   WAIT arith_dt
   // Read result
   REG_WR r3 op -op(s_arith_low)

**``s_usr_time`` and ``s_out_time``**  
- ``s_usr_time``: Current time from the user's perspective (``t_abs - t_ref``). Read‑only.
- ``s_out_time``: User‑programmable time for the *next* output. Write to this, then use ``@s_out_time`` in port instructions.

**Why two time registers?**  
You can pre‑compute a series of times in advance. For example, to output pulses at 100, 200, 300 ns:

.. code-block:: none

   REG_WR s_out_time imm #100
   DPROT_WR p0 imm 1 @s_out_time
   REG_WR s_out_time op -op(s_out_time + #100)
   DPROT_WR p0 imm 1 @s_out_time
   REG_WR s_out_time op -op(s_out_time + #100)
   DPROT_WR p0 imm 1 @s_out_time

This pattern avoids repeating immediate time values.

4.3. Wave parameter registers (``w_freq``, ``w_phase``, etc.)
-------------------------------------------------------------

These six registers are concatenated into a single 168‑bit register called ``r_wave``. When you write to any ``w_*`` register, you are updating part of ``r_wave``. When you write ``r_wave`` to a WPORT or WMEM, the entire set of parameters is sent together.

**Example: dynamically changing frequency while keeping other parameters:**

.. code-block:: none

   REG_WR w_freq op -op(w_freq + #0x10000)  // Increment frequency
   WPORT_WR p0 r_wave @s_out_time           // Send all parameters

5. Instruction Set – Deeper Explanation
========================================

5.1. Dual‑task instructions (``-wr``, ``-wp``)
----------------------------------------------

This is the most powerful feature of the tProcessor. One instruction can do **two things** in parallel.

**Example without dual task:**

.. code-block:: none

   REG_WR r0 op -op(r0 + #1)   // Increment r0
   DPROT_WR p0 reg r0 @100     // Write r0 to port (uses old value! Bug!)

**With dual task (correct):**

.. code-block:: none

   REG_WR r1 op -op(r0 + #1) -wr(r0 op) -op(r0 + #1)  // Increment r0 and store to r1 in parallel

Or better, using the special syntax:

.. code-block:: none

   REG_WR r0 op -op(r0 + #1) -wp(p0) -wr(...)   // Actually -wp is only for wave ports, but you get the idea

The key is that **both operations see the same original register values**. The writes happen at the end of the cycle.

**Practical use:**  
Update a loop counter and write data in the same cycle, saving execution time.

5.2. Conditional execution (``-if(condition)``)
------------------------------------------------

Every data instruction can be conditionally executed. This eliminates many short branches.

**Without conditions (bad):**

.. code-block:: none

   JUMP SKIP -if(Z)        // Branch penalty
   REG_WR r0 imm #1
SKIP:
   REG_WR r1 imm #2

**With conditions (good):**

.. code-block:: none

   REG_WR r0 imm #1 -if(NZ)   // Only executed if Zero flag is NOT set
   REG_WR r1 imm #2           // Always executed

The condition checks the ALU flags (Z, S), an internal flag, or an external flag (set from Python).

**Why external flag?**  
Python can set a flag (via ``tproc_ctrl``) that the tProc can test. This allows the ARM processor to influence real‑time decisions without stopping the tProc.

5.3. Macros: ``WAIT`` and ``CLEAR``
-----------------------------------

These are not real hardware instructions; they are **assembler macros** that expand into short sequences.

``WAIT time @N`` expands to:

.. code-block:: none

   TEST -op(s_usr_time - #N)   // Compare current time with N
   JUMP HERE -if(S)            // Loop if current time < N

``WAIT div_dt`` expands to:

.. code-block:: none

   TEST -op(s_status AND #8)   // Check bit 3 (DIV_DT_NEW)
   JUMP HERE -if(Z)            // Loop if not ready

**Why macros?**  
They save typing and reduce errors. But remember they expand into multiple instructions, so you cannot use them inside a cycle‑accurate tight loop without accounting for the extra cycles.

6. Python Integration – Detailed Examples
==========================================

6.1. Loading a program and waveforms
-------------------------------------

.. code-block:: python

   from qick import *
   from qick.py_asm import Assembler

   soc = QickSoc()

   # Define waveforms in Python
   waveforms = [
       {"freq": 200_000_000, "phase": 0, "gain": 32768, "length": 1000},
       {"freq": 210_000_000, "phase": 0, "gain": 16384, "length": 1000},
       {"freq": 190_000_000, "phase": 180, "gain": 32768, "length": 1000},
   ]

   # Load into WMEM at addresses 0,1,2
   for i, w in enumerate(waveforms):
       soc.tproc.load_wave(i, w)

   # Assembly program that cycles through waveforms
   asm = """
       .ADDR 0x00
       REG_WR r0 imm #0       // index
       REG_WR r1 imm #3       // count
   LOOP:
       REG_WR r_wave wmem [r0]   // load waveform from WMEM
       WPORT_WR p1 r_wave @s_out_time
       REG_WR s_out_time op -op(s_out_time + #2000)
       REG_WR r0 op -op(r0 + #1)
       REG_WR r1 op -op(r1 - #1) -uf
       JUMP LOOP -if(NZ)
       .END
   """

   p_bin = Assembler.str_asm2bin(asm)
   soc.tproc.load_mem(prog_mem=p_bin)
   soc.tproc.start()

6.2. Reading feedback from ADC
------------------------------

The ADC sends data to the tProc via an input port (AXI‑Stream). The tProc reads it with ``DPORT_RD``.

**Example: conditional pulse based on ADC value**

.. code-block:: python

   asm_feedback = """
       .ADDR 0x00
       CLEAR port
   WAIT_TRIG:
       WAIT port_dt
       DPORT_RD p0
       REG_WR r0 op -op(s_port_l)   // r0 = ADC value
       // If ADC > threshold, send a long pulse; else short pulse
       REG_WR r0 op -op(r0 - #1000) -uf
       REG_WR r1 imm #5000 -if(NS)   // long pulse time (if ADC <= 1000)
       REG_WR r1 imm #1000 -if(S)    // short pulse time (if ADC > 1000)
       REG_WR s_out_time op -op(s_out_time + #100)
       WPORT_WR p0 r_wave @s_out_time   // send waveform with adjusted time
       REG_WR s_out_time op -op(s_out_time)  // add delay to avoid overlap
       JUMP WAIT_TRIG
       .END
   """

7. Common Pitfalls and How to Avoid Them
=========================================

7.1. Forgetting that time is signed
------------------------------------

``s_out_time`` and ``@time`` in port instructions are **signed 32‑bit integers**. This allows you to schedule outputs *before* the current time (e.g., if you are behind schedule). But it also means that if you accidentally write a negative time, the dispatcher will output immediately.

**Solution:** Always use positive times unless you explicitly need negative offsets.

7.2. Overflowing the FIFOs
--------------------------

The dispatcher FIFOs have limited depth (configurable, default 8‑9 entries). If you write more than that without waiting for them to drain, the FIFO will assert ``FIFO_FULL`` and the tProc will stall (if ``DISABLE_FIFO_FULL_PAUSE`` is 0).

**Solution:** Monitor ``s_status[15]`` (``FIFO_FULL``) or use the ``WAIT fifo_not_full`` macro (if defined). Design your program to not burst more writes than FIFO depth.

7.3. Mixing up ``s_usr_time`` and ``s_out_time``
------------------------------------------------

- ``s_usr_time`` is read‑only and reflects the current time.
- ``s_out_time`` is read/write and sets the time for the *next* output.

**Common mistake:** Using ``@s_usr_time`` in a write instruction. This would schedule the output at the current time (immediately), not at a future time.

7.4. Pipeline hazards on branches
---------------------------------

After a conditional JUMP or CALL, the next two instructions are fetched but then discarded. This creates a 2‑cycle penalty.

**Solution:** Place independent instructions (e.g., NOPs or operations that do not affect the branch condition) after the branch, but in practice the assembler does not reorder for you. Keep branches infrequent in tight loops.

8. Performance Tuning Guidelines
================================

- **Group writes to the same port** to maximize FIFO utilization.
- **Use dual tasks** (``-wr``) to update counters and write data in one cycle.
- **Prefer conditional execution** over short branches.
- **Pre‑load waveforms into WMEM** rather than recomputing them.
- **Use immediate values when possible** (they avoid register reads).
- **Align loops to 8‑byte boundaries** for best fetch performance (use ``.ADDR``).

9. Debugging Techniques
=======================

9.1. Reading the debug register
-------------------------------

The AXI register at address 0x0F (``debug``) contains many internal state signals. In Python:

.. code-block:: python

   debug_bits = soc.tproc.read_axi_reg(0x0F)
   print(f"PC stall: {(debug_bits >> 4) & 1}")

Refer to the debug bit map in the full register specification.

9.2. Single‑stepping the core
-----------------------------

Set ``tproc_ctrl[10] = 1`` (``CORE_STEP``). The core will execute one instruction and stop.

In Python:

.. code-block:: python

   soc.tproc.core_step()   # if method exists
   # or directly:
   soc.tproc.write_axi_reg(0x00, 1 << 10)

9.3. Using the status register
------------------------------

Poll ``s_status`` in your program or from Python to see if peripherals are ready or FIFOs are full.

10. Reference: Complete Condition Code Table
=============================================

.. list-table::
   :header-rows: 1

   * - Code
     - Meaning
     - Flags tested
     - Typical use
   * - ``ALWAYS`` (or omitted)
     - Always execute
     - none
     - Default
   * - ``Z``
     - Zero
     - Z=1
     - After subtraction or AND
   * - ``NZ``
     - Non‑zero
     - Z=0
     - Loop until counter reaches 0
   * - ``S``
     - Negative (Sign)
     - S=1
     - Check if result < 0
   * - ``NS``
     - Non‑negative
     - S=0
     - Check if result >= 0
   * - ``F``
     - Flag (internal or external)
     - flag=1
     - Wait for Python or peripheral signal
   * - ``NF``
     - Not Flag
     - flag=0
     - Wait for flag to clear

---

*End of Document*