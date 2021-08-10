from qsystem_2 import PfbSoc, freq2reg
from slab.instruments import Instrument,InstrumentManager

class RFSocInstrument(Instrument):
    
    def __init__(self, name, address='', enabled=True, timeout=1, query_sleep=0, **kwargs):
        Instrument.__init__(self, name=name, address=address, enabled=enabled, timeout=timeout, query_sleep=query_sleep, **kwargs)
        self.reset()
        
    def reset(self):
        self.soc = PfbSoc('qsystem_2.bit')
    
    def acquire(self, prog, load_pulses=True,ReadoutPerExpt=1, Average=[]):
        if prog.__class__.__base__.__name__=='RRAveragerProgram':
            return prog.acquire(self.soc, load_pulses, ReadoutPerExpt, Average)
        else:
            return prog.acquire(self.soc, load_pulses)
    
    def single_write(self, addr, data):
        self.soc.tproc.single_write(addr,data)
        
    def single_read(self, addr):
        return self.soc.tproc.single_read(addr)
    
    def acquire_decimated_ds(self, prog, load_pulses=True):
        return prog.acquire_decimated_ds(self.soc, load_pulses)
    
#     def start(self):
#         return self.soc.tproc.start()

#     def stop(self):
#         return self.soc.tproc.stop()
        
#     def get_accumulated(self, ch, address=0, length=AxisAvgBuffer.AVG_MAX_LENGTH):
#         return self.soc.get_accumulated(ch,address,length)
    
#     def get_decimated(self, ch, address=0, length=AxisAvgBuffer.BUF_MAX_LENGTH):
#         return self.soc.get_decimated(ch,address,length)
    
    def set_nyquist(self, ch, nqz):
        return self.soc.set_nyquist(ch,nqz)
