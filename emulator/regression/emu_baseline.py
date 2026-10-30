"""Baseline driver for QICKEmu.

usage: emu_baseline.py <repo_root> <out_dir> [--build]

<repo_root> holds emulator/ and qick_lib/. Runs the programs of notebooks/00_intro_emu.ipynb
(multi_pulse and simple_sweep, decimated and averaged; the muxed generator with two PFB readouts; the standard readout) and saves every returned array as .npy
and the md5 of the arrays in <out_dir>/md5.txt. Compare it with baseline_legacy_md5.txt.

Environment: PRE_RUN_DELAY_NS (default 0) pins the start-up jitter that qick_emu draws at
random; TEST_RUN_NS_AVG (default 50000) is the simulated time of the averaged runs, which
return zeros if the simulation ends before the averager is done. See README.md.
"""
import hashlib
import pathlib
import sys

import numpy as np

root = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2]).resolve()
build = '--build' in sys.argv
out.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(root / 'qick_lib'))
sys.path.insert(0, str(root / 'emulator' / 'software'))

from qick_emu import QickEmu  # noqa: E402
from qick.asm_v2 import AveragerProgramV2, QickSweep1D  # noqa: E402

GEN_CH, RO_CH, TRIG_TIME, FREQ = 0, 0, 0.40, 100

# qick_emu draws the start-up jitter (+PRE_RUN_DELAY_NS, 0..100 ns) at random for every run, on
# purpose. For a reproducible baseline pin it (env PRE_RUN_DELAY_NS, default 0) without touching
# the upstream file; _run_emu_acquire does not pass it.
import functools  # noqa: E402
import os  # noqa: E402
TEST_RUN_NS_AVG = int(os.environ.get('TEST_RUN_NS_AVG', '50000'))
PRE_RUN_DELAY_NS = int(os.environ.get('PRE_RUN_DELAY_NS', '0'))
_orig_run = QickEmu.run_verilator_tb
QickEmu.run_verilator_tb = lambda self, *a, **k: _orig_run(self, *a, **{'pre_run_delay_ns': PRE_RUN_DELAY_NS, **k})


class MultiPulseProgram(AveragerProgramV2):
    def _initialize(self, cfg):
        ro_ch, gen_ch = cfg['ro_ch'], cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=1)
        self.declare_readout(ch=ro_ch, length=cfg['ro_len'])
        ramp_len = 0.2
        self.add_gauss(ch=gen_ch, name='ramp', sigma=ramp_len/10, length=ramp_len, even_length=True)
        self.add_pulse(ch=gen_ch, name='myflattop', ro_ch=ro_ch, style='flat_top', envelope='ramp',
                       freq=cfg['freq'], length=0.1, phase=0, gain=1.0)
        self.add_pulse(ch=gen_ch, name='mygaus', ro_ch=ro_ch, style='arb', envelope='ramp',
                       freq=cfg['freq'], phase=0, gain=1.0)
        self.add_pulse(ch=gen_ch, name='myconst', ro_ch=ro_ch, style='const', length=0.2,
                       freq=cfg['freq'], phase=0, gain=1.0)
        self.add_pulse(ch=gen_ch, name='myflattop2', ro_ch=ro_ch, style='flat_top', envelope='ramp',
                       freq=cfg['freq'], length=0.1, phase=90, gain=1.0)
        self.add_readoutconfig(ch=ro_ch, name='myro', freq=cfg['freq'], gen_ch=gen_ch)
        self.send_readoutconfig(ch=ro_ch, name='myro', t=0)

    def _body(self, cfg):
        self.trigger(ros=[cfg['ro_ch']], pins=[0], t=cfg['trig_time'], ddr4=True)
        self.pulse(ch=cfg['gen_ch'], name='myflattop', t=0)
        self.pulse(ch=cfg['gen_ch'], name='mygaus', t=0.4)
        self.pulse(ch=cfg['gen_ch'], name='myconst', t=0.8)
        self.pulse(ch=cfg['gen_ch'], name='myflattop2', t=1.2)
        self.pulse(ch=cfg['gen_ch'], name='mygaus', t=1.6)


class SimpleSweepProgram(AveragerProgramV2):
    def _initialize(self, cfg):
        ro_ch, gen_ch = cfg['ro_ch'], cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=1)
        self.declare_readout(ch=ro_ch, length=cfg['ro_len'])
        self.add_loop('myloop', cfg['steps'])
        self.add_gauss(ch=gen_ch, name='ramp', sigma=cfg['ramp_len']/10, length=cfg['ramp_len'], even_length=True)
        self.add_pulse(ch=gen_ch, name='mypulse', ro_ch=ro_ch, style='flat_top', envelope='ramp',
                       freq=cfg['freq'], length=cfg['flat_len'], phase=cfg['phase'], gain=cfg['gain'])
        self.add_readoutconfig(ch=ro_ch, name='myro', freq=cfg['freq'], gen_ch=gen_ch)
        self.send_readoutconfig(ch=ro_ch, name='myro', t=0)

    def _body(self, cfg):
        self.pulse(ch=cfg['gen_ch'], name='mypulse', t=0)
        self.trigger(ros=[cfg['ro_ch']], pins=[0], t=cfg['trig_time'])


class MuxProgram(AveragerProgramV2):
    """Muxed generator (gen 2, axis_sg_mux8_v1) with two PFB readouts (readouts 2 and 3, axis_pfb_readout_v4)."""
    def _initialize(self, cfg):
        ro_chs, gen_ch = cfg['ro_chs'], cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=1, ro_ch=ro_chs[0], mux_freqs=cfg['pulse_freqs'],
                         mux_gains=cfg['pulse_gains'], mux_phases=cfg['pulse_phases'])
        for ch, f, ph in zip(ro_chs, cfg['pulse_freqs'], cfg['ro_phases']):
            self.declare_readout(ch=ch, length=cfg['ro_len'], freq=f, phase=ph, gen_ch=gen_ch)
        self.add_pulse(ch=gen_ch, name="mymux", style="const", length=cfg["pulse_len"], mask=[0, 1])

    def _body(self, cfg):
        self.trigger(ros=cfg['ro_chs'], pins=[0], t=cfg['trig_time'], ddr4=True)
        self.pulse(ch=cfg['gen_ch'], name="mymux", t=0)


class StdReadoutProgram(AveragerProgramV2):
    """Generator 1 (axis_signal_gen_v6) with the standard readout (readout 1, axis_readout_v2): PYNQ-configured, so the
    frequency and phase are set in declare_readout and there is no readout config."""
    def _initialize(self, cfg):
        ro_ch, gen_ch = cfg['ro_ch'], cfg['gen_ch']
        self.declare_gen(ch=gen_ch, nqz=1)
        self.declare_readout(ch=ro_ch, length=cfg['ro_len'], freq=cfg['freq'], phase=0, gen_ch=gen_ch)
        self.add_gauss(ch=gen_ch, name='ramp', sigma=cfg['ramp_len']/10, length=cfg['ramp_len'], even_length=True)
        self.add_pulse(ch=gen_ch, name='mypulse', ro_ch=ro_ch, style='flat_top', envelope='ramp',
                       freq=cfg['freq'], length=cfg['flat_len'], phase=0, gain=1.0)

    def _body(self, cfg):
        self.pulse(ch=cfg['gen_ch'], name='mypulse', t=0)
        self.trigger(ros=[cfg['ro_ch']], pins=[0], t=cfg['trig_time'])


soc = QickEmu(str(root / 'emulator' / 'config' / 'qick_emu_config.json'))
soccfg = soc.soccfg
results = {}

# 1. multi_pulse, decimated
cfg = {'gen_ch': GEN_CH, 'ro_ch': RO_CH, 'freq': FREQ, 'trig_time': TRIG_TIME, 'ro_len': 1.9}
prog = MultiPulseProgram(soccfg, reps=1, final_delay=0.5, cfg=cfg)
d = out / 'multi_pulse'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=build, trace=False, verbose=False)
results['multi_pulse_dec'] = prog.acquire_decimated(soc, rounds=2)[0]

# 2. simple_sweep, decimated
cfg = {'steps': 5, 'gen_ch': GEN_CH, 'ro_ch': RO_CH, 'freq': FREQ, 'trig_time': TRIG_TIME, 'ro_len': 0.35,
       'flat_len': 0.05, 'ramp_len': 0.2,
       'phase': QickSweep1D('myloop', -360, 720), 'gain': QickSweep1D('myloop', 0.0, 1.0)}
prog = SimpleSweepProgram(soccfg, reps=1, final_delay=0.5, cfg=cfg)
d = out / 'simple_sweep'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False)
results['simple_sweep_dec'] = prog.acquire_decimated(soc, rounds=2)[0]

# 3. simple_sweep, averaged (accumulated buffer), 4 reps
prog = SimpleSweepProgram(soccfg, reps=4, final_delay=0.5, cfg=cfg)
d = out / 'simple_sweep_avg'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False, test_run_ns=TEST_RUN_NS_AVG)
results['simple_sweep_avg'] = prog.acquire(soc, rounds=1)[0]

# 4. multi_pulse, averaged, 4 reps
cfg = {'gen_ch': GEN_CH, 'ro_ch': RO_CH, 'freq': FREQ, 'trig_time': TRIG_TIME, 'ro_len': 1.9}
prog = MultiPulseProgram(soccfg, reps=4, final_delay=0.5, cfg=cfg)
d = out / 'multi_pulse_avg'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False, test_run_ns=TEST_RUN_NS_AVG)
results['multi_pulse_avg'] = prog.acquire(soc, rounds=1)[0]

# 5. muxed generator + PFB readouts, decimated (section 3 of notebooks/tutorial/07_Advanced_Generators_And_Readouts_emu)
cfg = {'gen_ch': 2, 'ro_chs': [2, 3], 'pulse_freqs': [500, 550], 'pulse_gains': [1.0] * 2, 'pulse_phases': [0.0] * 2,
       'ro_phases': [0.0] * 2, 'trig_time': 0.4, 'pulse_len': 1.0, 'ro_len': 1.9}
prog = MuxProgram(soccfg, reps=1, final_delay=0.5, cfg=cfg)
d = out / 'mux_pfb'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False)
results['mux_pfb_dec'] = np.array(prog.acquire_decimated(soc, rounds=1))

# 6. standard readout (axis_readout_v2, readout 1) driven by generator 1 (the harness loops DAC 1 into ADC 1), decimated and averaged (4 reps)
cfg = {'gen_ch': 1, 'ro_ch': 1, 'freq': FREQ, 'trig_time': TRIG_TIME, 'ro_len': 0.35, 'flat_len': 0.05, 'ramp_len': 0.2}
prog = StdReadoutProgram(soccfg, reps=1, final_delay=0.5, cfg=cfg)
d = out / 'std_readout_dec'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False)
results['std_readout_dec'] = np.array(prog.acquire_decimated(soc, rounds=1))
prog = StdReadoutProgram(soccfg, reps=4, final_delay=0.5, cfg=cfg)
d = out / 'std_readout_avg'
d.mkdir(exist_ok=True)
soc = soc.prepare_emu(memdir=d, build=False, test_run_ns=TEST_RUN_NS_AVG)
results['std_readout_avg'] = prog.acquire(soc, rounds=1)[0]

lines = []
for k, v in results.items():
    v = np.asarray(v)
    np.save(out / (k + '.npy'), v)
    lines.append('%s  %s  shape=%s  max|x|=%.6g' % (hashlib.md5(v.tobytes()).hexdigest(), k, v.shape, np.abs(v).max()))
(out / 'md5.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))
