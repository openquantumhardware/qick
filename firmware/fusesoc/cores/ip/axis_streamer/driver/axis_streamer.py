"""
QICK driver for the axis_streamer IP core.
Uses the PeakRDL-generated register model. Register access via `.regs`, e.g.:
    st = soc.axis_streamer_0
    st.regs.STATUS_REG.IDLE.read()

The high-level methods implement the programming sequence of the register map
(rdl/axis_streamer_regmap.rdl): configure only while IDLE, arm the DMA before
START, stop by clearing START and polling IDLE, read LOST only once IDLE.

Works with both a raw PYNQ Overlay and QickSoc. The register model is built in
_init_firmware() (always called from SocIP.__init__, needs only self.mmio).
configure_connections() finds the AXI DMA fed by m_axis; it only runs under
QickSoc, so with a raw Overlay pass `dma=` to the capture methods or set
`.dma` by hand.
"""
import sys
import time
from pathlib import Path
# Find the generated PeakRDL package in dev (next to driver) or prod (installed).
_RDL_PKG_PATHS = [
    Path(__file__).parent.parent / "rdl",        # dev: fusesoc/cores/ip/.../rdl
    Path(__file__).parent.parent / "rdl_pkgs",   # prod: qick_lib/qick/rdl_pkgs
]
for _path in _RDL_PKG_PATHS:
    if (_path / "axis_streamer_regmap_pkg").exists():
        if str(_path) not in sys.path:
            sys.path.insert(0, str(_path))
        break

import numpy as np
from axis_streamer_regmap_pkg.reg_model import RegModel
from axis_streamer_regmap_pkg.lib import NormalCallbackSet
from qick.ip import SocIP

# AXI DMA S2MM registers (PG021), used where pynq's own calls block forever.
_DMA_S2MM_CR = 0x30
_DMA_S2MM_LENGTH = 0x58


def dma_wait(dma, timeout=1.0):
    """Poll the S2MM channel until the transfer closes (it closes on tlast).

    dma.recvchannel.wait() blocks forever on a transfer that never sees tlast.
    Returns True if the channel went idle within `timeout` seconds.
    """
    t0 = time.time()
    while True:
        if dma.recvchannel.idle:
            return True
        if time.time() - t0 >= timeout:
            return False
        time.sleep(0.001)


def dma_reset(dma, timeout=1.0):
    """Drop a pending S2MM transfer: soft reset of the AXI DMA, then restart the receive channel.

    The reset bit resets both channels of the DMA.
    """
    dma.write(_DMA_S2MM_CR, 0x4)
    t0 = time.time()
    while dma.read(_DMA_S2MM_CR) & 0x4 and time.time() - t0 < timeout:
        pass
    dma.recvchannel.start()


def dma_received_bytes(dma):
    """Bytes written by the last completed S2MM transfer."""
    return dma.read(_DMA_S2MM_LENGTH)


class AxisStreamer(SocIP):
    """QICK driver for axis_streamer. Register access through `.regs`.

    Configuration (from the IP parameters): `b_tdata`, `b_tuser`, `b_axis`, `n_fifo`.
    Each output beat is `{zero padding, tuser, tdata}`, `b_axis` bits wide.
    """
    bindto = ['qick:ip:axis_streamer:1.0', 'qick:ip:axis_streamer:2.0']

    # STATUS_REG bits
    RUNNING, DONE, IDLE, OVERFLOW, FIFO_FULL, FIFO_EMPTY = 1, 2, 4, 8, 16, 32
    _STATUS_NAMES = ('RUNNING', 'DONE', 'IDLE', 'OVERFLOW', 'FIFO_FULL', 'FIFO_EMPTY')

    #: Timeout (s) for the block to reach a state after a register write. The
    #: FSM reacts within a few clocks; this only covers Python and MMIO latency.
    STATE_TIMEOUT = 1.0

    def _init_config(self, description):
        params = description.get('parameters', {})
        for key, name, default in (('b_tdata', 'B_TDATA', 16), ('b_tuser', 'B_TUSER', 8),
                                   ('b_axis', 'B_AXIS', 32), ('n_fifo', 'N_FIFO', 16)):
            self.cfg[key] = int(params.get(name, default))
        self.dma = None
        self.last_capture = None
        self.last_recover = None

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

    def configure_connections(self, soc):
        """Find the AXI DMA fed by m_axis (directly or through an axis_switch)."""
        super().configure_connections(soc)
        if self['version'] == '2.0' and self['revision'] < 1:
            self.logger.warning("%s is axis_streamer 2.0.0: its one-shot packets are followed by stray beats "
                                "and the block never returns to IDLE. Rebuild with 2.0.1 or later.",
                                self['fullpath'])
        try:
            dma_path, _, _ = soc.metadata.trace_dma('forward', self['fullpath'], 'm_axis')
        except Exception as e:
            self.logger.warning("%s: no AXI DMA found on m_axis (%s); pass dma= explicitly",
                                self['fullpath'], e)
            return
        self.dma = soc._get_block(dma_path)
        self.cfg['dma'] = dma_path

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
                "AxisStreamer: register model not initialized "
                "(expected _init_firmware to run in __init__)"
            )
        return self._reg_model

    # -- hand-written high-level methods below --

    @property
    def beat_dtype(self):
        """numpy dtype of one output beat, for DMA buffers."""
        return {8: np.uint8, 16: np.uint16, 32: np.uint32, 64: np.uint64}[self['b_axis']]

    def status(self):
        """STATUS_REG as an int (bits: RUNNING, DONE, IDLE, OVERFLOW, FIFO_FULL, FIFO_EMPTY)."""
        return self.regs.STATUS_REG.read()

    def status_flags(self, value=None):
        """STATUS_REG decoded into a dict of booleans."""
        value = self.status() if value is None else value
        return {name: bool(value >> i & 1) for i, name in enumerate(self._STATUS_NAMES)}

    def wait_status(self, mask, value=True, timeout=None):
        """Poll STATUS until (STATUS & mask) is nonzero (value=True) or zero (value=False)."""
        timeout = self.STATE_TIMEOUT if timeout is None else timeout
        t0 = time.time()
        while True:
            if bool(self.status() & mask) == value:
                return True
            if time.time() - t0 >= timeout:
                return False
            time.sleep(0.001)

    @property
    def lost(self):
        """Samples dropped in the last run. Only meaningful while IDLE."""
        return self.regs.LOST_REG.read()

    def configure(self, nsamp, continuous=False, flush=True):
        """Write NSAMP, MODE and FLUSH. The block must be IDLE.

        Parameters
        ----------
        nsamp : int
            beats per packet; 0 keeps the block in IDLE.
        continuous : bool
            False = one-shot (one packet, then DONE), True = back-to-back packets until stopped.
        flush : bool
            what to do with a packet cut short by stop(): True = drain it, the last beat carries
            tlast; False = discard it (at most one beat, already on the bus, still comes out).
            A one-shot packet that completed is never followed by anything, whatever this says.
        """
        if not self.wait_status(self.IDLE):
            raise RuntimeError("axis_streamer not IDLE (STATUS 0x%02x): stop() or recover() first"
                               % self.status())
        self.regs.NSAMP_REG.write(int(nsamp))
        self.regs.MODE_REG.write(int(bool(continuous)))
        self.regs.FLUSH_REG.write(int(bool(flush)))

    def start(self):
        """Set START. Arm the DMA first: with no transfer armed, the ~N_FIFO-deep FIFO overflows at once."""
        self.regs.START_REG.write(1)

    def stop(self, timeout=None):
        """Clear START and wait for IDLE. Returns True if the block reached IDLE.

        Stopping is not instantaneous. With flush=True a partial packet is drained first, and that
        needs a DMA transfer armed to take it (see recover()).
        """
        self.regs.START_REG.write(0)
        return self.wait_status(self.IDLE, timeout=timeout)

    def wait_dma(self, timeout=1.0, dma=None):
        """Wait for the DMA's current S2MM transfer to close (on tlast). Use instead of
        dma.recvchannel.wait(), which blocks forever when no tlast comes. Returns whether it closed."""
        return dma_wait(self._get_dma(dma), timeout)

    def reset_dma(self, dma=None):
        """Drop a pending S2MM transfer (soft reset of the AXI DMA, then restart of the receive channel)."""
        dma_reset(self._get_dma(dma))

    def _get_dma(self, dma):
        dma = self.dma if dma is None else dma
        if dma is None:
            raise RuntimeError("axis_streamer: no DMA known; pass dma= (raw Overlay) or use QickSoc")
        return dma

    def recover(self, dma=None, max_beats=65536, max_transfers=4):
        """Bring the block to IDLE whatever it still holds, without leaving a DMA transfer pending.

        START is cleared FIRST. With START still set, a continuous run would start a new packet into
        the spare transfer, close it on that packet's tlast, and then leave the next beat presented on
        the bus with nothing to take it (with FLUSH = 0 it can never be withdrawn). Once START is
        clear, the block only emits what is left:
        - FLUSH = 1: the rest of the cut packet, ending with tlast. That can take two transfers when
          the beat already on the bus closes the previous packet.
        - FLUSH = 0: at most the one beat on the bus, without tlast, so the spare never closes and the
          DMA is reset.

        Spare transfers are armed one after another until the block is IDLE (at most `max_transfers`).
        Returns (idle, beats), where beats counts the beats of the transfers that closed.
        `self.last_recover` holds idle, beats, transfers (closed), and dropped (a spare had to be reset).
        """
        from pynq import allocate
        dma = self._get_dma(dma)
        self.regs.START_REG.write(0)
        if not dma.recvchannel.idle:
            dma_reset(dma)
        idle, beats, closed, dropped = self.wait_status(self.IDLE, timeout=0.01), 0, 0, False
        spare = allocate(shape=(max_beats,), dtype=self.beat_dtype)
        try:
            while not idle and closed < max_transfers:
                dma.recvchannel.transfer(spare)
                if dma_wait(dma, 0.1):
                    closed += 1
                    beats += dma_received_bytes(dma) // (self['b_axis'] // 8)
                    idle = self.wait_status(self.IDLE, timeout=0.01)
                else:
                    dma_reset(dma)
                    dropped = True
                    idle = self.wait_status(self.IDLE)
                    break
        finally:
            spare.freebuffer()
        self.last_recover = dict(idle=idle, beats=beats, transfers=closed, dropped=dropped)
        return idle, beats

    def capture(self, nsamp, dma=None, flush=True, timeout=2.0):
        """One-shot capture of `nsamp` beats through the DMA. Returns the raw beats (numpy array).

        Follows the register map's sequence: IDLE -> configure -> arm the DMA -> START -> DMA closes on
        tlast -> DONE -> stop -> IDLE. Raises RuntimeError if the DMA does not close or the block does
        not return to IDLE, after bringing the block back to IDLE. `self.last_capture` keeps the
        details: dma, done, idle, lost.
        """
        from pynq import allocate
        dma = self._get_dma(dma)
        buf = allocate(shape=(int(nsamp),), dtype=self.beat_dtype)
        try:
            self.configure(nsamp, continuous=False, flush=flush)
            dma.recvchannel.transfer(buf)
            self.start()
            got = dma_wait(dma, timeout)
            done = self.wait_status(self.DONE)
            idle = self.stop()
            self.last_capture = dict(dma=got, done=done, idle=idle, lost=self.lost if idle else None)
            if not (got and idle):
                status = self.status()
                if not got:
                    dma_reset(dma)
                self.recover(dma)
                raise RuntimeError("axis_streamer capture failed: DMA closed %s, DONE %s, IDLE after stop %s "
                                   "(STATUS 0x%02x)" % (got, done, idle, status))
            return np.array(buf)
        finally:
            buf.freebuffer()

    def decode(self, beats):
        """Split raw beats into (tdata, tuser), as unsigned integer arrays."""
        w = np.asarray(beats).astype(np.uint64)
        bt, bu = self['b_tdata'], self['b_tuser']
        tdata = w & np.uint64((1 << bt) - 1)
        tuser = (w >> np.uint64(bt)) & np.uint64((1 << bu) - 1)
        return tdata, tuser

    @staticmethod
    def iq(tdata, bits=16):
        """Interpret tdata as {Q, I}, `bits` each, signed (the axis_readout_v2 m1_axis layout). Returns I + jQ."""
        t = np.asarray(tdata).astype(np.uint64)
        mask, half = (1 << bits) - 1, 1 << (bits - 1)
        i = (t & np.uint64(mask)).astype(np.int64)
        q = ((t >> np.uint64(bits)) & np.uint64(mask)).astype(np.int64)
        i = np.where(i >= half, i - (1 << bits), i)
        q = np.where(q >= half, q - (1 << bits), q)
        return i + 1j * q
