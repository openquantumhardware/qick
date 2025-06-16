library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tuser_sync is
  Port ( clk : in std_logic;
         resetn : in std_logic;
         reset : in std_logic;
         enable : in std_logic;
         latch : out std_logic
         );
end tuser_sync;

architecture arch of tuser_sync is

component d_type is
  Port (d : in std_logic;
        q : out std_logic;
        clk : in std_logic;
        resetn : in std_logic
        );
end component d_type;

signal sig_latch, sig_d_type : std_logic;

begin

d_type_inst : d_type
  Port Map (
    d => sig_latch,
    q => sig_d_type,
    clk => clk,
    resetn => resetn
  );

sig_latch <= (not reset) and ((sig_d_type xor enable) or (sig_d_type and enable));
latch <= sig_latch;

end arch;
