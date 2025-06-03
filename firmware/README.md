QICK firmware
=================================================

For a description of the firmware design, see the [documentation](https://qick-docs.readthedocs.io/latest/firmware.html).

# Building the firmware yourself

If you want to make changes to the firmware, or you just want to look at the design and dig around:

* Pick the firmware project you want to build. The projects for the standard images for ZCU111, ZCU216, and RFSoC4x2 (`qick_111.bit`, `qick_216.bit`, `qick_4x2.bit`) are in subdirectories of the `projects` directory, as are projects for ZCU111 images with support for the v1 and v2 RF boards. You will find a project script (`proj.tcl`) and a block design script (`bd_2022-1.tcl` or similar).
* Install the version of Vivado specified by the block design filename (e.g. 2022.1 - older or newer will fail!), with a license that is valid for the FPGA you are using (you will have received such a license with your board). Start Vivado.
* In the Tcl console at the bottom of the screen navigate to this directory, then run the project script (e.g. `source ./proj.tcl`). This will create the firmware project and will end by showing you a block diagram of the firmware.
* Now click "Generate Bitstream" in the navigation menu at the left: this will compile the firmware.
* You need the .bit and .hwh files. These are not easy to find but the `out` directory has symlinks to their locations.

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
Same RFDC settings and connectivity as v2; this readout always expects interleaved input, and for dual-ADC systems (ZCU111, RFSoC4x2) you need to use an axis combiner and `axis_reorder_iq_v1`

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

* s_axis input: decimated data stream from readout
* m0_axis output: accumulated buffer to DMA, typically through a switch
* m1_axis output: decimated buffer to DMA, typically through a switch
* m2_axis output: individual accumulated data points to tProc input (for fast feedback), typically through a clock converter

buffer settings: N_AVG and N_BUF are up to you, setting the accumulated and decimated buffer lengths (buffer size will be `2^N`)

BRAM: 28.5 tiles for accumulated at typical N_AVG=14, 1 tile for decimated at typical N_BUF=10

### weighted buffer (`axis_weighted_buffer`):

same configuration as the standard buffer, adds the following port:

* s1_axis_weights: weights from DMA, typically through a switch (this can be the same switch that is used for generator envelopes)

buffer settings: N_AVG, N_BUF, N_WGT are up to you, setting the accumulated and decimated buffer lengths and the weights memory (size will be `2^N`)

BRAM: 28.5 tiles for accumulated at typical N_AVG=14, 1 tile each for decimated and weights at typical N_BUF=N_WGT=10

### multi-rate buffer (`mr_buffer_et`):

buffer settings: NM is samples per fabric clock, use 8; B is bits per sample, use 32; N is buffer size, up to you (buffer size will be `NM*2^N` samples)
BRAM: 8 tiles for typical N=10

### resonator emulator (`axis_pfba_pr_4x256_v1`, `axis_kidsim_v3`, `axis_pfbs_pr_4x256_v1`):

RFDC ADC settings on 216:
* Digital Output Data: I/Q
* Decimation Mode: 2x
* Samples per AXI4-Stream Cycle: 8
* Mixer Type: Coarse
* Mixer Mode: Real->I/Q
* Frequency: -Fs/4

on 4x2/111, 4 samples per cycle; between RFDC and analysis chain need a combiner then reorder IQ (B=16 L=4)

kidsim L=8

RFDC DAC settings:
* Interpolation Mode: 2x
* Samples per AXI4-Stream Cycle: 8
* Datapath Mode: DUC 0 to Fs/2
* Mixer Type: Coarse
* Mixer Mode: I/Q->Real
* Frequency: Fs/4

### time tagger (`qick_time_tagger`):
* qick_peripheral: to tProc v2 QPeriphA/B
* c_clk/c_aresetn: tProc core clock
* adc_clk/adc_aresetn: ADC fabric clock
* ps_clk/ps_aresetn: AXI clock
* m_axis_dma: to S_AXIS_S2MM port of a DMA

If IO ARM control is enabled, arm_i input can be connected to a tProc trigger bit.

DMA should have:
* buffer length width 18, address width 32
* write enabled, 1 channel, width 32 (auto), burst 16

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

BRAM: 1 tile per trigger output, 3 tiles per wave output, 8/4/5 tiles for P/D/W memories with AW=12/12/10

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

