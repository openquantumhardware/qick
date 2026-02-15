library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin2gray is
	Generic
	(
		-- Data width.
		B : Integer := 8
	);
	Port
	(
		din	: in std_logic_vector (B-1 downto 0);
		dout: out std_logic_vector (B-1 downto 0)
	);
end bin2gray;

architecture rtl of bin2gray is

signal gray : std_logic_vector (B-1 downto 0);

begin

-- MSB always match.
gray(B-1) <= din(B-1);

GEN: for I in 0 to B-2 generate
begin
	gray(I) <= din(I+1) xor din(I);	
end generate;
	
-- Assign output.
dout <= gray;

end rtl;

