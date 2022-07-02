A high-level overview of the QICK software capabilities
=================================================

Below is a brief summary of the QICK software capabilities.

## Sending and receiving pulses
* Basic example given in [Demo 00_Send_receive_pulse](https://github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb)
* Control of 1st and 2nd Nyquist zone pulses, direct synthesis of pulses up to 6 GHz
* Decimated mode and acquire (I/Q) mode (with round-robin style data acquisition)
* Arbitrary pulse envelopes
* DAC modes of operation: CW mode, product mode, envelope-only mode
* ADC modes of operation: demodulation in the ADC
* Relative timing and phase control between pulses

## Sweeping variables within a QICK program
* Basic example given in [Demo 02_Sweeping_variables](https://github.com/openquantumhardware/qick/blob/main/qick_demos/02_Sweeping_variables.ipynb)
* The update function allows you to easily update parameters such as pulse gain in a fast loop (within a QICK program, rather than a Python slow loop over multiple QICK programs)

## Conditional logic within a QICK program
* Basic example given in [Demo 03_Conditional_logic](https://github.com/openquantumhardware/qick/blob/main/qick_demos/03_Conditional_logic.ipynb)
* The ability to play conditional pulses based on tProc register values

## Reading, math and writing within a QICK program
* Basic example given in [Demo 04_Reading_Math_Writing](https://github.com/openquantumhardware/qick/blob/main/qick_demos/04_Reading_Math_Writing.ipynb)
* The ability to write data to and read data from tProc memory addresses (which tProc registers can access) 
* Addition, subtraction, multiplication, bit shifting

## Measurements on quantum devices

The ZCU111 firmware posted in this repository has been tested on multiple different kinds of quantum devices:

* Measuring a transmon with high-fidelity readout and active reset enabled [Demo 06_qubit_demos](https://github.com/openquantumhardware/qick/blob/main/qick_demos/06_qubit_demos.ipynb)
* Measuring a storage cavity + qubit + readout cavity system
* Measuring a fluxonium qubit controlled with fast flux pulse gates
* Measuring a Kerr-cat qubit which expands on the standard transmon measurements by adding a squeezing drive and relative phase control

A modified version of the firmware with 4 DACs and 4 ADCs enabled (instead of 7 DACs and 2 ADCs enabled) has been tested:

* Measuring independently 4 high-Q resonators at once

## Features available on the QICK which are not included in this collection of demos
* Control other lab hardware remotely using the QICK (e.g. Yokogawa voltage source, Signalcore LO, digital step attenuators)
* Marker pulses coming out of the RFSoC PMOD pins

## Other examples of QICK measurement code, shared by QICK collaborators

* [Connie Miao, Schuster Lab](https://github.com/conniemiao/slab_rfsoc_expts)
* [Chao Zhou, Hatlab](https://github.com/PITT-HATLAB/Hatlab_RFSOC)
* [Sara Sussman, Houck Lab](https://github.com/sarafs1926/qick-amo)

