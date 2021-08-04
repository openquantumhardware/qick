from pynq import Overlay
from qsystem_2 import *
from qsystem2_asm import *

class qubit:

	def __init__(self, qubitOutputChannel = 7, cavityOutputChannel = 6, readoutChannel = 0, configDictionary = None):
		
		if configDictionary != None: 
			self.cfg = configDictionary
		else: 
			self.cfg = {}
			self.cfg['rch'] = readoutChannel
			self.cfg['coch'] = cavityOutputChannel
			self.cfg['qoch'] = qubitOutputChannel
			self.cfg['tof'] = 214
			self.cfg['maxSampBuf'] = 1022
		
		self.writeBitfile(initClocks = False)

	def writeBitfile(self, bitfile = 'qsystem_2.bit', initClocks = False):
		self.soc = PfbSoc(bitfile, force_init_clks=initClocks)

	def _writeDemoASM(self, outputChannel, printASM=False):
		with ASM_Program() as p:
			#Write all memory addresses to program memory
			p.memri(0,1,1,"Pulse Count")
			p.memri(0,2,2,"Encoded Frequency")
			p.memri(0,3,3,"Phase")
			p.memri(0,4,4,"Address")
			p.memri(0,5,5,"Gain")
			p.memri(0,6,6,"nsamp")
			p.memri(0,7,7,"nsync")
			p.memri(0,12,10,"smo")
			p.memri(0,13,11,"tOffset")
			p.memri(0,14,12,"tDuration")
			p.math(0,15,13,"+",14)
			#Set up nsamp and DAC selection register.
			# For envelope, set outsel=00
			#p.regwi(0,8,0b1000,"0b1000, stdysel = 1 (zero value), mode = 0 (nsamp), outsel = 00 (envelope).")
			p.memri(0, 8, 10)
			p.bitwi(0,8,8, "<<", 16)
			p.bitw(0,6,6,"|",8)
			#Delay the start a bit
			p.synci(1000)
			#Trigger value for the average block. 
			p.regwi(0,9,0xC001,"Trigger pmod0 bit0 and input channels 0 and 1") # Trigger average/buffer blocks of ADC channels 0 and 1
			#Loop
			p.label("LOOP")
			p.set(0,0,9,0,0,0,0,13)#Start the trigger
			p.set(0,0,0,0,0,0,0,15)#Stop the trigger
			p.set(outputChannel,0,2,3,4,5,6,0)
			p.sync(0,7)
			# Instead of the hardwired "5" and "15" in the next lines, use tOffset and tDuration to calculate tEnd
			# tOffset it hardwired to be 5, and for a tDuration of 10, that would yield tEnd to be 15.
			p.loopnz(0,1,"LOOP")

			# Wait and read average value
			p.waiti(0, 1000)

			p.read(0, 0, "lower", 10, "lower bits of channel 0 to page 0, register 10")
			p.read(0, 0, "upper", 11, "upper bits of channel 0 to page 0, register 11")
			p.memwi(0, 10, 8, "write page 0, register 10 to address 8")
			p.memwi(0, 11, 9, "write page 0, register 11 to address 9")
			#End the signal
			p.seti(0,0,0,0)

			self.soc.tproc.load_asm_program(p)
			if printASM: print(p)

	def _writeTOFASM(self, outputChannel, printASM=False):
		with ASM_Program() as p:
			#Write all memory addresses to program memory
			p.memri(0,2,2,"Encoded Frequency")
			p.memri(0,4,4,"Address")
			p.memri(0,5,5,"Gain")
			p.memri(0,6,6,"nsamp")
			p.memri(0,13,11,"tOffset")
			p.math(0,1,6,"+",13) #Add the pulse duration + the trigger offset to the device. 
			#Set up nsamp and DAC selection register.
			# For envelope, set outsel=00
			p.regwi(0,8,0b1000,"0b1000, stdysel = 1 (zero value), mode = 0 (nsamp), outsel = 00 (envelope).")
			p.bitwi(0,8,8, "<<", 16)
			p.bitw(0,6,6,"|",8)
			p.regwi(0,9,0xC001,"Trigger pmod0 bit0 and input channels 0 and 1") 
			#Delay the start a bit
			p.synci(1000)
			#Trigger value for the average block. 
			p.set(0,0,9,9,9,9,9,13)#Start the trigger at the offset value
			p.set(outputChannel,0,2,0,4,5,6,0)
			p.sync(0,1)
			#End the trigger signal
			p.seti(0,0,0,0)
			self.soc.tproc.load_asm_program(p)
			if printASM: print(p)

	def _writeFreqSweepASM(self, outputChannel, printASM=False):
		with ASM_Program() as p:
			#Write all memory addresses to program memory
			p.memri(0,1,1,"freq")
			p.memri(0,2,2,"gain")
			p.memri(0,3,3,"nsamp")
			#p.memri(1,7,1) # Set the readout frequency I believe this is depreciated. 
			p.memri(1,2,4,"Nsync")
			p.memri(1,3,5,"Loop")
			#Set up nsamp and DAC selection register. 
			p.regwi(0,4,0b0001,"0b1001, stdysel = 1 (zero value), mode = 0 (nsamp), outsel = 01 (dds).")
			p.bitwi(0,4,4, "<<", 16)
			p.bitw(0,3,3,"|",4)
			#Delay the start a bit
			p.synci(1000)
			#Trigger the average block. 
			p.regwi(1, 1, 0xC001)  
			p.seti(0,1,0,0) #Just set the triger to 0. 
			#Loop
			p.label("LOOP")
			p.seti(0,1,1,214) #Trigger the readout
			p.seti(0,1,0,219) #Disable trigger 5 clocks later. 
			p.set(outputChannel,0,1,0,0,2,3,0) # The Output Channel
			p.sync(1,2)
			p.loopnz(1,3,"LOOP")
			#End loop
			#Signal End
			p.seti(0, 1, 0, 0)
			p.end("all done")
		soc.tproc.load_asm_program(p)
		if printASM: print(p)

	def runPulseExample(
		self,
		pulseCount = 5, 
		frequency = 500, 
		gain = 32767, 
		pulseWidth = 100, 
		delayWidth = 150, 
		envelope = None,
		scopeMode = False, 
		outputChannel = None, 
		readoutChannel = None):
		
		#Although these variables are configurable within the tproc, they have been excluded for simplicity of the example. 
		phase = 0 
		outputType = "product"
		stdysel = 1
		mode = 0
		outsel = 0
		tDuration = 5 #Duration of the trigger pulse
		tOffset = self.cfg['tof']
		
		nsync = pulseWidth + delayWidth
		address = 0 #Address that the envelope will be stored at. 
		
		if outputChannel == None: outputChannel = self.cfg['qoch']
		if readoutChannel == None: readoutChannel = self.cfg['rch']
		
		#Write the required ASM code
		self._writeDemoASM(outputChannel)
		
		#Write requsite values to the memory of the tproc
		freqRegDAC = freq2reg(self.soc.fs_dac, frequency, B=32)
		self.soc.tproc.single_write(addr=1, data = pulseCount-1)
		self.soc.tproc.single_write(addr=2, data = freqRegDAC)
		self.soc.tproc.single_write(addr=3, data = phase)
		self.soc.tproc.single_write(addr=4, data = address)
		self.soc.tproc.single_write(addr=5, data = gain)
		self.soc.tproc.single_write(addr=6, data = pulseWidth)
		self.soc.tproc.single_write(addr=7, data = nsync)
		smo = 8*stdysel + 4*mode + outsel
		self.soc.tproc.single_write(addr=10, data = smo)
		self.soc.tproc.single_write(addr=11, data = tOffset)
		self.soc.tproc.single_write(addr=12, data = tDuration)

		# If an envelope was not given, provide a default envelope
		if envelope == None:
			envelope = []
			envelope.append(gauss(mu=16*pulseWidth/2, si=pulseWidth, length=16*pulseWidth, maxv=30000))
			envelope.append(np.zeros(16 * pulseWidth))
		self.soc.gens[outputChannel-1].load(addr=address, xin_i=envelope[0], xin_q=envelope[1])

		#Set up the readout channel
		self.soc.readouts[readoutChannel].set_out(outputType)
		self.soc.readouts[readoutChannel].set_freq(frequency)
		decimatedLength = self.cfg['maxSampBuf'] if scopeMode else int(pulseCount*pulseWidth)
		self.soc.avg_bufs[readoutChannel].config(address=0, length=1022 if scopeMode else pulseWidth)
		self.soc.avg_bufs[readoutChannel].enable()

		#Restart the tproc
		self.soc.tproc.stop()
		self.soc.tproc.start()

		#Get the results of the run
		if (decimatedLength <= self.cfg['maxSampBuf']): #We only want to try and read the decimated buffer if the length is less than the max buffer length. 
			idec,qdec = self.soc.get_decimated(ch=readoutChannel, length = decimatedLength)
		else: 
			idec, qdec = None, None
		iacc,qacc =  self.soc.get_accumulated(ch=readoutChannel, length=pulseCount)

		#Return
		return idec,qdec,iacc,qacc

	def measureTOF(
		self,
		frequency = 500, 
		gain = 32767, 
		pulseWidth = 100, 
		tOffset = 0, 
		displayFig = True):
		
		address = 0 #address where the gaussian envelope will be stored. 
		
		self._writeTOFASM(self.cfg['coch'])

		#Write requsite values to the memory of the tproc
		freqRegDAC = freq2reg(self.soc.fs_dac, frequency, B=32)
		self.soc.tproc.single_write(addr=2, data = freqRegDAC)
		self.soc.tproc.single_write(addr=4, data = address)
		self.soc.tproc.single_write(addr=5, data = gain)
		self.soc.tproc.single_write(addr=6, data = pulseWidth)
		self.soc.tproc.single_write(addr=11, data = tOffset)

		# For envelope, upload envelope
		xg_i = gauss(mu=16*pulseWidth/2, si=pulseWidth, length=16*pulseWidth, maxv=30000)
		xg_q = np.zeros(len(xg_i))
		self.soc.gens[self.cfg['coch']-1].load(addr=address, xin_i=xg_i, xin_q=xg_q)

		#Set up the readout channel
		self.soc.readouts[self.cfg['rch']].set_out("product")
		self.soc.readouts[self.cfg['rch']].set_freq(frequency)
		decimatedLength = 1000
		self.soc.avg_bufs[self.cfg['rch']].config(address=0, length=1000)
		self.soc.avg_bufs[self.cfg['rch']].enable()

		#Restart the tproc
		self.soc.tproc.stop()
		self.soc.tproc.start()

		#Get the results of the run
		idec,qdec = self.soc.get_decimated(self.cfg['rch'], length = decimatedLength)

		amps = np.abs(idec + 1j*qdec)
		times = np.linspace(tOffset, tOffset+999, 1000)

		#Plot the amplitudes with the best guess line
		bestLine = np.where(amps == np.amax(amps))[0][0]
		bestLine = bestLine + tOffset
		
		tof = bestLine - (pulseWidth / 2) #Calculate where the pulse actually began
		
		if displayFig: 
			fig = plt.figure()
			fig.set_figwidth(10)
			plt.plot(times, amps)
			plt.axvline(bestLine, ls="--", color="red", alpha=0.5, label="Detected Peak")
			plt.axvline(tof, ls="--", color="green", alpha = 0.5, label="Pulse Start")
			tofLabel = "Time of Flight: " + str(tof) + " clocks or " + str(tof * 2.6) + " ns"
			plt.axvspan(tOffset, tof, color="lightslategrey", alpha=0.2, label=tofLabel)
			plt.legend()
			plt.title("Time of Flight Test Readout")
			plt.show()

		#Return and update the dictionary 
		self.cfg['tof'] = tof
		return tof
	
	def singleToneSpec(self, freqStart = 1000, freqFinish = 3072, numFreqs = 1000, pulseWidth = 200, nReps = 100, gain = 32767): 
		freqs = np.linspace(freqStart, freqFinish, numFreqs)
		ampMeans = np.zeros(len(freqs))
		ampStds = np.zeros(len(freqs))
		phaseMeans = np.zeros(len(freqs))
		phaseStds = np.zeros(len(freqs))

		for i, f in enumerate(freqs):
			idec,qdec,iacc,qacc = self.runPulseExample(
				frequency = f, 
				gain = gain, 
				pulseCount = nReps, 
				pulseWidth = pulseWidth, 
				delayWidth = 100, 
				outputChannel = self.cfg['coch'], 
				readoutChannel = self.cfg['rch'])
			amps = np.abs(iacc + 1j * qacc)
			phases = np.angle(iacc + 1j * qacc)
			ampMeans[i] = amps[2:].mean()
			phaseMeans[i] = phases[2:].mean()

		return ampMeans, phaseMeans
	'''
	fig,ax = plt.subplots(2,1,sharex=True)
	ax[0].set_title("Frequency Sweep")
	#ax[0].errorbar(freqs, ampMeans, yerr=ampStds)
	ax[0].plot(freqs, ampMeans)
	ax[0].set_ylabel("Amplitude Means")
	#ax[1].errorbar(freqs, phaseMeans, yerr=phaseStds)
	ax[1].plot(freqs, phaseMeans)
	ax[1].set_ylabel("Phases in Radians")
	plt.xlabel("MHz")
	plt.show()
	'''

	def get_i_acc(self):
		return self.soc.tproc.single_read(addr=8)

	def get_q_acc(self):
		return self.soc.tproc.single_read(addr=9)