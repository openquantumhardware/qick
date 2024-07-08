-- %%%%%%%%%%%%%%%%%%% Test Description %%%%%%%%%%%%%%%%%%%%%
--
-- This test is for understanding if moving tvalid makes the
-- block to generate incorrect tlast at the output.
--
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity tb is
end tb;

architecture rtl of tb is

-- DUT.
component ssrfft_8x32_sync is
	Generic
	(
		NFFT	: Integer := 16;
		SSR		: Integer := 4;
		B		: Integer := 16
	);
    Port
    (
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (2*SSR*B-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

		-- AXIS Master.
		m_axis_tdata	: out std_logic_vector (2*SSR*B-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tvalid	: out std_logic;

		-- Registers.
		SCALE_REG		: in std_logic_vector (31 downto 0);
		QOUT_REG		: in std_logic_vector (31 downto 0)
    );
end component;

constant NFFT			: Integer := 32;
constant SSR			: Integer := 8;
constant B				: Integer := 16;

signal aresetn			: std_logic;
signal aclk				: std_logic;
signal s_axis_tdata		: std_logic_vector (2*SSR*B-1 downto 0) := (others => '0');
signal s_axis_tlast		: std_logic := '0';
signal s_axis_tvalid	: std_logic := '0';

signal m_axis_tdata		: std_logic_vector (2*SSR*B-1 downto 0);
signal m_axis_tlast		: std_logic;
signal m_axis_tvalid	: std_logic;

signal SCALE_REG		: std_logic_vector (31 downto 0) := (others => '0');
signal QOUT_REG			: std_logic_vector (31 downto 0) := std_logic_vector(to_unsigned(0,32));

-- TB control.
signal rd_start			: std_logic := '0';

signal i_re_0   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_1   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_2   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_3   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');  
signal i_re_4   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_5   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_6   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_re_7   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');  
signal i_im_0   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_1   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_2   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_3   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_4   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_5   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_6   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal i_im_7   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');

signal o_re_0   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_1   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_2   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_3   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');  
signal o_re_4   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_5   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_6   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_re_7   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');  
signal o_im_0   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_1   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_2   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_3   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_4   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_5   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_6   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');
signal o_im_7   		: std_logic_vector( 16-1 downto 0 ) := (others => '0');

begin

-- DUT.
DUT : ssrfft_8x32_sync
	Generic map
	(
		NFFT	=> NFFT	,
		SSR		=> SSR	,
		B		=> B
	)
    Port map
    (
		-- Reset and clock.
		aresetn			=> aresetn			,
		aclk			=> aclk				,

		-- AXIS Slave.
		s_axis_tdata	=> s_axis_tdata 	,
		s_axis_tlast	=> s_axis_tlast 	,
		s_axis_tvalid	=> s_axis_tvalid	,

		-- AXIS Master.
		m_axis_tdata	=> m_axis_tdata 	,
		m_axis_tlast	=> m_axis_tlast 	,
		m_axis_tvalid	=> m_axis_tvalid	,

		-- Registers.
		SCALE_REG		=> SCALE_REG		,
		QOUT_REG		=> QOUT_REG
    );

-- Input data.
s_axis_tdata	<= i_im_7 & i_im_6 & i_im_5 & i_im_4 & i_im_3 & i_im_2 & i_im_1 & i_im_0 & i_re_7 & i_re_6 & i_re_5 & i_re_4 & i_re_3 & i_re_2 & i_re_1 & i_re_0;

-- Output data.
o_re_0	<= m_axis_tdata (1*B-1 downto 0*B);
o_re_1	<= m_axis_tdata (2*B-1 downto 1*B);
o_re_2	<= m_axis_tdata (3*B-1 downto 2*B);
o_re_3	<= m_axis_tdata (4*B-1 downto 3*B);
o_re_4	<= m_axis_tdata (5*B-1 downto 4*B);
o_re_5	<= m_axis_tdata (6*B-1 downto 5*B);
o_re_6	<= m_axis_tdata (7*B-1 downto 6*B);
o_re_7	<= m_axis_tdata (8*B-1 downto 7*B);
o_im_0	<= m_axis_tdata (9*B-1 downto 8*B);
o_im_1	<= m_axis_tdata (10*B-1 downto 9*B);
o_im_2	<= m_axis_tdata (11*B-1 downto 10*B);
o_im_3	<= m_axis_tdata (12*B-1 downto 11*B);
o_im_4	<= m_axis_tdata (13*B-1 downto 12*B);
o_im_5	<= m_axis_tdata (14*B-1 downto 13*B);
o_im_6	<= m_axis_tdata (15*B-1 downto 14*B);
o_im_7	<= m_axis_tdata (16*B-1 downto 15*B);

-- Main TB.
process
begin
	aresetn <= '0';
	wait for 250 ns;
	aresetn <= '1';

	wait for 3 us;

	rd_start <= '1';
	wait for 110 ns;
	rd_start <= '0';
	wait for 220 ns;
	rd_start <= '1';
	wait for 490 ns;
	rd_start <= '0';
	wait for 100 ns;
	rd_start <= '1';

	wait for 20 us;

end process;

-- Data process.
process
	variable I : Integer := 0;

	begin

	for K in 0 to 200 loop
		for J in 0 to 2 loop
			while rd_start = '0' loop
				wait until rising_edge(aclk);
				s_axis_tvalid <= '0';	
			end loop;
			wait until rising_edge(aclk);
			s_axis_tlast <= '0';
			s_axis_tvalid <= '1';
			i_re_0 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_1 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_2 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_3 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_4 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_5 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_6 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_re_7 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_0 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_1 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_2 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_3 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_4 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_5 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_6 <= std_logic_vector(to_signed(I,i_re_0'length));
			i_im_7 <= std_logic_vector(to_signed(I,i_re_0'length));

			I := I + 1;
		end loop;

		while rd_start = '0' loop
			wait until rising_edge(aclk);
			s_axis_tvalid <= '0';	
		end loop;
		wait until rising_edge(aclk);
		s_axis_tlast <= '1';
		s_axis_tvalid <= '1';
		i_re_0 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_1 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_2 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_3 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_4 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_5 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_6 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_re_7 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_0 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_1 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_2 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_3 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_4 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_5 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_6 <= std_logic_vector(to_signed(I,i_re_0'length));
		i_im_7 <= std_logic_vector(to_signed(I,i_re_0'length));

		I := I + 1;
	end loop;

end process;

-- Clock.
process
begin
	aclk <= '0';
	wait for 5 ns;
	aclk <= '1';
	wait for 5 ns;
end process;

end rtl;

