"""
The interface for running QICK programs against an emulated (Verilated) design.

This module provides a drop-in replacement for :class:`QickSoc` that records
every AXI-Lite transaction and memory export a QICK program performs. The
captured artifacts (``pmem.mem``, ``wmem.mem``, ``sgmem_ch*.mem``,
``axi_replay.jsonl``) are replayed by a Verilator testbench, which produces
CSV files that can be loaded back as decimated / accumulated readout buffers
and DAC traces.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import pathlib
import shutil
import subprocess
from dataclasses import dataclass, asdict
from typing import Any, Dict, Iterable, List, Optional, Protocol, Tuple, Union

import numpy as np

try:
    from qick import QickConfig
except Exception as e:
    raise ImportError("qick is not importable. Install qick first.") from e


# =============================================================================
# JSON Serialization Helper
# =============================================================================

class NpEncoder(json.JSONEncoder):
    """JSON encoder that converts numpy scalar/array types to native Python types.

    Used when serializing :class:`AxiTxn` records to JSONL so that values
    produced by QICK helpers (which are often ``np.int64`` / ``np.float64``)
    are representable in standard JSON.
    """
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return super(NpEncoder, self).default(obj)


# =============================================================================
# AXI transaction log
# =============================================================================

@dataclass
class AxiTxn:
    """A single AXI-Lite transaction captured from the emulated SoC.

    Parameters
    ----------
    op : str
        Transaction type: ``"w"`` (write), ``"r"`` (read), or ``"stream"``
        (AXIS stream load).
    addr : int, optional
        Absolute 32-bit AXI-Lite address (for ``"w"`` / ``"r"`` ops).
    data : int, optional
        32-bit data word for a write transaction.
    stream : str, optional
        Stream name (e.g. ``"s0_axis"``) for a stream load.
    words : list of int, optional
        Data words pushed onto the stream.
    comment : str
        Free-form annotation shown in the JSONL log / Vivado replay file.
    """
    op: str  # "w", "r", "stream"
    addr: Optional[int] = None
    data: Optional[int] = None
    stream: Optional[str] = None
    words: Optional[List[int]] = None
    comment: str = ""

    def to_json(self) -> str:
        """Serialize this transaction to a single-line JSON string.

        Keys with a ``None`` value are omitted so reads don't carry an empty
        ``"data"`` field, etc.
        """
        return json.dumps({k: v for k, v in asdict(self).items() if v is not None}, cls=NpEncoder)


class AxiRecorder:
    """Ordered log of AXI-Lite transactions performed against the emulated SoC.

    A single recorder instance is shared by :class:`SocEmu` and all its mock
    IP drivers; every ``reg_write`` / ``reg_read`` on the SoC adds one entry
    here. After the QICK program's ``config_all`` / ``start_tproc`` have run
    :meth:`save_jsonl` is used to dump the captured script for the
    Verilator testbench to replay.
    """

    def __init__(self):
        self.txns: List[AxiTxn] = []

    def write(self, addr: int, data: int, comment: str = ""):
        """Record an AXI-Lite write.

        Parameters
        ----------
        addr : int
            Absolute 32-bit AXI-Lite address.
        data : int
            32-bit data word to be written.
        comment : str
            Free-form annotation for the JSONL / Vivado replay log.
        """
        self.txns.append(AxiTxn(op="w", addr=int(addr), data=int(data), comment=comment))

    def read(self, addr: int, comment: str = ""):
        """Record an AXI-Lite read (no data, since the emulator doesn't model return values).

        Parameters
        ----------
        addr : int
            Absolute 32-bit AXI-Lite address.
        comment : str
            Free-form annotation for the JSONL / Vivado replay log.
        """
        self.txns.append(AxiTxn(op="r", addr=int(addr), comment=comment))

    def stream_load_words(self, stream: str, words: Iterable[int], comment: str = ""):
        """Record an AXIS stream load (e.g. envelope data into a signal generator).

        Parameters
        ----------
        stream : str
            Stream name (e.g. ``"s0_axis"``).
        words : iterable of int
            Data words to push onto the stream.
        comment : str
            Free-form annotation for the JSONL / Vivado replay log.
        """
        self.txns.append(AxiTxn(op="stream", stream=str(stream), words=[int(w) for w in words], comment=comment))

    def save_jsonl(self, path: Union[str, pathlib.Path]) -> pathlib.Path:
        """Serialize the captured transactions to JSONL (one transaction per line).

        Parameters
        ----------
        path : str or pathlib.Path
            Destination file path. Parent directories are created if missing.

        Returns
        -------
        pathlib.Path
            Absolute path to the written JSONL file.
        """
        path = pathlib.Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w") as f:
            for t in self.txns:
                f.write(t.to_json() + "\n")
        return path


# =============================================================================
# Address mapping
# =============================================================================

@dataclass
class RegDef:
    """Definition of a single memory-mapped register.

    Parameters
    ----------
    offset : int
        Byte offset from the owning IP's base address.
    width : int
        Register width in bits (default 32).
    comment : str
        Optional human-readable description.
    """
    offset: int
    width: int = 32
    comment: str = ""


class AddrMap:
    """Maps ``(fullpath, regname)`` to absolute AXI-Lite addresses.

    The address map is split into three tables:

    * ``base_addrs`` : ``fullpath -> base address`` for each IP instance.
    * ``type_by_fullpath`` : ``fullpath -> ip_type`` (e.g. ``"axis_signal_gen_v6"``).
    * ``reg_defs_by_type`` : ``ip_type -> {regname: RegDef}`` shared register
      layout for all instances of a given IP type.

    Parameters
    ----------
    base_addrs : dict of str -> int, optional
        Per-IP base addresses keyed by ``fullpath``.
    reg_defs_by_type : dict, optional
        Register-layout dictionaries keyed by IP type.
    type_by_fullpath : dict of str -> str, optional
        IP type lookup keyed by ``fullpath``.
    """

    def __init__(
        self,
        base_addrs: Optional[Dict[str, int]] = None,
        reg_defs_by_type: Optional[Dict[str, Dict[str, RegDef]]] = None,
        type_by_fullpath: Optional[Dict[str, str]] = None,
    ):
        self.base_addrs: Dict[str, int] = base_addrs or {}
        self.reg_defs_by_type: Dict[str, Dict[str, RegDef]] = reg_defs_by_type or {}
        self.type_by_fullpath: Dict[str, str] = type_by_fullpath or {}

    @staticmethod
    def from_json(path: Union[str, pathlib.Path]) -> "AddrMap":
        """Load a previously saved address map from a JSON file.

        Parameters
        ----------
        path : str or pathlib.Path
            Path to the JSON file produced by :meth:`save`.

        Returns
        -------
        AddrMap
            Address map reconstructed from the JSON document.
        """
        p = pathlib.Path(path)
        d = json.loads(p.read_text())
        reg_defs_by_type = {}
        for typ, regs in d.get("reg_defs_by_type", {}).items():
            reg_defs_by_type[typ] = {rn: RegDef(**rv) for rn, rv in regs.items()}
        return AddrMap(
            base_addrs={k: int(v) for k, v in d.get("base_addrs", {}).items()},
            type_by_fullpath={k: str(v) for k, v in d.get("type_by_fullpath", {}).items()},
            reg_defs_by_type=reg_defs_by_type,
        )

    @classmethod
    def from_qick_config(cls, cfg: Dict[str, Any]) -> "AddrMap":
        """Build an :class:`AddrMap` from a raw ``qick_config`` dictionary.

        Assigns each IP instance a sequential 64 KiB block starting at
        ``0x40000000``, in the order used by the reference ZCU216 firmware:
        ``ddr4_buf``, ``mr_buf``, signal generators, then per-readout the
        ``(ro, avgbuf)`` pair, and finally the tProc(s).

        Parameters
        ----------
        cfg : dict
            Parsed contents of a ``qick_config_*.json`` file.

        Returns
        -------
        AddrMap
            Fully populated address map.
        """
        am = default_addrmap_skeleton()
        current_addr = 0x40000000

        def add(name, typ):
            nonlocal current_addr
            am.base_addrs[name] = current_addr
            am.type_by_fullpath[name] = typ
            current_addr += 0x10000

        if 'ddr4_buf' in cfg: add(cfg['ddr4_buf']['fullpath'], cfg['ddr4_buf']['type'])
        if 'mr_buf' in cfg:   add(cfg['mr_buf']['fullpath'],   cfg['mr_buf']['type'])
        for g in cfg.get('gens', []):     add(g['fullpath'], g['type'])
        for r in cfg.get('readouts', []):
            add(r['ro_fullpath'], r['ro_type'])
            add(r['avgbuf_fullpath'], r['avgbuf_type'])
        for t in cfg.get('tprocs', []):   add(t.get('fullpath', 'qick_processor_0'), t['type'])

        return am

    def resolve(self, fullpath: str, regname: str) -> int:
        """Resolve an IP's register name to an absolute AXI-Lite address.

        Parameters
        ----------
        fullpath : str
            Full hierarchical name of the IP instance (e.g. ``"qick_processor_0"``).
        regname : str
            Register name defined in the IP type's :class:`RegDef` table.

        Returns
        -------
        int
            Absolute 32-bit AXI-Lite address.

        Raises
        ------
        KeyError
            If the IP, IP type, or register name is not found in the map.
        """
        if fullpath not in self.base_addrs:
            raise KeyError(f"AddrMap missing base for '{fullpath}'")
        if fullpath not in self.type_by_fullpath:
            raise KeyError(f"AddrMap missing type for '{fullpath}'")
        typ = self.type_by_fullpath[fullpath]
        if typ not in self.reg_defs_by_type:
            raise KeyError(f"AddrMap missing regs for type '{typ}'")
        regs = self.reg_defs_by_type[typ]
        if regname not in regs:
            raise KeyError(f"AddrMap missing reg '{regname}' in '{typ}'")
        return self.base_addrs[fullpath] + regs[regname].offset

    def to_json(self) -> Dict[str, Any]:
        """Return a JSON-serializable dictionary representation of this map."""
        return {
            "base_addrs": self.base_addrs,
            "type_by_fullpath": self.type_by_fullpath,
            "reg_defs_by_type": {
                typ: {rn: asdict(rd) for rn, rd in regs.items()}
                for typ, regs in self.reg_defs_by_type.items()
            },
        }

    def save(self, path: Union[str, pathlib.Path]) -> pathlib.Path:
        """Serialize this address map to a JSON file.

        Parameters
        ----------
        path : str or pathlib.Path
            Destination file path. Parent directories are created if missing.

        Returns
        -------
        pathlib.Path
            Absolute path to the written JSON file.
        """
        p = pathlib.Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(self.to_json(), indent=2))
        return p


def default_addrmap_skeleton() -> AddrMap:
    """Return an :class:`AddrMap` pre-populated with known QICK IP register layouts.

    Only the ``reg_defs_by_type`` table is filled in; the per-instance
    ``base_addrs`` and ``type_by_fullpath`` tables remain empty and must be
    populated by :meth:`AddrMap.from_qick_config` (or equivalent).
    """
    am = AddrMap()
    
    # Corrected axis_avg_buffer register offsets to match hardware
    am.reg_defs_by_type["axis_avg_buffer"] = {
        "AVG_START":    RegDef(0x00),  "AVG_ADDR":    RegDef(0x04),  "AVG_LEN":    RegDef(0x08),
        "AVG_DR_START": RegDef(0x0C),  "AVG_DR_ADDR": RegDef(0x10),  "AVG_DR_LEN": RegDef(0x14),
        "BUF_START":    RegDef(0x18),  "BUF_ADDR":    RegDef(0x1C),  "BUF_LEN":    RegDef(0x20),
        "BUF_DR_START": RegDef(0x24),  "BUF_DR_ADDR": RegDef(0x28),  "BUF_DR_LEN": RegDef(0x2C),
    }
    am.reg_defs_by_type["axis_dyn_readout_v1"] = {
        "RO_LEN": RegDef(0x10), "OUTSEL": RegDef(0x14),
        "NCO_FREQ": RegDef(0x18), "NCO_PHASE": RegDef(0x1C),
    }
    am.reg_defs_by_type["axis_pfb_readout_v4"] = {
        "PFB_CH": RegDef(0x10), "OUTSEL": RegDef(0x14),
        "NCO_FREQ": RegDef(0x18), "NCO_PHASE": RegDef(0x1C),
    }
    
    am.reg_defs_by_type["axis_signal_gen_v6"] = {
        "NQZ": RegDef(0x10), "MIXER_FREQ": RegDef(0x14), "ENABLE": RegDef(0x18),
    }
    am.reg_defs_by_type["axis_sg_int4_v2"] = {
        "NQZ": RegDef(0x10), "MIXER_FREQ": RegDef(0x14), "PHASE": RegDef(0x18),
        "GAIN": RegDef(0x1C), "ENABLE": RegDef(0x20),
    }
    am.reg_defs_by_type["axis_sg_mixmux8_v1"] = {
        "NQZ": RegDef(0x10), "MIXER_FREQ": RegDef(0x14), "ENABLE": RegDef(0x18),
    }

    am.reg_defs_by_type["axis_tproc_v2"] = {
        "CTRL": RegDef(0x00), "CFG": RegDef(0x04), "CORE_CFG": RegDef(0x1C),
    }
    # Alias qick_processor to axis_tproc_v2 so your config works
    am.reg_defs_by_type["qick_processor"] = am.reg_defs_by_type["axis_tproc_v2"]
    
    am.reg_defs_by_type["axis_buffer_ddr_v1"] = {
        "BUF_START": RegDef(0x08), "BUF_LEN": RegDef(0x0C), "ARM": RegDef(0x10)
    }
    am.reg_defs_by_type["mr_buffer_et"] = {
        "BUF_START": RegDef(0x08), "BUF_LEN": RegDef(0x0C), "ARM": RegDef(0x10)
    }

    return am


# =============================================================================
# Mock Drivers
# =============================================================================

class MockIpDriver:
    """Base class for the minimal IP driver stubs used by :class:`SocEmu`.

    Real QICK IP drivers talk to mmap'd registers on a PYNQ overlay. In the
    emulator we only need to know which IP instance a shim method is targeting
    so the resulting AXI write is tagged with the correct ``fullpath`` —
    everything else is routed through :meth:`SocEmu.reg_write`.

    Parameters
    ----------
    soc : SocEmu
        Parent emulated SoC (owns the :class:`AxiRecorder` and :class:`AddrMap`).
    fullpath : str
        Full hierarchical name of the IP instance.
    ip_type : str
        IP type string (matches a key in ``AddrMap.reg_defs_by_type``).
    """
    def __init__(self, soc: 'SocEmu', fullpath: str, ip_type: str):
        self.soc = soc
        self.fullpath = fullpath
        self.ip_type = ip_type

class MockAvgBuffer(MockIpDriver):
    """Mock driver for :ref:`axis_avg_buffer` (accumulated + decimated readout buffer)."""

    def config_avg(self, address=0, length=1, edge_counting=False, high_threshold=1000, low_threshold=0):
        """Configure the accumulated-sample buffer ("avg"). Mirrors :meth:`AxisAvgBuffer.config_avg`."""
        self.soc.reg_write(self.fullpath, "AVG_START", 0, comment="stop avg")
        self.soc.reg_write(self.fullpath, "AVG_LEN", length, comment="avg buf len")

    def config_buf(self, address=0, length=1):
        """Configure the decimated-sample buffer ("buf"). Mirrors :meth:`AxisAvgBuffer.config_buf`."""
        self.soc.reg_write(self.fullpath, "BUF_START", 0, comment="stop decim")
        self.soc.reg_write(self.fullpath, "BUF_LEN", length, comment="decim buf len")

    def enable(self, avg=True, buf=True):
        """Enable capture for the accumulated and/or decimated buffer.

        Parameters
        ----------
        avg : bool
            Start the accumulated-sample buffer.
        buf : bool
            Start the decimated-sample buffer.
        """
        if avg: self.soc.reg_write(self.fullpath, "AVG_START", 1, comment="start avg")
        if buf: self.soc.reg_write(self.fullpath, "BUF_START", 1, comment="start decim")

class MockDDR4Buffer(MockIpDriver):
    """Mock driver for :ref:`axis_buffer_ddr_v1` (PS-DDR capture buffer)."""

    def set_switch(self, path):
        """Route a switch upstream of the DDR4 buffer (no-op beyond an AXI log entry)."""
        self.soc.axi.write(0, 0, comment=f"DDR4 Switch -> {path}")

    def arm(self, nt=1, force_overwrite=False):
        """Arm the DDR4 capture buffer for ``nt`` triggers."""
        self.soc.reg_write(self.fullpath, "ARM", 1, comment="DDR4 Arm")


class MockPFBReadout(MockIpDriver):
    """Mock driver for the polyphase-filterbank readouts (``axis_pfb_readout_v{2,3,4}``).

    The v2 version has an ``OUTSEL`` register that picks between product /
    input / DDS output; v3 and v4 have a fixed output routing.
    """

    _HAS_OUTSEL_BY_TYPE = {
        "axis_pfb_readout_v2": True,
        "axis_pfb_readout_v3": False,
        "axis_pfb_readout_v4": False,
    }

    @property
    def HAS_OUTSEL(self):
        """True iff the PFB variant exposes a runtime ``OUTSEL`` register."""
        return self._HAS_OUTSEL_BY_TYPE.get(self.ip_type, False)

    def set_out(self, sel='product'):
        """Select the PFB output stream.

        Parameters
        ----------
        sel : {'product', 'input', 'dds'}
            Signal source routed to the downstream readout chain.
        """
        val = {"product": 0, "input": 1, "dds": 2}[sel]
        self.soc.reg_write(self.fullpath, "OUTSEL", val, comment=f"PFB outsel={sel}")

    def set_freq_int(self, cfg):
        """Set the NCO frequency and PFB channel for a single output port.

        Parameters
        ----------
        cfg : dict
            Must include ``pfb_port``, ``pfb_ch``, and ``f_int`` keys as
            produced by the QICK readout config helpers.
        """
        out_ch = cfg.get('pfb_port', 0)
        pfb_ch = cfg.get('pfb_ch', 0)
        f_int = cfg.get('f_int', 0)
        self.soc.reg_write(self.fullpath, "NCO_FREQ", f_int, comment=f"PFB ch{pfb_ch}->out{out_ch} freq")
        self.soc.reg_write(self.fullpath, "PFB_CH", pfb_ch, comment=f"PFB ch{pfb_ch}->out{out_ch} sel")


class MockTProc(MockIpDriver):
    """Mock driver for :ref:`qick_processor` / :ref:`axis_tproc_v2`.

    Only the register writes needed for LFSR configuration and
    :meth:`SocEmu.start_tproc` are modelled; everything else on the real
    tProc driver is a no-op or omitted.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._core_cfg = 0

    def set_lfsr_cfg(self, mode, core=0):
        """Configure the LFSR random-number source for one tProc core.

        Parameters
        ----------
        mode : int
            LFSR mode (``0`` disabled, ``1`` free running, ``2`` step on
            ``s1`` read, ``3`` step on ``s0`` write).
        core : int
            Core index (0 or 1 for dual-core tProc).
        """
        CORE_CFG_LFSR_MASK = 0x3
        self._core_cfg &= ~(CORE_CFG_LFSR_MASK << (core * 2))
        self._core_cfg |= (mode & CORE_CFG_LFSR_MASK) << (core * 2)
        self.soc.reg_write(self.fullpath, "CORE_CFG", self._core_cfg, comment=f"LFSR mode={mode} core={core}")


# =============================================================================
# Emulated Soc
# =============================================================================

class SocEmu:
    """Drop-in mock for :class:`QickSoc` used by QICK programs during ``prepare()``.

    ``SocEmu`` exposes the subset of :class:`QickSoc` methods that QICK
    programs call while configuring the board (``set_nyquist``,
    ``set_mixer_freq``, ``config_avg``, ``config_buf``, ``start_tproc``,
    etc.). Every call is redirected to an :class:`AxiRecorder`, producing
    a deterministic transaction log for the Verilator testbench to replay.

    Parameters
    ----------
    soccfg : QickConfig
        Parsed QICK configuration for the target board.
    raw_cfg : dict
        The raw ``qick_config_*.json`` contents (for fields not exposed by
        :class:`QickConfig`, e.g. ``ddr4_buf``, ``mr_buf``, ``tprocs``).
    addrmap : AddrMap
        Address map used to resolve ``(fullpath, regname)`` to absolute
        AXI-Lite addresses.
    memdir : str or pathlib.Path
        Directory where ``prepare()`` will emit ``pmem.mem`` / ``wmem.mem`` /
        ``sgmem_ch*.mem`` / ``axi_replay.jsonl``.
    recorder : AxiRecorder, optional
        Externally supplied recorder. If ``None``, a new one is created.
    """
    def __init__(
        self,
        soccfg: QickConfig,
        raw_cfg: Dict[str, Any],
        addrmap: AddrMap,
        memdir: Union[str, pathlib.Path],
        recorder: Optional[AxiRecorder] = None,
    ):
        self.soccfg = soccfg
        self.raw_cfg = raw_cfg
        self.addrmap = addrmap
        self.memdir = pathlib.Path(memdir)
        self.memdir.mkdir(parents=True, exist_ok=True)
        self.axi = recorder or AxiRecorder()
        self._results = {}
        self._start_src = "internal"

        # Mock Drivers
        self.gens = [MockIpDriver(self, g['fullpath'], g['type']) for g in soccfg['gens']]
        
        self.avg_bufs = []
        for ro in soccfg['readouts']:
            self.avg_bufs.append(MockAvgBuffer(self, ro['avgbuf_fullpath'], ro['avgbuf_type']))
            
        self.readouts = [MockIpDriver(self, r['ro_fullpath'], r['ro_type']) for r in soccfg['readouts']]
        
        if 'ddr4_buf' in self.raw_cfg:
            self.ddr4_buf = MockDDR4Buffer(self, self.raw_cfg['ddr4_buf']['fullpath'], self.raw_cfg['ddr4_buf']['type'])

        if 'mr_buf' in self.raw_cfg:
            self.mr_buf = MockIpDriver(self, self.raw_cfg['mr_buf']['fullpath'], self.raw_cfg['mr_buf']['type'])

        tproc_cfg = self.raw_cfg['tprocs'][0]
        tproc_path = tproc_cfg.get('fullpath', 'qick_processor_0')
        self.tproc = MockTProc(self, tproc_path, tproc_cfg['type'])

        self._pfb_readouts: Dict[str, MockPFBReadout] = {}
        for ro in soccfg['readouts']:
            if 'pfb_readout' in ro['ro_type']:
                pfb = MockPFBReadout(self, ro['ro_fullpath'], ro['ro_type'])
                self._pfb_readouts[ro['ro_fullpath']] = pfb

    def __getitem__(self, key):
        return self.soccfg[key]

    # ---- QickSoc Shim Methods ----

    def set_nyquist(self, ch, nqz, force=False):
        """Mirror :meth:`QickSoc.set_nyquist`: log the Nyquist-zone write for generator ``ch``."""
        gen = self.gens[ch]
        self.reg_write(gen.fullpath, "NQZ", int(nqz))

    def set_mixer_freq(self, ch, f, ro_ch=None, phase_reset=True, force=False):
        """Mirror :meth:`QickSoc.set_mixer_freq`: log the DAC mixer-frequency write for generator ``ch``."""
        gen = self.gens[ch]
        self.reg_write(gen.fullpath, "MIXER_FREQ", int(f))

    def config_mux_gen(self, ch, tones):
        """Program per-tone frequency registers for a mux signal generator.

        Parameters
        ----------
        ch : int
            Generator channel index.
        tones : list of dict
            One dict per mux tone. ``freq_int`` is the integer frequency
            word the hardware expects.
        """
        gen = self.gens[ch]
        BASE_TONE_REG = 0x40
        for i, tone in enumerate(tones):
            reg_offset = BASE_TONE_REG + (i * 16)
            try:
                base = self.addrmap.base_addrs[gen.fullpath]
                addr = base + reg_offset
                self.axi.write(addr, tone['freq_int'], comment=f"Gen{ch} Tone{i} Freq")
            except KeyError:
                self.axi.write(0xFFFFFFFF, tone['freq_int'], comment=f"UNRESOLVED Gen{ch} Tone{i}")

    def configure_readout(self, ch, ro_regs):
        """Mirror :meth:`QickSoc.configure_readout`: push the program-generated readout register values."""
        ro = self.readouts[ch]
        if 'ro_len' in ro_regs:
            self.reg_write(ro.fullpath, "RO_LEN", ro_regs['ro_len'])

    def config_mux_readout(self, pfbpath, cfgs, sel=None):
        """Configure a PFB readout: set OUTSEL (if supported) and one NCO per tone.

        Parameters
        ----------
        pfbpath : str
            Full hierarchical name of the PFB readout instance.
        cfgs : list of dict
            One dict per tone (as produced by QICK's PFB readout helpers).
        sel : {'product', 'input', 'dds', None}
            Output selection. Only supported on ``axis_pfb_readout_v2``; raise
            on other variants if non-None.
        """
        pfb = self._pfb_readouts[pfbpath]
        if pfb.HAS_OUTSEL:
            if sel is None: sel = 'product'
            pfb.set_out(sel)
        else:
            if sel is not None:
                raise RuntimeError("this readout doesn't support configuring sel, you have sel=%s" % (sel))
        for cfg in cfgs:
            pfb.set_freq_int(cfg)

    def config_avg(self, ch, **kwargs):
        """Forward accumulated-buffer config to :meth:`MockAvgBuffer.config_avg`."""
        self.avg_bufs[ch].config_avg(**kwargs)

    def config_buf(self, ch, **kwargs):
        """Forward decimated-buffer config to :meth:`MockAvgBuffer.config_buf`."""
        self.avg_bufs[ch].config_buf(**kwargs)

    def enable_buf(self, ch, enable_avg=True, enable_buf=True):
        """Forward buffer-enable to :meth:`MockAvgBuffer.enable`."""
        self.avg_bufs[ch].enable(avg=enable_avg, buf=enable_buf)

    def arm_ddr4(self, ch, nt, force_overwrite=False):
        """Arm the DDR4 capture buffer (no-op if the board has no ``ddr4_buf``)."""
        if hasattr(self, 'ddr4_buf'):
            self.ddr4_buf.arm(nt, force_overwrite)

    def load_envelope(self, ch, data, addr):
        """No-op: envelopes are loaded from ``sgmem_ch*.mem`` in the TB, not at configure time."""
        pass

    def load_weights(self, ch, data, addr=0):
        """No-op: readout weights are not modelled in the current testbench."""
        pass

    def load_bin_program(self, binprog, load_mem=True):
        """No-op: the compiled program is loaded from ``pmem.mem`` / ``dmem.mem`` by the TB."""
        pass

    def start_tproc(self):
        """Mirror :meth:`QickSoc.start_tproc`: issue a TIME_RST, then start processor and core."""
        path = self.raw_cfg['tprocs'][0].get('fullpath', "qick_processor_0")
        # Step 1: Reset time counter
        self.reg_write(path, "CTRL", 0x10, comment="TIME_RST (bit 4)")
        # Step 2: Start processor + core
        self.reg_write(path, "CTRL", 0x05, comment="PROC_START (bit 0) + CORE_START (bit 2)")

    def start_src(self, mode: str):
        """Record the configured start source; not otherwise used by the emulator."""
        self._start_src = mode

    def stop_tproc(self, lazy=False):
        """No-op: the TB runs for a fixed ``TEST_RUN_TIME`` regardless."""
        pass

    def reg_write(self, fullpath: str, regname: str, value: int, comment: str = ""):
        """Resolve ``(fullpath, regname)`` through :class:`AddrMap` and append a write to the recorder.

        If the register can't be resolved, the transaction is still recorded
        at the sentinel address ``0xFFFFFFFF`` so missing entries show up as
        a hard-to-miss marker in the replay log.
        """
        try:
            addr = self.addrmap.resolve(fullpath, regname)
            self.axi.write(addr, int(value), comment=comment)
        except KeyError:
            self.axi.write(0xFFFFFFFF, int(value), comment=f"UNRESOLVED: {fullpath}.{regname}")

    def reg_read(self, fullpath: str, regname: str, comment: str = ""):
        """No-op: the emulator doesn't model return values."""
        pass

    def get_decimated(self, ro_ch: int, address=0, length=None) -> np.ndarray:
        """Return a dummy decimated buffer (real data is loaded from CSV post-simulation)."""
        return self._results.get("decimated", {}).get(ro_ch, np.zeros((100, 2)))

    def get_accumulated(self, ro_ch: int, address=0, length=None) -> np.ndarray:
        """Return a dummy accumulated buffer (real data is loaded from CSV post-simulation)."""
        return self._results.get("accumulated", {}).get(ro_ch, np.zeros((1, 2)))


# =============================================================================
# QickEmu
# =============================================================================

class QickEmu:
    """Top-level entry point for preparing and running Verilator simulations of QICK programs.

    A :class:`QickEmu` instance owns the :class:`QickConfig` and
    :class:`AddrMap` for a specific board (described by a
    ``qick_config_*.json`` file). Typical usage:

    .. code-block:: python

        emu = QickEmu("qick_emu_config.json")
        soc = emu.make_soc(memdir="tb_mem")
        emu.prepare(prog, soc, memdir="tb_mem")
        csvs = emu.run_verilator_tb("tb_mem", prog=prog)
        t, samples = emu.load_dac(csvs['dac'].parent)

    Parameters
    ----------
    qick_config_json : str or pathlib.Path
        Path to the board config JSON (e.g. ``qick_emu_config.json``).
    addrmap : AddrMap, str, pathlib.Path, or None
        Pre-built address map, a path to a saved address-map JSON, or
        ``None`` to derive one from the board config with
        :meth:`AddrMap.from_qick_config`.
    backend : object, optional
        Reserved for a future pluggable simulation backend; ignored today.
    """
    def __init__(
        self,
        qick_config_json: Union[str, pathlib.Path],
        *,
        addrmap: Union[None, str, pathlib.Path, AddrMap] = None,
        backend: Optional[Any] = None,
    ):
        self.cfg_path = pathlib.Path(qick_config_json)
        self.soccfg = QickConfig(str(self.cfg_path))
        self.raw_cfg = json.loads(self.cfg_path.read_text())

        if addrmap is None:
            self.addrmap = AddrMap.from_qick_config(self.raw_cfg)
        elif isinstance(addrmap, AddrMap):
            self.addrmap = addrmap
        else:
            self.addrmap = AddrMap.from_json(addrmap)

        self.backend = backend

    def make_soc(self, memdir: Union[str, pathlib.Path] = "tb_mem") -> SocEmu:
        """Return a fresh :class:`SocEmu` wired to this emulator's config and address map.

        Parameters
        ----------
        memdir : str or pathlib.Path
            Directory where :meth:`prepare` will write the testbench artifacts.

        Returns
        -------
        SocEmu
            A drop-in replacement for :class:`QickSoc`.
        """
        return SocEmu(self.soccfg, self.raw_cfg, self.addrmap, memdir=memdir)

    # Known artifact filenames that prepare()/run_verilator_tb() produce.
    # Wiped by prepare() before a new run so stale files from a prior experiment
    # don't get picked up by the testbench or plotting code.
    _ARTIFACT_GLOBS = (
        "pmem.mem", "dmem.mem", "wmem.mem",
        "sgmem_ch*.mem",
        "axi_replay.jsonl", "axi_replay.txt",
        "dac_out.csv", "dac_out_ch*.csv",
        "avg_out.csv", "avg_out_ch*.csv",
        "dec_out.csv", "dec_out_ch*.csv",
    )

    def _clean_artifacts(self, memdir: pathlib.Path) -> None:
        """Remove known artifact files from memdir. Preserves unrelated files."""
        for pattern in self._ARTIFACT_GLOBS:
            for p in memdir.glob(pattern):
                if p.is_file():
                    p.unlink()

    def prepare(self, prog, soc: SocEmu, memdir: Union[str, pathlib.Path] = "tb_mem",
                clean: bool = True) -> Dict[str, Any]:
        """Run a QICK program against the emulated SoC and emit the testbench inputs.

        This drives the program through its usual ``config_all`` /
        ``config_bufs`` / ``start_tproc`` sequence, but every register write
        goes to the :class:`AxiRecorder` instead of real hardware. When the
        method returns, ``memdir`` contains:

        * ``pmem.mem`` — program binary (``print_pmem2hex``).
        * ``dmem.mem`` — data memory (zero-filled if the program doesn't use it).
        * ``wmem.mem`` — waveform parameter table (``print_wmem2hex``).
        * ``sgmem_ch{N}.mem`` — envelope data, one per declared generator
          channel with ``maxlen > 0`` and a non-empty stream (``style="const"``
          pulses produce no envelope so they're skipped).
        * ``axi_replay.jsonl`` — the ordered AXI-Lite transaction log.

        Parameters
        ----------
        prog : qick.QickProgramV2
            A compiled QICK program.
        soc : SocEmu
            Emulated SoC (from :meth:`make_soc`).
        memdir : str or pathlib.Path
            Destination directory for the artifacts listed above.
        clean : bool
            Wipe stale artifacts from ``memdir`` before starting (default
            ``True``) so a previous experiment's files aren't picked up by the
            testbench or the plotting helpers.

        Returns
        -------
        dict
            ``{"memdir": str(memdir), "axi_script": str(axi_replay.jsonl)}``.
        """
        prog.config_all(soc, load_mem=False)
        prog.config_bufs(soc, enable_avg=True, enable_buf=True)

        memdir = pathlib.Path(memdir)
        memdir.mkdir(parents=True, exist_ok=True)
        if clean:
            self._clean_artifacts(memdir)
        
        self._capture_to_file(prog.print_pmem2hex, memdir / "pmem.mem")
        
        # --- DMEM CAPTURE & ZERO-FILL FIX ---
        dmem_path = memdir / "dmem.mem"
        self._capture_to_file(prog.print_dmem2hex if hasattr(prog, "print_dmem2hex") else lambda f: None, dmem_path)
        
        # If the program doesn't use Data Memory, the file might be completely empty.
        # Write a single line of zeros so Verilator clears the garbage at address 0.
        if not dmem_path.exists() or dmem_path.stat().st_size == 0:
            dmem_path.write_text("00000000\n")
        # ------------------------------------
        
        try:
            prog.print_wmem2hex(stem=str(memdir / "wmem"))
        except TypeError:
            self._capture_to_file(prog.print_wmem2hex, memdir / "wmem.mem")

        wmem_path = memdir / "wmem.mem"
        if wmem_path.exists():
            fixed = "\n".join(
                line.lstrip("_") if not line.startswith("//") else line
                for line in wmem_path.read_text().splitlines()
            )
            wmem_path.write_text(fixed + "\n")
            
        gens = self.raw_cfg.get("gens", [])
        declared_gen_chs = sorted(getattr(prog, 'gen_chs', {}).keys())
        for ch in declared_gen_chs:
            if ch < len(gens) and gens[ch].get('maxlen', 0) > 0:
                buf = io.StringIO()
                with contextlib.redirect_stdout(buf):
                    prog.print_sg_mem(sg_idx=ch, gen_file=False)
                content = buf.getvalue()
                if content.strip():
                    (memdir / f"sgmem_ch{ch}.mem").write_text(content)

        soc.start_tproc()
        axi_script = soc.axi.save_jsonl(memdir / "axi_replay.jsonl")
        
        return {"memdir": str(memdir), "axi_script": str(axi_script)}

    @staticmethod
    def _capture_to_file(fn, out_path: Union[str, pathlib.Path], *args, **kwargs):
        """Run ``fn`` into ``out_path``, tolerating callables that only print to stdout.

        QICK's ``print_*2hex`` helpers vary: some accept a file path, others
        only print to stdout. Try the path argument first, fall back to
        capturing stdout.
        """
        try:
            fn(str(out_path), *args, **kwargs)
        except TypeError:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                fn(*args, **kwargs)
            out_path.write_text(buf.getvalue())

    def _find_proj_root(self) -> pathlib.Path:
        """Find the root of the qick repository to locate the PULP submodules."""
        here = pathlib.Path(__file__).resolve().parent
        for ancestor in [here] + list(here.parents):
            candidate = ancestor / "firmware" / "testbench" / "qick_testbench" / "Makefile"
            if candidate.exists():
                return ancestor
        return here.parent.parent  # Fallback

    # =========================================================================
    # VERILATOR RUNNERS
    # =========================================================================

    def run_verilated_mem_tb(
        self,
        mem_file,
        ro_dec_len: int = 1000,
        ro_avg_len: int = 1,
        verilog_dir=None,
        top_module="tb_qick_emu_verilator",
        sources=("tb_qick_emu_verilator.sv",),
        build_dir="build_tb_mem",
        log_csv_name="dac_out.csv",
        mem_filename_in_tb="wmem.mem",
        enable_wave=False,
        extra_verilator_args=None,
        verbose=True,
    ):
        """Verilate and run a stand-alone testbench that reads a single memory file.

        This is the "lightweight" path used by some of the smaller model
        testbenches (e.g. dds / signal_gen). It links in the PULP AXI
        sources, symlinks ``mem_file`` into the build directory as
        ``mem_filename_in_tb``, runs the binary with ``+RO_DEC_LEN`` /
        ``+RO_AVG_LEN`` plusargs, and returns the path to the resulting
        CSV.

        Parameters
        ----------
        mem_file : str or pathlib.Path
            Path to the ``.mem`` file that the TB reads via ``$readmemh``.
        ro_dec_len : int
            Plusarg value passed as ``+RO_DEC_LEN``.
        ro_avg_len : int
            Plusarg value passed as ``+RO_AVG_LEN``.
        verilog_dir : str or pathlib.Path, optional
            Directory containing the TB sources listed in ``sources`` (default cwd).
        top_module : str
            Name of the top-level Verilog module.
        sources : tuple of str
            Verilog sources under ``verilog_dir`` to compile.
        build_dir : str or pathlib.Path
            Verilator ``-Mdir`` build directory.
        log_csv_name : str
            Filename of the CSV produced by the TB.
        mem_filename_in_tb : str
            Name the TB ``$readmemh`` expects inside ``build_dir``.
        enable_wave : bool
            If ``True``, compile with ``--trace-fst``.
        extra_verilator_args : list of str, optional
            Additional Verilator CLI flags.
        verbose : bool
            Print the Verilator / sim commands and output paths.

        Returns
        -------
        pathlib.Path
            Path to the generated CSV file.
        """
        import os, shutil, subprocess
        from pathlib import Path

        verilog_dir = Path(verilog_dir) if verilog_dir is not None else Path.cwd()
        build_dir = Path(build_dir)
        build_dir.mkdir(parents=True, exist_ok=True)
        
        proj_root = self._find_proj_root()
        # pulp_dir = proj_root / "firmware" / "pulp_platform"
        pulp_dir = proj_root / "emulator" / "submodules" / "pulp_platform"
        
        pulp_sources = [
            pulp_dir / "common_verification/src/rand_id_queue.sv",
            pulp_dir / "axi/src/axi_intf.sv",
            pulp_dir / "axi/src/axi_pkg.sv",
            pulp_dir / "axi/src/axi_test.sv"
        ]

        src_paths = [verilog_dir / s for s in sources] + pulp_sources
        for sp in src_paths:
            if not sp.exists():
                print(f"[warn] Verilog source not found: {sp}")

        verilator = shutil.which("verilator") or "/opt/homebrew/bin/verilator"
        if not shutil.which("verilator") and not Path(verilator).exists():
            raise FileNotFoundError("verilator not found in PATH.")

        mem_file = Path(mem_file)
        if not mem_file.exists():
            raise FileNotFoundError(f"mem_file not found: {mem_file}")
        
        target_mem = build_dir / mem_filename_in_tb
        try:
            if target_mem.exists() or target_mem.is_symlink():
                target_mem.unlink()
            target_mem.symlink_to(mem_file.resolve())
        except Exception:
            shutil.copy2(mem_file, target_mem)

        exe_name = f"V{top_module}"
        cmd = [str(verilator), "--binary", "-sv", "-Wall", "-Mdir", str(build_dir), "--top-module", top_module]
        if enable_wave: cmd += ["--trace-fst"]
        
        cmd += [
            f"-I{pulp_dir}/axi/include",
            f"-I{pulp_dir}/common_verification/include",
            f"-I{pulp_dir}/common_cells/include"
        ]

        if extra_verilator_args: cmd += list(extra_verilator_args)
        cmd += [str(p) for p in src_paths]

        if verbose: print("$", " ".join(cmd))
        subprocess.run(cmd, check=True, cwd=verilog_dir)

        candidates = [build_dir / exe_name, build_dir / f"{exe_name}.exe"]
        sim_path = next((p for p in candidates if p.exists()), None)
        if sim_path is None:
            for p in build_dir.rglob(f"V{top_module}*"):
                if p.is_file() and os.access(p, os.X_OK):
                    sim_path = p
                    break
        if sim_path is None:
            raise FileNotFoundError(f"Verilator binary not found under {build_dir}")

        sim_cmd = [f"./{sim_path.name}", f"+RO_DEC_LEN={int(ro_dec_len)}", f"+RO_AVG_LEN={int(ro_avg_len)}"]
        if verbose: print(f"$ (cd {build_dir} && {' '.join(sim_cmd)})")
        subprocess.run(sim_cmd, check=True, cwd=build_dir)
        
        out_csv = build_dir / log_csv_name
        if not out_csv.exists():
            raise FileNotFoundError(f"Expected CSV not found: {out_csv}")
        if verbose: print(f"[ok] Wrote {out_csv}")
        return out_csv

    def _find_tb_makefile(self) -> pathlib.Path:
        """Locate ``firmware/testbench/qick_testbench/Makefile`` used by :meth:`run_verilator_tb`."""
        proj_root = self._find_proj_root()
        candidate = proj_root / "firmware" / "testbench" / "qick_testbench" / "Makefile"
        if not candidate.exists():
            raise FileNotFoundError("Cannot find firmware/testbench/qick_testbench/Makefile.")
        return candidate

    @staticmethod
    def _auto_buf_lens(prog) -> Tuple[int, int]:
        """Compute (ro_dec_len, ro_avg_len) from the program's first readout.

        Mirrors what ``acquire_decimated`` sizes its buffers to: one decimated
        window per shot per rep, one accumulated sample per shot per rep.
        """
        import functools, operator
        if not getattr(prog, "ro_chs", None):
            return 1000, 1
        ch, ro = next(iter(prog.ro_chs.items()))
        total_count = functools.reduce(operator.mul, prog.loop_dims, 1)
        trigs = ro.get("trigs", 1)
        length = ro.get("length", 1)
        ro_dec_len = int(total_count * trigs * length)
        ro_avg_len = int(total_count * trigs)
        return max(ro_dec_len, 1), max(ro_avg_len, 1)

    def run_verilator_tb(
        self,
        emu_dir: Union[str, pathlib.Path],
        prog=None,
        ro_dec_len: Optional[int] = None,
        ro_avg_len: Optional[int] = None,
        mr_len: int = 0,
        *,
        build: bool = True,
        verbose: bool = True,
        timeout: Optional[int] = 300,
    ) -> Dict[str, pathlib.Path]:
        """Invoke ``make verilate`` / ``make sim`` on the full-system TB and collect its CSVs.

        ``emu_dir`` is the directory written by :meth:`prepare` — the TB
        reads its ``pmem.mem`` / ``wmem.mem`` / ``sgmem_ch*.mem`` /
        ``axi_replay.txt`` and writes ``dac_out.csv`` / ``avg_out.csv`` /
        ``dec_out.csv`` back into the same directory.

        Parameters
        ----------
        emu_dir : str or pathlib.Path
            Directory produced by :meth:`prepare`. Passed to the TB as
            ``SIM_EMU_DIR``.
        prog : qick.QickProgramV2, optional
            If provided, ``ro_dec_len`` and ``ro_avg_len`` default to values
            derived from ``prog.loop_dims`` / ``prog.ro_chs`` via
            :meth:`_auto_buf_lens`.
        ro_dec_len : int, optional
            Override for the decimated-buffer read length plusarg.
        ro_avg_len : int, optional
            Override for the accumulated-buffer read length plusarg.
        build : bool
            Run ``make verilate`` before ``make sim`` (default ``True``).
        verbose : bool
            If ``True``, stream build/sim output to the terminal. If
            ``False``, capture and include it only when the subprocess fails.
        timeout : int or None
            Per-subprocess timeout in seconds.

        Returns
        -------
        dict
            Mapping of short key (``"dac"``, ``"avg"``, ``"dec"``) to
            :class:`pathlib.Path` for each CSV file actually produced.
        """
        # Auto-size buffer reads from `prog` so CSV lengths line up with
        # prog.get_time_axis() / prog.ro_chs and downstream loaders work without
        # the user having to compute them by hand.
        if (ro_dec_len is None or ro_avg_len is None) and prog is not None:
            auto_dec, auto_avg = self._auto_buf_lens(prog)
            if ro_dec_len is None:
                ro_dec_len = auto_dec
            if ro_avg_len is None:
                ro_avg_len = auto_avg
        if ro_dec_len is None:
            ro_dec_len = 1000
        if ro_avg_len is None:
            ro_avg_len = 1
        makefile = self._find_tb_makefile()
        tb_dir = makefile.parent

        emu_dir = pathlib.Path(emu_dir).resolve()
        if not emu_dir.exists():
            raise FileNotFoundError(f"EMU_DIR does not exist: {emu_dir}")

        try:
            rel_emu = emu_dir.relative_to(tb_dir.resolve())
        except ValueError:
            rel_emu = emu_dir

        run_kw = dict(cwd=tb_dir, capture_output=not verbose, text=True)

        if build:
            if verbose:
                print(f"[verilate] Building tb_qick_emu_verilator ...")
            result = subprocess.run(
                ["make", "verilate"], timeout=timeout, **run_kw
            )
            if result.returncode != 0:
                raise RuntimeError(
                    f"make verilate failed (rc={result.returncode})"
                    + ("" if verbose else f"\n{result.stderr}")
                )

        if verbose:
            print(f"[sim] Running simulation with EMU_DIR={rel_emu} ...")
            
        sim_args_str = (
            f"SIM_ARGS=+RO_DEC_LEN={int(ro_dec_len)} "
            f"+RO_AVG_LEN={int(ro_avg_len)} "
            f"+MR_LEN={int(mr_len)}"
        )
        result = subprocess.run(
            ["make", "sim", f"SIM_EMU_DIR={rel_emu}", sim_args_str], timeout=timeout, **run_kw
        )
        
        if result.returncode != 0:
            raise RuntimeError(
                f"make sim failed (rc={result.returncode})"
                + ("" if verbose else f"\n{result.stderr}")
            )

        csvs = {}
        for key, name in [
            ("dac", "dac_out.csv"),
            ("avg", "avg_out.csv"),
            ("dec", "dec_out.csv"),
            ("mr",  "mr_out.csv"),
        ]:
            p = emu_dir / name
            if p.exists():
                csvs[key] = p
        if not csvs:
            raise FileNotFoundError(f"No CSV outputs found in {emu_dir}.")
        if verbose:
            print(f"[ok] CSV outputs: {', '.join(f'{k}={v.name}' for k, v in csvs.items())}")
        return csvs

    # ── plotting helpers ──────────────────────────────────────────────────
    @staticmethod
    def plot_dac_csv(
        csv_path: Union[str, pathlib.Path],
        *,
        time_unit: str = "us",
        title: str = "DAC Output",
        channels: Optional[List[int]] = None,
        ax=None,
        absolute_time: bool = False,
    ):
        """Plot the sequential DAC stream from a ``dac_out.csv`` file.

        The TB writes one row per sg_clk, with 16 parallel DDS samples
        (``s0`` through ``s15``) per row. This helper flattens them into a
        single time series at the true sample rate.

        Parameters
        ----------
        csv_path : str or pathlib.Path
            Path to the CSV produced by the TB.
        time_unit : {'fs', 'ps', 'ns', 'us', 'ms'}
            Unit for the x-axis.
        title : str
            Figure title.
        channels : list of int, optional
            Kept for API compatibility; currently unused.
        ax : matplotlib.axes.Axes, optional
            Draw into an existing Axes instead of creating a new figure.
        absolute_time : bool
            Keep the raw sim time; otherwise shift so the first sample sits
            at ``t=0`` (the TB spends ~20 µs loading envelopes via AXIS
            before the first DAC sample).

        Returns
        -------
        matplotlib.figure.Figure or None
            The figure, or ``None`` if the CSV was empty.
        """
        import matplotlib.pyplot as plt

        data = np.genfromtxt(csv_path, delimiter=",", names=True, dtype=None)
        if data.size == 0:
            print(f"[warn] {csv_path} is empty — nothing to plot")
            return None

        # The hardware outputs 16 parallel samples per clock
        n_dds = 16 
        
        # Flatten the 16 parallel columns into a single sequential 1D array
        seq_data = np.column_stack([data[f"s{i}"] for i in range(n_dds)]).flatten()
        
        # Reconstruct the high-resolution time array
        # NB: the TB writes "$time" with `timescale 1ns/1fs`, so the column
        # labelled "time_ps" actually contains *fs* counts.
        if len(data) > 1:
            clk_period_fs = data["time_ps"][1] - data["time_ps"][0]
        else:
            clk_period_fs = 1.6693e6  # Fallback (~1669 ps)

        sample_period_fs = clk_period_fs / n_dds
        # By default normalise to t=0 (TB has ~20 µs of SG-load setup time
        # before the first DAC sample). Pass absolute_time=True to opt out.
        t_origin_fs = 0.0 if absolute_time else float(data["time_ps"][0])
        t_fs = (data["time_ps"][0] - t_origin_fs) + np.arange(len(seq_data)) * sample_period_fs

        scale = {"fs": 1.0, "ps": 1e-3, "ns": 1e-6, "us": 1e-9, "ms": 1e-12}[time_unit]
        t = t_fs * scale

        if ax is None:
            fig, ax = plt.subplots(figsize=(12, 4))
        else:
            fig = ax.figure

        ax.plot(t, seq_data, linewidth=1.0, color='#1f77b4')
        ax.set_xlabel(f"time [{time_unit}]")
        ax.set_ylabel("DAC value")
        ax.set_title(title)
        ax.grid(True, linestyle=":", alpha=0.5)
        fig.tight_layout()
        return fig

    @staticmethod
    def plot_iq_csv(
        csv_path: Union[str, pathlib.Path],
        *,
        time_unit: str = "us",
        title: str = "I/Q",
        ax=None,
    ):
        """Plot the I / Q columns of a readout CSV (``avg_out.csv`` or ``dec_out.csv``).

        Parameters
        ----------
        csv_path : str or pathlib.Path
            Path to the CSV produced by the TB.
        time_unit : {'fs', 'ps', 'ns', 'us', 'ms'}
            Unit for the x-axis.
        title : str
            Figure title.
        ax : matplotlib.axes.Axes, optional
            Draw into an existing Axes instead of creating a new figure.

        Returns
        -------
        matplotlib.figure.Figure or None
            The figure, or ``None`` if the CSV was empty.
        """
        import matplotlib.pyplot as plt

        data = np.genfromtxt(csv_path, delimiter=",", names=True, dtype=None)
        if data.size == 0:
            print(f"[warn] {csv_path} is empty — nothing to plot")
            return None

        # CSV column "time_ps" contains fs counts (TB uses 1ns/1fs timescale).
        scale = {"fs": 1.0, "ps": 1e-3, "ns": 1e-6, "us": 1e-9, "ms": 1e-12}[time_unit]
        t = data["time_ps"] * scale

        if ax is None:
            fig, ax = plt.subplots(figsize=(12, 4))
        else:
            fig = ax.figure

        ax.plot(t, data["I"], linewidth=0.8, label="I")
        ax.plot(t, data["Q"], linewidth=0.8, label="Q")
        ax.set_xlabel(f"time [{time_unit}]")
        ax.set_ylabel("value")
        ax.set_title(title)
        ax.grid(True, linestyle=":", alpha=0.5)
        ax.legend()
        fig.tight_layout()
        return fig

    # ── data-first loaders (mirror prog.acquire / prog.acquire_decimated) ──
    @staticmethod
    def _find_ch_csv(emu_dir: pathlib.Path, stem: str, ch: int) -> Optional[pathlib.Path]:
        """Locate a per-channel CSV (stem_chN.csv) or fall back to the single-channel file."""
        per_ch = emu_dir / f"{stem}_ch{ch}.csv"
        if per_ch.exists():
            return per_ch
        plain = emu_dir / f"{stem}.csv"
        if plain.exists():
            return plain
        return None

    def load_dac(
        self,
        emu_dir: Union[str, pathlib.Path],
        gen_ch: Optional[int] = None,
        *,
        time_unit: str = "us",
        absolute_time: bool = False,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Load DAC samples as a flat 1D array plus a time axis.

        The TB emits 16 parallel samples per valid ``sg_clk`` edge (one CSV
        row per clock). To get a scope-like 1D stream we unroll each row
        into 16 sub-samples spaced by ``clk_period/16``.

        Between pulses the TB stops logging rows because the CSV writer
        gates on ``axis_sg_dac_tvalid``, but the DAC itself is physically
        driving zero during that idle time (see ``dac_data <= 'd0`` in the
        TB). Per-row time placement alone does not stop matplotlib from
        connecting the surviving points with a diagonal — if one pulse
        ends at full amplitude (e.g. a ``const`` pulse) the line rendered
        across the gap looks like a spurious ramp. To restore the true
        idle baseline we insert a pair of zero-valued samples at each
        gap: one just past the last sub-sample of the preceding row, one
        just before the first sub-sample of the next row. matplotlib then
        draws pulse-end → 0 → 0 → pulse-start, i.e. a flat zero line
        across the dead time, matching the physical DAC behaviour. The
        returned samples array is therefore float, not int.

        By default the time axis is normalised to the first DAC sample (so
        the plot starts at t=0). The TB spends ~20 µs streaming the SG
        envelope into BRAM via AXIS at the slow ``s_ps_dma_aclk`` before
        tproc fires, so absolute timestamps include that setup overhead and
        aren't useful for visualising the program waveform. Pass
        ``absolute_time=True`` to keep raw sim-time values.

        Parameters
        ----------
        emu_dir : str or pathlib.Path
            Directory containing the ``dac_out*.csv`` file.
        gen_ch : int, optional
            Generator channel for per-channel CSVs (``dac_out_ch{N}.csv``).
            Defaults to channel 0 (and falls back to the single-channel
            ``dac_out.csv`` if no per-channel file exists).
        time_unit : {'fs', 'ps', 'ns', 'us', 'ms'}
            Unit for the returned time axis.
        absolute_time : bool
            If ``True``, return raw sim-time values instead of normalising
            to the first DAC sample.

        Returns
        -------
        t : numpy.ndarray
            Time axis in ``time_unit``.
        samples : numpy.ndarray
            Flat DAC stream aligned to ``t``.
        """
        emu_dir = pathlib.Path(emu_dir)
        csv = self._find_ch_csv(emu_dir, "dac_out", gen_ch if gen_ch is not None else 0)
        if csv is None:
            raise FileNotFoundError(f"No dac_out CSV in {emu_dir}")

        data = np.genfromtxt(csv, delimiter=",", names=True, dtype=None)
        if data.size == 0:
            return np.array([]), np.array([])

        n_dds = 16
        # NB: TB uses `timescale 1ns/1fs`, so the column labelled "time_ps"
        # actually contains *fs* counts.
        t_rows = np.atleast_1d(data["time_ps"]).astype(float)

        # Estimate the sg_clk period. Verilator can quantize $time to 1 ns
        # resolution, which turns the true 1.6693 ns period into an alternating
        # 1/2/2/1/2/2 ns row-to-row delta pattern in the CSV. min() picks 1 ns
        # and packs the 16 sub-samples ~40% too tight; median over all diffs is
        # biased high by the much larger inter-pulse gaps. Compromise: mean of
        # diffs within 3× the minimum — keeps every legitimate consecutive-clock
        # delta and excludes only the big idle gaps.
        clk_period_fs = 1.6693e6  # fallback (~600 MHz sg_clk)
        if t_rows.size > 1:
            diffs = np.diff(t_rows)
            positive = diffs[diffs > 0]
            if positive.size:
                min_d = float(np.min(positive))
                close = positive[positive < 3 * min_d]
                if close.size:
                    clk_period_fs = float(np.mean(close))
        sample_period_fs = clk_period_fs / n_dds

        # Per-row sub-sample layout: row i spans [t_row[i], t_row[i] + 16*sample_period).
        # float dtype so we can mix in zero bookends without losing precision.
        samples_2d = np.column_stack(
            [data[f"s{i}"] for i in range(n_dds)]
        ).astype(float)
        t_2d = t_rows[:, None] + np.arange(n_dds)[None, :] * sample_period_fs

        # Detect row-to-row gaps larger than one clock period. These are dead-time
        # intervals where the SG held tvalid low (no CSV row logged) but the DAC
        # itself is sitting at 0. Insert two zero-valued samples — one just past
        # the trailing row and one just before the leading row — so matplotlib
        # renders the idle baseline as a flat zero line rather than a diagonal
        # joining the last sample of one pulse to the first sample of the next.
        if t_rows.size > 1:
            gap_mask = np.diff(t_rows) > 1.5 * clk_period_fs
        else:
            gap_mask = np.array([], dtype=bool)

        if gap_mask.any():
            t_chunks: List[np.ndarray] = []
            s_chunks: List[np.ndarray] = []
            for i in range(t_rows.size):
                t_chunks.append(t_2d[i])
                s_chunks.append(samples_2d[i])
                if i < gap_mask.size and gap_mask[i]:
                    t_gap_lo = t_rows[i] + n_dds * sample_period_fs
                    t_gap_hi = t_rows[i + 1] - sample_period_fs
                    # Guard against pathologically small gaps — shouldn't happen
                    # given the 1.5× threshold above, but cheap to check.
                    if t_gap_hi > t_gap_lo:
                        t_chunks.append(np.array([t_gap_lo, t_gap_hi]))
                        s_chunks.append(np.array([0.0, 0.0]))
            t_fs = np.concatenate(t_chunks)
            samples = np.concatenate(s_chunks)
        else:
            t_fs = t_2d.flatten()
            samples = samples_2d.flatten()

        # Normalise to the first sample by default — see docstring.
        if not absolute_time and t_fs.size:
            t_fs = t_fs - np.nanmin(t_fs)

        scale = {"fs": 1.0, "ps": 1e-3, "ns": 1e-6, "us": 1e-9, "ms": 1e-12}[time_unit]
        return t_fs * scale, samples

    def load_mr(
        self,
        emu_dir: Union[str, pathlib.Path],
        *,
        time_unit: str = "us",
        absolute_time: bool = False,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Load MR buffer (full-rate, post-downconversion) I/Q samples.

        ``mr_out.csv`` rows hold 8 I/Q pairs per ``ro_clk`` edge. This helper
        unrolls the 8 lanes into a 1-D sample stream (as the real MR buffer
        would present them) and returns the matching time axis.

        Parameters
        ----------
        emu_dir : str or pathlib.Path
            Directory containing ``mr_out.csv``.
        time_unit : {'fs', 'ps', 'ns', 'us', 'ms'}
            Unit for the returned time axis.
        absolute_time : bool
            Keep raw sim-time. Default shifts so the first sample is at t=0.

        Returns
        -------
        t : numpy.ndarray
            Time axis in ``time_unit``.
        iq : numpy.ndarray
            Array of shape ``(N, 2)`` with interleaved I / Q samples.
        """
        emu_dir = pathlib.Path(emu_dir)
        csv = emu_dir / "mr_out.csv"
        if not csv.exists() or csv.stat().st_size == 0:
            return np.array([]), np.zeros((0, 2), dtype=float)

        data = np.genfromtxt(csv, delimiter=",", names=True, dtype=None)
        if data.size == 0:
            return np.array([]), np.zeros((0, 2), dtype=float)

        n_lanes = 8
        t_rows = np.atleast_1d(data["time_ps"]).astype(float)

        # Estimate ro_clk period from consecutive-row deltas (same trick as
        # load_dac). Verilator's $time is quantised to 1 ns, so pick the mean
        # over diffs within 3× the minimum.
        clk_period_fs = float(1e6 / 0.3072)  # ~3.255 ns (307.2 MHz ro_clk)
        if t_rows.size > 1:
            diffs = np.diff(t_rows)
            positive = diffs[diffs > 0]
            if positive.size:
                min_d = float(np.min(positive))
                close = positive[positive < 3 * min_d]
                if close.size:
                    clk_period_fs = float(np.mean(close))
        sample_period_fs = clk_period_fs / n_lanes

        I = np.column_stack([data[f"I{i}"] for i in range(n_lanes)]).astype(float)
        Q = np.column_stack([data[f"Q{i}"] for i in range(n_lanes)]).astype(float)
        iq = np.stack([I.flatten(), Q.flatten()], axis=-1)

        t_fs = (t_rows[:, None] + np.arange(n_lanes)[None, :] * sample_period_fs).flatten()
        if not absolute_time and t_fs.size:
            t_fs = t_fs - np.nanmin(t_fs)

        scale = {"fs": 1.0, "ps": 1e-3, "ns": 1e-6, "us": 1e-9, "ms": 1e-12}[time_unit]
        return t_fs * scale, iq

    @staticmethod
    def _read_iq_csv(csv: pathlib.Path) -> np.ndarray:
        """Return an (N, 2) float array of [I, Q] samples from a dec/avg CSV."""
        data = np.genfromtxt(csv, delimiter=",", names=True, dtype=None)
        if data.size == 0:
            return np.zeros((0, 2), dtype=float)
        # genfromtxt returns a 0-d array for a single row; normalise to 1-d.
        I = np.atleast_1d(data["I"]).astype(float)
        Q = np.atleast_1d(data["Q"]).astype(float)
        return np.stack([I, Q], axis=-1)

    def load_iq_decimated(
        self,
        emu_dir: Union[str, pathlib.Path],
        prog,
        *,
        align_to_signal: bool = False,
    ) -> List[np.ndarray]:
        """Load decimated I/Q samples shaped like ``prog.acquire_decimated(soc)``.

        Returns a list (one entry per declared readout channel) matching the
        shape rules in ``QickProgramV2._process_decimated``:

        * single-rep, single-read        : ``(length, 2)``
        * multi-rep or multi-read        : ``(n_reps*n_reads, length, 2)``
        * multi-rep AND multi-read       : ``(n_reps, n_reads, length, 2)``

        If the CSV has more or fewer rows than expected (TB plusarg mismatch,
        sim cutoff, or the actual captured window being shorter than the
        program's ``ro["length"]``), the array is trimmed to a length that
        divides evenly into ``total_count * trigs`` shots. Partial trailing
        shots are discarded rather than raising ValueError; a warning is
        emitted when per-shot length doesn't match the program's expectation.

        Parameters
        ----------
        emu_dir : str or pathlib.Path
            Directory containing the ``dec_out*.csv`` files.
        prog : QickProgramV2
            Program whose ``ro_chs`` / ``loop_dims`` dictate the output shape.
        align_to_signal : bool, optional
            If True, skip leading near-zero rows produced while the readout
            FIR/decimator settles. WARNING: those samples are usually
            legitimate (the FIR's natural startup transient) and stripping
            them shortens the array, which then won't match
            ``prog.get_time_axis()``. Only enable for signal-only inspection
            where time-axis alignment is not needed. Default False.

        Returns
        -------
        list of numpy.ndarray
            One entry per readout channel, shaped per the rules above.
        """
        import functools, operator, warnings
        emu_dir = pathlib.Path(emu_dir)
        total_count = functools.reduce(operator.mul, prog.loop_dims, 1)
        onetrig = all(ro["trigs"] == 1 for ro in prog.ro_chs.values())

        result: List[np.ndarray] = []
        for ch, ro in prog.ro_chs.items():
            csv = self._find_ch_csv(emu_dir, "dec_out", ch)
            if csv is None:
                raise FileNotFoundError(f"No dec_out CSV for ro_ch={ch} in {emu_dir}")
            d = self._read_iq_csv(csv)
            # Skip leading zero rows from the latency pad / FIR settling.
            if align_to_signal and len(d):
                nz = np.where(np.abs(d[:, 0]) + np.abs(d[:, 1]) > 0)[0]
                if nz.size:
                    d = d[nz[0]:]
            # Match the CSV row count to an integer number of complete shots.
            # The TB can deliver a different row count than the program predicts:
            #   - MORE rows: RO_DEC_LEN plusarg > ro["length"] * total_count.
            #     Trim tail down to the expected length.
            #   - FEWER rows: sim hit TEST_RUN_TIME early, or the avg_buffer's
            #     captured window is shorter than ro["length"] (e.g. ro_clk in
            #     the TB runs at a lower rate than the program's config
            #     assumes — we see ~26 samples/shot for a 108-sample program
            #     request, roughly 1/4).
            # In both cases, trim to the largest integer multiple of
            # (total_count * trigs) and use the implied per-shot length.
            n_shots = total_count * ro["trigs"]
            if n_shots == 0:
                result.append(d)
                continue
            intended_per_shot = ro["length"]
            actual_per_shot = len(d) // n_shots
            if actual_per_shot == 0:
                raise ValueError(
                    f"dec_out for ch={ch} has {len(d)} rows, which is fewer "
                    f"than one sample per shot for {n_shots} expected shots. "
                    f"Check that the TB finished and RO_DEC_LEN was set "
                    f"correctly."
                )
            per_shot = min(intended_per_shot, actual_per_shot)
            d = d[:n_shots * per_shot]
            if per_shot != intended_per_shot:
                warnings.warn(
                    f"dec_out for ch={ch}: program expected {intended_per_shot} "
                    f"samples/shot but CSV supplies {actual_per_shot}. Plots "
                    f"using prog.get_time_axis() may not align — truncated to "
                    f"{per_shot} samples/shot."
                )
            if total_count == 1 and onetrig:
                result.append(d)
            else:
                if onetrig or total_count == 1:
                    result.append(d.reshape(n_shots, per_shot, 2))
                else:
                    result.append(d.reshape(total_count, ro["trigs"], per_shot, 2))
        return result

    def load_iq_averaged(
        self,
        emu_dir: Union[str, pathlib.Path],
        prog,
        *,
        length_norm: bool = True,
    ) -> List[np.ndarray]:
        """Load accumulated I/Q shots shaped like ``prog.acquire(soc)``.

        One entry per declared readout channel. Shape is
        ``(trigs, *remaining_loop_dims, 2)`` — matching the
        ``_average_buf`` output after averaging over ``prog.avg_level``.

        Parameters
        ----------
        emu_dir : str or pathlib.Path
            Directory containing the ``avg_out*.csv`` files.
        prog : QickProgramV2
            Program whose ``ro_chs`` / ``loop_dims`` / ``avg_level`` dictate
            reshape and averaging behavior.
        length_norm : bool, optional
            If True (default), divide accumulated sums by ``ro["length"]``
            to match ``acquire()``'s length normalization. Skipped for
            edge-counting readouts.

        Returns
        -------
        list of numpy.ndarray
            One entry per readout channel, shaped
            ``(trigs, *remaining_loop_dims, 2)``.
        """
        emu_dir = pathlib.Path(emu_dir)

        import functools, operator
        total_count = functools.reduce(operator.mul, prog.loop_dims, 1)

        result: List[np.ndarray] = []
        for ch, ro in prog.ro_chs.items():
            csv = self._find_ch_csv(emu_dir, "avg_out", ch)
            if csv is None:
                raise FileNotFoundError(f"No avg_out CSV for ro_ch={ch} in {emu_dir}")
            d = self._read_iq_csv(csv).astype(float)
            # Trim trailing rows if the TB emitted more shots than the program needs.
            expected = total_count * ro["trigs"]
            if len(d) > expected:
                d = d[:expected]
            # Reshape flat (N, 2) into (*loop_dims, trigs, 2).
            shape = tuple(prog.loop_dims) + (ro["trigs"], 2)
            d = d.reshape(shape)
            # Average over the reps/avg axis.
            d = d.mean(axis=prog.avg_level)
            if length_norm and not ro.get("edge_counting", False):
                d = d / ro["length"]
            # Move trigs axis to the front (acquire() convention).
            d = np.moveaxis(d, -2, 0)
            result.append(d)
        return result

    def export_vivado_files(
        self,
        memdir: Union[str, pathlib.Path] = "tb_mem",
        replay_filename: str = "axi_replay.txt",
    ) -> pathlib.Path:
        """Convert the JSONL AXI replay into the flat format ``tb_qick_emu.sv`` expects.

        ``prepare()`` writes ``axi_replay.jsonl`` (one JSON record per line).
        The Vivado-compatible testbench reads a simpler whitespace-separated
        ``"HEXADDR HEXDATA"`` file via ``$fscanf``; this helper rewrites the
        JSONL into that format and prints the current board's address-routing
        localparam values (``TPROC_BASE``, ``SG_BASE_LO/HI``, ``AVG_BASE_LO/HI``)
        so they can be pasted into ``tb_qick_emu.sv`` when the board config
        differs from the defaults.

        Parameters
        ----------
        memdir : str or pathlib.Path, optional
            Directory containing ``axi_replay.jsonl``; output is written here.
        replay_filename : str, optional
            Output filename. Default ``"axi_replay.txt"``.

        Returns
        -------
        pathlib.Path
            Path to the generated flat replay file.

        Raises
        ------
        FileNotFoundError
            If ``axi_replay.jsonl`` is missing (i.e. ``prepare()`` was not run).
        """
        memdir = pathlib.Path(memdir)
        jsonl_path = memdir / "axi_replay.jsonl"
        if not jsonl_path.exists():
            raise FileNotFoundError(
                f"axi_replay.jsonl not found: {jsonl_path}\n"
                "Run QickEmu.prepare() first."
            )

        out_path = memdir / replay_filename
        with jsonl_path.open() as fin, out_path.open("w") as fout:
            fout.write("# AXI-Lite replay for tb_qick_emu.sv\n")
            fout.write("# Generated by QickEmu.export_vivado_files()\n")
            fout.write("# Format: hex_addr hex_data  [# comment]\n")
            fout.write("#\n")
            for line in fin:
                line = line.strip()
                if not line:
                    continue
                txn = json.loads(line)
                addr = int(txn["addr"])
                data = int(txn["data"])
                comment = txn.get("comment", "")
                fout.write(f"{addr:08X} {data:08X}  # {comment}\n")

        print(f"[ok] Wrote {out_path}  ({sum(1 for _ in out_path.open()) - 4} transactions)")

        print("\n--- tb_qick_emu.sv address routing parameters ---")
        print("# Paste these localparam values into tb_qick_emu.sv if defaults differ:")
        ba = self.addrmap.base_addrs
        tf = self.addrmap.type_by_fullpath

        tproc_bases = [v for k, v in ba.items() if 'tproc' in tf.get(k, '') or 'processor' in tf.get(k, '')]
        sg_bases    = [v for k, v in ba.items() if 'signal_gen' in tf.get(k, '') or 'sg_int4' in tf.get(k, '') or 'sg_mix' in tf.get(k, '')]
        avg_bases   = [v for k, v in ba.items() if 'avg_buffer' in tf.get(k, '')]

        if tproc_bases:
            print(f"localparam integer TPROC_BASE  = 32'h{tproc_bases[0]:08X};")
        if sg_bases:
            lo = min(sg_bases)
            hi = max(sg_bases) + 0x10000
            print(f"localparam integer SG_BASE_LO  = 32'h{lo:08X};  // {len(sg_bases)} gen IP(s)")
            print(f"localparam integer SG_BASE_HI  = 32'h{hi:08X};")
        if avg_bases:
            lo = min(avg_bases)
            hi = max(avg_bases) + 0x10000
            print(f"localparam integer AVG_BASE_LO = 32'h{lo:08X};  // {len(avg_bases)} avgbuf IP(s)")
            print(f"localparam integer AVG_BASE_HI = 32'h{hi:08X};")
        print("-------------------------------------------------\n")

        return out_path