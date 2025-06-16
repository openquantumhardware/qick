library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity rising_edge_detector is
  Port (clk : in std_logic;
        resetn : in std_logic;
        data_in : in std_logic;
        data_out : out std_logic
        );
end rising_edge_detector;

architecture arch of rising_edge_detector is

component d_type is
  Port (d : in std_logic;
        q : out std_logic;
        clk : in std_logic;
        resetn : in std_logic
        );
end component d_type;

signal sig_data_out : std_logic;
signal sig_not_out : std_logic;

begin

d_type_inst : d_type
  Port Map (
    d => data_in,
    q => sig_data_out,
    clk => clk,
    resetn => resetn
  );
  
data_out <= (not sig_data_out) and data_in;

end arch;
