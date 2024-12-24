from pathlib import Path
import struct
import fcntl
import cffi

"""A pure-Python implementation of basic spidev functionality.
Reproduces a small subset of the py-spidev API.

This code should work on Xilinx RFSoC devices running PYNQ OS without adding any additional dependencies.
Compatibility with any other environment is not guaranteed.

Useful references:

    * https://www.kernel.org/doc/Documentation/spi/spidev
    * https://github.com/torvalds/linux/blob/master/include/uapi/linux/spi/spidev.h
    * https://github.com/doceme/py-spidev/blob/master/spidev_module.c
    * https://github.com/Xilinx/PYNQ/blob/master/sdbuild/packages/xrfclk/package/xrfclk/xrfclk.py
    * https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/ioctl.h
    * https://ep2020.europython.eu/media/conference/slides/7kfqf76-speak-python-with-devices.pdf
"""

# IOC encoding from linux asm-generic/ioctl.h
_IOC_NRBITS = 8
_IOC_TYPEBITS = 8

_IOC_SIZEBITS = 14
_IOC_DIRBITS = 2
_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = (_IOC_NRSHIFT + _IOC_NRBITS)
_IOC_SIZESHIFT = (_IOC_TYPESHIFT + _IOC_TYPEBITS)
_IOC_DIRSHIFT = (_IOC_SIZESHIFT + _IOC_SIZEBITS)

_IOC_NONE = 0
_IOC_WRITE = 1
_IOC_READ = 2

def _IOC(direction, ioctype, iocnr, size):
    return ((direction << _IOC_DIRSHIFT) 
            | (ioctype << _IOC_TYPESHIFT) 
            | (iocnr << _IOC_NRSHIFT) 
            | (size << _IOC_SIZESHIFT))


def spidev_desc(bus, device):
    """Look up properties of an SPI device. Based on Xilinx xrfclk _find_devices().
    """
    dev = Path('/sys/bus/spi/devices/spi%d.%d'%(bus, device))
    desc = {}
    desc['compatible'] = (dev / 'of_node' / 'compatible').read_text().strip('\x00').split(',')
    desc['num_bytes'] = int.from_bytes((dev / 'of_node' / 'num_bytes').read_bytes(), byteorder='big')
    return desc

def spidev_bind(bus, device):
    """Rebind the spidev driver. Based on Xilinx xrfclk _find_devices().
    """
    dev = Path('/sys/bus/spi/devices/spi%d.%d'%(bus, device))
    if (dev / 'driver').exists():                        
        (dev / 'driver' / 'unbind').write_text(dev.name) 
    (dev / 'driver_override').write_text('spidev')
    Path('/sys/bus/spi/drivers/spidev/bind').write_text(dev.name)

class SpiDev:
    """Implements the minimal set of py-spidev features needed by ipq-pynq-utils.
    """

    # constants and struct format from linux spi/spidev.h
    SPI_IOC_MAGIC = ord('k')
    SPI_IOCTL_MSG = 0
    SPI_IOCTL_BITS_PER_WORD = 3
    SPI_IOCTL_MAX_SPEED_HZ = 4
    XFER_FORMAT = '=QQIIHBBBBBB'

    def __init__(self, bus, device):
        self.file_obj = open('/dev/spidev%d.%d'%(bus, device), 'w+b', buffering=0)
        
    def __enter__(self):
        return self
    def __exit__(self, type, value, traceback):
        self.file_obj.close()
        
    def writebytes(self, msg):
        """Write to the SPI device.
        """
        self.file_obj.write(bytes(msg))
        
    def xfer(self, msg):
        """Do a single full-duplex transaction.
        """
        _ffi = cffi.FFI()
        
        n = len(msg)
        tx_buf = _ffi.new("char [%d]"%(n))
        rx_buf = _ffi.new("char [%d]"%(n))
        tx_buf[0:n] = msg

        xfer_bytes = struct.pack(self.XFER_FORMAT,
                                 int(_ffi.cast("uintptr_t", tx_buf)),
                                 int(_ffi.cast("uintptr_t", rx_buf)),
                                 n,0,0,0,0,0,0,0,0)
        ioc = _IOC(_IOC_WRITE, self.SPI_IOC_MAGIC, self.SPI_IOCTL_MSG, len(xfer_bytes))

        fcntl.ioctl(self.file_obj.fileno(), ioc, xfer_bytes)
        return _ffi.unpack(rx_buf, n)
    
    @property
    def bits_per_word(self):
        n = 1
        buf = bytearray(n)
        ioc = _IOC(_IOC_READ, self.SPI_IOC_MAGIC, self.SPI_IOCTL_BITS_PER_WORD, n)
        fcntl.ioctl(self.file_obj.fileno(), ioc, buf)
        return int.from_bytes(buf, byteorder='little')

    @bits_per_word.setter
    def bits_per_word(self, value):
        n = 1
        buf = value.to_bytes(length=n, byteorder='little')
        ioc = _IOC(_IOC_WRITE, self.SPI_IOC_MAGIC, self.SPI_IOCTL_BITS_PER_WORD, n)
        fcntl.ioctl(self.file_obj.fileno(), ioc, buf)

    @property
    def max_speed_hz(self):
        n = 4
        buf = bytearray(n)
        ioc = _IOC(_IOC_READ, self.SPI_IOC_MAGIC, self.SPI_IOCTL_MAX_SPEED_HZ, n)
        fcntl.ioctl(self.file_obj.fileno(), ioc, buf)
        return int.from_bytes(buf, byteorder='little')

    @max_speed_hz.setter
    def max_speed_hz(self, value):
        n = 4
        buf = value.to_bytes(length=n, byteorder='little')
        ioc = _IOC(_IOC_WRITE, self.SPI_IOC_MAGIC, self.SPI_IOCTL_MAX_SPEED_HZ, n)
        fcntl.ioctl(self.file_obj.fileno(), ioc, buf)
