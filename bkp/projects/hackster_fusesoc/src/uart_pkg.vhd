library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


package adiuvo_uart is 

    function vector_size(clk_freq, baud_rate : real) return integer;
    function parity (a : std_logic_vector) return std_logic;
    constant fe_det     : std_logic_vector(1 downto 0) := "10";
    constant start_bit  : std_logic                    := '0';
    constant stop_bit   : std_logic_vector             := "11";
end package;

package body adiuvo_uart is 

    function vector_size(clk_freq, baud_rate : real) return integer is
        variable div                             : real;
        variable res                             : real;
      begin
        div := (clk_freq/baud_rate);
        res := CEIL(LOG(div)/LOG(2.0));
        return integer(res - 1.0);
      end;
    
      function parity (a : std_logic_vector) return std_logic is
        variable y         : std_logic := '0';
      begin
        for i in a'range loop
          y := y xor a(i);
        end loop;
        return y;
      end parity;
    

      
end package body adiuvo_uart;