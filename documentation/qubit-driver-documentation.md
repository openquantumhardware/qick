# Qubit Driver Documentation

***Collin Bradford***

The qubit driver is designed as a software wrapper for the qsystem_2 hardware system that allows for characterization and control of a qubit. The characterization process using the qubit driver class is outlined in this document. 

## Configuration Dictionary

The settings in the class are all stored in a configuration dictionary `self.cfg`. The configuration dictionary can either be imported when the object is created, or built over time as a qubit is characterized. Each function of the class will default to values in the configuration dictionary unless a value is specified as a parameter to the function. 

The fields in the configuration dictionary are as follows: 


| Key | Name | Units | Description |
| :--- | :--- | :--- | :--- |
| `'qoch'` | 1 - 7 | Qubit Output Channel | Output channel for the quibt |
| `'coch'` | 1 - 7 | Cavity Ouput Channel | Output channel for the readout cavity |
| `'rch'` | 0 - 1 | Readout Channel | Readout channel for the system |
| `'qfreq'` | MHz | Qubit Frequency | Resonant frequency of the qubit |
| `'cfreq'` | MHz | Cavity Freuqency | Resonant frequency of the cavity |
| `'tof'` | clocks | Time of Flight | Time in clocks for a pulse to loop through the system. This value defaults to 214 which has been measured to be the typical tof for a loopback cable on the device. | 
| `'cperiod'` | ns | Clock Period | The clock period of the tproc in nanoseconds |
| `'maxSampBuf'` | samples | Maximum Sample Buffer Size | Size of the sample buffer in decimated samples | 

## Functions

Various functions are provided to demonstrate the capabilites of the RF SoC system and to characterize a qubit. Some getters and setters are provided for ease of use. 

### `__init__()`

Initialies the object and automatically writes the bitfile to the FGPA. 

| Parameter | Default Value | Units | Description |
| --- | --- | --- | --- |
| `qubitOutputChannel` | 7 | 1 - 7 | The qubit output channel that will be stored in the configuration dictionary |  
| `cavityOutputChannel` | 6 | 1 - 7 | The cavity output channel that will be stored in the configuration dictionary |  
| `readoutChannel` | 0 | 0 - 1 | The readout channel that will be stored in the configuration dictionary | 
| `configDictionary` | None | `dict` | Used to set the entire configuration dictionary. If present, this parameter will supersede the other parameters |

### `writeBitfile()` 

Writes the bitfile to the FGPA. This function is called at the end of the `__init__()` function is called. It can be called later to reset the FGPA. 

| Parameter | Default Value | Units | Description |
| --- | --- | --- | --- |
| `bitfile` | `'qsystem_2.bit'` | `string` | Location of the bitfile. |
| `initClocks` | `False` | `boolean` | Initialize the clocking hardware on the FPGA. This is generaly only run once after the FGPA is powered on. | 

### `runPulseExample()`

Creates a train of pulses on the qubit output channel specified on the global configuration dictionary and reads them back using the readout channel in the global configuration dictionary. It also uses the defualt time of flight from the global dictionary to trigger the readout. 

When used in oscilloscope mode, the readout will trigger on the first pulse and read out 1022 samples. The entire buffer will then be returned. If the pulse train exceeds the 1022 buffer length, the readout will re-trigger and only the end of the pulse train will be returned. 

By defualt, the pulese will be sent out with a gaussian envelope. If the user wishes to specify a differnt envelope, then one must be provided using the `envelope` parameter. A two-dimensional array should be provided where element `[0]` contains the q values and `[1]` contains the i values of the envelope. Each sub-array should contain `pulseWidth` number of values each representing the desired amplitude of that part of the envelope from 0 to `gain`. 

| Parameter | Default Value | Units | Description |
| --- | --- | --- | --- |
| `pulseCount` | 5 | int | Number of pulses to send |
| `frequency` | 500 | MHz | The output DDS frequency |
| `gain` | 32767 | n/a | The gain for the output pulses |
| `pulseWidth` | 100 | clocks | The width of the pulse in clocks |
| `delayWidth` | 150 | clocks | The width of the delay between pulses in clocks |
| `envelope` | `None` | array | The envelope to be used with the pulse. If `None` is selected, a gaussian will be generated| 
| `scopeMode` | `False` | boolean | Enable scope mode in which the full buffer is read out instead of just the pulses |
| `outputChannel` | `cfg['qoch']` | channel | Defines the output channel for the pulses. |
| `readoutChannel` | `cfg['rch']` | channel | Defines the readout channel. |

This function returns a list of values as follows: 

* ibuff - The real-value samples read from the readout buffer (either the pulses in normal mode or the entire buffer in scope mode) 
* qbuff - The imaginary-value samples read from the readout buffer (either the pulses in normal mode or the entire buffer in scope mode) 
* iacc - the real-value values read from the accumulated buffer
* qacc - the imaginary-value values read from the accumulated buffer


### `measureTOF()`

Makes a measurement of the time of flight for a pulse running through the system. By default, the function uses the cavity and readout channels from the configuration dictionary. The function sends out a pulse with a gaussian envelope and, after `tOffset`, it triggers and reads out the entire sample buffer. The highest value is taken to be the peak of the gaussian pulse which designates the center of the pulse sent out. Half the pulse width is then subtracted from the center to get the beginning of the pulse. This value is the time of flight value which designates the time from the start of a pulse going out to the beginning of the pulse coming in. 

Because the function uses rough pulse detection to determine the return time of the pulse, a `displayPlot` feature is enabled by default that will display the pulse and pulse detection metrics. It is important that the user check to be sure that the pulse can be seen in the buffer window that was recorded and that the peak detection is working properly. 

A proper plot will look like the following: 

<img src="images/time-of-flight-example.png" alt="time of flight example graph" class="center">

The key thing to look for is that the red "detected peak" line is in the middle of the peak. 

When characterizing a qubit, it is recommended that the user start with a time offset of zero and run the function with the default value of `displayPlot` which will display a plot of the incoming signal. Ideally, the user will see a clear gaussian pulse with the markers for the center of the pulse in the right place. In the case where the pulse takes more time than 2.66 μs (the time required to fill the sample buffer) to move through the system, only noise will be displayed on the graph. In that case, it is recommend that the user increase the time offset until the gaussian pulse can clearly be seen on the graph. Once the return pulse can be seen on the graph and the peak detection software has properly found the peak, the reutrn value will represent the time of flight, taking into account `tOffset`. 

The time of flight value found when the function is run is automatically stored in the configuration dictionary regardless of where the function has properly identified the time of flight. Thus, it is important to run the function with differnt values of `tOffset` unil the time of flight has been measured properly. 

| Parameter | Default Value | Units | Description |
| --- | --- | --- | --- |
| `frequency` | 500 | MHz | The frequency of the pulse |
| `gain` | 32767 | n/a | The gain of the pulse |
| `pulseWidth` | 100 | clocks | The width of the pulse |
| `tOffset` | 0 | clocks | The amount to delay the start of the readout | 
| `displayFig` | True | `boolean` | Enable to display a plot of the readout buffer and the peak detection results | 

Return value represents the number time of flight in clocks. 