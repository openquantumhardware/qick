from ..rfboard import RFQickSoc216V1
from . import Buffer, Generator


class RFBoardTestSoc216V1(RFQickSoc216V1):
    def __init__(self, bitfile=None, **kwargs):
        super().__init__(bitfile=bitfile, **kwargs)

        # Create channel mapping for DACs and ADCs
        self.ch_map = {
            "dac": dict(enumerate(self["dacs"])),
            "adc": dict(enumerate(self["adcs"])),
        }

        # Map signal
        self.map_signal_paths()

        # Signal Gnerator.
        self.generator = Generator(
            self,
            self["dacs"]["00"]["fs"],
            self.axis_signal_gen_v6_c_0,
            self.axis_signal_gen_v6_0,
            self.axis_switch_v1_0,
        )

        # Buffer.
        self.buffer = Buffer(
            self,
            self["adcs"]["10"]["fs"],
            self.axis_switch_1,
            self.mr_buffer_et_0,
            self.axi_dma_0,
        )

    def description(self):
        return f"\nQICK configuration:\n\n\tBoard: {self['board']}"

    # Extend map_signal_paths.
    def map_signal_paths(self):
        # Run standard QickSoc map_signal_paths.
        # super().map_signal_paths()
        pass

    def set_nyquist(self, ch=0, nqz=1, btype="dac"):
        # Get converter id.
        block_id = self.ch_map[btype][ch]

        # Set nyquist zone.
        self.rf.set_nyquist(block_id, nqz, blocktype=btype)

    def get_nyquist(self, ch=0, btype="dac"):
        # Get converter id.
        block_id = self.ch_map[btype][ch]

        # Get nyquist zone.
        return self.rf.get_nyquist(block_id, blocktype=btype)
