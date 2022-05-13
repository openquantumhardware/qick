library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity axis_register_slice_nb is
	Generic
	(
		-- Number of bits.
		B	: Integer := 16;

		-- Delay.
		N 	: Integer := 4
	);
	Port
	(
		-- Reset and clock.
		aclk	 		: in std_logic;
		aresetn			: in std_logic;

		-- AXIS Slave I/F.
		s_axis_tdata	: in std_logic_vector(B-1 downto 0);
		s_axis_tvalid	: in std_logic;
		s_axis_tready	: out std_logic;

		-- AXIS Master I/F.
		m_axis_tdata	: out std_logic_vector(B-1 downto 0);
		m_axis_tvalid	: out std_logic;
		m_axis_tready	: in std_logic
	);
end axis_register_slice_nb;

architecture rtl of axis_register_slice_nb is

-- Shift register for data.
type reg_v is array (N-1 downto 0) of std_logic_vector (B-1 downto 0);
signal shift_reg_tdata	: reg_v;

begin

-- Registers.
process (aclk)
begin
	if ( rising_edge(aclk) ) then
		if ( aresetn = '0' ) then
			-- Shift registers.
			shift_reg_tdata	<= (others => (others => '0'));
		else		    
			shift_reg_tdata	<= shift_reg_tdata (N-2 downto 0) & s_axis_tdata;
		end if;
	end if;	
end process;

-- Assign outputs.
s_axis_tready	<= '1';

m_axis_tdata	<= shift_reg_tdata (N-1);
m_axis_tvalid	<= '1';

end rtl;

