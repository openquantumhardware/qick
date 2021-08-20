library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity bram is
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
end bram;

architecture rtl of bram is

-- Ram type.
type ram_type is array (2**N-1 downto 0) of std_logic_vector (B-1 downto 0);
shared variable RAM : ram_type;

begin

process (clk)
begin
    if (clk'event and clk = '1') then
        if (ena = '1') then
            if (wea = '1') then
                RAM(conv_integer(addra)) := dia;
            end if;
        end if;
    end if;
end process;

process (clk)
begin
    if (clk'event and clk = '1') then
        if (ena = '1') then
            doa <= RAM(conv_integer(addra));
        end if;
    end if;
end process;

end rtl;

