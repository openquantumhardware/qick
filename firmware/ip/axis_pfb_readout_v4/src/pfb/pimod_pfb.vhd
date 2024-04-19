-----------------------
-- Spectral PI shift --
-----------------------
-- This block performs PI shift in frequency domain.
-- It's intended to be used at the output of the SSR FFT
-- IP in the polyphase filter bank implementation.
--
-- PI frequency shift means multiplying by alternating
-- sequence of +1 -1. It is only applied to odd FFT bins.
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity pimod_pfb is
	Generic
	(
		-- FFT size.
		NFFT	: Integer := 16;
		-- Number of bits.
		B		: Integer := 16;
		-- Number of Lanes.
		L		: Integer := 4
	);
	Port
	(
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- S_AXIS for input.
		s_axis_tdata	: in std_logic_vector(2*B*L-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;
		s_axis_tready	: out std_logic;

		-- M_AXIS for output.
		m_axis_tdata	: out std_logic_vector(2*B*L-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tvalid	: out std_logic;
		m_axis_tready	: in std_logic
	);
end pimod_pfb;

architecture rtl of pimod_pfb is

-- Number of bits.
constant NBITS : Integer := 2*B*L;

-- MIN,MAX values.
constant MAX_P	: Integer := 2**(B-1)-1;
constant MIN_N	: Integer := -2**(B-1);	

-- Period for +1 -1.
constant T		: Integer := NFFT/L;
constant T_LOG2 : Integer := Integer(ceil(log2(real(T))));

-- Single-clock AXI compatible FIFO.
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
        rstn	: in std_logic;
        clk 	: in std_logic;

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
end component;


signal fifo_din		: std_logic_vector (NBITS downto 0);
signal fifo_dout	: std_logic_vector (NBITS downto 0);
signal fifo_full	: std_logic;
signal fifo_empty	: std_logic;

-- Input data/tlast.
signal d_i			: std_logic_vector (NBITS-1 downto 0);
signal last_i		: std_logic;

-- Pipeline registers.
signal d_r			: std_logic_vector (NBITS-1 downto 0);
signal d_rr			: std_logic_vector (NBITS-1 downto 0);
signal empty_r		: std_logic;
signal empty_rr		: std_logic;
signal last_r		: std_logic;
signal last_rr		: std_logic;

-- Vector signals for pm operation.
type vect_t is array (L-1 downto 0) of signed (B-1 downto 0);
signal dv_i 		: vect_t;
signal dv_i_pm 		: vect_t;
signal dv_q 		: vect_t;
signal dv_q_pm 		: vect_t;

-- Signals combined after pm.
signal d_pm			: std_logic_vector (NBITS-1 downto 0);

-- Muxed signal for alternating pm operation.
signal d_mux		: std_logic_vector (NBITS-1 downto 0);

-- Selection register.
signal cnt			: unsigned (T_LOG2-1 downto 0);
signal sel			: unsigned (0 downto 0);

begin

-- FIFO (NBIT_IN+1 bits: data + tlast).
fifo : fifo_axi
    Generic map
    (
        -- Data width.
        B => NBITS+1	,
        
        -- Fifo depth.
        N => 4
    )
    Port map
    ( 
        rstn	=> aresetn			,
        clk 	=> aclk				,
        
        -- Write I/F.
        wr_en  	=> s_axis_tvalid	,
        din     => fifo_din			,
        
        -- Read I/F.
        rd_en  	=> m_axis_tready	,
        dout   	=> fifo_dout		,
        
        -- Flags.
        full    => fifo_full		,
        empty   => fifo_empty
    );

-- Fifo connections.
fifo_din		<= s_axis_tlast & s_axis_tdata;
s_axis_tready	<= not(fifo_full);

-- Registers.
process (aclk)
begin
	if ( rising_edge(aclk) ) then
		if ( aresetn = '0' ) then
			-- Pipeline registers.
			d_r			<= (others => '0');
			d_rr		<= (others => '0');
			empty_r		<= '1';
			empty_rr	<= '1';
			last_r		<= '0';
			last_rr		<= '0';
			
			-- sel register.
			cnt			<= (others => '0');
			sel			<= (others => '0');
		else
			-- Pipeline registers.
			d_r			<= d_i;
			d_rr		<= d_mux;
			empty_r		<= fifo_empty;
			empty_rr	<= empty_r;
			last_r		<= last_i;
			last_rr		<= last_r;
			
			-- sel register: if reading and not empty, count.
			if ( m_axis_tready = '1' and empty_r = '0' ) then
				if ( cnt < to_unsigned(T-1,cnt'length) ) then
					cnt <= cnt + 1;
				else
					cnt <= (others => '0');
					sel <= sel + 1;
				end if;
			end if;

		end if;
	end if;	
end process;

-- Input data/tlast.
d_i		<= fifo_dout(NBITS-1 downto 0);
last_i	<= fifo_dout(NBITS);

-- Slice input.
GEN_SLICE_IN: for I in 0 to L-1 generate
	dv_i(I)	<= signed(d_r ( 	2*I*B+B-1 	downto 		2*I*B));
	dv_q(I)	<= signed(d_r ( (2*I+1)*B+B-1 	downto (2*I+1)*B));
end generate GEN_SLICE_IN;

-- Multiply by -1 only odd samples.
GEN_PM: for I in 0 to L/2-1 generate
	-- Even samples: multiply always by 1.
	dv_i_pm(2*I) 	<= dv_i(2*I);
	
	-- Odd samples: multiply by -1. Check maximum negative number.
	dv_i_pm(2*I+1)	<=	to_signed(MAX_P,B) when dv_i(2*I+1) = to_signed(MIN_N,B) else
						-dv_i(2*I+1);

	-- Even samples: multiply always by 1.
	dv_q_pm(2*I) 	<= dv_q(2*I);

	-- Odd samples: multiply by -1. Check maximum negative number.
	dv_q_pm(2*I+1) 	<= 	to_signed(MAX_P,B) when dv_q(2*I+1) = to_signed(MIN_N,B) else
						-dv_q(2*I+1);
end generate GEN_PM;

-- Combine signals back.
GEN_COMBINE_PM: for I in 0 to L-1 generate
	d_pm (	2*I*B+B-1 	downto 	 2*I*B)		<= std_logic_vector(dv_i_pm(I));
	d_pm ((2*I+1)*B+B-1 downto (2*I+1)*B) 	<= std_logic_vector(dv_q_pm(I));
end generate GEN_COMBINE_PM;

-- Data mux.
d_mux	<= 	d_r when sel = to_unsigned(0,sel'length) else
			d_pm;


-- Assign outputs.
m_axis_tdata	<= d_rr;
m_axis_tlast	<= last_rr;
m_axis_tvalid	<= not(empty_rr);

end rtl;

