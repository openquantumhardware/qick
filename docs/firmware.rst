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

.. figure:: ../graphics/qsystem-readout.svg
   :width: 100%
   :align: center

tProcessor channel assignment
#############################

tProcessor will be used to control the real-time operation of the experiment. Output channels (AXIS MASTER) of the tProcessor are assigned as follows:

- Channel 0 : connected to PMOD0 0-3, and triggers for readout. Bits 0-3 are connected to PMOD0, bit 14 is connected to the trigger of the average/buffer block coming from the readout of ADC 224 CH0. Bit 15 is connected to the trigger of the average/buffer block coming from the readout of ADC 224 CH1.
- Channel 1 : connected to Signal Generator V4, which drives DAC 228 CH0.
- Channel 2 : connected to Signal Generator V4, which drives DAC 228 CH1.
- Channel 3 : connected to Signal Generator V4, which drives DAC 228 CH2.
- Channel 4 : connected to Signal Generator V4, which drives DAC 229 CH0.
- Channel 5 : connected to Signal Generator V4, which drives DAC 229 CH1.
- Channel 6 : connected to Signal Generator V4, which drives DAC 229 CH2.
- Channel 7 : connected to Signal Generator V4, which drives DAC 229 CH3.

The updated version of the tProcessor has 4 input (AXIS SLAVE) channels, which can be used for feedback. These are 64-bit, and the updated ``read`` instruction can specify channel number and upper/lower 32-bits to be read and written into an internal register. See example below on how to use this new capability.

* Channel 0 : connected to readout 0, which is driven by ADC 224 CH0
* Channel 1 : connected to readout 1, which is driven by ADC 224 CH1

Signal Generators are organized on the array ``soc.gens``, which is composed of 7 instances. Array index 0 is connected to tProcessor Channel 1, array index 1 is connected to tProcessor Channel 2, and so on. As way of example, let's assume the user needs to create a pulse on DAC 229 CH1 and DAC 229 CH3. These are connected to Channels 5, and 7 or the tProcessor, respectively. However, let's also assume that a gaussian envelope needs to be uploaded into the corresponding signal generator. ``soc.gens[3]`` drives DAC 229 CH1, and ``soc.gens[6]`` drives DAC 229 CH3.

Similarly, average and buffer inputs blocks are organized on ``soc.avg_bufs`` array, which has two instances of the Average + Buffer block. The user can access them using index 0 and 1.

Timing
########

The clock frequency of the FPGA is 384 MHz. Therefore, each clock cycle has a period of 2.6 ns.

Firmware parameters
###################

* Pulse memory length: 65536 per channel x2 (I,Q), i.e., 128k total
* Decimated ADC buffer length: 1024 samples per component (I,Q), 2k total
* Accumulated ADC buffer length: 16384 samples per component (I,Q), 32 k total
* tProc program memory length: 8k instructions of 64 bits, 64k Bytes total
* tProc data memory length: 4096 samples of 32 bits, 16k Bytes total
* tProc stack size: 256 samples of 32 bits, 1k Byte total
* Phase conversion from deg to reg: Phase resolution is 32-bit, that is :math:`\Delta \phi = 2 \pi /2^{32}` or :math:`360/2^{32}`
* Gain is 16-bit signed [-32768,32767]
