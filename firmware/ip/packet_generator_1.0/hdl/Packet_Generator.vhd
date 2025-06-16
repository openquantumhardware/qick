--  Copyright (c) 2021, Xilinx, Inc.
--  All rights reserved.
-- 
--  Redistribution and use in source and binary forms, with or without 
--  modification, are permitted provided that the following conditions are met:
--
--  1.  Redistributions of source code must retain the above copyright notice, 
--      this list of conditions and the following disclaimer.
--
--  2.  Redistributions in binary form must reproduce the above copyright 
--      notice, this list of conditions and the following disclaimer in the 
--      documentation and/or other materials provided with the distribution.
--
--  3.  Neither the name of the copyright holder nor the names of its 
--      contributors may be used to endorse or promote products derived from 
--      this software without specific prior written permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
--  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
--  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
--  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
--  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
--  OR BUSINESS INTERRUPTION). HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
--  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
--  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
--  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


----------------------------------------------------------------------------------
-- Company: Xilinx
-- Engineer: David Northcote
-- 
-- Create Date: 26.01.2021 09:01:02
-- Design Name: Packet Generator
-- Module Name: Packet_Generator - arch_imp
-- Project Name: AXI Packet Generator
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: Converts a free running AXI-Stream to an AXI-Stream packet.
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Revision 1.00 - Design Complete
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Packet_Generator is
    Generic ( N : integer := 32);
    Port ( packetsize : in STD_LOGIC_VECTOR (31 downto 0);
           s_tvalid : in STD_LOGIC;
           s_tdata : in STD_LOGIC_VECTOR (N-1 downto 0);
           m_tvalid : out STD_LOGIC;
           m_tdata : out STD_LOGIC_VECTOR (N-1 downto 0);
           m_tuser : out STD_LOGIC;
           m_tlast : out STD_LOGIC;
           clk : in STD_LOGIC);
end Packet_Generator;

architecture arch_imp of Packet_Generator is

    component D_Type is
        Generic (N : integer);
        Port ( D : in STD_LOGIC_VECTOR (N-1 downto 0);
               en : in STD_LOGIC;
               rst : in STD_LOGIC;
               clk : in STD_LOGIC;
               Q : out STD_LOGIC_VECTOR (N-1 downto 0));
    end component;
    
    component Free_Counter is
        Generic (N : integer);
        Port ( en : in STD_LOGIC;
               rst : in STD_LOGIC;
               clk : in STD_LOGIC;
               dout : out STD_LOGIC_VECTOR (N-1 downto 0));
    end component;
    
    constant zero_const : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    constant one_const : STD_LOGIC_VECTOR (31 downto 0) := (0 => '1', others => '0');
    
    signal s_tvalid_sig : STD_LOGIC;
    signal s_tdata_sig : STD_LOGIC_VECTOR (N-1 downto 0);
    
    signal packetsize_sig : STD_LOGIC_VECTOR (31 downto 0);
    signal packetsize_new_sig : STD_LOGIC_VECTOR (31 downto 0);
    signal packetsize_count_sig : STD_LOGIC_VECTOR (31 downto 0);
    
    signal relational_leeq_sig : STD_LOGIC;
    signal relational_ineq_sig : STD_LOGIC;
    signal relational_eeq_sig : STD_LOGIC;
    
    signal logical_tlast_sig : STD_LOGIC;
    signal logical_tuser_sig : STD_LOGIC;
    signal logical_tvalid_sig : STD_LOGIC;

begin

    reg_tvalid_in : D_Type
        generic map (N => 1)
        port map (D(0) => s_tvalid,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => s_tvalid_sig);
                  
    reg_tdata_in : D_Type
        generic map (N => N)
        port map (D => s_tdata,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q => s_tdata_sig);
                  
    reg_packetsize_in : D_Type
        generic map (N => 32)
        port map (D => packetsize,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q => packetsize_sig);
                  
    reg_tvalid_out : D_Type
        generic map (N => 1)
        port map (D(0) => logical_tvalid_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => m_tvalid);   
                  
    reg_tdata_out : D_Type
        generic map (N => N)
        port map (D => s_tdata_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q => m_tdata);
                  
    reg_tlast_out : D_Type
        generic map (N => 1)
        port map (D(0) => logical_tlast_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => m_tlast);     
                  
    reg_tuser_out : D_Type
        generic map (N => 1)
        port map (D(0) => logical_tuser_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => m_tuser); 
                                    
    reg_en_packetsize : D_Type
        generic map (N => 32)
        port map (D => packetsize_sig,
                  en => relational_leeq_sig,
                  rst => '0',
                  clk => clk,
                  Q => packetsize_new_sig);
                  
    free_counter_packetsize : Free_Counter
        generic map (N => 32)
        port map (en => s_tvalid_sig,
                  rst => relational_leeq_sig,
                  clk => clk,
                  dout => packetsize_count_sig);
                  
    relational_ineq_sig <= '1' when zero_const /= packetsize_new_sig else '0';
    relational_leeq_sig <= '1' when packetsize_new_sig <= packetsize_count_sig else '0';
    relational_eeq_sig <= '1' when packetsize_count_sig = one_const else '0';
    
    logical_tlast_sig <= relational_leeq_sig and s_tvalid_sig and relational_ineq_sig;
    logical_tuser_sig <= relational_eeq_sig and s_tvalid_sig and relational_ineq_sig;
    logical_tvalid_sig <= relational_ineq_sig and s_tvalid_sig;

end arch_imp;