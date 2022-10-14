"""
Support functions.
"""
import numpy as np
import json
import base64
from collections import OrderedDict


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
    y = maxv * np.exp(-(x-mu)**2/si**2)
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
    gaus = maxv * np.exp(-(x-mu)**2/si**2)
    # derivative of the gaussian
    dgaus = -(x-mu)/(si**2)*gaus
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
    JSON encoder with support for numpy objects.
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
        return super().default(obj)

def progs2json(proglist):
    return json.dumps(proglist, cls=NpEncoder)

def json2progs(s):
    # be sure to read dicts back in order (only matters for Python <3.7)
    proglist = json.loads(s, object_pairs_hook=OrderedDict)

    for progdict in proglist:
        # tweak data structures that got screwed up by JSON:
        # in JSON, dict keys are always strings, so we must cast back to int
        progdict['gen_chs'] = OrderedDict([(int(k),v) for k,v in progdict['gen_chs'].items()])
        progdict['ro_chs'] = OrderedDict([(int(k),v) for k,v in progdict['ro_chs'].items()])
        # the envelope arrays need to be restored as numpy arrays with the proper type
        for iCh, pulsedict in enumerate(progdict['pulses']):
            for name, pulse in pulsedict.items():
                #pulse['data'] = np.array(pulse['data'], dtype=self._gen_mgrs[iCh].env_dtype)
                data, shape, dtype = pulse['data']
                pulse['data'] = np.frombuffer(base64.b64decode(data), dtype=np.dtype(dtype)).reshape(shape)
    return proglist


def trace_net(parser, blockname, portname):
    """
    Find the block and port that connect to this block and port.
    If you expect to only get one block+port as a result, you can assign the result to ((block, port),)

    :param parser: HWH parser object (from Overlay.parser, or BusParser)
    :param blockname: the IP block of interest
    :type blockname: string
    :param portname: the port we want to trace
    :type portname: string

    :return: a list of (block, port) pairs
    :rtype: list
    """

    fullport = blockname+"/"+portname
    # the net connected to this port
    netname = parser.pins[fullport]
    if netname == '__NOC__':
        return []
    # get the list of other ports on this net, discard the port we started at and ILA ports
    return [x.split('/') for x in parser.nets[netname] if x != fullport and 'system_ila_' not in x]


def get_fclk(parser, blockname, portname):
    """
    Find the frequency of a clock port.

    :param parser: HWH parser object (from Overlay.parser, or BusParser)
    :param blockname: the IP block of interest
    :type blockname: string
    :param portname: the port we want to trace
    :type portname: string

    :return: frequency in MHz
    :rtype: float
    """
    xmlpath = "./MODULES/MODULE[@FULLNAME='/{0}']/PORTS/PORT[@NAME='{1}']".format(
        blockname, portname)
    port = parser.root.find(xmlpath)
    return float(port.get('CLKFREQUENCY'))/1e6


class BusParser:
    def __init__(self, parser):
        """
        Matching all the buses in the modules from the HWH file.
        This is essentially a copy of the HWH parser's match_nets() and match_pins(),
        but working on buses instead of signals.

        In addition, there's a map from module names to module types.

        :param parser: HWH parser object (from Overlay.parser)
        """
        self.nets = {}
        self.pins = {}
        self.mod2type = {}
        for module in parser.root.findall('./MODULES/MODULE'):
            fullpath = module.get('FULLNAME').lstrip('/')
            self.mod2type[fullpath] = module.get('MODTYPE')
            for bus in module.findall('./BUSINTERFACES/BUSINTERFACE'):
                port = fullpath + '/' + bus.get('NAME')
                busname = bus.get('BUSNAME')
                self.pins[port] = busname
                if busname in self.nets:
                    self.nets[busname] |= set([port])
                else:
                    self.nets[busname] = set([port])
