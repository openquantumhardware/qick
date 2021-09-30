"""
The higher-level driver for the QICK library. Contains an tProc assembly language wrapper class and auxiliary functions.
"""
import numpy as np

fs_adc = 384*8
fs_dac = 384*16
fs_proc=384


def freq2reg(f):
    """
    Converts frequency in MHz to tProc DAC register value.

    :param f: frequency (MHz)
    :type f: float
    :return: Re-formatted frequency
    :rtype: int
    """
    B=32
    df = 2**B/fs_dac
    f_i = f*df
    return int(f_i)

def freq2reg_adc(f):
    """
    Converts frequency in MHz to tProc ADC register value.

    :param f: frequency (MHz)
    :type f: float
    :return: Re-formatted frequency
    :rtype: int
    """
    B=32
    df = 2**B/fs_adc
    f_i = f*df
    return int(f_i)    

def reg2freq(r):
    """
    Converts frequency from format readable by tProc DAC to MHz.

    :param r: frequency in tProc DAC format
    :type r: float
    :return: Re-formatted frequency in MHz
    :rtype: float
    """
    return r*fs_dac/2**32

def reg2freq_adc(r):
    """
    Converts frequency from format readable by tProc ADC to MHz.

    :param r: frequency in tProc ADC format
    :type r: float
    :return: Re-formatted frequency in MHz
    :rtype: float
    """
    return r*fs_adc/2**32

def adcfreq(f):
    """
    Takes a frequency and casts it to an (even) valid ADC DDS frequency.

    :param f: frequency (MHz)
    :type f: float
    :return: Re-formatted frequency
    :rtype: int
    """
    reg=freq2reg_adc(f)
    return reg2freq_adc(reg+(reg%2))

def cycles2us(cycles):
    """
    Converts tProc clock cycles to microseconds.

    :param cycles: Number of tProc clock cycles
    :type cycles: int
    :return: Number of microseconds
    :rtype: float
    """
    return cycles/fs_proc

def us2cycles(us):
    """
    Converts microseconds to integer number of tProc clock cycles.

    :param cycles: Number of microseconds
    :type cycles: float
    :return: Number of tProc clock cycles
    :rtype: int
    """
    return int(us*fs_proc)

def deg2reg(deg):
    """
    Converts degrees into phase register values; numbers greater than 360 will effectively be wrapped.

    :param deg: Number of degrees
    :type deg: float
    :return: Re-formatted number of degrees
    :rtype: int
    """
    return int(deg*2**32//360) % 2**32

def reg2deg(reg):
    """
    Converts phase register values into degrees.

    :param cycles: Re-formatted number of degrees
    :type cycles: int
    :return: Number of degrees
    :rtype: float
    """
    return reg*360/2**32


class QickProgram:
    """
    QickProgram is a Python representation of the QickSoc processor assembly program. It can be used to compile simple assembly programs and also contains macros to help make it easy to configure and schedule pulses.
    """
    #Instruction set for the tproc describing how to automatically generate methods for these instructions
    instructions = {'pushi': {'type':"I", 'bin': 0b00010000, 'fmt': ((0,53),(1,41),(2,36), (3,0)), 'repr': "{0}, ${1}, ${2}, {3}"},
                    'popi':  {'type':"I", 'bin': 0b00010001, 'fmt': ((0,53),(1,41)), 'repr': "{0}, ${1}"},
                    'mathi': {'type':"I", 'bin': 0b00010010, 'fmt': ((0,53),(1,41),(2,36), (3,46), (4, 0)), 'repr': "{0}, ${1}, ${2}, {3}, {4}"},
                    'seti':  {'type':"I", 'bin': 0b00010011, 'fmt': ((1,53),(0,50),(2,36), (3,0)), 'repr': "{0}, {1}, ${2}, {3}"},
                    'synci': {'type':"I", 'bin': 0b00010100, 'fmt': ((0,0),), 'repr': "{0}"},
                    'waiti': {'type':"I", 'bin': 0b00010101, 'fmt': ((0,50),(1,0)), 'repr': "{0}, {1}"},
                    'bitwi': {'type':"I", 'bin': 0b00010110, 'fmt': ((0,53),(3,46), (1,41), (2, 36), (4,0) ), 'repr': "{0}, ${1}, ${2} {3} {4}"},
                    'memri': {'type':"I", 'bin': 0b00010111, 'fmt': ((0,53),(1,41), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'memwi': {'type':"I", 'bin': 0b00011000, 'fmt': ((0,53),(1,31), (2,0)), 'repr': "{0}, ${1}, {2}"},
                    'regwi': {'type':"I", 'bin': 0b00011001, 'fmt': ((0,53),(1,41), (2,0)), 'repr': "{0}, ${1}, {2}"},
                    'setbi': {'type':"I", 'bin': 0b00011010, 'fmt': ((0,53),(1,41), (2,0)), 'repr': "{0}, ${1}, {2}"},

                    'loopnz': {'type':"J1", 'bin': 0b00110000, 'fmt': ((0,53),(1,41), (1,36) , (2,0) ), 'repr': "{0}, ${1}, @{2}"},
                    'end':    {'type':"J1", 'bin': 0b00111111, 'fmt': (), 'repr': ""},

                    'condj':  {'type':"J2", 'bin': 0b00110001, 'fmt': ((0,53), (2,46), (1,36), (3,31), (4,0)), 'repr': "{0}, ${1}, {2}, ${3}, @{4}"},

                    'math':  {'type':"R", 'bin': 0b01010000, 'fmt': ((0,53),(3,46),(1,41),(2,36),(4,31)), 'repr': "{0}, ${1}, ${2}, {3}, ${4}"},
                    'set':  {'type':"R", 'bin': 0b01010001, 'fmt': ((1,53),(0,50),(2,36),(7,31),(3,26),(4,21),(5,16), (6, 11)), 'repr': "{0}, {1}, ${2}, ${3}, ${4}, ${5}, ${6}, ${7}"},
                    'sync': {'type':"R", 'bin': 0b01010010, 'fmt': ((0,53),(1,31)), 'repr': "{0}, ${1}"},
                    'read': {'type':"R", 'bin': 0b01010011, 'fmt': ((1,53),(0,50), (2,46), (3,41)), 'repr': "{0}, {1}, {2} ${3}"},
                    'wait': {'type':"R", 'bin': 0b01010100, 'fmt': ((0,53),(1,31)), 'repr': "{0}, {1}, ${2}"},
                    'bitw': {'type':"R", 'bin': 0b01010101, 'fmt': ((0,53),(1,41),(2,36),(3,46), (4,31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'memr': {'type':"R", 'bin': 0b01010110, 'fmt': ((0,53),(1,41),(2,36)), 'repr': "{0}, ${1}, ${2}"},
                    'memw': {'type':"R", 'bin': 0b01010111, 'fmt': ((0,53),(2,36),(1,31)), 'repr': "{0}, ${1}, ${2}"},
                    'setb': {'type':"R", 'bin': 0b01011000, 'fmt': ((0,53),(2,36),(1,31)), 'repr': "{0}, ${1}, ${2}"}
                    }

    #op codes for math and bitwise operations
    op_codes = {">": 0b0000, ">=": 0b0001, "<": 0b0010, "<=": 0b0011, "==": 0b0100, "!=": 0b0101, 
                "+": 0b1000, "-": 0b1001, "*": 0b1010,
                "&": 0b0000, "|": 0b0001, "^": 0b0010, "~": 0b0011, "<<": 0b0100, ">>": 0b0101,
                "upper": 0b1010, "lower": 0b0101
               }
    
    #To make it easier to configure pulses these special registers are reserved for each channels pulse configuration
    special_registers = [{"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "length":22}, # ch1 - pg 0
                          {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "length":29}, # ch2 - pg 0
                          {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "length":22}, # ch3 - pg 1
                          {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "length":29}, # ch4 - pg 1
                          {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "length":22}, # ch5 - pg 2
                          {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "length":29}, # ch6 - pg 3
                          {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "length":22}, # ch7 - pg 4
                        ]   
    
    #delay in clock cycles between marker channel (ch0) and siggen channels (due to pipeline delay)
    trig_offset=25
    
    def __init__(self, cfg=None):
        """
        Constructor method
        """
        self.prog_list = []
        self.labels = {}
        self.dac_ts = [0]*9 #np.zeros(9,dtype=np.uint16)
        self.channels={ch:{"addr":0, "pulses":{}, "last_pulse":None} for ch in range(1,8)}      
        
    
    def add_pulse(self, ch, name, style, idata=None, qdata=None, length=None):
        """
        Adds a pulse to the pulse library within the program.

        :param ch: DAC channel
        :type ch: int
        :param name: Name of the pulse
        :type name: str
        :param style: Pulse style ("const", "arb", "flat_top", "poly")
        :type style: str
        :param idata: I data Numpy array
        :type idata: array
        :param qdata: Q data Numpy array
        :type qdata: array
        :param length: Length of pulse in FPGA clock ticks
        :type length: int
        """
        if qdata is None and idata is not None:
            qdata=np.zeros(len(idata))
        if idata is None and qdata is not None:
            idata=np.zeros(len(qdata))
        if idata is not None and (len(idata) % 16 !=0 or len(idata) % 16 !=0):
            raise RuntimeError("Error: Pulse length must be integer multiple of 16")
        
        if style=="arb":
            self.channels[ch]["pulses"][name]={"idata":idata, "qdata":qdata, "addr":self.channels[ch]['addr'], "length":len(idata)//16, "style": style}
            self.channels[ch]["addr"]+=len(idata)
        elif style=="flat_top":
            self.channels[ch]["pulses"][name]={"idata":idata, "qdata":qdata, "addr":self.channels[ch]['addr'], "length":length, "style": style}
            self.channels[ch]["addr"]+=len(idata)
        elif style=="const":
            self.channels[ch]["pulses"][name]={"addr":0, "length":length, "style": style}
        elif style=="poly":
            pass
        
    def load_pulses(self, soc):
        """
        Loads pulses that were added using add_pulse into the SoC's signal generator memories.

        :param soc: Qick object
        :type soc: Qick object
        """
        for ch,gen in zip(self.channels.keys(),soc.gens):
            for name,pulse in self.channels[ch]['pulses'].items():
                if pulse['style'] != 'const':
                    idata = pulse['idata'].astype(np.int16)
                    qdata = pulse['qdata'].astype(np.int16)
                    gen.load(xin_i=idata, xin_q=qdata, addr=pulse['addr'])

    def ch_page(self, ch):
        """
        Gets tProc register page associated with channel.

        :param ch: DAC channel
        :type ch: int
        :return: tProc page number
        :rtype: int
        """
        return (ch-1)//2
    
    def sreg(self, ch, name):
        """
        Gets tProc special register number associated with a channel and register name.

        :param ch: DAC channel
        :type ch: int
        :param name: Name of special register ("gain", "freq")
        :type name: str
        :return: tProc special register number
        :rtype: int
        """
        return self.__class__.special_registers[ch-1][name]
        

    def set_pulse_registers (self, ch, freq=None, phase=None, addr=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None, t=None):
        """
        A macro to set (optionally) the pulse parameters including frequency, phase, address of pulse, gain, stdysel, mode register (compiled from length and other flags), outsel, length, and schedule time.

        :param ch: DAC channel
        :type ch: int
        :param freq: Frequency (MHz)
        :type freq: float
        :param phase: Phase (degrees)
        :type phase: float
        :param addr: Address
        :type addr: int
        :param gain: Gain (DAC units)
        :type gain: float
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        :returns:
            - rp (:py:class:`int`) The pulse page
            - r_freq (:py:class:`int`) The pulse phase
            - r_phase (:py:class:`int`) The pulse phase
            - r_addr (:py:class:`int`) The pulse address
            - r_gain (:py:class:`int`) The pulse gain
            - r_mode (:py:class:`int`) The pulse mode
            - r_t (:py:class:`int`) The pulse beginning time
        """
        p=self
        rp=self.ch_page(ch)
        r_freq,r_phase,r_addr, r_gain, r_mode, r_t = p.sreg(ch,'freq'), p.sreg(ch,'phase'), p.sreg(ch,'addr'), p.sreg(ch,'gain'), p.sreg(ch,'mode'), p.sreg(ch,'t')
        if freq is not None: p.safe_regwi (rp, r_freq, freq, f'freq = {reg2freq(freq)} MHz')
        if phase is not None: p.safe_regwi (rp, r_phase, phase, f'phase = {phase}')
        if gain is not None: p.regwi (rp, r_gain, gain, f'gain = {gain}')
        if t is not None and t !='auto': p.regwi (rp, r_t, t, f't = {t}')
        if addr is not None: p.regwi (rp, r_addr, addr, f'addr = {addr}')
        if length is not None or stdysel is not None or phrst is not None or mode is not None or outsel is not None:
            mc=p.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length)
            p.regwi (rp, r_mode, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

        return rp, r_freq,r_phase,r_addr, r_gain, r_mode, r_t
    
    def const_pulse(self, ch, name=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None, t='auto', play=True):
        """
        Schedule and (optionally) play a constant pulse, can autoschedule this based on previous pulses.

        :param ch: DAC channel
        :type ch: int
        :param name: Pulse name
        :type name: str
        :param freq: Frequency (MHz)
        :type freq: float
        :param phase: Phase (degrees)
        :type phase: float
        :param gain: Gain (DAC units)
        :type gain: float
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        """
        p=self
        if name is not None:
            pinfo=self.channels[ch]['pulses'][name]
            length=pinfo['length']
            addr=pinfo['addr']
            self.channels[ch]['last_pulse']=name
        else:
            pinfo=self.channels[ch]['pulses'][self.channels[ch]['last_pulse']]
            addr=None
            
        if length is not None: 
            outsel=1
        else:
            outsel=None
            
        rp, r_freq,r_phase,r_addr, r_gain, r_mode, r_t = p.set_pulse_registers(ch, freq=freq, phase=phase, gain=gain, phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length, t=t)
        
        if play:
            if t is not None:
                if t=='auto':
                    t=p.dac_ts[ch]
                    p.dac_ts[ch]=t+length                   
                p.regwi (rp, r_t, t, f't = {t}')
            p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")        
     
    def arb_pulse(self, ch, name=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None , t= 'auto', play=True):
        """
        Schedule and (optionally) play an arbitrary pulse, can autoschedule this based on previous pulses.

        :param ch: DAC channel
        :type ch: int
        :param name: Pulse name
        :type name: str
        :param freq: Frequency (MHz)
        :type freq: float
        :param phase: Phase (degrees)
        :type phase: float
        :param gain: Gain (DAC units)
        :type gain: float
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        """
        p=self
        addr=None
        if name is not None:
            pinfo=self.channels[ch]['pulses'][name]
            addr=pinfo["addr"]//16
            length=pinfo["length"]
            self.channels[ch]['last_pulse']=name

        rp, r_freq,r_phase,r_addr, r_gain, r_mode, r_t = p.set_pulse_registers(ch, freq=freq, phase=phase, addr=addr, gain=gain, phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length)

        if play:
            if t is not None:
                if t=='auto':
                    t=p.dac_ts[ch]
                if name is None:
                    pinfo=p.channels[ch]['pulses'][p.channels[ch]['last_pulse']]
                p.dac_ts[ch]=t+pinfo['length']
                p.safe_regwi (rp, r_t, t, f't = {t}')
            p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")

    def flat_top_pulse(self, ch, name=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None , t= 'auto', play=True):
        """
        Schedule and (optionally) play an a flattop pulse with arbitrary ramps, can autoschedule based on previous pulses
        To use these pulses one should use add_pulse to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

        :param ch: DAC channel
        :type ch: int
        :param name: Pulse name
        :type name: str
        :param freq: Frequency (MHz)
        :type freq: float
        :param phase: Phase (degrees)
        :type phase: float
        :param gain: Gain (DAC units)
        :type gain: float
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        """
        p=self
        addr=None
        if name is not None:
            pinfo=self.channels[ch]['pulses'][name]
            self.channels[ch]['last_pulse']=name
            length=len(pinfo["idata"])//16//2
            addr=pinfo['addr']//16
            stdysel=1        
        if gain is not None:
            pinfo['gain']=gain
            
        rp, r_freq,r_phase,r_addr, r_gain, r_mode, r_t = p.set_pulse_registers(ch, freq=freq, phase=phase, addr=addr, gain=gain, phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length, t=t)
        p.regwi(rp, p.sreg(ch, "length"), pinfo["length"])
        
        if play:
            if t is not None:
                if t=='auto':
                    t=p.dac_ts[ch]
                if name is None:
                    pinfo=p.channels[ch]['pulses'][p.channels[ch]['last_pulse']]
                
                ramp_length=len(pinfo["idata"])//16//2
                
                p.set_pulse_registers(ch, addr=pinfo["addr"], phase=phase, gain=pinfo['gain'], length=ramp_length, outsel=0, t=t) #play ramp up part of pulse
                p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")
                
                p.set_pulse_registers(ch, addr=pinfo["addr"], phase=phase, gain=pinfo['gain']//2, length=0, outsel=1, t=t) #play ramp up part of pulse
                p.math(rp,r_mode, r_mode, "+", p.sreg(ch, "length"),"+")
                p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")
                p.set_pulse_registers(ch, addr=pinfo["addr"]+ramp_length, phase=phase, gain=pinfo['gain'], length=ramp_length, outsel=0, t=t+ramp_length+pinfo['length']) #play ramp down part of pulse with length delay
                p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")

            p.dac_ts[ch]=t+pinfo['length']+2*ramp_length
              
    def pulse(self, ch, name=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None , t= 'auto', play=True):
        """
        Overall pulse class which will select the correct function to call based on the 'style' parameter of the named pulse.

        :param ch: DAC channel
        :type ch: int
        :param name: Pulse name
        :type name: str
        :param freq: Frequency (MHz)
        :type freq: float
        :param phase: Phase (degrees)
        :type phase: float
        :param gain: Gain (DAC units)
        :type gain: float
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        :return: Dict of pulse styles
        :rtype: dict
        """
        if name is None:
            name=self.channels[ch]['last_pulse']
        
        pinfo=self.channels[ch]['pulses'][name]
            
        f={'const':self.const_pulse,'arb':self.arb_pulse,'flat_top':self.flat_top_pulse}[pinfo['style']]
        
        return f(ch, name=name, freq=freq, phase=phase, gain=gain, phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length , t= t, play=play)
              
    def align(self, chs):
        """
        Sets all of the last times for each channel included in chs to the latest time in any of the channels.
        """
        max_t=max([self.dac_ts[ch] for ch in range(1,9)])
        for ch in range(1,9):
            self.dac_ts[ch]=max_t
            
    def safe_regwi(self, rp, reg, imm, comment=None):
        """
        Due to the way the instructions are setup immediate values can only be 30bits before not loading properly.
        This comes up mostly when trying to regwi values into registers, especially the _frequency_ and _phase_ pulse registers.
        safe_regwi can be used wherever one might use regwi and will detect if the value is >2**30 and if so will break it into two steps, putting in the first 30 bits shifting it over and then adding the last two.

        :param rp: Register page
        :type rp: int
        :param reg: Register number
        :type reg: int
        :param imm: Value of the write
        :type imm: int
        :param comment: Comment associated with the write
        :type comment: str
        """
        if abs(imm) <2**30: 
            self.regwi(rp,reg,imm,comment)
        else:
            self.regwi(rp,reg,imm>>2,comment)
            self.bitwi(rp,reg,reg,"<<",2)
            if imm % 4 !=0:
                self.mathi(rp,reg,reg,"+",imm % 4)
            
    def sync_all(self, t=0):
        """
        Aligns and syncs all channels with additional time t.

        :param t: The time offset in clock ticks
        :type t: int
        """
        max_t=max([self.dac_ts[ch] for ch in range(1,9)])
        if max_t+t>0:
            self.synci(max_t+t)
            self.dac_ts=[0]*len(self.dac_ts) #zeros(len(self.dac_ts),dtype=uint16)

    #should change behavior to only change bits that are specified
    def marker(self, t, t1 = 0, t2 = 0, t3 = 0, t4=0, adc1=0, adc2=0, rp=0, r_out = 31, short=True): 
        """
        Sets the value of the marker bits at time t. This triggers the ADC(s) at a specified time t and also sends trigger values to 4 PMOD pins for syncing a scope trigger.
        Channel 0 of the tProc is connected to triggers/PMODs. E.g. if t3=1 PMOD0_2 goes high.

        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        :param t1: t1 - value of an external pin connected to the PMOD (PMOD0_0)
        :type t1: int
        :param t2: t2 - value of an external pin connected to the PMOD (PMOD0_1)
        :type t2: int
        :param t3: t3 - value of an external pin connected to the PMOD (PMOD0_2)
        :type t3: int
        :param t4: t4 - value of an external pin connected to the PMOD (PMOD0_3)
        :type t4: int
        :param adc1: 1 if ADC channel 0 is triggered; 0 otherwise.
        :type adc1: bool
        :param adc2: 1 if ADC channel 1 is triggered; 0 otherwise.
        :type adc2: bool
        :param rp: Register page
        :type rp: int
        :param r_out: Register number
        :type r_out: int
        :param short: If 1, plays a short marker pulse that is 5 clock ticks long
        :type short: bool
        """
        out= (adc2 << 15) |(adc1 << 14) | (t4 << 3) | (t3 << 2) | (t2 << 1) | (t1 << 0)
        self.regwi (rp, r_out, out, 'out = 0b{out:>016b}')
        self.seti (0, rp, r_out, t, f'ch =0 out = ${r_out} @t = {t}')
        if short:
            self.regwi (rp, r_out, 0, 'out = 0b{out:>016b}')
            self.seti (0, rp, r_out, t+5, f'ch =0 out = ${r_out} @t = {t}')
    
    
    def trigger_adc(self,adc1=0,adc2=0, adc_trig_offset=270, t=0):
        """
        Triggers the ADC(s) at a specified time t+adc_trig_offset.

        :param adc1: 1 if ADC channel 0 is triggered; 0 otherwise.
        :type adc1: bool
        :param adc2: 1 if ADC channel 1 is triggered; 0 otherwise.
        :type adc2: bool
        :param adc_trig_offset: Offset time at which the ADC is triggered (in clock ticks)
        :type adc_trig_offset: int
        :param t: The number of clock ticks at which point the ADC trigger starts
        :type t: int
        """
        out= (adc2 << 15) |(adc1 << 14)
        r_out=31
        self.regwi (0, r_out, out, f'out = 0b{out:>016b}')
        self.seti (0, 0, r_out, t+adc_trig_offset, f'ch =0 out = ${r_out} @t = {t}')
        self.regwi (0, r_out, 0, f'out = 0b{0:>016b}')
        self.seti (0, 0, r_out, t+adc_trig_offset+10, f'ch =0 out = ${r_out} @t = {t}')     
        
    def convert_immediate(self, val):
        """
        Convert the register value to ensure that it is positive and not too large. Throws an error if you ever try to use a value greater than 2**31 as an immediate value.

        :param val: Original register value
        :type val: int
        :return: Converted register value
        :rtype: int
        """
        if val> 2**31:
            raise RuntimeError(f"Immediate values are only 31 bits {val} > 2**31")
        if val <0:
            return 2**31+val
        else:
            return val
        
    def compile_instruction(self,inst, debug = False):
        """
        Converts an assembly instruction into a machine bytecode.

        :param inst: Assembly instruction
        :type inst: dict
        :param debug: If True, debug mode is on
        :type debug: bool
        :return: Compiled instruction in binary
        :rtype: int
        """
        args=list(inst['args'])
        idef = self.__class__.instructions[inst['name']]
        fmt=idef['fmt']

        if debug:
            print (inst)
        
        if idef['type'] =="I":
            args[len(fmt)-1]=self.convert_immediate(args[len(fmt)-1])
                    
        if inst['name'] == 'loopnz': 
            args[-1]=self.labels[args[-1]] #resolve label

        if inst['name'] == 'condj': 
            args[4]=self.labels[args[4]] #resolve label
            args[2]=self.__class__.op_codes[inst['args'][2]] #get binary condtional op code
            
        if inst['name'][:4] == 'math':
            args[3]=self.__class__.op_codes[inst['args'][3]] #get math op code

        if inst['name'][:4] == 'bitw':
            args[3]=self.__class__.op_codes[inst['args'][3]] #get bitwise op code

        if inst['name'][:4] == 'read':
            args[2]=self.__class__.op_codes[inst['args'][2]] #get read op code
            
        mcode = (idef['bin'] << 56)
        #print(inst)
        for field in fmt:
            mcode|=(args[field[0]] << field[1])
            
        if inst['name'] == 'loopnz':
            mcode|= (0b1000 << 46)

        return mcode

    def compile(self, debug=False):
        """
        Compiles program to machine code.

        :param debug: If True, debug mode is on
        :type debug: bool
        :return: List of binary instructions
        :rtype: list
        """
        return [self.compile_instruction(inst,debug=debug) for inst in self.prog_list]
   
    def get_mode_code(self, phrst, stdysel, mode, outsel, length):
        """
        Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: bool
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If 0, it is the last calculated sample of the pulse. If 1, it is a zero value.
        :type stdysel: bool
        :param mode: Selects whether the output is periodic or one-shot. If 0, it is one-shot. If 1, it is periodic.
        :type mode: bool
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If 0, the output is the product of table and DDS. If 1, the output is the DDS only. If 2, the output is from the table for the real part, and zeros for the imaginary part. If 3, the output is always zero.
        :type outsel: int
        :param length: The number of samples in the pulse
        :type length: int
        :return: Compiled mode code in binary
        :rtype: int
        """
        if phrst is None:
            phrst=0
        if stdysel is None:
            stdysel=1
        if mode is None:
            mode=0
        if outsel is None:
            outsel=0
        mc=phrst*0b10000+stdysel*0b01000+mode*0b00100+outsel
        return mc << 16 | length

    def append_instruction(self, name, *args):
        """
        Append instruction to the program list

        :param name: Instruction name
        :type name: str
        :param *args: Instruction arguments
        :type *args: *args object
        """
        self.prog_list.append({'name':name, 'args':args})
                    
    def label(self, name):
        """
        Add line number label to the labels dictionary. This labels the instruction by its position in the program list. The loopz and condj commands use this label information.

        :param name: Instruction name
        :type name: str
        """
        self.labels[name]= len(self.prog_list)

    def comment(self, comment):
        """
        Dummy function used for comments.

        :param comment: Comment
        :type comment: str
        """
        pass

    def __getattr__(self, a):
        """
        Uses instructions dictionary to automatically generate methods for the standard instruction set.

        :param a: Instruction name
        :type a: str
        :return: Instruction arguments
        :rtype: *args object
        """
        if a in self.__class__.instructions:
            return lambda *args: self.append_instruction(a, *args)
        else:
            return object.__getattribute__(self, a)

    def hex(self):
        """
        Returns hex representation of program as string.

        :return: Compiled program in hex format
        :rtype: str
        """
        return "\n".join([format(mc, '#018x') for mc in self.compile()])
    
    def bin(self):
        """
        Returns binary representation of program as string.

        :return: Compiled program in binary format
        :rtype: str
        """
        return "\n".join([format(mc, '#066b') for mc in self.compile()])

    def asm(self):
        """
        Returns assembly representation of program as string, should be compatible with the parse_prog from the parser module.

        :return: asm file
        :rtype: str
        """
        if self.labels =={}:
            max_label_len=0
        else:
            max_label_len = max([len(label) for label in self.labels.keys()])
        lines=[]
        s="\n// Program\n\n"
        for ii, inst in enumerate(self.prog_list):
            #print(inst)
            template=inst['name']+ " " + self.__class__.instructions[inst['name']]['repr'] +";"
            num_args=len(self.__class__.instructions[inst['name']]['fmt'])
            line=" "*(max_label_len+2) + template.format(*inst['args'])
            if len(inst['args']) > num_args:
                line+=" "*(48-len(line)) + "//" + inst['args'][-1]
            lines.append(line)

        for label, jj in self.labels.items():
            lines[jj] = label + ": " + lines[jj][len(label)+2:]
        return s+"\n".join(lines)
    
    def compare_program(self,fname):
        """
        For debugging purposes to compare binary compilation of parse_prog with the compile.

        :param fname: File the comparison program is stored in
        :type fname: str
        :return: True if programs are identical; False otherwise
        :rtype: bool
        """
        match=True
        pns=[int(n,2) for n in self.bin().split('\n')]
        fns=[int(n,2) for ii,n in parse_prog(file=fname,outfmt="bin").items()]
        if len(pns) != len(fns):
            print ("Programs are different lengths")
            return False
        for ii in range(len(pns)):
            if pns[ii] != fns[ii]:
                print (f"Mismatch on line ii: p={pns[ii]}, f={fns[ii]}")
                match=False
        return match

    def __len__(self):
        """
        :return: number of instructions in the program
        :rtype: int
        """
        return len(self.prog_list)
    
    def __repr__(self):
        """
        Print as assembly by default.

        :return: The asm file associated with the class
        :rtype: str
        """
        return self.asm()
    
    def __enter__(self):
        """
        Enter the runtime context related to this object.

        :return: self
        :rtype: self
        """
        return self
    
    def __exit__(self,type, value, traceback):
        """
        Exit the runtime context related to this object.

        :param type: type of error
        :type type: type
        :param value: value of error
        :type value: int
        :param traceback: traceback of error
        :type traceback: str
        """
        pass