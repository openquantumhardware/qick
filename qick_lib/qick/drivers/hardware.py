from qick.ip import SocIP
from qick.ipq_pynq_utils.ipq_pynq_utils import clock_models
import numpy as np
import time
from numbers import Integral
from operator import itemgetter
import logging

logger = logging.getLogger(__name__)

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

    @staticmethod
    def freq2steps(section, f, n=11, get_freqs=False):
        # state=0 and state=15 frequencies for each filter band, from data sheet
        BANDS = {'LPF':
                [
                    [ 2050,  3850],
                    [ 3350,  7250],
                    [ 7000, 13000],
                    [12550, 18850]
                    ],
                'HPF':
                [
                    [ 1750,  3550],
                    [ 3400,  7250],
                    [ 6600, 12600],
                    [12500, 19900]
                    ]
                }

        if f < 1000:
            raise ValueError("unexpectedly small filter frequency %f MHz: either you should be using bypass mode, or you are using units of GHz instead of MHz" % (f))
        freqs = np.concatenate([np.linspace(f0, f15, 16) for f0, f15 in BANDS[section]])
        sortlist = list(enumerate(freqs))
        sortlist.sort(key=lambda x: np.abs(x[1]-f))
        sortlist = sorted(sortlist[:n], key=itemgetter(1))
        logger.debug("%s, find %d steps and freqs closest to %f: %s" % (section, n, f, sortlist))

        if get_freqs:
            return sortlist
        best_steps, best_freqs = list(zip(*sortlist))
        return best_steps

    def _freq2step(self, f, section):
        if f<0: return -1
        return self.freq2steps(section, f, 1)[0]

    def set_filter_raw(self, hpf, lpf):
        """
        lpf, hpf: -1 for bypass, 0 through 63 to enable filter
        """
        if not isinstance(hpf, Integral):
            raise RuntimeError("hpf must be an integer, not %s" % (hpf))
        if not isinstance(lpf, Integral):
            raise RuntimeError("lpf must be an integer, not %s" % (hpf))

        if hpf < 0:
            hpf_band, hpf_state = 0, 0
        elif hpf > 63:
            raise RuntimeError("hpf must be negative (bypass) or 0-63, not %s" % (hpf))
        else:
            hpf_band = 1 + hpf//16
            hpf_state = hpf % 16

        if lpf < 0:
            lpf_band, lpf_state = 0, 0
        elif lpf > 63:
            raise RuntimeError("lpf must be negative (bypass) or 0-63, not %s" % (lpf))
        else:
            lpf_band = 1 + lpf//16
            lpf_state = lpf % 16

        sw = 0xC0 + (hpf_band<<3) + lpf_band
        filt_state = (hpf_state<<4) + lpf_state

        self.write_reg(reg="WR0_SW", value=sw)
        self.write_reg(reg="WR0_FILTER", value=filt_state)

    def set_filter(self, fc, bw, ftype):
        # Low-pass.
        if ftype == 'lowpass':
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            step_lpf = self._freq2step(f=fc, section="LPF")
            step_hpf = self._freq2step(f=-1, section="HPF")

        elif ftype == 'highpass':
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc))

            step_lpf = self._freq2step(f=-1, section="LPF")
            step_hpf = self._freq2step(f=fc, section="HPF")

        elif ftype == 'bandpass':
            f1 = fc-bw/2
            f2 = fc+bw/2
            logger.debug("{}: setting {} filter type, fc = {:.2f} GHz, bw = {:.2f} GHz.".format(self.__class__.__name__, ftype, fc, bw))

            step_lpf = self._freq2step(f=f2, section="LPF")
            step_hpf = self._freq2step(f=f1, section="HPF")

        elif ftype == 'bypass':
            logger.debug("{}: setting filter to bypass mode.".format(self.__class__.__name__))

            step_lpf = self._freq2step(f=-1, section="LPF")
            step_hpf = self._freq2step(f=-1, section="HPF")
    
        else:
            raise RuntimeError("%s: filter type %s not supported." % (self.__class__.__name__, ftype))

        self.set_filter_raw(step_hpf, step_lpf)

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
