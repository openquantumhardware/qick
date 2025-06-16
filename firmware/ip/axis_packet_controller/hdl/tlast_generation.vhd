library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tlast_generation is
  Port (clk : in std_logic;
        resetn : in std_logic;
        packet_size : in std_logic_vector(31 downto 0);
        valid : in std_logic;
        reset : in std_logic;
        tlast : out std_logic
        );
end tlast_generation;

architecture arch of tlast_generation is

signal sig_tlast_out : std_logic;
signal sig_reset : std_logic;
signal sig_count : std_logic_vector(31 downto 0);

begin

tlast_gen_process : process(clk)
variable accumulator : unsigned(31 downto 0) := (others=>'0');
begin
if rising_edge(clk) then
    if resetn = '1' then
        if sig_reset = '0' then
            if valid = '1' then
                accumulator := accumulator + 1;
            end if;
        else
            accumulator := (others=>'0');
        end if;
    else
        accumulator := (others=> '0');
    end if;
end if;
if std_logic_vector(accumulator) >= packet_size then
    sig_tlast_out <= '1';
else
    sig_tlast_out <= '0';
end if;
end process;

sig_reset <= reset or sig_tlast_out;
tlast <= sig_tlast_out;

end arch;
