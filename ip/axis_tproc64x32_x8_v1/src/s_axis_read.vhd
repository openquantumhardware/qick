library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity s_axis_read is
    Generic (
        -- Data width.
        B : Integer := 16
    );
    Port ( 
		-- Clock and reset.
        clk    			: in std_logic;
		rstn			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (B-1 downto 0);
		s_axis_tvalid	: in std_logic;
		s_axis_tready	: out std_logic;

		-- Output data.
		dout			: out std_logic_vector (B-1 downto 0)
    );
end s_axis_read;

architecture rtl of s_axis_read is

-- Data register.
signal data_r	: std_logic_vector (B-1 downto 0);

begin

-- Registers.
process (clk)
begin
	if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			-- Data register.
			data_r	<= (others => '0');
		else
			-- Data register.
			if ( s_axis_tvalid = '1' ) then
				data_r	<= s_axis_tdata;
			end if;
		end if;
	end if;
end process;

-- Assign outputs.
s_axis_tready	<= '1';
dout			<= data_r;

end rtl;

