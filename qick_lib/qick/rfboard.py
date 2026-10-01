from .qick import QickSoc
from .ip import SocIP
from .drivers.hardware import *
from .qick_asm import QickConfig
from pynq.buffer import allocate
import numpy as np
import time
from contextlib import contextmanager, suppress
from abc import ABC, abstractmethod
import logging

logger = logging.getLogger(__name__)

class AxisSignalGenV3(SocIP):
    # AXIS Table Registers.
    # START_ADDR_REG
    #
    # WE_REG
    # * 0 : disable writes.
    # * 1 : enable writes.
    #
    bindto = ['user.org:user:axis_signal_gen_v3:1.0',
              'QICK:QICK:axis_signal_gen_v3:1.0']

    # Generics
    N = 12
    NDDS = 16

    # Maximum number of samples
    MAX_LENGTH = 2**N*NDDS

    def __init__(self, description, **kwargs):
        super().__init__(description)
        self.REGISTERS = {'start_addr_reg': 0, 'we_reg': 1}

    def config(self, axi_dma, dds_mr_switch, axis_switch, channel, name, **kwargs):
        # Default registers.
        self.start_addr_reg = 0
        self.we_reg = 0

        # dma
        self.dma = axi_dma

        # Real/imaginary selection switch.
        #self.iq_switch = AxisDdsMrSwitch(dds_mr_switch)
        self.iq_switch = dds_mr_switch

        # switch
        self.switch = axis_switch

        # Channel.
        self.ch = channel

        # Name.
        self.name = name

    # Load waveforms.
    def load(self, buff_in, addr=0):
        # Route switch to channel.
        self.switch.sel(slv=self.ch)

        time.sleep(0.1)

        # Define buffer.
        self.buff = allocate(shape=(len(buff_in)), dtype=np.int16)

        ###################
        ### Load I data ###
        ###################
        np.copyto(self.buff, buff_in)

        # Enable writes.
        self.wr_enable(addr)

        # DMA data.
        self.dma.sendchannel.transfer(self.buff)
        self.dma.sendchannel.wait()

        # Disable writes.
        self.wr_disable()

    def wr_enable(self, addr=0):
        self.start_addr_reg = addr
        self.we_reg = 1

    def wr_disable(self):
        self.we_reg = 0


class AxisSignalGenV3Ctrl(SocIP):
    # Signal Generator V3 Control registers.
    # ADDR_REG
    bindto = ['user.org:user:axis_signal_gen_v3_ctrl:1.0',
              'QICK:QICK:axis_signal_gen_v3_ctrl:1.0']

    # Generics of Signal Generator.
    N = 10
    NDDS = 16
    B = 16
    MAX_v = 2**B - 1

    # Sampling frequency.
    fs = 4096

    def __init__(self, description, **kwargs):
        super().__init__(description)
        self.REGISTERS = {
            'freq': 0,
            'phase': 1,
            'addr': 2,
            'gain': 3,
            'nsamp': 4,
            'outsel': 5,
            'mode': 6,
            'stdysel': 7,
            'we': 8}

        # Default registers.
        self.freq = 0
        self.phase = 0
        self.addr = 0
        self.gain = 30000
        self.nsamp = 16*100
        self.outsel = 1  # dds
        self.mode = 1  # periodic
        self.stdysel = 1  # zero
        self.we = 0

    def add(self,
            freq=0,
            phase=0,
            addr=0,
            gain=30000,
            nsamp=16*100,
            outsel="dds",
            mode="periodic",
            stdysel="zero"):

        # Input frequency is in MHz.
        w0 = 2*np.pi*freq/self.fs
        freq_tmp = w0/(2*np.pi)*self.MAX_v

        self.freq = int(np.round(freq_tmp))
        self.phase = phase
        self.addr = addr
        self.gain = gain
        self.nsamp = int(np.round(nsamp/self.NDDS))

        self.outsel = {"product": 0, "dds":1, "envelope":2}[outsel]
        self.mode = {"nsamp": 0, "periodic":1}[mode]
        self.stdysel = {"last": 0, "zero":1}[stdysel]

        # Write fifo..
        self.we = 1
        self.we = 0

    def set_fs(self, fs):
        self.fs = fs

class AxisSignalGenV6Ctrl(SocIP):
    # Signal Generator V6 Control registers.
    # FREQ_REG      : 32-bit.

    # PHASE_REG     : 32-bit.

    # ADDR_REG      : 16-bit.

    # GAIN_REG      : 16-bit.

    # NSAMP_REG     : 16-bit.

    # OUTSEL_REG    : 2-bit.
    # * 0 : product.
    # * 1 : dds.
    # * 2 : envelope.

    # MODE_REG      : 1-bit.
    # * 0 : nsamp.
    # * 1 : periodic.

    # STDYSEL_REG   : 1-bit.
    # * 0 : last.
    # * 1 : zero.

    # PHRST_REG     : 1-bit.
    # * 0 : don't reset.
    # * 1 : reset.

    # WE_REG        : 1-bit.
    # * 0 : disable.
    # * 1 : enable.
    bindto = ['user.org:user:axis_signal_gen_v6_ctrl:1.0',
              'QICK:QICK:axis_signal_gen_v6_ctrl:1.0']

    def __init__(self, description, **kwargs):
        super().__init__(description)
        self.REGISTERS = {
            'freq_reg'      : 0,
            'phase_reg'     : 1,
            'addr_reg'      : 2,
            'gain_reg'      : 3,
            'nsamp_reg'     : 4,
            'outsel_reg'    : 5,
            'mode_reg'      : 6,
            'stdysel_reg'   : 7,
            'phrst_reg'     : 8,
            'we_reg'        : 9}

        # Default registers.
        self.we_reg = 0

    def configure(self, fs, gen):
        # Sampling frequency.
        self.fs = fs

        # Frequency resolution.
        self.df = fs/2**gen.B_DDS

        # Generator controlled by this block.
        self.gen = gen

    def add(self,
            freq    = 0         ,
            phase   = 0         ,
            addr    = 0         ,
            gain    = 0.99      ,
            nsamp   = 16*100    ,
            outsel  = "dds"     ,
            mode    = "periodic",
            stdysel = "zero"    ,
            phrst   = "no"      ):

        # Set registers.
        try:
            self.freq_reg       = int(np.round(freq/self.df))
            self.phase_reg      = phase
            self.addr_reg       = addr
            self.gain_reg       = int(gain*self.gen.MAXV)
            self.nsamp_reg      = int(np.round(nsamp/self.gen.SAMPS_PER_CLK))
            self.outsel_reg     = {"product": 0, "dds":1, "envelope":2}[outsel]
            self.mode_reg       = {"nsamp": 0, "periodic":1}[mode]
            self.stdysel_reg    = {"last": 0, "zero":1}[stdysel]
            self.phase_reg      = {"no": 0, "yes":1}[phrst]
        except Exception as e:
            raise type(e)('Did you call configure').with_traceback(e.__traceback__)

        logger.debug("{}".format(self.__class__.__name__))
        logger.debug(" * freq_reg      : {}".format(self.freq_reg))
        logger.debug(" * phase_reg     : {}".format(self.phase_reg))
        logger.debug(" * addr_reg      : {}".format(self.addr_reg))
        logger.debug(" * gain_reg      : {}".format(self.gain_reg))
        logger.debug(" * nsamp_reg     : {}".format(self.nsamp_reg))
        logger.debug(" * outsel_reg    : {}".format(self.outsel_reg))
        logger.debug(" * mode_reg      : {}".format(self.mode_reg))
        logger.debug(" * stdysel_reg   : {}".format(self.stdysel_reg))
        logger.debug(" * phase_reg     : {}".format(self.phase_reg))

        # Write fifo..
        self.we_reg = 1
        self.we_reg = 0

class AxisDdsMrSwitch(SocIP):
    # AXIS DDS MR SWITCH registers.
    # DDS_REAL_IMAG_REG
    # * 0 : real part.
    # * 1 : imaginary part.
    #
    bindto = ['user.org:user:axis_dds_mr_switch:1.0',
              'QICK:QICK:axis_dds_mr_switch:1.0']

    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)
        self.REGISTERS = {'dds_real_imag': 0}

        # Default registers.
        # dds_real_imag = 0  : take real part.
        self.dds_real_imag = 0

    def config(self, reg_):
        self.dds_real_imag = reg_

    def real(self):
        self.config(0)

    def imag(self):
        self.config(1)


class AxisSwitchV1(SocIP):
    bindto = ['user.org:user:axis_switch_v1:1.0',
              'QICK:QICK:axis_switch_v1:1.0']

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)
        self.REGISTERS = {'channel_reg': 0}

        # Number of bits.
        self.B = int(description['parameters']['B'])
        # Number of master interfaces.
        self.N = int(description['parameters']['N'])

    def sel(self, mst=0):
        if mst > self.N-1:
            print("%s: Master number %d does not exist in block." %
                  __class__.__name__)
            return

        # Select channel.
        self.channel_reg = mst

class AbsDacRfChain(ABC):
    @abstractmethod
    def enable_rf(self, att1, att2):
        pass

class AbsAdcRfChain(ABC):
    @abstractmethod
    def enable_rf(self, att):
        pass

class AbsDacDcChain(ABC):
    @abstractmethod
    def enable_dc(self):
        pass

class AbsAdcDcChain(ABC):
    @abstractmethod
    def enable_dc(self, gain):
        pass

    @abstractmethod
    def get_gain(self):
        pass

class AbsDacBalunChain(ABC):
    pass

class AbsAdcBalunChain(ABC):
    pass

class AdcRfChain111(AbsAdcRfChain):
    def __init__(self, ch, switches, attn_spi):
        # Channel number.
        self.ch = ch
        # Power switches.
        self.switches = switches

        # Attenuator.
        self.attn = [AttenuatorPE43705(attn_spi, ch, le=[0])]

    def enable_rf(self, att):
        # Turn on 5V power.
        self.switches["RF2IF5V_EN%d"%(self.ch)] = 1
        att = self.attn[0].set_att(att)
        return att

    def disable(self):
        # Turn off 5V power.
        self.switches["RF2IF5V_EN%d"%(self.ch)] = 0

class AdcDcChain111(AbsAdcDcChain):
    """Class to describe the ADC-DC channel chain.
    """
    # Constructor.
    def __init__(self, ch, switches, gain_spi):
        # Channel number.
        self.ch = ch

        # Power switches.
        self.switches = switches

        # V2 RF board has powerdown control, V1 does not
        self.powerdown = "RF2IF_PD%d"%(self.ch)
        if self.powerdown not in self.switches:
            self.powerdown = None

        self.gain = GainLMH6401(gain_spi, ch_en=ch)

        # Default to 0 dB gain.
        self.gain.set_gain(0)

    def get_gain(self):
        return self.gain.get_gain()

    def enable_dc(self, gain):
        if self.powerdown is not None:
            # Power up.
            self.switches[self.powerdown] = 0
        return self.gain.set_gain(gain)

    def disable(self):
        if self.powerdown is not None:
            # Power down.
            self.switches[self.powerdown] = 1
        else:
            raise RuntimeError("enable/disable only supported on ZCU111 V2, is this V1?")

class DacChain111(AbsDacRfChain, AbsDacDcChain):
    def __init__(self, ch, switches, attn_spi):
        # Channel number.
        self.ch = ch

        # RF input and power switches.
        self.switches = switches

        # V2 RF board has powerdown control, V1 does not
        self.dc_powerdown = "IF2RF_PD%d"%(self.ch)
        if self.dc_powerdown not in self.switches:
            self.dc_powerdown = None

        # Attenuators.
        self.attn = []
        self.attn.append(AttenuatorPE43705(attn_spi, ch, le=[1]))
        self.attn.append(AttenuatorPE43705(attn_spi, ch, le=[2]))

        # Initialize in off state.
        self.disable()

    # Switch selection.
    def rfsw_sel(self, sel="RF"):
        if sel == "RF":
            # Set logic one.
            # Select RF output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 1
            # Turn on 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 1
            # Power down DC amplifier.
            if self.dc_powerdown is not None:
                self.switches[self.dc_powerdown] = 1
        elif sel == "DC":
            # Select DC output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 0
            # Turn off 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 0
            # Power up DC amplifier.
            if self.dc_powerdown is not None:
                self.switches[self.dc_powerdown] = 0
        elif sel == "OFF":
            # Select RF output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 1
            # Turn off 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 0
            # Power down DC amplifier.
            if self.dc_powerdown is not None:
                self.switches[self.dc_powerdown] = 1
        else:
            raise RuntimeError("%s: selection %s not recoginzed." %
                  (self.__class__.__name__, sel))

    def enable_rf(self, att1, att2):
        self.rfsw_sel("RF")
        att1 = self.attn[0].set_att(att1)
        att2 = self.attn[1].set_att(att2)
        return att1, att2

    def enable_dc(self):
        self.rfsw_sel("DC")

    def disable(self):
        self.rfsw_sel("OFF")
        self.attn[0].set_att(31.75)
        self.attn[1].set_att(31.75)

class Chain216(ABC):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        self.soc = soc
        self.card = card
        self.global_ch = global_ch
        self.card_num = card_num
        self.card_ch = card_ch
        # TODO: log?
        #logger.debug("{}: ADC Channel = {}, Daughter Card = {}, Daughter Card DAC channel {}.".format(self.__class__.__name__, self.ch, self.rfboard_ch, self.local_ch))

class FilterChain(Chain216):
    def init_filter(self):
        # Enable this daughter card.
        with self.soc.board_sel.enable_context(self.card_num):
            # Program ADI_SPI_CONFIG_A register to 0x3C.
            self.filter.write_reg(reg="ADI_SPI_CONFIG_A", value=0x3C)

    def set_filter(self, fc=0, bw=None, ftype="lowpass"):
        # Enable this daughter card.
        with self.soc.board_sel.enable_context(self.card_num):
            # Set filter.
            self.filter.set_filter(fc=fc, bw=bw, ftype=ftype)

    def set_filter_raw(self, hpf=-1, lpf=-1):
        # Enable this daughter card.
        with self.soc.board_sel.enable_context(self.card_num):
            # Set filter.
            self.filter.set_filter_raw(hpf=hpf, lpf=lpf)

    def read_filter(self, reg=""):
        logger.debug("{}: reading register {}".format(self.__class__.__name__, reg))

        # Enable this daughter card.
        with self.soc.board_sel.enable_context(self.card_num):
            # Set filter.
            return self.filter.read_reg(reg=reg)

class DacRfChain216(AbsDacRfChain, FilterChain):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

        # there are two 5V power supplies for the four channels on this card
        self.powerup = "RFOUT5V0_EN%d"%((card_ch + 1) % 2)

        # Attenuators. There are 2 per DAC Channel.
        self.attn = []
        for i in range(2):
            addr = 2*card_ch+i
            self.attn.append(AttenuatorPE43705(soc.attn_spi, ch=addr, nch=1, le=[0]))
            logger.debug("{}: adding attenuator with address {}.".format(self.__class__.__name__, addr))

        # Filters. There is 1 per ADC Channel.
        self.filter = FilterADMV8818(soc.filter_spi, ch=card_ch)
        logger.debug("{}: adding filter with address {}.".format(self.__class__.__name__, card_ch))

        # Initialize filter.
        self.init_filter()

    def enable_rf(self, att1, att2):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerup] = 1
            att1 = self.attn[0].set_att(att1)
            att2 = self.attn[1].set_att(att2)
        return att1, att2

    def disable(self):
        """Because this daughter card doesn't have a per-channel power switch, we don't power it down.
        """
        # TODO: if needed, we can add methods to the daughter card class to toggle pairs of channels
        with self.soc.board_sel.enable_context(self.card_num):
            self.attn[0].set_att(31.75)
            self.attn[1].set_att(31.75)

class AdcRfChain216(AbsAdcRfChain, FilterChain):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

        self.powerup = "RFIN5V0CH%d_EN"%(card_ch)

        # Attenuators. There is 1 per ADC Channel.
        self.attn = []
        self.attn.append(AttenuatorPE43705(soc.attn_spi, ch=card_ch, nch=1, le=[0]))
        logger.debug("{}: adding attenuator with address {}.".format(self.__class__.__name__, card_ch))

        # Filters. There is 1 per ADC Channel.
        self.filter = FilterADMV8818(soc.filter_spi, ch=card_ch)
        logger.debug("{}: adding filter with address {}.".format(self.__class__.__name__, card_ch))

        # Initialize filter.
        self.init_filter()

    def enable_rf(self, att):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerup] = 1
            # Set attenuator.
            att = self.attn[0].set_att(att)
        return att

    def disable(self):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerup] = 0
            self.attn[0].set_att(31.75)

class DacDcChain216(AbsDacDcChain, Chain216):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

        self.powerdown = "PD%d"%(card_ch)

    def enable_dc(self):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerdown] = 0

    def disable(self):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerdown] = 1

class AdcDcChain216(AbsAdcDcChain, Chain216):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

        self.powerdown = "PD%d"%(card_ch)
        self.gain = GainLMH6401(soc.filter_spi, ch_en=card_ch)

    def enable_dc(self, gain):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerdown] = 0
            return self.gain.set_gain(gain)

    def disable(self):
        with self.soc.board_sel.enable_context(self.card_num):
            self.card.switch_control[self.powerdown] = 1

    def get_gain(self):
        with self.soc.board_sel.enable_context(self.card_num):
            return self.gain.get_gain()

class DacBalunChain216(AbsDacBalunChain, Chain216):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

class AdcBalunChain216(AbsAdcBalunChain, Chain216):
    def __init__(self, soc, card, global_ch, card_num, card_ch):
        super().__init__(soc, card, global_ch, card_num, card_ch)

class DaughterCard216(ABC):
    NCH = None # channels per daughter card
    CARDNUM_OFFSET = None # DAC cards are 0-3, ADC cards are 4-7
    CHAIN_CLASS = None # signal chain class to instantiate for each channel
    GPIO_OUTPUTS = [None]*4 # nets controlled by the daughter card's GPIO chip
    NAME = '' # name for this card type
    def __init__(self, card_num, soc, gpio):
        self.card_num = card_num
        self.soc = soc
        self.switch_control = SwitchControl(self.soc.filter_spi)
        self.switch_control.add_MCP(gpio, self.GPIO_OUTPUTS)
        self.chains = []
        for card_ch in range(self.NCH):
            global_ch = self.NCH*self.card_num + card_ch
            if self.CHAIN_CLASS is not None:
                self.chains.append(self.CHAIN_CLASS(soc=soc, card=self, global_ch=global_ch, card_num=self.CARDNUM_OFFSET+card_num, card_ch=card_ch))
            else:
                # TODO: do something more useful
                self.chains.append(global_ch)

    def disable_all(self):
        for chain in self.chains:
            chain.disable()

class DacRfCard216(DaughterCard216):
    NCH = 4
    CARDNUM_OFFSET = 0
    CHAIN_CLASS = DacRfChain216
    # disable all outputs by default
    GPIO_OUTPUTS = [("RFOUT5V0_EN%d"%(i), 0) for i in range(2)] + [None]*2
    NAME = 'RF Out'
    def disable_all(self):
        for i in range(2):
            self.switch_control["RFIN5V0CH%d_EN"%(i)] = 0

class DacDcCard216(DaughterCard216):
    NCH = 4
    CARDNUM_OFFSET = 0
    CHAIN_CLASS = DacDcChain216
    # power-on all outputs by default, because in power-down state the LMH5401 just lets through the DAC common-mode voltage
    GPIO_OUTPUTS = [("PD%d"%(i), 0) for i in range(4)]
    NAME = 'DC Out'

class DacBalunCard216(DaughterCard216):
    NCH = 4
    CARDNUM_OFFSET = 0
    CHAIN_CLASS = DacBalunChain216
    GPIO_OUTPUTS = [None]*4
    NAME = 'Balun Out'

class AdcRfCard216(DaughterCard216):
    NCH = 2
    CARDNUM_OFFSET = 4
    CHAIN_CLASS = AdcRfChain216
    # disable all outputs by default
    GPIO_OUTPUTS = [("RFIN5V0CH%d_EN"%(i), 0) for i in range(2)] + [None]*2
    NAME = 'RF In'

class AdcDcCard216(DaughterCard216):
    NCH = 2
    CARDNUM_OFFSET = 4
    CHAIN_CLASS = AdcDcChain216
    # power-down all outputs by default
    GPIO_OUTPUTS = [("PD%d"%(i), 1) for i in range(2)] + [None]*2
    NAME = 'DC In'

class AdcBalunCard216(DaughterCard216):
    NCH = 2
    CARDNUM_OFFSET = 4
    CHAIN_CLASS = AdcBalunChain216
    GPIO_OUTPUTS = [None]*4
    NAME = 'Balun In'

class BoardSelection:
    """
    This class is used to enable one daughter card on the RF Board for the ZCU216, V1.
    """

    def __init__(self, gpio_ip):
        self.gpio = gpio_ip.channel1

    def enable(self, board_id = 0):
        # There are 8 boards: 3 bits for selection, 1 bit for active/inactive.
        # Bits:
        # |-----|-------|-------|-------|
        # | B3  | B2    | B1    | B0    |
        # |-----|-------|-------|-------|
        # | E/D | SEL 2 | SEL 1 | SEL 0 |
        # |-----|-------|-------|-------|
        #
        # E/D:
        # * 0 : disable.
        # * 1 : enable (selected board).
        val_ = (1 << 3) + board_id
        self.gpio.write(val_, 0xf)

        logger.debug("{}: setting vaue = 0x{:01X}".format(self.__class__.__name__,val_))

    def disable(self):
        # E/D bit to 0.
        self.gpio.write(0, 0xf)

    @contextmanager
    def enable_context(self, board_id):
        """Use with "with" to temporarily enable a card inside a code block.
        """
        try:
            self.enable(board_id)
            yield None
        finally:
            self.disable()

class RFQickSocMixin(ABC):
    """
    Use this mixin class (or a subclass) in combination with QickSoc (or a subclass) to enable RF board support.
    """
    HAS_LO = True
    def __init__(self, bitfile, clk_output=None, **kwargs):
        """
        A bitfile must always be provided, since the default bitstream will not work with the RF board.

        The ZCU111 RF board takes its LO reference from the ZCU111 clock output.
        So if clk_output is None, the clocks will be re-initialized every time.
        This ensures that the LO output to the RF board is enabled.
        """
        if clk_output is None and self.HAS_LO:
            clk_output = True
        super().__init__(bitfile=bitfile, clk_output=clk_output, **kwargs)

        # ADC signal chains.
        self.adc_chains = []

        # DAC signal chains.
        self.dac_chains = []

        # Bias channels.
        self.biases = []

        self._rfb_config()

    @abstractmethod
    def _rfb_config(self):
        """Detects and configures RF board components.
        """
        ...

    def rfb_set_gen_rf(self, gen_ch, att1, att2):
        """Enable and configure an RF-board output channel for RF output.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        att1 : float
            Attenuation for first stage (0 through 31.75 dB in 0.25-dB increments)
        att2 : float
            Attenuation for second stage (0 through 31.75 dB in 0.25-dB increments)

        Returns
        -------
        float
            actual (rounded) att1 value that was set
        float
            actual (rounded) att2 value that was set
        """
        rfb_ch = self.gens[gen_ch].rfb_ch
        if not isinstance(rfb_ch, AbsDacRfChain):
            raise RuntimeError("generator %d is not connected to an RF signal chain" % (gen_ch))
        return rfb_ch.enable_rf(att1, att2)

    def rfb_set_gen_dc(self, gen_ch):
        """Enable and configure an RF-board output channel for DC output.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        """
        rfb_ch = self.gens[gen_ch].rfb_ch
        if not isinstance(rfb_ch, AbsDacDcChain):
            raise RuntimeError("generator %d is not connected to an RF signal chain" % (gen_ch))
        rfb_ch.enable_dc()

    def rfb_set_dac_rf(self, dac_port, att1, att2):
        """Enable and configure a QICK box or RF board DAC port for RF output.

        Parameters
        ----------
        dac_port : int
            QICK box or RF board DAC port number (0-15 for ZCU216, 0-7 for ZCU111)
        att1 : float
            Attenuation for first stage (0 through 31.75 dB in 0.25-dB increments)
        att2 : float
            Attenuation for second stage (0 through 31.75 dB in 0.25-dB increments)

        Returns
        -------
        float
            actual (rounded) att1 value that was set
        float
            actual (rounded) att2 value that was set
        """
        rfb_ch = self.dac_chains[dac_port]
        if not isinstance(rfb_ch, AbsDacRfChain):
            raise RuntimeError("DAC port %d does not have an RF signal chain" % (dac_port))
        return rfb_ch.enable_rf(att1, att2)

    def rfb_set_dac_dc(self, dac_port):
        """Enable and configure a QICK box or RF board DAC port for DC output.

        Parameters
        ----------
        dac_port : int
            QICK box or RF board DAC port number (0-15 for ZCU216, 0-7 for ZCU111)
        """
        rfb_ch = self.dac_chains[dac_port]
        if not isinstance(rfb_ch, AbsDacDcChain):
            raise RuntimeError("DAC port %d does not have a DC signal chain" % (dac_port))
        rfb_ch.enable_dc()

    def rfb_set_ro_rf(self, ro_ch, att):
        """Enable and configure an RF-board RF input channel.
        Will fail if this is not an RF input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'avg_bufs' list)
        att : float
            Attenuation (0 through 31.75 dB in 0.25-dB increments)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.avg_bufs[ro_ch].rfb_ch
        if not isinstance(rfb_ch, AbsAdcRfChain):
            raise RuntimeError("readout %d is not connected to an RF signal chain" % (ro_ch))
        return rfb_ch.enable_rf(att)

    def rfb_set_ro_dc(self, ro_ch, gain):
        """Enable and configure an RF-board DC input channel.
        Will fail if this is not a DC input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'readouts' list)
        gain : float
            Gain (-6 through 26 dB in 1-dB increments)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.avg_bufs[ro_ch].rfb_ch
        if not isinstance(rfb_ch, AbsAdcDcChain):
            raise RuntimeError("readout %d is not connected to a DC signal chain" % (ro_ch))
        return rfb_ch.enable_dc(gain)

    def rfb_set_adc_rf(self, adc_port, att):
        """Enable and configure an RF-board RF input channel.
        Will fail if this is not an RF input.

        Parameters
        ----------
        adc_port : int
            QICK box or RF board ADC port number (0-7 for ZCU216, 0-3 for ZCU111)
        att : float
            Attenuation (0 through 31.75 dB in 0.25-dB increments)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.adc_chains[adc_port]
        if not isinstance(rfb_ch, AbsAdcRfChain):
            raise RuntimeError("ADC port %d does not have a RF signal chain" % (adc_port))
        return rfb_ch.enable_rf(att)

    def rfb_set_adc_dc(self, adc_port, gain):
        """Enable and configure an RF-board DC input channel.
        Will fail if this is not a DC input.

        Parameters
        ----------
        adc_port : int
            QICK box or RF board ADC port number (0-7 for ZCU216, 4-7 for ZCU111)
        gain : float
            Gain (-6 through 26 dB in 1-dB increments)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.adc_chains[adc_port]
        if not isinstance(rfb_ch, AbsAdcDcChain):
            raise RuntimeError("ADC port %d does not have a DC signal chain" % (adc_port))
        return rfb_ch.enable_dc(gain)

    def rfb_set_bias(self, bias_ch, v):
        """Set a voltage on an RF-board bias output.

        Parameters
        ----------
        bias_ch : int
            Channel number (0-7)
        v : float
            Voltage (-10 to 10 V)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        return self.biases[bias_ch].set_volt(v)

    def rfb_get_bias(self, bias_ch):
        """Read the voltage setpoint on an RF-board bias output.

        Parameters
        ----------
        bias_ch : int
            Channel number (0-7)

        Returns
        -------
        float
            setpoint, in volts
        """
        return self.biases[bias_ch].get_volt()

class RFQickSoc111V1(RFQickSocMixin, QickSoc):
    def _init_switches(self, spi):
        self.switches = SwitchControl(spi)
        # ADC power
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=0, dev_addr=0),
                outputs=[("RF2IF5V_EN"+str(i), 0) for i in range(4)]
                + [None]*4)
        # DAC power
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=1, dev_addr=0),
                outputs=[("IF2RF5V_EN"+str(i), 0) for i in range(8)])
        # DAC RF/DC switch
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=2, dev_addr=0),
                outputs=[("CH%d_PE42020_CTL"%(i), 1) for i in range(8)])

    def _init_lo(self, spi):
        self.lo = [LoSynthADF4372(spi, le=[i]) for i in range(2)]

    def _rfb_config(self):
        """
        Configure the SPI interfaces to the RF board.
        """
        # SPI used for Attenuators.
        self.attn_spi.config(lsb="lsb")

        # SPI used for Power, Switch and Fan.
        self.psf_spi.config(lsb="msb")

        # SPI used for the LO.
        self.lo_spi.config(lsb="msb")

        # SPI used for DAC BIAS.
        self.dac_bias_spi.config(lsb="msb", cpha="invert")

        # GPIO outputs:
        # ADC/DAC power enable, DAC RF input switch.
        # Initialize everything with power off.
        self._init_switches(self.psf_spi)

        # DAC BIAS.
        self.biases = [BiasAD5781(self.dac_bias_spi, ch_en=ii) for ii in range(8)]

        # ADC channels.
        self.adc_chains = [AdcRfChain111(ii, self.switches, self.attn_spi) for ii in range(4)] + [AdcDcChain111(ii, self.switches, self.psf_spi) for ii in range(4,8)]

        # DAC channels.
        self.dac_chains = [DacChain111(ii, self.switches, self.attn_spi) for ii in range(8)]

        # LO Synthesizers.
        self._init_lo(self.lo_spi)

        # Link gens/readouts to the corresponding RF board channels.
        for gen in self.gens:
            tile, block = [int(a) for a in gen['dac']]
            gen.rfb_ch = self.dac_chains[4*tile + block]
        for avg_buf in self.avg_bufs:
            tile, block = [int(a) for a in avg_buf.readout['adc']]
            avg_buf.rfb_ch = self.adc_chains[2*tile + block]

    def rfb_set_lo(self, f):
        """Set both of the RF-board local oscillators to the same frequency.

        Tile 0 DACs and all RF ADCs are connected to LO[0], tile 1 DACs are connected to LO[1].

        Parameters
        ----------
        f : float
            Frequency (4000-8000 MHz)
        """
        for lo in self.lo:
            lo.set_freq(f)

class RFQickSoc111V2(RFQickSoc111V1):
    def _init_switches(self, spi):
        self.switches = SwitchControl(spi)
        # ADC power/power-down
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=0, dev_addr=0),
                outputs=[("RF2IF5V_EN"+str(i), 0) for i in range(4)]
                + [("RF2IF_PD"+str(i), 1) for i in range(4, 8)])
        # DAC power-down
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=1, dev_addr=1),
                outputs=[("IF2RF_PD"+str(i), 1) for i in range(8)])
        # DAC power
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=1, dev_addr=0),
                outputs=[("IF2RF5V_EN"+str(i), 0) for i in range(8)])
        # DAC RF/DC switch
        self.switches.add_MCP(GpioMCP23S08(spi, ch_en=2, dev_addr=0),
                outputs=[("CH%d_PE42020_CTL"%(i), 1) for i in range(8)])

    def _init_lo(self, spi):
        self.lo = [LoSynthLMX2594(spi, i) for i in range(3)]

        # Link RF channels to LOs.
        for adc in self.adc_chains[:4]: adc.lo = self.lo[0]
        for dac in self.dac_chains[:4]: dac.lo = self.lo[1]
        for dac in self.dac_chains[4:]: dac.lo = self.lo[2]

    def rfb_set_lo(self, f, ch=None, verbose=False):
        """Set RF-board local oscillators.

        LO[0]: all RF ADCs
        LO[1]: RF DACs 0-3
        LO[2]: RF DACs 4-7

        Parameters
        ----------
        f : float
            Frequency (4000-8000 MHz)
        ch : int
            LO to configure (None=all)
        verbose : bool
            Print freq and lock info.
        """
        if ch is not None:
            self.lo[ch].set_freq(f, verbose=verbose)
        else:
            for lo in self.lo:
                lo.set_freq(f, verbose=verbose)

    def rfb_get_lo(self, gen_ch=None, ro_ch=None):
        """Get local oscillator frequency for a DAC or ADC channel.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        ro_ch : int
            ADC channel (index in 'readouts' list)
        """
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch")
        if gen_ch is not None:
            return self.gens[gen_ch].rfb.lo.freq
        if ro_ch is not None:
            return self.avg_bufs[ro_ch].rfb.lo.freq
        raise RuntimeError("must specify gen_ch or ro_ch")

# define the old name, for compatibility
RFQickSocV2 = RFQickSoc111V2

class RFQickSoc216V1Mixin(RFQickSocMixin):
    HAS_LO = False

    def _rfb_config(self):
        """
        Configure the GPIO/SPI interfaces to the RF board.
        """

        # GPIO for Board Selection.
        if hasattr(self, 'rfb_control'):
            self.board_sel = BoardSelection(self.rfb_control.brd_sel_gpio)
            self.attn_spi = self.rfb_control.attn_spi
            self.filter_spi = self.rfb_control.filter_spi
            self.bias_spi = self.rfb_control.bias_spi
            self.bias_gpio = self.rfb_control.bias_gpio
        else:
            self.board_sel = BoardSelection(self.brd_sel_gpio)

        # SPI used for Attenuators.
        self.attn_spi.config(lsb="lsb")

        # SPI used for Filter.
        self.filter_spi.config(lsb="msb")

        # SPI used for Bias.
        self.bias_spi.config(lsb="msb", cpha="invert")

        # Bias channels.
        for ii in range(8):
            self.biases.append(BiasDAC11001(self.bias_spi, ch_en=ii))

        self.rfb_enable_bias()

        # DAC daughter cards are the lower 4.
        self.dac_cards = []
        for card_num in range(4):
            with self.board_sel.enable_context(board_id=card_num):
                gpio = GpioMCP23S08(self.filter_spi, ch_en=4, dev_addr=0, iodir=0xf0)
                card_id = gpio.read_reg("GPIO_REG") >> 4
                logger.debug("ADC card %d: ID %d"%(card_num, card_id))
                if card_id == 1:
                    card = DacDcCard216(card_num, self, gpio)
                elif card_id == 3:
                    card = DacRfCard216(card_num, self, gpio)
                elif card_id == 6:
                    card = DacBalunCard216(card_num, self, gpio)
                else:
                    card = None
            if card is None:
                self.dac_chains.extend([None]*4)
            else:
                self.dac_chains.extend(card.chains)
            self.dac_cards.append(card)

        # ADC daughter cards are the upper 4.
        self.adc_cards = []
        for card_num in range(4):
            with self.board_sel.enable_context(board_id=card_num+4):
                gpio = GpioMCP23S08(self.filter_spi, ch_en=2, dev_addr=0, iodir=0xf0)
                card_id = gpio.read_reg("GPIO_REG") >> 4
                logger.debug("DAC card %d: ID %d"%(card_num, card_id))
                # TODO: recognize 15 as empty or balun, raise error on unrecognized
                if card_id == 0:
                    # note: first version of DC-in had pinout bug that broke SPI reads
                    #if card_id == 0 or card_id == 15:
                    card = AdcDcCard216(card_num, self, gpio)
                elif card_id == 2:
                    card = AdcRfCard216(card_num, self, gpio)
                elif card_id == 5:
                    card = AdcBalunCard216(card_num, self, gpio)
                else:
                    card = None
            if card is None:
                self.adc_chains.extend([None]*2)
            else:
                self.adc_chains.extend(card.chains)
            self.adc_cards.append(card)

        # Link gens/readouts to the corresponding RF board channels.
        # Each DAC tile maps to a daughter card, in order.
        for gen in self.gens:
            tile, block = [int(a) for a in gen['dac']]
            card = self.dac_cards[tile]
            if card is not None:
                gen.rfb_ch = card.chains[block]
            else:
                gen.rfb_ch = None
        # Each of the middle two ADC tiles (225+226) maps to a pair of daughter cards.
        for avg_buf in self.avg_bufs:
            tile, block = [int(a) for a in avg_buf.readout['adc']]
            card = self.adc_cards[2*(tile-1) + block//2]
            chain_num = block % 2
            if card is not None:
                avg_buf.rfb_ch = card.chains[chain_num]
            else:
                avg_buf.rfb_ch = None

        # DC-in ADCs need to be restarted after initial power-up
        for tile in self['rf']['tiles']['adc']:
            self.rf.restart_adc_tile(tile)
        # now, clear any ADC interrupts
        self.clear_interrupts(error_on_interrupt=False, error_on_persist=False, warn=False)

        # add a list of detected cards to the configuration printout
        self['extra_description'].append("\nQICK box daughter cards detected:")
        for slot, card in enumerate(self.adc_cards):
            if card is None:
                self['extra_description'].append(f"\tADC slot {slot}: No card detected")
            else:
                channels = [chain.global_ch for chain in card.chains]
                self['extra_description'].append(f"\tADC slot {slot}: {card.NAME} card has ports {channels}")
        for slot, card in enumerate(self.dac_cards):
            if card is None:
                self['extra_description'].append(f"\tDAC slot {slot}: No card detected")
            else:
                channels = [chain.global_ch for chain in card.chains]
                self['extra_description'].append(f"\tDAC slot {slot}: {card.NAME} card has ports {channels}")


    def rfb_enable_bias(self):
        """Enable all eight main-board bias outputs (by turning on DAC_BIAS_SWEN).

        This is normally run during board initialization, so you should not need to run it yourself.
        """

        self.bias_gpio.channel1.write(1, 0x1)

    def rfb_disable_bias(self):
        """Disable all eight main-board bias outputs (by turning off DAC_BIAS_SWEN).
        """

        self.bias_gpio.channel1.write(0, 0x1)

    def rfb_set_gen_filter(self, gen_ch, fc, bw=1000, ftype='bandpass'):
        """Set the programmable analog filter of the QICK box DAC port connected to a specified generator.

        Parameters
        ----------
        gen_ch : int
            generator channel (index in 'gens' list)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        rfb_ch = self.gens[gen_ch].rfb_ch
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("generator %d is not connected to an RF signal chain" % (gen_ch))
        rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)

    def rfb_set_ro_filter(self, ro_ch, fc, bw=1000, ftype='bandpass'):
        """Set the programmable analog filter of the QICK box ADC port connected to a specified readout channel.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'avg_bufs' list)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        rfb_ch = self.avg_bufs[ro_ch].rfb_ch
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("readout %d is not connected to an RF signal chain" % (ro_ch))
        rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)
        self.clear_interrupts(error_on_interrupt=False, error_on_persist=False, warn=False)

    def rfb_set_dac_filter(self, dac_port, fc, bw=1000, ftype='bandpass'):
        """Set the programmable analog filter of the specified QICK box DAC port.

        Parameters
        ----------
        dac_port : int
            QICK box DAC port number (0-15)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        rfb_ch = self.dac_chains[dac_port]
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("DAC port %d does not have a RF signal chain" % (dac_port))
        rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)

    def rfb_set_adc_filter(self, adc_port, fc, bw=1000, ftype='bandpass'):
        """Set the programmable analog filter of the specified QICK box ADC port.

        Parameters
        ----------
        adc_port : int
            QICK box ADC port number (0-7)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        rfb_ch = self.adc_chains[adc_port]
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("ADC port %d does not have a RF signal chain" % (adc_port))
        rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)
        self.clear_interrupts(error_on_interrupt=False, error_on_persist=False, warn=False)

    def rfb_get_filter_steps(self, section, f, n=11):
        """Get the N filter steps with cutoffs closest to the requested frequency.
        This is based on the information in the ADMV8818 datasheet.
        The "bypass" setting (step=-1) is not checked; if you want a low-pass >18850 MHz or a high-pass <1750 MHz, you may want to use bypass mode instead.

        The intended use of this method is to get a list of candidate steps that you can test, and use the best one.

        Parameters
        ----------
        section : str
            "HPF" or "LPF"
        f : float
            Desired cutoff frequency [MHz]
        n : int
            Number of filter steps to find

        Returns
        -------
        list of int
            Filter steps, in increasing order of frequency
        """
        return FilterADMV8818.freq2steps(section, f, n)

    def rfb_set_dac_filter_raw(self, dac_port, hpf=-1, lpf=-1):
        """Set the programmable analog filter of the specified QICK box DAC port.
        Filter cutoffs are specified in terms of filter steps.

        Parameters
        ----------
        dac_port : int
            QICK box DAC port number (0-15)
        hpf : int
            High-pass filter setting. -1 to bypass, 0 through 63 to enable, with 3 dB cutoff from 1.75 to 19.90 GHz.
        lpf : int
            Low-pass filter setting. -1 to bypass, 0 through 63 to enable, with 3 dB cutoff from 2.05 to 18.85 GHz.
        """
        rfb_ch = self.dac_chains[dac_port]
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("DAC port %d does not have a RF signal chain" % (dac_port))
        rfb_ch.set_filter_raw(hpf, lpf)

    def rfb_set_adc_filter_raw(self, adc_port, hpf=-1, lpf=-1):
        """Set the programmable analog filter of the specified QICK box ADC port.
        Filter cutoffs are specified in terms of filter steps.

        Parameters
        ----------
        adc_port : int
            QICK box ADC port number (0-7)
        hpf : int
            High-pass filter setting. -1 to bypass, 0 through 63 to enable, with 3 dB cutoff from 1.75 to 19.90 GHz.
        lpf : int
            Low-pass filter setting. -1 to bypass, 0 through 63 to enable, with 3 dB cutoff from 2.05 to 18.85 GHz.
        """
        rfb_ch = self.adc_chains[adc_port]
        if not isinstance(rfb_ch, FilterChain):
            raise RuntimeError("ADC port %d does not have a RF signal chain" % (adc_port))
        rfb_ch.set_filter_raw(hpf, lpf)
        self.clear_interrupts(error_on_interrupt=False, error_on_persist=False, warn=False)

    def rfb_set_rfadc_attenuator(self, adc_port, att):
        """Set the programmable attenuator of the RFSoC RF-ADC connected to the specified QICK box ADC port.

        Parameters
        ----------
        adc_port : int
            QICK box ADC port number (0-7)
        att : float
            Attenuation value (0 through 27 dB in 1-dB increments)
        """
        adcname = "%d%d"%(adc_port//4 + 1, adc_port%4)
        val = self.set_adc_attenuator(adcname, att)
        self.clear_interrupts(error_on_interrupt=False, error_on_persist=False, warn=False)
        return val

    def prepare_round(self):
        # if an ADC is already in interrupt state, don't run the program
        self.clear_interrupts(error_on_interrupt=True)

    def cleanup_round(self):
        self.clear_interrupts()

class RFQickSoc216V1(RFQickSoc216V1Mixin, QickSoc):
    pass
