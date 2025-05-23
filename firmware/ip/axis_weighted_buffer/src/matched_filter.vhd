-------------------------------------------------------------------------------
-- Title : Matched Filter Time-Domain Multiplier
-- Project :
-------------------------------------------------------------------------------
-- File : matched_filter.vhd
-- Author : <javierc@correlator6.fnal.gov>
-- Company :
-- Created : 2025-02-27
-- Last update: 2025-03-03
-- Platform :
-- Standard : VHDL'08
-------------------------------------------------------------------------------
-- Description: Stores filter envelope and processes DSP
-- Inputs are single precision (B), outputs double (2*B)
-------------------------------------------------------------------------------
-- Copyright (c) 2025
-------------------------------------------------------------------------------
-- Revisions :
-- Date Version Author Description
-- 2025-02-27 1.0 javierc Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity matched_filter is
  generic (
    B : natural := 16;
    N : natural := 10
    );
  port (
    -- clock+reset for readout data path
    clk  : in std_logic;

    -- clock+reset for writing weights
    write_rstn : in std_logic;
    write_clk  : in std_logic;

    trigger_i : in  std_logic;
    trigger_o : out std_logic;

    -- AXIS programming interface from DMA
    s_axis_tready : out std_logic;
    s_axis_tdata  : in  std_logic_vector(2*B-1 downto 0);
    s_axis_tvalid : in  std_logic;

    -- Input and output readout streams
    din_valid_i  : in  std_logic;
    din_i        : in  std_logic_vector(2*B-1 downto 0);
    dout_o       : out std_logic_vector(2*B-1 downto 0);
    dout_valid_o : out std_logic;

    -- Configuration registers
    -- active length of the weights buffer (how many samples of incoming data will be weighted)
    LEN_REG        : in std_logic_vector (31 downto 0);
    -- data writer start address and write-enable
    DW_ADDR_REG    : in std_logic_vector(31 downto 0);
    WE_REG         : in std_logic
    );
end matched_filter;

architecture rtl of matched_filter is
  signal mem_envelope_wea, mem_envelope_ena     : std_logic := '0';
  signal mem_envelope_addra                     : std_logic_vector(N-1 downto 0);
  signal mem_envelope_addrb                     : std_logic_vector(31 downto 0);
  signal mem_envelope_dia                       : std_logic_vector(2*B-1 downto 0);
  signal envelope_iq                            : std_logic_vector(2*B-1 downto 0);
  signal envelope_ii, envelope_qq               : std_logic_vector (B-1 downto 0);

  signal ac, bd, ad, bc                             : std_logic_vector(47 downto 0);
  signal ac_signed, bd_signed, ad_signed, bc_signed : signed(2*B-1 downto 0);

  signal din_ii, din_qq                   : std_logic_vector(B-1 downto 0);
  signal filt_ii, filt_qq                 : std_logic_vector(2*B-1 downto 0);
  signal filt_ii_quant, filt_qq_quant     : std_logic_vector(B-1 downto 0);
  signal filt_ii_quant_r, filt_qq_quant_r : std_logic_vector(B-1 downto 0);

  -- Higher precision
  signal dfiltered_ii, dfiltered_qq : std_logic_vector (2*N-1 downto 0);

  -- Compensate memory latency for data
  constant WGT_LATENCY  : natural := 3;
  -- Compensate DSP latency for trigger & valid
  constant DSP_LATENCY  : natural := 3;
  
  type reg_t is array (WGT_LATENCY-1 downto 0) of std_logic_vector (2*B-1 downto 0);
  signal din_reg        : reg_t;
  
  signal trigger_reg    : std_logic_vector(0 to WGT_LATENCY+DSP_LATENCY-1);
  signal dout_valid_reg : std_logic_vector(0 to WGT_LATENCY+DSP_LATENCY-1);

  -- Read address
  signal cnt       : unsigned (31 downto 0) := to_unsigned(0, 32);
  signal length    : unsigned (31 downto 0) := to_unsigned(0, 32);

  type fsm_state is (INIT_ST,
                     WAIT_ST,
                     READ_ST);
  signal state : fsm_state;

  component dsp_macro_0
    port (
      CLK : in  std_logic;
      CE  : in  std_logic;
      A   : in  std_logic_vector(B-1 downto 0);
      B   : in  std_logic_vector(B-1 downto 0);
      C   : in  std_logic_vector(47 downto 0);
      P   : out std_logic_vector(47 downto 0)
      );
  end component;
begin

  data_writer_i : entity work.data_writer
    generic map (
      NT => 1,
      N  => N,
      B  => 2*B)
    port map (
      rstn           => write_rstn,
      clk            => write_clk,
      s_axis_tready  => s_axis_tready,
      s_axis_tdata   => s_axis_tdata,
      s_axis_tvalid  => s_axis_tvalid,
      mem_en(0)      => mem_envelope_ena,
      mem_we         => mem_envelope_wea,
      mem_addr       => mem_envelope_addra,
      mem_di         => mem_envelope_dia,
      START_ADDR_REG => DW_ADDR_REG,
      WE_REG         => WE_REG);

  bram_envelope_iq : entity work.bram_dp
    generic map (
      N => N,
      B => 2*B)
    port map (
      clka  => write_clk,
      clkb  => clk,
      ena   => '1',
      enb   => '1',
      wea   => mem_envelope_wea,
      web   => '0',
      addra => mem_envelope_addra,
      addrb => mem_envelope_addrb(N-1 downto 0),
      dia   => mem_envelope_dia,
      dib   => (others => '0'),
      doa   => open,
      dob   => envelope_iq);


  matched_filter_mult_ac : dsp_macro_0
    port map (
      CLK => clk,
      CE  => '1',
      A   => din_ii,
      B   => envelope_ii,
      C   => (others => '0'),
      P   => ac
      );

  matched_filter_mult_bd : dsp_macro_0
    port map (
      CLK => clk,
      CE  => '1',
      A   => din_qq,
      B   => envelope_qq,
      C   => (others => '0'),
      P   => bd
      );

  matched_filter_mult_ad : dsp_macro_0
    port map (
      CLK => clk,
      CE  => '1',
      A   => din_ii,
      B   => envelope_qq,
      C   => (others => '0'),
      P   => ad
      );

  matched_filter_mult_bc : dsp_macro_0
    port map (
      CLK => clk,
      CE  => '1',
      A   => din_qq,
      B   => envelope_ii,
      C   => (others => '0'),
      P   => bc
      );

  latency_compensation : process (clk) is
    variable i : integer;
  begin
    if (rising_edge(clk)) then
      din_reg(0)        <= din_i;
      trigger_reg(0)    <= trigger_i;
      dout_valid_reg(0) <= din_valid_i;
      for i in 1 to WGT_LATENCY-1 loop
        din_reg(i)        <= din_reg(i-1);
      end loop;
      for i in 1 to WGT_LATENCY+DSP_LATENCY-1 loop
        trigger_reg(i)    <= trigger_reg(i-1);
        dout_valid_reg(i) <= dout_valid_reg(i-1);
      end loop;
    end if;
  end process;

  proc_read_addr : process(clk) is
  begin
    if (rising_edge(clk)) then
      if (state = READ_ST) then
        if (din_valid_i = '1') then
          cnt       <= cnt + 1;
        end if;
      else
        cnt       <= to_unsigned(0, 32);
      end if;
    end if;
  end process;

  proc_state : process (clk) is
  begin
    if (rising_edge(clk)) then
      case state is
        when INIT_ST =>
          state <= WAIT_ST;
        when WAIT_ST =>
          if (trigger_i = '1') then
            state <= READ_ST;
          end if;

        when READ_ST =>
          if (cnt > length) then
            state <= INIT_ST;
          end if;
      end case;
    end if;
  end process;

  reg_output : process(clk) is
  begin
    if (rising_edge(clk)) then
      filt_ii_quant_r <= filt_ii_quant;
      filt_qq_quant_r <= filt_qq_quant;
    end if;
  end process;

  din_ii <= din_reg(WGT_LATENCY-1)(2*B-1 downto B);
  din_qq <= din_reg(WGT_LATENCY-1)(B-1 downto 0);

  trigger_o    <= trigger_reg(WGT_LATENCY+DSP_LATENCY - 1);
  dout_valid_o <= dout_valid_reg(WGT_LATENCY+DSP_LATENCY - 1);

  mem_envelope_addrb <= std_logic_vector(cnt);
  envelope_ii <= envelope_iq(2*B-1 downto B);
  envelope_qq <= envelope_iq(B-1 downto 0);


  ac_signed <= signed(ac(2*B-1 downto 0));
  bd_signed <= signed(bd(2*B-1 downto 0));
  ad_signed <= signed(ad(2*B-1 downto 0));
  bc_signed <= signed(bc(2*B-1 downto 0));

  filt_ii <= std_logic_vector(ac_signed - bd_signed);
  filt_qq <= std_logic_vector(ad_signed + bc_signed);

  -- Keep only MSBs
  filt_ii_quant <= filt_ii(2*B-1 downto B);
  filt_qq_quant <= filt_qq(2*B-1 downto B);

  dout_o(2*B-1 downto B) <= filt_ii_quant_r;
  dout_o(B-1 downto 0)   <= filt_qq_quant_r;

  length <= unsigned(LEN_REG);


end rtl;
