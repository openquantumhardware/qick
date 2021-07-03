from qsystem_2 import PfbSoc, freq2reg
from slab.instruments import Instrument

class RFSocInstrument(Instrument):
    
    def __init__(self, name, address='', enabled=True, timeout=1, query_sleep=0, **kwargs):
        Instrument.__init__(self, name=name, address=address, enabled=enabled, timeout=timeout, query_sleep=query_sleep, **kwargs)
        self.reset()
        
    def reset(self):
        self.soc = PfbSoc('qsystem_2.bit')
    
    def acquire(self, prog, load_pulses=True):
        return prog.acquire(self.soc, load_pulses)