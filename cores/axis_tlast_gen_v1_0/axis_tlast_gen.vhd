library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_tlast_gen is
  generic (
  AXIS_TDATA_WIDTH : natural := 8;
  PKT_CNTR_BITS    : natural := 8 -- number of bits of the packet counter
);
port (
  -- System signals
  aclk          : in std_logic;
  aresetn       : in std_logic;

  -- Control signals
  pkt_length    : in std_logic_vector((PKT_CNTR_BITS-1) downto 0);

  -- Master side
  m_axis_tvalid : out std_logic;
  m_axis_tready : in std_logic;
  m_axis_tlast  : out std_logic;
  m_axis_tdata  : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tvalid : in std_logic;
  s_axis_tready : out std_logic;
  s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
);
end axis_tlast_gen;

architecture rtl of axis_tlast_gen is

  -- Internal signals
  signal new_sample  : std_logic;
  signal cnt         : std_logic_vector((PKT_CNTR_BITS-1) downto 0) := (others => '0');
  signal axis_tlast  : std_logic;
  signal axis_tready : std_logic;
begin

  -- Pass through control signals
  s_axis_tready <= m_axis_tready;
  m_axis_tvalid <= s_axis_tvalid;
  m_axis_tdata  <= s_axis_tdata;

  axis_tready <= m_axis_tready;
  -- Count samples
  new_sample <= s_axis_tvalid and axis_tready;

  process(aclk)
  begin
    if rising_edge(aclk) then 
      if (aresetn = '0' or (axis_tlast = '1' and new_sample = '1')) then
          cnt <= (others => '0');
      else
        if (new_sample = '1') then
          cnt <= std_logic_vector(unsigned(cnt) + 1);
        end if;
      end if;
    end if;
  end process;

  -- Generate tlast
  axis_tlast <= '1' when (unsigned(cnt) = unsigned(unsigned(pkt_length)-1)) else '0';
  m_axis_tlast <= axis_tlast;

end rtl;
