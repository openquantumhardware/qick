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
        N : Integer := 4
    );
    Port
    ( 
        rstn	: in std_logic;
        clk 	: in std_logic;

        -- Write I/F.
        wr_en  	: in std_logic;
        din     : in std_logic_vector (B-1 downto 0);
        
        -- Read I/F.
        rd_en  	: in std_logic;
        dout   	: out std_logic_vector (B-1 downto 0);
        
        -- Flags.
        full    : out std_logic;        
        empty   : out std_logic
    );
end fifo;

architecture rtl of fifo is

-- Number of bits of depth.
constant N_LOG2 : Integer := Integer(ceil(log2(real(N))));

-- Dual port, single clock  BRAM.
component bram_simple_dp is
    Generic (
        -- Memory address size.
        N       : Integer := 16;
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
        clk    	: in STD_LOGIC;
        ena     : in STD_LOGIC;
        enb     : in STD_LOGIC;
        wea     : in STD_LOGIC;
        addra   : in STD_LOGIC_VECTOR (N-1 downto 0);
        addrb   : in STD_LOGIC_VECTOR (N-1 downto 0);
        dia     : in STD_LOGIC_VECTOR (B-1 downto 0);
        dob     : out STD_LOGIC_VECTOR (B-1 downto 0)
    );
end component;

-- Pointers.
signal wptr   	: unsigned (N_LOG2-1 downto 0);
signal rptr   	: unsigned (N_LOG2-1 downto 0);

-- Memory signals.
signal mem_wea	: std_logic;
signal mem_dob	: std_logic_vector (B-1 downto 0);

-- Flags.
signal full_i   : std_logic;
signal empty_i  : std_logic;

begin

-- FIFO memory.
mem_i : bram_simple_dp
    Generic map (
        -- Memory address size.
        N       => N_LOG2,
        -- Data width.
        B       => B
    )
    Port map ( 
        clk    	=> clk						,
        ena     => '1'						,
        enb     => rd_en					,
        wea     => mem_wea					,
        addra   => std_logic_vector(wptr)	,
        addrb   => std_logic_vector(rptr)	,
        dia     => din						,
        dob     => mem_dob
    );

-- Memory connections.
mem_wea <= 	wr_en when full_i = '0' else
			'0';

-- Full/empty signals.
full_i 	<=  '1' when wptr = rptr - 1 else 
            '0';           
empty_i	<= 	'1' when wptr = rptr else
			'0';

-- wr_clk registers.
process (clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            wptr <= (others => '0');
            rptr    <= (others => '0');
        else
            -- Write.
            if ( wr_en = '1' and full_i = '0' ) then
                -- Write data.
                
                -- Increment pointer.
                wptr <= wptr + 1;
            end if;

            -- Read.
            if ( rd_en = '1' and empty_i = '0' ) then
                -- Read data.
                
                -- Increment pointer.
                rptr <= rptr + 1;
            end if;
        end if;
    end if;
end process;

-- Assign outputs.
dout   	<= mem_dob;
full    <= full_i;
empty   <= empty_i;

end rtl;

