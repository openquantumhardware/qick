--------------------------------------------------------------------------------
-- Create Date:		2/4/2019
-- Designer:		Maxwell S.
-- Module Name:		vt_gt_clk - behavioral
-- Target Device:	Xilinx 7-series or later
-- Description:		Bring GT clock and optionally output to a global buffer 
-- Dependencies:	none
-- Copyright:		2019 VadaTech Incorporated, All Rights Reserved
--------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.VComponents.all;

entity vt_gt_clk is
generic (
	FPGA_TRANSCEIVER	: string 		:= "GTHE2";
	ENABLE_BUFG		: boolean 		:= false;
	BUFG_DIV2		: boolean 		:= false
);
port (
	gt_refclk_disable	: in	std_logic;
	gt_refclk_p		: in	std_logic; 
	gt_refclk_n		: in	std_logic; 
	gt_clk_o		: out	std_logic;		-- for GTREFCLK
	gt_clk_bufg		: out	std_logic	:= '0'	-- for Fabric
);
end vt_gt_clk;

architecture behavioural of vt_gt_clk is
	signal gt_clk_odiv2	: std_logic;
	signal gt_clk_o_i	: std_logic;
	
begin
	gen_gte2: if FPGA_TRANSCEIVER = "GTHE2" or FPGA_TRANSCEIVER = "GTXE2" generate
		IBUFDS_inst_gte2 : IBUFDS_GTE2
		port map (
			O				=> gt_clk_o_i,
			ODIV2			=> gt_clk_odiv2,	-- Fixed div2. either O or ODIV2 can be used for fabric
			CEB				=> gt_refclk_disable,
			I				=> gt_refclk_p,
			IB				=> gt_refclk_n
		);
		
		gt_clk_o	<= gt_clk_o_i;
		
		gen_bufg: if ENABLE_BUFG and not BUFG_DIV2 generate
			BUFG_inst_gte2 : BUFG
			port map (
				I			=> gt_clk_o_i,
				O			=> gt_clk_bufg
			);	
		end generate;
		
		gen_bufg_div2: if ENABLE_BUFG and BUFG_DIV2 generate
			BUFG_inst_gte2 : BUFG
			port map (
				I			=> gt_clk_odiv2,
				O			=> gt_clk_bufg
			);	
		end generate;		
	end generate;

	gen_gte3: if FPGA_TRANSCEIVER = "GTHE3" or FPGA_TRANSCEIVER = "GTYE3" generate
		gen_ibufds_gt: if not BUFG_DIV2 generate
			IBUFDS_inst_gte3 : IBUFDS_GTE3
			generic map (
				REFCLK_HROW_CK_SEL 		=> "00"	-- 00: ODIV2=O; 01: ODIV2=O/2; 10: ODIV2=0; 11: reserved
			)
			port map (
				O				=> gt_clk_o,
				ODIV2				=> gt_clk_odiv2,
				CEB				=> gt_refclk_disable,
				I				=> gt_refclk_p,
				IB				=> gt_refclk_n
			);
		end generate;
		
		gen_ibufds_gt_div2: if BUFG_DIV2 generate
			IBUFDS_inst_gte3 : IBUFDS_GTE3
			generic map (
				REFCLK_HROW_CK_SEL 		=> "01"	-- 00: ODIV2=O; 01: ODIV2=O/2; 10: ODIV2=0; 11: reserved
			)
			port map (
				O				=> gt_clk_o,
				ODIV2				=> gt_clk_odiv2,
				CEB				=> gt_refclk_disable,
				I				=> gt_refclk_p,
				IB				=> gt_refclk_n
			);
		end generate;
		
		gen_bufg_gt: if ENABLE_BUFG generate
			BUFG_GT_inst_gte3 : BUFG_GT
			port map (
				CE				=> '1',
				CEMASK				=> '1',
				CLR				=> '0',
				CLRMASK				=> '1',
				DIV				=> "000",
				I				=> gt_clk_odiv2,
				O				=> gt_clk_bufg
			);	
		end generate;
	end generate;

	gen_gte4: if FPGA_TRANSCEIVER = "GTHE4" or FPGA_TRANSCEIVER = "GTYE4" generate
		gen_ibufds_gt: if not BUFG_DIV2 generate
			IBUFDS_inst_gte4 : IBUFDS_GTE4
			generic map (
				REFCLK_HROW_CK_SEL 		=> "00"	-- 00: ODIV2=O; 01: ODIV2=O/2; 10: ODIV2=0; 11: reserved
			)
			port map (
				O				=> gt_clk_o,
				ODIV2			=> gt_clk_odiv2,
				CEB				=> gt_refclk_disable,
				I				=> gt_refclk_p,
				IB				=> gt_refclk_n
			);
		end generate;
		
		gen_ibufds_gt_div2: if BUFG_DIV2 generate
			IBUFDS_inst_gte4 : IBUFDS_GTE4
			generic map (
				REFCLK_HROW_CK_SEL 		=> "01"	-- 00: ODIV2=O; 01: ODIV2=O/2; 10: ODIV2=0; 11: reserved
			)
			port map (
				O				=> gt_clk_o,
				ODIV2			=> gt_clk_odiv2,
				CEB				=> gt_refclk_disable,
				I				=> gt_refclk_p,
				IB				=> gt_refclk_n
			);
		end generate;
		
		gen_bufg_gt: if ENABLE_BUFG generate
			BUFG_GT_inst_gte4 : BUFG_GT
			port map (
				CE				=> '1',
				CEMASK			=> '1',
				CLR				=> '0',
				CLRMASK			=> '1',
				DIV				=> "000",
				I				=> gt_clk_odiv2,
				O				=> gt_clk_bufg
			);	
		end generate;
	end generate;
		
end behavioural;