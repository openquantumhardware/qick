import os
import logging
from .pmbus import pmbus_set_vout
from .sensors import read_dac_avtt, print_sensors, read_sensor
from .gpio import read_gpio, write_gpio

logger = logging.getLogger(__name__)

def irps_busnum():
    """The physical I2C bus connectivity to the IRPS5401 chips is the same for the ZCU111 and ZCU216:
    I2C bus 0 -> mux (PCA9544A) with address 0x75 -> mux channel 2.
    The index for the resulting logical I2C bus is not always the same.
    
    This uses the method described in https://docs.kernel.org/i2c/i2c-sysfs.html to find the logical bus number.
    """
    buspath = os.readlink('/sys/bus/i2c/devices/i2c-0/0-0075/channel-2')
    # buspath is of the form "../i2c-4"
    return int(buspath.split('-')[-1])

def read_dac_avtt():
    board = os.environ['BOARD']

    if board=='ZCU111':
        devnum = 0x45
        busnum = irps_busnum()
        return read_sensor("irps5401-i2c-%d-%x"%(busnum, devnum), "in3")
    elif board in ['ZCU208', 'ZCU216']:
        return read_sensor("ina226_dac_avtt-isa-0000", "in2")
    elif board == 'RFSoC4x2':
        devnum = 0x47
        busnum = 0
        return read_sensor("ina220-i2c-%d-%x"%(busnum, devnum), "in1")
    else:
        raise RuntimeError("board %s is not recognized" % (board))

def control_fan(mode):
    """'auto' or 'max'
    """
    board = os.environ['BOARD']
    gpio_vals = {
        'auto': 0,
        'max': 1,
    }
    if mode not in gpio_vals:
        raise RuntimeError("control_fan() mode must be 'auto' or 'max', not %s" % (mode))

    if board == 'ZCU111':
        ch = 1 # the open-drain FANFAIL output and the FULLSPD input are both wired to this pin, driving it high
    elif board in ['ZCU208', 'ZCU216']:
        ch = 7
    elif board == 'RFSoC4x2':
        raise RuntimeError("RFSoC4x2 does not support fan control (it's always on auto)")
    else:
        raise RuntimeError("board %s is not recognized" % (board))
    write_gpio('/dev/gpiochip2', [ch], [gpio_vals[mode]])
        
def set_dac_avtt(val):
    board = os.environ['BOARD']
    if val not in [2.5, 3.0]:
        raise RuntimeError("set_dac_avtt() val must be 2.5 or 3.0, not %s" % (val))
    if board == 'ZCU111':
        busnum = irps_busnum()
        pmbus_set_vout(busnum, 0x45, 1, val)
    elif board in ['ZCU208', 'ZCU216']:
        gpio_vals = {
            2.5: 0,
            3.0: 1,
        }
        write_gpio('/dev/gpiochip2', [3], [gpio_vals[val]])
    elif board == 'RFSoC4x2':
        raise RuntimeError("RFSoC4x2 does not support DAC_AVTT control (it's always on 2.5 V)")
    else:
        raise RuntimeError("board %s is not recognized" % (board))
