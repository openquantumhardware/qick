"""Shared pytest fixtures for QCVT tests."""
from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _clear_qcvt_labels():
    try:
        from qcvt import clear_channel_labels
    except ImportError:
        yield
        return
    clear_channel_labels()
    yield
    clear_channel_labels()
