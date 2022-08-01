----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/16/2017 02:49:57 PM
-- Design Name: 
-- Module Name: lo_spi_mux - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lo_spi_mux is
    Port ( ss_in : in STD_LOGIC_VECTOR (1 downto 0);
           ss0_out : out STD_LOGIC;
           ss1_out : out STD_LOGIC;
           sdo0_in : in STD_LOGIC;
           sdo1_in : in STD_LOGIC;
           sdo_out : out STD_LOGIC);
end lo_spi_mux;

architecture Behavioral of lo_spi_mux is

begin

-- Assign ss outputs.
ss0_out <= ss_in(0);
ss1_out <= ss_in(1);

sdo_out <= sdo0_in when (ss_in(1) = '1' and ss_in(0) = '0') else
		sdo1_in when (ss_in(1) = '0' and ss_in(0) = '1') else
		'1';

end Behavioral;
