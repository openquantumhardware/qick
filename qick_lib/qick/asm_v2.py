import logging
import numpy as np
from collections import namedtuple, OrderedDict, defaultdict

#from .tprocv2_compiler import tprocv2_compile
from .tprocv2_assembler import Assembler
from .qick_asm import AbsQickProgram, QickRegister

class Wave(namedtuple('Wave', ["freq", "phase", "env", "gain", "length", "conf"])):
    widths = [4, 4, 3, 4, 4, 2]
    def compile(self):
        # convert to bytes to get a 168-bit word (this is what actually ends up in the wave memory)
        rawbytes = b''.join([int(i).to_bytes(length=w, byteorder='little', signed=True) for i, w in zip(self, self.widths)])
        # pad with zero bytes to get the 256-bit word (this is the format for DMA transfers)
        paddedbytes = rawbytes[:11]+bytes(1)+rawbytes[11:]+bytes(10)
        # pack into a numpy array
        return np.frombuffer(paddedbytes, dtype=np.int32)

class QickProgramV2(AbsQickProgram):
    def __init__(self, soccfg):
        super().__init__(soccfg)
        self.prog_list = []
        self.labels = {'s15': 's15'} # register 15 predefinition

        # address in program memory
        self.p_addr = 1
        # line number
        self.line = 1
        # first instruction is always NOP, so both counters start at 1

        self.user_reg_dict = {}  # look up dict for registers defined in each generator channel
        self._user_regs = []  # addr of all user defined registers

        self.loop_list = []
        self.loop_stack = []

        self.waves = OrderedDict()
        self.wave2idx = {}

    def add_instruction(self, inst, addr_inc=1):
        # copy the instruction dict in case it's getting reused and modified
        inst = inst.copy()
        inst['P_ADDR'] = self.p_addr
        inst['LINE'] = self.line
        self.p_addr += addr_inc
        self.line += 1
        self.prog_list.append(inst)

    def end(self):
        self.add_instruction({'CMD':'JUMP', 'ADDR':f'&{self.p_addr}', 'UF':'0'})

    def wait(self, time):
        # the assembler translates "WAIT" into two instructions
        self.add_instruction({'CMD':'WAIT', 'ADDR':f'&{self.p_addr + 1}', 'TIME': f'{time}'}, addr_inc=2)

    def add_label(self, label):
        """apply the specified label to the next instruction
        """
        self.labels[label] = '&' + str(len(self.prog_list)+1)

    def new_reg(self, addr: int = None, name: str = None, init_val=None, reg_type: str = None,
                gen_ch: int = None, ro_ch: int = None):
        """ Declare a new data register.

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
            name = f"reg_page{addr}"
        if name in self.user_reg_dict.keys():
            raise NameError(f"register name '{name}' already exists")

        reg = QickRegister(self, 0, addr, reg_type, gen_ch, ro_ch, init_val, name=name)
        self.user_reg_dict[name] = reg

        return reg
    
    def add_wave(self, name, freq, phase, env, gain, length, conf):
        self.waves[name] = Wave(freq, phase, env, gain, length, conf)
        self.wave2idx[name] = len(self.waves)-1
        
    def pulse(self, ch, name, t=0):
        pulse_length = self.waves[name].length
        pulse_length *= self.tproccfg['f_time']/self.soccfg['gens'][ch]['f_fabric']
        ts = self.get_timestamp(gen_ch=ch)
        if t == 'auto':
            t = int(ts) #TODO: 0?
            self.set_timestamp(int(ts + pulse_length), gen_ch=ch)
        else:
            if t<ts:
                print("warning: pulse time %d appears to conflict with previous pulse ending at %f?"%(t, ts))
                self.set_timestamp(int(ts + pulse_length), gen_ch=ch)
            else:
                self.set_timestamp(int(t + pulse_length), gen_ch=ch)
        
        idx = self.wave2idx[name]
        tproc_ch = ch # TODO: actually translate
        self.add_instruction({'CMD':"REG_WR", 'DST':'s14' ,'SRC':'imm' ,'LIT':str(t), 'UF':'0'})
        self.add_instruction({'CMD':'WPORT_WR', 'DST':str(tproc_ch) ,'SRC':'wmem', 'ADDR':'&'+str(idx), 'UF':'0'})

    def open_loop(self, n, name=None, addr=None):
        if name is None: name = f"loop_{len(self.loop_list)}"
        reg = self.new_reg(name=name, addr=addr)
        self.loop_list.append(name)
        self.loop_stack.append(name)
        self.add_instruction({'CMD':"REG_WR" , 'DST':'r'+str(reg.addr) ,'SRC':'imm' ,'LIT': str(n), 'UF':'0'})
        self.add_label(name.upper())
    
    def close_loop(self):
        name = self.loop_stack.pop()
        reg = self.user_reg_dict[name]
        self.add_instruction({'CMD':'REG_WR', 'DST':f'r{reg.addr}', 'SRC':'op', 'OP':f'r{reg.addr}-#1', 'UF':'1'})
        self.add_instruction({'CMD':'JUMP', 'LABEL':name.upper(), 'IF':'NZ', 'UF':'0'})
        
#         self.add_instruction({'CMD':'JUMP', 'LABEL':name.upper(), 'IF':'NZ', 'WR':f'r{reg.addr} op', 'OP':f'r{reg.addr}-#1', 'UF':'1' })
    
    def trigger(self, ros=None, pins=None, t=0, width=10):
        if ros is None: ros = []
        if pins is None: pins = []
        outdict = defaultdict(int)
        trigset = set()
        for ro in ros:
            rocfg = self.soccfg['readouts'][ro]
            if rocfg['trigger_type'] == 'dport':
                outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
            else:
                trigset.add(rocfg['trigger_port'])
            ts = self.get_timestamp(ro_ch=ro)
            if t < ts: print("Readout time %d appears to conflict with previous readout ending at %f?"%(t, ts))
            ro_length = self.ro_chs[ro]['length']
            ro_length *= self.tproccfg['f_time']/self.soccfg['readouts'][ro]['f_fabric']
            self.set_timestamp(int(t + ro_length), ro_ch=ro)
        for pin in pins:
            porttype, portnum, pinnum, _ = self.soccfg['tprocs'][0]['output_pins'][pin]
            if porttype == 'dport':
                outdict[portnum] |= (1 << pinnum)
            else:
                trigset.add(portnum)

        if outdict:
            self.add_instruction({'CMD':"REG_WR", 'DST':'s14', 'SRC':'imm', 'LIT': str(t), 'UF':'0'})
            for outport, out in outdict.items():
                self.add_instruction({'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':str(out), 'UF':'0'})
            self.add_instruction({'CMD':"REG_WR", 'DST':'s14','SRC':'imm', 'LIT':str(t+width), 'UF':'0'})
            for outport, out in outdict.items():
                self.add_instruction({'CMD':'DPORT_WR', 'DST':str(outport), 'SRC':'imm', 'DATA':'0', 'UF':'0'})
        if trigset:
            for outport in trigset:
                self.add_instruction({'CMD':'TRIG', 'SRC':'set', 'DST':str(outport), 'TIME':str(t)})
                self.add_instruction({'CMD':'TRIG', 'SRC':'clr', 'DST':str(outport), 'TIME':str(t+width)})

    def sync_all(self, t=0):
        max_t = self.get_max_timestamp()
        if max_t+t > 0:
            self.add_instruction({'CMD':'TIME', 'DST':'inc_ref', 'LIT':f'{int(max_t+t)}'})
            self.reset_timestamps()

    def compile_prog(self):
        _, p_mem = Assembler.list2bin(self.prog_list, self.labels)
        return p_mem

    def compile_waves(self):
        if self.waves:
            return np.stack([w.compile() for w in self.waves.values()])
        else:
            return np.zeros((0,8), dtype=np.int32)

    def asm(self):
        asm = Assembler.list2asm(self.prog_list, self.labels)
        return asm

    def config_all(self, soc):
        soc.tproc.proc_stop()
        super().config_all(soc)
        soc.tproc.Load_PMEM(self.compile_prog())
        soc.tproc.load_mem(3, self.compile_waves())
