library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_reader is
   Generic
   (
      -- Address map of memory.
      N           : Integer := 8;
      -- Data width.
      B           : Integer := 16
   );
   Port
   (
      -- Reset and clock.
      rstn              : in std_logic;
      clk               : in std_logic;

      -- Memory I/F.
      mem_en            : out std_logic;
      mem_we            : out std_logic;
      mem_addr          : out std_logic_vector (N-1 downto 0);
      mem_dout          : in std_logic_vector (B-1 downto 0);

      -- Data out.
      dout              : out std_logic_vector (B-1 downto 0);
      dready            : in std_logic;
      dvalid            : out std_logic;
      dlast             : out std_logic;

      -- Registers.
      START_REG         : in std_logic;
      ADDR_REG          : in std_logic_vector (N-1 downto 0);
      LEN_REG           : in std_logic_vector (N-1 downto 0)
   );
end entity;

architecture rtl of data_reader is

constant NPOW       : Integer := 2**N;

-- Fifo to drive AXI Stream Master I/F.
component fifo_axi is
   Generic
   (
      -- Data width.
      B : Integer := 16;

      -- Fifo depth.
      N : Integer := 4
   );
   Port
   (
      rstn  : in std_logic;
      clk   : in std_logic;

      -- Write I/F.
      wr_en    : in std_logic;
      din      : in std_logic_vector (B-1 downto 0);

      -- Read I/F.
      rd_en    : in std_logic;
      dout     : out std_logic_vector (B-1 downto 0);

      -- Flags.
      full    : out std_logic;
      empty   : out std_logic
   );
end component;

type fsm_state is (  INIT_ST,
                     REGS_ST,
                     READ_BRAM_ST,
                     WRITE_FIFO_ST,
                     READ_LAST_ST,
                     WRITE_LAST_ST,
                     FIFO_ST,
                     END_ST);
signal current_state, next_state : fsm_state;

signal init_state   : std_logic;
signal regs_state   : std_logic;
signal read_state   : std_logic;
signal write_state  : std_logic;
signal fifo_state   : std_logic;
signal read_en      : std_logic;

-- Counter for memory address and samples.
signal cnt_wr     : unsigned(N-1 downto 0);
signal cnt_rd     : unsigned(N-1 downto 0);
signal addr_cnt   : unsigned(N-1 downto 0);

-- Length register.
signal len_r      : unsigned(N-1 downto 0);

-- Fifo signals.
signal fifo_wr_en   : std_logic;
signal fifo_rd_en   : std_logic;
signal fifo_din     : std_logic_vector (B-1 downto 0);
signal fifo_dout    : std_logic_vector (B-1 downto 0);
signal fifo_full    : std_logic;
signal fifo_empty   : std_logic;

-- Fifo pipeline.
-- signal fifo_dout_r  : std_logic_vector (B-1 downto 0);
-- signal fifo_empty_r : std_logic;

begin

-- Fifo to drive AXI Stream Master I/F.
fifo_i : fifo_axi
   Generic map
   (
      -- Data width.
      B => B   ,

      -- Fifo depth.
      N => 4
   )
   Port map
   (
      rstn    => rstn         ,
      clk     => clk       ,

      -- Write I/F.
      wr_en   => fifo_wr_en   ,
      din     => fifo_din     ,

      -- Read I/F.
      rd_en   => fifo_rd_en   ,
      dout    => fifo_dout ,

      -- Flags.
      full    => fifo_full ,
      empty   => fifo_empty
   );

-- Fifo connections - write
fifo_wr_en  <= write_state and not fifo_full;
fifo_din    <= mem_dout;

-- Fifo connections - read
fifo_rd_en  <= read_en and not fifo_empty and dready;

process(clk)
begin
   if ( rising_edge(clk) ) then
      if ( rstn = '0' ) then
         -- State register.
         current_state   <= INIT_ST;

         -- Counter for memory address and samples.
         cnt_wr         <= (others => '0');
         cnt_rd         <= (others => '0');
         addr_cnt       <= (others => '0');

         -- Length register.
         len_r          <= (others => '0');

         -- Fifo pipeline.
         -- fifo_dout_r    <= (others => '0');
         -- fifo_empty_r   <= '1';
      else
         -- State register.
         current_state   <= next_state;

         -- Memory address and data.
         if ( init_state = '1' ) then
            cnt_wr         <= (others => '0');
            addr_cnt       <= (others => '0');
            len_r          <= (others => '0');
         elsif ( regs_state = '1' ) then
            cnt_wr         <= (others => '0');
            addr_cnt       <= unsigned(ADDR_REG);
            len_r          <= unsigned(LEN_REG)-1;
            cnt_rd         <= unsigned(LEN_REG)-1;
         end if;
         if ( read_state = '1' ) then
            cnt_wr         <= cnt_wr + 1;
         end if;
         if ( fifo_rd_en = '1' ) then
            cnt_rd         <= cnt_rd - 1;
         end if;
         if ( write_state = '1' and fifo_full = '0') then
            addr_cnt       <= addr_cnt + 1;
         end if;

         -- Fifo pipeline.
         -- if ( dready = '1' ) then
            -- fifo_dout_r    <= fifo_dout;
            -- fifo_empty_r   <= fifo_empty;
         -- end if;
         
      end if;
   end if;
end process;

-- Next state logic.
process (current_state, START_REG, len_r, cnt_wr, fifo_full, cnt_rd, fifo_rd_en)
begin
   case current_state is
      when INIT_ST =>
         if (START_REG = '0') then
            next_state <= INIT_ST;
         else
            next_state <= REGS_ST;
         end if;

      when REGS_ST =>
         next_state <= READ_BRAM_ST;

      when READ_BRAM_ST =>
         next_state <= WRITE_FIFO_ST;

      when WRITE_FIFO_ST =>
         if ( fifo_full = '1' ) then
            next_state <= WRITE_FIFO_ST;
         elsif ( cnt_wr < len_r ) then
            next_state <= READ_BRAM_ST;
         else
            next_state <= READ_LAST_ST;
         end if;

      when READ_LAST_ST =>
         next_state <= WRITE_LAST_ST;

      when WRITE_LAST_ST =>
         if ( fifo_full = '1' ) then
            next_state <= WRITE_LAST_ST;
         else
            next_state <= FIFO_ST;
         end if;

      when FIFO_ST =>
         if ( cnt_rd = 0 and fifo_rd_en = '1' ) then
            next_state <= END_ST;
         else
            next_state <= FIFO_ST;
         end if;

      when END_ST =>
         if ( START_REG = '1' ) then
            next_state <= END_ST;
         else
            next_state <= INIT_ST;
         end if;
   end case;
end process;

-- Output logic.
process (current_state)
begin
   init_state  <= '0';
   regs_state  <= '0';
   read_state  <= '0';
   write_state <= '0';
   fifo_state  <= '0';
   read_en     <= '0';
   case current_state is
      when INIT_ST =>
         init_state  <= '1';

      when REGS_ST =>
         regs_state  <= '1';

      when READ_BRAM_ST =>
         read_state  <= '1';
         read_en     <= '1';

      when WRITE_FIFO_ST =>
         write_state <= '1';
         read_en     <= '1';

      when READ_LAST_ST =>
         read_state  <= '1';
         read_en     <= '1';

      when WRITE_LAST_ST =>
         write_state <= '1';
         read_en     <= '1';

      when FIFO_ST =>
         fifo_state  <= '1';
         read_en     <= '1';

      when END_ST =>

   end case;
end process;

-- Assign outputs.
mem_en      <= '1';
mem_we      <= '0';
mem_addr    <= std_logic_vector(addr_cnt);

dout        <= fifo_dout;
dvalid      <= fifo_rd_en and dready;
dlast       <= '1' when (cnt_rd = 0) else '0'; --fifo_state and fifo_empty;

end rtl;
