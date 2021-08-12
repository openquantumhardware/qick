from pynq import Overlay
from qsystem_2 import *
from qsystem2_asm import *
from scipy import signal
import warnings
try:
    from windfreak import SynthHD
    import serial
except ImportError: 
    print("Local oscillator contorl libraries not installed. The library will continue to function without the local oscillator functionality.")

class qubit:
    """
    The qubit driver is designed as a software wrapper for the qsystem_2 hardware system that allows for characterization and control of a qubit. The characterization process using the qubit driver class is outlined in this document.

    The settings in the class are all stored in a configuration dictionary `self.cfg`. The configuration dictionary can either be imported when the object is created, or built over time as a qubit is characterized. Each function of the class will default to values in the configuration dictionary unless a value is specified as a parameter to the function. 
    ...

    Attributes
    ----------
    cfg['qoch'] : int
        Output channel for the quibt 
    cfg['coch'] : int
        Output channel for the cavity
    cfg['rch'] : int
        Readout channel for the qubit
    cfg['qfreq'] : int
        Resonant frequency of the qubit in MHz
    cfg['cfreq'] : int
        Resonant frequency of the cavity in MHz
    cfg['cgain'] : int
        Gain for the readout pulse
    cfg['cReadoutDuration'] : int 
        Readout pulse duration in clocks
    cfg['tof'] : int
        Time of flight for a pulse through the readout cavity in clocks
    cfg['trigWidth'] : int
        Width of the readout trigger in clocks.
    cfg['clkPeriod'] : float
        Clock period of the tproc in nanoseconds
    cfg['maxSampBuf'] : int
        Size of the sample buffer in decimated sampes
    cfg['dacFreqWidth'] : int
        Bit width for the frequency register that controls the DAC DDS frequency
    cfg['loFreq'] : float
        The frequency of the local oscillator in MHz. This will be added to the the qubit or cavity frequency on return values where frequency is included as part of the return value. 
    cfg['loPower'] : float
        The power level of the local oscillator. 
    cfg['loEnabled'] : boolean
        Whether or not the local oscillator is enabled.
    cfg['maxADCFreq'] : int
        The maximum adc frequency in MHz. This represents the high end of the 2nd nyqist zone. 
    """

    def __init__(
        self, 
        qubitOutputChannel = 7,
        cavityOutputChannel = 6, 
        readoutChannel = 0, 
        configDictionary = None):
        """
        Initialies the object and automatically writes the bitfile to the FGPA. 
        
        Parameters
        ----------
        
        qubitOutputChannel : int, optional
            The qubit output channel that will be stored in the configuration dictionary
        cavityOutputChannel : int, optional
            The cavity output channel that will be stored in the configuration dictionary
        readoutChannel : int, optional
            The readout channel that will be stored in the configuration dictionary
        configDictionary : dict, optional
            Used to set the entire configuration dictionary. If present, this parameter will supersede the other parameters
        """
        if configDictionary != None: 
            self.cfg = configDictionary
        else: 
            self.cfg = {}
            self.cfg['rch'] = readoutChannel
            self.cfg['coch'] = cavityOutputChannel
            self.cfg['qoch'] = qubitOutputChannel
            self.cfg['tof'] = 214
            self.cfg['trigWidth'] = 5
            self.cfg['qfreq'] = 500
            self.cfg['cfreq'] = 500
            self.cfg['cgain'] = 32767
            self.cfg['cReadoutDuration'] = 200
            self.cfg['clkPeriod'] = 2.6
            self.cfg['maxSampBuf'] = 1022
            self.cfg['dacFreqWidth'] = 32
            self.cfg['loFreq'] = 0
            self.cfg['loPower'] = 0
            self.cfg['loEnabled'] = False
            self.cfg['maxADCFreq'] = 3072
        
        self.writeBitfile(initClocks = False)

    def writeBitfile(
        self, 
        bitfile = 'qsystem_2.bit', 
        initClocks = False):
        """
        Writes the bitfile to the FGPA. This function is called at the end of the `__init__()` function is called. It can be called later to reset the FGPA. 
        
        
        Parameters
        ----------
        
        bitfile : string, optional
            Location of the bitfile to be loaded onto the FPGA
        initClocks : boolean, optional
            Initialize the clocking hardware on the FPGA. This is generaly only run once after the FGPA is powered on.
        """
        self.soc = PfbSoc(bitfile, force_init_clks=initClocks)
    
    def initLO(
        self,
        port):
        
        """
            Initializes the local oscillator on `port`. 
            
        Parameters
        ----------
        port : string
            The port that the local oscillator is running on. 
        """
        
        self.synth = SynthHD(port)
        self.synth.init()
    
    def setLOFreq(
        self,
        channel,
        loFreq):
        
        """
        Set the frequency of the local oscillator. The function `initLO()` should be run before this function is used. 
        
        Parameters
        ----------
        
        loFreq : float
            The desired frequency of the local oscillator in MHz. 
        
        """
        self.cfg['loFreq'] = loFreq
        self.synth[channel].frequency = loFreq
    
    def setLOPower(
        self,
        channel,
        loPower):
        
        """
        Sets the power level of the local oscillaotr. 
        
        Parameters
        ---------
        loPower : float
            The desired power level of the local oscillator. 
        """
        
        self.cfg['loPower'] = loPower
        self.synth[channel].power = loPower
        
    def enableLO(
        self, 
        channel,
        enableLO):
        
        """
        Sets whether the local oscillator is enabled or not. 
        
        Parameters
        ----------
        enableLO : boolean
            Whether the external osciallator is enabled. 
        """
        
        self.cfg['loEnabled'] = enableLO
        self.synth[channel].enable = enableIO
        
    def _writeRabiASM(
        self,
        qubitChannel = None,
        cavityChannel = None,
        printASM = False):
        
        """
        Write the ASM code for the rabi measurement functionality. This may end up being more of a master ASM file because it has such robust functionality. 
        
        Parameters
        ----------
        
        qubitChannel : int, optional
            Used to overwrite the qubit channel in the configuration dictionary. If this value is left as `None`, the function will simply use the output channel set in the configuration dictionary. 
        cavityChannel : int, optional
            Used to overwrite the cavity channel in the configuration dictionary. If this value is left as `None`, the function will simply use the output channel set in the configuration dictionary. 
        printASM : boolean, optional
            Used to print the ASM code that is loaded onto the device for debugging purposes. 
        """
        
        if qubitChannel == None: 
            qubitChannel = self.cfg['qoch']
        if cavityChannel == None:
            cavityChannel = self.cfg['coch']
        
        with ASM_Program() as p:
            #Write all memory addresses to program memory
            #Set the frequency for the qubit channel 
            p.memri(0, 1, 1,"freq qubit channel")
            #Set the start gain and delta gain for the qubit channel
            p.memri(0, 2, 2,"start/current gain qubit channel")
            p.memri(0, 3, 3,"delta gain qubit channel")
            #Set the start time and delta time for the qubit excitation pulse
            p.memri(0, 4, 4,"start time qubit excitation pulse")
            p.memri(0, 5, 5,"delta time for qubit excitation pulse")
            #Set the frequency, gain, and time for the cavity readout pulse
            p.memri(0, 6, 6,"Freuqency for cavity readount pulse")
            p.memri(0, 7, 7,"Gain for cavity readount pulse")
            p.memri(0, 8, 8,"Time duration for cavity readout pulse")
            #Set the post-readout relaxation time
            p.memri(0, 12, 11,"Post-readout relaxation time")
            #Set the pre-readout relaxation time
            p.memri(0, 13, 12,"Pre-readout start relaxation time")
            p.memri(0, 14, 13,"Pre-readout delta relaxation time")
            #Set the outer and inner loop count registers
            p.memri(1, 1, 9,"Gain loop count")
            p.memri(1, 2, 10,"Qubit pulse time loop count")
            p.memri(1, 3, 14,"Iteration loop count")
            #Trigger value for the average block. This will be enabled during the cavity readout pulse
            #p.regwi(1,6, 0x4001 if cavityChannel == 0 else 0x8001)
            p.regwi(1,6, 0xC001)
            #Set up the DAC selection and pulse duration register for the qubit channel
            p.regwi(0,9,0b1001,"0b1001, stdysel = 1 (zero value), mode = 0 (nsamp), outsel = 01 (DDS).") #Value
            p.bitwi(0,9,9, "<<", 16) #Shift it left and leave it in r9
            p.bitw(0,10,15,"|",9) #Combine the settings into register 10. We use a different register so that we can combine values in fewer steps later when the pulse duration changes. 
            #Set up the DAC Selection and pulse duration register for the cavity channel. We use the same ouptut select because it is the same for both channels. Only the pusle duration is different for this register. 
            p.bitw(0,11,8,"|",9)
            #Delay the start a bit
            p.synci(1000)
            #Loop
            p.label("GAIN_LOOP")
            #Reset the pulse loop count
            p.math(1,4,0,"+",2) #Reset the pulse loop
            #Reset all things iterated in the pulse_loop loop
            p.math(0,15,0,"+",4) #Reset the pulse duration
            p.math(0,16,0,"+",13) #Reset the pre-readout delay
            p.bitw(0,10,15,"|",9) #Update the pulse duration. 
            p.label("PULSE_LOOP")
            #Reset the iteration loop count
            p.math(1,5,0,"+",3)
            p.label("ITERATION_LOOP")
            #Que the qubit pulse immediately and que all later operations after it finishes
            p.set(qubitChannel,0,1,0,0,2,10,0)
            p.sync(0,15)
            #Delay for the pre-readout delay
            p.sync(0,16)
            #Que the readout pulse right after the qubit pulse, start the trigger, and que all later operations after it finishes
            p.set(cavityChannel,0,6,0,0,7,11,0)
            p.seti(0,1,6,self.cfg['tof'])
            p.sync(0,8)
            #Delay for the relaxation time
            #Disable the trigger
            p.seti(0,1,0,self.cfg['tof'] + self.cfg['trigWidth'])
            p.sync(0,12)
            p.loopnz(1,5,"ITERATION_LOOP")
            #Run the math to add the gain values and time delay values for the next iteration of the inner loop. 
            p.math(0,15,15,"+",5) #Add delta time to the current time and store it in the current time register. 
            p.math(0,16,16,"+",14) #Add the delta pre-readout time delay to the pre-readout time delay. 
            p.bitw(0,10,15,"|",9) #Update the pulse duration. 
            p.loopnz(1,4,"PULSE_LOOP")
            p.math(0,2,2,"+",3) #Add delta gain to the current gain and store it in the current gain register. 
            p.loopnz(1,1,"GAIN_LOOP")
            #End the signal
            p.seti(0,0,0,0)
        self.soc.tproc.load_asm_program(p)

    def _writeDemoASM(
        self, 
        outputChannel, 
        printASM=False):
        """
        Write the ASM code for the pulse output demo to the tproc. 
        
        Parameters
        ---------
        
        outputChannel : int
            Defines the output channel to use for the pulses
        printASM : boolean, optional
            If `True`, the function will print the ASM code after uploading it to the board. 
        """
        
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

#             p.read(0, 0, "lower", 10, "lower bits of channel 0 to page 0, register 10")
#             p.read(0, 0, "upper", 11, "upper bits of channel 0 to page 0, register 11")
#             p.memwi(0, 10, 8, "write page 0, register 10 to address 8")
#             p.memwi(0, 11, 9, "write page 0, register 11 to address 9")
            #End the signal
            p.seti(0,0,0,0)

            self.soc.tproc.load_asm_program(p)
            if printASM: print(p)

    def _writeTOFASM(
        self, 
        outputChannel, 
        printASM=False):
        """
        Write the ASM code for the time of flight function to the tproc. 
        
        Parameters
        ---------
        
        outputChannel : int
            Defines the output channel to use for the pulses
        printASM : boolean, optional
            If `True`, the function will print the ASM code after uploading it to the board. 
        """
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

    def sendPulses(
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
        
        """
        Creates a train of pulses on the qubit output channel specified on the global configuration dictionary and reads them back using the readout channel in the global configuration dictionary. It also uses the defualt time of flight from the global dictionary to trigger the readout. 

        When used in oscilloscope mode, the readout will trigger on the first pulse and read out 1022 samples. The entire buffer will then be returned. If the pulse train exceeds the 1022 buffer length, the readout will re-trigger and only the end of the pulse train will be returned. 

        By defualt, the pulese will be sent out with a gaussian envelope. If the user wishes to specify a differnt envelope, then one must be provided using the `envelope` parameter. A two-dimensional array should be provided where element `[0]` contains the q values and `[1]` contains the i values of the envelope. Each sub-array should contain `pulseWidth` number of values each representing the desired amplitude of that part of the envelope from 0 to `gain`. 
        
        Parameter
        ---------
        
        pulseCount : int, optional
            Number of pulses to send
        frequency : int, optional
            The output DDS frequency
        gain : int, optional
            The gain for the output pulses
        pulseWidth : int, optional
            The width of the pulse in clocks
        delayWidth : int, optional
            The width of the delay between pulses in clocks
        envelop : list, optional
            The envelope to be used with the pulse. If `None` is selected, a gaussian will be generated
        scopeMOde : boolean, optional
            Enable scope mode in which the full buffer is read out instead of just the pulses
        outputChannel : int, optional
            Defines the output channel for the pulses.
        readoutChannel : int, optional
            Defines the readout channel
            
        Returns
        -------
        list
            The real-value samples read from the readout buffer (either the pulses in normal mode or the entire buffer in scope mode) 
        list
            The imaginary-value samples read from the readout buffer (either the pulses in normal mode or the entire buffer in scope mode) 
        list 
            The real-value values read from the accumulated buffer
        list
            The imaginary-value values read from the accumulated buffer
        """
        
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
        freqRegDAC = freq2reg(self.soc.fs_dac, frequency, B=self.cfg['dacFreqWidth'])
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
            envelope.append(gauss(mu=16*pulseWidth/2, si=pulseWidth, length=16*pulseWidth, maxv=gain))
            envelope.append(np.zeros(16 * pulseWidth))
        self.soc.gens[outputChannel-1].load(addr=address, xin_i=envelope[0], xin_q=envelope[1])

        #Set up the readout channel
        self.soc.readouts[readoutChannel].set_out(outputType)
        self.soc.readouts[readoutChannel].set_freq(frequency)
        decimatedLength = self.cfg['maxSampBuf'] if scopeMode else int(pulseCount*pulseWidth)
        self.soc.avg_bufs[readoutChannel].config(address=0, length=self.cfg['maxSampBuf'] if scopeMode else pulseWidth)
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
        """
        Makes a measurement of the time of flight for a pulse running through the system. By default, the function uses the cavity and readout channels from the configuration dictionary. The function sends out a pulse with a gaussian envelope and, after `tOffset`, it triggers and reads out the entire sample buffer. The highest value is taken to be the peak of the gaussian pulse which designates the center of the pulse sent out. Half the pulse width is then subtracted from the center to get the beginning of the pulse. This value is the time of flight value which designates the time from the start of a pulse going out to the beginning of the pulse coming in. 

        Because the function uses rough pulse detection to determine the return time of the pulse, a `displayPlot` feature is enabled by default that will display the pulse and pulse detection metrics. It is important that the user check to be sure that the pulse can be seen in the buffer window that was recorded and that the peak detection is working properly.
        
        When characterizing a qubit, it is recommended that the user start with a time offset of zero and run the function with the default value of `displayPlot` which will display a plot of the incoming signal. Ideally, the user will see a clear gaussian pulse with the markers for the center of the pulse in the right place. In the case where the pulse takes more time than 2.66 μs (the time required to fill the sample buffer) to move through the system, only noise will be displayed on the graph. In that case, it is recommend that the user increase the time offset until the gaussian pulse can clearly be seen on the graph. Once the return pulse can be seen on the graph and the peak detection software has properly found the peak, the reutrn value will represent the time of flight, taking into account `tOffset`. 

        The time of flight value found when the function is run is automatically stored in the configuration dictionary regardless of where the function has properly identified the time of flight. Thus, it is important to run the function with differnt values of `tOffset` unil the time of flight has been measured properly. 
        
        Parameters 
        ---------
        frequency : int, optional
            The frequency of the pulse
        gain : int, optional
            The gain of the pulse
        pulseWidth : int, optional
            The width of the pulse
        tOffset : int, optional
            The amount to delay the start of the readout
        displayFig : int, optional
            Enable to display a plot of the readout buffer and the peak detection results
            
        Returns
        -------
        float
            The time of flight in clocks
        """
        
        address = 0 #address where the gaussian envelope will be stored. 
        
        self._writeTOFASM(self.cfg['coch'])

        #Write requsite values to the memory of the tproc
        freqRegDAC = freq2reg(self.soc.fs_dac, frequency, B=self.cfg['dacFreqWidth'])
        self.soc.tproc.single_write(addr=2, data = freqRegDAC)
        self.soc.tproc.single_write(addr=4, data = address)
        self.soc.tproc.single_write(addr=5, data = gain)
        self.soc.tproc.single_write(addr=6, data = pulseWidth)
        self.soc.tproc.single_write(addr=11, data = tOffset)

        # For envelope, upload envelope
        xg_i = gauss(mu=16*pulseWidth/2, si=pulseWidth, length=16*pulseWidth, maxv=gain)
        xg_q = np.zeros(len(xg_i))
        self.soc.gens[self.cfg['coch']-1].load(addr=address, xin_i=xg_i, xin_q=xg_q)

        #Set up the readout channel
        self.soc.readouts[self.cfg['rch']].set_out("product")
        self.soc.readouts[self.cfg['rch']].set_freq(frequency)
        self.soc.avg_bufs[self.cfg['rch']].config(address=0, length=self.cfg['maxSampBuf'])
        self.soc.avg_bufs[self.cfg['rch']].enable()

        #Restart the tproc
        self.soc.tproc.stop()
        self.soc.tproc.start()

        #Get the results of the run
        idec,qdec = self.soc.get_decimated(self.cfg['rch'], length = self.cfg['maxSampBuf'])

        amps = np.abs(idec + 1j*qdec)
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            ampsFiltered = (signal.correlate(amps, xg_i, mode='same')/len(amps)) 
            
        amps = ampsFiltered #Delete this line to use unfiltered amplitudes
        times = np.linspace(tOffset, tOffset+self.cfg['maxSampBuf'] - 1, self.cfg['maxSampBuf'])

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
            tofLabel = "Time of Flight: " + str(tof) + " clocks or " + str(tof * self.cfg['clkPeriod']) + " ns"
            plt.axvspan(tOffset, tof, color="lightslategrey", alpha=0.2, label=tofLabel)
            plt.legend()
            plt.title("Time of Flight Test Readout")
            plt.show()

        #Return and update the dictionary 
        self.cfg['tof'] = int(np.round(tof)) #This number must be an integer as that is what the tproc accepts. 
        return tof
    
    def singleToneSpec(
        self, 
        freqStart = 1000, 
        freqFinish = 3072, 
        numFreqs = 100, 
        pulseWidth = 200, 
        pulseDelay = 100,
        nReps = 100, 
        gain = 32767): 
        
        """
        Performs a frequency sweep from `freqStart` to `freqFinsih` with `numFreqs` nubmer of frequency steps. `nReps` defines the number of times each frequency measurement is repeated and averageed. 
        
        Parameters
        ----------
        
        freqStart : int, optional
            Start frequency of the sweep in MHz
        freqFinish : int, optional
            End frequency in MHz. This number should be less than cfg['maxADCFreq']
        numFreqs : int, optional
            Number of steps to use for the frequency sweep
        pulseWidth : int, optional 
            The width of each pulse that is sent in clocks
        pulseDelay : int, optional
            The delay time between pulses. 
        nReps : int, optional
            The number of repetitions for each frequency. Each frequency pulse set will be averaged before the value is sent back. 
        gain : int, optional
            THe max gain at which the pulses will be sent
            
        Returns
        ------
        float[]:
            List of freuqencies used. These will take into account the local oscillaotr freuqnecy
        float[]: 
            List of amplitudes that were returned and averaged for each frequency
        float[]:
            LIst of phasses that were returned and averaged for each frequency
        """
        
        freqs = np.linspace(freqStart, freqFinish, numFreqs)
        ampMeans = np.zeros(len(freqs))
        ampStds = np.zeros(len(freqs))
        phaseMeans = np.zeros(len(freqs))
        phaseStds = np.zeros(len(freqs))

        for i, f in enumerate(freqs):
            idec,qdec,iacc,qacc = self.sendPulses(
                frequency = f, 
                gain = gain, 
                pulseCount = nReps, 
                pulseWidth = pulseWidth, 
                delayWidth = pulseDelay, 
                outputChannel = self.cfg['coch'], 
                readoutChannel = self.cfg['rch'])
            amps = np.abs(iacc + 1j * qacc)
            phases = np.angle(iacc + 1j * qacc)
            ampMeans[i] = amps[2:].mean()
            phaseMeans[i] = phases[2:].mean()
            
        
        if self.cfg['loEnabled']: 
            freqs = freqs + self.cfg['loFreq']

        return freqs, ampMeans, phaseMeans
    
    def twoToneSpec(
        self, 
        freqStart = 1000, 
        freqFinish = 3072, 
        numFreqs = 100, 
        pulseWidth = 200, 
        pulseDelay = 100,
        nReps = 100, 
        gain = 32767): 
        
        """
        Performs a two tone spectroscopy test in which the cavity frequency is held constant at `cfg['cfreq']` and the qubit frequency is swept. 
        
        Parameters
        ----------
        
        freqStart : int, optional
            Start frequency of the sweep in MHz
        freqFinish : int, optional
            End frequency of the sweep in MHz. This number should be less than cfg['maxADCFreq']
        numFreqs : int, optional
            Number of steps to use for the frequency sweep
        pulseWidth : int, optional 
            The width of each pulse that is sent in clocks
        pulseDelay : int, optional
            The delay time between pulses. 
        nReps : int, optional
            The number of repetitions for each frequency. Each frequency pulse set will be averaged before the value is sent back. 
        gain : int, optional
            THe max gain at which the pulses will be sent
            
        Returns
        ------
        float[]:
            List of freuqencies used. These will take into account the local oscillaotr freuqnecy
        float[]: 
            List of amplitudes that were returned from the cavity and averaged for each frequency
        float[]:
            List of phases that were returned and averaged for each frequency
        """
        
        freqs = np.linspace(freqStart, freqFinish, numFreqs)
        ampMeans = np.zeros(len(freqs))
        ampStds = np.zeros(len(freqs))
        phaseMeans = np.zeros(len(freqs))
        phaseStds = np.zeros(len(freqs))

        for i, f in enumerate(freqs):
            idec,qdec,iacc,qacc = self.rabiOscillation( # We use rabi oscillation because it does what we need. In a future version of the code, we will combine most of the pusle work into a single pulse function with ASM. 
                qubitFrequency = f, 
                qStartGain = gain, 
                qDeltaGain = 0,
                pulseWidthStart = pulseWidth,
                pulseWidthDelta = 0,
                preReadoutDelayStart = 0, 
                preReadoutDelayDelta = 0,
                postReadoutDelay = pulseDelay,
                gainLoopCount = 1,
                durationLoopCount = 1,
                iterationLoopCount = nReps)
            amps = np.abs(iacc + 1j * qacc)
            phases = np.angle(iacc + 1j * qacc)
            ampMeans[i] = amps[2:].mean()
            phaseMeans[i] = phases[2:].mean()
            
        if self.cfg['loEnabled']:
            freqs = freqs + self.cfg['loFreq']

        return freqs, ampMeans, phaseMeans
    
    def rabiOscillation(
        self,
        qStartGain = 32767,
        qDeltaGain = 0, 
        pulseWidthStart = 100, 
        pulseWidthDelta = 50,
        preReadoutDelayStart = 100,
        preReadoutDelayDelta = 0,
        postReadoutDelay = 300,
        gainLoopCount = 1,
        durationLoopCount = 5,
        iterationLoopCount = 10,
        qubitFrequency = None):
        
        """
        Performs rabi oscillation testing. 
        
        The code works using three loops. The outer gain loop increments the gain value each time the loop is run. The middle duration loop increments the pulse width and pre-readout delay each time it is run. The center loop does not increment anything. To sweep a variable, simply provide a start and delta values and a loop count as needed. If a programmer wishes for a variable that is normally swept to remain constant, one would simply select the delta value to be zero. 
        
        Parameters
        ----------
        qStartGain : int, optional
            The beginning gain value for the cavity. 
        qDeltaGain : int, optional
            The delta gain value to be incremented every time the outer gain loop runs. 
        pulseWidthStart : int, optional
            The start time duration for the qubit excitation pulse expressed in clocks. 
        pulseWidthDelta : int, optinal
            The delta time duration for the qubit excitation pulse to be added each time the inner loop runs expressed in clocks. 
        preReadoutDelayStart : int, optional
            The start time duration for the delay given between the qubit excitation pulse and the readout pulse expressed in clocks. 
        preReadoutDelayDelta : int, optional
            The delta time duration for the delay given between the qubit excitation pulse and the readout pulse expressed in clocks. This will be added to `preReadoutDelayStart` every time the inner loop rolls over. 
        postReadoutDelay : int, optional
            THe delay time given after a readout pulse. 
        gainLoopCount : int, optional
            Number of times to increment the gain
        durationLoopCount : int, optional
            Number of times to run the inner loop that increments the qubit pulse druation and the pre-readout delay duration. 
        iterationLoopCount : int, optional
            Number of times to run each individual test
        qubitFrequency : float, optional
            Used to overwrite the qubit frequency stored in `cfg['qfreq']`. If left as `none`, this value will take the value of `cfg['qfreq']
        """
        
        if qubitFrequency == None: 
            qubitFrequency = self.cfg['qfreq']
        
        self._writeRabiASM()
        
        #Populate the address space. 
        qFreqReg = freq2reg(self.soc.fs_dac, qubitFrequency, B=32)
        self.soc.tproc.single_write(addr=1, data=qFreqReg)

        self.soc.tproc.single_write(addr=2, data=qStartGain)
        self.soc.tproc.single_write(addr=3, data=qDeltaGain)

        self.soc.tproc.single_write(addr=4, data=pulseWidthStart)
        self.soc.tproc.single_write(addr=5, data=pulseWidthDelta)

        cavFreqReg = freq2reg(self.soc.fs_dac, self.cfg['cfreq'], B=32)
        self.soc.tproc.single_write(addr=6, data=cavFreqReg)
        self.soc.tproc.single_write(addr=7, data=self.cfg['cgain'])
        self.soc.tproc.single_write(addr=8, data=self.cfg['cReadoutDuration'])

        self.soc.tproc.single_write(addr=9, data=gainLoopCount-1)
        self.soc.tproc.single_write(addr=10, data=durationLoopCount-1)
        self.soc.tproc.single_write(addr=14, data=iterationLoopCount-1)

        self.soc.tproc.single_write(addr=11, data=postReadoutDelay)

        self.soc.tproc.single_write(addr=12, data=preReadoutDelayStart)
        self.soc.tproc.single_write(addr=13, data=preReadoutDelayDelta)


        decimatedLength = self.cfg['cReadoutDuration']
        accumulatedLength = gainLoopCount * durationLoopCount * iterationLoopCount

        #Set up the readout buffer
        self.soc.readouts[self.cfg['rch']].set_out("product")
        self.soc.readouts[self.cfg['rch']].set_freq(self.cfg['cfreq'])
        self.soc.avg_bufs[self.cfg['rch']].config(address=self.cfg['rch'], length=decimatedLength)
        self.soc.avg_bufs[self.cfg['rch']].enable()

        #Start tProc
        #soc.setSelection("product")
        self.soc.tproc.stop()
        self.soc.tproc.start()

        time.sleep(1)

        idec,qdec = self.soc.get_decimated(ch=self.cfg['rch'], length=1022)
        iacc,qacc = self.soc.get_accumulated(ch=self.cfg['rch'], length=accumulatedLength)

        return idec, qdec, iacc, qacc