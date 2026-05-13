.. _tprocv2_trm:

==================================================
QICK tProcessor v2 - Complete Reference Manual
==================================================

.. meta::
  :description: Complete reference manual for the QICK tProcessor v2 real-time co-processor

:Version: 2.1
:Last Update: 2026-05-13
:Compatibility: QICK Firmware (>= v0.0.1)
:Audience: Firmware developers, advanced QICK users, researchers

.. note::
  This is the complete reference manual for the qick_processor (tProcV2).
  For system-level firmware overview (signal generators, readout, channel assignments),
  see :doc:`/firmware`.

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

.. _tproc-wis:

1. What is the qick_processor (tProcV2)? (Executive Summary)
============================================================

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

Overview
--------

The ``qick_processor`` (tProcV2) is a custom 32-bit data, 72-bit instruction processor
designed specifically for generating precisely timed waveforms, handling data, and
triggering events in quantum computing control systems.

Architecture
------------

The processor is composed of two main blocks:

- **CORE**: Contains the Processing Unit (``CORE_CPU``) and the Memory Unit (``CORE_MEM``).
  The ``CORE_CPU`` is a 5-stage pipelined Harvard architecture executing one instruction per
  clock cycle, with 18 instructions optimized for multi-operation execution. It includes a
  PC-Stack supporting up to 256 nested ``CALL`` functions and a Pseudo Random Number Generator
  (LFSR) for 32-bit pseudorandom number generation.

- **DISPATCHER**: Responsible for timely port signal output. It manages three FIFOs (Wave,
  Trigger, and Data), each holding specific information for output along with a designated
  time. The Dispatcher continuously compares the current time against the scheduled time in
  each FIFO, updating the corresponding port when the scheduled time is reached.

Memory
------

``CORE_MEM`` consists of three distinct memory components:

- **Program Memory (PMEM)**: 72-bit memory for storing instructions.
- **Data Memory (DMEM)**: 32-bit memory for user data storage.
- **WaveParam Memory (WMEM)**: 32-bit memory for storing waveform parameters to be written
  to the Analog Wave Ports.

Output Ports
------------

The ``qick_processor`` provides three groups of output ports:

- **Four** 32-bit Data Ports (DPORT)
- **Thirty-two** Trigger Output Ports (TRIG)
- **Sixteen** Analog Wave Ports (WPORT)

Special Features
----------------

- **Multiplication Unit (FPGA DSP)**: Performs the operation ``(D±A)*B±C`` in 2 clock cycles.
- **Division Unit (Custom)**: Provides the quotient and remainder of an integer division in
  32 clock cycles.
- **Pseudo Random Number Generator (LFSR)**: Configurable Linear Feedback Shift Register for
  32-bit pseudorandom number generation.
- **Nested CALL**: Supports function call nesting up to 256 levels.
- **Debugging Capabilities**: Step-by-step execution, time stepping, core stepping, status
  reading, and debug signal output.

AXI Interface
-------------

The AXI stream interface is monitored by a block (``DPORT_IN Register``) that updates on
every new data reception, storing it and updating a status bit in the SREG
(``PROC_xREG``). The ``qick_processor`` exposes a set of AXI Registers (``PROC_xREG``)
that can be read and written through the AXI-Lite interface.

Compatibility
-------------

tProcV2 is compatible with Signal Generators of types **INT**, **Mux**, and **SGV6**
for waveform generation and output.

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

.. list-table:: WAIT Options
  :header-rows: 1
  :widths: 20 40 40

  * - WAIT Option
    - Condition Tested
    - Expands To
  * - ``WAIT time @N``
    - ``s_usr_time >= N``
    - TEST + JUMP loop
  * - ``WAIT div_dt``
    - ``DIV_DT_NEW`` (s_status[3] == 1)
    - TEST + JUMP loop
  * - ``WAIT arith_dt``
    - ``ARITH_DT_NEW`` (s_status[1] == 1)
    - TEST + JUMP loop
  * - ``WAIT port_dt``
    - Any ``PORT_DT_NEW`` bit set
    - TEST + JUMP loop

.. list-table:: CLEAR Options
  :header-rows: 1
  :widths: 25 25 50

  * - CLEAR Option
    - s_ctrl Bit
    - Clears
  * - ``CLEAR arith``
    - 16
    - ``ARITH_DT_NEW``
  * - ``CLEAR div``
    - 17
    - ``DIV_DT_NEW``
  * - ``CLEAR qnet``
    - 18
    - ``QNET_DT_NEW``
  * - ``CLEAR port``
    - 22
    - All ``PORT_DT_NEW`` bits

Complete Instruction Header Reference
-------------------------------------

.. list-table:: Instruction Headers (bits 71:69)
  :header-rows: 1
  :widths: 12 20 20 48

  * - Header
    - Instruction Category
    - Instructions
    - Section
  * - 000
    - Configuration
    - NOP, TEST
    - 5.15
  * - 001
    - Branch
    - JUMP, CALL, RET
    - 5.16
  * - 100
    - Register Write
    - REG_WR
    - 5.14
  * - 101
    - Memory Write
    - DMEM_WR, WMEM_WR
    - 5.13
  * - 110
    - Port I/O
    - DPORT_WR, TRIG, WPORT_WR, DPORT_RD
    - 5.12
  * - 111
    - Peripheral Control
    - TIME, FLAG, ARITH, DIV, NET, PA, PB
    - 5.8

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

3.4. Pipeline Stages and Hazards
--------------------------------

The tProcessor uses a 5-stage pipeline. Understanding it helps avoid performance issues.

**Pipeline Stages:**

The tProcessor uses a 5-stage pipeline:

.. code-block:: text

  Cycle:   1      2      3      4      5
        ────────────────────────────────────
  Inst1:  FETCH  DECODE READ   EXEC   WRITE
  Inst2:         FETCH  DECODE READ   EXEC
  Inst3:                FETCH  DECODE READ
  Inst4:                       FETCH  DECODE
  Inst5:                              FETCH


**Branch Penalty:**

When a branch is taken, the pipeline flushes, causing a **2-cycle penalty**.

**Load-Use Hazard:**

Reading a register immediately after writing may cause a 1-cycle stall.

**Dual Task Hazard Prevention:**

In dual task instructions, both operations read **original** register values.
Writes happen at the end of the cycle - no hazard.

3.5. Interrupts (Important Limitation)
--------------------------------------

.. warning::
   The tProcessor v2 **does NOT support interrupts**.

This is intentional for deterministic real-time behavior.

**Alternatives for event response:**

- Use ``WAIT`` macro (polls status register)
- Use short loops and check flags frequently
- Python can set external flags that tProc polls


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

4.6. Detailed Bit Field Definitions
------------------------------------
.. _s_cfg_details:

s_cfg - Configuration Register (Lower 16 bits of s2)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This register controls data routing and flag selection. Write using ``REG_WR s_cfg imm <value>``.

**Bit Fields:**

.. list-table::
  :header-rows: 1
  :widths: 10 15 15 60

  * - Bits
    - Field
    - Assembler Aliases
    - Description
  * - 3:0
    - ``DT_SRC``
    - ``src_axi``, ``src_arith``, ``src_qnet``, etc.
    - Selects source for ``s_core_r1`` (s6) and ``s_core_r2`` (s7).

        * 0x0 (``src_axi``): Reads Python-written data.
        * 0x1 (``src_arith``): Reads ARITH result (lower 32 bits).
        * 0x4 (``src_qnet``): Reads QNET input data.
  * - 7:4
    - ``FLAG_SRC``
    - ``flg_int``, ``flg_axi``, ``flg_ext``, ``flg_div``, etc.
    - Selects the flag source for conditional execution ``-if(F)``.

        * 0x0 (``flg_int``): Internal Flag.
        * 0x1 (``flg_axi``): AXI Flag.
        * 0x3 (``flg_div``): Division Unit Flag (``DIV_DT_NEW``).
  * - 15:8
    - ``RFU``
    -
    - Reserved for Future Use.

s_ctrl - Clear Flags Register (Upper 16 bits of s2)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Write **'1'** to clear the corresponding ``_NEW`` flag in ``s_status``. The bit self-clears.

**Bit Fields:**

.. list-table::
  :header-rows: 1
  :widths: 10 15 15 60

  * - Bits
    - Field
    - Assembler Aliases
    - Description
  * - 16
    - ``arith_clr``
    - ``clr_arith``
    - Clears ``ARITH_DT_NEW`` (bit 1 of ``s_status``).
  * - 17
    - ``div_clr``
    - ``clr_div``
    - Clears ``DIV_DT_NEW`` (bit 3 of ``s_status``).
  * - 18
    - ``qnet_clr``
    - ``clr_qnet``
    - Clears ``QNET_DT_NEW``.
  * - 22
    - ``port_clr``
    - ``clr_port``
    - Clears all ``PORT_DT_NEW`` bits (bits 31:16 of ``s_status``).

s_status - Status Register (Read-Only, 0x2A)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Bit Fields:**

.. list-table::
  :header-rows: 1
  :widths: 10 15 15 60

  * - Bit
    - Name
    - Assembler Mask
    - Description
  * - 0
    - ``ARITH_RDY``
    - ``#1``
    - Arithmetic unit is ready/Idle.
  * - 1
    - ``ARITH_DT_NEW``
    - ``#2``
    - New arithmetic result available. Clear via ``s_ctrl[16]`` or reading.
  * - 2
    - ``DIV_RDY``
    - ``#4``
    - Divider unit is ready.
  * - 3
    - ``DIV_DT_NEW``
    - ``#8``
    - New division result available. Clear via ``s_ctrl[17]``.
  * - 5
    - ``QNET_DT_NEW``
    - ``#0x20``
    - New data from QNET received.
  * - 15
    - ``FIFO_FULL``
    - ``#0x8000``
    - Any of the dispatcher FIFOs is full. Stalls core if not disabled.
  * - 31:16
    - ``PORT_DT_NEW``
    - ``#0xFFFF0000``
    - **Bit mask per input port**. Bit 16 corresponds to Port 0. Set when new data arrives via ``DPORT_RD``. Clear via ``s_ctrl[22]``.

.. _core_cfg_details:

core_cfg - LFSR Configuration (AXI Register 0x07)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Controls the behavior of the Pseudo-Random Number Generator (LFSR) connected to ``s_rand``.

**Bit Fields:**

.. list-table::
  :header-rows: 1
  :widths: 10 25 60

  * - Bits
    - Value (CFG)
    - Description
  * - 1:0
    - ``0`` (STOP)
    - LFSR stops. The value in ``s_rand`` remains constant.
  * - 1:0
    - ``1`` (FREE_RUN)
    - LFSR advances **every** `c_clk` cycle. Fastest random updates.
  * - 1:0
    - ``2`` (READ_STEP)
    - LFSR advances **only when** the core reads the ``s_rand`` register.
  * - 1:0
    - ``3`` (WRITE_STEP)
    - LFSR advances **only when** the core writes to the ``s_rand`` register (value is discarded).

4.7. Peripherals Control & Status Registers
--------------------------------------------

Each peripheral (ARITH, DIV, TIME, FLAG) has a specific control and status interface.
The table below summarizes the registers involved:

.. list-table:: Peripheral Register Map
  :header-rows: 1
  :widths: 30 30 30 35

  * - Peripheral
    - Control Register
    - Status Register
    - Data Register
  * - ARITH (Multiply)
    - Instruction only (no control reg)
    - ``s_status[0]`` (RDY), ``s_status[1]`` (NEW)
    - ``s_arith_low`` (s3)
  * - DIV (Divide)
    - Instruction only
    - ``s_status[2]`` (RDY), ``s_status[3]`` (NEW)
    - ``s_div_q`` (s4), ``s_div_r`` (s5)
  * - TIME (Time control)
    - ``TIME`` instruction
    - (none)
    - ``s_usr_time`` (s11), ``s_out_time`` (s14)
  * - FLAG (Internal)
    - ``FLAG`` instruction
    - (none)
    - (none - just the flag bit)
  * - LFSR (Random)
    - ``core_cfg`` (AXI)
    - (none)
    - ``s_rand`` (s1)

4.7.1. ARITH (Multiply-Accumulate)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ARITH peripheral is started by an instruction, not by writing a register.

**Control Flow:**

.. code-block:: text

  // 1. Start operation
  ARITH PTP r1 r2 r3 r4     // (r1+r2)*r3+r4

  // 2. Wait for completion (poll s_status)
  WAIT arith_dt             // macro: loops until bit 1 is set

  // 3. Read result
  REG_WR r5 op -op(s_arith_low)

  // 4. Clear new-data flag (optional)
  CLEAR arith               // macro: writes s_ctrl[16]=1

**Status Bits (s_status):**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Bit
    - Name
    - Description
  * - 0
    - ``ARITH_RDY``
    - Set when ARITH is idle. Cleared when operation starts.
  * - 1
    - ``ARITH_DT_NEW``
    - Set when result is ready. Cleared by reading or ``CLEAR arith``.

**Data Register:**

- ``s_arith_low`` (s3): Lower 32 bits of the 64-bit result.
- The upper 32 bits are NOT accessible in this version.

**Control Register: None** - The ARITH unit has no memory-mapped control register.
All configuration is done via the instruction opcode.

4.7.2. DIV (Integer Division)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Control Flow:**

.. code-block:: text

  // 1. Start division
  DIV r1 r2                 // r1 / r2 (unsigned)

  // 2. Do other work while division runs (32 cycles)
  REG_WR r3 op -op(r3 + #1)

  // 3. Wait for completion
  WAIT div_dt

  // 4. Read results
  REG_WR r4 op -op(s_div_q)   // quotient
  REG_WR r5 op -op(s_div_r)   // remainder

  // 5. Clear flag
  CLEAR div

**Status Bits (s_status):**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Bit
    - Name
    - Description
  * - 2
    - ``DIV_RDY``
    - Set when DIV is idle. Cleared when division starts.
  * - 3
    - ``DIV_DT_NEW``
    - Set when result is ready. Cleared by reading or ``CLEAR div``.

**Data Registers:**

- ``s_div_q`` (s4): 32-bit quotient (unsigned).
- ``s_div_r`` (s5): 32-bit remainder (unsigned).

**Important Notes:**

- Division is **unsigned only**. For signed division, convert to positive values.
- Denominator cannot be zero (undefined behavior).
- Takes exactly 32 cycles to complete (plus pipeline overhead).

4.7.3. TIME (Time Control Peripheral)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TIME peripheral is controlled by dedicated instructions, not by memory-mapped registers.

**Instructions:**

.. list-table::
  :header-rows: 1
  :widths: 20 30 50

  * - Instruction
    - Example
    - Effect
  * - ``TIME rst``
    - ``TIME rst``
    - ``t_abs = 0``, ``t_ref = 0``, reset core
  * - ``TIME set_ref rX``
    - ``TIME set_ref r0``
    - ``t_ref = rX`` (t_abs unchanged)
  * - ``TIME inc_ref #N``
    - ``TIME inc_ref #100``
    - ``t_ref = t_ref + N``
  * - ``TIME updt #N``
    - ``TIME updt #10``
    - ``t_abs = t_abs + N`` (rarely used)

**Internal Time Registers (not directly accessible):**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Register
    - Width
    - Description
  * - ``t_abs``
    - 48 bits
    - Absolute time counter. Runs at DAC clock (`t_clk`).
  * - ``t_ref``
    - 48 bits
    - Reference time offset. Defines where user time = 0.
  * - ``t_usr``
    - 32 bits (read via s11)
    - User time = `t_abs - t_ref` (truncated to 32 bits).

**Time-Related SREG Registers:**

.. list-table::
  :header-rows: 1
  :widths: 15 20 20 45

  * - Register
    - Alias
    - Access
    - Description
  * - s11
    - ``s_usr_time``
    - Read-only
    - Current user time (32 bits of `t_abs - t_ref`)
  * - s14
    - ``s_out_time``
    - Read/Write
    - Output time for next port write (signed 32-bit)

**Clock Domain Crossing Warning:**

The TIME instruction crosses from `c_clk` to `t_clk` domain.
Do **not** execute two TIME instructions with less than 5 cycles between them.

4.7.4. FLAG (Internal Flag)
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The internal flag is a single bit that can be used for conditional execution.

**Instructions:**

.. list-table::
  :header-rows: 1
  :widths: 20 30 50

  * - Instruction
    - Example
    - Effect
  * - ``FLAG set``
    - ``FLAG set``
    - Sets internal flag to 1.
  * - ``FLAG clr``
    - ``FLAG clr``
    - Clears internal flag to 0.
  * - ``FLAG inv``
    - ``FLAG inv``
    - Toggles internal flag (0→1, 1→0).

**Usage with Conditional Execution:**

.. code-block:: text

  FLAG set                     // set flag
  REG_WR r0 imm #100 -if(F)    // executed (flag=1)
  FLAG clr
  REG_WR r1 imm #200 -if(F)    // NOT executed (flag=0=NF)

**Note:** The flag used by `-if(F)` can be configured via `s_cfg[7:4]` (FLAG_SRC) to be:
- Internal flag (``flg_int``)
- External flag from Python (``flg_axi``)
- Division completion flag (``flg_div``)
- Etc.

4.7.5. LFSR (Random Number Generator)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The LFSR generates pseudo-random numbers accessible via `s_rand` (s1).

**Configuration Register (AXI core_cfg, address 0x07):**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Bits
    - Value
    - Mode
  * - 1:0
    - 0 (``STOP``)
    - LFSR stops. `s_rand` constant.
  * - 1:0
    - 1 (``FREE_RUN``)
    - LFSR advances every `c_clk` cycle.
  * - 1:0
    - 2 (``READ_STEP``)
    - LFSR advances when `s_rand` is read.
  * - 1:0
    - 3 (``WRITE_STEP``)
    - LFSR advances when `s_rand` is written.

**Example Configuration (from Python):**

.. code-block:: python

  # Configure LFSR to advance on each read
  soc.tproc.write_axi_reg(0x07, 0x02)   # core_cfg = 2

**Assembly Usage:**

.. code-block:: text

   REG_WR r0 op -op(s_rand)   // reads random number (advances if mode=2)
   REG_WR r1 op -op(s_rand)   // next random number

**Polynomial:** The LFSR implements Fibonacci series with polynomial
`x^31 + x^21 + x^1 + x^0` (maximum length sequence).

4.7.6. WAIT and CLEAR Macros
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

These are not hardware peripherals but assembler macros that expand to instruction sequences.

**WAIT time @N - Expansion:**

.. code-block:: text

  // WAIT time @1000 expands to:
  TEST -op(s_usr_time - #1000)
  JUMP HERE -if(S)            // loop until s_usr_time >= 1000

**WAIT arith_dt - Expansion:**

.. code-block:: text

  // WAIT arith_dt expands to:
  TEST -op(s_status AND #2)   // test bit 1 (ARITH_DT_NEW)
  JUMP HERE -if(Z)            // loop until set

**CLEAR arith - Expansion:**

.. code-block:: text

  // CLEAR arith expands to:
  REG_WR s_ctrl imm clr_arith   // s_ctrl[16] = 1

4.7.7. Summary: Peripheral Control Flow Pattern
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Standard pattern for all peripherals:**

.. code-block:: text

  // 1. Start (instruction only)
  ARITH T r1 r2

  // 2. Wait for completion (poll s_status)
  WAIT arith_dt

  // 3. Read result (from dedicated sreg)
  REG_WR r3 op -op(s_arith_low)

  // 4. Clear new-data flag
  CLEAR arith

**For peripherals that produce new data asynchronously (input ports):**

.. code-block:: text

  // 1. Wait for data arrival (poll s_status)
  WAIT port_dt

  // 2. Read data
  DPORT_RD p0
  REG_WR r0 op -op(s_port_l)

  // 3. Clear flag (auto-cleared by read, or manually)
  CLEAR port

4.8. Quick Reference: Register Naming in Assembly
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

4.9. Common Mistakes with Registers
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


5.3.1 ARITH Command Decoder: Understanding PTP, MTM, T, etc.

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

5.6. Memory Addressing Modes - Detailed Reference
-------------------------------------------------

The tProcessor supports multiple addressing modes for different memory types.
Understanding these modes is crucial for writing efficient code.

5.6.1. DMEM Addressing Modes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Data Memory (DMEM) supports 4 addressing modes:

.. list-table:: DMEM Addressing Modes
  :header-rows: 1
  :widths: 20 20 20 40

  * - Mode
    - Syntax
    - Encoding (ADDR_MODE)
    - Example
  * - Literal
    - ``[&imm]``
    - 000
    - ``DMEM_WR [&10] imm #42``
  * - Register
    - ``[rX]``
    - 001
    - ``DMEM_WR [r1] imm #42``
  * - Indexed Literal
    - ``[rX + &imm]``
    - 010
    - ``DMEM_WR [r1+&4] imm #42``
  * - Indexed Register
    - ``[rX + rY]``
    - 011
    - ``DMEM_WR [r2+r3] imm #42``

**When to use each mode:**

- **Literal**: Fixed addresses (constants, lookup tables)
- **Register**: Dynamic addressing (arrays with variable index)
- **Indexed Literal**: Arrays with base pointer + small offset
- **Indexed Register**: 2D arrays or complex data structures

**Example: Array traversal with indexed literal**

.. code-block:: text

  REG_WR r0 imm #0        ; index
  REG_WR r1 imm #10       ; base address
  LOOP:
    REG_WR r2 dmem [r1 + r0]   ; read array[r0] from base r1
    ; ... process r2 ...
    REG_WR r0 op -op(r0 + #1) -uf
    JUMP LOOP -if(NZ)

5.6.2. WMEM Addressing Modes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Wave Memory (WMEM) supports 2 addressing modes:

.. list-table:: WMEM Addressing Modes
  :header-rows: 1
  :widths: 20 20 20 40

  * - Mode
    - Syntax
    - Encoding (ADDR_MODE)
    - Example
  * - Literal
    - ``[&imm]``
    - 00
    - ``WMEM_WR [&5]``
  * - Register
    - ``[rX]``
    - 01
    - ``WMEM_WR [r0]``

**Example: Sequentially loading waveforms**

.. code-block:: text

  REG_WR r0 imm #0
  LOOP:
    REG_WR r_wave wmem [r0]   ; load waveform from WMEM[r0]
    WPORT_WR p1 r_wave @s_out_time
    REG_WR r0 op -op(r0 + #1) -uf
    JUMP LOOP -if(NZ)


5.6.3. PMEM Addressing (Branch Instructions)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Program Memory (PMEM) addressing is used only for JUMP, CALL, and RET:

.. list-table:: PMEM Addressing Modes
  :header-rows: 1
  :widths: 20 20 20 40

  * - Mode
    - Syntax
    - Encoding (AI bits)
    - Example
  * - Immediate (Label)
    - ``LABEL``
    - 001
    - ``JUMP LOOP``
  * - Register (s_addr)
    - ``s_addr``
    - 010
    - ``JUMP s_addr``
  * - Special constants
    - ``HERE``, ``PREV``, ``NEXT``, ``SKIP``
    - (assembler)
    - ``JUMP HERE -if(Z)``

5.7. Dual Task Instructions - Unified Reference
-----------------------------------------------

One of the most powerful features of the tProcessor is the ability to execute
**two operations in a single instruction cycle**.

5.7.1. Types of Dual Tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Dual Task Types
  :header-rows: 1
  :widths: 15 15 20 50

  * - Type
    - Option
    - Abbreviation
    - Description
  * - Second Data Task
    - ``-wr(dest, source)``
    - SDT
    - Writes a register in the same cycle
  * - Second Wave Task
    - ``-ww``
    - SWT
    - Writes to WMEM (wave memory)
  * - Second Port Task
    - ``-wp(port)``
    - SPT
    - Writes to a wave port

5.7.2. Rules for Dual Tasks
^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. **Only ONE immediate value** per instruction total.
2. **The source for SDT** can be ALU operation (-op) or immediate (imm).
3. **The destination for SDT** can be any register (r, s, or w).
4. **SWT and SPT** are only available for specific instructions (REG_WR, WMEM_WR).

5.7.3. Instruction Support Matrix
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Dual Task Support by Instruction
  :header-rows: 1
  :widths: 20 15 15 15 15

  * - Instruction
    - SDT (-wr)
    - SWT (-ww)
    - SPT (-wp)
    - Notes
  * - REG_WR
    - ✅
    - ✅
    - ✅
    - Most flexible
  * - DMEM_WR
    - ✅
    - ❌
    - ❌
    -
  * - WMEM_WR
    - ✅
    - ❌ (already WW)
    - ✅
    - WW is the primary
  * - DPORT_WR
    - ✅
    - ❌
    - ❌
    -
  * - TRIG
    - ✅
    - ❌
    - ❌
    -
  * - WPORT_WR
    - ✅
    - ❌
    - ❌ (WP is primary)
    -
  * - JUMP/CALL/RET
    - ✅
    - ❌
    - ❌
    - SDT executes before branch
  * - TEST
    - ❌
    - ❌
    - ❌
    - No destination

5.7.4. Practical Examples
^^^^^^^^^^^^^^^^^^^^^^^^^

**Example 1: Increment counter while writing data**

.. code-block:: text

  ; Without SDT (2 instructions, 2 cycles)
  DPROT_WR p0 reg r5 @1000
  REG_WR r5 op -op(r5 + #1)

  ; With SDT (1 instruction, 1 cycle)
  DPROT_WR p0 reg r5 @1000 -wr(r5 op) -op(r5 + #1)

**Example 2: Loop with decrement and branch**

.. code-block:: text

  REG_WR r0 imm #10
  LOOP:
    ; ... loop body ...
    JUMP LOOP -wr(r0 op) -op(r0 - #1) -uf -if(NZ)
    ; Decrement, update flags, and branch in one cycle

**Example 3: Load waveform and increment address**

.. code-block:: text

  REG_WR r_wave wmem [r0] -wr(r0 op) -op(r0 + #1)
  ; Load waveform from WMEM[r0] and increment r0


5.8. Peripherals Control Instructions - Bit Field Reference
-----------------------------------------------------------

Instructions with `HEADER = 111` (binary) control the peripheral blocks.
This section provides the detailed bit encoding for each instruction.

.. note::
  The instruction width is **72 bits**. Tables show bit positions from MSB (bit 71) to LSB (bit 0).

5.8.1. TIME Instruction (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TIME instruction controls the absolute time counter and reference time.

**Bit Encoding:**

.. list-table:: TIME Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 8 5 5 5 5 8 10 5 5 5 5 5 5 5 5 5

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60:58
    - 57:55
    - 54:45
    - 44:39
    - 38:31
    - 30:23
    - 22:15
    - 14:7
    - 6:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - OPCODE
    - TIME_OP
    - (unused)
    - (unused)
    - (unused)
    - (unused)
    - (unused)
    - (unused)
    - (unused)
    - (unused)
    - (unused)
  * - **Value**
    - 111
    - a
    - i
    - d
    - f
    - 010
    - see table
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0

.. list-table:: TIME_OP Field Values
  :header-rows: 1
  :widths: 20 20 60

  * - TIME_OP (bits 60:58)
    - Mnemonic
    - Effect
  * - 000
    - ``rst``
    - ``t_abs = 0``, ``t_ref = 0``, core reset
  * - 001
    - ``set_ref``
    - ``t_ref = Source Data`` (t_abs unchanged)
  * - 010
    - ``inc_ref``
    - ``t_ref = t_ref + Source Data``
  * - 011
    - ``set_cmp``
    - Set time comparator for Time Flag
  * - 100
    - ``updt``
    - ``t_abs = t_abs + Source Data``

**Field Descriptions:**

.. list-table::
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 111 for peripheral instructions
  * - AI (Address Immediate)
    - 68:66
    - 0=Source is register, 1=Source is immediate value
  * - DF (Data Format)
    - 65:64
    - Source data format (00=32-bit immediate, 01=24-bit, etc.)
  * - OPCODE
    - 63:61
    - Always 010 for TIME instruction
  * - TIME_OP
    - 60:58
    - Operation code (see table above)
  * - Source Data
    - 57:0
    - Time value (immediate) or register address (if AI=0)

**Assembly Syntax:**

.. code-block:: text

  TIME rst                    // Reset absolute time
  TIME set_ref r2             // Set reference time to value in r2
  TIME inc_ref #15750         // Increment reference time by 15750
  TIME set_cmp #16800         // Set comparator for time flag

5.8.2. FLAG Instruction (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The FLAG instruction modifies the internal flag bit.

**Bit Encoding:**

.. list-table:: ARITH Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 10 10 10 10 10 10 10

  * - Row Type
    - 71:69
    - 68:66
    - 65:64
    - 63:53
    - 52:42
    - 41:31
    - 30:20
    - 19:0
  * - **Field**
    - HEADER
    - AI/DF
    - OPCODE
    - OPERAND_A
    - OPERAND_B
    - OPERAND_C
    - OPERAND_D
    - (unused)
  * - **Value**
    - 111
    - varies
    - see table
    - reg addr
    - reg addr
    - reg addr
    - reg addr
    - 0

.. list-table:: FLAG_OP Field Values
  :header-rows: 1
  :widths: 15 20 60

  * - FLAG_OP (bits 60:59)
    - Mnemonic
    - Effect
  * - 00
    - ``set``
    - Internal flag = 1
  * - 01
    - ``clr``
    - Internal flag = 0
  * - 10
    - ``inv``
    - Internal flag = ~internal flag
  * - 11
    - (reserved)
    - Reserved for future use

**Assembly Syntax:**

.. code-block:: text

   FLAG set    // Set internal flag
   FLAG clr    // Clear internal flag
   FLAG inv    // Invert internal flag

5.8.3. ARITH Instruction (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ARITH instruction starts a multiply-accumulate operation on the DSP.

**Bit Encoding:**

.. list-table:: ARITH Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 10 10 10 10 10 10 20

  * - Row Type
    - 71:69
    - 68:66
    - 65:64
    - 63:61
    - 60:50
    - 49:39
    - 38:28
    - 27:0
  * - **Field**
    - HEADER
    - AI/DF
    - OPCODE
    - OPERAND_A
    - OPERAND_B
    - OPERAND_C
    - OPERAND_D
    - (unused)
  * - **Value**
    - 111
    - varies
    - see table
    - reg addr
    - reg addr
    - reg addr
    - reg addr
    - 0

.. list-table:: ARITH OPCODE Values (bits 63:61)
  :header-rows: 1
  :widths: 15 15 20 45

  * - OPCODE
    - Mnemonic
    - Operands
    - Formula
  * - 000
    - T
    - 2
    - A * B
  * - 001
    - PT
    - 3
    - (A + B) * C
  * - 010
    - MT
    - 3
    - (A - B) * C
  * - 011
    - PTP
    - 4
    - (A + B) * C + D
  * - 100
    - PTM
    - 4
    - (A + B) * C - D
  * - 101
    - MTP
    - 4
    - (A - B) * C + D
  * - 110
    - MTM
    - 4
    - (A - B) * C - D

**Register Addressing:** Each operand field (60:50, 49:39, etc.) contains a 11-bit register address:
- Bits 10:8 = Register bank (000=r, 001=s, 010=w)
- Bits 7:0 = Register index (0-31)

**Assembly Syntax:**

.. code-block:: text

   ARITH T r1 r2                    // r1 * r2
   ARITH PT r1 r2 r3                // (r1 + r2) * r3
   ARITH PTP r1 r2 r3 r4            // (r1 + r2) * r3 + r4

5.8.4. DIV Instruction (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The DIV instruction starts unsigned 32-bit integer division.

**Bit Encoding:**

.. list-table:: DIV Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 5 5 5 5 8 10 10 10 20

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:53
    - 52:42
    - 41:31
    - 30:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - OPCODE
    - NUMERATOR
    - DENOMINATOR
    - (unused)
    - (unused)
  * - **Value**
    - 111
    - a
    - i
    - d
    - f
    - 001
    - reg addr
    - reg addr
    - 0
    - 0

**Field Descriptions:**

- **AI bit (68:66)**: 0 = Denominator is register, 1 = Denominator is immediate (24-bit)
- **Numerator (60:50)**: Always a register address
- **Denominator (49:39)**: Register address or 24-bit immediate value

**Assembly Syntax:**

.. code-block:: text

   DIV r1 r2        // r1 / r2 (both registers)
   DIV r1 #100      // r1 / 100 (immediate denominator)

5.8.5. NET Instruction (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The NET instruction communicates with the QICK network interface.

**Bit Encoding:**

.. list-table:: NET Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 15 10 10 15 15 35

  * - Bit(s)
    - 71:69
    - 68:66
    - 65:64
    - 63:61
    - 60:0
  * - **Field**
    - HEADER
    - AI/DF
    - OPCODE
    - NET_CMD
    - DATA
  * - **Value**
    - 111
    - varies
    - 100
    - see table
    - varies

.. list-table:: NET_CMD Field Values (bits 60:56)
  :header-rows: 1
  :widths: 15 20 45

  * - NET_CMD
    - Mnemonic
    - Description
  * - 00000
    - ``get_net``
    - Count nodes in network
  * - 00001
    - ``set_net``
    - Configure network nodes
  * - 00010
    - ``sync_net``
    - Synchronize all nodes
  * - 00011
    - ``get_st``
    - Read data from network node

5.8.6. PA/PB Instructions (Header=111)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
PA and PB control custom peripherals.

**Bit Encoding:**

.. list-table:: PA/PB Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 10 10 10 10 10 10 10 10 10

  * - Bit(s)
    - 71:69
    - 68:66
    - 65:64
    - 63:61
    - 60:56
    - 55:44
    - 43:32
    - 31:20
    - 19:8
    - 7:0
  * - **Field**
    - HEADER
    - AI/DF
    - OPCODE
    - PERIPH_OP
    - DATA_A
    - DATA_B
    - DATA_C
    - DATA_D
    - (unused)
    - (unused)
  * - **Value**
    - 111
    - varies
    - 101/110
    - varies
    - reg/imm
    - reg/imm
    - reg/imm
    - reg/imm
    - 0
    - 0

**OPCODE Values:**

- 101 = PA (Custom Peripheral A)
- 110 = PB (Custom Peripheral B)

**Data Fields:** Each can be a register address or immediate value, depending on DF bits.

5.8.7. Summary: Peripheral OPCODE Map
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Complete Peripheral OPCODE Reference
  :header-rows: 1
  :widths: 15 20 20 45

  * - OPCODE (bits 63:61)
    - Instruction
    - Operands
    - Description
  * - 000
    - ARITH
    - 2-4
    - Multiply-accumulate (2 cycles)
  * - 001
    - DIV
    - 2
    - Unsigned integer division (32 cycles)
  * - 010
    - TIME
    - 0-1
    - Time counter control
  * - 011
    - FLAG
    - 0
    - Internal flag control
  * - 100
    - NET
    - 0-1
    - Network communication
  * - 101
    - PA
    - 4
    - Custom peripheral A
  * - 110
    - PB
    - 4
    - Custom peripheral B
  * - 111
    - (reserved)
    -
    - Reserved for future use

5.8.8. Programming Pattern
^^^^^^^^^^^^^^^^^^^^^^^^^^

**Standard pattern for peripheral control:**

.. code-block:: text

   // 1. Configure data source (if reading result)
   REG_WR s_cfg imm src_arith    // route ARITH result to s_core_r1

   // 2. Clear any old flags
  CLEAR arith

   // 3. Start peripheral operation
  ARITH PTP r1 r2 r3 r4

   // 4. Wait for completion (macro expands to polling loop)
  WAIT arith_dt

   // 5. Read result
  REG_WR r0 op -op(s_arith_low)

   // 6. Clear flag for next use
  CLEAR arith

Related Status Bits (s_status):

.. list-table:: Peripheral Status Bits
  :header-rows: 1
  :widths: 20 20 20 25

  * - Peripheral
    - Ready Bit (RDY)
    - New Data Bit (DT_NEW)
    - Clear Method
  * - ARITH
    - bit 0
    - bit 1
    - CLEAR arith or read
  * - DIV
    - bit 2
    - bit 3
    - CLEAR div or read
  * - QPA (Custom A)
    - bit 8
    - bit 9
    - CLEAR qpa
  * - QPB (Custom B)
    - bit 10
    - bit 11
    - CLEAR qpb
  * - Input Ports
    - (none)
    - bits 31:16
    - CLEAR port or read

5.9. Subroutines (CALL/RET)
---------------------------

The tProc supports nested calls up to 256 levels deep.

.. code-block:: text

  CALL MY_SUBROUTINE
   // ... after subroutine returns, execution continues here

  MY_SUBROUTINE:
      // ... do something ...
      RET

**Important:** The stack only stores return addresses, not local variables. Use registers or DMEM for local storage.

5.10. Waiting (WAIT macro) - Detailed Reference
-----------------------------------------------

The ``WAIT`` instruction is an **assembler macro** that expands to a small polling loop.
It is not a single hardware instruction but a convenient way to wait for conditions.

5.10.1. WAIT Macro Expansion
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**WAIT time @N - Expansion:**

.. code-block:: text

  ; Original: WAIT time @1000
  ; Expands to:
  TEST -op(s_usr_time - #1000)   ; Compare current time with N
  JUMP HERE -if(S)               ; Loop if current_time < N

**Bit encoding of expanded instructions:**

.. list-table:: WAIT time @N Expansion Encoding
  :header-rows: 1
  :widths: 45 35 60

  * - Instruction
    - Opcode
    - Description
  * - ``TEST -op(s_usr_time - #N)``
    - TEST (Header=000)
    - Performs subtraction, updates flags. N is 32-bit immediate.
  * - ``JUMP HERE -if(S)``
    - JUMP (Header=001)
    - Conditional jump to current address if Negative flag is set.

5.10.2. WAIT div_dt - Expansion
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ; Original: WAIT div_dt
  ; Expands to:
  TEST -op(s_status AND #8)      ; Test DIV_DT_NEW bit (bit 3)
  JUMP HERE -if(Z)               ; Loop while bit is 0 (Z flag set)

**Bit encoding:**

.. list-table:: WAIT div_dt Expansion Encoding
  :header-rows: 1
  :widths: 35 30 50

  * - Instruction
    - Opcode
    - Description
  * - ``TEST -op(s_status AND #8)``
    - TEST (Header=000)
    - AND operation with mask 0x8, updates Z flag
  * - ``JUMP HERE -if(Z)``
    - JUMP (Header=001)
    - Conditional jump to current address if Z flag is set (bit not set)

5.10.3. WAIT arith_dt - Expansion
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ; Original: WAIT arith_dt
  ; Expands to:
  TEST -op(s_status AND #2)      ; Test ARITH_DT_NEW bit (bit 1)
  JUMP HERE -if(Z)               ; Loop while bit is 0

5.10.4. WAIT port_dt - Expansion
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ; Original: WAIT port_dt
  ; Expands to:
  TEST -op(s_status AND #0xFFFF0000)  ; Test any PORT_DT_NEW bit
  JUMP HERE -if(Z)                    ; Loop if no new data on any port

5.10.5. Custom WAIT Macro (user-defined)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You can create your own wait loops for any condition:

.. code-block:: text

  ; Wait for QPA_RDY (bit 8 of s_status)
  WAIT_QPA_RDY:
    TEST -op(s_status AND #0x100)   ; Test bit 8
    JUMP WAIT_QPA_RDY -if(Z)        ; Loop if not ready

  ; Wait for a specific input port (e.g., port 2, bit 18)
  WAIT_PORT2:
    TEST -op(s_status AND #1<<18)   ; Test bit 18
    JUMP WAIT_PORT2 -if(Z)

5.11. Clearing Flags (CLEAR) - Detailed Reference
-------------------------------------------------

The ``CLEAR`` instruction is an **assembler macro** that writes to ``s_ctrl`` (upper 16 bits of s2)
to clear ``_NEW`` flags in ``s_status``.

5.11.1. CLEAR Macro Expansion
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**CLEAR arith - Expansion:**

.. code-block:: text

  ; Original: CLEAR arith
  ; Expands to:
  REG_WR s_ctrl imm clr_arith    ; s_ctrl[16] = 1

**Bit encoding of expanded instruction:**

.. list-table:: CLEAR arith Expansion Encoding
  :header-rows: 1
  :widths: 20 20 60

  * - Instruction
    - Opcode
    - Description
  * - ``REG_WR s_ctrl imm clr_arith``
    - REG_WR (Header=100)
    - Writes immediate value to s_ctrl, setting bit 16 to 1

5.11.2. CLEAR Options and Corresponding s_ctrl Bits
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: CLEAR Options
  :header-rows: 1
  :widths: 20 20 15 45

  * - CLEAR Option
    - s_ctrl Bit
    - Bit Value
    - Clears
  * - ``CLEAR arith``
    - 16
    - 0x00010000
    - ``ARITH_DT_NEW`` (s_status[1])
  * - ``CLEAR div``
    - 17
    - 0x00020000
    - ``DIV_DT_NEW`` (s_status[3])
  * - ``CLEAR qnet``
    - 18
    - 0x00040000
    - ``QNET_DT_NEW`` (s_status[5])
  * - ``CLEAR qcom``
    - 19
    - 0x00080000
    - ``QCOM_DT_NEW`` (s_status[7])
  * - ``CLEAR qpa``
    - 20
    - 0x00100000
    - ``QPA_DT_NEW`` (s_status[9])
  * - ``CLEAR qpb``
    - 21
    - 0x00200000
    - ``QPB_DT_NEW`` (s_status[11])
  * - ``CLEAR port``
    - 22
    - 0x00400000
    - All ``PORT_DT_NEW`` bits (s_status[31:16])

5.11.3. CLEAR Macro Expansion Example
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ; Original: CLEAR div
  ; Expands to:
  REG_WR s_ctrl imm #0x00020000   ; Set bit 17 only

  ; Note: Writing to s_ctrl is self-clearing.
  ; The bit returns to 0 after one clock cycle.

5.11.4. Direct s_ctrl Usage (without CLEAR macro)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You can write directly to ``s_ctrl`` to clear specific flags:

.. code-block:: text

  ; Clear multiple flags at once
  REG_WR s_ctrl imm #0x00700000   ; Clear arith + div + qpa (bits 16,17,20)

  ; Clear using predefined constants (if defined in assembler)
  REG_WR s_ctrl imm clr_arith | clr_div

5.12. Port Instructions - Bit Field Reference
----------------------------------------------

Instructions with `HEADER = 110` (binary) control output ports (DPORT, TRIG, WPORT)
and input ports (DPORT_RD).

5.12.1. DPORT_WR (Data Port Write) - Header=110
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The DPORT_WR instruction writes 32-bit data to a digital output port at a specified time.

**Bit Encoding:**

.. list-table:: Instruction Encoding (72-bit)
  :header-rows: 2
  :widths: 10 5 5 5 5 5 5 5 5 5 5 5 5 5 5 20

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63
    - 62
    - 61
    - 60
    - 59
    - 58
    - 57
    - 56
    - 55:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - (un)
    - (un)
    - (un)
    - (un)
    - (un)
    - (un)
    - (un)
    - (un)
    - (un)
    - DATA
  * - **Value**
    - 110
    - 1
    - 1
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - 0
    - varies

**Field Descriptions:**

.. list-table:: DPORT_WR Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 110 for port instructions
  * - AI (Address Immediate)
    - 68:66
    - 111 = Data is immediate, 000 = Data is from register
  * - DF (Data Format)
    - 65:64
    - Source data format (00=32-bit immediate, 01=24-bit, etc.)
  * - PORT
    - 63:61
    - Port number (0-7 for DPORT)
  * - TIME_SRC
    - 60:59
    - 00 = Time from s_out_time, 01 = Immediate time (@value)
  * - DATA_SRC
    - 58:55
    - Source of data (varies by AI/DF)
  * - Imm_Data/Reg_Addr
    - 54:0
    - Immediate data value or register address

**Time Encoding:**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - TIME_SRC bits (60:59)
    - Meaning
    - Example
  * - 00
    - Use s_out_time register
    - ``DPORT_WR p0 reg r0 @s_out_time``
  * - 01
    - Use immediate time value
    - ``DPORT_WR p0 imm 1 @1000``

**Assembly Syntax:**

.. code-block:: text

  DPORT_WR p0 imm 1 @1000        ; Write 1 to port 0 at time 1000
  DPORT_WR p2 reg r5 @s_out_time ; Write r5 to port 2 using s_out_time

5.12.2. TRIG (Trigger Port Write) - Header=110
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TRIG instruction writes a single bit (0 or 1) to a trigger output port.

**Bit Encoding:**

.. list-table:: TRIG Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 5 5 5 5 10 10 10 10 20

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - (unused)
    - PORT
    - SET_CLR
    - TIME_SRC
    - (unused)
  * - **Value**
    - 110
    - 1
    - 1
    - 0
    - 0
    - 0
    - port #
    - 0 or 1
    - 0 or 1
    - 0

**Field Descriptions:**

.. list-table:: TRIG Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 110 for port instructions
  * - PORT
    - 63:61
    - Port number (0-31 for TRIG ports)
  * - SET_CLR
    - 60
    - 0 = Clear (write 0), 1 = Set (write 1)
  * - TIME_SRC
    - 59:58
    - 00 = Time from s_out_time, 01 = Immediate time (@value)
  * - Imm_Time
    - 57:0
    - Immediate time value (if TIME_SRC=01)

**Assembly Syntax:**

.. code-block:: text

  TRIG p0 set @150              ; Set trigger port 0 high at time 150
  TRIG p1 clr @200              ; Set trigger port 1 low at time 200
  TRIG p2 set @s_out_time       ; Use s_out_time register

5.12.3. WPORT_WR (Wave Port Write) - Header=110
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The WPORT_WR instruction writes 168-bit waveform parameters to an analog wave output port.

**Bit Encoding:**

.. list-table:: WPORT_WR Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 8 7 4 4 4 4 4 6 4 4 7 10 10 24

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:55
    - 54:45
    - 44:39
    - 38:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - WW
    - PORT
    - WP
    - TI
    - SRC
    - ADDR_SRC
    - DATA_SRC
    - (unused)
  * - **Value**
    - 110
    - 1
    - 1
    - 0
    - 0
    - 0 or 1
    - port #
    - 0 or 1
    - 0 or 1
    - varies
    - varies
    - varies
    - 0

**Field Descriptions:**

.. list-table:: WPORT_WR Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 110 for port instructions
  * - WW (Write Wave)
    - 64
    - 1 = Write wave as second task (SWT), 0 = not a second task
  * - PORT
    - 63:61
    - Wave port number (0-15)
  * - WP (Write Port)
    - 60
    - 1 = This is a second port task (SPT), 0 = primary task
  * - TI (Time Immediate)
    - 59
    - 0 = Use s_out_time, 1 = Use immediate time @value
  * - SRC (Source Select)
    - 58:55
    - 0000 = Source is r_wave, 0001 = Source is WMEM
  * - ADDR_SRC
    - 54:45
    - WMEM address (immediate or register, depending on AI/DF)
  * - DATA_SRC
    - 44:39
    - Source register for r_wave (if SRC=0000 and not immediate)
  * - Imm_Time
    - 38:0
    - Immediate time value (if TI=1)

**Source Encoding (SRC bits 58:55):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 65

  * - SRC
    - Source
    - Description
  * - 0000
    - r_wave
    - Use the r_wave register
  * - 0001
    - wmem
    - Load from WMEM address (requires ADDR_SRC)

**Assembly Syntax:**

.. code-block:: text

  WPORT_WR p0 r_wave @1000          ; Write r_wave to port 0 at time 1000
  WPORT_WR p1 wmem [&5] @s_out_time ; Write WMEM[5] to port 1 using s_out_time
  WPORT_WR p2 r_wave                ; Write r_wave at time from s_out_time

5.12.4. DPORT_RD (Data Port Read) - Header=110
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The DPORT_RD instruction reads 64-bit data from an input port (AXI-Stream interface)
to s_port_l (s8) and s_port_h (s9).

**Bit Encoding:**

.. list-table:: DPORT_RD Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 10 5 5 5 5 10 10 30

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - (unused)
    - PORT
    - (unused)
  * - **Value**
    - 110
    - 0
    - 0
    - 0
    - 0
    - 0
    - port #
    - 0

**Field Descriptions:**

.. list-table:: DPORT_RD Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 110 for port instructions
  * - PORT
    - 63:61
    - Input port number (0-3 typically, up to 16 configurable)

**Result Registers:**

- s8 (s_port_l): Lower 32 bits of input data
- s9 (s_port_h): Upper 32 bits of input data

**Status Bits:**

- s_status[31:16] (PORT_DT_NEW): Bit N indicates new data on port N
- Cleared by reading the port or by ``CLEAR port``

**Assembly Syntax:**

.. code-block:: text

  DPORT_RD p0                    ; Read port 0 to s_port_l/s_port_h
  DPORT_RD p1 -wr(r15 op) -op(r1-#1) ; Read port 1 with dual task

5.12.5. Summary: Port Instruction OPCODE Map
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Port Instruction Summary
  :header-rows: 1
  :widths: 20 20 20 40

  * - Instruction
    - Header
    - Sub-fields
    - Description
  * - DPORT_WR
    - 110
    - PORT, TIME_SRC, DATA_SRC
    - Write 32-bit data to digital port
  * - TRIG
    - 110
    - PORT, SET_CLR, TIME_SRC
    - Write single bit to trigger port
  * - WPORT_WR
    - 110
    - PORT, TI, SRC, WW, WP
    - Write 168-bit waveform to analog port
  * - DPORT_RD
    - 110
    - PORT
    - Read 64-bit from input port

5.12.6. Dual Task Options for Port Instructions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Port instructions can include dual tasks:

- **-wr(rd, src)** : Second Data Task - writes a register
- **-uf** : Update flags (used with -wr)
- **-wp(port)** : Second Port Task - writes a wave port (only for WPORT_WR?)

**Example with dual task:**

.. code-block:: text

  DPORT_WR p0 reg r5 @s_out_time -wr(r1 imm) #100
  ; Primary: Write r5 to port 0
  ; Secondary: Write 100 to r1 (same cycle)

  TRIG p0 set @s_out_time -wr(r0 op) -op(r0 + #1)
  ; Primary: Set trigger
  ; Secondary: Increment r0

**Bit encoding for dual task (SDT) in port instructions:**

.. list-table:: Dual Task Fields in Port Instructions
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - WR (Write Register)
    - 57
    - 1 = Second Data Task present
  * - UF (Update Flag)
    - 56
    - 1 = Update ALU flags
  * - RDI (Register Destination Immediate)
    - 55
    - 0 = ALU source, 1 = Immediate source
  * - ALU_OP
    - 54:50
    - ALU operation code (for -op())

5.13. Memory Instructions - Bit Field Reference
------------------------------------------------

Instructions with `HEADER = 101` (binary) write to Data Memory (DMEM) or Wave Parameter Memory (WMEM).

5.13.1. DMEM_WR (Data Memory Write) - Header=101
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The DMEM_WR instruction writes 32-bit data to Data Memory at a specified address.

**Bit Encoding:**

.. list-table:: DMEM_WR Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 7 5 4 4 4 4 5 5 4 4 4 7 7 7 6 6 6 6

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:55
    - 54:45
    - 44:39
    - 38:31
    - 30:23
    - 22:15
    - 14:7
    - 6:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - COND
    - ADDR_MODE
    - WR
    - UF
    - RDI
    - ADDR_SRC0
    - ADDR_SRC1
    - DATA_SRC
    - (unused)
    - (unused)
    - (unused)
    - (unused)
  * - **Value**
    - 101
    - see table
    - see table
    - see table
    - see table
    - 0-7
    - see table
    - 0/1
    - 0/1
    - 0/1
    - varies
    - varies
    - varies
    - 0
    - 0
    - 0
    - 0

**Field Descriptions:**

.. list-table:: DMEM_WR Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 101 for memory write instructions
  * - AI (Address Immediate)
    - 68:66
    - Address mode selector (see table below)
  * - DF (Data Format)
    - 65:64
    - Source data format (00=32-bit immediate, 01=24-bit, 10=16-bit, 11=register only)
  * - COND
    - 63:61
    - Condition code for conditional execution (0-7)
  * - ADDR_MODE
    - 60:58
    - 000=literal, 001=register, 010=indexed literal, 011=indexed register
  * - WR (Write Register)
    - 57
    - 1 = Second Data Task present (-wr)
  * - UF (Update Flag)
    - 56
    - 1 = Update ALU flags
  * - RDI (Register Destination Immediate)
    - 55
    - 0 = ALU source for SDT, 1 = Immediate source for SDT
  * - ADDR_SRC0
    - 54:45
    - First address component (register or immediate)
  * - ADDR_SRC1
    - 44:39
    - Second address component (register, for indexed modes)
  * - DATA_SRC
    - 38:31
    - Data to write (register address or immediate value)

**Address Modes (ADDR_MODE bits 60:58):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 20 45

  * - ADDR_MODE
    - Mode
    - Syntax
    - Description
  * - 000
    - Literal
    - ``[&imm]``
    - Address is immediate value
  * - 001
    - Register
    - ``[rX]``
    - Address is in register
  * - 010
    - Indexed Literal
    - ``[rX + &imm]``
    - Address = register + immediate offset
  * - 011
    - Indexed Register
    - ``[rX + rY]``
    - Address = register + register

**AI Field Encoding (bits 68:66):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 65

  * - AI
    - Meaning
    - Description
  * - 000
    - ADDR_SRC0 is register
    - First address component is a register address
  * - 001
    - ADDR_SRC0 is immediate (11-bit)
    - First address component is an immediate value
  * - 010
    - ADDR_SRC1 is register
    - Second address component is a register (for indexed modes)
  * - 100
    - ADDR_SRC1 is immediate
    - Second address component is immediate (rare)

**Assembly Syntax:**

.. code-block:: text

  DMEM_WR [&10] imm #42                  ; Literal addressing
  DMEM_WR [r1] op -op(r0)                ; Register addressing
  DMEM_WR [r1+&4] imm #5                 ; Indexed literal
  DMEM_WR [r2+r3] imm #1                 ; Indexed register
  DMEM_WR [&10] imm #42 -wr(r5 op) -op(r0+r1) ; With SDT

5.13.2. WMEM_WR (Wave Memory Write) - Header=101
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The WMEM_WR instruction writes the 168-bit r_wave register to Wave Parameter Memory.

**Bit Encoding:**

.. list-table:: WMEM_WR Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 8 7 4 4 4 4 4 6 4 4 7 10 10 24

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:55
    - 54:45
    - 44:39
    - 38:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - WW
    - (unused)
    - WP
    - TI
    - ADDR_MODE
    - ADDR_SRC
    - DATA_SRC
    - (unused)
  * - **Value**
    - 101
    - see table
    - see table
    - see table
    - see table
    - 0/1
    - 0
    - 0/1
    - 0/1
    - see table
    - varies
    - varies
    - 0

**Field Descriptions:**

.. list-table:: WMEM_WR Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 101 for memory write instructions
  * - WW (Write Wave)
    - 64
    - 1 = This is a second wave task (SWT), 0 = primary task
  * - WP (Write Port)
    - 59
    - 1 = Second port task present (-wp)
  * - TI (Time Immediate)
    - 58
    - For SPT: 0 = use s_out_time, 1 = use immediate time
  * - ADDR_MODE
    - 57:56
    - 00 = Literal, 01 = Register
  * - ADDR_SRC
    - 55:45
    - WMEM address (immediate or register address)
  * - DATA_SRC
    - 44:39
    - Source of data (always r_wave, field may be unused)

**Address Modes for WMEM:**

.. list-table::
  :header-rows: 1
  :widths: 15 20 20 45

  * - ADDR_MODE
    - Mode
    - Syntax
    - Description
  * - 00
    - Literal
    - ``[&imm]``
    - Address is immediate (10-bit)
  * - 01
    - Register
    - ``[rX]``
    - Address from register (5-bit register address)

**Assembly Syntax:**

.. code-block:: text

  WMEM_WR [&5]                         ; Write r_wave to WMEM address 5
  WMEM_WR [r0]                         ; Write r_wave to address in r0
  WMEM_WR [&5] -wr(r1 imm) #100        ; With SDT
  WMEM_WR [&5] -wp(p1)                 ; With SPT (second port task)

5.14. Register Instructions - Bit Field Reference
--------------------------------------------------

Instructions with `HEADER = 100` (binary) write to registers (DREG, SREG, WREG, or r_wave).

5.14.1. REG_WR (Register Write) - Header=100
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The REG_WR instruction writes data to a register from various sources (immediate, ALU, DMEM, WMEM).

**Bit Encoding:**

.. list-table:: REG_WR Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 7 5 4 4 4 4 5 5 5 5 5 5 7 7 7 10 10

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:55
    - 54:50
    - 49:39
    - 38:31
    - 30:23
    - 22:15
    - 14:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - DST_BANK
    - DST_IDX
    - SRC_TYPE
    - WR
    - UF
    - RDI
    - ALU_OP
    - SRC_A
    - SRC_B
    - IMM_DATA
    - (unused)
  * - **Value**
    - 100
    - see table
    - see table
    - see table
    - see table
    - see table
    - reg index
    - see table
    - 0/1
    - 0/1
    - 0/1
    - see table
    - varies
    - varies
    - varies
    - 0

**Field Descriptions:**

.. list-table:: REG_WR Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 100 for register write instructions
  * - DST_BANK (Destination Bank)
    - 68:67
    - 00 = DREG (r0-r31), 01 = SREG (s0-s15), 10 = WREG (w0-w5), 11 = r_wave (special)
  * - DST_IDX (Destination Index)
    - 66:61
    - Register index within the bank (0-31)
  * - SRC_TYPE (Source Type)
    - 60:58
    - 000 = ALU operation (-op), 001 = DMEM, 010 = WMEM, 011 = Immediate
  * - WR (Write Register for SDT)
    - 57
    - 1 = Second Data Task present
  * - UF (Update Flag)
    - 56
    - 1 = Update ALU flags
  * - RDI (Register Destination Immediate)
    - 55
    - For SDT: 0 = ALU source, 1 = Immediate source
  * - ALU_OP
    - 54:50
    - ALU operation code (for SRC_TYPE=000)
  * - SRC_A
    - 49:39
    - First source register address
  * - SRC_B
    - 38:31
    - Second source register address (or immediate value for some modes)
  * - IMM_DATA
    - 30:0
    - Immediate data value (when SRC_TYPE=011 or part of ALU operation)

**Destination Bank Encoding (bits 68:67):**

.. list-table::
  :header-rows: 1
  :widths: 15 15 20 50

  * - DST_BANK
    - Bank
    - Registers
    - Example
  * - 00
    - DREG
    - r0-r31
    - ``REG_WR r5 ...``
  * - 01
    - SREG
    - s0-s15
    - ``REG_WR s_cfg ...``
  * - 10
    - WREG
    - w0-w5
    - ``REG_WR w_freq ...``
  * - 11
    - r_wave
    - (special)
    - ``REG_WR r_wave ...``

**Source Type Encoding (bits 60:58):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 65

  * - SRC_TYPE
    - Source
    - Description
  * - 000
    - ALU (-op)
    - Source is result of ALU operation
  * - 001
    - DMEM
    - Source is Data Memory (requires address)
  * - 010
    - WMEM
    - Source is Wave Memory (requires address, destination must be r_wave)
  * - 011
    - Immediate
    - Source is immediate value (#value)

**ALU Operation Codes (bits 54:50) - when SRC_TYPE=000:**

.. list-table::
  :header-rows: 1
  :widths: 15 15 70

  * - ALU_OP
    - Operation
    - Example
  * - 00000
    - ADD
    - ``-op(r0 + r1)``
  * - 00001
    - SUB
    - ``-op(r0 - r1)``
  * - 00010
    - AND
    - ``-op(r0 AND r1)``
  * - 00011
    - ASR
    - ``-op(r0 ASR #2)``
  * - 00100
    - ABS
    - ``-op(ABS r0)``
  * - 00101
    - MSH
    - ``-op(MSH r0)``
  * - 00110
    - LSH
    - ``-op(LSH r0)``
  * - 00111
    - SWP
    - ``-op(SWP r0)``
  * - 01000
    - NOT
    - ``-op(NOT r0)``
  * - 01001
    - OR
    - ``-op(r0 OR r1)``
  * - 01010
    - XOR
    - ``-op(r0 XOR r1)``
  * - 01110
    - SL
    - ``-op(r0 SL #2)``
  * - 01111
    - SR
    - ``-op(r0 SR #2)``

**Assembly Syntax:**

.. code-block:: text

  REG_WR r0 imm #100                    ; Immediate source
  REG_WR r1 op -op(r0 + r2)             ; ALU source
  REG_WR r2 dmem [&10]                  ; DMEM source
  REG_WR r_wave wmem [&5]               ; WMEM source (to r_wave)
  REG_WR s_addr label LOOP              ; Label address to s_addr
  REG_WR r0 op -op(r0 + #1) -uf -wr(r1 imm) #100 ; With SDT

5.15. Configuration Instructions - Bit Field Reference
-------------------------------------------------------

Instructions with `HEADER = 000` (binary) perform configuration operations without writing data.

5.15.1. NOP (No Operation) - Header=000
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The NOP instruction does nothing and takes one cycle.

**Bit Encoding:**

.. list-table:: NOP Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 20 20 60

  * - Bit(s)
    - 71:69
    - 68:0
  * - **Field**
    - HEADER
    - (unused)
  * - **Value**
    - 000
    - 0

**Assembly Syntax:**

.. code-block:: text

  NOP

5.15.2. TEST (Test and Update Flags) - Header=000
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TEST instruction performs an ALU operation and updates flags without writing a register.

**Bit Encoding:**

.. list-table:: TEST Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 7 5 5 5 5 5 7 5 5 10 10 10 20

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58:50
    - 49:39
    - 38:31
    - 30:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - (unused)
    - COND
    - UF
    - RDI
    - ALU_OP
    - SRC_A
    - SRC_B
    - (unused)
  * - **Value**
    - 000
    - see table
    - see table
    - see table
    - see table
    - 0
    - 0-7
    - 1
    - 0/1
    - see table
    - varies
    - varies
    - 0

**Field Descriptions:**

.. list-table:: TEST Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 000 for configuration instructions
  * - COND
    - 63:61
    - Condition code (typically 000 for ALWAYS)
  * - UF
    - 60
    - Must be 1 to update flags
  * - RDI
    - 59
    - 0 = ALU operation, 1 = Immediate (rare for TEST)
  * - ALU_OP
    - 58:50
    - ALU operation code (same as REG_WR)
  * - SRC_A
    - 49:39
    - First source register address
  * - SRC_B
    - 38:31
    - Second source register address or immediate value

**Assembly Syntax:**

.. code-block:: text

  TEST -op(r0 - #1) -uf            ; Test if r0-1 == 0 or negative
  TEST -op(s_status AND #8) -uf    ; Test DIV_DT_NEW bit
  TEST -op(r1 - #32768) -uf        ; Compare with threshold


5.16. Branch Instructions - Bit Field Reference
------------------------------------------------

Instructions with `HEADER = 001` (binary) control program flow by modifying the Program Counter (PC).

5.16.1. JUMP (Conditional Branch) - Header=001
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The JUMP instruction changes the PC to a specified address, conditionally or unconditionally.

**Bit Encoding:**

.. list-table:: JUMP Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 7 5 4 4 4 4 4 6 4 4 4 4 4 4 7 10 10 20

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58
    - 57
    - 56
    - 55
    - 54:50
    - 49:39
    - 38:31
    - 30:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - BT
    - COND
    - UF
    - WR
    - RDI
    - (un)
    - (un)
    - (un)
    - ALU_OP
    - ADDR_SRC
    - DATA_SRC
    - (un)
  * - **Value**
    - 001
    - see table
    - see table
    - see table
    - see table
    - 0/1
    - 0-7
    - 0/1
    - 0/1
    - 0/1
    - 0
    - 0
    - 0
    - see table
    - varies
    - varies
    - 0

**Field Descriptions:**

.. list-table:: JUMP Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 001 for branch instructions
  * - AI (Address Immediate)
    - 68:66
    - 001 = Address is immediate, 010 = Address is from s_addr register
  * - DF (Data Format)
    - 65:64
    - Data format for SDT (if present)
  * - BT (Branch Type)
    - 64? (verify)
    - 0 = JUMP, 1 = CALL (may be combined with RET)
  * - COND
    - 63:61
    - Condition code for conditional execution (0-7)
  * - UF (Update Flag)
    - 60
    - 1 = Update ALU flags (for SDT)
  * - WR (Write Register)
    - 59
    - 1 = Second Data Task present (-wr)
  * - RDI (Register Destination Immediate)
    - 58
    - For SDT: 0 = ALU source, 1 = Immediate source
  * - ALU_OP
    - 54:50
    - ALU operation code for SDT (-op)
  * - ADDR_SRC
    - 49:39
    - Jump target address (immediate or register address)
  * - DATA_SRC
    - 38:31
    - Data source for SDT (if WR=1)

**Branch Type (BT) Encoding:**

.. list-table:: Branch Type (BT) Encoding
  :header-rows: 1
  :widths: 15 20 65

  * - BT (bit 64)
    - Instruction
    - Description
  * - 0
    - JUMP
    - Unconditional or conditional branch
  * - 1
    - CALL
    - Branch with return address pushed to stack

**Address Modes (AI bits 68:66):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 65

  * - AI
    - Mode
    - Description
  * - 001
    - Immediate
    - Address is immediate value (11-bit)
  * - 010
    - Register
    - Address is from s_addr (s15) register
  * - 100
    - Label (assembler)
    - Assembler calculates immediate address from label

**Special Address Constants (assembler-only):**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Constant
    - Meaning
    - Effect
  * - ``HERE``
    - Current address
    - `PC = PC` (infinite loop)
  * - ``PREV``
    - Previous instruction
    - `PC = PC - 1`
  * - ``NEXT``
    - Next instruction
    - `PC = PC + 1`
  * - ``SKIP``
    - Skip one instruction
    - `PC = PC + 2`

**Condition Codes (COND bits 63:61):**

.. list-table::
  :header-rows: 1
  :widths: 15 20 15 50

  * - COND
    - Condition
    - Code
    - Description
  * - 000
    - ALWAYS
    - (always)
    - Unconditional jump
  * - 001
    - Z
    - Zero
    - Jump if Zero flag = 1
  * - 010
    - NZ
    - Non-Zero
    - Jump if Zero flag = 0
  * - 011
    - S
    - Sign (Negative)
    - Jump if Sign flag = 1
  * - 100
    - NS
    - Non-Sign (Positive)
    - Jump if Sign flag = 0
  * - 101
    - F
    - Flag
    - Jump if configured flag = 1
  * - 110
    - NF
    - Not Flag
    - Jump if configured flag = 0

**Assembly Syntax:**

.. code-block:: text

  JUMP LABEL                         ; Unconditional jump to LABEL
  JUMP LABEL -if(NZ)                 ; Conditional jump if not zero
  JUMP HERE -if(Z)                   ; Infinite loop if zero flag set
  JUMP PREV -if(S)                   ; Jump to previous instruction
  JUMP s_addr                        ; Jump to address in s_addr
  JUMP LABEL -wr(r0 op) -op(r0 - #1) -uf ; Jump with SDT (decrement counter)

5.16.2. CALL (Subroutine Call) - Header=001
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The CALL instruction saves the current PC to the stack and jumps to the specified address.

**Bit Encoding:**

.. list-table:: CALL Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 8 4 4 4 4 4 8 4 4 4 42

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58
    - 57:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - BT
    - COND
    - UF
    - WR
    - RDI
    - ADDR_SRC
  * - **Value**
    - 001
    - see table
    - see table
    - see table
    - see table
    - 1
    - 0-7
    - 0/1
    - 0/1
    - 0/1
    - varies

**Field Descriptions:**

.. list-table:: CALL Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 001 for branch instructions
  * - BT (Branch Type)
    - 64
    - 1 = CALL (0 = JUMP)
  * - COND
    - 63:61
    - Condition code (0-7) - CALL can be conditional!
  * - ADDR_SRC
    - 57:0
    - Target address (immediate or register)
  * - UF, WR, RDI
    - 60,59,58
    - Same as JUMP - for SDT support

**Stack Operation:**

- Pushes current PC (return address) to hardware stack
- Stack depth is 256 levels
- Stack is **only** for return addresses, not local variables

**Assembly Syntax:**

.. code-block:: text

  CALL SUBROUTINE                    ; Call subroutine
  CALL SUBROUTINE -if(NZ)            ; Conditional call
  CALL s_addr                        ; Call address in s_addr
  CALL SUBROUTINE -wr(r0 imm) #1     ; Call with SDT

5.16.3. RET (Return from Subroutine) - Header=001
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The RET instruction pops the return address from the stack and jumps back to the caller.

**Bit Encoding:**

.. list-table:: RET Instruction (72-bit encoding)
  :header-rows: 2
  :widths: 10 8 4 4 4 4 4 8 4 4 4 42

  * - Bit(s)
    - 71:69
    - 68
    - 67
    - 66
    - 65
    - 64
    - 63:61
    - 60
    - 59
    - 58
    - 57:0
  * - **Field**
    - HEADER
    - AI_H
    - AI_L
    - DF_H
    - DF_L
    - BT
    - COND
    - UF
    - WR
    - RDI
    - (unused)
  * - **Value**
    - 001
    - 0
    - 0
    - 0
    - 0
    - 2
    - 7
    - 0/1
    - 0/1
    - 0/1
    - 0

**Field Descriptions:**

.. list-table:: RET Fields
  :header-rows: 1
  :widths: 15 15 70

  * - Field
    - Bits
    - Description
  * - HEADER
    - 71:69
    - Always 001 for branch instructions
  * - BT (Branch Type)
    - 64
    - 10 or 2? (RET is a special encoding)
  * - COND
    - 63:61
    - Typically 111 (ALWAYS) - RET is normally unconditional
  * - UF, WR, RDI
    - 60,59,58
    - For SDT support (rarely used with RET)

**Stack Operation:**

- Pops return address from hardware stack
- PC = popped address
- Stack depth decreases by 1

**Assembly Syntax:**

.. code-block:: text

  RET                              ; Return to caller
  RET -wr(r0 op) -op(r0 + #1)      ; Return with SDT (rare)

5.16.4. Summary: Branch Instructions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Branch Instruction Summary
  :header-rows: 1
  :widths: 20 15 20 45

  * - Instruction
    - Header
    - BT Bit
    - Description
  * - JUMP
    - 001
    - 0
    - Conditional/unconditional branch
  * - CALL
    - 001
    - 1
    - Branch with stack push (return address)
  * - RET
    - 001
    - 10 (special)
    - Return from CALL (stack pop)

**Pipeline Behavior:**

.. list-table::
  :header-rows: 1
  :widths: 20 20 60

  * - Instruction
    - Latency
    - Pipeline Effect
  * - JUMP (taken)
    - 2 cycles
    - Pipeline flushed, 2 instruction slots wasted
  * - JUMP (not taken)
    - 1 cycle
    - No flush, continues normally
  * - CALL
    - 2 cycles
    - Pipeline flush + stack push
  * - RET
    - 2 cycles
    - Pipeline flush + stack pop

**Conditional Branch Optimization:**

Branch instructions cause a 2-cycle penalty when taken. For simple conditional execution, use conditional instruction execution instead:

.. code-block:: text

  ; Instead of:
  ; JUMP SKIP -if(Z)
  ; REG_WR r0 imm #1
  ; SKIP:

  ; Do this (no branch penalty):
  REG_WR r0 imm #1 -if(NZ)

**Stack Depth:** Maximum 256 nested CALLs. Exceeding this will overwrite the stack (undefined behavior).

5.16.5. Branch Instructions with SDT (Second Data Task)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

All branch instructions can include a Second Data Task (-wr) that executes **before** the branch is taken.

.. code-block:: text

  JUMP LOOP -wr(r0 op) -op(r0 - #1) -uf -if(NZ)
  ; 1. Decrement r0 and update flags
  ; 2. If NZ flag set, jump to LOOP
  ; If NZ flag not set, fall through

**Use case:** Loop counter management in a single instruction.

.. code-block:: text

  REG_WR r0 imm #10
  LOOP:
    ; ... loop body ...
    JUMP LOOP -wr(r0 op) -op(r0 - #1) -uf -if(NZ)
    ; Decrement and branch in one instruction


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

6.5. Reset and Initialization Sequence
---------------------------------------

A proper initialization sequence ensures predictable behavior.

**Complete Initialization Checklist:**

.. code-block:: text

  ; 1. Reset everything
  TIME rst
  
  ; 2. Configure data sources (if using peripherals)
  REG_WR s_cfg imm src_arith
  
  ; 3. Clear stale flags
  CLEAR arith
  CLEAR div
  CLEAR port
  
  ; 4. Initialize time registers
  REG_WR s_out_time imm #1000
  
  ; 5. Load initial waveform parameters
  REG_WR w_freq imm #0x1000000
  REG_WR w_phase imm #0
  REG_WR w_gain imm #32768
  REG_WR w_length imm #1024
  
  ; 6. Save to WMEM (optional)
  WMEM_WR [&0]
  
  ; 7. Initialize loop counters
  REG_WR r0 imm #100
  
  ; 8. Start main program
  JUMP MAIN

**What TIME rst does:**

.. list-table::
  :header-rows: 1
  :widths: 30 70

  * - Component
    - Effect
  * - t_abs, t_ref
    - Set to 0
  * - Program Counter
    - Set to 0
  * - All registers (r, s, w)
    - Cleared to 0
  * - FIFOs
    - Flushed
  * - AXI registers
    - NOT cleared
  * - LFSR (s_rand)
    - NOT cleared

**Python Initialization:**

.. code-block:: python

  soc = QickSoc()
  soc.tproc.time_rst()           # Reset tProc
  soc.tproc.load_mem(prog_mem=program_binary)
  soc.tproc.start()              # Start execution


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

12.1. Initializing the tProcessor
---------------------------------

.. code-block:: python

  from qick import QickSoc
  from qick.tprocv2_assembler import Assembler

  # Connect to the RFSoC board
  soc = QickSoc()

  # Access the tProcessor instance
  tproc = soc.tproc

12.2. Loading a Program
-----------------------

**From an assembly string:**

.. code-block:: python

  asm_code = \"\"\"
      .ADDR 0x00
      REG_WR r0 imm #100
      DPROT_WR p0 reg r0 @1000
      .END
  \"\"\"
  prog_bin = Assembler.str_asm2bin(asm_code)
  tproc.load_mem(prog_mem=prog_bin)

**From a list of instructions (dictionary format):**

.. code-block:: python

  prog_list = [
      {'CMD': 'REG_WR', 'DST': 'r0', 'SRC': 'imm', 'LIT': 100},
      {'CMD': 'DPROT_WR', 'DST': '0', 'SRC': 'reg', 'DATA': 'r0', 'TIME': 1000},
  ]
  prog_bin = Assembler.list2bin(prog_list)
  tproc.load_mem(prog_mem=prog_bin)

12.3. Controlling Execution
---------------------------

.. code-block:: python

  tproc.time_rst()        # Reset time and core
  tproc.start()           # Start execution
  tproc.stop()            # Stop execution
  tproc.core_start()      # Reset and start only core (time continues)
  tproc.core_stop()       # Stop only core

12.4. Reading Status and Data
-----------------------------

.. code-block:: python

  # Read the status register (s10)
  status = tproc.read_status()
  print(status['ARITH_RDY'], status['DIV_DT_NEW'])

  # Read current user time (s11)
  usr_time = tproc.time_usr

  # Read random number (s1)
  rand_val = tproc.rand

  # Read from DMEM
  data = tproc.read_dmem(addr=0x10, length=100)

  # Write to DMEM
  tproc.write_dmem(addr=0x20, data=0xDEADBEEF)

12.5. Configuring the LFSR
--------------------------

.. code-block:: python

  # Set LFSR mode: 0=stop, 1=free run, 2=advance on read, 3=advance on write
  tproc.write_axi_reg(0x07, 0x02)   # core_cfg = 0x02

-------------------------------------------------------------------------------

13. Python Examples
===================

This section provides practical examples of using the tProcessor v2 from Python.
For complete API documentation, see Chapter 12.

.. contents::
  :local:
  :depth: 2

13.1. Basic Python Workflow
---------------------------

A typical QICK experiment follows this pattern:

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler
  import numpy as np
  import matplotlib.pyplot as plt
  import time

  # 1. Connect to board
  soc = QickSoc()

  # 2. Configure hardware parameters
  freq = 100e6                    # 100 MHz
  gain = 0.5
  length = 1024                   # samples

  # Convert to firmware units
  freq_reg = soc.config.freq2reg(freq, gen_ch=0)
  gain_reg = int(gain * 32768)

  # 3. Load waveform to WMEM (address 0)
  soc.tproc.load_wave(0, {
      'freq': freq_reg,
      'phase': 0,
      'gain': gain_reg,
      'length': length,
      'conf': 0
  })

  # 4. Write tProc assembly program
  asm_code = \"\"\"
      .ADDR 0x00
      REG_WR r_wave wmem [&0]
      WPORT_WR p1 r_wave @1000
      .END
  \"\"\"

  # 5. Assemble and load
  prog_bin = Assembler.str_asm2bin(asm_code)
  soc.tproc.load_mem(prog_mem=prog_bin)

  # 6. Configure readout (if needed)
  soc.avg_bufs[0].set_avg_mode(0)    # raw mode
  soc.avg_bufs[0].set_nsamp(length)

  # 7. Run experiment
  soc.tproc.time_rst()
  soc.tproc.start()

  # 8. Wait for completion (simple delay)
  time.sleep(0.1)

  # 9. Read results
  data_i, data_q = soc.avg_bufs[0].get_data()

  # 10. Plot and analyze
  plt.plot(data_i)
  plt.show()

13.2. Basic Loopback Demo (Send and Receive Pulse)
---------------------------------------------------

This example demonstrates a complete loopback experiment: send a pulse and capture it.

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler
  import numpy as np
  import time

  soc = QickSoc()
  tproc = soc.tproc

  # --- Step 1: Configure waveform parameters ---
  freq_mhz = 100
  gain = 0.5
  length_us = 1.0

  # Convert to firmware units
  freq_reg = int(freq_mhz * 1e6 / (soc.fs_dac / 2**32))
  gain_reg = int(gain * 32768)
  length_cycles = int(length_us * soc.fs_dac / 1e6)

  # Load waveform parameters to WMEM (address 0)
  tproc.load_wave(0, {
    'freq': freq_reg,
    'phase': 0,
    'gain': gain_reg,
    'length': length_cycles,
    'conf': 0
  })

  # --- Step 2: tProc assembly program ---
  asm_program = \"\"\"
    .ADDR 0x00
    REG_WR r_wave wmem [&0]
    WPORT_WR p1 r_wave @1000
    .END
  \"\"\"

  # Assemble and load
  prog_bin = Assembler.str_asm2bin(asm_program)
  tproc.load_mem(prog_mem=prog_bin)

  # --- Step 3: Configure readout ---
  ro = soc.avg_bufs[0]
  ro.set_avg_mode(0)               # raw mode
  ro.set_nsamp(1024)               # number of samples

  # --- Step 4: Run experiment ---
  tproc.time_rst()
  tproc.start()

  # Wait for acquisition to complete
  time.sleep(0.1)

  # --- Step 5: Read results ---
  data_i, data_q = ro.get_data()
  print(f"Acquired {len(data_i)} samples")

13.3. Conditional Feedback Demo
-------------------------------

This example reads ADC data and conditionally selects a waveform based on the measured value.

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler

  soc = QickSoc()
  tproc = soc.tproc

  # Pre-load waveforms (long and short pulses) to WMEM addresses 0 and 1
  long_pulse = {'freq': 100e6, 'phase': 0, 'gain': 32768, 'length': 2000, 'conf': 0}
  short_pulse = {'freq': 100e6, 'phase': 0, 'gain': 32768, 'length': 500, 'conf': 0}

  tproc.load_wave(0, long_pulse)
  tproc.load_wave(1, short_pulse)

  # tProc assembly program with conditional feedback
  asm_feedback = \"\"\"
      .ADDR 0x00
      REG_WR s_out_time imm #1000
      REG_WR r0 imm #100               // 100 experiments
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

  # Assemble, load, and run
  prog_bin = Assembler.str_asm2bin(asm_feedback)
  tproc.load_mem(prog_mem=prog_bin)
  tproc.time_rst()
  tproc.start()

13.4. Frequency Sweep (Chirp)
-----------------------------

This example generates a frequency sweep (chirp) without waiting for feedback.

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler

  soc = QickSoc()
  tproc = soc.tproc

  # Pre-compute frequency sweep values
  start_freq = 50e6
  end_freq = 150e6
  steps = 100
  freq_step_reg = int((end_freq - start_freq) / steps / (soc.fs_dac / 2**32))

  # Assembly program for chirp
  asm_chirp = f\"\"\"
    .ADDR 0x00
    REG_WR r0 imm #{steps}
    REG_WR s_out_time imm #1000
    REG_WR w_freq imm #{soc.config.freq2reg(start_freq, gen_ch=0)}
    REG_WR w_phase imm #0
    REG_WR w_gain imm #32768
    REG_WR w_length imm #100
    REG_WR w_conf imm #0
  LOOP:
    WPORT_WR p1 r_wave @s_out_time
    REG_WR w_freq op -op(w_freq + #{freq_step_reg})
    REG_WR s_out_time op -op(s_out_time + #500)
    REG_WR r0 op -op(r0 - #1) -uf
    JUMP LOOP -if(NZ)
    .END
  \"\"\"

  prog_bin = Assembler.str_asm2bin(asm_chirp)
  tproc.load_mem(prog_mem=prog_bin)
  tproc.time_rst()
  tproc.start()

13.5. Complete Example: Send Pulse and Capture Echo
----------------------------------------------------

This example combines everything: DAC pulse, ADC capture, and data analysis.

.. code-block:: python

  from qick import *
  from qick.tprocv2_assembler import Assembler
  import numpy as np
  import matplotlib.pyplot as plt
  import time

  soc = QickSoc()
  tproc = soc.tproc

  # --- Configure waveform ---
  freq = 50e6
  gain = 0.5
  length = 512

  freq_reg = soc.config.freq2reg(freq, gen_ch=0)
  gain_reg = int(gain * 32768)

  tproc.load_wave(0, {
      'freq': freq_reg,
      'phase': 0,
      'gain': gain_reg,
      'length': length,
      'conf': 0
  })

  # --- tProc program: send pulse and trigger readout ---
  asm_program = \"\"\"
      .ADDR 0x00
      REG_WR r_wave wmem [&0]
      WPORT_WR p1 r_wave @1000
      TRIG p0 set @2000           // trigger readout after pulse
      .END
  \"\"\"

  prog_bin = Assembler.str_asm2bin(asm_program)
  tproc.load_mem(prog_mem=prog_bin)

  # --- Configure readout ---
  ro = soc.avg_bufs[0]
  ro.set_avg_mode(0)               # raw mode
  ro.set_nsamp(2048)               # capture more than needed
  ro.clear_buffer()

  # --- Run ---
  tproc.time_rst()
  tproc.start()

  # Wait for acquisition
  time.sleep(0.2)

  # --- Read and analyze data ---
  data_i, data_q = ro.get_data()
  amplitude = np.sqrt(np.array(data_i)**2 + np.array(data_q)**2)

  plt.plot(amplitude)
  plt.xlabel("Sample")
  plt.ylabel("Amplitude")
  plt.title("Pulse Echo")
  plt.show()

  print(f"Peak amplitude: {np.max(amplitude)}")
  print(f"Noise floor: {np.mean(amplitude[:100])}")

13.6. Integration with Signal Generator v6
------------------------------------------

The Signal Generator v6 (SG-v6) is the waveform generation engine for DAC outputs.
It is controlled through the tProc's wave ports (channels 1-7).

For complete documentation and additional Python examples, see :doc:`/sg_v6`.

**Quick reference:** The SG-v6 is exposed to Python as ``soc.gens[i]``.
Waveforms are loaded via ``WPORT_WR`` instructions using the 168-bit ``r_wave`` bus.

.. code-block:: python

  # Direct SG-v6 control (immediate playback, no tProc sequencing)
  gen = soc.gens[0]
  gen.set_freq(100e6)
  gen.set_gain(0.5)
  gen.set_pulse(freq=100e6, phase=0, gain=0.5, length=1024)
  gen.trigger()

13.7. Integration with Readout System
-------------------------------------

The readout system captures ADC data. It is triggered by tProc channel 0.

**Trigger mapping:**
- tProc Channel 0, bit 14 → triggers average/buffer for ADC 224 CH0
- tProc Channel 0, bit 15 → triggers average/buffer for ADC 224 CH1

.. code-block:: python

  # tProc program that triggers readout at time 1000
  asm_readout = \"\"\"
    .ADDR 0x00
    TRIG p0 set @1000
    .END
  \"\"\"

  # Configure readout before starting tProc
  ro = soc.avg_bufs[0]
  ro.set_avg_mode(0)               # raw mode
  ro.set_nsamp(1024)               # number of samples
  ro.clear_buffer()

  # Start tProc
  prog_bin = Assembler.str_asm2bin(asm_readout)
  soc.tproc.load_mem(prog_mem=prog_bin)
  soc.tproc.time_rst()
  soc.tproc.start()

  # Wait for acquisition to complete
  time.sleep(0.1)

  # Read data
  data_i, data_q = ro.get_data()
  print(f"Captured {len(data_i)} samples")

13.8. Debugging and Monitoring
------------------------------

**Reading tProc status from Python:**

.. code-block:: python

  # Read status register (s10)
  status = soc.tproc.read_status()
  print(f"ARITH_RDY: {status['ARITH_RDY']}")
  print(f"DIV_DT_NEW: {status['DIV_DT_NEW']}")
  print(f"FIFO_FULL: {status['FIFO_FULL']}")

  # Read current user time (s11)
  usr_time = soc.tproc.time_usr
  print(f"Current time: {usr_time} cycles")

  # Read random number from LFSR (s1)
  rand_val = soc.tproc.rand
  print(f"Random: {rand_val}")

**Reading the debug register (address 0x0F):**

.. code-block:: python

  debug = soc.tproc.read_axi_reg(0x0F)
  core_stalled = (debug >> 4) & 1
  time_enabled = (debug >> 5) & 1
  core_state = (debug >> 8) & 0x03   # 0=stop, 1=run, 2=reset, 3=stall
  print(f"Core state: {core_state}")

**Single-stepping the core:**

.. code-block:: python

  # Enable single-step mode (set CORE_STEP bit in tproc_ctrl)
  soc.tproc.write_axi_reg(0x00, 1 << 10)

  # Execute one instruction at a time
  for i in range(10):
      soc.tproc.core_step()
      status = soc.tproc.read_status()

  # Resume normal execution (clear CORE_STEP bit)
  soc.tproc.write_axi_reg(0x00, 0)

**Reading the program counter (indirectly):**

.. code-block:: python

  # Store PC to DMEM and read it back
  asm_debug = \"\"\"
      .ADDR 0x00
      DMEM_WR [&0] imm s15   // Store s_addr (PC) to DMEM address 0
      .END
  \"\"\"
  # ... load and run, then read DMEM[0]

13.9. Performance Measurement
-----------------------------

**Measuring execution time of a tProc program:**

.. code-block:: python

  import time

  tproc.time_rst()
  start_time = time.perf_counter_ns()
  tproc.start()

  # Wait for completion (poll a flag set by the program)
  # Note: PROGRAM_DONE is hypothetical; implement your own flag
  while not tproc.read_status().get('PROGRAM_DONE', False):
    pass

  end_time = time.perf_counter_ns()
  duration_us = (end_time - start_time) / 1000
  print(f"tProc program executed in {duration_us:.2f} us")

**Alternative: Use a GPIO pin to measure with oscilloscope:**

.. code-block:: text

  ; In assembly program
  TRIG p0 set @start_time
  ; ... program to measure ...
  TRIG p0 clr @end_time

13.10. Repository of Examples
-----------------------------

The QICK project provides several repositories with ready-to-run examples:

.. list-table:: Example Repositories
  :header-rows: 1
  :widths: 30 25 45

  * - Repository
    - Focus
    - Link
  * - QICK Official Demos
    - Basic to advanced examples
    - `github.com/openquantumhardware/qick/tree/main/qick_demos <https://github.com/openquantumhardware/qick/tree/main/qick_demos>`_
  * - tProc v2 Specific Examples
    - Assembly programming, feedback loops
    - `github.com/meeg/qick_demos_sho/tree/main/tprocv2 <https://github.com/meeg/qick_demos_sho/tree/main/tprocv2>`_
  * - Signal Generator v6 Examples
    - Waveform generation, DDS configuration
    - `github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_signal_gen_v6 <https://github.com/openquantumhardware/qick/tree/main/firmware/ip/axis_signal_gen_v6>`_
  * - Readout and Averaging
    - ADC data acquisition, feedback
    - `github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb <https://github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb>`_

13.11. Where to Find More Examples
----------------------------------

For more elaborate examples (multi-qubit experiments, advanced feedback loops,
calibration routines), refer to:

- **Official QICK Demos Repository** – Contains notebooks for basic pulses,
  readout, averaging, and feedback.

- **tProc v2 Specific Examples** – Focuses on assembly programming and
  tProc-specific features.

- **Community Contributions** – Check the `#qick` channel on the
  `Unitary Fund Discord <https://discord.unitary.foundation/>`_ for user-contributed
  examples and support.

- **QICK Papers** – See :doc:`/papers` for academic papers that include
  example use cases and code snippets.

-------------------------------------------------------------------------------

.. _tproc-pitfalls:

14. Common Pitfalls and Debugging
==================================

14.1. Pitfall: Forgetting to Wait for Peripherals
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

14.2. Pitfall: FIFO Overflow
----------------------------

**Symptom:** Program stalls unexpectedly.

**Check:** ``s_status[15]`` (FIFO_FULL)

**Fix:** Increase FIFO depth in hardware, or add delays between port writes.

14.3. Pitfall: Branch Penalty in Tight Loops
--------------------------------------------

**Symptom:** Loop takes longer than expected.

**Example of inefficient loop:**

.. code-block:: text

  LOOP:
    // ... code ...
    JUMP LOOP -if(NZ)    // 2 cycle penalty each iteration

**Better: use conditional execution or unroll.**

14.4. Pitfall: Using s_out_time Incorrectly
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

14.5. Debugging Technique: Single Step
---------------------------------------

From Python:

.. code-block:: python

  soc.tproc.core_step()   # execute one instruction, then stop

You can single‑step through your program to see where it gets stuck.

14.6. Debugging Technique: Read Debug Register
----------------------------------------------

.. code-block:: python

  dbg = soc.tproc.read_axi_reg(0x0F)
  # Bit 4: core_stall (1 = core is stalled due to FIFO full)
  # Bit 5: time_en (0 = time stopped)
  # Bits 9:8: core state (0=stop, 1=run, 2=reset, 3=stall)

14.7. Common Issues Quick Reference
------------------------------------

.. list-table::
  :header-rows: 1
  :widths: 40 55

  * - Symptom
    - Likely cause and fix
  * - Output never appears on port
    - FIFO full (check ``s_status[15]``); or ``abs_time`` already past ``out_abs_time``
  * - Flag condition never triggers
    - Condition flag set in instruction N but tested in N+1 (2-cycle lag). Insert NOPs.
  * - DIV/ARITH results wrong
    - Reading result before ``_DT_NEW`` is set. Use ``WAIT div_dt`` / ``WAIT arith_dt``.
  * - Jump goes to wrong place
    - Using ``[]`` around a label: ``JUMP [LABEL]`` is wrong; use ``JUMP LABEL``.
  * - Time does not advance
    - ``TIME`` instructions issued < 5 cycles apart. Insert NOPs.
  * - ``s_addr``-based JUMP misbehaves
    - Address written to ``s15`` too close to JUMP. Insert at least 2 NOPs after writing ``s15``.

-------------------------------------------------------------------------------

15. FAQ (Frequently Asked Questions)
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

16. Glossary
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
