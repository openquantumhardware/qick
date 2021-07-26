from pynq import Overlay
from qsystem_2 import *
from qsystem2_asm import *

class qubit:

	def __init__(self, inputChannel = 0, outputChannel = 7):
		self.ich = inputChannel
		self.och = outputChannel
		
		self.writeBitfile()
		self.writeASM()

	def writeBitfile(self):
		self.soc = PfbSoc('qsystem_2.bit', force_init_clks=False)

	def writeASM(self,printASM=False):
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
			p.set(self.och,0,2,3,4,5,6,0)
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

	def runPulseExample(
		self,
		pulseCount = 5, 
		frequency = 200, 
		gain = 32767, 
		phase = 0, 
		address = 0, 
		nsamp = 100, 
		nsync = 250, 
		outputType = "product", 
		stdysel = 1, 
		mode = 0, 
		outsel = 0, 
		tOffset = 
		215, 
		tDuration = 5, 
		scopeMode = False):

		#Write requsite values to the memory of the tproc
		freqRegDAC = freq2reg(self.soc.fs_dac, frequency, B=32)
		self.soc.tproc.single_write(addr=1, data = pulseCount-1)
		self.soc.tproc.single_write(addr=2, data = freqRegDAC)
		self.soc.tproc.single_write(addr=3, data = phase)
		self.soc.tproc.single_write(addr=4, data = address)
		self.soc.tproc.single_write(addr=5, data = gain)
		self.soc.tproc.single_write(addr=6, data = nsamp)
		self.soc.tproc.single_write(addr=7, data = nsync)
		smo = 8*stdysel + 4*mode + outsel
		self.soc.tproc.single_write(addr=10, data = smo)
		self.soc.tproc.single_write(addr=11, data = tOffset)
		self.soc.tproc.single_write(addr=12, data = tDuration)

		# For envelope, upload envelope
		xg_i = gauss(mu=16*nsamp/2, si=nsamp, length=16*nsamp, maxv=30000)
		xg_q = np.zeros(len(xg_i))
		self.soc.gens[self.och-1].load(addr=address, xin_i=xg_i, xin_q=xg_q)

		#Set up the readout channel
		self.soc.readouts[self.ich].set_out(outputType)
		self.soc.readouts[self.ich].set_freq(frequency)
		decimatedLength = 1022 if scopeMode else int(pulseCount*nsamp)
		self.soc.avg_bufs[self.ich].config(address=0, length=1022 if scopeMode else nsamp)
		self.soc.avg_bufs[self.ich].enable()

		#Restart the tproc
		self.soc.tproc.stop()
		self.soc.tproc.start()

		#Get the results of the run
		idec,qdec = self.soc.get_decimated(ch=self.ich, length = decimatedLength)
		iacc,qacc =  self.soc.get_accumulated(ch=self.ich, length=pulseCount)

		#Return
		return idec,qdec,iacc,qacc

	def get_i_acc(self):
		return self.soc.tproc.single_read(addr=8)

	def get_q_acc(self):
		return self.soc.tproc.single_read(addr=9)