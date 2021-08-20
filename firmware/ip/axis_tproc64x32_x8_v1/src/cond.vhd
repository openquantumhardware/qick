library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Conditional block.

-- It operates on two inputs.
-- Operations are:
-- 0000 : din_a > 	din_b
-- 0001 : din_a >= 	din_b
-- 0010 : din_a < 	din_b
-- 0011 : din_a <= 	din_b
-- 0100 : din_a == 	din_b
-- 0101 : din_a != 	din_b

-- Output flag is 1 when condition is true. Otherwise is 0.
-- Latency is 1 clock.

entity cond is
    Generic (
        -- Data width.
        B : Integer := 16
    );
    Port ( 
		-- Clock and reset.
        clk    	: in std_logic;
		rstn	: in std_logic;

		-- Input operands.
		din_a	: in std_logic_vector (B-1 downto 0);
		din_b	: in std_logic_vector (B-1 downto 0);

		-- Operation.
		op		: in std_logic_vector (3 downto 0);

		-- Flag.
        flag    : out std_logic
    );
end cond;

architecture rtl of cond is

-- Input registers.
signal din_a_r	: signed (B-1 downto 0);
signal din_b_r	: signed (B-1 downto 0);
signal op_r		: std_logic_vector (3 downto 0);

-- Flags for conditions.
signal cond_0_i	: std_logic;	-- >
signal cond_1_i	: std_logic;	-- >=
signal cond_2_i	: std_logic;	-- <
signal cond_3_i	: std_logic;	-- <=
signal cond_4_i	: std_logic;	-- ==
signal cond_5_i	: std_logic;	-- !=

begin

-- Registers.
process (clk)
begin
	if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			-- Input registers.
			din_a_r	<= (others => '0');
			din_b_r	<= (others => '0');
			op_r	<= (others => '0');
		else
			-- Input registers.
			din_a_r	<= signed(din_a);
			din_b_r	<= signed(din_b);
			op_r	<= op;
		end if;
	end if;
end process;

-- Flags for conditions.
cond_0_i	<= '1' when din_a_r > din_b_r else '0'	; -- >
cond_1_i	<= cond_0_i or cond_4_i					; -- >=
cond_2_i	<= '1' when din_a_r < din_b_r else '0'	; -- <
cond_3_i	<= cond_2_i or cond_4_i					; -- <=
cond_4_i	<= '1' when din_a_r = din_b_r else '0'	; -- ==
cond_5_i	<= not(cond_4_i)						; -- !=

-- Mux for output.
flag		<= 	cond_0_i when op_r = "0000" else
				cond_1_i when op_r = "0001" else
				cond_2_i when op_r = "0010" else
				cond_3_i when op_r = "0011" else
				cond_4_i when op_r = "0100" else
				cond_5_i when op_r = "0101" else
				'0';

end rtl;

