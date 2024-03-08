-------------------------------------------------------------------
-- System Generator version 2019.2 VHDL source file.
--
-- Copyright(C) 2019 by Xilinx, Inc.  All rights reserved.  This
-- text/file contains proprietary, confidential information of Xilinx,
-- Inc., is distributed under license from Xilinx, Inc., and may be used,
-- copied and/or disclosed only pursuant to the terms of a valid license
-- agreement with Xilinx, Inc.  Xilinx hereby grants you a license to use
-- this text/file solely for design, simulation, implementation and
-- creation of design files limited to Xilinx devices or technologies.
-- Use with non-Xilinx devices or technologies is expressly prohibited
-- and immediately terminates your license unless covered by a separate
-- agreement.
--
-- Xilinx is providing this design, code, or information "as is" solely
-- for use in developing programs and solutions for Xilinx devices.  By
-- providing this design, code, or information as one possible
-- implementation of this feature, application or standard, Xilinx is
-- making no representation that this implementation is free from any
-- claims of infringement.  You are responsible for obtaining any rights
-- you may require for your implementation.  Xilinx expressly disclaims
-- any warranty whatsoever with respect to the adequacy of the
-- implementation, including but not limited to warranties of
-- merchantability or fitness for a particular purpose.
--
-- Xilinx products are not intended for use in life support appliances,
-- devices, or systems.  Use in such applications is expressly prohibited.
--
-- Any modifications that are made to the source code are done at the user's
-- sole risk and will be unsupported.
--
-- This copyright and support notice must be retained as part of this
-- text at all times.  (c) Copyright 1995-2019 Xilinx, Inc.  All rights
-- reserved.
-------------------------------------------------------------------

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;


entity ssr_8x64_xldelay is
   generic(width        : integer := -1;
           latency      : integer := -1;
           reg_retiming : integer :=  0;
           reset        : integer :=  0);
   port(d       : in std_logic_vector (width-1 downto 0);
        ce      : in std_logic;
        clk     : in std_logic;
        en      : in std_logic;
        rst     : in std_logic;
        q       : out std_logic_vector (width-1 downto 0));

end ssr_8x64_xldelay;

architecture behavior of ssr_8x64_xldelay is
   component synth_reg
      generic (width       : integer;
               latency     : integer);
      port (i       : in std_logic_vector(width-1 downto 0);
            ce      : in std_logic;
            clr     : in std_logic;
            clk     : in std_logic;
            o       : out std_logic_vector(width-1 downto 0));
   end component; -- end component synth_reg

   component synth_reg_reg
      generic (width       : integer;
               latency     : integer);
      port (i       : in std_logic_vector(width-1 downto 0);
            ce      : in std_logic;
            clr     : in std_logic;
            clk     : in std_logic;
            o       : out std_logic_vector(width-1 downto 0));
   end component;

   signal internal_ce  : std_logic;

begin
   internal_ce  <= ce and en;

   srl_delay: if ((reg_retiming = 0) and (reset = 0)) or (latency < 1) generate
     synth_reg_srl_inst : synth_reg
       generic map (
         width   => width,
         latency => latency)
       port map (
         i   => d,
         ce  => internal_ce,
         clr => '0',
         clk => clk,
         o   => q);
   end generate srl_delay;

   reg_delay: if ((reg_retiming = 1) or (reset = 1)) and (latency >= 1) generate
     synth_reg_reg_inst : synth_reg_reg
       generic map (
         width   => width,
         latency => latency)
       port map (
         i   => d,
         ce  => internal_ce,
         clr => rst,
         clk => clk,
         o   => q);
   end generate reg_delay;
end architecture behavior;

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             COMPLEX_FIXED_PKG.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Package Name:    COMPLEX_FIXED_PKG
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Unconstrained Size Vectors and Matrices of Complex Arbitrary Precision Fixed Point Numbers
--
-------------------------------------------------------------------------------- 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_complex.all;

package COMPLEX_FIXED_PKG is
  type BOOLEAN_VECTOR is array(NATURAL range <>) of BOOLEAN;
  type INTEGER_VECTOR is array(NATURAL range <>) of INTEGER;
  type REAL_VECTOR is array(NATURAL range <>) of REAL;
--2008  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED;
  type COMPLEX_VECTOR is array(INTEGER range <>) of COMPLEX;

  type SFIXED is array(INTEGER range <>) of STD_LOGIC; -- arbitrary precision fixed point signed number, like SIGNED but lower bound can be negative
--2008  type SFIXED_VECTOR is array(INTEGER range <>) of SFIXED; -- unconstrained array of SFIXED
--2008  type CFIXED is record RE,IM:SFIXED; end record; -- arbitrary precision fixed point complex signed number
--2008  type CFIXED_VECTOR is array(INTEGER range <>) of CFIXED; -- unconstrained array of CFIXED
--2008  type CFIXED_MATRIX is array(INTEGER range <>) of CFIXED_VECTOR; -- unconstrained array of CFIXED_VECTOR
  type SFIXED_VECTOR is array(INTEGER range <>) of STD_LOGIC; -- unconstrained array of SFIXED, vector size must be given by a separate generic
  type CFIXED is array(INTEGER range <>) of STD_LOGIC; -- arbitrary precision fixed point complex signed number, CFIXED'low is always even and CFIXED'high is always odd
  type CFIXED_VECTOR is array(INTEGER range <>) of STD_LOGIC; -- unconstrained array of CFIXED, vector size must be given by a separate generic

--  function ELEMENT(X:CFIXED;K,N:INTEGER) return CFIXED; -- returns the CFIXED range for X(K)
--  function RE(X:CFIXED;K,N:INTEGER) return SFIXED; -- returns the CFIXED range for X(K).RE
--  function IM(X:CFIXED;K,N:INTEGER) return SFIXED; -- returns the CFIXED range for X(K).IM
  
  function MIN(A,B:INTEGER) return INTEGER;
  function MIN(A,B,C:INTEGER) return INTEGER;
  function MIN(A,B,C,D:INTEGER) return INTEGER;
  function MED(A,B,C:INTEGER) return INTEGER;
  function MAX(A,B:INTEGER) return INTEGER;
  function MAX(A,B,C:INTEGER) return INTEGER;
  function MAX(A,B,C,D:INTEGER) return INTEGER;
  function "+"(X,Y:SFIXED) return SFIXED; -- full precision add with SFIXED(MAX(X'high,Y'high)+1 downto MIN(X'low,Y'low)) result
  function "-"(X,Y:SFIXED) return SFIXED; -- full precision subtract with SFIXED(MAX(X'high,Y'high)+1 downto MIN(X'low,Y'low)) result
  function "-"(X:SFIXED) return SFIXED; -- full precision negate with SFIXED(X'high+1 downto X'low) result
  function "*"(X,Y:SFIXED) return SFIXED; -- full precision multiply with SFIXED(X'high+Y'high+1 downto X'low+Y'low) result
  function "*"(X:SFIXED;Y:STD_LOGIC) return SFIXED; -- multiply by 0 or 1 with SFIXED(X'high downto X'low) result
  function RESIZE(X:SFIXED;H,L:INTEGER) return SFIXED; -- resizes X and returns SFIXED(H downto L)
  function RESIZE(X:SFIXED;HL:SFIXED) return SFIXED; -- resizes X to match HL and returns SFIXED(HL'high downto HL'low)
  function SHIFT_RIGHT(X:SFIXED;N:INTEGER) return SFIXED; -- returns SFIXED(X'high-N downto X'low-N) result
  function SHIFT_LEFT(X:SFIXED;N:INTEGER) return SFIXED; -- returns SFIXED(X'high+N downto X'low+N) result
  function TO_SFIXED(R:REAL;H,L:INTEGER) return SFIXED; -- returns SFIXED(H downto L) result
  function TO_SFIXED(R:REAL;HL:SFIXED) return SFIXED; -- returns SFIXED(HL'high downto HL'low) result
  function TO_REAL(S:SFIXED) return REAL; -- returns REAL result
--  function ELEMENT(X:SFIXED_VECTOR;K,N:INTEGER) return SFIXED; -- returns element K out of an N-size array X

  function RE(X:CFIXED) return SFIXED; -- returns SFIXED(X'high/2 downto X'low/2) result
--  procedure vRE(X:out CFIXED;S:SFIXED); -- use when X is a variable, X'low is always even and X'high is always odd
--  procedure RE(signal X:out CFIXED;S:SFIXED); -- use when X is a signal, X'low is always even and X'high is always odd
  function IM(X:CFIXED) return SFIXED; -- returns SFIXED(X'high/2 downto X'low/2) result
--  procedure vIM(X:out CFIXED;S:SFIXED); -- use when X is a variable, X'low is always even and X'high is always odd
--  procedure IM(signal X:out CFIXED;S:SFIXED); -- use when X is a signal, X'low is always even and X'high is always odd
  function "+"(X,Y:CFIXED) return CFIXED; -- full precision add with CFIXED(MAX(X'high,Y'high)+2 downto MIN(X'low,Y'low)) result
  function "-"(X,Y:CFIXED) return CFIXED; -- full precision subtract with CFIXED(MAX(X'high,Y'high)+2 downto MIN(X'low,Y'low)) result
  function "*"(X,Y:CFIXED) return CFIXED; -- full precision multiply with CFIXED(X'high+Y'high+2 downto X'low+Y'low) result
  function "*"(X:CFIXED;Y:SFIXED) return CFIXED; -- full precision multiply with CFIXED(X'high+Y'high downto X'low+Y'low) result
  function "*"(X:SFIXED;Y:CFIXED) return CFIXED;
  function RESIZE(X:CFIXED;H,L:INTEGER) return CFIXED; -- resizes X and returns CFIXED(H downto L)
  function RESIZE(X:CFIXED;HL:CFIXED) return CFIXED; -- resizes X to match HL and returns CFIXED(HL'high downto HL'low)
  function PLUS_i_TIMES(X:CFIXED) return CFIXED; -- returns CFIXED(X'high+2 downto X'low) result
  function "-"(X:CFIXED) return CFIXED; -- full precision negate with CFIXED(X'high+2 downto X'low) result
  function MINUS_i_TIMES(X:CFIXED) return CFIXED; -- returns CFIXED(X'high+2 downto X'low) result
  function X_PLUS_i_TIMES_Y(X,Y:CFIXED;RND:CFIXED) return CFIXED; -- returns CFIXED(MAX(X'high,Y'high)+2 downto MIN(X'low,Y'low)) result
  function X_MINUS_i_TIMES_Y(X,Y:CFIXED;RND:CFIXED) return CFIXED; -- returns CFIXED(MAX(X'high,Y'high)+2 downto MIN(X'low,Y'low)) result
  function SWAP(X:CFIXED) return CFIXED; -- returns CFIXED(X'high downto X'low) result
  function CONJ(X:CFIXED) return CFIXED; -- returns CFIXED(X'high+2 downto X'low) result
  function SHIFT_RIGHT(X:CFIXED;N:INTEGER) return CFIXED; -- returns CFIXED(X'high-N downto X'low-N) result
  function SHIFT_LEFT(X:CFIXED;N:INTEGER) return CFIXED; -- returns CFIXED(X'high+N downto X'low+N) result
  function TO_CFIXED(R,I:REAL;H,L:INTEGER) return CFIXED; -- returns CFIXED(H downto L) result
  function TO_CFIXED(R,I:REAL;HL:CFIXED) return CFIXED; -- returns CFIXED(HL'high downto HL'low) result
  function TO_CFIXED(C:COMPLEX;HL:CFIXED) return CFIXED; -- returns CFIXED(RE(HL.RE'high downto HL.RE'low),IM(RE(HL.IM'high downto HL.IM'low)) result
  function TO_CFIXED(R,I:SFIXED) return CFIXED; -- returns CFIXED(2*MAX(R'high,I'high)+1 downto 2*MIN(R'low,I'low)) result
  function TO_COMPLEX(C:CFIXED) return COMPLEX; -- returns COMPLEX result
  function TO_CFIXED_VECTOR(C:COMPLEX_VECTOR;HL:CFIXED) return CFIXED_VECTOR; -- returns CFIXED_VECTOR(RE(HL.RE'high downto HL.RE'low),IM(RE(HL.IM'high downto HL.IM'low)) result
  function TO_COMPLEX_VECTOR(C:CFIXED_VECTOR;N:INTEGER) return COMPLEX_VECTOR; -- returns COMPLEX_VECTOR result
  function "*"(R:REAL;C:COMPLEX_VECTOR) return COMPLEX_VECTOR; -- returns R*C

  function ELEMENT(X:CFIXED_VECTOR;K,N:INTEGER) return CFIXED; -- returns element K out of an N-size array X
  procedure vELEMENT(X:out CFIXED_VECTOR;K,N:INTEGER;C:CFIXED); -- use when X is a variable, set element K out of an N-size array X to C
  procedure ELEMENT(signal X:out CFIXED_VECTOR;K,N:INTEGER;C:CFIXED); -- use when X is a signal, set element K out of an N-size array X to C

  function LOG2(N:INTEGER) return INTEGER; -- returns ceil(log2(N))
end COMPLEX_FIXED_PKG;

package body COMPLEX_FIXED_PKG is
--  function ELEMENT(X:CFIXED;K,N:INTEGER) return CFIXED is -- returns the CFIXED range for X(K)
--    variable O:CFIXED(X'length/N*(K+1)-1+X'low/N downto X'length/N*K+X'low/N);
--  begin
--    return O;
--  end;
  
--  function RE(X:CFIXED;K,N:INTEGER) return SFIXED is -- returns the CFIXED range for X(K).RE
--  begin
--    return RE(ELEMENT(X,K,N));
--  end;
  
--  function IM(X:CFIXED;K,N:INTEGER) return SFIXED is -- returns the CFIXED range for X(K).IM
--  begin
--    return IM(ELEMENT(X,K,N));
--  end;
  
  function MIN(A,B:INTEGER) return INTEGER is
  begin
    if A<B then
      return A;
    else
      return B;
    end if;
  end;
  
  function MIN(A,B,C:INTEGER) return INTEGER is
  begin
    return MIN(MIN(A,B),C);
  end;
  
  function MIN(A,B,C,D:INTEGER) return INTEGER is
  begin
    return MIN(MIN(A,B),MIN(C,D));
  end;
  
  function MED(A,B,C:INTEGER) return INTEGER is
  begin
    return MAX(MIN(A,B),MIN(MAX(A,B),C));
  end;
  
  function MAX(A,B:INTEGER) return INTEGER is
  begin
    if A>B then
      return A;
    else
      return B;
    end if;
  end;
  
  function MAX(A,B,C:INTEGER) return INTEGER is
  begin
    return MAX(MAX(A,B),C);
  end;
  
  function MAX(A,B,C,D:INTEGER) return INTEGER is
  begin
    return MAX(MAX(A,B),MAX(C,D));
  end;
  
  function "+"(X,Y:SFIXED) return SFIXED is
    variable SX,SY,SR:SIGNED(MAX(X'high,Y'high)+1-MIN(X'low,Y'low) downto 0);
    variable R:SFIXED(MAX(X'high,Y'high)+1 downto MIN(X'low,Y'low));
  begin
    for K in SX'range loop
      if K<X'low-Y'low then
        SX(K):='0';           -- zero pad X LSBs
      elsif K>X'high-R'low then
        SX(K):=X(X'high);     -- sign extend X MSBs
      else
        SX(K):=X(R'low+K);
      end if;
    end loop;
    for K in SY'range loop
      if K<Y'low-X'low then
        SY(K):='0';           -- zero pad Y LSBs
      elsif K>Y'high-R'low then
        SY(K):=Y(Y'high);     -- sign extend Y MSBs
      else
        SY(K):=Y(R'low+K);
      end if;
    end loop;
    SR:=SX+SY; -- SIGNED addition
    for K in SR'range loop
      R(R'low+K):=SR(K);
    end loop;
    return R;
  end;
  
  function "-"(X,Y:SFIXED) return SFIXED is
    variable SX,SY,SR:SIGNED(MAX(X'high,Y'high)+1-MIN(X'low,Y'low) downto 0);
    variable R:SFIXED(MAX(X'high,Y'high)+1 downto MIN(X'low,Y'low));
  begin
    for K in SX'range loop
      if K<X'low-Y'low then
        SX(K):='0';           -- zero pad X LSBs
      elsif K>X'high-R'low then
        SX(K):=X(X'high);     -- sign extend X MSBs
      else
        SX(K):=X(R'low+K);
      end if;
    end loop;
    for K in SY'range loop
      if K<Y'low-X'low then
        SY(K):='0';           -- zero pad Y LSBs
      elsif K>Y'high-R'low then
        SY(K):=Y(Y'high);     -- sign extend Y MSBs
      else
        SY(K):=Y(R'low+K);
      end if;
    end loop;
    SR:=SX-SY; -- SIGNED subtraction
    for K in SR'range loop
      R(R'low+K):=SR(K);
    end loop;
    return R;
  end;
  
  function "-"(X:SFIXED) return SFIXED is
    variable SX:SIGNED(X'high-X'low downto 0);
    variable SR:SIGNED(X'high-X'low+1 downto 0);
    variable R:SFIXED(X'high+1 downto X'low);
  begin
    for K in SX'range loop
      SX(K):=X(X'low+K);
    end loop;
    SR:=-RESIZE(SX,SR'length); -- SIGNED negation
    for K in SR'range loop
      R(R'low+K):=SR(K);
    end loop;
    return R;
  end;
  
  function "*"(X,Y:SFIXED) return SFIXED is
    variable SX:SIGNED(X'high-X'low downto 0);
    variable SY:SIGNED(Y'high-Y'low downto 0);
    variable SR:SIGNED(SX'high+SY'high+1 downto 0);
    variable R:SFIXED(X'high+Y'high+1 downto X'low+Y'low);
  begin
    for K in SX'range loop
      SX(K):=X(X'low+K);
    end loop;
    for K in SY'range loop
      SY(K):=Y(Y'low+K);
    end loop;
    SR:=SX*SY; -- SIGNED multiplication
    for K in SR'range loop
      R(R'low+K):=SR(K);
    end loop;
    return R;
  end;
  
  function "*"(X:SFIXED;Y:STD_LOGIC) return SFIXED is
  begin
    if Y='1' then
      return X;
    else
      return TO_SFIXED(0.0,X);
    end if;
  end;
  
  function RESIZE(X:SFIXED;H,L:INTEGER) return SFIXED is
    variable R:SFIXED(H downto L);
  begin
    for K in R'range loop
      if K<X'low then
        R(K):='0';           -- zero pad X LSBs
      elsif K>X'high then
        R(K):=X(X'high);     -- sign extend X MSBs
      else
        R(K):=X(K);
      end if;
    end loop;
    return R;
  end;
  
  function RESIZE(X:SFIXED;HL:SFIXED) return SFIXED is
  begin
    return RESIZE(X,HL'high,HL'low);
  end;
  
  function SHIFT_RIGHT(X:SFIXED;N:INTEGER) return SFIXED is
    variable R:SFIXED(X'high-N downto X'low-N);
  begin
    for K in R'range loop
      R(K):=X(K+N);
    end loop;
    return R;
  end;
  
  function SHIFT_LEFT(X:SFIXED;N:INTEGER) return SFIXED is
    variable R:SFIXED(X'high+N downto X'low+N);
  begin
    for K in R'range loop
      R(K):=X(K-N);
    end loop;
    return R;
  end;

  function TO_SFIXED(R:REAL;H,L:INTEGER) return SFIXED is
    variable RR:REAL;
    variable V:SFIXED(H downto L);
  begin
    assert (R<2.0**H) and (R>=-2.0**H) report "TO_SFIXED vector truncation!" severity warning;
    if R<0.0 then
      V(V'high):='1';
      RR:=R+2.0**V'high;
    else
      V(V'high):='0';
      RR:=R;
    end if;
    for K in V'high-1 downto V'low loop
      if RR>=2.0**K then
        V(K):='1';
        RR:=RR-2.0**K;
      else
        V(K):='0';
      end if;
    end loop;
    return V;
  end;
  
  function TO_SFIXED(R:REAL;HL:SFIXED) return SFIXED is
  begin
    return TO_SFIXED(R,HL'high,HL'low);
  end;

  function TO_REAL(S:SFIXED) return REAL is
    variable R:REAL;
  begin
    R:=0.0;
    for K in S'range loop
      if K=S'high then
        if S(K)='1' then
          R:=R-2.0**K;
        end if;
      else
        if S(K)='1' then
          R:=R+2.0**K;
        end if;
      end if;
    end loop;
    return R;
  end;

--  function ELEMENT(X:SFIXED_VECTOR;K,N:INTEGER) return SFIXED is -- X'low and X'length are always multiples of N
--    variable R:SFIXED(X'length/N-1+X'low/N downto X'low/N);
--  begin
--    R:=SFIXED(X((K+1)*R'length-1+X'low downto K*R'length+X'low));
--    return R; -- element K out of N of X
--  end;

  function RE(X:CFIXED) return SFIXED is -- X'low is always even and X'high is always odd
    variable R:SFIXED((X'high+1)/2-1 downto X'low/2);
  begin
    R:=SFIXED(X(R'length-1+X'low downto X'low));
    return R; --lower half of X
  end;

--  procedure vRE(X:out CFIXED;S:SFIXED) is -- X'low is always even and X'high is always odd
--  begin
--    X(S'length-1+X'low downto X'low):=CFIXED(S); -- set lower half of X
--  end;

--  procedure RE(signal X:out CFIXED;S:SFIXED) is -- X'low is always even and X'high is always odd
--  begin
--    X(S'length-1+X'low downto X'low)<=CFIXED(S); -- set lower half of X
--  end;

  function IM(X:CFIXED) return SFIXED is -- X'low is always even and X'high is always odd
    variable R:SFIXED((X'high+1)/2-1 downto X'low/2);
  begin
    R:=SFIXED(X(X'high downto R'length+X'low));
    return R; --upper half of X
  end;

--  procedure vIM(X:out CFIXED;S:SFIXED) is -- X'low is always even and X'high is always odd
--  begin
--    X(X'high downto S'length+X'low):=CFIXED(S); -- set upper half of X
--  end;

--  procedure IM(signal X:out CFIXED;S:SFIXED) is -- X'low is always even and X'high is always odd
--  begin
--    X(X'high downto S'length+X'low)<=CFIXED(S); -- set upper half of X
--  end;

  function "+"(X,Y:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)+RE(Y),IM(X)+IM(Y));
  end;
  
  function "-"(X,Y:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)-RE(Y),IM(X)-IM(Y));
  end;
  
  function "*"(X,Y:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)*RE(Y)-IM(X)*IM(Y),RE(X)*IM(Y)+IM(X)*RE(Y));
  end;

  function "*"(X:CFIXED;Y:SFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)*Y,IM(X)*Y);
  end;

  function "*"(X:SFIXED;Y:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(X*RE(Y),X*IM(Y));
  end;

  function RESIZE(X:CFIXED;H,L:INTEGER) return CFIXED is
  begin
    return TO_CFIXED(RESIZE(RE(X),H,L),RESIZE(IM(X),H,L));
  end;
  
  function RESIZE(X:CFIXED;HL:CFIXED) return CFIXED is
  begin
    return RESIZE(X,HL'high/2,HL'low/2);
  end;
  
  function PLUS_i_TIMES(X:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(-IM(X),RE(X));
  end;
  
  function "-"(X:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(-RE(X),-IM(X));
  end;
  
  function MINUS_i_TIMES(X:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(IM(X),-RE(X));
  end;
  
  function X_PLUS_i_TIMES_Y(X,Y:CFIXED;RND:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)-IM(Y)+RE(RND),IM(X)+RE(Y)+IM(RND));
  end;
  
  function X_MINUS_i_TIMES_Y(X,Y:CFIXED;RND:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X)+IM(Y)+RE(RND),IM(X)-RE(Y)+IM(RND));
  end;
  
  function SWAP(X:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(IM(X),RE(X));
  end;
  
  function CONJ(X:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(RE(X),-IM(X));
  end;
  
  function SHIFT_RIGHT(X:CFIXED;N:INTEGER) return CFIXED is
  begin
    return TO_CFIXED(SHIFT_RIGHT(RE(X),N),SHIFT_RIGHT(IM(X),N));
  end;
  
  function SHIFT_LEFT(X:CFIXED;N:INTEGER) return CFIXED is
  begin
    return TO_CFIXED(SHIFT_LEFT(RE(X),N),SHIFT_LEFT(IM(X),N));
  end;

  function TO_CFIXED(R,I:REAL;H,L:INTEGER) return CFIXED is
  begin
    return TO_CFIXED(TO_SFIXED(R,H,L),TO_SFIXED(I,H,L));
  end;
  
  function TO_CFIXED(R,I:REAL;HL:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(R,I,HL'high/2,HL'low/2);
  end;

  function TO_CFIXED(C:COMPLEX;HL:CFIXED) return CFIXED is
  begin
    return TO_CFIXED(C.RE,C.IM,HL);
  end;
  
  function TO_CFIXED(R,I:SFIXED) return CFIXED is
    constant H:INTEGER:=MAX(R'high,I'high);
    constant L:INTEGER:=MIN(R'low,I'low);
    variable C:CFIXED(2*H+1 downto 2*L);
  begin
    C:=CFIXED(RESIZE(I,H,L))&CFIXED(RESIZE(R,H,L));
    return C; -- I&R
  end;

  function ELEMENT(X:CFIXED_VECTOR;K,N:INTEGER) return CFIXED is -- X'low and X'length are always multiples of N
    variable R:CFIXED(X'length/N-1+X'low/N downto X'low/N);
  begin
    R:=CFIXED(X((K+1)*R'length-1+X'low downto K*R'length+X'low));
    return R; -- element K out of N of X
  end;

  procedure vELEMENT(X:out CFIXED_VECTOR;K,N:INTEGER;C:CFIXED) is -- X'low and X'length are always multiples of N
  begin
    X((K+1)*C'length-1+X'low downto K*C'length+X'low):=CFIXED_VECTOR(C); -- element K out of N of X
  end;

  procedure ELEMENT(signal X:out CFIXED_VECTOR;K,N:INTEGER;C:CFIXED) is -- X'low and X'length are always multiples of N
  begin
    X((K+1)*C'length-1+X'low downto K*C'length+X'low)<=CFIXED_VECTOR(C); -- element K out of N of X
  end;

  function TO_COMPLEX(C:CFIXED) return COMPLEX is
    variable R:COMPLEX;
  begin
    R.RE:=TO_REAL(RE(C));
    R.IM:=TO_REAL(IM(C));
    return R;
  end;
  
  function TO_CFIXED_VECTOR(C:COMPLEX_VECTOR;HL:CFIXED) return CFIXED_VECTOR is
    variable R:CFIXED_VECTOR(C'length*(HL'high+1)-1 downto C'length*HL'low);
  begin
    for K in C'range loop
      R((K-C'low+1)*HL'length-1+R'low downto (K-C'low)*HL'length+R'low):=CFIXED_VECTOR(TO_CFIXED(C(K),HL));
    end loop;
    return R;
  end;

  function TO_COMPLEX_VECTOR(C:CFIXED_VECTOR;N:INTEGER) return COMPLEX_VECTOR is
    variable R:COMPLEX_VECTOR(0 to N-1);
  begin
    for K in 0 to N-1 loop
      R(K):=TO_COMPLEX(ELEMENT(C,K,N));
    end loop;
    return R;
  end;

  function "*"(R:REAL;C:COMPLEX_VECTOR) return COMPLEX_VECTOR is
    variable X:COMPLEX_VECTOR(C'range);
  begin
    for K in C'range loop
      X(K):=R*C(K);
    end loop;
    return X;
  end;

  function LOG2(N:INTEGER) return INTEGER is
    variable TEMP:INTEGER;
    variable RESULT:INTEGER;
  begin
    TEMP:=N;
    RESULT:=0;
    while TEMP>1 loop
      RESULT:=RESULT+1;
      TEMP:=(TEMP+1)/2;
    end loop;  
    return RESULT; 
  end; 
end COMPLEX_FIXED_PKG;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ? Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             BDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     BDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic BOOLEAN Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity BDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in BOOLEAN;
       O:out BOOLEAN);
end BDELAY;

architecture TEST of BDELAY is
  attribute rloc:STRING;
  
  component BDELAY
    generic(SIZE:INTEGER:=1);
    port(CLK:in STD_LOGIC;
         I:in BOOLEAN;
         O:out BOOLEAN);
  end component;

begin
  l0:if SIZE=0 generate
     begin
       O<=I;
     end generate l0;
  --   end;

 l1:if SIZE=1 generate
       signal iO:BOOLEAN:=FALSE;
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iO<=I;
         end if;
       end process;
       O<=iO;
     end generate l1;
     -- end;

  l17: if SIZE>=2 and SIZE<18 generate
        signal A:UNSIGNED(3 downto 0);
        signal D,Q:STD_LOGIC;
        signal RQ:STD_LOGIC:='0';
        --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
      begin
        A<=TO_UNSIGNED(SIZE-2,A'length);
        D<='1' when I else '0';
        sr:SRL16E port map(CLK=>CLK,
                           CE=>'1',
                           A0=>A(0),
                           A1=>A(1),
                           A2=>A(2),
                           A3=>A(3),
                           D=>D,
                           Q=>Q);
        process(CLK)
        begin
          if rising_edge(CLK) then
            RQ<=Q;
          end if;
        end process;
        O<=RQ='1';	
      end generate l17;
  --   end;

  l33: if SIZE>=18 and SIZE<34 generate
--       signal MEM:UFIXED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       signal A:UNSIGNED(LOG2(SIZE-1)-1 downto 0):=(others=>'0');
--       attribute ram_style:STRING;
--       attribute ram_style of MEM:signal is "distributed";
            signal D,Q:STD_LOGIC;
       signal RQ:STD_LOGIC:='0';
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           if A=SIZE-2 then
             A<=(others=>'0');
           else
             A<=A+1;
           end if;
--           MEM(TO_INTEGER(A))<=I;
--           O<=MEM(TO_INTEGER(A));
         end if;
       end process;
--       O<=RESIZE(iO,O);
            D<='1' when I else '0';
            rs:RAM32X1S port map(A0=>A(0),
                                 A1=>A(1),
                                 A2=>A(2),
                                 A3=>A(3),
                                 A4=>A(4),
                                 D=>D,
                                 WCLK=>CLK,
                                 WE=>'1',
                                 O=>Q);
            process(CLK)
            begin
              if rising_edge(CLK) then
                RQ<=Q;
              end if;
            end process;
            O<=RQ='1';	
      end generate l33;
  --   end;

  l257: if SIZE>=34 and SIZE<BRAM_THRESHOLD generate
       signal iO:BOOLEAN;
     begin
       ld:entity work.BDELAY generic map(SIZE=>33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>iO);
       hd:entity work.BDELAY generic map(SIZE=>SIZE-33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>iO,
                                      O=>O);
     -- end;
      end generate l257;

  ln: if SIZE>=BRAM_THRESHOLD generate
--       signal MEM:UNSIGNED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       type TUV is array(0 to SIZE-3) of UNSIGNED(0 downto 0);
--2008       signal MEM:UNSIGNED_VECTOR(0 to SIZE-3)(0 downto 0):=(others=>(others=>'0'));
       signal MEM:TUV:=(others=>(others=>'0'));
       signal RA,WA:UNSIGNED(LOG2(SIZE-2)-1 downto 0):=(others=>'0');
       signal iO1E,iO:UNSIGNED(0 downto 0):=(others=>'0');
       signal D,Q:UNSIGNED(0 downto 0);
       attribute ram_style:STRING;
       attribute ram_style of MEM:signal is "block";
     begin
       D<="1" when I else "0";
       process(CLK)
       begin
         if rising_edge(CLK) then
--           if RA=SIZE-2 then
           if RA=SIZE-3 then
             RA<=(others=>'0');
           else
             RA<=RA+1;
           end if;
           WA<=RA;
           MEM(TO_INTEGER(WA))<=D;
--           iO<=MEM(TO_INTEGER(RA));
           iO1E<=MEM(TO_INTEGER(RA));
           iO<=iO1E;
           O<=iO="1";
         end if;
       end process;
     -- end;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             UDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     UDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic UNSIGNED Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity UDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in UNSIGNED;
       O:out UNSIGNED);
end UDELAY;

architecture TEST of UDELAY is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute rloc:STRING;
begin
  assert I'length=O'length report "Ports I and O must have the same length" severity error;

  l0:if SIZE=0 generate
     begin
       O<=I;
--     end;
     end generate;
--  elsif l1: SIZE=1 generate
  l1:if SIZE=1 generate
       signal iO:UNSIGNED(O'range):=(others=>'0');
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iO<=I;
         end if;
       end process;
       O<=iO;
--     end;
     end generate;
--  elsif l17: SIZE>=2 and SIZE<18 generate
  l17:if SIZE>=2 and SIZE<18 generate
        lk:for K in 0 to O'length-1 generate
             signal A:UNSIGNED(3 downto 0);
             signal Q:STD_LOGIC;
             signal RQ:STD_LOGIC:='0';
             --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
           begin
             A<=TO_UNSIGNED(SIZE-2,A'length);
             sr:SRL16E port map(CLK=>CLK,
                                CE=>'1',
                                A0=>A(0),
                                A1=>A(1),
                                A2=>A(2),
                                A3=>A(3),
                                D=>I(I'low+K),
                                Q=>Q);
             process(CLK)
             begin
               if rising_edge(CLK) then
                 RQ<=Q;
               end if;
             end process;
             O(O'low+K)<=RQ;	
           end generate;
--     end;
     end generate;
--  elsif l33: SIZE>=18 and SIZE<34 generate
  l33:if SIZE>=18 and SIZE<34 generate
--       signal MEM:UFIXED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       signal A:UNSIGNED(LOG2(SIZE-1)-1 downto 0):=(others=>'0');
--       attribute ram_style:STRING;
--       attribute ram_style of MEM:signal is "distributed";
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           if A=SIZE-2 then
             A<=(others=>'0');
           else
             A<=A+1;
           end if;
--           MEM(TO_INTEGER(A))<=I;
--           O<=MEM(TO_INTEGER(A));
         end if;
       end process;
--       O<=RESIZE(iO,O);
       lk:for K in 0 to I'length-1 generate
            signal Q:STD_LOGIC;
            signal RQ:STD_LOGIC:='0';
            --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
          begin
            rs:RAM32X1S port map(A0=>A(0),
                                 A1=>A(1),
                                 A2=>A(2),
                                 A3=>A(3),
                                 A4=>A(4),
                                 D=>I(I'low+K),
                                 WCLK=>CLK,
                                 WE=>'1',
                                 O=>Q);
            process(CLK)
            begin
              if rising_edge(CLK) then
                RQ<=Q;
              end if;
            end process;
            O(O'low+K)<=RQ;	
          end generate;
--     end;
     end generate;
--  elsif l257: SIZE>=34 and SIZE<BRAM_THRESHOLD generate
  l257:if SIZE>=34 and SIZE<BRAM_THRESHOLD generate
       signal iO:UNSIGNED(I'range);
     begin
       ld:entity work.UDELAY generic map(SIZE=>33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>iO);
       hd:entity work.UDELAY generic map(SIZE=>SIZE-33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>iO,
                                      O=>O);
--     end;
     end generate;
--  elsif ln: SIZE>=BRAM_THRESHOLD generate
  ln:if SIZE>=BRAM_THRESHOLD generate
--       signal MEM:UNSIGNED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
--2008       signal MEM:UNSIGNED_VECTOR(0 to SIZE-3)(I'range):=(others=>(others=>'0'));
       type TMEM is array(0 to SIZE-3) of UNSIGNED(I'range);
       signal MEM:TMEM:=(others=>(others=>'0'));
       signal RA,WA:UNSIGNED(LOG2(SIZE-2)-1 downto 0):=(others=>'0');
       signal iO1E,iO:UNSIGNED(I'range):=(others=>'0');
       attribute ram_style:STRING;
       attribute ram_style of MEM:signal is "block";
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
--           if RA=SIZE-2 then
           if RA=SIZE-3 then
             RA<=(others=>'0');
           else
             RA<=RA+1;
           end if;
           WA<=RA;
           MEM(TO_INTEGER(WA))<=I;
--           iO<=MEM(TO_INTEGER(RA));
           iO1E<=MEM(TO_INTEGER(RA));
           iO<=iO1E;
           O<=iO;
         end if;
       end process;
--     end;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             SDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     SDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic SFIXED Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity SDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in SFIXED;
       O:out SFIXED);
end SDELAY;

architecture TEST of SDELAY is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute rloc:STRING;
begin
--  assert I'length=O'length report "Ports I and O must have the same length" severity error;

  l0:if SIZE=0 generate
     begin
       O<=RESIZE(I,O'high,O'low);
	 end generate l0;  
     --end;

	 l1:if SIZE=1 generate
       signal iO:SFIXED(O'range):=(others=>'0');
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iO<=RESIZE(I,iO);
         end if;
       end process;
       O<=iO;
      end generate l1;
	 --end;
 
 l17:if SIZE>=2 and SIZE<18 generate
--        signal iO:SFIXED(I'range):=(others=>'0');
        signal iO:SFIXED(I'range);
      begin
        lk:for K in 0 to I'length-1 generate
             signal A:UNSIGNED(3 downto 0);
             signal Q:STD_LOGIC;
             signal RQ:STD_LOGIC:='0';
             --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
           begin
             A<=TO_UNSIGNED(SIZE-2,A'length);
             sr:SRL16E port map(CLK=>CLK,
                                CE=>'1',
                                A0=>A(0),
                                A1=>A(1),
                                A2=>A(2),
                                A3=>A(3),
                                D=>I(I'low+K),
                                Q=>Q);
             process(CLK)
             begin
               if rising_edge(CLK) then
                 RQ<=Q;
               end if;
             end process;
             iO(iO'low+K)<=RQ;	
           end generate;
           O<=RESIZE(iO,O'high,O'low);
       end generate l17;
	 --end;
  
 l33:if SIZE>=18 and SIZE<34 generate
--       signal MEM:SFIXED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       signal A:UNSIGNED(LOG2(SIZE-1)-1 downto 0):=(others=>'0');
--       signal iO:SFIXED(I'range):=(others=>'0');
       signal iO:SFIXED(I'range);
--       attribute ram_style:STRING;
--       attribute ram_style of MEM:signal is "distributed";
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           if A=SIZE-2 then
             A<=(others=>'0');
           else
             A<=A+1;
           end if;
--           MEM(TO_INTEGER(A))<=I;
--           iO<=MEM(TO_INTEGER(A));
         end if;
       end process;
--       O<=RESIZE(iO,O);
       lk:for K in 0 to I'length-1 generate
            signal Q:STD_LOGIC;
            signal RQ:STD_LOGIC:='0';
            --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
          begin
            rs:RAM32X1S port map(A0=>A(0),
                                 A1=>A(1),
                                 A2=>A(2),
                                 A3=>A(3),
                                 A4=>A(4),
                                 D=>I(I'low+K),
                                 WCLK=>CLK,
                                 WE=>'1',
                                 O=>Q);
            process(CLK)
            begin
              if rising_edge(CLK) then
                RQ<=Q;
              end if;
            end process;
            iO(iO'low+K)<=RQ;	
          end generate;
          O<=RESIZE(iO,O'high,O'low);
     end generate l33;
	 --end;
 
 l257:if SIZE>=34 and SIZE<BRAM_THRESHOLD generate
       signal iO:SFIXED(I'range);
     begin
       ld:entity work.SDELAY generic map(SIZE=>33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>iO);
       hd:entity work.SDELAY generic map(SIZE=>SIZE-33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>iO,
                                      O=>O);
     --end;
	end generate l257; 
 
 ln:if SIZE>=BRAM_THRESHOLD generate
--       signal MEM:SFIXED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
--2008       signal MEM:SFIXED_VECTOR(0 to SIZE-3)(I'range):=(others=>(others=>'0'));
       type TMEM is array(0 to SIZE-3) of SFIXED(I'range);
       signal MEM:TMEM:=(others=>(others=>'0'));
       signal RA,WA:UNSIGNED(LOG2(SIZE-2)-1 downto 0):=(others=>'0');
       signal iO1E,iO:SFIXED(I'range):=(others=>'0');
       attribute ram_style:STRING;
       attribute ram_style of MEM:signal is "block";
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
--           if RA=SIZE-2 then
           if RA=SIZE-3 then
             RA<=(others=>'0');
           else
             RA<=RA+1;
           end if;
           WA<=RA;
           MEM(TO_INTEGER(WA))<=I;
--           iO<=MEM(TO_INTEGER(RA));
           iO1E<=MEM(TO_INTEGER(RA));
           iO<=iO1E;
           O<=RESIZE(iO,O'high,O'low);
         end if;
       end process;
    -- end;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic CFIXED Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity CDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in CFIXED;
       O:out CFIXED);
end CDELAY;

architecture TEST of CDELAY is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute rloc:STRING;
  signal IRE,IIM:SFIXED((I'high+1)/2-1 downto I'low/2);
  signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
begin
  IRE<=RE(I);
  IIM<=IM(I);
  dr:entity work.SDELAY generic map(SIZE=>SIZE,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD)
                        port map(CLK=>CLK,
--2008                                 I=>I.RE,
--2008                                 O=>O.RE);
                                 I=>IRE,
                                 O=>ORE);
  di:entity work.SDELAY generic map(SIZE=>SIZE,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD)
                        port map(CLK=>CLK,
--2008                                 I=>I.IM,
--2008                                 O=>O.IM);
                                 I=>IIM,
                                 O=>OIM);
  O<=TO_CFIXED(ORE,OIM);
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CB.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CB
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14     2018-Feb-14 Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Matrix Transposer (Corner Bender) Module Stage
--                     It does an RxR matrix transposition where R=I'length
--                     and each matrix element is a group of PACKING_FACTOR consecutive samples
--                     LATENCY=(I'length-1)*PACKING_FACTOR+1 when I'length>1 or 0 when I'length=1
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CB is
  generic(SSR:INTEGER:=4; --93
          F:INTEGER:=0;
          PACKING_FACTOR:INTEGER:=1;
          INPUT_PACKING_FACTOR_ADJUST:INTEGER:=0;
          OUTPUT_PACKING_FACTOR_ADJUST:INTEGER:=0;
          SHORTEN_VO_BY:INTEGER:=0;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end CB;

architecture TEST of CB is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute rloc:STRING;

  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(LOG2(SSR)-1 downto 0); --93 local constrained UNSIGNED_VECTOR type
  type iCFIXED_VECTOR is array(NATURAL range <>) of CFIXED((I'high+1)/SSR-1 downto I'low/SSR); --93 local constrained CFIXED_VECTOR type
  
  signal CNTP:UNSIGNED(LOG2(PACKING_FACTOR) downto 0):=(others=>'0');
  signal CNT:UNSIGNED(LOG2(SSR)-1 downto 0):=(others=>'0');
--2008  signal A:UNSIGNED_VECTOR(0 to I'length):=(others=>(others=>'0'));
--2008  signal EN:BOOLEAN_VECTOR(0 to I'length):=(others=>FALSE);
--2008  signal DI:CFIXED_VECTOR(0 to I'length-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008  signal DO:CFIXED_VECTOR(0 to I'length-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(0 to I'length-1=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).IM'range=>'0')));
  signal A:UNSIGNED_VECTOR(0 to SSR):=(others=>(others=>'0'));
  signal EN:BOOLEAN_VECTOR(0 to SSR):=(others=>FALSE);
  signal II,DI,OO:iCFIXED_VECTOR(0 to SSR-1);
  signal DO:iCFIXED_VECTOR(0 to SSR-1):=(others=>(others=>'0'));
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**LOG2(I'length) report "Port I length must be a power of 2!" severity error;
  assert SSR=2**LOG2(SSR) report "SSR must be a power of 2!" severity error;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity error;

  f0:if F=0 generate
     begin
--2008       i0:if I'length=1 generate
       i0:if SSR=1 generate
            O<=I;
            VO<=VI;
            SO<=SI;
          end generate;
--2008          else generate
--2008       i1:if I'length>1 generate
       i1:if SSR>1 generate
            process(CLK)
            begin
              if rising_edge(CLK) then
                if VI then
                  if CNTP=PACKING_FACTOR-1 then
                    CNTP<=(others=>'0');
                    CNT<=CNT+1;
                  else
                    CNTP<=CNTP+1;
                  end if;
                else
                  CNTP<=(others=>'0');
                  CNT<=(others=>'0');
                end if;
              end if;
            end process;
            
            A(0)<=CNT;
            EN(0)<=CNTP=PACKING_FACTOR-1;
--2008            lk:for K in 0 to I'length-1 generate
            lk:for K in 0 to SSR-1 generate
               begin
                 II(K)<=CFIXED(I(I'length/SSR*(K+1)-1+I'low downto I'length/SSR*K+I'low)); --93
                 i1:entity work.CDELAY generic map(SIZE=>K*(PACKING_FACTOR+INPUT_PACKING_FACTOR_ADJUST),
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                       port map(CLK=>CLK,
                                                I=>II(K), --93 I(I'low+K),
                                                O=>DI(K));
                 process(CLK)
                 begin
                   if rising_edge(CLK) then
                     DO(K)<=DI(TO_INTEGER(A(K)));
                     if EN(K) then
                       A(K+1)<=A(K);
                     end if;
                   end if;
                 end process;
                 bd:entity work.BDELAY generic map(SIZE=>PACKING_FACTOR)
                                       port map(CLK=>CLK,
                                                I=>EN(K),
                                                O=>EN(K+1));
                 o1:entity work.CDELAY generic map(SIZE=>(SSR-1-K)*(PACKING_FACTOR+OUTPUT_PACKING_FACTOR_ADJUST),
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                       port map(CLK=>CLK,
                                                I=>DO(K),
                                                O=>OO(K)); --93 O(O'low+K));
                 O(O'length/SSR*(K+1)-1+O'low downto O'length/SSR*K+O'low)<=CFIXED_VECTOR(OO(K)); --93
               end generate;
           
            bd:entity work.BDELAY generic map(SIZE=>(SSR-1)*PACKING_FACTOR+1-SHORTEN_VO_BY)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
           
            ud:entity work.UDELAY generic map(SIZE=>(SSR-1)*PACKING_FACTOR+1-SHORTEN_VO_BY,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                  port map(CLK=>CLK,
                                           I=>SI,
                                           O=>SO);
       end generate;
--          end;
--     else generate
     end generate;
  i1:if F>0 generate
       constant G:INTEGER:=2**F;          -- size of each PARFFT
       constant H:INTEGER:=SSR/G;           -- number of PARFFTs
--2008       signal S:UNSIGNED_VECTOR(0 to H)(SO'range);
       type TUV is array(0 to H) of UNSIGNED(SO'range);
       signal S:TUV;
       signal V:BOOLEAN_VECTOR(0 to H-1);
     begin
       S(S'low)<=(others=>'0');
       lk:for K in 0 to H-1 generate
            signal SK:UNSIGNED(SO'range);
--workaround for QuestaSim bug
--2008            signal II:CFIXED_VECTOR(0 to G-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008            signal OO:CFIXED_VECTOR(0 to G-1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
            signal II:CFIXED_VECTOR((I'high+1)/H-1 downto I'low/H);
            signal OO:CFIXED_VECTOR((O'high+1)/H-1 downto O'low/H);
          begin
--2008            II<=I(I'low+G*K+0 to I'low+G*K+G-1);
            II<=I(I'length/H*(K+1)-1+I'low downto I'length/H*K+I'low);
            bc:entity work.CB generic map(SSR=>G,
                                          F=>0,
                                          PACKING_FACTOR=>PACKING_FACTOR,
                                          INPUT_PACKING_FACTOR_ADJUST=>INPUT_PACKING_FACTOR_ADJUST,
                                          OUTPUT_PACKING_FACTOR_ADJUST=>OUTPUT_PACKING_FACTOR_ADJUST,
                                          SHORTEN_VO_BY=>SHORTEN_VO_BY,
                                          BRAM_THRESHOLD=>BRAM_THRESHOLD)
                              port map(CLK=>CLK,
                                       I=>II,
                                       VI=>VI,
                                       SI=>SI,
                                       O=>OO,
                                       VO=>V(K),
                                       SO=>SK);
--workaround for QuestaSim bug
--            O(O'low+G*K+0 to O'low+G*K+G-1)<=OO;
--2008            lo:for J in 0 to G-1 generate
--2008                 O(O'low+G*K+J)<=OO(J);
--2008               end generate;
            O(O'length/H*(K+1)-1+O'low downto O'length/H*K+O'low)<=OO;
            S(K+1)<=S(K) or SK;
          end generate;
       SO<=S(S'high);
       VO<=V(V'high);
--     end;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             BFS.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     BFS
-- Purpose:         Generic Add/Subtract Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Real Arbitrary Fixed Point Size, Add/Subtract FFT Module with scaling and overflow detection
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity BFS is
  generic(PIPELINE:BOOLEAN:=TRUE;
          SUB:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          EXTRA_MSBs:INTEGER:=1);
  port(CLK:in STD_LOGIC:='0';
--       A,B:in SIGNED; -- if SIGNED, A, B and P must be LSB aligned
       A,B:in SFIXED; -- if SFIXED, A, B and P can be any size
       SCALE:in STD_LOGIC;
--       P:out SIGNED); -- O=A±B
       P:out SFIXED; -- O=A±B
       OVR:out STD_LOGIC);
end BFS;

architecture FAST of BFS is
  constant SH:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(A'high,B'high)+EXTRA_MSBs;
  constant SM:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(A'low,B'low);
  constant SL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(A'low,B'low);
--  signal SA,SB,M:SIGNED(SH+1 downto SM-1);
--  signal S:SIGNED(SH+1 downto SL);
  signal SA,SB:SFIXED(SH+1 downto SM-1);
  signal S:SFIXED(SH+1 downto SL);

  signal O5:SIGNED(SH-SM+1 downto 0);
  signal O6:SIGNED(SH-SM+1 downto 0);
  signal CY:STD_LOGIC_VECTOR((SH-SM+1)/8*8+8 downto 0);
  signal SI,DI,O:STD_LOGIC_VECTOR((SH-SM+1)/8*8+7 downto 0);
begin
  SA<=RESIZE(A,SA);
  SB<=RESIZE(B,SB);

  CY(0)<='1' when SUB else '0';
  lk:for K in SM to SH+1 generate
       constant I0:BIT_VECTOR(63 downto 0):=X"AAAAAAAAAAAAAAAA" xor (63 downto 0=>BIT'val(BOOLEAN'pos(SUB)));
       constant I1:BIT_VECTOR(63 downto 0):=X"CCCCCCCCCCCCCCCC";
       constant I2:BIT_VECTOR(63 downto 0):=X"F0F0F0F0F0F0F0F0" xor (63 downto 0=>BIT'val(BOOLEAN'pos(SUB)));
       constant I3:BIT_VECTOR(63 downto 0):=X"FF00FF00FF00FF00";
       constant I4:BIT_VECTOR(63 downto 0):=X"FFFF0000FFFF0000";
       constant I5:BIT_VECTOR(63 downto 0):=X"FFFFFFFF00000000";
     begin
       l6:LUT6_2 generic map(INIT=>(I5 and (((I0 and not I4) or (I2 and I4)) xor ((I1 and not I4) or (I3 and I4)))) or (not I5 and ((I1 and not I4) or (I3 and I4))))
                 port map(I0=>SB(K-1),I1=>SA(K-1),I2=>SB(K),I3=>SA(K),I4=>SCALE,I5=>'1',O5=>O5(K-SM),O6=>O6(K-SM));
     end generate;

  SI<=STD_LOGIC_VECTOR(RESIZE(O6,SI'length));
  DI<=STD_LOGIC_VECTOR(RESIZE(O5,DI'length));
  lj:for J in 0 to (SH-SM+1)/8 generate
     begin
       i1:if DSP48E=1 generate -- 7-series
            cl:CARRY4 port map(CI=>CY(8*J),                  -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+3 downto 8*J),     -- 4-bit carry-MUX data in
                               S=>SI(8*J+3 downto 8*J),      -- 4-bit carry-MUX select input
                               CO=>CY(8*J+4 downto 8*J+1),   -- 4-bit carry out
                               O=>O(8*J+3 downto 8*J));      -- 4-bit carry chain XOR data out
            ch:CARRY4 port map(CI=>CY(8*J+4),                -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+7 downto 8*J+4),   -- 4-bit carry-MUX data in
                               S=>SI(8*J+7 downto 8*J+4),    -- 4-bit carry-MUX select input
                               CO=>CY(8*J+8 downto 8*J+5),   -- 4-bit carry out
                               O=>O(8*J+7 downto 8*J+4));    -- 4-bit carry chain XOR data out
       end generate;
       i2:if DSP48E=2 generate -- US/US+
            c8:CARRY8 generic map(CARRY_TYPE=>"SINGLE_CY8")  -- 8-bit or dual 4-bit carry (DUAL_CY4, SINGLE_CY8)
                      port map(CI=>CY(8*J),                  -- 1-bit input: Lower Carry-In
                               CI_TOP=>'0',                  -- 1-bit input: Upper Carry-In
                               DI=>DI(8*J+7 downto 8*J),     -- 8-bit input: Carry-MUX data in
                               S=>SI(8*J+7 downto 8*J),      -- 8-bit input: Carry-mux select
                               CO=>CY(8*J+8 downto 8*J+1),   -- 8-bit output: Carry-out
                               O=>O(8*J+7 downto 8*J));      -- 8-bit output: Carry chain XOR data out
       end generate;
     end generate;

  ll:for L in SM to SH generate
       S(L)<=O(L-SM+1);
     end generate;
  S(SH+1)<=O(O'high);

  ia:if A'low<B'low generate
       S(SM-1 downto SL)<=A(SM-1 downto SL);
     end generate;
     
  ib:if B'low<A'low generate
       S(SM-1 downto SL)<=B(SM-1 downto SL);
     end generate;

  i0:if not PIPELINE generate
       P<=RESIZE(S,P'high,P'low);
       OVR<=S(S'high) xor S(S'high-1);
     end generate;

  i1:if PIPELINE generate
       signal iP:SFIXED(P'range):=(others=>'0');
       signal iOVR:STD_LOGIC:='0';
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iP<=RESIZE(S,P'high,P'low);
           iOVR<=S(S'high) xor S(S'high-1);
         end if;
       end process;
       P<=iP;
       OVR<=iOVR;
     end generate;
end FAST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CBFS.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CBFS
-- Purpose:         Generic Add/Subtract Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Complex Arbitrary Fixed Point Size, Add/Subtract FFT Module with scaling and overflow detection
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CBFS is -- O0=I0+I1, O1=I0-I1
  generic(ROUNDING:BOOLEAN:=TRUE;
          PIPELINE:BOOLEAN:=TRUE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          EXTRA_MSBs:INTEGER:=1);
  port(CLK:in STD_LOGIC;
         I0,I1:in CFIXED;
         SCALE:in STD_LOGIC;
         O0,O1:out CFIXED;
         OVR:out STD_LOGIC);
end CBFS;

architecture TEST of CBFS is
  signal I0RE,I0IM,I1RE,I1IM:SFIXED(I0'high/2 downto I0'low/2);
  signal O0RE,O0IM,O1RE,O1IM:SFIXED(O0'high/2 downto O0'low/2);
  signal OVR4:STD_LOGIC_VECTOR(3 downto 0);
begin
  I0RE<=RE(I0);
  I0IM<=IM(I0);
  I1RE<=RE(I1);
  I1IM<=IM(I1);
  
  u0:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>FALSE) -- O0RE=I0RE+I1RE
                     port map(CLK=>CLK,
                              A=>I0RE,
                              B=>I1RE,
                              SCALE=>SCALE,
                              P=>O0RE,
                              OVR=>OVR4(0));

  u1:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>FALSE) -- O0IM=I0IM+I1IM
                     port map(CLK=>CLK,
                              A=>I0IM,
                              B=>I1IM,
                              SCALE=>SCALE,
                              P=>O0IM,
                              OVR=>OVR4(1));

  u2:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>TRUE) -- O1RE=I0RE-I1RE
                     port map(CLK=>CLK,
                              A=>I0RE,
                              B=>I1RE,
                              SCALE=>SCALE,
                              P=>O1RE,
                              OVR=>OVR4(2));

  u3:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>TRUE) -- O1IM=I0IM-I1IM
                     port map(CLK=>CLK,
                              A=>I0IM,
                              B=>I1IM,
                              SCALE=>SCALE,
                              P=>O1IM,
                              OVR=>OVR4(3));

  O0<=TO_CFIXED(O0RE,O0IM);
  O1<=TO_CFIXED(O1RE,O1IM);
  OVR<=OVR4(0) or OVR4(1) or OVR4(2) or OVR4(3);
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CSA3.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CSA3
-- Purpose:         Generic 3-input Add/Sub Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Carry Save 3-input Adder/Subtracter
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity CSA3 is
  generic(PIPELINE:BOOLEAN:=TRUE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          NEGATIVE_A:BOOLEAN:=FALSE;
          NEGATIVE_B:BOOLEAN:=FALSE;
          EXTRA_MSBs:INTEGER:=2);
  port(CLK:in STD_LOGIC:='0';
--       A,B,C:in SIGNED; -- if SIGNED, A, B, C and P must be LSB aligned
       A,B,C:in SFIXED; -- if SFIXED, A, B, C and P can be any size
       CY1,CY2:in BOOLEAN:=FALSE; -- the number of CYs TRUE must equal the number of negative A and B terms
--       P:out SIGNED); -- O=C±A±B
       P:out SFIXED); -- O=C±A±B
end CSA3;

architecture FAST of CSA3 is
  constant SH:INTEGER:=MAX(A'high,B'high,C'high)+EXTRA_MSBs;
  constant SM:INTEGER:=work.COMPLEX_FIXED_PKG.MED(A'low,B'low,C'low);
  constant SL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(A'low,B'low,C'low);
--  signal SA,SB,SC,M:SIGNED(SH downto SM);
--  signal S:SIGNED(SH downto SL);
  signal SA,SB,SC:SFIXED(SH downto SM);
  signal S:SFIXED(SH downto SL);

  signal O5:SIGNED(SH-SM+1 downto 0);
  signal O6:SIGNED(SH-SM downto 0);
  signal CY:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8 downto 0);
  signal SI,DI,O:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8-1 downto 0);
begin
  SA<=RESIZE(A,SA);
  SB<=RESIZE(B,SB);
  SC<=RESIZE(C,SC);
  O5(0)<='1' when CY1 else '0';
  CY(0)<='1' when CY2 else '0';
  lk:for K in SM to SH generate
       constant I0:BIT_VECTOR(63 downto 0):=X"AAAAAAAAAAAAAAAA";
       constant I1:BIT_VECTOR(63 downto 0):=X"CCCCCCCCCCCCCCCC";
       constant I2:BIT_VECTOR(63 downto 0):=X"F0F0F0F0F0F0F0F0" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_B)));
       constant I3:BIT_VECTOR(63 downto 0):=X"FF00FF00FF00FF00" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_A)));
       constant I4:BIT_VECTOR(63 downto 0):=X"FFFF0000FFFF0000";
       constant I5:BIT_VECTOR(63 downto 0):=X"FFFFFFFF00000000";
     begin
       l6:LUT6_2 generic map(INIT=>(I5 and (I1 xor I2 xor I3 xor I4)) or (not I5 and ((I2 and I3) or (I3 and I1) or (I1 and I2))))
                 port map(I0=>'0',I1=>SC(K),I2=>SB(K),I3=>SA(K),I4=>O5(K-SM),I5=>'1',O5=>O5(K+1-SM),O6=>O6(K-SM));
     end generate;

  SI<=STD_LOGIC_VECTOR(RESIZE(O6,SI'length));
  DI<=STD_LOGIC_VECTOR(RESIZE(O5,DI'length));
  lj:for J in 0 to (SH-SM)/8 generate
     begin
       i1:if DSP48E=1 generate -- 7-series
            cl:CARRY4 port map(CI=>CY(8*J),                  -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+3 downto 8*J),     -- 4-bit carry-MUX data in
                               S=>SI(8*J+3 downto 8*J),      -- 4-bit carry-MUX select input
                               CO=>CY(8*J+4 downto 8*J+1),   -- 4-bit carry out
                               O=>O(8*J+3 downto 8*J));      -- 4-bit carry chain XOR data out
            ch:CARRY4 port map(CI=>CY(8*J+4),                -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+7 downto 8*J+4),   -- 4-bit carry-MUX data in
                               S=>SI(8*J+7 downto 8*J+4),    -- 4-bit carry-MUX select input
                               CO=>CY(8*J+8 downto 8*J+5),   -- 4-bit carry out
                               O=>O(8*J+7 downto 8*J+4));    -- 4-bit carry chain XOR data out
       end generate;
       i2:if DSP48E=2 generate -- US/US+
            c8:CARRY8 generic map(CARRY_TYPE=>"SINGLE_CY8")  -- 8-bit or dual 4-bit carry (DUAL_CY4, SINGLE_CY8)
                      port map(CI=>CY(8*J),                  -- 1-bit input: Lower Carry-In
                               CI_TOP=>'0',                  -- 1-bit input: Upper Carry-In
                               DI=>DI(8*J+7 downto 8*J),     -- 8-bit input: Carry-MUX data in
                               S=>SI(8*J+7 downto 8*J),      -- 8-bit input: Carry-mux select
                               CO=>CY(8*J+8 downto 8*J+1),   -- 8-bit output: Carry-out
                               O=>O(8*J+7 downto 8*J));      -- 8-bit output: Carry chain XOR data out
       end generate;
     end generate;

  ll:for L in SM to SH generate
       S(L)<=O(L-SM);
     end generate;

  ia:if (A'low<B'low) and (A'low<C'low) generate
       S(SM-1 downto SL)<=A(SM-1 downto SL);
     end generate;
     
  ib:if (B'low<C'low) and (B'low<A'low) generate
       S(SM-1 downto SL)<=B(SM-1 downto SL);
     end generate;
     
  ic:if (C'low<A'low) and (C'low<B'low) generate
       S(SM-1 downto SL)<=C(SM-1 downto SL);
     end generate;
     
  i0:if not PIPELINE generate
       P<=RESIZE(S,P'high,P'low);
     end generate;

  i1:if PIPELINE generate
       signal iP:SFIXED(P'range):=(others=>'0');
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iP<=RESIZE(S,P'high,P'low);
         end if;
       end process;
       P<=iP;
     end generate;
end FAST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
--*****************************************************************************
-- © Copyright 2008 - 2018 Xilinx, Inc. All rights reserved.
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
--
--*****************************************************************************
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor                : Xilinx
-- \   \   \/     Version               : v1.2
--  \   \         Application           : DSP48E2 generic wrapper
--  /   /         Filename              : DSP48E2GW.vhd
-- /___/   /\     Date Last Modified    : Oct 11 2017
-- \   \  /  \    Date Created          : Nov 14 2014
--  \___\/\___\
--
--Device            : UltraScale and UltraScale+
--Design Name       : DSP48E2GW
--Purpose           : DSP48E2 Generic Wrapper makes DSP48E2 primitive instantiation easier
--Reference         : 
--Revision History  : v1.0 - original version
--Revision History  : v1.1 - smart SFIXED resizing
--Revision History  : v1.2 - fix for output resizing
--*****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.all;
--use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity DSP48E2GW is
  generic(X,Y:INTEGER:=-1;
          DSP48E:INTEGER:=2; -- use 1 for DSP48E1 and 2 for DSP48E2
          -- Feature Control Attributes: Data Path Selection
          AMULTSEL:STRING:="A";                                      -- Selects A input to multiplier (A, AD)
          A_INPUT:STRING:="DIRECT";                                  -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
          BMULTSEL:STRING:="B";                                      -- Selects B input to multiplier (AD, B)
          B_INPUT:STRING:="DIRECT";                                  -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
          PREADDINSEL:STRING:="A";                                   -- Selects input to preadder (A, B)
          RND:STD_LOGIC_VECTOR(47 downto 0):=X"000000000000";        -- Rounding Constant
          USE_MULT:STRING:="MULTIPLY";                               -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
          USE_SIMD:STRING:="ONE48";                                  -- SIMD selection (FOUR12, ONE48, TWO24)
          USE_WIDEXOR:STRING:="FALSE";                               -- Use the Wide XOR function (FALSE, TRUE)
          XORSIMD:STRING:="XOR24_48_96";                             -- Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
          -- Pattern Detector Attributes: Pattern Detection Configuration
          AUTORESET_PATDET:STRING:="NO_RESET";                       -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
          AUTORESET_PRIORITY:STRING:="RESET";                        -- Priority of AUTORESET vs.CEP (CEP, RESET).
          MASK:STD_LOGIC_VECTOR(47 downto 0):=X"3fffffffffff";       -- 48-bit mask value for pattern detect (1=ignore)
          PATTERN:STD_LOGIC_VECTOR(47 downto 0):=X"000000000000";    -- 48-bit pattern match for pattern detect
          SEL_MASK:STRING:="MASK";                                   -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
          SEL_PATTERN:STRING:="PATTERN";                             -- Select pattern value (C, PATTERN)
          USE_PATTERN_DETECT:STRING:="NO_PATDET";                    -- Enable pattern detect (NO_PATDET, PATDET)
          -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
          IS_ALUMODE_INVERTED:STD_LOGIC_VECTOR(3 downto 0):=X"0";    -- Optional inversion for ALUMODE
          IS_CARRYIN_INVERTED:BIT:='0';                              -- Optional inversion for CARRYIN
          IS_CLK_INVERTED:BIT:='0';                                  -- Optional inversion for CLK
          IS_INMODE_INVERTED:STD_LOGIC_VECTOR(4 downto 0):="00000";  -- Optional inversion for INMODE
          IS_OPMODE_INVERTED:STD_LOGIC_VECTOR(8 downto 0):="000000000";  -- Optional inversion for OPMODE
          IS_RSTALLCARRYIN_INVERTED:BIT:='0';                        -- Optional inversion for RSTALLCARRYIN
          IS_RSTALUMODE_INVERTED:BIT:='0';                           -- Optional inversion for RSTALUMODE
          IS_RSTA_INVERTED:BIT:='0';                                 -- Optional inversion for RSTA
          IS_RSTB_INVERTED:BIT:='0';                                 -- Optional inversion for RSTB
          IS_RSTCTRL_INVERTED:BIT:='0';                              -- Optional inversion for RSTCTRL
          IS_RSTC_INVERTED:BIT:='0';                                 -- Optional inversion for RSTC
          IS_RSTD_INVERTED:BIT:='0';                                 -- Optional inversion for RSTD
          IS_RSTINMODE_INVERTED:BIT:='0';                            -- Optional inversion for RSTINMODE
          IS_RSTM_INVERTED:BIT:='0';                                 -- Optional inversion for RSTM
          IS_RSTP_INVERTED:BIT:='0';                                 -- Optional inversion for RSTP
          -- Register Control Attributes: Pipeline Register Configuration
          ACASCREG:INTEGER:=1;                                       -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
          ADREG:INTEGER:=1;                                          -- Pipeline stages for pre-adder (0-1)
          ALUMODEREG:INTEGER:=1;                                     -- Pipeline stages for ALUMODE (0-1)
          AREG:INTEGER:=1;                                           -- Pipeline stages for A (0-2)
          BCASCREG:INTEGER:=1;                                       -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
          BREG:INTEGER:=1;                                           -- Pipeline stages for B (0-2)
          CARRYINREG:INTEGER:=1;                                     -- Pipeline stages for CARRYIN (0-1)
          CARRYINSELREG:INTEGER:=1;                                  -- Pipeline stages for CARRYINSEL (0-1)
          CREG:INTEGER:=1;                                           -- Pipeline stages for C (0-1)
          DREG:INTEGER:=1;                                           -- Pipeline stages for D (0-1)
          INMODEREG:INTEGER:=1;                                      -- Pipeline stages for INMODE (0-1)
          MREG:INTEGER:=1;                                           -- Multiplier pipeline stages (0-1)
          OPMODEREG:INTEGER:=1;                                      -- Pipeline stages for OPMODE (0-1)
          PREG:INTEGER:=1);                                          -- Number of pipeline stages for P (0-1)
  port(-- Cascade inputs: Cascade Ports
       ACIN:in STD_LOGIC_VECTOR(29 downto 0):=(others=>'0');         -- 30-bit input: A cascade data
       BCIN:in STD_LOGIC_VECTOR(17 downto 0):=(others=>'0');         -- 18-bit input: B cascade
       CARRYCASCIN:in STD_LOGIC:='0';                                -- 1-bit input: Cascade carry
       MULTSIGNIN:in STD_LOGIC:='0';                                 -- 1-bit input: Multiplier sign cascade
       PCIN:in STD_LOGIC_VECTOR(47 downto 0):=(others=>'0');         -- 48-bit input: P cascade
       -- Control inputs: Control Inputs/Status Bits
       ALUMODE:in STD_LOGIC_VECTOR(3 downto 0):=X"0";                -- 4-bit input: ALU control
       CARRYINSEL:in STD_LOGIC_VECTOR(2 downto 0):="000";            -- 3-bit input: Carry select
       CLK:in STD_LOGIC:='0';                                        -- 1-bit input: Clock
       INMODE:in STD_LOGIC_VECTOR(4 downto 0):="00000";              -- 5-bit input: INMODE control
       OPMODE:in STD_LOGIC_VECTOR(8 downto 0):="000110101";          -- 9-bit input: Operation mode - default is P<=C+A*B
       -- Data inputs: Data Ports
       A:in SFIXED;--(Ahi downto Alo):=(others=>'0');                   -- 30-bit input: A data
       B:in SFIXED;--(Bhi downto Blo):=(others=>'0');                   -- 18-bit input: B data
       C:in SFIXED;--(Chi downto Clo):=(others=>'0');                   -- 48-bit input: C data
       CARRYIN:in STD_LOGIC:='0';                                    -- 1-bit input: Carry-in
       D:in SFIXED;--(Dhi downto Dlo):=(others=>'0');                   -- 27-bit input: D data
       -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
       CEA1:in STD_LOGIC:='1';                                       -- 1-bit input: Clock enable for 1st stage AREG
       CEA2:in STD_LOGIC:='1';                                       -- 1-bit input: Clock enable for 2nd stage AREG
       CEAD:in STD_LOGIC:='1';                                       -- 1-bit input: Clock enable for ADREG
       CEALUMODE:in STD_LOGIC:='1';                                  -- 1-bit input: Clock enable for ALUMODE
       CEB1:in STD_LOGIC:='1';                                       -- 1-bit input: Clock enable for 1st stage BREG
       CEB2:in STD_LOGIC:='1';                                       -- 1-bit input: Clock enable for 2nd stage BREG
       CEC:in STD_LOGIC:='1';                                        -- 1-bit input: Clock enable for CREG
       CECARRYIN:in STD_LOGIC:='1';                                  -- 1-bit input: Clock enable for CARRYINREG
       CECTRL:in STD_LOGIC:='1';                                     -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
       CED:in STD_LOGIC:='1';                                        -- 1-bit input: Clock enable for DREG
       CEINMODE:in STD_LOGIC:='1';                                   -- 1-bit input: Clock enable for INMODEREG
       CEM:in STD_LOGIC:='1';                                        -- 1-bit input: Clock enable for MREG
       CEP:in STD_LOGIC:='1';                                        -- 1-bit input: Clock enable for PREG
       RSTA:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for AREG
       RSTALLCARRYIN:in STD_LOGIC:='0';                              -- 1-bit input: Reset for CARRYINREG
       RSTALUMODE:in STD_LOGIC:='0';                                 -- 1-bit input: Reset for ALUMODEREG
       RSTB:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for BREG
       RSTC:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for CREG
       RSTCTRL:in STD_LOGIC:='0';                                    -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
       RSTD:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for DREG and ADREG
       RSTINMODE:in STD_LOGIC:='0';                                  -- 1-bit input: Reset for INMODEREG
       RSTM:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for MREG
       RSTP:in STD_LOGIC:='0';                                       -- 1-bit input: Reset for PREG
       -- Cascade outputs: Cascade Ports
       ACOUT:out STD_LOGIC_VECTOR(29 downto 0);                      -- 30-bit output: A port cascade
       BCOUT:out STD_LOGIC_VECTOR(17 downto 0);                      -- 18-bit output: B cascade
       CARRYCASCOUT:out STD_LOGIC;                                   -- 1-bit output: Cascade carry
       MULTSIGNOUT:out STD_LOGIC;                                    -- 1-bit output: Multiplier sign cascade
       PCOUT:out STD_LOGIC_VECTOR(47 downto 0);                      -- 48-bit output: Cascade output
       -- Control outputs: Control Inputs/Status Bits
       OVERFLOW:out STD_LOGIC;                                       -- 1-bit output: Overflow in add/acc
       PATTERNBDETECT:out STD_LOGIC;                                 -- 1-bit output: Pattern bar detect
       PATTERNDETECT:out STD_LOGIC;                                  -- 1-bit output: Pattern detect
       UNDERFLOW:out STD_LOGIC;                                      -- 1-bit output: Underflow in add/acc
       -- Data outputs: Data Ports
       CARRYOUT:out STD_LOGIC_VECTOR(3 downto 0);                    -- 4-bit output: Carry
       P:out SFIXED;--(Phi downto Plo);                                 -- 48-bit output: Primary data
       XOROUT:out STD_LOGIC_VECTOR(7 downto 0));                     -- 8-bit output: XOR data
end entity;

architecture WRAPPER of DSP48E2GW is
  signal slvA:STD_LOGIC_VECTOR(29 downto 0);
  signal slvB:STD_LOGIC_VECTOR(17 downto 0);
  signal slvD:STD_LOGIC_VECTOR(26 downto 0);
  signal slvC,slvP:STD_LOGIC_VECTOR(47 downto 0);
-- resize SFIXED and convert to STD_LOGIC_VECTOR
  function SFIXED_TO_SLV_RESIZE(I:SFIXED;hi,lo:INTEGER) return STD_LOGIC_VECTOR is
    variable O:STD_LOGIC_VECTOR(hi-lo downto 0);
  begin
    for K in O'range loop
      if K<I'low-lo then
        O(K):='0';
      elsif K<I'length then
        O(K):=I(K+lo);
      else
        O(K):=I(I'high);
      end if;
    end loop;
    return O;
  end;
-- convert STD_LOGIC_VECTOR to SFIXED and resize 
  function SLV_TO_SFIXED_RESIZE(I:STD_LOGIC_VECTOR;hi,lo:INTEGER;ofs:INTEGER:=0) return SFIXED is
    variable O:SFIXED(hi downto lo);
  begin
    for K in O'range loop
      if K<I'low+lo+ofs then
        O(K):='0';
      elsif K-lo-ofs<I'length then
        O(K):=I(K-lo-ofs);
      else
        O(K):=I(I'high);
      end if;
    end loop;
    return O;
  end;
  
  function MIN(X,Y:INTEGER) return INTEGER is
  begin
    if X<Y then
      return X;
    else
      return Y;
    end if;
  end;
  
  constant AD_low:INTEGER:=MIN(A'low,D'low);
  constant BD_low:INTEGER:=MIN(B'low,D'low);
  constant CAD_low:INTEGER:=MIN(AD_low+B'low,P'low);
  constant CBD_low:INTEGER:=MIN(BD_low+A'low,P'low);
begin
  slvA<=SFIXED_TO_SLV_RESIZE(A,AD_low+slvA'length-1,AD_low) when PREADDINSEL="A" else
        SFIXED_TO_SLV_RESIZE(A,A'low+slvA'length-1,A'low); -- when PREADDINSEL="B"
  slvB<=SFIXED_TO_SLV_RESIZE(B,B'low+slvB'length-1,B'low) when PREADDINSEL="A" else
        SFIXED_TO_SLV_RESIZE(B,BD_low+slvB'length-1,BD_low); -- when PREADDINSEL="B"
  slvC<=SFIXED_TO_SLV_RESIZE(C,CAD_low+slvC'length-1,CAD_low) when PREADDINSEL="A" else
        SFIXED_TO_SLV_RESIZE(C,CBD_low+slvC'length-1,CBD_low); -- when PREADDINSEL="B"
  slvD<=SFIXED_TO_SLV_RESIZE(D,AD_low+slvD'length-1,AD_low) when PREADDINSEL="A" else
        SFIXED_TO_SLV_RESIZE(D,BD_low+slvD'length-1,BD_low); -- when PREADDINSEL="B"
-- two versions to avoid creating false Vivado critical warnings when no LOC constraints are used
  i1:if (X>=0) and (Y>=0) generate
     begin
       i1:if DSP48E=1 generate
            attribute loc:STRING;
            attribute loc of ds:label is "DSP48E2_X"&INTEGER'image(X)&"Y"&INTEGER'image(Y);
          begin
            ds:DSP48E1 generic map(-- Feature Control Attributes: Data Path Selection
                                   A_INPUT => A_INPUT,                                     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                   B_INPUT => B_INPUT,                                     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                   USE_MULT => USE_MULT,                                   -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                   USE_SIMD => USE_SIMD,                                   -- SIMD selection (FOUR12, ONE48, TWO24)
                                   -- Pattern Detector Attributes: Pattern Detection Configuration
                                   AUTORESET_PATDET => AUTORESET_PATDET,                   -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
--                                   MASK => MASK,                                           -- 48-bit mask value for pattern detect (1=ignore)
--                                   PATTERN => PATTERN,                                     -- 48-bit pattern match for pattern detect
                                   SEL_MASK => SEL_MASK,                                   -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                   SEL_PATTERN => SEL_PATTERN,                             -- Select pattern value (C, PATTERN)
                                   USE_PATTERN_DETECT => USE_PATTERN_DETECT,               -- Enable pattern detect (NO_PATDET, PATDET)
                                   -- Register Control Attributes: Pipeline Register Configuration
                                   ACASCREG => ACASCREG,                                   -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                   ADREG => ADREG,                                         -- Pipeline stages for pre-adder (0-1)
                                   ALUMODEREG => ALUMODEREG,                               -- Pipeline stages for ALUMODE (0-1)
                                   AREG => AREG,                                           -- Pipeline stages for A (0-2)
                                   BCASCREG => BCASCREG,                                   -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                   BREG => BREG,                                           -- Pipeline stages for B (0-2)
                                   CARRYINREG => CARRYINREG,                               -- Pipeline stages for CARRYIN (0-1)
                                   CARRYINSELREG => CARRYINSELREG,                         -- Pipeline stages for CARRYINSEL (0-1)
                                   CREG => CREG,                                           -- Pipeline stages for C (0-1)
                                   DREG => DREG,                                           -- Pipeline stages for D (0-1)
                                   INMODEREG => INMODEREG,                                 -- Pipeline stages for INMODE (0-1)
                                   MREG => MREG,                                           -- Multiplier pipeline stages (0-1)
                                   OPMODEREG => OPMODEREG,                                 -- Pipeline stages for OPMODE (0-1)
                                   PREG => PREG)                                           -- Number of pipeline stages for P (0-1)
                       port map(-- Cascade inputs: Cascade Ports
                                ACIN => ACIN,                                              -- 30-bit input: A cascade data
                                BCIN => BCIN,                                              -- 18-bit input: B cascade
                                CARRYCASCIN => CARRYCASCIN,                                -- 1-bit input: Cascade carry
                                MULTSIGNIN => MULTSIGNIN,                                  -- 1-bit input: Multiplier sign cascade
                                PCIN => PCIN,                                              -- 48-bit input: P cascade
                                -- Control inputs: Control Inputs/Status Bits
                                ALUMODE => ALUMODE,                                        -- 4-bit input: ALU control
                                CARRYINSEL => CARRYINSEL,                                  -- 3-bit input: Carry select
                                CLK => CLK,                                                -- 1-bit input: Clock
                                INMODE => INMODE,                                          -- 5-bit input: INMODE control
                                OPMODE => OPMODE(6 downto 0),                              -- 7-bit input: Operation mode
                                -- Data inputs: Data Ports
                                A => slvA,                                                 -- 30-bit input: A data
                                B => slvB,                                                 -- 18-bit input: B data
                                C => slvC,                                                 -- 48-bit input: C data
                                CARRYIN => CARRYIN,                                        -- 1-bit input: Carry-in
                                D => slvD(24 downto 0),                                    -- 25-bit input: D data
                                -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                CEA1 => CEA1,                                              -- 1-bit input: Clock enable for 1st stage AREG
                                CEA2 => CEA2,                                              -- 1-bit input: Clock enable for 2nd stage AREG
                                CEAD => CEAD,                                              -- 1-bit input: Clock enable for ADREG
                                CEALUMODE => CEALUMODE,                                    -- 1-bit input: Clock enable for ALUMODE
                                CEB1 => CEB1,                                              -- 1-bit input: Clock enable for 1st stage BREG
                                CEB2 => CEB2,                                              -- 1-bit input: Clock enable for 2nd stage BREG
                                CEC => CEC,                                                -- 1-bit input: Clock enable for CREG
                                CECARRYIN => CECARRYIN,                                    -- 1-bit input: Clock enable for CARRYINREG
                                CECTRL => CECTRL,                                          -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                CED => CED,                                                -- 1-bit input: Clock enable for DREG
                                CEINMODE => CEINMODE,                                      -- 1-bit input: Clock enable for INMODEREG
                                CEM => CEM,                                                -- 1-bit input: Clock enable for MREG
                                CEP => CEP,                                                -- 1-bit input: Clock enable for PREG
                                RSTA => RSTA,                                              -- 1-bit input: Reset for AREG
                                RSTALLCARRYIN => RSTALLCARRYIN,                            -- 1-bit input: Reset for CARRYINREG
                                RSTALUMODE => RSTALUMODE,                                  -- 1-bit input: Reset for ALUMODEREG
                                RSTB => RSTB,                                              -- 1-bit input: Reset for BREG
                                RSTC => RSTC,                                              -- 1-bit input: Reset for CREG
                                RSTCTRL => RSTCTRL,                                        -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                RSTD => RSTD,                                              -- 1-bit input: Reset for DREG and ADREG
                                RSTINMODE => RSTINMODE,                                    -- 1-bit input: Reset for INMODEREG
                                RSTM => RSTM,                                              -- 1-bit input: Reset for MREG
                                RSTP => RSTP,                                              -- 1-bit input: Reset for PREG
                                -- Cascade outputs: Cascade Ports
                                ACOUT => ACOUT,                                            -- 30-bit output: A port cascade
                                BCOUT => BCOUT,                                            -- 18-bit output: B cascade
                                CARRYCASCOUT => CARRYCASCOUT,                              -- 1-bit output: Cascade carry
                                MULTSIGNOUT => MULTSIGNOUT,                                -- 1-bit output: Multiplier sign cascade
                                PCOUT => PCOUT,                                            -- 48-bit output: Cascade output
                                -- Control outputs: Control Inputs/Status Bits
                                OVERFLOW => OVERFLOW,                                      -- 1-bit output: Overflow in add/acc
                                PATTERNBDETECT => PATTERNBDETECT,                          -- 1-bit output: Pattern bar detect
                                PATTERNDETECT => PATTERNDETECT,                            -- 1-bit output: Pattern detect
                                UNDERFLOW => UNDERFLOW,                                    -- 1-bit output: Underflow in add/acc
                                -- Data outputs: Data Ports
                                CARRYOUT => CARRYOUT,                                      -- 4-bit output: Carry
                                P => slvP);                                                -- 48-bit output: Primary data
          end generate;
       i2:if DSP48E=2 generate
            attribute loc:STRING;
            attribute loc of ds:label is "DSP48E2_X"&INTEGER'image(X)&"Y"&INTEGER'image(Y);
          begin
            ds:DSP48E2 generic map(-- Feature Control Attributes: Data Path Selection
                                   AMULTSEL => AMULTSEL,                                   -- Selects A input to multiplier (A, AD)
                                   A_INPUT => A_INPUT,                                     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                   BMULTSEL => BMULTSEL,                                   -- Selects B input to multiplier (AD, B)
                                   B_INPUT => B_INPUT,                                     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                   PREADDINSEL => PREADDINSEL,                             -- Selects input to preadder (A, B)
                                   RND => RND,                                             -- Rounding Constant
                                   USE_MULT => USE_MULT,                                   -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                   USE_SIMD => USE_SIMD,                                   -- SIMD selection (FOUR12, ONE48, TWO24)
                                   USE_WIDEXOR => USE_WIDEXOR,                             -- Use the Wide XOR function (FALSE, TRUE)
                                   XORSIMD => XORSIMD,                                     -- Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                   -- Pattern Detector Attributes: Pattern Detection Configuration
                                   AUTORESET_PATDET => AUTORESET_PATDET,                   -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                   AUTORESET_PRIORITY => AUTORESET_PRIORITY,               -- Priority of AUTORESET vs.CEP (CEP, RESET).
                                   MASK => MASK,                                           -- 48-bit mask value for pattern detect (1=ignore)
                                   PATTERN => PATTERN,                                     -- 48-bit pattern match for pattern detect
                                   SEL_MASK => SEL_MASK,                                   -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                   SEL_PATTERN => SEL_PATTERN,                             -- Select pattern value (C, PATTERN)
                                   USE_PATTERN_DETECT => USE_PATTERN_DETECT,               -- Enable pattern detect (NO_PATDET, PATDET)
                                   -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                   IS_ALUMODE_INVERTED => IS_ALUMODE_INVERTED,             -- Optional inversion for ALUMODE
                                   IS_CARRYIN_INVERTED => IS_CARRYIN_INVERTED,             -- Optional inversion for CARRYIN
                                   IS_CLK_INVERTED => IS_CLK_INVERTED,                     -- Optional inversion for CLK
                                   IS_INMODE_INVERTED => IS_INMODE_INVERTED,               -- Optional inversion for INMODE
                                   IS_OPMODE_INVERTED => IS_OPMODE_INVERTED,               -- Optional inversion for OPMODE
                                   IS_RSTALLCARRYIN_INVERTED => IS_RSTALLCARRYIN_INVERTED, -- Optional inversion for RSTALLCARRYIN
                                   IS_RSTALUMODE_INVERTED => IS_RSTALUMODE_INVERTED,       -- Optional inversion for RSTALUMODE
                                   IS_RSTA_INVERTED => IS_RSTA_INVERTED,                   -- Optional inversion for RSTA
                                   IS_RSTB_INVERTED => IS_RSTB_INVERTED,                   -- Optional inversion for RSTB
                                   IS_RSTCTRL_INVERTED => IS_RSTCTRL_INVERTED,             -- Optional inversion for RSTCTRL
                                   IS_RSTC_INVERTED => IS_RSTC_INVERTED,                   -- Optional inversion for RSTC
                                   IS_RSTD_INVERTED => IS_RSTD_INVERTED,                   -- Optional inversion for RSTD
                                   IS_RSTINMODE_INVERTED => IS_RSTINMODE_INVERTED,         -- Optional inversion for RSTINMODE
                                   IS_RSTM_INVERTED => IS_RSTM_INVERTED,                   -- Optional inversion for RSTM
                                   IS_RSTP_INVERTED => IS_RSTP_INVERTED,                   -- Optional inversion for RSTP
                                   -- Register Control Attributes: Pipeline Register Configuration
                                   ACASCREG => ACASCREG,                                   -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                   ADREG => ADREG,                                         -- Pipeline stages for pre-adder (0-1)
                                   ALUMODEREG => ALUMODEREG,                               -- Pipeline stages for ALUMODE (0-1)
                                   AREG => AREG,                                           -- Pipeline stages for A (0-2)
                                   BCASCREG => BCASCREG,                                   -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                   BREG => BREG,                                           -- Pipeline stages for B (0-2)
                                   CARRYINREG => CARRYINREG,                               -- Pipeline stages for CARRYIN (0-1)
                                   CARRYINSELREG => CARRYINSELREG,                         -- Pipeline stages for CARRYINSEL (0-1)
                                   CREG => CREG,                                           -- Pipeline stages for C (0-1)
                                   DREG => DREG,                                           -- Pipeline stages for D (0-1)
                                   INMODEREG => INMODEREG,                                 -- Pipeline stages for INMODE (0-1)
                                   MREG => MREG,                                           -- Multiplier pipeline stages (0-1)
                                   OPMODEREG => OPMODEREG,                                 -- Pipeline stages for OPMODE (0-1)
                                   PREG => PREG)                                           -- Number of pipeline stages for P (0-1)
                       port map(-- Cascade inputs: Cascade Ports
                                ACIN => ACIN,                                              -- 30-bit input: A cascade data
                                BCIN => BCIN,                                              -- 18-bit input: B cascade
                                CARRYCASCIN => CARRYCASCIN,                                -- 1-bit input: Cascade carry
                                MULTSIGNIN => MULTSIGNIN,                                  -- 1-bit input: Multiplier sign cascade
                                PCIN => PCIN,                                              -- 48-bit input: P cascade
                                -- Control inputs: Control Inputs/Status Bits
                                ALUMODE => ALUMODE,                                        -- 4-bit input: ALU control
                                CARRYINSEL => CARRYINSEL,                                  -- 3-bit input: Carry select
                                CLK => CLK,                                                -- 1-bit input: Clock
                                INMODE => INMODE,                                          -- 5-bit input: INMODE control
                                OPMODE => OPMODE,                                          -- 9-bit input: Operation mode
                                -- Data inputs: Data Ports
                                A => slvA,                                                 -- 30-bit input: A data
                                B => slvB,                                                 -- 18-bit input: B data
                                C => slvC,                                                 -- 48-bit input: C data
                                CARRYIN => CARRYIN,                                        -- 1-bit input: Carry-in
                                D => slvD,                                                 -- 27-bit input: D data
                                -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                CEA1 => CEA1,                                              -- 1-bit input: Clock enable for 1st stage AREG
                                CEA2 => CEA2,                                              -- 1-bit input: Clock enable for 2nd stage AREG
                                CEAD => CEAD,                                              -- 1-bit input: Clock enable for ADREG
                                CEALUMODE => CEALUMODE,                                    -- 1-bit input: Clock enable for ALUMODE
                                CEB1 => CEB1,                                              -- 1-bit input: Clock enable for 1st stage BREG
                                CEB2 => CEB2,                                              -- 1-bit input: Clock enable for 2nd stage BREG
                                CEC => CEC,                                                -- 1-bit input: Clock enable for CREG
                                CECARRYIN => CECARRYIN,                                    -- 1-bit input: Clock enable for CARRYINREG
                                CECTRL => CECTRL,                                          -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                CED => CED,                                                -- 1-bit input: Clock enable for DREG
                                CEINMODE => CEINMODE,                                      -- 1-bit input: Clock enable for INMODEREG
                                CEM => CEM,                                                -- 1-bit input: Clock enable for MREG
                                CEP => CEP,                                                -- 1-bit input: Clock enable for PREG
                                RSTA => RSTA,                                              -- 1-bit input: Reset for AREG
                                RSTALLCARRYIN => RSTALLCARRYIN,                            -- 1-bit input: Reset for CARRYINREG
                                RSTALUMODE => RSTALUMODE,                                  -- 1-bit input: Reset for ALUMODEREG
                                RSTB => RSTB,                                              -- 1-bit input: Reset for BREG
                                RSTC => RSTC,                                              -- 1-bit input: Reset for CREG
                                RSTCTRL => RSTCTRL,                                        -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                RSTD => RSTD,                                              -- 1-bit input: Reset for DREG and ADREG
                                RSTINMODE => RSTINMODE,                                    -- 1-bit input: Reset for INMODEREG
                                RSTM => RSTM,                                              -- 1-bit input: Reset for MREG
                                RSTP => RSTP,                                              -- 1-bit input: Reset for PREG
                                -- Cascade outputs: Cascade Ports
                                ACOUT => ACOUT,                                            -- 30-bit output: A port cascade
                                BCOUT => BCOUT,                                            -- 18-bit output: B cascade
                                CARRYCASCOUT => CARRYCASCOUT,                              -- 1-bit output: Cascade carry
                                MULTSIGNOUT => MULTSIGNOUT,                                -- 1-bit output: Multiplier sign cascade
                                PCOUT => PCOUT,                                            -- 48-bit output: Cascade output
                                -- Control outputs: Control Inputs/Status Bits
                                OVERFLOW => OVERFLOW,                                      -- 1-bit output: Overflow in add/acc
                                PATTERNBDETECT => PATTERNBDETECT,                          -- 1-bit output: Pattern bar detect
                                PATTERNDETECT => PATTERNDETECT,                            -- 1-bit output: Pattern detect
                                UNDERFLOW => UNDERFLOW,                                    -- 1-bit output: Underflow in add/acc
                                -- Data outputs: Data Ports
                                CARRYOUT => CARRYOUT,                                      -- 4-bit output: Carry
                                P => slvP,                                                 -- 48-bit output: Primary data
                                XOROUT => XOROUT);                                         -- 8-bit output: XOR data
          end generate;
--     end;
     end generate;
--     else generate
  i2:if (X<0) or (Y<0) generate
     begin
       i1:if DSP48E=1 generate
            ds:DSP48E1 generic map(-- Feature Control Attributes: Data Path Selection
                                   A_INPUT => A_INPUT,                                     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                   B_INPUT => B_INPUT,                                     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                   USE_MULT => USE_MULT,                                   -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                   USE_SIMD => USE_SIMD,                                   -- SIMD selection (FOUR12, ONE48, TWO24)
                                   -- Pattern Detector Attributes: Pattern Detection Configuration
                                   AUTORESET_PATDET => AUTORESET_PATDET,                   -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
--                                   MASK => MASK,                                           -- 48-bit mask value for pattern detect (1=ignore)
--                                   PATTERN => PATTERN,                                     -- 48-bit pattern match for pattern detect
                                   SEL_MASK => SEL_MASK,                                   -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                   SEL_PATTERN => SEL_PATTERN,                             -- Select pattern value (C, PATTERN)
                                   USE_PATTERN_DETECT => USE_PATTERN_DETECT,               -- Enable pattern detect (NO_PATDET, PATDET)
                                   -- Register Control Attributes: Pipeline Register Configuration
                                   ACASCREG => ACASCREG,                                   -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                   ADREG => ADREG,                                         -- Pipeline stages for pre-adder (0-1)
                                   ALUMODEREG => ALUMODEREG,                               -- Pipeline stages for ALUMODE (0-1)
                                   AREG => AREG,                                           -- Pipeline stages for A (0-2)
                                   BCASCREG => BCASCREG,                                   -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                   BREG => BREG,                                           -- Pipeline stages for B (0-2)
                                   CARRYINREG => CARRYINREG,                               -- Pipeline stages for CARRYIN (0-1)
                                   CARRYINSELREG => CARRYINSELREG,                         -- Pipeline stages for CARRYINSEL (0-1)
                                   CREG => CREG,                                           -- Pipeline stages for C (0-1)
                                   DREG => DREG,                                           -- Pipeline stages for D (0-1)
                                   INMODEREG => INMODEREG,                                 -- Pipeline stages for INMODE (0-1)
                                   MREG => MREG,                                           -- Multiplier pipeline stages (0-1)
                                   OPMODEREG => OPMODEREG,                                 -- Pipeline stages for OPMODE (0-1)
                                   PREG => PREG)                                           -- Number of pipeline stages for P (0-1)
                       port map(-- Cascade inputs: Cascade Ports
                                ACIN => ACIN,                                              -- 30-bit input: A cascade data
                                BCIN => BCIN,                                              -- 18-bit input: B cascade
                                CARRYCASCIN => CARRYCASCIN,                                -- 1-bit input: Cascade carry
                                MULTSIGNIN => MULTSIGNIN,                                  -- 1-bit input: Multiplier sign cascade
                                PCIN => PCIN,                                              -- 48-bit input: P cascade
                                -- Control inputs: Control Inputs/Status Bits
                                ALUMODE => ALUMODE,                                        -- 4-bit input: ALU control
                                CARRYINSEL => CARRYINSEL,                                  -- 3-bit input: Carry select
                                CLK => CLK,                                                -- 1-bit input: Clock
                                INMODE => INMODE,                                          -- 5-bit input: INMODE control
                                OPMODE => OPMODE(6 downto 0),                              -- 7-bit input: Operation mode
                                -- Data inputs: Data Ports
                                A => slvA,                                                 -- 30-bit input: A data
                                B => slvB,                                                 -- 18-bit input: B data
                                C => slvC,                                                 -- 48-bit input: C data
                                CARRYIN => CARRYIN,                                        -- 1-bit input: Carry-in
                                D => slvD(24 downto 0),                                    -- 25-bit input: D data
                                -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                CEA1 => CEA1,                                              -- 1-bit input: Clock enable for 1st stage AREG
                                CEA2 => CEA2,                                              -- 1-bit input: Clock enable for 2nd stage AREG
                                CEAD => CEAD,                                              -- 1-bit input: Clock enable for ADREG
                                CEALUMODE => CEALUMODE,                                    -- 1-bit input: Clock enable for ALUMODE
                                CEB1 => CEB1,                                              -- 1-bit input: Clock enable for 1st stage BREG
                                CEB2 => CEB2,                                              -- 1-bit input: Clock enable for 2nd stage BREG
                                CEC => CEC,                                                -- 1-bit input: Clock enable for CREG
                                CECARRYIN => CECARRYIN,                                    -- 1-bit input: Clock enable for CARRYINREG
                                CECTRL => CECTRL,                                          -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                CED => CED,                                                -- 1-bit input: Clock enable for DREG
                                CEINMODE => CEINMODE,                                      -- 1-bit input: Clock enable for INMODEREG
                                CEM => CEM,                                                -- 1-bit input: Clock enable for MREG
                                CEP => CEP,                                                -- 1-bit input: Clock enable for PREG
                                RSTA => RSTA,                                              -- 1-bit input: Reset for AREG
                                RSTALLCARRYIN => RSTALLCARRYIN,                            -- 1-bit input: Reset for CARRYINREG
                                RSTALUMODE => RSTALUMODE,                                  -- 1-bit input: Reset for ALUMODEREG
                                RSTB => RSTB,                                              -- 1-bit input: Reset for BREG
                                RSTC => RSTC,                                              -- 1-bit input: Reset for CREG
                                RSTCTRL => RSTCTRL,                                        -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                RSTD => RSTD,                                              -- 1-bit input: Reset for DREG and ADREG
                                RSTINMODE => RSTINMODE,                                    -- 1-bit input: Reset for INMODEREG
                                RSTM => RSTM,                                              -- 1-bit input: Reset for MREG
                                RSTP => RSTP,                                              -- 1-bit input: Reset for PREG
                                -- Cascade outputs: Cascade Ports
                                ACOUT => ACOUT,                                            -- 30-bit output: A port cascade
                                BCOUT => BCOUT,                                            -- 18-bit output: B cascade
                                CARRYCASCOUT => CARRYCASCOUT,                              -- 1-bit output: Cascade carry
                                MULTSIGNOUT => MULTSIGNOUT,                                -- 1-bit output: Multiplier sign cascade
                                PCOUT => PCOUT,                                            -- 48-bit output: Cascade output
                                -- Control outputs: Control Inputs/Status Bits
                                OVERFLOW => OVERFLOW,                                      -- 1-bit output: Overflow in add/acc
                                PATTERNBDETECT => PATTERNBDETECT,                          -- 1-bit output: Pattern bar detect
                                PATTERNDETECT => PATTERNDETECT,                            -- 1-bit output: Pattern detect
                                UNDERFLOW => UNDERFLOW,                                    -- 1-bit output: Underflow in add/acc
                                -- Data outputs: Data Ports
                                CARRYOUT => CARRYOUT,                                      -- 4-bit output: Carry
                                P => slvP);                                                -- 48-bit output: Primary data
          end generate;
       i2:if DSP48E=2 generate
            ds:DSP48E2 generic map(-- Feature Control Attributes: Data Path Selection
                                   AMULTSEL => AMULTSEL,                                   -- Selects A input to multiplier (A, AD)
                                   A_INPUT => A_INPUT,                                     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                   BMULTSEL => BMULTSEL,                                   -- Selects B input to multiplier (AD, B)
                                   B_INPUT => B_INPUT,                                     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                   PREADDINSEL => PREADDINSEL,                             -- Selects input to preadder (A, B)
                                   RND => RND,                                             -- Rounding Constant
                                   USE_MULT => USE_MULT,                                   -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                   USE_SIMD => USE_SIMD,                                   -- SIMD selection (FOUR12, ONE48, TWO24)
                                   USE_WIDEXOR => USE_WIDEXOR,                             -- Use the Wide XOR function (FALSE, TRUE)
                                   XORSIMD => XORSIMD,                                     -- Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                   -- Pattern Detector Attributes: Pattern Detection Configuration
                                   AUTORESET_PATDET => AUTORESET_PATDET,                   -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                   AUTORESET_PRIORITY => AUTORESET_PRIORITY,               -- Priority of AUTORESET vs.CEP (CEP, RESET).
                                   MASK => MASK,                                           -- 48-bit mask value for pattern detect (1=ignore)
                                   PATTERN => PATTERN,                                     -- 48-bit pattern match for pattern detect
                                   SEL_MASK => SEL_MASK,                                   -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                   SEL_PATTERN => SEL_PATTERN,                             -- Select pattern value (C, PATTERN)
                                   USE_PATTERN_DETECT => USE_PATTERN_DETECT,               -- Enable pattern detect (NO_PATDET, PATDET)
                                   -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                   IS_ALUMODE_INVERTED => IS_ALUMODE_INVERTED,             -- Optional inversion for ALUMODE
                                   IS_CARRYIN_INVERTED => IS_CARRYIN_INVERTED,             -- Optional inversion for CARRYIN
                                   IS_CLK_INVERTED => IS_CLK_INVERTED,                     -- Optional inversion for CLK
                                   IS_INMODE_INVERTED => IS_INMODE_INVERTED,               -- Optional inversion for INMODE
                                   IS_OPMODE_INVERTED => IS_OPMODE_INVERTED,               -- Optional inversion for OPMODE
                                   IS_RSTALLCARRYIN_INVERTED => IS_RSTALLCARRYIN_INVERTED, -- Optional inversion for RSTALLCARRYIN
                                   IS_RSTALUMODE_INVERTED => IS_RSTALUMODE_INVERTED,       -- Optional inversion for RSTALUMODE
                                   IS_RSTA_INVERTED => IS_RSTA_INVERTED,                   -- Optional inversion for RSTA
                                   IS_RSTB_INVERTED => IS_RSTB_INVERTED,                   -- Optional inversion for RSTB
                                   IS_RSTCTRL_INVERTED => IS_RSTCTRL_INVERTED,             -- Optional inversion for RSTCTRL
                                   IS_RSTC_INVERTED => IS_RSTC_INVERTED,                   -- Optional inversion for RSTC
                                   IS_RSTD_INVERTED => IS_RSTD_INVERTED,                   -- Optional inversion for RSTD
                                   IS_RSTINMODE_INVERTED => IS_RSTINMODE_INVERTED,         -- Optional inversion for RSTINMODE
                                   IS_RSTM_INVERTED => IS_RSTM_INVERTED,                   -- Optional inversion for RSTM
                                   IS_RSTP_INVERTED => IS_RSTP_INVERTED,                   -- Optional inversion for RSTP
                                   -- Register Control Attributes: Pipeline Register Configuration
                                   ACASCREG => ACASCREG,                                   -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                   ADREG => ADREG,                                         -- Pipeline stages for pre-adder (0-1)
                                   ALUMODEREG => ALUMODEREG,                               -- Pipeline stages for ALUMODE (0-1)
                                   AREG => AREG,                                           -- Pipeline stages for A (0-2)
                                   BCASCREG => BCASCREG,                                   -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                   BREG => BREG,                                           -- Pipeline stages for B (0-2)
                                   CARRYINREG => CARRYINREG,                               -- Pipeline stages for CARRYIN (0-1)
                                   CARRYINSELREG => CARRYINSELREG,                         -- Pipeline stages for CARRYINSEL (0-1)
                                   CREG => CREG,                                           -- Pipeline stages for C (0-1)
                                   DREG => DREG,                                           -- Pipeline stages for D (0-1)
                                   INMODEREG => INMODEREG,                                 -- Pipeline stages for INMODE (0-1)
                                   MREG => MREG,                                           -- Multiplier pipeline stages (0-1)
                                   OPMODEREG => OPMODEREG,                                 -- Pipeline stages for OPMODE (0-1)
                                   PREG => PREG)                                           -- Number of pipeline stages for P (0-1)
                       port map(-- Cascade inputs: Cascade Ports
                                ACIN => ACIN,                                              -- 30-bit input: A cascade data
                                BCIN => BCIN,                                              -- 18-bit input: B cascade
                                CARRYCASCIN => CARRYCASCIN,                                -- 1-bit input: Cascade carry
                                MULTSIGNIN => MULTSIGNIN,                                  -- 1-bit input: Multiplier sign cascade
                                PCIN => PCIN,                                              -- 48-bit input: P cascade
                                -- Control inputs: Control Inputs/Status Bits
                                ALUMODE => ALUMODE,                                        -- 4-bit input: ALU control
                                CARRYINSEL => CARRYINSEL,                                  -- 3-bit input: Carry select
                                CLK => CLK,                                                -- 1-bit input: Clock
                                INMODE => INMODE,                                          -- 5-bit input: INMODE control
                                OPMODE => OPMODE,                                          -- 9-bit input: Operation mode
                                -- Data inputs: Data Ports
                                A => slvA,                                                 -- 30-bit input: A data
                                B => slvB,                                                 -- 18-bit input: B data
                                C => slvC,                                                 -- 48-bit input: C data
                                CARRYIN => CARRYIN,                                        -- 1-bit input: Carry-in
                                D => slvD,                                                 -- 27-bit input: D data
                                -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                CEA1 => CEA1,                                              -- 1-bit input: Clock enable for 1st stage AREG
                                CEA2 => CEA2,                                              -- 1-bit input: Clock enable for 2nd stage AREG
                                CEAD => CEAD,                                              -- 1-bit input: Clock enable for ADREG
                                CEALUMODE => CEALUMODE,                                    -- 1-bit input: Clock enable for ALUMODE
                                CEB1 => CEB1,                                              -- 1-bit input: Clock enable for 1st stage BREG
                                CEB2 => CEB2,                                              -- 1-bit input: Clock enable for 2nd stage BREG
                                CEC => CEC,                                                -- 1-bit input: Clock enable for CREG
                                CECARRYIN => CECARRYIN,                                    -- 1-bit input: Clock enable for CARRYINREG
                                CECTRL => CECTRL,                                          -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                CED => CED,                                                -- 1-bit input: Clock enable for DREG
                                CEINMODE => CEINMODE,                                      -- 1-bit input: Clock enable for INMODEREG
                                CEM => CEM,                                                -- 1-bit input: Clock enable for MREG
                                CEP => CEP,                                                -- 1-bit input: Clock enable for PREG
                                RSTA => RSTA,                                              -- 1-bit input: Reset for AREG
                                RSTALLCARRYIN => RSTALLCARRYIN,                            -- 1-bit input: Reset for CARRYINREG
                                RSTALUMODE => RSTALUMODE,                                  -- 1-bit input: Reset for ALUMODEREG
                                RSTB => RSTB,                                              -- 1-bit input: Reset for BREG
                                RSTC => RSTC,                                              -- 1-bit input: Reset for CREG
                                RSTCTRL => RSTCTRL,                                        -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                RSTD => RSTD,                                              -- 1-bit input: Reset for DREG and ADREG
                                RSTINMODE => RSTINMODE,                                    -- 1-bit input: Reset for INMODEREG
                                RSTM => RSTM,                                              -- 1-bit input: Reset for MREG
                                RSTP => RSTP,                                              -- 1-bit input: Reset for PREG
                                -- Cascade outputs: Cascade Ports
                                ACOUT => ACOUT,                                            -- 30-bit output: A port cascade
                                BCOUT => BCOUT,                                            -- 18-bit output: B cascade
                                CARRYCASCOUT => CARRYCASCOUT,                              -- 1-bit output: Cascade carry
                                MULTSIGNOUT => MULTSIGNOUT,                                -- 1-bit output: Multiplier sign cascade
                                PCOUT => PCOUT,                                            -- 48-bit output: Cascade output
                                -- Control outputs: Control Inputs/Status Bits
                                OVERFLOW => OVERFLOW,                                      -- 1-bit output: Overflow in add/acc
                                PATTERNBDETECT => PATTERNBDETECT,                          -- 1-bit output: Pattern bar detect
                                PATTERNDETECT => PATTERNDETECT,                            -- 1-bit output: Pattern detect
                                UNDERFLOW => UNDERFLOW,                                    -- 1-bit output: Underflow in add/acc
                                -- Data outputs: Data Ports
                                CARRYOUT => CARRYOUT,                                      -- 4-bit output: Carry
                                P => slvP,                                                 -- 48-bit output: Primary data
                                XOROUT => XOROUT);                                         -- 8-bit output: XOR data
          end generate;
--     end;
     end generate;
  P<=SLV_TO_SFIXED_RESIZE(slvP,P'high,P'low,A'low+B'low-P'low);
end WRAPPER;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CKCM.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CKCM
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Constant Coeficient Complex Multiplier
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

use work.COMPLEX_FIXED_PKG.all;

entity CKCM is -- LATENCY=3
  generic(M:INTEGER:=1;              -- must be 0, 1, 2 or 3 to multiply I by (1.0,0.0), (Sqrt(0.5),-Sqrt(0.5)), (0.0,-1.0), (-Sqrt(0.5),-Sqrt(0.5))
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          ROUNDING:BOOLEAN:=FALSE;   -- set to TRUE to round the result
          CONJUGATE:BOOLEAN:=FALSE); -- set to TRUE for IFFT
  port(CLK:in STD_LOGIC;
       I:in CFIXED;
       O:out CFIXED);
end CKCM;

architecture TEST of CKCM is
  attribute use_dsp48:STRING;
  attribute use_dsp48 of TEST:architecture is "no";
--2008  signal RND:SFIXED(O.RE'high downto O.RE'low-1);
  signal RND:SFIXED((O'high+1)/2-1 downto O'low/2-1);
  constant nCONJUGATE:BOOLEAN:=not CONJUGATE;
begin
  i0:if M=0 generate
       cd:entity work.CDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>O);
     end generate;
--elsif i1: M=2 generate
  i1:if M=2 generate
      ic:if CONJUGATE generate
--2008           signal NIIM1D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.IM'high,I.IM'low);
           signal NIIM1D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
           signal IRE:SFIXED((I'high+1)/2-1 downto I'low/2);
           signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         begin
           process(CLK)
           begin
             if rising_edge(CLK) then
--2008               NIIM1D<=RESIZE(-I.IM,I.IM);
               NIIM1D<=RESIZE(-IM(I),NIIM1D);
             end if;
           end process;
           r2:entity work.SDELAY generic map(SIZE=>2)
                                 port map(CLK=>CLK,
                                          I=>NIIM1D,
--2008                                          O=>O.RE);
                                          O=>ORE);
           IRE<=RE(I);
           i3:entity work.SDELAY generic map(SIZE=>3)
                                 port map(CLK=>CLK,
--2008                                          I=>I.RE,
--2008                                          O=>O.IM);
                                          I=>IRE,
                                          O=>OIM);
           O<=TO_CFIXED(ORE,OIM);
--         end;
         end generate;
         ---else generate
		  nc:if not CONJUGATE generate
--2008           signal NIRE1D:SFIXED(I.RE'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
           signal NIRE1D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
           signal IIM:SFIXED((I'high+1)/2-1 downto I'low/2);
           signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         begin
           IIM<=IM(I);
           r3:entity work.SDELAY generic map(SIZE=>3)
                                 port map(CLK=>CLK,
--2008                                          I=>I.IM,
--2008                                          O=>O.RE);
                                          I=>IIM,
                                          O=>ORE);
           process(CLK)
           begin
             if rising_edge(CLK) then
--2008               NIRE1D<=RESIZE(-I.RE,I.RE);
               NIRE1D<=RESIZE(-RE(I),RE(I));
             end if;
           end process;
           i2:entity work.SDELAY generic map(SIZE=>2)
                                 port map(CLK=>CLK,
                                          I=>NIRE1D,
--2008                                          O=>O.IM);
                                          O=>OIM);
           O<=TO_CFIXED(ORE,OIM);
--         end;
         end generate;
       end generate;
--     else generate -- M=1 or 3
  i2:if (M=1) or (M=3) generate -- M=1 or 3
         constant K:SFIXED(0 downto -18):="0101101010000010100"; -- SQRT(0.5)
												 
--2008         signal X1,Y1:SFIXED(I.RE'high downto I.RE'low-14);
--2008         signal X2,Y2:SFIXED(I.RE'range);
--2008         signal KIRE,KIIM:SFIXED(I.RE'range);

  
	   
         signal X1,Y1:SFIXED((I'high+1)/2-1 downto I'low/2-14);
         signal X2,Y2:SFIXED((I'high+1)/2-1 downto I'low/2):=(others=>'0');
         signal KIRE,KIIM:SFIXED((I'high+1)/2-1 downto I'low/2);
--2008         signal I_1:CFIXED(RE(I.RE'high-1 downto I.RE'low-1),IM(I.IM'high-1 downto I.IM'low-1));
--2008         signal I_6:CFIXED(RE(I.RE'high-6 downto I.RE'low-6),IM(I.IM'high-6 downto I.IM'low-6));
--2008         signal I_14:CFIXED(RE(I.RE'high-14 downto I.RE'low-14),IM(I.IM'high-14 downto I.IM'low-14));
         signal I_1:CFIXED(I'high-2*1 downto I'low-2*1);
         signal I_6:CFIXED(I'high-2*6 downto I'low-2*6);
         signal I_14:CFIXED(I'high-2*14 downto I'low-2*14);
         signal I_1RE,I_1IM:SFIXED((I_1'high+1)/2-1 downto I_1'low/2);
         signal I_6RE,I_6IM:SFIXED((I_6'high+1)/2-1 downto I_6'low/2);
         signal I_14RE,I_14IM:SFIXED((I_14'high+1)/2-1 downto I_14'low/2);
         signal X1_2:SFIXED(X1'high-2 downto X1'low-2);
         signal X2_4:SFIXED(X2'high-4 downto X2'low-4);
         signal Y1_2:SFIXED(Y1'high-2 downto Y1'low-2);
         signal Y2_4:SFIXED(Y2'high-4 downto Y2'low-4);
         signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         constant MEQ3:BOOLEAN:=M=3;
       begin
--2008       RND<=TO_SFIXED(2.0**(O.RE'low-1),RND) when ROUNDING else (others=>'0');
       RND<=TO_SFIXED(2.0**(O'low/2-1),RND) when ROUNDING else (others=>'0');
       process(CLK)
       begin
         if rising_edge(CLK) then
--2008           X2<=I.RE;
--2008           Y2<=I.IM;
           X2<=RE(I);
           Y2<=IM(I);
         end if;
       end process;

       I_1<=SHIFT_RIGHT(I,1);
       I_6<=SHIFT_RIGHT(I,6);
       I_14<=SHIFT_RIGHT(I,14);
       X1_2<=SHIFT_RIGHT(X1,2);
       X2_4<=SHIFT_RIGHT(X2,4);
       Y1_2<=SHIFT_RIGHT(Y1,2);
       Y2_4<=SHIFT_RIGHT(Y2,4);
       I_1RE<=RE(I_1);
       I_6RE<=RE(I_6);
       I_14RE<=RE(I_14);

       a1:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
--2008                                    A=>I_1.RE,
--2008                                    B=>I_6.RE,
--2008                                    C=>I_14.RE,
                                    A=>I_1RE,
                                    B=>I_6RE,
                                    C=>I_14RE,
                                    P=>X1); -- P=C+A+B

       a2:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>X1,
                                    B=>X1_2,
                                    C=>X2_4,
                                    P=>KIRE); -- P=C+A+B

       I_1IM<=IM(I_1);
       I_6IM<=IM(I_6);
       I_14IM<=IM(I_14);
       a3:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
--2008                                    A=>I_1.IM,
--2008                                    B=>I_6.IM,
--2008                                    C=>I_14.IM,
                                    A=>I_1IM,
                                    B=>I_6IM,
                                    C=>I_14IM,
                                    P=>Y1); -- P=C+A+B

       a4:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>Y1,
                                    B=>Y1_2,
                                    C=>Y2_4,
                                    P=>KIIM); -- P=C+A+B

       a5:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       NEGATIVE_A=>MEQ3, --2008 M=3,
                                       NEGATIVE_B=>CONJUGATE,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>KIRE,
                                    B=>KIIM,
                                    C=>RND,
                                    CY1=>MEQ3, --2008 M=3,
                                    CY2=>CONJUGATE,
--2008                                    P=>O.RE); -- P=C+A+B
                                    P=>ORE); -- P=C+A+B
 
       a6:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       NEGATIVE_A=>nCONJUGATE,
                                       NEGATIVE_B=>MEQ3, --2008 M=3,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>KIRE,
                                    B=>KIIM,
                                    C=>RND,
                                    CY1=>nCONJUGATE,
                                    CY2=>MEQ3, --2008 M=3,
--2008                                    P=>O.IM); -- P=C+A+B
                                    P=>OIM); -- P=C+A+B
       O<=TO_CFIXED(ORE,OIM);
  --end;
 end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             ADDSUB.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     PARFFT
-- Purpose:         Generic Add/Subtract Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Parallel FFT Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity ADDSUB is
  generic(PIPELINE:BOOLEAN:=TRUE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          EXTRA_MSBs:INTEGER:=1);
  port(CLK:in STD_LOGIC:='0';
--       A,B:in SIGNED; -- if SIGNED, A, B and P must be LSB aligned
       A,B:in SFIXED; -- if SFIXED, A, B and P can be any size
       SUB:in BOOLEAN:=FALSE;
--       P:out SIGNED); -- O=A±B
       P:out SFIXED); -- O=A±B
end ADDSUB;

architecture FAST of ADDSUB is
  constant SH:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(A'high,B'high)+EXTRA_MSBs;
  constant SM:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(A'low,B'low);
  constant SL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(A'low,B'low);
--  signal SA,SB,M:SIGNED(SH downto SM);
--  signal S:SIGNED(SH downto SL);
  signal SA,SB:SFIXED(SH downto SM);
  signal S:SFIXED(SH+1 downto SL);

  signal O5:SIGNED(SH-SM downto 0);
  signal O6:SIGNED(SH-SM downto 0);
  signal CY:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8 downto 0);
  signal SI,DI,O:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8-1 downto 0);
begin
  SA<=RESIZE(A,SA);
  SB<=RESIZE(B,SB);
  CY(0)<='1' when SUB else '0';
  lk:for K in SM to SH generate
       constant I0:BIT_VECTOR(63 downto 0):=X"AAAAAAAAAAAAAAAA";
       constant I1:BIT_VECTOR(63 downto 0):=X"CCCCCCCCCCCCCCCC";
       constant I2:BIT_VECTOR(63 downto 0):=X"F0F0F0F0F0F0F0F0";
       constant I3:BIT_VECTOR(63 downto 0):=X"FF00FF00FF00FF00";
       constant I4:BIT_VECTOR(63 downto 0):=X"FFFF0000FFFF0000";
       constant I5:BIT_VECTOR(63 downto 0):=X"FFFFFFFF00000000";
       signal I_4:STD_LOGIC;
     begin
       I_4<='1' when SUB else '0';
       l6:LUT6_2 generic map(INIT=>(I5 and (I2 xor I3 xor I4)) or (not I5 and ((I2 xor I4) and I3)))
                 port map(I0=>'0',I1=>'0',I2=>SB(K),I3=>SA(K),I4=>I_4,I5=>'1',O5=>O5(K-SM),O6=>O6(K-SM));
     end generate;

  SI<=STD_LOGIC_VECTOR(RESIZE(O6,SI'length));
  DI<=STD_LOGIC_VECTOR(RESIZE(O5,DI'length));
  lj:for J in 0 to (SH-SM)/8 generate
     begin
       i1:if DSP48E=1 generate -- 7-series
            cl:CARRY4 port map(CI=>CY(8*J),                  -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+3 downto 8*J),     -- 4-bit carry-MUX data in
                               S=>SI(8*J+3 downto 8*J),      -- 4-bit carry-MUX select input
                               CO=>CY(8*J+4 downto 8*J+1),   -- 4-bit carry out
                               O=>O(8*J+3 downto 8*J));      -- 4-bit carry chain XOR data out
            ch:CARRY4 port map(CI=>CY(8*J+4),                -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+7 downto 8*J+4),   -- 4-bit carry-MUX data in
                               S=>SI(8*J+7 downto 8*J+4),    -- 4-bit carry-MUX select input
                               CO=>CY(8*J+8 downto 8*J+5),   -- 4-bit carry out
                               O=>O(8*J+7 downto 8*J+4));    -- 4-bit carry chain XOR data out
       end generate;
       i2:if DSP48E=2 generate -- US/US+
            c8:CARRY8 generic map(CARRY_TYPE=>"SINGLE_CY8")  -- 8-bit or dual 4-bit carry (DUAL_CY4, SINGLE_CY8)
                      port map(CI=>CY(8*J),                  -- 1-bit input: Lower Carry-In
                               CI_TOP=>'0',                  -- 1-bit input: Upper Carry-In
                               DI=>DI(8*J+7 downto 8*J),     -- 8-bit input: Carry-MUX data in
                               S=>SI(8*J+7 downto 8*J),      -- 8-bit input: Carry-mux select
                               CO=>CY(8*J+8 downto 8*J+1),   -- 8-bit output: Carry-out
                               O=>O(8*J+7 downto 8*J));      -- 8-bit output: Carry chain XOR data out
       end generate;
     end generate;

--  ll:for L in SM to SH+1 generate
  ll:for L in SM to SH generate
--       S(L)<=O(L-SM+1);
       S(L)<=O(L-SM);
     end generate;
  S(SH+1)<=S(SH);

  ia:if A'low<B'low generate
       S(SM-1 downto SL)<=A(SM-1 downto SL);
     end generate;
     
  ib:if B'low<A'low generate
       S(SM-1 downto SL)<=B(SM-1 downto SL);
     end generate;
     
  i0:if not PIPELINE generate
       P<=RESIZE(S,P'high,P'low);
     end generate;

  i1:if PIPELINE generate
       signal iP:SFIXED(P'range):=(others=>'0');
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iP<=RESIZE(S,P'high,P'low);
         end if;
       end process;
       P<=iP;
     end generate;
end FAST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             TABLE.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     TABLE
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, SinCos Table Module
--
-- Latency is always 2
-- when INV_FFT=FALSE W=exp(-2.0*PI*i*JK/N) and when INV_FFT=TRUE W=exp(2.0*PI*i*JK/N)
-- to maximize W output bit size utilization W.RE and W.IM are always negative (MSB='1') and that bit could be ignored, this is why W.RE'length can be 19 bits but a single BRAM would still be used
-- when W.RE or W.IM need to be positive CS respectively SS are TRUE, same thing when they are 0.0 CZ respectively SZ are TRUE - the complex multiplier has to use CS, SS, CZ and SZ, not just W to produce the correct result
-- the SIN and COS ROM table sizes are N/4 deep and W.RE'length-1 wide (it is implictly assumed that W.RE and W.IM always have the same range)
-- if STYLE="block" a single dual port BRAM is used for both tables
-- if STYLE="distributed" then two fabric LUT based ROMs are used
-- as a general rule for N<2048 "distributed" should be used, otherwise "block" makes more sense but this is not a hard rule
-- W range is unconstrained but W.RE'high and W.IM'high really have to be 0 all the time, do not use other values
-- the maximum SNR without using extra BRAMs is achieved when W.RE'low and W.IM'low are -18 so W.RE'length and W.IM'length are 19 bits but they can be less than that - this would reduce SNR and save resources only when STYLE="distributed"
-- TABLE.VHD also works with more than 19 bits but the current complex multiplier implementation does not support that - this would essentially double the number of BRAMs and DSP48s used and seems too high a price to pay for a few extra dB of SNR
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

use work.COMPLEX_FIXED_PKG.all;

--!! entity TABLE is -- LATENCY=3 (2 if SEPARATE_SIGN is TRUE)
entity TABLE is -- LATENCY=4 (3 if SEPARATE_SIGN is TRUE) when SPLIT_RADIX=0 else LATENCY=0
  generic(N:INTEGER:=1024;
          SPLIT_RADIX:INTEGER:=0; -- 0 for use in systolic FFT and J*1 or J*3 with J>0 for use in parallel Split Radix FFT
          INV_FFT:BOOLEAN:=FALSE;
          SEPARATE_SIGN:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          STYLE:STRING:="block"); -- use only "block" or "distributed"
  port(CLK:in STD_LOGIC;
       JK:in UNSIGNED;
       VI:in BOOLEAN;
       W:out CFIXED;
       CS,SS,CZ,SZ:out BOOLEAN;
       VO:out BOOLEAN);
end TABLE;

architecture TEST of TABLE is
--2008  constant WH:INTEGER:=W.RE'high-1+BOOLEAN'pos(SEPARATE_SIGN);
--2008  constant WL:INTEGER:=W.RE'low; -- SNR=110.06dB with WL=-17 and 116.27dB with WL=-18
  constant WH:INTEGER:=(W'high+1)/2-1-1+BOOLEAN'pos(SEPARATE_SIGN);
  constant WL:INTEGER:=W'low/2; -- SNR=110.06dB with WL=-17 and 116.27dB with WL=-18
begin
  i0:if SPLIT_RADIX=0 generate
       type wSFIXED_VECTOR is array(INTEGER range <>) of SFIXED(WH-1 downto WL); -- local constrained array of SFIXED type
--2008       function LUT_VALUE(N,WH,WL:INTEGER) return SFIXED_VECTOR is
--2008         variable RESULT:SFIXED_VECTOR(0 to N/4-1)(WH-1 downto WL);
       function LUT_VALUE(N,WH,WL:INTEGER) return wSFIXED_VECTOR is
         variable RESULT:wSFIXED_VECTOR(0 to N/4-1);
       begin
         RESULT(0):=TO_SFIXED(-1.0,WH,WL)(WH-1 downto WL); -- round and drop MSB, it is always 1
         for J in 1 to N/4-1 loop
           RESULT(J):=TO_SFIXED(-COS(-2.0*MATH_PI*REAL(J)/REAL(N))+2.0**(WL-1),WH,WL)(WH-1 downto WL); -- round and drop MSB, it is always 1
           if RESULT(J)=TO_SFIXED(-1.0,WH,WL)(WH-1 downto WL) then
             RESULT(J):=TO_SFIXED(-1.0+2.0**WL,WH,WL)(WH-1 downto WL);
           end if;
         end loop;
         return RESULT;
       end;
  
       signal JKD:UNSIGNED(JK'range):=(others=>'0');
       signal KC,KS:UNSIGNED(JK'range):=(others=>'0');--!!
       signal DC,C,DS,S:SFIXED(WH-1 downto WL):=(others=>'0');
--2008       signal LUT:SFIXED_VECTOR(0 to N/4-1)(WH-1 downto WL):=LUT_VALUE(N,WH,WL);
       signal LUT:wSFIXED_VECTOR(0 to N/4-1):=LUT_VALUE(N,WH,WL);
       attribute rom_style:STRING;
       attribute rom_style of LUT:signal is STYLE;
       signal RC,RS:BOOLEAN:=FALSE;
       signal MC,MS:STD_LOGIC:='0';
       signal CS1,SS1,CS2,SS2:BOOLEAN:=FALSE;
       signal W_RE,W_IM:SFIXED((W'high+1)/2-1 downto W'low/2);
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
--!!
--2008           KC<=JK when JK(JK'high-1)='0' else (not JK)+1;
--2008           KS<=(not JK)+1 when JK(JK'high-1)='0' else JK;
           if JK(JK'high-1)='0' then
             KC<=JK;
             KS<=(not JK)+1;
           else
             KC<=(not JK)+1;
             KS<=JK;
           end if;
           JKD<=JK;
           if (JKD and TO_UNSIGNED(2**(JK'length-2)-1,JK'length))=0 then --mask first two MSBs of JK
             RC<=JKD(JK'high-1)='1';
             RS<=JKD(JK'high-1)='0';
           else
             RC<=FALSE;
             RS<=FALSE;
           end if;
           DC<=LUT(TO_INTEGER(KC and TO_UNSIGNED(2**(KC'length-2)-1,KC'length)));
           DS<=LUT(TO_INTEGER(KS and TO_UNSIGNED(2**(KS'length-2)-1,KS'length)));
           if RC then
             C<=(others=>'0');
             MC<='0';
           else
             C<=DC;
             MC<='1';
           end if;
           if RS then
             S<=(others=>'0');
             MS<='0';
           else
             S<=DS;
             MS<='1';
           end if;
           CS1<=JKD(JK'high)=JKD(JK'high-1);
           SS1<=(JKD(JK'high)='1') xor INV_FFT;
           CS2<=CS1;
           SS2<=SS1;
         end if;  
       end process;  

       i0:if SEPARATE_SIGN generate
--2008            W.RE<=MC&C;
--2008            W.IM<=MS&S;
            W(W'length/2-1+W'low downto W'low)<=CFIXED(MC&C);
            W(W'high downto W'length/2+W'low)<=CFIXED(MS&S);
            CS<=CS2;
            SS<=SS2;
--          else generate
          end generate;
       i1:if not SEPARATE_SIGN generate
            signal WRE,WIM:SFIXED(WH downto WL):=(others=>'0');
            attribute keep:STRING;
            attribute keep of WRE:signal is "yes";
            attribute keep of WIM:signal is "yes";
            signal ZERO:SFIXED(WH downto WL):=TO_SFIXED(0.0,WH,WL);
          begin
            WRE<=MC&C;
            WIM<=MS&S;
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                CS<=CS2;
                SS<=SS2;
                CZ<=WRE(WRE'high)='0';
                SZ<=WIM(WIM'high)='0';
              end if;
            end process;
            ar:entity work.ADDSUB generic map(DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           A=>ZERO,
                                           B=>WRE,
                                           SUB=>CS2,
--2008                                           P=>W.RE); -- P=Â±B
                                           P=>W_RE); -- P=Â±B
            ai:entity work.ADDSUB generic map(DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           A=>ZERO,
                                           B=>WIM,
                                           SUB=>SS2,
--2008                                           P=>W.IM); -- P=Â±B
                                           P=>W_IM); -- P=Â±B
            W(W'length/2-1+W'low downto W'low)<=CFIXED(W_RE);
            W(W'high downto W'length/2+W'low)<=CFIXED(W_IM);
--          end;
          end generate;

--!!       b2:entity work.BDELAY generic map(SIZE=>3-BOOLEAN'pos(SEPARATE_SIGN))
          b2:entity work.BDELAY generic map(SIZE=>4-BOOLEAN'pos(SEPARATE_SIGN))
                                port map(CLK=>CLK,
                                         I=>VI,
                                         O=>VO);
--          end;
     end generate;
--     else generate
     i1:if SPLIT_RADIX>0 generate
     begin
       i0:if SEPARATE_SIGN generate
--2008            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W);
            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W'high/2,W'low/2);
            CS<=FALSE;
            SS<=FALSE;
          end generate;
--          else generate
       ii:if not SEPARATE_SIGN generate
          begin
--2008            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W);
            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W'high/2,W'low/2);
            CS<=FALSE;
            SS<=FALSE;
            CZ<=(SPLIT_RADIX=N/4) or (SPLIT_RADIX=3*N/4);
            SZ<=(SPLIT_RADIX=0) or (SPLIT_RADIX=N/2);
--          end;
          end generate;
       VO<=VI;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CM3.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CM3
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Complex Multiplier Using 3 DSP48E2s
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CM3 is -- LATENCY=6
  generic(ROUNDING:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED; -- I.RE'length and I.IM'length<27
       W:in CFIXED; -- W must be (1 downto -16) or (1 downto -17)
       CS,SS,CZ,SZ:in BOOLEAN:=FALSE;
       VI:in BOOLEAN;
       O:out CFIXED;
       VO:out BOOLEAN);
end CM3;

architecture TEST of CM3 is
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute loc:STRING;

--2008  constant HMAX:INTEGER:=MAX(I.RE'high,I.IM'high)+MAX(W.RE'high,W.IM'high)+3;
--2008  constant LMIN:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(I.RE'low,I.IM'low)+work.COMPLEX_FIXED_PKG.MIN(W.RE'low,W.IM'low);
  constant HMAX:INTEGER:=(I'high+1)/2-1+(W'high+1)/2-1+3;
  constant LMIN:INTEGER:=I'low/2+W'low/2;

--  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'high,1) downto MAX(W.RE'low,-16));
--  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'high,0) downto MAX(W.RE'low,-17));
--2008  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'low+17,1) downto W.RE'low); -- we only have 18 bits max to work with
--2008  signal WRE1D,nWRE2D:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
--2008  signal IRE1D,IRE2D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
--2008  signal IIM1D,IIM2D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.IM'high,I.IM'low);
  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W'low/2+17,1) downto W'low/2); -- we only have 18 bits max to work with
  signal WRE1D,nWRE2D:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
  signal IRE,IRE1D,IRE2D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal IIM,IIM1D,IIM2D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal CS2D,SS2D:BOOLEAN;
  signal C0S1:BOOLEAN:=FALSE;
  signal P1,P2,P3:SFIXED(HMAX downto LMIN);
  signal P2D:SFIXED(HMAX downto LMIN):=(others=>'0');
  signal C1,C2,C3:SFIXED(HMAX downto LMIN):=(others=>'0');
  signal AC1,AC2:STD_LOGIC_VECTOR(29 downto 0);
  signal BC1:STD_LOGIC_VECTOR(17 downto 0);
  signal PC1,PC2:STD_LOGIC_VECTOR(47 downto 0);
--2008  signal A_ZERO:SFIXED(I.RE'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
  signal A_ZERO:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal B_ZERO:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
  signal C_ZERO:SFIXED(HMAX downto LMIN):=TO_SFIXED(0.0,HMAX,LMIN);
  signal BR,BI:BOOLEAN;
  signal iO:CFIXED(O'range);
begin
--!!
--2008  WRE<=RESIZE(W.RE,WRE);
  WRE<=RESIZE(RE(W),WRE);
--!!  WRE<=TO_SFIXED(1.0-2.0**WRE'low,WRE) when W.RE=TO_SFIXED(1.0,W.RE) else RESIZE(W.RE,WRE);
--!!
--2008  WIM<=RESIZE(W.IM,WIM);
  WIM<=RESIZE(IM(W),WIM);
  process(CLK)
  begin
    if rising_edge(CLK) then
      WRE1D<=WRE;
--2008      IRE1D<=I.RE;
--2008      IIM1D<=I.IM;
      IRE1D<=RE(I);
      IIM1D<=IM(I);
--2008      C0S1<=CZ and (W.IM(W.IM'high)='0');
      C0S1<=CZ and (W(W'high)='0');
--!!
      NWRE2D<=RESIZE(-WRE1D,NWRE2D);
--!!      if WRE1D=TO_SFIXED(-1.0,WRE1D) then
--!!        for K in NWRE2D'range loop
--!!          NWRE2D(K)<=not WRE1D(K);
--!!        end loop;
--!!      else
--!!        NWRE2D<=RESIZE(-WRE1D,NWRE2D);
--!!      end if;
--!!
      IRE2D<=IRE1D;
      IIM2D<=IIM1D;
    end if;
  end process;
  
  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      if (W.RE'low=-17) and C0S1 then
      if (W'low/2=-17) and C0S1 then
        C1<=RESIZE(SHIFT_LEFT(IRE1D+IIM1D,1),C1);
      else
        C1<=TO_SFIXED(0.0,C1);
      end if;
    end if;
  end process;
  
  IRE<=RE(I);
  IIM<=IM(I);
  dsp1:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         AMULTSEL=>"AD",         -- Selects A input to multiplier (A, AD)
                                         BREG=>2)                -- Pipeline stages for B (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"00101",  -- (D+A1)*B2
                                      ALUMODE=>"0011",  -- Z-W-X-Y
                                      OPMODE=>"110000101", -- PCOUT=-C-(D+A1)*B2
--2008                                      A=>I.RE,  
                                      A=>IRE,
                                      B=>WIM,
                                      C=>C1,
--2008                                      D=>I.IM,
                                      D=>IIM,
                                      ACOUT=>AC1,
                                      BCOUT=>BC1,
                                      P=>P1,
                                      PCOUT=>PC1);

--  C2<=TO_SFIXED(2.0**(O.RE'low-1),C2) when ROUNDING else TO_SFIXED(0.0,C2);
  BR<=W(W'length/2-1+W'low)='0';
  BI<=W(W'high)='0';
  cd:entity work.BDELAY generic map(SIZE=>2)
                        port map(CLK=>CLK,
--2008                                 I=>W.RE(W.RE'high)='0',
                                 I=>BR,
                                 O=>CS2D);
  sd:entity work.BDELAY generic map(SIZE=>2)
                        port map(CLK=>CLK,
--2008                                 I=>W.IM(W.IM'high)='0',
                                 I=>BI,
                                 O=>SS2D);
  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      if (W.RE'low=-17) and CS2D=SS2D then
      if (W'low/2=-17) and CS2D=SS2D then
        if CS2D then
          if ROUNDING then
--2008            C2<=RESIZE(TO_SFIXED(2.0**(O.RE'low-1),C2)+SHIFT_LEFT(IRE2D,1),C2);
            C2<=RESIZE(TO_SFIXED(2.0**(O'low/2-1),C2)+SHIFT_LEFT(IRE2D,1),C2);
          else
--2008            C2<=RESIZE(I.RE,C2);
            C2<=RESIZE(SHIFT_LEFT(IRE2D,1),C2);
          end if;
        else
          if ROUNDING then
--2008            C2<=RESIZE(TO_SFIXED(2.0**(O.RE'low-1),C2)-SHIFT_LEFT(IRE2D,1),C2);
            C2<=RESIZE(TO_SFIXED(2.0**(O'low/2-1),C2)-SHIFT_LEFT(IRE2D,1),C2);
          else
--2008            C2<=RESIZE(-I.RE,C2);
            C2<=RESIZE(-SHIFT_LEFT(IRE2D,1),C2);
          end if;
        end if;
      else
        if ROUNDING then
--2008          C2<=TO_SFIXED(2.0**(O.RE'low-1),C2);
          C2<=TO_SFIXED(2.0**(O'low/2-1),C2);
        else
          C2<=TO_SFIXED(0.0,C2);
        end if;
      end if;
    end if;
  end process;
  
  dsp2:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         A_INPUT=>"CASCADE",     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                         BMULTSEL=>"AD",         -- Selects B input to multiplier (AD, B)
                                         B_INPUT=>"CASCADE",     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                         PREADDINSEL=>"B",       -- Selects input to preadder (A, B)
                                         AREG=>2)                -- Pipeline stages for A (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"10100",  -- (D+B1)*A2
                                      ALUMODE=>"0000",  -- Z+W+X+Y
                                      OPMODE=>"110010101", -- PCOUT=PCIN+C+(D+B1)*A2    
                                      A=>A_ZERO,
                                      B=>B_ZERO,
                                      C=>C2,
                                      D=>WRE1D,
                                      ACIN=>AC1,
                                      BCIN=>BC1,
                                      PCIN=>PC1,
                                      ACOUT=>AC2,
                                      P=>P2,
                                      PCOUT=>PC2);

--  C3<=RESIZE(SHIFT_RIGHT(P1,-16-W.RE'low),P1);
  C3<=P1;
  dsp3:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         AMULTSEL=>"AD",         -- Selects A input to multiplier (A, AD)
                                         A_INPUT=>"CASCADE",     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                         BREG=>2)                -- Pipeline stages for B (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"01101", --5x"0C",  -- (D-A1)*B2
                                      ALUMODE=>"0011",  -- Z-W-X-Y
                                      OPMODE=>"110010101", -- PCOUT=PCIN-C-(D-A1)*B2 
                                      A=>A_ZERO,
                                      B=>NWRE2D,
                                      C=>C3,
                                      D=>IIM2D,
                                      ACIN=>AC2,
                                      PCIN=>PC2,
                                      P=>P3);

  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      O.RE<=RESIZE(P2,O.RE);
      P2D<=P2;
    end if;
  end process;
--2008  O.IM<=RESIZE(P3,O.IM);
--  O<=RESIZE(TO_CFIXED(P2D,P3),O);
  O<=RESIZE(TO_CFIXED(P2D,P3),iO);
  
  bd:entity work.BDELAY generic map(SIZE=>6)
                        port map(CLK=>CLK,
                                 I=>VI,
                                 O=>VO);  
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 3
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CM3FFT.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CM3FFT
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic Complex Multiplier Stage Module - uses 3 DSP48s/complex multiplication
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CM3FFT is -- LATENCY=10
  generic(N:INTEGER;
          RADIX:INTEGER;
          SPLIT_RADIX:INTEGER:=0; -- 0 for use in systolic FFT and 1 or 3 for use in parallel Split Radix FFT
          INV_FFT:BOOLEAN:=FALSE;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=256; -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end CM3FFT;

architecture TEST of CM3FFT is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  
  function STYLE(N:INTEGER) return STRING is
  begin
    if N>BRAM_THRESHOLD then
      return "block";
    else
      return "distributed";
    end if;
  end;

  function TABLE_LATENCY(SPLIT_RADIX:INTEGER) return INTEGER is
  begin
    if SPLIT_RADIX=0 then
      return 4;
    else
      return 0;
    end if;
  end;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  signal CNT:UNSIGNED(L2N-L2R-1 downto 0):=(others=>'0');
  signal I0:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
  signal O0:CFIXED((O'high+1)/RADIX-1 downto O'low/RADIX);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity warning;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity warning;

--!!  cd:entity work.CDELAY generic map(SIZE=>3+6)
  I0<=ELEMENT(I,0,RADIX);
  cd:entity work.CDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
--2008                                 I=>I(I'low),
--2008                                 O=>O(O'low));
                                 I=>I0,
                                 O=>O0);
  O(O'length/RADIX-1+O'low downto O'low)<=CFIXED_VECTOR(O0);

  process(CLK)
  begin
    if rising_edge(CLK) then
      if not VI or (SPLIT_RADIX/=0) then
        CNT<=(others=>'0');
      else
        CNT<=CNT+1;
      end if;
    end if;
  end process;

--2008  lk:for J in 1 to I'length-1 generate
  lk:for J in 1 to RADIX-1 generate
       signal JK:UNSIGNED(L2N-1 downto 0):=(others=>'0');
--2008       signal W:CFIXED(RE(W_high downto W_low),IM(W_high downto W_low));
       signal W:CFIXED(2*(W_high+1)-1 downto 2*W_low);
       signal V,CZ:BOOLEAN;
--2008       signal ID:CFIXED(RE(I(I'low).RE'high downto I(I'low).RE'low),IM(I(I'low).IM'high downto I(I'low).IM'low));
       signal ID:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
       signal IJ:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
       signal OJ:CFIXED((O'high+1)/RADIX-1 downto O'low/RADIX);
     begin  
       process(CLK)
       begin
         if rising_edge(CLK) then
           if SPLIT_RADIX=0 then
             if not VI or (CNT=N/RADIX-1) then
               JK<=(others=>'0');
             else
               JK<=JK+J;
             end if;
           else
             JK<=TO_UNSIGNED(J*SPLIT_RADIX,JK'length);
           end if;
         end if;
       end process;

       ut:entity work.TABLE generic map(N=>N,
                                        INV_FFT=>INV_FFT,
                                        DSP48E=>DSP48E,
                                        STYLE=>STYLE(N/4))
                            port map(CLK=>CLK,
                                     JK=>JK,
                                     VI=>VI,
                                     CZ=>CZ,
                                     W=>W,
                                     VO=>V);

       IJ<=ELEMENT(I,J,RADIX);
--!!       cd:entity work.CDELAY generic map(SIZE=>3)
       cd:entity work.CDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX))
                             port map(CLK=>CLK,
--2008                                      I=>I(I'low+J),
                                      I=>IJ,
                                      O=>ID);

       u1:entity work.CM3 generic map(ROUNDING=>ROUNDING,
                                      DSP48E=>DSP48E)
                          port map(CLK=>CLK,
                                   I=>ID,
                                   W=>W,
                                   CZ=>CZ,
                                   VI=>V,
--2008                                   O=>O(O'low+J),
                                   O=>OJ,
                                   VO=>open);
       O((J+1)*O'length/RADIX-1+O'low downto J*O'length/RADIX+O'low)<=CFIXED_VECTOR(OJ);
     end generate;

--!!  bd:entity work.BDELAY generic map(SIZE=>3+6)
  bd:entity work.BDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
                                 I=>VI,
                                 O=>VO);

--!!  ud:entity work.UDELAY generic map(SIZE=>3+6)
  ud:entity work.UDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
                                 I=>SI,
                                 O=>SO);
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             PARFFT.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     PARFFT
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Parallel FFT Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;
use ieee.math_complex.all;

use work.COMPLEX_FIXED_PKG.all;

entity PARFFT is
  generic(N:INTEGER:=4;
          F:INTEGER:=0;
          INV_FFT:BOOLEAN:=FALSE;
          ROUNDING:BOOLEAN:=FALSE;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-16;
          BRAM_THRESHOLD:INTEGER:=256;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end PARFFT;

architecture TEST of PARFFT is
  constant I_low:INTEGER:=I'low/2/N;
  constant I_high:INTEGER:=I'length/2/N-1+I_low;
  constant O_low:INTEGER:=O'low/2/N;
  constant O_high:INTEGER:=O'length/2/N-1+O_low;

  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";

  constant L2N:INTEGER:=LOG2(N);
begin
--2008  assert I'length=O'length report "Ports I and O must have the same length!" severity warning;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity warning;

  f0:if F=0 generate
     begin
       l2:if N=2 generate -- FFT2 case
            signal I0,I1:CFIXED(2*I_high+1 downto 2*I_low);
            signal O0,O1:CFIXED(2*O_high+1 downto 2*O_low);
            signal iSO:UNSIGNED(SO'high-1 downto SO'low):=(others=>'0');
          begin
-- unpack CFIXED_VECTOR I
            I0<=ELEMENT(I,0,2);     
            I1<=ELEMENT(I,1,2);     
-- complex add/sub butterfly with scaling and overflow detection
            bf:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>I0,
                                         I1=>I1,
                                         SCALE=>SI(SI'low),
                                         O0=>O0,
                                         O1=>O1,
                                         OVR=>SO(SO'high));
-- pack CFIXED_VECTOR O
            O((0+1)*O'length/2-1+O'low downto 0*O'length/2+O'low)<=CFIXED_VECTOR(O0);
            O((1+1)*O'length/2-1+O'low downto 1*O'length/2+O'low)<=CFIXED_VECTOR(O1);
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                iSO<=SI(SI'high downto SI'low+1);
              end if;
            end process;
            SO(SO'high-1 downto SO'low)<=iSO;
            
            bd:entity work.BDELAY generic map(SIZE=>1)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
--          end;
          end generate;
--       elsif N=4 generate -- FFT4 case
       l4:if N=4 generate -- FFT4 case
            signal I0,I1,I2,I3:CFIXED(2*I_high+1 downto 2*I_low);
            signal P0,P1,P2,P3,P3S:CFIXED(2*I_high+3 downto 2*I_low);
            signal O0,O1,O2,O3,O1S,O3S:CFIXED(2*O_high+1 downto 2*O_low);
            signal S:UNSIGNED(SI'range):=(others=>'0');
            signal OVR1,OVR2:UNSIGNED(1 downto 0);
            signal iSO:UNSIGNED(SO'high-1 downto SO'low):=(others=>'0');
          begin
-- unpack CFIXED_VECTOR I
            I0<=ELEMENT(I,0,4);     
            I1<=ELEMENT(I,1,4);     
            I2<=ELEMENT(I,2,4);     
            I3<=ELEMENT(I,3,4);    
-- complex add/sub butterflies with scaling and overflow detection
            u0:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>I0,
                                         I1=>I2,
                                         SCALE=>SI(SI'low),
                                         O0=>P0,
                                         O1=>P1,
                                         OVR=>OVR1(0));
       
            u1:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                          I0=>I1,
                                          I1=>I3,
                                          SCALE=>SI(SI'low),
                                          O0=>P2,
                                          O1=>P3,
                                          OVR=>OVR1(1));
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                S<=(OVR1(0) or OVR1(1))&SI(SI'high downto SI'low+1);
              end if;
            end process;
          
            u2:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>P0,
                                         I1=>P2,
                                         SCALE=>S(S'low),
                                         O0=>O0,
                                         O1=>O2,
                                         OVR=>OVR2(0));
       
            P3S<=SWAP(P3);
            u3:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>P1,
                                         I1=>P3S,
                                         SCALE=>S(S'low),
                                         O0=>O1S,
                                         O1=>O3S,
                                         OVR=>OVR2(1));
            O1<=TO_CFIXED(RE(O1S),IM(O3S));
            O3<=TO_CFIXED(RE(O3S),IM(O1S));
-- pack CFIXED_VECTOR O
            O((0+1)*O'length/4-1+O'low downto 0*O'length/4+O'low)<=CFIXED_VECTOR(O0);
            O((1+1)*O'length/4-1+O'low downto 1*O'length/4+O'low)<=CFIXED_VECTOR(O1);
            O((2+1)*O'length/4-1+O'low downto 2*O'length/4+O'low)<=CFIXED_VECTOR(O2);
            O((3+1)*O'length/4-1+O'low downto 3*O'length/4+O'low)<=CFIXED_VECTOR(O3);
       
            SO(SO'high)<=(OVR2(0) or OVR2(1));
            process(CLK)
            begin
              if rising_edge(CLK) then
                iSO<=S(S'high downto S'low+1);
              end if;
            end process;
            SO(SO'high-1 downto SO'low)<=iSO;
            
            bd:entity work.BDELAY generic map(SIZE=>2)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
--          end;
          end generate;
--       elsif N=8 generate -- FFT8 case
       l8:if N=8 generate -- FFT8 case
--2008            constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
            constant BIT_GROWTH:INTEGER:=(O'high+1)/8/2-(I'high+1)/8/2;
            constant X:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,1); -- ModelSim workaround
            signal iV:BOOLEAN_VECTOR(0 to 3);
--2008            signal S:UNSIGNED_VECTOR(0 to 3)(SI'range);
            type TUV is array(NATURAL range <>) of UNSIGNED(SI'range);
            signal S:TUV(0 to 3);
            signal SS:UNSIGNED(SI'range);
            signal P:CFIXED_VECTOR(I'high+8*2*X downto I'low);
            signal VP:BOOLEAN;
            signal SP:UNSIGNED(SI'range);
            signal oV:BOOLEAN_VECTOR(0 to 1);
--2008            signal oS:UNSIGNED_VECTOR(0 to 1)(SO'range);
            signal oS:TUV(0 to 1);
          begin  
            s1:for K in 0 to 3 generate
--2008                 signal II:CFIXED_VECTOR(0 to 1)(RE(I(0).RE'high downto I(0).RE'low),IM(I(0).IM'high downto I(0).IM'low));
--2008                 signal OO:CFIXED_VECTOR(0 to 1)(RE(P(0).RE'high downto P(0).RE'low),IM(P(0).IM'high downto P(0).IM'low));
                 signal II:CFIXED_VECTOR(4*(I_high+1)-1 downto 4*I_low);
                 signal OO:CFIXED_VECTOR(4*(I_high+1+2*X)-1 downto 4*I_low);
                 signal OO0,OO1:CFIXED(2*(I_high+1+2*X)-1 downto 2*I_low);
                 signal P0,P1:CFIXED(I'length/8+2*X-1+I'low/8 downto I'low/8);
                 signal SS:UNSIGNED(SI'range);
               begin
--2008                 II(0)<=I(K);
--2008                 II(1)<=I(K+4);
                 II((0+1)*II'length/2-1+II'low downto 0*II'length/2+II'low)<=CFIXED_VECTOR(ELEMENT(I,K,8));
                 II((1+1)*II'length/2-1+II'low downto 1*II'length/2+II'low)<=CFIXED_VECTOR(ELEMENT(I,K+4,8));
                 p2:entity work.PARFFT generic map(N=>2,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>II,
                                                VI=>VI,
                                                SI=>SI,
                                                O=>OO,
                                                VO=>iV(K),
                                                SO=>S(K));
                 OO0<=ELEMENT(OO,0,2);
                 OO1<=ELEMENT(OO,1,2);
                 cd:entity work.CDELAY generic map(SIZE=>3)
                                       port map(CLK=>CLK,
--2008                                                I=>OO(0),
--2008                                                O=>P(2*K+0));
                                                I=>OO0,
                                                O=>P0);
                 ck:entity work.CKCM generic map(DSP48E=>DSP48E,
                                                 M=>K,
                                                 ROUNDING=>ROUNDING,
                                                 CONJUGATE=>INV_FFT)
                                     port map(CLK=>CLK,
--2008                                              I=>OO(1),
--2008                                              O=>P(2*K+1));
                                              I=>OO1,
                                              O=>P1);
                 P((2*K+1)*P'length/8-1+P'low downto (2*K+0)*P'length/8+P'low)<=CFIXED_VECTOR(P0);
                 P((2*K+2)*P'length/8-1+P'low downto (2*K+1)*P'length/8+P'low)<=CFIXED_VECTOR(P1);
               end generate;
            SS(SI'high)<=S(0)(SI'high) or S(1)(SI'high) or S(2)(SI'high) or S(3)(SI'high) when iV(0) else '0';
            SS(SI'high-1 downto SI'low)<=S(0)(SI'high-1 downto SI'low);
            ud:entity work.UDELAY generic map(SIZE=>3)
                                  port map(CLK=>CLK,
                                           I=>SS,
                                           O=>SP);
            bd:entity work.BDELAY generic map(SIZE=>3)
                                  port map(CLK=>CLK,
                                           I=>iV(0),
                                           O=>VP);
            s2:for K in 0 to 1 generate
--2008                 signal II:CFIXED_VECTOR(0 to 3)(RE(P(0).RE'high downto P(0).RE'low),IM(P(0).IM'high downto P(0).IM'low));
--2008                 signal OO:CFIXED_VECTOR(0 to 3)(RE(O(0).RE'high downto O(0).RE'low),IM(O(0).IM'high downto O(0).IM'low));
                 signal II:CFIXED_VECTOR((P'high+1)/2-1 downto P'low/2);
                 signal OO:CFIXED_VECTOR((O'high+1)/2-1 downto O'low/2);
                 signal SS:UNSIGNED(SI'range);
               begin
--2008                 II(0)<=P(K+0);
--2008                 II(1)<=P(K+2);
--2008                 II(2)<=P(K+4);
--2008                 II(3)<=P(K+6);
                 II((0+1)*II'length/4-1+II'low downto 0*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+0,8));     
                 II((1+1)*II'length/4-1+II'low downto 1*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+2,8));     
                 II((2+1)*II'length/4-1+II'low downto 2*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+4,8));     
                 II((3+1)*II'length/4-1+II'low downto 3*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+6,8));     
                 p2:entity work.PARFFT generic map(N=>4,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>II,
                                                VI=>VP,
                                                SI=>SP,
                                                O=>OO,
                                                VO=>oV(K),
                                                SO=>oS(K));
--2008                 O(K+0)<=OO(0);
--2008                 O(K+2)<=OO(1);
--2008                 O(K+4)<=OO(2);
--2008                 O(K+6)<=OO(3);
                 O((K+0+1)*O'length/8-1+O'low downto (K+0)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,0,4));
                 O((K+2+1)*O'length/8-1+O'low downto (K+2)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,1,4));
                 O((K+4+1)*O'length/8-1+O'low downto (K+4)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,2,4));
                 O((K+6+1)*O'length/8-1+O'low downto (K+6)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,3,4));
               end generate;
            VO<=oV(0);
            SO(SO'high downto SO'high-1)<=oS(0)(SO'high downto SO'high-1) or oS(1)(SO'high downto SO'high-1) when oV(0) else "00";
            SO(SO'high-2 downto SO'low)<=oS(0)(SO'high-2 downto SO'low);
--          end;
          end generate;
--       elsif N=2**L2N generate -- FFT2**n case using Split Radix decomposition, uses recursive PARFFT instantiation
       ln:if (N>8) and (N=2**L2N) generate -- FFT2**n  case using Split Radix decomposition, uses recursive PARFFT instantiation
--2008            constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
            constant BIT_GROWTH:INTEGER:=(O'high+1)/N/2-(I'high+1)/N/2;
            constant X1:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(0,work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,L2N)-2); -- ModelSim workaround
            constant X2:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(0,work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,L2N)-1); -- ModelSim workaround
            function MUL_LATENCY(N:INTEGER) return INTEGER is
            begin
              return 6;
            end;
            function LATENCY(N:INTEGER) return INTEGER is
            begin
              return LOG2(N)*4-6;
            end;
--2008            signal IU:CFIXED_VECTOR(0 to N/2-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008            signal U,UD:CFIXED_VECTOR(0 to N/2-1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
            signal IU:CFIXED_VECTOR((I'high+1)/2-1 downto I'low/2);
            signal U,UD:CFIXED_VECTOR((I'high+1)/2-1+N/2*2*X2 downto I'low/2);
            signal SU,SUD:UNSIGNED(SI'range);
            signal VU,VU4D:BOOLEAN;
--2008            signal ZO:CFIXED_MATRIX(0 to N/4-1)(0 to 1)(RE(I(I'low).RE'high+X1 downto I(I'low).RE'low),IM(I(I'low).IM'high+X1 downto I(I'low).IM'low));
            type CFIXED_MATRIX is array(INTEGER range <>) of CFIXED_VECTOR(2*2*(I_high+X1+1)-1 downto 2*2*I_low); -- unconstrained array of CFIXED_VECTOR
            signal ZO:CFIXED_MATRIX(0 to N/4-1);
            type TUV is array(NATURAL range <>) of UNSIGNED(SI'range);
--2008            signal S1:UNSIGNED_VECTOR(0 to 1)(SI'range);
            signal S1:TUV(0 to 1);
            signal S1I:UNSIGNED(SI'range);
--2008            signal S2:UNSIGNED_VECTOR(0 to N/4-1)(SI'range);
            signal S2:TUV(0 to N/4-1);
            signal S2I:UNSIGNED(SI'range):=(others=>'0');
--2008            signal S:UNSIGNED_VECTOR(0 to N/2-1)(SI'range);
            signal S:TUV(0 to N/2-1);
          begin
            lk:for K in 0 to N/2-1 generate
--2008                 IU(K)<=I(I'low+2*K);
                 IU((K+1)*IU'length/N*2-1+IU'low downto K*IU'length/N*2+IU'low)<=CFIXED_VECTOR(ELEMENT(I,2*K,N));
               end generate;
            pu:entity work.PARFFT generic map(N=>N/2,
                                              ROUNDING=>ROUNDING,
                                              W_high=>W_high,
                                              W_low=>W_low,
                                              INV_FFT=>INV_FFT,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                              DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           I=>IU,
                                           VI=>VI,
                                           SI=>SI,
                                           O=>U,
                                           VO=>VU,
                                           SO=>SU);
            du:for K in 0 to N/2-1 generate
                 signal UK,UDK:CFIXED((UD'high+1)/N*2-1 downto UD'low/N*2);
               begin
                 UK<=ELEMENT(U,K,N/2);
                 cd:entity work.CDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+1-LATENCY(N/2))--3) -- when CMUL latency is 6
                                     port map(CLK=>CLK,
--2008                                              I=>U(K),
--2008                                              O=>UD(K));
                                              I=>UK,
                                              O=>UDK);
                 UD((K+1)*UD'length/N*2-1+UD'low downto K*UD'length/N*2+UD'low)<=CFIXED_VECTOR(UDK);
               end generate;
            u4:entity work.UDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+2-LATENCY(N/2))--4) -- when CMUL latency is 6
                                  port map(CLK=>CLK,
                                           I=>SU,
                                           O=>SUD);
            b5:entity work.BDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+2-LATENCY(N/2))--4) -- when CMUL latency is 6
                                  port map(CLK=>CLK,
                                           I=>VU,
                                           O=>VO);
            ll:for L in 0 to 1 generate
--2008                 signal IZ:CFIXED_VECTOR(0 to N/4-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008                 signal Z,OZ:CFIXED_VECTOR(0 to N/4-1)(RE(I(I'low).RE'high+X1 downto I(I'low).RE'low),IM(I(I'low).IM'high+X1 downto I(I'low).IM'low));
                 signal IZ:CFIXED_VECTOR((I'high+1)/4-1 downto I'low/4);
                 signal Z,OZ:CFIXED_VECTOR((I'high+1)/4-1+N/4*2*X1 downto I'low/4);
                 signal SZ:UNSIGNED(SI'range);
                 signal SM:UNSIGNED(SI'range);
                 signal VZ:BOOLEAN;
               begin
                 li:for J in 0 to N/4-1 generate
--2008                      IZ(J)<=I(I'low+4*J+2*L+1);
                      IZ(2*(J+1)*(I_high-I_low+1)-1+IZ'low downto 2*J*(I_high-I_low+1)+IZ'low)<=CFIXED_VECTOR(ELEMENT(I,4*J+2*L+1,N));
                    end generate;
                 pe:entity work.PARFFT generic map(N=>N/4,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IZ,
                                                VI=>VI,
                                                SI=>SI,
                                                O=>Z,
                                                VO=>VZ,
                                                SO=>SZ);
                 me:entity work.CM3FFT generic map(N=>N,
                                                   RADIX=>N/4,
                                                   SPLIT_RADIX=>2*L+1,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>Z,
                                                VI=>VZ,
                                                SI=>SZ,
                                                O=>OZ,
                                                VO=>open,
                                                SO=>S1(L));
                 lo:for J in 0 to N/4-1 generate
--2008                      ZO(J)(L)<=OZ(J);
                      ZO(J)((L+1)*ZO(J)'length/2-1+ZO(J)'low downto L*ZO(J)'length/2+ZO(J)'low)<=CFIXED_VECTOR(ELEMENT(OZ,J,N/4));
                    end generate;
               end generate;
            S1I<=S1(0) or S1(1);
            l2:for J in 0 to N/4-1 generate
--2008                 signal O2:CFIXED_VECTOR(0 to 1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
--2008                 signal IE,IO:CFIXED_VECTOR(0 to 1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
--2008                 signal OE,OO:CFIXED_VECTOR(0 to 1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
                 signal O2:CFIXED_VECTOR(2*2*(I_high+X2+1)-1 downto 2*2*I_low);
                 signal IE,IO:CFIXED_VECTOR(2*2*(I_high+X2+1)-1 downto 2*2*I_low);
                 signal OE,OO:CFIXED_VECTOR(2*2*(O_high+1)-1 downto 2*2*O_low);
               begin
                 p2:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>ZO(J),
                                                VI=>TRUE,
                                                SI=>S1I,
                                                O=>O2,
                                                VO=>open,
                                                SO=>S2(J));
--2008                 IE(0)<=UD(J);
--2008                 IE(1)<=O2(0);
                 IE((0+1)*IE'length/2-1+IE'low downto 0*IE'length/2+IE'low)<=CFIXED_VECTOR(ELEMENT(UD,J,N/2));
                 IE((1+1)*IE'length/2-1+IE'low downto 1*IE'length/2+IE'low)<=CFIXED_VECTOR(ELEMENT(O2,0,2));
                 pe:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IE,
                                                VI=>TRUE,
                                                SI=>S2I,
                                                O=>OE,
                                                VO=>open,
                                                SO=>S(2*J));
--2008                 O(O'low+J)<=OE(0);
--2008                 O(O'low+J+N/2)<=OE(1);
--2008                 IO(0)<=UD(J+N/4);
--2008                 IO(1).RE<=O2(1).IM;
--2008                 IO(1).IM<=O2(1).RE;
--                 O((J+1)*O'length/N-1+O'low downto J*O'length/N+O'low)<=CFIXED_VECTOR(ELEMENT(OE,0,2));
--                 O((J+N/2+1)*O'length/N-1+O'low downto (J+N/2)*O'length/N+O'low)<=CFIXED_VECTOR(ELEMENT(OE,1,2));
                 O(2*(J+1)*(O_high-O_low+1)-1+O'low downto 2*J*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(ELEMENT(OE,0,2));
                 O(2*(J+N/2+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/2)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(ELEMENT(OE,1,2));
                 IO((0+1)*IO'length/2-1+IO'low downto 0*IO'length/2+IO'low)<=CFIXED_VECTOR(ELEMENT(UD,J+N/4,N/2));
                 IO((1+1)*IO'length/2-1+IO'low downto 1*IO'length/2+IO'low)<=CFIXED_VECTOR(TO_CFIXED(IM(ELEMENT(O2,1,2)),RE(ELEMENT(O2,1,2))));
                 po:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IO,
                                                VI=>TRUE,
                                                SI=>S2I,
                                                O=>OO,
                                                VO=>open,
                                                SO=>S(2*J+1));
                 ii:if INV_FFT generate
                    begin
--2008                      O(O'low+J+N/4).RE<=OO(1).RE;
--2008                      O(O'low+J+N/4).IM<=OO(0).IM;
--2008                      O(O'low+J+3*N/4).RE<=OO(0).RE;
--2008                      O(O'low+J+3*N/4).IM<=OO(1).IM;
--                      O((J+N/4+1)*O'length/N-1+O'low downto (J+N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
--                      O((J+3*N/4+1)*O'length/N-1+O'low downto (J+3*N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
                      O(2*(J+N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
                      O(2*(J+3*N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+3*N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
--                    end;
                    end generate;
--               else generate
                 id:if not INV_FFT generate
                    begin
--2008                      O(O'low+J+N/4).RE<=OO(0).RE;
--2008                      O(O'low+J+N/4).IM<=OO(1).IM;
--2008                      O(O'low+J+3*N/4).RE<=OO(1).RE;
--2008                      O(O'low+J+3*N/4).IM<=OO(0).IM;
--                      O((J+N/4+1)*O'length/N-1+O'low downto (J+N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
--                      O((J+3*N/4+1)*O'length/N-1+O'low downto (J+3*N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
                      O(2*(J+N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
                      O(2*(J+3*N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+3*N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
--                    end;
                    end generate;
               end generate;
            process(S2)
              variable vS2:UNSIGNED(SI'range);
            begin
              vS2:=SUD;
              for K in S2'range loop
                vS2:=vS2 or S2(K);
              end loop;
              S2I<=vS2;
            end process;
            process(S)
              variable vS:UNSIGNED(SI'range);
            begin
              vS:=(others=>'0');
              for K in S'range loop
                vS:=vS or S(K);
              end loop;
              SO<=vS;
            end process;
--          end;
          end generate;
--     else generate
     end generate;
  i1:if F>0 generate
       constant G:INTEGER:=2**F;          -- size of each PARFFT
       constant H:INTEGER:=N/G;           -- number of PARFFTs
--2008       signal S:UNSIGNED_VECTOR(0 to H)(SO'range);
       type TUV is array(0 to H) of UNSIGNED(SO'range);
       signal S:TUV;
       signal V:BOOLEAN_VECTOR(0 to H-1);
     begin
       S(S'low)<=(others=>'0');
       lk:for K in 0 to H-1 generate
            signal SK:UNSIGNED(SO'range);
--workaround for QuestaSim bug
--2008            signal II:CFIXED_VECTOR(0 to G-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008            signal OO:CFIXED_VECTOR(0 to G-1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
            signal II:CFIXED_VECTOR((I'high+1)/H-1 downto I'low/H);
            signal OO:CFIXED_VECTOR((O'high+1)/H-1 downto O'low/H);
          begin
--2008            II<=I(I'low+G*K+0 to I'low+G*K+G-1);
            II<=I(I'length/H*(K+1)-1+I'low downto I'length/H*K+I'low);
            bc:entity work.PARFFT generic map(N=>G,
                                              F=>0,
                                              INV_FFT=>INV_FFT,
                                              ROUNDING=>ROUNDING,
                                              W_high=>W_high,
                                              W_low=>W_low,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                              DSP48E=>DSP48E)
                              port map(CLK=>CLK,
                                       I=>II,
                                       VI=>VI,
                                       SI=>SI,
                                       O=>OO,
                                       VO=>V(K),
                                       SO=>SK);
--workaround for QuestaSim bug
--            O(O'low+G*K+0 to O'low+G*K+G-1)<=OO;
--2008            lo:for J in 0 to G-1 generate
--2008                 O(O'low+G*K+J)<=OO(J);
--2008               end generate;
            O(O'length/H*(K+1)-1+O'low downto O'length/H*K+O'low)<=OO;
            S(K+1)<=S(K) or SK;
          end generate;
       SO<=S(S'high);
       VO<=V(V'high);
--     end;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ?? Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             INPUT_SWAP.vhd
--  /   /                  Date Last Modified:   14 February 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     INPUT_SWAP
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Input Order Swap Module for Systolic FFT
--                     The module takes N samples, I'length per clock, in natural input order
--                     and outputs them in natural transposed order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity INPUT_SWAP is
  generic(N:INTEGER;                   -- N must be a power of 2
          SSR:INTEGER;                 -- SSR must be a power of 2
          BRAM_THRESHOLD:INTEGER:=256; -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
          USE_CB:BOOLEAN:=TRUE);       -- if FALSE use alternate architecture
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;             -- I'length must be a divisor of N, so it is also a power of 2
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end INPUT_SWAP;

architecture TEST of INPUT_SWAP is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute ram_style:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;   -- if F is not zero there will be a partial last stage
  constant G:INTEGER:=2**F;          -- size of each CB in last stage
  constant H:INTEGER:=RADIX/G;       -- number of CBs in last stage

  function RS(K:INTEGER) return STRING is
  begin
    if K<BRAM_THRESHOLD then
      return "distributed";
    else
      return "block";
    end if;
  end;

  type iCFIXED_MATRIX is array(NATURAL range <>) of CFIXED_VECTOR(I'range);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**LOG2(I'length) report "Port I length must be a power of 2!" severity error;
  assert SSR=2**LOG2(SSR) report "SSR must be a power of 2!" severity error;

  i0:if USE_CB or (L2N<=2*L2R) generate
       constant SIZE:INTEGER:=L2N/L2R;    -- floor(LOG2(N)/LOG2(RADIX))
     
       signal V:BOOLEAN_VECTOR(0 to SIZE-1);
--2008       signal S:UNSIGNED_VECTOR(0 to SIZE-1)(SI'range);
--2008       signal D:CFIXED_MATRIX(0 to SIZE-1)(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SI'range);
       signal S:UNSIGNED_VECTOR(0 to SIZE-1);
       signal D:iCFIXED_MATRIX(0 to SIZE-1);
     begin
       D(D'low)<=I;
       V(V'low)<=VI;
       S(S'low)<=SI;
       lk:for K in 0 to SIZE-2 generate
            bc:entity work.CB generic map(SSR=>SSR, --93
                                          PACKING_FACTOR=>RADIX**K,
                                          INPUT_PACKING_FACTOR_ADJUST=>-(RADIX**K/RADIX),                    -- this helps reduce
                                          OUTPUT_PACKING_FACTOR_ADJUST=>-(RADIX**K mod RADIX**(SIZE-2)),     -- RAM count and
                                          SHORTEN_VO_BY=>(RADIX-1)*RADIX**K mod ((RADIX-1)*RADIX**(SIZE-2))) -- latency by N/RADIX/RADIX-1 clocks
                              port map(CLK=>CLK,
                                       I=>D(K),
                                       VI=>V(K),
                                       SI=>S(K),
                                       O=>D(K+1),
                                       VO=>V(K+1),
                                       SO=>S(K+1));
          end generate;
--Last stage, it becomes a trivial assignment if F=0
       bl:block
            signal OV:BOOLEAN_VECTOR(0 to H-1);
--2008            signal OS:UNSIGNED_VECTOR(0 to H-1)(SI'range);
            signal OS:UNSIGNED_VECTOR(0 to H-1);
          begin
            lj:for J in OV'range generate
--2008                 signal OO:CFIXED_VECTOR(0 to G-1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
                 signal OO:CFIXED_VECTOR((O'high+1)/H-1 downto O'low/H);
               begin
                 bc:entity work.CB generic map(SSR=>G, --93
                                               PACKING_FACTOR=>RADIX**(SIZE-1))
                                   port map(CLK=>CLK,
--2008                                            I=>D(D'high)(I'low+G*J+0 to I'low+G*J+G-1),
                                            I=>D(D'high)(I'length/H*(J+1)-1+I'low downto I'length/H*J+I'low),
                                            VI=>V(V'high),
                                            SI=>S(S'high),
                                            O=>OO,
                                            VO=>OV(J),
                                            SO=>OS(J));
                 lk:for K in 0 to G-1 generate
--2008                      O(O'low+J+H*K)<=OO(K);
                      O(O'length/SSR*(J+H*K+1)-1+O'low downto O'length/SSR*(J+H*K)+O'low)<=OO(O'length/SSR*(K+1)-1+OO'low downto O'length/SSR*K+OO'low);
                    end generate;
               end generate;
            VO<=OV(OV'low);
            SO<=OS(OS'low);
          end block;
--2008     end;
     end generate;
--2008     else generate
  i1:if (not USE_CB) and (L2N>2*L2R) generate
       signal VI1D:BOOLEAN:=FALSE;
       signal V:BOOLEAN;
--2008       signal I1D:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(I'range=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0')));
       signal I1D:CFIXED_VECTOR(I'range):=(others=>'0');
       signal WCNT,RCNT:UNSIGNED(LOG2(N/RADIX)-1 downto 0):=(others=>'0');
       signal WA:UNSIGNED(WCNT'range):=(others=>'0');
       signal RA:UNSIGNED(RCNT'range):=(others=>'0');
       signal WSEL:UNSIGNED(LOG2(WCNT'length)-1 downto 0):=TO_UNSIGNED(0,LOG2(RCNT'length));
       signal RSEL:UNSIGNED(LOG2(RCNT'length)-1 downto 0):=TO_UNSIGNED(L2N-2*L2R,LOG2(RCNT'length));
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal OV:BOOLEAN;
       signal S:UNSIGNED(SO'range);     
     begin
       bd:entity work.BDELAY generic map(SIZE=>N/RADIX-RADIX-N/RADIX/RADIX+2)
                             port map(CLK=>CLK,
                                      I=>VI,
                                      O=>V);
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if VI then
             if WCNT=N/RADIX-1 then
               WSEL<=RSEL;
             end if;
             WCNT<=WCNT+1;
           else
             WCNT<=(others=>'0');
           end if;
         end if;
       end process;
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if V then
             if RCNT=N/RADIX-1 then
               if RSEL<L2R then
                 RSEL<=RSEL+TO_UNSIGNED(L2N-2*L2R,RSEL'length);
               else
                 RSEL<=RSEL+TO_UNSIGNED(2**LOG2(L2N-L2R)-L2R,RSEL'length);
               end if;
             end if;
             RCNT<=RCNT+1;
           else
             RCNT<=(others=>'0');
           end if;
           VI1D<=VI;
           I1D<=I;
         end if;
       end process;
-- Write Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           WA<=ROTATE_LEFT(WCNT,TO_INTEGER(WSEL));
         end if;
       end process;
-- Read Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           RA<=ROTATE_LEFT(RCNT,TO_INTEGER(RSEL));
         end if;
       end process;
          
--2008       lk:for K in 0 to I'length-1 generate
       lk:if TRUE generate
--? Vivado synthesis does not infer RAM from this code, just LUTs and FFs
--            signal MEM:CFIXED_VECTOR(0 to 2**(CNT'length+1)-1)(RE(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).RE)),IM(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).IM))):=(0 to 2**(CNT'length+1)-1=>(RE=>(I(low_f(I)).RE'range=>'0'),IM=>(I(low_f(I)).IM'range=>'0')));
--2008            signal MEMR:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            signal MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).IM'range):=(0 to 2**WCNT'length-1=>(I(I'low).IM'range=>'0'));
--2008            signal Q:CFIXED(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0'));
            signal MEM:iCFIXED_MATRIX(0 to 2**WCNT'length-1):=(0 to 2**WCNT'length-1=>(others=>'0'));
            signal Q:CFIXED_VECTOR(I'range):=(others=>'0');
--WBR            shared variable MEMR,MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            attribute ram_style of MEMR:signal is RS(N/RADIX);
--2008            attribute ram_style of MEMI:signal is RS(N/RADIX);
            attribute ram_style of MEM:signal is RS(N/RADIX);
          begin
            process(CLK)
            begin
              if rising_edge(CLK) then
                if VI1D then
                  MEM(TO_INTEGER(WA))<=I1D;
--2008                  MEMR(TO_INTEGER(WA))<=I1D(K).RE;
--2008                  MEMI(TO_INTEGER(WA))<=I1D(K).IM;
--                  MEMR(TO_INTEGER(WA)):=I1D(K).RE;
--                  MEMI(TO_INTEGER(WA)):=I1D(K).IM;
--WBR                  Q.RE<=I1D(K).RE;
--WBR                  Q.IM<=I1D(K).IM;
--WBR                else
--WBR                  Q.RE<=MEMR(TO_INTEGER(WA));
--WBR                  Q.IM<=MEMI(TO_INTEGER(WA));
                end if;
                Q<=MEM(TO_INTEGER(RA));
--2008                Q.RE<=MEMR(TO_INTEGER(RA));
--2008                Q.IM<=MEMI(TO_INTEGER(RA));
                IO<=Q;
              end if;
            end process;
          end generate;

       bo:entity work.BDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>V,
                                      O=>OV);

       sd:entity work.UDELAY generic map(SIZE=>N/RADIX-RADIX-N/RADIX/RADIX+5)
                             port map(CLK=>CLK,
                                      I=>SI,
                                      O=>S);

       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>1)
                         port map(CLK=>CLK,
                                  I=>IO,
                                  VI=>OV,
                                  SI=>S,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ? Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             SYSTOLIC_FFT.vhd
--  /   /                  Date Last Modified:   9 Mar 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     SYSTOLIC_FFT
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Mar-09 Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Systolic FFT Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity SYSTOLIC_FFT is
  generic(N:INTEGER;
          SSR:INTEGER; --93
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=256;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end SYSTOLIC_FFT;

architecture TEST of SYSTOLIC_FFT is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  
--2008  constant RADIX:INTEGER:=I'length;      -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;           -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;       -- if F is not zero there will be a partial last stage
  constant G:INTEGER:=2**F;              -- size of each CB and PARFFT in last stage
  constant H:INTEGER:=RADIX/G;           -- number of CBs and PARFFTsin last stage
  constant SIZE:INTEGER:=(L2N-1)/L2R;    -- ceil(LOG2(N)/LOG2(RADIX)), number of stages
--2008  constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
  constant BIT_GROWTH:INTEGER:=(O'high+1)/2/SSR-(I'high+1)/2/SSR;

--  constant XL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN((SIZE-1)*L2R,BIT_GROWTH);
  constant XL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(SIZE*L2R,BIT_GROWTH);
--2008  signal D:CFIXED_MATRIX(0 to SIZE)(I'range)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
  type CFIXED_MATRIX is array(INTEGER range <>) of CFIXED_VECTOR(O'range); -- unconstrained array of CFIXED_VECTOR
  signal D:CFIXED_MATRIX(0 to SIZE);
  signal V:BOOLEAN_VECTOR(0 to SIZE);
--2008  signal S:UNSIGNED_VECTOR(0 to SIZE)(SI'range);
  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SI'range); --93
  signal S:UNSIGNED_VECTOR(0 to SIZE);

--  constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(SIZE*L2R,BIT_GROWTH);
  constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(L2N,BIT_GROWTH);
--2008  signal DI:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XI downto I(I'low).RE'low),IM(I(I'low).IM'high+XI downto I(I'low).IM'low));
--2008  signal OO:CFIXED_VECTOR(O'range)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
  signal DI:CFIXED_VECTOR(I'high+2*SSR*XI downto I'low);
  signal OO:CFIXED_VECTOR(O'range);
begin
--2008  lj:for J in I'range generate
--2008       D(D'low)(J)<=RESIZE(I(J),D(D'low)(J));
  lj:for J in 0 to SSR-1 generate
       D(D'low)(O'length/SSR*(J+1)-1+O'low downto O'length/SSR*J+O'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(I,J,SSR),(O'high+1)/2/SSR-1,O'low/2/SSR));
     end generate;
  V(V'low)<=VI;
  S(S'low)<=SI;
  lk:for K in 0 to SIZE-1 generate
       constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(K*L2R,BIT_GROWTH);
       constant XO:INTEGER:=work.COMPLEX_FIXED_PKG.MIN((K+1)*L2R,BIT_GROWTH);
--2008       signal DI:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XI downto I(I'low).RE'low),IM(I(I'low).IM'high+XI downto I(I'low).IM'low));
--2008       signal DM,DB,DO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XO downto I(I'low).RE'low),IM(I(I'low).IM'high+XO downto I(I'low).IM'low));
       signal DI:CFIXED_VECTOR(I'high+2*SSR*XI downto I'low);
       signal DM,DB,DO:CFIXED_VECTOR(I'high+2*SSR*XO downto I'low);
       signal VM,VB:BOOLEAN;
       signal SM,SB:UNSIGNED(SI'range);
     begin
--2008       li:for J in 0 to I'length-1 generate
--2008            DI(DI'low+J)<=RESIZE(D(K)(J),DI(DI'low+J));
       li:for J in 0 to SSR-1 generate
            DI(DI'length/SSR*(J+1)-1+DI'low downto DI'length/SSR*J+DI'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(D(K),J,SSR),(DI'high+1)/2/SSR-1,DI'low/2/SSR));
          end generate;
       pf:entity work.PARFFT generic map(N=>RADIX, --93
                                         INV_FFT=>FALSE,
                                         ROUNDING=>ROUNDING,
                                         W_high=>W_high,
                                         W_low=>W_low,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                         DSP48E=>DSP48E)
                                     port map(CLK=>CLK,
                                              I=>DI,
                                              VI=>V(K),
                                              SI=>S(K),
                                              O=>DM,
                                              VO=>VM,
                                              SO=>SM);
       cm:entity work.CM3FFT generic map(N=>N/(RADIX**K),
                                         RADIX=>RADIX, --93
                                         INV_FFT=>FALSE,
                                         W_high=>W_high,
                                         W_low=>W_low,
                                         ROUNDING=>ROUNDING,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                         DSP48E=>DSP48E)
                            port map(CLK=>CLK,
                                      I=>DM,
                                      VI=>VM,
                                      SI=>SM,
                                      O=>DB,
                                      VO=>VB,
                                      SO=>SB);
     
       bc:entity work.CB generic map(SSR=>RADIX, --93
                                     F=>F*BOOLEAN'pos(K=SIZE-1),
                                     PACKING_FACTOR=>N/(RADIX**(K+2))*BOOLEAN'pos(K<SIZE-1)+BOOLEAN'pos(K=SIZE-1),
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>DB,
                                  VI=>VB,
                                  SI=>SB,
                                  O=>DO,
                                  VO=>V(K+1),
                                  SO=>S(K+1));
--2008       lo:for J in 0 to I'length-1 generate
--2008            D(K+1)(J)<=RESIZE(DO(DO'low+J),D(K+1)(J));
       lo:for J in 0 to SSR-1 generate
            D(K+1)(O'length/SSR*(J+1)-1+O'low downto O'length/SSR*J+O'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(DO,J,SSR),(O'high+1)/2/SSR-1,O'low/2/SSR));
          end generate;
     end generate;
--last PARFFT stage
--2008  li:for J in 0 to I'length-1 generate
--2008       DI(DI'low+J)<=RESIZE(D(D'high)(J),DI(DI'low+J));
  li:for J in 0 to SSR-1 generate
       DI(DI'length/SSR*(J+1)-1+DI'low downto DI'length/SSR*J+DI'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(D(D'high),J,SSR),(DI'high+1)/2/SSR-1,DI'low/2/SSR));
     end generate;
  pf:entity work.PARFFT generic map(N=>RADIX,
                                    F=>F,
                                    INV_FFT=>FALSE,
                                    ROUNDING=>ROUNDING,
                                    W_high=>W_high,
                                    W_low=>W_low,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                    DSP48E=>DSP48E)
                        port map(CLK=>CLK,
                                 I=>DI,
                                 VI=>V(V'high),
                                 SI=>S(S'high),
                                 O=>OO,
                                 VO=>VO,
                                 SO=>SO);
  lo:for J in 0 to H-1 generate
       lk:for K in 0 to G-1 generate
--2008            O(O'low+J+H*K)<=OO(OO'low+K+G*J);
            O(O'length/SSR*(J+H*K+1)-1+O'low downto O'length/SSR*(J+H*K)+O'low)<=OO(O'length/SSR*(K+G*J+1)-1+OO'low downto O'length/SSR*(K+G*J)+OO'low);
          end generate;
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
--  Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             DS.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     DS
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Output Order Swap Module for Systolic FFT (Digit Swap)
--                     Produces Transposed Output Order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity DS is -- LATENCY=0 when N=2*SSR else LATENCY=N/SSR+1
  generic(N:INTEGER;
          SSR:INTEGER;                  -- SSR must be a power of 2
          BRAM_THRESHOLD:INTEGER:=256); -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end DS;

architecture TEST of DS is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute ram_style:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;
  constant G:INTEGER:=2**F;

  signal VI1D:BOOLEAN:=FALSE;
  signal V:BOOLEAN;
--2008  signal I1D:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(I'range=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0')));
  signal I1D:CFIXED_VECTOR(I'range):=(others=>'0');
  signal WCNT,RCNT:UNSIGNED(LOG2(N/RADIX)-1 downto 0):=(others=>'0');
  signal WA:UNSIGNED(WCNT'range):=(others=>'0');
  signal RA:UNSIGNED(RCNT'range):=(others=>'0');

  function RS(K:INTEGER) return STRING is
  begin
    if K<BRAM_THRESHOLD then
      return "distributed";
    else
      return "block";
    end if;
  end;
  
  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(RCNT'range); --93
  function IDENTITY(K:INTEGER) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(0 to K-1);--93 (LOG2(K)-1 downto 0);
  begin
    for J in RESULT'range loop
      RESULT(J):=TO_UNSIGNED(J,RESULT(J)'length);
    end loop;
    return RESULT;
  end;
  
  function PERMUTE(A:UNSIGNED_VECTOR) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(A'range);--93 (A(A'low)'range);
  begin
    for J in RESULT'range loop
      for J in 0 to A'length/L2R-1 loop
        for K in 0 to L2R-1 loop
          RESULT((A'length/L2R-1-J)*L2R+K+F):=A(J*L2R+K);
        end loop;
      end loop;
      for K in 0 to F-1 loop
        RESULT(K):=A(A'length/L2R*L2R+K);
      end loop;
    end loop;
    return RESULT;
  end;
  
  function INVERSE_PERMUTE(A:UNSIGNED_VECTOR) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(A'range);--93 (A(A'low)'range);
  begin
    for J in RESULT'range loop
      for J in 0 to A'length/L2R-1 loop
        for K in 0 to L2R-1 loop
          RESULT(J*L2R+K):=A((A'length/L2R-1-J)*L2R+K+F);
        end loop;
      end loop;
      for K in 0 to F-1 loop
        RESULT(A'length/L2R*L2R+K):=A(K);
      end loop;
    end loop;
    return RESULT;
  end;
  
--2008  signal WSEL:UNSIGNED_VECTOR(0 to WCNT'length-1)(LOG2(WCNT'length)-1 downto 0):=INVERSE_PERMUTE(IDENTITY(WCNT'length));
--2008  signal RSEL:UNSIGNED_VECTOR(0 to RCNT'length-1)(LOG2(RCNT'length)-1 downto 0):=IDENTITY(RCNT'length);
  signal WSEL:UNSIGNED_VECTOR(0 to WCNT'length-1):=INVERSE_PERMUTE(IDENTITY(WCNT'length));
  signal RSEL:UNSIGNED_VECTOR(0 to RCNT'length-1):=IDENTITY(RCNT'length);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**L2R report "Port I length must be a power of 2!" severity error;
  assert SSR=2**L2R report "Port I length must be a power of 2!" severity error;

  i0:if L2N-L2R<2 generate
       O<=I;
       VO<=VI;
       SO<=SI;
--2008     else generate
     end generate;
  i1:if L2N-L2R>=2 generate
       bd:entity work.BDELAY generic map(SIZE=>N/RADIX-2)
                             port map(CLK=>CLK,
                                      I=>VI,
                                      O=>V);
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if VI then
             if WCNT=N/RADIX-1 then
               WSEL<=RSEL;
             end if;
             WCNT<=WCNT+1;
           else
             WCNT<=(others=>'0');
           end if;
         end if;
       end process;
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if V then
             if RCNT=N/RADIX-1 then
               RSEL<=PERMUTE(WSEL);
             end if;
             RCNT<=RCNT+1;
           else
             RCNT<=(others=>'0');
           end if;
           VI1D<=VI;
           I1D<=I;
         end if;
       end process;
-- Write Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           for K in WCNT'range loop
             WA(K)<=WCNT(TO_INTEGER(WSEL(K)));
           end loop;
         end if;
       end process;
-- Read Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           for K in RCNT'range loop
             RA(K)<=RCNT(TO_INTEGER(RSEL(K)));
           end loop;
         end if;
       end process;
     
--2008       lk:for K in 0 to I'length-1 generate
       lk:if TRUE generate
--? Vivado synthesis does not infer RAM from this code, just LUTs and FFs
--            signal MEM:CFIXED_VECTOR(0 to 2**(CNT'length+1)-1)(RE(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).RE)),IM(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).IM))):=(0 to 2**(CNT'length+1)-1=>(RE=>(I(low_f(I)).RE'range=>'0'),IM=>(I(low_f(I)).IM'range=>'0')));
--2008            signal MEMR:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            signal MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).IM'range):=(0 to 2**WCNT'length-1=>(I(I'low).IM'range=>'0'));
--2008            signal Q:CFIXED(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0'));
            type iCFIXED_MATRIX is array(NATURAL range <>) of CFIXED_VECTOR(I'range);
            signal MEM:iCFIXED_MATRIX(0 to 2**WCNT'length-1):=(0 to 2**WCNT'length-1=>(others=>'0'));
            signal Q:CFIXED_VECTOR(I'range):=(others=>'0');
--WBR            shared variable MEMR,MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            attribute ram_style of MEMR:signal is RS(N/RADIX);
--2008            attribute ram_style of MEMI:signal is RS(N/RADIX);
            attribute ram_style of MEM:signal is RS(N/RADIX);
          begin
            process(CLK)
            begin
              if rising_edge(CLK) then
                if VI1D then
                  MEM(TO_INTEGER(WA))<=I1D;
--2008                  MEMR(TO_INTEGER(WA))<=I1D(K).RE;
--2008                  MEMI(TO_INTEGER(WA))<=I1D(K).IM;
--                  MEMR(TO_INTEGER(WA)):=I1D(K).RE;
--                  MEMI(TO_INTEGER(WA)):=I1D(K).IM;
--WBR                  Q.RE<=I1D(K).RE;
--WBR                  Q.IM<=I1D(K).IM;
--WBR                else
--WBR                  Q.RE<=MEMR(TO_INTEGER(WA));
--WBR                  Q.IM<=MEMI(TO_INTEGER(WA));
                end if;
                Q<=MEM(TO_INTEGER(RA));
--2008                Q.RE<=MEMR(TO_INTEGER(RA));
--2008                Q.IM<=MEMI(TO_INTEGER(RA));
--2008                O(K)<=Q;
                O<=Q;
              end if;
            end process;
          end generate;
     
       bo:entity work.BDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>V,
                                      O=>VO);

       sd:entity work.UDELAY generic map(SIZE=>N/RADIX+1)
                             port map(CLK=>CLK,
                                      I=>SI,
                                      O=>SO);
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- Â© Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             DSN.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     DSN
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Output Order Swap Module for Systolic FFT (Digit Swap)
--                     Produces Natural Output Order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity DSN is
  generic(N:INTEGER;
          SSR:INTEGER;                  -- SSR must be a power of 2
          BRAM_THRESHOLD:INTEGER:=256); -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end DSN;

architecture TEST of DSN is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute rloc:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;
  constant G:INTEGER:=2**F;
  constant H:INTEGER:=RADIX/G;
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**L2R report "Port I length must be a power of 2!" severity error;
  assert SSR=2**L2R report "Port I length must be a power of 2!" severity error;

  i1:if L2N<2*L2R generate
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal V:BOOLEAN;
       signal S:UNSIGNED(SI'range);
       signal OV:BOOLEAN_VECTOR(0 to H-1);
--2008       signal OS:UNSIGNED_VECTOR(0 to H-1)(SO'range);
       type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SO'range); --93
       signal OS:UNSIGNED_VECTOR(0 to H-1);
     begin
       sd:entity work.DS generic map(N=>N,
                                     SSR=>SSR, --93
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>IO,
                                  VO=>V,
                                  SO=>S);
       lk:for K in 0 to H-1 generate
----2008            signal II,OO:CFIXED_VECTOR(0 to G-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
            signal II,OO:CFIXED_VECTOR((I'high+1)/H-1 downto I'low/H);
          begin
            li:for J in 0 to G-1 generate
--2008                 II(J)<=IO(IO'low+K+H*J);
                 II(I'length/SSR*(J+1)-1+II'low downto I'length/SSR*J+II'low)<=IO(I'length/SSR*(K+H*J+1)-1+I'low downto I'length/SSR*(K+H*J)+I'low);
               end generate;
            ci:entity work.CB generic map(SSR=>G, --93
                                          PACKING_FACTOR=>1)
                              port map(CLK=>CLK,
                                       I=>II,
                                       VI=>V,
                                       SI=>S,
                                       O=>OO,
                                       VO=>OV(K),
                                       SO=>OS(K));
            lo:for J in 0 to G-1 generate
----2008                 O(O'low+K*G+J)<=OO(J);
                 O(O'length/SSR*(K*G+J+1)-1+O'low downto O'length/SSR*(K*G+J)+O'low)<=OO(O'length/SSR*(J+1)-1+OO'low downto O'length/SSR*J+OO'low);
               end generate;
          end generate;
       VO<=OV(OV'low);
       SO<=OS(OS'low);
--2008     end;
     end generate;
--2008     elsif L2N=2*L2R generate
  i2:if L2N=2*L2R generate
       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>1)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
--2008     else generate
     end generate;
  i3:if L2N>2*L2R generate
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal V:BOOLEAN;
       signal S:UNSIGNED(SO'range);     
     begin
       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>N/RADIX/RADIX,
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>IO,
                                  VO=>V,
                                  SO=>S);

       sd:entity work.DS generic map(N=>N/RADIX,
                                     SSR=>SSR, --93
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>IO,
                                  VI=>V,
                                  SI=>S,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
     end generate;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ? Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             VECTOR_FFT.vhd
--  /   /                  Date Last Modified:   9 Mar 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     VECTOR_FFT
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Mar-09 Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Top Level Test Module for SYSTOLIC_FFT
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity VECTOR_FFT is
  generic(SSR:INTEGER:=8;--4;
          N:INTEGER:=16384;--8192;--4096;--1024;
          I_high:INTEGER:=0;
          I_low:INTEGER:=-17;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          O_high:INTEGER:=0;
          O_low:INTEGER:=-17;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=512;
          USE_CB:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
--2008       I:in CFIXED_VECTOR(0 to RADIX-1)(RE(I_high downto I_low),IM(I_high downto I_low));
       I:in CFIXED_VECTOR(SSR*2*(I_high-I_low+1)-1 downto 0);
       VI:in BOOLEAN;
       SI:in UNSIGNED(LOG2(N)-1 downto 0);
--2008       O:out CFIXED_VECTOR(0 to RADIX-1)(RE(O_high downto O_low),IM(O_high downto O_low));
       O:out CFIXED_VECTOR(SSR*2*(O_high-O_low+1)-1 downto 0);
       VO:out BOOLEAN;
       SO:out UNSIGNED(LOG2(N)-1 downto 0));
end VECTOR_FFT;

architecture TEST of VECTOR_FFT is
  function TO_SFIXED(S:STD_LOGIC_VECTOR;I:SFIXED) return SFIXED is
    variable R:SFIXED(I'range);
  begin
    for K in 0 to R'length-1 loop
      R(R'low+K):=S(S'low+K);
    end loop;
    return R;
  end;
  
  function TO_STD_LOGIC_VECTOR(S:SFIXED) return STD_LOGIC_VECTOR is
    variable R:STD_LOGIC_VECTOR(S'length-1 downto 0);
  begin
    for K in 0 to R'length-1 loop
      R(R'low+K):=S(S'low+K);
    end loop;
    return R;
  end;
  
--2008  signal II:CFIXED_VECTOR(I'range)(RE(I_high downto I_low),IM(I_high downto I_low));
  signal II:CFIXED_VECTOR(I'range);
  signal V,VOFFT,VODS:BOOLEAN;
  signal S,SFFT,SODS:UNSIGNED(SI'range);
--2008  signal OFFT,ODS:CFIXED_VECTOR(O'range)(RE(O_high downto O_low),IM(O_high downto O_low));
  signal OFFT,ODS:CFIXED_VECTOR(O'range);
begin
  u0:entity work.INPUT_SWAP generic map(N=>N,
                                       SSR=>SSR, --93
                                       BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                       USE_CB=>USE_CB)
                           port map(CLK=>CLK,
                                    I=>I,
                                    VI=>VI,
                                    SI=>SI,
                                    O=>II,
                                    VO=>V,
                                    SO=>S);

  u1:entity work.SYSTOLIC_FFT generic map(N=>N,
                                         SSR=>SSR, --93
                                         W_high=>W_high,
                                         W_low=>W_low,
                                         ROUNDING=>ROUNDING,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                         DSP48E=>DSP48E)
                             port map(CLK=>CLK,
                                      I=>II,
                                      VI=>V,
                                      SI=>S,
                                      O=>OFFT,
                                      VO=>VOFFT,
                                      SO=>SFFT);

  u2:entity work.DSN generic map(N=>N,
                                 SSR=>SSR, --93
                                 BRAM_THRESHOLD=>BRAM_THRESHOLD)
                     port map(CLK=>CLK,
                              I=>OFFT,
                              VI=>VOFFT,
                              SI=>SFFT,
                              O=>O,
                              VO=>VO,
                              SO=>SO);  
--  O<=OFFT;
--  VO<=VOFFT;
--  SO<=SFFT;
end TEST;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.COMPLEX_FIXED_PKG.all;

entity WRAPPER_VECTOR_FFT is
  generic(SSR:INTEGER:=8;
          N:INTEGER:=512;
          L2N:INTEGER:=9; -- L2N must be set equal to log2(N)!!!
          I_high:INTEGER:=0;
          I_low:INTEGER:=-15;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          O_high:INTEGER:=0;
          O_low:INTEGER:=-15;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=512;
          USE_CB:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       CE:in STD_LOGIC:='1'; -- not used, for SysGen only
       I:in STD_LOGIC_VECTOR(2*SSR*(I_high-I_low+1)-1 downto 0);
       VI:in STD_LOGIC;
       SI:in STD_LOGIC_VECTOR(L2N-1 downto 0):=(L2N-1 downto 0=>'0'); -- can be left unconnected if internal scaling is not used, must be a (LOG2(N)-1 downto 0) port
       O:out STD_LOGIC_VECTOR(2*SSR*(O_high-O_low+1)-1 downto 0);
       VO:out STD_LOGIC;
       SO:out STD_LOGIC_VECTOR(L2N-1 downto 0)); -- can be left unconnected if internal overflow is not possible, must be a (LOG2(N)-1 downto 0) port
end WRAPPER_VECTOR_FFT;

architecture WRAPPER of WRAPPER_VECTOR_FFT is 
-- resize SFIXED and convert to STD_LOGIC_VECTOR
  function SFIXED_TO_SLV_RESIZE(I:SFIXED;hi,lo:INTEGER) return STD_LOGIC_VECTOR is
    variable O:STD_LOGIC_VECTOR(hi-lo downto 0);
  begin
    for K in O'range loop
      if K<I'low-lo then
        O(K):='0';
      elsif K<I'length then
        O(K):=I(K+lo);
      else
        O(K):=I(I'high);
      end if;
    end loop;
    return O;
  end;
-- convert STD_LOGIC_VECTOR to SFIXED and resize 
  function SLV_TO_SFIXED_RESIZE(I:STD_LOGIC_VECTOR;hi,lo:INTEGER;ofs:INTEGER:=0) return SFIXED is
    variable O:SFIXED(hi downto lo);
  begin
    for K in O'range loop
      if K<I'low+lo+ofs then
        O(K):='0';
      elsif K-lo-ofs<I'length then
        O(K):=I(K-lo-ofs);
      else
        O(K):=I(I'high);
      end if;
    end loop;
    return O;
  end;

  signal II:CFIXED_VECTOR(SSR*2*(I_high+1)-1 downto SSR*2*I_low);
  signal VII:BOOLEAN;
  signal SII:UNSIGNED(SI'range);
  signal OO:CFIXED_VECTOR(SSR*2*(O_high+1)-1 downto SSR*2*O_low);
  signal VOO:BOOLEAN;
  signal SOO:UNSIGNED(SO'range);
begin
  II<=CFIXED_VECTOR(I);
  VII<=VI='1';
  SII<=UNSIGNED(SI);
  pf:entity work.VECTOR_FFT generic map(SSR=>SSR,
                                              N=>N,
                                              I_high=>I_high,
                                              I_low=>I_low,
                                              W_high=>W_high,
                                              W_low=>W_low,
                                              O_high=>O_high,
                                              O_low=>O_low,
                                              ROUNDING=>ROUNDING,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                              USE_CB=>USE_CB,
                                              DSP48E=>DSP48E)        -- 1 for DSP48E1, 2 for DSP48E2
                                  port map(CLK=>CLK,
                                           I=>II,
                                           VI=>VII,
                                           SI=>SII,
                                           O=>OO,
                                           VO=>VOO,
                                           SO=>SOO); 
  O<=STD_LOGIC_VECTOR(OO);
  VO<='1' when VOO else '0';
  SO<=STD_LOGIC_VECTOR(SOO);
end WRAPPER;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity WRAPPER_VECTOR_FFT_c5415935ecc00ff9eff39575a72e6e61 is 
  generic (
    BRAM_THRESHOLD : integer := 258;
    DSP48E : integer := 2;
    I_high : integer := -2;
    I_low : integer := -17;
    L2N : integer := 6;
    N : integer := 64;
    O_high : integer := 9;
    O_low : integer := -17;
    SSR : integer := 8;
    W_high : integer := 1;
    W_low : integer := -17
    );
  port(
    I : in std_logic_vector(255 downto 0);
    VI : in std_logic;
    SI : in std_logic_vector(5 downto 0);
    O : out std_logic_vector(431 downto 0);
    VO : out std_logic;
    SO : out std_logic_vector(5 downto 0);
    CLK : in std_logic;
    CE : in std_logic
  );
end WRAPPER_VECTOR_FFT_c5415935ecc00ff9eff39575a72e6e61;
architecture structural of WRAPPER_VECTOR_FFT_c5415935ecc00ff9eff39575a72e6e61 is 
  signal I_net : std_logic_vector(255 downto 0);
  signal VI_net : std_logic;
  signal SI_net : std_logic_vector(5 downto 0);
  signal O_net : std_logic_vector(431 downto 0);
  signal VO_net : std_logic;
  signal SO_net : std_logic_vector(5 downto 0);
  signal CLK_net : std_logic;
  signal CE_net : std_logic;
  component WRAPPER_VECTOR_FFT is
  generic (
    BRAM_THRESHOLD : integer := 258;
    DSP48E : integer := 2;
    I_high : integer := -2;
    I_low : integer := -17;
    L2N : integer := 6;
    N : integer := 64;
    O_high : integer := 9;
    O_low : integer := -17;
    SSR : integer := 8;
    W_high : integer := 1;
    W_low : integer := -17
    );
    port(
      I : in std_logic_vector(255 downto 0);
      VI : in std_logic;
      SI : in std_logic_vector(5 downto 0);
      O : out std_logic_vector(431 downto 0);
      VO : out std_logic;
      SO : out std_logic_vector(5 downto 0);
      CLK : in std_logic;
      CE : in std_logic
    );
  end component;
begin
  I_net <= I;
  VI_net <= VI;
  SI_net <= SI;
  O <= O_net;
  VO <= VO_net;
  SO <= SO_net;
  CLK_net <= CLK;
  CE_net <= CE;
  WRAPPER_VECTOR_FFT_inst : WRAPPER_VECTOR_FFT
    generic map(
      BRAM_THRESHOLD => 258,
      DSP48E => 2,
      I_high => -2,
      I_low => -17,
      L2N => 6,
      N => 64,
      O_high => 9,
      O_low => -17,
      SSR => 8,
      W_high => 1,
      W_low => -17
    )
    port map(
      I => I_net,
      VI => VI_net,
      SI => SI_net,
      O => O_net,
      VO => VO_net,
      SO => SO_net,
      CLK => CLK_net,
      CE => CE_net
    );
end structural;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

---------------------------------------------------------------------
--
--  Filename      : xlslice.vhd
--
--  Description   : VHDL description of a block that sets the output to a
--                  specified range of the input bits. The output is always
--                  set to an unsigned type with it's binary point at zero.
--
---------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;


entity ssr_8x64_xlslice is
    generic (
        new_msb      : integer := 9;           -- position of new msb
        new_lsb      : integer := 1;           -- position of new lsb
        x_width      : integer := 16;          -- Width of x input
        y_width      : integer := 8);          -- Width of y output
    port (
        x : in std_logic_vector (x_width-1 downto 0);
        y : out std_logic_vector (y_width-1 downto 0));
end ssr_8x64_xlslice;

architecture behavior of ssr_8x64_xlslice is
begin
    y <= x(new_msb downto new_lsb);
end  behavior;

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity sysgen_concat_384683215a is
  port (
    in0 : in std_logic_vector((16 - 1) downto 0);
    in1 : in std_logic_vector((16 - 1) downto 0);
    y : out std_logic_vector((32 - 1) downto 0);
    clk : in std_logic;
    ce : in std_logic;
    clr : in std_logic);
end sysgen_concat_384683215a;
architecture behavior of sysgen_concat_384683215a
is
  signal in0_1_23: unsigned((16 - 1) downto 0);
  signal in1_1_27: unsigned((16 - 1) downto 0);
  signal y_2_1_concat: unsigned((32 - 1) downto 0);
begin
  in0_1_23 <= std_logic_vector_to_unsigned(in0);
  in1_1_27 <= std_logic_vector_to_unsigned(in1);
  y_2_1_concat <= std_logic_vector_to_unsigned(unsigned_to_std_logic_vector(in0_1_23) & unsigned_to_std_logic_vector(in1_1_27));
  y <= unsigned_to_std_logic_vector(y_2_1_concat);
end behavior;

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity sysgen_reinterpret_53c8e6f5a2 is
  port (
    input_port : in std_logic_vector((16 - 1) downto 0);
    output_port : out std_logic_vector((16 - 1) downto 0);
    clk : in std_logic;
    ce : in std_logic;
    clr : in std_logic);
end sysgen_reinterpret_53c8e6f5a2;
architecture behavior of sysgen_reinterpret_53c8e6f5a2
is
  signal input_port_1_40: signed((16 - 1) downto 0);
  signal output_port_5_5_force: unsigned((16 - 1) downto 0);
begin
  input_port_1_40 <= std_logic_vector_to_signed(input_port);
  output_port_5_5_force <= signed_to_unsigned(input_port_1_40);
  output_port <= unsigned_to_std_logic_vector(output_port_5_5_force);
end behavior;

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity sysgen_reinterpret_d7a483898b is
  port (
    input_port : in std_logic_vector((27 - 1) downto 0);
    output_port : out std_logic_vector((27 - 1) downto 0);
    clk : in std_logic;
    ce : in std_logic;
    clr : in std_logic);
end sysgen_reinterpret_d7a483898b;
architecture behavior of sysgen_reinterpret_d7a483898b
is
  signal input_port_1_40: unsigned((27 - 1) downto 0);
  signal output_port_5_5_force: signed((27 - 1) downto 0);
begin
  input_port_1_40 <= std_logic_vector_to_unsigned(input_port);
  output_port_5_5_force <= unsigned_to_signed(input_port_1_40);
  output_port <= signed_to_std_logic_vector(output_port_5_5_force);
end behavior;

library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity sysgen_concat_c0fcf025b9 is
  port (
    in0 : in std_logic_vector((32 - 1) downto 0);
    in1 : in std_logic_vector((32 - 1) downto 0);
    in2 : in std_logic_vector((32 - 1) downto 0);
    in3 : in std_logic_vector((32 - 1) downto 0);
    in4 : in std_logic_vector((32 - 1) downto 0);
    in5 : in std_logic_vector((32 - 1) downto 0);
    in6 : in std_logic_vector((32 - 1) downto 0);
    in7 : in std_logic_vector((32 - 1) downto 0);
    y : out std_logic_vector((256 - 1) downto 0);
    clk : in std_logic;
    ce : in std_logic;
    clr : in std_logic);
end sysgen_concat_c0fcf025b9;
architecture behavior of sysgen_concat_c0fcf025b9
is
  signal in0_1_23: unsigned((32 - 1) downto 0);
  signal in1_1_27: unsigned((32 - 1) downto 0);
  signal in2_1_31: unsigned((32 - 1) downto 0);
  signal in3_1_35: unsigned((32 - 1) downto 0);
  signal in4_1_39: unsigned((32 - 1) downto 0);
  signal in5_1_43: unsigned((32 - 1) downto 0);
  signal in6_1_47: unsigned((32 - 1) downto 0);
  signal in7_1_51: unsigned((32 - 1) downto 0);
  signal y_2_1_concat: unsigned((256 - 1) downto 0);
begin
  in0_1_23 <= std_logic_vector_to_unsigned(in0);
  in1_1_27 <= std_logic_vector_to_unsigned(in1);
  in2_1_31 <= std_logic_vector_to_unsigned(in2);
  in3_1_35 <= std_logic_vector_to_unsigned(in3);
  in4_1_39 <= std_logic_vector_to_unsigned(in4);
  in5_1_43 <= std_logic_vector_to_unsigned(in5);
  in6_1_47 <= std_logic_vector_to_unsigned(in6);
  in7_1_51 <= std_logic_vector_to_unsigned(in7);
  y_2_1_concat <= std_logic_vector_to_unsigned(unsigned_to_std_logic_vector(in0_1_23) & unsigned_to_std_logic_vector(in1_1_27) & unsigned_to_std_logic_vector(in2_1_31) & unsigned_to_std_logic_vector(in3_1_35) & unsigned_to_std_logic_vector(in4_1_39) & unsigned_to_std_logic_vector(in5_1_43) & unsigned_to_std_logic_vector(in6_1_47) & unsigned_to_std_logic_vector(in7_1_51));
  y <= unsigned_to_std_logic_vector(y_2_1_concat);
end behavior;

