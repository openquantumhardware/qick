"""
Assembly language wrapper class and auxiliary functions for the v1 tProcessor.
"""
import logging
import numpy as np
import json
from collections import namedtuple, OrderedDict, defaultdict
from typing import Union, List
from abc import ABC, abstractmethod

from .qick_asm import AbsQickProgram
from .helpers import ch2list
from .parser import parse_prog

RegisterType = ["freq", "time", "phase", "adc_freq"]
DefaultUnits = {"freq": "MHz", "time": "us", "phase": "deg", "adc_freq": "MHz"}
MathOperators = ["+", "-", "*"]
logger = logging.getLogger(__name__)

class AbsRegisterManager(ABC):
    """Generic class for managing registers that will be written to a tProc-controlled block (signal generator or readout).
    """
    PULSE_REGISTERS = ["freq", "phase", "addr", "gain", "mode", "t", "addr2", "gain2", "mode2", "mode3"]

    def __init__(self, prog, tproc_ch, ch_name):
        self.prog = prog
        # the tProc output channel controlled by this manager
        self.tproc_ch = tproc_ch
        # the name of this block (for messages)
        self.ch_name = ch_name
        # the register page and register map for this manager
        # these are initialized by QickProgram._allocate_registers
        self.rp = None
        self.regmap = None
        # default parameters
        self.defaults = {}
        # registers that are fully defined by the default parameters
        self.default_regs = set()
        # the registers to be used in the next "set" command
        self.next_pulse = None
        # registers values used in the last set_registers() call
        self.last_set_regs = {}

    def set_reg(self, name, val, comment=None, defaults=False):
        """Wrapper around regwi.
        Looks up the register name and keeps track of whether the register already has a default value.

        Parameters
        ----------
        name : str
            Register name
        val : int
            Register value
        comment : str
            Comment to be printed in ASM output
        defaults : bool
            This is a default value, which doesn't need to be rewritten for every pulse

        """
        if defaults:
            self.default_regs.add(name)
        elif name in self.default_regs:
            # this reg was already written, so we skip it this time
            return
        rp, r = self.regmap[(self.ch, name)]
        if comment is None: comment = f'{name} = {val}'
        self.prog.safe_regwi(rp, r, val, comment)

    def set_defaults(self, kwargs):
        """Set default values for parameters.
        This is called by QickProgram.set_default_registers().

        Parameters
        ----------
        kwargs : dict
            Parameter values

        """
        if self.defaults:
            # complain if the default parameter dict is not empty
            raise RuntimeError("%s already has a set of default parameters"%(self.ch_name))
        self.defaults = kwargs
        self.write_regs(kwargs, defaults=True)

    def set_registers(self, kwargs):
        """Set pulse parameters.
        This is called by QickProgram.set_pulse_registers().

        Parameters
        ----------
        kwargs : dict
            Parameter values

        """
        self.last_set_regs = kwargs
        if not self.defaults.keys().isdisjoint(kwargs):
            raise RuntimeError("these params were set for {0} both in default_pulse_registers and set_pulse_registers: {1}".format(self.ch_name, self.defaults.keys() & kwargs.keys()))
        merged = {**self.defaults, **kwargs}
        # check the final param set for validity
        self.check_params(merged)
        self.write_regs(merged, defaults=False)

    @abstractmethod
    def check_params(self, params):
        ...

    @abstractmethod
    def write_regs(self, params, defaults):
        ...

class ReadoutManager(AbsRegisterManager):
    """Manages the frequency and mode registers for a tProc-controlled readout channel.
    """
    PARAMS_REQUIRED = ['freq', 'length']
    PARAMS_OPTIONAL = ['phrst', 'mode', 'outsel']

    def __init__(self, prog, ro_ch):
        self.ch = ro_ch
        self.rocfg = prog.soccfg['readouts'][self.ch]
        tproc_ch = self.rocfg['tproc_ctrl']
        super().__init__(prog, tproc_ch, "readout %d"%(self.ch))

    def check_params(self, params):
        """Check whether the parameters defined for a pulse are supported and sufficient for this generator and pulse type.
        Raise an exception if there is a problem.

        Parameters
        ----------
        params : dict
            Parameter values

        """
        required = set(self.PARAMS_REQUIRED)
        allowed = required | set(self.PARAMS_OPTIONAL)
        defined = params.keys()
        if required - defined:
            raise RuntimeError("missing required pulse parameter(s)", required - defined)
        if defined - allowed:
            raise RuntimeError("unsupported pulse parameter(s)", defined - allowed)

    def write_regs(self, params, defaults):
        if 'freq' in params:
            self.set_reg('freq', params['freq'], defaults=defaults)
        if not defaults:
            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []

            # these mode bits could be defined, or left as None
            phrst, mode, outsel = [params.get(x) for x in ['phrst', 'mode', 'outsel']]
            mc = self.get_mode_code(phrst=phrst, mode=mode, outsel=outsel, length=params['length'])
            self.set_reg('mode', mc, f'mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            self.next_pulse['regs'].append([self.regmap[(self.ch, x)][1] for x in ['freq', '0', 'mode', '0', '0']])

    def get_mode_code(self, length, outsel=None, mode=None, phrst=None):
        """Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        Parameters
        ----------
        length : int
            The number of ADC fabric cycles in the pulse

        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q.
            The default is "product".

            * If "product", the output is the product of table and DDS.

            * If "dds", the output is the DDS only.

            * If "input", the output is from the table for the real part, and zeros for the imaginary part.

            * If "zero", the output is always zero.

        mode : str
            Selects whether the output is "oneshot" or "periodic". The default is "oneshot".

        phrst : int
            If 1, it resets the phase coherent accumulator. The default is 0.

        Returns
        -------
        int
            Compiled mode code in binary

        """
        if length >= 2**16 or length < 3:
            raise RuntimeError("Pulse length of %d is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (length))
        if outsel is None: outsel = "product"
        if mode is None: mode = "oneshot"
        if phrst is None: phrst = 0

        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        mc = phrst*0b01000+mode_reg*0b00100+outsel_reg
        return mc << 16 | np.uint16(length)


class AbsGenManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = {}
    PARAMS_OPTIONAL = {}

    def __init__(self, prog, gen_ch):
        self.ch = gen_ch
        self.gencfg = prog.soccfg['gens'][self.ch]
        tproc_ch = self.gencfg['tproc_ch']
        super().__init__(prog, tproc_ch, "generator %d"%(self.ch))
        self.samps_per_clk = self.gencfg['samps_per_clk']
        self.tmux_ch = self.gencfg.get('tmux_ch') # default to None if undefined

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

    def get_mode_code(self, length, mode=None, outsel=None, stdysel=None, phrst=None):
        """Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        Parameters
        ----------
        length : int
            The number of DAC fabric cycles in the pulse
        mode : str
            Selects whether the output is "oneshot" or "periodic". The default is "oneshot".
        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q.
            The default is "product".

            * If "product", the output is the product of table and DDS. 

            * If "dds", the output is the DDS only. 

            * If "input", the output is from the table for the real part, and zeros for the imaginary part. 
            
            * If "zero", the output is always zero.

        stdysel : str
            Selects what value is output continuously by the signal generator after the generation of a pulse.
            The default is "zero".

            * If "last", it is the last calculated sample of the pulse.

            * If "zero", it is a zero value.

        phrst : int
            If 1, it resets the phase coherent accumulator. The default is 0.

        Returns
        -------
        int
            Compiled mode code in binary

        """
        if mode is None: mode = "oneshot"
        if outsel is None: outsel = "product"
        if stdysel is None: stdysel = "zero"
        if phrst is None: phrst = 0
        if length >= 2**16 or length < 3:
            raise RuntimeError("Pulse length of %d is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (length))
        stdysel_reg = {"last": 0, "zero": 1}[stdysel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mc = phrst*0b10000+stdysel_reg*0b01000+mode_reg*0b00100+outsel_reg
        return mc << 16 | np.uint16(length)

class FullSpeedGenManager(AbsGenManager):
    """Manager for the full-speed (non-interpolated, non-muxed) signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'waveform'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'waveform']}
    PARAMS_OPTIONAL = {'const': ['phrst', 'stdysel', 'mode'],
            'arb': ['phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['phrst', 'stdysel']}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_envelope to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the waveform is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length waveform with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        for parname in ['freq', 'phase', 'gain']:
            if parname in params:
                self.set_reg(parname, params[parname], defaults=defaults)
        if 'waveform' in params:
            pinfo = self.envelopes[params['waveform']]
            wfm_length = pinfo['data'].shape[0] // self.samps_per_clk
            addr = pinfo['addr'] // self.samps_per_clk
            self.set_reg('addr', addr, defaults=defaults)
        if not defaults:
            style = params['style']
            # these mode bits could be defined, or left as None
            phrst, stdysel, mode, outsel = [params.get(x) for x in ['phrst', 'stdysel', 'mode', 'outsel']]

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []
            if style=='const':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', '0', 'gain', 'mode']])
                self.next_pulse['length'] = params['length']
            elif style=='arb':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=wfm_length)
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', 'addr', 'gain', 'mode']])
                self.next_pulse['length'] = wfm_length
            elif style=='flat_top':
                # address for ramp-down
                self.set_reg('addr2', addr+(wfm_length+1)//2)
                # gain for flat segment
                self.set_reg('gain2', params['gain']//2)
                # mode for ramp up
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode='oneshot', outsel='product', length=wfm_length//2)
                self.set_reg('mode2', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for flat segment
                mc = self.get_mode_code(phrst=False, stdysel=stdysel, mode='oneshot', outsel='dds', length=params['length'])
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for ramp down
                mc = self.get_mode_code(phrst=False, stdysel=stdysel, mode='oneshot', outsel='product', length=wfm_length//2)
                self.set_reg('mode3', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', 'addr', 'gain', 'mode2']])
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', '0', 'gain2', 'mode']])
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', 'addr2', 'gain', 'mode3']])
                self.next_pulse['length'] = (wfm_length//2)*2 + params['length']

    def get_mode_code(self, **kwargs):
        mc = super().get_mode_code(**kwargs)
        if self.tmux_ch is not None:
            mc += (self.tmux_ch << 24)
        return mc


class InterpolatedGenManager(AbsGenManager):
    """Manager for the interpolated signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'waveform'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'waveform']}
    PARAMS_OPTIONAL = {'const': ['phrst', 'stdysel', 'mode'],
            'arb': ['phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['phrst', 'stdysel']}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_envelope to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the waveform is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length waveform with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        addr = 0
        if 'waveform' in params:
            pinfo = self.envelopes[params['waveform']]
            wfm_length = pinfo['data'].shape[0] // self.samps_per_clk
            addr = pinfo['addr'] // self.samps_per_clk
        if 'phase' in params and 'freq' in params:
            phase, freq = [params[x] for x in ['phase', 'freq']]
            self.set_reg('freq',  (phase << 16) | freq, f'phase = {phase} | freq = {freq}', defaults=defaults)
        if 'gain' in params and ('waveform' in params or params.get('style')=='const'):
            gain = params['gain']
            self.set_reg('addr',  (gain << 16) | addr, f'gain = {gain} | addr = {addr}', defaults=defaults)
        if not defaults:
            style = params['style']
            # these mode bits could be defined, or left as None
            phrst, stdysel, mode, outsel = [params.get(x) for x in ['phrst', 'stdysel', 'mode', 'outsel']]

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []

            # if we use the tproc mux, the mux address needs to be written to its own register
            if self.tmux_ch is None:
                tmux_reg = '0'
            else:
                self.set_reg('mode3', self.tmux_ch << 24)
                tmux_reg = 'mode3'

            if style=='const':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'addr', 'mode', '0', tmux_reg]])
                self.next_pulse['length'] = params['length']
            elif style=='arb':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=wfm_length)
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'addr', 'mode', '0', tmux_reg]])
                self.next_pulse['length'] = wfm_length
            elif style=='flat_top':
                maxv_scale = self.gencfg['maxv_scale']
                gain, length = [params[x] for x in ['gain', 'length']]
                # mode for flat segment
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode="oneshot", outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for ramps
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode="oneshot", outsel="product", length=wfm_length//2)
                self.set_reg('mode2', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

                # gain+addr for ramp-up
                self.set_reg('addr', (gain << 16) | addr, f'gain = {gain} | addr = {addr}')
                # gain+addr for flat
                self.set_reg('gain', (int(gain*maxv_scale/2) << 16), f'gain = {gain} | addr = {addr}')
                # gain+addr for ramp-down
                self.set_reg('addr2', (gain << 16) | addr+(wfm_length+1)//2, f'gain = {gain} | addr = {addr}')

                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'addr', 'mode2', '0', tmux_reg]])
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'gain', 'mode', '0', tmux_reg]])
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'addr2', 'mode2', '0', tmux_reg]])
                # workaround for FIR bug: we play a zero-gain DDS pulse (length equal to the flat segment) after the ramp-down, which brings the FIR to zero
                self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['0', '0', 'mode', '0', tmux_reg]])
                # set the pulse duration (including the extra duration for the FIR workaround)
                self.next_pulse['length'] = (wfm_length//2)*2 + 2*params['length']

class MultiplexedGenManager(AbsGenManager):
    """Manager for the muxed signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'mask', 'length']}
    PARAMS_OPTIONAL = {'const': []}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        Only the "const" pulse style, with the "mask" and "length" parameters, is supported.
        The frequency and gain are set at program initialization.

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        if 'length' in params:
            if params['length'] >= 2**32 or params['length'] < 3:
                raise RuntimeError("Pulse length of %d is out of range (exceeds 32 bits, or less than 3) - use multiple pulses" % (params['length']))
            self.set_reg('freq', params['length'], defaults=defaults)
        if 'mask' in params:
            val_mask = 0
            mask = params['mask']
            for maskch in mask:
                if maskch not in range(4):
                    raise RuntimeError("invalid mask specification")
                val_mask |= (1 << maskch)
            self.set_reg('phase', val_mask, f'mask = {mask}', defaults=defaults)
        if not defaults:
            style = params['style']

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []
            self.next_pulse['regs'].append([self.regmap[(self.ch,x)][1] for x in ['freq', 'phase', '0', '0', '0']])
            self.next_pulse['length'] = params['length']

class QickProgram(AbsQickProgram):
    """QickProgram is a Python representation of the QickSoc processor assembly program. It can be used to compile simple assembly programs and also contains macros to help make it easy to configure and schedule pulses."""
    # Instruction set for the tproc describing how to automatically generate methods for these instructions
    instructions = {'pushi': {'type': "I", 'bin': 0b00010000, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 0)), 'repr': "{0}, ${1}, ${2}, {3}"},
                    'popi':  {'type': "I", 'bin': 0b00010001, 'fmt': ((0, 53), (1, 41)), 'repr': "{0}, ${1}"},
                    'mathi': {'type': "I", 'bin': 0b00010010, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 0)), 'repr': "{0}, ${1}, ${2} {3} {4}"},
                    'seti':  {'type': "I", 'bin': 0b00010011, 'fmt': ((1, 53), (0, 50), (2, 36), (3, 0)), 'repr': "{0}, {1}, ${2}, {3}"},
                    'synci': {'type': "I", 'bin': 0b00010100, 'fmt': ((0, 0),), 'repr': "{0}"},
                    'waiti': {'type': "I", 'bin': 0b00010101, 'fmt': ((0, 50), (1, 0)), 'repr': "{0}, {1}"},
                    'bitwi': {'type': "I", 'bin': 0b00010110, 'fmt': ((0, 53), (3, 46), (1, 41), (2, 36), (4, 0)), 'repr': "{0}, ${1}, ${2} {3} {4}"},
                    'memri': {'type': "I", 'bin': 0b00010111, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'memwi': {'type': "I", 'bin': 0b00011000, 'fmt': ((0, 53), (1, 31), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'regwi': {'type': "I", 'bin': 0b00011001, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'setbi': {'type': "I", 'bin': 0b00011010, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},

                    'loopnz': {'type': "J1", 'bin': 0b00110000, 'fmt': ((0, 53), (1, 41), (1, 36), (2, 0)), 'repr': "{0}, ${1}, @{2}"},
                    'end':    {'type': "J1", 'bin': 0b00111111, 'fmt': (), 'repr': ""},

                    'condj':  {'type': "J2", 'bin': 0b00110001, 'fmt': ((0, 53), (2, 46), (1, 36), (3, 31), (4, 0)), 'repr': "{0}, ${1}, {2}, ${3}, @{4}"},

                    'math':  {'type': "R", 'bin': 0b01010000, 'fmt': ((0, 53), (3, 46), (1, 41), (2, 36), (4, 31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'set':  {'type': "R", 'bin': 0b01010001, 'fmt': ((1, 53), (0, 50), (2, 36), (7, 31), (3, 26), (4, 21), (5, 16), (6, 11)), 'repr': "{0}, {1}, ${2}, ${3}, ${4}, ${5}, ${6}, ${7}"},
                    'sync': {'type': "R", 'bin': 0b01010010, 'fmt': ((0, 53), (1, 31)), 'repr': "{0}, ${1}"},
                    'read': {'type': "R", 'bin': 0b01010011, 'fmt': ((1, 53), (0, 50), (2, 46), (3, 41)), 'repr': "{0}, {1}, {2} ${3}"},
                    'wait': {'type': "R", 'bin': 0b01010100, 'fmt': ((1, 53), (0, 50), (2, 31)), 'repr': "{0}, {1}, ${2}"},
                    'bitw': {'type': "R", 'bin': 0b01010101, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'memr': {'type': "R", 'bin': 0b01010110, 'fmt': ((0, 53), (1, 41), (2, 36)), 'repr': "{0}, ${1}, ${2}"},
                    'memw': {'type': "R", 'bin': 0b01010111, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"},
                    'setb': {'type': "R", 'bin': 0b01011000, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"},
                    'comment': {'fmt': ()}
                    }

    # op codes for math and bitwise operations
    op_codes = {">": 0b0000, ">=": 0b0001, "<": 0b0010, "<=": 0b0011, "==": 0b0100, "!=": 0b0101,
                "+": 0b1000, "-": 0b1001, "*": 0b1010,
                "&": 0b0000, "|": 0b0001, "^": 0b0010, "~": 0b0011, "<<": 0b0100, ">>": 0b0101,
                "upper": 0b1010, "lower": 0b0101
                }

    # To make it easier to configure pulses these special registers are reserved for each channel's pulse configuration.
    # In each page, register 0 is hard-wired with the value 0.
    # In page 0 we reserve the following additional registers:
    # 13, 14 and 15 for loop counters, 16 for the trigger bits.
    # Pairs of channels share a register page.
    # The flat_top pulse uses some extra registers.

    # Attributes to dump when saving the program to JSON.
    dump_keys = ['prog_list', 'envelopes', 'ro_chs', 'gen_chs', 'counter_addr', 'reps', 'expts', 'rounds', 'shot_angle', 'shot_threshold']

    gentypes = {'axis_signal_gen_v4': FullSpeedGenManager,
                'axis_signal_gen_v5': FullSpeedGenManager,
                'axis_signal_gen_v6': FullSpeedGenManager,
                'axis_sg_int4_v1': InterpolatedGenManager,
                'axis_sg_mux4_v1': MultiplexedGenManager,
                'axis_sg_mux4_v2': MultiplexedGenManager,
                'axis_sg_mux4_v3': MultiplexedGenManager}

    def __init__(self, soccfg):
        """
        Constructor method
        """
        super().__init__(soccfg)

        # List of commands. This may include comments.
        self.prog_list = []

        # Label to apply to the next instruction.
        self._label_next = None

        # Address of the rep counter in the data memory.
        self.counter_addr = 1
        # Number of iterations in the innermost loop.
        self.reps = None
        # Number of times the program repeats the innermost loop. None means there is no outer loop.
        self.expts = None

        # Generator managers, for keeping track of register values.
        self._gen_mgrs = [self.gentypes[ch['type']](self, iCh) for iCh, ch in enumerate(soccfg['gens'])]
        self._ro_mgrs = [ReadoutManager(self, iCh) if 'tproc_ctrl' in ch else None for iCh, ch in enumerate(soccfg['readouts'])]

        # Mapping from gen/RO channels and parameters to register pages and numbers
        self._gen_pagemap = {}
        self._gen_regmap = {}
        self._ro_pagemap = {}
        self._ro_regmap = {}
        self._allocate_registers()

        # Number of times the whole program is to be run.
        self.rounds = 1
        # Rotation angle and thresholds for single-shot readout.
        self.shot_angle = None
        self.shot_threshold = None

    def _allocate_registers(self):
        # assign tProc-controlled generator/readout channels to pages
        # we pack the first channel in page 0
        # subsequent channels are packed in pairs (which allows for 15 channels)
        # if pairs won't fit, we pack in triplets
        mgrs = [x for x in self._gen_mgrs + self._ro_mgrs if x is not None]
        if (len(mgrs)>15):
            mgrs_per_page = 3
        else:
            mgrs_per_page = 2
        groups = [[]]
        for iMgr, mgr in enumerate(mgrs):
            if iMgr % mgrs_per_page == 1: groups.append([])
            groups[-1].append(mgr)

        for page, mgrs in enumerate(groups):
            nRegs = sum([len(mgr.PULSE_REGISTERS) for mgr in mgrs])
            regnum = 32 - nRegs
            for iMgr, mgr in enumerate(mgrs):
                mgr.rp = page
                if isinstance(mgr, ReadoutManager):
                    self._ro_pagemap[mgr.ch] = page
                    mgr.regmap = self._ro_regmap
                else:
                    self._gen_pagemap[mgr.ch] = page
                    mgr.regmap = self._gen_regmap
                # for convenience, map the zero register
                mgr.regmap[(mgr.ch, '0')] = (page, 0)
                for iReg, regname in enumerate(mgr.PULSE_REGISTERS):
                    mgr.regmap[(mgr.ch, regname)] = (page, regnum)
                    regnum += 1

    def dump_prog(self):
        """
        Dump the program to a dictionary.
        This output contains all the information necessary to run the program.
        Caution: don't modify the sub-dictionaries of this dict!
        You will be modifying the original program (this is not a deep copy).
        """
        progdict = {}
        for key in self.dump_keys:
            progdict[key] = getattr(self, key)
        return progdict

    def load_prog(self, progdict):
        """
        Load the program from a dictionary.
        """
        for key in self.dump_keys:
            setattr(self, key, progdict[key])

    def config_all(self, soc, load_pulses=True, reset=False, debug=False):
        super().config_all(soc, load_pulses)

        # load this program into the soc's tproc
        soc.load_bin_program(self.compile(debug=debug), reset=reset)

    def ch_page(self, gen_ch):
        """Gets tProc register page associated with generator channel.

        Parameters
        ----------
        gen_ch : int
            generator channel (index in 'gens' list)

        Returns
        -------
        int
            tProc page number

        """
        return self._gen_pagemap[gen_ch]

    def sreg(self, gen_ch, name):
        """Gets tProc special register number associated with a generator channel and register name.

        Parameters
        ----------
        gen_ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of special register ("gain", "freq")

        Returns
        -------
        int
            tProc special register number

        """
        return self._gen_regmap[(gen_ch, name)][1]

    def ch_page_ro(self, ro_ch):
        """Gets tProc register page associated with tProc-controlled readout channel.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)

        Returns
        -------
        int
            tProc page number

        """
        return self._ro_pagemap[ro_ch]

    def sreg_ro(self, ro_ch, name):
        """Gets tProc special register number associated with a readout channel and register name.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        name : str
            Name of special register ("gain", "freq")

        Returns
        -------
        int
            tProc special register number

        """
        return self._ro_regmap[(ro_ch, name)][1]

    def add_pulse(self, ch, name, idata=None, qdata=None):
        """Adds a waveform to the waveform library within the program.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        idata : array
            I data Numpy array
        qdata : array
            Q data Numpy array

        """
        self.add_envelope(ch=ch, name=name, idata=idata, qdata=qdata)

    def default_pulse_registers(self, ch, **kwargs):
        """Set default values for pulse parameters.
        If any registers can be written at this point, write them in order to save time later.
        
        This is optional (you can set all parameters in set_pulse_registers).
        You can only call this method once per channel.
        There cannot be any overlap between the parameters defined here and the parameters you define in set_pulse_registers.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        **kwargs : dict
            Pulse parameters

        """
        self._gen_mgrs[ch].set_defaults(kwargs)

    def set_pulse_registers(self, ch, **kwargs):
        """Set the pulse parameters including frequency, phase, address of pulse, gain, stdysel, mode register (compiled from length and other flags), outsel, and length.
        The time is scheduled when you call pulse().
        See the write_regs() method of the relevant generator manager for the list of supported pulse styles.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        style : str
            Pulse style ("const", "arb", "flat_top")
        freq : int
            Frequency (register value)
        phase : int
            Phase (register value)
        gain : int
            Gain (DAC units)
        phrst : int
            If 1, it resets the phase coherent accumulator
        stdysel : str
            Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        mode : str
            Selects whether the output is "oneshot" or "periodic"
        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        length : int
            The number of fabric clock cycles in the flat portion of the pulse, used for "const" and "flat_top" styles
        waveform : str
            Name of the envelope waveform loaded with add_envelope(), used for "arb" and "flat_top" styles
        mask : list of int
            for a muxed signal generator, the list of tones to enable for this pulse
        """
        self._gen_mgrs[ch].set_registers(kwargs)

    def set_readout_registers(self, ch, **kwargs):
        """Set the readout parameters including frequency, mode, outsel, and length.
        The time is scheduled when you call readout().

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        freq : int
            Frequency (register value)
        phrst : int
            If 1, it resets the phase coherent accumulator
        mode : str
            Selects whether the output is "oneshot" or "periodic"
        outsel : str
            Selects the output source. The output is complex. The input comes from the ADC and is purely real. If "product", the output is the product of input and DDS. If "dds", the output is the DDS only. If "input", the output is from the input for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        length : int
            The number of fabric clock cycles for which these readout parameters are defined.
        """
        self._ro_mgrs[ch].set_registers(kwargs)

    def default_readout_registers(self, ch, **kwargs):
        """Set default values for readout parameters.
        If any registers can be written at this point, write them in order to save time later.

        This is optional (you can set all parameters in set_readout_registers).
        You can only call this method once per channel.
        There cannot be any overlap between the parameters defined here and the parameters you define in set_readout_registers.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        **kwargs : dict
            Pulse parameters

        """
        self._ro_mgrs[ch].set_defaults(kwargs)

    def readout(self, ch, t):
        """Play the pulse currently programmed into the registers for this tProc-controlled readout channel.
        You must have already run set_readout_registers for this channel.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        t : int
            The number of tProc cycles at which the pulse starts
        """
        # try to convert pulse_ch to int; if that fails, assume it's list of ints
        ch_list = ch2list(ch)
        for ch in ch_list:
            tproc_ch = self.soccfg['readouts'][ch]['tproc_ctrl']
            rp, r_t = self._ro_regmap[(ch, 't')]
            next_pulse = self._ro_mgrs[ch].next_pulse
            if next_pulse is None:
                raise RuntimeError("no pulse has been set up for channel %d"%(ch))

            self.safe_regwi(rp, r_t, t, f't = {t}')

            for regs in next_pulse['regs']:
                self.set(tproc_ch, rp, *regs, r_t, f"ch = {ch}, pulse @t = ${r_t}")


    def setup_and_pulse(self, ch, t='auto', **kwargs):
        """Set up a pulse on this generator channel, and immediately play it.
        This is a wrapper around set_pulse_registers() and pulse(), and takes the arguments from both.
        You can only run this on a single generator channel.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        t : int, optional
            Pulse time, in tProc cycles
        **kwargs : dict
            Pulse parameters: refer to set_pulse_registers
        """
        self.set_pulse_registers(ch, **kwargs)
        self.pulse(ch, t)

    def setup_and_measure(self, adcs, pulse_ch, pins=None, adc_trig_offset=270, t='auto', wait=False, syncdelay=None, **kwargs):
        """Set up a pulse on this generator channel, and immediately do a measurement with it.
        This is a wrapper around set_pulse_registers() and measure(), and takes the arguments from both.
        You can only run this on a single generator channel.

        Parameters
        ----------
        adcs : list of int
            readout channels (index in 'readouts' list)
        pulse_ch : int
            generator channel (index in 'gens' list)
        pins : list of int, optional
            refer to trigger()
        adc_trig_offset : int, optional
            refer to trigger()
        t : int, optional
            refer to pulse()
        wait : bool, optional
            refer to measure()
        syncdelay : int, optional
            refer to measure()
        **kwargs : dict
            Pulse parameters: refer to set_pulse_registers()
        """
        self.set_pulse_registers(pulse_ch, **kwargs)
        self.measure(adcs, pulse_ch, pins=pins, adc_trig_offset=adc_trig_offset, t=t, wait=wait, syncdelay=syncdelay)

    def pulse(self, ch, t='auto'):
        """Play the pulse currently programmed into the registers for this generator channel.
        You must have already run set_pulse_registers for this channel.

        Parameters
        ----------
        ch : int or list of int
            generator channel (index in 'gens' list)
        t : int, optional
            The number of tProc cycles at which the pulse starts (None to use the time register as is, 'auto' to start whenever the last pulse ends)
        """
        # try to convert pulse_ch to int; if that fails, assume it's list of ints
        ch_list = ch2list(ch)
        for ch in ch_list:
            tproc_ch = self.soccfg['gens'][ch]['tproc_ch']
            rp, r_t = self._gen_regmap[(ch, 't')]
            next_pulse = self._gen_mgrs[ch].next_pulse
            if next_pulse is None:
                raise RuntimeError("no pulse has been set up for channel %d"%(ch))

            if t is not None:
                ts = self.get_timestamp(gen_ch=ch)
                if t == 'auto':
                    t = int(ts)
                elif t < ts:
                    print("warning: pulse time %d appears to conflict with previous pulse ending at %f?"%(t, ts))
                # convert from generator clock to tProc clock
                pulse_length = next_pulse['length']
                pulse_length *= self.tproccfg['f_time']/self.soccfg['gens'][ch]['f_fabric']
                self.set_timestamp(t + pulse_length, gen_ch=ch)
                self.safe_regwi(rp, r_t, t, f't = {t}')

            # Play each pulse segment.
            # We specify the same time for all segments and rely on the signal generator to concatenate them without gaps.
            # We could specify the "correct" times, but it's difficult to get right when the tProc and generator clocks are different.
            for regs in next_pulse['regs']:
                self.set(tproc_ch, rp, *regs, r_t, f"ch = {ch}, pulse @t = ${r_t}")

    def safe_regwi(self, rp, reg, imm, comment=None):
        """Due to the way the instructions are setup immediate values can only be 30bits before not loading properly.
        This comes up mostly when trying to regwi values into registers, especially the _frequency_ and _phase_ pulse registers.
        safe_regwi can be used wherever one might use regwi and will detect if the value is >2**30 and if so will break it into two steps, putting in the first 30 bits shifting it over and then adding the last two.

        Parameters
        ----------
        rp : int
            Register page
        reg : int
            Register number
        imm : int
            Value of the write
        comment : str, optional
            Comment associated with the write
        """
        if abs(imm) < 2**30:
            self.regwi(rp, reg, imm, comment)
        else:
            self.regwi(rp, reg, imm >> 2, comment)
            self.bitwi(rp, reg, reg, "<<", 2)
            if imm % 4 != 0:
                self.mathi(rp, reg, reg, "+", imm % 4)


    def sync_all(self, t=0, gen_t0=None):
        """Aligns and syncs all channels with additional time t.
        Accounts for both generator pulses and readout windows.
        This does not pause the tProc. gen_t0 is an optional list of
        additional delays for each individual generator channel, e.g. when 
        the channels are on different tiles so they don't natively sync.

        Parameters
        ----------
        t : int, optional
            The time offset in tProc cycles
        gen_t0 : list, optional
            List of additional delays for each individual generator channel, in tProc cycles
        """
        # subtract gen_t0 from the timestamps
        max_t = self.get_max_timestamp(gen_t0=gen_t0)
        if max_t + t > 0:
            self.synci(int(max_t + t))
            # reset all timestamps to 0 or gen_t0 (if defined)
            self.reset_timestamps(gen_t0=gen_t0)
        elif gen_t0:
            # we just want to set the timestamps to gen_t0
            self.reset_timestamps(gen_t0=gen_t0)


    def wait_all(self, t=0):
        """Pause the tProc until all ADC readout windows are complete, plus additional time t.
        This does not sync the tProc clock.

        Parameters
        ----------
        t : int, optional
            The time offset in tProc cycles
        """
        self.waiti(0, int(self.get_max_timestamp(gens=False, ros=True) + t))

    # should change behavior to only change bits that are specified
    def trigger(self, adcs=None, pins=None, ddr4=False, mr=False, adc_trig_offset=270, t=0, width=10, rp=0, r_out=16):
        """Pulse the readout(s) and marker pin(s) with a specified pulse width at a specified time t+adc_trig_offset.
        If no readouts are specified, the adc_trig_offset is not applied.

        Parameters
        ----------
        adcs : list of int
            List of readout channels to trigger (index in 'readouts' list)
        pins : list of int
            List of marker pins to pulse.
            Use the pin numbers in the QickConfig printout.
        ddr4 : bool
            If True, trigger the DDR4 buffer.
        mr : bool
            If True, trigger the MR buffer.
        adc_trig_offset : int, optional
            Offset time at which the ADC is triggered (in tProc cycles)
        t : int, optional
            The number of tProc cycles at which the ADC trigger starts
        width : int, optional
            The width of the trigger pulse, in tProc cycles
        rp : int, optional
            Register page
        r_out : int, optional
            Register number
        """
        if adcs is None:
            adcs = []
        if pins is None:
            pins = []
        #if not any([adcs, pins, ddr4]):
        #    raise RuntimeError("must pulse at least one readout or pin")

        outdict = defaultdict(int)
        for ro in adcs:
            rocfg = self.soccfg['readouts'][ro]
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
            # update trigger count for this readout
            self.ro_chs[ro]['trigs'] += 1
        for pin in pins:
            pincfg = self.soccfg['tprocs'][0]['output_pins'][pin]
            outdict[pincfg[1]] |= (1 << pincfg[2])
        if ddr4:
            rocfg = self.soccfg['ddr4_buf']
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
        if mr:
            rocfg = self.soccfg['mr_buf']
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])

        t_start = t
        if any([adcs, ddr4, mr]):
            t_start += adc_trig_offset
            # update timestamps with the end of the readout window
            for ro in adcs:
                ts = self.get_timestamp(ro_ch=ro)
                if t_start < ts:
                    print("Readout time %d appears to conflict with previous readout ending at %f?"%(t, ts))
                # convert from readout clock to tProc clock
                ro_length = self.ro_chs[ro]['length']
                ro_length *= self.tproccfg['f_time']/self.soccfg['readouts'][ro]['f_fabric']
                self.set_timestamp(t_start + ro_length, ro_ch=ro)
        t_end = t_start + width

        for outport, out in outdict.items():
            self.regwi(rp, r_out, out, f'out = 0b{out:>016b}')
            self.seti(outport, rp, r_out, t_start, f'ch =0 out = ${r_out} @t = {t}')
            self.seti(outport, rp, 0, t_end, f'ch =0 out = 0 @t = {t}')


    def measure(self, adcs, pulse_ch, pins=None, adc_trig_offset=270, t='auto', wait=False, syncdelay=None):
        """Wrapper method that combines an ADC trigger, a pulse, and (optionally) the appropriate wait and a sync_all.
        You must have already run set_pulse_registers for this channel.
        
        If you use wait=True, it's recommended to also specify a nonzero syncdelay.

        Parameters
        ----------
        adcs : list of int
            readout channels (index in 'readouts' list)
        pulse_ch : int or list of int
            generator channel(s) (index in 'gens' list)
        pins : list of int, optional
            refer to trigger()
        adc_trig_offset : int, optional
            refer to trigger()
        t : int, optional
            refer to pulse()
        wait : bool, optional
            Pause tProc execution until the end of the ADC readout window
        syncdelay : int, optional
            The number of additional tProc cycles to delay in the sync_all
        """
        self.trigger(adcs, pins=pins, adc_trig_offset=adc_trig_offset)
        self.pulse(ch=pulse_ch, t=t)
        if wait:
            # tProc should wait for the readout to complete.
            # This prevents loop counters from getting incremented before the data is available.
            self.wait_all()
        if syncdelay is not None:
            self.sync_all(syncdelay)

    def reset_phase(self, gen_ch: Union[int, List[int]] = None, ro_ch: Union[int, List[int]] = None, t: int = 0):
        """
        Reset the phase of generator and tproc-controlled readout channels at tproc time t.
        This will play an empty pulse that lasts 3 fabric clock cycles, just to trigger the phase reset.

        This command is designed to be transparent to previous 'set_pulse/readout_registers()' calls. i.e. the register
        values set using 'set_pulse/readout_registers()' before this command will remain the same after this command.
        However, pulse registers set using other functions will need to be re-set, e.g. if a pulse register value was
        set by directly calling 'regwi()', calling this function will overwrite that register value, and user need to
        redo the 'regwi()' after this phase reset.

        :param gen_ch: generator channel(s) to reset phase (index in 'gens' list)
        :param ro_ch: tProc-controlled readout channel(s) to reset phase (index in 'readouts' list)
        :param t: the number of tProc cycles at which the phase reset happens
        """
        # todo: not sure if it is possible to perform the phase reset without playing the empty pulses

        # convert gen and readout channels to lists of ints
        channels = {"generator": ch2list(gen_ch), "readout": ch2list(ro_ch)}

        # reset phase for each generator and readout channel
        for ch_type, ch_list in channels.items():
            for ch in ch_list:
                # check time and get generator/readout manager
                if ch_type == "generator":
                    ts = self.get_timestamp(gen_ch=ch)
                    if t < ts:
                        print(f"warning: generator {ch} phase reset at t={t} appears to conflict "
                              f"with previous pulse ending at {ts}")
                    ch_mgr = self._gen_mgrs[ch]
                    phrst_params = dict(style="const", phase=0, freq=0, gain=0, length=3, phrst=1)
                    tproc_ch = self.soccfg["gens"][ch]['tproc_ch']
                else:  # for readout channels
                    ch_mgr = self._ro_mgrs[ch]
                    # skip PYNQ-controlled readouts, which can't be reset
                    if ch_mgr is None: continue
                    ts = self.get_timestamp(ro_ch=ch)
                    if t < ts:
                        print(f"warning: readout {ch} phase reset at t={t} appears to conflict "
                              f"with previous readout ending at {ts}")
                    phrst_params = dict(freq=0, length=3, phrst=1)
                    tproc_ch = self.soccfg["readouts"][ch]['tproc_ctrl']

                # keeps a record of the last set registers and the default registers
                last_set_regs_ = ch_mgr.last_set_regs
                defaults_regs_ = ch_mgr.defaults
                # temporarily ignore the default registers
                ch_mgr.defaults = {}
                # set registers for phase reset
                ch_mgr.set_registers(phrst_params)

                # write phase reset time register
                if ch_type=="generator":
                    rp, r_t = self._gen_regmap[(ch, 't')]
                else:
                    rp, r_t = self._ro_regmap[(ch, 't')]
                self.safe_regwi(rp, r_t, t, f't = {t}')
                # schedule phrst at $r_t
                for regs in ch_mgr.next_pulse["regs"]:
                    self.set(tproc_ch, rp, *regs, r_t, f" {ch_type} ch{ch} phase reset @t = ${r_t}")

                # set the default and last set registers back
                ch_mgr.set_defaults(defaults_regs_)
                ch_mgr.set_registers(last_set_regs_)

        self.sync_all(3)

    def convert_immediate(self, val):
        """Convert the register value to ensure that it is positive and not too large. Throws an error if you ever try to use a value greater than 2**31 as an immediate value.

        Parameters
        ----------
        val : int
            Original register value

        Returns
        -------
        int
            Converted register value

        """
        if val > 2**31:
            raise RuntimeError(
                f"Immediate values are only 31 bits {val} > 2**31")
        if val < 0:
            return 2**31+val
        else:
            return val

    def compile_instruction(self, inst, labels, debug=False):
        """Converts an assembly instruction into a machine bytecode.

        Parameters
        ----------
        inst : dict
            Assembly instruction
        labels : dict
            Map from label name to program counter
        debug : bool
            If True, debug mode is on

        Returns
        -------
        int
            Compiled instruction in binary

        """
        args = list(inst['args'])
        idef = self.__class__.instructions[inst['name']]
        fmt = idef['fmt']

        if debug:
            print(inst)

        if idef['type'] == "I":
            args[len(fmt)-1] = self.convert_immediate(args[len(fmt)-1])

        if inst['name'] == 'loopnz':
            args[2] = labels[args[2]]  # resolve label

        if inst['name'] == 'condj':
            args[4] = labels[args[4]]  # resolve label
            # get binary condtional op code
            args[2] = self.__class__.op_codes[inst['args'][2]]

        if inst['name'][:4] == 'math':
            args[3] = self.__class__.op_codes[inst['args'][3]]  # get math op code

        if inst['name'][:4] == 'bitw':
            # get bitwise op code
            args[3] = self.__class__.op_codes[inst['args'][3]]

        if inst['name'][:4] == 'read':
            args[2] = self.__class__.op_codes[inst['args'][2]]  # get read op code

        mcode = (idef['bin'] << 56)
        # print(inst)
        for field in fmt:
            mcode |= (args[field[0]] << field[1])

        if inst['name'] == 'loopnz':
            mcode |= (0b1000 << 46)

        return mcode

    def compile(self, debug=False):
        """Compiles program to machine code.

        Parameters
        ----------
        debug : bool
            If True, debug mode is on

        Returns
        -------
        list of int
            List of binary instructions

        """
        labels = {}
        # Scan the ASM instructions for labels. Skip comment lines.
        prog_counter = 0
        for inst in self.prog_list:
            if inst['name']=='comment':
                continue
            if 'label' in inst:
                if inst['label'] in labels:
                    raise RuntimeError("label used twice:", inst['label'])
                labels[inst['label']] = prog_counter
            prog_counter += 1
        return [self.compile_instruction(inst, labels, debug=debug) for inst in self.prog_list if inst['name']!='comment']

    def append_instruction(self, name, *args):
        """Append instruction to the program list

        Parameters
        ----------
        name : str
            Instruction name
        *args : dict
            Instruction arguments
        """
        n_args = max([f[0] for f in self.instructions[name]['fmt']]+[-1])+1
        if len(args)==n_args:
            inst = {'name': name, 'args': args}
        elif len(args)==n_args+1:
            inst = {'name': name, 'args': args[:n_args], 'comment': args[n_args]}
        else:
            raise RuntimeError("wrong number of args:", name, args)
        if self._label_next is not None:
            # store the label with the instruction, for printing
            inst['label'] = self._label_next
            self._label_next = None
        self.prog_list.append(inst)

    def label(self, name):
        """Add line number label to the labels dictionary. This labels the instruction by its position in the program list. The loopz and condj commands use this label information.

        Parameters
        ----------
        name : str
            Label name
        """
        if self._label_next is not None:
            raise RuntimeError("label already defined for the next line")
        self._label_next = name

    def __getattr__(self, a):
        """
        Uses instructions dictionary to automatically generate methods for the standard instruction set.

        Also include all QickConfig methods as methods of the QickProgram.
        This allows e.g. this.freq2reg(f) instead of this.soccfg.freq2reg(f).

        :param a: Instruction name
        :type a: str
        :return: Instruction arguments
        :rtype: *args object
        """
        if a in self.__class__.instructions:
            return lambda *args: self.append_instruction(a, *args)
        elif a in self.__class__.soccfg_methods:
            return getattr(self.soccfg, a)
        else:
            return object.__getattribute__(self, a)

    def hex(self):
        """Returns hex representation of program as string.

        Returns
        -------
        str
            Compiled program in hex format
        """
        return "\n".join([format(mc, '#018x') for mc in self.compile()])

    def bin(self):
        """Returns binary representation of program as string.

        Returns
        -------
        str
            Compiled program in binary format
        """
        return "\n".join([format(mc, '#066b') for mc in self.compile()])

    def asm(self):
        """Returns assembly representation of program as string, should be compatible with the parse_prog from the parser module.

        Returns
        -------
        str
            asm file
        """
        label_list = [inst['label'] for inst in self.prog_list if 'label' in inst]
        if label_list:
            max_label_len = max([len(label) for label in label_list])
        else:
            max_label_len = 0
        s = "\n// Program\n\n"
        lines = [self._inst2asm(inst, max_label_len) for inst in self.prog_list]
        return s+"\n".join(lines)

    def _inst2asm(self, inst, max_label_len):
        if inst['name']=='comment':
            return "// "+inst['comment']
        template = inst['name'] + " " + self.__class__.instructions[inst['name']]['repr'] + ";"
        line = " "*(max_label_len+2) + template.format(*inst['args'])
        if 'comment' in inst:
            line += " "*(48-len(line)) + "//" + (inst['comment'] if inst['comment'] is not None else "")
        if 'label' in inst:
            label = inst['label']
            line = label + ": " + line[len(label)+2:]
        return line

    def compare_program(self, fname):
        """For debugging purposes to compare binary compilation of parse_prog with the compile.

        Parameters
        ----------
        fname : str
            File the comparison program is stored in

        Returns
        -------
        bool
            True if programs are identical; False otherwise
        """
        match = True
        pns = [int(n, 2) for n in self.bin().split('\n')]
        fns = [int(n, 2)
               for ii, n in parse_prog(file=fname, outfmt="bin").items()]
        if len(pns) != len(fns):
            print("Programs are different lengths")
            return False
        for ii in range(len(pns)):
            if pns[ii] != fns[ii]:
                print(f"Mismatch on line ii: p={pns[ii]}, f={fns[ii]}")
                match = False
        return match

    def __len__(self):
        """
        :return: number of instructions in the program
        :rtype: int
        """
        return len(self.prog_list)

    def __str__(self):
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

    def __exit__(self, type, value, traceback):
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


class QickRegister:
    """A qick register object that keeps the page, address, generator/readout channel and register type information,
       provides functions that make it easier to set register value given input values in physical units.
    """
    def __init__(self, prog: QickProgram, page: int, addr: int, reg_type: str = None,
                 gen_ch: int = None, ro_ch: int = None, init_val=None, name: str = None):
        """
        :param prog: qick program in which the register is used.
        :param page: page of the register
        :param addr: address of the register in the register page (referred as "register number" in some other places)
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None,
            type of the register, used for automatic converting to physical values.
        :param gen_ch: generator channel numer to which the register is associated with, for unit convert.
        :param ro_ch: readout channel numer to which the register is associated with, for unit convert.
        :param init_val: initial value of the register. If reg_type is not None, the value should be in its physical
            unit. i.e. freq in MHz, time in us, phase in deg.
        :param name: If None, an auto generated name based on the register page and address will be used
        """
        self.prog = prog
        self.page = page
        self.addr = addr
        self.reg_type = reg_type
        self.gen_ch = gen_ch
        self.ro_ch = ro_ch
        self.init_val = init_val
        self.unit = DefaultUnits.get(str(self.reg_type))
        if name is None:
            self.name = f"reg_p{page}_{addr}"
        else:
            self.name = name
        if init_val is not None:
            self.reset()

    def val2reg(self, val):
        """
        convert physical value to a qick register value
        :param val:
        :return:
        """
        if self.reg_type == "freq":
            return self.prog.freq2reg(val, self.gen_ch, self.ro_ch)
        elif self.reg_type == "time":
            if self.gen_ch is not None:
                return self.prog.us2cycles(val, self.gen_ch)
            else:
                return self.prog.us2cycles(val, self.gen_ch, self.ro_ch)
        elif self.reg_type == "phase":
            return self.prog.deg2reg(val, self.gen_ch)
        elif self.reg_type == "adc_freq":
            return self.prog.freq2reg_adc(val, self.ro_ch, self.gen_ch)
        else:
            return np.int32(val)

    def reg2val(self, reg):
        """
        converts a qick register value to its value in physical units
        :param reg:
        :return:
        """
        if self.reg_type == "freq":
            return self.prog.reg2freq(reg, self.gen_ch)
        elif self.reg_type == "time":
            if self.gen_ch is not None:
                return self.prog.cycles2us(reg, self.gen_ch)
            else:
                return self.prog.cycles2us(reg, self.gen_ch, self.ro_ch)
        elif self.reg_type == "phase":
            return self.prog.reg2deg(reg, self.gen_ch)
        elif self.reg_type == "adc_freq":
            return self.prog.reg2freq_adc(reg, self.ro_ch)
        else:
            return reg


    def set_to(self, a: Union["QickRegister", float, int], operator: str = "+",
                  b: Union["QickRegister", float, int] = 0, physical_unit=True):
        """
        a shorthand function that sets the register value using different asm commands based on the input type.

        if input "a" is a number, "operator" and "b" will be neglected, "a"(or the register integer that corresponds to
        "a") will be assigned to the current register

        if input "a" is a QickRegister and "b" is a number, the register will be set to the "mathi" result between "a"
        and "b". (when physical_unit==True, "b" will be auto-converted from physical value to register value based on
        the register type)

        if both  "a" and "b" are QickRegisters, the register will be set to the "math" result between "a" and "b".

        :param a: first operand register or a constant value
        :param operator: {"+", "-", "*"}. math symbol supported by "math" and "mathi" asm commands
        :param b: second operand register or a constant value
        :param physical_unit: when True, the constant value operands should be in its physical unit and will be
            automatically converted to the register integer before assignment.
        :return:
        """
        if operator not in MathOperators:
            raise ValueError(f"operator {operator} is not supported.")
        if type(a) != QickRegister: # assign value "a" to register, do unit conversion if physical_unit==True
            reg = self.val2reg(a) if physical_unit else a
            comment = f"'{self.name}' <= {reg} " + \
                      (f"({a} {self.unit})" if physical_unit and (self.unit is not None) else "")
            self.prog.safe_regwi(self.page, self.addr, reg, comment)
        else:
            if type(b) == QickRegister:
                # do math operation between register "b" and register "a", assign the result to current register
                comment = f" '{self.name}' <= '{a.name}' {operator} '{b.name}'"
                if not (self.page == a.page == b.page):
                    raise RuntimeError(f"the qick registers for mathematical operation must be on the same page. "
                                       f"Got '{self.name}' on page {self.page}, '{a.name}' on page {a.page} "
                                       f"and '{b.name}' on page {b.page}")
                self.prog.math(self.page, self.addr, a.addr, operator, b.addr, comment)
            else:
                # do math operation between value "b" and register "a", assign the result to current register
                reg = self.val2reg(b) if physical_unit else b # do unit conversion on "b" if physical_unit==True
                comment = f" '{self.name}' <= '{a.name}' {operator} {reg} " \
                          + (f"({b} {self.unit})" if physical_unit and (self.unit is not None) else "")
                if not (self.page == a.page):
                    raise RuntimeError(f"the qick registers for mathematical operation must be on the same page. "
                                       f"Got '{self.name}' on page {self.page} and '{a.name}' on page {a.page}")
                self.prog.mathi(self.page, self.addr, a.addr, operator, reg, comment)

    def reset(self):
        """
        reset register value to its init_val
        :return:
        """
        self.set_to(self.init_val)


class QickRegisterManagerMixin:
    """
    A mixin class for QickProgram that provides manager functions for getting and declaring new qick registers.
    """

    def __init__(self, *args, **kwargs):
        self.user_reg_dict = {}  # look up dict for registers defined in each generator channel
        self._user_regs = []  # (page, addr) of all user defined registers
        super().__init__(*args, **kwargs)

    def new_reg(self, page: int, addr: int = None, name: str = None, init_val=None, reg_type: str = None,
                gen_ch: int = None, ro_ch: int = None):
        """ Declare a new register in a specific page.

        :param page: register page
        :param addr: address of the new register. If None, the function will automatically try to find the next
            available address.
        :param name: name of the new register. Optional.
        :param init_val: initial value for the register, when reg_type is provided, the reg_val should be in the
            physical unit of the corresponding type. i.e. freq in MHz, time in us, phase in deg.
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None, type of the register
        :param gen_ch: generator channel numer to which the register is associated with, for unit convert.
        :param ro_ch: readout channel numer to which the register is associated with, for unit convert.
        :return: QickRegister
        """
        if addr is None:
            addr = 1
            while (page, addr) in self._user_regs:
                addr += 1
            if addr > 12:
                raise RuntimeError(f"registers in page {page} is full.")
        else:
            if addr < 1 or addr > 12:
                raise ValueError(f"register address must be greater than 0 and smaller than 13")
            if (page, addr) in self._user_regs:
                raise ValueError(f"register at address {addr} in page {page} is already occupied.")
        self._user_regs.append((page, addr))

        if name is None:
            name = f"reg_page{page}_{addr}"
        if name in self.user_reg_dict.keys():
            raise NameError(f"register name '{name}' already exists")

        reg = QickRegister(self, page, addr, reg_type, gen_ch, ro_ch, init_val, name=name)
        self.user_reg_dict[name] = reg

        return reg

    def get_gen_reg(self, gen_ch: int, name: str) -> QickRegister:
        """
        Gets tProc register page and address associated with gen_ch and register name. Creates a QickRegister object for
        return.

        :param gen_ch: generator channel number
        :param name:  name of the qick register, as in QickProgram.pulse_registers
        :return: QickRegister
        """
        gen_cgf = self.gen_chs[gen_ch]
        page = self.ch_page(gen_ch)
        addr = self.sreg(gen_ch, name)
        reg_type = name if name in RegisterType else None
        reg = QickRegister(self, page, addr, reg_type, gen_ch, gen_cgf.get("ro_ch"), name=f"gen{gen_ch}_{name}")
        return reg

    def new_gen_reg(self, gen_ch: int, name: str = None, init_val=None, reg_type: str = None,
                    tproc_reg=False) -> QickRegister:
        """
        Declare a new register in the generator register page. Address automatically adds 1 one when each time a new
        register in the same page is declared.

        :param gen_ch: generator channel number
        :param name: name of the new register. Optional.
        :param init_val: initial value for the register, when reg_type is provided, the reg_val should be in the unit of
            the corresponding type.
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None, type of the register.
        :param tproc_reg: if True, the new register created will not be associated to a specific generator or readout
            channel. It will still be on the same page as the gen_ch for math calculations. This is usually used for a
            time register in t_processor, where we want to calculate "us2cycles" with the t_proc fabric clock rate
            instead of the generator clock rate.
        :return: QickRegister
        """
        gen_cgf = self.gen_chs[gen_ch]
        page = self.ch_page(gen_ch)

        addr = 1
        while (page, addr) in self._user_regs:
            addr += 1
        if name is None:
            name = f"gen{gen_ch}_reg{addr}"

        if tproc_reg:
            return self.new_reg(page, addr, name, init_val, reg_type, None, None)
        else:
            return self.new_reg(page, addr, name, init_val, reg_type, gen_ch, gen_cgf.get("ro_ch"))
