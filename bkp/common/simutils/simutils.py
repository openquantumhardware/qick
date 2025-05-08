from fxpmath import Fxp
import numpy as np
import pyxsi
import glob
import matplotlib.pyplot as plt
from scipy.fftpack import fftshift

class Block:
    def __init__(self):
        self.xsi : pyxsi.XSI = None
        self.sample_repr = Fxp()

    def set_clock(self, port_name, freq, timescale):
        self.clock      = port_name
        self.clock_freq = freq
        self.timescale  = timescale
        self.half_cycle = round(0.5/(self.clock_freq*self.timescale))

    def tick(self):
        self.xsi.set_port_value(self.clock, "1")
        self.xsi.run(self.half_cycle)
        self.xsi.set_port_value(self.clock, "0")
        self.xsi.run(self.half_cycle)

    def load_hw_lib(self, lib_path, tracefile=None):
        self.xsi= pyxsi.XSI(glob.glob(lib_path).pop(), tracefile=tracefile)

    def set_reset(self, port_name):
        self.reset_port = port_name

    def reset(self, n_clocks):
        self.xsi.set_port_value(self.reset_port, "1")
        for _ in range(n_clocks): self.tick()
        self.xsi.set_port_value(self.reset_port, "0")

    def fp_sim(self):
        return NotImplementedError()

    def fxp_sim(self):
        return NotImplementedError()

    def hw_sim(self):
        return NotImplementedError()

def concat_complex_string(cval):
    string_rep = cval.split('+')
    return string_rep[1][:-1] + string_rep[0]

vect_concat_complex_string = np.vectorize(concat_complex_string)

def complex_to_bit(cval):
    return vect_concat_complex_string(cval.bin())

def bit_to_num(sval, data_repr, raw=False):
    def to_signed(val, nbits):
        num = int(val, 2)
        if val[0] == '1':
            num ^= (1 << nbits) - 1
            num += 1
            num = -num
        return num

    if isinstance(sval, list):
        nums = [bit_to_num(x, data_repr, raw=True) for x in sval]
    else:
        if data_repr.vdtype == complex:
            n_bits = data_repr.n_word
            fsval = sval.zfill(2*n_bits)
            nums = to_signed(fsval[n_bits:], n_bits) + 1j*to_signed(fsval[:n_bits],
                    n_bits)
        else:
            n_bits = data_repr.n_word
            fsval = sval.zfill(n_bits)
            nums = to_signed(fsval, n_bits)

    return Fxp(None).like(data_repr).set_val(nums, raw=True) if not raw else nums

def fp2bitstring(samples, sample_repr):
    samples_fxp = Fxp(samples).like(sample_repr)
    samples_bin = complex_to_bit(samples_fxp)
    samples_bin = [''.join(s[::-1]) for s in samples_bin.T]
    return samples_bin

def bitstring2fxp(result_bin, output_repr):
    if output_repr.vdtype == complex:
        n_bits_output = 2 * output_repr.n_word
    else:
        n_bits_output = output_repr.n_word

    if max(list(map(len, result_bin))) > n_bits_output:
        result_bin = [list(map(''.join, zip(*[iter(x)]*n_bits_output)))[::-1] for
                x in result_bin]
    result = bit_to_num(result_bin, output_repr).T
    return result

def plot_fft(samples, fs, title, ax=None, **plt_kwargs):
    fft_points = len(samples)
    fval_mhz = np.arange(-fft_points/2, fft_points/2)*fs/fft_points
    if ax is None:
       ax = plt.gca()
    ax.plot(fval_mhz, np.abs(fftshift(samples)), **plt_kwargs)
    ax.set_xlabel("Frequency [MHz]")
    ax.set_ylabel("Amplitude")
    ax.set_title(title)
    return(ax)
