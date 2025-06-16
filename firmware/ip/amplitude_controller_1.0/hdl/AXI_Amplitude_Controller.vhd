--  Copyright (c) 2021, Xilinx, Inc.
--  All rights reserved.
-- 
--  Redistribution and use in source and binary forms, with or without 
--  modification, are permitted provided that the following conditions are met:
--
--  1.  Redistributions of source code must retain the above copyright notice, 
--      this list of conditions and the following disclaimer.
--
--  2.  Redistributions in binary form must reproduce the above copyright 
--      notice, this list of conditions and the following disclaimer in the 
--      documentation and/or other materials provided with the distribution.
--
--  3.  Neither the name of the copyright holder nor the names of its 
--      contributors may be used to endorse or promote products derived from 
--      this software without specific prior written permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
--  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
--  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
--  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
--  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
--  OR BUSINESS INTERRUPTION). HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
--  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
--  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
--  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


----------------------------------------------------------------------------------
-- Company: Xilinx
-- Engineer: David Northcote
-- 
-- Create Date: 27.01.2021 10:21:12
-- Design Name: AXI Amplitude Controller
-- Module Name: AXI_Amplitude_Controller - arch_imp
-- Project Name: AXI Ampltide Controller
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: A simple amplitude controller that outputs an AXI-Lite register to
--              an AXI-Stream interface.
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Revision 1.00 - Design Complete
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity AXI_Amplitude_Controller is
    Generic (  C_S_AXI_DATA_WIDTH	: integer	:= 32;
		       C_S_AXI_ADDR_WIDTH	: integer	:= 4;
		       C_M_AXIS_DATA_WIDTH  : integer   := 32);
    Port ( 	aclk	: in std_logic;
            aresetn	: in std_logic;
            s_axi_awaddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            s_axi_awprot	: in std_logic_vector(2 downto 0);
            s_axi_awvalid	: in std_logic;
            s_axi_awready	: out std_logic;
            s_axi_wdata	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            s_axi_wstrb	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
            s_axi_wvalid	: in std_logic;
            s_axi_wready	: out std_logic;
            s_axi_bresp	: out std_logic_vector(1 downto 0);
            s_axi_bvalid	: out std_logic;
            s_axi_bready	: in std_logic;
            s_axi_araddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            s_axi_arprot	: in std_logic_vector(2 downto 0);
            s_axi_arvalid	: in std_logic;
            s_axi_arready	: out std_logic;
            s_axi_rdata	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            s_axi_rresp	: out std_logic_vector(1 downto 0);
            s_axi_rvalid	: out std_logic;
            s_axi_rready	: in std_logic;
    
            m_axis_tvalid : out STD_LOGIC;
            m_axis_tdata : out STD_LOGIC_VECTOR (C_M_AXIS_DATA_WIDTH-1 downto 0);
            m_axis_tready : in STD_LOGIC
        );

end AXI_Amplitude_Controller;

architecture arch_imp of AXI_Amplitude_Controller is

    component S_AXI_Lite is
		generic (
		C_S_AXI_DATA_WIDTH	: integer;
		C_S_AXI_ADDR_WIDTH	: integer
		);
		port (
		enable : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		amplitude : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component; 
	
	component Amplitude_Controller is
        Generic (N : integer;
             B : integer);
        Port ( enable : in STD_LOGIC;
               amplitude : in STD_LOGIC_VECTOR (N-1 downto 0);
               m_tvalid : out STD_LOGIC;
               m_tdata : out STD_LOGIC_VECTOR (N*B-1 downto 0);
               m_tready : in STD_LOGIC;
               clk : in STD_LOGIC);
    end component;
    
    constant NUMBER_OF_CONCATS : integer := C_M_AXIS_DATA_WIDTH/C_S_AXI_DATA_WIDTH;
    signal ac_enable_sig : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others=>'0');
    signal ac_amplitude_sig : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others=>'0');

begin

    AXI_LITE_CORE : S_AXI_Lite
        generic map (
            C_S_AXI_DATA_WIDTH	=> C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH	=> C_S_AXI_ADDR_WIDTH
        )
        port map (
            enable => ac_enable_sig,
            amplitude => ac_amplitude_sig,
            S_AXI_ACLK	=> aclk,
            S_AXI_ARESETN	=> aresetn,
            S_AXI_AWADDR	=> s_axi_awaddr,
            S_AXI_AWPROT	=> s_axi_awprot,
            S_AXI_AWVALID	=> s_axi_awvalid,
            S_AXI_AWREADY	=> s_axi_awready,
            S_AXI_WDATA	=> s_axi_wdata,
            S_AXI_WSTRB	=> s_axi_wstrb,
            S_AXI_WVALID	=> s_axi_wvalid,
            S_AXI_WREADY	=> s_axi_wready,
            S_AXI_BRESP	=> s_axi_bresp,
            S_AXI_BVALID	=> s_axi_bvalid,
            S_AXI_BREADY	=> s_axi_bready,
            S_AXI_ARADDR	=> s_axi_araddr,
            S_AXI_ARPROT	=> s_axi_arprot,
            S_AXI_ARVALID	=> s_axi_arvalid,
            S_AXI_ARREADY	=> s_axi_arready,
            S_AXI_RDATA	=> s_axi_rdata,
            S_AXI_RRESP	=> s_axi_rresp,
            S_AXI_RVALID	=> s_axi_rvalid,
            S_AXI_RREADY	=> s_axi_rready
        );
        
    AC : Amplitude_Controller
        generic map (
            N => C_S_AXI_DATA_WIDTH,
            B => NUMBER_OF_CONCATS
        )
        port map (
            enable => ac_enable_sig(0),
            amplitude => ac_amplitude_sig,
            m_tvalid => m_axis_tvalid,
            m_tdata => m_axis_tdata,
            m_tready => m_axis_tready,
            clk => aclk);

end arch_imp;