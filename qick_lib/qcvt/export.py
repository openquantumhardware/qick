# -*- coding: utf-8 -*-
"""
CSV / table exports derived from a QICK pulse :class:`~qcvt.model.Schedule`.

:func:`export_edge_matrix_csv` writes a compact on/off "edge matrix": one row
per lane, one column per timestamp at which some lane's state changes.

:func:`csv_to_table_png` renders that CSV as a highlighted table image.
"""

from __future__ import annotations

import csv as _csv
from typing import List, Optional, Tuple

from .model import Schedule, extract_schedule


def _as_schedule(prog_or_schedule) -> Schedule:
    if isinstance(prog_or_schedule, Schedule):
        return prog_or_schedule
    return extract_schedule(prog_or_schedule)


def _gen_intervals(sched: Schedule, window_end_us: float):
    """Return ``{ch: [(t0, t1), ...]}`` for generator channels."""
    draw_lengths = sched.draw_lengths(window_end_us)
    suppressed = sched.suppressed_events()
    out = {}
    for e in sched.gen_events:
        if id(e) in suppressed:
            continue
        draw_len = draw_lengths.get(id(e), e.length)
        if draw_len <= 0.0:
            continue
        out.setdefault(e.ch, []).append((float(e.t_start), float(e.t_start + draw_len)))
    return out


def _adc_intervals(sched: Schedule):
    out = {}
    for e in sched.adc_events:
        out.setdefault(e.ch, []).append((float(e.t_start), float(e.t_end)))
    return out


def export_edge_matrix_csv(
    prog,
    out_prefix: str,
    t0_us: float,
    t1_us: Optional[float],
    rows: Optional[List[Tuple[str, str, int]]] = None,
    schedule: Optional[Schedule] = None,
) -> str:
    """Export an on/off edge matrix as ``{out_prefix}_state.csv``.

    Columns are timestamps (ns) at which at least one lane changes state.
    Entries are ``on`` / ``off``.

    ``rows`` is a list of ``(label, kind, ch)`` with ``kind`` in ``{"gen","adc"}``;
    when ``None`` it defaults to every generator then every readout channel.

    Returns the CSV path.
    """
    sched = schedule if schedule is not None else _as_schedule(prog)
    if not sched:
        raise RuntimeError("No schedule could be extracted from this program.")
    if t1_us is None:
        t1_us = sched.end_us()

    gen_intervals = _gen_intervals(sched, t1_us)
    adc_intervals = _adc_intervals(sched)
    intervals = {("gen", ch): segs for ch, segs in gen_intervals.items()}
    intervals.update({("adc", ch): segs for ch, segs in adc_intervals.items()})

    if rows is None:
        rows = ([(f"gen {ch}", "gen", ch) for ch in sorted(gen_intervals)]
                + [(f"ro {ch}", "adc", ch) for ch in sorted(adc_intervals)])

    def on_at(kind: str, ch: int, t: float) -> bool:
        for t0, t1 in intervals.get((kind, ch), []):
            if t0 <= t < t1:
                return True
        return False

    edge_times = {float(t0_us), float(t1_us)}
    for segs in intervals.values():
        for a, b in segs:
            if t0_us <= a <= t1_us:
                edge_times.add(float(a))
            if t0_us <= b <= t1_us:
                edge_times.add(float(b))
    edge_times = sorted(edge_times)

    # Keep only timestamps where some lane's on/off state actually changes.
    columns: List[float] = []
    for t in edge_times:
        if not columns:
            columns.append(t)
            continue
        prev = columns[-1]
        changed = any(
            on_at(kind, ch, prev) != on_at(kind, ch, t)
            for _label, kind, ch in rows
        )
        if changed:
            columns.append(t)

    state_rows = []
    for label, kind, ch in rows:
        srow = [label]
        for col in columns:
            srow.append("on" if on_at(kind, int(ch), float(col)) else "off")
        state_rows.append(srow)

    header = ["timestamp (ns)"] + _unique_time_labels([c * 1_000.0 for c in columns])
    state_path = f"{out_prefix}_state.csv"
    with open(state_path, "w", newline="") as f:
        w = _csv.writer(f)
        w.writerow(header)
        w.writerows(state_rows)
    return state_path


def _unique_time_labels(values_ns) -> List[str]:
    """Format timestamps with the fewest decimals that keep them distinct."""
    for decimals in range(2, 10):
        labels = []
        for v in values_ns:
            mant, exp = f"{v:.{decimals}e}".split("e")
            mant = mant.rstrip("0").rstrip(".")
            labels.append(f"{mant}e{int(exp)}")
        if len(labels) == len(set(labels)):
            return labels
    seen, out = {}, []
    for lbl in labels:
        n = seen.get(lbl, 0) + 1
        seen[lbl] = n
        out.append(lbl if n == 1 else f"{lbl}({n})")
    return out


def csv_to_table_png(csv_path: str, png_path: str, title: str = "") -> None:
    """Render a CSV (e.g. an edge matrix) as a PNG table.

    Cells that are ``on`` are highlighted.  Uses the stdlib ``csv`` module
    (no pandas required).
    """
    import matplotlib.pyplot as plt

    with open(csv_path, newline="") as f:
        rows = list(_csv.reader(f))
    if not rows:
        raise ValueError(f"empty CSV: {csv_path}")
    header, data = rows[0], rows[1:]

    def _display_col(col: str) -> str:
        if col == header[0]:
            return col
        s = str(col).strip()
        if "(" in s and s.endswith(")"):
            base, suf = s.rsplit("(", 1)
            base = base.strip()
            try:
                float(base)
                return base + "(" + suf
            except ValueError:
                pass
        return s

    display_cols = [_display_col(c) for c in header]
    fig_h = max(2.5, 0.55 * (len(data) + 1))
    fig_w = max(8.0, 0.8 * len(header))
    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")
    cell_text = data if data else [[""] * len(header)]
    tbl = ax.table(
        cellText=cell_text, colLabels=display_cols, loc="center", cellLoc="center",
    )
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(9)
    tbl.scale(1.0, 1.35)
    try:
        first_w = tbl[(0, 0)].get_width()
        for (r, c), cell in tbl.get_celld().items():
            if c == 0:
                cell.set_width(first_w * 1.8)
    except Exception:
        pass

    highlight = "#d9ecff"
    for (r, c), cell in tbl.get_celld().items():
        if r == 0 or c <= 0:
            continue
        try:
            val = data[r - 1][c]
        except (IndexError, TypeError):
            continue
        on = isinstance(val, str) and val.strip().lower() == "on"
        if on:
            cell.set_facecolor(highlight)

    if title:
        ax.set_title(title, pad=6)
    fig.tight_layout()
    fig.savefig(png_path, dpi=200, bbox_inches="tight")
    plt.close(fig)
