--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
--Date        : Tue Nov  5 21:21:44 2024
--Host        : Laptop-Adam running 64-bit major release  (build 9200)
--Command     : generate_target design_1_wrapper.bd
--Design      : design_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity design_1_wrapper is
  port (
    S_AXI_0_araddr : in STD_LOGIC_VECTOR ( 11 downto 0 );
    S_AXI_0_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_0_arready : out STD_LOGIC;
    S_AXI_0_arvalid : in STD_LOGIC;
    S_AXI_0_awaddr : in STD_LOGIC_VECTOR ( 11 downto 0 );
    S_AXI_0_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_0_awready : out STD_LOGIC;
    S_AXI_0_awvalid : in STD_LOGIC;
    S_AXI_0_bready : in STD_LOGIC;
    S_AXI_0_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_0_bvalid : out STD_LOGIC;
    S_AXI_0_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_0_rready : in STD_LOGIC;
    S_AXI_0_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_0_rvalid : out STD_LOGIC;
    S_AXI_0_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_0_wready : out STD_LOGIC;
    S_AXI_0_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_0_wvalid : in STD_LOGIC;
    s_axi_aclk_0 : in STD_LOGIC;
    s_axi_aresetn_0 : in STD_LOGIC
  );
end design_1_wrapper;

architecture STRUCTURE of design_1_wrapper is
  component design_1 is
  port (
    S_AXI_0_araddr : in STD_LOGIC_VECTOR ( 11 downto 0 );
    S_AXI_0_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_0_arready : out STD_LOGIC;
    S_AXI_0_arvalid : in STD_LOGIC;
    S_AXI_0_awaddr : in STD_LOGIC_VECTOR ( 11 downto 0 );
    S_AXI_0_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_0_awready : out STD_LOGIC;
    S_AXI_0_awvalid : in STD_LOGIC;
    S_AXI_0_bready : in STD_LOGIC;
    S_AXI_0_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_0_bvalid : out STD_LOGIC;
    S_AXI_0_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_0_rready : in STD_LOGIC;
    S_AXI_0_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_0_rvalid : out STD_LOGIC;
    S_AXI_0_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_0_wready : out STD_LOGIC;
    S_AXI_0_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_0_wvalid : in STD_LOGIC;
    s_axi_aclk_0 : in STD_LOGIC;
    s_axi_aresetn_0 : in STD_LOGIC
  );
  end component design_1;
begin
design_1_i: component design_1
     port map (
      S_AXI_0_araddr(11 downto 0) => S_AXI_0_araddr(11 downto 0),
      S_AXI_0_arprot(2 downto 0) => S_AXI_0_arprot(2 downto 0),
      S_AXI_0_arready => S_AXI_0_arready,
      S_AXI_0_arvalid => S_AXI_0_arvalid,
      S_AXI_0_awaddr(11 downto 0) => S_AXI_0_awaddr(11 downto 0),
      S_AXI_0_awprot(2 downto 0) => S_AXI_0_awprot(2 downto 0),
      S_AXI_0_awready => S_AXI_0_awready,
      S_AXI_0_awvalid => S_AXI_0_awvalid,
      S_AXI_0_bready => S_AXI_0_bready,
      S_AXI_0_bresp(1 downto 0) => S_AXI_0_bresp(1 downto 0),
      S_AXI_0_bvalid => S_AXI_0_bvalid,
      S_AXI_0_rdata(31 downto 0) => S_AXI_0_rdata(31 downto 0),
      S_AXI_0_rready => S_AXI_0_rready,
      S_AXI_0_rresp(1 downto 0) => S_AXI_0_rresp(1 downto 0),
      S_AXI_0_rvalid => S_AXI_0_rvalid,
      S_AXI_0_wdata(31 downto 0) => S_AXI_0_wdata(31 downto 0),
      S_AXI_0_wready => S_AXI_0_wready,
      S_AXI_0_wstrb(3 downto 0) => S_AXI_0_wstrb(3 downto 0),
      S_AXI_0_wvalid => S_AXI_0_wvalid,
      s_axi_aclk_0 => s_axi_aclk_0,
      s_axi_aresetn_0 => s_axi_aresetn_0
    );
end STRUCTURE;
