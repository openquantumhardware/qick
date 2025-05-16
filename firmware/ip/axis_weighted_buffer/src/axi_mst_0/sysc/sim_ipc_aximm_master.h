// (c) Copyright 1995-2021 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.

#pragma once

#include "xtlm.h"
#include "ipc2aximm_socket.h"
#include <systemc>

class sim_ipc_aximm_master : public sc_core::sc_module
{
public:
	SC_HAS_PROCESS(sim_ipc_aximm_master);

	sim_ipc_aximm_master(sc_core::sc_module_name name,
			xsc::common_cpp::properties &ppts);

	~sim_ipc_aximm_master();

	sc_core::sc_in<bool> m_aximm_aresetn;
	sc_core::sc_in<bool> m_aximm_aclk;

	//Read & Write Sockets
	xtlm::xtlm_aximm_initiator_socket* rd_socket;
	xtlm::xtlm_aximm_initiator_socket* wr_socket;

	xtlm::xtlm_aximm_initiator_rd_socket_util rd_util;
	xtlm::xtlm_aximm_initiator_wr_socket_util wr_util;
private:
	//! SystemC Method to Read incoming data from ipc...
	void ipc2aximm_receive();
	void send_response();
	std::string get_ipi_name(std::string s);

	xsc::ipc2aximm_socket* m_ipc2aximm_socket;
	xsc::common_cpp::report_handler m_logger;
};
