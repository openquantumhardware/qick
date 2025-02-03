from fxpmath import Fxp
import numpy as np
import pyxsi
import glob
import matplotlib.pyplot as plt
from scipy.fftpack import fftshift

class Block:
    def __init__(self):
        self.xsi : pyxsi.XSI = None
        self.drive_delay_steps = 2000

    def set_clock(self, port_name, freq, timescale):
        self.clock      = port_name
        self.clock_freq = freq
        self.timescale  = timescale
        self.half_cycle = round(0.5/(self.clock_freq*self.timescale))

    def tick(self):
        self.post_posedge()
        self.prev_posedge()

    def prev_posedge(self):
        try:
            self.xsi.run(self.half_cycle - self.drive_delay_steps)
            self.xsi.set_port_value(self.clock, "0")
            self.xsi.run(self.half_cycle)
        except RuntimeError as e:
            print(str(e))
            print(f"Simulation Status: {self.xsi.get_status()}")
            print(f"Simulation Messages: \n{self.xsi.get_error_info()}")
            exit()

    def post_posedge(self):
        try:
            self.xsi.set_port_value(self.clock, "1")
            self.xsi.run(self.drive_delay_steps)
        except RuntimeError as e:
            print(str(e))
            print(f"Simulation Status: {self.xsi.get_status()}")
            print(f"Simulation Messages: \n{self.xsi.get_error_info()}")
            exit()


    def load_hw_lib(self, lib_path, tracefile=None, logfile=None):
        self.xsi= pyxsi.XSI(
                glob.glob(lib_path, recursive=True).pop(), 
                tracefile=tracefile, 
                logfile=logfile
        )

    def set_reset(self, port_name):
        self.reset_port = port_name

    def reset(self, n_clocks):
        self.post_posedge()
        self.xsi.set_port_value(self.reset_port, "1")
        self.prev_posedge()
        for _ in range(n_clocks):
            self.tick()
        self.post_posedge()
        self.xsi.set_port_value(self.reset_port, "0")
        self.prev_posedge()

    def fp_sim(self):
        return NotImplementedError()

    def fxp_sim(self):
        return NotImplementedError()

    def hw_sim(self):
        return NotImplementedError()

class AxiLiteIF():
    def __init__(self, block, awready, awvalid, awaddr, awprot, wready, wvalid, wdata,
                 wstrb, bready, bvalid, bresp, arready, arvalid, araddr,
                 arprot, rready, rvalid, rdata, rresp, bus_width=32):
        self.block     = block
        self.awready   = awready
        self.awvalid   = awvalid
        self.awaddr    = awaddr
        self.awprot    = awprot
        self.wready    = wready
        self.wvalid    = wvalid
        self.wdata     = wdata
        self.wstrb     = wstrb
        self.bready    = bready
        self.bvalid    = bvalid
        self.bresp     = bresp
        self.arready   = arready
        self.arvalid   = arvalid
        self.araddr    = araddr
        self.arprot    = arprot
        self.rready    = rready
        self.rvalid    = rvalid
        self.rdata     = rdata
        self.rresp     = rresp
        self.bus_width = bus_width

    @classmethod
    def from_prefix(cls, block, prefix):
        return cls(
                block     = block,
                awready = prefix + "AWREADY",
                awvalid = prefix + "AWVALID",
                awaddr  = prefix + "AWADDR",
                awprot  = prefix + "AWPROT",
                wready  = prefix + "WREADY",
                wvalid  = prefix + "WVALID",
                wdata   = prefix + "WDATA",
                wstrb   = prefix + "WSTRB",
                bready  = prefix + "BREADY",
                bvalid  = prefix + "BVALID",
                bresp   = prefix + "BRESP",
                arready = prefix + "ARREADY",
                arvalid = prefix + "ARVALID",
                araddr  = prefix + "ARADDR",
                arprot  = prefix + "ARPROT",
                rready  = prefix + "RREADY",
                rvalid  = prefix + "RVALID",
                rdata   = prefix + "RDATA",
                rresp   = prefix + "RRESP"
        )

    def write(self, addr, data, mask=None, offset=None):
        if (offset):
            data = data << offset
        if (mask):
            prev_data = self.read(addr)
            data = prev_data & ~mask | data & mask
        addr_bin = bin(addr)[2:].zfill(self.bus_width)
        data_bin = bin(data)[2:].zfill(self.bus_width)
        self.block.post_posedge()
        self.block.xsi.set_port_value(self.wdata, data_bin)
        self.block.xsi.set_port_value(self.awaddr, addr_bin)
        self.block.xsi.set_port_value(self.awvalid, "1")
        self.block.xsi.set_port_value(self.wvalid, "1")
        self.block.xsi.set_port_value(self.wstrb, "1"*(self.bus_width//8))
        self.block.xsi.set_port_value(self.bready, "1")
        self.block.prev_posedge()

        while (self.block.xsi.get_port_value(self.awready) != "1" and 
               self.block.xsi.get_port_value(self.wready) != "1"):
            self.block.tick()

        self.block.post_posedge()
        self.block.xsi.set_port_value(self.awvalid, "0")
        self.block.xsi.set_port_value(self.wvalid, "0")
        self.block.prev_posedge()

    def read(self, addr, mask=None, offset=None):
        addr_bin = bin(addr)[2:].zfill(self.bus_width)
        self.block.post_posedge()
        self.block.xsi.set_port_value(self.araddr, addr_bin)
        self.block.xsi.set_port_value(self.arvalid, "1")
        self.block.xsi.set_port_value(self.rready, "1")
        self.block.prev_posedge()

        while(self.block.xsi.get_port_value(self.arready) != "1"):
            self.block.tick()

        self.block.post_posedge()
        self.block.xsi.set_port_value(self.arvalid, "0")
        self.block.prev_posedge()

        while(self.block.xsi.get_port_value(self.rvalid) != "1"):
            self.block.tick()

        data = int(self.block.xsi.get_port_value(self.rdata),2)

        self.block.post_posedge()
        self.block.xsi.set_port_value(self.rready, "0")
        self.block.prev_posedge()
        
        if (mask):
            data = data & mask

        if (offset):
            data = data >> offset

        return data


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
    samples_bin = [''.join(s) for s in samples_bin.T]
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
