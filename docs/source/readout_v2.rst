========================================================
Readout v2 (axis_readout_v2) - QICK Firmware
========================================================

.. contents::
  :local:
  :depth: 2

**axis_readout_v2** is the digital down-converter (DDC) IP that sits between
the RFDC's ADC output and :doc:`/avg_buffer`. It is the readout used on
tProc-v1-style single-tone (non-multiplexed, non-PFB) readout channels. The
module lives under ``firmware/ip/axis_readout_v2/`` and is exposed to Python
through ``qick.drivers.readout.AxisReadoutV2``.

--------------------------------------------------------------------
1. General Description
--------------------------------------------------------------------

``axis_readout_v2`` mixes the ADC's real-valued input samples down to
baseband with an on-chip DDS, then applies an FIR anti-aliasing filter and
decimates by 8 before handing the complex (I, Q) stream to
:doc:`/avg_buffer`. Unlike the newer PFB-based readouts, it demodulates a
single, software-tunable frequency (no simultaneous multi-tone channelizer).

The datapath, in order:

1. **down_conversion** (``down_conversion.v``) -- complex multiply of the
   real ADC input against a local DDS tone (``dds_compiler_0``), 16 parallel
   lanes (``N_DDS=16`` samples/clock, matching the RFDC's parallel output).
2. **down_conversion_fir** (``down_conversion_fir.v``) -- FIR low-pass
   (``fir_compiler_0``, fixed coefficients compiled into the bitstream) plus
   decimation by 8.
3. Output to ``axis_avg_buffer``'s ``s_axis``.

--------------------------------------------------------------------
2. Frequency/Output Control (``ctrl.sv``)
--------------------------------------------------------------------

Register writes don't take effect directly -- ``ctrl.sv`` packs
``freq``/``phase``/``nsamp``/``outsel``/``mode`` into a single 83-bit
descriptor pushed through a FIFO (driven by the ``WE_REG`` pulse), then
drains that FIFO into the N_DDS DDS phase accumulators:

.. list-table:: Descriptor fields (FIFO word, 83 bits)
   :header-rows: 1
   :widths: 20 15 65

   * - Field
     - Width
     - Description
   * - ``freq``
     - 32 bits
     - DDS tuning word (downconversion frequency).
   * - ``phase``
     - 32 bits
     - DDS phase offset.
   * - ``nsamp``
     - 16 bits
     - Sample count used when ``mode=0`` (see below).
   * - ``outsel``
     - 2 bits
     - Output source (see register map).
   * - ``mode``
     - 1 bit
     - 0: run for ``nsamp`` samples then stop. 1: run continuously
       (periodic).

The complex multiply itself: each of the 16 lanes takes one 16-bit real ADC
sample and multiplies it against that lane's complex DDS output
(``dds_compiler_0``, 32-bit {Q,I}), producing a 32-bit signed product per
component, rounded (add ``2**15``, keep bits ``[31:16]``) back down to 16-bit
I/Q before the output mux -- this is the "product" ``outsel`` value.

--------------------------------------------------------------------
3. Register Map
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - Register
     - Width
     - Description
   * - ``FREQ_REG``
     - 32 bits
     - Downconversion DDS frequency.
   * - ``PHASE_REG``
     - 32 bits
     - DDS phase offset.
   * - ``NSAMP_REG``
     - 16 bits
     - Sample count for one-shot mode (``MODE_REG=0``); ignored in periodic
       mode.
   * - ``OUTSEL_REG``
     - 2 bits
     - 0: product (mixer output, the normal downconverted signal). 1: dds
       (raw local oscillator tone, for calibration/debugging). 2: input
       (bypass -- the raw ADC sample, delay-matched to the other paths).
   * - ``MODE_REG``
     - 1 bit
     - 0: NSAMP (stop after ``NSAMP_REG`` samples). 1: Periodic (free-running
       tone).
   * - ``WE_REG``
     - 1 bit (pulse)
     - Toggling this 0->1->0 pushes the current FREQ/PHASE/NSAMP/OUTSEL/MODE
       register values into the descriptor FIFO as one atomic update.

--------------------------------------------------------------------
4. Key Parameters
--------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 15 60

   * - Parameter
     - Value
     - Notes
   * - Downsampling ratio
     - 8
     - Fixed FIR decimation; exposed to Python as ``DOWNSAMPLING = 8`` on
       the driver class.
   * - DDS/phase width
     - 32 bits
     - ``B_DDS = B_PHASE = 32`` on the driver.
   * - IQ offset
     - 0
     - Unlike the muxed/PFB readouts, ``axis_readout_v2`` introduces no
       fixed I/Q rounding offset (``IQ_OFFSET = 0.0`` -- see
       :meth:`.AcquireMixin._ro_offset`).
   * - tProc control
     - none
     - This readout is PYNQ/software-configured only; it has no
       ``tproc_ctrl`` connection (unlike the dynamic readouts, see
       :doc:`/readout_dynamic`).

--------------------------------------------------------------------
5. Python Interface
--------------------------------------------------------------------

As with the buffer (:doc:`/avg_buffer`), normal programs configure this
readout via :meth:`.QickProgram.declare_readout` (``freq``, ``phase``,
``sel``, ``gen_ch``), not by writing registers directly -- see
:doc:`/readout`'s Python Interface section for the full
``declare_readout()``/``trigger()``/``acquire()`` workflow.
``AxisReadoutV2.set_all()``/``set_all_int()`` exist for direct register
access but are explicitly for debugging: *"Normally the [readout] is
configured based on parameters supplied in QickProgram.declare_readout()."*

Related Documentation
----------------------

* :doc:`/readout` -- readout system overview and the normal
  ``declare_readout()`` workflow.
* :doc:`/avg_buffer` -- the buffer downstream of this readout's output.
* :doc:`/readout_dynamic` -- the tProc-configured readouts
  (``axis_readout_v3``/``axis_dyn_readout_v1``), for comparison.
* :doc:`topics/freq_matching` -- keeping generator and readout frequencies
  in sync.
