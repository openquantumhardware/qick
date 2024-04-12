import logging
import numpy as np
import textwrap
from collections import namedtuple, OrderedDict, defaultdict
from collections.abc import Mapping
from types import SimpleNamespace
from typing import NamedTuple, Union, List, Dict, Tuple
from abc import ABC, abstractmethod
from fractions import Fraction

from .tprocv2_assembler import Assembler
from .qick_asm import AbsQickProgram, AcquireMixin
from .helpers import to_int, check_bytes, check_keys

logger = logging.getLogger(__name__)

class QickSpan(NamedTuple):
    """Defines a sweep axis.
    A QickSpan equals 0 at the start of the specified loop, and the specified "span" value at the end of the loop.
    You may sum QickSpan objects and floats to build a multi-dimensional QickSweep.

    Parameters
    ----------
    loop : str
        The name of the loop to use for the sweep.
    span : float
        The desired value at the end of the loop. Can be positive or negative.
    """
    loop: str
    span: float
    def _to_sweep(self):
        # convert to sweep
        # helper for math ops and to_int()
        return QickSweep(0, {self.loop:self.span})
    def to_int(self, scale, quantize, parname, trunc=False):
        # this will get called if you use a single QickSpan as a parameter
        return to_int(self._to_sweep(), scale, quantize=quantize, parname=parname, trunc=trune)
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
    def to_int(self, scale, quantize, parname, trunc=False):
        start = to_int(self.start, scale, quantize=quantize, parname=parname, trunc=trunc)
        spans = {k: to_int(v, scale, quantize=quantize, parname=parname, trunc=trunc) for k,v in self.spans.items()}
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
        # used when comparing timestamps, or range-checking before converting to raw
        # compares a to the min possible value of the sweep
        return self.minval() > a
    def __lt__(self, a):
        # compares a to the max possible value of the sweep
        return self.maxval() < a

# user units, single dimension
def QickSweep1D(loop, start, end):
    """Convenience shortcut for a one-dimensional QickSweep.

    Parameters
    ----------
    loop : str
        The name of the loop to use for the sweep.
    start : float
        The desired value at the start of the loop.
    end : float
        The desired value at the end of the loop.
    """
    return start + QickSpan(loop, end-start)

class SimpleClass:
    # if you print this class, it will print the attributes listed in self._fields
    def __repr__(self):
        # based on https://docs.python.org/3/library/types.html#types.SimpleNamespace
        items = (f"{k}={getattr(self,k)!r}" for k in self._fields)
        return "{}({})".format(type(self).__name__, ", ".join(items))

# ASM units, multi-dimension
class QickSweepRaw(SimpleClass):
    _fields = ['par', 'start', 'spans', 'quantize', 'steps']
    def __init__(self, par: str, start: int, spans: Dict[str, int], quantize: int=1):
        # identifies the parameter being swept, so EndLoop can apply the sweep
        self.par = par
        # the initial value, which will be written to the register or waveform memory
        self.start = start
        # dict of sweep spans to cover in each loop
        self.spans = spans
        # when sweeping, the step size will be rounded to a multiple of this value
        self.quantize = quantize
        # dict of sweep steps for each loop, computed by to_steps() after the loop lengths are known
        self.steps = None

    def to_steps(self, loops):
        self.steps = {}
        for loop, r in self.spans.items():
            nSteps = loops[loop]
            # to avoid overflow, values are rounded towards zero using np.trunc()
            stepsize = int(self.quantize * np.trunc(r/(nSteps-1)/self.quantize))
            if stepsize==0:
                raise RuntimeError("requested sweep step is smaller than the available resolution: span=%d, steps=%d"%(r, nSteps-1))
            self.steps[loop] = {"step":stepsize, "span":stepsize*(nSteps-1)}

    def __mul__(self, a):
        # multiplying a QickSweepRaw by a Fraction yields a QickSweepRaw
        # used when scaling parameters (e.g. flat_top segment gain)
        # this will only happen before steps have been defined
        if not isinstance(a, Fraction):
            raise RuntimeError("QickSweepRaw can only be multiplied by Fraction")
        if self.steps is not None:
            raise RuntimeError("QickSweepRaw can only be multiplied before steps have been defined")
        if not all([x%a.denominator==0 for x in [self.start, self.quantize] + list(self.spans.values())]):
            raise RuntimeError("cannot multiply %s evenly by %d"%(str(self), a))
        spans = {k:int(v*a) for k,v in self.spans.items()}
        return QickSweepRaw(self.par, int(self.start*a), spans, int(self.quantize*a))
    def __mod__(self, a):
        # used in freq2reg etc.
        # do nothing - mod will be applied when compiling the Waveform
        return self
    def __truediv__(self, a):
        # dividing a QickSweepRaw by a number yields a QickSweep
        # this is used to convert duration to us (for updating timestamps)
        # or generally to convert sweeps back to user units (for getting sweep points)
        # this will only happen after steps have been defined
        if self.steps is None:
            raise RuntimeError("QickSweepRaw can only be divided after steps have been defined")
        spans = {k:v['span']/a for k,v in self.steps.items()}
        return QickSweep(self.start/a, spans)
    def __iadd__(self, a):
        # used when adding a scalar value to a sweep (when ReadoutManager adds a mixer freq to a readout freq)
        self.start += a
        return self
    def minval(self):
        # used to check for out-of-range values
        spanmin = min([min(r, 0) for r in self.spans.values()])
        return self.start + spanmin
    def maxval(self):
        spanmax = max([max(r, 0) for r in self.spans.values()])
        return self.start + spanmax

class Waveform(Mapping, SimpleClass):
    widths = [4, 4, 3, 4, 4, 2]
    _fields = ['name', 'freq', 'phase', 'env', 'gain', 'length', 'conf']
    def __init__(self, freq: Union[int, QickSweepRaw], phase: Union[int, QickSweepRaw], env: int, gain: Union[int, QickSweepRaw], length: Union[int, QickSweepRaw], conf: int, name: str=None):
        self.freq = freq
        self.phase = phase
        self.env = env
        self.gain = gain
        self.length = length
        self.conf = conf
        # name is assigned when the parent pulse is processed to fill the wave list
        self.name = name

    def compile(self):
        # use the field ordering, skipping the name
        params = [getattr(self, f) for f in self._fields[1:]]
        # if a parameter is swept, the start value is what we write to the wave memory
        startvals = [x.start if isinstance(x, QickSweepRaw) else x for x in params]
        # convert to bytes to get a 168-bit word (this is what actually ends up in the wave memory)
        # we truncate each parameter to its correct length using mod
        # some generator parameter lengths are smaller than the waveform parameter length:
        # e.g. int4 uses 16 bits for all params, full-speed uses 16 bits for length
        # in these cases the sg_translator will apply the additional truncation
        # truncation causes parameters to wrap, which is good for some params (freq, phase) not for others (gain, length)
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
    # implement Mapping interface to simplify converting this to a dict and back to a Waveform
    def __len__(self):
        return len(self._fields)
    def __getitem__(self, k):
        v = getattr(self, k)
        if isinstance(v, QickSweepRaw):
            return v.start
        else:
            return v
    def __iter__(self):
        return iter(self._fields)
    def to_dict(self):
        # for JSON serialization with helpers.NpEncoder
        # note that if a Waveform has swept parameters, the sweeps will be lost
        # this is OK because the sweeps should already have been converted to ASM
        d = OrderedDict()
        for k in self._fields:
            d[k] = getattr(self, k)
            if isinstance(d[k], QickSweepRaw):
                d[k] = d[k].start
        return d

class QickPulse(SimpleClass):
    """A pulse is mostly just a list of waveforms.
    You will not normally instantiate this class yourself.
    Use QickProgramV2.add_pulse() instead.

    Parameters
    ----------
    waveforms : list of Waveform
        The waveforms that make up this pulse.
    ch_mgr : AbsRegisterManager
        The generator or readout manager associated with this pulse's definition.
        Used to calculate pulse lengths.
    """
    _fields = ['waveforms']
    def __init__(self, waveforms: list[Waveform], ch_mgr: 'AbsRegisterManager'=None, par_map=None):
        self.waveforms = waveforms
        self.ch_mgr = ch_mgr
        self.par_map = par_map

    def get_length(self):
        if self.ch_mgr is None:
            logger.warning("no channel manager defined for this pulse, get_length() will return 0")
            return 0
        else:
            return sum([w.length/self.ch_mgr.f_clk for w in self.waveforms]) # in us

class QickRegister(SimpleClass):
    _fields = ['name', 'addr', 'sweep']
    def __init__(self, name: str=None, addr: int=None, sweep: QickSweep=None):
        self.name = name
        self.addr = addr
        self.sweep = sweep

class Macro(SimpleNamespace):
    def translate(self, prog):
        logger.debug("translating %s" % (self))
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
        logger.debug("adding ASM %s, addr_inc=%d" % (self.inst, self.addr_inc))
        prog._add_asm(self.inst.copy(), self.addr_inc)

class Label(Macro):
    def translate(self, prog):
        logger.debug("adding label %s" % (self.label))
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
        # use the field list to get index of the waveform register
        # skip the name field, which comes first
        iPar = Waveform._fields.index(self.par) - 1

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

class Delay(Macro):
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
            return [AsmInst(inst={'CMD':'TIME', 'C_OP':'inc_ref', 'R1':f'r{t_reg.addr}'}, addr_inc=1)]
        else:
            return [AsmInst(inst={'CMD':'TIME', 'C_OP':'inc_ref', 'LIT':f'{t_reg}'}, addr_inc=1)]

class Pulse(Macro):
    # ch, name, t
    def preprocess(self, prog):
        pulse_length = prog.pulses[self.name].get_length() # in us
        ts = prog.get_timestamp(gen_ch=self.ch)
        t = self.t
        if t == 'auto':
            t = ts #TODO: 0?
            prog.set_timestamp(t + pulse_length, gen_ch=self.ch)
        else:
            if t<ts:
                logger.warn("warning: pulse time %s appears to conflict with previous pulse ending at %s?"%(t, ts))
                prog.set_timestamp(ts + pulse_length, gen_ch=self.ch)
            else:
                prog.set_timestamp(t + pulse_length, gen_ch=self.ch)
        self.convert_time(prog, t, "t")

    def expand(self, prog):
        insts = []
        pulse = prog.pulses[self.name]
        tproc_ch = prog.soccfg['gens'][self.ch]['tproc_ch']
        insts.append(self.set_timereg(prog, "t"))
        for wave in pulse.waveforms:
            idx = prog.wave2idx[wave.name]
            insts.append(AsmInst(inst={'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx)}, addr_inc=1))
        return insts

class ConfigReadout(Macro):
    # ch, name, t
    def preprocess(self, prog):
        t = self.t
        self.convert_time(prog, t, "t")

    def expand(self, prog):
        insts = []
        pulse = prog.pulses[self.name]
        tproc_ch = prog.soccfg['readouts'][self.ch]['tproc_ctrl']
        insts.append(self.set_timereg(prog, "t"))
        for wave in pulse.waveforms:
            idx = prog.wave2idx[wave.name]
            insts.append(AsmInst(inst={'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx)}, addr_inc=1))
        return insts

class Trigger(Macro):
    # ros, pins, t, width, ddr4, mr
    def preprocess(self, prog):
        if self.width is None: self.width = prog.cycles2us(10)
        if self.ros is None: self.ros = []
        if self.pins is None: self.pins = []
        self.outdict = defaultdict(int)
        self.trigset = set()

        #treg = self.us2cycles(t)
        self.convert_time(prog, self.t, "t_start")
        self.convert_time(prog, self.t+self.width, "t_end")

        special_ros = []
        if self.ddr4: special_ros.append(prog.soccfg['ddr4_buf'])
        if self.mr: special_ros.append(prog.soccfg['mr_buf'])
        for rocfg in special_ros:
            if rocfg['trigger_type'] == 'dport':
                self.outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
            else:
                self.trigset.add(rocfg['trigger_port'])

        for ro in self.ros:
            rocfg = prog.soccfg['readouts'][ro]
            if rocfg['trigger_type'] == 'dport':
                self.outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
            else:
                self.trigset.add(rocfg['trigger_port'])
            ts = prog.get_timestamp(ro_ch=ro)
            if self.t < ts: logger.warning("Readout time %d appears to conflict with previous readout ending at %f?"%(self.t, ts))
            ro_length = prog.ro_chs[ro]['length']
            ro_length /= prog.soccfg['readouts'][ro]['f_output']
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
        for wave in prog.waves:
            spans_to_apply = []
            for sweep in wave.sweeps():
                if lname in sweep.steps:
                    spans_to_apply.append((sweep.par, sweep.steps[lname]))
            if spans_to_apply:
                wave_sweeps.append((wave.name, spans_to_apply))

        # check for register sweeps
        reg_sweeps = []
        for reg in prog.reg_dict.values():
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
        lreg = prog.reg_dict[lname]
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

class Read(Macro):
    # ro_ch
    def expand(self, prog):
        tproc_input = prog.soccfg['readouts'][self.ro_ch]['tproc_ch']
        return [AsmInst(inst={'CMD':"DPORT_RD", 'DST':str(tproc_input)}, addr_inc=1)]

class CondJump(Macro):
    # reg1, val2, reg2, op, test, label
    def expand(self, prog):
        insts = []
        nvals = sum([x is None for x in [self.val2, self.reg2]])
        if nvals > 1:
            raise RuntimeError("second operand must be reg or literal value, but you have provided both val2=%s, reg2=%s"
                               %(self.val2, self.reg2))
        elif nvals==1:
            op = {'+': '+',
                  '-': '-',
                  '>>': 'ASR',
                  '&': 'AND'}[self.op]
            v2 = self.reg2 if self.val2 is None else '#%d'%(self.val2)
            insts.append(AsmInst(inst={'CMD': 'TEST', 'OP': self.reg1 + op + v2, 'UF': '1'}, addr_inc=1))
        else:
            v2 = None
            insts.append(AsmInst(inst={'CMD': 'TEST', 'OP': self.reg1 + op + v2, 'UF': '1'}, addr_inc=1))
        insts.append(AsmInst(inst={'CMD': 'JUMP', 'IF': self.test, 'LABEL': self.label}, addr_inc=1))
        return insts

class AbsRegisterManager(ABC):
    """Generic class for managing registers that will be written to a tProc-controlled block (signal generator or readout).
    """
    def __init__(self, prog, chcfg, ch_name):
        self.prog = prog
        # the soccfg for this generator/readout
        self.chcfg = chcfg
        # the name of this block (for messages)
        self.ch_name = ch_name
        # the following will be set by subclass:
        # the tProc output channel controlled by this manager
        self.tproc_ch = None
        # the clock frequency to use for converting time units
        self.f_clk = None

    def add_pulse(self, name, kwargs):
        """Set pulse parameters.
        This is called by QickProgramV2.add_pulse().

        Parameters
        ----------
        kwargs : dict
            Parameter values
        """
        # check the final param set for validity
        self.check_params(kwargs)
        waves, par_map = self.params2pulse(kwargs)

        self.prog.pulses[name] = QickPulse(waves, self, par_map)

    @abstractmethod
    def check_params(self, params) -> None:
        ...

    @abstractmethod
    def params2pulse(self, params) -> Tuple[list[Waveform], dict[str, int]]:
        ...

    def cfg2reg(self, outsel, mode, stdysel, phrst):
        """Creates generator config register value, by setting flags.
        The bit ordering here is the one expected by the input to sg_translator.
        The translator will remap the bits to whatever the peripheral expects.

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
        Selects what value is output continuously by the signal generator after the generation of a waveform.
        The default is "zero".

        * If "last", it is the last calculated sample of the waveform.

        * If "zero", it is a zero value.

        phrst : int
        If 1, it resets the phase coherent accumulator. The default is 0.

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

class AbsGenManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = {}
    PARAMS_OPTIONAL = {}

    def __init__(self, prog, gen_ch):
        self.ch = gen_ch
        chcfg = prog.soccfg['gens'][gen_ch]
        super().__init__(prog, chcfg, "generator %d"%(gen_ch))
        self.tproc_ch = chcfg['tproc_ch']
        self.f_clk = chcfg['f_fabric']
        self.samps_per_clk = self.chcfg['samps_per_clk']

        # dictionary of defined envelopes
        self.envelopes = prog.envelopes[gen_ch]['envs']

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
        check_keys(params.keys(), self.PARAMS_REQUIRED[style], self.PARAMS_OPTIONAL[style])

class StandardGenManager(AbsGenManager):
    """Manager for the full-speed and interpolated signal generators.
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
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        else:
            if lenreg >= 2**16 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        wavereg = Waveform(freqreg, phasereg, env, gainreg, lenreg, confreg)
        return wavereg

    def params2pulse(self, par):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_pulse to add the ramp envelope which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the envelope is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length envelope with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        par : dict
            Pulse parameters
        """
        phrst_gens = ['axis_signal_gen_v6', 'axis_sg_int4_v1']
        if par.get('phrst') is not None and self.chcfg['type'] not in phrst_gens:
            raise RuntimeError("phrst not supported for %s, only for %s" % (self.chcfg['type'], phrst_gens))

        par_map = {}
        par_map['freq'] = (0, 1/self.prog.reg2freq(r=1, gen_ch=self.ch))
        par_map['phase'] = (0, 1/self.prog.reg2deg(r=1, gen_ch=self.ch))
        w = {}
        w['freqreg'] = self.prog.freq2reg(gen_ch=self.ch, f=par['freq'], ro_ch=par.get('ro_ch'))
        w['phasereg'] = self.prog.deg2reg(gen_ch=self.ch, deg=par['phase'])

        # gains should be rounded towards zero to avoid overflow
        if par['style']=='flat_top':
            # the flat segment is played at half gain, to match the ramps
            flat_scale = Fraction("1/2")
            # for int4 gen, the envelope amplitude will have been limited to maxv_scale
            # we need to reduce the flat segment amplitude by a corresponding amount
            flat_scale *= Fraction(self.chcfg['maxv_scale']).limit_denominator(20)

            # this is the gain that will be used for the ramps
            # because the flat segment will be scaled by flat_scale, we need this to be an even multiple of the flat_scale denominator
            w['gainreg'] = to_int(par['gain'], self.chcfg['maxv'], parname='gain', quantize=flat_scale.denominator, trunc=True)
            par_map['gain'] = (0, self.chcfg['maxv'])
        elif par['style']=='const':
            # it's not strictly necessary to apply maxv_scale here, but if we don't the amplitudes for different styles will be extra confusing?
            w['gainreg'] = to_int(par['gain'], self.chcfg['maxv']*self.chcfg['maxv_scale'], parname='gain', trunc=True)
            par_map['gain'] = (0, (self.chcfg['maxv']*self.chcfg['maxv_scale']))
        else:
            w['gainreg'] = to_int(par['gain'], self.chcfg['maxv'], parname='gain', trunc=True)
            par_map['gain'] = (0, self.chcfg['maxv'])

        if 'envelope' in par:
            env = self.envelopes[par['envelope']]
            env_length = env['data'].shape[0] // self.samps_per_clk
            env_addr = env['addr'] // self.samps_per_clk

        waves = []
        if par['style']=='const':
            par_map['length'] = (0, 1/self.prog.cycles2us(cycles=1, gen_ch=self.ch))
            w.update({k:par.get(k) for k in ['mode', 'stdysel', 'phrst']})
            w['outsel'] = 'dds'
            w['lenreg'] = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])
            waves.append(self.params2wave(**w))
        elif par['style']=='arb':
            w.update({k:par.get(k) for k in ['mode', 'outsel', 'stdysel', 'phrst']})
            w['env'] = env_addr
            w['lenreg'] = env_length
            waves.append(self.params2wave(**w))
        elif par['style']=='flat_top':
            par_map['length'] = (1, 1/self.prog.cycles2us(cycles=1, gen_ch=self.ch))
            w.update({k:par.get(k) for k in ['stdysel']})
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
            w2['gainreg'] = w2['gainreg'] * flat_scale
            w3 = w1.copy()
            w3['env'] = env_addr + (env_length+1)//2
            # only the first segment should have phrst
            w1['phrst'] = par.get('phrst')
            waves.append(self.params2wave(**w1))
            waves.append(self.params2wave(**w2))
            waves.append(self.params2wave(**w3))

            if self.chcfg['type'] == 'axis_sg_int4_v1':
                # workaround for FIR bug: we play a zero-gain min-length DDS pulse after the ramp-down, which brings the FIR to zero
                waves.append(self.params2wave(freqreg=0, phasereg=0, gainreg=0, lenreg=3))

        return waves, par_map

class MultiplexedGenManager(AbsGenManager):
    """Manager for the muxed signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'mask', 'length']}
    PARAMS_OPTIONAL = {'const': []}

    def params2wave(self, maskreg, lenreg):
        if isinstance(lenreg, QickSweepRaw):
            if lenreg.maxval() >= 2**32 or lenreg.minval() < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 32 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        else:
            if lenreg >= 2**32 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 32 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        wavereg = Waveform(freq=0, phase=0, env=0, gain=0, length=lenreg, conf=maskreg)
        return wavereg

    def params2pulse(self, par):
        par_map = {'length': (0, 1/self.prog.cycles2us(cycles=1, gen_ch=self.ch))}
        lenreg = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])

        tones = self.prog.gen_chs[self.ch]['mux_tones']
        maskreg = 0
        for maskch in par['mask']:
            if maskch not in range(len(tones)):
                raise RuntimeError("mask includes tone %d, but only %d tones are declared" % (maskch, len(tones)))
            maskreg |= (1 << maskch)
        return [self.params2wave(lenreg=lenreg, maskreg=maskreg)], par_map

class ReadoutManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = ['freq']
    PARAMS_OPTIONAL = ['length', 'phase', 'phrst', 'mode', 'outsel', 'gen_ch']

    def __init__(self, prog, ro_ch):
        self.ch = ro_ch
        chcfg = prog.soccfg['readouts'][self.ch]
        super().__init__(prog, chcfg, "readout %d"%(self.ch))
        self.tproc_ch = chcfg['tproc_ctrl']
        self.f_clk = chcfg['f_output']

    def check_params(self, params):
        """Check whether the parameters defined for a pulse are supported and sufficient for this generator and pulse type.
        Raise an exception if there is a problem.

        Parameters
        ----------
        params : dict
            Parameter values
        """
        check_keys(params.keys(), self.PARAMS_REQUIRED, self.PARAMS_OPTIONAL)

    def params2pulse(self, par):
        """Write whichever pulse registers are fully determined by the defined parameters.

        Parameters
        ----------
        par : dict
            Pulse parameters
        """
        par_map = {}
        par_map['freq'] = (0, 1/self.prog.reg2freq_adc(r=1, ro_ch=self.ch))
        par_map['length'] = (0, 1/self.prog.cycles2us(cycles=1, ro_ch=self.ch))
        par_map['phase'] = (0, 1/self.prog.reg2deg(r=1, gen_ch=None, ro_ch=self.ch))
        # convert the requested freq, frequency-matching to the generator if specified
        # freqreg may be an int or a QickSweepRaw
        freqreg = self.prog.freq2reg_adc(ro_ch=self.ch, f=par['freq'], gen_ch=par.get('gen_ch'))
        # if the matching generator has a mixer, that frequency needs to be added to this one
        # it should already be rounded to the readout and mixer frequency steps, so no additional rounding is needed
        # the relevant quantization step is still going to be the readout+generator step
        if 'gen_ch' in par and 'mixer_freq' in self.prog.gen_chs[par['gen_ch']]:
            # this will always be an integer
            freqreg += self.prog.freq2reg_adc(ro_ch=self.ch, f=self.prog.gen_chs[par['gen_ch']]['mixer_freq']['rounded'])

        """
        freq = self.prog.soccfg.adcfreq(f=par['freq'], ro_ch=self.ch, gen_ch=par.get('gen_ch'))
        # if the matching generator has a mixer, that frequency needs to be added to this one
        # it should already be rounded to the readout and mixer frequency steps, so no additional rounding is needed
        if 'gen_ch' in par and self.prog.gen_chs[par['gen_ch']]['mixer_freq'] is not None:
            freq += self.prog.gen_chs[par['gen_ch']]['mixer_freq']['rounded']
        freqreg = self.prog.freq2reg_adc(ro_ch=self.ch, f=freq)
        """

        if 'phase' in par:
            phasereg = self.prog.deg2reg(gen_ch=None, ro_ch=self.ch, deg=par['phase'])
        else:
            phasereg = 0

        if 'length' in par:
            lenreg = self.prog.us2cycles(ro_ch=self.ch, us=par['length'])
        else:
            lenreg = 3
        if isinstance(lenreg, QickSweepRaw):
            if lenreg.maxval() >= 2**16 or lenreg.minval() < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        else:
            if lenreg >= 2**16 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))

        confpars = {k:par.get(k) for k in ['outsel', 'mode', 'phrst']}
        confpars['stdysel'] = None
        confreg = self.cfg2reg(**confpars)
        return [Waveform(freqreg, phasereg, 0, 0, lenreg, confreg)], par_map

class QickProgramV2(AbsQickProgram):
    """Base class for all tProc v2 programs.

    Parameters
    ----------
    soccfg : QickConfig
        The QICK firmware configuration dictionary.
    """
    gentypes = {'axis_signal_gen_v4': StandardGenManager,
                'axis_signal_gen_v5': StandardGenManager,
                'axis_signal_gen_v6': StandardGenManager,
                'axis_sg_int4_v1': StandardGenManager,
                'axis_sg_mux4_v1': MultiplexedGenManager,
                'axis_sg_mux4_v2': MultiplexedGenManager,
                'axis_sg_mux4_v3': MultiplexedGenManager,
                'axis_sg_mux8_v1': MultiplexedGenManager,
                }

    def __init__(self, soccfg):
        super().__init__(soccfg)

        # all current v1 programs are processed in one pass:
        # * init the program
        # * fill the ASM list (using make_program or by calling ASM wrappers directly)
        # * compile the ASM list to binary as needed
        #
        # v2 programs require multiple passes:
        # * init the program
        # * fill the macro_list (using make_program or by calling macro wrappers directly)
        # * preprocess the macro_list, put register initialization in ASM
        # * expand the macro_list to fill the ASM list
        # * compile the ASM list to binary
        #
        # things that get added to a program:
        # * declare_gen, declare_readout
        # * add_pulse
        # * macros
        # 
        # user commands can add macros and/or waveforms+pulses to the program
        # macros are user commands
        # preprocessing: allocate registers, convert sweeps from physical units to ASM values, define the timeline
        # preprocessing allows us to initialize registers at the start of the program
        # expanding/translating: convert macros to lower-level macros and then to ASM

        # to convert sweeps from user values to ASM, we need:
        # loop lengths
        # the timeline

        # Attributes to dump when saving the program to JSON.
        # The dump just keeps enough information to execute the program - ASM and initial waveform values.
        # Most of the high-level information (macros, sweeps) is lost.
        self.dump_keys += ['waves', 'prog_list', 'labels']

    def _init_declarations(self):
        # initialize the high-level objects that get filled in manually, or by a make_program()

        super()._init_declarations()

        # high-level macros
        self.macro_list = []

        # generator managers handle a gen's envelopes and add_pulse logic
        self._gen_mgrs = [self.gentypes[ch['type']](self, iCh) for iCh, ch in enumerate(self.soccfg['gens'])]
        self._ro_mgrs = [ReadoutManager(self, iCh) if 'tproc_ctrl' in ch else None for iCh, ch in enumerate(self.soccfg['readouts'])]

        # pulses are software constructs, each is a set of 1 or more waveforms
        self.pulses = {}

    def _init_instructions(self):
        # initialize the low-level objects that get filled by macro expansion

        # this will also reset self.binprog
        super()._init_instructions()

        # high-level program structure

        self.reg_dict = {}  # lookup dict for registers defined

        self.loop_dict = OrderedDict()
        self.loop_stack = []

        # waveforms consist of initial parameters (to be written to the wave memory) and sweeps (to be applied when looping)
        self.waves = []
        self.wave2idx = {}

        # low-level ASM management

        self.prog_list = []
        self.labels = {'s15': 's15'} # register 15 predefinition

        # address in program memory
        self.p_addr = 1
        # line number
        self.line = 1
        # first instruction is always NOP, so both counters start at 1

    def load_prog(self, progdict):
        # note that we only dump+load the raw waveforms and ASM (the low-level stuff that gets converted to binary)
        # we don't load the macros, pulses, or sweeps (the high-level stuff that gets translated to the low-level stuff)
        super().load_prog(progdict)
        # re-create the Waveform objects
        self.waves = [Waveform(**w) for w in self.waves]
        # make the binary (this will prevent compile() from running and wiping out the low-level stuff)
        self._make_binprog()

    def _compile_prog(self):
        _, p_mem = Assembler.list2bin(self.prog_list, self.labels)
        return p_mem

    def _compile_waves(self):
        if self.waves:
            return np.stack([w.compile() for w in self.waves])
        else:
            return np.zeros((0,8), dtype=np.int32)

    def compile(self):
        self._make_asm()
        self._make_binprog()

    def _make_binprog(self):
        # convert the low-level program definition (ASM and waveform list) to binary
        self.binprog = {}
        self.binprog['pmem'] = self._compile_prog()
        self.binprog['wmem'] = self._compile_waves()

    def _make_asm(self):
        # convert the high-level program definition (macros and pulses) to low-level (ASM and waveform list)

        # reset the low-level program objects
        self._init_instructions()

        # fill wave list
        for iPulse, (pulsename, pulse) in enumerate(self.pulses.items()):
            # register the pulse and waves with the program
            for iWave, wave in enumerate(pulse.waveforms):
                if len(pulse.waveforms)==1:
                    wavename = pulsename
                else:
                    wavename = "%s_w%d" % (pulsename, iWave)
                while wavename in self.wave2idx:
                    newname = wavename + "_"
                    logger.warning("wavename %s already used, using %s instead" % (wavename, newname))
                    wavename = newname
                self.waves.append(wave)
                self.wave2idx[wavename] = len(self.waves)-1
                wave.name = wavename

        # we need the loop names and counts first, to convert sweeps to steps
        # allocate the loop register, set a name if not defined, add the loop to the program's loop dict
        for macro in self.macro_list:
            if isinstance(macro, StartLoop):
                if macro.name is None: macro.name = f"loop_{len(self.loop_dict)}"
                self.loop_dict[macro.name] = macro.n
                macro.reg = self.new_reg(name=macro.name)
        # compute step sizes for sweeps
        for w in self.waves:
            w.fill_steps(self.loop_dict)
        for i, macro in enumerate(self.macro_list):
            macro.preprocess(self)
        # initialize sweep registers
        for reg in self.reg_dict.values():
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
        self.labels[label] = '&%d' % (self.p_addr)

    def asm(self):
        """Convert the program instructions to printable ASM.

        Returns
        -------
        str
            text ASM
        """
        # make sure the program's been compiled
        if self.binprog is None:
            self.compile()
        asm = Assembler.list2asm(self.prog_list, self.labels)
        return asm

    def __str__(self):
        # make sure the program's been compiled
        if self.binprog is None:
            self.compile()
        lines = []
        lines.append("macros:")
        lines.extend(["\t%s" % (p) for p in self.macro_list])
        lines.append("registers:")
        lines.extend(["\t%s: %s" % (k,v) for k,v in self.reg_dict.items()])
        lines.append("pulses:")
        lines.extend(["\t%s: %s" % (k,v) for k,v in self.pulses.items()])
        #lines.append("waveforms:")
        #lines.extend(["\t%s" % (w) for w in self.waves])

        lines.append("expanded ASM:")
        lines.extend(textwrap.indent(self.asm(), "\t").splitlines())
        return "\n".join(lines)

    # natural-units wrappers for methods of AbsQickProgram

    def add_gauss(self, ch, name, sigma, length, maxv=None, even_length=False):
        """Adds a Gaussian envelope to the envelope library.
        The Gaussian will peak at length/2.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the envelope
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

    def add_raw_pulse(self, name, waveforms, gen_ch=None, ro_ch=None):
        """Add a pulse defined as a list of raw waveform objects.
        This is usually only useful for testing and debugging.
        If you need the pulse length to be defined (e.g. if playing this pulse on a generator), you must specify one of gen_ch and ro_ch.

        Parameters
        ----------
        name : str
            name of the pulse
        waveforms : list of Waveform
            waveforms that will be concatenated for this pulse
        gen_ch : int
            generator channel (index in 'gens' list)
        ro_ch : int
            readout channel (index in 'readouts' list)
        """
        ch_mgr = None
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        elif gen_ch is not None:
            ch_mgr = self._gen_mgrs[gen_ch]
        elif ro_ch is not None:
            ch_mgr = self._ro_mgrs[ro_ch]

        self.pulses[name] = QickPulse(waveforms)

    def add_pulse(self, ch, name, **kwargs):
        """Add a pulse to the program's pulse library.
        See the relevant generator manager for the list of supported pulse styles and parameters.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            name of the pulse
        style : str
            Pulse style ("const", "arb", "flat_top")
        freq : int
            Frequency (MHz)
        phase : int
            Phase (degrees)
        gain : int
            Gain (-1.0 to 1.0, relative to the max amplitude for this generator and pulse style)
        phrst : int
            If 1, it resets the phase coherent accumulator
        stdysel : str
            Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        mode : str
            Selects whether the output is "oneshot" or "periodic"
        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        length : float
            The duration (us) of the flat portion of the pulse, used for "const" and "flat_top" styles
        envelope : str
            Name of the envelope waveform loaded with add_envelope(), used for "arb" and "flat_top" styles
        mask : list of int
            for a muxed signal generator, the list of tones to enable for this pulse
        """
        self._gen_mgrs[ch].add_pulse(name, kwargs)

    def add_readoutconfig(self, ch, name, **kwargs):
        """Add a readout config to the program's pulse library.
        The "mode" and "length" parameters have no useful effect and should probably never be used.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        name : str
            name of the config
        freq : float or QickSweep
            Frequency (MHz)
        phase : float or QickSweep
            Phase (degrees)
        phrst : int
            If 1, it resets the DDS phase. The default is 0.
        mode : str
            Selects whether the output is "oneshot" (the default) or "periodic."
        outsel : str
            Selects the output source. The input is real, the output is complex. If "product" (the default), the output is the product of input and DDS. If "dds", the output is the DDS only. If "input", the output is from the input. If "zero", the output is always zero.
        length : float or QickSweep
            The duration (us) of the config pulse. The default is the shortest possible length.
        """
        self._ro_mgrs[ch].add_pulse(name, kwargs)

    def get_pulse_param(self, pulsename, parname, as_array=False):
        """Get the fully rounded value of a pulse parameter, in the same units that are used to specify the parameter in add_pulse().
        By default, a swept parameter will be returned as a QickSweep.
        If instead you ask for an array, the array will have a dimension for each loop where the parameter is swept.
        The dimensions will be ordered by the loop order.

        The rounded value is only available after the program has been compiled (or run).
        So you can't call this method from inside your program definition.

        Parameters
        ----------
        pulsename : str
            Name of the pulse
        parname : str
            Name of the parameter
        as_array : bool
            If the parameter is swept, return an array instead of a QickSweep

        Returns
        -------
        float, QickSweep, or array
            Parameter value
        """
        # if the parameter is swept, it's not fully defined until the loop macros have been processed
        if self.binprog is None:
            raise RuntimeError("get_pulse_param() can only be called on a program after it's been compiled")

        pulse = self.pulses[pulsename]
        if parname=='total_length':
            param = pulse.get_length()
        else:
            index, scale = pulse.par_map[parname]
            waveform = pulse.waveforms[index]
            param = getattr(waveform, parname)/scale

        if as_array and isinstance(param, QickSweep):
            allpoints = None
            for name, n in self.loop_dict.items():
                if name in param.spans:
                    points = np.linspace(0, param.spans[name], n)
                    if allpoints is None:
                        allpoints = points + param.start
                    else:
                        allpoints = np.add.outer(allpoints, points)
            return allpoints
        else:
            return param

    # register management

    def new_reg(self, addr: int = None, name: str = None, sweep: QickSweepRaw = None):
        """Declare a new data register.
        For internal use; not recommended for user code at this time.

        :param addr: address of the new register. If None, the function will automatically try to find the next
            available address.
        :param name: name of the new register. Optional.
        :return: QickRegister
        """
        assigned_addrs = set([v.addr for v in self.reg_dict.values()])
        if addr is None:
            addr = 0
            while addr in assigned_addrs:
                addr += 1
            if addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise RuntimeError(f"data registers are full.")
        else:
            if addr < 0 or addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise ValueError(f"register address must be smaller than {self.soccfg['tprocs'][0]['dreg_qty']}")
            if addr in assigned_addrs:
                raise ValueError(f"register at address {addr} is already occupied.")

        if name is None:
            name = f"reg_{addr}"
        if name in self.reg_dict.keys():
            raise NameError(f"register name '{name}' already exists")

        reg = QickRegister(addr=addr, name=name, sweep=sweep)
        self.reg_dict[name] = reg

        return reg
    
    def get_reg(self, name, lazy_init=False):
        """Get a previously defined register object.
        For internal use; not recommended for user code at this time.
        """
        if lazy_init and name not in self.reg_dict:
            self.new_reg(name=name)
        return self.reg_dict[name]

    # start of ASM code
    def add_macro(self, macro):
        """Add a macro to the program's macro list.

        Parameters
        ----------
        macro : Macro
            macro to be added
        """
        self.macro_list.append(macro)

    def asm_inst(self, inst, addr_inc=1):
        """Add a macro-wrapped ASM instruction to the program's macro list.
        If you are mixing ASM and macros (you probably are), this is what you want to use.

        Parameters
        ----------
        inst : dict
            ASM instruction in dictionary format
        addr_inc : int
            number of machine-code words this instruction will occupy. Only used for WAIT.
        """
        self.add_macro(AsmInst(inst=inst, addr_inc=addr_inc))


    # low-level macros

    def label(self, label):
        """Apply the specified label to the next instruction.
        If the next instruction is a macro that expands to multiple ASM instructions, the label goes on the first ASM instruction.
        That's what you want.

        Parameters
        ----------
        label : str
            label to be applied
        """
        self.add_macro(Label(label=label))

    def nop(self):
        """Do a NOP instruction.
        This is a no-op - it doesn't do anything except waste a tProcessor cycle.
        """
        self.asm_inst({'CMD': 'NOP'})

    def end(self):
        """Do an END instruction, which will end execution.
        This is implemented as an infinite loop (the v2 doesn't really have an "end" state).
        """
        self.add_macro(End())

    def set_ext_counter(self, addr=1, val=0):
        """Set one of the externally readable registers.
        This is usually used to initialize the shot counter.

        Parameters
        ----------
        addr : int
            register number, 1 or 2
        val : int
            value to write (signed 32-bit)
        """
        # initialize the data counter
        reg = {1:'s12', 2:'s13'}[addr]
        self.add_macro(SetReg(reg=reg, val=val))

    def inc_ext_counter(self, addr=1, val=1):
        """Increment one of the externally readable registers.
        This is usually used to increment the shot counter.

        Parameters
        ----------
        addr : int
            register number, 1 or 2
        val : int
            value to add (signed 32-bit)
        """
        # increment the data counter
        reg = {1:'s12', 2:'s13'}[addr]
        self.add_macro(IncReg(reg=reg, val=val))

    # feedback and branching
    def read(self, ro_ch):
        """Read an accumulated I/Q value from one of the tProc inputs.
        The readout must have already pushed the value into the input, otherwise you will get a stale value.
        The value you read gets stored in two special registers (s8/s9, aka port_l/port_h or I/Q) until you are ready to use it.
        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        """
        self.add_macro(Read(ro_ch=ro_ch))

    def cond_jump(self, label, reg1, test, op=None, val2=None, reg2=None):
        """Do a conditional jump (do a test, then jump if the test passes).
        A test is done by executing an operation on two operands and testing the resulting value.
        If val2 and reg2 are both None, the test will just use reg1, no operation.
        
        Parameters
        ----------
        label : str
            the label to jump to
        reg1 : str
            the name of the register for operand 1
        test: str
            the name of the test: 1/0 (always/never), Z/NZ (==0/!=0), S/NS (<0/>=0), F/NF (external flag)
        op : str
            the name of the operation: +, -, AND (bitwise AND, &), or ASR (shift-right, >>)
        val2 : int
            24-bit signed value for operand 2
        reg2 : int
            the name of the register for operand 2
        """
        self.add_macro(CondJump(label=label, reg1=reg1, op=op, test=test, val2=val2, reg2=reg2))

    def read_and_jump(self, ro_ch, component, threshold, test, label):
        """Read an input I/Q value and jump based on a threshold.
        This just combines read() and cond_jump().
        As noted in read(), you must be sure your readout has already completed.
        
        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        component : str
            I or Q
        threshold : int
            24-bit signed value
        test: str
            ">=" or "<"
        label : str
            the label to jump to
        """
        test = {'>=':'NS', '<':'S'}[test]
        reg = {'I':'s8', 'Q':'s9'}[component]
        self.read(ro_ch)
        self.cond_jump(label=label, reg1=reg, op='-', test=test, val2=threshold)

    # control statements
    def open_loop(self, n, name=None):
        """Start a loop.
        This will use a register.
        If you're using AveragerProgramV2, you should use add_loop() instead.

        Parameters
        ----------
        n : int
            number of iterations
        name : str
            number of iterations
        """
        self.add_macro(StartLoop(n=n, name=name))
    
    def close_loop(self):
        """End whatever loop you're in.
        This will increment whatever sweeps are tied to this loop.
        """
        self.add_macro(EndLoop())

    # timeline management

    def wait(self, t):
        """Pause tProc execution until the time reaches the specified value, relative to the reference time.

        Parameters
        ----------
        t : float
            time (us)
        """
        self.add_macro(Wait(t=t, auto=False))

    def delay(self, t):
        """Increment the reference time.
        This will have the effect of delaying all timed instructions executed after this one.

        Parameters
        ----------
        t : float
            time (us)
        """
        self.add_macro(Delay(t=t, auto=False))

    def delay_auto(self, t=0, gens=True, ros=True):
        """Set the reference time to the end of the last pulse/readout, plus the specified value.
        You can select whether this accounts for pulses, readout windows, or both.

        Parameters
        ----------
        t : float
            time (us)
        gens : bool
            check the ends of generator pulses
        ros : bool
            check the ends of readout windows
        """
        self.add_macro(Delay(t=t, auto=True, gens=gens, ros=ros))

    def wait_auto(self, t=0, gens=False, ros=True):
        """Pause tProc execution until the time reaches the specified value, relative to the end of the last pulse/readout.
        You can select whether this accounts for pulses, readout windows, or both.

        Parameters
        ----------
        t : float
            time (us)
        gens : bool
            check the ends of generator pulses
        ros : bool
            check the ends of readout windows
        """
        self.add_macro(Wait(t=t, auto=True, gens=gens, ros=ros))

    # pulses and triggers

    def pulse(self, ch, name, t=0):
        """Play a pulse.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            pulse name (as used in add_pulse())
        t : float, QickSweep, or "auto"
            time (us), or the end of the last pulse on this generator
        """
        self.add_macro(Pulse(ch=ch, name=name, t=t))

    def send_readoutconfig(self, ch, name, t=0):
        """Send a previously defined readout config to a readout.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        name : str
            config name (as used in add_readoutconfig())
        t : float or QickSweep
            time (us)
        """
        self.add_macro(ConfigReadout(ch=ch, name=name, t=t))

    def trigger(self, ros=None, pins=None, t=0, width=None, ddr4=False, mr=False):
        """Pulse readout triggers and output pins.

        Parameters
        ----------
        ros : list of int
            readout channels to trigger (index in 'readouts' list)
        pins : list of int
            output pins to trigger (index in output pins list in QickCOnfig printout)
        t : float or QickSweep
            time (us)
        width : float or QickSweep
            pulse width (us), default of 10 cycles of the tProc timing clock
        ddr4 : bool
            trigger the DDR4 buffer
        mr : bool
            trigger the MR buffer
        """
        self.add_macro(Trigger(ros=ros, pins=pins, t=t, width=width, ddr4=ddr4, mr=mr))

class AcquireProgramV2(AcquireMixin, QickProgramV2):
    """Base class for tProc v2 programs with shot counting and readout acquisition.
    You will need to define the acquisition structure with setup_acquire().
    If you just want shot counting and run_rounds(), you can use setup_counter().
    """
    pass

class AveragerProgramV2(AcquireProgramV2):
    """Use this as a base class to build looping programs.
    You are responsible for writing initialize() and body().
    The content of your body() - a "shot" - will be run inside nested loops, where the outermost loop is run "reps" times, and you can add loop levels with add_loop().
    The returned data will be averaged over the "reps" axis.

    This is similar to the NDAveragerProgram from tProc v1.
    (Note that the order of user loops is reversed: first added is outermost, not innermost)

    Parameters
    ----------
    soccfg : QickConfig
        The QICK firmware configuration dictionary.
    cfg : dict
        Your program configuration dictionary.
        There are no required entries, this is for your use and can be accessed as self.cfg in your initialize() and body().
    reps : int
        Number of iterations in the "reps" loop.
    final_delay : float
        Amount of time (in us) to add at the end of the shot timeline, after the end of the last pulse or readout.
        If your experiment requires a gap between shots (e.g. qubit relaxation time), use this parameter.
        The total length of your shot timeline should allow enough time for the tProcessor to execute your commands, and for the CPU to read the accumulated buffers; the default of 1 us usually guarantees this, and 0 will be fine for simple programs with sparse timelines.
        A value of None will disable this behavior (and you should insert appropriate delay/delay_auto statements in your body).
        This parameter is often called "relax_delay."
    final_wait : float
        Amount of time (in us) to pause tProc execution at the end of each shot, after the end of the last readout.
        The default of 0 is usually appropriate.
        A value of None will disable this behavior (and you should insert appropriate wait/wait_auto statements in your body).
    initial_delay : float
        Amount of time (in us) to add to the timeline before starting to run the loops.
        This should allow enough time for the tProcessor to execute your initialization commands.
        The default of 1 us is usually sufficient.
        A value of None will disable this behavior (and you should insert appropriate delay/delay_auto statements in your initialization).
    """

    COUNTER_ADDR = 1
    def __init__(self, soccfg, reps, final_delay, final_wait=0, initial_delay=1.0, cfg=None):
        self.cfg = {} if cfg is None else cfg.copy()
        self.reps = reps
        self.final_delay = final_delay
        self.final_wait = final_wait
        self.initial_delay = initial_delay
        super().__init__(soccfg)

        # fill the program
        self.compile()

    def compile(self):
        # we should only need to compile once
        if self.binprog is not None:
            return

        # wipe out macros
        self._init_declarations()

        # prepare the loop list
        self.loops = [("reps", self.reps)]

        # make_program() should add all the declarations and macros
        self.make_program()

        # process macros, generate ASM and waveform list, generate binary program
        super().compile()

        # use the loop list to set up the data shape
        self.setup_acquire(counter_addr=self.COUNTER_ADDR, loop_dims=[x[1] for x in self.loops], avg_level=0)

    def add_loop(self, name, count):
        """Add a loop level to the program.
        The first level added will be the outermost loop (after the reps loop).

        Parameters
        ----------
        name : str
            Name of this loop level.
            This should match the name used in your sweeps.
        count : int
            Number of iterations for this loop.
        """
        self.loops.append((name, count))

    def initialize(self, cfg):
        """Do inital setup of your program and the QICK.
        This is where you should put any ASM commands (register operations, setup pulses) that need to be played before the shot loops begin.
        It's also conventional to put program declarations here (though because these are executed by Python and not the tProc it doesn't really matter, they just need to be executed).
        """
        pass

    def body(self, cfg):
        """Play a shot.
        This is where you should put pulses and readout triggers.
        """
        pass

    def make_program(self):
        # play the initialization
        self.set_ext_counter(addr=self.COUNTER_ADDR)
        self.initialize(self.cfg)
        if self.initial_delay is not None:
            self.delay_auto(self.initial_delay)

        for name, count in self.loops:
            self.open_loop(count, name=name)

        # play the shot
        self.body(self.cfg)
        if self.final_wait is not None:
            self.wait_auto(self.final_wait)
        if self.final_delay is not None:
            self.delay_auto(self.final_delay)
        self.inc_ext_counter(addr=self.COUNTER_ADDR)

        # close the loops - order doesn't matter
        for name, count in self.loops:
            self.close_loop()

        self.end()
