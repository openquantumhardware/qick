"""
Support classes for dealing with FPGA IP blocks.
"""
from pynq.overlay import DefaultIP
import numpy as np
import logging
from qick import obtain

class DummyIP:
    """Dummy superclass for firmware IP blocks without register access (i.e. that don't inherit from SocIP or DefaultIP).
    Those classes should inherit from (QickIP, DummyIP) in that order.
    THis ensures that this class is last in the method resolution order.

    The purpose of this class is to eat the ``description`` parameter before the MRO reaches ``object.__init__()``.
    Inspired by https://stackoverflow.com/questions/74350679/python-mixins-how-to-deal-with-args-kwargs-when-calling-super
    """
    def __init__(self, description):
        super().__init__()

class QickIP:
    """Stores the configuration constants for a firmware IP block.
    Configuration constants are accessed as dictionary items.
    """
    def __init__(self, description):
        # config dictionary for QickConfig
        self._cfg = {}
        # this block's type
        self.cfg['type'] = description['type'].split(':')[-2]
        # this block's unique identifier in the firmware
        self.cfg['fullpath'] = description['fullpath']
        # logger for messages associated with this block
        self.logger = logging.getLogger(self['type'])

        super().__init__(description)

    @property
    def cfg(self):
        return self._cfg

    def __getitem__(self, key):
        return self._cfg[key]

    def configure_connections(self, soc):
        """Use the HWH metadata to figure out what connects to this IP block.

        Parameters
        ----------
        soc : QickSoc
            The overlay object, used to look up metadata and dereference driver names.
        """
        self.cfg['revision'] = soc.metadata.mod2rev(self['fullpath'])
        self.cfg['version'] = soc.metadata.mod2version(self['fullpath'])

class SocIP(QickIP, DefaultIP):
    """
    Base class for firmware IP drivers (classes that provide access to IP registers).
    Registers are accessed as attributes.

    Classes that extend a Xilinx driver will inherit from both this class and the Xilinx class.
    They should inherit from (SocIP, XilinxDriver) in that order.
    This ensures that DefaultIP (which does not support cooperative multiple inheritance) is last in the method resolution order.
    """

    def __init__(self, description):
        # this block's register map: to be defined in _init_config()
        self.REGISTERS = {}

        super().__init__(description)

        self._init_config(description)
        self._init_firmware()

    def _init_config(self, description):
        """
        Read the IP description and fill the driver's config dictionary.
        Define the register map.
        """
        pass

    def _init_firmware(self):
        """
        Do any initial configuration of the IP.
        """
        pass

    def __setattr__(self, a, v):
        """
        Sets the arguments associated with a register

        :param a: Register specified by an offset value
        :type a: int
        :param v: value to be written
        :type v: int
        """
        # don't try to index into self.REGISTERS if we're trying to access self.REGISTERS or self.REGISTERS has not yet been initialized
        if a!='REGISTERS' and hasattr(self, 'REGISTERS') and a in self.REGISTERS:
            index = self.REGISTERS[a]
            self.mmio.array[index] = np.uint32(obtain(v))
        else:
            super().__setattr__(a, v)

    def __getattr__(self, a):
        """
        Gets the arguments associated with a register

        :param a: register name
        :type a: str
        :return: Register arguments
        :rtype: *args object
        """
        if a!='REGISTERS' and hasattr(self, 'REGISTERS') and a in self.REGISTERS:
            index = self.REGISTERS[a]
            return self.mmio.array[index]
        else:
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
        # QIckSoc object, for getting RFDC clock freqs
        self.soc = soc

        if hasattr(soc, 'systemgraph'):
            # PYNQ 3.0 and higher have a "system graph"
            # this contains much of the information we need, but we don't use it because it has various quirks and we want to maintain compatibility with PYNQ 2.6/2.7
            self.systemgraph = soc.systemgraph
            self.xml = soc.systemgraph._root
        else:
            self.xml = soc.parser.root

        # parsers for signals and busses
        self.sigparser = SigParser(self.xml)
        # TODO: We shouldn't need to use BusParser for PYNQ 3.0, but we think there's a bug in how pynqmetadata handles axis_switch.
        self.busparser = BusParser(self.xml)

        # info for IP blocks - this is largely the same information available in ip_dict at driver initialization, but includes IPs without AXI interfaces.
        self.modinfo = {}
        for module in self.xml.findall('./MODULES/MODULE'):
            fullpath = module.get('FULLNAME').lstrip('/')
            info = {'params':{}}
            info['type'] = module.get('MODTYPE')
            info['version'] = module.get('HWVERSION')
            info['revision'] = int(module.get('COREREVISION'))
            params = {}
            for param in module.findall('./PARAMETERS/PARAMETER'):
                info['params'][param.get('NAME')] = param.get('VALUE')
            self.modinfo[fullpath] = info

        # firmware build time
        self.timestamp = self.xml.get('TIMESTAMP')

    def get_systemgraph_block(self, blockname):
        return self.systemgraph.blocks[blockname.replace('/','_')]

    def trace_sig(self, blockname, portname):
        return self._trace_net(self.sigparser, blockname, portname)

    def trace_bus(self, blockname, portname):
        return self._trace_net(self.busparser, blockname, portname)

    def _trace_net(self, parser, blockname, portname):
        """
        Find the block and port that connect to this block and port.
        If you expect to only get one block+port as a result, you can assign the result to ((block, port),)

        :param parser: HWH parser object (from Overlay.parser, or BusParser)
        :param blockname: the IP block of interest
        :type blockname: str
        :param portname: the port we want to trace
        :type portname: str

        :return: a list of [block, port] pairs, or just [port] for ports of the top-level design
        :rtype: list
        """
        fullport = blockname+"/"+portname
        # the net connected to this port
        netname = parser.pins[fullport]
        if netname == '__NOC__':
            return []
        # get the list of other ports on this net, discard the port we started at and ILA ports
        return [x.rsplit('/', maxsplit=1) for x in parser.nets[netname] if x != fullport and 'system_ila_' not in x]

    def get_fclk(self, blockname, portname):
        """
        Find the frequency of a clock port.
        This returns whatever value is in the HWH file, and does not reflect software changes to the frequency after the bitstream was loaded.

        :param parser: HWH parser object (from Overlay.parser, or BusParser)
        :param blockname: the IP block of interest
        :type blockname: str
        :param portname: the port we want to trace
        :type portname: str

        :return: frequency in MHz
        :rtype: float
        """
        return self.sigparser.freqs[blockname + '/' + portname]/1e6

    def get_param(self, blockname, parname):
        """
        Find the value of an IP parameter. This works for all IPs, including those that do not show up in ip_dict because they're not addressable.

        :param parser: HWH parser object (from Overlay.parser, or BusParser)
        :param blockname: the IP block of interest
        :type blockname: str
        :param parname: the parameter of interest
        :type parname: str

        :return: parameter value
        :rtype: str
        """
        return self.modinfo[blockname]['params'][parname]

    def mod2type(self, blockname):
        return self.modinfo[blockname]['type']

    def mod2version(self, blockname):
        return self.modinfo[blockname]['version']

    def mod2rev(self, blockname):
        return self.modinfo[blockname]['revision']

    def trace_back(self, start_block, start_port, goal_types):
        """Follow the AXI-Stream bus backwards from a given block and port.
        Raise an error if none of the requested IP types is found.
        Return None if we run into an unconnected input port.

        Parameters
        ----------
        start_block : str
            The fullpath for the block to start tracing from.
        start_port : str
            The name of the input port to start tracing from,
        goal_types : list of str
            IP types that we're interested in.

        Returns
        -------
        str
            The fullpath for the block we found.
        str
            The output port on the block we found.
        str
            The IP type we found.
        """
        next_block = start_block
        next_port = start_port
        while True:
            trace_result = self.trace_bus(next_block, next_port)
            # if we hit an unconnected port, return False
            if len(trace_result)==0:
                return None
            ((next_block, port),) = trace_result
            next_type = self.mod2type(next_block)
            if next_type in goal_types:
                return (next_block, port, next_type)
            elif next_type in ["axis_clock_converter", "axis_dwidth_converter", "axis_register_slice", "axis_broadcaster"]:
                next_port = 'S_AXIS'
            elif next_type == "axis_cdcsync_v1":
                # port name is of the form 'm4_axis' - follow corresponding input 's4_axis'
                next_port = 's'+port[1:]
            elif next_type == "sg_translator":
                next_port = 's_tproc_axis'
            elif next_type == "axis_resampler_2x1_v1":
                next_port = 's_axis'
            else:
                raise RuntimeError("failed to trace back from %s - unrecognized IP block %s" % (start_block, next_block))

    def trace_forward(self, start_block, start_port, goal_types):
        """Follow the AXI-Stream bus forwards from a given block and port.
        If a broadcaster is encountered, follow all outputs.
        Raise an error if ~=1 matching block is found.

        Parameters
        ----------
        start_block : str
            The fullpath for the block to start tracing from.
        start_port : str
            The name of the output port to start itracing from,
        goal_types : list of str
            IP types that we're interested in.

        Returns
        -------
        str
            The fullpath for the block we found.
        str
            The input port on the block we found.
        str
            The IP type we found.
        """
        to_check = [(start_block, start_port)]
        found = []
        dead_ends = []

        while to_check:
            block, port = to_check.pop(0)
            ((block, port),) = self.trace_bus(block, port)
            blocktype = self.mod2type(block)
            if blocktype in goal_types:
                found.append((block, port, blocktype))
            elif blocktype == "axis_broadcaster":
                for iOut in range(int(self.get_param(block, 'NUM_MI'))):
                    to_check.append((block, "M%02d_AXIS" % (iOut)))
            elif blocktype == "axis_clock_converter":
                to_check.append((block, "M_AXIS"))
            elif blocktype == "axis_register_slice":
                to_check.append((block, "M_AXIS"))
            elif blocktype == "axis_register_slice_nb":
                to_check.append((block, "m_axis"))
            else:
                dead_ends.append(block)
        if len(found) != 1:
            raise RuntimeError("traced forward from %s for one block of type %s, but found %s (and dead ends %s)" % (start_block, goal_types, found, dead_ends))
        return found[0]

    def _analyze_clkwiz(self, blockname):
        """Compute the range of valid input frequencies to a clocking wizard, based on the VCO range.
        """
        # determine whether we're using an MMCM or PLL
        primitive = self.get_param(blockname, 'PRIMITIVE')
        if primitive == 'Auto':
            primitive = self.get_param(blockname, 'AUTO_PRIMITIVE')
        # grab the relevant mult/divide factors
        if primitive == 'MMCM':
            div = float(self.get_param(blockname, 'MMCM_DIVCLK_DIVIDE'))
            mult = float(self.get_param(blockname, 'MMCM_CLKFBOUT_MULT_F'))
        else:
            div = float(self.get_param(blockname, 'PLL_DIVCLK_DIVIDE'))
            mult = float(self.get_param(blockname, 'PLL_CLKFBOUT_MULT'))
        vco_mult = mult/div
        # grab the VCO range and compute the input clock range
        vco_min = float(self.get_param(blockname, 'C_VCO_MIN'))
        vco_max = float(self.get_param(blockname, 'C_VCO_MAX'))
        in_min = vco_min/vco_mult
        in_max = vco_max/vco_mult
        return in_min, in_max

    def trace_dma(self, direction, start_block, start_port):
        """Trace back the data path for a block that is fed by a DMA, possibly through a switch.

        Parameters
        ----------
        direction : str
            'forward' or 'backward'
        start_block : str
            The fullpath for the block to start tracing from.
        start_port : str
            The name of the clock input port to start tracing from.

        Returns
        -------
        str
            fullpath for the DMA block
        str
            fullpath for the switch block, None if there is no switch
        int
            switch port, None if there is no switch
        """
        # when going backward, the DMA is connected to S00_AXIS and the data consumers are Mxx_AXIS
        # when going forward, the DMA is connected to M00_AXIS and the data sources are Sxx_AXIS
        if direction == 'forward':
            switch_common = "M00_AXIS"
        elif direction == 'backward':
            switch_common = "S00_AXIS"
        else:
            raise RuntimeError("trace_dma direction must be 'forward' or 'backward', got %s"%(direction))
        ((block, port),) = self.trace_bus(start_block, start_port)
        blocktype = self.mod2type(block)
        if blocktype == 'axi_dma':
            dma_path = block
            return dma_path, None, None
        elif blocktype == 'axis_switch':
            switch_path = block
            switch_ch = int(port.split('_')[0][1:])
            ((block, port),) = self.trace_bus(block, switch_common)
            blocktype = self.mod2type(block)
            if blocktype != 'axi_dma':
                raise RuntimeError("tracing port %s from block %s: expected to find axi_dma after axis_switch, found %s instead"%(start_port, start_block, blocktype))
            dma_path = block
            return dma_path, switch_path, switch_ch
        else:
            raise RuntimeError("tracing port %s from block %s: expected to find axi_dma or axis_switch, found %s instead"%(start_port, start_block, blocktype))

    def trace_clk_back(self, start_block, start_port):
        """Follow the clock backwards from a given block and port.
        Compute the clock source, the frequency, and any limits imposed by the clock path.
        Because it traces the clock back to its source, the frequency accounts for software changes.

        The clock source is assumed to be the Zynq PS or the RF data converter.
        Raise an error if the clock can't be traced back to either of those sources.

        The clock path may pass through clocking wizards, which multiply the clock and impose limits on the frequency range.

        Parameters
        ----------
        start_block : str
            The fullpath for the block to start tracing from.
        start_port : str
            The name of the clock input port to start tracing from.

        Returns
        -------
        dict
            source: The clock source ('PS', 'dac', 'adc'), and the channel number.
            f_clk: The clock frequency that the block sees (MHz).
            Accounts for clock multipliers between the source and the given block, and for software changes to the source frequency.
            src_range: None, or bounds (MHz) on the source clock's frequency.
        """
        clk_mult = 1.0
        src_range = None
        next_block = start_block
        next_port = start_port
        while next_port is not None:
            trace_result = self.trace_sig(next_block, next_port)
            next_port = None
            for block, port in trace_result:
                next_type = self.mod2type(block)
                if next_type == 'clk_wiz' and port.startswith('clk_out'):
                    next_block = block
                    next_port = 'clk_in1'
                    f_out = self.get_fclk(block, port)
                    f_in = self.get_fclk(block, next_port)
                    clk_mult *= (f_out/f_in)
                    if src_range is not None:
                        src_range[0] /= (f_out/f_in)
                        src_range[1] /= (f_out/f_in)

                    in_min, in_max = self._analyze_clkwiz(block)
                    if src_range is None:
                        src_range = [in_min, in_max]
                    else:
                        src_range[0] = max(src_range[0], in_min)
                        src_range[1] = min(src_range[1], in_max)
                    continue
                elif next_type == 'zynq_ultra_ps_e' and port.startswith('pl_clk'):
                    f_clk = self.get_fclk(block, port)
                    iClk = int(port[6:])
                    return {
                            'source': ('PS', iClk),
                            'f_clk': float(f_clk*clk_mult),
                            'src_range': src_range
                            }
                elif next_type == 'usp_rf_data_converter' and port.startswith('clk_'):
                    tilename = port.split('_')[1]
                    tiletype = tilename[:3]
                    iTile = int(tilename[3:])
                    f_clk = self.soc['rf']['tiles'][tiletype][iTile]['f_out']
                    return {
                            'source': (tiletype, iTile),
                            'f_clk': float(f_clk*clk_mult),
                            'src_range': src_range
                            }
        raise RuntimeError("tried to trace clock %s from IP block %s, but this clock doesn't seem to come from Zynq PS or RFDC"%(start_port, start_block))

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
        for module in root.findall('./MODULES/MODULE'):
            fullpath = module.get('FULLNAME').lstrip('/')
            for bus in module.findall('./BUSINTERFACES/BUSINTERFACE'):
                port = fullpath + '/' + bus.get('NAME')
                busname = bus.get('BUSNAME')
                self.pins[port] = busname
                if busname in self.nets:
                    self.nets[busname] |= set([port])
                else:
                    self.nets[busname] = set([port])

class SigParser:
    """Parses the HWH XML file to extract information on the nets connecting IP blocks.
    This is mostly a copy of the PYNQ 2.7 HWH parser, but also grabs clock frequencies.
    """
    def __init__(self, root):
        self.nets = {}
        self.pins = {}
        self.freqs = {}
        for module in root.findall('./MODULES/MODULE'):
            fullpath = module.get('FULLNAME').lstrip('/')
            for netport in module.findall('./PORTS/PORT'):
                netname = netport.get('SIGNAME')
                portname = fullpath + '/' + netport.get('NAME')
                if 'CLKFREQUENCY' in netport.attrib: self.freqs[portname] = float(netport.get('CLKFREQUENCY'))
                self.pins[portname] = netname
                if netname in self.nets:
                    self.nets[netname] |= set([portname])
                else:
                    self.nets[netname] = set([portname])

        for netport in root.findall('./EXTERNALPORTS/PORT'):
            netname = netport.get('SIGNAME')
            portname = netport.get('NAME')
            self.pins[portname] = netname
            if netname in self.nets:
                self.nets[netname] |= set([portname])
            else:
                self.nets[netname] = set([portname])

