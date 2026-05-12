# QICK Tutorial Notebooks

This directory contains Jupyter notebooks that introduce the QICK framework and the tProc v2.

## Prerequisites

- QICK installed on RFSoC board or remote PC
- Firmware bitstream file (`.bit`) for your board
- Jupyter notebook/lab

## Notebooks

### Basic (00–05)

| # | Notebook | Description |
|:-|:---|:---|
| 00 | `00_Getting_Started.ipynb` | Connect to the board, inspect hardware configuration |
| 01 | `01_Basic_Sequencing.ipynb` | Define pulses, create sequences, acquire data |
| 02 | `02_Parameter_Sweeps.ipynb` | 1D and 2D parameter sweeps |
| 03 | `03_Advanced_Timing.ipynb` | `delay` vs `wait`, auto-timing, avoiding collisions |
| 04 | `04_Real_Time_Feedback.ipynb` | Conditional pulses, active reset, thresholding |
| 05 | `05_Dynamic_Parameters_Subroutines.ipynb` | Virtual-Z gates, subroutines, dynamic updates |

### Intermediate (06–08)

| # | Notebook | Description |
|:-|:---|:---|
| 06 | `06_Generators_And_Readouts.ipynb` | Basic waveform generators, readout resonators, I/Q mixing |
| 07 | `07_Advanced_Generators_And_Readouts.ipynb` | Muxed generators, PFB readout, dynamic readouts, fast dynamic readout, electrical delay calibration, IQ offsets, performance benchmarks |
| 08 | `08_Hardware_Buffers.ipynb` | DDR4 and MR buffers, data capture |
| 09 | `09_Appendix_Tips_And_Limits.ipynb` | Common errors, limits, debugging tips |

### Advanced (10–13)

| # | Notebook | Description |
|:-|:---|:---|
| 10 | `10_Multi_Core_Synchronization.ipynb` | Multi-tProc cores, triggers, cross-core dependencies |
| 11 | `11_Streaming_And_RealTime_Processing.ipynb` | IQ streaming, on-FPGA averaging, real-time decimation |
| 12 | `12_DSP_Blocks_And_Correlators.ipynb` | FIR filters, DDS tuning, hardware correlators |
| 13 | `13_Custom_Firmware_Integration.ipynb` | Adding custom Verilog/VHDL, AXI-lite interface, rebuilding |

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
## Common Setup Cell (copy this to any notebook)

```python
# Configuration
BITSTREAM_PATH = "/path/to/your/firmware.bit"  # ← CHANGE THIS

# Optional: remote execution
USE_PROXY = False
PROXY_IP = "192.168.1.100"

# Connection
from qick import QickSoc
import numpy as np
import matplotlib.pyplot as plt

if USE_PROXY:
    from qick.pyro import make_proxy
    soc = make_proxy(PROXY_IP)
    print(f"Connected to proxy at {PROXY_IP}")
else:
    soc = QickSoc(bitfile=BITSTREAM_PATH)
    print("Connected directly to RFSoC")

print(f"Firmware: {soc.get_cfg()['fw_version']}")
print(f"tProc cores: {soc.num_tprocs}")
```

## Notes

* Notebooks 00–09 are self-contained and work on any QICK setup

* Notebooks 10–13 require additional hardware resources (multi-core, streaming, DSP48)

* Notebook 13 requires a licensed Vivado installation for custom firmware compilation

## Troubleshooting

If you see "Bitstream not found", check `BITSTREAM_PATH`

If tProc commands fail, try `soc.reset_gens()` and `soc.reset_adcs()`

For proxy connection issues, verify the board IP and that the proxy is running

If no signal in readout, check DAC→ADC loopback cables, verify `gen_ch` is correct

Phase rotates with frequency, run electrical delay calibration (see [Notebook 07](./07_Advanced_Generators_And_Readouts.ipynb))