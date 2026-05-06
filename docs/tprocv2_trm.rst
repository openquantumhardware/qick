.. _tprocv2_trm:

==================================================
QICK tProcessor v2 - Complete Reference Manual
==================================================

.. meta::
   :description: Complete reference manual for the QICK tProcessor v2 real-time co-processor

:Version: 2.1
:Last Update: 2026-05-05
:Compatibility: QICK Firmware (>= v0.0.1)
:Audience: Firmware developers, advanced QICK users, researchers

.. note::
   This is the complete reference manual for the tProcessor v2.
   For system-level firmware overview (signal generators, readout, channel assignments),
   see :doc:`/firmware`.

.. contents:: Table of Contents
   :depth: 3

:Version: 2.1
:Last Update: 2026-05-05
:Compatibility: QICK Firmware (>= v0.0.1)
:Audience: Firmware developers, advanced QICK users, researchers

.. contents:: Table of Contents
   :depth: 3

-------------------------------------------------------------------------------

PREFACE: How to use this manual
===============================

This manual is organized by **task**, not just by instruction. If you know what you want to *do* (e.g., "wait for ADC data", "generate a chirp", "synchronize two boards"), look for the **task‑based section** (Chapter 9). If you need the exact encoding of an instruction, see the **reference section** (Chapter 11).

**Conventions used in this manual:**

.. list-table::
   :header-rows: 1

   * - Symbol
     - Meaning
   * - ``[value]``
     - Optional parameter
   * - ``#123``
     - Immediate (literal) value
   * - ``&123``
     - Memory address
   * - ``@123``
     - Time value
   * - ``p0 .. p15``
     - Port number
   * - ``// text``
     - Comment
   * - ``> text``
     - Explanation of the preceding line

-------------------------------------------------------------------------------

1. What is the tProcessor? (Executive Summary)
===============================================

The tProcessor is a **hard real‑time co‑processor** inside the QICK FPGA. It runs a user‑written program that controls waveform generation, data acquisition, and feedback with **nanosecond precision**.

**What it does well:**

* Generate sequences of pulses with precise timing
* React to ADC data within microseconds
* Coordinate multiple DAC/ADC channels
* Run independently of the Linux operating system

**What it does NOT do:**

* Floating‑point math (use fixed‑point or Python pre‑computation)
* Complex control flow (stay mostly linear with short loops)
* Interact with files or networks (that is the ARM's job)

**Typical experiment flow:**

::

    +-------------+     +-------------+     +-------------+     +-------------+
    | Initialize  | --> |  Configure  | --> |  Run tProc  | --> |  Read back  |
    | board, DACs |     | waveforms   |     |  program    |     |  results    |
    +-------------+     +-------------+     +-------------+     +-------------+
          ^                    |                   |                    |
          |                    v                   v                    v
      Python (PS)          Python/ARM          tProcessor           Python/ARM
      (once)               (pre‑compute)       (real‑time)           (post‑process)

-------------------------------------------------------------------------------

.. _tproc-quick-ref:

2. Quick Reference Card
=======================

**Most common instructions (keep this nearby):**

.. code-block:: text

   // Register operations
   REG_WR rd imm #value               // rd = value
   REG_WR rd op -op(rs + #imm)        // rd = rs + imm
   REG_WR rd op -op(rs1 + rs2)        // rd = rs1 + rs2

   // Memory operations
   REG_WR rd dmem [&addr]             // rd = DMEM[addr]
   DMEM_WR [&addr] imm #value         // DMEM[addr] = value

   // Waveform operations
   REG_WR r_wave wmem [&addr]         // load waveform from WMEM
   WPORT_WR pN r_wave @time           // output waveform

   // Port operations
   DPROT_WR pN imm value @time        // output 32‑bit data
   DPROT_WR pN reg rX @time           // output from register
   TRIG pN set @time                  // set trigger high
   TRIG pN clr @time                  // set trigger low
   DPORT_RD pN                        // read input port (to s_port_l/h)

   // Flow control
   JUMP LABEL -if(condition)          // conditional branch
   CALL SUBROUTINE
   RET

   // Waiting
   WAIT time @N                       // wait until current time >= N
   WAIT div_dt                        // wait for division to complete
   WAIT arith_dt                      // wait for ARITH to complete
   WAIT port_dt                       // wait for input port data

   // Peripherals
   DIV num den                        // start division (32 cycles)
   ARITH T rA rB                      // rA * rB (2 cycles)

**Condition codes (most useful):**

.. code-block:: text

   -if(Z)    // zero (result == 0)
   -if(NZ)   // non‑zero (result != 0)  ← most common for loops
   -if(S)    // negative (result < 0)
   -if(NS)   // non‑negative (result >= 0)
   -if(F)    // flag set (internal or external)
   -if(NF)   // flag clear

-------------------------------------------------------------------------------

3. Architecture Deep Dive
=========================

3.1. Block Diagram with Data Flow
---------------------------------

The diagram below shows how data moves through the tProcessor. Follow the arrows to understand pipeline stages.

::

    +=======================================================================+
    ||                           PS (ARM)                                   ||
    ||  +-------------------+    +-------------------+                      ||
    ||  | Python script     |    | DMA controller    |                      ||
    ||  | (notebook, CLI)   |<-->| (AXI master)      |                      ||
    ||  +---------+---------+    +---------+---------+                      ||
    ||            |                        |                                ||
    +=============|========================|================================+
                  |                        |
                  | (AXI‑Lite)             | (AXI‑Stream, DMA)
                  v                        v
    +=======================================================================+
    ||                          tProcessor                                  ||
    ||                                                                      ||
    ||  +------------------+     +---------------------------------------+  ||
    ||  | AXI_REG bank     |     | Dispatcher (t_clk domain)             |  ||
    ||  | * tproc_ctrl     |     |                                       |  ||
    ||  | * tproc_cfg      |     |  +--------+    +--------+    +-----+  |  ||
    ||  | * core_cfg       |     |  | WFIFO  |    | DFIFO  |    | TFIFO| |  ||
    ||  | * src_dt         |     |  |(168b)  |    | (32b)  |    | (1b) | |  ||
    ||  +------------------+     |  +---+----+    +---+----+    +--+--+  |  ||
    ||         |                 |      |             |            |     |  ||
    ||         v                 |      v             v            v     |  ||
    ||  +==================+     |  +-------+    +-------+    +-------+  |  ||
    ||  || CORE (c_clk)   ||     |  | 48‑bit|    | 48‑bit|    | 48‑bit|  |  ||
    ||  ||                ||     |  |compar |    |compar |    |compar |  |  ||
    ||  || +-----------+  ||     |  |  &    |    |  &    |    |  &    |  |  ||
    ||  || | 5‑stage   |  ||     |  +---+---+    +---+---+    +---+---+  |  ||
    ||  || | pipeline  |  ||     |      |            |            |      |  ||
    ||  || | * Fetch   |  ||     |      v            v            v      |  ||
    ||  || | * Decode  |  ||     |  +-------+    +-------+    +-------+  |  ||
    ||  || | * Read    |  ||     |  | WPORT |    | DPORT |    | TRIG  |  |  ||
    ||  || | * Execute |  ||     |  | (analog|   | (digital|   | (1‑bit| |  ||
    ||  || | * Write   |  ||     |  | wave) |    | data) |    | out)  |  |  ||
    ||  || +-----------+  ||     |  +---+---+    +---+---+    +---+---+  |  ||
    ||  ||       |        ||     |      |            |            |      |  ||
    ||  ||       v        ||     +======|============|============|======+  ||
    ||  || +----+----+    ||            v            v            v         ||
    ||  || | ALU     |    ||        [DACs]       [PMODs]      [Triggers]    ||
    ||  || | (DSP)   |    ||                                                ||
    ||  || +----+----+    ||                                                ||
    ||  ||      |         ||                                                ||
    ||  ||      v         ||                                                ||
    ||  || +----+----+    ||                                                ||
    ||  || | DIV     |    ||                                                ||
    ||  || | (32 cyc)|    ||                                                ||
    ||  || +----+----+    ||                                                ||
    ||  ||      |         ||                                                ||
    ||  ||      v         ||                                                ||
    ||  || +----+----+    ||                                                ||
    ||  || | LFSR    |    ||                                                ||
    ||  || |(PRNG)   |    ||                                                ||
    ||  || +---------+    ||                                                ||
    ||  ||                ||                                                ||
    ||  || +-----------+  ||                                                ||
    ||  || | Memories  |  ||                                                ||
    ||  || | * PMEM    |  ||                                                ||
    ||  || | * DMEM    |  ||                                                ||
    ||  || | * WMEM    |  ||                                                ||
    ||  || +-----------+  ||                                                ||
    ||  +==================+                                                ||
    ||                                                                      ||
    ||  +------------------+                                                ||
    ||  | IN_PORT (AXI‑S)  | <─── from ADC or external source               ||
    ||  | (feedback data)  |                                                ||
    ||  +------------------+                                                ||
    +=======================================================================+

3.2. Clock Domain Crossing (CDC) Explained
-------------------------------------------

Because the core and the dispatcher run on different clocks, any communication between them must cross clock domains. This introduces **latency** and **metastability protection**.

**Critical paths and their latencies:**

.. list-table::
   :header-rows: 1

   * - Action
     - From domain
     - To domain
     - Latency (cycles of destination clock)
   * - Write to FIFO (DPORT_WR)
     - c_clk
     - t_clk
     - 2‑3 cycles
   * - FIFO pop to output pin
     - t_clk
     - t_clk (same)
     - 1 cycle
   * - Read input port (DPORT_RD)
     - t_clk (ADC)
     - c_clk
     - 2‑3 cycles
   * - TIME instruction effect
     - c_clk
     - t_clk
     - 3‑5 cycles
   * - FLAG from Python to core
     - ps_clk
     - c_clk
     - several µs (not for tight timing)

**Practical implication:** Do not back‑to‑back TIME instructions without at least 5 c_clk cycles between them.

3.3. FIFO Depth and Flow Control
--------------------------------

The dispatcher has three independent FIFOs:

.. list-table::
   :header-rows: 1

   * - FIFO
     - Entry width
     - Default depth
     - Configurable up to
     - When is it written?
   * - Wave FIFO (WFIFO)
     - 168 bits + 48 bits time
     - 8
     - 512
     - WPORT_WR
   * - Data FIFO (DFIFO)
     - 32 bits + 48 bits time
     - 8
     - 512
     - DPORT_WR
   * - Trigger FIFO (TFIFO)
     - 1 bit + 48 bits time
     - 8
     - 512
     - TRIG

**Flow control behavior:**

When a FIFO becomes full:

- If ``tproc_cfg[10]`` (``DISABLE_FIFO_FULL_PAUSE``) = 0 (default): The core **stalls** (pauses) until space is available.
- If = 1: The core continues, but writes to the full FIFO are **dropped** (data loss).

**Checklist for avoiding FIFO overflow:**

- [ ] Count how many port writes you have in the shortest time window.
- [ ] Ensure that number ≤ FIFO depth.
- [ ] If you need more, increase FIFO depth in the hardware configuration (Chapter 10).
- [ ] Or add ``WAIT fifo_not_full`` (macro) before writes.

-------------------------------------------------------------------------------

.. _tproc-registers:

4. Complete Register Bank Reference
====================================

The tProcessor has three independent register banks. Each bank has a different purpose and access method.

4.1. Register Organization Overview
------------------------------------

The diagram below shows the physical organization of all registers:

::

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                         REGISTER BANKS (total 32+16+6 registers)             ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                              ║
    ║  ┌─────────────────────────────┐    ┌──────────────────────────────┐         ║
    ║  │  DREG (Data Registers)      │    │  SREG (Special Function)     │         ║
    ║  │  ┌─────┬─────────────┐      │    │  ┌─────┬─────────────────┐   │         ║
    ║  │  │ r0  │ general     │      │    │  │ s0  │ s_zero (always0)│   │         ║
    ║  │  │ r1  │ purpose     │      │    │  │ s1  │ s_rand (LFSR)   │   │         ║
    ║  │  │ r2  │ 32-bit      │      │    │  │ s2  │ s_cfg / s_ctrl  │   │         ║
    ║  │  │ ... │ registers   │      │    │  │ s3  │ s_arith_low     │   │         ║
    ║  │  │ r31 │             │      │    │  │ s4  │ s_div_q         │   │         ║
    ║  │  └─────┴─────────────┘      │    │  │ s5  │ s_div_r         │   │         ║
    ║  │                             │    │  │ s6  │ s_core_r1       │   │         ║
    ║  │  Access: REG_WR rd ...      │    │  │ s7  │ s_core_r2       │   │         ║
    ║  │  Example: REG_WR r5 imm #10 │    │  │ s8  │ s_port_l        │   │         ║
    ║  └─────────────────────────────┘    │  │ s9  │ s_port_h        │   │         ║
    ║                                     │  │ s10 │ s_status        │   │         ║
    ║  ┌─────────────────────────────┐    │  │ s11 │ s_usr_time      │   │         ║
    ║  │  WREG (Wave Param Registers)│    │  │ s12 │ s_core_w1       │   │         ║
    ║  │  ┌─────────┬──────────────┐ │    │  │ s13 │ s_core_w2       │   │         ║
    ║  │  │ w0      │ w_freq  (32b)│ │    │  │ s14 │ s_out_time      │   │         ║
    ║  │  │ w1      │ w_phase (32b)│ │    │  │ s15 │ s_addr          │   │         ║
    ║  │  │ w2      │ w_gain  (32b)| │    │  └─────┴─────────────────┘   │         ║
    ║  │  │ w3      │ w_env   (24b)│ │    │                              │         ║
    ║  │  │ w4      │ w_length(32b)│ │    │  Access: REG_WR sX ...       │         ║
    ║  │  │ w5      │ w_conf  (16b)│ │    │  Example: REG_WR s10 op -op()│         ║
    ║  │  └─────────┴──────────────┘ │    └──────────────────────────────┘         ║
    ║  │                             │                                             ║
    ║  │  These 6 registers are      │                                             ║
    ║  │  concatenated to form       │                                             ║
    ║  │  the 168-bit r_wave bus:    │                                             ║
    ║  │                             │                                             ║
    ║  │  r_wave = {w5, w4, w3,      │                                             ║
    ║  │            w2, w1, w0}      │                                             ║
    ║  │                             │                                             ║
    ║  │  Access: REG_WR wX ...      │                                             ║
    ║  │  Example: REG_WR w_freq imm │                                             ║
    ║  └─────────────────────────────┘                                             ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝


4.2. Physical Address Map
-------------------------

Each register has a physical address used internally. You don't need this for assembly
programming (use names like ``r5``, ``s10``, ``w_freq``), but it's useful for debugging
or when reading the AXI debug registers.

.. list-table:: Register Physical Addresses
   :header-rows: 1
   :widths: 15 15 20 50

   * - Bank
     - Address Range
     - Number
     - Assembly Names
   * - DREG
     - 0x00 - 0x1F
     - 32
     - ``r0`` ... ``r31``
   * - SREG
     - 0x20 - 0x2F
     - 16
     - ``s0`` ... ``s15`` (plus aliases)
   * - WREG (wave params)
     - 0x30 - 0x35
     - 6
     - ``w0`` (w_freq), ``w1`` (w_phase), ``w2`` (w_gain), ``w3`` (w_env), ``w4`` (w_length), ``w5`` (w_conf)
   * - Special (r_wave)
     - (virtual)
     - 1
     - ``r_wave`` (168-bit concatenation of all wregs)

4.3. Complete Register Table with Aliases
------------------------------------------

**DREG - Data Registers (r0 - r31)**

These are general purpose. No predefined aliases, but you can create your own:

.. code-block:: text

   .ALIAS loop_counter r0
   .ALIAS temp_result  r1
   .ALIAS dmem_ptr     r2

**SREG - Special Function Registers (s0 - s15)**

.. list-table::
   :header-rows: 1
   :widths: 10 25 15 50

   * - Address
     - Assembly Name
     - Aliases
     - Description / Typical Use
   * - 0x20
     - ``s0``
     - ``s_zero``
     - Always reads as 0. Useful for clearing or as a source.
   * - 0x21
     - ``s1``
     - ``s_rand``
     - Pseudo-random number from LFSR. Configurable behavior via core_cfg.
   * - 0x22
     - ``s2``
     - ``s_cfg`` (lower 16 bits), ``s_ctrl`` (upper 16 bits)
     - Configuration: data sources, flag sources. Write to s_ctrl to clear flags.
   * - 0x23
     - ``s3``
     - ``s_arith_low``
     - Lower 32 bits of ARITH (multiply) result.
   * - 0x24
     - ``s4``
     - ``s_div_q``
     - Quotient from DIV operation.
   * - 0x25
     - ``s5``
     - ``s_div_r``
     - Remainder from DIV operation.
   * - 0x26
     - ``s6``
     - ``s_core_r1``
     - First data word from selected source (see s_cfg DT_SRC).
   * - 0x27
     - ``s7``
     - ``s_core_r2``
     - Second data word from selected source.
   * - 0x28
     - ``s8``
     - ``s_port_l``
     - Lower 32 bits of input port read (DPORT_RD).
   * - 0x29
     - ``s9``
     - ``s_port_h``
     - Upper 32 bits of input port read (DPORT_RD).
   * - 0x2A
     - ``s10``
     - ``s_status``
     - Status flags: peripherals ready, new data, FIFO state.
   * - 0x2B
     - ``s11``
     - ``s_usr_time``, ``curr_usr_time``
     - Current user time (read-only). t_abs - t_ref.
   * - 0x2C
     - ``s12``
     - ``s_core_w1``
     - First data word written from PS (ARM) to core.
   * - 0x2D
     - ``s13``
     - ``s_core_w2``
     - Second data word written from PS to core.
   * - 0x2E
     - ``s14``
     - ``s_out_time``, ``out_usr_time``
     - Output time register for port writes (read/write, signed 32-bit).
   * - 0x2F
     - ``s15``
     - ``s_addr``
     - Address register for JUMP instructions.

**WREG - Wave Parameter Registers (w0 - w5)**

These six registers are **individually accessible** but also concatenated into ``r_wave``.

.. list-table::
   :header-rows: 1
   :widths: 10 15 15 15 45

   * - Address
     - Base Name
     - Alias
     - Bits
     - Description
   * - 0x30
     - ``w0``
     - ``w_freq``
     - 32
     - Frequency control word for DDS. 0 = DC, 2^31 = Nyquist.
   * - 0x31
     - ``w1``
     - ``w_phase``
     - 32
     - Phase offset. 2^32 = 360 degrees.
   * - 0x32
     - ``w2``
     - ``w_gain``
     - 32
     - Amplitude scaling. Signed 32-bit integer.
   * - 0x33
     - ``w3``
     - ``w_env``
     - 24
     - Starting address in envelope table memory.
   * - 0x34
     - ``w4``
     - ``w_length``
     - 32
     - Envelope length in samples.
   * - 0x35
     - ``w5``
     - ``w_conf``
     - 16
     - Configuration bits for signal generator.

**Special Composite: r_wave**

.. code-block:: text

   r_wave is not a physical register. It is a 168-bit bus formed by concatenation:
   
   r_wave = { w5 (w_conf), w4 (w_length), w3 (w_env), 
              w2 (w_gain), w1 (w_phase), w0 (w_freq) }
   
   Bits: 167:152 = w_conf
         151:120 = w_length
         119:96  = w_env
         95:64   = w_gain
         63:32   = w_phase
         31:0    = w_freq

You can write to ``r_wave`` using ``REG_WR r_wave ...``, which updates **all six** wave parameters at once.

4.4. Access Examples by Register Type
--------------------------------------

**Writing to DREG (data registers):**

.. code-block:: text

   REG_WR r5 imm #100           // r5 = 100
   REG_WR r5 op -op(r0 + r1)    // r5 = r0 + r1
   REG_WR r5 dmem [&10]         // r5 = DMEM[10]

**Reading from DREG (as source):**

.. code-block:: text

   REG_WR r6 op -op(r5)         // r6 = r5 (copy)
   DMEM_WR [&20] imm r5         // DMEM[20] = r5
   DPROT_WR p0 reg r5 @100      // output r5 to port

**Writing to SREG:**

.. code-block:: text

   REG_WR s_cfg imm src_arith   // configure data source
   REG_WR s_out_time imm #1000  // set output time
   REG_WR s_addr label LOOP     // store jump address

**Reading from SREG:**

.. code-block:: text

   REG_WR r0 op -op(s_rand)         // r0 = random number
   REG_WR r1 op -op(s_usr_time)     // r1 = current time
   REG_WR r2 op -op(s_status)       // r2 = status bits

**Writing to WREG (individual parameter):**

.. code-block:: text

   REG_WR w_freq imm #0x1000000     // set frequency
   REG_WR w_gain imm #32768         // set gain
   REG_WR w_length imm #1000        // set length

**Writing to r_wave (all parameters at once):**

.. code-block:: text

   REG_WR r_wave wmem [&5]          // load from WMEM
   // or
   REG_WR r_wave imm #0x...         // immediate (not practical, too large)

**Using wreg as source in ALU operations:**

.. code-block:: text

   REG_WR r0 op -op(w_freq)         // r0 = current frequency
   REG_WR r1 op -op(w_freq + #100)  // r1 = frequency + 100

4.5. Flag Register (not memory-mapped)
--------------------------------------

The tProcessor has an **internal flag** (IF) and can also use an **external flag** (EF) set from Python.

.. list-table::
   :header-rows: 1

   * - Flag
     - Set by
     - Cleared by
     - Test with
   * - Internal Flag (IF)
     - ``FLAG set``, or automatically by peripherals
     - ``FLAG clr``
     - ``-if(F)``, ``-if(NF)``
   * - External Flag (EF)
     - Python (tproc_ctrl bit 13)
     - Python (tproc_ctrl bit 14)
     - ``-if(F)``, ``-if(NF)`` (if configured)

Which flag is used by ``-if(F)`` is determined by ``s_cfg[7:4]`` (FLAG_SRC).

4.6. Quick Reference: Register Naming in Assembly
--------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Register Type
     - Prefix
     - Examples
   * - Data registers
     - ``r``
     - ``r0``, ``r1``, ... ``r31``
   * - Special functions
     - ``s``
     - ``s0``, ``s_rand``, ``s_status``, ``s_out_time``
   * - Wave parameters
     - ``w``
     - ``w0``, ``w_freq``, ``w_phase``, ``w_gain``
   * - Composite wave
     - ``r_wave``
     - ``r_wave`` (no number)
   * - Aliases (user-defined)
     - any
     - ``.ALIAS my_var r5`` then use ``my_var``

**Important:** The assembler is case‑sensitive for register names. ``R0`` is NOT the same as ``r0``. Always use lowercase ``r``, ``s``, ``w``.

4.7. Common Mistakes with Registers
------------------------------------

**Mistake 1: Using r_wave when you meant a wreg**

.. code-block:: text

   // Wrong: trying to write only frequency
   REG_WR r_wave imm #0x1000000   // This would zero out other parameters!

   // Correct: write to w_freq directly
   REG_WR w_freq imm #0x1000000

**Mistake 2: Reading s_status without masking**

.. code-block:: text

   // Wrong: compares entire status (many bits may be set)
   TEST -op(s_status - #4)        // checks if status == 4

   // Correct: mask only the bit you care about
   TEST -op(s_status AND #4)      // checks only bit 2

**Mistake 3: Using s_out_time as read‑only**

.. code-block:: text

   // Wrong: trying to read current time
   REG_WR r0 op -op(s_out_time)   // this reads the OUTPUT time, not current time!

   // Correct: use s_usr_time for current time
   REG_WR r0 op -op(s_usr_time)

-------------------------------------------------------------------------------

5. Instruction Set – Task‑Oriented Guide
========================================

5.1. Moving Data
----------------

**Register to register:**

.. code-block:: text

   REG_WR r1 op -op(r0)            // r1 = r0
   REG_WR r1 op -op(s_rand)        // r1 = random number

**Immediate to register:**

.. code-block:: text

   REG_WR r0 imm #12345            // r0 = 12345
   REG_WR r0 imm #hDEADBEEF        // r0 = 0xDEADBEEF (hex)
   REG_WR r0 imm #b10101010        // r0 = 0xAA (binary)

**Memory to register:**

.. code-block:: text

   REG_WR r0 dmem [&100]           // r0 = DMEM[100]
   REG_WR r_wave wmem [&5]         // r_wave = WMEM[5]

**Register to memory:**

.. code-block:: text

   DMEM_WR [&100] imm #42          // DMEM[100] = 42
   DMEM_WR [r0] op -op(r1)         // DMEM[r0] = r1
   WMEM_WR [&5]                    // WMEM[5] = r_wave

5.2. Arithmetic and Logic
-------------------------

**Addition and subtraction:**

.. code-block:: text

   REG_WR r2 op -op(r0 + #100)     // r2 = r0 + 100
   REG_WR r2 op -op(r0 - r1)       // r2 = r0 - r1

**Bitwise operations:**

.. code-block:: text

   REG_WR r2 op -op(r0 AND #hFF)   // r2 = r0 & 0xFF (lower byte)
   REG_WR r2 op -op(r0 OR r1)      // r2 = r0 | r1
   REG_WR r2 op -op(r0 XOR r1)     // r2 = r0 ^ r1
   REG_WR r2 op -op(NOT r0)        // r2 = ~r0

**Shifts:**

.. code-block:: text

   REG_WR r2 op -op(r0 SL #2)      // r2 = r0 << 2 (logical left)
   REG_WR r2 op -op(r0 SR #1)      // r2 = r0 >> 1 (logical right)
   REG_WR r2 op -op(r0 ASR #1)     // r2 = r0 >> 1 (arithmetic, sign preserved)

**Special operations:**

.. code-block:: text

   REG_WR r2 op -op(MSH r0)        // r2 = upper 16 bits of r0
   REG_WR r2 op -op(LSH r0)        // r2 = lower 16 bits of r0
   REG_WR r2 op -op(SWP r0)        // r2 = swap upper and lower 16 bits
   REG_WR r2 op -op(ABS r0)        // r2 = |r0| (absolute value)
   REG_WR r2 op -op(PAR r0)        // r2 = parity of r0 (0 or 1)

5.3. Multiplication (ARITH)
---------------------------

The ARITH unit uses the FPGA's DSP48 slices. It can compute (D ± A) * B ± C in 2 cycles.

**Operation codes (second letter indicates pattern):**

.. list-table::
   :header-rows: 1
   :widths: 20 20 40

   * - Mnemonic
     - Formula
     - Example
   * - ``ARITH T A B``
     - A * B
     - ``ARITH T r1 r2`` = r1 * r2
   * - ``ARITH TP A B C``
     - A * B + C
     - ``ARITH TP r1 w_freq s_rand`` = r1 * w0 + s1
   * - ``ARITH TM A B C``
     - A * B - C
     - ``ARITH TM r1 s2 r3`` = r1 * s2 - r3
   * - ``ARITH PT A B C``
     - (D + A) * B
     - ``ARITH PT r2 r1 w_gain`` = (r2 + r1) * w3
   * - ``ARITH MT A B C``
     - (D - A) * B
     - ``ARITH MT r1 r2 r3`` = (r1 - r2) * r3
   * - ``ARITH PTP A B C D``
     - (D + A) * B + C
     - ``ARITH PTP r1 s_rand r3 r4`` = (r1 + s1) * r3 + r4
   * - ``ARITH PTM A B C D``
     - (D + A) * B - C
     - ``ARITH PTM r1 r2 r3 r4`` = (r1 + r2) * r3 - r4
   * - ``ARITH MTP A B C D``
     - (D - A) * B + C
     - ``ARITH MTP r1 s2 w3 r4`` = (r1 - s2) * w3 + r4
   * - ``ARITH MTM A B C D``
     - (D - A) * B - C
     - ``ARITH MTM r1 r2 r3 r4`` = (r1 - r2) * r3 - r4
  

**Typical use: multiply‑accumulate for digital filtering**

.. code-block:: text

   // Example: y = (r1 * r2) + r3
   REG_WR r1 imm #100
   REG_WR r2 imm #200
   REG_WR r3 imm #50
   ARITH T r1 r2                   // r1 * r2 takes 2 cycles
   WAIT arith_dt
   REG_WR r4 op -op(s_arith_low)   // r4 = 20000 (product)
   REG_WR r4 op -op(r4 + r3)       // r4 = 20000 + 50 = 20050

   // Using combined operation (faster):
   // ARITH PTP r1 r2 zero r3   // assuming zero is a register that holds 0
   // WAIT arith_dt
   // REG_WR r4 op -op(s_arith_low)   // r4 = (r1+r2)*0 + r3 ?? Not correct.

**Better real example: (A * B) + C with ARITH**

The ARITH unit can compute (D ± A) * B ± C. To get A * B + C, set D=0, use addition for the first term, and addition for the last term. You need a register that contains 0 (use s_zero).

.. code-block:: text

   // (0 + r1) * r2 + r3
   ARITH PTP r1 r2 s_zero r3
   WAIT arith_dt
   REG_WR r4 op -op(s_arith_low)

ARITH Command Decoder: Understanding PTP, MTM, T, etc.
------------------------------------------------------------

The ARITH instruction uses a compact 2-3 letter code that encodes the entire formula.

**Formula Pattern:** (D ± A) * B ± C

Where:
- **A, B, C, D** are registers (rX, sY, or wZ)
- **D** is often s_zero (0) if not used

**Decoding the mnemonic:**

The mnemonic consists of up to 3 letters. Read them from LEFT to RIGHT:

.. list-table:: ARITH Mnemonic Decoder
   :header-rows: 1
   :widths: 15 25 50

   * - Mnemonic
     - Number of operands
     - Formula
   * - T
     - 2
     - A * B
   * - PT
     - 3
     - (A + B) * C
   * - MT
     - 3
     - (A - B) * C
   * - PTP
     - 4
     - (A + B) * C + D
   * - PTM
     - 4
     - (A + B) * C - D
   * - MTP
     - 4
     - (A - B) * C + D
   * - MTM
     - 4
     - (A - B) * C - D

**Memory trick to remember:**

.. code-block:: text

   T  = Times (multiply only)
   P  = Plus (addition in first part)
   M  = Minus (subtraction in first part)
   TP = Times Plus (multiply then add)
   TM = Times Minus (multiply then subtract)

   Read PT as "Plus then Times" → (A+B)*C
   Read PTP as "Plus then Times then Plus" → (A+B)*C + D

**Examples decoded:**

.. code-block:: text

   ARITH T r1 r2           → r1 × r2
   ARITH PT r1 r2 r3       → (r1 + r2) × r3
   ARITH MT r1 r2 r3       → (r1 - r2) × r3
   ARITH PTP r1 r2 r3 r4   → (r1 + r2) × r3 + r4
   ARITH PTM r1 r2 r3 r4   → (r1 + r2) × r3 - r4
   ARITH MTP r1 r2 r3 r4   → (r1 - r2) × r3 + r4
   ARITH MTM r1 r2 r3 r4   → (r1 - r2) × r3 - r4

**Quick Reference Card for ARITH:**

.. code-block:: text

   ┌─────────────────────────────────────────────────────────────────┐
   │  USE THIS CHEAT SHEET FOR ARITH                                 │
   ├─────────────────────────────────────────────────────────────────┤
   │                                                                 │
   │  Need: A * B                 →  ARITH T rA rB                   │
   │  Need: (A + B) * C           →  ARITH PT rA rB rC               │
   │  Need: (A - B) * C           →  ARITH MT rA rB rC               │
   │  Need: (A + B) * C + D       →  ARITH PTP rA rB rC rD           │
   │  Need: (A + B) * C - D       →  ARITH PTM rA rB rC rD           │
   │  Need: (A - B) * C + D       →  ARITH MTP rA rB rC rD           │
   │  Need: (A - B) * C - D       →  ARITH MTM rA rB rC rD           │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘

**Complete Working Example:**

.. code-block:: text

   // Calculate: (r1 + r2) * r3 + r4
   REG_WR r1 imm #10
   REG_WR r2 imm #20
   REG_WR r3 imm #3
   REG_WR r4 imm #5
   
   ARITH PTP r1 r2 r3 r4
   WAIT arith_dt
   REG_WR r5 op -op(s_arith_low)   // r5 = (10+20)*3+5 = 95

5.4. Division (DIV)
--------------------

The DIV block performs **unsigned** 32‑bit integer division in 32 cycles.

**Syntax:**

.. code-block:: text

   DIV numerator denominator

- numerator: a register (rX, sY, or wZ)
- denominator: a register OR a 24‑bit immediate (#value)

**Example: divide r1 by r2, get quotient and remainder**

.. code-block:: text

   DIV r1 r2                // start division
   WAIT div_dt              // wait 32 cycles (macro)
   REG_WR r3 op -op(s_div_q)   // r3 = quotient
   REG_WR r4 op -op(s_div_r)   // r4 = remainder

**Important:** Division is unsigned only. For signed division, convert to positive, divide, then adjust sign.

5.5. Flow Control
-----------------

**Unconditional jump:**

.. code-block:: text

   JUMP LABEL               // always jump

**Conditional jump (most common for loops):**

.. code-block:: text

   JUMP LABEL -if(NZ)       // jump if last ALU result was not zero

**Conditional jump with decrement (standard loop pattern):**

.. code-block:: text

   REG_WR r0 imm #10        // r0 = 10 (loop counter)
   LOOP:
      // ... do something ...
      JUMP LOOP -wr(r0 op) -op(r0 - #1) -uf   // decrement r0, update flags, jump if not zero

**Avoiding the branch penalty:**

Because branches cause a 2‑cycle pipeline flush, use conditional execution for simple cases:

.. code-block:: text

   // Instead of:
   // JUMP SKIP -if(Z)
   // REG_WR r1 imm #1
   // SKIP:

   // Do:
   REG_WR r1 imm #1 -if(NZ)   // only executed if Z flag is NOT set

5.6. Subroutines (CALL/RET)
---------------------------

The tProc supports nested calls up to 256 levels deep.

.. code-block:: text

   CALL MY_SUBROUTINE
   // ... after subroutine returns, execution continues here

   MY_SUBROUTINE:
      // ... do something ...
      RET

**Important:** The stack only stores return addresses, not local variables. Use registers or DMEM for local storage.

5.7. Waiting (WAIT macro)
-------------------------

The ``WAIT`` macro expands to a small loop. It is convenient but not cycle‑accurate to single cycles.

**Expansion of ``WAIT time @N``:**

.. code-block:: text

   // Original: WAIT time @1000
   // Expands to:
   TEST -op(s_usr_time - #1000)
   JUMP HERE -if(S)         // loop until s_usr_time >= 1000

**Expansion of ``WAIT div_dt`` (wait for division to complete):**

.. code-block:: text

   // Original: WAIT div_dt
   // Expands to:
   TEST -op(s_status AND #8)   // test DIV_DT_NEW bit (bit 3)
   JUMP HERE -if(Z)            // loop until bit is set

**Custom wait for a specific flag:**

.. code-block:: text

   // Wait for ARITH_RDY (bit 0 of s_status)
   WAIT_LOOP:
      TEST -op(s_status AND #1)
      JUMP WAIT_LOOP -if(Z)

5.8. Clearing Flags (CLEAR)
---------------------------

The ``CLEAR`` macro clears the ``_NEW`` flags in ``s_status``.

.. code-block:: text

   CLEAR arith      // clears bit 1 (ARITH_DT_NEW)
   CLEAR div        // clears bit 3 (DIV_DT_NEW)
   CLEAR port       // clears all PORT_DT_NEW bits (31:16)
   CLEAR qnet       // clears QNET related bits

**Pattern for reading a peripheral only when new data is ready:**

.. code-block:: text

   WAIT arith_dt
   REG_WR r0 op -op(s_arith_low)   // read result
   CLEAR arith                      // acknowledge, clear flag

-------------------------------------------------------------------------------

6. Time Management
==================

6.1. Time Variables Recap
-------------------------

- ``t_abs``: 48‑bit counter, runs at DAC frequency (t_clk). Counts absolute time since last reset.
- ``t_ref``: 48‑bit reference. Defines where user time = 0.
- ``t_usr = t_abs - t_ref``: user time, available in ``s_usr_time``.
- ``t_out_user``: 32‑bit signed value you specify in port writes.
- ``t_abs_out = t_ref + t_out_user``: absolute time when output will occur.

**Why signed t_out_user?**  
You can schedule outputs with a **negative** offset, meaning "output at time X relative 
to reference, even if reference is in the past". This is useful for synchronizing with 
other boards or for pre‑calculated sequences where the reference moves.

6.2. TIME Instructions
----------------------

.. code-block:: text

   TIME rst           // t_abs = 0, t_ref = 0, core resets
   TIME set_ref rX    // t_ref = rX (t_abs unchanged)
   TIME inc_ref #N    // t_ref = t_ref + N
   TIME updt #N       // t_abs = t_abs + N (rarely used)

**Typical initialization sequence:**

.. code-block:: text

   TIME rst           // start from zero
   // ... wait for external trigger ...
   TIME set_ref r0    // once triggered, set t_ref to current t_abs (so t_usr becomes 0)

6.3. Scheduling Outputs
------------------------

**Fixed time (immediate):**

.. code-block:: text

   WPORT_WR p0 r_wave @1000    // output at t_usr = 1000

**Relative to previous output:**

.. code-block:: text

   REG_WR s_out_time imm #1000
   WPORT_WR p0 r_wave @s_out_time
   REG_WR s_out_time op -op(s_out_time + #500)
   WPORT_WR p0 r_wave @s_out_time   // 500 cycles after first

**Variable time from register:**

.. code-block:: text

   REG_WR r0 imm #2000
   WPORT_WR p0 r_wave @r0          // @r0 is allowed? Check syntax.

**Note:** The assembler accepts ``@rX`` (time from register) but the manual shows only immediate or s_out_time. Verify.

6.4. Waiting for a Specific Time
--------------------------------

.. code-block:: text

   WAIT time @5000     // pause execution until t_usr >= 5000

-------------------------------------------------------------------------------

7. Input/Output Programming
===========================

7.1. Output Ports
-----------------

**Data ports (DPORT)**: 32‑bit digital outputs

.. code-block:: text

   DPROT_WR p0 imm 0x12345678 @1000
   DPROT_WR p2 reg r5 @2000

**Trigger ports (TRIG)**: 1‑bit outputs (set high or low)

.. code-block:: text

   TRIG p0 set @150    // output 1
   TRIG p0 clr @200    // output 0

**Wave ports (WPORT)**: 168‑bit waveform parameters

.. code-block:: text

   WPORT_WR p1 r_wave @1000        // from r_wave
   WPORT_WR p1 wmem [&5] @2000     // from WMEM address 5

7.2. Input Ports (Feedback)
---------------------------

Input ports receive data from ADCs or other sources via AXI‑Stream.

**Reading a single port (64 bits total):**

.. code-block:: text

   WAIT port_dt        // wait until any input port has new data
   DPORT_RD p0         // read port 0 -> s_port_l (lower 32) and s_port_h (upper 32)
   REG_WR r0 op -op(s_port_l)   // use lower part

**Checking which port received data (advanced):**

The ``s_status`` register has bits 31:16 indicating which port has fresh data. You can test individual bits.

.. code-block:: text

   // Wait specifically for port 2 (bit 18)
   WAIT_PORT2:
      TEST -op(s_status AND #(1<<18))
      JUMP WAIT_PORT2 -if(Z)
   DPORT_RD p2

7.3. External Flag (Python to tProc)
------------------------------------

Python can set or clear an external flag that the tProc can test with ``-if(F)`` or ``-if(NF)``.

**From Python:**

.. code-block:: python

   soc.tproc.set_external_flag()   # sets bit 13 of tproc_ctrl
   soc.tproc.clear_external_flag() # sets bit 14

**In assembly:**

.. code-block:: text

   WAIT_FOR_FLAG:
      REG_WR r0 imm #0 -if(NF)     // do nothing if flag not set
      JUMP WAIT_FOR_FLAG -if(NF)   // loop if flag not set
      // flag is set, proceed

-------------------------------------------------------------------------------

.. _tproc-peripherals:

8. Peripherals Deep Dive
========================

8.1. ARITH (Multiply‑Accumulate)
--------------------------------

The ARITH unit is the most powerful peripheral. It can replace multiple ALU instructions.

**Configuration before using ARITH:**

.. code-block:: text

   // 1. Set data source for s_core_r1 to ARITH
   REG_WR s_cfg imm src_arith

   // 2. Clear any old new‑data flag
   REG_WR s_ctrl imm clr_arith

**Start an ARITH operation:**

.. code-block:: text

   ARITH T r1 r2        // r1 * r2 (2 cycles)

**Wait for completion:**

.. code-block:: text

   WAIT arith_dt        // macro: poll ARITH_DT_NEW bit

**Read the result (64 bits):**

.. code-block:: text

   REG_WR r_low op -op(s_arith_low)    // lower 32 bits
   // s3 (s_arith_low) holds the result
   // For upper 32 bits, s4? Actually ARITH result is 64 bits, but only lower 32 bits are exposed in s3.

**Note:** The ARITH unit produces a 64‑bit result. However, the manual shows only ``s_arith_low`` (s3). The upper 32 bits may be available in another register (s_arith_high?) or may be discarded. Check the actual firmware.

8.2. DIV (Integer Division)
---------------------------

Division is slow (32 cycles) but non‑blocking: the CPU continues execution while DIV works in the background.

**Best practice:** Start a division early, do other work, then check for completion.

.. code-block:: text

   // Start division early
   DIV r1 r2

   // Do other useful work while division runs
   REG_WR r3 op -op(r3 + #100)
   REG_WR r4 op -op(r4 - #50)

   // Wait for division to complete
   WAIT div_dt
   REG_WR r5 op -op(s_div_q)   // quotient
   REG_WR r6 op -op(s_div_r)   // remainder

8.3. LFSR (Random Number Generator)
------------------------------------

Configure via ``core_cfg`` AXI register.

**Modes:**

- 0: Stop (do not advance)
- 1: Free running (advance every c_clk cycle)
- 2: Advance when read
- 3: Advance when written (write any value to s_rand)

**Example: advance‑on‑read mode**

.. code-block:: text

   // Configure from Python
   soc.tproc.write_axi_reg(0x07, 0x02)   // core_cfg = 2 (advance on read)

   // In assembly: each read gives a new random number
   REG_WR r0 op -op(s_rand)   // first random
   REG_WR r1 op -op(s_rand)   // second random (different)

-------------------------------------------------------------------------------

.. _tproc-examples:

9. Task‑Based Examples (Copy‑Paste Ready)
==========================================

9.1. Generate a Single Pulse
----------------------------

.. code-block:: text

   .ADDR 0x00
   // Configure waveform
   REG_WR w_freq imm #0x1000000      // 1 MHz (example)
   REG_WR w_phase imm #0
   REG_WR w_gain imm #32768          // half amplitude
   REG_WR w_length imm #1000         // 1000 samples
   REG_WR w_conf imm #0

   // Output at time 1000
   WPORT_WR p1 r_wave @1000
   .END

9.2. Generate a Pulse Train
---------------------------

.. code-block:: text

   .ADDR 0x00
   REG_WR r0 imm #10                 // number of pulses
   REG_WR s_out_time imm #1000       // start time

   LOOP:
      WPORT_WR p1 r_wave @s_out_time
      REG_WR s_out_time op -op(s_out_time + #500)   // 500 cycle spacing
      REG_WR r0 op -op(r0 - #1) -uf
      JUMP LOOP -if(NZ)
      .END

9.3. Conditional Pulse Based on ADC Value
------------------------------------------

.. code-block:: text

   .ADDR 0x00
   // Initialization
   REG_WR s_out_time imm #1000
   REG_WR r0 imm #100    

   // Configure waveform A (long pulse)
   REG_WR w_freq imm #0x1000000
   REG_WR w_gain imm #32768
   REG_WR w_length imm #2000
   REG_WR w_conf imm #0
   // Save a copy to WMEM
   WMEM_WR [&0]

   // Configure waveform B (short pulse)
   REG_WR w_length imm #500
   WMEM_WR [&1]

   // Main loop
   REG_WR r0 imm #100               // number of experiments

   EXPERIMENT:
      WAIT port_dt                      // wait for ADC data
      DPORT_RD p0                       // read port 0
      REG_WR r1 op -op(s_port_l)        // r1 = ADC value
      REG_WR r1 op -op(r1 - #32768) -uf // compare with threshold

      // Select waveform based on comparison
      REG_WR r_wave wmem [&0] -if(NS)   // long pulse if ADC >= 32768
      REG_WR r_wave wmem [&1] -if(S)    // short pulse if ADC < 32768

      WPORT_WR p1 r_wave @s_out_time
      REG_WR s_out_time op -op(s_out_time + #2000)   // wait for next experiment

      REG_WR r0 op -op(r0 - #1) -uf
      JUMP EXPERIMENT -if(NZ)
      .END

9.4. Frequency Sweep (Chirp)
----------------------------

.. code-block:: text

   .ADDR 0x00
   REG_WR r0 imm #100               // number of steps
   REG_WR r1 imm #0x1000000         // start frequency
   REG_WR s_out_time imm #1000

LOOP:
   REG_WR w_freq op -op(r1)
   WPORT_WR p1 r_wave @s_out_time
   REG_WR r1 op -op(r1 + #0x10000)  // increment frequency
   REG_WR s_out_time op -op(s_out_time + #500)
   REG_WR r0 op -op(r0 - #1) -uf
   JUMP LOOP -if(NZ)
   .END

9.5. Wait for External Trigger (from Python flag)
--------------------------------------------------

.. code-block:: text

   .ADDR 0x00
   // Wait for Python to set external flag
   WAIT_TRIG:
      JUMP WAIT_TRIG -if(NF)           // loop while flag is 0
      // Flag is set, continue
      WPORT_WR p1 r_wave @1000
      .END

From Python:

.. code-block:: python

   soc.tproc.set_external_flag()    # triggers the tProc

9.6. Read and Accumulate ADC Data
---------------------------------

.. code-block:: text

   .ADDR 0x00
   REG_WR r0 imm #0                  // accumulator
   REG_WR r1 imm #100                // number of samples

LOOP:
   WAIT port_dt
   DPORT_RD p0
   REG_WR r0 op -op(r0 + s_port_l)   // accumulate
   REG_WR r1 op -op(r1 - #1) -uf
   JUMP LOOP -if(NZ)

   // Store result to DMEM
   DMEM_WR [&0] imm r0               // result at DMEM address 0
   .END

-------------------------------------------------------------------------------

10. System Configuration (Hardware Parameters)
==============================================

The tProcessor can be configured at synthesis time (in the FPGA bitstream) to match your needs. The following parameters trade off resource usage against capabilities.

10.1. Memory Sizes
------------------

.. list-table::
   :header-rows: 1

   * - Parameter
     - Width (bits)
     - Minimum
     - Maximum
     - Default (QICK)
     - When to increase
   * - PMEM_AW (Program Memory address bits)
     - 2^AW words
     - 8 (256 words)
     - 16 (65536)
     - 10 (1024 words)
     - Complex programs with many instructions
   * - DMEM_AW (Data Memory address bits)
     - 2^AW words
     - 8 (256)
     - 16 (65536)
     - 10 (1024)
     - Large lookup tables or data buffers
   * - WMEM_AW (Wave Memory address bits)
     - 2^AW words
     - 8 (256)
     - 11 (2048)
     - 10 (1024)
     - Many pre‑computed waveforms
   * - REG_AW (Number of data registers)
     - 2^AW registers
     - 4 (16 registers)
     - 5 (32 registers)
     - 5 (32 registers)
     - Usually fine at 32

10.2. FIFO Depths
-----------------

.. list-table::
   :header-rows: 1

   * - Parameter
     - Default
     - Maximum
     - Resource cost
   * - FIFO_DEPTH (all three FIFOs)
     - 8
     - 512
     - Increases BRAM usage

**Choosing FIFO depth:** Set to the maximum number of pending port writes you may have. If your program writes 20 ports between waiting periods, set depth ≥ 20.

10.3. Port Counts
-----------------

.. list-table::
   :header-rows: 1

   * - Parameter
     - Default (QICK)
     - Maximum
   * - IN_PORT_QTY (input ports)
     - 4
     - 16
   * - OUT_TRIG_QTY (trigger ports)
     - 4
     - 8
   * - OUT_DPORT_QTY (data ports)
     - 1
     - 4
   * - OUT_DPORT_DW (data port width, bits)
     - 4
     - 32
   * - OUT_WPORT_QTY (wave ports)
     - 1
     - 16

**Note:** Increasing port counts increases FPGA resource usage and may reduce maximum clock frequency.

-------------------------------------------------------------------------------

11. Complete Instruction Reference (Alphabetical)
==================================================

11.1. ARITH
-----------

**Purpose:** Start a multiply‑accumulate operation on the DSP.

**Syntax:** ``ARITH op A B [C D]``

**Operation codes:**

- ``T``: A * B
- ``PT``: (A + B) * C
- ``MT``: (A - B) * C
- ``PTP``: (A + B) * C + D
- ``PTM``: (A + B) * C - D
- ``MTP``: (A - B) * C + D
- ``MTM``: (A - B) * C - D

**Latency:** 2 cycles

**Flags affected:** None (but sets ARITH_DT_NEW in s_status)

**Example:** ``ARITH T r1 r2``

11.2. CALL
----------

**Purpose:** Call a subroutine (save PC to stack).

**Syntax:** ``CALL address``

**Address can be:** label, immediate (&addr), or s_addr.

**Latency:** 2 cycles (branch penalty)

**Max nesting:** 256

**Example:** ``CALL MY_SUB``

11.3. CLEAR (macro)
-------------------

**Purpose:** Clear ``_NEW`` flag in s_status.

**Syntax:** ``CLEAR option``

**Options:** ``arith``, ``div``, ``port``, ``qnet``

**Expands to:** ``REG_WR s_ctrl imm value``

**Example:** ``CLEAR arith``

11.4. DIV
---------

**Purpose:** Start unsigned 32‑bit integer division.

**Syntax:** ``DIV numerator denominator``

- numerator: register
- denominator: register or 24‑bit immediate

**Latency:** 32 cycles (non‑blocking)

**Results:** s_div_q (quotient), s_div_r (remainder)

**Example:** ``DIV r1 r2``

11.5. DMEM_WR
-------------

**Purpose:** Write to Data Memory.

**Syntax:** ``DMEM_WR [address] source``

**Address modes:**
- ``[&imm]`` – literal
- ``[rX]`` – register
- ``[rX + &imm]`` – indexed literal
- ``[rX + rY]`` – indexed register

**Source:** ``imm #value`` or ``op -op(...)``

**Example:** ``DMEM_WR [&10] imm #42``

11.6. DPORT_RD
--------------

**Purpose:** Read input port.

**Syntax:** ``DPORT_RD port``

**Result:** s_port_l (lower 32 bits), s_port_h (upper 32 bits)

**Sets:** PORT_DT_NEW flag for that port (cleared by read or CLEAR port)

**Example:** ``DPORT_RD p0``

11.7. DPORT_WR
--------------

**Purpose:** Write 32‑bit data to output port.

**Syntax:** ``DPORT_WR port source [time]``

**Source:** ``imm #value`` or ``reg rX``

**Time:** ``@imm`` or ``@s_out_time`` (default = s_out_time)

**Example:** ``DPORT_WR p0 imm 1 @1000``

11.8. FLAG
----------

**Purpose:** Modify internal flag.

**Syntax:** ``FLAG operation``

**Operations:** ``set``, ``clr``, ``inv``

**Example:** ``FLAG set``

11.9. JUMP
----------

**Purpose:** Conditional or unconditional branch.

**Syntax:** ``JUMP address -if(condition)``

**Address:** label, ``HERE``, ``PREV``, ``NEXT``, ``SKIP``, immediate, or s_addr

**Latency:** 2 cycles if taken

**Example:** ``JUMP LOOP -if(NZ)``

11.10. NOP
----------

**Purpose:** No operation.

**Syntax:** ``NOP``

**Latency:** 1 cycle

11.11. REG_WR
-------------

**Purpose:** Write to register (r, s, or w).

**Syntax:** ``REG_WR destination source``

**Source:** ``imm #value``, ``op -op(...)``, ``dmem [addr]``, ``wmem [addr]``, ``label address``

**Example:** ``REG_WR r0 imm #100``

11.12. RET
----------

**Purpose:** Return from subroutine.

**Syntax:** ``RET``

**Latency:** 2 cycles

11.13. TEST
-----------

**Purpose:** Perform ALU operation and update flags without writing a register.

**Syntax:** ``TEST -op(operation) -uf``

**Example:** ``TEST -op(r0 - #1) -uf``

11.14. TIME
-----------

**Purpose:** Control time counters.

**Syntax:** ``TIME operation [value]``

**Operations:** ``rst``, ``set_ref``, ``inc_ref``, ``updt``

**Example:** ``TIME rst``

11.15. TRIG
-----------

**Purpose:** Set or clear trigger output.

**Syntax:** ``TRIG port operation [time]``

**Operation:** ``set`` or ``clr``

**Time:** ``@imm`` or ``@s_out_time``

**Example:** ``TRIG p0 set @150``

11.16. WAIT (macro)
-------------------

**Purpose:** Wait for condition.

**Syntax:** ``WAIT condition``

**Conditions:** ``time @N``, ``div_rdy``, ``div_dt``, ``arith_rdy``, ``arith_dt``, ``port_dt``

**Example:** ``WAIT time @1000``

11.17. WMEM_WR
--------------

**Purpose:** Write r_wave to Wave Parameter Memory.

**Syntax:** ``WMEM_WR [address]``

**Address:** ``[&imm]`` or ``[rX]``

**Example:** ``WMEM_WR [&5]``

11.18. WPORT_WR
---------------

**Purpose:** Write waveform to wave port.

**Syntax:** ``WPORT_WR port source [time]``

**Source:** ``r_wave`` or ``wmem [addr]``

**Example:** ``WPORT_WR p1 r_wave @1000``

-------------------------------------------------------------------------------

12. Python API Reference
========================

12.1. Initialization
--------------------

.. code-block:: python

   from qick import *
   soc = QickSoc(address="192.168.1.10")   # or omit for default
   # tProc is available as soc.tproc

12.2. Memory Operations
-----------------------

.. code-block:: python

   # Load program to PMEM (from binary)
   soc.tproc.load_mem(prog_mem=bin_data)

   # Write to DMEM (single word)
   soc.tproc.write_dmem(addr, data)

   # Read from DMEM (block)
   data = soc.tproc.read_dmem(addr, length)

   # Write waveform to WMEM
   soc.tproc.load_wave(addr, {"freq": 1000, "phase": 0, "gain": 32768, "length": 1024, "conf": 0})

12.3. Control Commands
----------------------

.. code-block:: python

   soc.tproc.start()           # start core and time
   soc.tproc.stop()            # stop core and time
   soc.tproc.time_rst()        # reset time and core
   soc.tproc.core_start()      # reset and start only core
   soc.tproc.core_stop()       # stop only core
   soc.tproc.set_external_flag()
   soc.tproc.clear_external_flag()

12.4. Status Reading
--------------------

.. code-block:: python

   status = soc.tproc.read_status()   # returns dict with bits
   print(status['ARITH_RDY'])
   print(status['DIV_RDY'])
   print(status['FIFO_FULL'])

   usr_time = soc.tproc.time_usr      # read s_usr_time
   rand = soc.tproc.rand              # read s_rand

12.5. Direct AXI Register Access
--------------------------------

.. code-block:: python

   soc.tproc.write_axi_reg(addr, value)
   value = soc.tproc.read_axi_reg(addr)

-------------------------------------------------------------------------------

.. _tproc-pitfalls:

13. Common Pitfalls and Debugging
==================================

13.1. Pitfall: Forgetting to Wait for Peripherals
-------------------------------------------------

**Wrong:**

.. code-block:: text

   ARITH T r1 r2
   REG_WR r3 op -op(s_arith_low)   // reads stale data!

**Correct:**

.. code-block:: text

   ARITH T r1 r2
   WAIT arith_dt
   REG_WR r3 op -op(s_arith_low)

13.2. Pitfall: FIFO Overflow
----------------------------

**Symptom:** Program stalls unexpectedly.

**Check:** ``s_status[15]`` (FIFO_FULL)

**Fix:** Increase FIFO depth in hardware, or add delays between port writes.

13.3. Pitfall: Branch Penalty in Tight Loops
--------------------------------------------

**Symptom:** Loop takes longer than expected.

**Example of inefficient loop:**

.. code-block:: text

   LOOP:
      // ... code ...
      JUMP LOOP -if(NZ)    // 2 cycle penalty each iteration

**Better: use conditional execution or unroll.**

13.4. Pitfall: Using s_out_time Incorrectly
--------------------------------------------

**Wrong:**

.. code-block:: text

   WPORT_WR p0 r_wave @1000
   WPORT_WR p0 r_wave @2000   // second write uses immediate 2000

**Correct (using s_out_time for incremental timing):**

.. code-block:: text

   REG_WR s_out_time imm #1000
   WPORT_WR p0 r_wave @s_out_time
   REG_WR s_out_time op -op(s_out_time + #1000)
   WPORT_WR p0 r_wave @s_out_time

13.5. Debugging Technique: Single Step
---------------------------------------

From Python:

.. code-block:: python

   soc.tproc.core_step()   # execute one instruction, then stop

You can single‑step through your program to see where it gets stuck.

13.6. Debugging Technique: Read Debug Register
----------------------------------------------

.. code-block:: python

   dbg = soc.tproc.read_axi_reg(0x0F)
   # Bit 4: core_stall (1 = core is stalled due to FIFO full)
   # Bit 5: time_en (0 = time stopped)
   # Bits 9:8: core state (0=stop, 1=run, 2=reset, 3=stall)

-------------------------------------------------------------------------------

14. FAQ (Frequently Asked Questions)
====================================

**Q1: Can I use floating‑point numbers?**  
A: No. The tProc only supports integer arithmetic. Pre‑compute floats in Python and convert to fixed‑point (e.g., scale by 2^16).

**Q2: What is the maximum program size?**  
A: Up to 65536 instructions (64 bits each) if configured with PMEM_AW=16. Default is 1024 instructions.

**Q3: How accurate is the timing?**  
A: The dispatcher compares times every t_clk cycle. Jitter is ±1 t_clk cycle (~2.6 ns at 384 MHz). The 5‑cycle write‑to‑output latency is deterministic.

**Q4: Can I interrupt the tProc?**  
A: Not in the current version. The tProc runs to completion or until stopped by Python.

**Q5: How do I synchronize two tProcessors on different boards?**  
A: Use the SYNC signal (abs_time bit 29) or external triggers. Distribute a common reference clock.

**Q6: What happens when time overflows (48 bits)?**  
A: Time rolls over to 0. For long experiments, reset time periodically or use relative timing.

**Q7: Can I use a register as a time value in @?**  
A: The assembler supports ``@rX`` but this manual recommends using s_out_time for clarity.

**Q8: Why does my program get stuck on WAIT div_dt?**  
A: You may have forgotten to start a division (DIV) before waiting. Or the division completed long ago and you need to clear the flag.

**Q9: How do I generate a sine wave?**  
A: The signal generator (separate block) generates sine/cosine from DDS. The tProc only sends frequency/phase/gain parameters.

**Q10: Can I read the same input port multiple times?**  
A: Yes. Each read clears the PORT_DT_NEW flag for that port. New data will set it again.

-------------------------------------------------------------------------------

15. Glossary
============

.. list-table::
   :header-rows: 1

   * - Term
     - Definition
   * - ALU
     - Arithmetic Logic Unit. Performs integer operations.
   * - AXI‑Lite
     - Simple AXI protocol for register access.
   * - AXI‑Stream
     - Streaming AXI protocol for high‑bandwidth data.
   * - CDC
     - Clock Domain Crossing. Transferring data between different clock domains.
   * - DDS
     - Direct Digital Synthesizer. Generates sine/cosine waves.
   * - Dispatcher
     - Hardware block that compares time and updates outputs.
   * - DMA
     - Direct Memory Access. Transfers data without CPU involvement.
   * - DMEM
     - Data Memory. 32‑bit wide, for user data.
   * - DSP48
     - FPGA DSP slice. Used for multiplication.
   * - FIFO
     - First‑In First‑Out queue. Holds scheduled outputs.
   * - LFSR
     - Linear Feedback Shift Register. Generates pseudo‑random numbers.
   * - Pipeline
     - Series of stages in the CPU. Allows overlapping instruction execution.
   * - PMEM
     - Program Memory. 64‑bit wide, stores instructions.
   * - PRNG
     - Pseudo‑Random Number Generator. See LFSR.
   * - PS
     - Processing System (ARM processor in the FPGA).
   * - tProc
     - timing Processor. Subject of this manual.
   * - WMEM
     - Wave Memory. 168‑bit wide, stores waveform parameters.

-------------------------------------------------------------------------------

*End of Document*