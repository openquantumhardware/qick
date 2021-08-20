library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This block is intended to use to sync gray coded vectors.

-- NOTE: Do not use with generic vector data, as it may result
-- in corrupted re-sync data.

entity synchronizer_vect is 
	generic (
		-- Sync stages.
		N : Integer := 2;

		-- Data width.
		B : Integer := 8
	);
	port (
		rstn	    : in std_logic;
		clk 		: in std_logic;
		data_in		: in std_logic_vector (B-1 downto 0);
		data_out	: out std_logic_vector (B-1 downto 0)
	);
end synchronizer_vect;

architecture rtl of synchronizer_vect is

-- Internal register.
type reg_t is array (N-1 downto 0) of std_logic_vector (B-1 downto 0);
signal data_int_reg : reg_t;

begin

process(clk)
begin
	if (rising_edge(clk)) then
		if (rstn = '0') then
			data_int_reg <= (others => (others => '0')); -- 1 FF.
		else
			data_int_reg <= data_int_reg(N-2 downto 0) & data_in;
		end if;
	end if;
end process;

-- Assign output.
data_out <= data_int_reg(N-1);

end rtl;

