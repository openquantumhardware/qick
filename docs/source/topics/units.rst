Time units
==========

Time durations are generally specified in units of clock cycles.
The relevant clocks are the tProcessor clock (`c_clk`) and the fabric clocks of the generators and readouts.
In general these can all be different (and can even vary among generators or readouts).

tProcessor Time
---------------

The tProcessor uses a 48-bit absolute time counter (`t_abs`) that runs at the DAC clock frequency (`t_clk`).
Time values in tProc assembly (e.g., `@1000`, `@s_out_time`) are in units of `t_clk` cycles.

**Typical clock frequencies:**

- `t_clk` (DAC clock): 384 MHz to 6 GHz
- `c_clk` (core clock): ≤ `t_clk` (typically 350-384 MHz)

**Conversion helpers in Python:**

For convenience, the :meth:`.QickConfig.us2cycles()` and :meth:`.QickConfig.cycles2us()` methods convert between floating-point times and integer cycles.
You must specify which clock you are using:

.. list-table:: Clock Selection for us2cycles()
   :header-rows: 1
   :widths: 30 40 30

   * - Parameter Type
     - Use
     - Example
   * - Generator (pulse length, sigma)
     - ``gen_ch`` (generator channel index)
     - ``soccfg.us2cycles(1e-6, gen_ch=0)``
   * - Readout (acquisition length)
     - ``ro_ch`` (readout channel index)
     - ``soccfg.us2cycles(1e-6, ro_ch=0)``
   * - tProcessor (wait, sync, delays)
     - No channel parameter
     - ``soccfg.us2cycles(1e-6)``

**Example:**

.. code-block:: python

   from qick import *

   soc = QickSoc()
   soccfg = soc.config

   # Convert 1 microsecond to tProc cycles
   tproc_cycles = soccfg.us2cycles(1e-6)
   print(f"1 us = {tproc_cycles} tProc cycles")

   # Convert 1 us to generator 0 cycles
   gen_cycles = soccfg.us2cycles(1e-6, gen_ch=0)
   print(f"1 us = {gen_cycles} generator cycles")

Note: tProc time values (`s_out_time`, `@time` in assembly) are **signed 32-bit integers**.
When using `us2cycles()`, ensure the result fits within ±2^31-1.

Related Documentation
---------------------

* :doc:`/tprocv2_trm` - tProcessor timing model
* :doc:`/sg_v6` - Signal Generator v6 documentation
* :doc:`/readout` - Readout system documentation
