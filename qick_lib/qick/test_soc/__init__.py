import time

from pynq import allocate
from numpy import int16


class Generator:
    def __init__(self, soc, fs, ctrl, gen, sw):
        self.soc = soc
        self.fs = fs
        self.ctrl = ctrl
        self.gen = gen
        self.sw = sw

        # Configure control block.
        self.ctrl.configure(self.fs, self.gen)

    def set(self, f, g=0.99, ch=0):
        # Set generator parameters.
        self.ctrl.add(freq=f, gain=g)

        # Select channel.
        self.sw.sel(mst=ch)

    def set_nyquist(self, nqz):
        for dac in self.soc.dacs.keys():
            self.soc.rf.set_nyquist(dac, nqz)


class Buffer:
    def __init__(self, soc, fs, sw, buff, dma):
        self.soc = soc
        self.fs = fs
        self.sw = sw
        self.buff_ip = buff
        self.dma = dma

        # Pre-allocated buffer.
        self.buff = allocate(shape=self.buff_ip["maxlen"], dtype=int16)

    def get_data(self, ch=0):
        # Select channel.
        self.sw.sel(slv=ch)

        # Capture.
        self.buff_ip.enable()
        time.sleep(0.1)
        self.buff_ip.disable()

        # Transfer.
        return self.transfer()

    def transfer(self):
        # Start send data mode.
        self.buff_ip.dr_start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(self.buff)
        self.dma.recvchannel.wait()

        # Stop send data mode.
        self.buff_ip.dr_start_reg = 0

        return self.buff
