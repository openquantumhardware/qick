from __future__ import annotations
import logging
import numpy as np
import textwrap
from collections import OrderedDict, defaultdict
from collections.abc import Mapping
from types import SimpleNamespace
from typing import Callable, NamedTuple, Union, Dict
from abc import ABC, abstractmethod
from fractions import Fraction
import copy
from numbers import Number, Integral

from .tprocv2_assembler import Assembler
from .qick_asm import AbsQickProgram, AcquireMixin
from .helpers import to_int, check_bytes, check_keys

logger = logging.getLogger(__name__)

# user units, multi-dimension
class QickParam:
    """Defines a parameter for use in pulses or times.
    This may be a floating-point scalar or a multi-dimensional sweep.
    This class isn't usually instantiated by user code:
    if you want to make a sweep, it's easier to use QickSweep1D or <start_val>+QickSpan+QickSpan....

    The lifecycle of the various sweep classes:

    User code builds a QickParam from scalars, QickSpans, and QickParams.

    When the pulse or timed instruction is defined, the QickParam might get additional scalar operations (mostly, if it's a readout freq for an RO that's freq-matched with a mixer generator).
    (are there cases where delay_auto values might get added to sweeps?)
    Then it gets converted to a QickRawParam by to_int.
    The QickRawParam may be scaled by int or Fraction multiplication, or offset by an int, e.g. to convert from flat-top to ramp gain, to apply mixer freq to a freq-matched RO freq. These are in-place operations.
    The "quantize" parameter ensures that the scaled QickRawParams will get stepped in the same way.

    When the loop dims are known, the QickRawParam gets divided into steps by to_steps.
    The same QickRawParam may be used for multiple Waveforms.

    QickRawParam gets converted back to QickParam to get user units by float division.
    This is used to get pulse durations; the resulting QickParam may get operated on and get used for an auto time.
    It is also used by get_pulse_param, but we will probably use get_actual_values instead?

    get_actual_values works as follows:

    derived_param and conversion_from_derived_param are updated whenever a new QickParam is created by scalar operation.
    Note that if the same QickParam is used in two places, the derived_param pointer gets overwritten.
    Pulse and timed-instruction parameters are copied at use, so get_pulse_param and get_time_param are safe.
    Code that calls get_actual_values directly on a QickParam relies on the step sizes being the same everywhere a sweep is used.

    raw_param and raw_scale are set by to_int.
    Normally the QickRawParam created by to_int is then stepped.

    When get_actual_values is called on the pulse parameter, it recurses through the derived_param pointers until it finds the QickParam that got converted by to_int.
    Then raw_param is used to get the rounded+stepped QickRawParam.
    """
    def __init__(self, start: float, spans: dict={}):
        self.start = start
        self.spans = spans

        # these get assigned when to_int is called and are used by get_actual_values
        self.raw_param: QickRawParam | None = None
        self.raw_scale: float | int | None = None

        # these get assigned when a mathematical operation is performed on this QickParam
        self.derived_param: QickParam | None = None
        self.conversion_from_derived_param: Callable | None = None

    def is_sweep(self):
        return bool(self.spans)

    def __float__(self):
        if self.is_sweep():
            raise RuntimeError("tried to cast a swept QickParam to float, which is not safe")
        return self.start

    def to_int(self, scale, quantize, parname, trunc=False):
        # this check catches the situation where a QickParam might get used in two different places and confuse get_actual_values
        # this shouldn't happen, because we copy the pulse and timed-instruction parameters
        if self.raw_param is not None:
            logger.warn("the same QickParam is being converted to QickRawParam twice")
        start = to_int(self.start, scale, quantize=quantize, parname=parname, trunc=trunc)
        spans = {k: to_int(v, scale, quantize=quantize, parname=parname, trunc=trunc) for k,v in self.spans.items()}
        self.raw_param = QickRawParam(par=parname, start=start, spans=spans, quantize=quantize)
        self.raw_scale = scale
        return self.raw_param

    def get_rounded(self, loop_counts: dict[str, int]=None) -> QickParam:
        """Calculate the param values after rounding to ASM units.
        loop_counts parameter is optional and will be used to compute steps if they have not already been computed.

        Parameters
        ----------
        loop_counts : dict[str, int]
            Number of iterations for each loop, outermost first.
        """
        if self.raw_param is not None:
            if self.raw_param.steps is None:
                # this shouldn't happen as part of get_pulse_param/get_time_param, because those only operate on converted+stepped QickParam
                logger.info("to_steps was never called on this QickRawParam")
                self.raw_param.to_steps(loop_counts)
            assert self.raw_scale is not None
            # convert QickRawParam to QickParam
            rounded_param = self.raw_param.to_rounded()
            # undo the scale that got applied by to_int
            rounded_param /= self.raw_scale
            return rounded_param

        if self.derived_param is not None:
            assert self.conversion_from_derived_param is not None
            return self.conversion_from_derived_param(
                self.derived_param.get_rounded(loop_counts)
            )

        raise RuntimeError("to_int has not been called on this QickParam or its descendants")

    def to_array(self, loop_counts, all_loops=False):
        """Calculate the sweep points.
        This calculation is based on the span values in the sweep.
        If you call this on a QickParam that you defined, the result will differ from the actual sweep points due to rounding.
        If you want exact actual values, use get_actual_values() or call this on an already-rounded QickParam (like one returned by get_pulse_param()/get_time_param().

        Parameters
        ----------
        loop_counts : dict[str, int]
            Number of iterations for each loop, outermost first.
        all_loops : bool
            If a loop in loop_counts doesn't increment this QickParam, include it in the output array as a dimension of size 1.

        Returns
        -------
        values : np.ndarray
            Each dimension corresponds to a loop in loop_counts.
        """
        values = self.start
        for name, count in loop_counts.items():
            if name in self.spans:
                span = self.spans[name]
                steps = np.linspace(0, span, count)
                values = np.add.outer(values, steps)
            elif all_loops:
                values = np.add.outer(values, [0])
        return values

    def get_actual_values(self, loop_counts: dict[str, int]) -> np.ndarray:
        """Calculate the actual sweep points after rounding to ASM units.

        Parameters
        ----------
        loop_counts : dict[str, int]
            Number of iterations for each loop, outermost first.

        Returns
        -------
        values : np.ndarray
            Each dimension corresponds to a loop in loop_counts. The size of the dimension is 1 if the loop does not increment this QickParam.
        """
        rounded_param = self.get_rounded(loop_counts)
        return rounded_param.to_array(loop_counts, all_loops=True)

    def __copy__(self):
        self.derived_param = QickParam(self.start, self.spans.copy())
        self.conversion_from_derived_param = lambda x: x
        return self.derived_param
    def __add__(self, a):
        if isinstance(a, QickParam):
            new_start = self.start + a.start
            new_spans = self.spans.copy()
            for loop, r in a.spans.items():
                new_spans[loop] = new_spans.get(loop, 0) + r
            return QickParam(new_start, new_spans)
        if isinstance(a, Number):
            new_start = self.start + a
            self.derived_param = QickParam(new_start, self.spans)
            self.conversion_from_derived_param = lambda x: x - a
            return self.derived_param
        return NotImplemented
    def __radd__(self, a):
        return self+a
    def __sub__(self, a):
        return self + (-a)
    def __rsub__(self, a):
        return (-self) + a
    def __mul__(self, a):
        if isinstance(a, (int, float)):
            new_start = self.start * a
            new_spans = {k: v * a for k, v in self.spans.items()}
            self.derived_param = QickParam(new_start, new_spans)
            self.conversion_from_derived_param = lambda x: x / a
            return self.derived_param
        return NotImplemented
    def __neg__(self):
        return self * -1
    def __rmul__(self, a):
        return self * a
    def __truediv__(self, a):
        return self * (1 / a)
    def minval(self):
        val = self.start
        if self.spans: val += min([min(r, 0) for r in self.spans.values()])
        return val
    def maxval(self):
        val = self.start
        if self.spans: val += max([max(r, 0) for r in self.spans.values()])
        return val
    def __gt__(self, a):
        # used when comparing timestamps, or range-checking before converting to raw
        # compares a to the min possible value of the sweep
        return self.minval() > a
    def __lt__(self, a):
        # compares a to the max possible value of the sweep
        return self.maxval() < a

# user units, single dimension
def QickSweep1D(loop, start, end):
    """Convenience shortcut for a one-dimensional QickParam.

    Parameters
    ----------
    loop : str
        The name of the loop to use for the sweep.
    start : float
        The desired value at the start of the loop.
    end : float
        The desired value at the end of the loop.
    """
    return QickParam(start, {loop: end-start})

def QickSpan(loop, span):
    """Convenience shortcut for building multi-dimensional QickParams.
    A QickSpan equals 0 at the start of the specified loop, and the specified "span" value at the end of the loop.
    You may sum QickSpans and floats to build a multi-dimensional QickParam.

    Parameters
    ----------
    loop : str
        The name of the loop to use for the sweep.
    span : float
        The desired value at the end of the loop. Can be positive or negative.
    """
    return QickParam(0.0, {loop: span})

class SimpleClass:
    # if you print this class, it will print the attributes listed in self._fields
    def __repr__(self):
        # based on https://docs.python.org/3/library/types.html#types.SimpleNamespace
        items = (f"{k}={getattr(self,k)!r}" for k in self._fields)
        return "{}({})".format(type(self).__name__, ", ".join(items))

# ASM units, multi-dimension
class QickRawParam(SimpleClass):
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

        self.scale = 1
        self.offset = 0

    def is_sweep(self):
        return bool(self.spans)

    def __int__(self):
        if self.is_sweep():
            raise RuntimeError("tried to cast a swept QickRawParam to int, which is not safe")
        return self.start

    def to_steps(self, loops):
        if self.steps is not None:
            logger.warn("to_steps is getting called twice on this QickRawParam")
        self.steps = {}
        for loop, r in self.spans.items():
            nSteps = loops[loop]
            if nSteps==1 or r==0:
                # a loop with one step or zero span isn't really a sweep, we can set a stepsize of 0
                stepsize = 0
                # TODO: continue, and get rid of zero sweep checks?
            else:
                # to avoid overflow, values are rounded towards zero using np.trunc()
                stepsize = int(self.quantize * np.trunc(r/(nSteps-1)/self.quantize))
                if stepsize==0:
                    raise RuntimeError("requested sweep step is smaller than the available resolution: span=%d, steps=%d"%(r, nSteps-1))
            self.steps[loop] = {"step":stepsize, "span":stepsize*(nSteps-1)}

    def to_rounded(self):
        """Reverse the conversion from QickParam to QickRawParam.
        This is used by QickParam.get_rounded().
        """
        # convert to QickParam
        rounded_param = self/1.0
        # undo the offset+scale that got applied
        rounded_param -= self.offset
        rounded_param /= self.scale
        return rounded_param

    def __copy__(self):
        newparam = QickRawParam(self.par, self.start, copy.copy(self.spans), self.quantize)
        newparam.steps = copy.copy(self.steps)
        return newparam
    def __imul__(self, a):
        # multiplying a QickRawParam by a int or Fraction yields a QickRawParam
        # used when scaling parameters (e.g. flat_top segment gain) or flipping the sign of downconversion freqs
        # this will only happen before steps have been defined
        if self.steps is not None:
            raise RuntimeError("QickRawParam can only be multiplied before steps have been defined")
        if isinstance(a, Fraction):
            if not all([x%a.denominator==0 for x in [self.start, self.quantize] + list(self.spans.values())]):
                raise RuntimeError("cannot multiply %s evenly by %d"%(str(self), a))
        elif isinstance(a, int): pass
        else:
            raise RuntimeError("QickRawParam can only be multiplied by int or Fraction")
        self.start = int(self.start*a)
        self.quantize = int(self.quantize*a)
        for k,v in self.spans.items():
            self.spans[k] = int(v*a)
        self.scale *= a
        self.offset *= a
        #spans = {k:int(v*a) for k,v in self.spans.items()}
        #return QickRawParam(self.par, int(self.start*a), spans, int(self.quantize*a))
        return self
    def __iadd__(self, a):
        # used when adding a scalar value to a param (when ReadoutManager adds a mixer freq to a readout freq)
        self.start += a
        self.offset += a
        return self
    def __mod__(self, a):
        # used in freq2reg etc.
        # do nothing - mod will be applied when compiling the Waveform
        return self
    def __truediv__(self, a):
        # dividing a QickRawParam by a number yields a QickParam
        # this is used to convert duration to us (for updating timestamps)
        # or generally to convert raw params back to user units (for getting rounded values)
        # this will only happen after steps have been defined
        if self.steps is None:
            raise RuntimeError("QickRawParam can only be divided after steps have been defined")
        spans = {k:v['span']/a for k,v in self.steps.items()}
        return QickParam(self.start/a, spans)
    def minval(self):
        # used to check for out-of-range values
        val = self.start
        if self.spans:
            val += min([min(r, 0) for r in self.spans.values()])
        return val
    def maxval(self):
        val = self.start
        if self.spans:
            val += max([max(r, 0) for r in self.spans.values()])
        return val

class Waveform(Mapping, SimpleClass):
    widths = [4, 4, 3, 4, 4, 2]
    _fields = ['name', 'freq', 'phase', 'env', 'gain', 'length', 'conf']
    def __init__(self, freq: Union[int, QickRawParam], phase: Union[int, QickRawParam], env: int, gain: Union[int, QickRawParam], length: Union[int, QickRawParam], conf: int, name: str=None):
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
        startvals = [x.start if isinstance(x, QickRawParam) else x for x in params]
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
        return [r for r in [self.freq, self.phase, self.gain, self.length] if isinstance(r, QickRawParam)]
    def fill_steps(self, loops):
        for sweep in self.sweeps():
            sweep.to_steps(loops)
    # implement Mapping interface to simplify converting this to a dict and back to a Waveform
    def __len__(self):
        return len(self._fields)
    def __getitem__(self, k):
        v = getattr(self, k)
        if isinstance(v, QickRawParam):
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
            if isinstance(d[k], QickRawParam):
                d[k] = d[k].start
        return d

class QickPulse(SimpleClass):
    """A pulse is mostly just a list of waveforms.
    It also contains some metadata to allow the rounded/swept values of the original pulse parameters to be extracted.
    You will not normally instantiate this class yourself.
    Use QickProgramV2.add_pulse() instead.

    Parameters
    ----------
    params : dict
        Parameter values
    ch_mgr : AbsRegisterManager
        The generator or readout manager associated with this pulse's definition.
        Used to calculate pulse lengths.
    """
    _fields = ['waveforms']

    SPECIAL_WAVEFORMS = {
            "dummy": Waveform(freq=0, phase=0, env=0, gain=0, length=3, conf=0, name="dummy"),
            "phrst": Waveform(freq=0, phase=0, env=0, gain=0, length=3, conf=0b010000, name="phrst"),
            }

    def __init__(self, prog: 'QickProgramV2', ch_mgr: 'AbsRegisterManager', params: dict={}):
        self.prog = prog
        self.ch_mgr = ch_mgr
        if ch_mgr is None:
            self.numeric_params = []
        else:
            self.numeric_params = list(params.keys() & ch_mgr.PARAMS_NUMERIC) + ['total_length']
        self.params = params
        self.waveforms = []

    def add_wave(self, waveform):
        """Add a Waveform or a waveform name to this pulse.
        """
        self.waveforms.append(waveform)
        if not isinstance(waveform, Waveform):
            # if we're adding a waveform by name, it must already be registered in the program
            # if it's one of the predefined "special" waveforms, we can register it now
            if waveform in self.prog.wave2idx:
                pass
            elif waveform in self.SPECIAL_WAVEFORMS:
                self.prog._register_wave(self.SPECIAL_WAVEFORMS[waveform], waveform)
            else:
                raise RuntimeError("add_wave argument {waveform} is neither a Waveform nor a waveform name")

    def get_length(self):
        # always returns a QickParam
        length = QickParam(start=0)
        if self.ch_mgr is None:
            logger.warning("no channel manager defined for this pulse, get_length() will return 0")
        else:
            for w in self.waveforms:
                if isinstance(w, Waveform):
                    wave = w
                else:
                    wave = self.prog._get_wave(w)
                length += wave.length/self.ch_mgr.f_clk # convert to us
        return length

    def get_wavenames(self, exclude_special=False):
        names = []
        for w in self.waveforms:
            if isinstance(w, Waveform):
                names.append(w.name)
            else:
                if exclude_special and w in self.SPECIAL_WAVEFORMS:
                    continue
                names.append(w)
        return names

# possible arguments:
# int
# QickRawParam
# * scalar
# * sweep
# str
# * allocated register name
# * special register name
# "register name" can be "user-defined name" or full address
# "full address" = "register type" + "register address"
# full address also sometimes referred to as "ASM address"
# register alias: things like "s_time"
class QickRegisterV2(SimpleClass):
    """A user-allocated data register, possibly with an initial (swept) value.

    This is for internal use; user code should not use this class.
    """
    _fields = ['addr', 'init']
    def __init__(self, addr: int, init: QickParam=None):
        self.addr = addr
        self.init = init

    def full_addr(self):
        return 'r%d'%(self.addr)

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
        # this runs after loop_dict is filled and waveform sweeps are stepped
        pass

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

# register operations

class WriteReg(Macro):
    # set a register to a literal or register
    # dst, src
    def expand(self, prog):
        dst = prog._get_reg(self.dst)
        if isinstance(self.src, Integral):
            return [AsmInst(inst={'CMD':"REG_WR", 'DST': dst, 'SRC':'imm', 'LIT': "#%d"%(self.src)}, addr_inc=1)]
        if isinstance(self.src, str):
            src = prog._get_reg(self.src)
            return [AsmInst(inst={'CMD':"REG_WR", 'DST': dst, 'SRC':'op', 'OP': src}, addr_inc=1)]
        raise RuntimeError(f"invalid src: {self.src}")

class IncReg(Macro):
    # increment a register by a literal or register
    # dst, src
    def expand(self, prog):
        insts = []
        dst = prog._get_reg(self.dst)
        if isinstance(self.src, Integral):
            # immediate arguments to operations must be 24-bit
            if check_bytes(self.src, 3):
                src = '#%d'%(self.src)
            else:
                # constrain the value to signed 32-bit
                trunc = np.int64(self.src).astype(np.int32)
                prog.add_reg("scratch", allow_reuse=True)
                insts.append(WriteReg(dst="scratch", src=trunc))
                src = prog._get_reg("scratch")
        elif isinstance(self.src, str):
            src = prog._get_reg(self.src)
        else:
            raise RuntimeError(f"invalid src: {self.src}")
        insts.append(AsmInst(inst={'CMD':"REG_WR", 'DST': dst, 'SRC':'op', 'OP': '%s + %s'%(dst, src)}, addr_inc=1))
        return insts

class ReadWmem(Macro):
    # name
    def expand(self, prog):
        addr = prog.wave2idx[self.name]
        return [AsmInst(inst={'CMD':'REG_WR', 'DST':'r_wave', 'SRC':'wmem', 'ADDR':f'&{addr}'}, addr_inc=1)]

class WriteWmem(Macro):
    # name
    def expand(self, prog):
        addr = prog.wave2idx[self.name]
        return [AsmInst(inst={'CMD':'WMEM_WR', 'DST':f'&{addr}'}, addr_inc=1)]

class ReadDmem(Macro):
    # copy a dmem value into a register, using an int literal or register for the dmem address
    # dst, addr
    def expand(self, prog):
        dst = prog._get_reg(self.dst)
        if isinstance(self.addr, Integral):
            addr = '&%d'%(self.addr)
        elif isinstance(self.addr, str):
            addr = '&%s'%(prog._get_reg(self.addr))
        else:
            raise RuntimeError(f"invalid addr: {self.addr}")
        return [AsmInst(inst={'CMD': 'REG_WR', 'DST': dst, 'SRC': 'dmem', 'ADDR': addr}, addr_inc=1)]

class WriteDmem(Macro):
    # write an int literal or register into dmem, using an int literal or register for the dmem index
    # addr, src
    def expand(self, prog):
        if isinstance(self.addr, Integral):
            dst = '[&%d]'%(self.addr)
        elif isinstance(self.addr, str):
            dst = '[&%s]'%(prog._get_reg(self.addr))
        else:
            raise RuntimeError(f"invalid addr: {self.addr}")

        if isinstance(self.src, Integral):
            return [AsmInst(inst={'CMD':"DMEM_WR", 'DST': dst, 'SRC':'imm', 'LIT': "#%d"%(self.src)}, addr_inc=1)]
        if isinstance(self.src, str):
            src = prog._get_reg(self.src)
            return [AsmInst(inst={'CMD':"DMEM_WR", 'DST': dst, 'SRC':'op', 'OP': src}, addr_inc=1)]
        raise RuntimeError(f"invalid src: {self.src}")

#feedback and branching

class ReadInput(Macro):
    # ro_ch
    def expand(self, prog):
        tproc_input = prog.soccfg['readouts'][self.ro_ch]['tproc_ch']
        return [AsmInst(inst={'CMD':"DPORT_RD", 'DST':str(tproc_input)}, addr_inc=1)]

class CondJump(Macro):
    # arg1, arg2, op, test, label
    def expand(self, prog):
        insts = []
        arg1 = prog._get_reg(self.arg1)
        if self.arg2 is not None:
            if self.op is None:
                raise RuntimeError("a second operand was supplied, but no operation")
            op = {'+': '+',
                  '-': '-',
                  '>>': 'ASR',
                  '&': 'AND'}[self.op]
            if isinstance(self.arg2, Integral):
                arg2 = '#%d'%(self.arg2)
            elif isinstance(self.arg2, str):
                arg2 = prog._get_reg(self.arg2)
            else:
                raise RuntimeError(f"invalid arg2: {self.arg2}")
            insts.append(AsmInst(inst={'CMD': 'TEST', 'OP': " ".join([arg1, op, arg2]), 'UF': '1'}, addr_inc=1))
        else:
            if self.op is not None:
                raise RuntimeError("an operation was supplied, but no second operand")
            insts.append(AsmInst(inst={'CMD': 'TEST', 'OP': arg1, 'UF': '1'}, addr_inc=1))
        insts.append(AsmInst(inst={'CMD': 'JUMP', 'IF': self.test, 'LABEL': self.label}, addr_inc=1))
        return insts

# loops

class OpenLoop(Macro):
    # name, reg, n
    def preprocess(self, prog):
        # allocate a register with the same name
        prog.add_reg(name=self.name)

    def expand(self, prog):
        insts = []
        prog.loop_stack.append(self.name)
        # initialize the loop counter to zero and set the loop label
        insts.append(WriteReg(dst=self.name, src=self.n))
        label = self.name
        insts.append(Label(label=label))
        return insts

class CloseLoop(Macro):
    def expand(self, prog):
        insts = []

        # the loop we're closing is the one at the top of the loop stack
        lname = prog.loop_stack.pop()
        label = lname

        # check for wave sweeps
        wave_sweeps = []
        for wave in prog.waves:
            spans_to_apply = []
            for sweep in wave.sweeps():
                # skip zero sweeps
                if lname in sweep.steps and sweep.steps[lname]['step']!=0:
                    spans_to_apply.append((sweep.par, sweep.steps[lname]))
            if spans_to_apply:
                wave_sweeps.append((wave.name, spans_to_apply))

        # check for register sweeps
        reg_sweeps = []
        for reg in prog.reg_dict.values():
            # skip zero sweeps
            if isinstance(reg.init, QickRawParam) and lname in reg.init.spans and reg.init.steps[lname]['step']!=0:
                reg_sweeps.append((reg, reg.init.steps[lname]))

        # increment waves and registers
        for wname, spans_to_apply in wave_sweeps:
            insts.append(ReadWmem(name=wname))
            for par, steps in spans_to_apply:
                insts.append(IncReg(dst="w_"+par, src=steps['step']))
            insts.append(WriteWmem(name=wname))
        for reg, steps in reg_sweeps:
            insts.append(IncReg(dst=reg.full_addr(), src=steps['step']))

        # increment and test the loop counter
        reg = prog.reg_dict[lname].full_addr()
        insts.append(AsmInst(inst={'CMD':'REG_WR', 'DST':reg, 'SRC':'op', 'OP':f'{reg} - #1', 'UF':'1'}, addr_inc=1))
        insts.append(AsmInst(inst={'CMD':'JUMP', 'LABEL':label, 'IF':'NZ'}, addr_inc=1))

        # if we swept a parameter, we should restore it to its original value
        for wname, spans_to_apply in wave_sweeps:
            insts.append(ReadWmem(name=wname))
            for par, steps in spans_to_apply:
                insts.append(IncReg(dst="w_"+par, src=-steps['step']-steps['span']))
            insts.append(WriteWmem(name=wname))
        for reg, steps in reg_sweeps:
            insts.append(IncReg(dst=reg.full_addr(), src=-steps['step']-steps['span']))

        return insts

class TimedMacro(Macro):
    """Timed instructions have parameters corresponding to times or durations.

    Add additional methods used for handling these time parameters.
    """
    def __init__(self, *args, **kwargs):
        # pass through any init arguments
        super().__init__(*args, **kwargs)
        self.t_params = {}
        self.t_regs = {}

    def convert_time(self, prog, t, name):
        # helper method, to be used in preprocess()
        # if the time value is swept, we need to allocate a register and initialize it at the beginning of the program
        # return actual (rounded, stepped) time value
        # if t is None (can happen with wait_auto/delay_auto), pass that through

        if t is None:
            t_reg = None
            t_rounded = None
        else:
            # if t is a QickParam, store a copy
            if isinstance(t, QickParam):
                t = copy.copy(t)
            # if t is scalar, convert to QickParam
            else:
                t = QickParam(start=t, spans={})

            t_reg = prog.us2cycles(t)
            t_reg.to_steps(prog.loop_dict)
            if t_reg.is_sweep():
                # allocate a register and initialize with the swept value
                # TODO: pick a meaningful register name?
                t_reg = prog.add_reg(init=t_reg)
            else:
                # this is just an int literal
                t_reg = int(t_reg)
            t_rounded = t.get_rounded()
        # t_params gets a QickParam, for later reference
        # t_regs gets an int or a register name, for use in ASM
        self.t_params[name] = t
        self.t_regs[name] = t_reg
        return t_rounded

    def list_time_params(self):
        return list(self.t_params.keys())

    def get_time_param(self, name):
        if name not in self.t_params:
            raise RuntimeError("invalid parameter name; use list_time_params() to get the list of valid names for this instruction")
        return self.t_params[name].get_rounded()

    def set_timereg(self, prog, name):
        # helper method, to be used in expand()
        t_reg = self.t_regs[name]
        return WriteReg(dst='s_out_time', src=t_reg)

    def inc_timereg(self, prog, name):
        # helper method, to be used in expand()
        t_reg = self.t_regs[name]
        return IncReg(dst='s_out_time', src=t_reg)

# timeline management

class Delay(TimedMacro):
    # t, auto, gens, ros (last two only defined if auto=True)
    def preprocess(self, prog):
        delay = self.t
        if isinstance(delay, Number):
            delay = QickParam(delay)
        if self.auto:
            # TODO: check for cases where auto doesn't work
            max_t = prog.get_max_timestamp(gens=self.gens, ros=self.ros)
            if max_t is None: # no relevant channels
                delay = None
            else:
                delay += max_t
        delay_rounded = self.convert_time(prog, delay, "t")
        prog.decrement_timestamps(delay_rounded)
    def expand(self, prog):
        t_reg = self.t_regs["t"]
        if t_reg is None:
            # if this was a delay_auto and we have no relevant channels, it should compile to nothing
            return []
        elif isinstance(t_reg, int):
            return [AsmInst(inst={'CMD':'TIME', 'C_OP':'inc_ref', 'LIT':f'#{t_reg}'}, addr_inc=1)]
        else:
            return [AsmInst(inst={'CMD':'TIME', 'C_OP':'inc_ref', 'R1':prog._get_reg(t_reg)}, addr_inc=1)]

class Wait(TimedMacro):
    # t, auto, gens, ros (last two only defined if auto=True)
    # t is float or QickParam
    def preprocess(self, prog):
        wait = self.t
        if isinstance(wait, Number):
            wait = QickParam(wait)
        if self.auto:
            max_t = prog.get_max_timestamp(gens=self.gens, ros=self.ros)
            if max_t is None: # no relevant channels
                wait = None
            else:
                wait += max_t
        if wait.is_sweep():
            # TODO: maybe rounding up should be optional?
            # TODO: track wait time in timestamps and do safety checks vs. sync and pulse times?
            waitmax = wait.maxval()
            if not self.no_warn:
                logger.warning("WAIT can only take a scalar argument, but in this case it would be %s, so rounding up to the max val of %f." % (wait, waitmax))
            wait = waitmax
        wait_rounded = self.convert_time(prog, wait, "t")
        # TODO: we could do something with this value
    def expand(self, prog):
        t_reg = self.t_regs["t"]
        if t_reg is None:
            # if this was a wait_auto and we have no relevant channels, it should compile to nothing
            return []
        elif isinstance(t_reg, int):
            return [AsmInst(inst={'CMD':'WAIT', 'ADDR':f'&{prog.p_addr + 1}', 'C_OP':'time', 'TIME': f'@{t_reg}'}, addr_inc=2)]
        else:
            raise RuntimeError("WAIT can only take a scalar argument, not a sweep")

# pulses and triggers

class Pulse(TimedMacro):
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
        for wave in pulse.get_wavenames():
            idx = prog.wave2idx[wave]
            insts.append(AsmInst(inst={'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx)}, addr_inc=1))
        return insts

class ConfigReadout(TimedMacro):
    # ch, name, t
    def preprocess(self, prog):
        t = self.t
        self.convert_time(prog, t, "t")

    def expand(self, prog):
        insts = []
        pulse = prog.pulses[self.name]
        tproc_ch = prog.soccfg['readouts'][self.ch]['tproc_ctrl']
        insts.append(self.set_timereg(prog, "t"))
        for wave in pulse.get_wavenames():
            idx = prog.wave2idx[wave]
            insts.append(AsmInst(inst={'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx)}, addr_inc=1))
        return insts

class Trigger(TimedMacro):
    # ros, pins, t, width, ddr4, mr
    def preprocess(self, prog):
        if self.width is None: self.width = prog.cycles2us(10)
        if self.ros is None: self.ros = []
        if self.pins is None: self.pins = []
        self.outdict = defaultdict(int)
        self.trigset = set()

        #treg = self.us2cycles(t)
        self.convert_time(prog, self.t, "t")
        self.convert_time(prog, self.width, "width")

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
            if self.t is not None:
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
        if self.t is not None:
            insts.append(self.set_timereg(prog, "t"))
        if self.outdict:
            for outport, out in self.outdict.items():
                insts.append(AsmInst(inst={'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':str(out)}, addr_inc=1))
        if self.trigset:
            for outport in self.trigset:
                insts.append(AsmInst(inst={'CMD':'TRIG', 'SRC':'set', 'DST':str(outport)}, addr_inc=1))
        insts.append(self.inc_timereg(prog, "width"))
        if self.outdict:
            for outport, out in self.outdict.items():
                insts.append(AsmInst(inst={'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':'0'}, addr_inc=1))
        if self.trigset:
            for outport in self.trigset:
                insts.append(AsmInst(inst={'CMD':'TRIG', 'SRC':'clr', 'DST':str(outport)}, addr_inc=1))
        return insts

class AsmV2:
    """A list of tProc v2 assembly instructions.
    You can think of this as a code snippet that you can insert in a program.
    """

    def __init__(self, *args, **kwargs):
        # this also gets reset in _init_declarations, but that's OK
        self.macro_list = []

        # pass through any init arguments
        super().__init__(*args, **kwargs)

    # start of ASM code
    def append_macro(self, macro):
        """Add a macro to the program's macro list.

        Parameters
        ----------
        macro : Macro
            macro to be added
        """
        self.macro_list.append(macro)

    def extend_macros(self, asm):
        """Append all the given instructions onto this list of instructions.
        Named by analogy to Python list.extend().

        Parameters
        ----------
        asm : AsmV2
            instruction list to append
        """
        self.macro_list.extend(asm.macro_list)

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
        self.append_macro(AsmInst(inst=inst, addr_inc=addr_inc))

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
        self.append_macro(Label(label=label))

    def nop(self):
        """Do a NOP instruction.
        This is a no-op - it doesn't do anything except waste a tProcessor cycle.
        """
        self.asm_inst({'CMD': 'NOP'})

    def end(self):
        """Do an END instruction, which will end execution.
        This is implemented as an infinite loop (the v2 doesn't really have an "end" state).
        """
        self.append_macro(End())

    def jump(self, label):
        """Do a JUMP instruction, jumping to the location of the specified label.
        """
        self.asm_inst({'CMD': 'JUMP', 'LABEL': label})

    def call(self, label):
        """Do a CALL instruction, storing the current program counter and jumping to the location of the specified label.
        The next RET instruction will cause the program to jump back to the CALL.
        This is used to call subroutines, where a subroutine is defined as a block of code starting with a label and ending with a RET.
        """
        self.asm_inst({'CMD': 'CALL', 'LABEL': label})

    def ret(self):
        """Do a RET instruction, returning from a CALL.
        """
        self.asm_inst({'CMD': 'RET'})

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
        reg = {1:'s_core_w1', 2:'s_core_w2'}[addr]
        self.write_reg(dst=reg, src=val)

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
        reg = {1:'s_core_w1', 2:'s_core_w2'}[addr]
        self.inc_reg(dst=reg, src=val)

    # register operations

    def write_reg(self, dst, src):
        """Write to a register.

        Parameters
        ----------
        dst : str
            Name of destination register
        src : int or str
            Literal value, or name of source register
        """
        self.append_macro(WriteReg(dst=dst, src=src))

    def inc_reg(self, dst, src):
        """Increment a register.

        Parameters
        ----------
        dst : str
            Name of destination register
        src : int or str
            Literal value, or name of source register
        """
        self.append_macro(IncReg(dst=dst, src=src))

    def read_wmem(self, name):
        """Copy a waveform from waveform memory to waveform registers.
        This is usually used in combination with write_wmem() to make changes to a waveform.
        You will usually get the waveform name using QickProgramV2.list_pulse_waveforms().

        Parameters
        ----------
        name : str
            Waveform name
        """
        self.append_macro(ReadWmem(name=name))

    def write_wmem(self, name):
        """Copy a waveform from waveform registers to waveform memory.
        This is usually used in combination with read_wmem() to make changes to a waveform.
        You will usually get the waveform name using QickProgramV2.list_pulse_waveforms().

        Parameters
        ----------
        name : str
            Waveform name
        """
        self.append_macro(WriteWmem(name=name))

    def read_dmem(self, dst, addr):
        """Copy a number from data memory to a register.
        The memory address can be specified as an int or a register.

        Parameters
        ----------
        dst : str
            Name of destination register
        addr : int or str
            Literal address, or name of register
        """
        self.append_macro(ReadDmem(dst=dst, addr=addr))

    def write_dmem(self, addr, src):
        """Copy a number into data memory.
        Both the value and the memory address can be specified as an int or a register.

        Parameters
        ----------
        addr : int or str
            Literal address, or name of register
        src : int str
            Literal value, or name of source register
        """
        self.append_macro(WriteDmem(addr=addr, src=src))

    # feedback and branching

    def read_input(self, ro_ch):
        """Read an accumulated I/Q value from one of the tProc inputs.
        The readout must have already pushed the value into the input, otherwise you will get a stale value.
        The value you read gets stored in two special registers (s_port_l/s_port_h or I/Q) until you are ready to use it.
        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        """
        self.append_macro(ReadInput(ro_ch=ro_ch))

    def cond_jump(self, label, arg1, test, op=None, arg2=None):
        """Do a conditional jump (do a test, then jump if the test passes).
        A test is done by executing an operation on two operands and testing the resulting value.
        If val2 and reg2 are both None, the test will just use reg1, no operation.

        Parameters
        ----------
        label : str
            the label to jump to
        arg1 : str
            the name of the register for operand 1
        test: str
            the name of the test: 1/0 (always/never), Z/NZ (==0/!=0), S/NS (<0/>=0), F/NF (external flag)
        op : str
            the name of the operation: +, -, AND (bitwise AND, &), or ASR (shift-right, >>)
        arg2 : int or str
            24-bit signed value or register name for operand 2
        """
        self.append_macro(CondJump(label=label, arg1=arg1, test=test, op=op, arg2=arg2))

    def read_and_jump(self, ro_ch, component, threshold, test, label):
        """Read an input I/Q value and jump based on a threshold.
        This just combines read_input() and cond_jump().
        As noted in read_input(), you must be sure your readout has already completed.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        component : str
            I or Q
        threshold : int or str
            24-bit signed value or register name
        test: str
            ">=" or "<"
        label : str
            the label to jump to
        """
        test = {'>=':'NS', '<':'S'}[test]
        reg = {'I':'s_port_l', 'Q':'s_port_h'}[component]
        self.read_input(ro_ch)
        self.cond_jump(label=label, arg1=reg, op='-', test=test, arg2=threshold)

    # loops

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
        self.append_macro(OpenLoop(n=n, name=name))

    def close_loop(self):
        """End whatever loop you're in.
        This will increment whatever sweeps are tied to this loop.
        """
        self.append_macro(CloseLoop())

    # timeline management

    def delay(self, t, tag=None):
        """Increment the reference time.
        This will have the effect of delaying all timed instructions executed after this one.

        Parameters
        ----------
        t : float
            time (us)
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(Delay(t=t, auto=False, tag=tag))

    def delay_auto(self, t=0, gens=True, ros=True, tag=None):
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
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(Delay(t=t, auto=True, gens=gens, ros=ros, tag=tag))

    def wait(self, t, tag=None):
        """Pause tProc execution until the time reaches the specified value, relative to the reference time.

        Parameters
        ----------
        t : float
            time (us)
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(Wait(t=t, auto=False, tag=tag, no_warn=False))

    def wait_auto(self, t=0, gens=False, ros=True, tag=None, no_warn=False):
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
        tag: str
            arbitrary name for use with get_time_param()
        no_warn : bool
            don't warn if the "auto" logic results in a swept wait which gets rounded up to a scalar
        """
        self.append_macro(Wait(t=t, auto=True, gens=gens, ros=ros, tag=tag, no_warn=no_warn))

    # pulses and triggers

    def pulse(self, ch, name, t=0, tag=None):
        """Play a pulse.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            pulse name (as used in add_pulse())
        t : float, QickParam, or "auto"
            time (us), or the end of the last pulse on this generator
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(Pulse(ch=ch, name=name, t=t, tag=tag))

    def send_readoutconfig(self, ch, name, t=0, tag=None):
        """Send a previously defined readout config to a readout.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        name : str
            config name (as used in add_readoutconfig())
        t : float or QickParam
            time (us)
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(ConfigReadout(ch=ch, name=name, t=t, tag=tag))

    def trigger(self, ros=None, pins=None, t=0, width=None, ddr4=False, mr=False, tag=None):
        """Pulse readout triggers and output pins.

        Parameters
        ----------
        ros : list of int
            readout channels to trigger (index in 'readouts' list)
        pins : list of int
            output pins to trigger (index in output pins list in QickCOnfig printout)
        t : float, QickParam, or None
            time (us)
            if None, the current value of the time register (s_out_time) will be used
            in this case, the channel timestamps will not be updated
        width : float or QickParam
            pulse width (us), default of 10 cycles of the tProc timing clock
        ddr4 : bool
            trigger the DDR4 buffer
        mr : bool
            trigger the MR buffer
        tag: str
            arbitrary name for use with get_time_param()
        """
        self.append_macro(Trigger(ros=ros, pins=pins, t=t, width=width, ddr4=ddr4, mr=mr, tag=tag))


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
        # the tProc output channel that connects to this block
        self.tproc_ch = None
        # if a tProc mux is used, the mux channel that connects to this block
        self.tmux_ch = None
        # the clock frequency to use for converting time units
        self.f_clk = None

    def make_pulse(self, kwargs):
        """Set pulse parameters.
        This is called by QickProgramV2.add_pulse().

        Parameters
        ----------
        kwargs : dict
            Parameter values
        """
        # check the final param set for validity, and convert param types as needed
        pulse_params = self.check_params(kwargs)
        return self.params2pulse(pulse_params)

    @abstractmethod
    def check_params(self, params) -> tuple[dict, list]:
        ...

    @abstractmethod
    def params2pulse(self, params) -> QickPulse:
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

        cfgreg = phrst*0b010000 + stdysel_reg*0b01000 + mode_reg*0b00100 + outsel_reg
        if self.tmux_ch is not None:
            cfgreg += (self.tmux_ch << 8)
        return cfgreg

class AbsGenManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = {}
    PARAMS_OPTIONAL = {}
    PARAMS_NUMERIC = []

    def __init__(self, prog, gen_ch):
        self.ch = gen_ch
        chcfg = prog.soccfg['gens'][gen_ch]
        super().__init__(prog, chcfg, "generator %d"%(gen_ch))
        self.tproc_ch = chcfg['tproc_ch']
        self.tmux_ch = chcfg.get('tmux_ch') # default to None if undefined
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

        Returns
        -------
        dict
            Parameter dictionary to be stored with the pulse.
            Scalar numeric parameters are converted to QickParam, QickParams are copied.
        """
        style = params['style']
        required = set(self.PARAMS_REQUIRED[style])
        allowed = required | set(self.PARAMS_OPTIONAL[style])
        check_keys(params.keys(), self.PARAMS_REQUIRED[style], self.PARAMS_OPTIONAL[style])

        pulse_params = {}
        for k,v in params.items():
            if k in self.PARAMS_NUMERIC and not isinstance(v, QickParam):
                pulse_params[k] = QickParam(start=v, spans={})
            else:
                pulse_params[k] = copy.copy(v)
        return pulse_params

class StandardGenManager(AbsGenManager):
    """Manager for the full-speed and interpolated signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'envelope'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'envelope']}
    PARAMS_OPTIONAL = {'const': ['ro_ch', 'phrst', 'stdysel', 'mode'],
            'arb': ['ro_ch', 'phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['ro_ch', 'phrst', 'stdysel']}
    PARAMS_NUMERIC = ['freq', 'phase', 'gain', 'length']

    def params2wave(self, freqreg, phasereg, gainreg, lenreg, env=0, mode=None, outsel=None, stdysel=None, phrst=None):
        confreg = self.cfg2reg(outsel=outsel, mode=mode, stdysel=stdysel, phrst=phrst)
        if isinstance(lenreg, QickRawParam):
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
        phrst_gens = ['axis_signal_gen_v6', 'axis_sg_int4_v1', 'axis_sg_int4_v2']
        if par.get('phrst') is not None and self.chcfg['type'] not in phrst_gens:
            raise RuntimeError("phrst not supported for %s, only for %s" % (self.chcfg['type'], phrst_gens))

        pulse = QickPulse(self.prog, self, par)

        w = {}
        if self.prog.ABSOLUTE_FREQS and self.chcfg['has_mixer']:
            mixer_freq = self.prog.gen_chs[self.ch]['mixer_freq']['rounded']
            f_dds = par['freq'] - mixer_freq
            f_offset = mixer_freq
        else:
            f_dds = par['freq']
            f_offset = 0
        w['freqreg'] = self.prog.freq2reg(gen_ch=self.ch, f=f_dds, ro_ch=par.get('ro_ch'))

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
        elif par['style']=='const':
            # it's not strictly necessary to apply maxv_scale here, but if we don't the amplitudes for different styles will be extra confusing?
            w['gainreg'] = to_int(par['gain'], self.chcfg['maxv']*self.chcfg['maxv_scale'], parname='gain', trunc=True)
        else:
            w['gainreg'] = to_int(par['gain'], self.chcfg['maxv'], parname='gain', trunc=True)

        if 'envelope' in par:
            env = self.envelopes[par['envelope']]
            env_length = env['data'].shape[0] // self.samps_per_clk
            env_addr = env['addr'] // self.samps_per_clk

        waves = []
        if par['style']=='const':
            w.update({k:par.get(k) for k in ['mode', 'stdysel', 'phrst']})
            w['outsel'] = 'dds'
            w['lenreg'] = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])
            pulse.add_wave(self.params2wave(**w))
        elif par['style']=='arb':
            w.update({k:par.get(k) for k in ['mode', 'outsel', 'stdysel', 'phrst']})
            w['env'] = env_addr
            w['lenreg'] = env_length
            pulse.add_wave(self.params2wave(**w))
        elif par['style']=='flat_top':
            w.update({k:par.get(k) for k in ['stdysel']})
            w['mode'] = 'oneshot'
            if env_length % 2 != 0:
                logger.warning("Envelope length %d is an odd number of fabric cycles.\n"
                "The middle cycle of the envelope will not be used.\n"
                "If this is a problem, you could use the even_length parameter for your envelope."%(env_length))
            # we want to make sure the original QickRawParam created from each pulse parameter ends up in exactly one waveform
            # so the parameters of the later segments are copies, except for the flat length
            w1 = w
            w2 = {k:copy.copy(v) for k,v in w.items()}
            w1['env'] = env_addr
            w1['outsel'] = 'product'
            w1['lenreg'] = env_length//2
            w2['outsel'] = 'dds'
            w2['lenreg'] = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])
            w2['gainreg'] *= flat_scale
            w3 = {k:copy.copy(v) for k,v in w1.items()}
            w3['env'] = env_addr + (env_length+1)//2
            # only the first segment should have phrst
            w1['phrst'] = par.get('phrst')
            pulse.add_wave(self.params2wave(**w1))
            pulse.add_wave(self.params2wave(**w2))
            pulse.add_wave(self.params2wave(**w3))

            if self.chcfg['type'] in ['axis_sg_int4_v1', 'axis_sg_int4_v2']:
                # workaround for FIR bug: we play a zero-gain min-length DDS pulse after the ramp-down, which brings the FIR to zero
                pulse.add_wave("dummy")

        return pulse

class MultiplexedGenManager(AbsGenManager):
    """Manager for the muxed signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'mask', 'length']}
    PARAMS_OPTIONAL = {'const': []}
    PARAMS_NUMERIC = ['length']

    def params2wave(self, maskreg, lenreg):
        cfgreg = maskreg
        if self.tmux_ch is not None:
            cfgreg += (self.tmux_ch << 8)
        if isinstance(lenreg, QickRawParam):
            if lenreg.maxval() >= 2**32 or lenreg.minval() < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 32 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        else:
            if lenreg >= 2**32 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 32 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        wavereg = Waveform(freq=0, phase=0, env=0, gain=0, length=lenreg, conf=cfgreg)
        return wavereg

    def params2pulse(self, par):
        pulse = QickPulse(self.prog, self, par)
        lenreg = self.prog.us2cycles(gen_ch=self.ch, us=par['length'])

        tones = self.prog.gen_chs[self.ch]['mux_tones']
        maskreg = 0
        for maskch in par['mask']:
            if maskch not in range(len(tones)):
                raise RuntimeError("mask includes tone %d, but only %d tones are declared" % (maskch, len(tones)))
            maskreg |= (1 << maskch)
        pulse.add_wave(self.params2wave(lenreg=lenreg, maskreg=maskreg))
        return pulse

class ReadoutManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = ['freq']
    PARAMS_OPTIONAL = ['length', 'phase', 'phrst', 'mode', 'outsel', 'gen_ch']
    PARAMS_NUMERIC = ['freq', 'length', 'phase']

    def __init__(self, prog, ro_ch):
        self.ch = ro_ch
        chcfg = prog.soccfg['readouts'][self.ch]
        super().__init__(prog, chcfg, "readout %d"%(self.ch))
        self.tproc_ch = chcfg['tproc_ctrl']
        self.tmux_ch = chcfg.get('tmux_ch') # default to None if undefined
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

        pulse_params = {}
        for k,v in params.items():
            if k in self.PARAMS_NUMERIC and not isinstance(v, QickParam):
                pulse_params[k] = QickParam(start=v, spans={})
            else:
                pulse_params[k] = copy.copy(v)
        return pulse_params

    def params2pulse(self, par):
        """Write whichever pulse registers are fully determined by the defined parameters.

        Parameters
        ----------
        par : dict
            Pulse parameters
        """
        pulse = QickPulse(self.prog, self, par)

        # convert the requested freq, frequency-matching to the generator if specified
        # freqreg may be an int or a QickRawParam
        # if the matching generator has a mixer, that frequency needs to be added to this one
        # it should already be rounded to the readout and mixer frequency steps, so no additional rounding is needed
        # the relevant quantization step is still going to be the readout+generator step
        if 'gen_ch' in par and 'mixer_freq' in self.prog.gen_chs[par['gen_ch']]:
            # the mixer_freq should already be rounded to a valid RO freq (by specifying ro_ch in declare_gen)
            # but we round here anyway - TODO: we could warn if it's not rounded
            mixer_freq = self.prog.gen_chs[par['gen_ch']]['mixer_freq']['rounded']
            mixer_freq = self.prog.roundfreq(mixer_freq, [self.chcfg])
        else:
            mixer_freq = 0
        if self.prog.ABSOLUTE_FREQS:
            f_dds = par['freq'] - mixer_freq
        else:
            f_dds = par['freq']
        freqreg = self.prog.freq2reg_adc(ro_ch=self.ch, f=f_dds, gen_ch=par.get('gen_ch'))
        freqreg += self.prog.freq2reg_adc(ro_ch=self.ch, f=mixer_freq)
        if self.prog.FLIP_DOWNCONVERSION: freqreg *= -1

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
        if isinstance(lenreg, QickRawParam):
            if lenreg.maxval() >= 2**16 or lenreg.minval() < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))
        else:
            if lenreg >= 2**16 or lenreg < 3:
                raise RuntimeError("Pulse length of %d cycles is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the envelope" % (lenreg))

        confpars = {k:par.get(k) for k in ['outsel', 'mode', 'phrst']}
        confpars['stdysel'] = None
        confreg = self.cfg2reg(**confpars)
        pulse.add_wave(Waveform(freqreg, phasereg, 0, 0, lenreg, confreg))
        return pulse

class QickProgramV2(AsmV2, AbsQickProgram):
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
                'axis_sg_int4_v2': StandardGenManager,
                'axis_sg_mux4_v1': MultiplexedGenManager,
                'axis_sg_mux4_v2': MultiplexedGenManager,
                'axis_sg_mux4_v3': MultiplexedGenManager,
                'axis_sg_mux8_v1': MultiplexedGenManager,
                'axis_sg_mixmux8_v1': MultiplexedGenManager,
                }

    REG_ALIASES = {
               'w_freq'        : 'w0'  ,
               'w_phase'       : 'w1'  ,
               'w_env'         : 'w2'  ,
               'w_gain'        : 'w3'  ,
               'w_length'      : 'w4'  ,
               'w_conf'        : 'w5'  ,
               's_zero'        : 's0'  ,
               's_rand'        : 's1'  ,
               's_cfg'         : 's2'  ,
               's_ctrl'        : 's2'  ,
               's_arith_l'     : 's3'  ,
               's_div_q'       : 's4'  ,
               's_div_r'       : 's5'  ,
               's_core_r1'     : 's6'  ,
               's_core_r2'     : 's7'  ,
               's_port_l'      : 's8'  ,
               's_port_h'      : 's9'  ,
               's_status'      : 's10' ,
               's_usr_time'    : 's11' ,
               's_core_w1'     : 's12' ,
               's_core_w2'     : 's13' ,
               's_out_time'    : 's14' ,
               's_addr'        : 's15' ,
            }

    # duration units in declare_readout and envelope definitions are in user units (float, us), not raw (int, clock ticks)
    USER_DURATIONS = True
    # frequencies are always absolute, even if there's a digital mixer invovled
    ABSOLUTE_FREQS = True
    # downconversion frequencies are negative
    FLIP_DOWNCONVERSION = True

    def __init__(self, soccfg):
        super().__init__(soccfg)

        ASM_REVISION = 21
        if self.tproccfg['type']!='qick_processor':
            raise RuntimeError("tProc v2 programs can only be run on a tProc v2 firmware")
        if self.tproccfg['revision']!=ASM_REVISION:
            raise RuntimeError("this version of the QICK library only supports tProc v2 revision %d, you have %d"%(ASM_REVISION, self.tproccfg['revision']))

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
        # preprocessing: allocate registers, convert params from physical units to ASM values, define the timeline
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
        # this also gets reset in AsmV2.__init__(), but that's OK
        self.macro_list = []

        # generator managers handle a gen's envelopes and add_pulse logic
        self._gen_mgrs = [self.gentypes[ch['type']](self, iCh) for iCh, ch in enumerate(self.soccfg['gens'])]
        self._ro_mgrs = [ReadoutManager(self, iCh) if 'tproc_ctrl' in ch else None for iCh, ch in enumerate(self.soccfg['readouts'])]

        # pulses are software constructs, each is a set of 1 or more waveforms
        self.pulses = {}

        # waveforms consist of initial parameters (to be written to the wave memory) and sweeps (to be applied when looping)
        self.waves = []
        self.wave2idx = {}

        # allocated registers
        self.reg_dict = {}

    def _init_instructions(self):
        # initialize the low-level objects that get filled by macro expansion

        # this will also reset self.binprog
        super()._init_instructions()

        # high-level program structure

        self.time_dict = {} # lookup dict for timed instructions with tags

        self.loop_dict = OrderedDict()
        self.loop_stack = []

        # low-level ASM management

        # the initial values here are copied from command_recognition() and label_recognition() in tprocv2_assembler.py
        self.prog_list = [{'P_ADDR':1, 'LINE':2, 'CMD':'NOP'}]
        self.labels = {'s15': 's15'} # register 15 predefinition
        # address in program memory
        self.p_addr = 1
        # line number
        self.line = 2

    def load_prog(self, progdict):
        # note that we only dump+load the raw waveforms and ASM (the low-level stuff that gets converted to binary)
        # we don't load the macros, pulses, or sweeps (the high-level stuff that gets translated to the low-level stuff)
        super().load_prog(progdict)
        # re-create the Waveform objects
        self.waves = [Waveform(**w) for w in self.waves]
        # make the binary (this will prevent compile() from running and wiping out the low-level stuff)
        self._make_binprog()

    def _compile_prog(self):
        # the assembler modifies some of the command dicts, so do a copy first
        plist_copy = copy.deepcopy(self.prog_list)
        _, p_mem = Assembler.list2bin(plist_copy, self.labels)
        return p_mem

    def _compile_waves(self):
        if self.waves:
            return [w.compile().tolist() for w in self.waves]
        else:
            return None

    def compile_datamem(self):
        """Generate the data that should be written to data memory before running the program.
        For basic QICK programs no data needs to be written, and this method returns no values.
        If you need to write data, you should override this method.

        Returns
        -------
        ndarray of int32 or None
            data to write
        """
        d_mem = None
        return d_mem

    def compile(self):
        self._make_asm()
        self._make_binprog()

    def _make_binprog(self):
        # convert the low-level program definition (ASM and waveform list) to binary
        self.binprog = {}
        self.binprog['pmem'] = self._compile_prog()
        self.binprog['wmem'] = self._compile_waves()
        self.binprog['dmem'] = self.compile_datamem()

    def _make_asm(self):
        # convert the high-level program definition (macros and pulses) to low-level (ASM and waveform list)

        # reset the low-level program objects
        self._init_instructions()

        for macro in self.macro_list:
            # get the loop names and counts and fill the loop dict
            # this needs to be done first, to convert sweeps to steps
            if isinstance(macro, OpenLoop):
                if macro.name in self.loop_dict:
                    raise RuntimeError("loop name %s is already used"%(macro.name))
                self.loop_dict[macro.name] = macro.n
            # fill the dict for looking up tagged instructions
            # this could be done at any time
            if isinstance(macro, TimedMacro) and hasattr(macro, "tag") and macro.tag is not None:
                if macro.tag in self.time_dict:
                    raise RuntimeError("two instructions have the same tag %s"%(macro.tag))
                self.time_dict[macro.tag] = macro
        # compute step sizes for sweeps
        # this need to happen before preprocess, because it determines pulse lengths
        for w in self.waves:
            w.fill_steps(self.loop_dict)
        # preprocess macros
        # this means stepping through the timeline (evaluating "auto" times etc.)
        for i, macro in enumerate(self.macro_list):
            macro.preprocess(self)
        # initialize sweep registers
        for k,v in self.reg_dict.items():
            if v.init is not None:
                WriteReg(dst=k, src=v.init.start).translate(self)
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
        if label in self.labels:
            raise RuntimeError("label %s is already defined"%(label))
        self.line += 1
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

    # waves+pulses

    def _register_wave(self, wave, wavename):
        if wavename in self.wave2idx:
            raise RuntimeError("waveform name %s is already used"%(wavename))
        self.waves.append(wave)
        self.wave2idx[wavename] = len(self.waves)-1
        wave.name = wavename

    def _register_pulse(self, pulse, pulsename):
        if pulsename in self.pulses:
            raise RuntimeError("pulse name %s is already used"%(pulsename))
        self.pulses[pulsename] = pulse
        i = 0
        for wave in pulse.waveforms:
            # if this is a waveform name, the waveform itself is already registered and we can skip it
            if not isinstance(wave, Waveform):
                continue
            while True:
                wavename = "%s_w%d" % (pulsename, i)
                if wavename not in self.wave2idx:
                    self._register_wave(wave, wavename)
                    break
                i += 1

    def _get_wave(self, wavename):
        return self.waves[self.wave2idx[wavename]]

    def add_raw_pulse(self, name, waveforms, gen_ch=None, ro_ch=None):
        """Add a pulse defined as a list of waveforms.
        The waveforms can be defined as raw Waveform objects, or names of waveforms that are already defined in the program.

        This is usually only useful for testing and debugging.
        If you need the pulse length to be defined (e.g. if playing this pulse on a generator), you must specify one of gen_ch and ro_ch.

        Parameters
        ----------
        name : str
            name of the pulse
        waveforms : list of Waveform or str
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

        pulse = QickPulse(self, ch_mgr)
        for w in waveforms:
            pulse.add_wave(w)
        self._register_pulse(pulse, name)

    def add_pulse(self, ch, name, **kwargs):
        """Add a pulse to the program's pulse library.
        See the relevant generator manager for the list of supported pulse styles and parameters.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            name of the pulse
        ro_ch : int or None, optional
            Readout channel to frequency-match to. For a muxed generator, pass this argument to declare_gen() instead.
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
        pulse = self._gen_mgrs[ch].make_pulse(kwargs)
        self._register_pulse(pulse, name)

    def add_readoutconfig(self, ch, name, **kwargs):
        """Add a readout config to the program's pulse library.
        The "mode" and "length" parameters have no useful effect and should probably never be used.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        name : str
            name of the config
        freq : float or QickParam
            Frequency (MHz)
        phase : float or QickParam
            Phase (degrees)
        phrst : int
            If 1, it resets the DDS phase. The default is 0.
        mode : str
            Selects whether the output is "oneshot" (the default) or "periodic."
        outsel : str
            Selects the output source. The input is real, the output is complex. If "product" (the default), the output is the product of input and DDS. If "dds", the output is the DDS only. If "input", the output is from the input. If "zero", the output is always zero.
        length : float or QickParam
            The duration (us) of the config pulse. The default is the shortest possible length.
        """
        pulse = self._ro_mgrs[ch].make_pulse(kwargs)
        self._register_pulse(pulse, name)

    def list_pulse_waveforms(self, pulsename, exclude_special=True):
        """Get the names of the waveforms in a given pulse.
        This is normally useful if you need to loop over them in your program, for example to change some parameter.

        Parameters
        ----------
        pulsename : str
            Name of the pulse
        exclude_special : bool
            Exclude the "dummy" and "phrst" waveforms (which have no parameters you'd want to manipulate) from the list

        Returns
        -------
        list of str
            Waveform names
        """
        return self.pulses[pulsename].get_wavenames(exclude_special=exclude_special)

    def list_pulse_params(self, pulsename):
        """Get the list of parameters you can look up for a given pulse with get_pulse_param().

        Parameters
        ----------
        pulsename : str
            Name of the pulse

        Returns
        -------
        list of str
            Parameter names
        """
        pulse = self.pulses[pulsename]
        return pulse.numeric_params

    def get_pulse_param(self, pulsename, parname, as_array=False):
        """Get the fully rounded value of a pulse parameter, in the same units that are used to specify the parameter in add_pulse().
        By default, a swept parameter will be returned as a QickParam.
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
            If the parameter is swept, return an array instead of a QickParam

        Returns
        -------
        float, QickParam, or array
            Parameter value
        """
        # if the parameter is swept, it's not fully defined until the loop macros have been processed
        if self.binprog is None:
            raise RuntimeError("get_pulse_param() can only be called on a program after it's been compiled")

        pulse = self.pulses[pulsename]
        if parname not in pulse.numeric_params:
            raise RuntimeError("invalid parameter name; use list_pulse_params() to get the list of valid names for this pulse")
        if parname=='total_length':
            # this should always be a QickParam, and it should already be rounded
            param = pulse.get_length()
        else:
            # this should always be a QickParam
            # steps should already be defined, so we can get the rounded sweep without supplying a loop dict
            param = pulse.params[parname].get_rounded()

        # if the parameter's not really swept, we just return the scalar
        if as_array: return param.to_array(self.loop_dict)
        elif param.is_sweep(): return param
        else: return float(param)

    def list_time_params(self, tag):
        """Get the list of parameters you can look up for a given timed instruction with get_time_param().

        Returns
        -------
        list of str
            Parameter names
        """
        inst = self.time_dict[tag]
        return inst.list_time_params()

    def get_time_param(self, tag, parname, as_array=False):
        """Get the fully rounded value of a time parameter of a timed instruction, in microseconds.
        You must have supplied a "tag" for the timed instruction.

        By default, a swept parameter will be returned as a QickParam.
        If instead you ask for an array, the array will have a dimension for each loop where the parameter is swept.
        The dimensions will be ordered by the loop order.

        The rounded value is only available after the program has been compiled (or run).
        So you can't call this method from inside your program definition.

        Parameters
        ----------
        tag : str
            Tag for the timed instruction.
        parname : str
            Name of the parameter
        as_array : bool
            If the parameter is swept, return an array instead of a QickParam

        Returns
        -------
        float, QickParam, or array
            Parameter value
        """
        inst = self.time_dict[tag]
        param = inst.get_time_param(parname)
        # if the parameter's not really swept, we just return the scalar
        if as_array: return param.to_array(self.loop_dict)
        elif param.is_sweep(): return param
        else: return float(param)

    # register management

    def add_reg(self, name: str = None, addr: int = None, init: QickRawParam = None, allow_reuse: bool = False):
        """Declare a new data register.

        Parameters
        ----------
        name : str
            Requested register name, must be unused.
            If None, a name will be chosen for you and returned.
        addr : int
            Requested register address, must be unused.
            If None, an address will be chosen for you.
        init : QickRawParam
            Initial value, to be swept in loops.
            This is used for swept times, and is not recommended for user code.
        allow_reuse : bool
            Allow reusing the same name.
            This is usually used for scratch registers that get used briefly.
            "init" and "addr" params must be None.

        Returns
        -------
        str
            Register name
        """
        if allow_reuse:
            if init is not None or addr is not None:
                raise ValueError("for allow_reuse=True, init and addr parameters must be left as None")
            if name in self.reg_dict:
                if self.reg_dict[name].init is not None:
                    raise RuntimeError("for allow_reuse=True, previously allocated register must not have an init value")
                return name

        assigned_addrs = set([v.addr for v in self.reg_dict.values()])
        if addr is None:
            addr = 0
            while addr in assigned_addrs:
                addr += 1
            if addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise RuntimeError(f"all data registers are assigned.")
        else:
            if addr < 0 or addr >= self.soccfg['tprocs'][0]['dreg_qty']:
                raise ValueError(f"register address must be smaller than {self.soccfg['tprocs'][0]['dreg_qty']}")
            if addr in assigned_addrs:
                raise ValueError(f"register at address {addr} is already occupied.")
        reg = QickRegisterV2(addr=addr, init=init)

        if name is None:
            name = reg.full_addr()
        if name in self.reg_dict:
            raise NameError(f"register name '{name}' already exists")
        if name in self.REG_ALIASES:
            raise NameError(f"register name '{name}' is reserved for use as a register alias")
        elif self._is_addr(name) and name != reg.full_addr():
            # if the requested name is a register address, the name must be the same as the address
            raise NameError(f"requested name {name} is reserved for use as a register address")

        self.reg_dict[name] = reg
        return name

    def _get_reg(self, name):
        """Get the full ASM address of a previously defined register.
        For internal use.

        Parameters
        ----------
        name : str
            Register name, can be a user-defined name or an ASM address.
        """
        if self._is_addr(name):
            return name
        if name in self.REG_ALIASES:
            return self.REG_ALIASES[name]
        return self.reg_dict[name].full_addr()

    def _is_addr(self, name: str):
        """Checks if a string is a valid ASM address.
        """
        try:
            addr = int(name[1:])
            if addr<0: return False
            if name[0]=='s': # special register
                return addr<16
            elif name[0]=='w': # waveform register
                return addr<6
            elif name[0]=='r': # data register
                return addr<self.soccfg['tprocs'][0]['dreg_qty']
            else:
                return False
        except ValueError:
            return False

class AcquireProgramV2(AcquireMixin, QickProgramV2):
    """Base class for tProc v2 programs with shot counting and readout acquisition.
    You will need to define the acquisition structure with setup_acquire().
    If you just want shot counting and run_rounds(), you can use setup_counter().
    """
    pass

class AveragerProgramV2(AcquireProgramV2):
    """Use this as a base class to build looping programs.
    You are responsible for writing _initialize() and _body(); you may optionally write a _cleanup().
    The content of your _body() - a "shot" - will be run inside nested loops, where the outermost loop is run "reps" times, and you can add loop levels with add_loop().
    The returned data will be averaged over the "reps" axis.

    This is similar to the NDAveragerProgram from tProc v1.
    (Note that the order of user loops is reversed: first added is outermost, not innermost)

    Parameters
    ----------
    soccfg : QickConfig
        The QICK firmware configuration dictionary.
    cfg : dict
        Your program configuration dictionary.
        There are no required entries, this is for your use and can be accessed as self.cfg in your _initialize() and _body().
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
    reps_innermost : bool
        If true, the "reps" loop will be the innermost loop (sweep once and take N shots at each step).
        Time-varying fluctuations will tend to appear as wiggles/jumps.
        If false, reps will be outermost (sweep N times and take 1 shot at each step).
        Time-varying fluctuations will tend to be averaged out.
    before_reps : AsmV2
        Instructions to execute before the contents of the "reps" loop.
    after_reps : AsmV2
        Instructions to execute after the contents of the "reps" loop.
    """

    COUNTER_ADDR = 1
    def __init__(self, soccfg, reps, final_delay, final_wait=0, initial_delay=1.0, reps_innermost=False, before_reps=None, after_reps=None, cfg=None):
        self.cfg = {} if cfg is None else cfg.copy()
        self.reps = reps
        self.final_delay = final_delay
        self.final_wait = final_wait
        self.initial_delay = initial_delay
        self.reps_innermost = reps_innermost
        self.before_reps = before_reps
        self.after_reps = after_reps
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
        self.loops = [("reps", self.reps, self.before_reps, self.after_reps)]

        # prepare the subroutine dict
        self.subroutines = {}

        # make_program() should add all the declarations and macros
        self.make_program()

        # process macros, generate ASM and waveform list, generate binary program
        super().compile()

        # use the loop list to set up the data shape
        self.setup_acquire(counter_addr=self.COUNTER_ADDR, loop_dims=[x[1] for x in self.loops], avg_level=0)

    def add_loop(self, name, count, exec_before=None, exec_after=None):
        """Add a loop level to the program.
        The first level added will be the outermost loop (after the reps loop).

        exec_before and exec_after allow you to specify instructions that should execute at this loop level (inside this loop, before or after the contents of the loop).
        This might be useful for configuring readouts or triggering external equipment.

        Parameters
        ----------
        name : str
            Name of this loop level.
            This should match the name used in your sweeps.
        count : int
            Number of iterations for this loop.
        exec_before : AsmV2
            Instructions to execute before the contents of this loop.
        exec_after : AsmV2
            Instructions to execute after the contents of this loop.
        """
        theloop = (name, count, exec_before, exec_after)
        if self.reps_innermost:
            self.loops.insert(len(self.loops)-1, theloop)
        else:
            self.loops.append(theloop)

    def add_subroutine(self, name, asm):
        if name in self.subroutines:
            raise RuntimeError("subroutine %s is already defined"%(name))
        self.subroutines[name] = asm

    @abstractmethod
    def _initialize(self, cfg):
        """Do inital setup of your program and the QICK.
        This is where you should put any ASM commands (register operations, setup pulses) that need to be played before the shot loops begin.
        It's also conventional to put program declarations here (though because these are executed by Python and not the tProc it doesn't really matter, they just need to be executed).

        User code should not call this method; it's called by make_program().
        """
        pass

    @abstractmethod
    def _body(self, cfg):
        """Play a shot.
        This is where you should put pulses and readout triggers.

        User code should not call this method; it's called by make_program().
        """
        pass

    def _cleanup(self, cfg):
        """Do any cleanup for your program.
        Instructions you put here will execute after all loops are complete.
        This might be used to send trigger pulses to external equipment or turn off periodic pulses.
        Overriding this method is optional, and most measurements don't use this.

        User code should not call this method; it's called by make_program().
        """
        pass

    def make_program(self):
        # play the initialization
        self.set_ext_counter(addr=self.COUNTER_ADDR)
        self._initialize(self.cfg)
        if self.initial_delay is not None:
            self.delay_auto(self.initial_delay)

        for name, count, before, after in self.loops:
            self.open_loop(count, name=name)
            if before is not None: self.extend_macros(before)

        # play the shot
        self._body(self.cfg)
        if self.final_wait is not None:
            self.wait_auto(self.final_wait, no_warn=True)
        if self.final_delay is not None:
            self.delay_auto(self.final_delay)
        self.inc_ext_counter(addr=self.COUNTER_ADDR)

        # close the loops - order doesn't matter
        for name, count, before, after in self.loops:
            if after is not None: self.extend_macros(after)
            self.close_loop()

        self._cleanup(self.cfg)

        self.end()

        # subroutines go after the main program
        for name, asm in self.subroutines.items():
            self.label(name)
            self.extend_macros(asm)
            self.ret()
