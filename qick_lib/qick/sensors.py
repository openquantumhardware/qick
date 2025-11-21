import enum
from ctypes import cdll, Structure, POINTER, byref, c_short, c_int, c_uint, c_char, c_double, c_size_t, c_char_p
import logging

logger = logging.getLogger(__name__)

"""A pure-Python interface to libsensors v5.
Most but not all of the API is supported.

This is meant to be used to read the INA226 power monitor chips used on the RFSoC boards.

Initializing libsensors with sensors_init() takes a significant amount of time (~10 ms).
If you want to do repeated measurements you should therefore write your own code that reuses the Sensors object.

Useful references:
    * https://github.com/lm-sensors/lm-sensors/blob/master/lib/sensors.h
    * https://linux.die.net/man/3/libsensors
    * https://github.com/torvalds/linux/blob/master/drivers/hwmon/ina2xx.c
    * https://github.com/Xilinx/device-tree-xlnx/blob/master/device_tree/data/kernel_dtsi/2023.1/BOARD/zcu216-reva.dtsi
    * https://github.com/Xilinx/PYNQ/blob/master/pynq/pmbus.py
"""


class SensorsSubfeatureFlags(enum.Flag):
    MODE_R = enum.auto() # 1
    MODE_W = enum.auto() # 2
    COMPUTE_MAPPING = enum.auto() # 4

class SensorsFeatureType(enum.Enum):
    IN = 0x00
    FAN = 0x01
    TEMP = 0x02
    POWER = 0x03
    ENERGY = 0x04
    CURR = 0x05
    HUMIDITY = 0x06
    MAX_MAIN = enum.auto()
    VID = 0x10
    INTRUSION = 0x11
    MAX_OTHER = enum.auto()
    BEEP_ENABLE = 0x18
    MAX = enum.auto()
    UNKNOWN = 0x7fffffff

class SensorsSubfeatureType(enum.Enum):
    IN_INPUT = SensorsFeatureType.IN.value << 8
    IN_MIN = enum.auto()
    IN_MAX = enum.auto()
    IN_LCRIT = enum.auto()
    IN_CRIT = enum.auto()
    IN_AVERAGE = enum.auto()
    IN_LOWEST = enum.auto()
    IN_HIGHEST = enum.auto()
    IN_ALARM = (SensorsFeatureType.IN.value << 8) | 0x80
    IN_MIN_ALARM = enum.auto()
    IN_MAX_ALARM = enum.auto()
    IN_BEEP = enum.auto()
    IN_LCRIT_ALARM = enum.auto()
    IN_CRIT_ALARM = enum.auto()

    FAN_INPUT = SensorsFeatureType.FAN.value << 8
    FAN_MIN = enum.auto()
    FAN_MAX = enum.auto()
    FAN_ALARM = (SensorsFeatureType.FAN.value << 8) | 0x80
    FAN_FAULT = enum.auto()
    FAN_DIV = enum.auto()
    FAN_BEEP = enum.auto()
    FAN_PULSES = enum.auto()
    FAN_MIN_ALARM = enum.auto()
    FAN_MAX_ALARM = enum.auto()

    TEMP_INPUT = SensorsFeatureType.TEMP.value << 8
    TEMP_MAX = enum.auto()
    TEMP_MAX_HYST = enum.auto()
    TEMP_MIN = enum.auto()
    TEMP_CRIT = enum.auto()
    TEMP_CRIT_HYST = enum.auto()
    TEMP_LCRIT = enum.auto()
    TEMP_EMERGENCY = enum.auto()
    TEMP_EMERGENCY_HYST = enum.auto()
    TEMP_LOWEST = enum.auto()
    TEMP_HIGHEST = enum.auto()
    TEMP_MIN_HYST = enum.auto()
    TEMP_LCRIT_HYST = enum.auto()
    TEMP_ALARM = (SensorsFeatureType.TEMP.value << 8) | 0x80
    TEMP_MAX_ALARM = enum.auto()
    TEMP_MIN_ALARM = enum.auto()
    TEMP_CRIT_ALARM = enum.auto()
    TEMP_FAULT = enum.auto()
    TEMP_TYPE = enum.auto()
    TEMP_OFFSET = enum.auto()
    TEMP_BEEP = enum.auto()
    TEMP_EMERGENCY_ALARM = enum.auto()
    TEMP_LCRIT_ALARM = enum.auto()

    POWER_AVERAGE = SensorsFeatureType.POWER.value << 8
    POWER_AVERAGE_HIGHEST = enum.auto()
    POWER_AVERAGE_LOWEST = enum.auto()
    POWER_INPUT = enum.auto()
    POWER_INPUT_HIGHEST = enum.auto()
    POWER_INPUT_LOWEST = enum.auto()
    POWER_CAP = enum.auto()
    POWER_CAP_HYST = enum.auto()
    POWER_MAX = enum.auto()
    POWER_CRIT = enum.auto()
    POWER_MIN = enum.auto()
    POWER_LCRIT = enum.auto()
    POWER_AVERAGE_INTERVAL = (SensorsFeatureType.POWER.value << 8) | 0x80
    POWER_ALARM = enum.auto()
    POWER_CAP_ALARM = enum.auto()
    POWER_MAX_ALARM = enum.auto()
    POWER_CRIT_ALARM = enum.auto()
    POWER_MIN_ALARM = enum.auto()
    POWER_LCRIT_ALARM = enum.auto()

    ENERGY_INPUT = SensorsFeatureType.ENERGY.value << 8

    CURR_INPUT = SensorsFeatureType.CURR.value << 8
    CURR_MIN = enum.auto()
    CURR_MAX = enum.auto()
    CURR_LCRIT = enum.auto()
    CURR_CRIT = enum.auto()
    CURR_AVERAGE = enum.auto()
    CURR_LOWEST = enum.auto()
    CURR_HIGHEST = enum.auto()
    CURR_ALARM = (SensorsFeatureType.CURR.value << 8) | 0x80
    CURR_MIN_ALARM = enum.auto()
    CURR_MAX_ALARM = enum.auto()
    CURR_BEEP = enum.auto()
    CURR_LCRIT_ALARM = enum.auto()
    CURR_CRIT_ALARM = enum.auto()

    HUMIDITY_INPUT = SensorsFeatureType.HUMIDITY.value << 8

    VID = SensorsFeatureType.VID.value << 8

    INTRUSION_ALARM = SensorsFeatureType.INTRUSION.value << 8
    INTRUSION_BEEP = enum.auto()

    BEEP_ENABLE = SensorsFeatureType.BEEP_ENABLE.value << 8

    UNKNOWN = 0x7fffffff

class sensors_bus_id(Structure):
    _fields_ = [
        ("type", c_short),
        ("nr", c_short),
    ]

class sensors_chip_name(Structure):
    _fields_ = [
        ("prefix", c_char_p),
        ("bus", sensors_bus_id),
        ("addr", c_int),
        ("path", c_char_p),
    ]

class sensors_feature(Structure):
    _fields_ = [
        ("name", c_char_p),
        ("number", c_int),
        ("type", c_int), # SensorsFeatureType
        ("first_subfeature", c_int), # for libsensors internal use
        ("padding1", c_int), # for libsensors internal use
    ]

class sensors_subfeature(Structure):
    _fields_ = [
        ("name", c_char_p),
        ("number", c_int),
        ("type", c_int), # SensorsSubfeatureType
        ("mapping", c_int),
        ("flags", c_uint),
    ]

class Sensors():
    """Initializes and manages access to the libsensors library.

    Loading a custom (not in the default path) config file is not supported.
    """

    def __init__(self):
        self._lib = cdll.LoadLibrary("libsensors.so")

        self.sensors_init.restype = c_int

        self.sensors_cleanup.restype = None

        # int sensors_parse_chip_name(const char *orig_name, sensors_chip_name *res);
        self.sensors_parse_chip_name.restype = c_int
        self.sensors_parse_chip_name.argtypes = (c_char_p, POINTER(sensors_chip_name))

        # void sensors_free_chip_name(sensors_chip_name *chip);
        self.sensors_free_chip_name.restype = None
        self.sensors_free_chip_name.argtypes = (POINTER(sensors_chip_name),)

        # int sensors_snprintf_chip_name(char *str, size_t size, const sensors_chip_name *chip);
        self.sensors_snprintf_chip_name.restype = c_int
        self.sensors_snprintf_chip_name.argtypes = (c_char_p, c_size_t, POINTER(sensors_chip_name))

        # int sensors_get_value(const sensors_chip_name *name, int subfeat_nr, double *value);
        self.sensors_get_value.restype = c_int
        self.sensors_get_value.argtypes = (POINTER(sensors_chip_name), c_int, POINTER(c_double))

        # const sensors_chip_name *sensors_get_detected_chips(const sensors_chip_name *match, int *nr);
        self.sensors_get_detected_chips.restype = POINTER(sensors_chip_name)
        self.sensors_get_detected_chips.argtypes = (POINTER(sensors_chip_name), POINTER(c_int))

        # const sensors_feature * sensors_get_features(const sensors_chip_name *name, int *nr);
        self.sensors_get_features.restype = POINTER(sensors_feature)
        self.sensors_get_features.argtypes = (POINTER(sensors_chip_name), POINTER(c_int))

        # const sensors_subfeature * sensors_get_all_subfeatures(const sensors_chip_name *name, const sensors_feature *feature, int *nr);
        self.sensors_get_all_subfeatures.restype = POINTER(sensors_subfeature)
        self.sensors_get_all_subfeatures.argtypes = (POINTER(sensors_chip_name), POINTER(sensors_feature), POINTER(c_int))

        # const sensors_subfeature * sensors_get_subfeature(const sensors_chip_name *name, const sensors_feature *feature, sensors_subfeature_type type);
        self.sensors_get_subfeature.restype = POINTER(sensors_subfeature)
        self.sensors_get_subfeature.argtypes = (POINTER(sensors_chip_name), POINTER(sensors_feature), c_int)

        # const char *sensors_strerror(int errnum);
        self.sensors_strerror.restype = c_char_p
        self.sensors_strerror.argtypes = (c_int,)

        # sensors_init() doesn't clear any previously loaded config, so repeated sensors_init() will lead to duplicate entries for the same chip
        # the context manager should trigger cleanup, but let's do a cleanup before init to guard against user error?
        self.sensors_cleanup()
        assert self.sensors_init(None) == 0

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        self.close()

    def close(self):
        self.sensors_cleanup()

    def __getattr__(self, name):
        return getattr(self._lib, name)

    def get_chips(self, name=None):
        """Return an iterable list of chips matching the specified name (or, if no name is given, all chips).
        """
        return ChipIterator(self, name)

class ChipIterator():
    def __init__(self, lib, name=None):
        self._lib = lib
        if name is None:
            self.chip_temp = None
        else:
            self.chip_temp = sensors_chip_name()
            assert self._lib.sensors_parse_chip_name(name.encode(), byref(self.chip_temp)) == 0
        self.chip_nr = c_int(0)

    def __iter__(self):
        return self

    def __next__(self):
        chip = self._lib.sensors_get_detected_chips(self.chip_temp, byref(self.chip_nr))
        if not chip:
            if self.chip_temp is not None:
                self._lib.sensors_free_chip_name(self.chip_temp)
            raise StopIteration
        logger.info("chip_nr %d" % (self.chip_nr.value))
        return SensorsChip(self._lib, chip)

class SensorsChip():
    def __init__(self, lib, chip):
        self._lib = lib
        self.chip = chip

    @property
    def prefix(self):
        return self.chip.contents.prefix.decode()

    @property
    def path(self):
        return self.chip.contents.path.decode()

    @property
    def addr(self):
        return self.chip.contents.addr

    def get_features(self):
        """Return an iterable list of this chip's features.
        """
        return FeatureIterator(self._lib, self.chip)

class FeatureIterator():
    def __init__(self, lib, chip):
        self._lib = lib
        self.chip = chip
        self.feature_nr = c_int(0)

    def __iter__(self):
        return self

    def __next__(self):
        feature = self._lib.sensors_get_features(self.chip, byref(self.feature_nr))
        if not feature:
            raise StopIteration
        logger.info("feature_nr %d" % (self.feature_nr.value))
        return SensorsFeature(self._lib, self.chip, feature)

class SensorsFeature():
    def __init__(self, lib, chip, feature):
        self._lib = lib
        self.chip = chip
        self.feature = feature

    @property
    def name(self):
        return self.feature.contents.name.decode()

    @property
    def number(self):
        return self.feature.contents.number

    @property
    def type(self):
        return SensorsFeatureType(self.feature.contents.type)

    def get_subfeature(self, subfeaturetype=None):
        """Return the subfeature of the given type (if no type is given, return the input subfeature).
        """
        if subfeaturetype is None:
            subfeaturetype = SensorsSubfeatureType[self.type.name + "_INPUT"]
        subfeature = self._lib.sensors_get_subfeature(self.chip, self.feature, subfeaturetype.value)
        return Subfeature(self._lib, self.chip, subfeature)

    def get_value(self):
        """Read and return the current value of this feature's input.
        """
        return self.get_subfeature().get_value()

class Subfeature():
    def __init__(self, lib, chip, subfeature):
        self._lib = lib
        self.chip = chip
        self.subfeature = subfeature

    @property
    def name(self):
        return self.subfeature.contents.name.decode()

    @property
    def number(self):
        return self.subfeature.contents.number

    @property
    def type(self):
        return SensorsSubfeatureType(self.subfeature.contents.type)

    @property
    def mapping(self):
        return self.subfeature.contents.mapping

    @property
    def flags(self):
        return SensorsSubfeatureFlags(self.subfeature.contents.flags)

    def get_value(self):
        """Read and return the current value of this subfeature.
        """
        value = c_double()
        assert self._lib.sensors_get_value(self.chip, self.number, byref(value)) == 0
        return value.value

def read_sensor(chipname, variable):
    """Read the current value of a single sensor input.
    The chip is assumed to be the INA226 power monitor chip.

    Parameters
    ----------
    chipname : str
        chip name as printed by the `sensors` command, e.g. "ina226_dac_avtt-isa-0000"
    variable : str
        "shunt_voltage", "bus_voltage", "power", "current"
        These map to the "in1", "in2", "power1", "curr1" features of the INA226 chip.

    Returns
    -------
    float
        value in units of V, W, or A
    """
    variables = {
        'shunt_voltage': 'in1',
        'bus_voltage': 'in2',
        'power': 'power1',
        'current': 'curr1',
    }
    featurename = variables[variable]

    with Sensors() as s:
        for chip in s.get_chips(chipname):
            for feature in chip.get_features():
                if feature.name != featurename:
                    continue
                value = feature.get_value()
                return value

def print_sensors(chipname=None):
    """Print all values for a specified chip or (if none is specified) all chips, similar to the `sensors` utility.

    Parameters
    ----------
    chipname : str or None
        chip name as printed by the `sensors` command, e.g. "ina226_dac_avtt-isa-0000"
    """
    units = {
        SensorsFeatureType.IN: 'V',
        SensorsFeatureType.POWER: 'W',
        SensorsFeatureType.CURR: 'A',
    }
    with Sensors() as s:
        for chip in s.get_chips(chipname):
            print(chip.prefix, chip.path)
            for feature in chip.get_features():
                value = feature.get_value()
                unit = units[feature.type]
                if value < 1.0:
                    value *= 1000
                    unit = 'm'+unit
                print("%s:\t% 8.3f %s"% (feature.name, value, unit))

