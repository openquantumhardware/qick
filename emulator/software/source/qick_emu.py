# qick_emu.py
"""
QickEmu: run QICK programs against an emulated (Verilated) design.
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
    op: str  # "w", "r", "stream"
    addr: Optional[int] = None
    data: Optional[int] = None
    stream: Optional[str] = None
    words: Optional[List[int]] = None
    comment: str = ""

    def to_json(self) -> str:
        return json.dumps({k: v for k, v in asdict(self).items() if v is not None}, cls=NpEncoder)


class AxiRecorder:
    def __init__(self):
        self.txns: List[AxiTxn] = []

    def write(self, addr: int, data: int, comment: str = ""):
        self.txns.append(AxiTxn(op="w", addr=int(addr), data=int(data), comment=comment))

    def read(self, addr: int, comment: str = ""):
        self.txns.append(AxiTxn(op="r", addr=int(addr), comment=comment))

    def stream_load_words(self, stream: str, words: Iterable[int], comment: str = ""):
        self.txns.append(AxiTxn(op="stream", stream=str(stream), words=[int(w) for w in words], comment=comment))

    def save_jsonl(self, path: Union[str, pathlib.Path]) -> pathlib.Path:
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
    offset: int
    width: int = 32
    comment: str = ""


class AddrMap:
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
        return {
            "base_addrs": self.base_addrs,
            "type_by_fullpath": self.type_by_fullpath,
            "reg_defs_by_type": {
                typ: {rn: asdict(rd) for rn, rd in regs.items()}
                for typ, regs in self.reg_defs_by_type.items()
            },
        }

    def save(self, path: Union[str, pathlib.Path]) -> pathlib.Path:
        p = pathlib.Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(self.to_json(), indent=2))
        return p


def default_addrmap_skeleton() -> AddrMap:
    am = AddrMap()
    
    # FIX 1: Corrected axis_avg_buffer register offsets to match hardware (tb_qick.sv)
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
    def __init__(self, soc: 'SocEmu', fullpath: str, ip_type: str):
        self.soc = soc
        self.fullpath = fullpath
        self.ip_type = ip_type

class MockAvgBuffer(MockIpDriver):
    # FIX 3: Added stop-before-config to match hardware sequence
    def config_avg(self, address=0, length=1, edge_counting=False, high_threshold=1000, low_threshold=0):
        self.soc.reg_write(self.fullpath, "AVG_START", 0, comment="stop avg")
        self.soc.reg_write(self.fullpath, "AVG_LEN", length, comment="avg buf len")

    def config_buf(self, address=0, length=1):
        self.soc.reg_write(self.fullpath, "BUF_START", 0, comment="stop decim")
        self.soc.reg_write(self.fullpath, "BUF_LEN", length, comment="decim buf len")

    def enable(self, avg=True, buf=True):
        if avg: self.soc.reg_write(self.fullpath, "AVG_START", 1, comment="start avg")
        if buf: self.soc.reg_write(self.fullpath, "BUF_START", 1, comment="start decim")

class MockDDR4Buffer(MockIpDriver):
    def set_switch(self, path):
        self.soc.axi.write(0, 0, comment=f"DDR4 Switch -> {path}")

    def arm(self, nt=1, force_overwrite=False):
        self.soc.reg_write(self.fullpath, "ARM", 1, comment="DDR4 Arm")


class MockPFBReadout(MockIpDriver):
    _HAS_OUTSEL_BY_TYPE = {
        "axis_pfb_readout_v2": True,
        "axis_pfb_readout_v3": False,
        "axis_pfb_readout_v4": False,
    }

    @property
    def HAS_OUTSEL(self):
        return self._HAS_OUTSEL_BY_TYPE.get(self.ip_type, False)

    def set_out(self, sel='product'):
        val = {"product": 0, "input": 1, "dds": 2}[sel]
        self.soc.reg_write(self.fullpath, "OUTSEL", val, comment=f"PFB outsel={sel}")

    def set_freq_int(self, cfg):
        out_ch = cfg.get('pfb_port', 0)
        pfb_ch = cfg.get('pfb_ch', 0)
        f_int = cfg.get('f_int', 0)
        self.soc.reg_write(self.fullpath, "NCO_FREQ", f_int, comment=f"PFB ch{pfb_ch}->out{out_ch} freq")
        self.soc.reg_write(self.fullpath, "PFB_CH", pfb_ch, comment=f"PFB ch{pfb_ch}->out{out_ch} sel")


class MockTProc(MockIpDriver):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._core_cfg = 0

    def set_lfsr_cfg(self, mode, core=0):
        """Configure LFSR mode: 0=disabled, 1=free running, 2=step on s1 read, 3=step on s0 write"""
        CORE_CFG_LFSR_MASK = 0x3
        self._core_cfg &= ~(CORE_CFG_LFSR_MASK << (core * 2))
        self._core_cfg |= (mode & CORE_CFG_LFSR_MASK) << (core * 2)
        self.soc.reg_write(self.fullpath, "CORE_CFG", self._core_cfg, comment=f"LFSR mode={mode} core={core}")


# =============================================================================
# Emulated Soc
# =============================================================================

class SocEmu:
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
        # gens is a list in QickConfig, so iterating it directly is safe
        self.gens = [MockIpDriver(self, g['fullpath'], g['type']) for g in soccfg['gens']]
        
        self.avg_bufs = []
        for ro in soccfg['readouts']:
            self.avg_bufs.append(MockAvgBuffer(self, ro['avgbuf_fullpath'], ro['avgbuf_type']))
            
        self.readouts = [MockIpDriver(self, r['ro_fullpath'], r['ro_type']) for r in soccfg['readouts']]
        
        # Safe dict checks
        if 'ddr4_buf' in self.raw_cfg:
            self.ddr4_buf = MockDDR4Buffer(self, self.raw_cfg['ddr4_buf']['fullpath'], self.raw_cfg['ddr4_buf']['type'])

        if 'mr_buf' in self.raw_cfg:
             self.mr_buf = MockIpDriver(self, self.raw_cfg['mr_buf']['fullpath'], self.raw_cfg['mr_buf']['type'])

        tproc_cfg = self.raw_cfg['tprocs'][0]
        tproc_path = tproc_cfg.get('fullpath', 'qick_processor_0')
        self.tproc = MockTProc(self, tproc_path, tproc_cfg['type'])

        # PFB readouts: create mocks and store in a dict keyed by fullpath
        self._pfb_readouts: Dict[str, MockPFBReadout] = {}
        for ro in soccfg['readouts']:
            if 'pfb_readout' in ro['ro_type']:
                pfb = MockPFBReadout(self, ro['ro_fullpath'], ro['ro_type'])
                self._pfb_readouts[ro['ro_fullpath']] = pfb

    def __getitem__(self, key):
        return self.soccfg[key]

    # ---- QickSoc Shim Methods ----

    def set_nyquist(self, ch, nqz, force=False):
        gen = self.gens[ch]
        self.reg_write(gen.fullpath, "NQZ", int(nqz))

    def set_mixer_freq(self, ch, f, ro_ch=None, phase_reset=True, force=False):
        gen = self.gens[ch]
        self.reg_write(gen.fullpath, "MIXER_FREQ", int(f))

    def config_mux_gen(self, ch, tones):
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
        ro = self.readouts[ch]
        if 'ro_len' in ro_regs:
             self.reg_write(ro.fullpath, "RO_LEN", ro_regs['ro_len'])

    def config_mux_readout(self, pfbpath, cfgs, sel=None):
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
        self.avg_bufs[ch].config_avg(**kwargs)

    def config_buf(self, ch, **kwargs):
        self.avg_bufs[ch].config_buf(**kwargs)

    # --- FIX: Explicitly map arguments to match Driver API ---
    def enable_buf(self, ch, enable_avg=True, enable_buf=True):
        # QickSoc maps 'enable_avg' -> 'avg' and 'enable_buf' -> 'buf'
        self.avg_bufs[ch].enable(avg=enable_avg, buf=enable_buf)
        
    def arm_ddr4(self, ch, nt, force_overwrite=False):
        if hasattr(self, 'ddr4_buf'):
            self.ddr4_buf.arm(nt, force_overwrite)

    def load_envelope(self, ch, data, addr):
        pass

    def load_weights(self, ch, data, addr=0):
        pass

    def load_bin_program(self, binprog, load_mem=True):
        pass

    # FIX 2: Corrected tproc start sequence — two-step: TIME_RST then PROC_START+CORE_START
    def start_tproc(self):
        path = self.raw_cfg['tprocs'][0].get('fullpath', "qick_processor_0")
        # Step 1: Reset time counter
        self.reg_write(path, "CTRL", 0x10, comment="TIME_RST (bit 4)")
        # Step 2: Start processor + core
        self.reg_write(path, "CTRL", 0x05, comment="PROC_START (bit 0) + CORE_START (bit 2)")

    def start_src(self, mode: str):
        self._start_src = mode

    def stop_tproc(self, lazy=False):
        pass

    def reg_write(self, fullpath: str, regname: str, value: int, comment: str = ""):
        try:
            addr = self.addrmap.resolve(fullpath, regname)
            self.axi.write(addr, int(value), comment=comment)
        except KeyError:
            self.axi.write(0xFFFFFFFF, int(value), comment=f"UNRESOLVED: {fullpath}.{regname}")

    def reg_read(self, fullpath: str, regname: str, comment: str = ""):
        pass

    def get_decimated(self, ro_ch: int, address=0, length=None) -> np.ndarray:
        return self._results.get("decimated", {}).get(ro_ch, np.zeros((100, 2)))

    def get_accumulated(self, ro_ch: int, address=0, length=None) -> np.ndarray:
        return self._results.get("accumulated", {}).get(ro_ch, np.zeros((1, 2)))


# =============================================================================
# QickEmu
# =============================================================================

class QickEmu:
    def __init__(
        self,
        qick_config_json: Union[str, pathlib.Path],
        *,
        addrmap: Union[None, str, pathlib.Path, AddrMap] = None,
        backend: Optional[SimBackend] = None,
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
        return SocEmu(self.soccfg, self.raw_cfg, self.addrmap, memdir=memdir)

    def prepare(self, prog, soc: SocEmu, memdir: Union[str, pathlib.Path] = "tb_mem") -> Dict[str, Any]:
        # 1. Static Config (Gens/ROs)
        prog.config_all(soc, load_mem=False) 
        
        # 2. Dynamic Config (Buffers) - NEW
        # We manually trigger buffer config because 'acquire' isn't running
        prog.config_bufs(soc, enable_avg=True, enable_buf=True)

        # 3. Export Memories
        memdir = pathlib.Path(memdir)
        memdir.mkdir(parents=True, exist_ok=True)
        
        self._capture_to_file(prog.print_pmem2hex, memdir / "pmem.mem")
        self._capture_to_file(prog.print_dmem2hex if hasattr(prog, "print_dmem2hex") else lambda f: None, memdir / "dmem.mem")
        
        try:
            prog.print_wmem2hex(stem=str(memdir / "wmem"))
        except TypeError:
            self._capture_to_file(prog.print_wmem2hex, memdir / "wmem.mem")

        # $readmemh forbids leading underscores (Verilog LRM §17.2.2).
        # Older qick versions emit "___XXXX_..." — strip any leading underscores
        # from non-comment lines so Vivado xsim loads the wave memory correctly.
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

        # 4. Start tProc - NEW
        soc.start_tproc()

        axi_script = soc.axi.save_jsonl(memdir / "axi_replay.jsonl")
        
        return {"memdir": str(memdir), "axi_script": str(axi_script)}

    @staticmethod
    def _capture_to_file(fn, out_path: Union[str, pathlib.Path], *args, **kwargs):
        try:
            fn(str(out_path), *args, **kwargs)
        except TypeError:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                fn(*args, **kwargs)
            out_path.write_text(buf.getvalue())

    # def run_verilated_mem_tb(self, **kwargs):
    #     cfg = VerilatorBackendConfig(
    #         verilog_dir=kwargs.get("verilog_dir"),
    #         top_module=kwargs.get("top_module"),
    #         sources=kwargs.get("sources"),
    #         build_dir=kwargs.get("build_dir", "build_tb_mem"),
    #         enable_wave=kwargs.get("enable_wave", False)
    #     )
    #     self.backend = VerilatorBackend(cfg)
    #     return self.backend.run(
    #         memdir="emulator", 
    #         axi_script="emulator/axi_replay.jsonl"
    #     )
    # =========================================================================
    # TEMPORARY VERILATOR RUNNER & PLOTTER
    # =========================================================================

    def run_verilated_mem_tb(
        self,
        mem_file,
        verilog_dir=None,
        top_module="dac_top_tb_mem",
        sources=("dac_top_tb_mem.sv", "dac_top.sv", "dac.sv"),
        build_dir="build_tb_mem",
        log_csv_name="top_dac_mem.csv",
        mem_filename_in_tb="stimulus.mem",
        enable_wave=False,
        extra_verilator_args=None,
        verbose=True,
    ):
        import os, shutil, subprocess
        from pathlib import Path

        verilog_dir = Path(verilog_dir) if verilog_dir is not None else Path.cwd()
        build_dir = Path(build_dir)
        build_dir.mkdir(parents=True, exist_ok=True)

        src_paths = [verilog_dir / s for s in sources]
        for sp in src_paths:
            if not sp.exists():
                raise FileNotFoundError(f"Verilog source not found: {sp}")

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

        if verbose: print(f"$ (cd {build_dir} && ./{sim_path.name})")
        subprocess.run([f"./{sim_path.name}"], check=True, cwd=build_dir)
        
        out_csv = build_dir / log_csv_name
        if not out_csv.exists():
            raise FileNotFoundError(f"Expected CSV not found: {out_csv}")
        if verbose: print(f"[ok] Wrote {out_csv}")
        return out_csv

    def plot_tb_csv(
        self,
        csv_path,
        time_col="time_ps",
        value_cols=("aout_active",),
        expected_col="expected_out",
        time_unit="us",
        labels=None,
        save_path=None,
        show=True,
    ):
        import csv, math
        from pathlib import Path
        import matplotlib.pyplot as plt

        csv_path = Path(csv_path)
        with csv_path.open(newline="") as f:
            rows = list(csv.DictReader(f))

        def parse_float(s, default=float("nan")):
            try: return float(s)
            except Exception: return default

        times_ps = [parse_float(r.get(time_col, "")) for r in rows]
        series = {c: [parse_float(r.get(c, "")) for r in rows] for c in value_cols}
        exp_vals = [parse_float(r.get(expected_col, "")) for r in rows] if expected_col else None

        unit_scale = {"ps": 1.0, "ns": 1e-3, "us": 1e-6, "ms": 1e-9}
        t = [v * unit_scale[time_unit] for v in times_ps]

        plt.figure()
        for c in value_cols:
            plt.plot(t, series[c], label=(labels or {}).get(c, c))
        if exp_vals and all(not math.isnan(x) for x in exp_vals):
            plt.plot(t, exp_vals, linestyle="--", label=(labels or {}).get(expected_col, expected_col or "expected"))
        
        plt.xlabel(f"time [{time_unit}]")
        plt.ylabel("value")
        plt.title("Testbench output vs time")
        plt.grid(True, which="both", linestyle=":")
        plt.legend()
        if show: plt.show()
        else: plt.close()

    def export_vivado_files(
        self,
        memdir: Union[str, pathlib.Path] = "tb_mem",
        replay_filename: str = "axi_replay.txt",
    ) -> pathlib.Path:
        """Convert ``axi_replay.jsonl`` → ``axi_replay.txt`` for use with
        ``tb_qick_emu.sv``.

        The output file contains one AXI-Lite write transaction per line::

            XXXXXXXX YYYYYYYY   # hex addr, hex data

        Lines beginning with ``#`` are comments.  The file can be read by the
        ``replay_axi_writes`` task in ``tb_qick_emu.sv``.

        Also prints the address-routing ``localparam`` values that must be set
        in ``tb_qick_emu.sv`` to match this board's ``AddrMap``.

        Parameters
        ----------
        memdir:
            Directory containing ``axi_replay.jsonl`` (same as passed to
            ``prepare()``).
        replay_filename:
            Output filename (written inside *memdir*).

        Returns
        -------
        Path to the generated ``axi_replay.txt`` file.
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

        # Print address-routing parameters for tb_qick_emu.sv
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