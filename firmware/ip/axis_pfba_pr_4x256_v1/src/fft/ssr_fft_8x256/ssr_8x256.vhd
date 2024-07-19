-- Generated from Simulink block ssr_8x256/Vector FFT/Scalar2Vector
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_scalar2vector is
  port (
    i : in std_logic_vector( 432-1 downto 0 );
    o_1 : out std_logic_vector( 54-1 downto 0 );
    o_2 : out std_logic_vector( 54-1 downto 0 );
    o_3 : out std_logic_vector( 54-1 downto 0 );
    o_4 : out std_logic_vector( 54-1 downto 0 );
    o_5 : out std_logic_vector( 54-1 downto 0 );
    o_6 : out std_logic_vector( 54-1 downto 0 );
    o_7 : out std_logic_vector( 54-1 downto 0 );
    o_8 : out std_logic_vector( 54-1 downto 0 )
  );
end ssr_8x256_scalar2vector;
architecture structural of ssr_8x256_scalar2vector is 
  signal slice5_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice1_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice3_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice4_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 54-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_o_net : std_logic_vector( 432-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 54-1 downto 0 );
begin
  o_1 <= slice0_y_net;
  o_2 <= slice1_y_net;
  o_3 <= slice2_y_net;
  o_4 <= slice3_y_net;
  o_5 <= slice4_y_net;
  o_6 <= slice5_y_net;
  o_7 <= slice6_y_net;
  o_8 <= slice7_y_net;
  test_systolicfft_vhdl_black_box_o_net <= i;
  slice0 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 53,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice0_y_net
  );
  slice1 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 54,
    new_msb => 107,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice1_y_net
  );
  slice2 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 108,
    new_msb => 161,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice2_y_net
  );
  slice3 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 162,
    new_msb => 215,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice3_y_net
  );
  slice4 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 216,
    new_msb => 269,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice4_y_net
  );
  slice5 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 270,
    new_msb => 323,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice5_y_net
  );
  slice6 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 324,
    new_msb => 377,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice6_y_net
  );
  slice7 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 378,
    new_msb => 431,
    x_width => 432,
    y_width => 54
  )
  port map (
    x => test_systolicfft_vhdl_black_box_o_net,
    y => slice7_y_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Concat
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_concat is
  port (
    hi_1 : in std_logic_vector( 16-1 downto 0 );
    lo_1 : in std_logic_vector( 16-1 downto 0 );
    hi_2 : in std_logic_vector( 16-1 downto 0 );
    hi_3 : in std_logic_vector( 16-1 downto 0 );
    hi_4 : in std_logic_vector( 16-1 downto 0 );
    hi_5 : in std_logic_vector( 16-1 downto 0 );
    hi_6 : in std_logic_vector( 16-1 downto 0 );
    hi_7 : in std_logic_vector( 16-1 downto 0 );
    hi_8 : in std_logic_vector( 16-1 downto 0 );
    lo_2 : in std_logic_vector( 16-1 downto 0 );
    lo_3 : in std_logic_vector( 16-1 downto 0 );
    lo_4 : in std_logic_vector( 16-1 downto 0 );
    lo_5 : in std_logic_vector( 16-1 downto 0 );
    lo_6 : in std_logic_vector( 16-1 downto 0 );
    lo_7 : in std_logic_vector( 16-1 downto 0 );
    lo_8 : in std_logic_vector( 16-1 downto 0 );
    out_1 : out std_logic_vector( 32-1 downto 0 );
    out_2 : out std_logic_vector( 32-1 downto 0 );
    out_3 : out std_logic_vector( 32-1 downto 0 );
    out_4 : out std_logic_vector( 32-1 downto 0 );
    out_5 : out std_logic_vector( 32-1 downto 0 );
    out_6 : out std_logic_vector( 32-1 downto 0 );
    out_7 : out std_logic_vector( 32-1 downto 0 );
    out_8 : out std_logic_vector( 32-1 downto 0 )
  );
end ssr_8x256_vector_concat;
architecture structural of ssr_8x256_vector_concat is 
  signal reinterpret0_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal concat4_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat0_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret0_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal concat1_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat5_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret2_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret3_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret6_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret7_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal concat7_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret4_output_port_net_x0 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal concat2_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat3_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat6_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 16-1 downto 0 );
begin
  out_1 <= concat0_y_net;
  out_2 <= concat1_y_net;
  out_3 <= concat2_y_net;
  out_4 <= concat3_y_net;
  out_5 <= concat4_y_net;
  out_6 <= concat5_y_net;
  out_7 <= concat6_y_net;
  out_8 <= concat7_y_net;
  reinterpret0_output_port_net_x0 <= hi_1;
  reinterpret0_output_port_net <= lo_1;
  reinterpret1_output_port_net_x0 <= hi_2;
  reinterpret2_output_port_net_x0 <= hi_3;
  reinterpret3_output_port_net_x0 <= hi_4;
  reinterpret4_output_port_net_x0 <= hi_5;
  reinterpret5_output_port_net_x0 <= hi_6;
  reinterpret6_output_port_net_x0 <= hi_7;
  reinterpret7_output_port_net_x0 <= hi_8;
  reinterpret1_output_port_net <= lo_2;
  reinterpret2_output_port_net <= lo_3;
  reinterpret3_output_port_net <= lo_4;
  reinterpret4_output_port_net <= lo_5;
  reinterpret5_output_port_net <= lo_6;
  reinterpret6_output_port_net <= lo_7;
  reinterpret7_output_port_net <= lo_8;
  concat0 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret0_output_port_net_x0,
    in1 => reinterpret0_output_port_net,
    y => concat0_y_net
  );
  concat1 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret1_output_port_net_x0,
    in1 => reinterpret1_output_port_net,
    y => concat1_y_net
  );
  concat2 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret2_output_port_net_x0,
    in1 => reinterpret2_output_port_net,
    y => concat2_y_net
  );
  concat3 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret3_output_port_net_x0,
    in1 => reinterpret3_output_port_net,
    y => concat3_y_net
  );
  concat4 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret4_output_port_net_x0,
    in1 => reinterpret4_output_port_net,
    y => concat4_y_net
  );
  concat5 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret5_output_port_net_x0,
    in1 => reinterpret5_output_port_net,
    y => concat5_y_net
  );
  concat6 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret6_output_port_net_x0,
    in1 => reinterpret6_output_port_net,
    y => concat6_y_net
  );
  concat7 : entity xil_defaultlib.sysgen_concat_6128f842cc 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => reinterpret7_output_port_net_x0,
    in1 => reinterpret7_output_port_net,
    y => concat7_y_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Delay
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_delay is
  port (
    d_1 : in std_logic_vector( 32-1 downto 0 );
    d_2 : in std_logic_vector( 32-1 downto 0 );
    d_3 : in std_logic_vector( 32-1 downto 0 );
    d_4 : in std_logic_vector( 32-1 downto 0 );
    d_5 : in std_logic_vector( 32-1 downto 0 );
    d_6 : in std_logic_vector( 32-1 downto 0 );
    d_7 : in std_logic_vector( 32-1 downto 0 );
    d_8 : in std_logic_vector( 32-1 downto 0 );
    clk_1 : in std_logic;
    ce_1 : in std_logic;
    q_1 : out std_logic_vector( 32-1 downto 0 );
    q_2 : out std_logic_vector( 32-1 downto 0 );
    q_3 : out std_logic_vector( 32-1 downto 0 );
    q_4 : out std_logic_vector( 32-1 downto 0 );
    q_5 : out std_logic_vector( 32-1 downto 0 );
    q_6 : out std_logic_vector( 32-1 downto 0 );
    q_7 : out std_logic_vector( 32-1 downto 0 );
    q_8 : out std_logic_vector( 32-1 downto 0 )
  );
end ssr_8x256_vector_delay;
architecture structural of ssr_8x256_vector_delay is 
  signal delay0_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay2_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay1_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay3_q_net : std_logic_vector( 32-1 downto 0 );
  signal concat0_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat4_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat1_y_net : std_logic_vector( 32-1 downto 0 );
  signal ce_net : std_logic;
  signal delay5_q_net : std_logic_vector( 32-1 downto 0 );
  signal concat5_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat6_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat7_y_net : std_logic_vector( 32-1 downto 0 );
  signal clk_net : std_logic;
  signal delay7_q_net : std_logic_vector( 32-1 downto 0 );
  signal concat3_y_net : std_logic_vector( 32-1 downto 0 );
  signal delay4_q_net : std_logic_vector( 32-1 downto 0 );
  signal concat2_y_net : std_logic_vector( 32-1 downto 0 );
  signal delay6_q_net : std_logic_vector( 32-1 downto 0 );
begin
  q_1 <= delay0_q_net;
  q_2 <= delay1_q_net;
  q_3 <= delay2_q_net;
  q_4 <= delay3_q_net;
  q_5 <= delay4_q_net;
  q_6 <= delay5_q_net;
  q_7 <= delay6_q_net;
  q_8 <= delay7_q_net;
  concat0_y_net <= d_1;
  concat1_y_net <= d_2;
  concat2_y_net <= d_3;
  concat3_y_net <= d_4;
  concat4_y_net <= d_5;
  concat5_y_net <= d_6;
  concat6_y_net <= d_7;
  concat7_y_net <= d_8;
  clk_net <= clk_1;
  ce_net <= ce_1;
  delay0 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat0_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay0_q_net
  );
  delay1 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat1_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay1_q_net
  );
  delay2 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat2_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay2_q_net
  );
  delay3 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat3_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay3_q_net
  );
  delay4 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat4_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay4_q_net
  );
  delay5 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat5_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay5_q_net
  );
  delay6 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat6_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay6_q_net
  );
  delay7 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 32
  )
  port map (
    en => '1',
    rst => '0',
    d => concat7_y_net,
    clk => clk_net,
    ce => ce_net,
    q => delay7_q_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Reinterpret
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_reinterpret is
  port (
    in_1 : in std_logic_vector( 16-1 downto 0 );
    in_2 : in std_logic_vector( 16-1 downto 0 );
    in_3 : in std_logic_vector( 16-1 downto 0 );
    in_4 : in std_logic_vector( 16-1 downto 0 );
    in_5 : in std_logic_vector( 16-1 downto 0 );
    in_6 : in std_logic_vector( 16-1 downto 0 );
    in_7 : in std_logic_vector( 16-1 downto 0 );
    in_8 : in std_logic_vector( 16-1 downto 0 );
    out_1 : out std_logic_vector( 16-1 downto 0 );
    out_2 : out std_logic_vector( 16-1 downto 0 );
    out_3 : out std_logic_vector( 16-1 downto 0 );
    out_4 : out std_logic_vector( 16-1 downto 0 );
    out_5 : out std_logic_vector( 16-1 downto 0 );
    out_6 : out std_logic_vector( 16-1 downto 0 );
    out_7 : out std_logic_vector( 16-1 downto 0 );
    out_8 : out std_logic_vector( 16-1 downto 0 )
  );
end ssr_8x256_vector_reinterpret;
architecture structural of ssr_8x256_vector_reinterpret is 
  signal reinterpret4_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_1_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_3_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_7_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_2_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_5_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_0_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 16-1 downto 0 );
begin
  out_1 <= reinterpret0_output_port_net;
  out_2 <= reinterpret1_output_port_net;
  out_3 <= reinterpret2_output_port_net;
  out_4 <= reinterpret3_output_port_net;
  out_5 <= reinterpret4_output_port_net;
  out_6 <= reinterpret5_output_port_net;
  out_7 <= reinterpret6_output_port_net;
  out_8 <= reinterpret7_output_port_net;
  i_re_0_net <= in_1;
  i_re_1_net <= in_2;
  i_re_2_net <= in_3;
  i_re_3_net <= in_4;
  i_re_4_net <= in_5;
  i_re_5_net <= in_6;
  i_re_6_net <= in_7;
  i_re_7_net <= in_8;
  reinterpret0 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_0_net,
    output_port => reinterpret0_output_port_net
  );
  reinterpret1 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_1_net,
    output_port => reinterpret1_output_port_net
  );
  reinterpret2 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_2_net,
    output_port => reinterpret2_output_port_net
  );
  reinterpret3 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_3_net,
    output_port => reinterpret3_output_port_net
  );
  reinterpret4 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_4_net,
    output_port => reinterpret4_output_port_net
  );
  reinterpret5 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_5_net,
    output_port => reinterpret5_output_port_net
  );
  reinterpret6 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_6_net,
    output_port => reinterpret6_output_port_net
  );
  reinterpret7 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_re_7_net,
    output_port => reinterpret7_output_port_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Reinterpret1
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_reinterpret1 is
  port (
    in_1 : in std_logic_vector( 16-1 downto 0 );
    in_2 : in std_logic_vector( 16-1 downto 0 );
    in_3 : in std_logic_vector( 16-1 downto 0 );
    in_4 : in std_logic_vector( 16-1 downto 0 );
    in_5 : in std_logic_vector( 16-1 downto 0 );
    in_6 : in std_logic_vector( 16-1 downto 0 );
    in_7 : in std_logic_vector( 16-1 downto 0 );
    in_8 : in std_logic_vector( 16-1 downto 0 );
    out_1 : out std_logic_vector( 16-1 downto 0 );
    out_2 : out std_logic_vector( 16-1 downto 0 );
    out_3 : out std_logic_vector( 16-1 downto 0 );
    out_4 : out std_logic_vector( 16-1 downto 0 );
    out_5 : out std_logic_vector( 16-1 downto 0 );
    out_6 : out std_logic_vector( 16-1 downto 0 );
    out_7 : out std_logic_vector( 16-1 downto 0 );
    out_8 : out std_logic_vector( 16-1 downto 0 )
  );
end ssr_8x256_vector_reinterpret1;
architecture structural of ssr_8x256_vector_reinterpret1 is 
  signal reinterpret3_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_2_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_5_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_0_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_1_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_7_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 16-1 downto 0 );
begin
  out_1 <= reinterpret0_output_port_net;
  out_2 <= reinterpret1_output_port_net;
  out_3 <= reinterpret2_output_port_net;
  out_4 <= reinterpret3_output_port_net;
  out_5 <= reinterpret4_output_port_net;
  out_6 <= reinterpret5_output_port_net;
  out_7 <= reinterpret6_output_port_net;
  out_8 <= reinterpret7_output_port_net;
  i_im_0_net <= in_1;
  i_im_1_net <= in_2;
  i_im_2_net <= in_3;
  i_im_3_net <= in_4;
  i_im_4_net <= in_5;
  i_im_5_net <= in_6;
  i_im_6_net <= in_7;
  i_im_7_net <= in_8;
  reinterpret0 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_0_net,
    output_port => reinterpret0_output_port_net
  );
  reinterpret1 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_1_net,
    output_port => reinterpret1_output_port_net
  );
  reinterpret2 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_2_net,
    output_port => reinterpret2_output_port_net
  );
  reinterpret3 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_3_net,
    output_port => reinterpret3_output_port_net
  );
  reinterpret4 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_4_net,
    output_port => reinterpret4_output_port_net
  );
  reinterpret5 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_5_net,
    output_port => reinterpret5_output_port_net
  );
  reinterpret6 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_6_net,
    output_port => reinterpret6_output_port_net
  );
  reinterpret7 : entity xil_defaultlib.sysgen_reinterpret_3bad6996c0 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => i_im_7_net,
    output_port => reinterpret7_output_port_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Reinterpret2
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_reinterpret2 is
  port (
    in_1 : in std_logic_vector( 27-1 downto 0 );
    in_2 : in std_logic_vector( 27-1 downto 0 );
    in_3 : in std_logic_vector( 27-1 downto 0 );
    in_4 : in std_logic_vector( 27-1 downto 0 );
    in_5 : in std_logic_vector( 27-1 downto 0 );
    in_6 : in std_logic_vector( 27-1 downto 0 );
    in_7 : in std_logic_vector( 27-1 downto 0 );
    in_8 : in std_logic_vector( 27-1 downto 0 );
    out_1 : out std_logic_vector( 27-1 downto 0 );
    out_2 : out std_logic_vector( 27-1 downto 0 );
    out_3 : out std_logic_vector( 27-1 downto 0 );
    out_4 : out std_logic_vector( 27-1 downto 0 );
    out_5 : out std_logic_vector( 27-1 downto 0 );
    out_6 : out std_logic_vector( 27-1 downto 0 );
    out_7 : out std_logic_vector( 27-1 downto 0 );
    out_8 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_vector_reinterpret2;
architecture structural of ssr_8x256_vector_reinterpret2 is 
  signal slice1_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice3_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal slice4_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal slice5_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 27-1 downto 0 );
begin
  out_1 <= reinterpret0_output_port_net;
  out_2 <= reinterpret1_output_port_net;
  out_3 <= reinterpret2_output_port_net;
  out_4 <= reinterpret3_output_port_net;
  out_5 <= reinterpret4_output_port_net;
  out_6 <= reinterpret5_output_port_net;
  out_7 <= reinterpret6_output_port_net;
  out_8 <= reinterpret7_output_port_net;
  slice0_y_net <= in_1;
  slice1_y_net <= in_2;
  slice2_y_net <= in_3;
  slice3_y_net <= in_4;
  slice4_y_net <= in_5;
  slice5_y_net <= in_6;
  slice6_y_net <= in_7;
  slice7_y_net <= in_8;
  reinterpret0 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice0_y_net,
    output_port => reinterpret0_output_port_net
  );
  reinterpret1 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice1_y_net,
    output_port => reinterpret1_output_port_net
  );
  reinterpret2 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice2_y_net,
    output_port => reinterpret2_output_port_net
  );
  reinterpret3 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice3_y_net,
    output_port => reinterpret3_output_port_net
  );
  reinterpret4 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice4_y_net,
    output_port => reinterpret4_output_port_net
  );
  reinterpret5 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice5_y_net,
    output_port => reinterpret5_output_port_net
  );
  reinterpret6 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice6_y_net,
    output_port => reinterpret6_output_port_net
  );
  reinterpret7 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice7_y_net,
    output_port => reinterpret7_output_port_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Reinterpret3
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_reinterpret3 is
  port (
    in_1 : in std_logic_vector( 27-1 downto 0 );
    in_2 : in std_logic_vector( 27-1 downto 0 );
    in_3 : in std_logic_vector( 27-1 downto 0 );
    in_4 : in std_logic_vector( 27-1 downto 0 );
    in_5 : in std_logic_vector( 27-1 downto 0 );
    in_6 : in std_logic_vector( 27-1 downto 0 );
    in_7 : in std_logic_vector( 27-1 downto 0 );
    in_8 : in std_logic_vector( 27-1 downto 0 );
    out_1 : out std_logic_vector( 27-1 downto 0 );
    out_2 : out std_logic_vector( 27-1 downto 0 );
    out_3 : out std_logic_vector( 27-1 downto 0 );
    out_4 : out std_logic_vector( 27-1 downto 0 );
    out_5 : out std_logic_vector( 27-1 downto 0 );
    out_6 : out std_logic_vector( 27-1 downto 0 );
    out_7 : out std_logic_vector( 27-1 downto 0 );
    out_8 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_vector_reinterpret3;
architecture structural of ssr_8x256_vector_reinterpret3 is 
  signal slice3_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice4_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice5_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal slice1_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 27-1 downto 0 );
begin
  out_1 <= reinterpret0_output_port_net;
  out_2 <= reinterpret1_output_port_net;
  out_3 <= reinterpret2_output_port_net;
  out_4 <= reinterpret3_output_port_net;
  out_5 <= reinterpret4_output_port_net;
  out_6 <= reinterpret5_output_port_net;
  out_7 <= reinterpret6_output_port_net;
  out_8 <= reinterpret7_output_port_net;
  slice0_y_net <= in_1;
  slice1_y_net <= in_2;
  slice2_y_net <= in_3;
  slice3_y_net <= in_4;
  slice4_y_net <= in_5;
  slice5_y_net <= in_6;
  slice6_y_net <= in_7;
  slice7_y_net <= in_8;
  reinterpret0 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice0_y_net,
    output_port => reinterpret0_output_port_net
  );
  reinterpret1 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice1_y_net,
    output_port => reinterpret1_output_port_net
  );
  reinterpret2 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice2_y_net,
    output_port => reinterpret2_output_port_net
  );
  reinterpret3 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice3_y_net,
    output_port => reinterpret3_output_port_net
  );
  reinterpret4 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice4_y_net,
    output_port => reinterpret4_output_port_net
  );
  reinterpret5 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice5_y_net,
    output_port => reinterpret5_output_port_net
  );
  reinterpret6 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice6_y_net,
    output_port => reinterpret6_output_port_net
  );
  reinterpret7 : entity xil_defaultlib.sysgen_reinterpret_9cd5a6908e 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    input_port => slice7_y_net,
    output_port => reinterpret7_output_port_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Slice Im
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_slice_im is
  port (
    in_1 : in std_logic_vector( 54-1 downto 0 );
    in_2 : in std_logic_vector( 54-1 downto 0 );
    in_3 : in std_logic_vector( 54-1 downto 0 );
    in_4 : in std_logic_vector( 54-1 downto 0 );
    in_5 : in std_logic_vector( 54-1 downto 0 );
    in_6 : in std_logic_vector( 54-1 downto 0 );
    in_7 : in std_logic_vector( 54-1 downto 0 );
    in_8 : in std_logic_vector( 54-1 downto 0 );
    out_1 : out std_logic_vector( 27-1 downto 0 );
    out_2 : out std_logic_vector( 27-1 downto 0 );
    out_3 : out std_logic_vector( 27-1 downto 0 );
    out_4 : out std_logic_vector( 27-1 downto 0 );
    out_5 : out std_logic_vector( 27-1 downto 0 );
    out_6 : out std_logic_vector( 27-1 downto 0 );
    out_7 : out std_logic_vector( 27-1 downto 0 );
    out_8 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_vector_slice_im;
architecture structural of ssr_8x256_vector_slice_im is 
  signal slice4_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice4_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice1_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice6_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice5_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice5_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice0_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice7_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice3_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice1_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice3_y_net : std_logic_vector( 54-1 downto 0 );
begin
  out_1 <= slice0_y_net_x0;
  out_2 <= slice1_y_net_x0;
  out_3 <= slice2_y_net_x0;
  out_4 <= slice3_y_net_x0;
  out_5 <= slice4_y_net_x0;
  out_6 <= slice5_y_net_x0;
  out_7 <= slice6_y_net_x0;
  out_8 <= slice7_y_net_x0;
  slice0_y_net <= in_1;
  slice1_y_net <= in_2;
  slice2_y_net <= in_3;
  slice3_y_net <= in_4;
  slice4_y_net <= in_5;
  slice5_y_net <= in_6;
  slice6_y_net <= in_7;
  slice7_y_net <= in_8;
  slice0 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice0_y_net,
    y => slice0_y_net_x0
  );
  slice1 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice1_y_net,
    y => slice1_y_net_x0
  );
  slice2 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice2_y_net,
    y => slice2_y_net_x0
  );
  slice3 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice3_y_net,
    y => slice3_y_net_x0
  );
  slice4 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice4_y_net,
    y => slice4_y_net_x0
  );
  slice5 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice5_y_net,
    y => slice5_y_net_x0
  );
  slice6 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice6_y_net,
    y => slice6_y_net_x0
  );
  slice7 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 27,
    new_msb => 53,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice7_y_net,
    y => slice7_y_net_x0
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector Slice Re
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_slice_re is
  port (
    in_1 : in std_logic_vector( 54-1 downto 0 );
    in_2 : in std_logic_vector( 54-1 downto 0 );
    in_3 : in std_logic_vector( 54-1 downto 0 );
    in_4 : in std_logic_vector( 54-1 downto 0 );
    in_5 : in std_logic_vector( 54-1 downto 0 );
    in_6 : in std_logic_vector( 54-1 downto 0 );
    in_7 : in std_logic_vector( 54-1 downto 0 );
    in_8 : in std_logic_vector( 54-1 downto 0 );
    out_1 : out std_logic_vector( 27-1 downto 0 );
    out_2 : out std_logic_vector( 27-1 downto 0 );
    out_3 : out std_logic_vector( 27-1 downto 0 );
    out_4 : out std_logic_vector( 27-1 downto 0 );
    out_5 : out std_logic_vector( 27-1 downto 0 );
    out_6 : out std_logic_vector( 27-1 downto 0 );
    out_7 : out std_logic_vector( 27-1 downto 0 );
    out_8 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_vector_slice_re;
architecture structural of ssr_8x256_vector_slice_re is 
  signal slice0_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice1_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice4_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice3_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice3_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice7_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice1_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice6_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice5_y_net : std_logic_vector( 54-1 downto 0 );
  signal slice5_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice4_y_net : std_logic_vector( 54-1 downto 0 );
begin
  out_1 <= slice0_y_net_x0;
  out_2 <= slice1_y_net_x0;
  out_3 <= slice2_y_net_x0;
  out_4 <= slice3_y_net_x0;
  out_5 <= slice4_y_net_x0;
  out_6 <= slice5_y_net_x0;
  out_7 <= slice6_y_net_x0;
  out_8 <= slice7_y_net_x0;
  slice0_y_net <= in_1;
  slice1_y_net <= in_2;
  slice2_y_net <= in_3;
  slice3_y_net <= in_4;
  slice4_y_net <= in_5;
  slice5_y_net <= in_6;
  slice6_y_net <= in_7;
  slice7_y_net <= in_8;
  slice0 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice0_y_net,
    y => slice0_y_net_x0
  );
  slice1 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice1_y_net,
    y => slice1_y_net_x0
  );
  slice2 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice2_y_net,
    y => slice2_y_net_x0
  );
  slice3 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice3_y_net,
    y => slice3_y_net_x0
  );
  slice4 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice4_y_net,
    y => slice4_y_net_x0
  );
  slice5 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice5_y_net,
    y => slice5_y_net_x0
  );
  slice6 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice6_y_net,
    y => slice6_y_net_x0
  );
  slice7 : entity xil_defaultlib.ssr_8x256_xlslice 
  generic map (
    new_lsb => 0,
    new_msb => 26,
    x_width => 54,
    y_width => 27
  )
  port map (
    x => slice7_y_net,
    y => slice7_y_net_x0
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT/Vector2Scalar
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector2scalar is
  port (
    i_1 : in std_logic_vector( 32-1 downto 0 );
    i_2 : in std_logic_vector( 32-1 downto 0 );
    i_3 : in std_logic_vector( 32-1 downto 0 );
    i_4 : in std_logic_vector( 32-1 downto 0 );
    i_5 : in std_logic_vector( 32-1 downto 0 );
    i_6 : in std_logic_vector( 32-1 downto 0 );
    i_7 : in std_logic_vector( 32-1 downto 0 );
    i_8 : in std_logic_vector( 32-1 downto 0 );
    o : out std_logic_vector( 256-1 downto 0 )
  );
end ssr_8x256_vector2scalar;
architecture structural of ssr_8x256_vector2scalar is 
  signal concat1_y_net : std_logic_vector( 256-1 downto 0 );
  signal delay0_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay1_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay3_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay4_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay2_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay5_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay7_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay6_q_net : std_logic_vector( 32-1 downto 0 );
begin
  o <= concat1_y_net;
  delay0_q_net <= i_1;
  delay1_q_net <= i_2;
  delay2_q_net <= i_3;
  delay3_q_net <= i_4;
  delay4_q_net <= i_5;
  delay5_q_net <= i_6;
  delay6_q_net <= i_7;
  delay7_q_net <= i_8;
  concat1 : entity xil_defaultlib.sysgen_concat_c6ccfb3c89 
  port map (
    clk => '0',
    ce => '0',
    clr => '0',
    in0 => delay7_q_net,
    in1 => delay6_q_net,
    in2 => delay5_q_net,
    in3 => delay4_q_net,
    in4 => delay3_q_net,
    in5 => delay2_q_net,
    in6 => delay1_q_net,
    in7 => delay0_q_net,
    y => concat1_y_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/Vector FFT
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_vector_fft is
  port (
    i_re_1 : in std_logic_vector( 16-1 downto 0 );
    i_im_1 : in std_logic_vector( 16-1 downto 0 );
    vi : in std_logic_vector( 1-1 downto 0 );
    si : in std_logic_vector( 8-1 downto 0 );
    i_re_2 : in std_logic_vector( 16-1 downto 0 );
    i_re_3 : in std_logic_vector( 16-1 downto 0 );
    i_re_4 : in std_logic_vector( 16-1 downto 0 );
    i_re_5 : in std_logic_vector( 16-1 downto 0 );
    i_re_6 : in std_logic_vector( 16-1 downto 0 );
    i_re_7 : in std_logic_vector( 16-1 downto 0 );
    i_re_8 : in std_logic_vector( 16-1 downto 0 );
    i_im_2 : in std_logic_vector( 16-1 downto 0 );
    i_im_3 : in std_logic_vector( 16-1 downto 0 );
    i_im_4 : in std_logic_vector( 16-1 downto 0 );
    i_im_5 : in std_logic_vector( 16-1 downto 0 );
    i_im_6 : in std_logic_vector( 16-1 downto 0 );
    i_im_7 : in std_logic_vector( 16-1 downto 0 );
    i_im_8 : in std_logic_vector( 16-1 downto 0 );
    clk_1 : in std_logic;
    ce_1 : in std_logic;
    o_re_1 : out std_logic_vector( 27-1 downto 0 );
    o_im_1 : out std_logic_vector( 27-1 downto 0 );
    vo : out std_logic;
    so : out std_logic_vector( 8-1 downto 0 );
    o_re_2 : out std_logic_vector( 27-1 downto 0 );
    o_re_3 : out std_logic_vector( 27-1 downto 0 );
    o_re_4 : out std_logic_vector( 27-1 downto 0 );
    o_re_5 : out std_logic_vector( 27-1 downto 0 );
    o_re_6 : out std_logic_vector( 27-1 downto 0 );
    o_re_7 : out std_logic_vector( 27-1 downto 0 );
    o_re_8 : out std_logic_vector( 27-1 downto 0 );
    o_im_2 : out std_logic_vector( 27-1 downto 0 );
    o_im_3 : out std_logic_vector( 27-1 downto 0 );
    o_im_4 : out std_logic_vector( 27-1 downto 0 );
    o_im_5 : out std_logic_vector( 27-1 downto 0 );
    o_im_6 : out std_logic_vector( 27-1 downto 0 );
    o_im_7 : out std_logic_vector( 27-1 downto 0 );
    o_im_8 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_vector_fft;
architecture structural of ssr_8x256_vector_fft is 
  signal i_im_0_net : std_logic_vector( 16-1 downto 0 );
  signal i_valid_net : std_logic_vector( 1-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret1_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret3_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret5_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret2_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal i_re_0_net : std_logic_vector( 16-1 downto 0 );
  signal i_scale_net : std_logic_vector( 8-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_so_net : std_logic_vector( 8-1 downto 0 );
  signal reinterpret4_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret0_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret6_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_vo_net : std_logic;
  signal reinterpret0_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret0_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal i_re_1_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_2_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret4_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal i_im_1_net : std_logic_vector( 16-1 downto 0 );
  signal concat6_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret6_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal i_re_3_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret2_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_o_net : std_logic_vector( 432-1 downto 0 );
  signal slice3_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal i_re_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_5_net : std_logic_vector( 16-1 downto 0 );
  signal slice5_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal i_im_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_4_net : std_logic_vector( 16-1 downto 0 );
  signal concat7_y_net : std_logic_vector( 32-1 downto 0 );
  signal i_re_7_net : std_logic_vector( 16-1 downto 0 );
  signal concat3_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret7_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal i_im_7_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret2_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret3_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal concat0_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret4_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal concat2_y_net : std_logic_vector( 32-1 downto 0 );
  signal reinterpret5_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal slice6_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal reinterpret6_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret7_output_port_net_x2 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret3_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net_x1 : std_logic_vector( 16-1 downto 0 );
  signal i_im_2_net : std_logic_vector( 16-1 downto 0 );
  signal ce_net : std_logic;
  signal slice4_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal slice0_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal concat1_y_net_x0 : std_logic_vector( 32-1 downto 0 );
  signal slice1_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal concat4_y_net : std_logic_vector( 32-1 downto 0 );
  signal concat5_y_net : std_logic_vector( 32-1 downto 0 );
  signal i_im_5_net : std_logic_vector( 16-1 downto 0 );
  signal slice2_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal clk_net : std_logic;
  signal slice7_y_net_x1 : std_logic_vector( 54-1 downto 0 );
  signal delay1_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice2_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice3_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice7_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice2_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice0_y_net : std_logic_vector( 27-1 downto 0 );
  signal delay_q_net : std_logic_vector( 1-1 downto 0 );
  signal delay2_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice0_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice4_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal delay0_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice1_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice5_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice5_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal delay5_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice6_y_net : std_logic_vector( 27-1 downto 0 );
  signal delay1_q_net_x0 : std_logic_vector( 8-1 downto 0 );
  signal delay4_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice1_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal delay3_q_net : std_logic_vector( 32-1 downto 0 );
  signal delay6_q_net : std_logic_vector( 32-1 downto 0 );
  signal slice7_y_net : std_logic_vector( 27-1 downto 0 );
  signal delay7_q_net : std_logic_vector( 32-1 downto 0 );
  signal concat1_y_net : std_logic_vector( 256-1 downto 0 );
  signal slice4_y_net : std_logic_vector( 27-1 downto 0 );
  signal slice3_y_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal slice6_y_net_x0 : std_logic_vector( 27-1 downto 0 );
begin
  o_re_1 <= reinterpret0_output_port_net_x0;
  o_im_1 <= reinterpret0_output_port_net;
  vo <= test_systolicfft_vhdl_black_box_vo_net;
  so <= test_systolicfft_vhdl_black_box_so_net;
  o_re_2 <= reinterpret1_output_port_net_x0;
  o_re_3 <= reinterpret2_output_port_net_x0;
  o_re_4 <= reinterpret3_output_port_net_x0;
  o_re_5 <= reinterpret4_output_port_net_x0;
  o_re_6 <= reinterpret5_output_port_net_x0;
  o_re_7 <= reinterpret6_output_port_net_x0;
  o_re_8 <= reinterpret7_output_port_net_x0;
  o_im_2 <= reinterpret1_output_port_net;
  o_im_3 <= reinterpret2_output_port_net;
  o_im_4 <= reinterpret3_output_port_net;
  o_im_5 <= reinterpret4_output_port_net;
  o_im_6 <= reinterpret5_output_port_net;
  o_im_7 <= reinterpret6_output_port_net;
  o_im_8 <= reinterpret7_output_port_net;
  i_re_0_net <= i_re_1;
  i_im_0_net <= i_im_1;
  i_valid_net <= vi;
  i_scale_net <= si;
  i_re_1_net <= i_re_2;
  i_re_2_net <= i_re_3;
  i_re_3_net <= i_re_4;
  i_re_4_net <= i_re_5;
  i_re_5_net <= i_re_6;
  i_re_6_net <= i_re_7;
  i_re_7_net <= i_re_8;
  i_im_1_net <= i_im_2;
  i_im_2_net <= i_im_3;
  i_im_3_net <= i_im_4;
  i_im_4_net <= i_im_5;
  i_im_5_net <= i_im_6;
  i_im_6_net <= i_im_7;
  i_im_7_net <= i_im_8;
  clk_net <= clk_1;
  ce_net <= ce_1;
  scalar2vector : entity xil_defaultlib.ssr_8x256_scalar2vector 
  port map (
    i => test_systolicfft_vhdl_black_box_o_net,
    o_1 => slice0_y_net_x1,
    o_2 => slice1_y_net_x1,
    o_3 => slice2_y_net_x1,
    o_4 => slice3_y_net_x1,
    o_5 => slice4_y_net_x1,
    o_6 => slice5_y_net_x1,
    o_7 => slice6_y_net_x1,
    o_8 => slice7_y_net_x1
  );
  vector_concat : entity xil_defaultlib.ssr_8x256_vector_concat 
  port map (
    hi_1 => reinterpret0_output_port_net_x1,
    lo_1 => reinterpret0_output_port_net_x2,
    hi_2 => reinterpret1_output_port_net_x1,
    hi_3 => reinterpret2_output_port_net_x1,
    hi_4 => reinterpret3_output_port_net_x1,
    hi_5 => reinterpret4_output_port_net_x1,
    hi_6 => reinterpret5_output_port_net_x1,
    hi_7 => reinterpret6_output_port_net_x1,
    hi_8 => reinterpret7_output_port_net_x1,
    lo_2 => reinterpret1_output_port_net_x2,
    lo_3 => reinterpret2_output_port_net_x2,
    lo_4 => reinterpret3_output_port_net_x2,
    lo_5 => reinterpret4_output_port_net_x2,
    lo_6 => reinterpret5_output_port_net_x2,
    lo_7 => reinterpret6_output_port_net_x2,
    lo_8 => reinterpret7_output_port_net_x2,
    out_1 => concat0_y_net,
    out_2 => concat1_y_net_x0,
    out_3 => concat2_y_net,
    out_4 => concat3_y_net,
    out_5 => concat4_y_net,
    out_6 => concat5_y_net,
    out_7 => concat6_y_net,
    out_8 => concat7_y_net
  );
  vector_delay : entity xil_defaultlib.ssr_8x256_vector_delay 
  port map (
    d_1 => concat0_y_net,
    d_2 => concat1_y_net_x0,
    d_3 => concat2_y_net,
    d_4 => concat3_y_net,
    d_5 => concat4_y_net,
    d_6 => concat5_y_net,
    d_7 => concat6_y_net,
    d_8 => concat7_y_net,
    clk_1 => clk_net,
    ce_1 => ce_net,
    q_1 => delay0_q_net,
    q_2 => delay1_q_net,
    q_3 => delay2_q_net,
    q_4 => delay3_q_net,
    q_5 => delay4_q_net,
    q_6 => delay5_q_net,
    q_7 => delay6_q_net,
    q_8 => delay7_q_net
  );
  vector_reinterpret : entity xil_defaultlib.ssr_8x256_vector_reinterpret 
  port map (
    in_1 => i_re_0_net,
    in_2 => i_re_1_net,
    in_3 => i_re_2_net,
    in_4 => i_re_3_net,
    in_5 => i_re_4_net,
    in_6 => i_re_5_net,
    in_7 => i_re_6_net,
    in_8 => i_re_7_net,
    out_1 => reinterpret0_output_port_net_x2,
    out_2 => reinterpret1_output_port_net_x2,
    out_3 => reinterpret2_output_port_net_x2,
    out_4 => reinterpret3_output_port_net_x2,
    out_5 => reinterpret4_output_port_net_x2,
    out_6 => reinterpret5_output_port_net_x2,
    out_7 => reinterpret6_output_port_net_x2,
    out_8 => reinterpret7_output_port_net_x2
  );
  vector_reinterpret1 : entity xil_defaultlib.ssr_8x256_vector_reinterpret1 
  port map (
    in_1 => i_im_0_net,
    in_2 => i_im_1_net,
    in_3 => i_im_2_net,
    in_4 => i_im_3_net,
    in_5 => i_im_4_net,
    in_6 => i_im_5_net,
    in_7 => i_im_6_net,
    in_8 => i_im_7_net,
    out_1 => reinterpret0_output_port_net_x1,
    out_2 => reinterpret1_output_port_net_x1,
    out_3 => reinterpret2_output_port_net_x1,
    out_4 => reinterpret3_output_port_net_x1,
    out_5 => reinterpret4_output_port_net_x1,
    out_6 => reinterpret5_output_port_net_x1,
    out_7 => reinterpret6_output_port_net_x1,
    out_8 => reinterpret7_output_port_net_x1
  );
  vector_reinterpret2 : entity xil_defaultlib.ssr_8x256_vector_reinterpret2 
  port map (
    in_1 => slice0_y_net,
    in_2 => slice1_y_net,
    in_3 => slice2_y_net,
    in_4 => slice3_y_net,
    in_5 => slice4_y_net,
    in_6 => slice5_y_net,
    in_7 => slice6_y_net,
    in_8 => slice7_y_net,
    out_1 => reinterpret0_output_port_net_x0,
    out_2 => reinterpret1_output_port_net_x0,
    out_3 => reinterpret2_output_port_net_x0,
    out_4 => reinterpret3_output_port_net_x0,
    out_5 => reinterpret4_output_port_net_x0,
    out_6 => reinterpret5_output_port_net_x0,
    out_7 => reinterpret6_output_port_net_x0,
    out_8 => reinterpret7_output_port_net_x0
  );
  vector_reinterpret3 : entity xil_defaultlib.ssr_8x256_vector_reinterpret3 
  port map (
    in_1 => slice0_y_net_x0,
    in_2 => slice1_y_net_x0,
    in_3 => slice2_y_net_x0,
    in_4 => slice3_y_net_x0,
    in_5 => slice4_y_net_x0,
    in_6 => slice5_y_net_x0,
    in_7 => slice6_y_net_x0,
    in_8 => slice7_y_net_x0,
    out_1 => reinterpret0_output_port_net,
    out_2 => reinterpret1_output_port_net,
    out_3 => reinterpret2_output_port_net,
    out_4 => reinterpret3_output_port_net,
    out_5 => reinterpret4_output_port_net,
    out_6 => reinterpret5_output_port_net,
    out_7 => reinterpret6_output_port_net,
    out_8 => reinterpret7_output_port_net
  );
  vector_slice_im : entity xil_defaultlib.ssr_8x256_vector_slice_im 
  port map (
    in_1 => slice0_y_net_x1,
    in_2 => slice1_y_net_x1,
    in_3 => slice2_y_net_x1,
    in_4 => slice3_y_net_x1,
    in_5 => slice4_y_net_x1,
    in_6 => slice5_y_net_x1,
    in_7 => slice6_y_net_x1,
    in_8 => slice7_y_net_x1,
    out_1 => slice0_y_net_x0,
    out_2 => slice1_y_net_x0,
    out_3 => slice2_y_net_x0,
    out_4 => slice3_y_net_x0,
    out_5 => slice4_y_net_x0,
    out_6 => slice5_y_net_x0,
    out_7 => slice6_y_net_x0,
    out_8 => slice7_y_net_x0
  );
  vector_slice_re : entity xil_defaultlib.ssr_8x256_vector_slice_re 
  port map (
    in_1 => slice0_y_net_x1,
    in_2 => slice1_y_net_x1,
    in_3 => slice2_y_net_x1,
    in_4 => slice3_y_net_x1,
    in_5 => slice4_y_net_x1,
    in_6 => slice5_y_net_x1,
    in_7 => slice6_y_net_x1,
    in_8 => slice7_y_net_x1,
    out_1 => slice0_y_net,
    out_2 => slice1_y_net,
    out_3 => slice2_y_net,
    out_4 => slice3_y_net,
    out_5 => slice4_y_net,
    out_6 => slice5_y_net,
    out_7 => slice6_y_net,
    out_8 => slice7_y_net
  );
  vector2scalar : entity xil_defaultlib.ssr_8x256_vector2scalar 
  port map (
    i_1 => delay0_q_net,
    i_2 => delay1_q_net,
    i_3 => delay2_q_net,
    i_4 => delay3_q_net,
    i_5 => delay4_q_net,
    i_6 => delay5_q_net,
    i_7 => delay6_q_net,
    i_8 => delay7_q_net,
    o => concat1_y_net
  );
  delay : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 1
  )
  port map (
    en => '1',
    rst => '0',
    d => i_valid_net,
    clk => clk_net,
    ce => ce_net,
    q => delay_q_net
  );
  delay1 : entity xil_defaultlib.ssr_8x256_xldelay 
  generic map (
    latency => 4,
    reg_retiming => 0,
    reset => 0,
    width => 8
  )
  port map (
    en => '1',
    rst => '0',
    d => i_scale_net,
    clk => clk_net,
    ce => ce_net,
    q => delay1_q_net_x0
  );
  test_systolicfft_vhdl_black_box : entity xil_defaultlib.WRAPPER_VECTOR_FFT_c48f0cd3f27fd6fdac4ed316c161272e 
  generic map (
    BRAM_THRESHOLD => 258,
    DSP48E => 2,
    I_high => -2,
    I_low => -17,
    L2N => 8,
    N => 256,
    O_high => 9,
    O_low => -17,
    SSR => 8,
    W_high => 1,
    W_low => -17
  )
  port map (
    i => concat1_y_net,
    vi => delay_q_net(0),
    si => delay1_q_net_x0,
    CLK => clk_net,
    CE => ce_net,
    o => test_systolicfft_vhdl_black_box_o_net,
    vo => test_systolicfft_vhdl_black_box_vo_net,
    so => test_systolicfft_vhdl_black_box_so_net
  );
end structural;
-- Generated from Simulink block ssr_8x256/i_im
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_i_im is
  port (
    i_im_0 : in std_logic_vector( 16-1 downto 0 );
    i_im_1 : in std_logic_vector( 16-1 downto 0 );
    i_im_2 : in std_logic_vector( 16-1 downto 0 );
    i_im_3 : in std_logic_vector( 16-1 downto 0 );
    i_im_4 : in std_logic_vector( 16-1 downto 0 );
    i_im_5 : in std_logic_vector( 16-1 downto 0 );
    i_im_6 : in std_logic_vector( 16-1 downto 0 );
    i_im_7 : in std_logic_vector( 16-1 downto 0 )
  );
end ssr_8x256_i_im;
architecture structural of ssr_8x256_i_im is 
  signal i_im_0_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_2_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_1_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_5_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_7_net : std_logic_vector( 16-1 downto 0 );
begin
  i_im_0_net <= i_im_0;
  i_im_1_net <= i_im_1;
  i_im_2_net <= i_im_2;
  i_im_3_net <= i_im_3;
  i_im_4_net <= i_im_4;
  i_im_5_net <= i_im_5;
  i_im_6_net <= i_im_6;
  i_im_7_net <= i_im_7;
end structural;
-- Generated from Simulink block ssr_8x256/i_re
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_i_re is
  port (
    i_re_0 : in std_logic_vector( 16-1 downto 0 );
    i_re_1 : in std_logic_vector( 16-1 downto 0 );
    i_re_2 : in std_logic_vector( 16-1 downto 0 );
    i_re_3 : in std_logic_vector( 16-1 downto 0 );
    i_re_4 : in std_logic_vector( 16-1 downto 0 );
    i_re_5 : in std_logic_vector( 16-1 downto 0 );
    i_re_6 : in std_logic_vector( 16-1 downto 0 );
    i_re_7 : in std_logic_vector( 16-1 downto 0 )
  );
end ssr_8x256_i_re;
architecture structural of ssr_8x256_i_re is 
  signal i_re_7_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_1_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_2_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_5_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_0_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_4_net : std_logic_vector( 16-1 downto 0 );
begin
  i_re_0_net <= i_re_0;
  i_re_1_net <= i_re_1;
  i_re_2_net <= i_re_2;
  i_re_3_net <= i_re_3;
  i_re_4_net <= i_re_4;
  i_re_5_net <= i_re_5;
  i_re_6_net <= i_re_6;
  i_re_7_net <= i_re_7;
end structural;
-- Generated from Simulink block ssr_8x256_struct
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_struct is
  port (
    i_scale : in std_logic_vector( 8-1 downto 0 );
    i_valid : in std_logic_vector( 1-1 downto 0 );
    i_im_0 : in std_logic_vector( 16-1 downto 0 );
    i_im_1 : in std_logic_vector( 16-1 downto 0 );
    i_im_2 : in std_logic_vector( 16-1 downto 0 );
    i_im_3 : in std_logic_vector( 16-1 downto 0 );
    i_im_4 : in std_logic_vector( 16-1 downto 0 );
    i_im_5 : in std_logic_vector( 16-1 downto 0 );
    i_im_6 : in std_logic_vector( 16-1 downto 0 );
    i_im_7 : in std_logic_vector( 16-1 downto 0 );
    i_re_0 : in std_logic_vector( 16-1 downto 0 );
    i_re_1 : in std_logic_vector( 16-1 downto 0 );
    i_re_2 : in std_logic_vector( 16-1 downto 0 );
    i_re_3 : in std_logic_vector( 16-1 downto 0 );
    i_re_4 : in std_logic_vector( 16-1 downto 0 );
    i_re_5 : in std_logic_vector( 16-1 downto 0 );
    i_re_6 : in std_logic_vector( 16-1 downto 0 );
    i_re_7 : in std_logic_vector( 16-1 downto 0 );
    clk_1 : in std_logic;
    ce_1 : in std_logic;
    o_scale : out std_logic_vector( 8-1 downto 0 );
    o_valid : out std_logic_vector( 1-1 downto 0 );
    o_im_0 : out std_logic_vector( 27-1 downto 0 );
    o_im_1 : out std_logic_vector( 27-1 downto 0 );
    o_im_2 : out std_logic_vector( 27-1 downto 0 );
    o_im_3 : out std_logic_vector( 27-1 downto 0 );
    o_im_4 : out std_logic_vector( 27-1 downto 0 );
    o_im_5 : out std_logic_vector( 27-1 downto 0 );
    o_im_6 : out std_logic_vector( 27-1 downto 0 );
    o_im_7 : out std_logic_vector( 27-1 downto 0 );
    o_re_0 : out std_logic_vector( 27-1 downto 0 );
    o_re_1 : out std_logic_vector( 27-1 downto 0 );
    o_re_2 : out std_logic_vector( 27-1 downto 0 );
    o_re_3 : out std_logic_vector( 27-1 downto 0 );
    o_re_4 : out std_logic_vector( 27-1 downto 0 );
    o_re_5 : out std_logic_vector( 27-1 downto 0 );
    o_re_6 : out std_logic_vector( 27-1 downto 0 );
    o_re_7 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256_struct;
architecture structural of ssr_8x256_struct is 
  signal i_im_6_net : std_logic_vector( 16-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_vo_net : std_logic_vector( 1-1 downto 0 );
  signal i_scale_net : std_logic_vector( 8-1 downto 0 );
  signal i_im_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_5_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_2_net : std_logic_vector( 16-1 downto 0 );
  signal test_systolicfft_vhdl_black_box_so_net : std_logic_vector( 8-1 downto 0 );
  signal i_re_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_4_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_2_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_5_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_6_net : std_logic_vector( 16-1 downto 0 );
  signal i_valid_net : std_logic_vector( 1-1 downto 0 );
  signal i_im_7_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_7_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret0_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal i_re_0_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret2_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal i_im_3_net : std_logic_vector( 16-1 downto 0 );
  signal i_re_1_net : std_logic_vector( 16-1 downto 0 );
  signal i_im_0_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret1_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal i_im_1_net : std_logic_vector( 16-1 downto 0 );
  signal reinterpret5_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret4_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret7_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret3_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal clk_net : std_logic;
  signal ce_net : std_logic;
  signal reinterpret6_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret1_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret4_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret0_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret5_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
  signal reinterpret3_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret6_output_port_net : std_logic_vector( 27-1 downto 0 );
  signal reinterpret2_output_port_net_x0 : std_logic_vector( 27-1 downto 0 );
begin
  i_scale_net <= i_scale;
  i_valid_net <= i_valid;
  o_scale <= test_systolicfft_vhdl_black_box_so_net;
  o_valid <= test_systolicfft_vhdl_black_box_vo_net;
  i_im_0_net <= i_im_0;
  i_im_1_net <= i_im_1;
  i_im_2_net <= i_im_2;
  i_im_3_net <= i_im_3;
  i_im_4_net <= i_im_4;
  i_im_5_net <= i_im_5;
  i_im_6_net <= i_im_6;
  i_im_7_net <= i_im_7;
  i_re_0_net <= i_re_0;
  i_re_1_net <= i_re_1;
  i_re_2_net <= i_re_2;
  i_re_3_net <= i_re_3;
  i_re_4_net <= i_re_4;
  i_re_5_net <= i_re_5;
  i_re_6_net <= i_re_6;
  i_re_7_net <= i_re_7;
  o_im_0 <= reinterpret0_output_port_net;
  o_im_1 <= reinterpret1_output_port_net;
  o_im_2 <= reinterpret2_output_port_net;
  o_im_3 <= reinterpret3_output_port_net;
  o_im_4 <= reinterpret4_output_port_net_x0;
  o_im_5 <= reinterpret5_output_port_net;
  o_im_6 <= reinterpret6_output_port_net;
  o_im_7 <= reinterpret7_output_port_net;
  o_re_0 <= reinterpret0_output_port_net_x0;
  o_re_1 <= reinterpret1_output_port_net_x0;
  o_re_2 <= reinterpret2_output_port_net_x0;
  o_re_3 <= reinterpret3_output_port_net_x0;
  o_re_4 <= reinterpret4_output_port_net;
  o_re_5 <= reinterpret5_output_port_net_x0;
  o_re_6 <= reinterpret6_output_port_net_x0;
  o_re_7 <= reinterpret7_output_port_net_x0;
  clk_net <= clk_1;
  ce_net <= ce_1;
  vector_fft : entity xil_defaultlib.ssr_8x256_vector_fft 
  port map (
    i_re_1 => i_re_0_net,
    i_im_1 => i_im_0_net,
    vi => i_valid_net,
    si => i_scale_net,
    i_re_2 => i_re_1_net,
    i_re_3 => i_re_2_net,
    i_re_4 => i_re_3_net,
    i_re_5 => i_re_4_net,
    i_re_6 => i_re_5_net,
    i_re_7 => i_re_6_net,
    i_re_8 => i_re_7_net,
    i_im_2 => i_im_1_net,
    i_im_3 => i_im_2_net,
    i_im_4 => i_im_3_net,
    i_im_5 => i_im_4_net,
    i_im_6 => i_im_5_net,
    i_im_7 => i_im_6_net,
    i_im_8 => i_im_7_net,
    clk_1 => clk_net,
    ce_1 => ce_net,
    o_re_1 => reinterpret0_output_port_net_x0,
    o_im_1 => reinterpret0_output_port_net,
    vo => test_systolicfft_vhdl_black_box_vo_net(0),
    so => test_systolicfft_vhdl_black_box_so_net,
    o_re_2 => reinterpret1_output_port_net_x0,
    o_re_3 => reinterpret2_output_port_net_x0,
    o_re_4 => reinterpret3_output_port_net_x0,
    o_re_5 => reinterpret4_output_port_net,
    o_re_6 => reinterpret5_output_port_net_x0,
    o_re_7 => reinterpret6_output_port_net_x0,
    o_re_8 => reinterpret7_output_port_net_x0,
    o_im_2 => reinterpret1_output_port_net,
    o_im_3 => reinterpret2_output_port_net,
    o_im_4 => reinterpret3_output_port_net,
    o_im_5 => reinterpret4_output_port_net_x0,
    o_im_6 => reinterpret5_output_port_net,
    o_im_7 => reinterpret6_output_port_net,
    o_im_8 => reinterpret7_output_port_net
  );
  i_im : entity xil_defaultlib.ssr_8x256_i_im 
  port map (
    i_im_0 => i_im_0_net,
    i_im_1 => i_im_1_net,
    i_im_2 => i_im_2_net,
    i_im_3 => i_im_3_net,
    i_im_4 => i_im_4_net,
    i_im_5 => i_im_5_net,
    i_im_6 => i_im_6_net,
    i_im_7 => i_im_7_net
  );
  i_re : entity xil_defaultlib.ssr_8x256_i_re 
  port map (
    i_re_0 => i_re_0_net,
    i_re_1 => i_re_1_net,
    i_re_2 => i_re_2_net,
    i_re_3 => i_re_3_net,
    i_re_4 => i_re_4_net,
    i_re_5 => i_re_5_net,
    i_re_6 => i_re_6_net,
    i_re_7 => i_re_7_net
  );
end structural;
-- Generated from Simulink block 
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256_default_clock_driver is
  port (
    ssr_8x256_sysclk : in std_logic;
    ssr_8x256_sysce : in std_logic;
    ssr_8x256_sysclr : in std_logic;
    ssr_8x256_clk1 : out std_logic;
    ssr_8x256_ce1 : out std_logic
  );
end ssr_8x256_default_clock_driver;
architecture structural of ssr_8x256_default_clock_driver is 
begin
  clockdriver : entity xil_defaultlib.xlclockdriver 
  generic map (
    period => 1,
    log_2_period => 1
  )
  port map (
    sysclk => ssr_8x256_sysclk,
    sysce => ssr_8x256_sysce,
    sysclr => ssr_8x256_sysclr,
    clk => ssr_8x256_clk1,
    ce => ssr_8x256_ce1
  );
end structural;
-- Generated from Simulink block 
library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;
entity ssr_8x256 is
  port (
    i_scale : in std_logic_vector( 8-1 downto 0 );
    i_valid : in std_logic_vector( 1-1 downto 0 );
    i_im_0 : in std_logic_vector( 16-1 downto 0 );
    i_im_1 : in std_logic_vector( 16-1 downto 0 );
    i_im_2 : in std_logic_vector( 16-1 downto 0 );
    i_im_3 : in std_logic_vector( 16-1 downto 0 );
    i_im_4 : in std_logic_vector( 16-1 downto 0 );
    i_im_5 : in std_logic_vector( 16-1 downto 0 );
    i_im_6 : in std_logic_vector( 16-1 downto 0 );
    i_im_7 : in std_logic_vector( 16-1 downto 0 );
    i_re_0 : in std_logic_vector( 16-1 downto 0 );
    i_re_1 : in std_logic_vector( 16-1 downto 0 );
    i_re_2 : in std_logic_vector( 16-1 downto 0 );
    i_re_3 : in std_logic_vector( 16-1 downto 0 );
    i_re_4 : in std_logic_vector( 16-1 downto 0 );
    i_re_5 : in std_logic_vector( 16-1 downto 0 );
    i_re_6 : in std_logic_vector( 16-1 downto 0 );
    i_re_7 : in std_logic_vector( 16-1 downto 0 );
    clk : in std_logic;
    o_scale : out std_logic_vector( 8-1 downto 0 );
    o_valid : out std_logic_vector( 1-1 downto 0 );
    o_im_0 : out std_logic_vector( 27-1 downto 0 );
    o_im_1 : out std_logic_vector( 27-1 downto 0 );
    o_im_2 : out std_logic_vector( 27-1 downto 0 );
    o_im_3 : out std_logic_vector( 27-1 downto 0 );
    o_im_4 : out std_logic_vector( 27-1 downto 0 );
    o_im_5 : out std_logic_vector( 27-1 downto 0 );
    o_im_6 : out std_logic_vector( 27-1 downto 0 );
    o_im_7 : out std_logic_vector( 27-1 downto 0 );
    o_re_0 : out std_logic_vector( 27-1 downto 0 );
    o_re_1 : out std_logic_vector( 27-1 downto 0 );
    o_re_2 : out std_logic_vector( 27-1 downto 0 );
    o_re_3 : out std_logic_vector( 27-1 downto 0 );
    o_re_4 : out std_logic_vector( 27-1 downto 0 );
    o_re_5 : out std_logic_vector( 27-1 downto 0 );
    o_re_6 : out std_logic_vector( 27-1 downto 0 );
    o_re_7 : out std_logic_vector( 27-1 downto 0 )
  );
end ssr_8x256;
architecture structural of ssr_8x256 is 
  attribute core_generation_info : string;
  attribute core_generation_info of structural : architecture is "ssr_8x256,sysgen_core_2019_2,{,compilation=HDL Netlist,block_icon_display=Default,family=zynquplusRFSOC,part=xczu28dr,speed=-2-e,package=ffvg1517,synthesis_language=vhdl,hdl_library=xil_defaultlib,synthesis_strategy=Vivado Synthesis Defaults,implementation_strategy=Vivado Implementation Defaults,testbench=0,interface_doc=0,ce_clr=0,clock_period=10,system_simulink_period=1,waveform_viewer=0,axilite_interface=0,ip_catalog_plugin=0,hwcosim_burst_mode=0,simulation_time=10,blackbox2=1,concat=9,delay=10,reinterpret=32,slice=24,}";
  signal clk_1_net : std_logic;
  signal ce_1_net : std_logic;
begin
  ssr_8x256_default_clock_driver : entity xil_defaultlib.ssr_8x256_default_clock_driver 
  port map (
    ssr_8x256_sysclk => clk,
    ssr_8x256_sysce => '1',
    ssr_8x256_sysclr => '0',
    ssr_8x256_clk1 => clk_1_net,
    ssr_8x256_ce1 => ce_1_net
  );
  ssr_8x256_struct : entity xil_defaultlib.ssr_8x256_struct 
  port map (
    i_scale => i_scale,
    i_valid => i_valid,
    i_im_0 => i_im_0,
    i_im_1 => i_im_1,
    i_im_2 => i_im_2,
    i_im_3 => i_im_3,
    i_im_4 => i_im_4,
    i_im_5 => i_im_5,
    i_im_6 => i_im_6,
    i_im_7 => i_im_7,
    i_re_0 => i_re_0,
    i_re_1 => i_re_1,
    i_re_2 => i_re_2,
    i_re_3 => i_re_3,
    i_re_4 => i_re_4,
    i_re_5 => i_re_5,
    i_re_6 => i_re_6,
    i_re_7 => i_re_7,
    clk_1 => clk_1_net,
    ce_1 => ce_1_net,
    o_scale => o_scale,
    o_valid => o_valid,
    o_im_0 => o_im_0,
    o_im_1 => o_im_1,
    o_im_2 => o_im_2,
    o_im_3 => o_im_3,
    o_im_4 => o_im_4,
    o_im_5 => o_im_5,
    o_im_6 => o_im_6,
    o_im_7 => o_im_7,
    o_re_0 => o_re_0,
    o_re_1 => o_re_1,
    o_re_2 => o_re_2,
    o_re_3 => o_re_3,
    o_re_4 => o_re_4,
    o_re_5 => o_re_5,
    o_re_6 => o_re_6,
    o_re_7 => o_re_7
  );
end structural;
