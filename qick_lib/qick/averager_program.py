"""
Several helper classes for writing qubit experiments.
"""
from tqdm.notebook import tqdm
import numpy as np
from .qick_asm import QickProgram


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
        p.regwi(0, rjj, self.cfg["reps"]-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0, rcount, rcount, "+", 1)

        p.memwi(0, rcount, 1)

        p.loopnz(0, rjj, 'LOOP_J')

        p.end()

    def acquire_round(self, soc, threshold=None, angle=None, readouts_per_experiment=1, save_experiments=None, load_pulses=True, progress=False, debug=False):
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

        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = [0]
        # Load the pulses from the program into the soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)
        self.config_bufs(soc, enable_avg=True, enable_buf=True)

        # load this program into the soc's tproc
        self.load_program(soc, debug=debug)

        reps = self.cfg['reps']
        total_count = reps
        count = 0
        t = tqdm(total=total_count, disable=not progress)  # progress bar

        d_buf = np.zeros((len(self.ro_chs), 2, total_count))
        stats_list = []

        streamer = soc.streamer
        streamer.start_readout(total_count, counter_addr=1,
                               ch_list=list(self.ro_chs))
        while streamer.readout_alive():
            new_data = streamer.poll_data()
            for d, s in new_data:
                new_points = d.shape[2]
                d_buf[:, :, count:count+new_points] = d
                count += new_points
                stats_list.append(s)
                t.update(new_points)
        t.close()
        self.stats = stats_list

        # reformat the data into separate I and Q arrays
        di_buf = np.stack([d_buf[i][0] for i in range(len(self.ro_chs))])
        dq_buf = np.stack([d_buf[i][1] for i in range(len(self.ro_chs))])

        # save results to class in case you want to look at it later or for analysis
        self.di_buf = di_buf
        self.dq_buf = dq_buf

        if threshold is not None:
            self.shots = self.get_single_shots(
                di_buf, dq_buf, threshold, angle)

        avg_di = np.zeros((len(self.ro_chs), len(save_experiments)))
        avg_dq = np.zeros((len(self.ro_chs), len(save_experiments)))

        for nn, ii in enumerate(save_experiments):
            for i_ch, (ch, ro) in enumerate(self.ro_chs.items()):
                if threshold is None:
                    avg_di[i_ch][nn] = np.sum(
                        di_buf[i_ch][ii::readouts_per_experiment])/(reps)/ro.length
                    avg_dq[i_ch][nn] = np.sum(
                        dq_buf[i_ch][ii::readouts_per_experiment])/(reps)/ro.length
                else:
                    avg_di[i_ch][nn] = np.sum(
                        self.shots[i_ch][ii::readouts_per_experiment])/(reps)
                    avg_dq = np.zeros(avg_di.shape)

        return avg_di, avg_dq

    def acquire(self, soc, threshold=None, angle=None, readouts_per_experiment=1, save_experiments=None, load_pulses=True, progress=False, debug=False):
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

        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = [0]
        if "rounds" not in self.cfg or self.cfg["rounds"] == 1:
            return self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, load_pulses=load_pulses, progress=progress, debug=debug)

        avg_di = None
        for ii in tqdm(range(self.cfg["rounds"]), disable=not progress):
            avg_di0, avg_dq0 = self.acquire_round(
                soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, load_pulses=load_pulses, progress=False, debug=debug)

            if avg_di is None:
                avg_di, avg_dq = avg_di0, avg_dq0
            else:
                avg_di += avg_di0
                avg_dq += avg_dq0

        return avg_di/self.cfg["rounds"], avg_dq/self.cfg["rounds"]

    def get_single_shots(self, di, dq, threshold, angle=None):
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

        if angle is None:
            angle = [0, 0]
        if isinstance(threshold, int):
            threshold = [threshold, threshold]
        return np.array([np.heaviside((di[i]*np.cos(angle[i]) - dq[i]*np.sin(angle[i]))/self.ro_chs[ch].length-threshold[i], 0) for i, ch in enumerate(self.ro_chs)])

    def acquire_decimated(self, soc, load_pulses=True, progress=True, debug=False):
        """
         This method acquires the raw (downconverted and decimated) data sampled by the ADC. This method is slow and mostly useful for lining up pulses or doing loopback tests.

         config requirements:
         "reps" = number of repetitions;

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
        # set reps to 1 since we are going to use soft averages
        if "reps" not in self.cfg or self.cfg["reps"] != 1:
            print("Warning reps is not set to 1, and this acquire method expects reps=1")

        # load pulses onto soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)

        # assume every channel has the same readout length
        d_buf = np.zeros((len(self.ro_chs), 2, max(
            [ro.length for ro in self.ro_chs.values()])))

        soft_avgs = self.cfg["soft_avgs"]

        # load the program - it's always the same, so this only needs to be done once
        self.load_program(soc, debug=debug)

        tproc = soc.tproc
        # for each soft average, run and acquire decimated data
        for ii in tqdm(range(soft_avgs), disable=not progress):

            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=True)

            # make sure count variable is reset to 0
            tproc.single_write(addr=1, data=0)
            tproc.start()  # runs the assembly program

            count = 0
            while count < 1:
                count = tproc.single_read(addr=1)

            for ii, (ch, ro) in enumerate(self.ro_chs.items()):
                d_buf[ii] += soc.get_decimated(ch=ch,
                                               address=0, length=ro.length)

        # average the decimated data
        return [d/soft_avgs for d in d_buf]


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

        p.regwi(0, rii, self.cfg["expts"]-1)
        p.label("LOOP_I")

        p.regwi(0, rjj, self.cfg["reps"]-1)
        p.label("LOOP_J")

        p.body()

        p.mathi(0, rcount, rcount, "+", 1)

        p.memwi(0, rcount, 1)

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

    def acquire_round(self, soc, threshold=None, angle=None,  readouts_per_experiment=1, save_experiments=None, load_pulses=True, progress=False, debug=False):
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

        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = [0]
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)
        self.config_bufs(soc, enable_avg=True, enable_buf=True)

        # load this program into the soc's tproc
        self.load_program(soc, debug=debug)

        reps, expts = self.cfg['reps'], self.cfg['expts']

        count = 0
        total_count = reps*expts*readouts_per_experiment

        d_buf = np.zeros((len(self.ro_chs), 2, total_count))
        streamer = soc.streamer
        stats_list = []

        with tqdm(total=total_count, disable=not progress) as pbar:
            streamer.start_readout(total_count, counter_addr=1, ch_list=list(
                self.ro_chs), reads_per_count=readouts_per_experiment)
            while streamer.readout_alive():
                new_data = streamer.poll_data()
                for d, s in new_data:
                    new_points = d.shape[2]
                    d_buf[:, :, count:count+new_points] = d
                    count += new_points
                    stats_list.append(s)
                    pbar.update(new_points)
            self.stats = stats_list

        # reformat the data into separate I and Q arrays
        di_buf = np.stack([d_buf[i][0] for i in range(len(self.ro_chs))])
        dq_buf = np.stack([d_buf[i][1] for i in range(len(self.ro_chs))])

        # save results to class in case you want to look at it later or for analysis
        self.di_buf = di_buf
        self.dq_buf = dq_buf

        if threshold is not None:
            self.shots = self.get_single_shots(
                di_buf, dq_buf, threshold, angle)

        expt_pts = self.get_expt_pts()

        avg_di = np.zeros((len(self.ro_chs), len(save_experiments), expts))
        avg_dq = np.zeros((len(self.ro_chs), len(save_experiments), expts))

        for nn, ii in enumerate(save_experiments):
            for i_ch, (ch, ro) in enumerate(self.ro_chs.items()):
                if threshold is None:
                    avg_di[i_ch][nn] = np.sum(di_buf[i_ch][ii::readouts_per_experiment].reshape(
                        (expts, reps)), 1)/(reps)/ro.length
                    avg_dq[i_ch][nn] = np.sum(dq_buf[i_ch][ii::readouts_per_experiment].reshape(
                        (expts, reps)), 1)/(reps)/ro.length
                else:
                    avg_di[i_ch][nn] = np.sum(
                        self.shots[i_ch][ii::readouts_per_experiment].reshape((expts, reps)), 1)/(reps)
                    avg_dq = np.zeros(avg_di.shape)

        return expt_pts, avg_di, avg_dq

    def get_single_shots(self, di, dq, threshold, angle=None):
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

        if angle is None:
            angle = [0, 0]
        if type(threshold) is int:
            threshold = [threshold, threshold]
        return np.array([np.heaviside((di[i]*np.cos(angle[i]) - dq[i]*np.sin(angle[i]))/self.ro_chs[ch].length-threshold[i], 0) for i, ch in enumerate(self.ro_chs)])

    def acquire(self, soc, threshold=None, angle=None, load_pulses=True, readouts_per_experiment=1, save_experiments=None, progress=False, debug=False):
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
        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = [0]
        if "rounds" not in self.cfg or self.cfg["rounds"] == 1:
            return self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, load_pulses=load_pulses, progress=progress, debug=debug)

        avg_di = None
        for ii in tqdm(range(self.cfg["rounds"]), disable=not progress):
            expt_pts, avg_di0, avg_dq0 = self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment,
                                                            save_experiments=save_experiments, load_pulses=load_pulses, progress=False, debug=debug)

            if avg_di is None:
                avg_di, avg_dq = avg_di0, avg_dq0
            else:
                avg_di += avg_di0
                avg_dq += avg_dq0

        return expt_pts, avg_di/self.cfg["rounds"], avg_dq/self.cfg["rounds"]
