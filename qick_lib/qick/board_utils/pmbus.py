import os
import fcntl, pathlib
from ctypes import cdll, c_int32, c_ubyte, c_uint16
import logging

logger = logging.getLogger(__name__)

# IRPS5401 datasheet: https://www.infineon.com/assets/row/public/documents/24/49/infineon-irps5401m-datasheet-en.pdf
# Infineon UN0049 (PMBus command set for IRPS5401): https://community.infineon.com/gfawx74859/attachments/gfawx74859/powermanagement/4980/1/UN0049-Rocky-V2.2%20(1).pdf
# https://docs.kernel.org/i2c/dev-interface.html

# ioctl numbers for i2c kernel interface
I2C_SLAVE = 0x0703

# PMBus register numbers
PMBUS_PAGE = 0x0
PMBUS_VOUT_MODE = 0x20
PMBUS_VOUT_COMMAND = 0x21

_libi2c = cdll.LoadLibrary("libi2c.so")

# extern __s32 i2c_smbus_read_byte_data(int file, __u8 command);
_libi2c.i2c_smbus_read_byte_data.restype = c_int32
_libi2c.i2c_smbus_read_byte_data.argtypes = (c_int32, c_ubyte)
# extern __s32 i2c_smbus_write_byte_data(int file, __u8 command, __u8 value);
_libi2c.i2c_smbus_write_byte_data.restype = c_int32
_libi2c.i2c_smbus_write_byte_data.argtypes = (c_int32, c_ubyte, c_ubyte)
# extern __s32 i2c_smbus_read_word_data(int file, __u8 command);
_libi2c.i2c_smbus_read_word_data.restype = c_int32
_libi2c.i2c_smbus_read_word_data.argtypes = (c_int32, c_ubyte)
# extern __s32 i2c_smbus_write_word_data(int file, __u8 command, __u16 value);
_libi2c.i2c_smbus_write_word_data.restype = c_int32
_libi2c.i2c_smbus_write_word_data.argtypes = (c_int32, c_ubyte, c_uint16)

class IRPS5401():
    def __init__(self, busnum, devnum):
        self._devname = '%d-%04x'%(busnum, devnum)
        dev = pathlib.Path('/sys/bus/i2c/devices/%s'%(self._devname))
        if (dev / 'driver').exists():
            logger.debug("unbinding driver from I2C device %s" % (self._devname))
            (dev / 'driver' / 'unbind').write_text(self._devname)

        self._fd = os.open('/dev/i2c-%d'%(busnum), os.O_RDWR)
        logger.debug("opened fd %d" % (self._fd))
        assert fcntl.ioctl(self._fd, I2C_SLAVE, devnum) >= 0

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        self.close()

    def close(self):
        logger.debug("closing fd %d" % (self._fd))
        os.close(self._fd)
        logger.debug("binding pmbus driver to I2C device %s" % (self._devname))
        pathlib.Path('/sys/bus/i2c/drivers/pmbus/bind').write_text(self._devname)

    def _set_page(self, pagenum):
        """Set the page (switching outputs A through D are pages 0-3, the LDO output is page 4)
        """
        assert _libi2c.i2c_smbus_write_byte_data(self._fd, PMBUS_PAGE, pagenum) == 0

    def _get_scale(self):
        """Return the voltage scale for the current page.
        """
        x = _libi2c.i2c_smbus_read_byte_data(self._fd, PMBUS_VOUT_MODE)
        assert (x >> 5) == 0 # mode (high 3 bits) should always be 0b000 (linear)
        # the exponent is in the bottom 5 bits, two's complement format
        e = x & ((1 << 5) - 1)
        if (e & (1 << 4)) != 0:
            e -= (1 << 5)
        return e

    def get_vout(self, pagenum):
        """Return the voltage setpoint for the specified page.
        """
        self._set_page(pagenum)
        e = self._get_scale()
        return _libi2c.i2c_smbus_read_word_data(self._fd, PMBUS_VOUT_COMMAND) * 2**e

    def set_vout(self, pagenum, val):
        """Set the voltage setpoint for the specified page.
        """
        self._set_page(pagenum)
        logger.debug("setting page %d vout to %f V" % (pagenum, val))
        e = self._get_scale()
        x = round(val / 2**e)
        assert _libi2c.i2c_smbus_write_word_data(self._fd, PMBUS_VOUT_COMMAND, x) == 0

def pmbus_set_vout(busnum, devnum, pagenum, val):
    with IRPS5401(busnum, devnum) as d:
        logger.debug("current value of page %d vout = %f V" % (pagenum, d.get_vout(pagenum=pagenum)))
        return d.set_vout(pagenum=pagenum, val=val)
