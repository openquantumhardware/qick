----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/26/2019 12:08:45 PM
-- Design Name: 
-- Module Name: data_reader - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_reader is
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
        -- Reset and clock.
        rstn        		: in std_logic;
        clk         		: in std_logic;
        
        -- Memory I/F.
        mem_en      		: out std_logic;
        mem_we      		: out std_logic;
        mem_addr    		: out std_logic_vector (N-1 downto 0);
        mem_dout    		: in std_logic_vector (NM*B-1 downto 0);        
        
        -- Data out.
        dout        		: out std_logic_vector (B-1 downto 0);
        dready      		: in std_logic;
        dvalid      		: out std_logic;
        dlast               : out std_logic;

        -- Registers.
		START_REG			: in std_logic
    );
end entity;

architecture Behavioral of data_reader is

constant NM_LOG2    : Integer := Integer(ceil(log2(real(NM))));
constant NPOW       : Integer := 2**N;

-- Fifo to drive AXI Stream Master I/F.
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

type fsm_state is ( INIT_ST,
                    READ_ST,                    
                    WRITE_ST,
                    READ_LAST_ST,
                    WRITE_LAST_ST,
                    FIFO_ST,
                    END_ST);
signal current_state, next_state : fsm_state;

signal init_state   : std_logic;
signal read_state   : std_logic;
signal write_state  : std_logic;
signal fifo_state   : std_logic;
signal read_en      : std_logic;

-- Counter for memory address.
signal addr_cnt : unsigned(N-1 downto 0);

-- Counter for memory selection.
signal sel_cnt  : unsigned(NM_LOG2-1 downto 0);

-- Counter for read data.
signal read_cnt : unsigned(NM_LOG2-1 downto 0);

-- Fifo signals.
signal fifo_wr_en   : std_logic;
signal fifo_rd_en   : std_logic;
signal fifo_din     : std_logic_vector (B-1 downto 0);
signal fifo_dout    : std_logic_vector (B-1 downto 0);
signal fifo_full    : std_logic;        
signal fifo_empty   : std_logic;

signal mem_dout_r   : std_logic_vector (NM*B-1 downto 0);

signal dlast_i      : std_logic;

begin

-- Fifo to drive AXI Stream Master I/F.
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
        din     => fifo_din,
        
        -- Read I/F.
        rd_en   => fifo_rd_en,
        dout    => fifo_dout,
        
        -- Flags.
        full    => fifo_full,        
        empty   => fifo_empty
    );
    
-- Fifo connections.
fifo_wr_en  <= write_state;

fifo_rd_en  <=  dready when read_en = '1' else
                '0';    
                
-- Mux for fifo_din.
process(sel_cnt,mem_dout_r)
begin
    fifo_din <= (others => '0');
    for I in 0 to NM-1 loop
        if ( sel_cnt = to_unsigned(I,sel_cnt'length) ) then
            fifo_din <= mem_dout_r((I+1)*B-1 downto I*B);
        end if;
    end loop;
end process;

-- dlast generation.
dlast_i <=  '1' when (read_cnt = to_unsigned(NM-1,read_cnt'length)) and (fifo_state = '1') else
            '0';                 

process(clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            current_state   <= INIT_ST;
            
            addr_cnt        <= (others => '0');
            sel_cnt         <= (others => '0');
            read_cnt        <= (others => '0');
            
            mem_dout_r      <= (others => '0');
        else
            current_state   <= next_state;

            if ( init_state = '1' ) then
                mem_dout_r      <= (others => '0');
                addr_cnt        <= (others => '0');
                sel_cnt         <= (others => '0');                
            elsif ( read_state = '1' ) then
                mem_dout_r      <= mem_dout;
                addr_cnt        <= addr_cnt + 1;
            elsif ( write_state = '1' ) then
                if ( fifo_full = '0' ) then
                    sel_cnt <= sel_cnt + 1;
                end if;
            end if;            
           
           if ( init_state = '1' ) then
                read_cnt <= (others => '0');
           else
                if ( dready = '1' and fifo_empty = '0' ) then
                    read_cnt <= read_cnt + 1;
                end if;
           end if; 
        end if;
    end if;
end process;

-- Next state logic.
process (current_state, START_REG, addr_cnt, sel_cnt, fifo_full, fifo_empty)
begin
    case current_state is
        when INIT_ST =>
            if (START_REG = '0') then
                next_state <= INIT_ST;
            else
                next_state <= READ_ST;
            end if;
            
        when READ_ST =>          
            next_state <= WRITE_ST;
            
        when WRITE_ST =>
            if ( (sel_cnt < to_unsigned(NM-1,sel_cnt'length)) or (fifo_full = '1') ) then
                next_state <= WRITE_ST;                         
            elsif ( addr_cnt < to_unsigned(NPOW-1,addr_cnt'length) ) then
                next_state <= READ_ST;
            else
                next_state <= READ_LAST_ST;
            end if;
        
        when READ_LAST_ST =>
            next_state <= WRITE_LAST_ST;
            
        when WRITE_LAST_ST =>
            if ( (sel_cnt < to_unsigned(NM-1,sel_cnt'length)) or (fifo_full = '1') ) then
                next_state <= WRITE_LAST_ST;
            else
                next_state <= FIFO_ST;
            end if;
            
        when FIFO_ST =>
            if ( fifo_empty = '0' ) then
                next_state <= FIFO_ST;
            else
                next_state <= END_ST;
            end if;
                
        when END_ST =>
            if ( START_REG = '1' ) then
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
read_state  <= '0';
write_state <= '0';
fifo_state  <= '0';
read_en     <= '0';
    case current_state is
        when INIT_ST =>
            init_state  <= '1';
            read_state  <= '0';
            write_state <= '0';      
            fifo_state  <= '0';      
            read_en     <= '0';
            
        when READ_ST =>
            init_state  <= '0';
            read_state  <= '1';
            write_state <= '0';
            fifo_state  <= '0';            
            read_en     <= '1';
        
        when WRITE_ST =>    
            init_state  <= '0';
            read_state  <= '0';
            write_state <= '1';
            fifo_state  <= '0';            
            read_en     <= '1';
            
        when READ_LAST_ST =>    
            init_state  <= '0';
            read_state  <= '1';
            write_state <= '0';
            fifo_state  <= '0';            
            read_en     <= '1';            
            
        when WRITE_LAST_ST =>    
            init_state  <= '0';
            read_state  <= '0';
            write_state <= '1';
            fifo_state  <= '0';            
            read_en     <= '1';            
            
        when FIFO_ST =>    
            init_state  <= '0';
            read_state  <= '0';
            write_state <= '0';
            fifo_state  <= '1';            
            read_en     <= '1';            
            
        when END_ST =>
            init_state  <= '0';
            read_state  <= '0';
            write_state <= '0';
            fifo_state  <= '0';            
            read_en     <= '0';
                        
    end case;
end process;

-- Assign outputs.
mem_en      <= '1';
mem_we      <= '0';
mem_addr    <= std_logic_vector(addr_cnt);

dout    <= fifo_dout;
dvalid  <= not(fifo_empty);
dlast   <= dlast_i;

end Behavioral;
