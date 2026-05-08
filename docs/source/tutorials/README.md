# QICK Tutorial Notebooks

This directory contains Jupyter notebooks that introduce the QICK framework and the tProc v2.

## Notebooks

| # | Notebook | Description |
|:-|:---|:---|
| 00 | `00_Getting_Started.ipynb` | Connect to the board, inspect hardware configuration |
| 01 | `01_Basic_Sequencing.ipynb` | Define pulses, create sequences, acquire data |
| 02 | `02_Parameter_Sweeps.ipynb` | 1D and 2D parameter sweeps |
| 03 | `03_Advanced_Timing.ipynb` | `delay` vs `wait`, auto-timing, avoiding collisions |
| 04 | `04_Real_Time_Feedback.ipynb` | Conditional pulses, active reset, thresholding |
| 05 | `05_Dynamic_Parameters_Subroutines.ipynb` | Virtual-Z gates, subroutines, dynamic updates |
| 06 | `06_Hardware_Buffers.ipynb` | DDR4 and MR buffers, data capture |
| 07 | `07_Appendix_Tips_And_Limits.ipynb` | Common errors, limits, debugging tips |

## Usage

1. Copy these notebooks to your RFSoC board (or run them directly from this location)
2. Start Jupyter: `jupyter notebook` or `jupyter lab`
3. Open the desired notebook
4. **IMPORTANT**: Change the `BITSTREAM_PATH` variable in each notebook to point to your firmware file
5. Run cells sequentially

## Remote Execution

For remote execution (e.g., from a PC), you'll need to start the QICK proxy server on the board first:

```bash
python -m qick.pyro
```

Then in your notebook, use:

```python
from qick.pyro import make_proxy
soc = make_proxy("board_ip_address")
```

