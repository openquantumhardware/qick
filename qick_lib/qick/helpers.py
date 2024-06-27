"""
Support functions.
"""
from typing import Union, List
import numpy as np
import json
import base64
from collections import OrderedDict

def to_int(val, scale, quantize=1, parname=None, trunc=False):
    """Convert a parameter value from user units to ASM units.
    Normally this means converting from float to int.
    For the v2 tProcessor this can also convert QickSweep to QickSweepRaw.
    To avoid overflow, values are rounded towards zero using np.trunc().

    Parameters
    ----------
    val : float or QickSweep
        parameter value or sweep range
    scale : float
        conversion factor
    quantize : int
        rounding step for ASM value
    parname : str
        parameter type - only for sweeps
    trunc : bool
        round towards zero using np.trunc(), instead of to closest integer using np.round()

    Returns
    -------
    int or QickSweepRaw
        ASM value
    """
    if hasattr(val, 'to_int'):
        return val.to_int(scale, quantize=quantize, parname=parname, trunc=trunc)
    else:
        if trunc:
            return int(quantize * np.trunc(val*scale/quantize))
        else:
            return int(quantize * np.round(val*scale/quantize))

def check_bytes(val, length):
    """Test if a signed int will fit in the specified number of bytes.

    Parameters
    ----------
    val : int
        value to test
    length : int
        number of bytes

    Returns
    -------
    bool
        True if value will fit, False otherwise
    """
    try:
        int(val).to_bytes(length=length, byteorder='little', signed=True)
        return True
    except OverflowError:
        return False

def cosine(length=100, maxv=30000):
    """
    Create a numpy array containing a cosine shaped envelope function
    
    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of cosine flattop function
    :type maxv: float
    :return: Numpy array containing a cosine flattop function
    :rtype: array
    """
    x = np.linspace(0,2*np.pi,length)
    y = maxv*(1-np.cos(x))/2
    return y


def gauss(mu=0, si=25, length=100, maxv=30000):
    """
    Create a numpy array containing a Gaussian function

    :param mu: Mu (peak offset) of Gaussian
    :type mu: float
    :param sigma: Sigma (standard deviation) of Gaussian
    :type sigma: float
    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of Gaussian
    :type maxv: float
    :return: Numpy array containing a Gaussian function
    :rtype: array
    """
    x = np.arange(0, length)
    y = maxv * np.exp(-(x-mu)**2/(2*si**2))
    return y


def DRAG(mu, si, length, maxv, delta, alpha):
    """
    Create I and Q arrays for a DRAG pulse.
    Based on QubiC and Qiskit-Pulse implementations.

    :param mu: Mu (peak offset) of Gaussian
    :type mu: float
    :param si: Sigma (standard deviation) of Gaussian
    :type si: float
    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of Gaussian
    :type maxv: float
    :param delta: anharmonicity of the qubit (units of 1/sample time)
    :type delta: float
    :param alpha: alpha parameter of DRAG (order-1 scale factor)
    :type alpha: float
    :return: Numpy array with I and Q components of the DRAG pulse
    :rtype: array, array
    """
    x = np.arange(0, length)
    gaus = maxv * np.exp(-(x-mu)**2/(2*si**2))
    # derivative of the gaussian
    dgaus = -(x-mu)/(2*si**2)*gaus
    idata = gaus
    qdata = -1 * alpha * dgaus / delta
    return idata, qdata


def triang(length=100, maxv=30000):
    """
    Create a numpy array containing a triangle function

    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of triangle function
    :type maxv: float
    :return: Numpy array containing a triangle function
    :rtype: array
    """
    y = np.zeros(length)

    # if length is even, there are length//2 samples in the ramp
    # if length is odd, there are length//2 + 1 samples in the ramp
    halflength = (length + 1) // 2

    y1 = np.linspace(0, maxv, halflength)
    y[:halflength] = y1
    y[length//2:length] = np.flip(y1)
    return y

class NpEncoder(json.JSONEncoder):
    """
    JSON encoder with support for numpy objects and custom classes with to_dict methods.
    Taken from https://stackoverflow.com/questions/50916422/python-typeerror-object-of-type-int64-is-not-json-serializable
    """
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            return float(obj)
        if isinstance(obj, np.ndarray):
            # base64 is considerably more compact and faster to pack/unpack
            # return obj.tolist()
            return (base64.b64encode(obj.tobytes()).decode(), obj.shape, obj.dtype.str)
        if hasattr(obj, "to_dict"):
            return obj.to_dict()
        return super().default(obj)

def decode_array(json_array):
    """
    Convert a base64-encoded array back into numpy.
    """
    data, shape, dtype = json_array
    return np.frombuffer(base64.b64decode(data), dtype=np.dtype(dtype)).reshape(shape)

def progs2json(proglist):
    """Dump QICK programs to a JSON string.

    Parameters
    ----------
    proglist : list of dict
        A list of program dictionaries to dump.

    Returns
    -------
    str
        A JSON string.
    """
    return json.dumps(proglist, cls=NpEncoder)

def json2progs(s):
    """Read QICK programs from JSON.

    Parameters
    ----------
    s : file-like object or string
        A JSON file or JSON string.

    Returns
    -------
    list of dict
        A list of program dictionaries.
    """
    if hasattr(s, 'read'):
        # input is file-like, we should use json.load()
        # be sure to read dicts back in order (only matters for Python <3.7)
        proglist = json.load(s, object_pairs_hook=OrderedDict)
    else:
        # input is string or bytes
        # be sure to read dicts back in order (only matters for Python <3.7)
        proglist = json.loads(s, object_pairs_hook=OrderedDict)

    return proglist

def ch2list(ch: Union[List[int], int]) -> List[int]:
    """
    convert a channel number or a list of ch numbers to list of integers

    :param ch: channel number or list of channel numbers
    :return: list of channel number(s)
    """
    if ch is None:
        return []
    try:
        ch_list = [int(ch)]
    except TypeError:
        ch_list = ch
    return ch_list

def check_keys(keys, required, optional):
    """Check whether the keys defined for a pulse are supported and sufficient for this generator and pulse type.
    Raise an exception if there is a problem.

    Parameters
    ----------
    params : set-like
        Parameter keys defined for this pulse
    required : list
        Required keys (these must be present)
    optional : list
        Optional keys (these are not required, but may be present)
    """
    required = set(required)
    allowed = required | set(optional)
    defined = set(keys)
    if required - defined:
        raise RuntimeError("missing required pulse parameter(s)", required - defined)
    if defined - allowed:
        raise RuntimeError("unsupported pulse parameter(s)", defined - allowed)

def nqz(f, fs):
    """Compute the Nyquist zone of a given frequency.
    """
    return int(f/(fs/2) + 1)

def folded_freq(f, fs):
    """Compute the zone-1 Nyquist image of a given frequency.
    """
    f_nqz = nqz(f, fs)
    if f_nqz%2 == 0:
        f_folded = -f
    else:
        f_folded = f
    f_folded %= (fs/2)
    return f_folded

def nyquist_image(f, fs, nqz):
    """Compute the Nyquist image of a given frequency in the specified zone.
    """
    f_folded = folded_freq(f, fs)
    return -f_folded*((-1)**nqz) + fs*(nqz//2)
