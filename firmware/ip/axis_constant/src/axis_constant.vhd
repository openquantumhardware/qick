library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_constant is
	generic
	(	
		-- Data width.
		DATA_WIDTH	: Integer := 16
	);
	port 
	(
		-- AXIS Slave I/F.
		m_axis_aclk		: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tready	: in std_logic;
		m_axis_tdata	: out std_logic_vector(DATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tvalid	: out std_logic
	);
end axis_constant;

architecture rtl of axis_constant is

begin

m_axis_tdata	<= (others => '0');
m_axis_tstrb	<= (others => '0');
m_axis_tlast	<= '0';
m_axis_tvalid	<= '0';

end rtl;

