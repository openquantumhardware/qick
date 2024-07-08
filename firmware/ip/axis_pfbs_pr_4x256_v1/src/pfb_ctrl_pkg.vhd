library IEEE;										 
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package pfb_ctrl_pkg is

	-- Functions.
	function f_nbit_axis (ARG: Integer) return Integer;
    
end pfb_ctrl_pkg;

package body pfb_ctrl_pkg is    

	function f_nbit_axis (ARG: Integer) return Integer is
	-- Function variables.
	variable arg_log2	: Integer := Integer(ceil(log2(real(ARG))));
	variable tmp 	   : Integer;

	begin
		
		if (arg_log2 <= 8 ) then
			tmp := 8;
		elsif ( arg_log2 <= 16 ) then
			tmp := 16;
		elsif ( arg_log2 <= 24 ) then
			tmp := 24;
		elsif ( arg_log2 <= 32 ) then
			tmp := 32;
		else
			tmp := -1;
		end if;
	
		return tmp;
	end;

end package body pfb_ctrl_pkg;

