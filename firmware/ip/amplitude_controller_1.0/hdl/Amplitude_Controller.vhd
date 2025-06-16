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
-- Create Date: 27.01.2021 10:21:12
-- Design Name: Amplitide Controller
-- Module Name: Amplitude_Controller - arch_imp
-- Project Name: AXI Amplitude Controller
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: A simple Amplitude Controller that outputs a value to the
--              AXI-Stream interface.
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

entity Amplitude_Controller is
    Generic (N : integer := 32;
             B : integer := 1);
    Port ( enable : in STD_LOGIC;
           amplitude : in STD_LOGIC_VECTOR (N-1 downto 0);
           m_tvalid : out STD_LOGIC;
           m_tdata : out STD_LOGIC_VECTOR (N*B-1 downto 0);
           m_tready : in STD_LOGIC;
           clk : in STD_LOGIC);
end Amplitude_Controller;

architecture arch_imp of Amplitude_Controller is

    component D_Type is
        Generic (N : integer);
        Port ( D : in STD_LOGIC_VECTOR (N-1 downto 0);
               en : in STD_LOGIC;
               rst : in STD_LOGIC;
               clk : in STD_LOGIC;
               Q : out STD_LOGIC_VECTOR (N-1 downto 0));
    end component;
    
    constant zero_const : STD_LOGIC_VECTOR (N*B-1 downto 0) := (others => '0');
    
    signal concat_data_sig : STD_LOGIC_VECTOR (N*B-1 downto 0) := (others => '0');
    signal mux_data_sig : STD_LOGIC_VECTOR (N*B-1 downto 0) := (others => '0');

begin

    reg_valid_out : D_Type
        generic map (N => 1)
        port map (D(0) => m_tready,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q(0) => m_tvalid);
                  
    reg_data_out : D_Type
        generic map (N => N*B)
        port map (D => mux_data_sig,
                  en => '1',
                  rst => '0',
                  clk => clk,
                  Q => m_tdata);

    concat : process(amplitude)
    begin
        for i in 0 to B-1 loop
            concat_data_sig(N + N*i-1 downto N*i) <= amplitude(N-1 downto 0);
        end loop;
    end process;
    
    mux_data_sig <= concat_data_sig when enable = '1' else zero_const;

end arch_imp;