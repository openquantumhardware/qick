/*
   Copyright (c) 2021, Xilinx, Inc.
   All rights reserved.
  
   Redistribution and use in source and binary forms, with or without 
   modification, are permitted provided that the following conditions are met:

   1.  Redistributions of source code must retain the above copyright notice, 
       this list of conditions and the following disclaimer.

   2.  Redistributions in binary form must reproduce the above copyright 
       notice, this list of conditions and the following disclaimer in the 
       documentation and/or other materials provided with the distribution.

   3.  Neither the name of the copyright holder nor the names of its 
       contributors may be used to endorse or promote products derived from 
       this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
   OR BUSINESS INTERRUPTION). HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
   ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


`timescale 1ns/1ns

module binary_latch_counter(
clk,
resetn,
counter,
latched
);

parameter  LATCH_VALUE = 2**17-1;
parameter  COUNTER_WIDTH = $clog2(LATCH_VALUE);

input  clk;
input  resetn;
output reg [COUNTER_WIDTH-1:0] counter;
output reg latched;

always @ (posedge clk)
begin
    if (!resetn)
    begin
        counter <= 0;
        latched <= 1'b0;
    end
    else
    begin
        if ($unsigned(counter) == LATCH_VALUE)
            latched <= 1'b1;
        else
            counter <= counter + 1;
    end
end

endmodule
