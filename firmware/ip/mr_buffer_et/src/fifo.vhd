----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/18/2019 08:35:37 AM
-- Design Name: 
-- Module Name: fifo - Behavioral
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


entity fifo is
    Generic
    (
        -- Data width.
        B : Integer := 16;
        
        -- Fifo depth.
        N : Integer := 4;
        
        -- Almost full.
        AF : Integer := 3
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
end fifo;

architecture Behavioral of fifo is

-- Number of bits of depth.
constant N_LOG2 : Integer := Integer(ceil(log2(real(N))));

-- Registers.
type array_t is array (N-1 downto 0) of std_logic_vector (B-1 downto 0);
signal regs : array_t;

-- Pointers.
signal wr_ptr   : unsigned (N_LOG2-1 downto 0);
signal rd_ptr   : unsigned (N_LOG2-1 downto 0);

-- Flags.
signal full_i   : std_logic;
signal empty_i  : std_logic;

begin

-- Full/empty signals.
full_i <=   '1' when wr_ptr = rd_ptr - 1 else 
            '0';           
empty_i <=  '1' when wr_ptr = rd_ptr else 
            '0';         

process (clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            wr_ptr <= (others => '0');
            rd_ptr <= (others => '0');
        else
            -- Write.
            if ( wr_en = '1' and full_i = '0' ) then
                -- Write data.
                regs(to_integer(wr_ptr)) <= din;
                
                -- Increment pointer.
                wr_ptr <= wr_ptr + 1;
            end if;
            
            -- Read.
            if ( rd_en = '1' and empty_i = '0' ) then
                -- Increment pointer.
                rd_ptr <= rd_ptr + 1;
            end if;
            
        end if;
    end if;
end process;

-- Assign outputs.
dout    <= regs(to_integer(rd_ptr));
full    <= full_i;
empty   <= empty_i;

end Behavioral;
