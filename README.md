
<img src="documentation/images/logoQICK.png">

# QICK: Quantum Instrumentation Controller Kit

QICK is a kit of firmware and software to use the Xilinx RFSoC as to control quantum systems.

It consists of:
* Firmware for the ZCU111 RFSoC evaluation board.  
* A python package for interfacing with the QICK controller
* Examples demonstrating usage

Note: The firmware and software here is still very much a work in progress. This is an alpha release. We strive to be consistent with the APIs but can not guarantee backwar


 

## Key Features 
* 6 GHz DAC and 4 GHz ADC direct modulation
* Timed Processor implemented in firmare orchestrats timed pulse generation and readback
* [Plotly](https://plot.ly/) visualisation of spectrum and spectrogram (waterfall)


## Installation

Copied from the project strath-sdr/rfsoc_sam -- need to make this correct!  

Follow the instructions below to install the Spectrum Analyser now. **You will need to give your board access to the internet**.
* Power on your RFSoC2x2 or ZCU111 development board with an SD Card containing a fresh PYNQ v2.6 image.
* Navigate to Jupyter Labs by opening a browser (preferably Chrome) and connecting to `http://<board_ip_address>:9090/lab`.
* We need to open a terminal in Jupyter Lab. Firstly, open a launcher window as shown in the figure below:


## ZCU111 Setup

DO WE NEED THIS or is it already done in pynq v2.6?

The ZCU111 image requres a few changes to operate correctly. It is absolutely essential that the xrfdc package is patched. This procedure will overwrite the xrfdc's `__init__.py`. You will not lose any current xrfdc functionality. You will gain thresholding capabilities and fabric read and write register configuration. These are required by the Spectrum Analyser to operate correctly.

**(xrfdc patch)** In the terminal window, run the following script:
```sh
mkdir /home/xilinx/GitHub
cd /home/xilinx/GitHub/
git clone https://github.com/dnorthcote/ZCU111-PYNQ
cd /home/xilinx/GitHub/ZCU111-PYNQ
cp /home/xilinx/GitHub/ZCU111-PYNQ/ZCU111/packages/xrfdc/pkg/xrfdc/__init__.py /usr/local/lib/python3.6/dist-packages/xrfdc/__init__.py
```


```sh
pip3 install git+https://github.com/link to the github
```

Once installation has complete you will find the Spectrum Analyser notebooks in the Jupyter workspace directory. The folder will be named 'spectrum-analyzer'.

## Using the Project Files
The following software is required to use the project files in this repository.
- Vivado Design Suite 2020.1 CHECK WITH LEO regarding the vivado version

### Vivado
This project can be built with Vivado from the command line. Open Vivado 2020.1 and execute the following into the tcl console:
```sh
cd /<repository-location>/boards/<board-name>/rfsoc_sam/
```
Now that we have moved into the correct directory, make the Vivado project by running the make commands below sequentially.
```sh
make project
make block_design
make bitstream_file
```

Alternatively, you can run the entire project build by executing the following into the tcl console:
```sh
make all
```

## License 

What license do we want?

[BSD 3-Clause](../../blob/master/LICENSE)
