library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_writer is
    Generic
    (
		-- Number of memories.
		NM	: Integer := 8;
		-- Address map of each memory.
		N	: Integer := 8;
		-- Data width.
		B	: Integer := 16
    );
    Port
    (
        rstn            : in std_logic;
        clk             : in std_logic;

		-- Trigger.
		trigger			: in std_logic;
        
        -- AXI Stream I/F.
        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(B-1 downto 0);				
		s_axis_tvalid	: in std_logic;
		
		-- Memory I/F.
		mem_en          : out std_logic;
		mem_we          : out std_logic;
		mem_addr        : out std_logic_vector (N-1 downto 0);
		mem_di          : out std_logic_vector (B-1 downto 0);
		
		-- Registers.
		CAPTURE_REG		: in std_logic
    );
end entity;

architecture Behavioral of data_writer is

constant NPOW : Integer := 2**N;

-- Fifo to interfase with AXI Stream.
component fifo is
    Generic
    (
        -- Data width.
        B : Integer := 16;
        
        -- Fifo depth.
        N : Integer := 4
    );
    Port
    ( 
        rstn    : in std_logic;
        clk     : in std_logic;
        
        -- Write I/F.
        wr_en   : in std_logic;
        din     : in std_logic_vector (B-1 downto 0);
        
        -- Read I/F.
        rd_en   : in std_logic;
        dout    : out std_logic_vector (B-1 downto 0);
        
        -- Flags.
        full    : out std_logic;        
        empty   : out std_logic
    );
end component;

-- State machine.
type fsm_state is ( INIT_ST,
					TRIGGER_ST,
                    CAPTURE_ST,
                    END_ST);
signal current_state, next_state : fsm_state;

signal init_state   : std_logic;

signal write_en     : std_logic;
         
signal fifo_wr_en   : std_logic;         
signal fifo_rd_en   : std_logic;
signal fifo_dout    : std_logic_vector (B-1 downto 0);         
signal fifo_full    : std_logic;
signal fifo_empty   : std_logic;

signal addr_cnt     : unsigned (N-1 downto 0);
                    
begin

-- Fifo to interfase with AXI stream.
fifo_i : fifo
    Generic map
    (
        -- Data width.
        B => B,
        
        -- Fifo depth.
        N => 4
    )
    Port map
    ( 
        rstn    => rstn,
        clk     => clk,
        
        -- Write I/F.
        wr_en   => fifo_wr_en,
        din     => s_axis_tdata,
        
        -- Read I/F.
        rd_en   => fifo_rd_en,
        dout    => fifo_dout,
        
        -- Flags.
        full    => fifo_full,        
        empty   => fifo_empty
    );

-- Mux for fifo_wr_en.
fifo_wr_en <=   s_axis_tvalid when write_en = '1' else
                '0';    
                
-- fifo_rd_en.
fifo_rd_en <= write_en;
                
-- Registers.
process (clk)
begin
    if (rising_edge(clk)) then
        if ( rstn = '0' ) then
            current_state <= INIT_ST;
        else
            current_state <= next_state;
            
            -- Address counter.
            if ( init_state = '1' ) then
                addr_cnt <= (others => '0');
            else
                if ( write_en  = '1' and fifo_empty = '0' ) then
                    addr_cnt <= addr_cnt + 1;
                end if; 
            end if;
        end if;
    end if;
end process;

-- Next state logic.
process (current_state, CAPTURE_REG, trigger, addr_cnt)
begin
    case current_state is
        when INIT_ST =>
            if (CAPTURE_REG = '0') then
                next_state <= INIT_ST;
            else
                next_state <= TRIGGER_ST;
            end if;

		when TRIGGER_ST =>
			if (trigger = '0') then
				next_state <= TRIGGER_ST;
			else
				next_state <= CAPTURE_ST;
			end if;
            
        when CAPTURE_ST =>
            if ( addr_cnt < to_unsigned(NPOW-1,addr_cnt'length) ) then
                next_state <= CAPTURE_ST;
            else
                next_state <= END_ST;
            end if;            
        
        when END_ST =>
            if ( CAPTURE_REG = '1' ) then
                next_state <= END_ST;
            else
                next_state <= INIT_ST;
            end if;
    end case;
end process;

-- Output logic.
process (current_state)
begin
init_state  <= '0';
write_en    <= '0';
    case current_state is
        when INIT_ST =>
            init_state  <= '1';

        when TRIGGER_ST =>
            
        when CAPTURE_ST =>
            write_en    <= '1';
            
        when END_ST =>
                        
    end case;
end process;

-- Assign outputs.
s_axis_tready <=    not(fifo_full) when write_en = '1' else
                    '0';

mem_en      <= '1';
mem_we      <= write_en;
mem_addr    <= std_logic_vector(addr_cnt);
mem_di      <= fifo_dout;

end Behavioral;
