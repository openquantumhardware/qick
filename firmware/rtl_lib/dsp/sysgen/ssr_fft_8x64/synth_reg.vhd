library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- $Header: /devl/xcs/repo/env/Jobs/sysgen/src/xbs/hdl_pkg/synth_reg.vhd,v 1.2 2005/01/11 00:33:32 stroomer Exp $
----------------------------------------------------------------------------
--
--  Filename      : synth_reg.vhd
--
--  Created       : 6/10/2000
--
--  Description   : Synthesizable VHDL description of parallel register without
--                  an init value and a clear.  SRLC32E components are used.  The
--                  initial value is always 0
--
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity synth_reg is
    generic (width           : integer := 8;
             latency         : integer := 1);
    port (i       : in std_logic_vector(width-1 downto 0);
          ce      : in std_logic;
          clr     : in std_logic;       -- Not used since implemented w/ SRLC32s
          clk     : in std_logic;
          o       : out std_logic_vector(width-1 downto 0));
end synth_reg;

architecture structural of synth_reg is
    component srlc33e
        generic (width : integer:=16;
                 latency : integer :=8);
        port (clk : in std_logic;
              ce  : in std_logic;
              d   : in std_logic_vector(width-1 downto 0);
              q   : out std_logic_vector(width-1 downto 0));
    end component;

    function calc_num_srlc33es (latency : integer)
        return integer
    is
        variable remaining_latency : integer;
        variable result : integer;
    begin
        result := latency / 33;

        remaining_latency := latency - (result * 33);
        -- If latency is not an even multiple of 33 then add one more
        --  srlc33e to the pipeline
        if (remaining_latency /= 0) then
            result := result + 1;
        end if;

        return result;
    end;


    constant complete_num_srlc33es : integer := latency / 33;
    constant num_srlc33es : integer := calc_num_srlc33es(latency);
    constant remaining_latency : integer := latency - (complete_num_srlc33es * 33);
    -- Array for std_logic_vectors
    type register_array is array (num_srlc33es downto 0) of
        std_logic_vector(width-1 downto 0);
    signal z : register_array;

begin

    z(0) <= i;
    complete_ones : if complete_num_srlc33es > 0 generate
        srlc33e_array: for i in 0 to complete_num_srlc33es-1 generate
            delay_comp : srlc33e
                generic map (width => width,
                             latency => 33)
                port map (clk => clk,
                          ce  => ce,
                          d       => z(i),
                          q       => z(i+1));

        end generate;
    end generate;

    partial_one : if remaining_latency > 0 generate
        last_srlc33e : srlc33e
            generic map (width => width,
                         latency => remaining_latency)
            port map (clk => clk,
                      ce  => ce,
                      d   => z(num_srlc33es-1),
                      q   => z(num_srlc33es));
    end generate;
    o <= z(num_srlc33es);
end structural;


