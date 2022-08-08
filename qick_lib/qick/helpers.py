"""
Support functions.
"""
import numpy as np


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
