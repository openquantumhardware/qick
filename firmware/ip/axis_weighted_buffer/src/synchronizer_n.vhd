library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common_lib;
use common_lib.all;

entity synchronizer_n is 
	generic (
		N : Integer := 2
	);
	port (
		rstn	    : in std_logic;
		clk 		: in std_logic;
		data_in		: in std_logic;
		data_out	: out std_logic
	);
end synchronizer_n;

architecture rtl of synchronizer_n is

-- Internal register.
signal data_int_reg : std_logic_vector (N-1 downto 0);

begin

process(clk)
begin
	if (rising_edge(clk)) then
		if (rstn = '0') then
			data_int_reg <= (others => '0');
		else
			data_int_reg <= data_int_reg(N-2 downto 0) & data_in;
		end if;
	end if;
end process;

-- Assign output.
data_out <= data_int_reg(N-1);

end rtl;

