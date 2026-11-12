library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

----------------------------------------------------------------------------
--
--  Filename      : srlc17e.vhd
--
--  Created       : 6/28/2013
--
--  Description   : splitted from synth_reg.vhd
--
----------------------------------------------------------------------------

-- synthesis translate_off
library unisim;
use unisim.vcomponents.all;
-- synthesis translate_on

library IEEE;
use IEEE.std_logic_1164.all;

entity srlc33e is
    generic (width : integer:=16;
             latency : integer :=8);    -- Max 17
    port (clk   : in std_logic;
          ce    : in std_logic;
          d     : in std_logic_vector(width-1 downto 0);
          q     : out std_logic_vector(width-1 downto 0));
end srlc33e;

architecture structural of srlc33e is

    component SRLC32E
        port (D   : in STD_ULOGIC;
              CE  : in STD_ULOGIC;
              CLK : in STD_ULOGIC;
              A   : in std_logic_vector(4 downto 0);
              Q   : out STD_ULOGIC);
    end component;
    attribute syn_black_box of SRLC32E : component is true;
    attribute fpga_dont_touch of SRLC32E : component is "true";

    component FDE
        port(
            Q  :        out   STD_ULOGIC;
            D  :        in    STD_ULOGIC;
            C  :        in    STD_ULOGIC;
            CE :        in    STD_ULOGIC);
    end component;
    attribute syn_black_box of FDE : component is true;
    attribute fpga_dont_touch of FDE : component is "true";


    constant a : std_logic_vector(4 downto 0) :=
        integer_to_std_logic_vector(latency-2,5,xlSigned);
    signal d_delayed : std_logic_vector(width-1 downto 0);
    signal srlc32_out : std_logic_vector(width-1 downto 0);

begin
    d_delayed <= d after 200 ps;

    reg_array : for i in 0 to width-1 generate
        srlc32_used: if latency > 1 generate
            u1 : srlc32e port map(clk => clk,
                                 d => d_delayed(i),
                                 q => srlc32_out(i),
                                 ce => ce,
                                 a  => a);
        end generate;
        srlc32_not_used: if latency <= 1 generate
            srlc32_out(i) <= d_delayed(i);
        end generate;

        fde_used: if latency /= 0  generate
            u2 : fde port map(c => clk,
                              d => srlc32_out(i),
                              q => q(i),
                              ce => ce);
        end generate;
        fde_not_used: if latency = 0  generate
            q(i) <= srlc32_out(i);
        end generate;

    end generate;
 end structural;


