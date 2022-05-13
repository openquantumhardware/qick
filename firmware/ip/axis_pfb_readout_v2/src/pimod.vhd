-----------------------
-- Spectral PI shift --
-----------------------
-- This block performs PI shift in frequency domain.
-- It's intended to be used at the output of the SSR FFT
-- IP in the polyphase filter bank implementation.
--
-- PI frequency shift means multiplying by alternating
-- sequence of +1 -1. It is only applied to odd FFT bins.
--
-- This simplified implementation is used when there is one
-- axis transaction per FFT, i.e., the number of points of 
-- the FFT is the same as the number of inputs to the FFT
-- in parallel.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity pimod is
	Generic
	(
		-- Number of bits.
		B		: Integer := 16;
		-- FFT size.
		N		: Integer := 4
	);
	Port
	(
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave I/F.
		s_axis_tdata	: in std_logic_vector(2*B*N-1 downto 0);
		s_axis_tvalid	: in std_logic;

		-- AXIS Master I/F.
		m_axis_tdata	: out std_logic_vector(2*B*N-1 downto 0);
		m_axis_tvalid	: out std_logic
	);
end pimod;

architecture rtl of pimod is

-- MIN,MAX values.
constant MAX_P	: Integer := 2**(B-1)-1;
constant MIN_N	: Integer := -2**(B-1);	

-- Vector signals for pm operation.
type vect_t is array (N-1 downto 0) of signed (B-1 downto 0);
signal dv_i 		: vect_t;
signal dv_i_pm 		: vect_t;
signal dv_q 		: vect_t;
signal dv_q_pm 		: vect_t;

-- Signals combined after pm.
signal d_pm			: std_logic_vector (2*B*N-1 downto 0);
signal d_pm_r		: std_logic_vector (2*B*N-1 downto 0);

-- Muxed signal for alternating pm operation.
signal dout_mux		: std_logic_vector (2*B*N-1 downto 0);

-- Selection register.
signal sel			: unsigned (0 downto 0);

-- Pipeline registers.
signal din_r		: std_logic_vector (2*B*N-1 downto 0);
signal din_rr		: std_logic_vector (2*B*N-1 downto 0);
signal valid_r		: std_logic;
signal valid_rr		: std_logic;

begin

-- Registers.
process (aclk)
begin
	if ( rising_edge(aclk) ) then
		if ( aresetn = '0' ) then
			-- Signals combined after pm.
			d_pm_r		<= (others => '0');

			-- sel register.
			sel			<= (others => '0');

			-- Pipeline registers.
			din_r		<= (others => '0');
			din_rr		<= (others => '0');
			valid_r		<= '0';
			valid_rr	<= '0';
		else
			-- Signals combined after pm.
			d_pm_r		<= d_pm;

			-- sel register.
			if (valid_r = '1') then
				sel <= sel + 1;
			end if;

			-- Pipeline registers.
			din_r		<= s_axis_tdata;
			din_rr		<= din_r;
			valid_r		<= s_axis_tvalid;
			valid_rr	<= valid_r;
		end if;
	end if;	
end process;

-- Slice input.
GEN_SLICE_IN: for I in 0 to N-1 generate
	dv_i(I)	<= signed(din_r ( 		(I+1)*B-1 	downto 		I*B));
	dv_q(I)	<= signed(din_r ( N*B+	(I+1)*B-1 	downto N*B+	I*B));
end generate GEN_SLICE_IN;

-- Multiply by -1 only odd samples.
GEN_PM: for I in 0 to N/2-1 generate
	-- Even samples: multiply always by 1.
	dv_i_pm(2*I) 	<= dv_i(2*I);
	
	-- Odd samples: multiply by -1. Check maximum negative number.
	dv_i_pm(2*I+1)	<=	to_signed(MAX_P,B) when dv_i(2*I+1) = to_signed(MIN_N,B) else
						-dv_i(2*I+1);

	-- Even samples: multiply always by 1.
	dv_q_pm(2*I) 	<= dv_q(2*I);

	-- Odd samples: multiply by -1. Check maximum negative number.
	dv_q_pm(2*I+1) 	<= 	to_signed(MAX_P,B) when dv_q(2*I+1) = to_signed(MIN_N,B) else
						-dv_q(2*I+1);
end generate GEN_PM;

-- Combine signals back.
GEN_COMBINE_PM: for I in 0 to N-1 generate
	d_pm (		(I+1)*B-1 downto 	 I*B)	<= std_logic_vector(dv_i_pm(I));
	d_pm ( N*B+	(I+1)*B-1 downto N*B+I*B) 	<= std_logic_vector(dv_q_pm(I));
end generate GEN_COMBINE_PM;

-- Data mux.
dout_mux	<= 	din_rr when sel = to_unsigned(0,sel'length) else
				d_pm_r;


-- Assign outputs.
m_axis_tdata	<= dout_mux;
m_axis_tvalid	<= valid_rr;

end rtl;

