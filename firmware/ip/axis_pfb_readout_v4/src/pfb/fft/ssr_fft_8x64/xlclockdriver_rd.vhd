library xil_defaultlib;
use xil_defaultlib.conv_pkg.all;

---------------------------------------------------------------------
--
--  Filename      : xlclockdriver.vhd
--
--  Date          : 10/1/99
--
--  Description   : VHDL description of a clock enable generator block.
--                  This code is synthesizable.
--
--  Assumptions   : period >= 1
--
--  Mod. History  : Removed one shot & OR gate
--                  If period is power of 2 a 1-bit smaller counter
--                  is used and no sync clear
--                : Logic needed for use_bufg generic added
--                : Initial ce output is now 0 instead of 1
--                  Enable pulse now occurs at the end of the sample
--                  period, instead of at the start
--                : Added pipeline registers
--                : added OR gate for sysclr to work properly
--
--  Mod. Dates    : 7/26/2001
--                : 8/05/2001
--                : 1/02/2002
--                : 11/30/2004
--                : 4/11/2005
--
---------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
-- synthesis translate_off
library unisim;
use unisim.vcomponents.all;
-- synthesis translate_on

entity xlclockdriver is
  generic (
    period: integer := 2;
    log_2_period: integer := 0;
    pipeline_regs: integer := 5;
    use_bufg: integer := 0
  );
  port (
    sysclk: in std_logic;
    sysclr: in std_logic;
    sysce: in std_logic;
    clk: out std_logic;
    clr: out std_logic;
    ce: out std_logic;
    ce_logic: out std_logic
  );
end xlclockdriver;

architecture behavior of xlclockdriver is
  component bufg
    port (
      i: in std_logic;
      o: out std_logic
    );
  end component;

  component synth_reg_w_init
    generic (
      width: integer;
      init_index: integer;
      init_value: bit_vector;
      latency: integer
    );
    port (
      i: in std_logic_vector(width - 1 downto 0);
      ce: in std_logic;
      clr: in std_logic;
      clk: in std_logic;
      o: out std_logic_vector(width - 1 downto 0)
    );
  end component;

  -- Returns the size of an unsigned integer
  -- if power_of_2 is true return value is one less
  function size_of_uint(inp: integer; power_of_2: boolean)
    return integer
  is
    constant inp_vec: std_logic_vector(31 downto 0) :=
      integer_to_std_logic_vector(inp,32, xlUnsigned);
    variable result: integer;
  begin
    result := 32;
    for i in 0 to 31 loop
      if inp_vec(i) = '1' then
        result := i;
      end if;
    end loop;
    if power_of_2 then
      return result;
    else
      return result+1;
    end if;
  end;

  -- Returns boolean which says if 'inp' is a power of two
  function is_power_of_2(inp: std_logic_vector)
    return boolean
  is
    constant width: integer := inp'length;
    variable vec: std_logic_vector(width - 1 downto 0);
    variable single_bit_set: boolean;
    variable more_than_one_bit_set: boolean;
    variable result: boolean;
  begin
    vec := inp;
    single_bit_set := false;
    more_than_one_bit_set := false;

    -- synthesis translate_off
    if (is_XorU(vec)) then
      return false;
    end if;
     -- synthesis translate_on
    if width > 0 then
      for i in 0 to width - 1 loop
        if vec(i) = '1' then
          if single_bit_set then
            more_than_one_bit_set := true;
          end if;
          single_bit_set := true;
        end if;
      end loop;
    end if;
    if (single_bit_set and not(more_than_one_bit_set)) then
      result := true;
    else
      result := false;
    end if;
    return result;
  end;

  -- Returns initial value for pipeline registers
  function ce_reg_init_val(index, period : integer)
    return integer
  is
     variable result: integer;
   begin
      result := 0;
      if ((index mod period) = 0) then
	  result := 1;
      end if;
      return result;
  end;    

  -- Returns the remainder(num_pipeline_regs/period) + 1
  function remaining_pipe_regs(num_pipeline_regs, period : integer)
    return integer
  is
     variable factor, result: integer;
  begin
      factor := (num_pipeline_regs / period);
      result := num_pipeline_regs - (period * factor) + 1;
      return result;
  end;    
  
  -- Calculate the min
  function sg_min(L, R: INTEGER) return INTEGER is
  begin
      if L < R then
            return L;
      else
            return R;
      end if;
  end;

  constant max_pipeline_regs : integer := 8;
  constant pipe_regs : integer := 5;

  -- Check if requested pipeline regs are greater than the max amount
  constant num_pipeline_regs : integer := sg_min(pipeline_regs, max_pipeline_regs);
  constant rem_pipeline_regs : integer := remaining_pipe_regs(num_pipeline_regs,period);

  constant period_floor: integer := max(2, period);
  constant power_of_2_counter: boolean :=
    is_power_of_2(integer_to_std_logic_vector(period_floor,32, xlUnsigned));
  constant cnt_width: integer :=
    size_of_uint(period_floor, power_of_2_counter);
  constant clk_for_ce_pulse_minus1: std_logic_vector(cnt_width - 1 downto 0) :=
    integer_to_std_logic_vector((period_floor - 2),cnt_width, xlUnsigned);
  constant clk_for_ce_pulse_minus2: std_logic_vector(cnt_width - 1 downto 0) :=
    integer_to_std_logic_vector(max(0,period - 3),cnt_width, xlUnsigned);
  constant clk_for_ce_pulse_minus_regs: std_logic_vector(cnt_width - 1 downto 0) :=
    integer_to_std_logic_vector(max(0,period - rem_pipeline_regs),cnt_width, xlUnsigned);

  signal clk_num: unsigned(cnt_width - 1 downto 0) := (others => '0');
  signal ce_vec : std_logic_vector(num_pipeline_regs downto 0);
  signal ce_vec_logic : std_logic_vector(num_pipeline_regs downto 0);  
  signal internal_ce: std_logic_vector(0 downto 0);
  signal internal_ce_logic: std_logic_vector(0 downto 0);
  signal cnt_clr, cnt_clr_dly: std_logic_vector (0 downto 0);
begin
  -- Pass through the system clock and clear
  clk <= sysclk;
  clr <= sysclr;

  -- Clock Number Counter
  cntr_gen: process(sysclk)
  begin
    if sysclk'event and sysclk = '1'  then
      if (sysce = '1') then
        if ((cnt_clr_dly(0) = '1') or (sysclr = '1')) then
          clk_num <= (others => '0');
        else
          clk_num <= clk_num + 1;
        end if;
    end if;
    end if;
  end process;

  -- Clear logic for counter
  clr_gen: process(clk_num, sysclr)
  begin
    if power_of_2_counter then
      cnt_clr(0) <= sysclr;
    else
      -- Counter does not reset when clk_num = a power of 2
      if (unsigned_to_std_logic_vector(clk_num) = clk_for_ce_pulse_minus1
          or sysclr = '1') then
        cnt_clr(0) <= '1';
      else
        cnt_clr(0) <= '0';
      end if;
    end if;
  end process;

  clr_reg: synth_reg_w_init
    generic map (
      width => 1,
      init_index => 0,
      init_value => b"0000",
      latency => 1
    )
    port map (
      i => cnt_clr,
      ce => sysce,
      clr => sysclr,
      clk => sysclk,
      o => cnt_clr_dly
    );

  -- Clock enable generation
  pipelined_ce : if period > 1 generate
      ce_gen: process(clk_num)
      begin
	  if unsigned_to_std_logic_vector(clk_num) = clk_for_ce_pulse_minus_regs then
              ce_vec(num_pipeline_regs) <= '1';
          else
              ce_vec(num_pipeline_regs) <= '0';
	  end if;
      end process;
      ce_pipeline: for index in num_pipeline_regs downto 1 generate
	  ce_reg : synth_reg_w_init
	      generic map (
		  width => 1,
		  init_index => ce_reg_init_val(index, period),
		  init_value => b"0000",  -- not used
		  latency => 1
		  )
	      port map (
		  i => ce_vec(index downto index),
		  ce => sysce,
		  clr => sysclr,
		  clk => sysclk,
		  o => ce_vec(index-1 downto index-1)
		  );
      end generate;  -- i
      internal_ce <= ce_vec(0 downto 0);
  end generate;

  -- Clock enable generation
  pipelined_ce_logic: if period > 1 generate
      ce_gen_logic: process(clk_num)
      begin
	  if unsigned_to_std_logic_vector(clk_num) = clk_for_ce_pulse_minus_regs then
              ce_vec_logic(num_pipeline_regs) <= '1';
          else
              ce_vec_logic(num_pipeline_regs) <= '0';
	  end if;
      end process;
      ce_logic_pipeline: for index in num_pipeline_regs downto 1 generate
	  ce_logic_reg : synth_reg_w_init
	      generic map (
		  width => 1,
		  init_index => ce_reg_init_val(index, period),
		  init_value => b"0000",  -- not used
		  latency => 1
		  )
	      port map (
		  i => ce_vec_logic(index downto index),
		  ce => sysce,
		  clr => sysclr,
		  clk => sysclk,
		  o => ce_vec_logic(index-1 downto index-1)
		  );
      end generate;  -- i
      internal_ce_logic <= ce_vec_logic(0 downto 0);
  end generate;


  use_bufg_true: if period > 1 and use_bufg = 1 generate
      -- Clock enable with bufg
    ce_bufg_inst: bufg
      port map (
        i => internal_ce(0),
        o => ce
      );
    ce_bufg_inst_logic: bufg
      port map (
        i => internal_ce_logic(0),
        o => ce_logic
      );
  end generate;

  use_bufg_false: if period > 1 and (use_bufg = 0) generate
    -- Clock enable without bufg
    ce <= internal_ce(0) and sysce;
    ce_logic <= internal_ce_logic(0) and sysce;
  end generate;

  generate_system_clk: if period = 1 generate
    ce <= sysce;
    ce_logic <= sysce;
  end generate;
end architecture behavior;




