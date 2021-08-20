library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_set_reg is
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
		s_axis_tvalid	: in std_logic;

		-- Output data.
		dout			: out std_logic_vector (DATA_WIDTH-1 downto 0)
	);
end axis_set_reg;

architecture rtl of axis_set_reg is

-- Data register.
signal dout_r : std_logic_vector (DATA_WIDTH-1 downto 0);

begin

-- Registers.
process (s_axis_aclk)
begin
	if ( rising_edge(s_axis_aclk) ) then
		if ( s_axis_aresetn = '0' ) then
			-- Data register.
			dout_r <= (others => '0');
		else
			-- Data register.
			if ( s_axis_tvalid = '1' ) then
				dout_r <= s_axis_tdata;
			end if;
		end if;
	end if;
end process;

-- Assign outputs.
s_axis_tready 	<= '1';
dout			<= dout_r;

end rtl;

