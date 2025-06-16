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
-- Create Date: 26.01.2021 11:10:44
-- Design Name: AXI Packet Generator
-- Module Name: AXI_Packet_Generator - arch_imp
-- Project Name: AXI Packet Generator
-- Target Devices: zynq
-- Tool Versions: 2020.1
-- Description: A simple IP core to convert free running AXI-Stream interfaces
--              to AXI-Stream packets. Primarily for transferring complex data
--              in an RFSoC design with an AXI DMA.
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

entity AXI_Packet_Generator is
    generic (
        C_S_AXIS_DATA_WIDTH : integer := 32;
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
		);
    Port (
        aclk	    : in std_logic;
        aresetn	: in std_logic;
        s_axi_awaddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		s_axi_awprot	: in std_logic_vector(2 downto 0);
		s_axi_awvalid	: in std_logic;
		s_axi_awready	: out std_logic;
		s_axi_wdata	    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		s_axi_wstrb	    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		s_axi_wvalid	: in std_logic;
		s_axi_wready	: out std_logic;
		s_axi_bresp	    : out std_logic_vector(1 downto 0);
		s_axi_bvalid	: out std_logic;
		s_axi_bready	: in std_logic;
		s_axi_araddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		s_axi_arprot	: in std_logic_vector(2 downto 0);
		s_axi_arvalid	: in std_logic;
		s_axi_arready	: out std_logic;
		s_axi_rdata	    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		s_axi_rresp	    : out std_logic_vector(1 downto 0);
		s_axi_rvalid	: out std_logic;
		s_axi_rready	: in std_logic;
		    
        s_axis_re_tvalid : in STD_LOGIC;
        s_axis_im_tvalid : in STD_LOGIC;
        s_axis_re_tdata  : in STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
        s_axis_im_tdata  : in STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
        s_axis_re_tready : out STD_LOGIC;
        s_axis_im_tready : out STD_LOGIC;
        m_axis_re_tvalid : out STD_LOGIC;
        m_axis_im_tvalid : out STD_LOGIC;
        m_axis_re_tdata  : out STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
        m_axis_im_tdata  : out STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
        m_axis_re_tlast  : out STD_LOGIC;
        m_axis_im_tlast  : out STD_LOGIC;
        m_axis_re_tready : in STD_LOGIC;
        m_axis_im_tready : in STD_LOGIC);
        
end AXI_Packet_Generator;

architecture arch_imp of AXI_Packet_Generator is

    component S_AXI_Lite is
		generic ( C_S_AXI_DATA_WIDTH	: integer	:= 32;
		          C_S_AXI_ADDR_WIDTH	: integer	:= 4
);
		port (
               packetsize : out std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
		       transfer : out std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
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

    component Packet_Generator is
        Generic ( N : integer);
        Port ( packetsize : in STD_LOGIC_VECTOR (31 downto 0);
               s_tvalid : in STD_LOGIC;
               s_tdata : in STD_LOGIC_VECTOR (N-1 downto 0);
               m_tvalid : out STD_LOGIC;
               m_tdata : out STD_LOGIC_VECTOR (N-1 downto 0);
               m_tuser : out STD_LOGIC;
               m_tlast : out STD_LOGIC;
               clk : in STD_LOGIC);
    end component;
    
    component Packet_Inspector is
    generic (N : integer);
    Port ( transfer : in STD_LOGIC;
           s_tvalid : in STD_LOGIC;
           s_tdata : in STD_LOGIC_VECTOR (N-1 downto 0);
           s_tuser : in STD_LOGIC;
           s_tlast : in STD_LOGIC;
           m_tvalid : out STD_LOGIC;
           m_tdata : out STD_LOGIC_VECTOR (N-1 downto 0);
           m_tlast : out STD_LOGIC;
           clk : in STD_LOGIC);
    end component;
    
    constant zero_const : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    
    signal packetsize_sig : STD_LOGIC_VECTOR (C_S_AXI_DATA_WIDTH-1 downto 0);
    signal transfer_sig : STD_LOGIC_VECTOR (C_S_AXI_DATA_WIDTH-1 downto 0);
    
    signal pgen_re_tvalid_sig : STD_LOGIC;
    signal pgen_re_tdata_sig : STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
    signal pgen_re_tuser_sig : STD_LOGIC;
    signal pgen_re_tlast_sig : STD_LOGIC;
    signal pgen_im_tvalid_sig : STD_LOGIC;
    signal pgen_im_tdata_sig : STD_LOGIC_VECTOR (C_S_AXIS_DATA_WIDTH-1 downto 0);
    signal pgen_im_tuser_sig : STD_LOGIC;
    signal pgen_im_tlast_sig : STD_LOGIC;

begin

    AXI_LITE_CORE : S_AXI_Lite
        generic map (
            C_S_AXI_DATA_WIDTH	=> C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH	=> C_S_AXI_ADDR_WIDTH
        )
        port map (
            packetsize => packetsize_sig,
            transfer => transfer_sig,
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

    PGEN_RE : Packet_Generator 
        generic map (N => C_S_AXIS_DATA_WIDTH)
        port map (packetsize => packetsize_sig,
                  s_tvalid => s_axis_re_tvalid,
                  s_tdata => s_axis_re_tdata,
                  m_tvalid => pgen_re_tvalid_sig,
                  m_tdata => pgen_re_tdata_sig,
                  m_tuser => pgen_re_tuser_sig,
                  m_tlast => pgen_re_tlast_sig,
                  clk => aclk);
                  
    PGEN_IM : Packet_Generator 
        generic map (N => C_S_AXIS_DATA_WIDTH)
        port map (packetsize => packetsize_sig,
                  s_tvalid => s_axis_im_tvalid,
                  s_tdata => s_axis_im_tdata,
                  m_tvalid => pgen_im_tvalid_sig,
                  m_tdata => pgen_im_tdata_sig,
                  m_tuser => pgen_im_tuser_sig,
                  m_tlast => pgen_im_tlast_sig,
                  clk => aclk);
                  
    PINS_RE : Packet_Inspector
        generic map (N => C_S_AXIS_DATA_WIDTH)
        port map (transfer => transfer_sig(0),
                  s_tvalid => pgen_re_tvalid_sig,
                  s_tdata => pgen_re_tdata_sig,
                  s_tuser => pgen_re_tuser_sig,
                  s_tlast => pgen_re_tlast_sig,
                  m_tvalid => m_axis_re_tvalid,
                  m_tdata => m_axis_re_tdata,
                  m_tlast => m_axis_re_tlast,
                  clk => aclk);
                  
    PINS_IM : Packet_Inspector
        generic map (N => C_S_AXIS_DATA_WIDTH)
        port map (transfer => transfer_sig(0),
                  s_tvalid => pgen_im_tvalid_sig,
                  s_tdata => pgen_im_tdata_sig,
                  s_tuser => pgen_im_tuser_sig,
                  s_tlast => pgen_im_tlast_sig,
                  m_tvalid => m_axis_im_tvalid,
                  m_tdata => m_axis_im_tdata,
                  m_tlast => m_axis_im_tlast,
                  clk => aclk);
                  
     s_axis_re_tready <= m_axis_re_tready;
     s_axis_im_tready <= m_axis_im_tready;

end arch_imp;
