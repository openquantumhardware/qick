import os
import fcntl
from ctypes import Structure, c_char, c_int, c_uint8, c_uint32, sizeof
from enum import Flag, auto
import logging

logger = logging.getLogger(__name__)

"""A pure-Python interface to the kernel GPIO API.
This provides only minimal functionality (reading and writing pins, printing chip and line info).
It is not compatible with the Python bindings to libgpiod or python3-gpiod.

QICK supports PYNQ OS versions that predate the "v2" GPIO API: PYNQ OS v2.7 uses kernel 5.4, v2 was introduced in 5.10.
So we use the deprecated "v1" API for compatibility.

This code should work on Xilinx RFSoC devices running PYNQ OS without adding any additional dependencies.
Compatibility with any other environment is not guaranteed.

Useful references:

    * https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/ioctl.h
    * https://www.kernel.org/doc/html/latest/userspace-api/gpio/chardev_v1.html
    * https://github.com/torvalds/linux/blob/v5.4/include/uapi/linux/gpio.h
    * https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/tree/bindings/python
    * https://github.com/hhk7734/python3-gpiod/tree/main/py_src/gpiod
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

# gpio v1 API from linux gpio.h (from kernel version 5.4, as used in PYNQ OS v2.7)
GPIO_MAX_NAME_SIZE = 32
GPIOHANDLES_MAX = 64

class GpioLineFlags(Flag):
    KERNEL = auto() # 1<<0 - line used by the kernel
    IS_OUT = auto() # 1<<1
    ACTIVE_LOW = auto() # 1<<2
    OPEN_DRAIN = auto() # 1<<3
    OPEN_SOURCE = auto() # 1<<4

class GpioHandleRequestFlags(Flag):
    INPUT = auto() # 1 << 0
    OUTPUT = auto() # 1 << 1
    ACTIVE_LOW = auto() # 1 << 2
    OPEN_DRAIN = auto() # 1 << 3
    OPEN_SOURCE = auto() # 1 << 4

class gpiochip_info(Structure):
    _fields_ = [
        ("name", c_char * GPIO_MAX_NAME_SIZE),
        ("label", c_char * GPIO_MAX_NAME_SIZE),
        ("lines", c_uint32),
    ]

class gpioline_info(Structure):
    _fields_ = [
        ("line_offset", c_uint32),
        ("flags", c_uint32),
        ("name", c_char * GPIO_MAX_NAME_SIZE),
        ("consumer", c_char * GPIO_MAX_NAME_SIZE),
    ]

class gpiohandle_request(Structure):
    _fields_ = [
        ("lineoffsets", c_uint32 * GPIOHANDLES_MAX),
        ("flags", c_uint32),
        ("default_values", c_uint8 * GPIOHANDLES_MAX),
        ("consumer_label", c_char * GPIO_MAX_NAME_SIZE),
        ("lines", c_uint32),
        ("fd", c_int),
    ]

class gpiohandle_data(Structure):
    _fields_ = [
        ("values", c_uint8 * GPIOHANDLES_MAX),
    ]

class Handle():
    """Utility class to hold and clean up a file descriptor.
    """
    def __init__(self, fd):
        self._fd = fd
        logger.info("opened fd %d" % (self._fd))

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        self.close()

    def close(self):
        logger.info("closing fd %d" % (self._fd))
        os.close(self._fd)

class Chip(Handle):
    """Encapsulates access to a GPIO chip.
    """
    CONSUMER = "QICK gpiod" # while we have an open request on a line, this string will show up in the line info

    def __init__(self, path):
        super().__init__(os.open(path, os.O_RDWR))

    def get_chip_info(self):
        """Returns a description string similar to what gpiodetect prints.
        """
        info = gpiochip_info()
        ioc = _IOC(_IOC_READ, 0xB4, 0x01, sizeof(gpiochip_info))
        fcntl.ioctl(self._fd, ioc, info)
        return "%s [%s] (%d lines)" % (info.name.decode(), info.label.decode(), info.lines)

    def get_line_info(self, line):
        """Returns a description string similar to what gpioinfo prints.
        """
        info = gpioline_info()
        info.line_offset=line
        ioc = _IOC(_IOC_READ | _IOC_WRITE, 0xB4, 0x02, sizeof(gpioline_info))
        fcntl.ioctl(self._fd, ioc, info)
        flags = GpioLineFlags(info.flags)
#         flags = GpioLineFlags(info.flags)
#         for i in list(GpioLineFlags):
#             if i in flags: print(i)
        name = '"%s"' % (info.name.decode())
        if name == '""': name = "unnamed"
        used = (GpioLineFlags.KERNEL in flags)
        direction = 'output' if GpioLineFlags.IS_OUT in flags else 'input'
        polarity = 'active-low' if GpioLineFlags.ACTIVE_LOW in flags else 'active-high'
        consumer = '"%s"' % (info.consumer.decode()) if used else 'unused'
        desc = [name, consumer, direction, polarity]
        if used: desc.append("[used]")
        return " ".join(desc)

    def request_lines_input(self, lines):
        """Open a request for read access to a list of lines.
        Note that this switches the lines to input mode.
        """
        req = gpiohandle_request()
        req.consumer_label = self.CONSUMER.encode()
        req.lines = len(lines)
        for i, line in enumerate(lines):
            req.lineoffsets[i] = line
        req.flags = GpioHandleRequestFlags.INPUT.value
        ioc = _IOC(_IOC_READ | _IOC_WRITE, 0xB4, 0x03, sizeof(gpiohandle_request))
        fcntl.ioctl(self._fd, ioc, req)
        return LineRequestInput(req.fd, len(lines))

    def request_lines_output(self, lines, default_values):
        """Open a request for write access to a list of lines, initializing them with the specified values.
        """
        req = gpiohandle_request()
        req.consumer_label = self.CONSUMER.encode()
        if len(lines) != len(default_values):
            raise RuntimeError("this request has %d lines and %d default values, list lengths must match" % (len(lines), len(default_values)))
        req.lines = len(lines)
        for i in range(len(lines)):
            req.lineoffsets[i] = lines[i]
            req.default_values[i] = default_values[i]
        req.flags = GpioHandleRequestFlags.OUTPUT.value
        ioc = _IOC(_IOC_READ | _IOC_WRITE, 0xB4, 0x03, sizeof(gpiohandle_request))
        fcntl.ioctl(self._fd, ioc, req)
        return LineRequestOutput(req.fd, len(lines))

    def read_lines(self, lines):
        """Read the current state of a list of lines.
        Note that this switches the lines to input mode.
        """
        with self.request_lines_input(lines) as req:
            return req.get_values()

    def write_lines(self, lines, values):
        """Set a list of lines to the specified values.

        Note that this immediately closes the line request, and the GPIO kernel API does not promise to keep a line driven after the request is closed.
        This does seem to work for the I2C port expanders on RFSoC boards, presumably because the port expander chip maintains its own state.
        """
        with self.request_lines_output(lines, values) as req:
            pass

class LineRequestInput(Handle):
    def __init__(self, fd, n):
        super().__init__(fd)
        self._n = n

    def get_values(self):
        data = gpiohandle_data()
        ioc = _IOC(_IOC_READ | _IOC_WRITE, 0xB4, 0x08, sizeof(gpiohandle_data))
        fcntl.ioctl(self._fd, ioc, data)
        return data.values[:self._n]

class LineRequestOutput(Handle):
    def __init__(self, fd, n):
        super().__init__(fd)
        self._n = n

    def set_values(self, values):
        if len(values)!=self._n:
            raise RuntimeError("this request has %d lines, but set_values() was given %d values" % (self._n, len(values)))
        data = gpiohandle_data()
        for i, val in enumerate(values):
            data.values[i] = val
        ioc = _IOC(_IOC_READ | _IOC_WRITE, 0xB4, 0x09, sizeof(gpiohandle_data))
        fcntl.ioctl(self._fd, ioc, data)

def read_gpio(path, lines):
    """Read the current state of a list of lines.
    Note that this switches the lines to input mode.

    Parameters
    ----------
    path : str
        path to GPIO chip device, e.g. "/dev/gpiochip0"
    lines : list of int
        lines to read

    Returns
    -------
    list of int
        state (0 or 1) of each line
    """
    with Chip(path) as chip:
        return chip.read_lines(lines)

def write_gpio(path, lines, values):
    """Set a list of lines to the specified values.

    Note that this immediately closes the line request, and the GPIO kernel API does not promise to keep a line driven after the request is closed.
    This does seem to work for the I2C port expanders on RFSoC boards, presumably because the port expander chip maintains its own state.

    Parameters
    ----------
    path : str
        path to GPIO chip device, e.g. "/dev/gpiochip0"
    lines : list of int
        lines to write
    values : list of int
        value (0 or 1) to set on each line
    """
    with Chip(path) as chip:
        chip.write_lines(lines, values)

