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
//  Module   : uart_led.v
//  Parent   : None
//  Children : uart_rx.v led_ctl.v 
//
//  Description: 
//     Ties the UART receiver to the LED controller
//
//  Parameters:
//     None
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//    None
//

`timescale 1ns/1ps
module uart_led (
  // Write side inputs
  input            clk_pin,      // Clock input (from pin)
  input            rst_pin,      // Active HIGH reset (from pin)
  input            btn_pin,      // Button to swap high and low bits
  input            rxd_pin,      // RS232 RXD pin - directly from pin
  output     [7:0] led_pins      // 8 LED outputs
);

//***************************************************************************
// Parameter definitions
//***************************************************************************
  parameter BAUD_RATE           = 115_200;   
  parameter CLOCK_RATE          = 125_000_000;

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  // Synchronized reset
  wire             rst_clk_rx;

  // Synchronized button
  wire             btn_clk_rx;

  // Between uart_rx and led_ctl
  wire [7:0]       rx_data;      // Data output of uart_rx
  wire             rx_data_rdy;  // Data ready output of uart_rx
  
//***************************************************************************
// Code
//***************************************************************************

  // Metastability harden the rst - this is an asynchronous input to the
  // system (from a pushbutton), and is used in synchronous logic. Therefore
  // it must first be synchronized to the clock domain (clk_pin in this case)
  // prior to being used. A simple metastability hardener is appropriate here.
  meta_harden meta_harden_rst_i0 (
    .clk_dst      (clk_pin),
    .rst_dst      (1'b0),    // No reset on the hardener for reset!
    .signal_src   (rst_pin),
    .signal_dst   (rst_clk_rx)
  );

  // And the button input
  meta_harden meta_harden_btn_i0 (
    .clk_dst      (clk_pin),
    .rst_dst      (rst_clk_rx),
    .signal_src   (btn_pin),
    .signal_dst   (btn_clk_rx)
  );

  uart_rx #(
    .CLOCK_RATE   (CLOCK_RATE),
    .BAUD_RATE    (BAUD_RATE) 
  ) uart_rx_i0 (
    .clk_rx      (clk_pin),
    .rst_clk_rx  (rst_clk_rx),

    .rxd_i       (rxd_pin),
    .rxd_clk_rx  (),
    
    .rx_data_rdy (rx_data_rdy),
    .rx_data     (rx_data),
    .frm_err     ()
  );

  led_ctl led_ctl_i0 (
    .clk_rx      (clk_pin),
    .rst_clk_rx  (rst_clk_rx),
    .btn_clk_rx  (btn_clk_rx),
    .rx_data     (rx_data),
    .rx_data_rdy (rx_data_rdy),
    .led_o       (led_pins)
  );

endmodule
