from qsystem_2 import *
import numpy as np

class ASM_Program:
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
                    'read': {'type':"R", 'bin': 0b01010011, 'fmt': ((1,53),(0,50), (2,46), (3,41)), 'repr': "{0}, {1} {2} ${3}"},
                    'wait': {'type':"R", 'bin': 0b01010100, 'fmt': ((0,53),(1,31)), 'repr': "{0}, {1}, ${2}"},
                    'bitw': {'type':"R", 'bin': 0b01010101, 'fmt': ((0,53),(1,41),(2,36),(3,46), (4,31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'memr': {'type':"R", 'bin': 0b01010110, 'fmt': ((0,53),(1,41),(2,36)), 'repr': "{0}, ${1}, ${2}"},
                    'memw': {'type':"R", 'bin': 0b01010111, 'fmt': ((0,53),(2,36),(1,31)), 'repr': "{0}, ${1}, ${2}"},
                    'setb': {'type':"R", 'bin': 0b01011000, 'fmt': ((0,53),(2,36),(1,31)), 'repr': "{0}, ${1}, ${2}"}
                    }

    op_codes = {">": 0b0000, ">=": 0b0001, "<": 0b0010, "<=": 0b0011, "==": 0b0100, "!=": 0b0101, 
                "+": 0b1000, "-": 0b1001, "*": 0b1010,
                "&": 0b0000, "|": 0b0001, "^": 0b0010, "~": 0b0011, "<<": 0b0100, ">>": 0b0101,
                "upper": 0b1010, "lower": 0b0101
               }
    
    special_registers = [{"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "adc_freq":22},
                         {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "adc_freq":29},
                         {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "adc_freq":22},
                         {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "adc_freq":29},
                         {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "adc_freq":22},
                         {"freq": 23 , "phase":24,"addr":25,"gain":26, "mode":27, "t":28, "adc_freq":29},
                         {"freq": 16 , "phase":17,"addr":18,"gain":19, "mode":20, "t":21, "adc_freq":22},
                        ]   
    
    trig_offset=25
    fs_adc = 384*8
    fs_dac = 320*16
    fs_proc=384
    
    def __init__(self):
        self.prog_list = []
        self.labels = {}
        self.dac_ts = [0]*9 #np.zeros(9,dtype=np.uint16)
        self.channels={ch:{"addr":0, "pulses":{}, "last_pulse":None} for ch in range(1,8)}
        
        
    def freq2reg(self,f):
        B=32
        df = 2**B/self.fs_dac
        f_i = f*df
        return int(f_i)

    def freq2reg_adc(self,f):
        B=16
        df = 2**B/self.fs_adc
        f_i = f*df
        return int(f_i)    
    
    def reg2freq(self,r):
        return r*self.fs_dac/2**32
    
    def cycles2us(self,cycles):
        return cycles/self.fs_proc
    
    def us2cycles(self, us):
        return int(us*self.fs_proc)
    
    def deg2reg(self, deg):
        return deg*2**16//360
    
    def reg2deg(self, reg):
        return reg*360/2**16
    
    def add_pulse(self, ch, name, data):
        if len(data) % 16 !=0:
            raise RuntimeError("Error: Pulse length must be integer multiple of 16")
        self.channels[ch]["pulses"][name]={"data":data, "addr":self.channels[ch]['addr'], "length":len(data)//16, "style": style}
        self.channels[ch]["addr"]+=len(data)
        
    def load_pulses(self, soc):
        for ch,gen in zip(self.channels.keys(),soc.gens):
            for name,pulse in self.channels[ch]['pulses'].items():
                if pulse['style'] != 'const':
                    data = pulse['data'].astype(np.int16)
                    gen.load(data,addr=pulse['addr'])                

    def ch_page(self, ch):
        return (ch-1)//2
    
    def sreg(self, ch, name):
        return self.__class__.special_registers[ch-1][name]
        
    def set_wave(self, ch, pulse=None, freq=None, phase=None, addr=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None , t= 'auto', play=True):
        p=self
        rp=self.ch_page(ch)
        r_freq,r_phase,r_addr, r_gain, r_mode, r_t = p.sreg(ch,'freq'), p.sreg(ch,'phase'), p.sreg(ch,'addr'), p.sreg(ch,'gain'), p.sreg(ch,'mode'), p.sreg(ch,'t')
        if freq is not None: p.regwi (rp, r_freq, freq, 'freq')
        if phase is not None: p.regwi (rp, r_phase, phase, 'phase')
        if gain is not None: p.regwi (rp, r_gain, gain, 'gain')
        if t is not None and t !='auto': p.regwi (rp, r_t, t, f't = {t}')
            
        if pulse is not None:
            pdata=self.channels[ch]['pulses'][pulse]["data"]
            length=len(pdata)//16
            addr=self.channels[ch]['pulses'][pulse]["addr"]
            self.channels[ch]['last_pulse']=pulse
        elif length is not None:
            addr=0

        if addr is not None: p.regwi (rp, r_addr, addr, 'addr')
        if length is not None:
            p.regwi (rp, r_mode, p.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=length), f'stdysel = {stdysel}, mode = {mode}, outsel = {outsel}, length = {length}')

        if play:
            if t is not None:
                if t=='auto':
                    t=p.dac_ts[ch]
                if pulse is None and length is None:
                    pulse=p.channels[ch]["pulses"][p.channels[ch]['last_pulse']]
                    length=pulse['length']
                p.dac_ts[ch]=t+length
                p.regwi (rp, r_t, t, f't = {t}')
            p.set (ch, rp, r_freq, r_phase, r_addr, r_gain, r_mode, r_t, f"ch = {ch}, out = ${r_freq},${r_addr},${r_gain},${r_mode} @t = ${r_t}")


    def align(self, chs):
        max_t=max([self.dac_ts[ch] for ch in range(1,9)])
        for ch in range(1,9):
            self.dac_ts[ch]=max_t
            
    def sync_all(self):
        max_t=max([self.dac_ts[ch] for ch in range(1,9)])
        if max_t>0:
            self.synci(max_t)
            self.dac_ts=[0]*len(self.dac_ts) #zeros(len(self.dac_ts),dtype=uint16)

    def delay(self, length):
        self.sync_all()
        if length < 2**14:
            self.synci(length)
        else:
            for ii in range(length // (2**14-1)):
                self.synci(2**14-1)
            self.synci(length % (2**14-1))
            
                
    #should change behavior to only change bits that are specified
    def seti_trigger(self, t, t1 = 0, t2 = 0, t3 = 0, t4=0, tadc=0, t14=0, t15=0, rp=0, r_out = 31): 
        p=self
        out= (t15 << 15) |(t14<<14) | (t4 << 3) | (t3 << 2) | (t2 << 1) | (t1 << 0) 
        p.regwi (rp, r_out, out, 'out = 0b{t4}{t3}{t2}{t1}')
        p.seti (0, rp, r_out, t, f'ch =0 out = ${r_out} @t = {t}')
        
    def measure(self, ch, pulse=None, freq=None, gain=None, phase=None, length=None, adc_trig_offset=256, t="auto", play=True):
        p=self          
        if freq is not None:
            p.regwi (p.ch_page(ch), p.sreg(ch,"freq"), freq)  # set dac frequency register
            #p.regwi (p.ch_page(ch), p.sreg(ch,"adc_freq"), adc_freq)  # set adc frequency register
            #p.seti(5, p.ch_page(ch), p.sreg(ch,"adc_freq"), 0)
        if t is not None and t != 'auto':
            p.regwi (p.ch_page(ch), p.sreg(ch,"t"), t) 
            t=t
        elif t=='auto':
            t=p.dac_ts[ch]

        
        if play:
            p.seti_trigger(t=t+adc_trig_offset, t1=0, t15=1, t14=1, )  # bit 14 triggers downconverted buffer / averager
            p.set_wave(ch, pulse=pulse,gain=gain, phase=phase, length=length,  outsel=1, play=play)  #if readout pulse configure dac
            p.seti_trigger(t=t+adc_trig_offset+length+10,  t1=0, t15=0, t14=0)
        else:
            p.set_wave(ch, pulse=pulse,gain=gain, phase=phase, outsel=1, length=length,  play=play)  #if readout pulse configure dac
        
        
    def compile_instruction(self,inst):
        args=list(inst['args'])
        
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
            
        idef = self.__class__.instructions[inst['name']]
        fmt=idef['fmt']
        mcode = (idef['bin'] << 56)
        #print(inst)
        for field in fmt:
            mcode|=(args[field[0]] << field[1])
            
        if inst['name'] == 'loopnz':
            mcode|= (0b1000 << 46)

        return mcode

    def compile(self):
        return [self.compile_instruction(inst) for inst in self.prog_list]

#     def get_mode_code(self, phrst, stdysel, mode, outsel, length):
#         if phrst is None:
#             phrst=0
#         if stdysel is None:
#             stdysel=1
#         if mode is None:
#             mode=0
#         if outsel is None:
#             outsel=0
#         return (stdysel << 15) | (mode << 14) | (outsel << 12) | (length <<0) # f'stdysel = {stdysel} , mode = {mode} , outsel = {outsel}, nsamp = {nsamp}'
    
    def get_mode_code(self, phrst, stdysel, mode, outsel, length):
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
        self.prog_list.append({'name':name, 'args':args})
                    
    def label(self, name):
        self.labels[name]= len(self.prog_list)

    def comment(self, comment):
        pass

    def __getattr__(self, a):
        if a in self.__class__.instructions:
            return lambda *args: self.append_instruction(a, *args)
        else:
            return object.__getattribute__(self, a)

    def hex(self):
        return "\n".join([format(mc, '#018x') for mc in self.compile()])
    
    def bin(self):
        return "\n".join([format(mc, '#066b') for mc in self.compile()])

    def asm(self):
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
                line+=" "*24 + inst['args'][-1]
            lines.append(line)

        for label, jj in self.labels.items():
            lines[jj] = label + ": " + lines[jj][len(label)+2:]
        return s+"\n".join(lines)
    
    def compare_program(self,fname):
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

    def __repr__(self):
        return self.asm()
    
    def __enter__(self):
        return self
    
    def __exit__(self,type, value, traceback):
        pass