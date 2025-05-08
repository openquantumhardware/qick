library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.adiuvo_uart.all;

entity uart is generic (
  reset_level : std_logic := '0'; -- reset level which causes a reset
  clk_freq    : natural   := 100_000_000; -- oscillator frequency
  baud_rate   : natural   := 115200 -- baud rate 
);
port (
  --!System Inputs 
  clk   : in std_logic;
  reset : in std_logic;

  --!External Interfaces
  rx : in std_logic;
  tx  : out std_logic;

  --! Master AXIS Interface  
  m_axis_tready : in  std_logic;
  m_axis_tdata  : out std_logic_vector(7 downto 0);
  m_axis_tvalid : out std_logic;

  --! Slave AXIS Interface
  s_axis_tready : out  std_logic;
  s_axis_tdata  : in std_logic_vector(7 downto 0);
  s_axis_tvalid : in std_logic
  
  );
  
end entity;
architecture rtl of uart is

  constant bit_period : integer := (clk_freq/baud_rate) - 1;
  

  type cntrl_fsm is (idle, set_tx,wait_tx);
  type rx_fsm is (idle, start, sample, check, wait_axis);

  signal current_state : cntrl_fsm; --:= idle;
  signal rx_state      : rx_fsm;-- := idle;
  signal baud_counter  : unsigned(vector_size(real(clk_freq), real(baud_rate)) downto 0) := (others => '0'); --timer for outgoing signals 
  signal baud_en       : std_logic                                                       := '0';
  signal meta_reg      : std_logic_vector(3 downto 0)                                    := (others => '0'); -- fe detection too
  signal capture       : std_logic_vector(7 downto 0)                                    := (others => '0'); -- data and parity
  signal bit_count     : integer range 0 to 1023                                         := 0;
  signal pos_count     : integer range 0 to 15                                           := 0;
  signal running       : std_logic                                                       := '0';
  signal load_tx  : std_logic := '0';
  signal complete : std_logic := '0';

  signal tx_reg  : std_logic_vector(11 downto 0) := (others => '0');
  signal tmr_reg : std_logic_vector(11 downto 0) := (others => '0');
  signal payload : std_logic_vector(7 downto 0)  := (others => '0');
  constant zero  : std_logic_vector(tmr_reg'range) := (others => '0');
begin

  process (reset, clk)
  begin
    if reset = reset_level then
      current_state <= idle;
      payload       <= (others => '0');
      load_tx <= '0';
    elsif rising_edge(clk) then
      load_tx <= '0';
      case current_state is
        when idle =>
          if s_axis_tvalid = '1' then
            current_state <= set_tx;
            load_tx       <= '1';
            payload       <= s_axis_tdata;
          end if;
        when set_tx =>
          current_state <= wait_tx;
        when wait_tx =>
          if complete = '1' then
            current_state <= idle;
          end if;
        when others => 
         current_state <= idle;
      end case;
    end if;
  end process;

  s_axis_tready <= '1' when (current_state = idle) else '0';

  process (reset, clk)
  --! baud counter for output TX 
  begin
    if reset = reset_level then
      baud_counter <= (others => '0');
      baud_en      <= '0';
    elsif rising_edge(clk) then
      baud_en <= '0';
      if (load_tx = '1') then
        baud_counter <= (others => '0');
      elsif (baud_counter = bit_period) then
        baud_en      <= '1';
        baud_counter <= (others => '0');
      else
        baud_counter <= baud_counter + 1;
      end if;
    end if;
  end process;

  process (reset, clk)
  --!metastability protection rx signal
  begin
    if reset = reset_level then
      meta_reg <= (others => '1');
    elsif rising_edge(clk) then
      meta_reg <= meta_reg(meta_reg'high - 1 downto meta_reg'low) & rx;
    end if;
  end process;

  process (reset, clk)
  begin
    if reset = reset_level then
      pos_count <= 0;
      bit_count <= 0;
      capture     <= (others => '0');
      rx_state    <= idle;
      m_axis_tvalid <= '0';
      m_axis_tdata     <= (others => '0');
      
    elsif rising_edge(clk) then
      case rx_state is
 
        when idle =>
          m_axis_tvalid  <= '0';
          if meta_reg(meta_reg'high downto meta_reg'high - 1) = fe_det then 
            pos_count <= 0;
            bit_count <= 0;
            capture  <= (others => '0');
            rx_state <= start;
          end if;
        when start =>
          if bit_count = bit_period then
            bit_count <= 0;
            rx_state  <= sample;
          else
            bit_count <= bit_count + 1;
          end if;
        when sample =>
          bit_count <= bit_count + 1;
          rx_state  <= sample;
          if bit_count = (bit_period/2) and (pos_count < 8) then 
            capture <= meta_reg(meta_reg'high) & capture(capture'high downto capture'low + 1);
          elsif bit_count = bit_period then
            if pos_count = 8 then 
              rx_state <= check;
            else
              pos_count <= pos_count + 1;
              bit_count <= 0;
            end if;
          end if;
        when check =>
          if parity(capture) = '1' then
            m_axis_tvalid <= '1';
            m_axis_tdata  <= capture(7 downto 0);
            rx_state      <= wait_axis;
          else
            m_axis_tvalid <= '1';
            m_axis_tdata  <= capture(7 downto 0);
            rx_state      <= wait_axis;
          end if;
        when wait_axis =>
          if m_axis_tready = '1' then 
            m_axis_tvalid <= '0';
            rx_state      <= idle;    
          end if;
      end case;
    end if;
  end process;

  op_uart : process (reset, clk)
  begin
    if reset = reset_level then
      tx_reg  <= (others => '1');
      tmr_reg <= (others => '0');
    elsif rising_edge(clk) then
      if load_tx = '1' then
        tx_reg  <= stop_bit & not(parity(payload)) & payload & start_bit ;
        tmr_reg <= (others => '1');
      elsif baud_en = '1' then
        tx_reg  <= '1' & tx_reg(tx_reg'high downto tx_reg'low + 1);
        tmr_reg <= tmr_reg(tmr_reg'high - 1 downto tmr_reg'low) & '0';
      end if;
    end if;
  end process;

  tx       <= tx_reg(tx_reg'low);
  complete <= '1' when (tmr_reg = zero and current_state = wait_tx) else '0';
end architecture;