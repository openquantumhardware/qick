from .qick_asm import QickProgram
from tqdm import tqdm_notebook as tqdm
import numpy as np
import time

class AveragerProgram(QickProgram):
    """Abstract base class for programs which do loop over experiments in hardware, consists of a template program which takes care of the loop and acquire methods that talk to the processor to stream single shot data in real-time and then reshape and average it appropriately"""
    
    def __init__(self, cfg):
        """Constructor for the AveragerProgram, calls make program at the end so for classes that inherit from this if you want it to do something before the program is made and compiled either do it before calling this __init__ or put it in the initialize method"""
        QickProgram.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        """Abstract method for initializing the Program and can include any instructions that are executed once at the beginning of the program."""
        pass
    
    def body(self):
        """Abstract method for the body of the program"""
        pass
    
    def make_program(self):
        """A template program which repeats the instructions defined in the body() method the number of times specified in self.cfg["reps"]"""
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
        """This method optionally loads pulses on to the soc, configures the adc readouts, loads the machine code representation of the AveragerProgram onto the soc, starts the program and streams the data into the python, returning it as a set of numpy arrays
            config requirements:
            "reps" = number of repetitions
            "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc
            "adc_lengths" = how many samples to accumulate over for each trigger
        """

        #Load the pulses from the program into the soc
        if load_pulses: 
            self.load_pulses(soc)
        
        #Configure the readout down converters
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        
        # Configure and enable buffer capture.
        for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
            avg_buf.config_buf(address=0,length=adc_length)
            avg_buf.enable_buf()
            avg_buf.config_avg(address=0,length=adc_length)
            avg_buf.enable_avg()

        #load the this AveragerProgram into the soc's tproc
        soc.tproc.load_qick_program(self, debug=debug)
        
        
        reps = self.cfg['reps']
        
        count=0
        last_count=0
        total_count=reps

        di_buf=np.zeros((2,total_count))
        dq_buf=np.zeros((2,total_count))
        
        soc.tproc.stop()
        
        soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0 before starting processor
        self.stats=[]
        
        soc.tproc.start()
        while count<total_count:   # Keep streaming data until you get all of it
            count = soc.tproc.single_read(addr= 1)
            if count>=min(last_count+1000,total_count-1):  #wait until either you've gotten 1000 measurements or until you've finished (so you don't go crazy trying to download every measurement
                addr=last_count % soc.avg_bufs[1].AVG_MAX_LENGTH
                length = count-last_count
                length -= length%2

                for ch in range(2):  #for each adc channel get the single shot data and add it to the buffer
                    di,dq = soc.get_accumulated(ch=ch,address=addr, length=length)

                    di_buf[ch,last_count:last_count+length]=di[:length]
                    dq_buf[ch,last_count:last_count+length]=dq[:length]

                last_count+=length
                self.stats.append( (time.time(), count,addr, length))
                    
        #save results to class in case you want to look at it later or for analysis
        self.di_buf=di_buf
        self.dq_buf=dq_buf
        
        #Average all of the data into a single point
        avg_di0=np.sum(di_buf[0])/(reps)/self.cfg['adc_lengths'][0]
        avg_dq0=np.sum(dq_buf[0])/(reps)/self.cfg['adc_lengths'][0]
        avg_amp0=np.sqrt(avg_di0**2+avg_dq0**2)
        
        avg_di1=np.sum(di_buf[1])/(reps)/self.cfg['adc_lengths'][1]
        avg_dq1=np.sum(dq_buf[1])/(reps)/self.cfg['adc_lengths'][1]
        avg_amp1=np.sqrt(avg_di1**2+avg_dq1**2)        
        
        return avg_di0, avg_dq0, avg_amp0,avg_di1, avg_dq1, avg_amp1

    def acquire_decimated(self, soc, load_pulses=True, progress=True, debug=False):
        """This method acquires the raw (downconverted and decimated) data sampled by the adc
           this method is slow and mostly useful for lining up pulses or doing loopback tests
            config requirements:
            "soft_avgs" = number of repetitions
            "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc
            "adc_lengths" = how many samples to accumulate over for each trigger
        """
        
        #set reps to 1 since we are going to use soft averages
        if "reps" not in self.cfg or self.cfg["reps"] != 1:
            print ("Warning reps is not set to 1, and this acquire method expects reps=1")
        
        #load pulses onto soc
        if load_pulses: 
            self.load_pulses(soc)
        
        #configure the adcs
        for readout,adc_freq in zip(soc.readouts,self.cfg["adc_freqs"]):
            readout.set_out(sel="product")
            readout.set_freq(adc_freq)
        

        soft_avgs=self.cfg["soft_avgs"]        

        di_avg0=np.zeros(self.cfg["adc_lengths"][0])
        dq_avg0=np.zeros(self.cfg["adc_lengths"][0])
        di_avg1=np.zeros(self.cfg["adc_lengths"][1])
        dq_avg1=np.zeros(self.cfg["adc_lengths"][1])
        
        #for each soft average stop the processor, reload the program, run and average decimated data
        for ii in tqdm(range(soft_avgs)):
            soc.tproc.stop()
            # Configure and enable buffer capture.
            for avg_buf,adc_length in zip(soc.avg_bufs, self.cfg["adc_lengths"]):
                avg_buf.config_buf(address=0,length=adc_length)
                avg_buf.enable_buf()
                avg_buf.config_avg(address=0,length=adc_length)
                avg_buf.enable_avg()

            soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0       
            soc.tproc.load_qick_program(self, debug=debug)
        
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
    
class RAveragerProgram(QickProgram):
    """Abstract base class similar to the AveragerProgram, except has an outer loop which allows one to sweep a parameter in the real-time program rather than looping over it in software.  This can be more efficient for short duty cycles.  
    """
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
        """
        Method for calculating experiment points (for x-axis of plots) based on the config
        """
        return self.cfg["start"]+np.arange(self.cfg['expts'])*self.cfg["step"]
        
    def acquire(self, soc, load_pulses=True, ReadoutPerExpt=1, SaveExperiments=[0], debug=False):
        """
        ReadoutPerExpt : How many measurements per experiment (>1 in experiments with conditional reset or just multiple measurements in same experiment
        SaveExperiments: List of indices of experiments to keep (lets one skip conditional reset experiments)
        """

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
        
        if SaveExperiments==[]:
            return expt_pts,di_buf,dq_buf
        else:
            avg_di=np.zeros((2,len(SaveExperiments),expts))
            avg_dq=np.zeros((2,len(SaveExperiments),expts))
            avg_amp=np.zeros((2,len(SaveExperiments),expts))
        
            for nn,ii in enumerate(SaveExperiments):
                avg_di[0][nn]=np.sum(di_buf[0][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_dq[0][nn]=np.sum(dq_buf[0][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_amp[0][nn]=np.sqrt(avg_di[0][nn]**2+avg_dq[0][nn]**2)
            
                avg_di[1][nn]=np.sum(di_buf[1][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_dq[1][nn]=np.sum(dq_buf[1][ii::ReadoutPerExpt].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][0]
                avg_amp[1][nn]=np.sqrt(avg_di[1][nn]**2+avg_dq[1][nn]**2)
        
            return expt_pts, avg_di, avg_dq, avg_amp