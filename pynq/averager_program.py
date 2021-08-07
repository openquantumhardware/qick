from qsystem2_asm import *
from tqdm import tqdm_notebook as tqdm
import numpy as np
import time

class AveragerProgram(ASM_Program):
    def __init__(self, cfg):
        ASM_Program.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        pass
    
    def body(self):
        pass
    
    def make_program(self):
        p=self
        
        rjj=14
        rcount=15
        p.initialize()
        p.regwi (0, rcount,0)
        p.regwi (0, rjj, self.cfg["reps"]-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0,rcount,rcount,"+",1)
        
        p.memwi(0,rcount,1)
                
        p.loopnz(0, rjj, 'LOOP_J')
       
        p.end()        
        
    def acquire(self, soc, load_pulses=True, progress=True, debug=False):

        if load_pulses: 
            self.load_pulses(soc)
        
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        
        # Configure and enable buffer capture.
        for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
            avg_buf.config_buf(address=0,length=adc_length)
            avg_buf.enable_buf()
            avg_buf.config_avg(address=0,length=adc_length)
            avg_buf.enable_avg()

        soc.tproc.load_asm_program(self, debug=debug)
        
        reps = self.cfg['reps']
        
        count=0
        last_count=0
        total_count=reps

        di_buf=np.zeros((2,total_count))
        dq_buf=np.zeros((2,total_count))
        
        soc.tproc.stop()
        
        soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0
        self.stats=[]
        
        soc.tproc.start()
        while count<total_count:
            count = soc.tproc.single_read(addr= 1)
            if count>=min(last_count+1000,total_count-1):
                addr=last_count % soc.avg_bufs[1].AVG_MAX_LENGTH
                length = count-last_count
                length -= length%2

                for ch in range(2):
                    di,dq = soc.get_accumulated(ch=ch,address=addr, length=length)

                    di_buf[ch,last_count:last_count+length]=di[:length]
                    dq_buf[ch,last_count:last_count+length]=dq[:length]

                last_count+=length
                self.stats.append( (time.time(), count,addr, length))
                    
        self.di_buf=di_buf
        self.dq_buf=dq_buf
        
        avg_di0=np.sum(di_buf[0])/(reps)/self.cfg['adc_lengths'][0]
        avg_dq0=np.sum(dq_buf[0])/(reps)/self.cfg['adc_lengths'][0]
        avg_amp0=np.sqrt(avg_di0**2+avg_dq0**2)
        
        avg_di1=np.sum(di_buf[1])/(reps)/self.cfg['adc_lengths'][1]
        avg_dq1=np.sum(dq_buf[1])/(reps)/self.cfg['adc_lengths'][1]
        avg_amp1=np.sqrt(avg_di1**2+avg_dq1**2)
        
        
        return avg_di0, avg_dq0, avg_amp0,avg_di1, avg_dq1, avg_amp1

    def acquire_decimated_ds(self, soc, load_pulses=True, progress=True, debug=False):
        if self.cfg["reps"] != 1:
            print ("Warning reps is not set to 1, and this acquire method expects reps=1")
            
        if load_pulses: 
            self.load_pulses(soc)
        
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        

        soft_avgs=self.cfg["soft_avgs"]        

        di_avg0=np.zeros(self.cfg["adc_lengths"][0])
        dq_avg0=np.zeros(self.cfg["adc_lengths"][0])
        di_avg1=np.zeros(self.cfg["adc_lengths"][1])
        dq_avg1=np.zeros(self.cfg["adc_lengths"][1])
        
        for ii in tqdm(range(soft_avgs)):
            soc.tproc.stop()
            # Configure and enable buffer capture.
            for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
                avg_buf.config_buf(address=0,length=adc_length)
                avg_buf.enable_buf()
                avg_buf.config_avg(address=0,length=adc_length)
                avg_buf.enable_avg()

            soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0       
            soc.tproc.load_asm_program(self, debug=debug)
        
            soc.tproc.start() #runs the assembly program

            count=0
            while count<1:
                count = soc.tproc.single_read(addr= 1)
                
            di0,dq0 = soc.get_decimated(ch=0, address=0, length=self.cfg["adc_lengths"][0])
            di1,dq1 = soc.get_decimated(ch=1, address=0, length=self.cfg["adc_lengths"][1])
            
            di_avg0+=di0
            dq_avg0+=dq0
            di_avg1+=di1
            dq_avg1+=dq1
            
        return di_avg0/soft_avgs,dq_avg0/soft_avgs, di_avg1/soft_avgs, dq_avg1/soft_avgs
    
class RRAveragerProgram(ASM_Program):
    def __init__(self, cfg):
        ASM_Program.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        pass
    
    def body(self):
        pass
    
    def update(self):
        pass
    
    def make_program(self):
        p=self
        
        rcount=13
        rii=14
        rjj=15

        p.initialize()

        p.regwi(0, rcount,0)
        
        p.regwi (0, rii, self.cfg["expts"]-1 )
        p.label("LOOP_I")    

        p.regwi (0, rjj, self.cfg["reps"]-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0,rcount,rcount,"+",1)
        
        p.memwi(0,rcount,1)
                
        p.loopnz(0, rjj, 'LOOP_J')

        p.update()
        
        p.loopnz(0, rii, "LOOP_I")    

        p.end()        

    def get_expt_pts(self):
        return self.cfg["start"]+np.arange(self.cfg['expts'])*self.cfg["step"]
        
    def acquire(self, soc, load_pulses=True, ReadoutPerExpt=1, Average=[0], debug=False):

        if load_pulses: 
            self.load_pulses(soc)
        
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        
        # Configure and enable buffer capture.
        for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
            avg_buf.config_buf(address=0,length=adc_length)
            avg_buf.enable_buf()
            avg_buf.config_avg(address=0,length=adc_length)
            avg_buf.enable_avg()

        soc.tproc.load_asm_program(self, debug=debug)
        
        reps,expts = self.cfg['reps'],self.cfg['expts']
        
        count=0
        last_count=0
        total_count=reps*expts*ReadoutPerExpt

        di_buf=np.zeros((2,total_count))
        dq_buf=np.zeros((2,total_count))
        
        soc.tproc.stop()
        
        soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0
        self.stats=[]
        
        with tqdm(total=total_count, disable=not progress) as pbar:
            soc.tproc.start()
            while count<total_count-1:
                count = soc.tproc.single_read(addr= 1)*ReadoutPerExpt

                if count>=min(last_count+1000,total_count-1):
                    addr=last_count % soc.avg_bufs[1].AVG_MAX_LENGTH
                    length = count-last_count
                    length -= length%2

                    for ch in range(2):
                        di,dq = soc.get_accumulated(ch=ch,address=addr, length=length)

                        di_buf[ch,last_count:last_count+length]=di[:length]
                        dq_buf[ch,last_count:last_count+length]=dq[:length]

                    last_count+=length
                    self.stats.append( (time.time(), count,addr, length))
                    pbar.update(last_count-pbar.n)
                    
        self.di_buf=di_buf
        self.dq_buf=dq_buf
        
        expt_pts=self.get_expt_pts()
        
        if Average==[]:
            return expt_pts,di_buf,dq_buf
        else:
            avg_di=np.zeros((2,len(Average),expts))
            avg_dq=np.zeros((2,len(Average),expts))
            avg_amp=np.zeros((2,len(Average),expts))
        
            for nn,ii in enumerate(Average):
                avg_di[0][nn]=np.sum(di_buf[0][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_dq[0][nn]=np.sum(dq_buf[0][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_amp[0][nn]=np.sqrt(avg_di[0][nn]**2+avg_dq[0][nn]**2)
            
                avg_di[1][nn]=np.sum(di_buf[1][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_dq[1][nn]=np.sum(dq_buf[1][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_amp[1][nn]=np.sqrt(avg_di[1][nn]**2+avg_dq[1][nn]**2)
            
#         avg_di0=np.sum(di_buf[0][1::2].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
#         avg_dq0=np.sum(dq_buf[0][1::2].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
#         amp_pts0=np.sqrt(avg_di0**2+avg_dq0**2)
        
#         avg_di1=np.sum(di_buf[1][1::2].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][1]
#         avg_dq1=np.sum(dq_buf[1][1::2].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][1]
#         amp_pts1=np.sqrt(avg_di1**2+avg_dq1**2)
        
            return expt_pts, avg_di, avg_dq, avg_amp
    
class RAveragerProgram(ASM_Program):
    def __init__(self, cfg):
        ASM_Program.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        pass
    
    def body(self):
        pass
    
    def update(self):
        pass
    
    def make_program(self):
        p=self
        
        rcount=13
        rii=14
        rjj=15

        p.initialize()

        p.regwi(0, rcount,0)
        
        p.regwi (0, rii, self.cfg["expts"]-1 )
        p.label("LOOP_I")    

        p.regwi (0, rjj, self.cfg["reps"]-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0,rcount,rcount,"+",1)
        
        p.memwi(0,rcount,1)
                
        p.loopnz(0, rjj, 'LOOP_J')

        p.update()
        
        p.loopnz(0, rii, "LOOP_I")    

        p.end()        

    def get_expt_pts(self):
        return self.cfg["start"]+np.arange(self.cfg['expts'])*self.cfg["step"]
        
    def acquire(self, soc, load_pulses=True, progress=True, debug=False):

        if load_pulses: 
            self.load_pulses(soc)
        
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        
        # Configure and enable buffer capture.
        for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
            avg_buf.config_buf(address=0,length=adc_length)
            avg_buf.enable_buf()
            avg_buf.config_avg(address=0,length=adc_length)
            avg_buf.enable_avg()

        soc.tproc.load_asm_program(self,debug=debug)
        
        reps,expts = self.cfg['reps'],self.cfg['expts']
        
        count=0
        last_count=0
        total_count=reps*expts

        di_buf=np.zeros((2,total_count))
        dq_buf=np.zeros((2,total_count))
        
        soc.tproc.stop()
        
        soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0
        self.stats=[]
        
        with tqdm(total=total_count, disable=not progress) as pbar:
            soc.tproc.start()
            while count<total_count-1:
                count = soc.tproc.single_read(addr= 1)

                if count>=min(last_count+1000,total_count-1):
                    addr=last_count % soc.avg_bufs[1].AVG_MAX_LENGTH
                    length = count-last_count
                    length -= length%2

                    for ch in range(2):
                        di,dq = soc.get_accumulated(ch=ch,address=addr, length=length)

                        di_buf[ch,last_count:last_count+length]=di[:length]
                        dq_buf[ch,last_count:last_count+length]=dq[:length]

                    last_count+=length
                    self.stats.append( (time.time(), count,addr, length))
                    pbar.update(last_count-pbar.n)
                    
        self.di_buf=di_buf
        self.dq_buf=dq_buf
        
        avg_di0=np.sum(di_buf[0].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
        avg_dq0=np.sum(dq_buf[0].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
        expt_pts=self.get_expt_pts()
        amp_pts0=np.sqrt(avg_di0**2+avg_dq0**2)
        
        avg_di1=np.sum(di_buf[1].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][1]
        avg_dq1=np.sum(dq_buf[1].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][1]
        amp_pts1=np.sqrt(avg_di1**2+avg_dq1**2)
        
        return expt_pts, avg_di0, avg_dq0, amp_pts0, avg_di1, avg_dq1, amp_pts1