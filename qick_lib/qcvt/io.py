# -*- coding: utf-8 -*-
"""
Input/output helpers and one-call orchestration for QCVT.

These functions cover the two offline entry points:

* load a compiled-program pickle (as saved into a QCoDeS dataset) and visualize it;
* save/load a ``soccfg`` JSON so programs can be rebuilt and visualized without a
  live RFSoC connection.

:func:`visualize_all` extracts the schedule once and produces every artifact
(schedule PNG, state edge matrix and its table PNG).
"""

from __future__ import annotations

import json
import os
from typing import List, Optional, Tuple

from .export import (
    csv_to_table_png,
    export_edge_matrix_csv,
)
from .model import extract_schedule
from .plotting import plot_pulse_schedule

try:  # optional: only needed to build QickConfig from JSON
    from qick.qick_asm import QickConfig
except Exception:  # pragma: no cover - qick not installed
    QickConfig = None


def save_soccfg_to_json(soc, path: str) -> None:
    """Save the current RFSoC config to JSON so programs can be built offline.

    Call this once while connected::

        save_soccfg_to_json(soc, "qick_config.json")
    """
    with open(path, "w") as f:
        json.dump(soc.get_cfg(), f, indent=2)
    print(f"Saved soccfg to {path}")


def load_soccfg_from_json(path: str, *, align_version: bool = False):
    """Load a :class:`QickConfig` from a JSON file (requires ``qick``).

    Parameters
    ----------
    path : str
        Path to a JSON file written by :func:`save_soccfg_to_json`.
    align_version : bool
        If ``True``, rewrite ``sw_version`` to the installed QICK version
        *before* constructing :class:`QickConfig`.  Use this for bundled
        offline demo configs so a stale snapshot does not warn you to
        upgrade the RFSoC.  Leave ``False`` (default) for configs captured
        from a live board, where a mismatch is a real signal.
    """
    if QickConfig is None:
        raise ImportError("qick is required for load_soccfg_from_json")
    if not align_version:
        return QickConfig(path)
    with open(path) as f:
        cfg = json.load(f)
    try:
        from qick import get_version
        cfg["sw_version"] = get_version()
    except Exception:
        pass
    return QickConfig(cfg)


def load_program_pickle(pickle_path: str):
    """Load a compiled program from a cloudpickle/pickle file.

    Prefers ``cloudpickle`` when installed (``pip install qcvt[pickle]``);
    falls back to the stdlib ``pickle`` module.
    """
    try:
        import cloudpickle as pickle_mod
    except ImportError:
        import pickle as pickle_mod
    with open(pickle_path, "rb") as f:
        return pickle_mod.load(f)


def visualize_from_pickle(
    pickle_path: str,
    output_path: Optional[str] = None,
    title: Optional[str] = None,
    show_amplitude: bool = True,
    amplitude_units: str = "dac",
    show: bool = False,
    t0_us: float = 0.0,
    max_time_us: Optional[float] = None,
):
    """Load a compiled-program pickle and plot its pulse schedule.

    Parameters
    ----------
    pickle_path : str
        Path to the ``.pkl`` file (e.g. ``compiled_program_pickle`` from a dataset).
    output_path : str, optional
        If set, save the figure here.
    title : str, optional
        Plot title.
    show_amplitude : bool
        Include the amplitude panel.
    amplitude_units : str
        ``"dac"`` or ``"norm"``.
    show : bool
        Call ``plt.show()`` (defaults to ``False`` so the function is headless-safe).
    t0_us, max_time_us :
        Optional viewing window in microseconds.

    Returns
    -------
    (prog, ax)
    """
    import matplotlib.pyplot as plt

    prog = load_program_pickle(pickle_path)
    result = plot_pulse_schedule(
        prog,
        show_amplitude=show_amplitude,
        amplitude_units=amplitude_units,
        title=title or "Pulse schedule",
        t0_us=t0_us,
        max_time_us=max_time_us,
    )
    ax = result[0] if isinstance(result, tuple) else result
    if output_path:
        ax.figure.savefig(output_path, dpi=150, bbox_inches="tight")
        print(f"Saved figure to {output_path}")
    if show:
        plt.show()
    return prog, ax


def review_schedule(
    prog,
    save_dir: Optional[str] = None,
    title: str = "Pulse schedule (pre-submit review)",
    show_amplitude: bool = True,
    amplitude_units: str = "dac",
    gen_ch_labels: Optional[dict] = None,
    physical_port_labels: Optional[dict] = None,
    t0_us: float = 0.0,
    max_time_us: Optional[float] = None,
    show: bool = False,
    confirm: bool = False,
    full_export: bool = False,
    time_origin: str = "program",
    insets: bool = False,
    strict: bool = False,
    suppress_off_pulses: bool = True,
) -> bool:
    """Pre-submission gate: visualize the schedule before sending it to the RFSoC.

    Always saves a schedule PNG when ``save_dir`` is set (created if missing).
    Optionally displays the figure and/or prompts for confirmation.

    Parameters
    ----------
    prog :
        Compiled QICK program.
    save_dir : str, optional
        Directory for the review PNG (and optional full export).  If ``None``,
        nothing is written to disk.
    title : str
        Plot title.
    show : bool
        If ``True``, call ``plt.show()`` (interactive).  Defaults to ``False``
        so this is safe in headless / scripted runs.
    confirm : bool
        If ``True``, prompt the user with ``Proceed with acquisition? [y/N]``.
        Returns ``False`` if they decline (caller should abort ``prog.acquire``).
    full_export : bool
        If ``True`` and ``save_dir`` is set, also write the state edge matrix
        via :func:`visualize_all`.
    time_origin : str
        ``"program"`` (absolute timeline, default) or ``"body"`` (t = 0 at the
        start of the loop body).  Affects plots only; exports stay absolute.
    t0_us, max_time_us :
        Optional viewing window (µs). Use to zoom on short pulses next to long ones.
    insets : bool
        If ``True``, add a zoom inset around short pulses.  Default ``False``.

    Returns
    -------
    bool
        ``True`` if acquisition should proceed, ``False`` if the user aborted.
        When ``confirm`` is ``False``, always returns ``True``.
    """
    import matplotlib.pyplot as plt

    schedule_path = None
    sched = extract_schedule(
        prog, strict=strict, suppress_off_pulses=suppress_off_pulses,
    )
    if save_dir is not None and full_export:
        os.makedirs(save_dir, exist_ok=True)
        visualize_all(
            prog,
            out_dir=save_dir,
            title=title,
            show_amplitude=show_amplitude,
            amplitude_units=amplitude_units,
            t0_us=t0_us,
            t1_us=max_time_us,
            gen_ch_labels=gen_ch_labels,
            physical_port_labels=physical_port_labels,
            show=False,
            time_origin=time_origin,
            insets=insets,
            strict=strict,
            suppress_off_pulses=suppress_off_pulses,
        )
        schedule_path = os.path.join(save_dir, "schedule.png")
        print(f"QCVT review saved: {schedule_path}")
        if show:
            plot_pulse_schedule(
                prog,
                schedule=sched,
                show_amplitude=show_amplitude,
                amplitude_units=amplitude_units,
                gen_ch_labels=gen_ch_labels,
                physical_port_labels=physical_port_labels,
                title=title,
                t0_us=t0_us,
                max_time_us=max_time_us,
                time_origin=time_origin,
                insets=insets,
            )
            plt.show()
    else:
        result = plot_pulse_schedule(
            prog,
            schedule=sched,
            show_amplitude=show_amplitude,
            amplitude_units=amplitude_units,
            gen_ch_labels=gen_ch_labels,
            physical_port_labels=physical_port_labels,
            title=title,
            t0_us=t0_us,
            max_time_us=max_time_us,
            time_origin=time_origin,
            insets=insets,
        )
        ax = result[0] if isinstance(result, tuple) else result
        if save_dir is not None:
            os.makedirs(save_dir, exist_ok=True)
            schedule_path = os.path.join(save_dir, "schedule.png")
            ax.figure.savefig(schedule_path, dpi=150, bbox_inches="tight")
            print(f"QCVT review saved: {schedule_path}")
        if show:
            plt.show()
        else:
            plt.close(ax.figure)

    if not confirm:
        return True
    try:
        answer = input("Proceed with RFSoC acquisition? [y/N] ").strip().lower()
    except EOFError:
        answer = ""
    if answer in ("y", "yes"):
        return True
    print("Acquisition aborted by user.")
    return False


def visualize_all(
    prog,
    out_dir: str,
    title: str = "Pulse schedule",
    show_amplitude: bool = True,
    amplitude_units: str = "dac",
    t0_us: float = 0.0,
    t1_us: Optional[float] = None,
    rows: Optional[List[Tuple[str, str, int]]] = None,
    gen_ch_labels: Optional[dict] = None,
    physical_port_labels: Optional[dict] = None,
    schedule_dpi: int = 150,
    show: bool = False,
    insets: bool = False,
    time_origin: str = "program",
    write_table_png: bool = True,
    strict: bool = False,
    suppress_off_pulses: bool = True,
) -> dict:
    """Generate every visualization artifact for ``prog`` in ``out_dir``.

    Returns a dict of output paths (values are ``None`` when a step is skipped).

    ``time_origin="body"`` shifts the schedule *plot* so t = 0 is the start of
    the loop body; the edge-matrix export always stays on the absolute timeline.

    ``write_table_png=False`` writes the edge-matrix CSV only (skips the table
    PNG).  ``strict`` and ``suppress_off_pulses`` are forwarded to
    :func:`~qcvt.model.extract_schedule`.
    """
    import matplotlib.pyplot as plt

    os.makedirs(out_dir, exist_ok=True)
    sched = extract_schedule(
        prog, strict=strict, suppress_off_pulses=suppress_off_pulses,
    )
    results: dict = {}

    schedule_path = os.path.join(out_dir, "schedule.png")
    result = plot_pulse_schedule(
        prog,
        schedule=sched,
        gen_ch_labels=gen_ch_labels,
        physical_port_labels=physical_port_labels,
        show_amplitude=show_amplitude,
        amplitude_units=amplitude_units,
        title=title,
        t0_us=t0_us,
        max_time_us=t1_us,
        insets=insets,
        time_origin=time_origin,
    )
    ax = result[0] if isinstance(result, tuple) else result
    ax.figure.savefig(schedule_path, dpi=schedule_dpi, bbox_inches="tight")
    if show:
        plt.show()
    plt.close(ax.figure)
    results["schedule_png"] = schedule_path

    edges_prefix = os.path.join(out_dir, "edges")
    try:
        state_csv = export_edge_matrix_csv(
            prog, out_prefix=edges_prefix, t0_us=t0_us, t1_us=t1_us,
            rows=rows, schedule=sched,
        )
        results["edges_state_csv"] = state_csv
        if write_table_png:
            state_png = edges_prefix + "_state.png"
            csv_to_table_png(state_csv, state_png, "State edge summary")
            results["edges_state_png"] = state_png
        else:
            results["edges_state_png"] = None
    except RuntimeError:
        results["edges_state_csv"] = None
        results["edges_state_png"] = None

    return results
