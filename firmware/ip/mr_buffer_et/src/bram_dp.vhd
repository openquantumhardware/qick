----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/02/2019 09:12:29 AM
-- Design Name: 
-- Module Name: bram_dp - Behavioral
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bram_dp is
    Generic (
        -- Memory address size.
        N       : Integer := 16;
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
        clka    : in STD_LOGIC;
        clkb    : in STD_LOGIC;
        ena     : in STD_LOGIC;
        enb     : in STD_LOGIC;
        wea     : in STD_LOGIC;
        web     : in STD_LOGIC;
        addra   : in STD_LOGIC_VECTOR (N-1 downto 0);
        addrb   : in STD_LOGIC_VECTOR (N-1 downto 0);
        dia     : in STD_LOGIC_VECTOR (B-1 downto 0);
        dib     : in STD_LOGIC_VECTOR (B-1 downto 0);
        doa     : out STD_LOGIC_VECTOR (B-1 downto 0);
        dob     : out STD_LOGIC_VECTOR (B-1 downto 0)
    );
end bram_dp;

architecture Behavioral of bram_dp is

-- Ram type.
type ram_type is array (2**N-1 downto 0) of std_logic_vector (B-1 downto 0);
shared variable RAM : ram_type;

begin

-- CLKA port.
process (clka)
begin
    if (clka'event and clka = '1') then
        if (ena = '1') then
            doa <= RAM(conv_integer(addra));
            if (wea = '1') then
                RAM(conv_integer(addra)) := dia;
            end if;
        end if;
    end if;
end process;

-- CLKB port.
process (clkb)
begin
    if (clkb'event and clkb = '1') then
        if (enb = '1') then
            dob <= RAM(conv_integer(addrb));
            if (web = '1') then
                RAM(conv_integer(addrb)) := dib;
            end if;
        end if;
    end if;
end process;

end Behavioral;
