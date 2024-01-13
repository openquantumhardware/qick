import logging
import numpy as np
from collections import namedtuple, OrderedDict, defaultdict
from types import SimpleNamespace
from typing import NamedTuple, Union, List, Dict
from abc import ABC, abstractmethod

from .tprocv2_assembler import Assembler
from .qick_asm import AbsQickProgram
from .helpers import to_int, check_bytes

logger = logging.getLogger(__name__)

class QickSpan(NamedTuple):
    loop: str
    span: float
    def _to_sweep(self):
        # convert to sweep
        # helper for math ops and to_int()
        return QickSweep(0, {self.loop:self.span})
    def to_int(self, scale, quantize, parname):
        # this will get called if you use a single QickSpan as a parameter
        return to_int(self._to_sweep(), scale, quantize=quantize, parname=parname)
    def __add__(self, a):
        return self._to_sweep() + a
    def __radd__(self, a):
        return self+a
    def __neg__(self):
        return QickSpan(loop=self.loop, span=-self.span)

# user units, multi-dimension
class QickSweep(NamedTuple):
    start: float
    spans: dict
    def to_int(self, scale, quantize, parname):
        start = to_int(self.start, scale, quantize=quantize, parname=parname)
        spans = {k: to_int(v, scale, quantize=quantize, parname=parname) for k,v in self.spans.items()}
        return QickSweepRaw(par=parname, start=start, spans=spans, quantize=quantize)
    def __add__(self, a):
        newstart = self.start
        newspans = self.spans.copy()
        if isinstance(a, QickSweep):
            newstart += a.start
            for loop, r in a.spans.items():
                newspans[loop] = newspans.get(loop, 0) + r
        elif isinstance(a, QickSpan):
            newspans[a.loop] = newspans.get(a.loop, 0) + a.span
        else:
            newstart += a
        return QickSweep(newstart, newspans)
    def __radd__(self, a):
        return self+a
    def __neg__(self):
        return QickSweep(-self.start, {k:-v for k,v in self.spans.items()})
    def __sub__(self, a):
        return self + (-a)
    def __rsub__(self, a):
        return (-self) + a
    def minval(self):
        spanmin = min([min(r, 0) for r in self.spans.values()])
        return self.start + spanmin
    def maxval(self):
        spanmax = max([max(r, 0) for r in self.spans.values()])
        return self.start + spanmax
    def __gt__(self, a):
        # used when comparing timestamps
        # compares a to the min possible value of the sweep
        return self.minval() > a
    def __lt__(self, a):
        # compares a to the max possible value of the sweep
        return self.maxval() < a

# user units, single dimension
def QickSweep1D(loop, start, end):
    return start + QickSpan(loop, end-start)

class SimpleClass:
    def __repr__(self):
        # based on https://docs.python.org/3/library/types.html#types.SimpleNamespace
        items = (f"{k}={getattr(self,k)!r}" for k in self._fields)
        return "{}({})".format(type(self).__name__, ", ".join(items))

# ASM units, multi-dimension
class QickSweepRaw(SimpleClass):
    _fields = ['par', 'start', 'spans', 'quantize', 'steps']
    def __init__(self, par: str, start: int, spans: Dict[str, int], quantize: int=1, steps: Dict[str, Dict[str, int]]=None):
        self.par = par
        self.start = start
        self.spans = spans
        self.quantize = quantize
        self.steps = steps

    def to_steps(self, loops):
        self.steps = {}
        for loop, r in self.spans.items():
            nSteps = loops[loop]
            stepsize = int(self.quantize * np.trunc(r/(nSteps-1)/self.quantize))
            if stepsize==0:
                raise RuntimeError("requested sweep step is smaller than the available resolution: span=%d, steps=%d"%(r, nSteps-1))
            self.steps[loop] = {"step":stepsize, "span":stepsize*(nSteps-1)}

    def __floordiv__(self, a):
        # used when scaling parameters (e.g. flat_top segment gain)
        # this will only happen before steps have been defined
        if not all([x%a==0 for x in [self.start, self.quantize] + list(self.spans.values())]):
            raise RuntimeError("cannot divide %s evenly by %d"%(str(self), a))
        spans = {k:v//a for k,v in self.spans.items()}
        return QickSweepRaw(self.par, self.start//a, spans, self.quantize//a)
    def __mod__(self, a):
        # used in freq2reg etc.
        # do nothing - mod will be applied when compiling the WaveReg
        return self
    def __truediv__(self, a):
        # this is used to convert duration to us
        # this will only happen after steps have been defined
        spans = {k:v['span']/a for k,v in self.steps.items()}
        return QickSweep(self.start/a, spans)
    def minval(self):
        # used to check for out-of-range values
        spanmin = min([min(r, 0) for r in self.spans.values()])
        return self.start + spanmin
    def maxval(self):
        spanmax = max([max(r, 0) for r in self.spans.values()])
        return self.start + spanmax

class WaveReg(SimpleClass):
    widths = [4, 4, 3, 4, 4, 2]
    _fields = ['freq', 'phase', 'env', 'gain', 'length', 'conf']
    def __init__(self, freq: Union[int, QickSweepRaw], phase: Union[int, QickSweepRaw], env: int, gain: Union[int, QickSweepRaw], length: Union[int, QickSweepRaw], conf: int):
        self.freq = freq
        self.phase = phase
        self.env = env
        self.gain = gain
        self.length = length
        self.conf = conf
    def compile(self):
        params = [getattr(self, f) for f in self._fields]
        # if a parameter is swept, the start value is what we write to the wave memory
        startvals = [x.start if isinstance(x, QickSweepRaw) else x for x in params]
        # convert to bytes to get a 168-bit word (this is what actually ends up in the wave memory)
        # same parameters (freq, phase) are expected to wrap, we do that here
        rawbytes = b''.join([int(i%2**(8*w)).to_bytes(length=w, byteorder='little', signed=False) for i, w in zip(startvals, self.widths)])
        # pad with zero bytes to get the 256-bit word (this is the format for DMA transfers)
        paddedbytes = rawbytes[:11]+bytes(1)+rawbytes[11:]+bytes(10)
        # pack into a numpy array
        return np.frombuffer(paddedbytes, dtype=np.int32)
    def sweeps(self):
        return [r for r in [self.freq, self.phase, self.gain, self.length] if isinstance(r, QickSweepRaw)]
    def fill_steps(self, loops):
        for sweep in self.sweeps():
            sweep.to_steps(loops)

class QickRegister(SimpleClass):
    _fields = ['name', 'addr', 'sweep']
    def __init__(self, name: str=None, addr: int=None, sweep: QickSweep=None):
        self.name = name
        self.addr = addr
        self.sweep = sweep

class Macro(SimpleNamespace):
    def translate(self, prog):
        # translate to ASM and push to prog_list
        insts = self.expand(prog)
        for inst in insts:
            inst.translate(prog)

    def expand(self, prog):
        # expand to other instructions
        # TODO: raise exception if this is undefined and translate is not overriden?
        pass

    def preprocess(self, prog):
        # allocate registers and stuff?
        pass

    def convert_time(self, prog, t, name):
        # helper method, to be used in preprocess()
        # if the time value is swept, we need to allocate a register and initialize it at the beginning of the program
        t_reg = prog.us2cycles(t)
        if isinstance(t_reg, QickSweepRaw):
            t_reg = prog.new_reg(sweep=t_reg)
            t_reg.sweep.to_steps(prog.loop_dict)
        if not hasattr(self, "t_reg"):
            self.t_reg = {}
        self.t_reg[name] = t_reg

    def set_timereg(self, prog, name):
        # helper method, to be used in expand()
        t_reg = self.t_reg[name]
        if isinstance(t_reg, QickRegister):
            return AsmInst(inst={'CMD':"REG_WR", 'DST':'s14' ,'SRC':'op' ,'OP':f'r{t_reg.addr}'}, addr_inc=1)
        else:
            return SetReg(reg='s14', val=t_reg)

class AsmInst(Macro):
    def translate(self, prog):
        prog._add_asm(self.inst.copy(), self.addr_inc)

class Label(Macro):
    def translate(self, prog):
        prog._add_label(self.label)

class End(Macro):
    def expand(self, prog):
        return [AsmInst(inst={'CMD':'JUMP', 'ADDR':f'&{prog.p_addr}'}, addr_inc=1)]

class LoadWave(Macro):
    def expand(self, prog):
        addr = prog.wave2idx[self.name]
        return [AsmInst(inst={'CMD':'REG_WR', 'DST':'r_wave', 'SRC':'wmem', 'ADDR':f'&{addr}'}, addr_inc=1)]

class WriteWave(Macro):
    def expand(self, prog):
        addr = prog.wave2idx[self.name]
        return [AsmInst(inst={'CMD':'WMEM_WR', 'DST':f'&{addr}'}, addr_inc=1)]

class IncrementWave(Macro):
    def expand(self, prog):
        insts = []

        op = '+'
        #op = '-' if step<0 else '+'
        #step = abs(step)
        iPar = WaveReg._fields.index(self.par)

        # immediate arguments to operations must be 24-bit
        if check_bytes(self.step, 3):
            insts.append(IncReg(reg=f'w{iPar}', val=self.step))
        else:
            # constrain the value to signed 32-bit
            steptrunc = np.int64(self.step).astype(np.int32)
            tmpreg = prog.get_reg("scratch", lazy_init=True)
            insts.append(SetReg(reg=f'r{tmpreg.addr}', val=steptrunc))
            insts.append(AsmInst(inst={'CMD':'REG_WR', 'DST':f'w{iPar}','SRC':'op','OP':f'w{iPar} {op} r{tmpreg.addr}'}, addr_inc=1))

        return insts

class Wait(Macro):
    # t, auto, gens, ros (last two only defined if auto=True)
    def preprocess(self, prog):
        if self.auto:
            max_t = prog.get_max_timestamp(gens=self.gens, ros=self.ros)
            self.convert_time(prog, max_t + self.t, "t")
        else:
            self.convert_time(prog, self.t, "t")
    def expand(self, prog):
        t_reg = self.t_reg["t"]
        if isinstance(t_reg, QickRegister):
            raise RuntimeError("WAIT can only take a scalar argument, not a sweep")
        else:
            return [AsmInst(inst={'CMD':'WAIT', 'ADDR':f'&{prog.p_addr + 1}', 'TIME': f'{t_reg}'}, addr_inc=2)]

class Sync(Macro):
    # t, auto, gens, ros (last two only defined if auto=True)
    def preprocess(self, prog):
        if self.auto:
            max_t = prog.get_max_timestamp(gens=self.gens, ros=self.ros)
            self.convert_time(prog, max_t+self.t, "t")
            prog.reset_timestamps()
        else:
            self.convert_time(prog, self.t, "t")
            prog.decrement_timestamps(self.t)
    def expand(self, prog):
        t_reg = self.t_reg["t"]
        if isinstance(t_reg, QickRegister):
            return [AsmInst(inst={'CMD':'TIME', 'DST':'inc_ref', 'SRC':f'r{t_reg.addr}'}, addr_inc=1)]
        else:
            return [AsmInst(inst={'CMD':'TIME', 'DST':'inc_ref', 'LIT':f'{t_reg}'}, addr_inc=1)]

class Pulse(Macro):
    # ch, name, t
    def preprocess(self, prog):
        pulse = prog.pulses[self.name]
        pulse_length = sum([prog.waves[w].length/prog.soccfg['gens'][self.ch]['f_fabric'] for w in pulse]) # in us
        ts = prog.get_timestamp(gen_ch=self.ch)
        t = self.t
        if t == 'auto':
            t = ts #TODO: 0?
            prog.set_timestamp(t + pulse_length, gen_ch=self.ch)
        else:
            if t<ts:
                print("warning: pulse time %d appears to conflict with previous pulse ending at %f?"%(t, ts))
                prog.set_timestamp(ts + pulse_length, gen_ch=self.ch)
            else:
                prog.set_timestamp(t + pulse_length, gen_ch=self.ch)
        self.convert_time(prog, t, "t")

    def expand(self, prog):
        insts = []
        pulse = prog.pulses[self.name]
        tproc_ch = prog.soccfg['gens'][self.ch]['tproc_ch']
        insts.append(self.set_timereg(prog, "t"))
        for wavename in pulse:
            idx = prog.wave2idx[wavename]
            insts.append(AsmInst(inst={'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx)}, addr_inc=1))
        return insts

class Trigger(Macro):
    # ros, pins, t, width
    #TODO: add DDR4+MR buffers, ADC offset
    def preprocess(self, prog):
        if self.width is None: self.width = prog.cycles2us(10)
        if self.ros is None: self.ros = []
        if self.pins is None: self.pins = []
        self.outdict = defaultdict(int)
        self.trigset = set()

        #treg = self.us2cycles(t)
        self.convert_time(prog, self.t, "t_start")
        self.convert_time(prog, self.t+self.width, "t_end")

        for ro in self.ros:
            rocfg = prog.soccfg['readouts'][ro]
            if rocfg['trigger_type'] == 'dport':
                self.outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
            else:
                self.trigset.add(rocfg['trigger_port'])
            ts = prog.get_timestamp(ro_ch=ro)
            if self.t < ts: print("Readout time %d appears to conflict with previous readout ending at %f?"%(self.t, ts))
            ro_length = prog.ro_chs[ro]['length']
            ro_length /= prog.soccfg['readouts'][ro]['f_fabric']
            prog.set_timestamp(self.t + ro_length, ro_ch=ro)
            # update trigger count for this readout
            prog.ro_chs[ro]['trigs'] += 1
        for pin in self.pins:
            porttype, portnum, pinnum, _ = prog.soccfg['tprocs'][0]['output_pins'][pin]
            if porttype == 'dport':
                self.outdict[portnum] |= (1 << pinnum)
            else:
                self.trigset.add(portnum)

    def expand(self, prog):
        insts = []
        if self.outdict:
            insts.append(self.set_timereg(prog, "t_start"))
            for outport, out in self.outdict.items():
                insts.append(AsmInst(inst={'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':str(out)}, addr_inc=1))
            insts.append(self.set_timereg(prog, "t_end"))
            for outport, out in self.outdict.items():
                insts.append(AsmInst(inst={'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':'0'}, addr_inc=1))
        if self.trigset:
            t_start = self.t_reg["t_start"]
            t_end = self.t_reg["t_end"]
            if isinstance(t_start, QickSweepRaw) or isinstance(t_end, QickSweepRaw):
                raise RuntimeError("trig ports do not support sweeps for start time or duration")
            for outport in self.trigset:
                insts.append(AsmInst(inst={'CMD':'TRIG', 'SRC':'set', 'DST':str(outport), 'TIME':str(t_start)}, addr_inc=1))
                insts.append(AsmInst(inst={'CMD':'TRIG', 'SRC':'clr', 'DST':str(outport), 'TIME':str(t_end)}, addr_inc=1))
        return insts

class StartLoop(Macro):
    def expand(self, prog):
        insts = []
        prog.loop_stack.append(self.name)
        # initialize the loop counter to zero and set the loop label
        insts.append(SetReg(reg='r%d'%(self.reg.addr), val=self.n))
        insts.append(Label(label=self.name.upper()))
        return insts

class EndLoop(Macro):
    def expand(self, prog):
        insts = []

        lname = prog.loop_stack.pop()

        # check for wave sweeps
        wave_sweeps = []
        for wname, wave in prog.waves.items():
            spans_to_apply = []
            for sweep in wave.sweeps():
                if lname in sweep.steps:
                    spans_to_apply.append((sweep.par, sweep.steps[lname]))
            if spans_to_apply:
                wave_sweeps.append((wname, spans_to_apply))

        # check for register sweeps
        reg_sweeps = []
        for reg in prog.user_reg_dict.values():
            if reg.sweep is not None and lname in reg.sweep.spans:
                reg_sweeps.append((reg, reg.sweep.steps[lname]))

        # increment waves and registers
        for wname, spans_to_apply in wave_sweeps:
            insts.append(LoadWave(name=wname))
            for par, steps in spans_to_apply:
                insts.append(IncrementWave(par=par, step=steps['step']))
            insts.append(WriteWave(name=wname))
        for reg, steps in reg_sweeps:
            insts.append(IncReg(reg=f'r{reg.addr}', val=steps['step']))

        # increment and test the loop counter
        lreg = prog.user_reg_dict[lname]
        insts.append(AsmInst(inst={'CMD':'REG_WR', 'DST':f'r{lreg.addr}', 'SRC':'op', 'OP':f'r{lreg.addr}-#1', 'UF':'1'}, addr_inc=1))
        insts.append(AsmInst(inst={'CMD':'JUMP', 'LABEL':lname.upper(), 'IF':'NZ'}, addr_inc=1))

        # if we swept a parameter, we should restore it to its original value
        for wname, spans_to_apply in wave_sweeps:
            insts.append(LoadWave(name=wname))
            for par, steps in spans_to_apply:
                insts.append(IncrementWave(par=par, step=-steps['step']-steps['span']))
            insts.append(WriteWave(name=wname))
        for reg, steps in reg_sweeps:
            insts.append(IncReg(reg=f'r{reg.addr}', val=-steps['step']-steps['span']))

        return insts

class SetReg(Macro):
    # reg, val
    def expand(self, prog):
        return [AsmInst(inst={'CMD':"REG_WR", 'DST':self.reg,'SRC':'imm','LIT': "%d"%(self.val)}, addr_inc=1)]

class IncReg(Macro):
    # reg, val
    def expand(self, prog):
        return [AsmInst(inst={'CMD':"REG_WR", 'DST':self.reg,'SRC':'op','OP': '%s + #%d'%(self.reg, self.val)}, addr_inc=1)]

class AbsRegisterManager(ABC):
    """Generic class for managing registers that will be written to a tProc-controlled block (signal generator or readout).
    """
    def __init__(self, prog, tproc_ch, ch_name):
        self.prog = prog
        # the tProc output channel controlled by this manager
        self.tproc_ch = tproc_ch
        # the name of this block (for messages)
        self.ch_name = ch_name

    def add_pulse(self, name, kwargs):
        """Set pulse parameters.
        This is called by QickProgram.set_pulse_registers().

        Parameters
        ----------
        kwargs : dict
            Parameter values

        """
        # check the final param set for validity
        self.check_params(kwargs)
        waves = self.params2pulse(kwargs)
        pulse = []

        # register the pulse and waves with the program
        self.prog.pulses[name] = pulse
        for iWave, wave in enumerate(waves):
            wavename = "%s_wave%d" % (name, iWave)
            self.prog.add_wave(wavename, wave)
            pulse.append(wavename)

    @abstractmethod
    def check_params(self, params):
        ...

    @abstractmethod
    def params2pulse(self, params):
        ...

class AbsGenManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = {}
    PARAMS_OPTIONAL = {}

    def __init__(self, prog, gen_ch):
        self.ch = gen_ch
        self.gencfg = prog.soccfg['gens'][gen_ch]
        tproc_ch = self.gencfg['tproc_ch']
        super().__init__(prog, tproc_ch, "generator %d"%(gen_ch))
        self.samps_per_clk = self.gencfg['samps_per_clk']

        # dictionary of defined pulse envelopes
        self.envelopes = prog.envelopes[gen_ch]
        # type and max absolute value for envelopes
        self.env_dtype = np.int16

        self.addr = 0

    def check_params(self, params):
        """Check whether the parameters defined for a pulse are supported and sufficient for this generator and pulse type.
        Raise an exception if there is a problem.

        Parameters
        ----------
        params : dict
            Parameter values

        """
        style = params['style']
        required = set(self.PARAMS_REQUIRED[style])
        allowed = required | set(self.PARAMS_OPTIONAL[style])
        defined = params.keys()
        if required - defined:
            raise RuntimeError("missing required pulse parameter(s)", required - defined)
        if defined - allowed:
            raise RuntimeError("unsupported pulse parameter(s)", defined - allowed)

    def add_envelope(self, name, idata, qdata):
        """Add a waveform to the list of envelope waveforms available for this channel.
        The I and Q arrays must be of equal length, and the length must be divisible by the samples-per-clock of this generator.

        Parameters
        ----------
        name : str
            Name for this waveform
        idata : array
            I values for this waveform
        qdata : array
            Q values for this waveform

        """
        length = [len(d) for d in [idata, qdata] if d is not None]
        if len(length)==0:
            raise RuntimeError("Error: no data argument was supplied")
        # if both arrays were defined, they must be the same length
        if len(length)>1 and length[0]!=length[1]:
            raise RuntimeError("Error: I and Q pulse lengths must be equal")
        length = length[0]

        if (length % self.samps_per_clk) != 0:
            raise RuntimeError("Error: pulse lengths must be an integer multiple of %d"%(self.samps_per_clk))
        data = np.zeros((length, 2), dtype=self.env_dtype)

        for i, d in enumerate([idata, qdata]):
            if d is not None:
                # range check
                if np.max(np.abs(d)) > self.gencfg['maxv']:
                    raise ValueError("max abs val of envelope (%d) exceeds limit (%d)" % (np.max(np.abs(d)), self.gencfg['maxv']))
                # copy data
                data[:,i] = np.round(d)

        self.envelopes[name] = {"data": data, "addr": self.addr}
        self.addr += length

    def cfg2reg(self, outsel, mode, stdysel, phrst):
        """Creates generator config register value, by setting flags.

        Parameters
        ----------
        outsel : str
        Selects the output source. The output is complex. Tables define envelopes for I and Q.
        The default is "product".

        * If "product", the output is the product of table and DDS.

        * If "dds", the output is the DDS only.

        * If "input", the output is from the table for the real part, and zeros for the imaginary part.

        * If "zero", the output is always zero.

        mode : str
        Selects whether the output is "oneshot" or "periodic". The default is "oneshot".

        stdysel : str
        Selects what value is output continuously by the signal generator after the generation of a pulse.
        The default is "zero".

        phrst : int
        If 1, it resets the phase coherent accumulator. The default is 0.

        * If "last", it is the last calculated sample of the pulse.

        * If "zero", it is a zero value.

        Returns
        -------
        int
            Compiled mode code in binary
        """
        if outsel is None: outsel = "product"
        if mode is None: mode = "oneshot"
        if stdysel is None: stdysel = "zero"
        if phrst is None: phrst = 0
        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        stdysel_reg = {"last": 0, "zero": 1}[stdysel]
        return phrst*0b010000 + stdysel_reg*0b01000 + mode_reg*0b00100 + outsel_reg

class FullSpeedGenManager(AbsGenManager):
    """Manager for the full-speed (non-interpolated, non-muxed) signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'envelope'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'envelope']}
    PARAMS_OPTIONAL = {'const': ['ro_ch', 'phrst', 'stdysel', 'mode'],
            'arb': ['ro_ch', 'phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['ro_ch', 'phrst', 'stdysel']}

    def params2wave(self, freqreg, phasereg, gainreg, lenreg, env=0, mode=None, outsel=None, stdysel=None, phrst=None):
        confreg = self.cfg2reg(outsel=outsel, mode=mode, stdysel=stdysel, phrst=phrst)
        if isinstance(lenreg, QickSweepRaw):
            if lenreg.maxval() >= 2**16 or lenreg.minval() < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (lenreg))
        else:
            if lenreg >= 2**16 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (lenreg))
        wavereg = WaveReg(freqreg, phasereg, env, gainreg, lenreg, confreg)
        return wavereg

    def params2pulse(self, par):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_pulse to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the waveform is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length waveform with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        par : dict
            Pulse parameters
        """
        w = {k:par.get(k) for k in ['phrst', 'stdysel']}
        w['freqreg'] = self.prog.freq2reg(gen_ch=self.ch, f=par['freq'], ro_ch=par.get('ro_ch'))
        w['phasereg'] = self.prog.deg2reg(gen_ch=self.ch, deg=par['phase'])
        if par['style']=='flat_top':
            # since the flat segment is played at half gain, the ramps should have even gain
            w['gainreg'] = to_int(par['gain'], self.gencfg['maxv']*self.gencfg['maxv_scale'], parname='gain', quantize=2)
        else:
            w['gainreg'] = to_int(par['gain'], self.gencfg['maxv']*self.gencfg['maxv_scale'], parname='gain')

        if 'envelope' in par:
            env = self.envelopes[par['envelope']]
            env_length = env['data'].shape[0] // self.samps_per_clk
            env_addr = env['addr'] // self.samps_per_clk

        waves = []
        if par['style']=='const':
            w.update({k:par.get(k) for k in ['mode']})
            w['outsel'] = 'dds'
            w['lenreg'] = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])
            waves.append(self.params2wave(**w))
        elif par['style']=='arb':
            w.update({k:par.get(k) for k in ['mode', 'outsel']})
            w['env'] = env_addr
            w['lenreg'] = env_length
            waves.append(self.params2wave(**w))
        elif par['style']=='flat_top':
            w['mode'] = 'oneshot'
            if env_length % 2 != 0:
                logger.warning("Envelope length %d is an odd number of fabric cycles.\n"
                "The middle cycle of the envelope will not be used.\n"
                "If this is a problem, you could use the even_length parameter for your envelope."%(env_length))
            w1 = w.copy()
            w1['env'] = env_addr
            w1['outsel'] = 'product'
            w1['lenreg'] = env_length//2
            w2 = w.copy()
            w2['outsel'] = 'dds'
            w2['lenreg'] = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])
            w2['gainreg'] = w2['gainreg']//2
            w3 = w1.copy()
            w3['env'] = env_addr + (env_length+1)//2
            waves.append(self.params2wave(**w1))
            waves.append(self.params2wave(**w2))
            waves.append(self.params2wave(**w3))

        return waves

class QickProgramV2(AbsQickProgram):
    gentypes = {'axis_signal_gen_v4': FullSpeedGenManager,
                'axis_signal_gen_v5': FullSpeedGenManager,
                'axis_signal_gen_v6': FullSpeedGenManager}

    def __init__(self, soccfg):
        super().__init__(soccfg)

        # user commands can add macros and/or waveforms+pulses to the program
        # macros are user commands
        # preprocessing: allocate registers, convert sweeps from physical units to ASM values, define the timeline
        # preprocessing allows us to initialize registers at the start of the program
        # expanding/translating: convert macros to lower-level macros and then to ASM

        # to convert sweeps from user values to ASM, we need:
        # loop lengths
        # the timeline

        # high-level instruction list
        self._init_macros()

        # low-level instruction list
        self._init_asm()


    def _init_macros(self):
        self.macro_list = []
        self.user_reg_dict = {}  # look up dict for registers defined in each generator channel
        self._user_regs = []  # addr of all user defined registers

        self.loop_dict = {}
        self.loop_stack = []

        # waveforms consist of initial parameters (to be written to the wave memory) and sweeps (to be applied when looping)
        self.waves = OrderedDict()
        self.wave2idx = {}

        # pulses are software constructs, each is a set of 1 or more waveforms
        self.pulses = {}

        self._gen_mgrs = [self.gentypes[ch['type']](self, iCh) for iCh, ch in enumerate(self.soccfg['gens'])]

    def _init_asm(self):
        self.prog_list = []
        self.labels = {'s15': 's15'} # register 15 predefinition

        # address in program memory
        self.p_addr = 1
        # line number
        self.line = 1
        # first instruction is always NOP, so both counters start at 1

    def _compile_prog(self):
        _, p_mem = Assembler.list2bin(self.prog_list, self.labels)
        return p_mem

    def _compile_waves(self):
        if self.waves:
            return np.stack([w.compile() for w in self.waves.values()])
        else:
            return np.zeros((0,8), dtype=np.int32)

    def compile(self):
        self._expand_macros()
        binprog = {}
        binprog['pmem'] = self._compile_prog()
        binprog['wmem'] = self._compile_waves()
        return binprog

    def _expand_macros(self):
        # we need the loop names and counts first, to convert sweeps to steps
        # allocate the loop register, set a name if not defined, add the loop to the program's loop dict
        for macro in self.macro_list:
            if isinstance(macro, StartLoop):
                if macro.name is None: macro.name = f"loop_{len(self.loop_dict)}"
                self.loop_dict[macro.name] = macro.n
                macro.reg = self.new_reg(name=macro.name)
        # compute step sizes for sweeps
        for w in self.waves.values():
            w.fill_steps(self.loop_dict)
        for i, macro in enumerate(self.macro_list):
            macro.preprocess(self)
        self._init_asm()
        # initialize sweep registers
        for reg in self.user_reg_dict.values():
            if reg.sweep is not None:
                self._add_asm({'CMD':'REG_WR', 'DST':f'r{reg.addr}','SRC':'imm','LIT':f'{reg.sweep.start}'})
        for i, macro in enumerate(self.macro_list):
            macro.translate(self)

    def _add_asm(self, inst, addr_inc=1):
        inst = inst.copy()
        inst['P_ADDR'] = self.p_addr
        inst['LINE'] = self.line
        self.p_addr += addr_inc
        self.line += 1
        self.prog_list.append(inst)

    def _add_label(self, label):
        self.labels[label] = '&%d' % (len(self.prog_list)+1)

    def asm(self):
        self._expand_macros()
        asm = Assembler.list2asm(self.prog_list, self.labels)
        return asm

    def config_all(self, soc, load_pulses=True):
        # compile() first, because envelopes might be declared in a make_program() inside _expand_macros()
        binprog = self.compile()
        soc.tproc.stop()
        super().config_all(soc, load_pulses=load_pulses)
        soc.load_bin_program(binprog)

    # natural-units wrappers for methods of AbsQickProgram

    def add_gauss(self, ch, name, sigma, length, maxv=None, even_length=False):
        """Adds a Gaussian pulse to the waveform library.
        The pulse will peak at length/2.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        sigma : float
            Standard deviation of the Gaussian (in units of us)
        length : float
            Total pulse length (in units of us)
        maxv : float
            Value at the peak (if None, the max value for this generator will be used)
        even_length : bool
            Round the envelope length to an even number of fabric clock cycles.
            This is useful for flat_top pulses, where the envelope gets split into two halves.
        """
        if even_length:
            lenreg = 2*self.us2cycles(gen_ch=ch, us=length/2)
        else:
            lenreg = self.us2cycles(gen_ch=ch, us=length)
        sigreg = self.us2cycles(gen_ch=ch, us=sigma)
        super().add_gauss(ch, name, sigreg, lenreg, maxv)

    def declare_readout(self, ch, length, freq=None, sel='product', gen_ch=None):
        lenreg = self.us2cycles(ro_ch=ch, us=length)
        super().declare_readout(ch, lenreg, freq, sel, gen_ch)

    # waves+pulses

    def add_wave(self, name, wave):
        self.waves[name] = wave
        self.wave2idx[name] = len(self.waves)-1

    def add_pulse(self, ch, name, **kwargs):
        self._gen_mgrs[ch].add_pulse(name, kwargs)

    # register management

    def new_reg(self, addr: int = None, name: str = None, sweep: QickSweepRaw = None):
        """ Declare a new data register.

        :param addr: address of the new register. If None, the function will automatically try to find the next
            available address.
        :param name: name of the new register. Optional.
        :return: QickRegister
        """
        if addr is None:
            addr = 0
            while addr in self._user_regs:
                addr += 1
            if addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise RuntimeError(f"data registers are full.")
        else:
            if addr < 0 or addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise ValueError(f"register address must be smaller than {self.soccfg['tprocs'][0]['dreg_qty']}")
            if addr in self._user_regs:
                raise ValueError(f"register at address {addr} is already occupied.")
        self._user_regs.append(addr)

        if name is None:
            name = f"reg_{addr}"
        if name in self.user_reg_dict.keys():
            raise NameError(f"register name '{name}' already exists")

        reg = QickRegister(addr=addr, name=name, sweep=sweep)
        self.user_reg_dict[name] = reg

        return reg
    
    def get_reg(self, name, lazy_init=False):
        """Get a previously defined register.
        """
        if lazy_init and name not in self.user_reg_dict:
            self.new_reg(name=name)
        return self.user_reg_dict[name]

    # start of ASM code

    # low-level macros

    def label(self, label):
        """apply the specified label to the next instruction
        """
        self.macro_list.append(Label(label=label))

    def end(self):
        self.macro_list.append(End())

    def set_ext_counter(self, addr=1, val=0):
        # initialize the data counter to zero
        reg = {1:'s12', 2:'s13'}[addr]
        self.macro_list.append(SetReg(reg=reg, val=val))

    def inc_ext_counter(self, addr=1, val=1):
        # increment the data counter
        reg = {1:'s12', 2:'s13'}[addr]
        self.macro_list.append(IncReg(reg=reg, val=val))
    
    # control statements

    def open_loop(self, n, name=None):
        self.macro_list.append(StartLoop(n=n, name=name))
    
    def close_loop(self):
        self.macro_list.append(EndLoop())

    # timeline management

    def wait(self, t):
        self.macro_list.append(Wait(t=t, auto=False))

    def sync(self, t):
        self.macro_list.append(Sync(t=t, auto=False))

    def sync_all(self, t=0, gens=True, ros=True):
        self.macro_list.append(Sync(t=t, auto=True, gens=gens, ros=ros))

    def wait_all(self, t=0, gens=False, ros=True):
        self.macro_list.append(Wait(t=t, auto=True, gens=gens, ros=ros))

    # pulses and triggers

    def pulse(self, ch, name, t=0):
        self.macro_list.append(Pulse(ch=ch, name=name, t=t))

    def trigger(self, ros=None, pins=None, t=0, width=None):
        self.macro_list.append(Trigger(ros=ros, pins=pins, t=t, width=width))

