library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity packet_control is
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
end packet_control;

architecture arch of packet_control is

component tuser_sync is
  Port ( clk : in std_logic;
         resetn : in std_logic;
         reset : in std_logic;
         enable : in std_logic;
         latch : out std_logic
         );
end component tuser_sync;

component tlast_generation is
  Port (clk : in std_logic;
        resetn : in std_logic;
        packet_size : in std_logic_vector(31 downto 0);
        valid : in std_logic;
        reset : in std_logic;
        tlast : out std_logic
        );
end component tlast_generation;

component d_type is
  Port (d : in std_logic;
        q : out std_logic;
        clk : in std_logic;
        resetn : in std_logic
        );
end component d_type;

component rising_edge_detector is
  Port (clk : in std_logic;
        resetn : in std_logic;
        data_in : in std_logic;
        data_out : out std_logic
        );
end component rising_edge_detector;

component fifo_generator_0
  Port (
    clk : IN STD_LOGIC;
    srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
end component fifo_generator_0;

signal sig_invert_reset : std_logic;
signal sig_read_enable : std_logic;
signal sig_full : std_logic;
signal sig_empty : std_logic;
signal sig_not_empty : std_logic;
signal sig_not_empty_ready : std_logic;
signal sig_rising_edge : std_logic;
signal sig_latch : std_logic;
signal sig_tlast_out : std_logic;
signal sig_read_fifo_ready : std_logic;
signal sig_pop_fifo : std_logic;

begin

fifo_inst : fifo_generator_0
  PORT MAP (
    clk => aclk,
    srst => packet_reset(0),
    din => s_axis_tdata,
    wr_en => s_axis_tvalid,
    rd_en => sig_pop_fifo,
    dout => m_axis_tdata,
    full => sig_full,
    empty => sig_empty,
    wr_rst_busy => open,
    rd_rst_busy => open
  );
  
rising_edge_inst : rising_edge_detector
  PORT MAP (
    clk => aclk,
    resetn => aresetn,
    data_in => packet_enable(0),
    data_out => sig_rising_edge
  );
  
tuser_sync_inst : tuser_sync
  PORT MAP (
    clk => aclk,
    resetn => aresetn,
    reset => sig_tlast_out,
    enable => sig_rising_edge,
    latch => sig_latch
  );
  
tlast_generation_inst : tlast_generation
  PORT MAP (
    clk => aclk,
    resetn => aresetn,
    packet_size => packet_size,
    valid => sig_read_fifo_ready,
    reset => packet_reset(0),
    tlast => sig_tlast_out
  );
  
d_type_inst : d_type
  PORT MAP (
    clk => aclk,
    resetn => aresetn,
    d => sig_read_fifo_ready,
    q => m_axis_tvalid
  );
  
sig_invert_reset <= not aresetn;
m_axis_tlast <= sig_tlast_out;
sig_pop_fifo <= sig_read_fifo_ready or sig_full;
sig_not_empty <= not sig_empty;
sig_not_empty_ready <= sig_not_empty and m_axis_tready;
sig_read_fifo_ready <= sig_latch and sig_not_empty_ready;

end arch;
