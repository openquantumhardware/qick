library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_writer is
    Generic
    (
        -- Memory size.
        N   : Integer := 16;
        -- Data width.
        B   : Integer := 16
    );
    Port
    (
        rstn            : in STD_LOGIC;
        clk             : in STD_LOGIC;
        
        -- AXI Stream I/F.
        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(B-1 downto 0);				
		s_axis_tvalid	: in std_logic;
		
		-- Memory I/F.
		mem_en          : out std_logic;
		mem_we          : out std_logic;
		mem_addr        : out std_logic_vector (N-1 downto 0);
		mem_di          : out std_logic_vector (B-1 downto 0);
		
		-- Registers.
		START_ADDR_REG  : in std_logic_vector (31 downto 0);
		WE_REG			: in std_logic 
    );
end data_writer;

architecture rtl of data_writer is

-- Synchronizer.
component synchronizer_n is 
	generic (
		N : Integer := 2
	);
	port (
		rstn	    : in std_logic;
		clk 		: in std_logic;
		data_in		: in std_logic;
		data_out	: out std_logic
	);
end component;

-- State machine.
type fsm_state is ( INIT_ST				,
                    READ_START_ADDR_ST	,
                    WAIT_TVALID_ST		,
                    RW_TDATA_ST			);
signal state : fsm_state;

signal read_start_addr_state    : std_logic;
signal rw_tdata_state           : std_logic;

-- WE_REG_resync.
signal WE_REG_resync   	: std_logic;

-- Axis registers.
signal tready_i     	: std_logic;
signal tready_r     	: std_logic;
signal tdata_r	    	: std_logic_vector(B-1 downto 0);
signal tdata_rr	    	: std_logic_vector(B-1 downto 0);				
signal tdata_rrr    	: std_logic_vector(B-1 downto 0);
signal tvalid_r     	: std_logic;
signal tvalid_rr    	: std_logic;
signal tvalid_rrr   	: std_logic;

-- Memory address space.
signal mem_addr_full    : unsigned (N-1 downto 0);
signal mem_addr_full_r  : unsigned (N-1 downto 0);

begin

-- WE_REG_resync
WE_REG_resync_i : synchronizer_n
	generic map (
		N => 2
	)
	port map (
		rstn	    => rstn				,
		clk 		=> clk				,
		data_in		=> WE_REG			,
		data_out	=> WE_REG_resync
	);

process (clk)
begin
	if ( rising_edge(clk) ) then
    	if (rstn = '0') then
    	    -- Axis registers.
    	    tready_r    	<= '0';
    	    tdata_r     	<= (others => '0');				
    	    tdata_rr    	<= (others => '0');
    	    tdata_rrr   	<= (others => '0');
    	    tvalid_r    	<= '0';
    	    tvalid_rr   	<= '0';
    	    tvalid_rrr  	<= '0';
    	            
    	    -- Memory address.
    	    mem_addr_full   <= (others => '0');
    	    mem_addr_full_r <= (others => '0');
    	else
    	    -- Axis registers.
    	    tready_r    	<= tready_i;
    	    tdata_r     	<= s_axis_tdata;				
    	    tvalid_r    	<= s_axis_tvalid;
    	    
    	    -- Extra registers to account pipe of state machine.
    	    tdata_rr    	<= tdata_r;
    	    tdata_rrr   	<= tdata_rr;
    	    tvalid_rr   	<= tvalid_r;
    	    tvalid_rrr  	<= tvalid_rr;
    	    
    	    -- Memory address.       
    	    if ( read_start_addr_state = '1') then
    	        mem_addr_full <= to_unsigned(to_integer(unsigned(START_ADDR_REG)),mem_addr_full'length);            
    	    elsif ( rw_tdata_state = '1' ) then
    	        mem_addr_full <= mem_addr_full + 1;
    	    end if;
    	    mem_addr_full_r <= mem_addr_full;
    	    
    	end if;
	end if;
end process;

-- Finite state machine.
process (clk)
begin
	if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			state <= INIT_ST;
		else
			case state is
				when INIT_ST =>
					if ( WE_REG_resync = '1' ) then
						state <= READ_START_ADDR_ST;
					end if;

				when READ_START_ADDR_ST =>
            		state <= WAIT_TVALID_ST;

				when WAIT_TVALID_ST =>
            		if ( WE_REG_resync = '1') then
            		    if ( tvalid_r = '0' ) then
            		        state <= WAIT_TVALID_ST;
            		    else 
            		        state <= RW_TDATA_ST;
            		    end if;
            		else
            		    state <= INIT_ST;
            		end if;

				when RW_TDATA_ST =>
            		if ( tvalid_r = '0' ) then
            		    state <= WAIT_TVALID_ST;
            		end if;        

			end case;
		end if;
	end if;
end process;

-- Output logic.
process (state)
begin
read_start_addr_state   <= '0';
rw_tdata_state          <= '0';
tready_i                <= '0';
    case state is
        when INIT_ST    =>
            
        when READ_START_ADDR_ST =>
            read_start_addr_state   <= '1';
                                           
        when WAIT_TVALID_ST =>
            tready_i                <= '1';
            
        when RW_TDATA_ST =>
            rw_tdata_state          <= '1';
            tready_i                <= '1';
        
    end case;
end process;

-- Assign output.
s_axis_tready   <= tready_r;

mem_en          <= '1';
mem_we          <= tvalid_rrr;
mem_addr        <= std_logic_vector(mem_addr_full_r); 
mem_di          <= tdata_rrr;

end rtl;

