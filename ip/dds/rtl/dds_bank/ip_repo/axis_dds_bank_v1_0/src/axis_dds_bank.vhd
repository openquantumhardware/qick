----------------------------------------------------------------------------------
-- Company: Falco Processing
-- Engineer: L. H. Arnaldi
--
-- Create Date: 11/11/2022 12:10:07 PM
-- Design Name:
-- Module Name: dds_bank
-- Project Name: RPA channelizer
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity dds_bank is
  generic (
    NCH              : natural := 2; --number of channels
    AXIS_TDATA_WIDTH : natural := 16
  );
  port (
    aclk                : in std_logic;
    aresetn             : in std_logic;
    s_axis_phase_tvalid : in std_logic;
    s_axis_phase_tdata  : in std_logic_vector(NCH * 2 * AXIS_TDATA_WIDTH - 1 downto 0);
    s_axis_data_tvalid  : in std_logic;
    s_axis_data_tdata   : in std_logic_vector(2 * AXIS_TDATA_WIDTH - 1 downto 0);
    m_axis_data_tvalid  : out std_logic;
    m_axis_data_tdata   : out std_logic_vector(NCH * 2 * AXIS_TDATA_WIDTH - 1 downto 0)
  );
end dds_bank;

architecture rtl of dds_bank is

  function clogb2 (value : natural) return natural is
    variable temp : natural := value;
    variable ret_val : natural := 1;
  begin
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp := temp / 2;
    end loop;
    return ret_val;
  end function;

  constant C_ADDR_SIZE : natural := clogb2(NCH); --counter addr_size
  constant M_ADDR_SIZE : natural := clogb2(2 * NCH); --memory addr_size

  -- DDS Compiler
  component dds
    port (
      aclk                : in std_logic;
      aresetn             : in std_logic;
      s_axis_phase_tvalid : in std_logic;
      s_axis_phase_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH - 1 downto 0); --Se cambio la fase a 16 bits
      m_axis_data_tvalid  : out std_logic;
      m_axis_data_tdata   : out std_logic_vector(2 * AXIS_TDATA_WIDTH - 1 downto 0)
    );
  end component;

  -- DDS Compiler
  component complex_multiplier
    port (
      aclk               : in std_logic;
      aresetn            : in std_logic;
      s_axis_a_tvalid    : in std_logic;
      s_axis_a_tdata     : in std_logic_vector(31 downto 0);
      s_axis_b_tvalid    : in std_logic;
      s_axis_b_tdata     : in std_logic_vector(31 downto 0);
      m_axis_dout_tvalid : out std_logic;
      m_axis_dout_tdata  : out std_logic_vector(31 downto 0)
    );
  end component;
  type in_array_t is array (NCH - 1 downto 0) of std_logic_vector(AXIS_TDATA_WIDTH - 1 downto 0);
  signal v_in_sig : in_array_t;

  type out_array_t is array (NCH - 1 downto 0) of std_logic_vector(2 * AXIS_TDATA_WIDTH - 1 downto 0);
  signal v_out_sig : out_array_t;
  signal m_out_sig : out_array_t;

  signal axis_dds_tvalid : std_logic_vector(NCH - 1 downto 0) := (others => '0');
  signal axis_mulc_tvalid : std_logic_vector(NCH - 1 downto 0) := (others => '0');

begin

  -- Input
  IN_GEN : for i in 0 to NCH - 1 generate
    v_in_sig(i) <= s_axis_phase_tdata((i + 1) * AXIS_TDATA_WIDTH - 1 downto i * 2 * AXIS_TDATA_WIDTH);
  end generate;

  DDS_GEN : for j in 0 to NCH - 1 generate
    DDS_inst : dds port map(
      aclk                => aclk,
      aresetn             => aresetn,
      s_axis_phase_tvalid => s_axis_phase_tvalid,
      s_axis_phase_tdata  => v_in_sig(j),
      m_axis_data_tvalid  => axis_dds_tvalid(j),
      m_axis_data_tdata   => v_out_sig(j)
    );
    COMPLEX_MULTIPLIER_inst : complex_multiplier port map(
      aclk               => aclk,
      aresetn            => aresetn,
      s_axis_a_tvalid    => axis_dds_tvalid(j),
      s_axis_a_tdata     => v_out_sig(j),
      s_axis_b_tvalid    => s_axis_data_tvalid,
      s_axis_b_tdata     => s_axis_data_tdata,
      m_axis_dout_tvalid => axis_mulc_tvalid(j),
      m_axis_dout_tdata  => m_out_sig(j)
    );
  end generate;

  OUT_GEN : for i in 0 to NCH - 1 generate
    m_axis_data_tdata(i * 2 * AXIS_TDATA_WIDTH + 2 * AXIS_TDATA_WIDTH - 1 downto i * 2 * AXIS_TDATA_WIDTH) <= m_out_sig(i);
  end generate;

  m_axis_data_tvalid <= and_reduce(axis_mulc_tvalid);

end rtl;
