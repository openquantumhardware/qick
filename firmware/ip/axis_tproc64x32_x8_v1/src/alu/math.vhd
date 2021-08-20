library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Mathematical block.

-- It operates on two inputs.
-- Operations are:
-- 0000 : din_a + 	din_b
-- 0001 : din_a - 	din_b
-- 0010 : din_a * 	din_b

-- Product: takes B/2 lower bits from din_a and din_b.

-- Zero detection does not have any latency.
-- Output latency is 3 clocks.

entity math is
    Generic (
        -- Data width.
        B : Integer := 16
    );
    Port ( 
		-- Clock and reset.
        clk    		: in std_logic;
		rstn		: in std_logic;

		-- Input operands.
		din_a		: in std_logic_vector (B-1 downto 0);
		din_b		: in std_logic_vector (B-1 downto 0);

		-- Operation.
		op			: in std_logic_vector (3 downto 0);

		-- Zero detection.
		zero_a		: out std_logic;
		zero_b		: out std_logic;

		-- Output.
        dout    	: out std_logic_vector (B-1 downto 0)
    );
end math;

architecture rtl of math is

-- Input registers.
signal din_a_r		: signed (B-1 downto 0);
signal din_b_r		: signed (B-1 downto 0);
signal op_r			: std_logic_vector (3 downto 0);

-- Operations.
signal add_i		: signed (B-1 downto 0);
signal sub_i		: signed (B-1 downto 0);
signal prod_i		: signed (B-1 downto 0);

-- Muxed output.
signal dout_mux		: std_logic_vector (B-1 downto 0);

-- Output registers.
signal dout_r		: std_logic_vector (B-1 downto 0);
signal dout_rr		: std_logic_vector (B-1 downto 0);

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

			-- Output registers.
			dout_r	<= (others => '0');
			dout_rr	<= (others => '0');
		else
			-- Input registers.
			din_a_r	<= signed(din_a);
			din_b_r	<= signed(din_b);
			op_r	<= op;

			-- Output registers.
			dout_r	<= dout_mux;
			dout_rr	<= dout_r;
		end if;
	end if;
end process;

-- Operations.
add_i			<= din_a_r + din_b_r;
sub_i			<= din_a_r - din_b_r;
prod_i			<= din_a_r(B/2-1 downto 0)*din_b_r(B/2-1 downto 0);

-- Muxed output.
dout_mux	<= 	std_logic_vector(add_i)	when op_r = "0000" else
				std_logic_vector(sub_i)	when op_r = "0001" else
				std_logic_vector(prod_i)when op_r = "0010" else
				(others => '0');

-- Assign outputs.
zero_a		<= '1' when signed(din_a) = 0 else '0';
zero_b		<= '1' when signed(din_b) = 0 else '0';
dout		<= dout_rr;

end rtl;

