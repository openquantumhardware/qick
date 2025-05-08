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

module uart_top(
  // Write side inputs
  input            clk_pin,      // Clock input (from pin)
  input            rst_pin,      // Active HIGH reset (from pin)
  input            btn_pin,      // Button to swap high and low bits
  output     [7:0] led_pins      // 8 LED outputs
);

wire rx_cross;

uart_led U0(
  // Write side inputs
  .clk_pin(clk_pin),      // Clock input (from pin)
  .rst_pin(rst_pin),      // Active HIGH reset (from pin)
  .btn_pin(btn_pin),      // Button to swap high and low bits
  .rxd_pin(rx_cross),      // RS232 RXD pin - directly from pin
  .led_pins(led_pins)      // 8 LED outputs
);

system_wrapper U1
   (
    .DDR_addr(),
    .DDR_ba(),
    .DDR_cas_n(),
    .DDR_ck_n(),
    .DDR_ck_p(),
    .DDR_cke(),
    .DDR_cs_n(),
    .DDR_dm(),
    .DDR_dq(),
    .DDR_dqs_n(),
    .DDR_dqs_p(),
    .DDR_odt(),
    .DDR_ras_n(),
    .DDR_reset_n(),
    .DDR_we_n(),
    .FIXED_IO_ddr_vrn(),
    .FIXED_IO_ddr_vrp(),
    .FIXED_IO_mio(),
    .FIXED_IO_ps_clk(),
    .FIXED_IO_ps_porb(),
    .FIXED_IO_ps_srstb(),
    .GPIO_O(rx_cross)
	);
endmodule
