library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity pfb_framing is
    Generic (
        -- Number of channels.
        N : Integer := 8
    );
    Port (
        -- Reset and clock. 
        rstn    : in std_logic;
        clk     : in std_logic;
        
        -- Framing.
		tready	: in std_logic;
		tvalid	: in std_logic;
		fr_sync	: in std_logic;
        fr_out  : out std_logic
        );
end pfb_framing;

architecture rtl of pfb_framing is

-- Number of bits of N.
constant N_LOG2			: Integer := Integer(ceil(log2(real(N))));

-- Wait value.
constant WAIT_C			: Integer := 10*N;
constant WAIT_C_LOG2	: Integer := Integer(ceil(log2(real(WAIT_C))));

-- FSM.
type fsm_type is (  INIT_ST		,
                    SHIFT_ST	,
					WAIT_ST		);

signal current_state, next_state : fsm_type;

-- Free running counter for framing.
signal fr_cnt			: unsigned (N_LOG2-1 downto 0);
signal fr_cnt_en		: std_logic;

-- Counter for waiting until next calibration.
signal wait_cnt			: unsigned (WAIT_C_LOG2-1 downto 0);
signal wait_cnt_en		: std_logic;

-- Framing sync.
signal fr_i				: std_logic;

begin

-- Registers.
process(clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            -- State register.
            current_state <= INIT_ST;
            
            -- Counters.
            fr_cnt  	<= (others => '0');
			wait_cnt	<= (others => '0');
        else
            -- State register.
            current_state <= next_state;
        
            -- Counters.
            if ( fr_cnt_en = '1' and tready = '1' and tvalid = '1' ) then
				if ( fr_cnt < to_unsigned(N-1,fr_cnt'length) ) then
                	fr_cnt 	<= fr_cnt + 1;
				else
					fr_cnt	<= (others => '0');
				end if;
            end if;
			if ( wait_cnt_en = '1' ) then
				if ( wait_cnt < to_unsigned(WAIT_C-1,wait_cnt'length) ) then
					wait_cnt	<= wait_cnt + 1;
				else
					wait_cnt	<= (others => '0');
				end if;
			end if;
            
        end if;
    end if;
end process;

-- Framing sync.
fr_i    <=  '1' when fr_cnt = to_unsigned(N-1,fr_cnt'length) else
            '0';

-- Next state logic.
process (current_state, fr_sync, wait_cnt)
begin
    case current_state is
        when INIT_ST =>
            if ( fr_sync = '0' ) then
                next_state <= INIT_ST;
            else
                next_state <= SHIFT_ST;
            end if;
            
		when SHIFT_ST =>
			next_state <= WAIT_ST;
            
        when WAIT_ST =>
            if ( wait_cnt = to_unsigned(WAIT_C-1,wait_cnt'length) ) then
                next_state <= INIT_ST;
            else
                next_state <= WAIT_ST;
            end if;
    end case;
end process;

-- Output logic.
process (current_state)
begin
fr_cnt_en	<= '0';
wait_cnt_en	<= '0';
    case current_state is
        when INIT_ST =>
			fr_cnt_en	<= '1';
        
        when SHIFT_ST =>
            
        when WAIT_ST =>
			fr_cnt_en	<= '1';
			wait_cnt_en	<= '1';
        
    end case;
end process;

-- Assign outputs.
fr_out  <= fr_i;

end rtl;

