library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.pfb_ctrl_pkg.ALL;

entity pfb_cfg is
    Generic (
        -- Number of channels.
        N : Integer := 8
    );
    Port (
        -- Reset and clock. 
        rstn    : in STD_LOGIC;
        clk     : in STD_LOGIC;
        
        -- Filter config.
        cfg_en  : in STD_LOGIC;
        tready  : in STD_LOGIC;
        tvalid  : out STD_LOGIC;
        tlast   : out STD_LOGIC;
        tdata   : out STD_LOGIC_VECTOR (f_nbit_axis(N)-1 downto 0)
        );
end pfb_cfg;

architecture rtl of pfb_cfg is

-- Number of bits.
constant NBITS : Integer := f_nbit_axis(N);

type fsm_type is (  INIT_ST,
                    CNT_ST,
                    END_ST);

signal current_state, next_state : fsm_type;

-- tlast.
signal tlast_i      : std_logic;

-- Counter for config.
signal cfg_cnt      : unsigned (NBITS-1 downto 0);
signal cfg_cnt_en   : std_logic;

begin

-- Registers.
process(clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            -- State register.
            current_state <= INIT_ST;
            
            -- Counter for config.
            cfg_cnt <= (others => '0');
            
        else
            -- State register.
            current_state <= next_state;
        
            -- Counter for config.
            if ( cfg_cnt_en = '1' ) then
                cfg_cnt <= cfg_cnt + 1;
            end if;
            
        end if;
    end if;
end process;

-- tlast.
tlast_i <=  '1' when cfg_cnt = to_unsigned(N-1,cfg_cnt'length) else
            '0';
            
-- Next state logic.
process (current_state, cfg_en, tready, cfg_cnt)
begin
    case current_state is
        when INIT_ST =>
            if ( cfg_en = '1' and tready = '1' ) then
                next_state <= CNT_ST;
            else
                next_state <= INIT_ST;
            end if;
            
        when CNT_ST =>
            if ( cfg_cnt = to_unsigned(N-1,cfg_cnt'length) ) then
                next_state <= END_ST;
            else
                next_state <= CNT_ST;
            end if;
            
        when END_ST =>
            if ( cfg_en = '1' ) then
                next_state <= END_ST;
            else
                next_state <= INIT_ST;
            end if;
            
    end case;
end process;

-- Output logic.
process (current_state)
begin
cfg_cnt_en  <= '0';
    case current_state is
        when INIT_ST =>
        
        when CNT_ST=>
            cfg_cnt_en <= '1';
            
        when END_ST =>
        
    end case;
end process;

-- Assign outputs.
tvalid  <= cfg_cnt_en;
tlast   <= tlast_i;
tdata   <= std_logic_vector (cfg_cnt);

end rtl;

