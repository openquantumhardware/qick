----------------------------------------------------------------------------------
-- Company:		VadaTech Incorporated
-- Engineer:		Maxwell
-- Copyright:		Copyright 2015 VadaTech Incorporated. All Rights Reserved.
--
-- Create Date:		04/28/2015
-- Design Name:
-- Module Name:		axi_gpio_32 - Behavioral
-- Project Name:	
-- Target Devices:
-- Tool Versions:
-- Description:		This module implements 32 gpio registers and 
--			version/signature and reg_scratch registers
--
-- Dependencies:	None
-- Revision History
-- 12/02/2015		Added wstrb support
-- 04/28/2015		Initial
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_gpio_32 is
generic (
	GPIO_INIT_0			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_1			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_2			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_3			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_4			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_5			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_6			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_7			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_8			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_9			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_10			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_11			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_12			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_13			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_14			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_15			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_16			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_17			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_18			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_19			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_20			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_21			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_22			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_23			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_24			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_25			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_26			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_27			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_28			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_29			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_30			: std_logic_vector(31 downto 0)	:= x"00000000";
	GPIO_INIT_31			: std_logic_vector(31 downto 0)	:= x"00000000";
	-- Do not change
	C_S_AXI_ADDR_WIDTH		: integer			:= 12
);
port (
	-- Ports of AXI4-Lite interface
	s_axi_aclk			: in 	std_logic;
	s_axi_aresetn			: in 	std_logic;
	s_axi_awaddr			: in 	std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_awvalid			: in 	std_logic;
	s_axi_awready			: out 	std_logic;
	s_axi_wdata			: in 	std_logic_vector(31 downto 0);
	s_axi_wstrb			: in 	std_logic_vector(3 downto 0);
	s_axi_wvalid			: in 	std_logic;
	s_axi_wready			: out 	std_logic;
	s_axi_bresp			: out 	std_logic_vector (1 downto 0);
	s_axi_bvalid			: out 	std_logic;
	s_axi_bready			: in 	std_logic;
	s_axi_araddr			: in 	std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_arvalid			: in 	std_logic;
	s_axi_arready			: out 	std_logic;
	s_axi_rdata			: out 	std_logic_vector (31 downto 0);
	s_axi_rresp			: out 	std_logic_vector (1 downto 0);
	s_axi_rvalid			: out 	std_logic;
	s_axi_rready			: in 	std_logic;

	-- IO
	gpio_out_0			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_0;
	gpio_out_1			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_1;
	gpio_out_2			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_2;
	gpio_out_3			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_3;
	gpio_out_4			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_4;
	gpio_out_5			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_5;
	gpio_out_6			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_6;
	gpio_out_7			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_7;
	gpio_out_8			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_8;
	gpio_out_9			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_9;
	gpio_out_10			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_10;
	gpio_out_11			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_11;
	gpio_out_12			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_12;
	gpio_out_13			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_13;
	gpio_out_14			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_14;
	gpio_out_15			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_15;
	gpio_out_16			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_16;
	gpio_out_17			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_17;
	gpio_out_18			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_18;
	gpio_out_19			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_19;
	gpio_out_20			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_20;
	gpio_out_21			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_21;
	gpio_out_22			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_22;
	gpio_out_23			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_23;
	gpio_out_24			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_24;
	gpio_out_25			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_25;
	gpio_out_26			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_26;
	gpio_out_27			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_27;
	gpio_out_28			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_28;
	gpio_out_29			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_29;
	gpio_out_30			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_30;
	gpio_out_31			: out	std_logic_vector(31 downto 0)	:= GPIO_INIT_31;
	
	gpio_out_en			: out	std_logic_vector(31 downto 0)	:= x"00000000";
	
	gpio_in_0			: in	std_logic_vector(31 downto 0)	:= x"00000000"; 
	gpio_in_1			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_2			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_3			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_4			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_5			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_6			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_7			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_8			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_9			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_10			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_11			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_12			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_13			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_14			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_15			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_16			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_17			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_18			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_19			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_20			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_21			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_22			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_23			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_24			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_25			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_26			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_27			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_28			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_29			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_30			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	gpio_in_31			: in	std_logic_vector(31 downto 0)	:= x"00000000";
	
	major_version			: in    std_logic_vector(7 downto 0);
	minor_version			: in    std_logic_vector(7 downto 0);
	patch_version			: in    std_logic_vector(7 downto 0);
	rev_version			: in    std_logic_vector(7 downto 0);
	signature			: in    std_logic_vector(15 downto 0);
	image_id 			: in    std_logic_vector(15 downto 0);
	
	program_n			: out	std_logic	:= '1';
	scratch				: out 	std_logic_vector(31 downto 0)
);
end axi_gpio_32;

architecture Behavioral of axi_gpio_32 is
	constant GPIO_0_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"00" & "00";
	constant GPIO_1_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"00" & "01";
	constant GPIO_2_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"00" & "10";
	constant GPIO_3_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"00" & "11";
	constant GPIO_4_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"01" & "00";
	constant GPIO_5_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"01" & "01";
	constant GPIO_6_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"01" & "10";
	constant GPIO_7_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"01" & "11";
	constant GPIO_8_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"02" & "00";
	constant GPIO_9_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"02" & "01";
	constant GPIO_10_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"02" & "10";
	constant GPIO_11_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"02" & "11";
	constant GPIO_12_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"03" & "00";
	constant GPIO_13_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"03" & "01";
	constant GPIO_14_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"03" & "10";
	constant GPIO_15_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"03" & "11";
	constant GPIO_16_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"04" & "00";
	constant GPIO_17_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"04" & "01";
	constant GPIO_18_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"04" & "10";
	constant GPIO_19_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"04" & "11";
	constant GPIO_20_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"05" & "00";
	constant GPIO_21_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"05" & "01";
	constant GPIO_22_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"05" & "10";
	constant GPIO_23_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"05" & "11";
	constant GPIO_24_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"06" & "00";
	constant GPIO_25_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"06" & "01";
	constant GPIO_26_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"06" & "10";
	constant GPIO_27_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"06" & "11";
	constant GPIO_28_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"07" & "00";
	constant GPIO_29_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"07" & "01";
	constant GPIO_30_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"07" & "10";
	constant GPIO_31_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"07" & "11";
	
	constant PROGRAM_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"FF" & "00";
	constant SCRATCH_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"FF" & "01";
	constant VER_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"FF" & "10";
	constant SIG_ADDR			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2) := x"FF" & "11";


	-- AXI4LITE signals
	signal axi_awaddr			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_araddr			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

	signal axi_awready			: std_logic;
	signal axi_wready			: std_logic;
	signal axi_bresp			: std_logic_vector(1 downto 0);
	signal axi_bvalid			: std_logic;
	signal axi_arready			: std_logic;
	signal axi_rdata			: std_logic_vector(31 downto 0);
	signal axi_rresp			: std_logic_vector(1 downto 0);
	signal axi_rvalid			: std_logic;

	-- AXI4LITE help signals
	signal slv_reg_wren			: std_logic;
	signal slv_reg_rden			: std_logic;
	signal reg_data_out			: std_logic_vector(31 downto 0);
	signal araddr				: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2);
	signal awaddr				: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2);

	-- registers
	signal reg_gpio_out			: std_logic_vector(32*32-1 downto 0);
	
	signal reg_gpio_in_0			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_1			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_2			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_3			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_4			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_5			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_6			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_7			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_8			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_9			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_10			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_11			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_12			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_13			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_14			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_15			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_16			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_17			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_18			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_19			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_20			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_21			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_22			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_23			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_24			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_25			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_26			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_27			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_28			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_29			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_30			: std_logic_vector(31 downto 0);
	signal reg_gpio_in_31			: std_logic_vector(31 downto 0);

	signal reg_scratch			: std_logic_vector(31 downto 0);
	signal version				: std_logic_vector(31 downto 0);
	signal sig_i				: std_logic_vector(31 downto 0);

begin
	-- =========== I/O Connections assignments ==============
	-- fixed axi4-lite I/O
	s_axi_awready			<= axi_awready;
	s_axi_wready			<= axi_wready;
	s_axi_bresp			<= axi_bresp;
	s_axi_bvalid			<= axi_bvalid;
	s_axi_arready			<= axi_arready;
	s_axi_rdata			<= axi_rdata;
	s_axi_rresp			<= axi_rresp;
	s_axi_rvalid			<= axi_rvalid;

	-- fixed system register I/O
	scratch 			<= reg_scratch;

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_awready		<= '0';
			else
				if (axi_awready = '0' and s_axi_awvalid = '1') then
					axi_awready	<= '1';
				else
					axi_awready	<= '0';
				end if;
			end if;
		end if;
	end process;

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_awaddr		<= (others => '0');
			else
				if (axi_awready = '0' and s_axi_awvalid = '1') then
					axi_awaddr	<= s_axi_awaddr;
				end if;
			end if;
		end if;
	end process;

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_wready		<= '0';
			else
				if (axi_wready = '0' and s_axi_wvalid = '1') then
					axi_wready	<= '1';
				else
					axi_wready	<= '0';
				end if;
			end if;
		end if;
	end process;

	slv_reg_wren		<= axi_wready and s_axi_wvalid;
	awaddr			<= axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto 2);


	-- Write registers
	
	process(s_axi_aclk)
	begin
		if(rising_edge(s_axi_aclk)) then
			gpio_out_en					<= x"00000000";
			
			if( s_axi_aresetn='0' ) then
				reg_gpio_out(32*(0 +1)-1 downto 32*0 ) 	<= GPIO_INIT_0;
				reg_gpio_out(32*(1 +1)-1 downto 32*1 ) 	<= GPIO_INIT_1;
				reg_gpio_out(32*(2 +1)-1 downto 32*2 ) 	<= GPIO_INIT_2;
				reg_gpio_out(32*(3 +1)-1 downto 32*3 ) 	<= GPIO_INIT_3;
				reg_gpio_out(32*(4 +1)-1 downto 32*4 ) 	<= GPIO_INIT_4;
				reg_gpio_out(32*(5 +1)-1 downto 32*5 ) 	<= GPIO_INIT_5;
				reg_gpio_out(32*(6 +1)-1 downto 32*6 ) 	<= GPIO_INIT_6;
				reg_gpio_out(32*(7 +1)-1 downto 32*7 ) 	<= GPIO_INIT_7;
				reg_gpio_out(32*(8 +1)-1 downto 32*8 ) 	<= GPIO_INIT_8;
				reg_gpio_out(32*(9 +1)-1 downto 32*9 ) 	<= GPIO_INIT_9;
				reg_gpio_out(32*(10+1)-1 downto 32*10) 	<= GPIO_INIT_10;
				reg_gpio_out(32*(11+1)-1 downto 32*11) 	<= GPIO_INIT_11;
				reg_gpio_out(32*(12+1)-1 downto 32*12) 	<= GPIO_INIT_12;
				reg_gpio_out(32*(13+1)-1 downto 32*13) 	<= GPIO_INIT_13;
				reg_gpio_out(32*(14+1)-1 downto 32*14) 	<= GPIO_INIT_14;
				reg_gpio_out(32*(15+1)-1 downto 32*15) 	<= GPIO_INIT_15;
				reg_gpio_out(32*(16+1)-1 downto 32*16) 	<= GPIO_INIT_16;
				reg_gpio_out(32*(17+1)-1 downto 32*17) 	<= GPIO_INIT_17;
				reg_gpio_out(32*(18+1)-1 downto 32*18) 	<= GPIO_INIT_18;
				reg_gpio_out(32*(19+1)-1 downto 32*19) 	<= GPIO_INIT_19;
				reg_gpio_out(32*(20+1)-1 downto 32*20) 	<= GPIO_INIT_20;
				reg_gpio_out(32*(21+1)-1 downto 32*21) 	<= GPIO_INIT_21;
				reg_gpio_out(32*(22+1)-1 downto 32*22) 	<= GPIO_INIT_22;
				reg_gpio_out(32*(23+1)-1 downto 32*23) 	<= GPIO_INIT_23;
				reg_gpio_out(32*(24+1)-1 downto 32*24) 	<= GPIO_INIT_24;
				reg_gpio_out(32*(25+1)-1 downto 32*25) 	<= GPIO_INIT_25;
				reg_gpio_out(32*(26+1)-1 downto 32*26) 	<= GPIO_INIT_26;
				reg_gpio_out(32*(27+1)-1 downto 32*27) 	<= GPIO_INIT_27;
				reg_gpio_out(32*(28+1)-1 downto 32*28) 	<= GPIO_INIT_28;
				reg_gpio_out(32*(29+1)-1 downto 32*29) 	<= GPIO_INIT_29;
				reg_gpio_out(32*(30+1)-1 downto 32*30) 	<= GPIO_INIT_30;
				reg_gpio_out(32*(31+1)-1 downto 32*31) 	<= GPIO_INIT_31;				
				
				program_n				<= '1';
				reg_scratch				<= (others => '0');
			elsif(slv_reg_wren = '1') then

				gpio_out_loop: for i in 31 downto 0 loop 
					if(awaddr = std_logic_vector(to_unsigned(i, C_S_AXI_ADDR_WIDTH-2))) then
						wstrb_loop: for j in 3 downto 0 loop
							if(s_axi_wstrb(j) = '1') then
								reg_gpio_out(32*i+8*(j+1)-1 downto 32*i+8*j) 
									<= s_axi_wdata(8*(j+1)-1 downto 8*j);
							end if;
						end loop;
						
						gpio_out_en(i)		<= '1';
					end if;
				end loop;
				
				-- wstrb is not supported for program_n
				if(awaddr = PROGRAM_ADDR and s_axi_wdata(15 downto 12) = signature(3 downto 0) and
					s_axi_wdata(11 downto 8) = signature(7 downto 4) and
					s_axi_wdata(7 downto 4) = signature(11 downto 8) and
					s_axi_wdata(3 downto 0) = signature(15 downto 12)) then
					program_n			<= '0';
				end if;
				
				if(awaddr = SCRATCH_ADDR) then
					scratch_wstrb_loop: for j in 3 downto 0 loop
						if(s_axi_wstrb(j) = '1') then
							reg_scratch(8*(j+1)-1 downto 8*j)
									<= s_axi_wdata(8*(j+1)-1 downto 8*j);						
						end if;
					end loop;
				end if;

			end if;
		end if;
	end process;
	
	gpio_out_0 	<= reg_gpio_out(32*(0 +1)-1 downto 32*0 );
	gpio_out_1 	<= reg_gpio_out(32*(1 +1)-1 downto 32*1 );
	gpio_out_2 	<= reg_gpio_out(32*(2 +1)-1 downto 32*2 );
	gpio_out_3 	<= reg_gpio_out(32*(3 +1)-1 downto 32*3 );
	gpio_out_4 	<= reg_gpio_out(32*(4 +1)-1 downto 32*4 );
	gpio_out_5 	<= reg_gpio_out(32*(5 +1)-1 downto 32*5 );
	gpio_out_6 	<= reg_gpio_out(32*(6 +1)-1 downto 32*6 );
	gpio_out_7 	<= reg_gpio_out(32*(7 +1)-1 downto 32*7 );
	gpio_out_8 	<= reg_gpio_out(32*(8 +1)-1 downto 32*8 );
	gpio_out_9 	<= reg_gpio_out(32*(9 +1)-1 downto 32*9 );
	gpio_out_10	<= reg_gpio_out(32*(10+1)-1 downto 32*10);
	gpio_out_11	<= reg_gpio_out(32*(11+1)-1 downto 32*11);
	gpio_out_12	<= reg_gpio_out(32*(12+1)-1 downto 32*12);
	gpio_out_13	<= reg_gpio_out(32*(13+1)-1 downto 32*13);
	gpio_out_14	<= reg_gpio_out(32*(14+1)-1 downto 32*14);
	gpio_out_15	<= reg_gpio_out(32*(15+1)-1 downto 32*15);
	gpio_out_16	<= reg_gpio_out(32*(16+1)-1 downto 32*16);
	gpio_out_17	<= reg_gpio_out(32*(17+1)-1 downto 32*17);
	gpio_out_18	<= reg_gpio_out(32*(18+1)-1 downto 32*18);
	gpio_out_19	<= reg_gpio_out(32*(19+1)-1 downto 32*19);
	gpio_out_20	<= reg_gpio_out(32*(20+1)-1 downto 32*20);
	gpio_out_21	<= reg_gpio_out(32*(21+1)-1 downto 32*21);
	gpio_out_22	<= reg_gpio_out(32*(22+1)-1 downto 32*22);
	gpio_out_23	<= reg_gpio_out(32*(23+1)-1 downto 32*23);
	gpio_out_24	<= reg_gpio_out(32*(24+1)-1 downto 32*24);
	gpio_out_25	<= reg_gpio_out(32*(25+1)-1 downto 32*25);
	gpio_out_26	<= reg_gpio_out(32*(26+1)-1 downto 32*26);
	gpio_out_27	<= reg_gpio_out(32*(27+1)-1 downto 32*27);
	gpio_out_28	<= reg_gpio_out(32*(28+1)-1 downto 32*28);
	gpio_out_29	<= reg_gpio_out(32*(29+1)-1 downto 32*29);
	gpio_out_30	<= reg_gpio_out(32*(30+1)-1 downto 32*30);
	gpio_out_31	<= reg_gpio_out(32*(31+1)-1 downto 32*31);

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_bvalid		<= '0';
				axi_bresp		<= "00";
			else
				if (axi_wready = '1' and s_axi_wvalid = '1' and axi_bvalid = '0'  ) then
					axi_bvalid	<= '1';
					axi_bresp	<= "00";
				elsif (s_axi_bready = '1' and axi_bvalid = '1') then
					axi_bvalid	<= '0';
				end if;
			end if;
		end if;
	end process;

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_arready <= '0';
				axi_araddr		<= (others => '1');
			else
				if (axi_arready = '0' and s_axi_arvalid = '1') then
					axi_arready	<= '1';
					axi_araddr	<= s_axi_araddr;
				else
					axi_arready	<= '0';
				end if;
			end if;
		end if;
	end process;

	 process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_rvalid		<= '0';
				axi_rresp		<= "00";
			else
				if (slv_reg_rden = '1' and axi_rvalid = '0') then
					axi_rvalid	<= '1';
					axi_rresp	<= "00";
				elsif (axi_rvalid = '1' and s_axi_rready = '1') then
					-- Read data is accepted by the master
					axi_rvalid	<= '0';
				end if;
			end if;
		end if;
	end process;

	-- Read registers	
	process(s_axi_aclk)
	begin
		if(rising_edge(s_axi_aclk)) then
			reg_gpio_in_0			<= gpio_in_0;
			reg_gpio_in_1			<= gpio_in_1;
			reg_gpio_in_2			<= gpio_in_2;
			reg_gpio_in_3			<= gpio_in_3;
			reg_gpio_in_4			<= gpio_in_4;
			reg_gpio_in_5			<= gpio_in_5;
			reg_gpio_in_6			<= gpio_in_6;
			reg_gpio_in_7			<= gpio_in_7;
			reg_gpio_in_8			<= gpio_in_8;
			reg_gpio_in_9			<= gpio_in_9;
			reg_gpio_in_10			<= gpio_in_10;
			reg_gpio_in_11			<= gpio_in_11;
			reg_gpio_in_12			<= gpio_in_12;
			reg_gpio_in_13			<= gpio_in_13;
			reg_gpio_in_14			<= gpio_in_14;
			reg_gpio_in_15			<= gpio_in_15;
			reg_gpio_in_16			<= gpio_in_16;
			reg_gpio_in_17			<= gpio_in_17;
			reg_gpio_in_18			<= gpio_in_18;
			reg_gpio_in_19			<= gpio_in_19;
			reg_gpio_in_20			<= gpio_in_20;
			reg_gpio_in_21			<= gpio_in_21;
			reg_gpio_in_22			<= gpio_in_22;
			reg_gpio_in_23			<= gpio_in_23;
			reg_gpio_in_24			<= gpio_in_24;
			reg_gpio_in_25			<= gpio_in_25;
			reg_gpio_in_26			<= gpio_in_26;
			reg_gpio_in_27			<= gpio_in_27;
			reg_gpio_in_28			<= gpio_in_28;
			reg_gpio_in_29			<= gpio_in_29;
			reg_gpio_in_30			<= gpio_in_30;
			reg_gpio_in_31			<= gpio_in_31;			
		end if;
	end process;
		
	slv_reg_rden		<= axi_arready and s_axi_arvalid and (not axi_rvalid) ;

	version			<=	major_version &
					minor_version &
					patch_version &
					rev_version;

	sig_i			<= image_id & signature;

	araddr			<= axi_araddr(C_S_AXI_ADDR_WIDTH-1 downto 2);
	
	with araddr select
		reg_data_out	<=	reg_gpio_in_0					when GPIO_0_ADDR,
					reg_gpio_in_1					when GPIO_1_ADDR,
					reg_gpio_in_2					when GPIO_2_ADDR,
					reg_gpio_in_3					when GPIO_3_ADDR,
					reg_gpio_in_4					when GPIO_4_ADDR,
					reg_gpio_in_5					when GPIO_5_ADDR,
					reg_gpio_in_6					when GPIO_6_ADDR,
					reg_gpio_in_7					when GPIO_7_ADDR,
					reg_gpio_in_8					when GPIO_8_ADDR,
					reg_gpio_in_9					when GPIO_9_ADDR,
					reg_gpio_in_10					when GPIO_10_ADDR,
					reg_gpio_in_11					when GPIO_11_ADDR,
					reg_gpio_in_12					when GPIO_12_ADDR,
					reg_gpio_in_13					when GPIO_13_ADDR,
					reg_gpio_in_14					when GPIO_14_ADDR,
					reg_gpio_in_15					when GPIO_15_ADDR,
					reg_gpio_in_16					when GPIO_16_ADDR,
					reg_gpio_in_17					when GPIO_17_ADDR,
					reg_gpio_in_18					when GPIO_18_ADDR,
					reg_gpio_in_19					when GPIO_19_ADDR,
					reg_gpio_in_20					when GPIO_20_ADDR,
					reg_gpio_in_21					when GPIO_21_ADDR,
					reg_gpio_in_22					when GPIO_22_ADDR,
					reg_gpio_in_23					when GPIO_23_ADDR,
					reg_gpio_in_24					when GPIO_24_ADDR,
					reg_gpio_in_25					when GPIO_25_ADDR,
					reg_gpio_in_26					when GPIO_26_ADDR,
					reg_gpio_in_27					when GPIO_27_ADDR,
					reg_gpio_in_28					when GPIO_28_ADDR,
					reg_gpio_in_29					when GPIO_29_ADDR,
					reg_gpio_in_30					when GPIO_30_ADDR,
					reg_gpio_in_31					when GPIO_31_ADDR,
					
					reg_scratch					when SCRATCH_ADDR,
					version						when VER_ADDR,
					sig_i						when SIG_ADDR,
					(others => '0')					when others;

	process(s_axi_aclk ) is
	begin
		if (rising_edge (s_axi_aclk)) then
			if ( S_AXI_ARESETN = '0' ) then
				axi_rdata		<= (others => '0');
			else
				if (slv_reg_rden = '1') then
					axi_rdata	<= reg_data_out;	   -- register read data
				end if;
			end if;
		end if;
	end process;

	
end Behavioral;
