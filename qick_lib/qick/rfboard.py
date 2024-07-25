import os
from .qick import SocIp, QickSoc
from .qick_asm import QickConfig
from pynq.overlay import Overlay, DefaultIP
from pynq.buffer import allocate
import xrfclk
import numpy as np
import time
from qick.ipq_pynq_utils import clock_models


class AxisSignalGenV3(SocIp):
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


class AxisSignalGenV3Ctrl(SocIp):
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

class AxisSignalGenV6Ctrl(SocIp):
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
            phrst   = "no"      ,
            debug   = False     ):

        # Set registers.
        self.freq_reg       = int(np.round(freq/self.df))
        self.phase_reg      = phase
        self.addr_reg       = addr
        self.gain_reg       = int(gain*self.gen.MAXV)
        self.nsamp_reg      = int(np.round(nsamp/self.gen.NDDS))
        self.outsel_reg     = {"product": 0, "dds":1, "envelope":2}[outsel]
        self.mode_reg       = {"nsamp": 0, "periodic":1}[mode]
        self.stdysel_reg    = {"last": 0, "zero":1}[stdysel]
        self.phase_reg      = {"no": 0, "yes":1}[phrst]

        if debug:
            print("{}".format(self.__class__.__name__))
            print(" * freq_reg      : {}".format(self.freq_reg))
            print(" * phase_reg     : {}".format(self.phase_reg))
            print(" * addr_reg      : {}".format(self.addr_reg))
            print(" * gain_reg      : {}".format(self.gain_reg))
            print(" * nsamp_reg     : {}".format(self.nsamp_reg))
            print(" * outsel_reg    : {}".format(self.outsel_reg))
            print(" * mode_reg      : {}".format(self.mode_reg))
            print(" * stdysel_reg   : {}".format(self.stdysel_reg))
            print(" * phase_reg     : {}".format(self.phase_reg))

        # Write fifo..
        self.we_reg = 1
        self.we_reg = 0

class AxisDdsMrSwitch(SocIp):
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


class spi(DefaultIP):

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
        #print(self.SPI_REGLIST)
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

# Step Attenuator PE43705.
# Range 0-31.75 dB.
# Parts are used in serial mode.
# See schematics for Address/LE correspondance.
class PE43705:
    address = 0
    nSteps = 2**7
    dbStep = 0.25
    dbMinAtt = 0
    dbMaxAtt = (nSteps-1)*dbStep

    def __init__(self, address=0):
        self.address = address

    def db2step(self, db):
        ret = -1

        # Sanity check.
        if db < self.dbMinAtt:
            raise RuntimeError("attenuation value %f out of range" % (db))
        elif db > self.dbMaxAtt:
            raise RuntimeError("attenuation value %f out of range" % (db))
        else:
            ret = int(np.round(db/self.dbStep))

        return ret

    def db2reg(self, db):
        # will get packed as (address << 8) | step
        return bytes([self.db2step(db), self.address])

# GPIO chip MCP23S08.
class MCP23S08:
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

    def __init__(self, dev_addr):
        self.dev_addr = dev_addr

    # Register/address mapping.
    def reg2addr(self, reg="GPIO_REG"):
        if reg in self.REGS:
            return self.REGS[reg]
        else:
            print("%s: register %s not recognized." %
                  (self.__class__.__name__, reg))
            return -1

    # Data array: 3 bytes.
    # byte[0] = opcode.
    # byte[1] = register address.
    # byte[2] = register value (dummy for read).
    def reg_rd(self, reg="GPIO_REG"):
        # Read command.
        cmd = self.cmd_rd + 2*self.dev_addr

        # Address.
        addr = self.reg2addr(reg)

        # Dummy byte for clocking data out.
        return bytes([cmd, addr, 0])

    def reg_wr(self, reg="GPIO_REG", val=0):
        # Write command.
        cmd = self.cmd_wr + 2*self.dev_addr

        # Address.
        addr = self.reg2addr(reg)

        return bytes([cmd, addr, val])

# LO Chip ADF4372.
class ADF4372:
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

    def reg2addr(self, reg="CONFIG0_REG"):
        if reg in self.REGS:
            return self.REGS[reg]
        else:
            print("%s: register %s not recognized." %
                  (self.__class__.__name__, reg))
            return -1

    # Data array: 3 bytes.
    # byte[0] = opcode/addr high.
    # byte[1] = addr low.
    # byte[2] = register value (dummy for read).
    def reg_rd(self, reg="CONFIG0_REG"):
        # Address.
        addr = self.reg2addr(reg)

        # Dummy byte for clocking data out.
        return bytes([self.cmd_rd, addr, 0])

    def reg_wr(self, reg="CONFIG0_REG", val=0):
        # Address.
        addr = self.reg2addr(reg)

        return bytes([self.cmd_wr, addr, val])

    # Simple frequency setting function.
    # FRAC2 = 0 not used.
    # INT,FRAC1 sections are used.
    # All frequencies are in MHz.
    # Frequency must be in the range 4-8 GHz.
    def set_freq(self, fin=6000):
        # Structures for output.
        regs = {}
        regs['INT'] = {'FULL': 0, 'LOW': 0, 'HIGH': 0}
        regs['FRAC1'] = {'FULL': 0, 'LOW': 0, 'MID': 0, 'HIGH': 0, 'MSB': 0}

        # Sanity check.
        if fin < 4000:
            print("%s: input frequency %d below the limit" %
                  (self.__class__.__name__, fin))
            return -1
        elif fin > 8000:
            print("%s: input frequency %d above the limit" %
                  (self.__class__.__name__, fin))
            return -1

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

        # Write values into structure.
        regs['INT']['FULL'] = int_
        regs['INT']['LOW'] = int_low
        regs['INT']['HIGH'] = int_high
        regs['FRAC1']['FULL'] = frac_
        regs['FRAC1']['LOW'] = frac_low
        regs['FRAC1']['MID'] = frac_mid
        regs['FRAC1']['HIGH'] = frac_high
        regs['FRAC1']['MSB'] = frac_msb

        return regs

# BIAS DAC chip AD5781.
class AD5781:
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

    # Register/address mapping.
    def reg2addr(self, reg="DAC_REG"):
        if reg in self.REGS:
            return self.REGS[reg]
        else:
            print("%s: register %s not recognized." %
                  (self.__class__.__name__, reg))
            return -1

    def reg_rd(self, reg="DAC_REG"):
        # Address.
        addr = self.reg2addr(reg)

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_rd << 3) | addr
        cmd = (cmd << 4)

        # Dummy bytes for completing the command.
        # NOTE: another full, 24-bit transaction is needed to clock the register out (may be all 0s).
        return bytes([cmd, 0, 0])

    def reg_wr(self, reg="DAC_REG", val=0):
        byte = []

        # Address.
        addr = self.reg2addr(reg)

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_wr << 3) | addr
        cmd = (cmd << 20) | val
        return cmd.to_bytes(length=3, byteorder='big')

    # Compute register value for voltage setting.
    def volt2reg(self, volt=0):
        if volt < self.VREFN:
            print("%s: %d V out of range." % (self.__class__.__name__, volt))
            return -1
        elif volt > self.VREFP:
            print("%s: %d V out of range." % (self.__class__.__name__, volt))
            return -1
        else:
            Df = (2**self.B - 1)*(volt - self.VREFN)/(self.VREFP - self.VREFN)

            # Shift by two as 2 lower bits are not used.
            Df = int(Df) << 2

            return int(Df)

# BIAS DAC chip DAC11001.
class DAC11001:
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

    # Register/address mapping.
    def reg2addr(self, reg="DAC_DATA_REG"):
        if reg in self.REGS:
            return self.REGS[reg]
        else:
            print("%s: register %s not recognized." %
                  (self.__class__.__name__, reg))
            return -1

    def reg_rd(self, reg="DAC_DATA_REG"):
        data = 0

        # Address.
        addr = self.reg2addr(reg)

        # R/W bit (MSB) +  address (lower 7 bits).
        cmd = (self.cmd_rd << 7) | addr
        #data |= (cmd << 24)
        data = bytes(3) + bytes([cmd])

        return data

    def reg_wr(self, reg="DAC_DATA_REG", val=0):
        data = 0

        # Address.
        addr = self.reg2addr(reg)

        # R/W bit (MSB) +  address (lower 7 bits).
        cmd = (self.cmd_wr << 7) | addr
        #data |= (cmd << 24)

        # Value is 24 bits (lower 4 not used).
        #data |= val
        data = val.to_bytes(length=3, byteorder='little') + bytes([cmd])

        return data

    # Compute register value for voltage setting.
    def volt2reg(self, volt=0):
        Df = np.round(2**self.B*(volt - self.VREFN)/(self.VREFP - self.VREFN))
        if (Df<0 or Df>2**self.B):
            raise RuntimeError("%f V out of range." % (volt))
        elif Df==2**self.B:
            # special case: V=VREFP is actually not reachable, but that's annoying and nobody will mind if we round down by an LSB
            Df -= 1

        # Shift by two as 4 lower bits are not used.
        return int(Df) << 4


# ADMV8818 Filter Chip.
class ADMV8818:
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

    def __init__(self):
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

    def cmd_wr(self, reg="CHIPTYPE", value=0, debug=False):
        if reg in self.REGS.keys():
            # Register addresss.
            addr = self.REGS[reg]

            # Data.
            byte = (addr & 0x7fff).to_bytes(length=2, byteorder='big') + value.to_bytes(length=1, byteorder='big')

            if debug:
                for b in byte:
                    print("{}: 0x{:02X}".format(self.__class__.__name__, b))
        else:
            raise RuntimeError("%s: register %s not found." %(self.__class__.__name__, reg))

        return byte

    def cmd_rd(self, reg="CHIPTYPE", debug=False):
        if reg in self.REGS.keys():
            # Register addresss.
            addr = self.REGS[reg]

            # Dummy.
            byte = (0x8000 | (addr & 0x7fff)).to_bytes(length=2, byteorder='big') + bytes(1)

            if debug:
                for b in byte:
                    print("{}: 0x{:02X}".format(self.__class__.__name__, b))
        else:
            raise RuntimeError("%s: register %s not found." %(self.__class__.__name__, reg))

        return byte

    def freq2band(self, f=0, section="LPF", debug=False):
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

        if debug:
            if ret is not None:
                print("{}: frequency {:.2f} GHz for section {} found in band {}".format(self.__class__.__name__, f, section, b))
            else:
                print("{}: frequency {:.2f} GHz for section {} not found.".format(self.__class__.__name__, f, section))

        return ret

    def freq2bits(self, f=0, section="LPF", band="LPF1", debug=False):
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
        
        if ret is not None:
            if debug:
                print("{}: fmin = {:.2f} GHz, fmax = {:.2f} GHz, span = {:.2f} GHz, df = {:.3f} GHz, f = {:.2f} GHz, bits = {}".format(self.__class__.__name__, fmin, fmax, span, df, f, ret))
        else:
            print("{}: frequency {:.2f} GHz not found in section {} band {}.".format(self.__class__.__name__, f, section, band))

        return ret

    def band2switch(self, section="LPF", band="LPF1", debug=False):
        if section in self.BANDS.keys():
            if band in self.BANDS[section].keys():
                return self.BANDS[section][band]['switch'] 
            else: 
                print("{}: band {} not found in section {}. Using bypass by default.".format(self.__class__.__name__, band, section))
                return 0
        else: 
            print("{}: section {} not found. Using bypass by default.".format(self.__class__.__name__, section))
            return 0

# Attenuator class: This class instantiates spi and PE43705 to simplify access to attenuator.
class attenuator:

    # Constructor.
    def __init__(self, spi_ip, ch=0, nch=3, le=[0], en_l="high", cs_t="pulse"):
        # PE43705.
        self.pe = PE43705(address=ch)

        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = self.spi.en_level(nch, le, en_l)
        self.cs_t = cs_t

        # Initialize with max attenuation.
        self.set_att(31.75)

    # Set attenuation function.
    def set_att(self, db):
        # Register value.
        reg = self.pe.db2reg(db)

        # Write value using spi.
        self.spi.send_receive_m(reg, self.ch_en, self.cs_t)

# Filter class: This class instantiates spi and ADMV8818 to simplify access to the filter chip.
class prog_filter:

    # Constructor.
    def __init__(self, spi_ip, ch=0, cs_t=""):
        # ADMV8818.
        self.ic = ADMV8818()

        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = ch
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

    def reg_wr(self, reg="CHIPTYPE", value=0, debug=False):
        if debug:
            print("{}: writing register {}".format(self.__class__.__name__, reg))

        # Byte array.
        byte = self.ic.cmd_wr(reg=reg, value=value, debug=debug)

        # Execute write.
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

    def reg_rd(self, reg="CHIPTYPE", debug=False):
        if debug:
            print("{}: reading register {}".format(self.__class__.__name__, reg))

        # Byte array.
        byte = self.ic.cmd_rd(reg=reg, debug=debug)

        # Send/receive.
        ret = int.from_bytes(self.spi.send_receive_m(byte, self.ch_en, self.cs_t), byteorder="big")

        # Execute write.
        return ret & 0xff

    def set_filter(self, fc=0, bw=None, ftype="lowpass", debug=False):
        # Low-pass.
        if ftype == 'lowpass':
            if debug:
                print("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            band_lpf = self.ic.freq2band(f=fc, section="LPF", debug=debug)
            bits_lpf = self.ic.freq2bits(f=fc, section="LPF", band=band_lpf, debug=debug)
            band_hpf = 'bypass'
            bits_hpf = 0

        elif ftype == 'highpass':
            if debug:
                print("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            band_lpf = 'bypass'
            bits_lpf = 0
            band_hpf = self.ic.freq2band(f=fc, section="HPF", debug=debug)
            bits_hpf = self.ic.freq2bits(f=fc, section="HPF", band=band_hpf, debug=debug)

        elif ftype == 'bandpass':
            # Default bw is 2 GHz.
            if bw is None:
                bw = 2
            f1 = fc-bw/2
            f2 = fc+bw/2
            if debug:
                print("{}: setting {} filter type, fc = {:.2f} GHz, bw = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc, bw))

            band_lpf = self.ic.freq2band(f=f2, section="LPF", debug=debug)
            bits_lpf = self.ic.freq2bits(f=f2, section="LPF", band=band_lpf, debug=debug)
            band_hpf = self.ic.freq2band(f=f1, section="HPF", debug=debug)
            bits_hpf = self.ic.freq2bits(f=f1, section="HPF", band=band_hpf, debug=debug)

        elif ftype == 'bypass':
            if debug:
                print("{}: setting filter to bypass mode.".format(self.__class__.__name__))

            band_lpf = 'bypass'
            bits_lpf = 0
            band_hpf = 'bypass'
            bits_hpf = 0
    
        else:
            raise Warning("%s: filter type %s not supported." % (self.__class__.__name__, ftype))

        # WR0_SW register.
        value = 0xc0 + (self.ic.band2switch(section="HPF", band=band_hpf) << 3) + self.ic.band2switch(section="LPF", band=band_lpf)
        self.reg_wr(reg="WR0_SW", value=value, debug=debug)

        # WR0_FILTER register.
        value = (bits_hpf << 4) + bits_lpf
        self.reg_wr(reg="WR0_FILTER", value=value, debug=debug)

# Power, Switch and Fan.
class SwitchControl:
    # Constructor.
    def __init__(self, spi_ip):
        self.spi = spi_ip
        self.devs = []
        self.net2port = {}

    def add_MCP(self, ch_en, outputs, dev_addr=0):
        if len(outputs) != 8:
            raise RuntimeError("must define all 8 outputs from the MCP23S08 (use None for NC pins)")
        defaults = 0
        for iOutput, output in enumerate(outputs):
            defaults <<= 1
            if output is not None:
                netname, defaultval = output
                self.net2port[netname] = (len(self.devs), iOutput)
                defaults += defaultval
        self.devs.append(power_sw_fan(self.spi, ch_en=ch_en, dev_addr=dev_addr, defaults=defaults))

    def __setitem__(self, netname, val):
        iDev, iBit = self.net2port[netname]
        if val == 1:
            self.devs[iDev].bits_set(bits=[iBit])
        elif val == 0:
            self.devs[iDev].bits_reset(bits=[iBit])
        else:
            raise RuntimeError("invalid value:", val)

class power_sw_fan:

    # Constructor.
    def __init__(self, spi_ip, ch_en, defaults=0xFF, dev_addr=0, cs_t=""):
        # MCP23S08.
        self.mcp = MCP23S08(dev_addr=dev_addr)

        # SPI.
        self.spi = spi_ip

        # CS.
        self.ch_en = ch_en
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        # Set all bits as outputs.
        byte = self.mcp.reg_wr("IODIR_REG", 0x00)
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

        # Set default output values.
        byte = self.mcp.reg_wr("GPIO_REG", defaults)
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

    # Write bits.
    def bits_set(self, bits=[0]):
        val = 0

        # Read actual value.
        byte = self.mcp.reg_rd("GPIO_REG")
        vals = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)
        val = int(vals[2])

        # Set bits.
        for i in range(len(bits)):
            val |= (1 << bits[i])

        # Set value to hardware.
        byte = self.mcp.reg_wr("GPIO_REG", val)
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

    def bits_reset(self, bits=[0]):
        val = 0xff

        # Read actual value.
        byte = self.mcp.reg_rd("GPIO_REG")
        vals = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)
        val = int(vals[2])

        # Reset bits.
        for i in range(len(bits)):
            val &= ~(1 << bits[i])

        # Set value to hardware.
        byte = self.mcp.reg_wr("GPIO_REG", val)
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

# LO Synthesis.
class lo_synth:

    # Constructor.
    def __init__(self, spi_ip, nch=2, le=[0], en_l="low", cs_t=""):
        # ADF4372.
        self.adf = ADF4372()

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

    def reg_rd(self, reg="CONFIG0_REG"):
        # Byte array.
        byte = self.adf.reg_rd(reg)

        # Execute read.
        reg = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

        return reg

    def reg_wr(self, reg="CONFIG0_REG", val=0):
        # Byte array.
        byte = self.adf.reg_wr(reg, val)

        # Execute write.
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

    def set_freq(self, fin=6000):
        # Get INT/FRAC register values.
        regs = self.adf.set_freq(fin)

        # Check if it was successful.
        if regs == -1:
            a = 1
        else:
            # Write FRAC1 register.
            # MSB
            self.reg_wr('FRAC2_LOW_REG', regs['FRAC1']['MSB'])

            # HIGH.
            self.reg_wr('FRAC1_HIGH_REG', regs['FRAC1']['HIGH'])

            # MID.
            self.reg_wr('FRAC1_MID_REG', regs['FRAC1']['MID'])

            # LOW.
            self.reg_wr('FRAC1_LOW_REG', regs['FRAC1']['LOW'])

            # Write INT register.
            # HIGH.
            self.reg_wr('INT_HIGH_REG', regs['INT']['HIGH'])

            # LOW
            self.reg_wr('INT_LOW_REG', regs['INT']['LOW'])

# Bias dac.
class dac_bias:

    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t="", gpio_ip=None, version=1, fpga_board="ZCU216", debug=False):
        # SPI.
        self.ch_en = ch_en
        self.cs_t = cs_t
        self.spi = spi_ip
        self.spi.SPI_SSR = 0xff

        # Version.
        self.version = version

        # Board.
        self.fpga_board = fpga_board

        if debug:
            print("{}: DAC Channel = {}.".format(self.__class__.__name__, self.ch_en))

        if self.fpga_board == 'ZCU111':
            # AD5791.
            self.ad = AD5781()

            # Initialize control register.
            self.write(reg="CTRL_REG", val=0x312)

            # Initialize to 0 volts.
            self.set_volt(0)

        elif self.fpga_board == 'ZCU216':
            if version == 1:
                # GPIO.
                self.gpio = gpio_ip.channel1

                # DAC11001.
                self.ad = DAC11001()

                # Initialize control register.
                self.write(reg="CONFIG1_REG", val=0x4e00)

                # Initialize to 0 volts.
                self.set_volt(0)

                # Enable output switch.
                self.gpio.write(1,0x1)
            else:
                raise RuntimeError("%s: version %d not supported." % (self.__class__.__name, version))
        else:
            raise RuntimeError("%s: board %s not recognized." % (self.__class__.__name__, fpga_board))


    def read(self, reg="DAC_REG"):
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # Read command.
            data = self.ad.reg_rd(reg)
            reg = self.spi.send_receive_m(data, self.ch_en, self.cs_t)

            # Another read with dummy data to allow clocking register out.
            data = bytes(4)
            reg = self.spi.send_receive_m(data, self.ch_en, self.cs_t)
            return int.from_bytes(reg[:3], byteorder='little')
        else:
            # Read command.
            byte = self.ad.reg_rd(reg)
            reg = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

            # Another read with dummy data to allow clocking register out.
            byte = bytes(3)
            reg = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

        return reg

    def write(self, reg="DAC_REG", val=0, debug=False):
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # Write command.
            data = self.ad.reg_wr(reg, val)

            if debug:
                print("{}: writing register {} with values {}.".format(self.__class__.__name__, reg, data))

            self.spi.send_receive_m(data, self.ch_en, self.cs_t)
        else:
            # Write command.
            data = self.ad.reg_wr(reg, val)

            if debug:
                print("{}: writing register {} with values {}.".format(self.__class__.__name__, reg, data))

            self.spi.send_receive_m(data, self.ch_en, self.cs_t)

    def set_volt(self, volt=0, debug=False):
        # Convert volts to register value.
        val = self.ad.volt2reg(volt)

        if self.fpga_board == 'ZCU216' and self.version == 1:
            self.write(reg="DAC_DATA_REG", val=val, debug=debug)
        else:
            self.write(reg="DAC_REG", val=val, debug=debug)

# Variable Gain Amp chip LMH6401.
class LMH6401:
    # Commands.
    cmd_wr = 0x00
    cmd_rd = 0x80

    # Registers.
    REGS = {'REVID_REG': 0x00,
            'PRODID_REG': 0x01,
            'GAIN_REG': 0x02,
            'TGAIN_REG': 0x04,
            'TFREQ_REG': 0x05}

    # Register/address mapping.
    def reg2addr(self, reg="GAIN_REG"):
        if reg in self.REGS:
            return self.REGS[reg]
        else:
            print("%s: register %s not recognized." %
                  (self.__class__.__name__, reg))
            return -1

    # Data array: 2 bytes.
    # byte[0] = rw/address.
    # byte[1] = data.
    def reg_rd(self, reg="GAIN_REG"):
        # Address.
        addr = self.reg2addr(reg)

        # Read command.
        cmd = self.cmd_rd | addr

        # Dummy byte for clocking data out.
        return bytes([cmd, 0])

    def reg_wr(self, reg="GAIN_REG", val=0):
        # Address.
        addr = self.reg2addr(reg)

        # Read command.
        cmd = self.cmd_wr | addr

        return bytes([cmd, val])

# Variable step amp class: This class instantiates spi and LMH6401 to simplify access to amplifier.
class gain:

    # Number of bits of gain setting.
    B = 6

    # Minimum/maximum gain.
    Gmin = -6
    Gmax = 26

    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # LMH6401.
        self.lmh = LMH6401()

        # SPI.
        self.spi = spi_ip

        # Lath-enable.
        self.ch_en = ch_en
        self.cs_t = cs_t

        # Initalize to min gain.
        self.set_gain(-6)

    # Set gain.
    def set_gain(self, db):
        # Sanity check.
        if db < self.Gmin:
            print("%s: gain %f out of limits." % (self.__class__.__name__, db))
        elif db > self.Gmax:
            print("%s: gain %f out of limits." % (self.__class__.__name__, db))
        else:
            # Convert gain to attenuation (register value).
            db_a = int(np.round(self.Gmax - db))

            # Write command.
            byte = self.lmh.reg_wr(reg="GAIN_REG", val=db_a)

            # Write value using spi.
            self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

# Class to describe the ADC-RF channel chain.
class adc_rf_ch():
    # Constructor.
    def __init__(self, ch=0, switches=None, attn_spi=None, filter_spi=None, version=2, fpga_board="ZCU216", rfboard_ch=0, rfboard_sel=None, debug=False):
        # Channel number.
        self.ch = ch

        # RF board version.
        self.version = version

        # FPGA Board.
        self.fpga_board = fpga_board

        # ZCU111 board.
        if self.fpga_board == 'ZCU111':

            # Power switches.
            self.switches = switches

            # Attenuator.
            self.attn = attenuator(attn_spi, ch, le=[0])

            # Default to 30 dB attenuation.
            self.set_attn_db(30)

        # ZCU216 board.
        elif self.fpga_board == 'ZCU216':
            if version == 1:
                # Board selection.
                self.rfboard_ch = rfboard_ch
                self.brd_sel = rfboard_sel

                # Channels are numbered from 0-7. Daughter cards have 2 channels each, with nubers going from 0-1.
                self.local_ch = ch % 2

                if debug:
                    print("{}: ADC Channel = {}, Daughter Card = {}, Daughter Card DAC channel {}.".format(self.__class__.__name__, self.ch, self.rfboard_ch, self.local_ch))

                # Attenuators. There is 1 per ADC Channel.
                self.attn = []
                self.attn.append(attenuator(attn_spi, ch=self.local_ch, nch=1, le=[0]))
                if debug:
                    print("{}: adding attenuator with address {}.".format(self.__class__.__name__, self.local_ch))

                # Filters. There is 1 per ADC Channel.
                self.filter = prog_filter(filter_spi, ch=self.local_ch)
                if debug:
                    print("{}: adding filter with address {}.".format(self.__class__.__name__, self.local_ch))

                # Initialize filter.
                self.init_filter()

            else:
                raise RuntimeError("%s: version %d not supported." % (self.__class__.__name, version))
        else:
            raise RuntimeError("%s: board %s not recognized." % (self.__class__.__name__, fpga_board))

    # Set attenuator.
    def set_attn_db(self, db=0, debug=False):
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # Enable this daughter card.
            self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

            # Set attenuator.
            self.attn[0].set_att(db)

            # Disable all daughter cards.
            self.brd_sel.disable()
        else:
            self.attn.set_att(db)
            self.enable()

    def init_filter(self,debug=False):
        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Program ADI_SPI_CONFIG_A register to 0x3C.
        self.filter.reg_wr(reg="ADI_SPI_CONFIG_A", value=0x3C, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()

    def set_filter(self, fc=0, bw=None, ftype="lowpass", debug=False):
        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Set filter.
        self.filter.set_filter(fc=fc, bw=bw, ftype=ftype, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()

    def read_filter(self, reg="", debug=False):
        if debug:
            print("{}: reading register {}".format(self.__class__.__name__, reg))

        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Set filter.
        ret = self.filter.reg_rd(reg=reg, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()
        
        return ret 

    def enable(self):
        # Turn on 5V power.
        self.switches["RF2IF5V_EN%d"%(self.ch)] = 1

    def disable(self):
        # Turn off 5V power.
        self.switches["RF2IF5V_EN%d"%(self.ch)] = 0

# Class to describe the ADC-DC channel chain.
class adc_dc_ch():
    # Constructor.
    def __init__(self, ch, switches, gain_spi, version=2):
        # Channel number.
        self.ch = ch

        # RF board version.
        self.version = version

        # Power switches.
        self.switches = switches

        # Variable Gain Amplifier.
        if ch < 4 or ch > 7:
            print("%s: channel %d not valid for ADC-DC type" %
                  (self.__class__.__name__, ch))

        self.gain = gain(gain_spi, ch_en=ch)

        # Default to 0 dB gain.
        self.set_gain_db(0)

    # Set gain.
    def set_gain_db(self, db=0):
        self.gain.set_gain(db)
        if self.version==2:
            self.enable()

    def enable(self):
        if self.version!=2:
            raise RuntimeError("enable/disable not supported for version", self.version)
        # Power up.
        self.switches["RF2IF_PD%d"%(self.ch)] = 0

    def disable(self):
        if self.version!=2:
            raise RuntimeError("enable/disable not supported for version", self.version)
        # Power down.
        self.switches["RF2IF_PD%d"%(self.ch)] = 1

# Class to describe the DAC channel chain.
class dac_ch():
    # Constructor.
    def __init__(self, ch=0, switches=None, attn_spi=None, filter_spi=None, version=2, fpga_board="ZCU216", rfboard_ch=0, rfboard_sel=None, debug=False):
        # Channel number.
        self.ch = ch

        # RF board version.
        self.version = version

        # FPGA Board.
        self.fpga_board = fpga_board

        # ZCU111 board.
        if self.fpga_board == 'ZCU111':
            # RF input and power switches.
            self.switches = switches

            # Attenuators.
            self.attn = []
            self.attn.append(attenuator(attn_spi, ch, le=[1]))
            self.attn.append(attenuator(attn_spi, ch, le=[2]))

            # Initialize in off state.
            self.disable()
        
        # ZCU216 board.
        elif self.fpga_board == 'ZCU216':
            if version == 1:
                # Board selection.
                self.rfboard_ch = rfboard_ch
                self.brd_sel = rfboard_sel

                # Channels are numbered from 0-15. Daughter cards have 4 channels each, with nubers going from 0-3.
                self.local_ch = ch % 4

                if debug:
                    print("{}: DAC Channel = {}, Daughter Card = {}, Daughter Card DAC channel {}.".format(self.__class__.__name__, self.ch, self.rfboard_ch, self.local_ch))

                # Attenuators. There are 2 per DAC Channel.
                self.attn = []
                for i in range(2):
                    addr = 2*self.local_ch+i
                    self.attn.append(attenuator(attn_spi, ch=addr, nch=1, le=[0]))
                    if debug:
                        print("{}: adding attenuator with address {}.".format(self.__class__.__name__, addr))

                # Filters. There is 1 per ADC Channel.
                self.filter = prog_filter(filter_spi, ch=self.local_ch)
                if debug:
                    print("{}: adding filter with address {}.".format(self.__class__.__name__, self.local_ch))

                # Initialize filter.
                self.init_filter()

            else:
                raise RuntimeError("%s: version %d not supported." % (self.__class__.__name, version))
        else:
            raise RuntimeError("%s: board %s not recognized." % (self.__class__.__name__, fpga_board))

    # Switch selection.
    def rfsw_sel(self, sel="RF"):
        if sel == "RF":
            # Set logic one.
            # Select RF output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 1
            # Turn on 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 1
            if self.version==2:
                # Power down DC amplifier.
                self.switches["IF2RF_PD%d"%(self.ch)] = 1
        elif sel == "DC":
            # Select DC output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 0
            # Turn off 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 0
            if self.version==2:
                # Power up DC amplifier.
                self.switches["IF2RF_PD%d"%(self.ch)] = 0
        elif sel == "OFF":
            # Select RF output from switch.
            self.switches["CH%d_PE42020_CTL"%(self.ch)] = 1
            # Turn off 5V power to RF chain.
            self.switches["IF2RF5V_EN%d"%(self.ch)] = 0
            if self.version==2:
                # Power down DC amplifier.
                self.switches["IF2RF_PD%d"%(self.ch)] = 1
        else:
            print("%s: selection %s not recoginzed." %
                  (self.__class__.__name__, sel))

    # Set attenuator.
    def set_attn_db(self, attn=0, db=0, debug=False):
        # Enable daughter card.
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # Board selection logic.    
            self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Set attenuator.        
        if attn < len(self.attn):
            self.attn[attn].set_att(db)
        else:
            print("%s: attenuator %d not in chain." %
                  (self.__class__.__name__, attn))

        # Disable daughter card.
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # Board selection logic.    
            self.brd_sel.disable()

    def init_filter(self,debug=False):
        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Program ADI_SPI_CONFIG_A register to 0x3C.
        self.filter.reg_wr(reg="ADI_SPI_CONFIG_A", value=0x3C, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()

    def set_filter(self, fc=0, bw=None, ftype="lowpass", debug=False):
        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Set filter.
        self.filter.set_filter(fc=fc, bw=bw, ftype=ftype, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()

    def read_filter(self, reg="", debug=False):
        if debug:
            print("{}: reading register {}".format(self.__class__.__name__, reg))

        # Enable this daughter card.
        self.brd_sel.enable(board_id = self.rfboard_ch, debug=debug)

        # Set filter.
        ret = self.filter.reg_rd(reg=reg, debug=debug)

        # Disable all daughter cards.
        self.brd_sel.disable()
        
        return ret 

    def set_rf(self, att1, att2):
        if self.fpga_board == 'ZCU216' and self.version == 1:
            # TODO: Check that this is a RF daughter card.
            self.set_attn_db(attn=0, db=att1)
            self.set_attn_db(attn=1, db=att2)
        else:
            self.rfsw_sel("RF")
            self.set_attn_db(attn=0, db=att1)
            self.set_attn_db(attn=1, db=att2)

    def set_dc(self):
        self.rfsw_sel("DC")

    def disable(self):
        self.rfsw_sel("OFF")
        self.set_attn_db(attn=0, db=31.75)
        self.set_attn_db(attn=1, db=31.75)

class BoardSelection:
    """
    This class is used to enable one daughter card on the RF Board for the ZCU216, V1.
    """

    def __init__(self, gpio_ip):
        self.gpio = gpio_ip.channel1

    def enable(self, board_id = 0, debug=False):
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

        if debug:
            print("{}: setting vaue = 0x{:01X}".format(self.__class__.__name__,val_))

    def disable(self):
        # E/D bit to 0.
        self.gpio.write(0, 0xf)

class RFQickSoc(QickSoc):
    """
    Overrides the __init__ method of QickSoc in order to add the drivers for the preproduction (V1) version of the RF board.
    Otherwise supports all the QickSoc functionality.
    """
    def __init__(self, bitfile, clk_output=True, no_tproc=False, **kwargs):
        """
        A bitfile must always be provided, since the default bitstream will not work with the RF board.
        By default, re-initialize the clocks every time.
        This ensures that the LO output to the RF board is enabled.
        """
        super().__init__(bitfile=bitfile, clk_output=clk_output, no_tproc=no_tproc, **kwargs)

        # Add configuration dictionary.
        self['rfboard'] = {}

        self.rfb_config(no_tproc)

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
        self.switches = SwitchControl(self.psf_spi)
        # ADC power
        self.switches.add_MCP(ch_en=0,
                outputs=[("RF2IF5V_EN"+str(i), 0) for i in range(4)] 
                + [None]*4)
        # DAC power
        self.switches.add_MCP(ch_en=1,
                outputs=[("IF2RF5V_EN"+str(i), 0) for i in range(8)])
        # DAC RF/DC switch
        self.switches.add_MCP(ch_en=2,
                outputs=[("CH%d_PE42020_CTL"%(i), 1) for i in range(8)])

        # LO Synthesizers.
        self.lo = [lo_synth(self.lo_spi, le=[i]) for i in range(2)]

        # DAC BIAS.
        self.dac_bias = [dac_bias(self.dac_bias_spi, ch_en=ii) for ii in range(8)]

        # ADC channels.
        self.adc_chains = [adc_rf_ch(ii, self.switches, self.attn_spi) for ii in range(4)] + [adc_dc_ch(ii, self.switches, self.psf_spi, version=1) for ii in range(4,8)]
        
        # DAC channels.
        self.dac_chains = [dac_ch(ii, self.switches, self.attn_spi, version=1) for ii in range(8)]

        if not no_tproc:
            # Link gens/readouts to the corresponding RF board channels.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb = self.dacs[4*tile + block]
            for avg_buf in self.avg_bufs:
                tile, block = [int(a) for a in avg_buf.readout.adc]
                avg_buf.rfb = self.adc_chains[2*tile + block]

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
        """
        self.gens[gen_ch].rfb.set_rf(att1, att2)

    def rfb_set_gen_dc(self, gen_ch):
        """Enable and configure an RF-board output channel for DC output.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        """
        self.gens[gen_ch].rfb.set_dc()

    def rfb_set_ro_rf(self, ro_ch, att):
        """Enable and configure an RF-board RF input channel.
        Will fail if this is not an RF input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'avg_bufs' list)
        att : float
            Attenuation (0 to 31.75 dB)
        """
        self.avg_bufs[ro_ch].rfb.set_attn_db(att)

    def rfb_set_ro_dc(self, ro_ch, gain):
        """Enable and configure an RF-board DC input channel.
        Will fail if this is not a DC input.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'readouts' list)
        gain : float
            Gain (-6 to 26 dB)
        """
        self.avg_bufs[ro_ch].rfb.set_gain_db(gain)

    def rfb_set_bias(self, bias_ch, v):
        """Set a voltage on an RF-board bias DAC.

        Parameters
        ----------
        bias_ch : int
            Channel number (0-7)
        v : float
            Voltage (-10 to 10 V)
        """
        self.dac_bias[bias_ch].set_volt(v)

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
        ftype : string.
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        self.gens[gen_ch].rfb.set_filter(fc = fc, bw = bw, ftype = ftype)

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
        ftype : string.
            Filter type: bypass, lowpass, highpass or bandpass.
        """
        self.avg_bufs[ro_ch].rfb.set_filter(fc = fc, bw = bw, ftype = ftype)

class lo_synth_v2:
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

    def read_and_parse(self, addr):
        regval = int.from_bytes(self.reg_rd(addr), byteorder="big")
        reg = clock_models.Register(self.lmx.registers_by_addr[addr].regdef)
        reg.parse(regval)
        return reg

    def is_locked(self):
        status = self.get_param("rb_LD_VTUNE")
        #print(status.value_description)
        return status.value == self.lmx.rb_LD_VTUNE.LOCKED.value

    def set_freq(self, f, pwr=50, osc_2x=False, reset=True, verbose=False):
        self.lmx.set_output_frequency(f, pwr=pwr, en_b=True, osc_2x=osc_2x, verbose=verbose)
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
        param = getattr(self.lmx, name)
        param.value = val
        if isinstance(param, clock_models.Field):
            self.reg_wr(self.lmx.registers_by_addr[param.addr].get_raw())
        else: # MultiRegister
            for field in param.fields:
                self.reg_wr(self.lmx.registers_by_addr[field.addr].get_raw())

    def get_param(self, name):
        param = getattr(self.lmx, name)
        return self.read_and_parse(param.addr).fields[param.index]

    def program(self):
        for regval in self.lmx.get_register_dump():
            self.reg_wr(regval)

class RFQickSocV2(RFQickSoc):
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
        self.switches = SwitchControl(self.psf_spi)
        # ADC power/power-down
        self.switches.add_MCP(ch_en=0, dev_addr=0,
                outputs=[("RF2IF5V_EN"+str(i), 0) for i in range(4)]
                + [("RF2IF_PD"+str(i), 1) for i in range(4, 8)])
        # DAC power-down
        self.switches.add_MCP(ch_en=1, dev_addr=1,
                outputs=[("IF2RF_PD"+str(i), 1) for i in range(8)])
        # DAC power
        self.switches.add_MCP(ch_en=1, dev_addr=0,
                outputs=[("IF2RF5V_EN"+str(i), 0) for i in range(8)])
        # DAC RF/DC switch
        self.switches.add_MCP(ch_en=2, dev_addr=0,
                outputs=[("CH%d_PE42020_CTL"%(i), 1) for i in range(8)])

        # LO Synthesizers.
        self.lo = [lo_synth_v2(self.lo_spi, i) for i in range(3)]

        # DAC BIAS.
        self.dac_bias = [dac_bias(self.dac_bias_spi, ch_en=ii, fpga_board=self['board']) for ii in range(8)]

        # ADC channels.
        self.adc_chains = [adc_rf_ch(ii, self.switches, self.attn_spi, fpga_board=self['board']) for ii in range(4)] + [adc_dc_ch(ii, self.switches, self.psf_spi) for ii in range(4,8)]

        # DAC channels.
        self.dac_chains = [dac_ch(ii, self.switches, self.attn_spi, fpga_board=self['board']) for ii in range(8)]

        # Link RF channels to LOs.
        for adc in self.adc_chains[:4]: adc.lo = self.lo[0]
        for dac in self.dac_chains[:4]: dac.lo = self.lo[1]
        for dac in self.dac_chains[4:]: dac.lo = self.lo[2]

        if not no_tproc:
            # Link gens/readouts to the corresponding RF board channels.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb = self.dac_chains[4*tile + block]
            for avg_buf in self.avg_bufs:
                tile, block = [int(a) for a in avg_buf.readout.adc]
                avg_buf.rfb = self.adc_chains[2*tile + block]

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

class RFQickSoc216V1(RFQickSoc):

    def rfb_config(self, no_tproc):
        """
        Configure the GPIO/SPI interfaces to the RF board.
        """

        # GPIO for Board Selection.
        if 'brd_sel_gpio' in self.ip_dict.keys():
            self.board_sel = BoardSelection(self.brd_sel_gpio)
        else:
            raise RuntimeError("%s: brd_sel_gpio for board selection logic not found." % self.__class__.__name__) 

        # SPI used for Attenuators.
        if 'attn_spi' in self.ip_dict.keys():
            self.attn_spi.config(lsb="lsb")
        else:
            raise RuntimeError("%s: attn_spi for attenuator control not found." % self.__class__.__name__) 

        # SPI used for Filter.
        if 'filter_spi' in self.ip_dict.keys():
            self.filter_spi.config(lsb="msb")
        else:
            raise RuntimeError("%s: filter_spi for filter control not found." % self.__class__.__name__) 

        # SPI used for BIAS.
        if 'bias_spi' in self.ip_dict.keys():
            self.bias_spi.config(lsb="msb", cpha="invert")
        else:
            raise RuntimeError("%s: bias_spi for bias DACs control not found." % self.__class__.__name__) 

        if 'bias_gpio' in self.ip_dict.keys():
            pass
        else:
            raise RuntimeError("%s: bias_gpio for bias DACs control not found." % self.__class__.__name__) 
        
        # DAC BIAS.
        self.dac_bias = [dac_bias(self.bias_spi, ch_en=ii, gpio_ip=self.bias_gpio, version=1, fpga_board=self['board']) for ii in range(8)]

        # ADC channels. ADC's daughter cards are the upper 4.
        self.adc_chains = []
        NRF = 4 # Number of ADC daughter cards.
        NCH = 2 # ADC channels per daughter card.
        for rf_board in range(NRF):
            for ch in range(NCH):
                self.adc_chains.append(adc_rf_ch(ch=NCH*rf_board+ch, attn_spi=self.attn_spi, filter_spi=self.filter_spi, version=1, fpga_board=self['board'], rfboard_ch=NRF+rf_board, rfboard_sel=self.board_sel))

        # DAC channels. DAC's daughter cards are the lower 4.
        self.dac_chains = []
        NRF = 4 # Number of DAC daughter cards.
        NCH = 4 # DAC channels per daughter card.
        for rf_board in range(NRF):
            for ch in range(NCH):
                self.dac_chains.append(dac_ch(ch=NCH*rf_board+ch, attn_spi=self.attn_spi, filter_spi=self.filter_spi, version=1, fpga_board=self['board'], rfboard_ch=rf_board, rfboard_sel=self.board_sel))

        # Link gens/readouts to the corresponding RF board channels.
        if not no_tproc:
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb = self.dac_chains[4*tile + block]
            for avg_buf in self.avg_bufs:
                tile, block = [int(a) for a in avg_buf.readout.adc]
                #TODO: is tile-1 correct? not tile-2?
                avg_buf.rfb = self.adc_chains[4*(tile-1) + block]

