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
-- Create Date: 26.01.2021 09:03:31
-- Design Name: D Type Flip Flop
-- Module Name: D_Type - arch_imp
-- Project Name: AXI Packet Generator
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: A simple d-type flip flop with enable.
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Revision 1.00 - Design Completed
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity D_Type is
    Generic (N : integer := 32);
    Port ( D : in STD_LOGIC_VECTOR (N-1 downto 0);
           en : in STD_LOGIC;
           rst : in STD_LOGIC;
           clk : in STD_LOGIC;
           Q : out STD_LOGIC_VECTOR (N-1 downto 0));
end D_Type;

architecture arch_imp of D_Type is

begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                Q <= (others => '0');
            else
                if en = '1' then
                    Q <= D;
                end if;
            end if;
        end if;
    end process;

end arch_imp;