"""
Support classes for dealing with FPGA IP blocks.
"""
from pynq.overlay import DefaultIP
import numpy as np
import logging
from qick import obtain
from .qick_asm import DummyIp

class SocIp(DefaultIP, DummyIp):
    """
    Base class for firmware IP drivers.
    Registers are accessed as attributes.
    Configuration constants are accessed as dictionary items.
    """
    REGISTERS = {}

    def __init__(self, description):
        """
        Constructor method
        """
        DefaultIP.__init__(self, description)
        # this block's unique identifier in the firmware
        self.fullpath = description['fullpath']
        # this block's type
        self.type = description['type'].split(':')[-2]
        DummyIp.__init__(self, self.type, self.fullpath)
        # logger for messages associated with this block
        self.logger = logging.getLogger(self.type)

    def __setattr__(self, a, v):
        """
        Sets the arguments associated with a register

        :param a: Register specified by an offset value
        :type a: int
        :param v: value to be written
        :type v: int
        """
        try:
            index = self.REGISTERS[a]
            self.mmio.array[index] = np.uint32(obtain(v))
        except KeyError:
            super().__setattr__(a, v)

    def __getattr__(self, a):
        """
        Gets the arguments associated with a register

        :param a: register name
        :type a: str
        :return: Register arguments
        :rtype: *args object
        """
        try:
            index = self.REGISTERS[a]
            return self.mmio.array[index]
        except KeyError:
            return super().__getattribute__(a)

class QickMetadata:
    """
    Provides information about the connections between IP blocks, extracted from the HWH file.
    The HWH parser is very different between PYNQ 2.6/2.7 and 3.0+, so this class serves as a common interface.
    """
    def __init__(self, soc):
        # We will use the HWH parser to extract information about signal connections between blocks.
        # system graph object, if available
        self.systemgraph = None
        # root element of the HWH file
        self.xml = None
        # parsers for signals and busses, using system graph or XML as appropriate
        self.sigparser = None
        self.busparser = None

        if hasattr(soc, 'systemgraph'):
            # PYNQ 3.0 and higher have a "system graph"
            self.systemgraph = soc.systemgraph
            self.xml = soc.systemgraph._root
        else:
            self.sigparser = soc.parser
            # Since the HWH parser doesn't parse buses, we also make our own BusParser.
            self.xml = soc.parser.root
        # TODO: We shouldn't need to use BusParser for PYNQ 3.0, but we think there's a bug in how pynqmetadata handles axis_switch.
        self.busparser = BusParser(self.xml)

        self.timestamp = self.xml.get('TIMESTAMP')

    def trace_sig(self, blockname, portname):
        if self.systemgraph is not None:
            dests = self.systemgraph.blocks[blockname].ports[portname].destinations()
            result = []
            for port, block in dests.items():
                blockname = block.parent().name
                if blockname==self.systemgraph.name:
                    result.append([port])
                else:
                    result.append([blockname, port])
            return result

        return self._trace_net(self.sigparser, blockname, portname)

    def trace_bus(self, blockname, portname):
        return self._trace_net(self.busparser, blockname, portname)

    def _trace_net(self, parser, blockname, portname):
        """
        Find the block and port that connect to this block and port.
        If you expect to only get one block+port as a result, you can assign the result to ((block, port),)

        :param parser: HWH parser object (from Overlay.parser, or BusParser)
        :param blockname: the IP block of interest
        :type blockname: string
        :param portname: the port we want to trace
        :type portname: string

        :return: a list of [block, port] pairs, or just [port] for ports of the top-level design
        :rtype: list
        """
        fullport = blockname+"/"+portname
        # the net connected to this port
        netname = parser.pins[fullport]
        if netname == '__NOC__':
            return []
        # get the list of other ports on this net, discard the port we started at and ILA ports
        return [x.split('/') for x in parser.nets[netname] if x != fullport and 'system_ila_' not in x]

    def get_fclk(self, blockname, portname):
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
        port = self.xml.find(xmlpath)
        return float(port.get('CLKFREQUENCY'))/1e6

    def get_param(self, blockname, parname):
        """
        Find the value of an IP parameter. This works for all IPs, including those that do not show up in ip_dict because they're not addressable.

        :param parser: HWH parser object (from Overlay.parser, or BusParser)
        :param blockname: the IP block of interest
        :type blockname: string
        :param parname: the parameter of interest
        :type parname: string

        :return: parameter value
        :rtype: string
        """
        xmlpath = "./MODULES/MODULE[@FULLNAME='/{0}']/PARAMETERS/PARAMETER[@NAME='{1}']".format(
            blockname, parname)
        param = self.xml.find(xmlpath)
        return param.get('VALUE')

    def mod2type(self, blockname):
        if self.systemgraph is not None:
            return self.systemgraph.blocks[blockname].vlnv.name
        return self.busparser.mod2type[blockname]

class BusParser:
    """Parses the HWH XML file to extract information on the buses connecting IP blocks.
    """
    def __init__(self, root):
        """
        Matching all the buses in the modules from the HWH file.
        This is essentially a copy of the HWH parser's match_nets() and match_pins(),
        but working on buses instead of signals.

        In addition, there's a map from module names to module types.

        :param root: HWH XML tree (from Overlay.parser.root)
        """
        self.nets = {}
        self.pins = {}
        self.mod2type = {}
        for module in root.findall('./MODULES/MODULE'):
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


