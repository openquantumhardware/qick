"""Helpers for the off-board behaviour tests of QICK drivers (firmware/docs/user/IP_INTEGRATION.md, D4).

A driver test imports this module first (it puts qick_lib on sys.path and stubs pynq when it is not installed),
then models its IP at register level with a FakeMmio subclass:

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "scripts"))
    import driver_testing as dt
    from qick.drivers.readout import MrBufferEt

    class FakeMr(dt.FakeMmio):
        def on_write(self, index, value): ...   # the IP's reaction to a register write

    ip = MrBufferEt(dt.description('qick:ip:mr_buffer_et:1.2', FakeMr(), B=16, N=16, NM=2))

Both driver styles work against a FakeMmio: Style A (`self.<reg> = v` goes to `mmio.array[index]`) and Style B
(PeakRDL model over `mmio.read(addr)` / `mmio.write(addr, v)`).
"""
import sys
import types
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
if str(REPO / "qick_lib") not in sys.path:
    sys.path.insert(0, str(REPO / "qick_lib"))


class Buffer(np.ndarray):
    """Stand-in for pynq's PynqBuffer: an ndarray with freebuffer()."""
    freed = False

    def freebuffer(self):
        self.freed = True


def allocate(shape, dtype, **kwargs):
    return np.zeros(shape, dtype=dtype).view(Buffer)


class DefaultIP:
    """Stand-in for pynq.overlay.DefaultIP: takes its MMIO from description['mmio']."""

    def __init__(self, description):
        self.mmio = description['mmio']


def _install_pynq_stub():
    try:
        import pynq  # noqa: F401
        return False
    except ImportError:
        pass
    pynq = types.ModuleType('pynq')
    overlay = types.ModuleType('pynq.overlay')
    buffer = types.ModuleType('pynq.buffer')
    overlay.DefaultIP = DefaultIP
    buffer.allocate = allocate
    pynq.overlay, pynq.buffer = overlay, buffer
    pynq.DefaultIP, pynq.allocate = DefaultIP, allocate
    sys.modules.update({'pynq': pynq, 'pynq.overlay': overlay, 'pynq.buffer': buffer})
    return True


PYNQ_STUBBED = _install_pynq_stub()


class _Array:
    """mmio.array: 32-bit word view that forwards writes to FakeMmio.on_write."""

    def __init__(self, mmio):
        self._mmio = mmio

    def __getitem__(self, index):
        return np.uint32(self._mmio.on_read(int(index)))

    def __setitem__(self, index, value):
        self._mmio._store(int(index), int(np.uint32(value)))


class FakeMmio:
    """Register file of `nregs` 32-bit words, with hooks for the modelled IP.

    Subclasses override on_write(index, value) (called after the word is stored) and on_read(index) (defaults
    to the stored word). `writes` logs every (index, value) in order, for sequence checks.
    """

    def __init__(self, nregs=64):
        self.words = [0] * nregs
        self.writes = []
        self.array = _Array(self)

    def _store(self, index, value):
        self.words[index] = value & 0xFFFFFFFF
        self.writes.append((index, value & 0xFFFFFFFF))
        self.on_write(index, value & 0xFFFFFFFF)

    def on_write(self, index, value):
        pass

    def on_read(self, index):
        return self.words[index]

    # byte-addressed API (PYNQ MMIO.read/write, used by PeakRDL-based drivers)
    def read(self, addr, length=4):
        return self.on_read(addr // 4)

    def write(self, addr, value):
        self._store(addr // 4, int(value))


class FakeDmaChannel:
    """AXI DMA S2MM channel in simple mode: transfer(buf) arms it; the model calls deliver() to fill and close it."""

    def __init__(self):
        self.buf = None
        self.length = 0
        self.on_arm = None

    @property
    def idle(self):
        return self.buf is None

    @property
    def running(self):
        return True

    def transfer(self, buf):
        assert self.buf is None, "transfer() while a transfer is pending"
        self.buf, self.length = buf, 0
        if self.on_arm:
            self.on_arm()

    def wait(self):
        assert self.buf is None, "wait() on a transfer that never closes would hang on the board"

    def start(self):
        pass

    def deliver(self, data, last=True):
        """The stream side sends `data` (1-D array of words); returns how many were accepted."""
        if self.buf is None:
            return 0
        flat = self.buf.reshape(-1).view(data.dtype) if self.buf.dtype != data.dtype else self.buf.reshape(-1)
        n = min(len(data), len(flat))
        flat[:n] = data[:n]
        self.length = n * data.itemsize
        if last and n == len(data):
            self.buf = None
        return n


class FakeDma:
    """An AXI DMA with a receive channel (the send side is unused by the tests so far)."""

    def __init__(self):
        self.recvchannel = FakeDmaChannel()


def description(vlnv, mmio, fullpath=None, **params):
    """A PYNQ ip_dict entry as the drivers see it."""
    name = vlnv.split(':')[2]
    return {'type': vlnv, 'fullpath': fullpath or name + '_0', 'mmio': mmio,
            'parameters': {k: str(v) for k, v in params.items()}}


def rdl_offsets(path, skip=('RESERVED',)):
    """{register name (lower case): byte offset} from a SystemRDL file, `//` and `/* */` comments stripped.
    Names starting with any of `skip` are left out (placeholder registers a driver does not map)."""
    import re
    text = re.sub(r'/\*.*?\*/', '', Path(path).read_text(), flags=re.S)
    text = re.sub(r'//[^\n]*', '', text)
    return {n.lower(): int(a, 16) for n, a in re.findall(r'\}\s*(\w+)\s*@\s*(0x[0-9A-Fa-f]+)', text)
            if not n.startswith(tuple(skip))}
