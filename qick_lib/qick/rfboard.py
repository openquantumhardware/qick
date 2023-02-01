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
    REGISTERS = {'start_addr_reg': 0, 'we_reg': 1}

    # Generics
    N = 12
    NDDS = 16

    # Maximum number of samples
    MAX_LENGTH = 2**N*NDDS

    def __init__(self, description, **kwargs):
        super().__init__(description)

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
    REGISTERS = {
        'freq': 0,
        'phase': 1,
        'addr': 2,
        'gain': 3,
        'nsamp': 4,
        'outsel': 5,
        'mode': 6,
        'stdysel': 7,
        'we': 8}

    # Generics of Signal Generator.
    N = 10
    NDDS = 16
    B = 16
    MAX_v = 2**B - 1

    # Sampling frequency.
    fs = 4096

    def __init__(self, description, **kwargs):
        super().__init__(description)

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


class AxisDdsMrSwitch(SocIp):
    # AXIS DDS MR SWITCH registers.
    # DDS_REAL_IMAG_REG
    # * 0 : real part.
    # * 1 : imaginary part.
    #
    bindto = ['user.org:user:axis_dds_mr_switch:1.0']
    REGISTERS = {'dds_real_imag': 0}

    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)

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
        # Manually assert channels.
        ch_en_temp = self.SPI_SSR.Selected_Slave

        # Standard CS at the beginning of transaction.
        if cs_t != "pulse":
            self.SPI_SSR = ch_en

        # Send data.
        for byte in data:
            # Send data.
            self.SPI_DTR = byte

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
        # Fifo is empty
        if self.SPISR.RX_Empty==1:
            return []
        else:
            # Get number of samples on fifo.
            nr = self.SPI_RXFIFO_OR.Occupancy_Value + 1
            data_r = bytes([self.SPI_DRR.RX_Data for i in range(nr)])
            return data_r

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
            print("%s: attenuation value %f out of range" %
                  (self.__class__.__name__, db))
        elif db > self.dbMaxAtt:
            print("%s: attenuation value %f out of range" %
                  (self.__class__.__name__, db))
        else:
            ret = int(np.round(db/self.dbStep))

        return ret

    def db2reg(self, db):
        reg = 0

        # Steps.
        reg |= self.db2step(db)

        # Address.
        reg |= (self.address << 8)

        return reg

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
        byte = []

        # Read command.
        byte.append(self.cmd_rd + 2*self.dev_addr)

        # Address.
        addr = self.reg2addr(reg)
        byte.append(addr)

        # Dummy byte for clocking data out.
        byte.append(0)

        return byte

    def reg_wr(self, reg="GPIO_REG", val=0):
        byte = []

        # Write command.
        byte.append(self.cmd_wr + 2*self.dev_addr)

        # Address.
        addr = self.reg2addr(reg)
        byte.append(addr)

        # Dummy byte for clocking data out.
        byte.append(val)

        return byte

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
        byte = []

        # Read command.
        byte.append(self.cmd_rd)

        # Address.
        addr = self.reg2addr(reg)
        byte.append(addr)

        # Dummy byte for clocking data out.
        byte.append(0)

        return byte

    def reg_wr(self, reg="CONFIG0_REG", val=0):
        byte = []

        # Write command.
        byte.append(self.cmd_wr)

        # Address.
        addr = self.reg2addr(reg)
        byte.append(addr)

        # Dummy byte for clocking data out.
        byte.append(val)

        return byte

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
        byte = []

        # Address.
        addr = self.reg2addr(reg)

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_rd << 3) | addr
        cmd = (cmd << 4)
        byte.append(cmd)

        # Dummy bytes for completing the command.
        # NOTE: another full, 24-bit transaction is needed to clock the register out (may be all 0s).
        byte.append(0)
        byte.append(0)

        return byte

    def reg_wr(self, reg="DAC_REG", val=0):
        byte = []

        # Address.
        addr = self.reg2addr(reg)

        # R/W bit +  address (upper 4 bits).
        cmd = (self.cmd_wr << 3) | addr
        cmd = (cmd << 4)

        val_high = val >> 16
        val_mid = (val >> 8) & 0xff
        val_low = val & 0xff

        # Append bytes.
        byte.append(cmd | val_high)
        byte.append(val_mid)
        byte.append(val_low)

        return byte

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
        reg = [self.pe.db2reg(db)]

        # Write value using spi.
        self.spi.send_receive_m(reg, self.ch_en, self.cs_t)

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
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # AD5791.
        self.ad = AD5781()

        # SPI.
        self.spi = spi_ip

        # CS.
        self.ch_en = ch_en
        self.cs_t = cs_t

        # All CS to high value.
        self.spi.SPI_SSR = 0xff

        # Initialize control register.
        self.write(reg="CTRL_REG", val=0x312)

        # Initialize to 0 volts.
        self.set_volt(0)

    def read(self, reg="DAC_REG"):
        # Read command.
        byte = self.ad.reg_rd(reg)
        reg = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

        # Another read with dummy data to allow clocking register out.
        byte = [0, 0, 0]
        reg = self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

        return reg

    def write(self, reg="DAC_REG", val=0):
        # Write command.
        byte = self.ad.reg_wr(reg, val)
        self.spi.send_receive_m(byte, self.ch_en, self.cs_t)

    def set_volt(self, volt=0):
        # Convert volts to register value.
        val = self.ad.volt2reg(volt)
        self.write(reg="DAC_REG", val=val)

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
        byte = []

        # Address.
        addr = self.reg2addr(reg)

        # Read command.
        cmd = self.cmd_rd | addr
        byte.append(cmd)

        # Dummy byte for clocking data out.
        byte.append(0)

        return byte

    def reg_wr(self, reg="GAIN_REG", val=0):
        byte = []

        # Address.
        addr = self.reg2addr(reg)

        # Read command.
        cmd = self.cmd_wr | addr
        byte.append(cmd)

        # Data.
        byte.append(val)

        return byte

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
    def __init__(self, ch, switches, attn_spi):
        # Channel number.
        self.ch = ch

        # Power switches.
        self.switches = switches

        # Attenuator.
        self.attn = attenuator(attn_spi, ch, le=[0])

        # Default to 30 dB attenuation.
        self.set_attn_db(30)

    # Set attenuator.
    def set_attn_db(self, db=0):
        self.attn.set_att(db)
        self.enable()

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
    def __init__(self, ch, switches, attn_spi, version=2):
        # Channel number.
        self.ch = ch

        # RF board version.
        self.version = version

        # RF input and power switches.
        self.switches = switches

        # Attenuators.
        self.attn = []
        self.attn.append(attenuator(attn_spi, ch, le=[1]))
        self.attn.append(attenuator(attn_spi, ch, le=[2]))

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
    def set_attn_db(self, attn=0, db=0):
        if attn < len(self.attn):
            self.attn[attn].set_att(db)
        else:
            print("%s: attenuator %d not in chain." %
                  (self.__class__.__name__, attn))

    def set_rf(self, att1, att2):
        self.rfsw_sel("RF")
        self.set_attn_db(attn=0, db=att1)
        self.set_attn_db(attn=1, db=att2)

    def set_dc(self):
        self.rfsw_sel("DC")

    def disable(self):
        self.rfsw_sel("OFF")
        self.set_attn_db(attn=0, db=31.75)
        self.set_attn_db(attn=1, db=31.75)



class RFQickSoc(QickSoc):
    """
    Overrides the __init__ method of QickSoc in order to add the drivers for the preproduction (V1) version of the RF board.
    Otherwise supports all the QickSoc functionality.
    """
    def __init__(self, bitfile, no_tproc=False, **kwargs):
        """
        A bitfile must always be provided, since the default bitstream will not work with the RF board.
        By default, re-initialize the clocks every time.
        This ensures that the LO output to the RF board is enabled.
        """
        super().__init__(bitfile=bitfile, clk_output=True, no_tproc=no_tproc, **kwargs)

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
        self.adcs = [adc_rf_ch(ii, self.switches, self.attn_spi) for ii in range(4)] + [adc_dc_ch(ii, self.switches, self.psf_spi, version=1) for ii in range(4,8)]
        
        # DAC channels.
        self.dacs = [dac_ch(ii, self.switches, self.attn_spi, version=1) for ii in range(8)]

        if not no_tproc:
            # Link gens/readouts to the corresponding RF board channels.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb = self.dacs[4*tile + block]
            for ro in self.readouts:
                tile, block = [int(a) for a in ro.adc]
                ro.rfb = self.adcs[2*tile + block]

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
            ADC channel (index in 'readouts' list)
        att : float
            Attenuation (0 to 31.75 dB)
        """
        self.readouts[ro_ch].rfb.set_attn_db(att)

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
        self.readouts[ro_ch].rfb.set_gain_db(gain)

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
        data = [addr + (1<<7), 0, 0]
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
        self.dac_bias = [dac_bias(self.dac_bias_spi, ch_en=ii) for ii in range(8)]

        # ADC channels.
        self.adcs = [adc_rf_ch(ii, self.switches, self.attn_spi) for ii in range(4)] + [adc_dc_ch(ii, self.switches, self.psf_spi) for ii in range(4,8)]

        # DAC channels.
        self.dacs = [dac_ch(ii, self.switches, self.attn_spi) for ii in range(8)]

        # Link RF channels to LOs.
        for adc in self.adcs[:4]: adc.lo = self.lo[0]
        for dac in self.dacs[:4]: dac.lo = self.lo[1]
        for dac in self.dacs[4:]: dac.lo = self.lo[2]

        if not no_tproc:
            # Link gens/readouts to the corresponding RF board channels.
            for gen in self.gens:
                tile, block = [int(a) for a in gen.dac]
                gen.rfb = self.dacs[4*tile + block]
            for ro in self.readouts:
                tile, block = [int(a) for a in ro.adc]
                ro.rfb = self.adcs[2*tile + block]

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
            return self.readouts[ro_ch].rfb.lo.freq
        raise RuntimeError("must specify gen_ch or ro_ch")

