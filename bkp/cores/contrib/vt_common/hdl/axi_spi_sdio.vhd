----------------------------------------------------------------------------------
-- Company:		VadaTech Incorporated
-- Engineer:		Maxwell
-- Copyright:		Copyright 2014 VadaTech Incorporated. All Rights Reserved.
--
-- Create Date:		06/16/2014
-- Design Name:
-- Module Name:		axi_spi_sdio - Behavioral
-- Project Name:	Any
-- Target Devices:	Any
-- Tool Versions:
-- Description:		This module implements a generic SPI controller with AXI4-Lite
--			interface
--
-- Dependencies:	None
-- Revision: 		
--			v1.3 01/22/2015 Changed parameter C_SDI_CS_ACTIVE_LOW to C_SDI_CS_IDLE
--			v1.2 01/20/2015 Added output ports sclk_sb, sdout_t_sb and sdout_sb to support 
--				shared sdio and sclk in multi-channel instantiation 
--			v1.1 12/12/2014 Added control register fields cpol cpha and rbpol
--				Added AXI_WSTRB support
--			v1.0 06/16/2014 Init for AMC521 project
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity axi_spi_sdio is
generic (
	C_SDI_CS_IDLE			: std_logic	:= '1';
	C_SDI_NUM_OF_SLAVES		: integer	:= 1;
	C_SDI_FREQ_RATIO		: integer	:= 16;
	C_S_AXI_ADDR_WIDTH		: integer	:= 7
 );
port (
	-- Ports of AXI4-Lite interface
	s_axi_aclk			: in  std_logic;
	s_axi_aresetn			: in  std_logic;
	s_axi_awaddr			: in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_awvalid			: in  std_logic;
	s_axi_awready			: out std_logic;
	s_axi_wdata			: in  std_logic_vector(31 downto 0);
	s_axi_wstrb			: in  std_logic_vector(3 downto 0);
	s_axi_wvalid			: in  std_logic;
	s_axi_wready			: out std_logic;
	s_axi_bresp			: out std_logic_vector(1 downto 0);
	s_axi_bvalid			: out std_logic;
	s_axi_bready			: in  std_logic;
	s_axi_araddr			: in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_arvalid			: in  std_logic;
	s_axi_arready			: out std_logic;
	s_axi_rdata			: out std_logic_vector(31 downto 0);
	s_axi_rresp			: out std_logic_vector(1 downto 0);
	s_axi_rvalid			: out std_logic;
	s_axi_rready			: in  std_logic;

	-- IO
	spi_sdio_o			: out std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_sdio_i			: in std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_sclk			: out std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_sdio_t			: out std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_ncs				: out std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	sclk_sb				: out std_logic;
	sdout_sb			: out std_logic;
	sdout_t_sb			: out std_logic;
	ip2intc_irpt			: out std_logic
 );
end axi_spi_sdio;

architecture Behavioral of axi_spi_sdio is
	constant DGIER_ADDR		: std_logic_vector(6 downto 2) := "00111";
	constant IPISR_ADDR		: std_logic_vector(6 downto 2) := "01000";
	constant IPIER_ADDR		: std_logic_vector(6 downto 2) := "01010";
	constant SRR_ADDR		: std_logic_vector(6 downto 2) := "10000";
	constant SPICR_ADDR		: std_logic_vector(6 downto 2) := "11000";
	constant SPISR_ADDR		: std_logic_vector(6 downto 2) := "11001";
	constant SPIDTR_ADDR		: std_logic_vector(6 downto 2) := "11010";
	constant SPIDRR_ADDR		: std_logic_vector(6 downto 2) := "11011";
	constant SPISSR_ADDR		: std_logic_vector(6 downto 2) := "11100";

	-- AXI4LITE signals
	signal axi_awaddr		: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_araddr		: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

	signal axi_awready		: std_logic;
	signal axi_wready		: std_logic;
	signal axi_bresp		: std_logic_vector(1 downto 0);
	signal axi_bvalid		: std_logic;
	signal axi_arready		: std_logic;
	signal axi_rdata		: std_logic_vector(31 downto 0);
	signal axi_rresp		: std_logic_vector(1 downto 0);
	signal axi_rvalid		: std_logic;

	-- AXI4LITE help signals
	signal slv_reg_wren		: std_logic;
	signal slv_reg_rden		: std_logic;
	signal reg_data_out		: std_logic_vector(31 downto 0);
	signal araddr			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2);
	signal awaddr			: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 2);

	-- output signals
	signal sdio_o			: std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	signal sclk			: std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	signal sdio_out_en_v		: std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	signal ncs			: std_logic_vector(C_SDI_NUM_OF_SLAVES-1 downto 0);
	signal interrupt		: std_logic;

	-- ========= Registers ============
	-- DGIER
	signal global_intr_en		: std_logic;
	-- IPISR & SPISR
	signal status_done		: std_logic	:= '1';
	-- IPIER
	signal done_intr_en		: std_logic	:= '0';
	-- SRR
	signal soft_reset		: std_logic;
	-- SPICR fields
	signal tran_width		: std_logic_vector(5 downto 0);
	signal data_start_pos		: std_logic_vector(5 downto 0);
	signal rw_bit_pos		: std_logic_vector(5 downto 0);
	signal rw_rd_active		: std_logic	:= '1';
	signal cpol			: std_logic	:= '0';
	signal cpha			: std_logic	:= '0';
	signal rbpol			: std_logic	:= '0';
	-- SPIDTR
	signal data_transmit		: std_logic_vector(31 downto 0);
	-- SPIDRR
	signal data_receive		: std_logic_vector(31 downto 0);
	-- SPISSR
	signal slave_select		: std_logic_vector(31 downto 0);

	-- internal signals
	signal start			: std_logic;
	signal shift_reg		: std_logic_vector(31 downto 0);
	signal clk_en			: std_logic;
	signal sdio_i_sc		: std_logic;
	signal sdio_o_sc		: std_logic;
	signal sdio_out_en_sc		: std_logic	:= '0';
	signal sclk_sc			: std_logic;
	signal cs_sc			: std_logic	:= C_SDI_CS_IDLE;

	signal sdio_i_fw		: std_logic_vector(31 downto 0);
	signal zeros_to_fw		: std_logic_vector(31 downto C_SDI_NUM_OF_SLAVES);

	signal bit_cnt			: std_logic_vector(6 downto 0);
	signal is_read			: std_logic;
	type sm_state_type is (IDLE, START_WRITE, SHIFT_DATA, END_WRITE);
	signal sm_state			: sm_state_type;
	
	signal byte_index		: integer;
	signal first_edge		: std_logic;
	
	signal count			: integer range 0 to C_SDI_FREQ_RATIO;	

begin
	-- I/O Connections assignments
	-- AXI4LITE assignments
	s_axi_awready	<= axi_awready;
	s_axi_wready	<= axi_wready;
	s_axi_bresp	<= axi_bresp;
	s_axi_bvalid	<= axi_bvalid;
	s_axi_arready	<= axi_arready;
	s_axi_rdata	<= axi_rdata;
	s_axi_rresp	<= axi_rresp;
	s_axi_rvalid	<= axi_rvalid;

	ip2intc_irpt	<= interrupt;
	
	sclk_sb		<= sclk_sc;
	sdout_sb	<= sdio_o_sc;
	sdout_t_sb	<= not(sdio_out_en_sc);

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
				axi_wready <= '0';
			else
				if (axi_wready = '0' and s_axi_wvalid = '1') then
					axi_wready	<= '1';
				else
					axi_wready	<= '0';
				end if;
			end if;
		end if;
	end process;

	slv_reg_wren	<= axi_wready and s_axi_wvalid;
	awaddr		<= axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto 2);

	-- Write registers
	process(s_axi_aresetn, s_axi_aclk)
	begin
		if(rising_edge(s_axi_aclk)) then
			if( s_axi_aresetn='0') then
				global_intr_en		<= '0';
				done_intr_en		<= '0';
				soft_reset		<= '0';
				tran_width		<= (others => '0');
				data_start_pos		<= (others => '0');
				rw_bit_pos		<= (others => '0');
				rw_rd_active		<= '1';
				cpha			<= '0';
				cpol			<= '0';
				rbpol			<= '0';
				data_transmit		<= (others => '0');
				slave_select		<= x"00000001";
				start			<= '0';
			elsif(slv_reg_wren = '1') then
				if(awaddr = DGIER_ADDR and s_axi_wstrb(3) = '1') then
					global_intr_en	<= s_axi_wdata(31);
				end if;

				if(awaddr = IPIER_ADDR and s_axi_wstrb(0) = '1') then
					done_intr_en	<= s_axi_wdata(0);
				end if;

				if(awaddr = SRR_ADDR and s_axi_wdata(3 downto 0) = "1010" and s_axi_wstrb(0) = '1') then
					soft_reset	<= '1';
				else
					soft_reset	<= '0';
				end if;

				if(awaddr = SPICR_ADDR and s_axi_wstrb(0) = '1') then
					tran_width	<= s_axi_wdata(5 downto 0);
				end if;

				if(awaddr = SPICR_ADDR and s_axi_wstrb(1) = '1') then
					data_start_pos	<= s_axi_wdata(13 downto 8);
				end if;
				
				if(awaddr = SPICR_ADDR and s_axi_wstrb(2) = '1') then
					rw_bit_pos	<= s_axi_wdata(21 downto 16);
				end if;
				
				if(awaddr = SPICR_ADDR and s_axi_wstrb(3) = '1') then				
					rw_rd_active	<= s_axi_wdata(24);
					cpha		<= s_axi_wdata(25);
					cpol		<= s_axi_wdata(26);
					rbpol		<= s_axi_wdata(27);					
				end if;

				if(awaddr = SPIDTR_ADDR and s_axi_wstrb(0) = '1') then
					data_transmit(7 downto 0)	<= s_axi_wdata(7 downto 0);
				end if;
				if(awaddr = SPIDTR_ADDR and s_axi_wstrb(1) = '1') then
					data_transmit(15 downto 8)	<= s_axi_wdata(15 downto 8);
				end if;
				if(awaddr = SPIDTR_ADDR and s_axi_wstrb(2) = '1') then
					data_transmit(23 downto 16)	<= s_axi_wdata(23 downto 16);
				end if;
				if(awaddr = SPIDTR_ADDR and s_axi_wstrb(3) = '1') then
					data_transmit(31 downto 24)	<= s_axi_wdata(31 downto 24);
				end if;

				if(awaddr = SPIDTR_ADDR and status_done = '1' and s_axi_wstrb(3) = '1') then
					start		<= '1';
				else
					start		<= '0';
				end if;

				if(awaddr = SPISSR_ADDR and s_axi_wstrb(0) = '1') then
					slave_select(7 downto 0)	<= s_axi_wdata(7 downto 0);
				end if;
				if(awaddr = SPISSR_ADDR and s_axi_wstrb(1) = '1') then
					slave_select(15 downto 8)	<= s_axi_wdata(15 downto 8);
				end if;
				if(awaddr = SPISSR_ADDR and s_axi_wstrb(2) = '1') then
					slave_select(23 downto 16)	<= s_axi_wdata(23 downto 16);
				end if;
				if(awaddr = SPISSR_ADDR and s_axi_wstrb(3) = '1') then
					slave_select(31 downto 24)	<= s_axi_wdata(31 downto 24);
				end if;				
			else
				start			<= '0';
			end if;
		end if;
	end process;

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
				elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
					axi_bvalid	<= '0';
				end if;
			end if;
		end if;
	end process;

	process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_arready		<= '0';
				axi_araddr		<= (others => '1');
			else
				if (axi_arready = '0' and S_AXI_ARVALID = '1') then
					axi_arready	<= '1';
					axi_araddr	<= S_AXI_ARADDR;
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
				if (axi_arready = '1' and s_axi_arvalid = '1' and axi_rvalid = '0') then
					axi_rvalid	<= '1';
					axi_rresp	<= "00";
				elsif (axi_rvalid = '1' and s_axi_rready = '1') then
					-- Read data is accepted by the master
					axi_rvalid	<= '0';
				end if;
			end if;
		end if;
	end process;

	slv_reg_rden		<= axi_arready and s_axi_arvalid and (not axi_rvalid) ;

	araddr			<= axi_araddr(C_S_AXI_ADDR_WIDTH-1 downto 2);

	with araddr select
		reg_data_out	<=	global_intr_en & "000" & x"0000000"		when DGIER_ADDR,
					x"0000000" & "000" & status_done		when IPISR_ADDR,
					x"0000000" & "000" & done_intr_en		when IPIER_ADDR,
					"0000" & rbpol & cpol & cpha & rw_rd_active & 
						"00" & rw_bit_pos & 
						"00" & data_start_pos &
						"00" & tran_width  			when SPICR_ADDR,
					x"0000000" & "000" & status_done		when SPISR_ADDR,
					data_receive					when SPIDRR_ADDR,
					slave_select					when SPISSR_ADDR,
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


	-- ============ SDIO ============================
	interrupt	<=	'1' when sm_state = END_WRITE and clk_en = '1' and global_intr_en = '1' and done_intr_en = '1' else
				'0';

	zeros_to_fw <= (others => '0');
	sdio_i_fw	<=	zeros_to_fw & spi_sdio_i;
	sdio_i_sc	<=	sdio_i_fw(31) when slave_select(31) = '1' else
				sdio_i_fw(30) when slave_select(30) = '1' else
				sdio_i_fw(29) when slave_select(29) = '1' else
				sdio_i_fw(28) when slave_select(28) = '1' else
				sdio_i_fw(27) when slave_select(27) = '1' else
				sdio_i_fw(26) when slave_select(26) = '1' else
				sdio_i_fw(25) when slave_select(25) = '1' else
				sdio_i_fw(24) when slave_select(24) = '1' else
				sdio_i_fw(23) when slave_select(23) = '1' else
				sdio_i_fw(22) when slave_select(22) = '1' else
				sdio_i_fw(21) when slave_select(21) = '1' else
				sdio_i_fw(20) when slave_select(20) = '1' else
				sdio_i_fw(19) when slave_select(19) = '1' else
				sdio_i_fw(18) when slave_select(18) = '1' else
				sdio_i_fw(17) when slave_select(17) = '1' else
				sdio_i_fw(16) when slave_select(16) = '1' else
				sdio_i_fw(15) when slave_select(15) = '1' else
				sdio_i_fw(14) when slave_select(14) = '1' else
				sdio_i_fw(13) when slave_select(13) = '1' else
				sdio_i_fw(12) when slave_select(12) = '1' else
				sdio_i_fw(11) when slave_select(11) = '1' else
				sdio_i_fw(10) when slave_select(10) = '1' else
				sdio_i_fw(9)  when slave_select(9)  = '1' else
				sdio_i_fw(8)  when slave_select(8)  = '1' else
				sdio_i_fw(7)  when slave_select(7)  = '1' else
				sdio_i_fw(6)  when slave_select(6)  = '1' else
				sdio_i_fw(5)  when slave_select(5)  = '1' else
				sdio_i_fw(4)  when slave_select(4)  = '1' else
				sdio_i_fw(3)  when slave_select(3)  = '1' else
				sdio_i_fw(2)  when slave_select(2)  = '1' else
				sdio_i_fw(1)  when slave_select(1)  = '1' else
				sdio_i_fw(0)  when slave_select(0)  = '1' else
				'0';

	sdio_o_sc	<= shift_reg(31);

	sdio_o		<= (others => sdio_o_sc);
	sclk		<= (others => sclk_sc);
	sdio_out_en_v	<= (others => sdio_out_en_sc);
	ncs		<= (others => cs_sc);

	spi_sdio_o	<= sdio_o and slave_select(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_sclk	<= sclk and slave_select(C_SDI_NUM_OF_SLAVES-1 downto 0);
	spi_sdio_t	<= not (sdio_out_en_v and slave_select(C_SDI_NUM_OF_SLAVES-1 downto 0));
	spi_ncs		<= ncs and slave_select(C_SDI_NUM_OF_SLAVES-1 downto 0) when C_SDI_CS_IDLE = '0' else
			   ncs or (not slave_select(C_SDI_NUM_OF_SLAVES-1 downto 0));

	process(s_axi_aclk)
	begin
		if(rising_edge(s_axi_aclk)) then
			if(s_axi_aresetn = '0' or soft_reset = '1') then
				sdio_out_en_sc	<= '0';
				cs_sc		<= C_SDI_CS_IDLE;
				sclk_sc		<= cpol;
				bit_cnt		<= (others => '0');
				is_read		<= '0';
				shift_reg	<= (others => '0');
				data_receive	<= (others => '0');
				status_done 	<= '1';
				first_edge	<= '1';
			else
				case sm_state is
				when IDLE =>
					sdio_out_en_sc		<= '1';
					first_edge		<= '1';
					if(start = '1') then
						sm_state	<= START_WRITE;
						bit_cnt		<= tran_width & '0';
						status_done	<= '0';
					end if;
				when START_WRITE =>
					if(clk_en = '1') then
						cs_sc		<= not C_SDI_CS_IDLE;
						shift_reg	<= data_transmit;
						sm_state	<= SHIFT_DATA;
					end if;
	
				when SHIFT_DATA =>
					if(clk_en = '1') then
						-- first SCLK assertion edge indicator
						if(first_edge = '1') then
							first_edge	<= '0';
						end if;
						
						-- bit_cnt(0) = '0' -> '1', SCLK assertion edge; 
						bit_cnt			<= std_logic_vector(unsigned(bit_cnt) - 1);
						
						-- Generating SCLK
						sclk_sc		<= not sclk_sc;
	
						if(bit_cnt(6 downto 1) = "000000") then
							sm_state	<= END_WRITE;
						end if;
	
						-- when cpha = 0, shift out data on the SCLK de-assertion edge. There's one extra shift out 
						-- 	on the last SCLK de-assertion edge, but it doesn't matter since SCLK is done with no more assertion edge
						-- when cpha = 1, shift out data on the SCLK assertion edge after the first edge
						if((bit_cnt(0) = '0' and cpha = '1' and first_edge = '0') or
						(bit_cnt(0) = '1' and cpha = '0')) then
							shift_reg	<= shift_reg(30 downto 0) & '0';
						end if;
	
						-- when rbpol = 0, shift in data on the SCLK assertion edge (bit_cnt(0) = '0')
						-- when rbpol = 1, shift in data on the SCLK de-assertion edge (bit_cnt(0) = '1')
						-- xnor logic
						if(bit_cnt(0) = rbpol ) then
							data_receive	<= data_receive(30 downto 0) & sdio_i_sc;
						end if;
	
						-- when cpha = 0, sample rw bit on SCLK assertion edge
						-- when cpha = 1, sample rw bit on SCLK de-assertion edge on the next position
						if((bit_cnt(0) = '0' and cpha = '0' and bit_cnt(6 downto 1) = rw_bit_pos) or
						(bit_cnt(0) = '1' and cpha = '1' and bit_cnt(6 downto 1) = std_logic_vector(unsigned(rw_bit_pos) - 1))) then
							if(sdio_o_sc = rw_rd_active) then
								is_read <= '1';
							else
								is_read <= '0';
							end if;
						end if;
	
						-- when cpha = 0, disable output on SCLK de-assertion edge if read
						-- when cpha = 1, disable output on SCLK assertion edge if read
						if(bit_cnt(0) /= cpha and is_read = '1' and  bit_cnt(6 downto 1) = data_start_pos) then
							sdio_out_en_sc	<= '0';
						end if;
	
					end if;
	
				when END_WRITE =>	-- Provide extra time for SCLK to SEN hold time
					if(clk_en = '1') then
						sm_state	<= IDLE;
						cs_sc		<= C_SDI_CS_IDLE;
						is_read		<= '0';
						status_done 	<= '1';
						-- sclk_sc should in cpol status already. just to make sure.
						sclk_sc		<= cpol;
					end if;
	
				end case;
			end if;
		end if;
	end process;

	
	process(s_axi_aclk)
	begin
		if(rising_edge(s_axi_aclk)) then
			if(s_axi_aresetn = '0') then
				clk_en		<= '0';
				count		<= C_SDI_FREQ_RATIO/2;
			else
				if(count = 0) then
					count	<= C_SDI_FREQ_RATIO/2;
					clk_en	<= '1';
				else
					count	<= count - 1;
					clk_en	<= '0';				
				end if;
			end if;
		end if;
	end process;
			
end Behavioral;
