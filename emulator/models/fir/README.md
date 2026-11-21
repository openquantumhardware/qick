# Decimation By 8 FIR Filter

## Architecture

* Two paths that each take eight 16-bit samples are filtered independently from each other but use the same coefficients

* Design is not pipelined, so timing will not be closed properly

* Shift register outputs the data after some time to match the FIR Compiler's output timing

## Testbench 

* Impulse, step, and sinusoidal stimuli are used and tested against the FIR Compiler's outputs

* The sinusoidal example produces a summed 2 MHz and 50 MHz sine wave so that filtering is clearly visible with analog waveforms

## Accuracy

* In all tests, the average output difference between the behavioral model and the FIR Compiler is 2-3 signed decimal values out of 2^16 possibilites