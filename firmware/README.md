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

* Pick the firmware project you want to build. The projects for the standard images for ZCU111, ZCU216, and RFSoC4x2 (`qick_111.bit`, `qick_216.bit`, `qick_4x2.bit`) are `proj_111.tcl`, `proj_216.tcl`, `proj_4x2.tcl`.
* Install the correct version of Vivado (the standard projects use 2022.1), with a license that is valid for the FPGA you are using (you will have received such a license with your board). Start Vivado.
* In the Tcl console at the bottom of the screen navigate to this directory, then run the project .tcl file (e.g. `source ./proj_111.tcl`). This will create the firmware project and will end by showing you a block diagram of the firmware.
* Now click "Generate Bitstream" in the navigation menu at the left: this will compile the firmware.
* You need the .bit and .hwh files. These are not easy to find but the `qick/firmware/out` directory has symlinks to their locations.

To save your block design:

```
write_bd_tcl -force -include_layout bd.tcl
```

## Generators and readouts
Block RAM (1080 tiles total) is always the limiting resource. It is only used for our own IPs as listed below, with the exception of DMA cores which use 1-8 tiles each and the DDR4 interface which uses ~25.5 tiles.
High BRAM utilization will often make it harder for a design to meet timing.

### standard readout (`axis_readout_v2`):

RFDC ADC settings:
* Digital Output Data: Real
* Decimation Mode: 1x
* Samples per AXI4-Stream Cycle: 8
* Mixer Type: Coarse
* Mixer Mode: Real->Real

connect: RFDC -> axis register slice (optional, defaults) -> readout

BRAM: 16 tiles

### tProc-configured readout (`axis_readout_v3`):

RFDC ADC settings: same as standard

connect:
* RFDC -> axis clock converter (optional, defaults) -> axis resampler (B=16, N=8) -> axis register slice (optional, fully-registered) ->  readout, s1_axis
* tProc -> axis clock converter or cdcsync -> readout, s0_axis

BRAM: 8 tiles

### mux readout (`axis_pfb_readout_v2`) on 111:

RFDC ADC settings:
* Digital Output Data: I/Q
* Decimation Mode: 2x
* Samples per AXI4-Stream Cycle: 4
* Mixer Type: Coarse
* Mixer Mode: Real->I/Q
* Frequency: -Fs/4

connect: RFDC -> axis combiner (default settings) -> axis register slice (optional, defaults) -> PFB readout ("interleaved input" unchecked)

need a clock wizard to double the clock coming out of the RFDC

### mux readout (`axis_pfb_readout_v2`) on 216:

RFDC ADC settings:
* Digital Output Data: I/Q
* Decimation Mode: 2x
* Samples per AXI4-Stream Cycle: 8
* Mixer Type: Coarse
* Mixer Mode: Real->I/Q
* Frequency: -Fs/4

connect: RFDC -> axis register slice (optional, defaults) -> PFB readout ("interleaved input" checked)

### mux readout (`axis_pfb_readout_v3`) on 216:
Same RFDC settings and connectivity as v2; this readout does not currently support dual-ADC systems (ZCU111, RFSoC4x2)

BRAM: 8 tiles

### full-speed gen (`axis_signal_gen_v6`):

gen settings: N Dds=16, N is up to you (buffer size will be `16*2^N`)

RFDC DAC settings:
* Interpolation Mode: 1x
* Samples per AXI4-Stream Cycle: 16
* Datapath Mode: No DUC 0 to Fs/2
* Mixer Type: Coarse
* Mixer Mode: Real->Real

BRAM: 32 tiles for the DDSes, 64 tiles for our typical buffer size of N=12

### mux4 gen (`axis_sg_mux4`) v1 or v2:

gen settings: N_DDS=4

RFDC DAC settings:
* Interpolation Mode: 4x
* Samples per AXI4-Stream Cycle: 8
* Datapath Mode: DUC 0 to Fs/2
* Mixer Type: Fine
* Mixer Mode: I/Q->Real

BRAM: 32 tiles

### mux4 gen v3 (`axis_sg_mux4_v3`):

gen settings: N Dds=16

RFDC DAC settings: same as full-speed

BRAM: 128 tiles

### mux8 gen v1 (`axis_sg_mux8_v1`):

gen settings: N Dds=16

RFDC DAC settings: same as full-speed

BRAM: 256 tiles

### I/Q gen (`axis_constant_iq`):

gen settings: B=16, N=8

RFDC DAC settings:
* Interpolation Mode: 2x
* Samples per AXI4-Stream Cycle: 16
* Datapath Mode: DUC 0 to Fs/2
* Mixer Type: Fine
* Mixer Mode: I/Q->Real

### int4 gen (`axis_sg_int4_v1`):

gen settings: N is up to you (buffer size will be `2^N`)

RFDC DAC settings:
* Interpolation Mode: 4x
* Samples per AXI4-Stream Cycle: 8
* Datapath Mode: DUC 0 to Fs/2
* Mixer Type: Fine
* Mixer Mode: I/Q->Real

BRAM: 8 tiles for DDSes, 4 tiles for our typical N=12

### standard buffer (`axis_avg_buffer`):

buffer settings: N_AVG and N_BUF are up to you, setting the accumulated and decimated buffer lengths (buffer size will be `2^N`)

BRAM: 28.5 tiles for accumulated at typical N_AVG=14, 1 tile for decimated at typical N_BUF=10

### multi-rate buffer (`mr_buffer_et`):

buffer settings: NM is samples per fabric clock, use 8; B is bits per sample, use 32; N is buffer size, up to you (buffer size will be `NM*2^N` samples)
BRAM: 8 tiles for typical N=10

### tProc v1 (`axis_tproc64x32_x8`):

BRAM: 0.5 tile base, 1 tile for data memory, 2 tiles for standard program memory of 1k words (8 kB in address map)

### tProc v2 (`qick_processor`):
* s0_axis: feedback inputs
* dma: to DMA AXIS ports
* t_clk: timing clock (typically one of the DAC clocks)
* c_clk: core clock (can be anything, but max ~200 MHz, doubling the PL clock makes sense)
* ps_clk: AXI clock, from PS

need a DMA:
* buffer length width 26, address width 32
* read enabled, 1 channel, width 256, burst 2
* write enabled, 1 channel, width 256, burst 16

BRAM: 1 tile for trigger port FIFO, roughly 3 tiles per wave output (33 for 11 outputs, 20 for 7 outputs), 2/1/5 tiles for P/D/W memories with AW=10/10/8

## Expanding the program memory (tProc v1)

In theory you just need to change it in the address editor and it will propagate to the block design, but there is some bug in Vivado which leads to an error message that complains about asymmetry between the two memory ports:

https://support.xilinx.com/s/question/0D52E00007GSLhKSAX/block-memory-generator-asymmetry-error

This will even cause a saved bd.tcl script to fail: if you make a big memory with the workaround below, and save the bd.tcl, you will not be able to regenerate the project using that bd.tcl. So we give you a bd.tcl with a small program memory.

THe solution is similar to what is suggested in the forum post:

* reconfigure the memory controller for 2 ports
* disconnect the port B signals from the memory
* connect the memory controller port B to the memory port B
* now you can expand the memory and validate the design
* put things back the way they were - disconnect and remove controller port B, reconnect the memory to the tProc

