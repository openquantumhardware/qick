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
-- Create Date: 26.01.2021 11:47:17
-- Design Name: Packet Inspector
-- Module Name: Packet_Inspector - arch_imp
-- Project Name: AXI Packet Generator
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: Output an AXI-Stream packet when enable is on the rising edge.
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

entity Packet_Inspector is
    generic (N : integer := 32);
    Port ( transfer : in STD_LOGIC;
           s_tvalid : in STD_LOGIC;
           s_tdata : in STD_LOGIC_VECTOR (N-1 downto 0);
           s_tuser : in STD_LOGIC;
           s_tlast : in STD_LOGIC;
           m_tvalid : out STD_LOGIC;
           m_tdata : out STD_LOGIC_VECTOR (N-1 downto 0);
           m_tlast : out STD_LOGIC;
           clk : in STD_LOGIC);
end Packet_Inspector;

architecture arch_imp of Packet_Inspector is

    component D_Type is
        Generic (N : integer);
        Port ( D : in STD_LOGIC_VECTOR (N-1 downto 0);
               en : in STD_LOGIC;
               rst : in STD_LOGIC;
               clk : in STD_LOGIC;
               Q : out STD_LOGIC_VECTOR (N-1 downto 0));
    end component;
    
    component SR_Latch is
    Port ( S : in STD_LOGIC;
           R : in STD_LOGIC;
           Q : out STD_LOGIC;
           clk : in STD_LOGIC);
    end component;
    
    component Falling_Edge_Detector is
    Port ( din : in STD_LOGIC;
           dout : out STD_LOGIC;
           clk : in STD_LOGIC);
    end component;
    
    component Rising_Edge_Detector is
    Port ( din : in STD_LOGIC;
           dout : out STD_LOGIC;
           clk : in STD_LOGIC);
    end component;
    
    constant zero_const : STD_LOGIC_VECTOR (N-1 downto 0) := (others => '0');
    
    signal transfer_and_tuser_sig : STD_LOGIC;
    signal transfer_fed : STD_LOGIC;
    signal transfer_red : STD_LOGIC;
    
    signal srlatch_transfer_sig : STD_LOGIC;
    signal srlatch_tlast_sig : STD_LOGIC;
    
    signal tlast_red : STD_LOGIC;
    
    signal mux_tdata_sig : STD_LOGIC_VECTOR(N-1 downto 0);
    
    signal logical_tlast_sig : STD_LOGIC;
    signal logical_tuser_sig : STD_LOGIC;
    signal logical_tvalid_sig : STD_LOGIC;

begin

    fed_transfer : Falling_Edge_Detector
        port map (din => transfer,
                  dout => transfer_fed,
                  clk => clk);
                  
    srlatch_transfer : SR_Latch
        port map (S => transfer_and_tuser_sig,
                  R => transfer_fed,
                  Q => srlatch_transfer_sig,
                  clk => clk);
                  
    red_transfer : Rising_Edge_Detector
        port map (din => srlatch_transfer_sig,
                  dout => transfer_red,
                  clk => clk);
                  
    red_last : Rising_Edge_Detector
        port map (din => s_tlast,
                  dout => tlast_red,
                  clk => clk);
                  
    srlatch_last : SR_Latch
        port map (S => transfer_red,
                  R => tlast_red,
                  Q => srlatch_tlast_sig,
                  clk => clk);
                  
    reg_tvalid_out : D_Type
        generic map (N => 1)
        port map (D(0) => logical_tvalid_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => m_tvalid);   
                  
    reg_tdata_out : D_Type
        generic map (N => N)
        port map (D => mux_tdata_sig,
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

    transfer_and_tuser_sig <= transfer and s_tuser;
    
    mux_tdata_sig <= s_tdata when srlatch_tlast_sig = '1' else zero_const;
    
    logical_tlast_sig <= s_tlast and srlatch_tlast_sig;
    logical_tvalid_sig <= s_tvalid and srlatch_tlast_sig;

end arch_imp;
