library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

----------------------------------------------------------------------------
--
--  Filename      : synth_reg_w_init.vhd
--
--  Created       : 6/10/2000
--
--  Description   : Synthesizable VHDL description of parallel register with
--                  an initial value.  The register has clr and ce pins and
--                  is implemented using flip-flops (i.e., not SRL16s).
--
--  Mod. History  : Delayed input .1 ns so that there isn't a setup
--                  violation in the fdse or fdre Unisim models.
--                : Changed VHDL so that initial register is passed as a bit
--                  vector generic value, instead of the const_pkg.
--
--  Mod. Dates    : 8/10/2001
--                  3/19/2003
----------------------------------------------------------------------------

-- synthesis translate_off
library unisim;
use unisim.vcomponents.all;
-- synthesis translate_on

library IEEE;
use IEEE.std_logic_1164.all;

entity synth_reg_w_init is
  generic (
    width: integer := 8;
    init_index: integer := 0;
    init_value: bit_vector := b"0000";
    latency: integer := 1
  );
  port (
    i: in std_logic_vector(width - 1 downto 0);
    ce: in std_logic;
    clr: in std_logic;
    clk: in std_logic;
    o: out std_logic_vector(width - 1 downto 0)
  );
end synth_reg_w_init;

architecture structural of synth_reg_w_init is
  component single_reg_w_init
    generic (
      width: integer := 8;
      init_index: integer := 0;
      init_value: bit_vector := b"0000"
    );
    port (
      i: in std_logic_vector(width - 1 downto 0);
      ce: in std_logic;
      clr: in std_logic;
      clk: in std_logic;
      o: out std_logic_vector(width - 1 downto 0)
    );
  end component; -- end single_reg_w_init

  -- 1D array used to connect all the register together
  signal dly_i: std_logic_vector((latency + 1) * width - 1 downto 0);
  signal dly_clr: std_logic;
begin
  latency_eq_0: if (latency = 0) generate
    o <= i;
  end generate; -- end latency_eq_0

  latency_gt_0: if (latency >= 1) generate
    -- Delayed input 200 ps so that there isn't a setup violation in the
    -- fdse or fdre Unisim models
    dly_i((latency + 1) * width - 1 downto latency * width) <= i
      after 200 ps;
    dly_clr <= clr after 200 ps;

    fd_array: for index in latency downto 1 generate
       reg_comp: single_reg_w_init
          generic map (
            width => width,
            init_index => init_index,
            init_value => init_value
          )
          port map (
            clk => clk,
            i => dly_i((index + 1) * width - 1 downto index * width),
            o => dly_i(index * width - 1 downto (index - 1) * width),
            ce => ce,
            clr => dly_clr
          );
    end generate; -- end fd_array

    o <= dly_i(width - 1 downto 0);
  end generate; -- end latency_gt_0
end structural;


