import numpy as np
from qick import *
from qick.asm_v2 import AveragerProgramV2
from qick.asm_v2 import QickSweep1D
from qick.asm_v2 import AsmV2
import matplotlib.pyplot as plt

class PulseProgram(AveragerProgramV2):
    def _initialize(self, cfg):
        ro_ch = cfg['ro_ch']
        gen_ch = cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=cfg['nqz'])
        self.declare_readout(ch=ro_ch, length=cfg['readout_length'])
        self.add_readoutconfig(ch=ro_ch, name="ro", freq=cfg['freq'], gen_ch=gen_ch, phase=0, outsel='product')        
        self.add_pulse(ch=gen_ch, name="tofpulse", ro_ch=ro_ch, style=cfg['pulse_style'], freq=cfg['freq'], length=cfg['pulse_length'], phase=0, gain=cfg['pulse_gain'])
        self.send_readoutconfig(ch=ro_ch, name="ro", t=0)
        
    def _body(self, cfg):
        self.pulse(ch=cfg['gen_ch'], name="tofpulse", t=0)
        self.trigger(ros=[cfg['ro_ch']], pins=[0], t=cfg['adc_trig_offset'])

class FreqSweepProgram(AveragerProgramV2):
    def _initialize(self, cfg):
        ro_ch = cfg['ro_ch']
        gen_ch = cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=cfg['nqz'])
        self.declare_readout(ch=ro_ch, length=cfg['readout_length'])
        self.add_readoutconfig(ch=ro_ch, name="ro", freq=cfg['freq'], gen_ch=gen_ch)
        loopbefore = AsmV2()
        loopbefore.send_readoutconfig(ch=cfg['ro_ch'], name="ro", t=0)
        self.add_loop("loop", self.cfg["steps"], exec_before=loopbefore)
        self.add_pulse(ch=gen_ch, name="pulse", ro_ch=ro_ch, style=cfg['pulse_style'], freq=cfg['freq'], length=cfg['pulse_length'], phase=0, gain=cfg['pulse_gain'])
        
    def _body(self, cfg):
        self.pulse(ch=cfg['gen_ch'], name="pulse", t=0)
        self.trigger(ros=[cfg['ro_ch']], pins=[0], t=cfg['adc_trig_offset'])

class Spectroscopy():
    def set_parameters(self, socc, soccfgg, f_start, f_stop, nb_step, nb_rep, power_in, ch_gen, ch_ro, nqz=1):
        self.parameters = {"gen_ch":ch_gen, # --Fixed
                       "ro_ch":ch_ro, # --Fixed
                       "steps":nb_step, # --Fixed
                        "reps":nb_rep,
                       "gen_phase":0, # --degrees
                       "pulse_style": "const", # --Fixed
                       "pulse_length":1, # [us]
                       "readout_length":0.5, # [us]
                       "pulse_gain":power_in, # [V]
                       "freq_start": f_start, # [MHz]
                       "freq_stop": f_stop, # [MHz]
                       "freq":0,
                       "nb_steps": nb_step,
                       "nqz": nqz,
                       "adc_trig_offset": 0 # [us]
                       }
        self.soc = socc
        self.soccfg = soccfgg
        
    def tof_measure(self):
        config_tof = {"gen_ch":self.parameters["gen_ch"], # --Fixed
                   "ro_ch":self.parameters["ro_ch"], # --Fixed
                   "pulse_style": "const", # --Fixed
                   "pulse_length":1, # [us]
                   "readout_length":2, # [us]
                   "pulse_gain":self.parameters["pulse_gain"], # [V]
                   "freq": int((self.parameters["freq_start"] + self.parameters["freq_stop"])/2), # [MHz]
                   "adc_trig_offset": 0, # [us]
                   "nqz": 1,
                   }
        prog = PulseProgram(self.soccfg, reps=1, final_delay=0, cfg=config_tof)
        iq_list = prog.acquire_decimated(self.soc, soft_avgs=10, progress=False)
        magnitude = np.abs(iq_list[0][:,0] + 1j*iq_list[0][:,1])
        t = prog.get_time_axis(ro_index=0)
        trig1 = 150
        trig2 = 0
        try:
            trig1 = np.where(magnitude > 25)[0][0]-50
            config_tof["adc_trig_offset"] = t[trig1]
            config_tof["readout_length"] = 1
            config_tof["pulse_length"] = 0.5
        except:
            print("No connection between emitter and receiver")
        prog = PulseProgram(self.soccfg, reps=1, final_delay=0, cfg=config_tof)
        iq_list = prog.acquire_decimated(self.soc, soft_avgs=10, progress=False)
        magnitude = np.abs(iq_list[0][:,0] + 1j*iq_list[0][:,1])
        try:
            trig2 = np.where(magnitude > 25)[0][0]
        except:
            print("No connection between emitter and receiver")
        print("trigger offset: ", t[trig1+trig2], " us")
        return(t[trig1+trig2])

    def fit_delay(self, freqs, iqs, initial_delay=0):
        iq_complex = iqs.dot([1,1j])
        iq_complex *= np.exp(-1j*freqs*2*np.pi*initial_delay)
        phases = np.unwrap(np.angle(iq_complex))/(2*np.pi)
        a = np.vstack([freqs, np.ones_like(freqs)]).T
        phase_delay = np.linalg.lstsq(a, phases, rcond=None)[0][0]
        total_delay = initial_delay + phase_delay
        return total_delay
        
    def run_spectroscopy(self):
        trig_off = self.tof_measure()
        self.parameters["adc_trig_offset"] = trig_off + 0.1 # us
        self.parameters['freq'] = QickSweep1D("loop", self.parameters["freq_start"], self.parameters["freq_stop"])
        
        prog = FreqSweepProgram(self.soccfg, reps=self.parameters["reps"], final_delay=1.0, cfg=self.parameters)
        freqs = prog.get_pulse_param('ro', 'freq', as_array=True)
        iq_list = prog.acquire(self.soc, soft_avgs=1, progress=False)
        iq_complex = iq_list[0][0].dot([1,1j])
        delay_cal = self.fit_delay(freqs, iq_list[0][0], self.parameters["adc_trig_offset"])
        iq_rotated = iq_complex*np.exp(-1j*freqs*2*np.pi*delay_cal)
        mag = np.abs(iq_rotated)
        phase = 360*np.unwrap(np.angle(iq_rotated))/(2*np.pi)
        plt.rcParams['figure.figsize'] = [12, 4]
        fig, (ax1, ax2) = plt.subplots(1, 2)
        fig.suptitle('Spectroscopy')
        ax1.semilogy(freqs, mag)
        ax1.set_xlabel("Frequency (MHz)")
        ax1.set_ylabel("Amplitude (ADC units)")
        ax2.plot(freqs, phase)
        ax2.set_xlabel("Frequency (MHz)")
        ax2.set_ylabel("Phase (°)")
        fig.tight_layout()
        plt.show()
        return(freqs, mag, phase)