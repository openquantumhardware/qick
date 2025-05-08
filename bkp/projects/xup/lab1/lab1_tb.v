`timescale 1ns / 1ps
// MIT License
// Copyright (c) 2022 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// SOFTWARE.

/////////////////////////////////////////////////////////////////
// Module Name: lab1_tb
/////////////////////////////////////////////////////////////////
module lab1_tb(

    );
    
    reg [3:0] btns;
    wire [3:0] leds;
    reg [3:0] e_led;
    
    integer i;
    
    lab1 dut(.led(leds),.btn(btns));
 
    function [3:0] expected_led;
       input [3:0] btn;
    begin      
       expected_led[0] = ~btn[0];
       expected_led[1] = btn[1] & ~btn[2];
       expected_led[3] = btn[2] & btn[3];
       expected_led[2] = expected_led[1] | expected_led[3];
    end   
    endfunction   
    
    initial
    begin
        for (i=0; i < 15; i=i+1)
        begin
            #50 btns=i;
            #10 e_led = expected_led(btns);
            if(leds == e_led)
                $display("LED output matched at", $time);
            else
                $display("LED output mis-matched at ",$time,": expected: %b, actual: %b", e_led, leds);
        end
    end
      
endmodule
