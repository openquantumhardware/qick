library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity framing is
    Generic
    (
		-- SSR and FFT Length.
		NFFT	: Integer := 16;
		SSR		: Integer := 4;

		-- Bits.
		B	: Integer := 16
    );
	Port
	(
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (2*SSR*B-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

		-- Synced outputs.
		tdata			: out std_logic_vector (2*SSR*B-1 downto 0);
		tvalid			: out std_logic
	);
end framing;

architecture rtl of framing is

constant NWAIT			: Integer := 256;
constant NWAIT_LOG2 	: Integer := Integer(ceil(log2(real(NWAIT))));
constant CYCLES 		: Integer := NFFT/SSR;
constant CYCLES_LOG2 	: Integer := Integer(ceil(log2(real(CYCLES))));

-- FSM.
type fsm_type is (	INIT_ST	,
					RST_ST	,
					S0_ST	,
					S1_ST	,
					S2_ST	);
signal current_state, next_state : fsm_type;

signal rst_state	: std_logic;

signal data_r		: std_logic_vector (s_axis_tdata'length-1 downto 0);
signal data_rr		: std_logic_vector (s_axis_tdata'length-1 downto 0);

signal valid_i		: std_logic;
signal valid_r		: std_logic;
signal valid_rr		: std_logic;

signal cnt_nwait	: unsigned (NWAIT_LOG2-1 downto 0);
signal cnt			: unsigned (CYCLES_LOG2-1 downto 0);

begin

-- Registers.
process (aclk)
begin
	if ( rising_edge(aclk) ) then
		if ( aresetn = '0' ) then
			-- State register.
			current_state <= INIT_ST;

			-- Pipeline registers.
			data_r		<= (others => '0');
			data_rr		<= (others => '0');
			valid_r		<= '0';
			valid_rr	<= '0';

			-- Counters.
			cnt_nwait	<= (others => '0');
			cnt			<= (others => '0');
		else
			-- State register.
			current_state <= next_state;

			-- Pipeline registers.
			data_r		<= s_axis_tdata;
			data_rr		<= data_r;
			valid_r		<= valid_i;
			valid_rr	<= valid_r;

			-- Counters.
			if ( rst_state = '1' ) then
				cnt_nwait <= cnt_nwait + 1;
			end if;
			
			if ( valid_i = '1' ) then
				if ( cnt < to_unsigned(CYCLES-1,cnt'length) ) then
					cnt <= cnt + 1;
				else
					cnt <= (others => '0');
				end if;
			end if;
		end if;
	end if;
end process;

-- Next state logic.
process (current_state, cnt_nwait, s_axis_tlast, cnt) 
begin
	case (current_state) is
		when INIT_ST =>
			next_state <= RST_ST;

		when RST_ST =>
			if ( cnt_nwait < to_unsigned(NWAIT-1,cnt_nwait'length) ) then
				next_state <= RST_ST;
			else
				next_state <= S0_ST;
			end if;

		when S0_ST =>
			if ( s_axis_tlast = '1' ) then
				-- Check if tlast is in the right position.
				if ( cnt = to_unsigned(CYCLES-1,cnt'length) ) then
					next_state <= S0_ST;
				else
					-- tlast in the wrong position.
					next_state <= S1_ST;
				end if;
			else
				next_state <= S0_ST;
			end if;

		when S1_ST =>
			-- Wait until a frame is completed.
			if ( cnt = to_unsigned(CYCLES-1,cnt'length) ) then
				next_state <= S2_ST;
			else
				next_state <= S1_ST;
			end if;

		when S2_ST =>
			-- Wait for the next tlast.
			if ( s_axis_tlast = '1' ) then
				next_state <= S0_ST;
			else
				next_state <= S2_ST;
			end if;

	end case;
end process;

-- Output logic.
process (current_state)
begin
rst_state	<= '0';
valid_i		<= '0';
	case (current_state) is
		when INIT_ST =>

		when RST_ST =>
			rst_state	<= '1';

		when S0_ST =>
			valid_i		<= '1';

		when S1_ST =>
			valid_i		<= '1';

		when S2_ST =>

	end case;
end process;

-- Assign outputs.
tdata			<= data_rr;
tvalid			<= valid_rr;

end rtl;

