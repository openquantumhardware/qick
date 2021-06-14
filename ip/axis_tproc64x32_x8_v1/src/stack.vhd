library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Stack block.
--
-- Number of words: 256 (8 bits).
-- op:
-- * 0 : pop operation.
-- * 1 : push operation.

entity stack is
    Generic (
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
		-- Clock and reset.
        clk    	: in std_logic;
		rstn	: in std_logic;

		-- Enable and operation.
        en		: in std_logic;
		op		: in std_logic;

		-- Input/Output data.
        din     : in std_logic_vector (B-1 downto 0);
        dout    : out std_logic_vector (B-1 downto 0);

		-- Flags.
		empty	: out std_logic;
		full	: out std_logic
    );
end stack;

architecture rtl of stack is

-- Bram.
component bram is
    Generic (
        -- Memory address size.
        N       : Integer := 16;
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
        clk    	: in std_logic;
        ena     : in std_logic;
        wea     : in std_logic;
        addra   : in std_logic_vector (N-1 downto 0);
        dia     : in std_logic_vector (B-1 downto 0);
        doa     : out std_logic_vector (B-1 downto 0)
    );
end component;

-- Memory signals.
signal mem_addr : std_logic_vector (7 downto 0);

-- Stack pointer (points to the address where the next data is written).
signal sp		: unsigned (7 downto 0);
signal sp_1		: unsigned (7 downto 0);

-- Empty/full.
signal empty_i	: std_logic;
signal full_i	: std_logic;

begin

-- Bram.
bram_i : bram
    Generic map (
        -- Memory address size.
        N       => 8	,
        -- Data width.
        B       => B
    )
    Port map ( 
        clk    	=> clk		,
        ena     => en		,
        wea     => op		,
        addra   => mem_addr	,
        dia     => din		,
        doa     => dout
    );

-- Registers.
process (clk)
begin
    if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			-- Stack pointer.
			sp	<= (others => '1');
		else
			-- Stack pointer.
			if ( en = '1' ) then
				if ( op = '1' ) then
					-- Push.
					if ( full_i = '0' ) then
						-- If not full.
						sp <= sp - 1;
					end if;
				else
					-- Pop.
					if ( empty_i = '0' ) then
						-- If not empty.	
						sp <= sp + 1;
					end if;
				end if;
			end if;
		
		end if;
    end if;
end process;

-- Stack pointer + 1 (read address).
sp_1	<= sp + 1;

-- Mux for memory address.
mem_addr	<= 	std_logic_vector (sp) when op = '1' else
				std_logic_vector (sp_1);

-- Empty/full flags.
empty_i	<= '1' when sp = 255 else '0';
full_i	<= '1' when sp = 0 else '0';

-- Assign outputs.
empty	<= empty_i;
full	<= full_i;

end rtl;

