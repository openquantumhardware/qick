library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_terminator is
	generic
	(	
		-- Data width.
		DATA_WIDTH	: Integer := 16
	);
	port 
	(
		-- AXIS Slave I/F.
		s_axis_aclk		: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(DATA_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic
	);
end axis_terminator;

architecture rtl of axis_terminator is

begin

s_axis_tready <= '1';

end rtl;

