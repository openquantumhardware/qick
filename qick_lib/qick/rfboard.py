import os
from .qick import SocIp, QickSoc
from .qick_asm import QickConfig
from pynq.overlay import Overlay, DefaultIP
from pynq.buffer import allocate
import xrfclk
import numpy as np
import time


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
        self.iq_switch = AxisDdsMrSwitch(dds_mr_switch)

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

        if outsel == "product":
            self.outsel = 0
        elif outsel == "dds":
            self.outsel = 1
        elif outsel == "envelope":
            self.outsel = 2
        else:
            print("AxisSignalGenV3Ctrl: %s output unknown" % outsel)

        if mode == "nsamp":
            self.mode = 0
        elif mode == "periodic":
            self.mode = 1
        else:
            print("AxisSignalGenV3Ctrl: %s mode unknown" % mode)

        if stdysel == "last":
            self.stdysel = 0
        elif stdysel == "zero":
            self.stdysel = 1
        else:
            print("AxisSignalGenV3Ctrl: %s stdysel unknown" % stdysel)

        # Write fifo..
        self.we = 1
        time.sleep(0.1)
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
            data_r = np.zeros(nr)
            for i in range(nr):
                data_r[i] = self.SPI_DRR.RX_Data
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
# All are used with address 0.


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
        byte.append(self.cmd_rd)

        # Address.
        addr = self.reg2addr(reg)
        byte.append(addr)

        # Dummy byte for clocking data out.
        byte.append(0)

        return byte

    def reg_wr(self, reg="GPIO_REG", val=0):
        byte = []

        # Write command.
        byte.append(self.cmd_wr)

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

    # Set attenuation function.
    def set_att(self, db):
        # Register value.
        reg = [self.pe.db2reg(db)]

        # Write value using spi.
        self.spi.send_receive_m(reg, self.ch_en, self.cs_t)

# Power, Switch and Fan.


class power_sw_fan:

    # Constructor.
    def __init__(self, spi_ip, ch_en, cs_t=""):
        # MCP23S08.
        self.mcp = MCP23S08()

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

        # Set all outputs to logic 1.
        byte = self.mcp.reg_wr("GPIO_REG", 0xff)
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
    def __init__(self, ch, attn_spi):
        # Channel number.
        self.ch = ch

        # Attenuator.
        self.attn = attenuator(attn_spi, ch, le=[0])

        # Default to 30 dB attenuation.
        self.set_attn_db(30)

    # Set attenuator.
    def set_attn_db(self, db=0):
        self.attn.set_att(db)

# Class to describe the ADC-DC channel chain.
class adc_dc_ch():
    # Constructor.
    def __init__(self, ch, gain_spi):
        # Channel number.
        self.ch = ch

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


# Class to describe the DAC channel chain.
class dac_ch():
    # Constructor.
    def __init__(self, ch, rfsw, attn_spi):
        # Channel number.
        self.ch = ch

        # RF Input Switch.
        self.rfsw = rfsw

        # Attenuators.
        self.attn = []
        self.attn.append(attenuator(attn_spi, ch, le=[1]))
        self.attn.append(attenuator(attn_spi, ch, le=[2]))

        # Default to 10 dB attenuation.
        self.set_attn_db(0, 10)
        self.set_attn_db(1, 10)

    # Switch selection.
    def rfsw_sel(self, sel="RF"):
        if sel == "RF":
            # Set logic one.
            self.rfsw.bits_set(bits=[self.ch])
        elif sel == "DC":
            # Set logic zero.
            self.rfsw.bits_reset(bits=[self.ch])
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


class RFQickSoc(QickSoc):
    """
    Overrides the __init__ method of QickSoc in order to add the RF board drivers.
    Otherwise supports all the QickSoc functionality.
    """
    ENABLE_LO_OUTPUT = True

    def __init__(self, bitfile=None, force_init_clks=True, ignore_version=True, **kwargs):
        """
        By default, re-initialize the clocks every time.
        This ensures that the LO output to the RF board is enabled.
        """
        super().__init__(bitfile=bitfile, force_init_clks=force_init_clks, ignore_version=ignore_version, **kwargs)

        self.rfb_config()

    def rfb_config(self):
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

        # ADC/DAC power enable, DAC RF input switch.
        self.adc_pwr = power_sw_fan(self.psf_spi, ch_en=0)
        self.dac_pwr = power_sw_fan(self.psf_spi, ch_en=1)
        self.dac_sw = power_sw_fan(self.psf_spi, ch_en=2)

        # LO Synthesizers.
        self.lo = []
        self.lo.append(lo_synth(self.lo_spi, le=[0]))
        self.lo.append(lo_synth(self.lo_spi, le=[1]))

        # DAC BIAS.
        self.dac_bias = []
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=0))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=1))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=2))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=3))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=4))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=5))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=6))
        self.dac_bias.append(dac_bias(self.dac_bias_spi, ch_en=7))

        # ADC channels.
        self.adcs = []
        for ii in range(4):
            self.adcs.append(adc_rf_ch(ii, self.attn_spi))
            
        for ii in range(4):
            self.adcs.append(adc_dc_ch(4+ii, self.psf_spi))
        
        # DAC channels.
        self.dacs = []
        for ii in range(8):            
            self.dacs.append(dac_ch(ii, self.dac_sw, self.attn_spi))  

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

    def rfb_set_genrf(self, gen_ch, att1, att2):
        """Configure an RF-board output channel for RF output.

        Parameters
        ----------
        gen_ch : int
            DAC channel (index in 'gens' list)
        att1 : float
            Attenuation for first stage (0-31.75 dB)
        att2 : float
            Attenuation for second stage (0-31.75 dB)
        """
        rfb_ch = self.gens[gen_ch].rfb
        rfb_ch.rfsw_sel("RF")
        rfb_ch.attn[0].set_att(att1)
        rfb_ch.attn[1].set_att(att2)

    def rfb_set_ro(self, ro_ch, att):
        """Configure an RF-board input channel.

        Parameters
        ----------
        ro_ch : int
            ADC channel (index in 'readouts' list)
        att : float
            Attenuation (0-31.75 dB)
        """
        rfb_ch = self.readouts[ro_ch].rfb
        rfb_ch.attn.set_att(att)

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

