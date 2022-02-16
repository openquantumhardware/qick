"""
Support functions.
"""
import numpy as np

def gauss(mu=0,si=25,length=100,maxv=30000):
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
    x = np.arange(0,length)
    y = 1/(2*np.pi*si**2)*np.exp(-(x-mu)**2/si**2)
    y = y/np.max(y)*maxv
    return y

def triang(length=100,maxv=30000):
    """
    Create a numpy array containing a triangle function

    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of triangle function
    :type maxv: float
    :return: Numpy array containing a triangle function
    :rtype: array
    """
    y1 = np.arange(0,length/2)
    y2 = np.flip(y1,0)
    y = np.concatenate((y1,y2))
    y = y/np.max(y)*maxv
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
    # get the list of other ports on this net, discard the port we started at and ILA ports
    return [x.split('/') for x in parser.nets[netname] if x!=fullport and 'system_ila_' not in x]

class BusParser:
    def __init__(self, parser):
        """
        Matching all the buses in the modules from the HWH file.
        This is essentially a copy of the HWH parser's match_nets() and match_pins(),
        but working on buses instead of signals.

        :param parser: HWH parser object (from Overlay.parser)
        """
        self.nets = {}
        self.pins = {}
        for module in parser.root.findall('./MODULES/MODULE'):
            fullpath = module.get('FULLNAME').lstrip('/')
            for bus in module.findall('./BUSINTERFACES/BUSINTERFACE'):
                port = fullpath + '/' + bus.get('NAME')
                busname = bus.get('BUSNAME')
                self.pins[port] = busname
                if busname in self.nets:
                    self.nets[busname] |= set([port])
                else:
                    self.nets[busname] = set([port])
