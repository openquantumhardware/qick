.. _pyro4:

Pyro4: Multi-Board Connection and Distributed Control
======================================================

Pyro4 (Python Remote Objects) enables communication between multiple QICK boards over a network. This is essential for:

- Running synchronized experiments across multiple RFSoC boards
- Distributing control and readout tasks
- Building scalable quantum control systems

.. note::
   Pyro4 is different from XCOM. Pyro4 operates at the software/network level (Ethernet), while XCOM is a hardware-level low-latency solution using LVDS signals. Use Pyro4 for flexibility and ease of use; use XCOM for sub-100 ps synchronization and deterministic latency below 200 ns.

Architecture
------------

The Pyro4 setup consists of three components:

1. **Name Server**: A central registry that keeps track of all available QICK boards
2. **Server**: Runs on each QICK board, exposing its functionality via Pyro
3. **Client**: Your control PC or Jupyter notebook that connects to the name server and calls methods on remote boards

::

   ┌─────────────────────────────────────────────────────────────────────────────┐
   │                         Pyro4 Architecture                                  │
   ├─────────────────────────────────────────────────────────────────────────────┤
   │                                                                             │
   │   ┌──────────┐        ┌──────────┐        ┌──────────┐                      │
   │   │ QICK #1  │        │ QICK #2  │        │  Client  │                      │
   │   │ (Server) │        │ (Server) │        │ (Python) │                      │
   │   └────┬─────┘        └────┬─────┘        └────┬─────┘                      │
   │        │                   │                   │                            │
   │        └───────────────────┼───────────────────┘                            │
   │                            │                                                │
   │                     ┌──────▼──────┐                                         │
   │                     │ Name Server │                                         │
   │                     │  (Pyro NS)  │                                         │
   │                     └─────────────┘                                         │
   │                                                                             │
   └─────────────────────────────────────────────────────────────────────────────┘

Setup Instructions
------------------

Install Pyro4 on all boards and the client machine:

.. code-block:: bash

   pip install Pyro4

Start the name server on a machine accessible by all boards (e.g., your control PC):

.. code-block:: bash

   python -m Pyro4.naming -n 0.0.0.0 -p 8888

Alternatively, use the script from the QICK repository:

.. code-block:: bash

   wget https://raw.githubusercontent.com/openquantumhardware/qick/main/pyro4/nameserver.sh
   chmod +x nameserver.sh
   ./nameserver.sh

On each QICK board, start the Pyro server:

.. code-block:: python

   from qick.pyro import start_server

   start_server(
       ns_host="your_nameserver_host",  # IP of the machine running the name server
       ns_port=8888,
       proxy_name="qick1",              # Unique name for this board
       external_clk=True,               # Optional: use external reference clock
       adc_sample_rates={0:3072.0}      # Optional: set ADC sample rates
   )

For production deployments, use the systemd service files from the QICK repository:

.. code-block:: bash

   wget https://raw.githubusercontent.com/openquantumhardware/qick/main/pyro4/qick_pyro.service
   wget https://raw.githubusercontent.com/openquantumhardware/qick/main/pyro4/pyro_service.py

   sudo cp qick_pyro.service /etc/systemd/system/
   sudo systemctl enable qick_pyro
   sudo systemctl start qick_pyro

Client Usage
------------

In your Jupyter notebook or Python script, connect to the name server and create proxies to each board:

.. code-block:: python

   from qick.pyro import make_proxy

   # Connect to boards
   proxies = []
   for name in ['qick1', 'qick2', 'qick3']:
       proxies.append(make_proxy(ns_host="your_nameserver_host", ns_port=8888, proxy_name=name))

   # Each proxy behaves like a local QickSoc object
   for soc, soccfg in proxies:
       print(soccfg)
       soc.reset_gens()
       soc.reset_adcs()

Example: Multi-Board Synchronized Acquisition
---------------------------------------------

For a complete example, refer to the Jupyter notebooks in the `pyro4` directory of the QICK repository:
`02_client.ipynb <https://github.com/openquantumhardware/qick/blob/main/pyro4/02_client.ipynb>`_.

.. code-block:: python

   import asyncio
   from qick.pyro import make_proxy
   from qick.asm_v2 import AveragerProgramV2

   # Connect to boards
   proxies = [make_proxy(ns_host="localhost", ns_port=8888, proxy_name=f"qick{i}") for i in range(1, 3)]

   # Define a simple program
   class SyncProgram(AveragerProgramV2):
       def _initialize(self, cfg):
           self.declare_gen(ch=cfg['gen_ch'], nqz=1)
           self.declare_readout(ch=cfg['ro_ch'], length=cfg['ro_len'])
           self.add_pulse(ch=cfg['gen_ch'], name="pulse",
                          style="const", freq=cfg['freq'],
                          length=cfg['pulse_len'], gain=cfg['gain'])

       def _body(self, cfg):
           self.pulse(ch=cfg['gen_ch'], name="pulse", t=0)
           self.trigger(ros=[cfg['ro_ch']], t=cfg['trig_time'])

   # Run on each board
   results = []
   for soc, soccfg in proxies:
       prog = SyncProgram(soccfg, cfg=config)
       results.append(prog.acquire(soc))

   # Process results
   for i, iq in enumerate(results):
       print(f"Board {i+1} data shape: {iq.shape}")

Asynchronous Multi-Board Execution
----------------------------------

For synchronous execution across multiple boards, use the `run_multi_decimated` helper function (see the :doc:`/tutorials/10_Multi_Board_Synchronization` notebook for details).

Files Reference
---------------

All Pyro4 files are available in the QICK repository:

- `00_nameserver.ipynb <https://github.com/openquantumhardware/qick/blob/main/pyro4/00_nameserver.ipynb>`_ - Tutorial for starting and verifying the name server
- `01_server.ipynb <https://github.com/openquantumhardware/qick/blob/main/pyro4/01_server.ipynb>`_ - Tutorial for starting Pyro servers on QICK boards
- `02_client.ipynb <https://github.com/openquantumhardware/qick/blob/main/pyro4/02_client.ipynb>`_ - Tutorial for connecting clients to multiple boards
- `nameserver.sh <https://github.com/openquantumhardware/qick/blob/main/pyro4/nameserver.sh>`_ - Shell script to start the name server
- `pyro_service.py <https://github.com/openquantumhardware/qick/blob/main/pyro4/pyro_service.py>`_ - Python module for Pyro service management
- `qick_pyro.service <https://github.com/openquantumhardware/qick/blob/main/pyro4/qick_pyro.service>`_ - systemd service file for auto-starting Pyro on boot

See Also
--------

- :doc:`xcom` - Hardware-level low-latency multi-board synchronization
- :doc:`/tutorials/10_Multi_Board_Synchronization` - Software synchronization with external clock and start signals
- `Pyro4 Documentation <https://pyro4.readthedocs.io/>`_
- `QICK pyro4 directory on GitHub <https://github.com/openquantumhardware/qick/tree/main/pyro4>`_
