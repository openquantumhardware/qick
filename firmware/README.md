QICK firmware
=================================================

This system includes the following components:

* 1 output channels connected to PMOD0-3 and triggers for Readout Block.
* 7 output channels connected to DACs.
* 2 input channels connected to ADCs.
* 1 instance of tProcessor 64-bit instructions, 32-bit registers.

Sampling frequency of ADC blocks is given by the variable ``soc.fs_adc``. Sampling frequency of DACs is stored in variable ``soc.fs_adc``. Fast-speed buffers were removed to save memory space. Raw data can be captured after x8 down-sampling.

Output channels driving DACs use the updated Signal Generator V4, which has the possibility to upload I/Q envelopes, and uses 32-bit resolution for both frequency and phase. The format of the control word was updated accordingly to accomodate the bits. See example asm files for a detailed description of the fields. The maximum length of the I/Q envelopes is given by the variable ``soc.gens[i].MAX_LENGTH``.

The readout block is actually built around two IPs: readout and average + buffer. Readout block includes a digital down-convertion, FIR filtering and decimation by 8. DDS frequency is configured using a register of the readout block and it is not intended to support real-time frequency hopping as in the Signal Generator side. After frequency shifting, filtering and decimation, the data stream is sent to the Average + Buffer block, which internally can store raw samples or perform the sum of the specified number of samples. The process is started with the external trigger signal, connected to output Channel 0 of tProcessor. The user can opt to route the input, the DDS wave or the frequency shifted signal to the FIR and decimation by 8 stage. This is done using a output selection register of the readout block. Regarding the buffering capabilities, the average section of the block has a buffer of ``soc.avg_bufs[i].AVG_MAX_LENGTH``.

<p align="center">
 <img src="../graphics/qsystem-readout.svg" alt="QICK readout" width=100% height=auto>
</p>

# tProcessor channel assignment


tProcessor will be used to control the real-time operation of the experiment. Output channels (AXIS MASTER) of the tProcessor are assigned as follows:

- Channel 0 : connected to PMOD0 0-3, and triggers for readout. Bits 0-3 are connected to PMOD0, bit 14 is connected to the trigger of the average/buffer block coming from the readout of ADC 224 CH0. Bit 15 is connected to the trigger of the average/buffer block coming from the readout of ADC 224 CH1.
- Channel 1 : connected to Signal Generator V4, which drives DAC 228 CH0.
- Channel 2 : connected to Signal Generator V4, which drives DAC 228 CH1.
- Channel 3 : connected to Signal Generator V4, which drives DAC 228 CH2.
- Channel 4 : connected to Signal Generator V4, which drives DAC 229 CH0.
- Channel 5 : connected to Signal Generator V4, which drives DAC 229 CH1.
- Channel 6 : connected to Signal Generator V4, which drives DAC 229 CH2.
- Channel 7 : connected to Signal Generator V4, which drives DAC 229 CH3.

**Note** that if you are using the Xilinx XM500 daughter board that comes with the ZCU111, be aware of the filters that are put on that XM500 board: DAC 229 channels 0 and 1 are high pass filtered by a 1 GHz high pass filter, so ensure that signals coming out of channels 4 and 5 are at least 1 GHz. Also, DAC 229 channels 2 and 3 are low pass filtered by a 1 GHz low pass filter, so ensure that signals coming out of channels 6 and 7 are less than 1 GHz. DAC 228 channels 0, 1 and 2 are not filtered by the XM500 daughter board.

The updated version of the tProcessor has 4 input (AXIS SLAVE) channels, which can be used for feedback. These are 64-bit, and the updated ``read`` instruction can specify channel number and upper/lower 32-bits to be read and written into an internal register. See example below on how to use this new capability.

* Channel 0 : connected to readout 0, which is driven by ADC 224 CH0
* Channel 1 : connected to readout 1, which is driven by ADC 224 CH1

**Note** that if you are using the Xilinx XM500 daughter board that comes with the ZCU111, be aware of the filters that are put on that XM500 board: ADC 224 channels 0 and 1 are low pass filtered by a 1 GHz low pass filter, so ensure that the signal coming into your XM500 board is less than 1 GHz so that it can be read in properly. 

Signal Generators are organized on the array ``soc.gens``, which is composed of 7 instances. Array index 0 is connected to tProcessor Channel 1, array index 1 is connected to tProcessor Channel 2, and so on. As way of example, let's assume the user needs to create a pulse on DAC 229 CH1 and DAC 229 CH3. These are connected to Channels 5, and 7 or the tProcessor, respectively. However, let's also assume that a gaussian envelope needs to be uploaded into the corresponding signal generator. ``soc.gens[3]`` drives DAC 229 CH1, and ``soc.gens[6]`` drives DAC 229 CH3.

Similarly, average and buffer inputs blocks are organized on ``soc.avg_bufs`` array, which has two instances of the Average + Buffer block. The user can access them using index 0 and 1.

# Timing

The DAC speed is ``384*16=6144 MHz`` (resolution ``~163 ps``) and the ADC speed is ``384*8 MHz`` but then the signal is decimated by a factor of ``8`` (resolution ``~2.6 ns``). The minimum DAC pulse length is 16 samples but if you want shorter pulses than that you can pad that pulse with zeros.

# Firmware parameters

* Pulse memory length: 65536 per channel x2 (I,Q), i.e., 128k total
* Decimated ADC buffer length: 1024 samples per component (I,Q), 2k total
* Accumulated ADC buffer length: 16384 samples per component (I,Q), 32k total
* tProc program memory length: 8k instructions of 64 bits, 64k Bytes total
* tProc data memory length: 4096 samples of 32 bits, 16k Bytes total
* tProc stack size: 256 samples of 32 bits, 1k Byte total
* Phase conversion from deg to reg: Phase resolution is 32-bit, that is \Delta \phi = 2 \pi /2^{32} or 360/2^{32}
* Gain is 16-bit signed [-32768,32767]

# Building the firmware yourself

If you want to make changes to the firmware, or you just want to look at the design and dig around:

* Install Vivado 2020.2, with a license that is valid for the FPGA you are using (you will have received such a license with your board). Start Vivado.
* In the Tcl console at the bottom of the screen navigate to this directory, then run `source ./proj_111.tcl` (or whichever of the proj_ scripts matches the board you are using). This will create the firmware project and will end by showing you a block diagram of the firmware.
* Now click "Generate Bitstream" in the navigation menu at the left: this will compile the firmware.
* You need the .bit and .hwh files. These are not easy to find but the `qick/firmware/out` directory has symlinks to their locations.
