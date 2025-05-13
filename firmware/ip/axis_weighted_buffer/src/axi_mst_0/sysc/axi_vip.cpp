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

#include "axi_vip.h"
#include <sstream>

axi_vip::axi_vip(sc_core::sc_module_name module_name,
		xsc::common_cpp::properties model_param_props) :
		sc_module(module_name), S_TARGET_rd_socket(nullptr), S_TARGET_wr_socket(
				nullptr), M_INITIATOR_rd_socket(nullptr), M_INITIATOR_wr_socket(
				nullptr), P1(nullptr), P2(nullptr), m_ipc_master(nullptr), m_ipc_slave(
				nullptr)
{
	int int_type = model_param_props.getLongLong("C_AXI_INTERFACE_MODE");
	if (int_type == 1)
	{
		M_INITIATOR_rd_socket = new xtlm::xtlm_aximm_initiator_socket(
				"initiator_rd_socket", 32);
		M_INITIATOR_wr_socket = new xtlm::xtlm_aximm_initiator_socket(
				"initiator_wr_socket", 32);
		S_TARGET_rd_socket = new xtlm::xtlm_aximm_target_socket(
				"target_rd_socket", 32);
		S_TARGET_wr_socket = new xtlm::xtlm_aximm_target_socket(
				"target_wr_socket", 32);
		P1 = new xtlm::xtlm_aximm_passthru_module("P1");
		P2 = new xtlm::xtlm_aximm_passthru_module("P2");
		P1->initiator_socket->bind(*M_INITIATOR_rd_socket);
		P2->initiator_socket->bind(*M_INITIATOR_wr_socket);
		S_TARGET_rd_socket->bind(*(P1->target_socket));
		S_TARGET_wr_socket->bind(*(P2->target_socket));
	}
	if (int_type == 0)
	{
		if (std::getenv("ENABLE_XTLM_IPC_IN_VIP") == nullptr)
		{
			M_INITIATOR_rd_socket = new xtlm::xtlm_aximm_initiator_socket(
					"initiator_rd_socket", 32);
			M_INITIATOR_wr_socket = new xtlm::xtlm_aximm_initiator_socket(
					"initiator_wr_socket", 32);
			auto *stubWr = new xtlm::xtlm_aximm_initiator_stub("ifWrStubskt0",
					32);
			stubWr->initiator_socket->bind(*M_INITIATOR_wr_socket);
			auto *stubRd = new xtlm::xtlm_aximm_initiator_stub("ifRdStubskt0",
					32);
			stubRd->initiator_socket->bind(*M_INITIATOR_rd_socket);
			stubInitSkt.push_back(stubWr);
			stubInitSkt.push_back(stubRd);
		}
		else
		{
			m_ipc_master = new sim_ipc_aximm_master(this->name(),
					model_param_props);
			M_INITIATOR_rd_socket = m_ipc_master->rd_socket;
			M_INITIATOR_wr_socket = m_ipc_master->wr_socket;
			m_ipc_master->m_aximm_aclk(aclk);
			m_ipc_master->m_aximm_aresetn(aresetn);
		}
	}
	if (int_type == 2)
	{
		if (std::getenv("ENABLE_XTLM_IPC_IN_VIP") == nullptr)
		{
			S_TARGET_rd_socket = new xtlm::xtlm_aximm_target_socket(
					"target_rd_socket", 32);
			S_TARGET_wr_socket = new xtlm::xtlm_aximm_target_socket(
					"target_wr_socket", 32);
			auto *stubWr = new xtlm::xtlm_aximm_target_stub("ifWrStubskt0", 32);
			S_TARGET_wr_socket->bind(stubWr->target_socket);
			auto *stubRd = new xtlm::xtlm_aximm_target_stub("ifRdStubskt0", 32);
			S_TARGET_rd_socket->bind(stubRd->target_socket);
			stubTargetSkt.push_back(stubWr);
			stubTargetSkt.push_back(stubRd);
		}
		else
		{
			m_ipc_slave = new sim_ipc_aximm_slave(this->name(),
					model_param_props);
			S_TARGET_rd_socket = m_ipc_slave->rd_socket;
			S_TARGET_wr_socket = m_ipc_slave->wr_socket;
			m_ipc_slave->s_aximm_aclk(aclk);
			m_ipc_slave->s_aximm_aresetn(aresetn);
		}
	}
}
axi_vip::~axi_vip()
{
	delete M_INITIATOR_wr_socket;
	delete M_INITIATOR_rd_socket;
	delete S_TARGET_wr_socket;
	delete S_TARGET_rd_socket;
	delete P1;
	delete P2;
	delete m_ipc_master;
	delete m_ipc_slave;
}
