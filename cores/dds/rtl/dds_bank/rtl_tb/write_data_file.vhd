library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity write_data_file is
  generic (
            C_FILENAME       : string;
            C_FRACT_WIDTH    : integer:=-1);
  port (
         clk            : in  std_logic;
         enable         : in  std_logic:='1';
         sim_finished   : in  boolean:=false;
         data           : in  std_logic_vector);
end write_data_file;

architecture beha of write_data_file is 
  constant OUTPUT_WIDTH : integer := data'LENGTH;
  signal   data_int        : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal   line_cnt        : integer := 0;

begin

  --Write process
  write_data : process 
    file filepointer     : text;
    variable filestatus  : file_open_status;
    variable line_content: string(1 to 4);
    variable line_num    : line;
    variable scaling     : integer:=OUTPUT_WIDTH;
  begin
    if C_FRACT_WIDTH > -1 then
      scaling := C_FRACT_WIDTH;
    end if;
    file_open(filestatus,filepointer,C_FILENAME,WRITE_MODE);
    if filestatus /= OPEN_OK then
      report "ERROR: read_dat_file: Unable to open file: " &  C_FILENAME severity failure;
    else
      report "INFO: read_dat_file: " &  C_FILENAME & " opened" severity note;
    end if;

    write_file: loop
      wait until rising_edge(clk) and enable='1';
      write(line_num,real(to_integer(signed(data)))/real(2**scaling)); -- precision = 2^19 --write the line.
      writeline(filepointer,line_num); --write the contents into the file.
      exit write_file when sim_finished or line_cnt = 100000;
      line_cnt <= line_cnt + 1;
    end loop write_file;
    file_close(filepointer);
    wait;
  end process;

end beha;
