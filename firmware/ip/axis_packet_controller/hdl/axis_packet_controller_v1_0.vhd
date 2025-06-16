library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_packet_controller_v1_0 is
	generic (
		C_S_AXI_Lite_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_Lite_ADDR_WIDTH	: integer	:= 4
	);
	port (
		aclk	: in std_logic;
		aresetn	: in std_logic;
		s_axi_lite_awaddr	: in std_logic_vector(C_S_AXI_Lite_ADDR_WIDTH-1 downto 0);
		s_axi_lite_awprot	: in std_logic_vector(2 downto 0);
		s_axi_lite_awvalid	: in std_logic;
		s_axi_lite_awready	: out std_logic;
		s_axi_lite_wdata	: in std_logic_vector(C_S_AXI_Lite_DATA_WIDTH-1 downto 0);
		s_axi_lite_wstrb	: in std_logic_vector((C_S_AXI_Lite_DATA_WIDTH/8)-1 downto 0);
		s_axi_lite_wvalid	: in std_logic;
		s_axi_lite_wready	: out std_logic;
		s_axi_lite_bresp	: out std_logic_vector(1 downto 0);
		s_axi_lite_bvalid	: out std_logic;
		s_axi_lite_bready	: in std_logic;
		s_axi_lite_araddr	: in std_logic_vector(C_S_AXI_Lite_ADDR_WIDTH-1 downto 0);
		s_axi_lite_arprot	: in std_logic_vector(2 downto 0);
		s_axi_lite_arvalid	: in std_logic;
		s_axi_lite_arready	: out std_logic;
		s_axi_lite_rdata	: out std_logic_vector(C_S_AXI_Lite_DATA_WIDTH-1 downto 0);
		s_axi_lite_rresp	: out std_logic_vector(1 downto 0);
		s_axi_lite_rvalid	: out std_logic;
		s_axi_lite_rready	: in std_logic;

		-- Ports of Axi Slave Bus Interface S_AXIS
		s_axis_tdata	: in std_logic_vector(31 downto 0);
		s_axis_tvalid	: in std_logic;

		-- Ports of Axi Master Bus Interface M_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(31 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end axis_packet_controller_v1_0;

architecture arch_imp of axis_packet_controller_v1_0 is

	-- component declaration
	component s_axi_lite is
		generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
		);
		port (
		packet_size : out std_logic_vector(31 downto 0);
		packet_enable : out std_logic_vector(31 downto 0);
		packet_reset : out std_logic_vector(31 downto 0);
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
	end component s_axi_lite;
	
	component packet_control is
       Port (aclk : in std_logic;
            aresetn : in std_logic;
            packet_size : in std_logic_vector(31 downto 0);
            packet_enable : in std_logic_vector(31 downto 0);
            packet_reset : in std_logic_vector(31 downto 0);
            s_axis_tdata : in std_logic_vector(31 downto 0);
            s_axis_tvalid : in std_logic;
            m_axis_tdata : out std_logic_vector(31 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tlast : out std_logic;
            m_axis_tready : in std_logic
            );
    end component packet_control;

signal sig_packet_size : std_logic_vector(31 downto 0);
signal sig_packet_enable : std_logic_vector(31 downto 0);
signal sig_packet_reset : std_logic_vector(31 downto 0);

begin

-- Instantiation of Axi Bus Interface S_AXI_Lite
s_axi_lite_inst : s_axi_lite
	generic map (
		C_S_AXI_DATA_WIDTH	=> C_S_AXI_Lite_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S_AXI_Lite_ADDR_WIDTH
	)
	port map (
	    packet_size => sig_packet_size,
	    packet_enable => sig_packet_enable,
	    packet_reset => sig_packet_reset,
		S_AXI_ACLK	=> aclk,
		S_AXI_ARESETN	=> aresetn,
		S_AXI_AWADDR	=> s_axi_lite_awaddr,
		S_AXI_AWPROT	=> s_axi_lite_awprot,
		S_AXI_AWVALID	=> s_axi_lite_awvalid,
		S_AXI_AWREADY	=> s_axi_lite_awready,
		S_AXI_WDATA	=> s_axi_lite_wdata,
		S_AXI_WSTRB	=> s_axi_lite_wstrb,
		S_AXI_WVALID	=> s_axi_lite_wvalid,
		S_AXI_WREADY	=> s_axi_lite_wready,
		S_AXI_BRESP	=> s_axi_lite_bresp,
		S_AXI_BVALID	=> s_axi_lite_bvalid,
		S_AXI_BREADY	=> s_axi_lite_bready,
		S_AXI_ARADDR	=> s_axi_lite_araddr,
		S_AXI_ARPROT	=> s_axi_lite_arprot,
		S_AXI_ARVALID	=> s_axi_lite_arvalid,
		S_AXI_ARREADY	=> s_axi_lite_arready,
		S_AXI_RDATA	=> s_axi_lite_rdata,
		S_AXI_RRESP	=> s_axi_lite_rresp,
		S_AXI_RVALID	=> s_axi_lite_rvalid,
		S_AXI_RREADY	=> s_axi_lite_rready
	);
	
packet_control_inst : packet_control
    port map(
        aclk => aclk,
        aresetn => aresetn,
        packet_size => sig_packet_size,
        packet_enable => sig_packet_enable,
        packet_reset => sig_packet_reset,
        s_axis_tdata => s_axis_tdata,
        s_axis_tvalid => s_axis_tvalid,
        m_axis_tdata => m_axis_tdata,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tlast => m_axis_tlast,
        m_axis_tready => m_axis_tready
    );

end arch_imp;
