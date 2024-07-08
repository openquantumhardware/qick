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
        tvalid	: out std_logic;
		fr_sync	: in std_logic
        );
end pfb_framing;

architecture rtl of pfb_framing is

-- Wait value.
constant WAIT_C			: Integer := 2*N;
constant WAIT_C_LOG2	: Integer := Integer(ceil(log2(real(WAIT_C))));

-- FSM.
type fsm_type is (  INIT_ST		,
                    SHIFT_ST	,
					WAIT_ST		);

signal current_state, next_state : fsm_type;

-- Counter for waiting until next calibration.
signal wait_cnt		: unsigned (WAIT_C_LOG2-1 downto 0);
signal wait_cnt_en	: std_logic;

signal tvalid_i		: std_logic;		

begin

-- Registers.
process(clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            -- State register.
            current_state <= INIT_ST;
            
            -- Counters.
			wait_cnt	<= (others => '0');
        else
            -- State register.
            current_state <= next_state;
        
            -- Counters.
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
wait_cnt_en	<= '0';
tvalid_i	<= '1';
    case current_state is
        when INIT_ST =>
        
        when SHIFT_ST =>
			tvalid_i	<= '0';
            
        when WAIT_ST =>
			wait_cnt_en	<= '1';
        
    end case;
end process;

-- Assign outputs.
tvalid <= tvalid_i;

end rtl;

