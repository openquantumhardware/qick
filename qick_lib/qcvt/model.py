# -*- coding: utf-8 -*-
"""
Data model and schedule extraction for QCVT.

The core idea: a compiled QICK ``asm_v2`` program stores everything we need to
draw a pulse schedule, but in a form that is awkward to consume directly.  This
module turns a compiled program into a small, explicit, sweep-aware
:class:`Schedule` made of :class:`PulseEvent` objects, all expressed in
**microseconds**.

Why microseconds (and not cycles)?  QICK stores each timed instruction's time as
a ``QickParam`` in microseconds (``macro.t_params[...]``) and each pulse's length
in microseconds (``pulse.get_length()``).  Working in microseconds sidesteps the
per-channel clock conversions (generators, readouts and the tProc all run at
different clock rates) that are a common source of off-by-a-clock-ratio bugs, and
lets every channel share one correct time axis.

Absolute timing: pulses are scheduled at a *local* time ``t`` relative to a moving
reference.  ``Delay`` instructions advance that reference (their stored ``t`` is
the fully resolved delay, including ``delay_auto``), so we accumulate delays as we
walk the macro list to recover absolute times.  ``Resync`` also advances the
reference (by at most ``t``; times after it are upper bounds).  ``Wait`` stalls
the processor but does not move the reference, so it is ignored for placement.
"""

from __future__ import annotations

import re
import warnings
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Optional, Tuple

import numpy as np

# Timed macros that legitimately place nothing on the timeline.
_IGNORED_TIMED_MACROS = frozenset({"Wait", "ConfigReadout"})

# Matches pulse names whose final token is "off"/"turnoff" (e.g. "pump_off",
# "turn_off", "turnoff", "off") without matching "offset_cal" or
# "off_resonant_probe", where "off" is not a trailing cleanup token.
# Lab convention for CW cleanup pulses; disable via suppress_off_pulses=False.
_OFF_PULSE_RE = re.compile(r"(^|[_\-\s])(turn[_\-\s]?)?off$")

_STRICT: ContextVar[bool] = ContextVar("qcvt_strict", default=False)


class QCVTError(RuntimeError):
    """Raised in strict mode when schedule extraction cannot proceed safely."""


def is_strict() -> bool:
    """Return whether the current thread/context is in strict extraction mode."""
    return _STRICT.get()


@contextmanager
def strict_mode(enabled: bool = True) -> Iterator[None]:
    """Context manager that makes schedule extraction raise on ambiguities.

    Default (non-strict) mode skips unparseable macros with a warning so a plot
    can still be produced.  Strict mode is for verification gates where a
    silently incomplete schedule is worse than an error.
    """
    token = _STRICT.set(bool(enabled))
    try:
        yield
    finally:
        _STRICT.reset(token)


def _fail(message: str, cause: Optional[BaseException] = None) -> None:
    """Raise :class:`QCVTError` in strict mode; otherwise emit a warning."""
    if is_strict():
        if cause is not None:
            raise QCVTError(message) from cause
        raise QCVTError(message)
    warnings.warn(f"QCVT: {message}")


# --------------------------------------------------------------------------- #
# QickParam helpers (work on plain numbers too, so nothing here requires qick)
# --------------------------------------------------------------------------- #
def _is_qickparam(x: Any) -> bool:
    """True if ``x`` looks like a QickParam (has ``.start`` and ``.spans``)."""
    return hasattr(x, "start") and hasattr(x, "spans")


def param_nominal(x: Any) -> float:
    """Return a single representative float from a QickParam or number."""
    if _is_qickparam(x):
        try:
            return float(x.start)
        except Exception:
            try:
                return float(x.minval())
            except Exception as exc:
                _fail(f"could not read QickParam nominal value from {x!r}", exc)
                return float("nan")
    try:
        return float(x)
    except Exception as exc:
        _fail(f"could not coerce {x!r} to float", exc)
        return float("nan")


def param_range(x: Any) -> Tuple[float, float, bool]:
    """Return ``(min, max, is_swept)`` for a QickParam or number (same units)."""
    if _is_qickparam(x):
        swept = bool(getattr(x, "spans", None))
        try:
            lo, hi = float(x.minval()), float(x.maxval())
        except Exception as exc:
            _fail(f"could not read QickParam range from {x!r}", exc)
            v = param_nominal(x)
            lo = hi = v
        return lo, hi, swept
    v = param_nominal(x)
    return v, v, False


def param_loop_names(x: Any) -> Tuple[str, ...]:
    """Loop names that increment a QickParam (``QickParam.spans`` keys).

    Averager ``reps`` is skipped.  Empty for scalars and unknown objects.
    """
    spans = getattr(x, "spans", None) or {}
    try:
        return tuple(k for k in spans.keys() if k != "reps")
    except Exception:
        return ()


def ordered_loop_names(names, loop_dict: Optional[Dict[str, int]] = None
                       ) -> Tuple[str, ...]:
    """Deduplicate ``names``, outer→inner when ``loop_dict`` is given."""
    seen = []
    for n in (loop_dict or {}):
        if n in names and n not in seen and n != "reps":
            seen.append(n)
    for n in names:
        if n and n not in seen and n != "reps":
            seen.append(n)
    return tuple(seen)


def _finite(*vals: float) -> bool:
    return all(np.isfinite(v) for v in vals)


# --------------------------------------------------------------------------- #
# Data model
# --------------------------------------------------------------------------- #
@dataclass
class PulseEvent:
    """A single generator pulse or ADC integration window, in microseconds."""

    ch: int
    name: str
    kind: str  # "gen" or "adc"
    t_start: float  # nominal absolute start time (us)
    length: float  # nominal length (us)
    t_min: float = 0.0
    t_max: float = 0.0
    len_min: float = 0.0
    len_max: float = 0.0
    style: str = "const"
    envelope: Optional[str] = None
    periodic: bool = False
    gain: float = 0.0
    gain_min: float = 0.0
    gain_max: float = 0.0
    freq: Optional[float] = None
    phase: Optional[float] = None
    swept_params: Tuple[str, ...] = ()
    # Loops that change this event's start time or length (ghost label).
    timing_loops: Tuple[str, ...] = ()
    # ``(param, loop)`` pairs for on-bar sweep captions, e.g. ("gain", "gainloop").
    param_loops: Tuple[Tuple[str, str], ...] = ()

    @property
    def t_end(self) -> float:
        return self.t_start + self.length

    @property
    def time_swept(self) -> bool:
        return not np.isclose(self.t_min, self.t_max)

    @property
    def length_swept(self) -> bool:
        return not np.isclose(self.len_min, self.len_max)

    @property
    def gain_swept(self) -> bool:
        return not np.isclose(self.gain_min, self.gain_max)


def representative_gain(event: "PulseEvent") -> float:
    """A single gain value suitable for drawing/exporting one pulse.

    For a swept gain the nominal value is the sweep *start*, which is 0.0 for a
    power Rabi — that would render the pulse under test as a flat zero line.
    Gains are signed in QICK (sweeps like -0.6..0.6 are common), so use the
    sweep endpoint with the largest magnitude: the pulse is drawn/exported at
    its largest amplitude extent.
    """
    if not event.gain_swept:
        return event.gain
    if abs(event.gain_max) >= abs(event.gain_min):
        return event.gain_max
    return event.gain_min


def gain_band(event: "PulseEvent") -> Tuple[float, float]:
    """``(lo, hi)`` bounds of ``|gain|`` over a pulse's sweep.

    Used to draw the amplitude min→max band.  A sweep whose sign changes
    (e.g. -0.6..0.6) passes through zero amplitude, so ``lo`` is 0.
    """
    if not event.gain_swept:
        g = abs(event.gain)
        return g, g
    hi = max(abs(event.gain_min), abs(event.gain_max))
    if event.gain_min < 0.0 < event.gain_max:
        lo = 0.0
    else:
        lo = min(abs(event.gain_min), abs(event.gain_max))
    return lo, hi


@dataclass
class Schedule:
    """A normalized, sweep-aware view of a compiled QICK program."""

    events: List[PulseEvent] = field(default_factory=list)
    soccfg: Any = None
    prog: Any = None
    loop_dict: Dict[str, int] = field(default_factory=dict)
    # Absolute time (us) at which the loop body starts (first OpenLoop); used
    # for time_origin="body" plotting.  Everything before it is _initialize().
    body_start_us: float = 0.0
    # Hide non-periodic "*_off"/"turnoff" pulses that share a timestamp with a
    # periodic pulse on the same channel (common CW cleanup convention).
    suppress_off_pulses: bool = True

    @property
    def gen_events(self) -> List[PulseEvent]:
        return [e for e in self.events if e.kind == "gen"]

    @property
    def adc_events(self) -> List[PulseEvent]:
        return [e for e in self.events if e.kind == "adc"]

    @property
    def gen_chs(self) -> List[int]:
        return sorted({e.ch for e in self.gen_events if e.ch >= 0})

    @property
    def adc_chs(self) -> List[int]:
        return sorted({e.ch for e in self.adc_events})

    def __bool__(self) -> bool:
        return bool(self.events)

    def __len__(self) -> int:
        return len(self.events)

    def end_us(self) -> float:
        """Nominal end time of the last event (us)."""
        return max((e.t_end for e in self.events), default=1.0)

    def draw_lengths(self, window_end_us: Optional[float] = None) -> Dict[int, float]:
        """Resolve display lengths, extending ``periodic`` pulses to the next
        event on the same channel (or the window end).  Keyed by ``id(event)``.
        """
        if window_end_us is None:
            window_end_us = self.end_us()
        out: Dict[int, float] = {}
        by_ch: Dict[int, List[PulseEvent]] = {}
        for e in self.gen_events:
            by_ch.setdefault(e.ch, []).append(e)
        for ch, evs in by_ch.items():
            evs_sorted = sorted(evs, key=lambda e: e.t_start)
            for i, e in enumerate(evs_sorted):
                if not e.periodic:
                    out[id(e)] = e.length
                    continue
                # Extend to the next strictly-later event on this channel.
                k = i + 1
                while k < len(evs_sorted) and evs_sorted[k].t_start <= e.t_start + 1e-9:
                    k += 1
                nxt = evs_sorted[k].t_start if k < len(evs_sorted) else window_end_us
                out[id(e)] = max(0.0, nxt - e.t_start)
        return out

    def suppressed_events(self) -> set:
        """Return ids of events to hide: a non-periodic "off"/"turnoff" pulse
        scheduled at the same time as a periodic pulse on the same channel
        (a common cleanup artifact that would otherwise clutter the plot).

        Disabled when ``suppress_off_pulses`` is ``False``.
        """
        if not self.suppress_off_pulses:
            return set()
        skip = set()
        by_key: Dict[Tuple[int, float], List[PulseEvent]] = {}
        for e in self.gen_events:
            by_key.setdefault((e.ch, round(e.t_start, 9)), []).append(e)
        for evs in by_key.values():
            if len(evs) < 2:
                continue
            if any(e.periodic for e in evs):
                for e in evs:
                    n = e.name.lower()
                    if not e.periodic and _OFF_PULSE_RE.search(n):
                        skip.add(id(e))
        return skip


# --------------------------------------------------------------------------- #
# Pulse parameter lookups
# --------------------------------------------------------------------------- #
def _call(obj: Any, name: str, *args, default: Any = None):
    """Call ``obj.name(*args)`` if it exists; otherwise return ``default``."""
    fn = getattr(obj, name, None)
    if callable(fn):
        return fn(*args)
    return default


def _macro_time_param(macro: Any, name: str):
    """Return the (rounded, sweep-aware) time QickParam for ``name`` in us."""
    getter = getattr(macro, "get_time_param", None)
    if callable(getter):
        try:
            return getter(name)
        except Exception as exc:
            if is_strict():
                raise QCVTError(
                    f"get_time_param({name!r}) failed on {type(macro).__name__}"
                ) from exc
    return getattr(macro, "t_params", {}).get(name)


def _pulse_param_range(prog: Any, name: str, param: str) -> Tuple[float, float, float, bool]:
    """Return ``(nominal, min, max, is_swept)`` for a pulse parameter.

    Prefers ``prog.get_pulse_param`` (fully rounded, loop-aware); falls back to
    the raw ``pulse.params`` entry.
    """
    getter = getattr(prog, "get_pulse_param", None)
    if callable(getter):
        try:
            arr = np.asarray(getter(name, param, as_array=True), dtype=float).ravel()
            if arr.size:
                lo, hi = float(np.nanmin(arr)), float(np.nanmax(arr))
                return float(arr.flat[0]), lo, hi, not np.isclose(lo, hi)
        except Exception as exc:
            if is_strict():
                raise QCVTError(
                    f"get_pulse_param({name!r}, {param!r}) failed"
                ) from exc
    try:
        pulses = _call(prog, "get_pulses", default=None) or getattr(prog, "pulses", {})
        pulse = pulses[name]
        params = _call(pulse, "get_params", default=None) or getattr(pulse, "params", {})
        p = params.get(param)
    except Exception as exc:
        if is_strict():
            raise QCVTError(
                f"could not read pulse param {param!r} for {name!r}"
            ) from exc
        p = None
    if p is None:
        return 0.0, 0.0, 0.0, False
    lo, hi, swept = param_range(p)
    return param_nominal(p), lo, hi, swept


def _pulse_param_loops(prog: Any, name: str, param: str) -> Tuple[str, ...]:
    """Loop names that increment ``param`` on pulse ``name``."""
    try:
        pulses = _call(prog, "get_pulses", default=None) or getattr(prog, "pulses", {})
        pulse = pulses[name]
        params = _call(pulse, "get_params", default=None) or getattr(pulse, "params", {})
        return param_loop_names(params.get(param))
    except Exception:
        return ()


def _ro_length_us(prog: Any, ro: int) -> Optional[float]:
    """ADC integration-window length (us) for readout channel ``ro``."""
    getter = getattr(prog, "get_ro_length_us", None)
    if callable(getter):
        try:
            return float(getter(ro))
        except Exception as exc:
            if is_strict():
                raise QCVTError(
                    f"could not resolve readout length for channel {ro}"
                ) from exc
    try:
        ro_chs = _call(prog, "get_ro_chs", default=None) or prog.ro_chs
        rc = ro_chs[ro]
        if "length_us" in rc:
            return float(rc["length_us"])
        length = rc["length"]
        soccfg = getattr(prog, "soccfg", None)
        f_output = _call(soccfg, "get_ro_f_output", ro, default=None)
        if f_output is None:
            f_output = soccfg["readouts"][ro]["f_output"]
        return float(length) / float(f_output)
    except Exception as exc:
        if is_strict():
            raise QCVTError(
                f"could not resolve readout length for channel {ro}"
            ) from exc
        return None


# --------------------------------------------------------------------------- #
# Extraction
# --------------------------------------------------------------------------- #
def extract_schedule(
    prog: Any,
    *,
    strict: bool = False,
    suppress_off_pulses: bool = True,
) -> Schedule:
    """Build a :class:`Schedule` from a compiled QICK ``asm_v2`` program.

    The program must be compiled (``AveragerProgramV2`` compiles on construction).
    Timing is recovered in microseconds and is sweep-aware.

    Parameters
    ----------
    prog :
        Compiled ``AveragerProgramV2`` (or compatible) instance.
    strict : bool
        If ``False`` (default), a macro that fails to parse is skipped with a
        warning.  If ``True``, extraction raises :class:`QCVTError` on parse
        failures, unhandled timed macros, and ``Resync`` (whose drawn times are
        only upper bounds).  Prefer ``strict=True`` for pre-submit verification.
    suppress_off_pulses : bool
        If ``True`` (default), hide non-periodic pulses whose name ends in
        ``off`` / ``turnoff`` when they share a timestamp with a periodic pulse
        on the same channel.  Set ``False`` if that naming heuristic does not
        match your lab's convention.
    """
    with strict_mode(strict):
        return _extract_schedule(prog, suppress_off_pulses=suppress_off_pulses)


def _extract_schedule(prog: Any, *, suppress_off_pulses: bool) -> Schedule:
    sched = Schedule(
        soccfg=getattr(prog, "soccfg", None),
        prog=prog,
        loop_dict=dict(
            _call(prog, "get_loop_dict", default=None)
            or getattr(prog, "loop_dict", {})
            or {}
        ),
        suppress_off_pulses=suppress_off_pulses,
    )

    macro_list = _call(prog, "get_macro_list", default=None) or getattr(prog, "macro_list", None) or []
    pulses = _call(prog, "get_pulses", default=None) or getattr(prog, "pulses", None) or {}
    if not macro_list:
        return sched

    # Moving reference offset (us), tracked with its sweep range.
    ref_nom = ref_min = ref_max = 0.0
    ref_loops: List[str] = []
    # Per-call warning/bookkeeping state.
    resync_warned = False
    unknown_warned: set = set()
    body_started = False

    for macro in macro_list:
        cname = type(macro).__name__
        try:
            if cname in ("Delay", "Resync"):
                # Resync advances the reference like Delay (both compile to
                # TIME inc_ref), but at runtime it applies max(0, t - elapsed),
                # so the drawn position is an upper bound.  QICK's own timestamp
                # bookkeeping uses the full t, so we match it.
                if cname == "Resync" and not resync_warned:
                    _fail(
                        "program contains Resync; times after it are "
                        "upper bounds (Resync applies max(0, t - elapsed) at "
                        "runtime)."
                    )
                    resync_warned = True
                tp = _macro_time_param(macro, "t")
                if tp is None:
                    continue
                lo, hi, _ = param_range(tp)
                ref_nom += param_nominal(tp)
                ref_min += lo
                ref_max += hi
                for n in param_loop_names(tp):
                    if n not in ref_loops:
                        ref_loops.append(n)

            elif cname == "Pulse":
                ch = getattr(macro, "ch", None)
                name = getattr(macro, "name", None)
                if ch is None or name is None or name not in pulses:
                    continue
                tp = _macro_time_param(macro, "t")
                if tp is None:
                    continue
                t_nom = param_nominal(tp)
                t_lo, t_hi, _ = param_range(tp)
                pulse = pulses[name]
                length_qp = pulse.get_length()
                l_nom = param_nominal(length_qp)
                l_lo, l_hi, _ = param_range(length_qp)
                if not _finite(t_nom, l_nom) or l_nom < 0:
                    continue
                params = getattr(pulse, "params", {}) or {}
                style = str(params.get("style", "const"))
                envelope = params.get("envelope")
                periodic = params.get("mode") == "periodic"
                g_nom, g_lo, g_hi, g_sw = _pulse_param_range(prog, name, "gain")
                f_nom, _, _, f_sw = _pulse_param_range(prog, name, "freq")
                p_nom, _, _, _ = _pulse_param_range(prog, name, "phase")
                swept = []
                if not np.isclose(t_lo, t_hi):
                    swept.append("time")
                if not np.isclose(l_lo, l_hi):
                    swept.append("length")
                if g_sw:
                    swept.append("gain")
                if f_sw:
                    swept.append("freq")
                t_loops = ordered_loop_names(
                    list(param_loop_names(tp)) + list(ref_loops), sched.loop_dict)
                l_loops = ordered_loop_names(param_loop_names(length_qp),
                                             sched.loop_dict)
                timing_loops = ordered_loop_names(
                    list(t_loops) + list(l_loops), sched.loop_dict)
                param_loops: List[Tuple[str, str]] = []
                if t_loops:
                    param_loops.append(("time", ", ".join(t_loops)))
                if l_loops:
                    param_loops.append(("length", ", ".join(l_loops)))
                g_loops = ordered_loop_names(
                    _pulse_param_loops(prog, name, "gain"), sched.loop_dict)
                if g_loops:
                    param_loops.append(("gain", ", ".join(g_loops)))
                f_loops = ordered_loop_names(
                    _pulse_param_loops(prog, name, "freq"), sched.loop_dict)
                if f_loops:
                    param_loops.append(("freq", ", ".join(f_loops)))
                sched.events.append(PulseEvent(
                    ch=int(ch), name=str(name), kind="gen",
                    t_start=ref_nom + t_nom, length=l_nom,
                    t_min=ref_min + t_lo, t_max=ref_max + t_hi,
                    len_min=l_lo, len_max=l_hi,
                    style=style, envelope=envelope, periodic=periodic,
                    gain=g_nom, gain_min=g_lo, gain_max=g_hi,
                    freq=f_nom, phase=p_nom, swept_params=tuple(swept),
                    timing_loops=timing_loops,
                    param_loops=tuple(param_loops),
                ))

            elif cname == "Trigger":
                ros = getattr(macro, "ros", None) or []
                if not ros:
                    continue
                tp = _macro_time_param(macro, "t")
                if tp is None:
                    continue
                t_nom = param_nominal(tp)
                t_lo, t_hi, _ = param_range(tp)
                width_qp = _macro_time_param(macro, "width")
                for ro in ros:
                    # Prefer the true integration length; fall back to trigger width.
                    length = _ro_length_us(prog, int(ro))
                    if length is None:
                        length = param_nominal(width_qp) if width_qp is not None else 0.0
                    if not _finite(t_nom, length) or length < 0:
                        continue
                    t_loops = ordered_loop_names(
                        list(param_loop_names(tp)) + list(ref_loops),
                        sched.loop_dict)
                    sched.events.append(PulseEvent(
                        ch=int(ro), name="readout", kind="adc",
                        t_start=ref_nom + t_nom, length=float(length),
                        t_min=ref_min + t_lo, t_max=ref_max + t_hi,
                        len_min=float(length), len_max=float(length),
                        style="const",
                        timing_loops=t_loops,
                        param_loops=(("time", ", ".join(t_loops)),) if t_loops else (),
                    ))

            elif cname == "OpenLoop":
                # Everything before the first loop is _initialize(); the loop
                # body starts here.  Recorded for time_origin="body" plotting.
                if not body_started:
                    sched.body_start_us = ref_nom
                    body_started = True

            else:
                # Register ops, loop control and labels carry no timing.
                # Anything with t_params is a TimedMacro we don't know about —
                # that's a real gap in the schedule.
                if hasattr(macro, "t_params") and cname not in _IGNORED_TIMED_MACROS:
                    if cname not in unknown_warned:
                        _fail(
                            f"unhandled timed macro {cname!r}; schedule "
                            f"may be incomplete or misaligned after this point."
                        )
                        unknown_warned.add(cname)
        except QCVTError:
            raise
        except Exception as exc:
            # keep going in default mode; a single bad macro shouldn't kill the plot
            _fail(f"skipping macro {cname}: {exc}", exc)

    return sched


# --------------------------------------------------------------------------- #
# Amplitude reconstruction
# --------------------------------------------------------------------------- #
def _gencfg(prog: Any, ch: int) -> dict:
    try:
        soccfg = getattr(prog, "soccfg", None)
        cfg = _call(soccfg, "get_gen_cfg", ch, default=None)
        if cfg is not None:
            return dict(cfg)
        return dict(soccfg["gens"][ch])
    except Exception as exc:
        if is_strict():
            raise QCVTError(f"could not read generator config for ch {ch}") from exc
        return {}


def _sample_dt_us(gencfg: dict) -> float:
    """Per-sample spacing (us) for a generator envelope at the DAC sample rate."""
    fs = float(gencfg.get("fs", 0.0))
    if fs <= 0:
        f_fabric = float(gencfg.get("f_fabric", 1000.0)) or 1000.0
        samps_per_clk = float(gencfg.get("samps_per_clk", 1)) or 1.0
        fs = f_fabric * samps_per_clk
    return 1.0 / fs


def _envelope_magnitude(prog: Any, ch: int, envelope: str) -> Optional[np.ndarray]:
    """Return the envelope magnitude samples (unitless DAC counts), or ``None``."""
    try:
        data = _call(prog, "get_envelope_data", ch, envelope, default=None)
        if data is None:
            envelopes = _call(prog, "get_envelopes", default=None) or getattr(prog, "envelopes", None)
            data = envelopes[ch]["envs"][envelope]["data"]
        data = np.asarray(data)
    except Exception as exc:
        if is_strict():
            raise QCVTError(
                f"could not read envelope {envelope!r} on ch {ch}"
            ) from exc
        return None
    if data.size == 0:
        return None
    if data.ndim == 2 and data.shape[1] >= 2:
        return np.hypot(data[:, 0].astype(float), data[:, 1].astype(float))
    return np.abs(data.astype(float))


def _flat_top_plateau_us(prog: Any, event: PulseEvent) -> float:
    """Duration of the flat (DDS) segment of a ``flat_top`` pulse, in us."""
    try:
        pulses = _call(prog, "get_pulses", default=None) or getattr(prog, "pulses", {})
        pulse = pulses[event.name]
        params = _call(pulse, "get_params", default=None) or getattr(pulse, "params", {})
        length = params.get("length")
        return max(0.0, param_nominal(length))
    except Exception as exc:
        if is_strict():
            raise QCVTError(
                f"could not resolve flat_top plateau for {event.name!r}"
            ) from exc
        # Fall back: total length minus whatever we can attribute to the ramps.
        return max(0.0, event.length)


def amplitude_trace(prog: Any, event: PulseEvent, length_us: Optional[float] = None,
                    dac_units: bool = True, gain_override: Optional[float] = None):
    """Return ``(t_us, amp)`` samples describing one pulse's amplitude envelope.

    Supported styles:

    * ``const``    — rectangle at ``|gain| * scale`` for the pulse length.
    * ``arb``      — stored envelope magnitude (gaussian, DRAG, arbitrary I/Q, …),
      scaled by ``|gain| * scale``.
    * ``flat_top`` — first half of the envelope as the rising ramp, a plateau of
      ``params['length']``, then the second half as the falling ramp (QICK's
      three-segment flat_top convention).

    ``scale`` is ``maxv`` (DAC units) when ``dac_units`` else 1.0 (normalized).
    ``length_us`` overrides the pulse length (used for periodic extension of
    ``const`` pulses).  When ``gain_override`` is ``None``, swept-gain pulses
    use their sweep maximum (see :func:`representative_gain`) so they are not
    drawn/exported at zero amplitude.
    """
    if length_us is None:
        length_us = event.length
    t0 = event.t_start
    gain = abs(representative_gain(event) if gain_override is None else gain_override)
    gencfg = _gencfg(prog, event.ch)
    soccfg = getattr(prog, "soccfg", None)
    maxv = _call(soccfg, "get_maxv", event.ch, default=None)
    if maxv is None:
        maxv = int(gencfg.get("maxv", 32766))
    scale = int(maxv) if dac_units else 1.0
    amp_peak = gain * scale

    def _box(duration: float = length_us):
        return (np.array([t0, t0, t0 + duration, t0 + duration]),
                np.array([0.0, amp_peak, amp_peak, 0.0]))

    style = event.style
    if style == "const" or not event.envelope:
        return _box()

    mag = _envelope_magnitude(prog, event.ch, event.envelope)
    if mag is None or mag.size == 0:
        return _box()

    dt_us = _sample_dt_us(gencfg)
    peak = float(np.max(mag)) or 1.0
    unit = mag / peak

    if style == "flat_top":
        # QICK convention: the envelope is a full up+down shape; the first half
        # is the rising ramp, the second half the falling ramp, and a DDS
        # plateau of params['length'] sits between them.  Odd-length envelopes
        # skip the middle sample.
        n = unit.size
        mid = n // 2
        up = unit[:mid]
        down = unit[mid + (n % 2):]
        plateau = _flat_top_plateau_us(prog, event)
        t_up = t0 + np.arange(up.size) * dt_us
        t_flat0 = t0 + up.size * dt_us
        t_flat1 = t_flat0 + plateau
        t_down = t_flat1 + np.arange(down.size) * dt_us
        t_parts = [np.array([t0])]
        a_parts = [np.array([0.0])]
        if up.size:
            t_parts.append(t_up)
            a_parts.append(up * amp_peak)
        t_parts.append(np.array([t_flat0, t_flat1]))
        a_parts.append(np.array([amp_peak, amp_peak]))
        if down.size:
            t_parts.append(t_down)
            a_parts.append(down * amp_peak)
            t_parts.append(np.array([t_down[-1]]))
        else:
            t_parts.append(np.array([t_flat1]))
        a_parts.append(np.array([0.0]))
        return np.concatenate(t_parts), np.concatenate(a_parts)

    # arb (and any other envelope-driven style): play the full envelope.
    t = t0 + np.arange(unit.size) * dt_us
    amp = unit * amp_peak
    t = np.concatenate([[t0], t, [t[-1]]])
    amp = np.concatenate([[0.0], amp, [0.0]])
    return t, amp
