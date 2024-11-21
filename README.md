
<p align="center">
 <img src="graphics/logoQICK.svg" alt="QICK logo" width=50% height=auto>
</p>

# QICK: Quantum Instrumentation Control Kit

QICK is an open-source qubit controller, consisting of firmware, software, and an optional frontend for use with Xilinx RFSoC development boards.
The goal of the project is to provide a powerful, flexible, cost-effective, and easy-to-learn platform for control and readout of a diverse range of quantum systems.

QICK supports the ZCU111, ZCU216, and RFSoC4x2 development boards.
We generally recommend using the newer generation of RFSoCs (ZCU216 and RFSoC4x2) for better overall performance.

It consists of:
* Firmware for the supported RFSoC boards, both compiled bitstreams and source for the designs and modules
* The `qick` Python package, which includes the interface to the firmware and an API for writing QICK programs
* [Jupyter notebooks](qick_demos) demonstrating usage

See our [Read the Docs site](https://qick-docs.readthedocs.io/) for:
* Documentation of the firmware and software
* A quick-start guide for setting up your board and running the example Jupyter notebooks
* Ways to communicate with QICK developers and the community
* Extensions to QICK for added functionailty

## Updates

The QICK firmware and software is still very much a work in progress.
We strive to be consistent with the APIs but cannot guarantee backwards compatibility.

Frequent updates to the QICK firmware and software are made as pull requests.
Each pull request will be documented with a description of the notable changes, including any changes that will require you to change your code.
We hope that this will help you decide whether or not to update your local code to the latest version.
We strive for, but cannot guarantee, bug-free and fully functional pull requests.
We also do not guarantee that the demo notebooks will keep pace with every pull request, though we make an effort to update the demos after major API changes.

Our version numbering follows the format major.minor.PR, where PR is the number of the most recently merged pull request.
This will result in the PR number often skipping values, and occasionally decreasing.
The tagged release of a new minor version will have the format major.minor.0.

Tagged releases can be expected periodically.
We recommend that everyone should be using at least the most recent release.
We guarantee the following for releases:
* The demo notebooks will be compatible with the QICK library, and will follow our current best recommendations for writing QICK programs.
* The firmware images for all supported boards will be fully compatible with the library and the demo notebooks.
* Release notes will summarize the pull request notes and explain both breaking API changes (what you need to change in your code) and improvements (why you should move to the new release).

We recommend that you "watch" this repository on GitHub to get automatic notifications of pull requests and releases.

## Contribute

You are welcome to contribute to QICK development by forking this repository and sending pull requests.

All contributions are expected to be consistent with [PEP 8 -- Style Guide for Python Code](https://www.python.org/dev/peps/pep-0008/).

We welcome bug reports and feature requests via GitHub Issues.

## License

The QICK source code is licensed under the MIT license, which you can find in the LICENSE file.
The [QICK logo](graphics/logoQICK.svg) was designed by Dr. Christie Chiu.

You are free to use this software, with or without modification, provided that the conditions listed in the LICENSE file are satisfied.
