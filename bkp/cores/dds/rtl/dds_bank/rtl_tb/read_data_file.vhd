-- (c) Copyright 2012 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-------------------------------------------------------------------------------
-- Description:
--  Read a specified dat file and output a quantized value given the specified 
--  data and fractional width 
--  - Assumes dat file content is real data in the range 1.0 > x > -1.0.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE ieee.math_real.ALL;

library std;
use std.textio.all;

entity read_dat_file is
  generic (
            C_FILENAME       : string;
            C_FRACT_WIDTH    : integer:=-1);
  port ( 
         clk            : in  std_logic;
         enable         : in  std_logic:='1';
         sim_finished   : in  boolean:=false;
         data           : out std_logic_vector;
         file_finished  : out boolean:=false);
end;

architecture xilinx of read_dat_file is
  constant OUTPUT_WIDTH : integer := data'LENGTH;
  signal   data_int        : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal   line_cnt        : integer := 0;
begin
  read_data : process
    file     filepointer : text;
    variable filestatus  : file_open_status;
    variable fileline    : line;
    variable file_data   : real;
    variable scaling     : integer:=OUTPUT_WIDTH;
  begin
    if C_FRACT_WIDTH > -1 then
      scaling := C_FRACT_WIDTH;
    end if;
    file_finished <= false;
    file_open(filestatus,filepointer,C_FILENAME,read_mode);
    if filestatus /= OPEN_OK then
      report "ERROR: read_dat_file: Unable to open file: " &  C_FILENAME severity failure;
    else
      report "INFO: read_dat_file: " &  C_FILENAME & " opened" severity note;
    end if;
    read_file: loop
      exit read_file when endfile(filepointer);
      wait until rising_edge(clk) and enable='1';
      readline(filepointer, fileline);
      read(fileline,file_data);
      -- Scale real input data to the precision of the output vector
      -- Will simply truncate
      data_int <= std_logic_vector(to_signed(integer(file_data*real(2**scaling)),OUTPUT_WIDTH));
      exit read_file when endfile(filepointer) or sim_finished;
      line_cnt <= line_cnt + 1;
    end loop read_file;
    file_close(filepointer);
    file_finished <= true;
    wait;
  end process;
  data <= data_int;
end;

