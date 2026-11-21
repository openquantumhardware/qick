"""
QICK driver for axis_kidsim_v3 IP core (L-lane KID resonator simulator).
Uses the PeakRDL-generated register model (`.regs`). The high-level methods follow the IP's README (U2): the
parameter registers are a staging area shared by all lanes, and a configuration reaches a lane only when
ADDR_REG selects it and WE_REG is pulsed, so config_lane() always writes every field and then commits it.

    k = soc.axis_kidsim_v3_0                              # QickSoc binds it; no import needed
    k.config_lane(3, outsel=k.OUT_SIGNAL, freq=0x0400, c1=k.q15(0.99), g=k.G_UNITY, punct=2)
    k.config_all(outsel=k.OUT_BYPASS)

Works with both a raw PYNQ Overlay and QickSoc: the register model is built in
_init_firmware() (always called from SocIP.__init__, needs only self.mmio).
configure_connections() is reserved for soc-dependent wiring (revision/version, peers).
"""
import sys
from pathlib import Path
# Find the generated PeakRDL package in dev (next to driver) or prod (installed).
_RDL_PKG_PATHS = [
    Path(__file__).parent.parent / "rdl",        # dev: fusesoc/cores/ip/.../rdl
    Path(__file__).parent.parent / "rdl_pkgs",   # prod: qick_lib/qick/rdl_pkgs
]
for _path in _RDL_PKG_PATHS:
    if (_path / "axis_kidsim_v3_regmap_pkg").exists():
        if str(_path) not in sys.path:
            sys.path.insert(0, str(_path))
        break

from axis_kidsim_v3_regmap_pkg.reg_model import RegModel
from axis_kidsim_v3_regmap_pkg.lib import NormalCallbackSet
from qick.ip import SocIP


def _to_unsigned(val, bits=16):
    return val & ((1 << bits) - 1)


def _to_signed(val, bits=16):
    half = 1 << (bits - 1)
    return val - (1 << bits) if val >= half else val


class AxisKidsimV3(SocIP):
    """QICK driver for axis_kidsim_v3. Register access through `.regs`; per-lane configuration through
    config_lane() / config_all(). `self['lanes']` is the IP's L parameter."""
    bindto = ['qick:ip:axis_kidsim_v3:1.0']

    #: OUTSEL_REG values: processed signal, DDS carrier alone, input bypass, zeros.
    OUT_SIGNAL, OUT_DDS, OUT_BYPASS, OUT_ZERO = 0, 1, 2, 3
    #: IIR gain register value for ~1.0 (32767/32768).
    G_UNITY = 0x7FFF

    def _init_config(self, description):
        self.cfg['lanes'] = int(description.get('parameters', {}).get('L', 8))

    def _init_firmware(self):
        # Called from SocIP.__init__ for BOTH raw Overlay and QickSoc.
        # Only needs self.mmio (already set by DefaultIP.__init__).
        super()._init_firmware()
        self._reg_model = RegModel(
            callbacks=NormalCallbackSet(
                read_callback=self._hw_read,
                write_callback=self._hw_write,
                read_block_callback=self._hw_read_block,
                write_block_callback=self._hw_write_block,
            )
        )

    def _hw_read(self, addr, width, accesswidth):
        return self.mmio.read(addr)

    def _hw_write(self, addr, width, accesswidth, data):
        self.mmio.write(addr, int(data) & 0xFFFFFFFF)

    def _hw_read_block(self, addr, width, accesswidth, length):
        return [self.mmio.read(addr + 4*i) for i in range(length)]

    def _hw_write_block(self, addr, width, accesswidth, data):
        for i, d in enumerate(data):
            self.mmio.write(addr + 4*i, int(d) & 0xFFFFFFFF)

    @property
    def regs(self):
        if self._reg_model is None:
            raise RuntimeError(
                "AxisKidsimV3: register model not initialized "
                "(expected _init_firmware to run in __init__)"
            )
        return self._reg_model

    # -- hand-written high-level methods below --

    @staticmethod
    def q15(x):
        """Real in [-1, 1) -> signed Q15 register value (16-bit two's complement), clipped. Same convention as the
        IP's model (model/kidsim_resonator.py, real_to_q15)."""
        r = int(round(x * 32768))
        return max(-0x8000, min(0x7FFF, r)) & 0xFFFF

    @staticmethod
    def from_q15(reg):
        """Signed Q15 register value -> real."""
        return _to_signed(int(reg) & 0xFFFF) / 32768

    def config_lane(self, lane, outsel=OUT_BYPASS, freq=0, c0=0, c1=0, g=G_UNITY, punct=0,
                    bval=0, slope=0, steps=0, wait=0):
        """Configure one lane and commit it (ADDR_REG = lane, then a WE_REG pulse).

        All values are register words (16 bit; use q15() for the Q15 fields C0, C1, G, BVAL, SLOPE). Every field is
        written: the staging registers are shared by all lanes, so a field left out would take whatever the
        previous lane got.

        Parameters
        ----------
        lane : int
            0 .. lanes-1
        outsel : int
            OUT_SIGNAL, OUT_DDS, OUT_BYPASS or OUT_ZERO
        freq : int
            DDS phase increment per processed sample (the resonator advances once per frame, README U2)
        c0, c1, g : int
            IIR zero, pole and output gain (Q15)
        punct : int
            index, within each frame, of the one sample the lane processes
        bval, slope, steps, wait : int
            chirp ramp: start value, slope per step, number of steps, processed samples waited per step
        """
        if not 0 <= lane < self['lanes']:
            raise ValueError("lane %d out of range: this IP has %d lanes" % (lane, self['lanes']))
        if outsel not in (self.OUT_SIGNAL, self.OUT_DDS, self.OUT_BYPASS, self.OUT_ZERO):
            raise ValueError("outsel must be 0..3, got %r" % (outsel,))
        r = self.regs
        for reg, v in ((r.DDS_BVAL_REG, bval), (r.DDS_SLOPE_REG, slope), (r.DDS_STEPS_REG, steps),
                       (r.DDS_WAIT_REG, wait), (r.DDS_FREQ_REG, freq), (r.IIR_C0_REG, c0), (r.IIR_C1_REG, c1),
                       (r.IIR_G_REG, g), (r.OUTSEL_REG, outsel), (r.PUNCT_ID_REG, punct)):
            reg.write(int(v) & 0xFFFF)
        r.ADDR_REG.write(lane)
        r.WE_REG.write(1)
        r.WE_REG.write(0)

    def config_all(self, **kwargs):
        """config_lane() with the same parameters on every lane."""
        for lane in range(self['lanes']):
            self.config_lane(lane, **kwargs)
