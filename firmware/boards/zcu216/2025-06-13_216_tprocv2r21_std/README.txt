QICK running on ZCU216, software version 0.2.289

Firmware configuration (built Sat Sep 28 22:15:40 2024):

	Global clocks (MHz): tProcessor 430.080, RF reference 245.760

	16 signal generator channels:
	0:	axis_signal_gen_v6 - envelope memory 65536 samples (6.838 us)
		fs=9584.640 MHz, fabric=599.040 MHz, 32-bit DDS, range=9584.640 MHz
		DAC tile 0, blk 0 is 0_228, on JHC1
	1:	axis_signal_gen_v6 - envelope memory 16384 samples (1.709 us)
		fs=9584.640 MHz, fabric=599.040 MHz, 32-bit DDS, range=9584.640 MHz
		DAC tile 0, blk 1 is 1_228, on JHC2
	2:	axis_signal_gen_v6 - envelope memory 32768 samples (3.419 us)
		fs=9584.640 MHz, fabric=599.040 MHz, 32-bit DDS, range=9584.640 MHz
		DAC tile 0, blk 2 is 2_228, on JHC1
	3:	axis_signal_gen_v6 - envelope memory 16384 samples (1.709 us)
		fs=9584.640 MHz, fabric=599.040 MHz, 32-bit DDS, range=9584.640 MHz
		DAC tile 0, blk 3 is 3_228, on JHC2
	4:	axis_sg_mixmux8_v1 - envelope memory 0 samples (0.000 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 1, blk 0 is 0_229, on JHC1
	5:	axis_sg_int4_v2 - envelope memory 16384 samples (38.095 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 1, blk 1 is 1_229, on JHC2
	6:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 1, blk 2 is 2_229, on JHC1
	7:	axis_sg_int4_v2 - envelope memory 16384 samples (38.095 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 1, blk 3 is 3_229, on JHC2
	8:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 2, blk 0 is 0_230, on JHC3
	9:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 2, blk 1 is 1_230, on JHC4
	10:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 2, blk 2 is 2_230, on JHC3
	11:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 2, blk 3 is 3_230, on JHC4
	12:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 3, blk 0 is 0_231, on JHC3
	13:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 3, blk 1 is 1_231, on JHC4
	14:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 3, blk 2 is 2_231, on JHC3
	15:	axis_sg_int4_v2 - envelope memory 8192 samples (19.048 us)
		fs=6881.280 MHz, fabric=430.080 MHz, 32-bit DDS, range=1720.320 MHz
		DAC tile 3, blk 3 is 3_231, on JHC4

	10 readout channels:
	0:	axis_dyn_readout_v1 - configured by tProc output 4
		fs=2457.600 MHz, decimated=307.200 MHz, 32-bit DDS, range=2457.600 MHz
		maxlen 8192 accumulated, 4096 decimated (13.333 us)
		triggered by tport 10, pin 0, feedback to tProc input 0
		ADC tile 2, blk 0 is 0_226, on JHC7
	1:	axis_dyn_readout_v1 - configured by tProc output 4
		fs=2457.600 MHz, decimated=307.200 MHz, 32-bit DDS, range=2457.600 MHz
		maxlen 8192 accumulated, 4096 decimated (13.333 us)
		triggered by tport 11, pin 0, feedback to tProc input 1
		ADC tile 2, blk 2 is 2_226, on JHC7
	2:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 12, pin 0, feedback to tProc input 2
		ADC tile 2, blk 1 is 1_226, on JHC8
	3:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 13, pin 0, feedback to tProc input 3
		ADC tile 2, blk 1 is 1_226, on JHC8
	4:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 14, pin 0, feedback to tProc input 4
		ADC tile 2, blk 1 is 1_226, on JHC8
	5:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 15, pin 0, feedback to tProc input 5
		ADC tile 2, blk 1 is 1_226, on JHC8
	6:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 16, pin 0, feedback to tProc input 6
		ADC tile 2, blk 1 is 1_226, on JHC8
	7:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 17, pin 0, feedback to tProc input 7
		ADC tile 2, blk 1 is 1_226, on JHC8
	8:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 18, pin 0, feedback to tProc input -1
		ADC tile 2, blk 1 is 1_226, on JHC8
	9:	axis_pfb_readout_v4 - configured by PYNQ
		fs=2457.600 MHz, decimated=38.400 MHz, 32-bit DDS, range=38.400 MHz
		maxlen 8192 accumulated, 1024 decimated (26.667 us)
		triggered by tport 19, pin 0, feedback to tProc input -1
		ADC tile 2, blk 1 is 1_226, on JHC8

	8 digital output pins:
	0:	PMOD0_0_LS
	1:	PMOD0_1_LS
	2:	PMOD0_2_LS
	3:	PMOD0_3_LS
	4:	PMOD0_4_LS
	5:	PMOD0_5_LS
	6:	PMOD0_6_LS
	7:	PMOD0_7_LS

	tProc qick_processor ("v2") rev 21: program memory 4096 words, data memory 16384 words
		external start pin: None

	DDR4 memory buffer: 1073741824 samples (3.495 sec), 128 samples/transfer
		wired to readouts [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

	MR buffer: 8192 samples (3.333 us), wired to readouts [0, 1]

