library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common_lib;
use common_lib.all;

entity synchronizer is 
	generic (
		N : Integer := 2
	);
	port (
		rstn	    : in std_logic;
		clk 		: in std_logic;
		data_in		: in std_logic;
		data_out	: out std_logic
	);
end synchronizer;

architecture rtl of synchronizer is

-- Internal register.
signal data_int_reg : std_logic_vector (N-1 downto 0);

begin

process(clk,rstn)
begin
	if (rstn = '0') then
		data_int_reg <= (others => '0'); -- 1 FF.
	elsif (clk'event and clk='1') then
		data_int_reg <= data_int_reg(N-2 downto 0) & data_in;
	end if;
end process;

-- Assign output.
data_out <= data_int_reg(N-1);

end rtl;

