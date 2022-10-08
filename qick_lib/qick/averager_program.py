"""
Several helper classes for writing qubit experiments.
"""
try:
    from tqdm.notebook import tqdm
except:
    from tqdm import tqdm_notebook as tqdm
import numpy as np
from .qick_asm import QickProgram, obtain

class AveragerProgram(QickProgram):
    """
    AveragerProgram class is an abstract base class for programs which do loops over experiments in hardware.
    It consists of a template program which takes care of the loop and acquire methods that talk to the processor to stream single shot data in real-time and then reshape and average it appropriately.

    :param soccfg: This can be either a QickSOc object (if the program is running on the QICK) or a QickCOnfig (if running remotely).
    :type soccfg: QickConfig
    :param cfg: Configuration dictionary
    :type cfg: dict
    """

    def __init__(self, soccfg, cfg):
        """
        Constructor for the AveragerProgram, calls make program at the end.
        For classes that inherit from this, if you want it to do something before the program is made and compiled:
        either do it before calling this __init__ or put it in the initialize method.
        """
        super().__init__(soccfg)
        self.cfg = cfg
        self.reps = cfg['reps']
        if "soft_avgs" in cfg:
            self.rounds = cfg['soft_avgs']
        if "rounds" in cfg:
            self.rounds = cfg['rounds']
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
        p = self

        rjj = 14
        rcount = 15
        p.initialize()
        p.regwi(0, rcount, 0)
        p.regwi(0, rjj, self.reps-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0, rcount, rcount, "+", 1)

        p.memwi(0, rcount, self.counter_addr)

        p.loopnz(0, rjj, 'LOOP_J')

        p.end()


    def acquire(self, soc, threshold=None, angle=None, readouts_per_experiment=1, save_experiments=None, load_pulses=True, start_src="internal", progress=False, debug=False):
        """
        This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.
        config requirements:
        "reps" = number of repetitions;

        :param soc: Qick object
        :type soc: Qick object
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list
        :param readouts_per_experiment: readouts per experiment
        :type readouts_per_experiment: int
        :param save_experiments: saved readouts (by default, save all readouts)
        :type save_experiments: list
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param start_src: "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        :type start_src: string
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - expt_pts (:py:class:`list`) - list of experiment points
            - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
            - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
        """

        self.shot_angle = angle
        self.shot_threshold = threshold

        if save_experiments is None:
            save_experiments = range(readouts_per_experiment)

        d_buf, avg_d, shots = super().acquire(soc, reads_per_rep=readouts_per_experiment, load_pulses=load_pulses, start_src=start_src, progress=progress, debug=debug)

        # reformat the data into separate I and Q arrays
        # save results to class in case you want to look at it later or for analysis
        self.di_buf = d_buf[:,:,0]
        self.dq_buf = d_buf[:,:,1]

        if threshold is not None:
            self.shots = shots

        n_ro = len(self.ro_chs)
        avg_di = np.zeros((n_ro, len(save_experiments)))
        avg_dq = np.zeros((n_ro, len(save_experiments)))

        for nn, ii in enumerate(save_experiments):
            for i_ch, (ch, ro) in enumerate(self.ro_chs.items()):
                avg_di[i_ch][nn] = avg_d[i_ch, ii, 0]
                avg_dq[i_ch][nn] = avg_d[i_ch, ii, 1]

        return avg_di, avg_dq


    def acquire_decimated(self, soc, load_pulses=True, readouts_per_experiment=1, start_src="internal", progress=True, debug=False):
        """
        This method acquires the raw (downconverted and decimated) data sampled by the ADC. This method is slow and mostly useful for lining up pulses or doing loopback tests.

        config requirements:
        "reps" = number of tProc loop repetitions;
        "soft_avgs" = number of Python loop repetitions;

        The data is returned as a list of ndarrays (one ndarray per readout channel).
        There are two possible array formats.
        reps = 1:
        2D array with dimensions (2, length), indices (I/Q, sample)
        reps > 1:
        3D array with dimensions (reps, 2, length), indices (rep, I/Q, sample)
        readouts_per_experiment>1:
        3D array with dimensions (reps, expts, 2, length), indices (rep, expt, I/Q, sample)

        :param soc: Qick object
        :type soc: Qick object
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param readouts_per_experiment: readouts per experiment (all will be saved)
        :type readouts_per_experiment: int
        :param start_src: "internal" (tProc starts immediately) or "external" (each soft_avg waits for an external trigger)
        :type start_src: string
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - iq_list (:py:class:`list`) - list of lists of averaged decimated I and Q data
        """

        buf = super().acquire_decimated(soc, reads_per_rep=readouts_per_experiment, load_pulses=load_pulses, start_src=start_src, progress=progress, debug=debug)
        # move the I/Q axis from last to second-last
        return np.moveaxis(buf, -1, -2)

class RAveragerProgram(QickProgram):
    """
    RAveragerProgram class, for qubit experiments that sweep over a variable (whose value is stored in expt_pts).
    It is an abstract base class similar to the AveragerProgram, except has an outer loop which allows one to sweep a parameter in the real-time program rather than looping over it in software.  This can be more efficient for short duty cycles.
    Acquire gathers data from both ADCs 0 and 1.

    :param cfg: Configuration dictionary
    :type cfg: dict
    """

    def __init__(self, soccfg, cfg):
        """
        Constructor for the RAveragerProgram, calls make program at the end so for classes that inherit from this if you want it to do something before the program is made and compiled either do it before calling this __init__ or put it in the initialize method.
        """
        super().__init__(soccfg)
        self.cfg = cfg
        self.reps = cfg['reps']
        self.expts = cfg['expts']
        if "rounds" in cfg:
            self.rounds = cfg['rounds']
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
        p = self

        rcount = 13
        rii = 14
        rjj = 15

        p.initialize()

        p.regwi(0, rcount, 0)

        p.regwi(0, rii, self.expts-1)
        p.label("LOOP_I")

        p.regwi(0, rjj, self.reps-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0, rcount, rcount, "+", 1)

        p.memwi(0, rcount, self.counter_addr)

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
        return self.cfg["start"]+np.arange(self.expts)*self.cfg["step"]

    def acquire(self, soc, threshold=None, angle=None, load_pulses=True, readouts_per_experiment=1, save_experiments=None, start_src="internal", progress=False, debug=False):
        """
        This method optionally loads pulses on to the SoC, configures the ADC readouts, loads the machine code representation of the AveragerProgram onto the SoC, starts the program and streams the data into the Python, returning it as a set of numpy arrays.
        config requirements:
        "reps" = number of repetitions;

        :param soc: Qick object
        :type soc: Qick object
        :param threshold: threshold
        :type threshold: int
        :param angle: rotation angle
        :type angle: list
        :param readouts_per_experiment: readouts per experiment
        :type readouts_per_experiment: int
        :param save_experiments: saved readouts (by default, save all readouts)
        :type save_experiments: list
        :param load_pulses: If true, loads pulses into the tProc
        :type load_pulses: bool
        :param start_src: "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        :type start_src: string
        :param progress: If true, displays progress bar
        :type progress: bool
        :param debug: If true, displays assembly code for tProc program
        :type debug: bool
        :returns:
            - expt_pts (:py:class:`list`) - list of experiment points
            - avg_di (:py:class:`list`) - list of lists of averaged accumulated I data for ADCs 0 and 1
            - avg_dq (:py:class:`list`) - list of lists of averaged accumulated Q data for ADCs 0 and 1
        """
        self.shot_angle = angle
        self.shot_threshold = threshold

        if save_experiments is None:
            save_experiments = range(readouts_per_experiment)

        d_buf, avg_d, shots = super().acquire(soc, reads_per_rep=readouts_per_experiment, load_pulses=load_pulses, start_src=start_src, progress=progress, debug=debug)

        # reformat the data into separate I and Q arrays
        # save results to class in case you want to look at it later or for analysis
        self.di_buf = d_buf[:,:,0]
        self.dq_buf = d_buf[:,:,1]

        if threshold is not None:
            self.shots = shots

        expt_pts = self.get_expt_pts()

        n_ro = len(self.ro_chs)
        avg_di = np.zeros((n_ro, len(save_experiments), self.expts))
        avg_dq = np.zeros((n_ro, len(save_experiments), self.expts))

        for nn, ii in enumerate(save_experiments):
            for i_ch, (ch, ro) in enumerate(self.ro_chs.items()):
                avg_di[i_ch][nn] = avg_d[i_ch, ii, :, 0]
                avg_dq[i_ch][nn] = avg_d[i_ch, ii, :, 1]

        return expt_pts, avg_di, avg_dq

