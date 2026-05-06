Timing with tProcessor v2
=========================

The tProcessor v2 uses a precise timing model based on three time variables.
Understanding these is essential for accurate waveform sequencing.

.. contents::
   :local:
   :depth: 2

Overview
--------

The tProcessor v2 has a **48-bit absolute time counter** (`t_abs`) that runs at the DAC clock frequency (`t_clk`). This counter is shared by all output channels (wave ports, data ports, triggers).

Key concepts:
- **Deterministic latency**: ~5 `t_clk` cycles from instruction to output
- **Signed output times**: You can schedule outputs "before" the reference time
- **Non-blocking writes**: Instructions write to FIFOs and continue immediately

Time Variables
--------------

.. list-table:: Time Variables
   :header-rows: 1
   :widths: 20 20 60

   * - Variable
     - Width
     - Description
   * - `t_abs`
     - 48 bits
     - Absolute time counter. Runs at DAC clock (`t_clk`). Counts from last reset.
   * - `t_ref`
     - 48 bits
     - Reference time offset. Defines where user time = 0.
   * - `t_usr`
     - 32 bits (read via `s_usr_time`)
     - User time = `t_abs - t_ref` (truncated to 32 bits, signed)
   * - `t_out_user`
     - 32 bits (signed)
     - Time specified in port write instructions (`@value` or `@s_out_time`)
   * - `t_abs_out`
     - 48 bits
     - Absolute output time = `t_ref + t_out_user` (calculated by hardware)

**Why is `t_out_user` signed?**  
You can schedule outputs with a **negative** offset. For example, if you set `t_ref` to a future time, negative `t_out_user` allows outputs to occur "before" the new reference. This is useful for synchronizing multiple boards or for pre-calculated sequences.

Time Instructions
-----------------

The `TIME` instruction controls the time counters:

.. code-block:: text

   TIME rst              // t_abs = 0, t_ref = 0, core reset
   TIME set_ref rX       // t_ref = rX (t_abs unchanged)
   TIME inc_ref #N       // t_ref = t_ref + N
   TIME updt #N          // t_abs = t_abs + N (rarely used)

**Typical initialization sequence:**

.. code-block:: text

   TIME rst              // Start from zero
   // ... wait for external trigger ...
   TIME set_ref r0       // Set t_ref to current t_abs (t_usr becomes 0)

Scheduling Outputs
------------------

**Fixed absolute time (using immediate):**

.. code-block:: text

   WPORT_WR p1 r_wave @1000    // Output when t_usr reaches 1000

**Relative to previous output (using s_out_time):**

.. code-block:: text

   REG_WR s_out_time imm #1000
   WPORT_WR p1 r_wave @s_out_time
   REG_WR s_out_time op -op(s_out_time + #500)
   WPORT_WR p1 r_wave @s_out_time   // 500 cycles after first

**Using a register as time source:**

.. code-block:: text

   REG_WR r0 imm #2000
   WPORT_WR p1 r_wave @r0          // Output when t_usr reaches value in r0

Waiting for Time
----------------

The `WAIT time @N` macro pauses the tProc until `t_usr >= N`:

.. code-block:: text

   WAIT time @5000     // Pause execution until t_usr >= 5000

**Expansion:**

.. code-block:: text

   // WAIT time @5000 expands to:
   TEST -op(s_usr_time - #5000)
   JUMP HERE -if(S)    // Loop while s_usr_time < 5000

Dispatcher Latency
------------------

When you execute a port write instruction (`WPORT_WR`, `DPORT_WR`, `TRIG`), the data is not output immediately. Instead:

1. **Cycle 1**: CPU writes to FIFO (in `c_clk` domain)
2. **Cycles 2-3**: Clock domain crossing to `t_clk` domain
3. **Cycle 4**: Dispatcher compares `t_abs` with scheduled time
4. **Cycle 5**: Output is updated on the physical pin

**Total latency:** Approximately **5 `t_clk` cycles** (about 13 ns at 384 MHz).

.. important::
   This latency is **deterministic** and constant. You can compensate for it by
   subtracting 5 cycles from your scheduled times if you need output aligned with
   a specific `t_abs` value.

FIFO Behavior
-------------

Each output type has its own FIFO:

- **WFIFO** (Wave): 168-bit data + 48-bit time, depth 8-512
- **DFIFO** (Data): 32-bit data + 48-bit time, depth 8-512  
- **TFIFO** (Trigger): 1-bit data + 48-bit time, depth 8-512

When a FIFO becomes full:
- Default behavior: Core **stalls** until space is available
- With `DISABLE_FIFO_FULL_PAUSE` (tproc_cfg[10]=1): Writes are dropped (data loss)

**Check FIFO status:**

.. code-block:: text

   TEST -op(s_status AND #0x8000)   // Test FIFO_FULL bit (bit 15)
   JUMP FIFO_OK -if(Z)              // Continue if not full

Clock Domains
-------------

The tProcessor has three clock domains:

.. list-table::
   :header-rows: 1
   :widths: 20 20 60

   * - Domain
     - Clock
     - Purpose
   * - Core (`c_clk`)
     - ≤ 350 MHz
     - CPU pipeline, registers, ALU, memories
   * - Time (`t_clk`)
     - DAC frequency (384 MHz - 6 GHz)
     - Dispatcher, FIFOs, time counter, output ports
   * - PS (`ps_clk`)
     - 100 MHz
     - AXI-Lite and AXI-Stream communication

**Rule:** `t_clk` must be ≥ `c_clk`. Never run the core faster than the time counter.

Related Instructions
--------------------

- `TIME rst` - Reset time counters
- `TIME set_ref` - Set reference time
- `TIME inc_ref` - Increment reference time
- `WAIT time @N` - Wait for specific user time
- `CLEAR` - Clear status flags (not directly time-related)

Common Pitfalls
---------------

**Pitfall 1: Forgetting that `s_out_time` is signed**

Negative values are allowed. If you accidentally write a negative time, the output will happen immediately (or when `t_abs` wraps around).

**Pitfall 2: Back-to-back TIME instructions**

TIME instructions cross clock domains. Do not execute two TIME instructions with less than 5 `c_clk` cycles between them.

**Pitfall 3: FIFO overflow in tight loops**

If you write ports faster than the dispatcher can process, the FIFO will fill and the core will stall. Monitor `s_status[15]` (FIFO_FULL).

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - Complete tProcessor v2 reference manual
* :doc:`/firmware` - Firmware overview and clock frequencies
* :doc:`../tprocv2_trm` - Time management section in main manual
