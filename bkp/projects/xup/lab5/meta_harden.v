//-----------------------------------------------------------------------------
//  
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
//
//  Project  : Programmable Wave Generator
//  Module   : meta_harden.v
//  Parent   : Various
//  Children : None
//
//  Description: 
//    This is a basic meta-stability hardener; it double synchronizes an
//    asynchronous signal onto a new clock domain.
//
//  Parameters:
//    None
//
//  Notes       : 
//
//  Multicycle and False Paths, Timing Exceptions
//    A tighter timing constraint should be placed between the signal_meta
//    and signal_dst flip-flops to allow for meta-stability settling time
//

`timescale 1ns/1ps


module meta_harden (
  input            clk_dst,      // Destination clock
  input            rst_dst,      // Reset - synchronous to destination clock
  input            signal_src,   // Asynchronous signal to be synchronized
  output reg       signal_dst    // Synchronized signal
);


//***************************************************************************
// Register declarations
//***************************************************************************

  reg           signal_meta;     // After sampling the async signal, this has
                                 // a high probability of being metastable.
                                 // The second sampling (signal_dst) has
                                 // a much lower probability of being
                                 // metastable

//***************************************************************************
// Code
//***************************************************************************

  always @(posedge clk_dst)
  begin
    if (rst_dst)
    begin
      signal_meta <= 1'b0;
      signal_dst  <= 1'b0;
    end
    else // if !rst_dst
    begin
      signal_meta <= signal_src;
      signal_dst  <= signal_meta;
    end // if rst
  end // always

endmodule

