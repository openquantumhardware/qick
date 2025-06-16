library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity d_type is
  Port (d : in std_logic;
        q : out std_logic;
        clk : in std_logic;
        resetn : in std_logic);
end d_type;

architecture arch of d_type is

begin

data_process : process(clk)
begin
if rising_edge(clk) then
    if resetn = '1' then
        q <= d;
    else
        q <= '0';
    end if;
end if;
end process;

end arch;
