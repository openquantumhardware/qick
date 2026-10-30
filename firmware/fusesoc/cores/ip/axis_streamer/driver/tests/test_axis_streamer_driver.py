"""Tests of the AxisStreamer driver's programming sequence, off the board.

pynq is stubbed when it is not installed (scripts/driver_testing.py), and the IP and its AXI DMA are
replaced by a small behavioural model (FakeStreamer, FakeDma) that follows the
FSM of rtl_lib/ctrl/streamer.sv at register level. `extra_after_packet` models
the 2.0.0 one-shot bug: beats emitted after the packet that no DMA transfer
takes, so the block stays in WAIT_END.
"""
import sys
import types
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "scripts"))
import driver_testing  # noqa: E402,F401  (qick_lib on sys.path, pynq stubbed if missing)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))   # driver/

import axis_streamer as drv                                     # noqa: E402

R_START, R_FLUSH, R_MODE, R_NSAMP, R_LOST, R_STATUS = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14


class FakeDma:
    """AXI DMA S2MM channel: one transfer at a time, closes on tlast."""

    def __init__(self):
        self.buf = None
        self.length = 0
        self.resets = 0
        self.on_arm = None
        self.recvchannel = self

    # pynq channel API
    @property
    def idle(self):
        return self.buf is None

    def transfer(self, buf):
        assert self.buf is None, "transfer() while a transfer is pending"
        self.buf, self.length = buf, 0
        if self.on_arm:
            self.on_arm()

    def start(self):
        pass

    # register API
    def read(self, addr):
        return self.length if addr == drv._DMA_S2MM_LENGTH else 0

    def write(self, addr, value):
        if addr == drv._DMA_S2MM_CR and value & 0x4:
            self.buf = None
            self.resets += 1

    def take(self, beats, last):
        """The streamer emits `beats`; returns how many the DMA accepted."""
        if self.buf is None:
            return 0
        n = min(len(beats), len(self.buf))
        self.buf[:n] = beats[:n]
        self.length = n * self.buf.itemsize
        if last and n == len(beats):
            self.buf = None                 # closes on tlast
        return n


class FakeStreamer:
    """Register-level model of the streamer FSM (rtl_lib/ctrl/streamer.sv) driving a FakeDma.

    The source never stops, so in RUN the block always has data:
    - one-shot: the packet goes out as soon as a transfer is armed. `extra` > 0 models 2.0.0: that many
      stray beats follow the packet (tlast on the last one if FLUSH = 1), and the block waits in WAIT_END
      until something takes them;
    - continuous: every armed transfer receives a full packet (tlast), after which the next beat is
      already presented on the bus (`on_bus`, AXI forbids withdrawing it).
    START = 0 in RUN leaves `leftover` words in the FIFO, plus the beat on the bus. FLUSH = 1 drains them
    with tlast at the end (a beat on the bus that closed a packet carries its own tlast: `on_bus_last`);
    FLUSH = 0 discards the FIFO words but the beat on the bus still goes out, without tlast.
    """

    def __init__(self, dma, extra_after_packet=0, leftover=5):
        self.dma = dma
        dma.on_arm = self._pump
        self.regs = {R_START: 0, R_FLUSH: 0, R_MODE: 0, R_NSAMP: 0, R_LOST: 0}
        self.state = 'IDLE'
        self.extra = extra_after_packet
        self.leftover = leftover
        self.on_bus = 0
        self.on_bus_last = False
        self.pending = []                   # [(beats, tlast on the last one)] to emit in WAIT_END
        self.counter = 0

    def read(self, addr):
        if addr == R_STATUS:
            bits = {'RUN': 1, 'END': 2, 'IDLE': 4}.get(self.state, 0)
            return bits | (32 if not self.pending else 0)
        return self.regs[addr]

    def _beats(self, n):
        b = np.arange(self.counter, self.counter + n, dtype=np.uint64)
        self.counter += n
        return b

    def _pump(self):
        if self.state == 'RUN' and self.dma.buf is not None:
            n = self.regs[R_NSAMP]
            if self.dma.take(self._beats(n), last=True) != n:
                return
            if self.regs[R_MODE]:
                self.on_bus, self.on_bus_last = 1, False
            else:
                self.pending = [(self.extra, bool(self.regs[R_FLUSH]))] if self.extra else []
                self.state = 'WAIT_END'
        while self.state == 'WAIT_END' and self.pending and self.dma.buf is not None:
            n, last = self.pending[0]
            if self.dma.take(self._beats(n), last=last) != n:
                return
            self.pending.pop(0)
        if self.state == 'WAIT_END' and not self.pending:
            self.state = 'IDLE' if not self.regs[R_START] else 'END'

    def write(self, addr, value):
        self.regs[addr] = value
        if addr != R_START:
            return
        if value and self.state == 'IDLE' and self.regs[R_NSAMP]:
            self.state = 'RUN'
            self.on_bus = 0
        elif not value:
            if self.state == 'RUN':
                self.state = 'WAIT_END'
                if self.regs[R_FLUSH]:
                    if self.on_bus and self.on_bus_last:
                        self.pending = [(1, True), (self.leftover, True)]
                    else:
                        self.pending = [(self.on_bus + self.leftover, True)]
                else:
                    self.pending = [(1, False)] if self.on_bus else []
            elif self.state == 'END':
                self.state = 'IDLE'
        self._pump()


def make(extra_after_packet=0, params=None, leftover=5):
    dma = FakeDma()
    mmio = FakeStreamer(dma, extra_after_packet, leftover)
    desc = {'type': 'qick:ip:axis_streamer:2.0', 'fullpath': 'axis_streamer_0', 'mmio': mmio,
            'parameters': params or {'B_TDATA': '32', 'B_TUSER': '8', 'B_AXIS': '64', 'N_FIFO': '16'}}
    st = drv.AxisStreamer(desc)
    st.STATE_TIMEOUT = 0.05
    st.dma = dma
    return st, mmio, dma


def test_config_from_parameters():
    st, _, _ = make()
    assert (st['b_tdata'], st['b_tuser'], st['b_axis'], st['n_fifo']) == (32, 8, 64, 16)
    assert st.beat_dtype is np.uint64
    st32, _, _ = make(params={'B_TDATA': '16', 'B_TUSER': '8', 'B_AXIS': '32', 'N_FIFO': '16'})
    assert st32.beat_dtype is np.uint32


def test_capture_follows_the_sequence():
    st, mmio, dma = make()
    beats = st.capture(1000)
    assert len(beats) == 1000 and beats[0] == 0 and beats[-1] == 999
    assert st.last_capture == dict(dma=True, done=True, idle=True, lost=0)
    assert mmio.state == 'IDLE' and dma.idle
    assert (mmio.regs[R_NSAMP], mmio.regs[R_MODE], mmio.regs[R_FLUSH], mmio.regs[R_START]) == (1000, 0, 1, 0)


def test_capture_back_to_back():
    st, _, _ = make()
    a = st.capture(100)
    b = st.capture(100)
    assert a[-1] == 99 and b[0] == 100


def test_capture_with_the_2_0_0_bug_raises_and_recovers():
    st, mmio, dma = make(extra_after_packet=8)
    with pytest.raises(RuntimeError, match="IDLE after stop False"):
        st.capture(1000)
    assert st.last_capture['idle'] is False and st.last_capture['lost'] is None
    assert mmio.state == 'IDLE' and dma.idle        # recover() drained the 8 beats
    mmio.extra = 0                                  # a fixed bitstream: the next capture runs
    assert len(st.capture(10)) == 10


def test_stop_needs_a_dma_to_drain_and_recover_counts_beats():
    st, mmio, dma = make(extra_after_packet=8)
    st.configure(4)
    dma.transfer(np.zeros(4, dtype=np.uint64))
    st.start()
    assert mmio.state == 'WAIT_END'                 # 2.0.0: 8 stray beats, nobody takes them
    assert st.stop() is False
    assert st.recover() == (True, 8)
    assert st.last_recover == dict(idle=True, beats=8, transfers=1, dropped=False)


def test_recover_stops_before_arming_in_continuous_mode():
    # Board, 2026-09-25: a spare armed while START = 1 took a whole new packet and closed; the beat
    # presented after it was then stuck on the bus with FLUSH = 0 (STATUS 0x18, never IDLE).
    st, mmio, dma = make()
    st.configure(1024, continuous=True, flush=False)
    st.start()
    idle, beats = st.recover()
    assert idle and mmio.state == 'IDLE' and dma.idle
    assert st.last_recover['dropped'] is False and beats == 0     # nothing on the bus, FIFO discarded


def test_recover_continuous_flush_drains_the_cut_packet():
    st, mmio, dma = make(leftover=7)
    st.configure(1024, continuous=True, flush=True)
    dma.transfer(np.zeros(1024, dtype=np.uint64))  # one packet, then a beat waits on the bus
    st.start()
    assert (dma.idle, mmio.on_bus) == (True, 1)
    assert st.recover() == (True, 8)               # the beat on the bus + 7 FIFO words, with tlast


def test_recover_uses_as_many_transfers_as_packets():
    st, mmio, dma = make(leftover=7)
    st.configure(16, continuous=True, flush=True)
    st.start()
    mmio.on_bus, mmio.on_bus_last = 1, True        # the beat on the bus closes a packet by itself
    assert st.recover() == (True, 8)
    assert st.last_recover['transfers'] == 2


def test_recover_resets_a_dma_that_never_closes():
    st, mmio, dma = make()
    st.configure(16, continuous=True, flush=False)
    dma.transfer(np.zeros(16, dtype=np.uint64))
    st.start()                                      # a packet, then a beat on the bus without tlast
    idle, beats = st.recover()
    assert (idle, beats) == (True, 0) and st.last_recover['dropped'] is True
    assert dma.resets == 1 and dma.idle


def test_configure_refuses_when_not_idle():
    st, mmio, _ = make()
    mmio.state = 'RUN'
    with pytest.raises(RuntimeError, match="not IDLE"):
        st.configure(10)


def test_no_dma_is_an_explicit_error():
    st, _, _ = make()
    st.dma = None
    with pytest.raises(RuntimeError, match="no DMA"):
        st.capture(10)


def test_status_flags():
    st, _, _ = make()
    assert st.status_flags(0x2c) == dict(RUNNING=False, DONE=False, IDLE=True, OVERFLOW=True,
                                         FIFO_FULL=False, FIFO_EMPTY=True)


def test_decode_and_iq():
    st, _, _ = make()
    i, q, tuser = -3, 1234, 0x5A
    word = (tuser << 32) | ((q & 0xFFFF) << 16) | (i & 0xFFFF) | (0xFF << 40)   # padding bits ignored
    tdata, tu = st.decode(np.array([word], dtype=np.uint64))
    assert tu[0] == tuser and tdata[0] == ((q & 0xFFFF) << 16) | (i & 0xFFFF)
    assert st.iq(tdata)[0] == complex(i, q)


def test_configure_connections_finds_the_dma():
    st, _, dma = make()
    st.dma = None

    class Meta:
        revision = 1

        def mod2rev(self, block):
            return self.revision

        def mod2version(self, block):
            return '2.0'

        def trace_dma(self, direction, block, port):
            assert (direction, block, port) == ('forward', 'axis_streamer_0', 'm_axis')
            return 'axi_dma_st', None, None

    soc = types.SimpleNamespace(metadata=Meta(), _get_block=lambda path: dma)
    st.configure_connections(soc)
    assert st.dma is dma and st['dma'] == 'axi_dma_st'


def test_configure_connections_warns_on_2_0_0(caplog):
    st, _, dma = make()

    class Meta:
        def mod2rev(self, block):
            return 0

        def mod2version(self, block):
            return '2.0'

        def trace_dma(self, direction, block, port):
            return 'axi_dma_st', None, None

    soc = types.SimpleNamespace(metadata=Meta(), _get_block=lambda path: dma)
    with caplog.at_level('WARNING'):
        st.configure_connections(soc)
    assert "Rebuild with 2.0.1" in caplog.text


def test_dma_helpers_as_methods():
    st, mmio, dma = make()
    st.configure(1024, continuous=True, flush=False)
    dma.transfer(np.zeros(16, dtype=np.uint64))     # smaller than a packet: never closes
    st.start()
    assert st.wait_dma(0.02) is False
    st.reset_dma()
    assert dma.idle and dma.resets == 1
