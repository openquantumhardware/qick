from vcdvcd import VCDVCD
import pandas as pd
import simutils
from fxpmath import Fxp

import matplotlib.pyplot as plt

class VCDFile:
    def __init__(self, fname):
        self.vcd = VCDVCD(fname)

    def set_clock(self, clk_name):
        time, value = zip(*self.vcd[clk_name].tv)
        self.df_clk = pd.DataFrame({'time': time, 'clk': value})

    def get_signal(self, signame, sigrepr, sigvalid=None, sigready=None, sigslice=None):
        time, value = zip(*self.vcd[signame].tv)
        value = list(value)
        if sigslice:
            bus_size = int(self.vcd[signame].size)
            value = [v.zfill(bus_size)[-sigslice[0]+bus_size-1:-sigslice[1]+bus_size] for v in value]

        df_sig = pd.DataFrame({'time': time, 'value': value})

        df = df_sig.merge(self.df_clk, on='time', how='outer').sort_values('time').ffill()

        if sigvalid:
            time, value = zip(*self.vcd[sigvalid].tv)
            df_valid = pd.DataFrame({'time': time, 'valid': value})
            df = df.merge(df_valid, on='time', how='outer').sort_values('time').ffill()
            df = df.loc[df['valid'] == int(self.vcd[sigvalid].size)*'1']

        if sigvalid and sigready:
            time, value = zip(*self.vcd[sigready].tv)
            df_ready = pd.DataFrame({'time': time, 'ready': value})
            df = df.merge(df_ready, on='time', how='outer').sort_values('time').ffill()
            df = df.loc[df['ready'] == int(self.vcd[sigready].size)*'1']

        df = df.loc[df['clk'] == '1']

        value_fxp = simutils.bitstring2fxp(df['value'].to_list(), sigrepr).get_val()

        return value_fxp
