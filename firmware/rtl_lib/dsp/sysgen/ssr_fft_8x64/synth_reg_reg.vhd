library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- $Header: /devl/xcs/repo/env/Jobs/sysgen/src/xbs/hdl_pkg/synth_reg.vhd,v 1.2 2005/01/11 00:33:32 stroomer Exp $
----------------------------------------------------------------------------
--
--  Filename      : synth_reg_reg.vhd
--
--  Created       : 6/28/2013
--
--  Description   : splitted from synth_reg.vhd
--
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity synth_reg_reg is
    generic (width           : integer := 8;
             latency         : integer := 1);
    port (i       : in std_logic_vector(width-1 downto 0);
          ce      : in std_logic;
          clr     : in std_logic;       -- Not used since implemented w/ SRL16s
          clk     : in std_logic;
          o       : out std_logic_vector(width-1 downto 0));
end synth_reg_reg;

architecture behav of synth_reg_reg is
  type reg_array_type is array (latency downto 0) of std_logic_vector(width -1 downto 0);
  signal reg_bank : reg_array_type := (others => (others => '0'));
  signal reg_bank_in : reg_array_type := (others => (others => '0'));
  attribute syn_allow_retiming : boolean;
  attribute syn_srlstyle : string;
  attribute syn_allow_retiming of reg_bank : signal is true;
  attribute syn_allow_retiming of reg_bank_in : signal is true;
  attribute syn_srlstyle of reg_bank : signal is "registers";
  attribute syn_srlstyle of reg_bank_in : signal is "registers";
begin  -- behav

  latency_eq_0: if latency = 0 generate
    o <= i;
  end generate latency_eq_0;

    latency_gt_0: if latency >= 1 generate
      o <= reg_bank(latency);
      reg_bank(0) <= i;
  
      sync_loop: for sync_idx in latency downto 1 generate
        sync_proc: process (clk)
        begin  -- process sync_proc
          if clk'event and clk = '1' then  -- rising clock edge
            if clr = '1' then
              reg_bank(sync_idx) <=  (others => '0');
            elsif ce = '1'  then
              reg_bank(sync_idx) <= reg_bank(sync_idx-1);
            end if;
          end if;   
        end process sync_proc;
      end generate sync_loop;
    end generate latency_gt_0;
  end behav;



