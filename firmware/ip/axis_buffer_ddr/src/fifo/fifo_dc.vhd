library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_dc is
    Generic
    (
        -- Data width.
        B : Integer := 16;
        
        -- Fifo depth.
        N : Integer := 4
    );
    Port
    ( 
        wr_rstn	: in std_logic;
        wr_clk 	: in std_logic;

        rd_rstn	: in std_logic;
        rd_clk 	: in std_logic;
        
        -- Write I/F.
        wr_en  	: in std_logic;
        din     : in std_logic_vector (B-1 downto 0);
        
        -- Read I/F.
        rd_en  	: in std_logic;
        dout   	: out std_logic_vector (B-1 downto 0);
        
        -- Flags.
        full    : out std_logic;        
        empty   : out std_logic
    );
end fifo_dc;

architecture rtl of fifo_dc is

-- Number of bits of depth.
constant N_LOG2 : Integer := Integer(ceil(log2(real(N))));

-- Binary to gray converter.
component bin2gray is
	Generic
	(
		-- Data width.
		B : Integer := 8
	);
	Port
	(
		din	: in std_logic_vector (B-1 downto 0);
		dout: out std_logic_vector (B-1 downto 0)
	);
end component;

-- Gray to binary converter.
component gray2bin is
	Generic
	(
		-- Data width.
		B : Integer := 8
	);
	Port
	(
		din	: in std_logic_vector (B-1 downto 0);
		dout: out std_logic_vector (B-1 downto 0)
	);
end component;

-- Vector synchronizer (only for gray coded).
component synchronizer_vect is 
	generic (
		-- Sync stages.
		N : Integer := 2;

		-- Data width.
		B : Integer := 8
	);
	port (
		rstn	    : in std_logic;
		clk 		: in std_logic;
		data_in		: in std_logic_vector (B-1 downto 0);
		data_out	: out std_logic_vector (B-1 downto 0)
	);
end component;

-- Dual port BRAM.
component bram_dp is
    Generic (
        -- Memory address size.
        N       : Integer := 16;
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
        clka    : in STD_LOGIC;
        clkb    : in STD_LOGIC;
        ena     : in STD_LOGIC;
        enb     : in STD_LOGIC;
        wea     : in STD_LOGIC;
        web     : in STD_LOGIC;
        addra   : in STD_LOGIC_VECTOR (N-1 downto 0);
        addrb   : in STD_LOGIC_VECTOR (N-1 downto 0);
        dia     : in STD_LOGIC_VECTOR (B-1 downto 0);
        dib     : in STD_LOGIC_VECTOR (B-1 downto 0);
        doa     : out STD_LOGIC_VECTOR (B-1 downto 0);
        dob     : out STD_LOGIC_VECTOR (B-1 downto 0)
    );
end component;

-- Pointers.
signal wptr   	: unsigned (N_LOG2-1 downto 0);
signal wptr_g 	: std_logic_vector (N_LOG2-1 downto 0);
signal wptr_gc 	: std_logic_vector (N_LOG2-1 downto 0);
signal wptr_c  	: std_logic_vector (N_LOG2-1 downto 0);
signal rptr   	: unsigned (N_LOG2-1 downto 0);
signal rptr_g 	: std_logic_vector (N_LOG2-1 downto 0);
signal rptr_gc 	: std_logic_vector (N_LOG2-1 downto 0);
signal rptr_c  	: std_logic_vector (N_LOG2-1 downto 0);

-- Memory signals.
signal mem_wea	: std_logic;
signal mem_dib	: std_logic_vector (B-1 downto 0);
signal mem_doa	: std_logic_vector (B-1 downto 0);
signal mem_dob	: std_logic_vector (B-1 downto 0);

-- Flags.
signal full_i   : std_logic;
signal empty_i  : std_logic;

begin

-- wptr_i: binary to gray.
wptr_i : bin2gray
	Generic map
	(
		-- Data width.
		B => N_LOG2
	)
	Port map
	(
		din		=> std_logic_vector(wptr),
		dout	=> wptr_g
	);

-- wptr_g: write to read domain.
wptr_g_i : synchronizer_vect
	generic  map (
		-- Sync stages.
		N => 2,

		-- Data width.
		B => N_LOG2
	)
	port map (
		rstn	    => rd_rstn,
		clk 		=> rd_clk,
		data_in		=> wptr_g,
		data_out	=> wptr_gc
	);

-- wptr_gc_i
wptr_gc_i : gray2bin
	Generic map
	(
		-- Data width.
		B => N_LOG2
	)
	Port map
	(
		din		=> wptr_gc,
		dout	=> wptr_c
	);

-- rptr_i: binary to gray.
rptr_i : bin2gray
	Generic map
	(
		-- Data width.
		B => N_LOG2
	)
	Port map
	(
		din		=> std_logic_vector(rptr),
		dout	=> rptr_g
	);

-- rptr_g: read to write domain.
rptr_g_i : synchronizer_vect
	generic  map (
		-- Sync stages.
		N => 2,

		-- Data width.
		B => N_LOG2
	)
	port map (
		rstn	    => wr_rstn,
		clk 		=> wr_clk,
		data_in		=> rptr_g,
		data_out	=> rptr_gc
	);

-- rptr_gc_i
rptr_gc_i : gray2bin
	Generic map
	(
		-- Data width.
		B => N_LOG2
	)
	Port map
	(
		din		=> rptr_gc,
		dout	=> rptr_c
	);

-- FIFO memory.
mem_i : bram_dp
    Generic map (
        -- Memory address size.
        N       => N_LOG2,
        -- Data width.
        B       => B
    )
    Port map ( 
        clka    => wr_clk,
        clkb    => rd_clk,
        ena     => '1',
        enb     => rd_en,
        wea     => mem_wea,
        web     => '0',
        addra   => std_logic_vector(wptr),
        addrb   => std_logic_vector(rptr),
        dia     => din,
        dib     => mem_dib,
        doa     => mem_doa,
        dob     => mem_dob
    );
-- Memory connections.
mem_wea <= 	wr_en when full_i = '0' else
			'0';
mem_dib	<= (others => '0');

-- Full/empty signals.
full_i 	<=  '1' when wptr = unsigned(rptr_c) - 1 else 
            '0';           
empty_i	<= 	'1' when unsigned(wptr_c) = rptr else
			'0';

-- wr_clk registers.
process (wr_clk)
begin
    if ( rising_edge(wr_clk) ) then
        if ( wr_rstn = '0' ) then
            wptr <= (others => '0');
        else
            -- Write.
            if ( wr_en = '1' and full_i = '0' ) then
                -- Write data.
                
                -- Increment pointer.
                wptr <= wptr + 1;
            end if;
        end if;
    end if;
end process;

-- rd_clk registers.
process (rd_clk)
begin
    if ( rising_edge(rd_clk) ) then
        if ( rd_rstn = '0' ) then
            rptr    <= (others => '0');
        else
            -- Read.
            if ( rd_en = '1' and empty_i = '0' ) then
                -- Read data.
                
                -- Increment pointer.
                rptr <= rptr + 1;
            end if;
        end if;
    end if;
end process;

-- Assign outputs.
dout   	<= mem_dob;
full    <= full_i;
empty   <= empty_i;

end rtl;
