How to play pulses with QICK
============================

With the tProcessor v2 and Signal Generator v6, playing a pulse involves three steps:

.. contents::
   :local:
   :depth: 2

Overview
--------

The pulse playback chain:

1. **Load waveform envelope** (optional) - Upload shaped pulse data to SG-v6 memory
2. **Configure parameters** - Write frequency, gain, length to registers (via tProc or Python)
3. **Schedule playback** - Use tProc to send parameters to SG-v6 at precise times

Step 1: Loading a waveform envelope
------------------------------------

(You skip this step for rectangular "const" pulses, which have no envelope.)

Each Signal Generator v6 has an internal waveform memory (BRAM) that stores I/Q envelope data.
Multiple waveforms can be stored in the same generator, and a single waveform can be reused
for different pulses (e.g., a Gaussian shape used for pulses with different flat-top durations).

**Python methods for loading envelopes:**

.. code-block:: python

   from qick import *
   import numpy as np

   soc = QickSoc()
   gen = soc.gens[0]  # Generator 0 (tProc channel 1)

   # Create a Gaussian envelope
   n_samples = 1024
   sigma = n_samples / 6
   envelope_i = 32767 * np.exp(-0.5 * ((np.arange(n_samples) - n_samples/2) / sigma)**2)
   envelope_q = np.zeros(n_samples)

   # Upload to generator memory at address 0
   gen.load_waveform(envelope_i.astype(int), envelope_q.astype(int), start_addr=0)

**Available envelope generators:**

- :meth:`.AbsQickProgram.add_gauss()` - Gaussian pulse
- :meth:`.AbsQickProgram.add_triangle()` - Triangular pulse
- :meth:`.AbsQickProgram.add_DRAG()` - DRAG pulse for qubit control
- :meth:`.AbsQickProgram.add_envelope()` - Custom arbitrary waveform

Step 2: Setting pulse parameters
--------------------------------

Pulse parameters are written to the tProc's wave parameter registers (`w_freq`, `w_phase`, `w_gain`, `w_env`, `w_length`, `w_conf`).

**Direct tProc assembly approach:**

.. code-block:: text

   ; Write parameters directly
   REG_WR w_freq imm #0x1000000
   REG_WR w_phase imm #0
   REG_WR w_gain imm #32768
   REG_WR w_env imm #0
   REG_WR w_length imm #1024
   REG_WR w_conf imm #0

   ; Send to SG-v6 (tProc channel 1)
   WPORT_WR p1 r_wave @1000

**From Python (using tProc WMEM for pre-loaded waveforms):**

.. code-block:: python

   from qick import *
   from qick.tprocv2_assembler import Assembler

   soc = QickSoc()
   tproc = soc.tproc

   # Pre-configure waveform in WMEM (address 0)
   tproc.load_wave(0, {
       'freq': soc.config.freq2reg(100e6, gen_ch=0),
       'phase': 0,
       'gain': 32768,
       'env': 0,           # envelope start address (0 for no envelope)
       'length': 1024,
       'conf': 0
   })

   # Assembly program: load and play
   asm_code = \"\"\"
       .ADDR 0x00
       REG_WR r_wave wmem [&0]
       WPORT_WR p1 r_wave @1000
       .END
   \"\"\"

   prog_bin = Assembler.str_asm2bin(asm_code)
   tproc.load_mem(prog_mem=prog_bin)
   tproc.start()

**Dynamic parameter updates (sweeps):**

To sweep a parameter (e.g., frequency) across multiple pulses:

.. code-block:: python

   # Pre-load base waveform to WMEM
   tproc.load_wave(0, base_params)

   # Create assembly program that updates frequency each loop
   asm_sweep = \"\"\"
       .ADDR 0x00
       REG_WR r0 imm #100        // number of steps
       REG_WR r1 imm #0x1000000  // start frequency
       REG_WR s_out_time imm #1000
   LOOP:
       REG_WR w_freq op -op(r1)
       REG_WR r_wave wmem [&0]   // load base params, keep new freq
       WPORT_WR p1 r_wave @s_out_time
       REG_WR r1 op -op(r1 + #0x10000)
       REG_WR s_out_time op -op(s_out_time + #500)
       REG_WR r0 op -op(r0 - #1) -uf
       JUMP LOOP -if(NZ)
       .END
   \"\"\"

Step 3: Firing the pulse
-------------------------

:meth:`.QickProgram.pulse()` is designed for the older tProc v1 API. For tProc v2, you directly write assembly or use the low-level tProc methods.

**Direct tProc execution:**

.. code-block:: python

   # Assuming tProc program is already loaded
   tproc.time_rst()
   tproc.start()

**Triggering readout simultaneously:**

To trigger readout at the same time as a pulse, use the tProc to send a trigger on channel 0:

.. code-block:: text

   ; Send pulse on channel 1 and trigger on channel 0 at same time
   WPORT_WR p1 r_wave @1000
   TRIG p0 set @1000

**Python helper for simple pulses (immediate playback without tProc):**

.. code-block:: python

   # For simple tests, use SG-v6 directly
   gen = soc.gens[0]
   gen.set_pulse(freq=100e6, phase=0, gain=0.5, length=1024)
   gen.trigger()   # Immediate playback

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - tProcessor v2 instruction set
* :doc:`/sg_v6` - Signal Generator v6 documentation
* :doc:`/firmware` - Channel assignments and firmware overview
* :doc:`tutorials` - tProc v2 tutorial examples
