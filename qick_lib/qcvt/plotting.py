# -*- coding: utf-8 -*-
"""
Matplotlib rendering of a QICK pulse :class:`~qcvt.model.Schedule`.

The schedule plot shows one horizontal lane per generator/readout channel with
every pulse drawn as a labelled bar on a shared microsecond axis.  An optional
amplitude panel reconstructs the output amplitude vs. time.  Swept start times
and lengths are shown as a dashed **ghost** of the pulse at the other sweep
extreme (same width if only the start moves; a different width if length
sweeps too), labelled with the loop that moves the pulse, so a sliding pulse
is not mistaken for a length sweep and a timing loop is not mistaken for a
gain loop.

Multi-timescale programs (ns-scale qubit pulses next to µs-scale readout / ms-scale
CW pumps) are handled by:

* an explicit ``t0_us`` / ``max_time_us`` viewing window;
* duration callouts + tick marks for pulses that would otherwise be invisible;
* an opt-in zoom inset around clusters of short pulses (``insets=True``).
  Pulses that overlap the inset are drawn even if they started earlier.
"""

from __future__ import annotations

from dataclasses import replace
from typing import List, Optional, Sequence, Tuple

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb
from matplotlib.patches import Patch

from .labels import default_port_text, lookup_physical, resolve_label_maps
from .model import PulseEvent, Schedule, amplitude_trace, extract_schedule, gain_band


_GEN_HEIGHT = 0.62
_ADC_HEIGHT = 0.4
_ADC_COLOR = "#1a7a1a"
# Pulses shorter than this fraction of the viewing window get a duration callout.
_SHORT_FRAC = 0.015


def _as_schedule(prog_or_schedule) -> Schedule:
    if isinstance(prog_or_schedule, Schedule):
        return prog_or_schedule
    return extract_schedule(prog_or_schedule)


def _shifted_schedule(sched: Schedule, offset_us: float) -> Schedule:
    """Draw-time copy of ``sched`` with all event times shifted earlier by
    ``offset_us``.  The original schedule is untouched, so exports made from it
    stay on the absolute program timeline."""
    events = [replace(e,
                      t_start=e.t_start - offset_us,
                      t_min=e.t_min - offset_us,
                      t_max=e.t_max - offset_us)
              for e in sched.events]
    return Schedule(
        events=events, soccfg=sched.soccfg, prog=sched.prog,
        loop_dict=dict(sched.loop_dict), body_start_us=0.0,
        suppress_off_pulses=sched.suppress_off_pulses,
    )


# tab10 index 2 is green and collides with ADC lane color ``_ADC_COLOR``.
_GEN_CMAP_INDICES = (0, 1, 3, 4, 5, 6, 7, 8, 9)


def _channel_colors(gen_chs):
    cmap = plt.cm.tab10
    n = len(_GEN_CMAP_INDICES)
    return {ch: cmap(_GEN_CMAP_INDICES[i % n]) for i, ch in enumerate(gen_chs)}


def _gen_label(sched: Schedule, ch: int, gen_ch_labels, physical_port_labels) -> str:
    label = (gen_ch_labels or {}).get(ch, f"gen {ch}")
    soccfg = sched.soccfg
    if soccfg is not None:
        try:
            getter = getattr(soccfg, "get_gen_cfg", None)
            gencfg = getter(ch) if callable(getter) else soccfg["gens"][ch]
            dac_id = gencfg.get("dac")
        except Exception:
            dac_id = None
        if dac_id is not None:
            phys = lookup_physical(physical_port_labels, dac_id)
            label = f"{label} ({phys or default_port_text(soccfg, 'dac', dac_id)})"
    return label


def _adc_label(sched: Schedule, ch: int, physical_port_labels,
               n_windows: Optional[int] = None) -> str:
    label = f"ro {ch}"
    if n_windows is not None and n_windows > 1:
        label = f"{label} ({n_windows} windows)"
    soccfg = sched.soccfg
    if soccfg is not None:
        try:
            getter = getattr(soccfg, "get_ro_cfg", None)
            rocfg = getter(ch) if callable(getter) else soccfg["readouts"][ch]
            adc_id = rocfg.get("adc")
        except Exception:
            adc_id = None
        if adc_id is not None:
            phys = lookup_physical(physical_port_labels, adc_id)
            label = f"{label} ({phys or default_port_text(soccfg, 'adc', adc_id)})"
    return label


def _format_duration(us: float) -> str:
    if us < 0.001:
        return f"{us * 1e6:.0f} ps"
    if us < 1.0:
        return f"{us * 1e3:.2g} ns"
    if us < 1000.0:
        return f"{us:.3g} µs"
    return f"{us / 1000.0:.3g} ms"


def _sliver(width: float, window_us: float) -> bool:
    """True if a bar this wide would render as a vertical tick, not a pulse."""
    return width < max(_SHORT_FRAC * window_us, 1e-6)


def _short_events(events: Sequence[PulseEvent], draw_lengths: dict,
                  window_us: float) -> List[PulseEvent]:
    out = []
    for e in events:
        if e.kind != "gen":
            continue
        if _sliver(draw_lengths.get(id(e), e.length), window_us):
            out.append(e)
    return out


def _choose_inset_window(short: Sequence[PulseEvent], pad_us: float) -> Optional[Tuple[float, float]]:
    if not short:
        return None
    starts = [e.t_start for e in short]
    ends = [e.t_start + e.length for e in short]
    lo, hi = min(starts), max(ends)
    span = max(hi - lo, 1e-3)
    return max(0.0, lo - pad_us), hi + pad_us + 0.05 * span


def sweep_ghost(event: PulseEvent, draw_len: Optional[float] = None
                ) -> Optional[Tuple[float, float]]:
    """Return ``(t_start, length)`` of the dashed ghost at the other sweep extreme.

    Nominal bars use the sweep *start* (``event.t_start``, ``event.length``).
    The ghost is the same pulse at the opposite endpoint:

    * time-only sweep: same width, different start (translation);
    * length-only sweep: same start, different width (stretch);
    * both: the other start *and* the other length.

    ``draw_len`` overrides the nominal width (periodic extension).  Returns
    ``None`` when nothing is swept or the ghost would overlap the nominal bar.
    """
    length = event.length if draw_len is None else draw_len
    t_g = event.t_start
    if event.time_swept:
        if abs(event.t_start - event.t_min) <= abs(event.t_start - event.t_max):
            t_g = event.t_max
        else:
            t_g = event.t_min
    l_g = length
    if event.length_swept:
        if abs(event.length - event.len_min) <= abs(event.length - event.len_max):
            l_g = event.len_max
        else:
            l_g = event.len_min
    l_g = max(float(l_g), 0.0)
    if np.isclose(t_g, event.t_start) and np.isclose(l_g, length):
        return None
    return float(t_g), l_g


def _darker(color, factor: float = 0.4):
    r, g, b = to_rgb(color)
    return (r * factor, g * factor, b * factor)


def _ghost_label_x(nom_left: float, nom_width: float, g_left: float, g_width: float
                   ) -> float:
    """Midpoint of the ghost segment that is not covered by the nominal bar."""
    n0, n1 = nom_left, nom_left + max(nom_width, 0.0)
    g0, g1 = g_left, g_left + max(g_width, 0.0)
    segs = []
    if g0 < n0 - 1e-12:
        segs.append((g0, min(g1, n0)))
    if g1 > n1 + 1e-12:
        segs.append((max(g0, n1), g1))
    segs = [(a, b) for a, b in segs if b - a > 1e-12]
    if segs:
        a, b = max(segs, key=lambda s: s[1] - s[0])
        return 0.5 * (a + b)
    return 0.5 * (g0 + g1)


def _timing_loop_label(events: Sequence[PulseEvent]) -> str:
    loops = []
    for e in events:
        for n in e.timing_loops:
            if n not in loops:
                loops.append(n)
    return ", ".join(loops)


def _draw_ghost(ax, y: float, left: float, width: float, height: float, color,
                label: Optional[str] = None,
                nom_left: Optional[float] = None,
                nom_width: Optional[float] = None,
                min_label_width: float = 0.0) -> None:
    """Dashed outline of the pulse at the other sweep extreme.

    Same lane as the solid bar, drawn on top, with a darker dotted edge so a
    ghost that overlaps the initial pulse still shows where it begins.
    ``label`` is the loop that moves or stretches this pulse.
    """
    width = max(width, 0.0)
    dark = _darker(color)
    bars = ax.barh(
        y, width, left=left, height=height,
        facecolor=color, alpha=0.12, edgecolor="none", zorder=3,
    )
    for artist in bars:
        artist.set_gid("qcvt_ghost")
    y0, y1 = y - height / 2, y + height / 2
    right = left + width
    kw = dict(color=dark, linewidth=1.8, linestyle=(0, (1.2, 0.9)),
              solid_capstyle="butt", zorder=6)
    ax.plot([left, right], [y1, y1], **kw)
    ax.plot([left, right], [y0, y0], **kw)
    ax.plot([left, left], [y0, y1], **kw)
    ax.plot([right, right], [y0, y1], **kw)
    if label and width >= min_label_width:
        x = _ghost_label_x(
            left if nom_left is None else nom_left,
            0.0 if nom_width is None else nom_width,
            left, width,
        )
        ax.text(x, y, label, ha="center", va="center", fontsize=6.5,
                color=dark, zorder=7, clip_on=True, fontstyle="italic",
                bbox=dict(boxstyle="round,pad=0.12", facecolor="white",
                          edgecolor="none", alpha=0.8))


def _adc_series_ghost(events: Sequence[PulseEvent]) -> Optional[Tuple[float, float]]:
    """One ghost spanning a burst of ADC windows at the other start extreme."""
    if not events:
        return None
    ghosts = []
    for e in events:
        g = sweep_ghost(e, e.length)
        if g is None:
            continue
        ghosts.append((g[0], g[0] + g[1]))
    if not ghosts:
        return None
    lo = min(a for a, _ in ghosts)
    hi = max(b for _, b in ghosts)
    return lo, max(hi - lo, 0.0)


def plot_pulse_schedule(
    prog,
    ax=None,
    t0_us: float = 0.0,
    max_time_us: Optional[float] = None,
    gen_ch_labels: Optional[dict] = None,
    physical_port_labels: Optional[dict] = None,
    show_readout_triggers: bool = True,
    show_amplitude: bool = False,
    amplitude_units: str = "dac",
    title: Optional[str] = None,
    label_pulses: bool = True,
    schedule: Optional[Schedule] = None,
    insets: bool = False,
    time_origin: str = "program",
):
    """Plot a pulse schedule from a compiled QICK ``asm_v2`` program.

    Parameters
    ----------
    prog :
        Compiled program (``AveragerProgramV2``) or a pre-built :class:`Schedule`.
    ax : matplotlib axes, optional
        Axes to draw the schedule on.  If ``None`` a new figure is created (and,
        when ``show_amplitude`` is set, a second amplitude panel is added).
    t0_us : float
        Left limit of the time axis (viewing-window start).
    max_time_us : float, optional
        Right limit of the time axis.  If ``None`` it is inferred from the schedule.
    gen_ch_labels : dict, optional
        Map ``gen_ch (int) -> label`` for lane labels.  Matches the channel
        numbers used in ``add_pulse`` / ``declare_gen``.  If omitted, session
        defaults from :func:`~qcvt.set_channel_labels` and any
        ``soccfg["qcvt_gen_ch_labels"]`` are used.
    physical_port_labels : dict, optional
        Map RFDC tile/block ids (e.g. ``'12'`` or ``12``) -> human labels.
        These ids are *not* QICK box DAC numbers; see ``print(soccfg)`` or
        ``soccfg.get_gen_cfg(ch)['dac']``.  Prefer ``gen_ch_labels`` for
        names you actually think about.  Unlabelled ports default to the
        QICK box port (``DAC 4``) when the board mapping is known.
    show_readout_triggers : bool
        Draw ADC integration windows as their own lanes.
    show_amplitude : bool
        Add an amplitude-vs-time panel (only when ``ax`` is not supplied).
    amplitude_units : str
        ``"dac"`` (0..maxv) or ``"norm"`` (0..1) for the amplitude panel.
    title : str, optional
        Plot title.  When the program has loops, a ``loops (outer → inner)``
        line is appended so sweep order is visible without extra annotations.
        Time- or length-swept pulses get a dashed ghost at the other sweep
        extreme so a sliding pulse is not drawn as a longer bar.
    label_pulses : bool
        Write each pulse's name on its bar.
    schedule : Schedule, optional
        Pre-extracted schedule (avoids re-extraction when plotting repeatedly).
    insets : bool
        If ``True``, add a zoom inset around short pulses.  Default ``False``:
        interactive windows can already zoom, and auto-insets often obscure
        the timeline.  Pulses that *overlap* the inset window are drawn even
        if they started earlier (so a CW pump that began before the zoom is
        still shown).
    time_origin : str
        ``"program"`` (default): absolute program timeline, including any
        initial delay from ``_initialize()``.  ``"body"``: shift the time axis
        so t = 0 is the start of the loop body, matching how times read inside
        ``_body()``.  Draw-time only; exports keep the absolute timeline.

    Returns
    -------
    ax, or (ax, ax_amp)
        ``ax_amp`` is ``None`` when the amplitude panel was not created.
    """
    if amplitude_units not in ("dac", "norm"):
        raise ValueError("amplitude_units must be 'dac' or 'norm'")
    if time_origin not in ("program", "body"):
        raise ValueError("time_origin must be 'program' or 'body'")

    sched = schedule if schedule is not None else _as_schedule(prog)
    if time_origin == "body" and sched and sched.body_start_us:
        sched = _shifted_schedule(sched, sched.body_start_us)
    gen_ch_labels, physical_port_labels = resolve_label_maps(
        getattr(sched, "soccfg", None), gen_ch_labels, physical_port_labels,
    )
    ax_amp = None
    want_amp = show_amplitude

    if not sched:
        if ax is None:
            _, ax = plt.subplots(figsize=(7, 3))
        ax.text(0.5, 0.5, "No pulse schedule could be extracted from this program.",
                transform=ax.transAxes, ha="center", va="center")
        if title:
            ax.set_title(title)
        return (ax, None) if want_amp else ax

    owns_figure = ax is None
    draw_amp = show_amplitude
    if show_amplitude and owns_figure:
        _, (ax, ax_amp) = plt.subplots(
            2, 1, figsize=(10, 6.5), height_ratios=[1.35, 1.0], sharex=True,
            constrained_layout=True,
        )
    elif owns_figure:
        _, ax = plt.subplots(figsize=(10, 4.5), constrained_layout=True)
    elif show_amplitude:
        draw_amp = False

    gen_chs = sched.gen_chs
    adc_chs = sched.adc_chs if show_readout_triggers else []
    colors = _channel_colors(gen_chs)

    y_pos = {}
    idx = 0
    for ch in gen_chs:
        y_pos[("gen", ch)] = idx
        idx += 1
    for ch in adc_chs:
        y_pos[("adc", ch)] = idx
        idx += 1

    # Window end used for periodic extension + short-pulse detection.
    if max_time_us is not None:
        end_us = float(max_time_us)
    else:
        ends = [max(e.t_end, e.t_max + e.len_max) for e in sched.events]
        end_us = max(ends, default=t0_us + 1.0) * 1.03
    end_us = max(end_us, t0_us + 1e-6)
    window_us = end_us - t0_us

    draw_lengths = sched.draw_lengths(end_us)
    suppressed = sched.suppressed_events()

    _draw_schedule_bars(
        ax, sched, y_pos, colors, draw_lengths, suppressed,
        gen_ch_labels, physical_port_labels, label_pulses,
        t0_us, end_us, window_us, gen_chs, adc_chs,
    )
    if time_origin == "body":
        ax.set_xlabel("Time (µs, relative to body start)")
    title_bits = []
    if title:
        title_bits.append(title)
    if sched.loop_dict:
        # AveragerProgramV2 always has a "reps" averaging loop; skip it so the
        # caption shows the experimenter's sweep order, not shot averaging.
        loops = [(n, c) for n, c in sched.loop_dict.items() if n != "reps"]
        if loops:
            loops_txt = " → ".join(f"{name} ({n})" for name, n in loops)
            title_bits.append(f"loops (outer → inner): {loops_txt}")
    if title_bits:
        ax.set_title("\n".join(title_bits), fontsize=11 if title else 10)

    # Duration callouts for pulses that would be invisible at this zoom.
    short = [e for e in _short_events(sched.gen_events, draw_lengths, window_us)
             if id(e) not in suppressed and t0_us <= e.t_start <= end_us]
    for e in short:
        y = y_pos.get(("gen", e.ch))
        if y is None:
            continue
        color = colors.get(e.ch, "C0")
        ax.plot([e.t_start, e.t_start], [y - _GEN_HEIGHT / 2, y + _GEN_HEIGHT / 2],
                color=color, linewidth=1.6, zorder=4)
        # Upper-left of the tick, in this lane's gap.  Straight up lands on
        # the next lane's ghost; straight right rides this pulse's dotted top.
        ax.annotate(
            f"{e.name}  {_format_duration(e.length)}",
            xy=(e.t_start, y + _GEN_HEIGHT / 2),
            xytext=(-8, 12), textcoords="offset points",
            fontsize=6.5, color=color, ha="right", va="bottom",
            arrowprops=dict(arrowstyle="-", color=color, lw=0.7),
            bbox=dict(boxstyle="round,pad=0.12", facecolor="white",
                      edgecolor="none", alpha=0.85),
            zorder=7,
        )

    # Opt-in inset around short pulses.  Include events that overlap the
    # zoom window even if they started earlier (periodic CW pumps, etc.).
    use_inset = bool(insets)
    if use_inset and owns_figure and short:
        inset_win = _choose_inset_window(short, pad_us=max(0.05, 0.15 * window_us * _SHORT_FRAC))
        if inset_win is not None:
            _add_zoom_inset(
                ax, sched, y_pos, colors, draw_lengths, suppressed,
                gen_ch_labels, physical_port_labels, gen_chs, adc_chs,
                inset_win[0], inset_win[1],
            )

    if draw_amp and ax_amp is not None:
        _draw_amplitude_panel(ax_amp, sched, colors, draw_lengths,
                              amplitude_units, t0_us, end_us, gen_ch_labels)
        if time_origin == "body":
            ax_amp.set_xlabel("Time (µs, relative to body start)")

    return (ax, ax_amp) if want_amp else ax


def _draw_schedule_bars(
    ax, sched, y_pos, colors, draw_lengths, suppressed,
    gen_ch_labels, physical_port_labels, label_pulses,
    t0_us, end_us, window_us, gen_chs, adc_chs,
):
    for e in sched.gen_events:
        if id(e) in suppressed:
            continue
        y = y_pos.get(("gen", e.ch))
        if y is None:
            continue
        color = colors.get(e.ch, "C0")
        draw_len = draw_lengths.get(id(e), e.length)
        t_end = e.t_start + max(draw_len, 0.0)
        # Skip pulses that do not intersect the viewing window.
        if t_end < t0_us or e.t_start > end_us:
            continue

        ghost = sweep_ghost(e, draw_len)
        if ghost is not None:
            _draw_ghost(ax, y, ghost[0], ghost[1], _GEN_HEIGHT, color,
                        label=_timing_loop_label([e]),
                        nom_left=e.t_start, nom_width=max(draw_len, 0.0),
                        min_label_width=max(_SHORT_FRAC * window_us, 1e-6))

        ax.barh(y, max(draw_len, 0.0), left=e.t_start, height=_GEN_HEIGHT,
                color=color, edgecolor="black", linewidth=0.6, zorder=2,
                hatch="////" if e.periodic else None,
                alpha=0.55 if e.periodic else 1.0)

        # Label at the midpoint of the *visible* segment so a zoomed window
        # does not place text far outside xlim (which blows up bbox_inches=tight).
        vis_lo = max(e.t_start, t0_us)
        vis_hi = min(t_end, end_us)
        vis_len = max(vis_hi - vis_lo, 0.0)
        if label_pulses and vis_len >= _SHORT_FRAC * window_us:
            label = e.name
            if e.param_loops:
                bits = [f"{p} ← {lp}" for p, lp in e.param_loops]
                label += f"\n[sweep: {', '.join(bits)}]"
            elif e.swept_params:
                label += f"\n[sweep: {', '.join(e.swept_params)}]"
            if e.style and e.style not in ("const",):
                label += f"\n({e.style})"
            center = 0.5 * (vis_lo + vis_hi)
            wide_enough = vis_len > 0.08 * window_us
            if wide_enough:
                ax.text(center, y, label, ha="center", va="center",
                        fontsize=7, color="white", zorder=3, fontweight="bold",
                        clip_on=True)
            else:
                ax.text(vis_lo, y + _GEN_HEIGHT / 2 + 0.02, label, ha="left",
                        va="bottom", fontsize=6.5, color=color, zorder=3,
                        clip_on=True)

    adc_by_ch: dict = {}
    for e in sched.adc_events:
        y = y_pos.get(("adc", e.ch))
        if y is None:
            continue
        t_end = e.t_start + max(e.length, 0.0)
        if t_end < t0_us or e.t_start > end_us:
            continue
        ax.barh(y, max(e.length, 0.01), left=e.t_start, height=_ADC_HEIGHT,
                color=_ADC_COLOR, alpha=0.7, edgecolor="black", linewidth=0.8, zorder=2)
        adc_by_ch.setdefault(e.ch, []).append(e)

    for ch, evs in adc_by_ch.items():
        y = y_pos.get(("adc", ch))
        if y is None:
            continue
        ghost = _adc_series_ghost(evs)
        if ghost is not None:
            _draw_ghost(ax, y, ghost[0], ghost[1], _ADC_HEIGHT, _ADC_COLOR,
                        label=_timing_loop_label(evs),
                        nom_left=min(e.t_start for e in evs),
                        nom_width=(max(e.t_start + e.length for e in evs)
                                   - min(e.t_start for e in evs)),
                        min_label_width=max(_SHORT_FRAC * window_us, 1e-6))

    adc_window_counts = {}
    for e in sched.adc_events:
        adc_window_counts[e.ch] = adc_window_counts.get(e.ch, 0) + 1

    y_ticks, y_labels = [], []
    for ch in gen_chs:
        y_ticks.append(y_pos[("gen", ch)])
        lab = _gen_label(sched, ch, gen_ch_labels, physical_port_labels)
        freqs = {round(e.freq, 3) for e in sched.gen_events if e.ch == ch and e.freq is not None}
        if len(freqs) == 1:
            lab += f"\n{next(iter(freqs)):g} MHz"
        y_labels.append(lab)
    for ch in adc_chs:
        y_ticks.append(y_pos[("adc", ch)])
        y_labels.append(_adc_label(sched, ch, physical_port_labels,
                                   n_windows=adc_window_counts.get(ch)))

    ax.set_yticks(y_ticks)
    ax.set_yticklabels(y_labels, fontsize=8)
    ax.set_ylim(-0.6, max(len(y_pos) - 0.4, 0.5))
    ax.set_xlim(t0_us, end_us)
    ax.set_xlabel("Time (µs)")
    ax.grid(True, axis="x", alpha=0.3)

    legend_items = []
    if any(e.periodic for e in sched.gen_events):
        legend_items.append(Patch(facecolor="0.6", hatch="////", alpha=0.55,
                                   edgecolor="black", label="periodic (CW)"))
    if adc_chs:
        legend_items.append(Patch(facecolor=_ADC_COLOR, alpha=0.7,
                                   edgecolor="black", label="ADC integration"))
    if any(e.time_swept or e.length_swept for e in sched.events):
        legend_items.append(Patch(facecolor="0.85", edgecolor="0.2",
                                   linestyle=(0, (1.2, 0.9)), linewidth=1.6,
                                   label="other sweep extreme"))
    if legend_items:
        ax.legend(handles=legend_items, loc="upper right", fontsize=7, framealpha=0.9)


def _add_zoom_inset(
    ax, sched, y_pos, colors, draw_lengths, suppressed,
    gen_ch_labels, physical_port_labels, gen_chs, adc_chs,
    z0, z1,
):
    """Overlay a zoom inset on the schedule axes around ``[z0, z1]``."""
    # Place the inset in the upper-left of the schedule panel.
    inset = ax.inset_axes([0.02, 0.55, 0.38, 0.42])
    # Re-draw bars into the inset without lane labels / legend clutter.
    for e in sched.gen_events:
        if id(e) in suppressed:
            continue
        y = y_pos.get(("gen", e.ch))
        if y is None:
            continue
        color = colors.get(e.ch, "C0")
        draw_len = draw_lengths.get(id(e), e.length)
        t_end = e.t_start + max(draw_len, 0.0)
        # Include pulses that overlap the zoom, even if they started earlier
        # (a periodic CW pump often begins before the short-pulse cluster).
        if t_end < z0 or e.t_start > z1:
            continue
        inset.barh(y, max(draw_len, 0.0), left=e.t_start, height=_GEN_HEIGHT,
                   color=color, edgecolor="black", linewidth=0.5, zorder=2,
                   hatch="////" if e.periodic else None,
                   alpha=0.55 if e.periodic else 1.0)
        ghost = sweep_ghost(e, draw_len)
        if ghost is not None:
            g_end = ghost[0] + ghost[1]
            if not (g_end < z0 or ghost[0] > z1):
                _draw_ghost(inset, y, ghost[0], ghost[1], _GEN_HEIGHT, color,
                            label=_timing_loop_label([e]),
                            nom_left=e.t_start, nom_width=max(draw_len, 0.0),
                            min_label_width=max(_SHORT_FRAC * (z1 - z0), 1e-6))
        # Center the label on the segment visible inside the inset window, not
        # the whole pulse (whose midpoint may lie far outside and blow up the
        # figure bbox on save).
        vis_lo = max(e.t_start, z0)
        vis_hi = min(e.t_start + max(draw_len, 0.0), z1)
        inset.text(0.5 * (vis_lo + vis_hi), y,
                   f"{e.name}\n{_format_duration(e.length)}",
                   ha="center", va="center", fontsize=6, color="white",
                   fontweight="bold", zorder=3, clip_on=True)
    adc_by_ch: dict = {}
    for e in sched.adc_events:
        t_end = e.t_start + max(e.length, 0.0)
        if t_end < z0 or e.t_start > z1:
            continue
        y = y_pos.get(("adc", e.ch))
        if y is None:
            continue
        inset.barh(y, max(e.length, 0.0), left=e.t_start, height=_ADC_HEIGHT,
                   color=_ADC_COLOR, alpha=0.7, edgecolor="black", linewidth=0.6)
        adc_by_ch.setdefault(e.ch, []).append(e)
    for ch, evs in adc_by_ch.items():
        y = y_pos.get(("adc", ch))
        if y is None:
            continue
        ghost = _adc_series_ghost(evs)
        if ghost is not None:
            _draw_ghost(inset, y, ghost[0], ghost[1], _ADC_HEIGHT, _ADC_COLOR,
                        label=_timing_loop_label(evs),
                        nom_left=min(e.t_start for e in evs),
                        nom_width=(max(e.t_start + e.length for e in evs)
                                   - min(e.t_start for e in evs)),
                        min_label_width=max(_SHORT_FRAC * (z1 - z0), 1e-6))

    inset.set_xlim(z0, z1)
    inset.set_ylim(ax.get_ylim())
    inset.set_yticks([])
    inset.set_title(f"zoom {_format_duration(z0)}–{_format_duration(z1)}", fontsize=7)
    inset.grid(True, axis="x", alpha=0.3)
    for spine in inset.spines.values():
        spine.set_color("#444444")
        spine.set_linewidth(1.0)
    # Indicate the zoomed region on the parent axes.
    try:
        ax.indicate_inset_zoom(inset, edgecolor="#444444")
    except Exception:
        ax.axvspan(z0, z1, color="0.5", alpha=0.08, zorder=0)


def _draw_amplitude_panel(ax_amp, sched: Schedule, colors, draw_lengths,
                          amplitude_units, t0_us, end_us, gen_ch_labels):
    dac_units = amplitude_units == "dac"
    prog = sched.prog
    seen = set()
    for e in sched.gen_events:
        if e.t_end < t0_us or e.t_start > end_us:
            continue
        draw_len = draw_lengths.get(id(e), e.length)
        color = colors.get(e.ch, "C0")
        label = (gen_ch_labels or {}).get(e.ch, f"gen {e.ch}")
        legend_label = label if e.ch not in seen else "_nolegend_"

        if e.gain_swept:
            # Band spans |gain| over the sweep; a sign-crossing sweep (e.g.
            # -0.6..0.6) reaches zero amplitude, so the band starts at 0.
            band_lo, band_hi = gain_band(e)
            t_lo, a_lo = amplitude_trace(prog, e, length_us=draw_len,
                                         dac_units=dac_units, gain_override=band_lo)
            t_hi, a_hi = amplitude_trace(prog, e, length_us=draw_len,
                                         dac_units=dac_units, gain_override=band_hi)
            if t_lo is not None and t_hi is not None and np.array_equal(t_lo, t_hi):
                ax_amp.fill_between(t_lo, np.abs(a_lo), np.abs(a_hi), color=color,
                                    alpha=0.3, linewidth=0, label="_nolegend_")
                ax_amp.plot(t_lo, (np.abs(a_lo) + np.abs(a_hi)) / 2, color=color,
                            linewidth=2.0, label=legend_label)
                seen.add(e.ch)
                continue

        t_arr, amp = amplitude_trace(prog, e, length_us=draw_len, dac_units=dac_units)
        if t_arr is None:
            continue
        ax_amp.plot(t_arr, np.abs(amp), color=color, linewidth=2.0, label=legend_label)
        seen.add(e.ch)

    for e in sched.adc_events:
        if e.t_end < t0_us or e.t_start > end_us:
            continue
        ax_amp.axvspan(e.t_start, e.t_end, color=_ADC_COLOR, alpha=0.2, lw=0)

    ax_amp.set_xlim(t0_us, end_us)
    ax_amp.set_ylim(bottom=0)
    ax_amp.set_xlabel("Time (µs)")
    ax_amp.set_ylabel("Amplitude (DAC units)" if dac_units else "Amplitude (norm)")
    ax_amp.grid(True, alpha=0.3)
    handles, labels = ax_amp.get_legend_handles_labels()
    if sched.adc_events:
        handles.append(Patch(facecolor=_ADC_COLOR, alpha=0.2, edgecolor="none"))
        labels.append("ADC integration")
    if handles:
        ax_amp.legend(handles=handles, labels=labels, loc="upper right",
                      fontsize=7, framealpha=0.9)


def show_schedule(
    prog,
    title: str = "Pulse schedule",
    show_amplitude: bool = True,
    amplitude_units: str = "dac",
    gen_ch_labels: Optional[dict] = None,
    physical_port_labels: Optional[dict] = None,
    t0_us: float = 0.0,
    max_time_us: Optional[float] = None,
    insets: bool = False,
    time_origin: str = "program",
) -> None:
    """Quickly display a pulse schedule interactively (no files saved).

    Intended for a fast look while running experiments, e.g. right before sending
    a program to the RFSoC.
    """
    plot_pulse_schedule(
        prog,
        show_amplitude=show_amplitude,
        amplitude_units=amplitude_units,
        gen_ch_labels=gen_ch_labels,
        physical_port_labels=physical_port_labels,
        title=title,
        t0_us=t0_us,
        max_time_us=max_time_us,
        insets=insets,
        time_origin=time_origin,
    )
    plt.show()
