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

#include "sim_ipc_aximm_master.h"
using namespace xtlm;

sim_ipc_aximm_master::sim_ipc_aximm_master(sc_core::sc_module_name name,
		xsc::common_cpp::properties &ppts):sc_module(name),
		rd_util(sc_gen_unique_name("rd_util"),xtlm::aximm::TRANSACTION,0),
		wr_util(sc_gen_unique_name("wr_util"),xtlm::aximm::TRANSACTION,0),
		m_logger((std::string) name)
{
	rd_socket = new  xtlm::xtlm_aximm_initiator_socket(
			sc_gen_unique_name("rd_socket"), 0);
	wr_socket = new xtlm::xtlm_aximm_initiator_socket(
			sc_gen_unique_name("wr_socket"), 0);

	//TODO Supporting outstanding transactions
	rd_util.rd_socket.bind(*rd_socket);
	wr_util.wr_socket.bind(*wr_socket);

	m_ipc2aximm_socket = new xsc::ipc2aximm_socket(
			sc_gen_unique_name("ipc2aximm_socket"), get_ipi_name(this->name()));

	SC_METHOD(ipc2aximm_receive);
	sensitive << m_ipc2aximm_socket->event();
	sensitive << wr_util.resp_available;
	sensitive << rd_util.data_available;
	//As of now only 1 outstanding transaction is supported.
	//If we support more, this may need to be updated.
	dont_initialize();

	SC_METHOD(send_response);
	sensitive << wr_util.resp_available;
	sensitive << rd_util.data_available;
	dont_initialize();
}

sim_ipc_aximm_master::~sim_ipc_aximm_master()
{
	delete m_ipc2aximm_socket;
	delete rd_socket;
	delete wr_socket;
}

void sim_ipc_aximm_master::ipc2aximm_receive()
{
	if(!m_ipc2aximm_socket->peek_payload())
		return;

	if (wr_util.is_slave_ready() &&
		(m_ipc2aximm_socket->peek_payload()->get_command()
					== xtlm::XTLM_WRITE_COMMAND))
	{
		auto delay = sc_core::sc_time(SC_ZERO_TIME);
		XSC_REPORT_INFO_VERB(m_logger, "IPC_AXIMM_MASTER",
				"Sending Write Request", DEBUG);
		//We Can do transaction on Write Channel
		wr_util.send_transaction(*m_ipc2aximm_socket->get_payload(), delay);

	}

	//Don't proceed further if there's no transaction
	if (!m_ipc2aximm_socket->peek_payload())
		return;

	if (rd_util.is_slave_ready()
			&& (m_ipc2aximm_socket->peek_payload()->get_command()
					== xtlm::XTLM_READ_COMMAND))
	{
		auto delay = sc_core::sc_time(SC_ZERO_TIME);
		XSC_REPORT_INFO_VERB(m_logger, "IPC_AXIMM_MASTER",
				"Sending Read Request", DEBUG);
		rd_util.send_transaction(*m_ipc2aximm_socket->get_payload(), delay);
	}
}

void sim_ipc_aximm_master::send_response()
{
	if(wr_util.is_resp_available())
	{
		XSC_REPORT_INFO_VERB(m_logger, "IPC_AXIMM_MASTER",
				"Sending Write Response", DEBUG);
		m_ipc2aximm_socket->send_response(wr_util.get_resp());
	}
	if(rd_util.is_data_available())
	{
		XSC_REPORT_INFO_VERB(m_logger, "IPC_AXIMM_MASTER",
				"Sending Read Response", DEBUG);
		m_ipc2aximm_socket->send_response(rd_util.get_data());
	}
}

std::string sim_ipc_aximm_master::get_ipi_name(std::string s)
{
    s = s.substr(0, s.find_last_of("./")); // Adding "/" to support QUESTA
    s = s.substr(s.find_last_of("./") + 1);
    return s;
}
