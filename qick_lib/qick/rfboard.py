import os
from .qick import QickSoc
from .ip import SocIP
from .qick_asm import QickConfig
from pynq.buffer import allocate
import xrfclk
import numpy as np
import time
from contextlib import contextmanager, suppress
from abc import ABC, abstractmethod
import logging
from qick.ipq_pynq_utils.ipq_pynq_utils import clock_models

logger = logging.getLogger(__name__)

class AxisSignalGenV3(SocIP):
    # AXIS Table Registers.
    # START_ADDR_REG
    #
    # WE_REG
    # * 0 : disable writes.
    # * 1 : enable writes.
    #
    bindto = ['user.org:user:axis_signal_gen_v3:1.0']

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
    bindto = ['user.org:user:axis_signal_gen_v3_ctrl:1.0']

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
    bindto = ['user.org:user:axis_signal_gen_v6_ctrl:1.0']

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
            self.nsamp_reg      = int(np.round(nsamp/self.gen.NDDS))
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
    bindto = ['user.org:user:axis_dds_mr_switch:1.0']

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
    bindto = ['user.org:user:axis_switch_v1:1.0']

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


class spi(SocIP):

    bindto = ['xilinx.com:ip:axi_quad_spi:3.2']
    SPI_REGLIST = ['DGIER', 'IPISR', 'IPIER', 'SRR', 'SPICR', 'SPISR', 'SPI_DTR', 'SPI_DRR', 'SPI_SSR', 'SPI_TXFIFO_OR', 'SPI_RXFIFO_OR']

    #
    # SPI registers - See Xilinx PG153 AXI Quad SPI for discriptions
    #
    #DGIER = 0x1C          # 0x1C - RW - SPI Device Global Interrupt Enable Register
    #IPISR = 0x20          # 0x20 - RW - SPI IP Interrupt Status Register
    #IPIER = 0x28          # 0x28 - RW - SPI IP Interrupt Enable Register
    #SRR = 0x40            # 0x40 - WO - SPI Software Reset Reg
    #SPICR = 0x60          # 0x60 - RW - SPI Control Register
    #SPISR = 0x64          # 0x64 - RO - SPI Status Register
    #SPI_DTR = 0x68        # 0x68 - WO - SPI Data Transmit Register
    #SPI_DRR = 0x6C        # 0x6C - RO - SPI Data Receive Register
    #SPI_SSR = 0x70        # 0x70 - RW - SPI Slave Select Register
    #SPI_TXFIFO_OR = 0x74  # 0x74 - RW - SPI Transmit FIFO Occupancy Register
    #SPI_RXFIFO_OR = 0x78  # 0x78 - RO - SPI Receive FIFO Occupancy Register

    def __init__(self, description, **kwargs):
        super().__init__(description)
        # Data width.
        self.data_width = int(description['parameters']['C_NUM_TRANSFER_BITS'])

        # Soft reset SPI.
        self.rst()

        # De-assert slave select
        self.SPI_SSR = 0

    def __setattr__(self, a, v):
        if a in self.SPI_REGLIST:
            setattr(self.register_map, a, v)
        else:
            super().__setattr__(a, v)

    def __getattr__(self, a):
        if a in self.SPI_REGLIST:
            return getattr(self.register_map, a)
        else:
            return super().__getattribute__(a)

    def rst(self):
        self.SRR = 0xA

    # SPI Control Register:
    # Bit 9 : LSB/MSB selection.
    # -> 0 : MSB first
    # -> 1 : LSB first
    #
    # Bit 8 : Master Transaction Inhibit.
    # -> 0 : Master Transaction Enabled.
    # -> 1 : Master Transaction Disabled.
    #
    # Bit 7 : Manual Slave Select Assertion.
    # -> 0 : Slave select asserted by master core logic.
    # -> 1 : Slave select follows data in SSR.
    #
    # Bit 6 : RX FIFO Reset.
    # -> 0 : Normal operation.
    # -> 1 : Reset RX FIFO.
    #
    # Bit 5 : TX FIFO Reset.
    # -> 0 : Normal operation.
    # -> 1 : Reset RX FIFO.
    #
    # Bit 4 : Clock Phase.
    # -> 0 :
    # -> 1 :
    #
    # Bit 3 : Clock Polarity.
    # -> 0 : Active-High clock. SCK idles low.
    # -> 1 : Active-Low clock. SCK idles high.
    #
    # Bit 2 : Master mode.
    # -> 0 : Slave configuration.
    # -> 1 : Master configuration.
    #
    # Bit 1 : SPI system enable.
    # -> 0 : SPI disabled. Outputs 3-state.
    # -> 1 : SPI enabled.
    #
    # Bit 0 : Local loopback mode.
    # -> 0 : Normal operation.
    # -> 1 : Loopback mode.
    def config(self,
               lsb="lsb",
               msttran="enable",
               ssmode="ssr",
               rxfifo="rst",
               txfifo="rst",
               cpha="",
               cpol="high",
               mst="master",
               en="enable",
               loopback="no"):

        # LSB/MSB.
        self.register_map.SPICR.LSB_First = {"lsb":1, "msb":0}[lsb]

        # Master transaction inhibit.
        self.register_map.SPICR.Master_Transaction_Inhibit = {"disable":1, "enable":0}[msttran]

        # Manual slave select.
        self.register_map.SPICR.Manual_Slave_Select_Assertion_Enable = {"ssr":1, "auto":0}[ssmode]

        # RX FIFO.
        self.register_map.SPICR.RX_FIFO_Reset = {"rst":1, "":0}[rxfifo]

        # TX FIFO.
        self.register_map.SPICR.TX_FIFO_Reset = {"rst":1, "":0}[txfifo]

        # CPHA.
        self.register_map.SPICR.CPHA = {"invert":1, "":0}[cpha]

        # CPOL
        self.register_map.SPICR.CPOL = {"low":1, "high":0}[cpol]

        # Master mode.
        self.register_map.SPICR.Master = {"master":1, "slave":0}[mst]

        # SPI enable.
        self.register_map.SPICR.SPE = {"enable":1, "disable":0}[en]

        # Loopback
        self.register_map.SPICR.LOOP = {"yes":1, "no":0}[loopback]

    # Enable function.
    def en_level(self, nch=4, chlist=[0], en_l="high"):
        """
        chlist: list of bits to enable
        en_l: enable level
        "high": ignore nch, enabled bits are set high
        "low": nch is total length, enabled bits are set low
        """
        ch_en = 0
        if en_l == "high":
            for i in range(len(chlist)):
                ch_en |= (1 << chlist[i])
        elif en_l == "low":
            ch_en = 2**nch - 1
            for i in range(len(chlist)):
                ch_en &= ~(1 << chlist[i])

        return ch_en

    # Send function.
    def send_m(self, data, ch_en, cs_t="pulse"):
        """
        The data must be formatted in bytes, regardless of the data width of the SPI IP.
        For data width 16 or 32, the bytes will be packed in little-endian order.
        """
        if not isinstance(data, bytes):
            raise RuntimeError("data is not a bytes object: ", data)
        if self.data_width == 16:
            data = np.frombuffer(data, dtype=np.dtype('H')) # uint16
        elif self.data_width == 32:
            data = np.frombuffer(data, dtype=np.dtype('I')) # uint32

        # Manually assert channels.
        ch_en_temp = self.SPI_SSR.Selected_Slave

        # Standard CS at the beginning of transaction.
        if cs_t != "pulse":
            self.SPI_SSR = ch_en

        # Send data.
        for word in data:
            # Send data.
            self.SPI_DTR = word

            # LE pulse at the end.
            if cs_t == "pulse":
                # Write SSR to enable channels.
                self.SPI_SSR = ch_en

                # Write SSR to previous value.
                self.SPI_SSR = ch_en_temp

        # Bring CS to default value.
        if cs_t != "pulse":
            self.SPI_SSR = ch_en_temp

    # Receive function.
    def receive(self):
        """
        The returned data will be formatted in bytes, regardless of the data width of the SPI IP.
        For data width 16 or 32, the bytes will be unpacked in little-endian order.
        """
        # Fifo is empty
        if self.SPISR.RX_Empty==1:
            return bytes()
        else:
            # Get number of samples on fifo.
            nr = self.SPI_RXFIFO_OR.Occupancy_Value + 1
            data_r = [self.SPI_DRR.RX_Data for i in range(nr)]
            if self.data_width == 8:
                return bytes(data_r)
            elif self.data_width == 16:
                return np.array(data_r).astype(np.dtype('H')).tobytes() # uint16
            elif self.data_width == 32:
                return np.array(data_r).astype(np.dtype('I')).tobytes() # uint32

    # Send/Receive.
    def send_receive_m(self, data, ch_en, cs_t="pulse"):
        """
        data: list of bytes to send
        ch_en: destination address
        """
        self.send_m(data, ch_en, cs_t)
        data_r = self.receive()

        return data_r

class BiasAD5781:
    """Bias DAC chip AD5781.
    """
    # Commands.
    cmd_wr = 0x0
    cmd_rd = 0x1

    # Negative/Positive voltage references.
    VREFN = -10
    VREFP = 10

    # Bits.
    B = 18

    # Registers.
    REGS = {'DAC_REG': 0x01,
            'CTRL_REG': 0x02,
            'CLEAR_REG': 0x03,
            'SOFT_REG': 0x04}

    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # SPI.
        self.ch_en = ch_en
        self.cs_t = cs_t
        self.spi = spi_ip
        self.spi.SPI_SSR = 0xff

        logger.debug("{}: DAC Channel = {}.".format(self.__class__.__name__, self.ch_en))

        # Initialize control register.
        self.write_reg(reg="CTRL_REG", val=0x312)

        # Initialize to 0 volts.
        self.set_volt(0)

    def _reg2volt(self, reg):
        reg >>= 2
        return reg*(self.VREFP - self.VREFN)/(2**self.B - 1) + self.VREFN

    # Compute register value for voltage setting.
    def _volt2reg(self, volt):
        if volt < self.VREFN or volt > self.VREFP:
            raise RuntimeError("%s: %d V out of range [%f, %f]" % (self.__class__.__name__, volt, self.VREFN, self.VREFP))

        Df = (2**self.B - 1)*(volt - self.VREFN)/(self.VREFP - self.VREFN)

        # Shift by two as 2 lower bits are not used.
        return int(np.round(Df)) << 2

    def read_reg(self, reg):
        # Address.
        addr = self.REGS[reg]

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_rd << 3) | addr
        cmd = (cmd << 4)

        # Dummy bytes for completing the command.
        # Read command.
        msg = bytes([cmd, 0, 0])
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        # Another read with dummy data to allow clocking register out.
        msg = bytes(3)
        res = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        res = int.from_bytes(res, byteorder='big')
        if (res >> 20) != addr:
            logger.error("AD5781 readback failed: tried to read addr %d, got back 0x%x"%(addr, res>>20))
        return res & 0x0fffff

    def write_reg(self, reg, val):
        # Address.
        addr = self.REGS[reg]

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_wr << 3) | addr
        cmd = (cmd << 20) | val

        # Write command.
        msg = cmd.to_bytes(length=3, byteorder='big')

        logger.debug("{}: writing register {} with values {}.".format(self.__class__.__name__, reg, msg))

        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    def set_volt(self, volt):
        """Set the voltage, return the actual (rounded) value that was set.
        """
        regval, rounded = self._volt2reg(volt)
        self.write_reg(reg="DAC_REG", val=regval)
        return self._reg2volt(regval)

    def get_volt(self):
        """Read and return the voltage setpoint.
        """
        return self._reg2volt(self.read_reg("DAC_REG"))

class BiasDAC11001:
    """Bias DAC chip DAC11001.
    """
    # Commands.
    cmd_wr = 0x0
    cmd_rd = 0x1

    # Negative/Positive voltage references.
    VREFN = -10
    VREFP = 10

    # Bits.
    B = 20

    # Registers.
    REGS = {'DAC_DATA_REG'      : 0x01  ,
            'CONFIG1_REG'       : 0x02  ,
            'DAC_CLEAR_DATA_REG': 0x03  ,
            'TRIGGER_REG'       : 0x04  ,
            'STATUS_REG'        : 0x05  ,
            'CONFIG2_REG'       : 0x06  }


    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # SPI.
        self.ch_en = ch_en
        self.cs_t = cs_t
        self.spi = spi_ip
        self.spi.SPI_SSR = 0xff

        logger.debug("{}: DAC Channel = {}.".format(self.__class__.__name__, self.ch_en))

        # Initialize control register.
        self.write_reg(reg="CONFIG1_REG", val=0x4e00)

        # Initialize to 0 volts.
        self.set_volt(0)

    # Compute register value for voltage setting.
    def _volt2reg(self, volt):
        if volt < self.VREFN or volt > self.VREFP:
            raise RuntimeError("%s: %d V out of range [%f, %f]" % (self.__class__.__name__, volt, self.VREFN, self.VREFP))
        Df = np.round(2**self.B*(volt - self.VREFN)/(self.VREFP - self.VREFN))
        if Df==2**self.B:
            # special case: V=VREFP is actually not reachable, but that's annoying and nobody will mind if we round down by an LSB
            Df -= 1

        # Shift by two as 4 lower bits are not used.
        return int(Df) << 4

    def _reg2volt(self, reg):
        reg >>= 4
        return reg*(self.VREFP - self.VREFN)/(2**self.B) + self.VREFN

    def read_reg(self, reg):
        # Address.
        addr = self.REGS[reg]

        # R/W bit (MSB) +  address (lower 7 bits).
        cmd = (self.cmd_rd << 7) | addr

        # Read command.
        msg = bytes(3) + bytes([cmd])
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        # Another read with dummy data to allow clocking register out.
        msg = bytes(4)
        res = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        return int.from_bytes(res[:3], byteorder='little')

    def write_reg(self, reg, val):
        # Address.
        addr = self.REGS[reg]

        # R/W bit (MSB) +  address (lower 7 bits).
        cmd = (self.cmd_wr << 7) | addr

        # Write command.
        # Value is 24 bits (lower 4 not used).
        msg = val.to_bytes(length=3, byteorder='little') + bytes([cmd])

        logger.debug("{}: writing register {} with values {}.".format(self.__class__.__name__, reg, msg))

        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    def set_volt(self, volt):
        # Convert volts to register value.
        val = self._volt2reg(volt)

        self.write_reg(reg="DAC_DATA_REG", val=val)
        return self._reg2volt(val)

    def get_volt(self):
        """Read and return the voltage setpoint.
        """
        return self._reg2volt(self.read_reg("DAC_DATA_REG"))

class AttenuatorPE43705:
    """
    This class provides SPI access to the PE43705 step attenuator.
    Range is 0-31.75 dB.
    Parts are used in serial mode.
    This device's SPI interface is write-only, no readback.
    See schematics for Address/LE correspondance.
    """
    nSteps = 2**7
    dbStep = 0.25
    dbMinAtt = 0
    dbMaxAtt = (nSteps-1)*dbStep

    # Constructor.
    def __init__(self, spi_ip, ch=0, nch=3, le=[0], en_l="high", cs_t="pulse"):
        self.address = ch

        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = self.spi.en_level(nch, le, en_l)
        self.cs_t = cs_t

        # Initialize with max attenuation.
        self.set_att(31.75)

    def _db2step(self, db):
        # Sanity check.
        if db < self.dbMinAtt or db > self.dbMaxAtt:
            raise RuntimeError("attenuation value %f out of range [%f, %f]" % (db, self.dbMinAtt, self.dbMaxAtt))

        return int(np.round(db/self.dbStep))

    # Set attenuation function.
    def set_att(self, db):
        # Register value.
        reg = self._db2step(db)

        msg = bytes([reg, self.address])

        # Write value using spi.
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        return reg*self.dbStep

class FilterADMV8818:
    """ADMV8818 filter chip.
    """
    # Commands.
    cmd_wr = 0x00
    cmd_rd = 0x01

    # Registers.
    REGS = {'ADI_SPI_CONFIG_A'  : 0x000,
            'ADI_SPI_CONFIG_B'  : 0x001,
            'CHIPTYPE'          : 0x003,
            'PRODUCT_ID_L'      : 0x004,
            'PRODUCT_ID_H'      : 0x005,
            'WR0_SW'            : 0x020,
            'WR0_FILTER'        : 0x021}

    # Filter Bands.
    BANDS = {}
    BANDS['LPF'] = {}
    BANDS['LPF']['bypass']  = {'min': 2.00 , 'max': 18.00, 'switch': 0}
    BANDS['LPF']['LPF1']    = {'min': 2.05 , 'max': 3.85 , 'switch': 1}
    BANDS['LPF']['LPF2']    = {'min': 3.35 , 'max': 7.25 , 'switch': 2}
    BANDS['LPF']['LPF3']    = {'min': 7.00 , 'max': 13.00, 'switch': 3}
    BANDS['LPF']['LPF4']    = {'min': 12.55, 'max': 18.85, 'switch': 4}
    BANDS['HPF'] = {}
    BANDS['HPF']['bypass']  = {'min': 2.00 , 'max': 18.00, 'switch': 0}
    BANDS['HPF']['HPF1']    = {'min': 1.75 , 'max': 3.55 , 'switch': 1}
    BANDS['HPF']['HPF2']    = {'min': 3.40 , 'max': 7.25 , 'switch': 2}
    BANDS['HPF']['HPF3']    = {'min': 6.60 , 'max': 12.60, 'switch': 3} # Actual max is 12.00. Modified to overlap bands.
    BANDS['HPF']['HPF4']    = {'min': 12.50, 'max': 19.90, 'switch': 4}

    # Number of bits for band setting.
    B = 4

    # Constructor.
    def __init__(self, spi_ip, ch, cs_t=""):
        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = ch
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        # Initialize df for each band.
        for b in self.BANDS['LPF'].keys():
            span = self.BANDS['LPF'][b]['max'] - self.BANDS['LPF'][b]['min']  
            df   = span/2**self.B
            self.BANDS['LPF'][b]['span'] = span
            self.BANDS['LPF'][b]['df']   = df
        for b in self.BANDS['HPF'].keys():
            span = self.BANDS['HPF'][b]['max'] - self.BANDS['HPF'][b]['min']  
            df   = span/2**self.B
            self.BANDS['HPF'][b]['span'] = span
            self.BANDS['HPF'][b]['df']   = df

    def write_reg(self, reg, value):
        logger.debug("{}: writing register {}".format(self.__class__.__name__, reg))

        # Register addresss.
        addr = self.REGS[reg]

        # Data.
        msg = (addr & 0x7fff).to_bytes(length=2, byteorder='big') + value.to_bytes(length=1, byteorder='big')

        for b in msg:
            logger.debug("{}: 0x{:02X}".format(self.__class__.__name__, b))

        # Execute write.
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    def read_reg(self, reg):
        logger.debug("{}: reading register {}".format(self.__class__.__name__, reg))

        # Register addresss.
        addr = self.REGS[reg]

        # Byte array.
        msg = (0x8000 | (addr & 0x7fff)).to_bytes(length=2, byteorder='big') + bytes(1)

        for b in msg:
            logger.debug("{}: 0x{:02X}".format(self.__class__.__name__, b))

        # Send/receive.
        res = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)
        return int(res[2])

    def _freq2band(self, f=0, section="LPF"):
        ret = None

        if section == "LPF":
            for b in self.BANDS[section].keys():
                if b != 'bypass':
                    fmin = self.BANDS[section][b]['min'] 
                    fmax = self.BANDS[section][b]['max'] 
                    if ((f > fmin) and (f < fmax)):
                        ret = b
                        break
        elif section == "HPF":
            for b in self.BANDS[section].keys():
                if b != 'bypass':
                    fmin = self.BANDS[section][b]['min'] 
                    fmax = self.BANDS[section][b]['max'] 
                    if ((f > fmin) and (f < fmax)):
                        ret = b
                        break

        if ret is not None:
            logger.debug("{}: frequency {:.2f} GHz for section {} found in band {}".format(self.__class__.__name__, f, section, b))
        else:
            logger.debug("{}: frequency {:.2f} GHz for section {} not found.".format(self.__class__.__name__, f, section))

        return ret

    def _freq2bits(self, f=0, section="LPF", band="LPF1"):
        ret = None

        if section == "LPF":
            if band in self.BANDS[section].keys():
                fmin = self.BANDS[section][band]['min'] 
                fmax = self.BANDS[section][band]['max'] 
                span = self.BANDS[section][band]['span'] 
                df   = self.BANDS[section][band]['df'] 
                if ((f > fmin) and (f < fmax)):
                    ret = int((f - fmin)/df)
        elif section == "HPF":
            if band in self.BANDS[section].keys():
                fmin = self.BANDS[section][band]['min'] 
                fmax = self.BANDS[section][band]['max'] 
                span = self.BANDS[section][band]['span'] 
                df   = self.BANDS[section][band]['df'] 
                if ((f > fmin) and (f < fmax)):
                    ret = int((f - fmin)/df)
        
        if ret is None:
            raise RuntimeError("{}: frequency {:.2f} GHz not found in section {} band {}.".format(self.__class__.__name__, f, section, band))
        logger.debug("{}: fmin = {:.2f} GHz, fmax = {:.2f} GHz, span = {:.2f} GHz, df = {:.3f} GHz, f = {:.2f} GHz, bits = {}".format(self.__class__.__name__, fmin, fmax, span, df, f, ret))

        return ret

    def _band2switch(self, section="LPF", band="LPF1"):
        if section in self.BANDS.keys():
            if band in self.BANDS[section].keys():
                return self.BANDS[section][band]['switch'] 
            else: 
                logger.warning("{}: band {} not found in section {}. Using bypass by default.".format(self.__class__.__name__, band, section))
                return 0
        else: 
            logger.warning("{}: section {} not found. Using bypass by default.".format(self.__class__.__name__, section))
            return 0

    def set_filter(self, fc=0, bw=2.0, ftype="lowpass"):
        # Low-pass.
        if ftype == 'lowpass':
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            band_lpf = self._freq2band(f=fc, section="LPF")
            bits_lpf = self._freq2bits(f=fc, section="LPF", band=band_lpf)
            band_hpf = 'bypass'
            bits_hpf = 0

        elif ftype == 'highpass':
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            band_lpf = 'bypass'
            bits_lpf = 0
            band_hpf = self._freq2band(f=fc, section="HPF")
            bits_hpf = self._freq2bits(f=fc, section="HPF", band=band_hpf)

        elif ftype == 'bandpass':
            f1 = fc-bw/2
            f2 = fc+bw/2
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz, bw = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc, bw))

            band_lpf = self._freq2band(f=f2, section="LPF")
            bits_lpf = self._freq2bits(f=f2, section="LPF", band=band_lpf)
            band_hpf = self._freq2band(f=f1, section="HPF")
            bits_hpf = self._freq2bits(f=f1, section="HPF", band=band_hpf)

        elif ftype == 'bypass':
            logger.debug("{}: setting filter to bypass mode.".format(self.__class__.__name__))

            band_lpf = 'bypass'
            bits_lpf = 0
            band_hpf = 'bypass'
            bits_hpf = 0
    
        else:
            raise RuntimeError("%s: filter type %s not supported." % (self.__class__.__name__, ftype))

        # WR0_SW register.
        value = 0xc0 + (self._band2switch(section="HPF", band=band_hpf) << 3) + self._band2switch(section="LPF", band=band_lpf)
        self.write_reg(reg="WR0_SW", value=value)

        # WR0_FILTER register.
        value = (bits_hpf << 4) + bits_lpf
        self.write_reg(reg="WR0_FILTER", value=value)

# Power, Switch and Fan.
class SwitchControl:
    """
    """
    # Constructor.
    def __init__(self, spi_ip):
        self.spi = spi_ip
        self.devs = []
        self.net2port = {}

    def add_MCP(self, gpio, outputs):
        if len(outputs) != len(gpio.outputs):
            raise RuntimeError("must define all %d outputs from the MCP23S08 (use None for NC pins)"%(len(gpio.outputs)))
        defaults = 0
        for iOutput, output in enumerate(outputs):
            defaults <<= 1
            if output is not None:
                netname, defaultval = output
                if netname in self.net2port:
                    raise RuntimeError("GPIO net %s is already defined")
                self.net2port[netname] = (len(self.devs), iOutput)
                defaults += defaultval

        # Set default output values.
        gpio.write_reg("GPIO_REG", defaults)
        self.devs.append(gpio)

    def __setitem__(self, netname, val):
        iDev, iBit = self.net2port[netname]
        self.devs[iDev].set_bits(bits=[iBit], val=val)

    def __contains__(self, key):
        return key in self.net2port

class GpioMCP23S08:
    """GPIO chip MCP23S08.
    """
    # Commands.
    cmd_wr = 0x40
    cmd_rd = 0x41

    # Registers.
    REGS = {'IODIR_REG': 0x00,
            'IPOL_REG': 0x01,
            'GPINTEN_REG': 0x02,
            'DEFVAL_REG': 0x03,
            'INTCON_REG': 0x04,
            'IOCON_REG': 0x05,
            'GPPU_REG': 0x06,
            'INTF_REG': 0x07,
            'INTCAP_REG': 0x08,
            'GPIO_REG': 0x09,
            'OLAT_REG': 0x0A}

    # Constructor.
    def __init__(self, spi_ip, ch_en, dev_addr, iodir=0x00, cs_t=""):
        # by default, all pins are outputs

        self.dev_addr = dev_addr

        # list of output pins
        self.outputs = [i for i in range(8) if (1<<i)&iodir==0]

        # SPI.
        self.spi = spi_ip

        # CS.
        self.ch_en = ch_en
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        # Set all bits as outputs.
        self.write_reg("IODIR_REG", iodir)

    # Data array: 3 bytes.
    # byte[0] = opcode.
    # byte[1] = register address.
    # byte[2] = register value (dummy for read).
    def read_reg(self, reg):
        # Read command.
        cmd = self.cmd_rd + 2*self.dev_addr

        # Address.
        addr = self.REGS[reg]

        # Dummy byte for clocking data out.
        msg = bytes([cmd, addr, 0])
        res = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        return int(res[2])

    def write_reg(self, reg, val):
        # Write command.
        cmd = self.cmd_wr + 2*self.dev_addr

        # Address.
        addr = self.REGS[reg]

        msg = bytes([cmd, addr, val])
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    # Write bits.
    def set_bits(self, bits, val):
        if val not in [0, 1]:
            raise RuntimeError("invalid value:", val)

        # Read actual value.
        reg = self.read_reg("GPIO_REG")

        # Set bits.
        for bit in bits:
            if bit not in self.outputs:
                raise RuntimeError("tried to set output %d, but only pins %s are configured as outputs"%(bit, self.outputs))
            if val == 1:
                reg |= (1 << bit)
            else:
                reg &= ~(1 << bit)

        # Set value to hardware.
        self.write_reg("GPIO_REG", reg)

class LoSynthADF4372:
    """LO Synthesis chip ADF4372
    """

    # Reference input.
    f_REF_in = 122.88

    # Fixed 25-bit modulus.
    MOD1 = 2**25

    # Commands.
    cmd_wr = 0x00
    cmd_rd = 0x80

    # Registers.
    REGS = {'CONFIG0_REG': 0x00,
            'CONFIG1_REG': 0x01,
            'CHIP_REG': 0x03,
            'PROD_ID0_REG': 0x04,
            'PROD_ID1_REG': 0x05,
            'PROD_REV_REG': 0x06,
            'INT_LOW_REG': 0x10,
            'INT_HIGH_REG': 0x11,
            'CAL_PRE_REG': 0x12,
            'FRAC1_LOW_REG': 0x14,
            'FRAC1_MID_REG': 0x15,
            'FRAC1_HIGH_REG': 0x16,
            'FRAC2_LOW_REG': 0x17,  # NOTE: bit zero is the MSB of FRAC1.
            'FRAC2_HIGH_REG': 0x18,
            'MOD2_LOW_REG': 0x19,
            'MOD2_HIGH_REG': 0x1A,  # NOTE: bi 6 is PHASE_ADJ.
            'PHASE_LOW_REG': 0x1B,
            'PHASE_MID_REG': 0x1C,
            'PHASE_HIGH_REG': 0x1D,
            'CONFIG2_REG': 0x1E,
            'RCNT_REG': 0x1F,
            'MUXOUT_REG': 0x20,
            'REF_REG': 0x22,
            'CONFIG3_REG': 0x23,
            'RFDIV_REG': 0x24,
            'RFOUT_REG': 0x25,
            'BLEED0_REG': 0x26,
            'BLEED1_REG': 0x27,
            'LOCK_REG': 0x28,
            'CONFIG4_REG': 0x2A,
            'SD_REG': 0x2B,
            'VCO_BIAS0_REG': 0x2C,
            'VCO_BIAS1_REG': 0x2D,
            'VCO_BIAS2_REG': 0x2E,
            'VCO_BIAS3_REG': 0x2F,
            'VCO_BAND_REG': 0x30,
            'TIMEOUT_REG': 0x31,
            'ADC_REG': 0x32,
            'SYNTH_TIMEOUT_REG': 0x33,
            'VCO_TIMEOUT_REG': 0x34,
            'ADC_CLK_REG': 0x35,
            'ICP_OFFSET_REG': 0x36,
            'SI_BAND_REG': 0x37,
            'SI_VCO_REG': 0x38,
            'SI_VTUNE_REG': 0x39,
            'ADC_OFFSET_REG': 0x3A,
            'SD_RESET_REG': 0x3D,
            'CP_TMODE_REG': 0x3E,
            'CLK1_DIV_LOW_REG': 0x3F,
            'CLK1_DIV_HIGH_REG': 0x40,
            'CLK2_DIV_REG': 0x41,
            'TRM_RESD0_REG': 0x47,
            'TRM_RESD1_REG': 0x52,
            'VCO_DATA_LOW_REG': 0x6E,
            'VCO_DATA_HIGH_REG': 0x6F,
            'BIAS_SEL_X2_REG': 0x70,
            'BIAS_SEL_X4_REG': 0x71,
            'AUXOUT_REG': 0x72,
            'LD_PD_ADC_REG': 0x73,
            'LOCK_DETECT_REG': 0x7C}

    # Constructor.
    def __init__(self, spi_ip, nch=2, le=[0], en_l="low", cs_t=""):
        # SPI.
        self.spi = spi_ip

        # CS.
        self.ch_en = self.spi.en_level(nch, le, en_l)
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        # Write 0x00 to reg 0x73
        self.reg_wr("LD_PD_ADC_REG", 0x00)
        # Write 0x3a to reg 0x72
        self.reg_wr("AUXOUT_REG", 0x3A)
        # Write 0x60 to reg 0x71
        self.reg_wr("BIAS_SEL_X4_REG", 0x60)
        # Write 0xe3 to reg 0x70
        self.reg_wr("BIAS_SEL_X2_REG", 0xE3)
        # Write 0xf4 to reg 0x52
        self.reg_wr("TRM_RESD1_REG", 0xF4)
        # Write 0xc0 to reg 0x47
        self.reg_wr("TRM_RESD0_REG", 0xC0)
        # Write 0x28 to reg 0x41
        self.reg_wr("CLK2_DIV_REG", 0x28)
        # Write 0x50 to reg 0x40
        self.reg_wr("CLK1_DIV_HIGH_REG", 0x50)
        # Write 0x80 to reg 0x3f
        self.reg_wr("CLK1_DIV_LOW_REG", 0x80)
        # Write 0x0c to reg 0x3e
        self.reg_wr("CP_TMODE_REG", 0x0C)
        # Write 0x00 to reg 0x3d
        self.reg_wr("SD_RESET_REG", 0x00)
        # Write 0x55 to reg 0x3a
        self.reg_wr("ADC_OFFSET_REG", 0x55)
        # Write 0x07 to reg 0x39
        self.reg_wr("SI_VTUNE_REG", 0x07)
        # Write 0x00 to reg 0x38
        self.reg_wr("SI_VCO_REG", 0x00)
        # Write 0x00 to reg 0x37
        self.reg_wr("SI_BAND_REG", 0x00)
        # Write 0x30 to reg 0x36
        self.reg_wr("ICP_OFFSET_REG", 0x30)
        # Write 0xff to reg 0x35
        self.reg_wr("ADC_CLK_REG", 0xFF)
        # Write 0x86 to reg 0x34
        self.reg_wr("VCO_TIMEOUT_REG", 0x86)
        # Write 0x23 to reg 0x33
        self.reg_wr("SYNTH_TIMEOUT_REG", 0x23)
        # Write 0x04 to reg 0x32
        self.reg_wr("ADC_REG", 0x04)
        # Write 0x02 to reg 0x31
        self.reg_wr("TIMEOUT_REG", 0x02)
        # Write 0x34 to reg 0x30
        self.reg_wr("VCO_BAND_REG", 0x34)
        # Write 0x94 to reg 0x2f
        self.reg_wr("VCO_BIAS3_REG", 0x94)
        # Write 0x12 to reg 0x2e
        self.reg_wr("VCO_BIAS2_REG", 0x12)
        # Write 0x11 to reg 0x2d
        self.reg_wr("VCO_BIAS1_REG", 0x11)
        # Write 0x44 to reg 0x2c
        self.reg_wr("VCO_BIAS0_REG", 0x44)
        # Write 0x10 to reg 0x2b
        self.reg_wr("SD_REG", 0x10)
        # Write 0x00 to reg 0x2a
        self.reg_wr("CONFIG4_REG", 0x00)
        # Write 0x83 to reg 0x28
        self.reg_wr("LOCK_REG", 0x83)
        # Write 0xcd to reg 0x27
        self.reg_wr("BLEED1_REG", 0xcd)
        # Write 0x2f to reg 0x26
        self.reg_wr("BLEED0_REG", 0x2F)
        # Write 0x07 to reg 0x25
        self.reg_wr("RFOUT_REG", 0x07)
        # Write 0x80 to reg 0x24
        self.reg_wr("RFDIV_REG", 0x80)
        # Write 0x00 to reg 0x23
        self.reg_wr("CONFIG3_REG", 0x00)
        # Write 0x00 to reg 0x22
        self.reg_wr("REF_REG", 0x00)
        # Write 0x14 to reg 0x20
        self.reg_wr("MUXOUT_REG", 0x14)
        # Write 0x01 to reg 0x1f
        self.reg_wr("RCNT_REG", 0x01)
        # Write 0x58 to reg 0x1e
        self.reg_wr("CONFIG2_REG", 0x58)
        # Write 0x00 to reg 0x1d
        self.reg_wr("PHASE_HIGH_REG", 0x00)
        # Write 0x00 to reg 0x1c
        self.reg_wr("PHASE_MID_REG", 0x00)
        # Write 0x00 to reg 0x1b
        self.reg_wr("PHASE_LOW_REG", 0x00)
        # Write 0x00 to reg 0x1a
        self.reg_wr("MOD2_HIGH_REG", 0x00)
        # Write 0x03 to reg 0x19
        self.reg_wr("MOD2_LOW_REG", 0x03)
        # Write 0x00 to reg 0x18
        self.reg_wr("FRAC2_HIGH_REG", 0x00)
        # Write 0x01 to reg 0x17 (holds MSB of FRAC1 on bit[0]).
        self.reg_wr("FRAC2_LOW_REG", 0x01)
        # Write 0x61 to reg 0x16
        self.reg_wr("FRAC1_HIGH_REG", 0x61)
        # Write 0x055 to reg 0x15
        self.reg_wr("FRAC1_MID_REG", 0x55)
        # Write 0x55 to reg 0x14
        self.reg_wr("FRAC1_LOW_REG", 0x55)
        # Write 0x40 to reg 0x12
        self.reg_wr("CAL_PRE_REG", 0x40)
        # Write 0x00 to reg 0x11
        self.reg_wr("INT_HIGH_REG", 0x00)
        # Write 0x28 to reg 0x10
        self.reg_wr("INT_LOW_REG", 0x28)

    # Data array: 3 bytes.
    # byte[0] = opcode/addr high.
    # byte[1] = addr low.
    # byte[2] = register value (dummy for read).
    def reg_rd(self, reg="CONFIG0_REG"):
        # Address.
        addr = self.REGS[reg]

        # Dummy byte for clocking data out.
        msg = bytes([self.cmd_rd, addr, 0])

        # Execute read.
        reg = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        return reg

    def reg_wr(self, reg="CONFIG0_REG", val=0):
        # Address.
        addr = self.REGS[reg]

        msg = bytes([self.cmd_wr, addr, val])

        # Execute write.
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    # Simple frequency setting function.
    # FRAC2 = 0 not used.
    # INT,FRAC1 sections are used.
    # All frequencies are in MHz.
    # Frequency must be in the range 4-8 GHz.
    def set_freq(self, fin=6000):
        # Sanity check.
        if fin < 4000 or fin > 8000:
            raise RuntimeError("%s: input frequency %d out of range" %
                  (self.__class__.__name__, fin))

        Ndiv = fin/self.f_REF_in

        # Integer part.
        int_ = int(np.floor(Ndiv))
        int_low = int_ & 0xff
        int_high = int_ >> 8

        # Fractional part.
        frac_ = Ndiv - int_
        frac_ = int(np.floor(frac_*self.MOD1))
        frac_low = frac_ & 0xff
        frac_mid = (frac_ >> 8) & 0xff
        frac_high = (frac_ >> 16) & 0xff
        frac_msb = frac_ >> 24

        # Write FRAC1 register.
        # MSB
        self.reg_wr('FRAC2_LOW_REG', frac_msb)

        # HIGH.
        self.reg_wr('FRAC1_HIGH_REG', frac_high)

        # MID.
        self.reg_wr('FRAC1_MID_REG', frac_mid)

        # LOW.
        self.reg_wr('FRAC1_LOW_REG', frac_low)

        # Write INT register.
        # HIGH.
        self.reg_wr('INT_HIGH_REG', int_high)

        # LOW
        self.reg_wr('INT_LOW_REG', int_low)

class LoSynthLMX2594:
    """
    """

    def __init__(self, spi_ip, ch):
        # SPI.
        self.spi = spi_ip

        # CS.
        self.ch_en = self.spi.en_level(3, [ch], "low")
        self.cs_t = ""
        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        self.lmx = clock_models.LMX2594(122.88)
        self.reset()

    @property
    def freq(self):
        return self.lmx.f_outa

    def reset(self):
        self.reg_wr(0x000002)
        self.reg_wr(0x000000)

    def reg_wr(self, regval):
        data = regval.to_bytes(length=3, byteorder='big')
        rec = self.spi.send_receive_m(data, self.ch_en, self.cs_t)

    def reg_rd(self, addr):
        data = bytes([addr + (1<<7), 0, 0])
        return self.spi.send_receive_m(data, self.ch_en, self.cs_t)

    def is_locked(self):
        status = self.get_param("rb_LD_VTUNE")
        return status.value == status.LOCKED.value

    def set_freq(self, f, pwr=50, reset=True, verbose=False):
        self.lmx.set_output_frequency(f, pwr=pwr, en_b=True, verbose=verbose)
        if reset: self.reset()
        self.program()
        time.sleep(0.01)
        self.calibrate(verbose=verbose)

    def calibrate(self, timeout=1.0, n_attempts=5, verbose=False):
        for i in range(n_attempts):
            # you'd think FCAL_EN needs to be toggled, not just set to 1?
            # but datasheet doesn't say so, and this seems to work
            self.set_param("FCAL_EN", 1)
            starttime = time.time()
            while time.time()-starttime < timeout:
                lock = self.is_locked()
                if lock:
                    if verbose: print("LO locked on attempt %d after %.2f sec"%(i+1, time.time()-starttime))
                    return
                time.sleep(0.01)
            if verbose: print("lock attempt %d failed"%(i+1))
        raise RuntimeError("LO failed to lock after %d attempts"%(n_attempts))

    def set_param(self, name, val):
        getattr(self.lmx, name).value = val
        for addr in self.lmx.find_addrs([name]):
            self.reg_wr(self.lmx.registers_by_addr[addr].get_raw())

    def get_param(self, name):
        for addr in self.lmx.find_addrs([name]):
            res = self.reg_rd(addr)
            self.lmx.registers_by_addr[addr].parse(int.from_bytes(res, byteorder='big'))
        return getattr(self.lmx, name)

    def program(self):
        for regval in self.lmx.get_register_dump():
            self.reg_wr(regval)

class GainLMH6401:
    """Variable gain amp LMH6401.
    """

    # Number of bits of gain setting.
    B = 6

    # Minimum/maximum gain.
    Gmin = -6
    Gmax = 26

    # Commands.
    cmd_wr = 0x00
    cmd_rd = 0x80

    # Registers.
    REGS = {'REVID_REG': 0x00,
            'PRODID_REG': 0x01,
            'GAIN_REG': 0x02,
            'TGAIN_REG': 0x04,
            'TFREQ_REG': 0x05}

    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = ch_en
        self.cs_t = cs_t

        # Initalize to min gain.
        self.set_gain(-6)

    def read_reg(self, reg):
        # Address.
        addr = self.REGS[reg]

        # Read command.
        cmd = self.cmd_rd | addr
        # Dummy byte for clocking data out.
        msg = bytes([cmd, 0])

        # Write value using spi.
        res = self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

        # res[0] is high-Z, might show up as 0 or 0xFF
        return res[1]

    def write_reg(self, reg, val):
        # Address.
        addr = self.REGS[reg]

        # Read command.
        cmd = self.cmd_wr | addr
        msg = bytes([cmd, val])

        # Write value using spi.
        self.spi.send_receive_m(msg, self.ch_en, self.cs_t)

    # Set gain.
    def set_gain(self, db):
        # Sanity check.
        if db < self.Gmin or db > self.Gmax:
            raise RuntimeError("%s: gain %f out of limits [%f, %f]" % (self.__class__.__name__, db, self.Gmin, self.Gmax))

        # Convert gain to attenuation (register value).
        regval = int(np.round(self.Gmax - db))

        # Write command.
        self.write_reg(reg="GAIN_REG", val=regval)

        return self.Gmax - regval

    def get_gain(self):
        regval = self.read_reg("GAIN_REG")
        return self.Gmax - regval

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

class DaughterCard216(ABC):
    NCH = None # channels per daughter card
    CARDNUM_OFFSET = None # DAC cards are 0-3, ADC cards are 4-7
    CHAIN_CLASS = None # signal chain class to instantiate for each channel
    GPIO_OUTPUTS = [None]*4 # nets controlled by the daughter card's GPIO chip
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

    def disable_all(self):
        for i in range(2):
            self.switch_control["RFIN5V0CH%d_EN"%(i)] = 0

class DacDcCard216(DaughterCard216):
    NCH = 4
    CARDNUM_OFFSET = 0
    CHAIN_CLASS = DacDcChain216
    # power-on all outputs by default, because in power-down state the LMH5401 just lets through the DAC common-mode voltage
    GPIO_OUTPUTS = [("PD%d"%(i), 0) for i in range(4)]

class AdcRfCard216(DaughterCard216):
    NCH = 2
    CARDNUM_OFFSET = 4
    CHAIN_CLASS = AdcRfChain216
    # disable all outputs by default
    GPIO_OUTPUTS = [("RFIN5V0CH%d_EN"%(i), 0) for i in range(2)] + [None]*2

class AdcDcCard216(DaughterCard216):
    NCH = 2
    CARDNUM_OFFSET = 4
    CHAIN_CLASS = AdcDcChain216
    # power-down all outputs by default
    GPIO_OUTPUTS = [("PD%d"%(i), 1) for i in range(2)] + [None]*2

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

class RFQickSoc(QickSoc):
    """
    Overrides the __init__ method of QickSoc in order to add the drivers for the preproduction (V1) version of the RF board.
    Otherwise supports all the QickSoc functionality.
    """
    HAS_LO = True
    def __init__(self, bitfile, clk_output=None, no_tproc=False, **kwargs):
        """
        A bitfile must always be provided, since the default bitstream will not work with the RF board.

        The ZCU111 RF board takes its LO reference from the ZCU111 clock output.
        So if clk_output is None, the clocks will be re-initialized every time.
        This ensures that the LO output to the RF board is enabled.
        """
        if clk_output is None and self.HAS_LO:
            clk_output = True
        super().__init__(bitfile=bitfile, clk_output=clk_output, no_tproc=no_tproc, **kwargs)

        self.rfb_config(no_tproc)

    def rfb_set_gen_rf(self, gen_ch, att1, att2):
        """Enable and configure an RF-board output channel for RF output.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        att1 : float
            Attenuation for first stage (0-31.75 dB)
        att2 : float
            Attenuation for second stage (0-31.75 dB)

        Returns
        -------
        float
            actual (rounded) att1 value that was set
        float
            actual (rounded) att2 value that was set
        """
        rfb_ch = self.gens[gen_ch].rfb_ch
        if not isinstance(rfb_ch, AbsDacRfChain):
            raise RuntimeError("generator %d is not connected to an RF signal chain")
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
            raise RuntimeError("generator %d is not connected to a DC signal chain")
        rfb_ch.enable_dc()

    def rfb_set_ro_rf(self, ro_ch, att):
        """Enable and configure an RF-board RF input channel.
        Will fail if this is not an RF input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'avg_bufs' list)
        att : float
            Attenuation (0 to 31.75 dB)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.avg_bufs[ro_ch].rfb_ch
        if not isinstance(rfb_ch, AbsAdcRfChain):
            raise RuntimeError("readout %d is not connected to an RF signal chain")
        return rfb_ch.enable_rf(att)

    def rfb_set_ro_dc(self, ro_ch, gain):
        """Enable and configure an RF-board DC input channel.
        Will fail if this is not a DC input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'readouts' list)
        gain : float
            Gain (-6 to 26 dB)

        Returns
        -------
        float
            actual (rounded) value that was set
        """
        rfb_ch = self.avg_bufs[ro_ch].rfb_ch
        if not isinstance(rfb_ch, AbsAdcDcChain):
            raise RuntimeError("readout %d is not connected to a DC signal chain")
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

class RFQickSoc111V1(RFQickSoc):
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

    def rfb_config(self, no_tproc):
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

        if not no_tproc:
            # Link gens/readouts to the corresponding RF board channels.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb_ch = self.dac_chains[4*tile + block]
            for avg_buf in self.avg_bufs:
                tile, block = [int(a) for a in avg_buf.readout.adc]
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

class RFQickSoc216V1(RFQickSoc):
    HAS_LO = False

    def __init__(self, bitfile, **kwargs):
        super().__init__(bitfile, **kwargs)

        self['extra_description'].append("\nDaughter cards detected:")
        with suppress(AttributeError):
            for slot, card in enumerate(self.dac_cards):
                if card is None:
                    self['extra_description'].append(f"\tslot {slot}: No card detected")
                else:
                    try:
                        channels = [chain.global_ch for chain in card.chains]
                    except AttributeError:
                        channels = "[UNKNOWN]"
                    self['extra_description'].append(f"\tslot {slot}: DAC card {type(card)} has channels {channels}")

            for raw_slot, card in enumerate(self.adc_cards):
                slot = raw_slot + 4
                if card is None:
                    self['extra_description'].append(f"\tslot {slot}: No card detected")
                else:
                    try:
                        channels = [chain.global_ch for chain in card.chains]
                    except AttributeError:
                        channels = "[UNKNOWN]"
                    self['extra_description'].append(f"\tslot {slot}: ADC card {type(card)} has channels {channels}")

    def rfb_config(self, no_tproc):
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
        self.biases = [BiasDAC11001(self.bias_spi, ch_en=ii) for ii in range(8)]
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
                else:
                    card = None
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
                else:
                    card = None
            self.adc_cards.append(card)

        # Link gens/readouts to the corresponding RF board channels.
        if not no_tproc:
            # Each DAC tile maps to a daughter card, in order.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                card = self.dac_cards[tile]
                if card is not None:
                    gen.rfb_ch = card.chains[block]
                else:
                    gen.rfb_ch = None
            # Each of the middle two ADC tiles (225+226) maps to a pair of daughter cards.
            for avg_buf in self.avg_bufs:
                tile, block = [int(a) for a in avg_buf.readout.adc]
                card = self.adc_cards[2*(tile-1) + block//2]
                chain_num = block % 2
                if card is not None:
                    avg_buf.rfb_ch = card.chains[chain_num]
                else:
                    avg_buf.rfb_ch = None

    def rfb_enable_bias(self):
        """Enable all eight main-board bias outputs (by turning on DAC_BIAS_SWEN).

        This is normally run during board initialization, so you should not need to run it yourself.
        """

        self.bias_gpio.channel1.write(1, 0x1)

    def rfb_disable_bias(self):
        """Disable all eight main-board bias outputs (by turning off DAC_BIAS_SWEN).
        """

        self.bias_gpio.channel1.write(0, 0x1)

    def rfb_set_gen_filter(self, gen_ch, fc, bw=1, ftype='bandpass'):
        """Set the programmable Analog Filter of the chain.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        self.gens[gen_ch].rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)

    def rfb_set_ro_filter(self, ro_ch, fc, bw=1, ftype='bandpass'):
        """Enable and configure an RF-board RF input channel.
        Will fail if this is not an RF input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'avg_bufs' list)
        fc : float
            Center frequency for bandpass, cut-off frequency of lowpass and highpass.
        bw : float
            Bandwidth.
        ftype : str
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        self.avg_bufs[ro_ch].rfb_ch.set_filter(fc = fc, bw = bw, ftype = ftype)

