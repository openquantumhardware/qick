"""
Several helper classes for writing qubit experiments.
"""
try:
    from tqdm.notebook import tqdm
except:
    from tqdm import tqdm_notebook as tqdm
import numpy as np
from .qick_asm import QickProgram
try:
    from rpyc.utils.classic import obtain
except:
    def obtain(i):
        return i

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

    def acquire_round(self, soc, threshold=None, angle=None, readouts_per_experiment=1, save_experiments=None, load_pulses=True, start_src="internal", progress=False, debug=False):
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
        :param start_src: "internal" (tProc starts immediately) or "external" (waits for an external trigger)
        :type start_src: string
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
            save_experiments = range(readouts_per_experiment)
        # Load the pulses from the program into the soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)
        self.config_bufs(soc, enable_avg=True, enable_buf=False)

        # load this program into the soc's tproc
        self.load_program(soc, debug=debug)

        # configure tproc for internal/external start
        soc.start_src(start_src)

        reps = self.cfg['reps']
        total_count = reps*readouts_per_experiment
        count = 0
        n_ro = len(self.ro_chs)

        d_buf = np.zeros((n_ro, 2, total_count))
        self.stats = []

        with tqdm(total=total_count, disable=not progress) as pbar:
            soc.start_readout(total_count, counter_addr=1,
                                   ch_list=list(self.ro_chs), reads_per_count=readouts_per_experiment)
            while count<total_count:
                new_data = soc.poll_data()
                for d, s in new_data:
                    new_points = d.shape[2]
                    d_buf[:, :, count:count+new_points] = d
                    count += new_points
                    self.stats.append(s)
                    pbar.update(new_points)

        # reformat the data into separate I and Q arrays
        di_buf = d_buf[:,0,:]
        dq_buf = d_buf[:,1,:]

        # save results to class in case you want to look at it later or for analysis
        self.di_buf = di_buf
        self.dq_buf = dq_buf

        if threshold is not None:
            self.shots = self.get_single_shots(
                di_buf, dq_buf, threshold, angle)

        avg_di = np.zeros((n_ro, len(save_experiments)))
        avg_dq = np.zeros((n_ro, len(save_experiments)))

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

        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = range(readouts_per_experiment)
        if "rounds" not in self.cfg or self.cfg["rounds"] == 1:
            return self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, start_src=start_src, load_pulses=load_pulses, progress=progress, debug=debug)

        avg_di = None
        for ii in tqdm(range(self.cfg["rounds"]), disable=not progress):
            avg_di0, avg_dq0 = self.acquire_round(
                soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, start_src=start_src, load_pulses=load_pulses, progress=False, debug=debug)

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

        reps = self.cfg['reps']
        soft_avgs = self.cfg["soft_avgs"]

        # load pulses onto soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)

        # Initialize data buffers
        d_buf = []
        for ch, ro in self.ro_chs.items():
            maxlen = self.soccfg['readouts'][ch]['buf_maxlen']
            if ro.length*reps > maxlen:
                raise RuntimeError("Warning: requested readout length (%d x %d reps) exceeds buffer size (%d)"%(ro.length, reps, maxlen))
            d_buf.append(np.zeros((2, ro.length*reps*readouts_per_experiment)))

        # load the program - it's always the same, so this only needs to be done once
        self.load_program(soc, debug=debug)

        # configure tproc for internal/external start
        tproc = soc.tproc

        soc.start_src(start_src)
        # for each soft average, run and acquire decimated data
        for ii in tqdm(range(soft_avgs), disable=not progress):

            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=True)

            # make sure count variable is reset to 0
            tproc.single_write(addr=1, data=0)

            # run the assembly program
            # if start_src="external", you must pulse the trigger input once for every soft_avg
            tproc.start()

            count = 0
            while count < reps:
                count = tproc.single_read(addr=1)

            for ii, (ch, ro) in enumerate(self.ro_chs.items()):
                d_buf[ii] += obtain(soc.get_decimated(ch=ch,
                                    address=0, length=ro.length*reps*readouts_per_experiment))

        # average the decimated data
        if reps == 1 and readouts_per_experiment == 1:
            return [d/soft_avgs for d in d_buf]
        else:
            # split the data into the individual reps:
            # we reshape to slice each long buffer into reps,
            # then use moveaxis() to transpose the I/Q and rep axes
            result = [np.moveaxis(d.reshape(2, reps*readouts_per_experiment, -1), 0, 1)/soft_avgs for d in d_buf]
            if reps > 1 and readouts_per_experiment > 1:
                result = [d.reshape(reps, readouts_per_experiment, 2, -1) for d in result]
            return result


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

    def acquire_round(self, soc, threshold=None, angle=None,  readouts_per_experiment=1, save_experiments=None, load_pulses=True, start_src="internal", progress=False, debug=False):
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
        :param start_src: "internal" (tProc starts immediately) or "external" (waits for an external trigger)
        :type start_src: string
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
            save_experiments = range(readouts_per_experiment)
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)
        self.config_bufs(soc, enable_avg=True, enable_buf=False)

        # load this program into the soc's tproc
        self.load_program(soc, debug=debug)

        # configure tproc for internal/external start
        soc.start_src(start_src)

        reps, expts = self.cfg['reps'], self.cfg['expts']

        total_count = reps*expts*readouts_per_experiment
        count = 0
        n_ro = len(self.ro_chs)

        d_buf = np.zeros((n_ro, 2, total_count))
        self.stats = []

        with tqdm(total=total_count, disable=not progress) as pbar:
            soc.start_readout(total_count, counter_addr=1, ch_list=list(
                self.ro_chs), reads_per_count=readouts_per_experiment)
            while count<total_count:
                new_data = soc.poll_data()
                for d, s in new_data:
                    new_points = d.shape[2]
                    d_buf[:, :, count:count+new_points] = d
                    count += new_points
                    self.stats.append(s)
                    pbar.update(new_points)

        # reformat the data into separate I and Q arrays
        di_buf = d_buf[:,0,:]
        dq_buf = d_buf[:,1,:]

        # save results to class in case you want to look at it later or for analysis
        self.di_buf = di_buf
        self.dq_buf = dq_buf

        if threshold is not None:
            self.shots = self.get_single_shots(
                di_buf, dq_buf, threshold, angle)

        expt_pts = self.get_expt_pts()

        avg_di = np.zeros((n_ro, len(save_experiments), expts))
        avg_dq = np.zeros((n_ro, len(save_experiments), expts))

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
        if angle is None:
            angle = [0, 0]
        if save_experiments is None:
            save_experiments = range(readouts_per_experiment)
        if "rounds" not in self.cfg or self.cfg["rounds"] == 1:
            return self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment, save_experiments=save_experiments, load_pulses=load_pulses, start_src=start_src, progress=progress, debug=debug)

        avg_di = None
        for ii in tqdm(range(self.cfg["rounds"]), disable=not progress):
            expt_pts, avg_di0, avg_dq0 = self.acquire_round(soc, threshold=threshold, angle=angle, readouts_per_experiment=readouts_per_experiment,
                                                            save_experiments=save_experiments, load_pulses=load_pulses, start_src=start_src, progress=False, debug=debug)

            if avg_di is None:
                avg_di, avg_dq = avg_di0, avg_dq0
            else:
                avg_di += avg_di0
                avg_dq += avg_dq0

        return expt_pts, avg_di/self.cfg["rounds"], avg_dq/self.cfg["rounds"]
