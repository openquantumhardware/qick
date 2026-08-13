# -*- coding: utf-8 -*-
"""
Matplotlib rendering of a QICK pulse :class:`~qcvt.model.Schedule`.

The schedule plot shows one horizontal lane per generator/readout channel with
every pulse drawn as a labelled bar on a shared microsecond axis.  An optional
amplitude panel reconstructs the output amplitude vs. time.  Swept parameters
(time, length, gain) are drawn as translucent ranges so you can see, at a glance,
what the loop actually varies before the program is sent to the RFSoC.

Multi-timescale programs (ns-scale qubit pulses next to µs-scale readout / ms-scale
CW pumps) are handled by:

* an explicit ``t0_us`` / ``max_time_us`` viewing window;
* duration callouts + tick marks for pulses that would otherwise be invisible;
* optional zoom insets around clusters of short pulses when the dynamic range
  of pulse lengths is large.
"""

from __future__ import annotations

from dataclasses import replace
from typing import List, Optional, Sequence, Tuple

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

from .model import PulseEvent, Schedule, amplitude_trace, extract_schedule, gain_band


_GEN_HEIGHT = 0.62
_ADC_HEIGHT = 0.4
_ADC_COLOR = "#1a7a1a"
# Pulses shorter than this fraction of the viewing window get a duration callout.
_SHORT_FRAC = 0.015
# If longest/shortest (visible) gen pulse exceeds this, offer an auto-inset.
_INSET_DYNAMIC_RANGE = 25.0


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
            phys = (physical_port_labels or {}).get(str(dac_id))
            label = f"{label} ({phys or 'dac ' + str(dac_id)})"
    return label


def _adc_label(sched: Schedule, ch: int, physical_port_labels) -> str:
    label = f"ro {ch}"
    soccfg = sched.soccfg
    if soccfg is not None:
        try:
            getter = getattr(soccfg, "get_ro_cfg", None)
            rocfg = getter(ch) if callable(getter) else soccfg["readouts"][ch]
            adc_id = rocfg.get("adc")
        except Exception:
            adc_id = None
        if adc_id is not None:
            phys = (physical_port_labels or {}).get(str(adc_id))
            label = f"{label} ({phys or 'adc ' + str(adc_id)})"
    return label


def _format_duration(us: float) -> str:
    if us < 0.001:
        return f"{us * 1e6:.0f} ps"
    if us < 1.0:
        return f"{us * 1e3:.2g} ns"
    if us < 1000.0:
        return f"{us:.3g} µs"
    return f"{us / 1000.0:.3g} ms"


def _short_events(events: Sequence[PulseEvent], draw_lengths: dict,
                  window_us: float) -> List[PulseEvent]:
    thresh = max(_SHORT_FRAC * window_us, 1e-6)
    out = []
    for e in events:
        if e.kind != "gen":
            continue
        if draw_lengths.get(id(e), e.length) < thresh:
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
    insets: Optional[bool] = None,
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
        Map ``gen_ch (int) -> label`` for lane labels.
    physical_port_labels : dict, optional
        Map RFDC ids (e.g. dac ``'00'``, adc ``'20'``) -> human labels.
    show_readout_triggers : bool
        Draw ADC integration windows as their own lanes.
    show_amplitude : bool
        Add an amplitude-vs-time panel (only when ``ax`` is not supplied).
    amplitude_units : str
        ``"dac"`` (0..maxv) or ``"norm"`` (0..1) for the amplitude panel.
    title : str, optional
        Plot title.
    label_pulses : bool
        Write each pulse's name on its bar.
    schedule : Schedule, optional
        Pre-extracted schedule (avoids re-extraction when plotting repeatedly).
    insets : bool or None
        If ``True``, always try to add a zoom inset around short pulses.
        If ``None`` (default), add an inset automatically when the schedule's
        pulse-length dynamic range is large.  If ``False``, never add an inset.
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
    if title:
        ax.set_title(title, fontsize=11)

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
        ax.annotate(
            f"{e.name}\n{_format_duration(e.length)}",
            xy=(e.t_start, y), xytext=(6, 10), textcoords="offset points",
            fontsize=6.5, color=color,
            arrowprops=dict(arrowstyle="-", color=color, lw=0.7),
            zorder=5,
        )

    # Auto inset when short and long pulses coexist in the same window.
    gen_lens = [draw_lengths.get(id(e), e.length) for e in sched.gen_events
                if id(e) not in suppressed and e.length > 0]
    use_inset = insets
    if use_inset is None and gen_lens and short:
        use_inset = (max(gen_lens) / max(min(gen_lens), 1e-9)) >= _INSET_DYNAMIC_RANGE
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

        if e.time_swept:
            ax.barh(y, (e.t_max + draw_len) - e.t_min, left=e.t_min, height=_GEN_HEIGHT,
                    color=color, alpha=0.15, edgecolor="none", zorder=1)
        elif e.length_swept:
            ax.barh(y, e.len_max, left=e.t_start, height=_GEN_HEIGHT,
                    color=color, alpha=0.15, edgecolor="none", zorder=1)

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
            if e.swept_params:
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

    for e in sched.adc_events:
        y = y_pos.get(("adc", e.ch))
        if y is None:
            continue
        if e.t_end < t0_us or e.t_start > end_us:
            continue
        ax.barh(y, max(e.length, 0.01), left=e.t_start, height=_ADC_HEIGHT,
                color=_ADC_COLOR, alpha=0.7, edgecolor="black", linewidth=0.8, zorder=2)

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
        y_labels.append(_adc_label(sched, ch, physical_port_labels))

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
    if any(e.swept_params for e in sched.gen_events):
        legend_items.append(Patch(facecolor="0.6", alpha=0.15, edgecolor="none",
                                   label="swept range"))
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
        if e.t_end < z0 or e.t_start > z1:
            continue
        y = y_pos.get(("gen", e.ch))
        if y is None:
            continue
        color = colors.get(e.ch, "C0")
        draw_len = draw_lengths.get(id(e), e.length)
        inset.barh(y, max(draw_len, 0.0), left=e.t_start, height=_GEN_HEIGHT,
                   color=color, edgecolor="black", linewidth=0.5, zorder=2,
                   hatch="////" if e.periodic else None,
                   alpha=0.55 if e.periodic else 1.0)
        # Center the label on the segment visible inside the inset window, not
        # the whole pulse (whose midpoint may lie far outside and blow up the
        # figure bbox on save).
        vis_lo = max(e.t_start, z0)
        vis_hi = min(e.t_start + max(draw_len, 0.0), z1)
        inset.text(0.5 * (vis_lo + vis_hi), y,
                   f"{e.name}\n{_format_duration(e.length)}",
                   ha="center", va="center", fontsize=6, color="white",
                   fontweight="bold", zorder=3, clip_on=True)
    for e in sched.adc_events:
        if e.t_end < z0 or e.t_start > z1:
            continue
        y = y_pos.get(("adc", e.ch))
        if y is None:
            continue
        inset.barh(y, max(e.length, 0.0), left=e.t_start, height=_ADC_HEIGHT,
                   color=_ADC_COLOR, alpha=0.7, edgecolor="black", linewidth=0.6)

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
    insets: Optional[bool] = None,
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
