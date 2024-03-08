library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tlast_gen is
    Generic
    (
		-- SSR and FFT Length.
		NFFT	: Integer := 16;
		SSR		: Integer := 4
    );
    Port
    (
        -- Input reset and clock.
        rstn				: in std_logic;
        clk 				: in std_logic;

		-- Input enable.
		en					: in std_logic;

		-- TLAST input/output.
		o_tlast				: out std_logic
    );
end entity;

architecture rtl of tlast_gen is

-- Number of transactions.
constant NTRAN 		: Integer := NFFT/SSR;
constant NTRAN_LOG2 : Integer := Integer(ceil(log2(real(NTRAN))));

-- Counter for transactions.
signal cnt 		: unsigned (NTRAN_LOG2-1 downto 0);

begin

-- Registers.
process (clk)
begin
	if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			cnt <= (others => '0');
		else
			if ( en = '1' ) then
				if ( cnt < to_unsigned(NTRAN-1,cnt'length) ) then
					cnt <= cnt + 1;
				else
					cnt <= (others => '0');
				end if;
			end if;
		end if;
	end if;
end process;

-- Assign outputs.
o_tlast	<= 	'1' when cnt = to_unsigned(NTRAN-1,cnt'length)	else
			'0';

end rtl;

