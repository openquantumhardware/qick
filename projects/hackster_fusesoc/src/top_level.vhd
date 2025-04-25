LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity top_level is
   port( 
      clk   : in     std_logic;
      reset : in     std_logic;
      rx    : in     std_logic;
      tx    : out    std_logic
   );

-- Declarations

end entity top_level ;

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use ieee.math_real.all;

architecture struct of top_level is

   -- Architecture declarations

   -- Internal signal declarations
   signal S_AXI_0_arready : STD_LOGIC;
   signal S_AXI_0_awready : STD_LOGIC;
   signal S_AXI_0_bresp   : STD_LOGIC_VECTOR( 1 downto 0 );
   signal S_AXI_0_bvalid  : STD_LOGIC;
   signal S_AXI_0_rdata   : STD_LOGIC_VECTOR( 31 downto 0 );
   signal S_AXI_0_rresp   : STD_LOGIC_VECTOR( 1 downto 0 );
   signal S_AXI_0_wready  : STD_LOGIC;
   signal S_AXI_0_wvalid  : STD_LOGIC;
   signal axi_araddr      : std_logic_vector(31 downto 0);
   signal axi_arprot      : std_logic_vector(2 downto 0);
   signal axi_arvalid     : std_logic;
   signal axi_awaddr      : std_logic_vector(31 downto 0);
   signal axi_awprot      : std_logic_vector(2 downto 0);
   signal axi_awvalid     : std_logic;
   signal axi_bready      : std_logic;
   signal axi_rready      : std_logic;
   signal axi_rvalid      : std_logic;
   signal axi_wdata       : std_logic_vector(31 downto 0);
   signal axi_wstrb       : std_logic_vector(3 downto 0);
   signal m_axis_tdata    : std_logic_vector(7 downto 0);
   signal m_axis_tready   : std_logic;
   signal m_axis_tvalid   : std_logic;
   signal s_axis_tdata    : std_logic_vector(7 downto 0);
   signal s_axis_tready   : std_logic;
   signal s_axis_tvalid   : std_logic;


   -- Component Declarations
   component axi_protocol
   generic (
      G_AXIL_DATA_WIDTH  : integer := 32;      --Width of AXI Lite data bus
      G_AXI_ADDR_WIDTH   : integer := 32;      --Width of AXI Lite Address Bu
      G_AXI_ID_WIDTH     : integer := 8;       --Width of AXI ID Bus
      G_AXI_AWUSER_WIDTH : integer := 1        --Width of AXI AW User bus
   );
   port (
      axi_arready   : in     std_logic;
      axi_awready   : in     std_logic;
      axi_bresp     : in     std_logic_vector (1 downto 0);
      axi_bvalid    : in     std_logic;
      axi_rdata     : in     std_logic_vector (31 downto 0);
      axi_rresp     : in     std_logic_vector (1 downto 0);
      axi_rvalid    : in     std_logic;
      axi_wready    : in     std_logic;
      clk           : in     std_ulogic;
      m_axis_tready : in     std_logic;
      reset         : in     std_ulogic;
      s_axis_tdata  : in     std_logic_vector (7 downto 0);
      s_axis_tvalid : in     std_logic;
      axi_araddr    : out    std_logic_vector (31 downto 0);
      axi_arprot    : out    std_logic_vector (2 downto 0);
      axi_arvalid   : out    std_logic;
      axi_awaddr    : out    std_logic_vector (31 downto 0);
      axi_awprot    : out    std_logic_vector (2 downto 0);
      axi_awvalid   : out    std_logic;
      axi_bready    : out    std_logic;
      axi_rready    : out    std_logic;
      axi_wdata     : out    std_logic_vector (31 downto 0);
      axi_wstrb     : out    std_logic_vector (3 downto 0);
      axi_wvalid    : out    std_logic;
      m_axis_tdata  : out    std_logic_vector (7 downto 0);
      m_axis_tvalid : out    std_logic;
      s_axis_tready : out    std_logic
   );
   end component axi_protocol;
   component design_1_wrapper
   port (
      S_AXI_0_araddr  : in     STD_LOGIC_VECTOR ( 11 downto 0 );
      S_AXI_0_arprot  : in     STD_LOGIC_VECTOR ( 2 downto 0 );
      S_AXI_0_arvalid : in     STD_LOGIC;
      S_AXI_0_awaddr  : in     STD_LOGIC_VECTOR ( 11 downto 0 );
      S_AXI_0_awprot  : in     STD_LOGIC_VECTOR ( 2 downto 0 );
      S_AXI_0_awvalid : in     STD_LOGIC;
      S_AXI_0_bready  : in     STD_LOGIC;
      S_AXI_0_rready  : in     STD_LOGIC;
      S_AXI_0_wdata   : in     STD_LOGIC_VECTOR ( 31 downto 0 );
      S_AXI_0_wstrb   : in     STD_LOGIC_VECTOR ( 3 downto 0 );
      S_AXI_0_wvalid  : in     STD_LOGIC;
      s_axi_aclk_0    : in     STD_LOGIC;
      s_axi_aresetn_0 : in     STD_LOGIC;
      S_AXI_0_arready : out    STD_LOGIC;
      S_AXI_0_awready : out    STD_LOGIC;
      S_AXI_0_bresp   : out    STD_LOGIC_VECTOR ( 1 downto 0 );
      S_AXI_0_bvalid  : out    STD_LOGIC;
      S_AXI_0_rdata   : out    STD_LOGIC_VECTOR ( 31 downto 0 );
      S_AXI_0_rresp   : out    STD_LOGIC_VECTOR ( 1 downto 0 );
      S_AXI_0_rvalid  : out    STD_LOGIC;
      S_AXI_0_wready  : out    STD_LOGIC
   );
   end component design_1_wrapper;
   component uart
   generic (
      reset_level : std_logic := '0';              -- reset level which causes a reset
      clk_freq    : natural   := 100_000_000;      -- oscillator frequency
      baud_rate   : natural   := 115200            -- baud rate
   );
   port (
      clk           : in     std_logic;
      m_axis_tready : in     std_logic;
      reset         : in     std_logic;
      rx            : in     std_logic;
      s_axis_tdata  : in     std_logic_vector (7 downto 0);
      s_axis_tvalid : in     std_logic;
      m_axis_tdata  : out    std_logic_vector (7 downto 0);
      m_axis_tvalid : out    std_logic;
      s_axis_tready : out    std_logic;
      tx            : out    std_logic
   );
   end component uart;

   -- Optional embedded configurations
   -- pragma synthesis_off
   for all : axi_protocol use entity src.axi_protocol;
   for all : design_1_wrapper use entity src.design_1_wrapper;
   for all : uart use entity src.uart;
   -- pragma synthesis_on


begin

   -- Instance port mappings.
   U_0 : axi_protocol
      generic map (
         G_AXIL_DATA_WIDTH  => 32,         --Width of AXI Lite data bus
         G_AXI_ADDR_WIDTH   => 32,         --Width of AXI Lite Address Bu
         G_AXI_ID_WIDTH     => 1,          --Width of AXI ID Bus
         G_AXI_AWUSER_WIDTH => 1           --Width of AXI AW User bus
      )
      port map (
         clk           => clk,
         reset         => reset,
         m_axis_tready => m_axis_tready,
         m_axis_tdata  => m_axis_tdata,
         m_axis_tvalid => m_axis_tvalid,
         s_axis_tready => s_axis_tready,
         s_axis_tdata  => s_axis_tdata,
         s_axis_tvalid => s_axis_tvalid,
         axi_awaddr    => axi_awaddr,
         axi_awprot    => axi_awprot,
         axi_awvalid   => axi_awvalid,
         axi_wdata     => axi_wdata,
         axi_wstrb     => axi_wstrb,
         axi_wvalid    => S_AXI_0_wvalid,
         axi_bready    => axi_bready,
         axi_araddr    => axi_araddr,
         axi_arprot    => axi_arprot,
         axi_arvalid   => axi_arvalid,
         axi_rready    => axi_rready,
         axi_awready   => S_AXI_0_wready,
         axi_wready    => S_AXI_0_awready,
         axi_bresp     => S_AXI_0_bresp,
         axi_bvalid    => S_AXI_0_bvalid,
         axi_arready   => S_AXI_0_arready,
         axi_rdata     => S_AXI_0_rdata,
         axi_rresp     => S_AXI_0_rresp,
         axi_rvalid    => axi_rvalid
      );
   U_1 : design_1_wrapper
      port map (
         S_AXI_0_araddr  => axi_araddr(11 downto 0),
         S_AXI_0_arprot  => axi_arprot,
         S_AXI_0_arready => S_AXI_0_arready,
         S_AXI_0_arvalid => axi_arvalid,
         S_AXI_0_awaddr  => axi_awaddr(11 downto 0),
         S_AXI_0_awprot  => axi_awprot,
         S_AXI_0_awready => S_AXI_0_awready,
         S_AXI_0_awvalid => axi_awvalid,
         S_AXI_0_bready  => axi_bready,
         S_AXI_0_bresp   => S_AXI_0_bresp,
         S_AXI_0_bvalid  => S_AXI_0_bvalid,
         S_AXI_0_rdata   => S_AXI_0_rdata,
         S_AXI_0_rready  => axi_rready,
         S_AXI_0_rresp   => S_AXI_0_rresp,
         S_AXI_0_rvalid  => axi_rvalid,
         S_AXI_0_wdata   => axi_wdata,
         S_AXI_0_wready  => S_AXI_0_wready,
         S_AXI_0_wstrb   => axi_wstrb,
         S_AXI_0_wvalid  => S_AXI_0_wvalid,
         s_axi_aclk_0    => clk,
         s_axi_aresetn_0 => reset
      );
   U_2 : uart
      generic map (
         reset_level => '0',                 -- reset level which causes a reset
         clk_freq    => 100_000_000,         -- oscillator frequency
         baud_rate   => 115200               -- baud rate
      )
      port map (
         clk           => clk,
         reset         => reset,
         rx            => rx,
         tx            => tx,
         m_axis_tready => s_axis_tready,
         m_axis_tdata  => s_axis_tdata,
         m_axis_tvalid => s_axis_tvalid,
         s_axis_tready => m_axis_tready,
         s_axis_tdata  => m_axis_tdata,
         s_axis_tvalid => m_axis_tvalid
      );

end architecture struct;
