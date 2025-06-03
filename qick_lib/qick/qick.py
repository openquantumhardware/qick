"""
The lower-level driver for the QICK library. Contains classes for interfacing with the SoC.
"""
import os
from pynq.overlay import Overlay
import xrfclk
import xrfdc
import numpy as np
import time
import queue
import logging
from collections import OrderedDict, defaultdict
from fractions import Fraction
from . import bitfile_path, obtain, get_version
from .ip import SocIP, QickMetadata
from .parser import parse_to_bin
from .streamer import DataStreamer
from .qick_asm import QickConfig
from .asm_v1 import QickProgram
from .asm_v2 import QickProgramV2
from .drivers.generator import *
from .drivers.readout import *
from .drivers.tproc import *

logger = logging.getLogger(__name__)


class AxisSwitch(SocIP):
    """
    AxisSwitch class to control Xilinx AXI-Stream switch IP

    :param nslave: Number of slave interfaces
    :type nslave: int
    :param nmaster: Number of master interfaces
    :type nmaster: int
    """
    bindto = ['xilinx.com:ip:axis_switch:1.1']

    def _init_config(self, description):
        # Number of slave interfaces.
        self.NSL = int(description['parameters']['NUM_SI'])
        # Number of master interfaces.
        self.NMI = int(description['parameters']['NUM_MI'])

        self.REGISTERS = {'ctrl': 0x0, 'mix_mux': 0x040}

    def _init_firmware(self):
        # Init axis_switch.
        self.ctrl = 0
        self.disable_ports()

    def disable_ports(self):
        """
        Disables ports
        """
        for ii in range(self.NMI):
            offset = self.REGISTERS['mix_mux'] + 4*ii
            self.write(offset, 0x80000000)

    def sel(self, mst=0, slv=0):
        """
        Digitally connects a master interface with a slave interface

        :param mst: Master interface
        :type mst: int
        :param slv: Slave interface
        :type slv: int
        """
        # Sanity check.
        if slv > self.NSL-1:
            print("%s: Slave number %d does not exist in block." %
                  __class__.__name__)
            return
        if mst > self.NMI-1:
            print("%s: Master number %d does not exist in block." %
                  __class__.__name__)
            return

        # Disable register update.
        self.ctrl = 0

        # Disable all MI ports.
        self.disable_ports()

        # MI[mst] -> SI[slv]
        offset = self.REGISTERS['mix_mux'] + 4*mst
        self.write(offset, slv)

        # Enable register update.
        self.ctrl = 2

class RFDC(SocIP, xrfdc.RFdc):
    """
    Extends the xrfdc driver.
    Calling xrfdc functions is slow (typically ~8 ms per call).
    We therefore cache parameters that need to be set in program initialization, such as Nyquist zone and frequency.
    """
    bindto = ["xilinx.com:ip:usp_rf_data_converter:2.3",
              "xilinx.com:ip:usp_rf_data_converter:2.4",
              "xilinx.com:ip:usp_rf_data_converter:2.6"]

    # consts from https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/rfdc/src/xrfdc.h
    XRFDC_CAL_BLOCK_OCB1 = 0
    XRFDC_CAL_BLOCK_OCB2 = 1
    XRFDC_CAL_BLOCK_GCB  = 2
    XRFDC_CAL_BLOCK_TSCB = 3
    XRFDC_GEN3 = 2
    # name, ID, number of coefficients
    ADC_CAL_BLOCKS = {'OCB1': (XRFDC_CAL_BLOCK_OCB1, 4),
                      'OCB2': (XRFDC_CAL_BLOCK_OCB2, 4),
                      'GCB' : (XRFDC_CAL_BLOCK_GCB,  4),
                      'TSCB': (XRFDC_CAL_BLOCK_TSCB, 8),
                      }

    def _init_config(self, description):
        # Nyquist zone for each channel
        self.nqz_dict = {'dac': {}, 'adc': {}}
        # Rounded NCO frequency for each channel
        self.mixer_dict = {}

        ip_params = description['parameters']

        # which generation RFSoC we are using
        self.cfg['ip_type'] = int(ip_params['C_IP_Type'])
        # quad or dual RF-ADC
        self.cfg['hs_adc'] = (ip_params['C_High_Speed_ADC'] == '1')
        # dicts of RFDC tiles and channels
        self.cfg['tiles'] = {'dac':{}, 'adc':{}}
        self.cfg['dacs'] = OrderedDict()
        self.cfg['adcs'] = OrderedDict()

        # list the enabled DAC+ADC tiles and blocks, and enumerate the "channel name" and tile/block indices for each block
        # the channel name is a 2-digit string that gets used in RFDC port and parameter names
        # the indices are what you need to index into the dac_tiles/adc_tiles structures
        for tiletype in ['dac', 'adc']:
            for iTile in range(4):
                if ip_params['C_%s%d_Enable' % (tiletype.upper(), iTile)] != '1': continue
                tilecfg = {}
                self['tiles'][tiletype][iTile] = tilecfg
                f_fabric = float(ip_params['C_%s%d_Fabric_Freq' % (tiletype.upper(), iTile)])
                f_out = float(ip_params['C_%s%d_Outclk_Freq' % (tiletype.upper(), iTile)])
                fs = float(ip_params['C_%s%d_Sampling_Rate' % (tiletype.upper(), iTile)])*1000
                tilecfg['fabric_div'] = int(fs/f_fabric)
                tilecfg['out_div'] = int(f_fabric/f_out)
                #out_div = Fraction(f_fabric/f_out).limit_denominator()
                tilecfg['blocks'] = []
                for block in range(4):
                    # pack the indices for the tile/block structure "channel name"
                    chname = "%d%d" % (iTile, block)
                    if tiletype == 'adc' and self['hs_adc']:
                        if block%2 != 0: continue
                        iBlock = block//2
                    else:
                        iBlock = block

                    # check whether this block is enabled
                    if ip_params['C_%s_Slice%s_Enable' % (tiletype.upper(), chname)] != 'true': continue
                    tilecfg['blocks'].append(chname)
                    self[tiletype+'s'][chname] = {'index': [iTile, iBlock]}
        # read the clock settings and block configs
        self._read_freqs()

    def _get_tile(self, tiletype, iTile):
        tiles = {'dac':self.dac_tiles, 'adc':self.adc_tiles}[tiletype]
        return tiles[iTile]

    def _read_freqs(self):
        for tiletype in ['dac', 'adc']:
            for iTile, tilecfg in self['tiles'][tiletype].items():
                #tilecfg.clear()
                tile = self._get_tile(tiletype, iTile)
                pllcfg = tile.PLLConfig
                tilecfg['f_ref'] = pllcfg['RefClkFreq']
                tilecfg['ref_div'] = pllcfg['RefClkDivider']
                tilecfg['fs_mult'] = pllcfg['FeedbackDivider']
                tilecfg['fs_div'] = pllcfg['RefClkDivider']*pllcfg['OutputDivider']
                # we could use SampleRate here, but it's the same
                tilecfg['fs'] = tilecfg['f_ref']*tilecfg['fs_mult']/tilecfg['fs_div']
                tilecfg['f_fabric'] = tilecfg['fs']/tilecfg['fabric_div']
                tilecfg['f_out'] = tilecfg['f_fabric']/tilecfg['out_div']

        """
        # lookup table for deciding whether the AXI-S interface uses IQ or real data
        # this only covers the cases we actually use in our generators/ROs
        mixer2iq = {}
        mixer2iq['dac'] = {
            (xrfdc.MIXER_TYPE_FINE,   xrfdc.MIXER_MODE_C2R): 2,
            (xrfdc.MIXER_TYPE_COARSE, xrfdc.MIXER_MODE_R2R): 1,
        }
        mixer2iq['adc'] = {
            (xrfdc.MIXER_TYPE_COARSE, xrfdc.MIXER_MODE_R2C): 2,
            (xrfdc.MIXER_TYPE_COARSE, xrfdc.MIXER_MODE_R2R): 1,
        }
        fabric_divs = {k:{iTile:[] for iTile in v.keys()} for k,v in self['tiles'].items()}
        """
        for tiletype in ['dac', 'adc']:
            for chname, chcfg in self[tiletype+'s'].items():
                iTile, iBlock = chcfg['index']
                #chcfg.clear()
                #chcfg['index'] = [iTile, iBlock]

                # copy the tile info
                chcfg.update(self['tiles'][tiletype][iTile])
                # clean up parameters that are only used at the tile level
                del chcfg['ref_div'], chcfg['out_div'], chcfg['fabric_div'], chcfg['f_out'], chcfg['blocks']

                block = self._get_tile(tiletype, iTile).blocks[iBlock]

                """
                # now we compute the ratio between the sample and fabric clocks
                # this is surprisingly annoying to do in full generality
                # https://docs.amd.com/r/en-US/pg269-rf-data-converter/RF-DAC-Interface-Data-and-Clock-Rates
                # https://docs.amd.com/r/en-US/pg269-rf-data-converter/RF-ADC-Interface-Data-and-Clock-Rates
                # note that this ratio has to be the same for all channels in a tile
                if tiletype == 'dac':
                    data_width = block.FabWrVldWords
                else:
                    data_width = block.FabRdVldWords
                mixer_settings = block.MixerSettings
                iq = mixer2iq[tiletype][tuple(mixer_settings[k] for k in ['MixerType', 'MixerMode'])]
                """

                if tiletype == 'dac':
                    chcfg['interpolation'] = block.InterpolationFactor
                    if self['ip_type'] == self.XRFDC_GEN3:
                        chcfg['datapath'] = block.DataPathMode
                    #chcfg['fabric_div'] = data_width*chcfg['interpolation']//iq
                else:
                    chcfg['decimation'] = block.DecimationFactor
                    #chcfg['fabric_div'] = data_width*iq//chcfg['decimation']
                #fabric_divs[tiletype][iTile].append(chcfg['fabric_div'])
                #chcfg['f_fabric'] = chcfg['fs']/chcfg['fabric_div']

        """
        for tiletype in ['dac', 'adc']:
            for iTile, tiledivs in fabric_divs[tiletype].items():
                assert len(set(tiledivs)) == 1
                tilecfg = self['tiles'][tiletype][iTile]
                tilecfg['fabric_div'] = tiledivs[0]
                tilecfg['f_out'] = tilecfg['fs']/tilecfg['fabric_div']/tilecfg['out_div']
        """

    def map_clocks(self, soc):
        """Map the clock networks driving the various IP blocks, and determine the resulting constraints on the RFDC sampling rates.
        This method gets run early in QickSoc initialization because it's needed to check validity of a requested set of sampling freqs.

        This code assumes that the RFDC configuration dictionary has been filled (this happens in RFDC driver initialization).
        It does not assume that configure_connections() has been run on all drivers.
        """
        # first, gather information
        # search for IP blocks with trace_clocks() methods - typically this is just the tProc
        # we run trace_clocks() here
        # it will also run as part of QickSoc init (via configure_connections()), but that's after sampling rate modification
        clk_groups = defaultdict(list)
        for blockname, blockdict in soc.ip_dict.items():
            if hasattr(blockdict['driver'], 'trace_clocks'):
                ip = soc._get_block(blockname)
                ip.trace_clocks(soc)
                for clkname, clkcfg in ip['clk_srcs'].items():
                    clkid = (blockname, clkname)
                    clk_groups[clkcfg['source']].append([clkid, clkcfg['src_range']])
        # check all RFDC inputs and outputs
        for tiletype, direction in [('dac', 's'), ('adc', 'm')]:
            for iTile in self['tiles'][tiletype].keys():
                clkcfg = soc.metadata.trace_clk_back(self['fullpath'],'%s%d_axis_aclk'%(direction, iTile))
                clkid = (tiletype, iTile)
                clk_groups[clkcfg['source']].append([clkid, clkcfg['src_range']])

        # now, analyze clock groups
        self.cfg['clk_groups'] = []
        for clk_src, clk_dests in clk_groups.items():
            # find RFDC tiles whose fabric clocks come from this source
            fs_group = [x[0] for x in clk_dests]
            # find limits imposed on the clock source freq
            src_ranges = [x[1] for x in clk_dests if x[1] is not None]

            if clk_src[0] in ['dac', 'adc']:
                if fs_group:
                    self['clk_groups'].append(fs_group)

                tilecfg = self['tiles'][clk_src[0]][clk_src[1]]
                # cross-check
                # this isn't a fundamental rule, we might end up making a firmware that violates it
                # for now, this assumption simplifies thinking about clock groups
                if clk_src not in fs_group:
                    raise RuntimeError("%s tile %d drives logic, but not its own fabric clock. There may be a problem with this firmware design."%(clk_src[0].upper(), clk_src[1]))
                # add the output clock limits to the tile info
                if src_ranges:
                    tilecfg['outclk_limits'] = [max([x[0] for x in src_ranges]), min([x[1] for x in src_ranges])]

    def clocks_locked(self):
        dac_locked = [self.dac_tiles[iTile]
                      .PLLLockStatus == 2 for iTile in self['tiles']['dac']]
        adc_locked = [self.adc_tiles[iTile]
                      .PLLLockStatus == 2 for iTile in self['tiles']['adc']]
        return dac_locked, adc_locked

    def valid_sample_rates(self, tiletype, tile):
        """
        Return an array of valid sample rates.
        """
        if tiletype not in ['dac', 'adc']:
            raise RuntimeError('tiletype must be "dac" or "adc"')
        if tile not in self['tiles'][tiletype]:
            raise RuntimeError('specified tile is not enabled in this firmware')
        tilecfg = self['tiles'][tiletype][tile]
        # reference clock after the PLL reference divider
        # this divider can't be changed by software, and Xilinx recommends keeping it at 1 for best phase noise
        refclk = tilecfg['f_ref']/tilecfg['ref_div']
        words_per_axi = tilecfg['fabric_div']

        # Allowed divider values, see PG269 "PLL Parameters"
        # https://docs.amd.com/r/en-US/pg269-rf-data-converter/PLL-Parameters
        Fb_div_vals = np.arange(13,161, dtype=int)
        if self['ip_type'] == self.XRFDC_GEN3 and tiletype=='dac':
            M_vals = np.concatenate([[1,2,3], np.arange(4,66,2)])
            VCO_range = [7863, 13760]
        else:
            M_vals = np.concatenate([[2,3], np.arange(4,66,2)])
            VCO_range = [8500, 13200]

        VCO_possible = refclk * Fb_div_vals
        Fb_div_possible = Fb_div_vals[(VCO_possible>=VCO_range[0]) & (VCO_possible<=VCO_range[1])]
        fs_possible = refclk*(Fb_div_possible.T/M_vals[:,np.newaxis]).ravel()

        if 'outclk_limits' in tilecfg:
            fs_range = [x*tilecfg['out_div']*tilecfg['fabric_div'] for x in tilecfg['outclk_limits']]
            fs_possible = fs_possible[fs_possible >= fs_range[0]]
            fs_possible = fs_possible[fs_possible <= fs_range[1]]

        # See DS926 "RF-ADC/RF-DAC to PL Interface Performance"
        # https://docs.amd.com/r/en-US/ds926-zynq-ultrascale-plus-rfsoc/RF-ADC/RF-DAC-to-PL-Interface-Switching-Characteristics
        if self['ip_type'] == self.XRFDC_GEN3:
            max_axi_clk = 614 # MHz
        else:
            max_axi_clk = 520 # MHz
        fs_possible = fs_possible[fs_possible <= words_per_axi*max_axi_clk]

        # Allowed ranges of sampling freqs
        # https://docs.amd.com/r/en-US/ds926-zynq-ultrascale-plus-rfsoc/RF-DAC-Electrical-Characteristics
        # https://docs.amd.com/r/en-US/ds926-zynq-ultrascale-plus-rfsoc/RF-ADC-Electrical-Characteristics
        if tiletype=='adc' and self['hs_adc']:
            fs_min = 1000
        else:
            fs_min = 500
        fs_possible = fs_possible[fs_possible >= fs_min]
        if tiletype=='dac':
            if self['ip_type'] == self.XRFDC_GEN3:
                fs_max = 9850
            else:
                fs_max = 6554
        else:
            if self['ip_type'] < self.XRFDC_GEN3:
                fs_max = 4096 # ZCU111
            else:
                if self['hs_adc']:
                    fs_max = 5000
                else:
                    fs_max = 2500
        fs_possible = fs_possible[fs_possible <= fs_max]

        # special rules for Gen3 RFSoC DACs
        if self['ip_type'] == self.XRFDC_GEN3 and tiletype=='dac':
            # forbidden "hole" for Gen3 RFSoC DAC PLL
            # https://docs.amd.com/r/en-US/ds926-zynq-ultrascale-plus-rfsoc/RF-Converters-Clocking-Characteristics
            fs_possible = fs_possible[(fs_possible<=6882) | (fs_possible>=7863)]

            # in datapath mode 1, Gen3 DACs can't go above 7 Gsps
            # https://docs.amd.com/r/en-US/pg269-rf-data-converter/RF-DAC-High-Sampling-Rates-Mode-Gen-3/DFE
            # https://docs.amd.com/r/en-US/ds926-zynq-ultrascale-plus-rfsoc/RF-DAC-Electrical-Characteristics
            datapaths = [self[tiletype+'s'][chname]['datapath'] for chname in tilecfg['blocks']]
            if any([x==1 for x in datapaths]):
                fs_possible = fs_possible[fs_possible<=7000]

        fs_possible.sort()
        return fs_possible

    def round_sample_rate(self, tiletype, tile, fs_target):
        """
        Return the closest achievable sample rate to the requested value.
        """
        if tiletype not in ['dac', 'adc']:
            raise RuntimeError('tiletype must be "dac" or "adc"')
        if tile not in self['tiles'][tiletype]:
            raise RuntimeError('specified tile is not enabled in this firmware')
        fs_possible = self.valid_sample_rates(tiletype, tile)
        fs_best = fs_possible[np.argmin(np.abs(fs_possible - fs_target))]
        return fs_best

    def _set_sample_rate(self, tiletype, tile, fs):
        """
        Set the sample rate of a tile.
        It's assumed that the requested frequency has already been validated and rounded to a valid value.

        Parameters
        ----------
        tiletype : str
            'dac' or 'adc'
        tile : int
            Tile number (0-3)
        fs : float
            Requested sample rate, in Msps
        """
        self.logger.info('programming %s tile %d to %.3f Msps'%(tiletype.upper(), tile, fs))
        f_ref = self['tiles'][tiletype][tile]['f_ref']
        self._get_tile(tiletype, tile).DynamicPLLConfig(source=xrfdc.CLK_SRC_PLL, ref_clk_freq=f_ref, samp_rate=fs)

    def configure_sample_rates(self, dac_sample_rates=None, adc_sample_rates=None):
        """
        Set the tile sample rates.
        This should only be called as part of initialization.

        Parameters
        ----------
        dac_sample_rates : dict[int, float]
            Sample rates to override the values compiled into the firmware.
            This should be a dictionary mapping DAC tiles to sample rates (in megasamples per second).
        adc_sample_rates : dict[int, float]
            Sample rates to override the values compiled into the firmware.
            This should be a dictionary mapping ADC tiles to sample rates (in megasamples per second).
        """

        # build a dictionary for the requested fs changes
        fs_requested = {
            'dac': dac_sample_rates,
            'adc': adc_sample_rates
        }
        for tiletype, fs_dict in fs_requested.items():
            # handle None input
            if fs_dict is None:
                fs_dict = {}
            # check that all tiles are valid
            for iTile, fs in fs_dict.items():
                if iTile not in self['tiles'][tiletype]:
                    raise RuntimeError('requested to change fs for %s tile %d, which is not enabled in this firmware'%(tiletype.upper(), iTile))
            # do a copy, since we will be modifying this dictionary
            fs_requested[tiletype] = fs_dict.copy()

        # compute the scaling to be applied to each RF tile's fs
        fs_ratios = {}
        for tiletype, tiles in self['tiles'].items():
            for iTile, tilecfg in tiles.items():
                if iTile not in fs_requested[tiletype]:
                    fs_ratios[(tiletype, iTile)] = Fraction(1)
                else:
                    fs_target = fs_requested[tiletype][iTile]
                    fs_best = self.round_sample_rate(tiletype, iTile, fs_target)
                    fs_current = tilecfg['fs']
                    fs_err = fs_best - fs_target
                    self.logger.info('%s tile %d: fs requested = %f Msps, best possible = %.3f Msps, error = %.3f Msps.'%(tiletype.upper(), iTile, fs_target, fs_best, fs_err))
                    if abs(fs_err) > 10:
                        raise RuntimeError("%s tile %d: requested fs %f Msps is not supported, closest is %.3f."%(tiletype.upper(), iTile, fs_target, fs_best))
                    if abs(fs_err) > 1:
                        self.logger.warning('%s tile %d: requested fs %f.3 Msps could not be achieved, will use %f.3 Msps.'%(tiletype.upper(), iTile, fs_target, fs_best))
                    if fs_best > fs_current+0.1:
                        raise RuntimeError('%s tile %d: increasing a sample rate is not allowed, but requested fs (%.3f Msps) is greater than current fs (%.3f Msps)'%(tiletype.upper(), iTile, fs_best, fs_current))
                    fs_requested[tiletype][iTile] = fs_best
                    fs_ratios[(tiletype, iTile)] = Fraction(fs_best/fs_current).limit_denominator()

        # check that linked clocks will get the same scaling
        for fs_group in self['clk_groups']:
            tiles = [x for x in fs_group if x[0] in ['dac', 'adc']]
            if not tiles: continue
            ratios = [fs_ratios[tile] for tile in tiles]
            if len(set(ratios)) != 1:
                tilenames = ["%s %d"%(tile[0].upper(), tile[1]) for tile in tiles]
                ratios_f = [float(r) for r in ratios]
                raise RuntimeError("the following RF tiles have related clocks and their sampling frequencies must be scaled by the same ratio: %s\nafter rounding your requested frequencies to the nearest valid value, you are requesting scaling by: %s"%(tilenames, ratios_f))

        # now we can apply the changes
        for tiletype, fs_dict in fs_requested.items():
            for iTile, fs in fs_dict.items():
                self._set_sample_rate(tiletype, iTile, fs)
        # we changed the clocks, so refresh that info
        self._read_freqs()

    def set_mixer_freq(self, dacname, f, phase_reset=True, force=False):
        """
        Set the NCO frequency that will be mixed with the generator output.

        Note that the RFdc driver does its own math to round the frequency to the NCO's frequency step.
        If you want predictable behavior, the frequency you use here should already be rounded.
        Rounding is normally done for you as part of AbsQickProgram.declare_gen().

        :param dacname: DAC channel (2-digit string)
        :type dacname: int
        :param f: NCO frequency
        :type f: float
        :param force: force update, even if the setting is the same
        :type force: bool
        :param phase_reset: if we change the frequency, also reset the NCO's phase accumulator
        :type phase_reset: bool
        """
        if not force and f == self.get_mixer_freq(dacname):
            return

        tile, channel = self['dacs'][dacname]['index']
        # Make a copy of mixer settings.
        dac_mixer = self.dac_tiles[tile].blocks[channel].MixerSettings
        new_mixcfg = dac_mixer.copy()

        # Update the copy
        new_mixcfg.update({
            'EventSource': xrfdc.EVNT_SRC_IMMEDIATE,
            'Freq': f,
            'MixerType': xrfdc.MIXER_TYPE_FINE,
            'PhaseOffset': 0})

        # Update settings.
        self.dac_tiles[tile].blocks[channel].MixerSettings = new_mixcfg
        self.dac_tiles[tile].blocks[channel].UpdateEvent(xrfdc.EVENT_MIXER)
        # The phase reset is mostly important when setting the frequency to 0: you want the NCO to end up at 1 instead of a complex value.
        # So we apply the reset after setting the new frequency (otherwise you accumulate some rotation before stopping the NCO).
        if phase_reset: self.dac_tiles[tile].blocks[channel].ResetNCOPhase()
        self.mixer_dict[dacname] = f

    def get_mixer_freq(self, dacname):
        try:
            return self.mixer_dict[dacname]
        except KeyError:
            tile, channel = self['dacs'][dacname]['index']
            self.mixer_dict[dacname] = self.dac_tiles[tile].blocks[channel].MixerSettings['Freq']
            return self.mixer_dict[dacname]

    def set_nyquist(self, blockname, nqz, blocktype='dac', force=False):
        """
        Sets channel to operate in Nyquist zone nqz.
        This setting doesn't change the DAC output frequencies:
        you will always have some power at both the demanded frequency and its image(s).
        Setting the NQZ to 2 increases output power in the 2nd/3rd Nyquist zones.
        See "RF-DAC Nyquist Zone Operation" in PG269.

        :param blockname: channel ID (2-digit string)
        :type blockname: int
        :param nqz: Nyquist zone (1 or 2)
        :type nqz: int
        :param blocktype: 'dac' or 'adc'
        :type blocktype: str
        :param force: force update, even if the setting is the same
        :type force: bool
        """
        if nqz not in [1,2]:
            raise RuntimeError("Nyquist zone must be 1 or 2")
        if blocktype not in ['dac','adc']:
            raise RuntimeError("Block type must be adc or dac")
        if not force and self.get_nyquist(blockname, blocktype) == nqz:
            return
        if blocktype=='dac':
            tile, channel = self['dacs'][blockname]['index']
            self.dac_tiles[tile].blocks[channel].NyquistZone = nqz
        else:
            tile, channel = self['adcs'][blockname]['index']
            self.adc_tiles[tile].blocks[channel].NyquistZone = nqz
        self.nqz_dict[blocktype][blockname] = nqz

    def get_nyquist(self, blockname, blocktype='dac'):
        """
        Get the current Nyquist zone setting for a channel.

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)
        blocktype : str
            'dac' or 'adc'

        Returns
        -------
        int
            NQZ setting (1 or 2)
        """
        if blocktype not in ['dac','adc']:
            raise RuntimeError("Block type must be adc or dac")
        try:
            return self.nqz_dict[blocktype][blockname]
        except KeyError:
            if blocktype=='dac':
                tile, channel = self['dacs'][blockname]['index']
                self.nqz_dict[blocktype][blockname] = self.dac_tiles[tile].blocks[channel].NyquistZone
            else:
                tile, channel = self['adcs'][blockname]['index']
                self.nqz_dict[blocktype][blockname] = self.adc_tiles[tile].blocks[channel].NyquistZone
            return self.nqz_dict[blocktype][blockname]

    def get_adc_attenuator(self, blockname):
        """Read the ADC's built-in step attenuator.

        Only available for RFSoC Gen 3 (ZCU216, RFSoC4x2).

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)

        Returns
        -------
        float
            Attenuation value (dB)
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        return adc.DSA['Attenuation']

    def set_adc_attenuator(self, blockname, attenuation):
        """Set the ADC's built-in step attenuator.
        The requested value will be rounded to the nearest valid value (0-27 dB inclusive, 1 dB steps).

        Only available for RFSoC Gen 3 (ZCU216, RFSoC4x2).

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)
        attenuation : float
            Attenuation value (dB)
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        adc.DSA['Attenuation'] = np.round(attenuation)

    def get_adc_cal(self, blockname):
        """Get the current calibration coefficients for an ADC.

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)

        Returns
        -------
        dict of list
            Calibration coefficients
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        a = xrfdc._ffi.new("XRFdc_Calibration_Coefficients *")
        cal = {}
        for name, (const, n) in self.ADC_CAL_BLOCKS.items():
            adc.GetCalCoefficients(const, a)
            cal[name] = [getattr(a, 'Coeff%d'%(i)) for i in range(n)]
        return cal

    def set_adc_cal(self, blockname, cal, calblocks):
        """Set calibration coefficients for an ADC.

        See the Xilinx documentation for explanations and cautions:

        https://docs.amd.com/r/en-US/pg269-rf-data-converter/Getting/Setting-Calibration-Coefficients

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)
        cal : dict of list
            Calibration coefficients
        calblocks : list of str
            List of calibration blocks to configure.
            Valid values are OCB1, OCB2, GCB, TSCB.

        Returns
        -------
        dict of list
            Calibration coefficients
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        for name, (const, n) in self.ADC_CAL_BLOCKS.items():
            a = xrfdc._ffi.new("XRFdc_Calibration_Coefficients *")
            for i in range(n):
                setattr(a, 'Coeff%d'%(i), cal[name][i])
            adc.SetCalCoefficients(const, a)

    def restart_adc_tile(self, tile):
        """Restart an ADC tile.

        This is useful as a way to rerun the OCB2 offset calibration, though of course it resets all of the calibrations.
        WHatever voltage the ADCs on this tile are seeing when you run this, that will be 0 ADU.

        Parameters
        ----------
        tile : int
            ADC tile number (0-3)
        """
        self.adc_tiles[tile].Reset()

    def freeze_adc_cal(self, blockname):
        """Freeze an ADC's calibration (stop the background calibration).

        See the Xilinx documentation:

        https://docs.amd.com/r/en-US/pg269-rf-data-converter/Background-Calibration-Process

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        adc.CalFreeze['FreezeCalibration'] = 1

    def unfreeze_adc_cal(self, blockname, calblocks=None):
        """Unfreeze an ADC's calibration (resume the background calibration).

        See the Xilinx documentation:

        https://docs.amd.com/r/en-US/pg269-rf-data-converter/Background-Calibration-Process

        Parameters
        ----------
        blockname : str
            Channel ID (2-digit string)
        """
        tile, block = [int(x) for x in blockname]
        adc = self.adc_tiles[tile].blocks[block]
        adc.CalFreeze['FreezeCalibration'] = 0
        if calblocks is None:
            if self['ip_type'] < self.XRFDC_GEN3:
                calblocks = ['OCB1', 'OCB2', 'GCB', 'TSCB']
            else:
                calblocks = ['OCB2', 'GCB', 'TSCB']
        for calblock in calblocks:
            adc.DisableCoefficientsOverride(self.ADC_CAL_BLOCKS[calblock][0])

class QickSoc(Overlay, QickConfig):
    """
    This class loads, initializes, and provides access to the QICK firmware.

    Parameters
    ----------
    bitfile : str
        Path to the firmware bitfile. This should end with .bit, and the corresponding .hwh file must be in the same directory.
    download : bool
        Load the bitfile into the FPGA logic. If you are certain that the bitfile you specified is already running, you can use False here.
    no_tproc : bool
        Use if this is a special firmware that doesn't have a tProcessor.
    no_rf : bool
        Use if this is a special firmware that doesn't have an RF data converter.
    force_init_clks : bool
        Re-initialize the board clocks regardless of whether they appear to be locked. Specifying (as True or False) the clk_output or external_clk options will also force clock initialization.
    clk_output: bool or None
        If true, output a copy of the RF reference. This option is supported for the ZCU111 (get 122.88 MHz from J108) and ZCU216 (get 245.76 MHz from OUTPUT_REF J10).
    external_clk: bool or None
        If true, lock the board clocks to an external reference. This option is supported for the ZCU111 (put 12.8 MHz on External_REF_CLK J109), ZCU216 (put 10 MHz on INPUT_REF_CLK J11), and RFSoC 4x2 (put 10 MHz on CLK_IN).
    dac_sample_rates : dict[int, float] or None
        Sample rates to override the values compiled into the firmware.
        This should be a dictionary mapping DAC tiles to sample rates (in megasamples per second).
    adc_sample_rates : dict[int, float] or None
        Sample rates to override the values compiled into the firmware.
        This should be a dictionary mapping ADC tiles to sample rates (in megasamples per second).
    """

    # The following constants are no longer used. Some of the values may not match the bitfile.
    # fs_adc = 384*8 # MHz
    # fs_dac = 384*16 # MHz
    # pulse_mem_len_IQ = 65536 # samples for I, Q
    # ADC_decim_buf_len_IQ = 1024 # samples for I, Q
    # ADC_accum_buf_len_IQ = 16384 # samples for I, Q
    #tProc_instruction_len_bytes = 8
    #tProc_prog_mem_samples = 8000
    #tProc_prog_mem_size_bytes_tot = tProc_instruction_len_bytes*tProc_prog_mem_samples
    #tProc_data_len_bytes = 4
    #tProc_data_mem_samples = 4096
    #tProc_data_mem_size_bytes_tot = tProc_data_len_bytes*tProc_data_mem_samples
    #tProc_stack_len_bytes = 4
    #tProc_stack_samples = 256
    #tProc_stack_size_bytes_tot = tProc_stack_len_bytes*tProc_stack_samples
    #phase_resolution_bits = 32
    #gain_resolution_signed_bits = 16

    # Constructor.
    def __init__(self, bitfile=None, download=True, no_tproc=False, no_rf=False, force_init_clks=False, clk_output=None, external_clk=None, dac_sample_rates=None, adc_sample_rates=None, **kwargs):
        self.external_clk = external_clk
        self.clk_output = clk_output
        # Read the bitstream configuration from the HWH file.
        # If download=True, we also program the FPGA.
        if bitfile is None:
            Overlay.__init__(self, bitfile_path(
            ), ignore_version=True, download=download, **kwargs)
        else:
            Overlay.__init__(
                self, bitfile, ignore_version=True, download=download, **kwargs)

        # Initialize the configuration
        self._cfg = {}
        QickConfig.__init__(self)

        self['board'] = os.environ["BOARD"]
        self['sw_version'] = get_version()

        # a space to dump any additional lines of config text which you want to print in the QickConfig
        self['extra_description'] = []

        # Extract the IP connectivity information from the HWH parser and metadata.
        self.metadata = QickMetadata(self)
        self['fw_timestamp'] = self.metadata.timestamp

        # Initialize lists of IP blocks.
        # Signal generators (anything driven by the tProc)
        self.gens = []
        # Constant generators
        self.iqs = []
        # Average + Buffer blocks.
        self.avg_bufs = []
        # Readout blocks.
        self.readouts = []

        if not no_rf:
            # RF data converter (for configuring ADCs and DACs, and setting NCOs)
            self.rf = self.usp_rf_data_converter_0
            self['rf'] = self.rf.cfg
            # map the clock networks, so we can validate the requested sampling rates
            self.rf.map_clocks(self)

            # Examine the RFDC config to find the reference clock frequency.
            refclks = []
            for tiletype in ['dac', 'adc']:
                refclks.extend([v['f_ref'] for k,v in self.rf['tiles'][tiletype].items()])
            if len(set(refclks)) != 1:
                raise RuntimeError("This firmware wants RF reference clocks %s, but they must all be equal"%(refclks))
            self['refclk_freq'] = refclks[0]

            # Configure xrfclk reference clocks
            self.config_clocks(force_init_clks)

            # Update the ADC sample rate if specified
            if dac_sample_rates or adc_sample_rates:
                self.rf.configure_sample_rates(dac_sample_rates, adc_sample_rates)

        if no_tproc:
            self.TPROC_VERSION = 0
        else:
            # tProcessor, 64-bit instruction, 32-bit registers, x8 channels.
            if 'axis_tproc64x32_x8_0' in self.ip_dict:
                self.TPROC_VERSION = 1
                self._tproc = self.axis_tproc64x32_x8_0
                self._tproc.configure(self.axi_bram_ctrl_0, self.axi_dma_tproc)
            elif 'qick_processor_0' in self.ip_dict:
                self.TPROC_VERSION = 2
                self._tproc = self.qick_processor_0
                self._tproc.configure(self.axi_dma_tproc)
            else:
                raise RuntimeError('No tProcessor found')

            #self.tnet = self.qick_net_0

            self.map_signal_paths()

            self._streamer = DataStreamer(self)

            # list of objects that need to be registered for autoproxying over Pyro
            self.autoproxy = [self.streamer, self.tproc]

    @property
    def tproc(self):
        return self._tproc
    
    @property
    def streamer(self):
        return self._streamer

    def _get_block(self, fullpath):
        """Return the IP block specified by its full path.
        """
        #return getattr(self, fullpath.replace('/','_'))
        block = self
        # recurse into hierarchies, if present
        for x in fullpath.split('/'):
            block = getattr(block, x)
        return block

    def map_signal_paths(self):
        """
        Make lists of signal generator, readout, and buffer blocks in the firmware.
        Also map the switches connecting the generators and buffers to DMA.
        Fill the config dictionary with parameters of the DAC and ADC channels.
        """
        # Use the HWH parser to trace connectivity and deduce the channel numbering.
        # Some blocks (e.g. DDR4) are inside hierarchies.
        # We access these through the hierarchy (e.g. self.ddr4.axis_buffer_ddr_v1_0)
        # but list them using ip_dict, which has all blocks, even those inside hierarchies
        for key, val in self.ip_dict.items():
            if hasattr(val['driver'], 'configure_connections'):
                self._get_block(val['fullpath']).configure_connections(self)

        # Populate the lists with the registered IP blocks.
        for key, val in self.ip_dict.items():
            if issubclass(val['driver'], AbsPulsedSignalGen):
                self.gens.append(getattr(self, key))
            elif val['driver'] == AxisConstantIQ:
                self.iqs.append(getattr(self, key))
            elif issubclass(val['driver'], AbsReadout):
                self.readouts.append(getattr(self, key))
            elif issubclass(val['driver'], AxisAvgBuffer):
                self.avg_bufs.append(getattr(self, key))

        # AxisReadoutV3 isn't a PYNQ-registered IP block, so we add it here
        for buf in self.avg_bufs:
            if buf.readout not in self.readouts:
                self.readouts.append(buf.readout)

        # Sort the lists.
        # We order gens by the tProc port number and tProc mux port number (if present).
        # We order buffers by the switch port number.
        # Those orderings are important, since those indices get used in programs.
        self.gens.sort(key=lambda x:(x['tproc_ch'], x._cfg.get('tmux_ch')))
        self.avg_bufs.sort(key=lambda x: x.switch_ch)
        # The IQ and readout orderings aren't critical for anything.
        self.iqs.sort(key=lambda x: x.dac)
        self.readouts.sort(key=lambda x: x.adc)

        # Configure the drivers.
        for i, gen in enumerate(self.gens):
            gen.configure(i, self.rf)

        for i, iq in enumerate(self.iqs):
            iq.configure(i, self.rf)

        for readout in self.readouts:
            readout.configure(self.rf)

        # Find the MR buffer, if present.
        try:
            self.mr_buf = self.mr_buffer_et_0
            self['mr_buf'] = self.mr_buf.cfg
        except:
            pass

        # Find the DDR4 controller and buffer, if present.
        try:
            if hasattr(self, 'ddr4'):
                self.ddr4_buf = self.ddr4.axis_buffer_ddr_v1_0
            else:
                self.ddr4_buf = self.axis_buffer_ddr_v1_0
            self['ddr4_buf'] = self.ddr4_buf.cfg
        except:
            pass

        # Fill the config dictionary with driver parameters.
        self['gens'] = [gen.cfg for gen in self.gens]
        self['iqs'] = [iq.cfg for iq in self.iqs]

        # In the config, we define a "readout" as the chain of ADC+readout+buffer.
        def merge_cfgs(bufcfg, rocfg):
            merged = {**bufcfg, **rocfg}
            for k in set(bufcfg.keys()) & set(rocfg.keys()):
                del merged[k]
                merged["avgbuf_"+k] = bufcfg[k]
                merged["ro_"+k] = rocfg[k]
            return merged
        self['readouts'] = [merge_cfgs(buf.cfg, buf.readout.cfg) for buf in self.avg_bufs]

        self['tprocs'] = [self.tproc.cfg]

    def config_clocks(self, force_init_clks):
        """
        Configure PLLs if requested, or if any ADC/DAC is not locked.
        The ADC/DAC PLL lock status is read through the RFDC IP, so this assumes that the bitstream has already been downloaded.
        The reference clock frequency must already have been read from the firmware config.
        """
        # if we're changing the clock config, we must set the clocks to apply the config
        if force_init_clks or (self.external_clk is not None) or (self.clk_output is not None):
            self.set_all_clks()
        else:
            # only set clocks if the RFDC isn't locked
            if not self.clocks_locked():
                self.set_all_clks()
        # Check if all DAC and ADC PLLs are locked.
        if not self.clocks_locked():
            print(
                "Not all DAC and ADC PLLs are locked. The FPGA may not be getting a good reference clock from the on-board clock chips.")

    def clocks_locked(self):
        """
        Checks whether the DAC and ADC PLLs are locked.
        This can only be run after the bitstream has been downloaded.
        A failure usually means the FPGA is not getting a good reference clock from the on-board clock chips.

        :return: clock status
        :rtype: bool
        """
        dac_locked, adc_locked = self.rf.clocks_locked()
        return all(dac_locked) and all(adc_locked)

    def set_all_clks(self):
        """
        Resets all the board clocks
        """
        if self['board'] == 'ZCU111':
            # master clock generator is LMK04208, always outputs 122.88
            # DAC/ADC are clocked by LMX2594
            # available: 102.4, 204.8, 409.6, 737.0
            lmk_freq = 122.88
            lmx_freq = self['refclk_freq']
            print("resetting clocks:", lmk_freq, lmx_freq)

            if hasattr(xrfclk, "xrfclk"): # pynq 2.7
                # load the default clock chip configurations from file, so we can then modify them
                xrfclk.xrfclk._find_devices()
                xrfclk.xrfclk._read_tics_output()
                if self.clk_output:
                    # change the register for the LMK04208 chip's 5th output, which goes to J108
                    # we need this for driving the RF board
                    xrfclk.xrfclk._Config['lmk04208'][lmk_freq][6] = 0x00140325
                if self.external_clk:
                    # default value is 0x2302886D
                    xrfclk.xrfclk._Config['lmk04208'][lmk_freq][14] = 0x2302826D
            else: # pynq 2.6
                if self.clk_output:
                    # change the register for the LMK04208 chip's 5th output, which goes to J108
                    # we need this for driving the RF board
                    xrfclk._lmk04208Config[lmk_freq][6] = 0x00140325
                else: # restore the default
                    xrfclk._lmk04208Config[lmk_freq][6] = 0x80141E05
                if self.external_clk:
                    xrfclk._lmk04208Config[lmk_freq][14] = 0x2302826D
                else: # restore the default
                    xrfclk._lmk04208Config[lmk_freq][14] = 0x2302886D
            xrfclk.set_all_ref_clks(lmx_freq)
        elif self['board'] == 'ZCU216':
            # master clock generator is LMK04828, which is used for DAC/ADC clocks
            # only 245.76 available by default
            # LMX2594 is not used
            # available: 102.4, 204.8, 409.6, 491.52, 737.0
            lmk_freq = self['refclk_freq']
            lmx_freq = self['refclk_freq']*2
            print("resetting clocks:", lmk_freq, lmx_freq)

            assert hasattr(xrfclk, "xrfclk") # ZCU216 only has a pynq 2.7 image
            xrfclk.xrfclk._find_devices()
            xrfclk.xrfclk._read_tics_output()
            if self.external_clk:
                # default value is 0x01471A
                xrfclk.xrfclk._Config['lmk04828'][lmk_freq][80] = 0x01470A
            if self.clk_output:
                # default value is 0x012C22
                xrfclk.xrfclk._Config['lmk04828'][lmk_freq][55] = 0x012C02
            xrfclk.set_ref_clks(lmk_freq=lmk_freq, lmx_freq=lmx_freq)
        elif self['board'] == 'RFSoC4x2':
            # master clock generator is LMK04828, always outputs 245.76
            # DAC/ADC are clocked by LMX2594
            # available: 102.4, 204.8, 409.6, 491.52, 737.0
            lmk_freq = 245.76
            lmx_freq = self['refclk_freq']
            print("resetting clocks:", lmk_freq, lmx_freq)

            xrfclk.xrfclk._find_devices()
            xrfclk.xrfclk._read_tics_output()
            if self.external_clk:
                # default value is 0x01471A
                xrfclk.xrfclk._Config['lmk04828'][lmk_freq][80] = 0x01470A
            xrfclk.set_ref_clks(lmk_freq=lmk_freq, lmx_freq=lmx_freq)

        # wait for the clock chips to lock
        time.sleep(1.0)

    def get_sample_rates(self):
        """
        Produce dictionaries of the current sample rates of the DAC and ADC tiles.
        A dictionary of this form can be used to configure the sample rates at SoC initialization.

        Returns
        -------
        dict[str, dict[int, float]]
            A pair of dictionaries mapping DAC/ADC tiles to sample rates (in Msps).
        """
        return {tiletype: {k: v['fs'] for k,v in self['rf']['tiles'][tiletype].items()} for tiletype in ['dac', 'adc']}

    def valid_sample_rates(self, tiletype, tile):
        """
        Return an array of valid sample rates.
        This does not account for dependencies due to clock groups,
        or the restriction that you're not allowed to raise the sample rate.

        Parameters
        ----------
        tiletype : str
            'dac' or 'adc'
        tile : int
            Tile number (0-3)

        Returns
        -------
        numpy.ndarray
            Array of sample rates, in Msps
        """
        return self.rf.valid_sample_rates(tiletype, tile)

    def round_sample_rate(self, tiletype, tile, fs_target):
        """
        Return the closest achievable sample rate to the requested value.
        This does not account for dependencies due to clock groups,
        or the restriction that you're not allowed to raise the sample rate.

        Parameters
        ----------
        tiletype : str
            'dac' or 'adc'
        tile : int
            Tile number (0-3)
        fs_target : float
            Requested sample rate, in Msps

        Returns
        -------
        float
            Closest valid sample rate, in Msps
        """
        return self.rf.round_sample_rate(tiletype, tile, fs_target)

    def get_decimated(self, ch, address=0, length=None):
        """
        Acquires data from the readout decimated buffer

        :param ch: ADC channel
        :type ch: int
        :param address: Address of data
        :type address: int
        :param length: Buffer transfer length
        :type length: int
        :return: List of I and Q decimated arrays
        :rtype: list of numpy.ndarray
        """
        if length is None:
            # this default will always cause a RuntimeError
            # TODO: remove the default, or pick a better fallback value
            length = self.avg_bufs[ch]['buf_maxlen']

        # request data from DMA
        return self.avg_bufs[ch].transfer_buf(address, length)

    def get_accumulated(self, ch, address=0, length=None):
        """
        Acquires data from the readout accumulated buffer

        :param ch: ADC channel
        :type ch: int
        :param address: Address of data
        :type address: int
        :param length: Buffer transfer length
        :type length: int
        :returns:
            - di[:length] (:py:class:`list`) - list of accumulated I data
            - dq[:length] (:py:class:`list`) - list of accumulated Q data
        """
        if length is None:
            # this default will always cause a RuntimeError
            # TODO: remove the default, or pick a better fallback value
            length = self.avg_bufs[ch]['avg_maxlen']

        # request data from DMA
        return self.avg_bufs[ch].transfer_avg(address, length)

    def configure_readout(self, ch, ro_regs):
        """Configure readout channel output style and frequency.
        This method is only for use with PYNQ-configured readouts.

        Parameters
        ----------
        ch : int
            readout channel number (index in 'readouts' list)
        ro_regs : dict
            readout registers, from QickConfig.calc_ro_regs()
        """
        buf = self.avg_bufs[ch]
        buf.readout.set_all_int(ro_regs)

    def config_avg(
        self, ch, address=0, length=1,
        edge_counting=False, high_threshold=1000, low_threshold=0):
        """Configure accumulated buffer; must then enable using enable_buf()

        Parameters
        ----------
        ch : int
            Readout channel to configure
        address : int
            Starting address of buffer
        length : int
            length of buffer (how many samples to integrate)
        """
        avg_buf = self.avg_bufs[ch]
        if avg_buf['has_edge_counter']:
            avg_buf.config_avg(
                address, length,
                edge_counting=edge_counting, high_threshold=high_threshold, low_threshold=low_threshold)
        else:
            avg_buf.config_avg(address, length)

    def config_buf(self, ch, address=0, length=1):
        """Configure decimated buffer; must then enable using enable_buf()

        Parameters
        ----------
        ch : int
            Readout channel to configure
        address : int
            Starting address of buffer
        length : int
            length of buffer (how many samples to take)
        """
        avg_buf = self.avg_bufs[ch]
        avg_buf.config_buf(address, length)

    def enable_buf(self, ch, enable_avg=True, enable_buf=True):
        """Enable capture of accumulated and/or decimated data for a buffer

        Parameters
        ----------
        ch : int
            Readout channel to configure
        enable_avg : bool
            Enable accumulated data capture
        enable_buf : bool
            Enable decimated data capture
        """
        avg_buf = self.avg_bufs[ch]
        avg_buf.enable(avg=enable_avg, buf=enable_buf)

    def load_weights(self, ch, data, addr=0):
        """Load weights array to a weighted buffer.

        Parameters
        ----------
        ch : int
            Readout channel to configure
        data : numpy.ndarray of int16
            array of 16-bit (I, Q) values for weights
        address : int
            starting address
        """
        # we may have converted to list for pyro compatiblity, so convert back to ndarray
        data = np.array(data, dtype=np.int16)
        self.avg_bufs[ch].load_weights(data, addr)

    def load_envelope(self, ch, data, addr):
        """Load envelope data into signal generators
        :param ch: Channel
        :type ch: int
        :param data: array of (I, Q) values for pulse envelope
        :type data: numpy.ndarray of int16
        :param addr: address to start data at
        :type addr: int
        """
        # we may have converted to list for pyro compatiblity, so convert back to ndarray
        data = np.array(data, dtype=np.int16)
        self.gens[ch].load(xin=data, addr=addr)

    def set_nyquist(self, ch, nqz, force=False):
        """
        Sets DAC channel ch to operate in Nyquist zone nqz mode.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param nqz: Nyquist zone
        :type nqz: int
        """

        self.gens[ch].set_nyquist(nqz)

    def set_mixer_freq(self, ch, f, ro_ch=None, phase_reset=True):
        """
        Set mixer frequency for a signal generator.
        If the generator does not have a mixer, you will get an error.

        Parameters
        ----------
        ch : int
            DAC channel (index in 'gens' list)
        f : float
            Mixer frequency (in MHz)
        ro_ch : int
            readout channel (index in 'readouts' list) for frequency matching
            use None if you don't want mixer freq to be rounded to a valid readout frequency
        phase_reset : bool
            if this changes the frequency, also reset the phase (so if we go to freq=0, we end up on the real axis)
        """
        if self.gens[ch].HAS_MIXER:
            self.gens[ch].set_mixer_freq(f, ro_ch, phase_reset=phase_reset)
        elif f != 0:
            raise RuntimeError("tried to set a mixer frequency, but this channel doesn't have a mixer")

    def config_mux_gen(self, ch, tones):
        """Set up a list of tones all at once, using raw (integer) units.
        If the supplied list of tones is shorter than the number supported, the extra tones will have their gains set to 0.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        tones : list of dict
            Tones to configure.
            This is generated by QickConfig.calc_muxgen_regs().
        """
        self.gens[ch].set_tones_int(tones)

    def config_mux_readout(self, pfbpath, cfgs, sel=None):
        """Set up a list of readout frequencies all at once, using raw (integer) units.

        Parameters
        ----------
        pfbpath : str
            Firmware path of the PFB readout being configured.
        cfgs : list of dict
            Readout chains to configure.
            This is generated by QickConfig.calc_pfbro_regs().
        sel : str
            Output selection (if supported), default to 'product'
        """
        pfb = getattr(self, pfbpath)
        if pfb.HAS_OUTSEL:
            if sel is None: sel = 'product'
            pfb.set_out(sel)
        else:
            if sel is not None:
                raise RuntimeError("this readout doesn't support configuring sel, you have sel=%s" % (sel))
        for cfg in cfgs:
            pfb.set_freq_int(cfg)

    def set_iq(self, ch, f, i, q, ro_ch=None, phase_reset=True):
        """
        Set frequency, I, and Q for a constant-IQ output.

        Parameters
        ----------
        ch : int
            DAC channel (index in 'gens' list)
        f : float
            frequency (in MHz)
        i : float
            I value (in range -1 to 1)
        q : float
            Q value (in range -1 to 1)
        ro_ch : int
            readout channel (index in 'readouts' list) for frequency matching
            use None if you don't want freq to be rounded to a valid readout frequency
        phase_reset : bool
            if this changes the frequency, also reset the phase (so if we go to freq=0, we end up on the real axis)
        """
        self.iqs[ch].set_mixer_freq(f)
        self.iqs[ch].set_iq(i, q)

    def load_bin_program(self, binprog, load_mem=True):
        """Write the program to the tProc program memory.

        Parameters
        ----------
        binprog : numpy.ndarray or dict
            compiled program (format depends on tProc version)
        load_mem : bool
            write waveform and data memory now (can do this later with reload_mem())
        """
        self.tproc.load_bin_program(obtain(binprog), load_mem=load_mem)

    def reload_mem(self):
        """Reload the waveform and data memory, overwriting any changes made by running the program.
        """
        if self.TPROC_VERSION == 2:
            self.tproc.reload_mem()

    def load_mem(self, buff, mem_sel='dmem', addr=0):
        """
        Write a block of the selected tProc memory.
        For tProc v1 only the data memory ("dmem") is valid.
        For tProc v2 the program, data, and waveform memory are all accessible.

        Parameters
        ----------
        buff_in : numpy.ndarray of int
            Data to be loaded
            32-bit array of shape (n, 8) for pmem and wmem, (n) for dmem
        mem_sel : str
            "pmem", "dmem", "wmem"
        addr : int
            Starting write address
        """
        if self.TPROC_VERSION == 1:
            if mem_sel=='dmem':
                self.tproc.load_dmem(buff, addr)
            else:
                raise RuntimeError("invalid mem_sel: %s"%(mem_sel))
        elif self.TPROC_VERSION == 2:
            self.tproc.load_mem(mem_sel, buff, addr)

    def read_mem(self, length, mem_sel='dmem', addr=0):
        """
        Read a block of the selected tProc memory.
        For tProc v1 only the data memory ("dmem") is valid.
        For tProc v2 the program, data, and waveform memory are all accessible.

        Parameters
        ----------
        length : int
            Number of words to read
        mem_sel : str
            "pmem", "dmem", "wmem"
        addr : int
            Starting read address

        Returns
        -------
        numpy.ndarray
            32-bit array of shape (n, 8) for pmem and wmem, (n) for dmem
        """
        if self.TPROC_VERSION == 1:
            if mem_sel=='dmem':
                return self.tproc.read_dmem(addr, length)
            else:
                raise RuntimeError("invalid mem_sel: %s"%(mem_sel))
        elif self.TPROC_VERSION == 2:
            return self.tproc.read_mem(mem_sel, length, addr)

    def start_src(self, src):
        """
        Sets the start source of tProc

        :param src: start source "internal" or "external"
        :type src: str
        """
        if self.TPROC_VERSION == 1:
            self.tproc.start_src(src)
        # TODO: not implemented for tproc v2

    def start_tproc(self):
        """
        Start the tProc.
        """
        if self.TPROC_VERSION == 1:
            self.tproc.start()
        elif self.TPROC_VERSION == 2:
            self.tproc.stop()
            self.tproc.start()

    def stop_tproc(self, lazy=False):
        """
        Stop the tProc.
        This is somewhat slow (tens of ms) for tProc v1.

        Parameters
        ----------
        lazy : bool
            Only stop the tProc if it's easy (i.e. do nothing for v1)
        """
        if self.TPROC_VERSION == 1:
            if not lazy:
                # there's no easy way to stop v1 - we need to reset and reload
                self.tproc.reset()
                # reload the program (since the reset will have wiped it out)
                self.tproc.reload_program()
        elif self.TPROC_VERSION == 2:
            self.tproc.stop()

    def set_tproc_counter(self, addr, val):
        """
        Initialize the tProc shot counter.
        For tProc v2. this does nothing (the counter is typically initialized by the program).

        Parameters
        ----------
        addr : int
            Counter address

        Returns
        -------
        int
            Counter value
        """
        if self.TPROC_VERSION == 1:
            self.tproc.single_write(addr=addr, data=val)

    def get_tproc_counter(self, addr):
        """
        Read the tProc shot counter.
        For tProc V1, this accesses the data memory at the given address.
        For tProc V2, this accesses one of the two special AXI-readable registers.

        Parameters
        ----------
        addr : int
            Counter address

        Returns
        -------
        int
            Counter value
        """
        if self.TPROC_VERSION == 1:
            return self.tproc.single_read(addr=addr)
        elif self.TPROC_VERSION == 2:
            self.tproc.read_sel=1
            reg = {1:'axi_r_dt1', 2:'axi_r_dt2'}[addr]
            return getattr(self.tproc, reg)

    def reset_gens(self):
        """
        Reset the tProc and run a minimal tProc program that drives all signal generators with 0's.
        Useful for stopping any periodic or stdysel="last" outputs that may have been driven by a previous program.
        """
        # list channel numbers for all generators capable of playing arbitrary envelopes
        # (what we actually care about is whether they can play periodic pulses, but it's the same set of gens)
        gen_chs = [i for i, gen in enumerate(self.gens) if isinstance(gen, AbsArbSignalGen)]

        if self.TPROC_VERSION == 1:
            prog = QickProgram(self)
            for gen in gen_chs:
                prog.set_pulse_registers(ch=gen, style="const", mode="oneshot", freq=0, phase=0, gain=0, length=3)
                prog.pulse(ch=gen,t=0)
            prog.end()
        elif self.TPROC_VERSION == 2:
            prog = QickProgramV2(self)
            for gen in gen_chs:
                prog.pulse(ch=gen, name="dummypulse", t=0)
            prog.end()
        self.tproc.reset()
        # this should always run with internal trigger
        prog.run(self, start_src="internal")

    def start_readout(self, total_shots, counter_addr=1, ch_list=None, reads_per_shot=1, stride=None):
        """
        Start a streaming readout of the accumulated buffers.

        :param total_shots: Final value expected for the shot counter
        :type total_shots: int
        :param counter_addr: Data memory address for the shot counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type ch_list: list of int
        :param reads_per_shot: Number of data points to expect per counter increment
        :type reads_per_shot: list of int
        :param stride: Default number of measurements to transfer at a time.
        :type stride: int
        """
        ch_list = obtain(ch_list)
        reads_per_shot = obtain(reads_per_shot)
        if ch_list is None: ch_list = [0, 1]
        if isinstance(reads_per_shot, int):
            reads_per_shot = [reads_per_shot]*len(ch_list)
        streamer = self.streamer

        if not streamer.readout_worker.is_alive():
            print("restarting readout worker")
            streamer.start_worker()
            print("worker restarted")

        # if there's still a readout job running, stop it
        if streamer.readout_running():
            print("cleaning up previous readout: stopping tProc and streamer loop")
            # stop the tProc
            self.stop_tproc()
            # tell the readout to stop (this will break the readout loop)
            streamer.stop_readout()
            streamer.done_flag.wait()
            # push a dummy packet into the data queue to halt any running poll_data(), and wait long enough for the packet to be read out
            streamer.data_queue.put((0, None))
            time.sleep(0.1)
            print("streamer stopped")
        streamer.stop_flag.clear()

        if streamer.data_available():
            # flush all the data in the streamer buffer
            print("clearing streamer buffer")
            # read until the queue times out, discard the data
            self.poll_data(totaltime=-1, timeout=0.1)
            print("buffer cleared")

        streamer.total_count = total_shots
        streamer.count = 0

        streamer.done_flag.clear()
        streamer.job_queue.put((total_shots, counter_addr, ch_list, reads_per_shot, stride))

    def poll_data(self, totaltime=0.1, timeout=None):
        """
        Get as much data as possible from the streamer data queue.
        Stop when any of the following conditions are met:
        * all the data has been transferred (based on the total_count)
        * we got data, and it has been totaltime seconds since poll_data was called
        * timeout is defined, and the timeout expired without getting new data in the queue
        If there are errors in the error queue, raise the first one.

        :param totaltime: How long to acquire data (negative value = ignore total time and total count, just read until timeout)
        :type totaltime: float
        :param timeout: How long to wait for the next data packet (None = wait forever)
        :type timeout: float
        :return: list of (data, stats) pairs, oldest first
        :rtype: list
        """
        streamer = self.streamer

        time_end = time.time() + totaltime
        new_data = []
        while (totaltime < 0) or (streamer.count < streamer.total_count and time.time() < time_end):
            try:
                raise RuntimeError("exception in readout loop") from streamer.error_queue.get(block=False)
            except queue.Empty:
                pass
            try:
                length, data = streamer.data_queue.get(block=True, timeout=timeout)
                # if we stopped the readout while we were waiting for data, break out and return
                if streamer.stop_flag.is_set() or data is None:
                    break
                streamer.count += length
                new_data.append((length, data))
            except queue.Empty:
                break
        return new_data

    def clear_ddr4(self, length=None):
        """Clear the DDR4 buffer, filling it with 0's.
        This is not necessary (the buffer will overwrite old data), but may be useful for debugging.
        Clearing the full buffer (4 GB) typically takes 4-5 seconds.

        Parameters
        ----------
        length : int
            Number of samples to clear (starting at the beginning of the buffer). If None, clear the entire buffer.
        """
        self.ddr4_buf.clear_mem(length)

    def get_ddr4(self, nt, start=None):
        """Get data from the DDR4 buffer.
        The first samples (typically 401 or 801) of the buffer are always stale data from the previous acquisition.

        Parameters
        ----------
        nt : int
            Number of data transfers (each transfer is 128 or 256 decimated samples) to retrieve.
            If start=None, the amount of data will be reduced (see below).
        start : int
            Number of samples to skip at the beginning of the buffer.
            If a value is specified, the end address of the transfer window will also be incremented.
            If None, the junk at the start of the buffer will be skipped but the end address will not be incremented.
            This reduces the amount of data, giving you exactly the block of valid data from a DDR4 trigger with the same value of nt.
        """
        return self.ddr4_buf.get_mem(nt, start)

    def arm_ddr4(self, ch, nt, force_overwrite=False):
        """Prepare the DDR4 buffer to take data.
        This must be called before starting a program that triggers the buffer.
        Once the buffer is armed, the first trigger it receives will cause the buffer to record the specified amount of data.
        Later triggers will have no effect.

        Parameters
        ----------
        ch : int
            The readout channel to record (index in 'readouts' list).
        nt : int
            Number of data transfers to record; the number of IQ samples/transfer (128 or 256) is printed in the QickSoc config.
            Note that the amount of useful data is less (see ``get_ddr4``)
        force_overwrite : bool
            Allow a DDR4 acqusition that exceeds the DDR4 memory capacity. The memory will be used as a circular buffer:
            later transfers will wrap around to the beginning of the memory and overwrite older data.
        """
        self.ddr4_buf.set_switch(self['readouts'][ch]['avgbuf_fullpath'])
        self.ddr4_buf.arm(nt, force_overwrite)

    def arm_mr(self, ch):
        """Prepare the Multi-Rate buffer to take data.
        This must be called before starting a program that triggers the buffer.
        Once the buffer is armed, the first trigger it receives will cause the buffer to record until the buffer is filled.
        Later triggers will have no effect.

        Parameters
        ----------
        ch : int
            The readout channel to record (index in 'readouts' list).
        """
        self.mr_buf.set_switch(self['readouts'][ch]['avgbuf_fullpath'])
        self.mr_buf.disable()
        self.mr_buf.enable()

    def get_mr(self, start=None):
        """Get data from the multi-rate buffer.
        The first 8 samples are always stale data from the previous acquisition.
        The transfer window always extends to the end of the buffer.

        Parameters
        ----------
        start : int
            Number of samples to skip at the beginning of the buffer.
            If None, the junk at the start of the buffer is skipped.
        """
        return self.mr_buf.transfer(start)

