library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bram_simple_dp is
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
end bram_simple_dp;

architecture rtl of bram_simple_dp is

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
        if (enb = '1') then
            dob <= RAM(conv_integer(addrb));
        end if;
    end if;
end process;

end rtl;

