'''
Personal note: I should take a critical look at the global configuration file. I may want to:
    Add a field for the number of puleses in a run. 
    Possibly add a field to keep track of the readout channels that are enabled for triggering and readout purposes. 
    For some reason, the tof gets shorter as we repeat runs without resetting the readout block. Why is this?! Should we just create a unified readout or run function that always resets the readout block before geting
'''

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
    cfg['loQubitChannel'] int
        The LO channel that goes to the qubit. 
    cfg['loQubitFreq'] : float
        The frequency of the local oscillator channel going to the qubit in MHz. 
    cfg['loQubitPower'] : float
        The power level of the local oscillato4r channel going to the qubit. 
    cfg['loQuitEnabled'] : boolean
        Whether or not the local oscillator channel going to the qubit is enabled.
    cfg['loCavityChannel'] int
        The LO channel that goes to the cavity. 
    cfg['loCavityFreq'] : float
        The frequency of the local oscillator channel going to the cavity in MHz. 
    cfg['loCavityPower'] : float
        The power level of the local oscillator channel going to the cavity. 
    cfg['loCavityEnabled'] : boolean
        Whether or not the local oscillator channel going to the cavity is enabled.
    cfg['maxADCFreq'] : int
        The maximum adc frequency in MHz. This represents the high end of the 2nd nyqist zone. 
    """
    
    def __init__(
        self, 
        qubitOutputChannel = 7,
        cavityOutputChannel = 6, 
        readoutChannel = 0, 
        cavityLOChannel = 0,
        qubitLOChannel = 1,
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
        cavityLOChannel : int, optional
            The local oscillator channel connected to the cavity
        qubitLOChannel : int, optional
            The local oscillator channel connected to the qubit
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
            self.cfg['qgain'] = 32767
            self.cfg['cfreq'] = 500
            self.cfg['cgain'] = 32767
            self.cfg['cReadoutDuration'] = 200
            self.cfg['clkPeriod'] = 2.6
            self.cfg['maxSampBuf'] = 1022
            self.cfg['dacFreqWidth'] = 32
            self.cfg['loQubitChannel'] = qubitLOChannel
            self.cfg['loQubitFreq'] = 0
            self.cfg['loQubitPower'] = 0
            self.cfg['loQubitEnabled'] = False
            self.cfg['loCavityChannel'] = cavityLOChannel
            self.cfg['loCavityFreq'] = 0
            self.cfg['loCavityPower'] = 0
            self.cfg['loCavityEnabled'] = False
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
    
    def setLOFreqQubit(
        self,
        loFreq):
        
        """
        Set the frequency of the local oscillator going to the qubit. The function `initLO()` should be run before this function is used. 
        
        Parameters
        ----------
        
        loFreq : float
            The desired frequency of the local oscillator in MHz. 
        
        """
        self.cfg['loQubitFreq'] = loFreq
        self.synth[self.cfg['loQubitChannel']].frequency = loFreq
    
    def setLOPowerQubit(
        self,
        loPower):
        
        """
        Sets the power level of the local oscillaotr cannel going to the qubit. 
        
        Parameters
        ---------
        loPower : float
            The desired power level of the local oscillator. 
        """
        
        self.cfg['loQubitPower'] = loPower
        self.synth[self.cfg['loQubitChannel']].power = loPower
        
    def enableLOQubit(
        self, 
        enableLO):
        
        """
        Sets whether the local oscillator going to the qubit is enabled or not. 
        
        Parameters
        ----------
        enableLO : boolean
            Whether the external osciallator is enabled. 
        """
        
        self.cfg['loQubitEnabled'] = enableLO
        self.synth[self.cfg['loQubitChannel']].enable = enableIO
        
    def setLOFreqCavity(
        self,
        loFreq):
        
        """
        Set the frequency of the local oscillator going to the cavity. The function `initLO()` should be run before this function is used. 
        
        Parameters
        ----------
        
        loFreq : float
            The desired frequency of the local oscillator in MHz. 
        
        """
        self.cfg['loCavityFreq'] = loFreq
        self.synth[self.cfg['loCavityChannel']].frequency = loFreq
    
    def setLOPowerCavity(
        self,
        loPower):
        
        """
        Sets the power level of the local oscillaotr cannel going to the cavity. 
        
        Parameters
        ---------
        loPower : float
            The desired power level of the local oscillator. 
        """
        
        self.cfg['loCavityPower'] = loPower
        self.synth[self.cfg['loCavityChannel']].power = loPower
        
    def enableLOCavity(
        self, 
        enableLO):
        
        """
        Sets whether the local oscillator going to the cavity is enabled or not. 
        
        Parameters
        ----------
        enableLO : boolean
            Whether the external osciallator is enabled. 
        """
        
        self.cfg['loCavityEnabled'] = enableLO
        self.synth[self.cfg['loCavityChannel']].enable = enableLO
        
    def _writeASM(
        self,
        
        scopeMode = False,

        qubitStartFrequency = None,
        qubitDeltaFrequency = 0,
        qubitStartGain = None,
        qubitDeltaGain = 0,

        cavityStartFrequency = None,
        cavityDeltaFrequency = 0,
        cavityStartGain = None,
        cavityDeltaGain = 0,

        qubitFirstPulseWidthStart = 0,
        qubitFirstPulseWidthDelta = 0,
        qubitSecondPulseWidthStart = 0,
        qubitSecondPulseWidthDelta = 0,

        qubitFirstPulsePhaseStart = 0,
        qubitFirstPulsePhaseDelta = 0,
        qubitSecondPulsePhaseStart = 0,
        qubitSecondPulsePhaseDelta = 0,

        cavityPulseWidthStart = 0,
        cavityPulseWidthDelta = 0,
        
        interPulseDelayStart = 0,
        interPulseDelayDelta = 0,
        preReadoutDelayStart = 0,
        preReadoutDelayDelta = 0,
        postReadoutDelayStart = 0,
        postReadoutDelayDelta = 0,

        frequencyLoopCount = 1,
        gainLoopCount = 1,
        pulseWidthLoopCount = 1,
        delayLoopCount = 1,
        phaseLoopCount = 1,
        iterationLoopCount = 1,

        qEnvelope = False,
        cEnvelope = False,

        qEnvAddr = 0,
        cEnvAddr = 0,

        qToneEnable = False,
        cToneEnable = False,

        tOffset = None,
        tDuration = None,

        readoutChannelEnable = [False,False],
        
        qubitChannel = None,
        cavityChannel = None,
        readoutChannel = None):
        
        """
        Writes ASM code to the timed processor. This function writes a custom ASM code to the timed processor according to the parameters given. It only generates the code and writes it to the processor. It does not start or read the processor. 
        
        Parameters
        ----------
        
        """
        ##############################################################
        # Setup for Default Values Based on Configuration Dictionary #
        ##############################################################
        
        if qubitChannel == None: qubitChannel = self.cfg['qoch']
        if cavityChannel == None: cavityChannel = self.cfg['coch']
        if readoutChannel == None: readoutChannel = self.cfg['rch']
        if tOffset == None: tOffset = self.cfg['tof']
        if tDuration == None: tDuration = self.cfg['trigWidth']
        if qubitStartFrequency == None: qubitStartFrequency = self.cfg['qfreq']
        if qubitStartGain == None: qubitStartGain = self.cfg['qgain']
        if cavityStartFrequency == None: cavityStartFrequency = self.cfg['cfreq']
        if cavityStartGain == None: cavityStartGain = self.cfg['cgain']
        
        #######################################
        # Data Formatting for Timed Processor #
        #######################################

        #Set up the pulse generator mode registers
        qgenMode = 0
        qgenMode += 0 if qToneEnable else 8 #set end value of a pulse to be zero as long as we aren't creating constant tones. 
        qgenMode += 4 if qToneEnable else 0 #Set the signal generator to constant tone if we are creating a tone. 
        qgenMode += 0 if qEnvelope else 1 #Set to product if we are using an envelope. Otherwise, set to dds. 
        qgenMode *= 2 ** 16 #Shift everything 16 bits to the left to or with pulseWidth later. 

        cgenMode = 0
        cgenMode += 0 if cToneEnable else 8 #set end value of a pulse to be zero as long as we aren't creating constant tones. 
        cgenMode += 4 if cToneEnable else 0 #Set the signal generator to constant tone if we are creating a tone. 
        cgenMode += 0 if cEnvelope else 1 #Set to product if we are using an envelope. Otherwise, set to dds.
        cgenMode *= 2 ** 16 #Shift everything 16 bits to the left to or with pulseWidth later. 

        tStart = tOffset
        tEnd = tOffset + tDuration

        tVal = 0
        tVal += 0x8000 if readoutChannelEnable[0] else 0
        tVal += 0x4000 if readoutChannelEnable[1] else 0

        frequencyLoopCount -= 1
        gainLoopCount -= 1
        pulseWidthLoopCount -= 1
        delayLoopCount -= 1
        phaseLoopCount -= 1
        iterationLoopCount -= 1

        qubitStartFrequencyReg = freq2reg(self.soc.fs_dac, qubitStartFrequency, B=32)
        qubitDeltaFrequencyReg = freq2reg(self.soc.fs_dac, qubitDeltaFrequency, B=32)
        cavityStartFrequencyReg = freq2reg(self.soc.fs_dac, cavityStartFrequency, B=32)
        cavityDeltaFrequencyReg = freq2reg(self.soc.fs_dac, cavityDeltaFrequency, B=32)
        
        ################
        # DATA STORAGE #
        ################

        #This data structure is a bit complex, but automates the register assignment and use. Register page within the tproc has a dictionary with values. A second dictionary is
        #automatically created that generates arbitrary addresses for the data. The variables can then be used in the actual ASM code by using the addresses dictionary. 

        vals = []
        signalPage = 0
        delayPage = 1
        loopPage = 2
        triggerPage = 3

        #Starting values for p0 registers
        #These registers hold everything for the signal generators (including some values that are swept)
        vals.append({
            #Frequency and gain to be swept by both qubit pulses
            'qsfreq' : qubitStartFrequencyReg, 
            'qdfreq' : qubitDeltaFrequencyReg, 
            'qsgain' : qubitStartGain, 
            'qdgain' : qubitDeltaGain, 

            #Frequency and gain to be swept by the cavity pulse
            'csfreq' : cavityStartFrequencyReg, 
            'cdfreq' : cavityDeltaFrequencyReg, 
            'csgain' : cavityStartGain, 
            'cdgain' : cavityDeltaGain, 

            #Phase values for the phases of the two qubit pulses. 
            'qfpps' : qubitFirstPulsePhaseStart, 
            'qfppd' : qubitFirstPulsePhaseDelta, 
            'qspps' : qubitSecondPulsePhaseStart, 
            'qsppd' : qubitSecondPulsePhaseDelta, 

            #Qubit and cavity pulse widths to be swept
            'qfpws' : qubitFirstPulseWidthStart, 
            'qfpwd' : qubitFirstPulseWidthDelta,  
            'qspws' : qubitSecondPulseWidthStart, 
            'qspwd' : qubitSecondPulseWidthDelta, 
            'cpws' : cavityPulseWidthStart, 
            'cpwd' : cavityPulseWidthDelta, 

            #Envelope Addresses
            'qenv' : qEnvAddr,
            'cenv' : cEnvAddr,

            #Pulse generator modes
            'qgenMode' : qgenMode,
            'cgenMode' : cgenMode, 

            'qfsettings' : 0, #Will be set inside the ASM
            'qssettings' : 0,
            'csettings' : 0, #Will be set inside the ASM 
        })

        #Starting values for p1 registers
        #These registers hold delay values (including some values that are swept)
        vals.append({
            #Delays
            'ipds' : interPulseDelayStart, 
            'ipdd' : interPulseDelayDelta, 
            'preRDS' : preReadoutDelayStart, 
            'preRDD' : preReadoutDelayDelta, 
            'postRDS' : postReadoutDelayStart, 
            'postRDD' : postReadoutDelayDelta, 
        })

        #Starting values for p2 registers
        #These registers hold the loop counts. 
        vals.append({
            'freqLoop' : frequencyLoopCount,
            'gainLoop' : gainLoopCount,
            'pwLoop' : pulseWidthLoopCount,
            'delLoop' : delayLoopCount,
            'phaseLoop' : phaseLoopCount,
            'iterLoop' : iterationLoopCount
        })

        #Starting values for p3 registers
        #These registers hold trigger data
        vals.append({
            'tstart' : tStart,
            'tend' : tEnd,
            'tval' : tVal, 
        })

        locs = []
        for page in range(len(vals)):
            locs.append({})
            for i, key in enumerate(vals[page]):
                locs[page][key] = i + 1
        
        #############################
        # Start ASM Code Generation #
        #############################
        
        with ASM_Program() as p:

            ########################
            # DATA UPLOAD TO TPROC #
            ########################

            #Write the values to the ASM
            for page in range(len(vals)):
                for key in (locs[page]):
                    p.regwi(page,locs[page][key],vals[page][key], f"Write value to register. Variable: {key} \tValue: {hex(vals[page][key])}\t{bin(vals[page][key])}")

            ###############
            # TPROC LOGIC #
            ###############

            p.synci(1000)

            #Frequency Loop Start
            p.label("FREQ_LOOP")

            #Gain Loop Start
            p.regwi(loopPage,locs[loopPage]['gainLoop'],vals[loopPage]['gainLoop'], f"Reset the gain loop value")
            p.regwi(signalPage,locs[signalPage]['qsgain'],vals[signalPage]['qsgain'], f"Reset the qubit gain value")
            p.regwi(signalPage,locs[signalPage]['csgain'],vals[signalPage]['csgain'], f"Reset the cavity gain value")
            p.label("GAIN_LOOP")

            #Pulse Width Loop Start
            p.regwi(loopPage,locs[loopPage]['pwLoop'],vals[loopPage]['pwLoop'], f"Reset the pulse width loop value")
            p.regwi(signalPage,locs[signalPage]['qfpws'],vals[signalPage]['qfpws'], f"Reset the qubit first pulse width")
            p.regwi(signalPage,locs[signalPage]['qspws'],vals[signalPage]['qspws'], f"Reset the qubit second pulse width")
            p.regwi(signalPage,locs[signalPage]['cpws'],vals[signalPage]['cpws'], f"Reset the cavity pulse width")
            p.label("PW_LOOP")
            p.bitw(signalPage, locs[signalPage]['qfsettings'], locs[signalPage]['qgenMode'], "|", locs[signalPage]['qfpws'], "Combine pulse width and settings to format the settings register.")
            p.bitw(signalPage, locs[signalPage]['qssettings'], locs[signalPage]['qgenMode'], "|", locs[signalPage]['qspws'], "Combine pulse width and settings to format the settings register.")
            p.bitw(signalPage, locs[signalPage]['csettings'], locs[signalPage]['cgenMode'], "|", locs[signalPage]['cpws'], "Combine pulse width and settings to format the settings register.")

            #Delay Loop Start
            p.regwi(loopPage,locs[loopPage]['delLoop'],vals[loopPage]['delLoop'], f"Reset the delay loop value")
            p.regwi(delayPage,locs[delayPage]['ipds'],vals[delayPage]['ipds'], f"Reset the inter-pulse delay width")
            p.regwi(delayPage,locs[delayPage]['preRDS'],vals[delayPage]['preRDS'], f"Reset the pre-readout delay width")
            p.regwi(delayPage,locs[delayPage]['postRDS'],vals[delayPage]['postRDS'], f"Reset the post-readout delay width")
            p.label("DEL_LOOP")

            #Phase Loop Start
            p.regwi(loopPage,locs[loopPage]['phaseLoop'],vals[loopPage]['phaseLoop'], f"Reset the phase loop value")
            p.regwi(signalPage,locs[signalPage]['qfpps'],vals[signalPage]['qfpps'], f"Reset the qubit first pulse phase")
            p.regwi(signalPage,locs[signalPage]['qspps'],vals[signalPage]['qspps'], f"Reset the qubit second pulse phase")
            p.label("PHASE_LOOP")

            #Iteration Loop Start
            p.regwi(loopPage,locs[loopPage]['iterLoop'],vals[loopPage]['iterLoop'], f"Reset the gain loop value")
            p.label("ITER_LOOP")

            ###################
            # ASM PULSE TRAIN # # Section where the actual pulses are generated. This will be looped with whatever changes come from the loops
            ###################

            if scopeMode: #If scopeMode is enabled, simply set the trigger once at the beginning of the pulse train. 
                p.set(0, triggerPage, locs[triggerPage]['tval'], 0, 0, 0, 0, locs[triggerPage]['tstart'])
                p.set(0, triggerPage, 0, 0, 0, 0, 0, locs[triggerPage]['tend'])

            p.set(qubitChannel, signalPage, locs[signalPage]['qsfreq'], locs[signalPage]['qfpps'], locs[signalPage]['qenv'], locs[signalPage]['qsgain'], locs[signalPage]['qfsettings'], 0)

            p.sync(signalPage,locs[signalPage]['qfpws']) #Delay for the pulse width 
            p.sync(delayPage, locs[delayPage]['ipds'], "Inter-pulse delay")

            p.set(qubitChannel, signalPage, locs[signalPage]['qsfreq'], locs[signalPage]['qspps'], locs[signalPage]['qenv'], locs[signalPage]['qsgain'], locs[signalPage]['qssettings'], 0)

            p.sync(signalPage,locs[signalPage]['qspws']) #Delay for the pulse width
            p.sync(delayPage, locs[delayPage]['preRDS'], "Pre-readout delay")

            p.set(cavityChannel, signalPage, locs[signalPage]['csfreq'], 0, locs[signalPage]['cenv'], locs[signalPage]['csgain'], locs[signalPage]['csettings'], 0) #Note, cavity pulse does not have a phase.

            if scopeMode is False: #Only trigger continuously if scopeMode is set to False. This will allow each pulse to be captured. 
                p.set(0, triggerPage, locs[triggerPage]['tval'], 0, 0, 0, 0, locs[triggerPage]['tstart'])
                p.set(0, triggerPage, 0, 0, 0, 0, 0, locs[triggerPage]['tend'])

            p.sync(delayPage, locs[delayPage]['postRDS'], "Post-readout delay")

            #######################
            # END ASM PULSE TRAIN #
            #######################

            #Iteration Loop End
            p.loopnz(loopPage,locs[loopPage]['iterLoop'], "ITER_LOOP")

            #Phase Loop End
            p.math(signalPage, locs[signalPage]['qfpps'], locs[signalPage]['qfpps'], "+", locs[signalPage]['qfppd'], "Increment the qubit first pulse phase")
            p.math(signalPage, locs[signalPage]['qspps'], locs[signalPage]['qspps'], "+", locs[signalPage]['qsppd'], "Increment the qubit second pulse phase") 
            p.loopnz(loopPage,locs[loopPage]['phaseLoop'], "PHASE_LOOP")

            #Delay Loop End
            p.math(delayPage, locs[delayPage]['ipds'], locs[delayPage]['ipds'], "+", locs[delayPage]['ipdd'], "Increment the inter-pulse delay width")
            p.math(delayPage, locs[delayPage]['preRDS'], locs[delayPage]['preRDS'], "+", locs[delayPage]['preRDD'], "Increment the pre-readout delay width") 
            p.math(delayPage, locs[delayPage]['postRDS'], locs[delayPage]['postRDS'], "+", locs[delayPage]['postRDS'], "Increment the post-readout delay width")
            p.loopnz(loopPage,locs[loopPage]['delLoop'], "DEL_LOOP")

            #Pulse Width Loop End
            p.math(signalPage, locs[signalPage]['qfpws'], locs[signalPage]['qfpws'], "+", locs[signalPage]['qfpwd'], "Increment the qubit first pulse width")
            p.math(signalPage, locs[signalPage]['qspws'], locs[signalPage]['qspws'], "+", locs[signalPage]['qspwd'], "Increment the qubit second pulse width") 
            p.math(signalPage, locs[signalPage]['cpws'], locs[signalPage]['cpws'], "+", locs[signalPage]['cpwd'], "Increment the cavity pulse width")
            p.loopnz(loopPage,locs[loopPage]['pwLoop'], "PW_LOOP")

            #Gain Loop End
            p.math(signalPage, locs[signalPage]['qsgain'], locs[signalPage]['qsgain'], "+", locs[signalPage]['qdgain'], "Increment the qubit gain")
            p.math(signalPage, locs[signalPage]['csgain'], locs[signalPage]['csgain'], "+", locs[signalPage]['cdgain'], "Increment the cavity gain") 
            p.loopnz(loopPage,locs[loopPage]['gainLoop'], "GAIN_LOOP")

            #Frequency Loop End
            p.math(signalPage, locs[signalPage]['qsfreq'], locs[signalPage]['qsfreq'], "+", locs[signalPage]['qdfreq'], "Increment the qubit frequency")
            p.math(signalPage, locs[signalPage]['csfreq'], locs[signalPage]['csfreq'], "+", locs[signalPage]['cdfreq'], "Increment the cavity frequency") 
            p.loopnz(loopPage,locs[loopPage]['freqLoop'], "FREQ_LOOP")
        
        ################################
        # Write ASM to Timed Processor #
        ################################
        
        self.soc.tproc.load_asm_program(p)
        
    def readoutChannelSetup(
        self,
        readoutChannel = None,
        readoutFrequency = None,
        readoutWidth = None,
        scopeMode = False,
        startAddress = 0,
        readoutMode = 'product'
    ):
        
        if readoutChannel == None: readoutChannel = self.cfg['rch']
        if readoutFrequency == None: readoutFrequency = self.cfg['cfreq']
        if readoutWidth == None: readoutWidth = self.cfg['cReadoutDuration']
        if scopeMode: readoutWidth = self.cfg['maxSampBuf']
        
        self.soc.readouts[readoutChannel].set_out("product")
        self.soc.readouts[readoutChannel].set_freq(readoutFrequency) 
        self.soc.avg_bufs[readoutChannel].config(address = startAddress, length = readoutWidth) 
        self.soc.avg_bufs[readoutChannel].enable()
        
    def runProcessor(self):
        self.soc.tproc.stop()
        self.soc.tproc.start()
        
    def getSamples(
        self,
        length = None,
        scopeMode = False):
        
        if length == None: length = self.cfg['cReadoutDuration']
        if scopeMode: length = self.cfg['maxSampBuf']
        
        isamp,qsamp = self.soc.get_decimated(self.cfg['rch'], length = length)
        return isamp,qsamp
    
    def getAccumulated(
        self,
        length = 0):
        
        iacc,qacc = soc.get_accumulated(self.cfg['rch'], length=length)
        return iacc,qacc