library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rd2axi is
    Generic
    (
        -- Data width.
        B : Integer := 16
    );
    Port
    ( 
        rstn		: in std_logic;
        clk 		: in std_logic;

        -- FIFO Read I/F.
        fifo_rd_en 	: out std_logic;
        fifo_dout  	: in std_logic_vector (B-1 downto 0);
        fifo_empty  : in std_logic;
        
        -- Read I/F.
        rd_en 		: in std_logic;
        dout  		: out std_logic_vector (B-1 downto 0);
        empty  		: out std_logic
    );
end rd2axi;

architecture rtl of rd2axi is

type fsm_state is (	WAIT_EMPTY_ST,
					READ_FIRST_ST,
					READ_ST,
					READ_LAST_ST);
signal current_state, next_state : fsm_state;

signal wait_empty_state	: std_logic;
signal read_first_state	: std_logic;
signal read_state		: std_logic;

signal fifo_rd_en_i		: std_logic;
signal empty_i 			: std_logic;

begin

process(clk)
begin
	if (rising_edge(clk)) then
		if (rstn = '0') then
			current_state <= WAIT_EMPTY_ST;
		else
			current_state <= next_state;
		end if;
	end if;
end process;

-- Next state logic.
process(current_state, fifo_empty, rd_en)
begin
	case current_state is
		when WAIT_EMPTY_ST =>
			if (fifo_empty = '1') then
				next_state <= WAIT_EMPTY_ST;
			else
				next_state <= READ_FIRST_ST;
			end if;

		when READ_FIRST_ST =>
			next_state <= READ_ST;

		when READ_ST =>
			if (fifo_empty = '0') then
				next_state <= READ_ST;
			else
				if (rd_en = '1') then
					next_state <= WAIT_EMPTY_ST;
				else
					next_state <= READ_LAST_ST;
				end if;
			end if;

		when READ_LAST_ST =>
			if (rd_en = '0') then
				next_state <= READ_LAST_ST;
			else
				next_state <= WAIT_EMPTY_ST;
			end if;

	end case;
end process;

-- Output logic.
process(current_state)
begin
wait_empty_state	<= '0';
read_first_state	<= '0';
read_state			<= '0';
empty_i				<= '0';
	case current_state is
		when WAIT_EMPTY_ST =>
			wait_empty_state	<= '1';
			read_first_state	<= '0';
			read_state			<= '0';
			empty_i				<= '1';

		when READ_FIRST_ST =>
			wait_empty_state	<= '0';
			read_first_state	<= '1';
			read_state			<= '0';
			empty_i				<= '1';

		when READ_ST =>
			wait_empty_state	<= '0';
			read_first_state	<= '0';
			read_state			<= '1';
			empty_i				<= '0';

		when READ_LAST_ST =>
			wait_empty_state	<= '0';
			read_first_state	<= '0';
			read_state			<= '0';
			empty_i				<= '0';

	end case;
end process;

-- FIFO Read enable signal.
fifo_rd_en_i	<= read_first_state or (read_state and rd_en);

-- Assign outputs.
fifo_rd_en 	<= 	fifo_rd_en_i;
-- TODO: add register to freeze last value.
dout  		<= 	fifo_dout when empty_i = '0' else
				(others => '0');
empty  		<= 	empty_i;

end rtl;

