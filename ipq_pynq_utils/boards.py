import spidev
import xrfdc
from .clock_models import CLK104
from . import utils

# Import compat-lib for python versions older than 3.10
if utils.python_version_lt("3.10.0"):
    from importlib_resources import files
else:
    from importlib.resources import files

"""
Board utilities module. This module is responsible for performing board-specific
opertions like configuration of the clock sources, clock alignment, multi-tile
synchronization and the likes.
"""

# For multi-tile synchronization the cffi.FFI instance of xrfdc is hijacked
# and populated with the missing cdefs in _XRFDC_CDEFS. Additionally, a bunch
# of constants are defined in the local context to be used for interaction with
# those cdefs.
_cdefs_loaded = False

XRFDC_MTS_SYSREF_DISABLE = 0
XRFDC_MTS_SYSREF_ENABLE = 1

XRFDC_MTS_SCAN_INIT = 0
XRFDC_MTS_SCAN_RELOAD = 1

XRFDC_MTS_OK = 0
XRFDC_MTS_NOT_SUPPORTED = 1
XRFDC_MTS_TIMEOUT = 2
XRFDC_MTS_MARKER_RUN = 4
XRFDC_MTS_MARKER_MISM = 8
XRFDC_MTS_DELAY_OVER = 16
XRFDC_MTS_TARGET_LOW = 32
XRFDC_MTS_IP_NOT_READY = 64
XRFDC_MTS_DTC_INVALID = 128
XRFDC_MTS_NOT_ENABLED = 512
XRFDC_MTS_SYSREF_GATE_ERROR = 2048
XRFDC_MTS_SYSREF_FREQ_NDONE = 4096
XRFDC_MTS_BAD_REF_TILE = 8192

XRFDC_MTS_DAC = None
XRFDC_MTS_ADC = None

class ZCU208Board:
    """
    The ZCU208 board is equipped with a ZU48DR and a CLK104 board as its clock source.
    To load the PLLs on the CLK104, three SPI devices need to be accessed which are
    made available by the operating system: /dev/spidev1.1 - /dev/spidev1.3. These
    are not directly connected spi devices, but rather through a multilplexed I2C bus
    and an I2C to SPI bridge.
    
    Registers of the SPI device are written by taking the 24-bit value from the register
    file (Which itself consists of a 16-bit address and a 8-bit register value),
    split them into a list of three bytes and write those consecutively on the spi bus.
    Ideally the SPI device expects a full 24-bit word to be written, but deals gracefully
    with that word being split up into three 8-bit words.
    
    The second function of the ZCU208Board class is to provide Multi-Tile synchronization
    of the dataconverter tiles. Note that compatible clocks must have been configured, MTS
    synchronization must have been enabled in the IP configurator and the PL SYSREF line
    must have been connected to the Dataconverter IP for MTS to work.
    As a short introduction, MTS works by aligning the dataconverters and digitial signal
    chains to a low-frequency SYSREF signal, which is a periodic signal < 10 MHz signal
    that's locked to the main PLLs, and should arrive at all relevant converters and
    chips simultaenously. This way digital delays can be measured and compensated, NCO
    phases can be reset and PLLs clock division ambigiuity can be eliminated by resetting
    at a leading edge of the sysref pulses. Because the alignment of the sysref signal
    is integral to this process, it *MUST* be generated with certain restrictions in mind,
    for more information see "SYSREF Signal Requirements" in "Zynq UltraScale+ RFSoC
    RF Data Converter v2.6 Gen 1/2/3 LogiCORE IP Product Guide".
    """
    
    def __init__(self, lmk_srcfile=None):
        global _cdefs_loaded,XRFDC_MTS_DAC,XRFDC_MTS_ADC
        
        self.spi_lmk = spidev.SpiDev(1, 1)
        self.spi_dac = spidev.SpiDev(1, 2)
        self.spi_adc = spidev.SpiDev(1, 3)

        for spi in [self.spi_lmk, self.spi_dac, self.spi_adc]:
            spi.bits_per_word = 8
            spi.max_speed_hz = 100000
        
        if not _cdefs_loaded:
            with files("ipq_pynq_utils").joinpath("data/xrfdc_cdefs.h").open() as f:
                xrfdc._ffi.cdef(f.read())
            _cdefs_loaded = True
        
        XRFDC_MTS_DAC = xrfdc._lib.XRFDC_DAC_TILE
        XRFDC_MTS_ADC = xrfdc._lib.XRFDC_ADC_TILE

        self.clk104 = CLK104(lmk_srcfile)
        
    def _parse_register_file(filename):
        with open(filename, "r") as f:
            lines = f.read().strip().split("\n")

        ret = []

        for line in lines:
            a,b = line.split("\t")
            data = int(b, 16)

            ret.append(data)

        return ret
    
    def _write_registers(spi, registers):
        for word in registers:
            data = [(word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]
            spi.writebytes(data)

    def _write_clk104_registers(self):
        lmk_regdump = self.clk104.get_register_dump()

    
    def configure_clocks(self, lmxdac, lmxadc):
        ZCU208Board._write_registers(self.spi_lmk, [0x000090] + self.clk104.get_register_dump())

        ZCU208Board._write_registers(self.spi_dac, ZCU208Board._parse_register_file(lmxdac))
        ZCU208Board._write_registers(self.spi_adc, ZCU208Board._parse_register_file(lmxadc))

    def print_clock_summary(self):
        print(f"Name            |  Frequency  | Enabled | Sysref Enabled")
        print( "----------------|-------------|---------|----------------")
        print(f"PLL2_FREQ       | {self.clk104.PLL2_FREQ:7.2f} MHz | True    |")
        print(f"AMS_SYSREF      | {self.clk104.SYSREF_FREQ:7.2f} MHz |         | {str(self.clk104.AMS_SYSREF.sysref_enable)}")
        print(f"SYSREF_FREQ     | {self.clk104.SYSREF_FREQ:7.2f} MHz |         | True")
        print(f"ADC_REFCLK      | {self.clk104.ADC_REFCLK.freq:7.2f} MHz | {str(self.clk104.ADC_REFCLK.enable):<7} | {str(self.clk104.ADC_REFCLK.sysref_enable):<7}")
        print(f"DAC_REFCLK      | {self.clk104.DAC_REFCLK.freq:7.2f} MHz | {str(self.clk104.DAC_REFCLK.enable):<7} | {str(self.clk104.DAC_REFCLK.sysref_enable):<7}")
        print(f"RF_PLL_ADC_REF  | {self.clk104.RF_PLL_ADC_REF.freq:7.2f} MHz | {str(self.clk104.RF_PLL_ADC_REF.enable):<7} | {str(self.clk104.RF_PLL_ADC_REF.sysref_enable):<7}")
        print(f"RF_PLL_DAC_REF  | {self.clk104.RF_PLL_DAC_REF.freq:7.2f} MHz | {str(self.clk104.RF_PLL_DAC_REF.enable):<7} | {str(self.clk104.RF_PLL_DAC_REF.sysref_enable):<7}")
        print(f"PL_CLK          | {self.clk104.PL_CLK.freq:7.2f} MHz | {str(self.clk104.PL_CLK.enable):<7} | {str(self.clk104.PL_CLK.sysref_enable):<7}")
    
    def perform_mts(self, rfdc, tile_type, tiles=0xf, target_latency=-1):
        """
        Perform multi-tile synchronization.
        
        rfdc: This is the xrfdc.RFdc object which is created as part of the overlay.
        tiles: A bitmap of tiles to perform synchronization on, where the zero-th bit refers to the first tile and so on.
               To synchronize the first three tiles, pass 0x7 (or 0b111).
        tile_type:   Whether to synchronize DACs (XRFDC_MTS_DAC) or ADCs (XRFDC_MTS_ADC).
        """
        
        sync_config = xrfdc._ffi.new("XRFdc_MultiConverter_Sync_Config*")

        ret = xrfdc._lib.XRFdc_MultiConverter_Init(sync_config, xrfdc._ffi.NULL, xrfdc._ffi.NULL, 0)

        sync_config.Tiles = tiles
        sync_config.Target_Latency = target_latency

        status_dac = xrfdc._lib.XRFdc_MultiConverter_Sync(rfdc._instance, tile_type, sync_config);
        if status_dac != XRFDC_MTS_OK:
            raise RuntimeError(f"Failed to perform MTS: {hex(status_dac)}")
        
        marker_delay = sync_config.Marker_Delay
        offsets = list(sync_config.Offset)
        latency = list(sync_config.Latency)
        
        del sync_config
                
        return marker_delay, offsets, latency
    
