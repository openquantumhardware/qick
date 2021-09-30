"""
Several helper classes for writing qubit experiments.
"""
from .qick_asm import QickProgram
from tqdm import tqdm_notebook as tqdm
import numpy as np
import time

class AveragerProgram(QickProgram):
    """
    AveragerProgram class is an abstract base class for programs which do loop over experiments in hardware. It consists of a template program which takes care of the loop and acquire methods that talk to the processor to stream single shot data in real-time and then reshape and average it appropriately.

    :param cfg: Configuration dictionary
    :type cfg: dict
    """
    def __init__(self, cfg):
        """
        Constructor for the AveragerProgram, calls make program at the end so for classes that inherit from this if you want it to do something before the program is made and compiled either do it before calling this __init__ or put it in the initialize method.
        """
        QickProgram.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        """
        Abstract method for initializing the program and can include any instructions that are executed once at the beginning of the program.
        """
        pass
    
    def body(self):
        """
        Abstract method for the body of the program
        """
        pass
    
    def make_program(self):
        """
        A template program which repeats the instructions defined in the body() method the number of times specified in self.cfg["reps"].
        """
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
        
    def acquire_round(self, soc, threshold=None, angle=[0,0], readouts_per_experiment=1, save_experiments=[0], load_pulses=True, progress=True, debug=False):
        """
        This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.

        config requirements:
        "reps" = number of repetitions;
        "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc;
        "adc_lengths" = how many samples to accumulate over for each trigger;

        :param soc: Qick object
        :type soc: Qick object
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list
        :param readouts_per_experiment: readouts per experiment
        :type readouts_per_experiment: int
        :param save_experiments: saved experiments
        :type save_experiments: list
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
            - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
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

        if threshold is not None:
            self.shots=self.get_single_shots(di_buf,dq_buf, threshold, angle)

        avg_di=np.zeros((2,len(save_experiments)))
        avg_dq=np.zeros((2,len(save_experiments)))

        for nn,ii in enumerate(save_experiments):
            for ch in range (2):
                if threshold is None:
                    avg_di[ch][nn]=np.sum(di_buf[ch][ii::readouts_per_experiment])/(reps)/self.cfg['adc_lengths'][ch]
                    avg_dq[ch][nn]=np.sum(dq_buf[ch][ii::readouts_per_experiment])/(reps)/self.cfg['adc_lengths'][ch]
                else:
                    avg_di[ch][nn]=np.sum(self.shots[ch][ii::readouts_per_experiment])/(reps)
                    avg_dq=np.zeros(avg_di.shape)

        return avg_di, avg_dq
    
    def acquire(self, soc, threshold=None, angle=[0,0], readouts_per_experiment=1, save_experiments=[0], load_pulses=True, progress=True, debug=False):
        """
        This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.
        config requirements:
        "reps" = number of repetitions;
        "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc;
        "adc_lengths" = how many samples to accumulate over for each trigger;

        :param soc: Qick object
        :type soc: Qick object
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list
        :param readouts_per_experiment: readouts per experiment
        :type readouts_per_experiment: int
        :param save_experiments: saved experiments
        :type save_experiments: list
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - expt_pts (:py:class:`list`) - list of experiment points
            - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
            - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
        """

        if "rounds" not in self.cfg or self.cfg["rounds"]==1:
            return self.acquire_round(soc,threshold=threshold, angle=angle, load_pulses=load_pulses,progress=progress, debug=debug)
        
        avg_di=None
        for ii in tqdm(range (self.cfg["rounds"]), disable=not progress):           
            avg_di0, avg_dq0, avg_amp0=self.acquire_round(soc,threshold=threshold, angle=angle, load_pulses=load_pulses,progress=False, debug=debug)
            
            if avg_di is None:
                avg_di, avg_dq = avg_di0, avg_dq0
            else:
                avg_di+= avg_di0
                avg_dq+= avg_dq0
                
        return expt_pts, avg_di/self.cfg["rounds"], avg_dq/self.cfg["rounds"]
    
    def get_single_shots(self, di, dq, threshold, angle=[0,0]):
        """
        This method converts the raw I/Q data to single shots according to the threshold and rotation angle

        :param di: Raw I data
        :type di: list
        :param dq: Raw Q data
        :type dq: list
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list

        :returns:
            - single_shot_array (:py:class:`array`) - Numpy array of single shot data

        """

        if type(threshold) is int:
            threshold=[threshold,threshold]            
        return np.array([np.heaviside((di[ch]*np.cos(angle[ch]) - dq[ch]*np.sin(angle[ch]))/self.cfg['adc_lengths'][ch]-threshold[ch],0) for ch in range(2)])        

    def acquire_decimated(self, soc, load_pulses=True, progress=True, debug=False):
        """
         This method acquires the raw (downconverted and decimated) data sampled by the ADC. This method is slow and mostly useful for lining up pulses or doing loopback tests.

         config requirements:
         "reps" = number of repetitions;
         "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc;
         "adc_lengths" = how many samples to accumulate over for each trigger;

         :param soc: Qick object
         :type soc: Qick object
         :param load_pulses: If true, loads pulses into the tProc
         :type load_pulses: bool
         :param progress: If true, displays progress bar
         :type progress: bool
         :param debug: If true, displays assembly code for tProc program
         :type debug: bool
         :returns:
             - iq0 (:py:class:`list`) - list of lists of averaged decimated I and Q data ADC 0
             - iq1 (:py:class:`list`) - list of lists of averaged decimated I and Q data ADC 1
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
        for ii in tqdm(range(soft_avgs),disable=not progress):
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
            
        return np.array([di_avg0,dq_avg0])/soft_avgs,np.array([di_avg1,dq_avg1])/soft_avgs
    
class RAveragerProgram(QickProgram):
    """
    RAveragerProgram class, for qubit experiments that sweep over a variable (whose value is stored in expt_pts).
    It is an abstract base class similar to the AveragerProgram, except has an outer loop which allows one to sweep a parameter in the real-time program rather than looping over it in software.  This can be more efficient for short duty cycles.
    Acquire gathers data from both ADCs 0 and 1.

    :param cfg: Configuration dictionary
    :type cfg: dict
    """
    def __init__(self, cfg):
        """
        Constructor for the RAveragerProgram, calls make program at the end so for classes that inherit from this if you want it to do something before the program is made and compiled either do it before calling this __init__ or put it in the initialize method.
        """
        QickProgram.__init__(self)
        self.cfg=cfg
        self.make_program()
    
    def initialize(self):
        """
        Abstract method for initializing the program and can include any instructions that are executed once at the beginning of the program.
        """
        pass
    
    def body(self):
        """
        Abstract method for the body of the program
        """
        pass
    
    def update(self):
        """
        Abstract method for updating the program
        """
        pass
    
    def make_program(self):
        """
        A template program which repeats the instructions defined in the body() method the number of times specified in self.cfg["reps"].
        """
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
        Method for calculating experiment points (for x-axis of plots) based on the config.

        :return: Numpy array of experiment points
        :rtype: array
        """
        return self.cfg["start"]+np.arange(self.cfg['expts'])*self.cfg["step"]
        
    def acquire_round(self, soc, threshold=None, angle=[0,0],  readouts_per_experiment=1, save_experiments=[0], load_pulses=True, progress=True, debug=False):
        """
         This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.

         config requirements:
         "reps" = number of repetitions;
         "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc;
         "adc_lengths" = how many samples to accumulate over for each trigger;

         :param soc: Qick object
         :type soc: Qick object
         :param threshold: threshold
         :type threshold: int
         :param angle: rotation angle
         :type angle: list
         :param readouts_per_experiment: readouts per experiment
         :type readouts_per_experiment: int
         :param save_experiments: saved experiments
         :type save_experiments: list
         :param load_pulses: If true, loads pulses into the tProc
         :type load_pulses: bool
         :param progress: If true, displays progress bar
         :type progress: bool
         :param debug: If true, displays assembly code for tProc program
         :type debug: bool
         :returns:
             - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
             - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
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

        soc.tproc.load_qick_program(self, debug=debug)
        
        reps,expts = self.cfg['reps'],self.cfg['expts']
        
        count=0
        last_count=0
        total_count=reps*expts*readouts_per_experiment

        di_buf=np.zeros((2,total_count))
        dq_buf=np.zeros((2,total_count))
        
        soc.tproc.stop()
        
        soc.tproc.single_write(addr= 1,data=0)   #make sure count variable is reset to 0
        self.stats=[]
        
        with tqdm(total=total_count, disable=not progress) as pbar:
            soc.tproc.start()
            while count<total_count-1:
                count = soc.tproc.single_read(addr= 1)*readouts_per_experiment

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
        
        if threshold is not None:
            self.shots=self.get_single_shots(di_buf,dq_buf, threshold, angle)
                
        expt_pts=self.get_expt_pts()
        

        avg_di=np.zeros((2,len(save_experiments),expts))
        avg_dq=np.zeros((2,len(save_experiments),expts))

        for nn,ii in enumerate(save_experiments):
            for ch in range (2):
                if threshold is None:
                    avg_di[ch][nn]=np.sum(di_buf[ch][ii::readouts_per_experiment].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][ch]
                    avg_dq[ch][nn]=np.sum(dq_buf[ch][ii::readouts_per_experiment].reshape((expts, reps)),1)/(reps)/self.cfg['adc_lengths'][ch]
                else:
                    avg_di[ch][nn]=np.sum(self.shots[ch][ii::readouts_per_experiment].reshape((expts, reps)),1)/(reps)
                    avg_dq=np.zeros(avg_di.shape)

        return expt_pts, avg_di, avg_dq

    def get_single_shots(self, di, dq, threshold, angle=[0,0]):
        """
        This method converts the raw I/Q data to single shots according to the threshold and rotation angle

        :param di: Raw I data
        :type di: list
        :param dq: Raw Q data
        :type dq: list
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list

        :returns:
            - single_shot_array (:py:class:`array`) - Numpy array of single shot data

        """

        if type(threshold) is int:
            threshold=[threshold,threshold]            
        return np.array([np.heaviside((di[ch]*np.cos(angle[ch]) - dq[ch]*np.sin(angle[ch]))/self.cfg['adc_lengths'][ch]-threshold[ch],0) for ch in range(2)])
                    
    def acquire(self, soc, threshold=None, angle=[0,0], load_pulses=True, readouts_per_experiment=1, save_experiments=[0], progress=True, debug=False):
        """
        This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.
        config requirements:
        "reps" = number of repetitions;
        "adc_freqs" = [freq1, freq2] the downconverting frequencies (in MHz) to be used in the adc_ddc;
        "adc_lengths" = how many samples to accumulate over for each trigger;

        :param soc: Qick object
        :type soc: Qick object
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list
        :param readouts_per_experiment: readouts per experiment
        :type readouts_per_experiment: int
        :param save_experiments: saved experiments
        :type save_experiments: list
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - expt_pts (:py:class:`list`) - list of experiment points
            - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
            - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
        """
        if "rounds" not in self.cfg or self.cfg["rounds"]==1:
            return self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, load_pulses=load_pulses, progress=progress, debug=debug)
        
        avg_di=None
        for ii in tqdm(range (self.cfg["rounds"]), disable=not progress):
            expt_pts, avg_di0, avg_dq0=self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, load_pulses=load_pulses, progress=False, debug=debug)
            
            if avg_di is None:
                avg_di, avg_dq= avg_di0, avg_dq0
            else:
                avg_di+= avg_di0
                avg_dq+= avg_dq0
        
                
        return expt_pts, avg_di/self.cfg["rounds"], avg_dq/self.cfg["rounds"]