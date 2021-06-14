library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Bit-wise operations block.

-- It operates on two inputs.
-- Operations are:
-- 0000 : din_a and din_b
-- 0001 : din_a or din_b
-- 0010 : din_a xor din_b
-- 0011 : not(din_b)
-- 0100 : din_a << din_b
-- 0101 : din_a >> din_b
--
-- Latency is 3 clocks.

entity bitw is
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

		-- Output.
        dout    : out std_logic_vector (B-1 downto 0)
    );
end bitw;

architecture rtl of bitw is

-- Number of bits of B.
constant B_LOG2 : Integer := Integer(ceil(log2(real(B))));

-- Input registers.
signal din_a_r	: std_logic_vector (B-1 downto 0);
signal din_b_r	: std_logic_vector (B-1 downto 0);
signal op_r		: std_logic_vector (3 downto 0);

-- Operations.
signal and_i	: std_logic_vector (B-1 downto 0);
signal or_i		: std_logic_vector (B-1 downto 0);
signal xor_i	: std_logic_vector (B-1 downto 0);
signal not_i	: std_logic_vector (B-1 downto 0);

-- Shift.
type vect_t is array (B-1 downto 0) of std_logic_vector (B-1 downto 0);
signal ls_i		: vect_t;
signal rs_i		: vect_t;
signal ls_mux	: std_logic_vector (B-1 downto 0);
signal rs_mux	: std_logic_vector (B-1 downto 0);
signal shift_n	: unsigned(B_LOG2-1 downto 0);

-- Output mux.
signal dout_mux	: std_logic_vector (B-1 downto 0);
signal dout_r	: std_logic_vector (B-1 downto 0);
signal dout_rr	: std_logic_vector (B-1 downto 0);

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

			-- Output mux.
			dout_r	<= (others => '0');
			dout_rr	<= (others => '0');
		else
			-- Input registers.
			din_a_r	<= din_a;
			din_b_r	<= din_b;
			op_r	<= op;

			-- Output mux.
			dout_r	<= dout_mux;
			dout_rr	<= dout_r;
		end if;
	end if;
end process;

-- Operations.
and_i	<= din_a_r and din_b_r;
or_i	<= din_a_r or din_b_r;
xor_i	<= din_a_r xor din_b_r;
not_i	<= not(din_b_r);

-- Shift.
GEN_shift: for I in 0 to B-1 generate
	-- Zeros for padding before/after.
	signal zeros_tmp : std_logic_vector (I-1 downto 0) := (others => '0');
begin
	ls_i(I)	<= din_a_r(B-I-1 downto 0) & zeros_tmp;
	rs_i(I)	<= zeros_tmp & din_a_r(B-1 downto I);
end generate GEN_shift;

-- Left shift selection mux.
ls_mux	<= ls_i(to_integer(shift_n));

-- Right shift selection mux.
rs_mux	<= rs_i(to_integer(shift_n));

-- Shift amount.
shift_n	<= unsigned(din_b(B_LOG2-1 downto 0));

-- Output mux.
dout_mux	<= 	and_i	when op_r = "0000" else
				or_i	when op_r = "0001" else
				xor_i	when op_r = "0010" else
				not_i	when op_r = "0011" else
				ls_mux	when op_r = "0100" else
				rs_mux	when op_r = "0101" else
				(others => '0');

-- Assign outputs.
dout	<= dout_rr;

end rtl;

