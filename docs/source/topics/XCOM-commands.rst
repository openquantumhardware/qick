.. _xcom-commands:

XCOM Commands Reference
=======================

This document provides a complete reference for all XCOM commands. Commands are sent either:

- **Over the network (NET)**: To other boards (OP code MSB = 0)
- **Locally (LOC)**: To the local XCOM instance (OP code MSB = 1)

NET Command Message Format
--------------------------

NET messages have a header followed by data:

.. list-table:: NET Message Structure
   :header-rows: 1
   :widths: 30 30 40

   * - Field
     - Bits
     - Description
   * - OP
     - HEADER[7:4]
     - Operation code (4 bits)
   * - ADDR
     - HEADER[3:0]
     - Destination board address
   * - DATA
     - Variable
     - Payload (8, 16, or 32 bits)

If ``ADDR = 0``, the command is broadcast to all boards in the network.

LOC Command Message Format
--------------------------

LOC commands are written directly to the ``XCOM_CTRL`` register:

- ``OP_I`` (``ctrl[5:1]``) contains the command
- ``EN`` (``ctrl[0]``) triggers execution (auto-resets after one cycle)

NET Commands
------------

XCOM_CLEAR_FLAG
~~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_CLEAR_FLAG
     - 0
     - 00000
     - ADDR
     - —

**Description**: 
This is a NET command. Clear the `qp_flag` pin in the external peripheral interface of the QICK processor. This signal can be used to inform the QICK processor some state in the execution of a program between boards. The DT1 register contains the address of the board where to execute the command.

If ADDR = 0 that means it is a broadcast message and all the boards in the network will execute this command.

---

XCOM_SET_FLAG
~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_SET_FLAG
     - 1
     - 00001
     - ADDR
     - —

**Description**: 
 This is a NET command. Set the `qp_flag` pin in the external peripheral interface of the QICK processor. This signal can be used to 
 inform the QICK processor some state in the execution of a program between boards. 
 The DT1 register contains the address of the board where to execute the command.

If ADDR = 0 that means it is a broadcast message and all the boards in the network will execute this command.

Sets the ``qp_flag`` pin on the specified remote board.

---

XCOM_SEND_8BIT
~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_SEND_8BIT_1
     - 2
     - 00010
     - ADDR
     - DATA[7:0]
   * - XCOM_SEND_8BIT_2
     - 3
     - 00011
     - ADDR
     - DATA[7:0]

**Description**: 
These are NET commands. Sends a byte of data to the board with address ADDR. DT1 
register selects where to write the data in DT2 register.

* With `XCOM_SEND_8BIT_1` the data contained in DT2 is written into the `qp_dt1` 
  and into the `o_time_update_data` outputs. This command writes to the registers 
  in the CORE processor of the receiving (ADDR) board.

* With `XCOM_SEND_8BIT_2` the data contained in DT2 is written into the 16x32 
  memory of the receiving (ADDR) board.

If ADDR = 0 that means it is a broadcast message and all the boards in the 
network will execute this command.

---

XCOM_SEND_16BIT
~~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_SEND_16BIT_1
     - 4
     - 00100
     - ADDR
     - DATA[15:0]
   * - XCOM_SEND_16BIT_2
     - 5
     - 00101
     - ADDR
     - DATA[15:0]

**Description**: 
These are NET commands. Sends 16-bit data to the board with address ADDR. DT1 
register selects where to write the data in DT2 register.

* With `XCOM_SEND_16BIT_1` the data contained in DT2 is written into the `qp_dt1` 
  and into the `o_time_update_data` outputs. This command writes to the registers 
  in the CORE processor of the receiving (ADDR) board.

* With `XCOM_SEND_16BIT_2` the data contained in DT2 is written into the 16x32 
  memory of the receiving (ADDR) board.

If ADDR = 0 that means it is a broadcast message and all the boards in the 
network will execute this command.

---

XCOM_SEND_32BIT
~~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_SEND_32BIT_1
     - 6
     - 00110
     - ADDR
     - DATA[31:0]
   * - XCOM_SEND_32BIT_2
     - 7
     - 00111
     - ADDR
     - DATA[31:0]

**Description**: 
These are NET commands. Sends 32-bit data to the board with address ADDR. DT1 
register selects where to write the data in DT2 register.

* With `XCOM_SEND_32BIT_1` the data contained in DT2 is written into the `qp_dt1` 
  and into the `o_time_update_data` outputs. This command writes to the registers 
  in the CORE processor of the receiving (ADDR) board.

* With `XCOM_SEND_32BIT_2` the data contained in DT2 is written into the 16x32 
  memory of the receiving (ADDR) board.

If ADDR = 0 that means it is a broadcast message and all the boards in the 
network will execute this command.

---

XCOM_QRST_SYNC
~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_QRST_SYNC
     - 8
     - 01000
     - ADDR
     - —

**Description**: 
This is a NET command. DT1 register selects the address of the board to which 
the local board wants to synchronize to. The transmitter board waits for the 
next rising edge in the PPS signal (synchronization signal) to send the 
command and at the same time it will wait for the next rising edge of the 
PPS signal to set the local `o_proc_start` signal. The receiving board, 
once receive the `XCOM_QRST_SYNC` command will wait for the next rising 
edge in the PPS signal and then will set the `o_proc_start` signal to 
let the QICK processor start with its operations. The `o_proc_start` signal 
will remain settled for 8 `t_clk` clock cycles and then goes to zero again. 
In that way, all the connected boards will start its QICK processor 
operations at the same time, that means 2 PPS after the `XCOM_QRST_SYNC` 
command was issued by the initial (master/main) board.

If ADDR = 0 that means it is a broadcast message and all the boards in 
the network will execute this command.

---

XCOM_AUTO_ID
~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_AUTO_ID
     - 9
     - 01001
     - —
     - —

**Description**: 
This is a NET command. The board receiving this command will auto 
assign itself a board ID calculated as the ID of the transmitter 
board plus one, so RX ID = TX ID + 1.

---

XCOM_UPDATE_DT8 / 16 / 32
~~~~~~~~~~~~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_UPDATE_DT8
     - 10
     - 01010
     - ADDR
     - DATA
   * - XCOM_UPDATE_DT16
     - 12
     - 01100
     - ADDR
     - DATA
   * - XCOM_UPDATE_DT32
     - 14
     - 01110
     - ADDR
     - DATA

**Description**: 
This is a NET command and for now they are just placeholders for future 
implementations. Not specific task assigned yet.

---

XCOM_QCTRL
~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_QCTRL
     - 11
     - 01011
     - ADDR
     - CONTROL[31:0]

**Description**: 
This is a NET command. DT1 register selects the board where to write the data 
in DT2 register. This command is related to the control of the QICK processor, 
see details in :doc:`xcom`.

It depends on what DT2[2:0] contains to select what to do in the receiving board:

* DT2[2:0] = 0, N/A.
* DT2[2:0] = 1, N/A.
* DT2[2:0] = 2 or 10, the `o_time_rst` signal is set for 8 `t_clk` clock cycles and then goes to zero again.
* DT2[2:0] = 3 or 11, the `o_time_update` signal is set for 8 `t_clk` clock cycles and then goes to zero again.
* DT2[2:0] = 4 or 12, the `o_core_start` signal is set for 8 `t_clk` clock cycles and then goes to zero again.
* DT2[2:0] = 5 or 13, the `o_core_stop` signal is set for 8 `t_clk` clock cycles and then goes to zero again.
* DT2[2:0] = 6 or 14, the `o_proc_start` signal is set for 8 `t_clk` clock cycles and then goes to zero again.
* DT2[2:0] = 7 or 15, the `o_proc_stop` signal is set for 8 `t_clk` clock cycles and then goes to zero again.

.. list-table:: Control Encoding
   :header-rows: 1

   * - DT2[2:0]
     - Operation
     - Description
   * - 2 / 10
     - Time reset
     - Reset time counter
   * - 3 / 11
     - Time update
     - Update time
   * - 4 / 12
     - Core start
     - Start core
   * - 5 / 13
     - Core stop
     - Stop core
   * - 6 / 14
     - Proc start
     - Start processor
   * - 7 / 15
     - Proc stop
     - Stop processor

---

XCOM_RFU
~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_RFU_1
     - 13
     - 01101
     - —
     - —
   * - XCOM_RFU_2
     - 15
     - 01111
     - —
     - —

**Description**: 
 This are NET commands and for now they are just placeholders for future 
 implementations. Not specific task assigned yet.

---

LOC Commands
------------

XCOM_SET_ID
~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_SET_ID
     - 16
     - 10000
     - ID
     - —

**Description**: 
This is a LOC command. Set the ID of the board locally. The DT1 register 
contains the desired ID. The ID must be a number between 1 and 15.

---

XCOM_WRITE_FLAG
~~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_WRITE_FLAG
     - 17
     - 10001
     - FLAG
     - —

**Description**: 
This is a LOC command. Set the `qp_flag` pin in the external peripheral interface
of the QICK processor. This signal can be used to inform the QICK processor some
state in the execution of a program between boards. The DT1[0] bit is used to
set (1) or unset (0) this flag.

---

XCOM_WRITE_REG
~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_WRITE_REG
     - 18
     - 10010
     - SEL
     - DATA[31:0]

**Description**: 
This is a LOC command. DT1 register selects where to write the data in DT2
register. If DT1[0] = 0, the data contained in DT2 is written into the `qp_dt1`
output. If DT1[0] = 1 the data contained in DT2 is written into the `qp_dt2`
output. This command writes to the registers in the CORE processor. When DT1[0]
= 0 this command also writes the data in DT2 register into the
`o_time_update_data` output.

---

XCOM_WRITE_MEM
~~~~~~~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_WRITE_MEM
     - 19
     - 10011
     - ADDR
     - DATA[31:0]

**Description**: 
This is a LOC command. DT1 register selects the address where to write the data
in DT2 register. Address range is 0 - 15. This command writes to the internal
16x32 memory.

---

XCOM_RST
~~~~~~~~

.. list-table:: Command Format
   :header-rows: 1

   * - Command
     - Code
     - OP
     - DT1
     - DT2
   * - XCOM_RST
     - 31
     - 11111
     - —
     - —

**Description**: 
This is a LOC command. It reset all the internal registers in the local `xcom`
instance.

---

Python API Example
------------------

.. code-block:: python

   from qick.pyro import make_proxy

   # Connect to board
   soc = make_proxy("board_ip_address")

   # Reset XCOM
   soc.xcom_0.run_cmd(soc.xcom_0.opcodes['XCOM_RST'], 0, 0)

   # Auto-assign IDs
   soc.xcom_0.run_cmd(soc.xcom_0.opcodes['XCOM_AUTO_ID'], 0, 0)

   # Set local ID to 2
   soc.xcom_0.set_local_id(2)

   # Send 32-bit data to board 5
   soc.xcom_0.send_word(0xDEADBEEF, dst=5, reg=2)

   # Read status
   soc.xcom_0.print_status()
   
See Also
--------

* :doc:`xcom` — XCOM overview and architecture

* `XCOM Network Synchronization <../tutorials/14_XCOM_Network_Synchronization.ipynb>`_ — XCOM demonstration notebook

* `XCOM paper (arXiv:2603.18977v1) <https://arxiv.org/abs/2603.18977v1>`_
