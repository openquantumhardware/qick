# -*- coding: utf-8 -*-
"""Session and soccfg defaults for QCVT channel labels.

Experimenters usually think in generator channel numbers (``gen 6``) or
QICK box ports (``DAC 4``), not RFDC tile/block ids (``'12'``).  This
module lets you set those names once per session (or stash them on the
``QickConfig``) instead of passing them to every ``show_schedule`` call.

Resolution order, later wins:

1. Session defaults from :func:`set_channel_labels`
2. ``soccfg["qcvt_gen_ch_labels"]`` / ``soccfg["qcvt_physical_port_labels"]``
   (or the combined ``soccfg["qcvt_labels"]`` dict)
3. Per-call ``gen_ch_labels`` / ``physical_port_labels`` arguments
"""

from __future__ import annotations

from typing import Any, Mapping, Optional, Tuple


_default_gen_ch_labels: dict = {}
_default_physical_port_labels: dict = {}


def _coerce_gen_ch_labels(mapping: Optional[Mapping]) -> dict:
    """JSON round-trips int keys to strings; restore generator-channel ints."""
    out = {}
    for key, val in (mapping or {}).items():
        try:
            out[int(key)] = val
        except (TypeError, ValueError):
            out[key] = val
    return out


def _coerce_physical_port_labels(mapping: Optional[Mapping]) -> dict:
    """Index physical labels by both ``'12'`` and ``12`` so either works."""
    out = {}
    for key, val in (mapping or {}).items():
        out[key] = val
        out[str(key)] = val
        try:
            out[int(key)] = val
        except (TypeError, ValueError):
            pass
    return out


def set_channel_labels(
    gen_ch_labels: Optional[Mapping] = None,
    physical_port_labels: Optional[Mapping] = None,
    *,
    merge: bool = True,
) -> None:
    """Set session-wide default labels for QCVT plots.

    Parameters
    ----------
    gen_ch_labels : dict, optional
        Map ``gen_ch (int) -> name``, e.g. ``{6: "qubit drive"}``.  This is
        usually what you want: it matches the channel numbers in ``add_pulse``.
    physical_port_labels : dict, optional
        Map RFDC tile/block id (``'12'`` or ``12``) -> name.  These ids come
        from ``soccfg.get_gen_cfg(ch)['dac']`` / ``get_ro_cfg(ch)['adc']``,
        and from ``print(soccfg)``.  They are *not* QICK box DAC numbers.
    merge : bool
        If ``True`` (default), update existing defaults.  If ``False``,
        replace the corresponding map entirely (pass an empty dict to clear
        one map without touching the other).

    Examples
    --------
    >>> from qcvt import set_channel_labels, show_schedule
    >>> set_channel_labels(gen_ch_labels={0: "sqz pump", 6: "qubit"})
    >>> show_schedule(prog)  # no labels argument needed
    """
    global _default_gen_ch_labels, _default_physical_port_labels
    if gen_ch_labels is not None:
        coerced = _coerce_gen_ch_labels(gen_ch_labels)
        if merge:
            _default_gen_ch_labels.update(coerced)
        else:
            _default_gen_ch_labels = coerced
    if physical_port_labels is not None:
        coerced = _coerce_physical_port_labels(physical_port_labels)
        if merge:
            _default_physical_port_labels.update(coerced)
        else:
            _default_physical_port_labels = coerced


def clear_channel_labels() -> None:
    """Clear session-wide QCVT channel-label defaults."""
    global _default_gen_ch_labels, _default_physical_port_labels
    _default_gen_ch_labels = {}
    _default_physical_port_labels = {}


def get_channel_labels() -> Tuple[dict, dict]:
    """Return copies of the current session default label maps."""
    return dict(_default_gen_ch_labels), dict(_default_physical_port_labels)


def _soccfg_get(soccfg: Any, key: str, default=None):
    if soccfg is None:
        return default
    try:
        return soccfg[key]
    except Exception:
        return default


def resolve_label_maps(
    soccfg: Any,
    gen_ch_labels: Optional[Mapping] = None,
    physical_port_labels: Optional[Mapping] = None,
) -> Tuple[dict, dict]:
    """Merge session, soccfg, and per-call label maps.  Later sources win."""
    gen = dict(_default_gen_ch_labels)
    phys = dict(_default_physical_port_labels)

    combined = _soccfg_get(soccfg, "qcvt_labels")
    if isinstance(combined, Mapping):
        gen.update(_coerce_gen_ch_labels(combined.get("gen_ch") or combined.get("gen_ch_labels")))
        phys.update(_coerce_physical_port_labels(
            combined.get("physical") or combined.get("physical_port_labels")
        ))
    gen.update(_coerce_gen_ch_labels(_soccfg_get(soccfg, "qcvt_gen_ch_labels")))
    phys.update(_coerce_physical_port_labels(_soccfg_get(soccfg, "qcvt_physical_port_labels")))

    if gen_ch_labels:
        gen.update(_coerce_gen_ch_labels(gen_ch_labels))
    if physical_port_labels:
        phys.update(_coerce_physical_port_labels(physical_port_labels))
    return gen, phys


def lookup_physical(mapping: Optional[Mapping], rfdc_id) -> Optional[str]:
    """Look up a physical-port label, accepting int or string keys."""
    if not mapping or rfdc_id is None:
        return None
    if rfdc_id in mapping:
        return mapping[rfdc_id]
    s = str(rfdc_id)
    if s in mapping:
        return mapping[s]
    try:
        i = int(s)
    except (TypeError, ValueError):
        return None
    return mapping.get(i)


def default_port_text(soccfg: Any, kind: str, rfdc_id) -> str:
    """Fallback y-axis suffix: QICK box port when known, else ``dac 12``."""
    if rfdc_id is None:
        return ""
    name = "get_dac_port_label" if kind == "dac" else "get_adc_port_label"
    getter = getattr(soccfg, name, None) if soccfg is not None else None
    if callable(getter):
        try:
            return getter(rfdc_id)
        except Exception:
            pass
    return f"{kind} {rfdc_id}"
