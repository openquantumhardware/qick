library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ssrfft_8x8 is
	Generic
	(
		NFFT	: Integer := 8;
		SSR		: Integer := 8;
		B		: Integer := 16
	);
    Port
    (
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (SSR*2*B-1 downto 0);
		s_axis_tvalid	: in std_logic;

		-- AXIS Master.
		m_axis_tdata	: out std_logic_vector (SSR*2*B-1 downto 0);
		m_axis_tvalid	: out std_logic;

		-- Registers.
		SCALE_REG		: in std_logic_vector (31 downto 0);
		QOUT_REG		: in std_logic_vector (31 downto 0)
    );
end entity;

architecture rtl of ssrfft_8x8 is

-- SSR FFT 8x8.
component ssr_8x8 is
  port (
	-- Clock signal.
    clk 		: in std_logic;

	-- Input data.
    i_re_0 		: in std_logic_vector( 16-1 downto 0 );
    i_re_1 		: in std_logic_vector( 16-1 downto 0 );
    i_re_2 		: in std_logic_vector( 16-1 downto 0 );
    i_re_3 		: in std_logic_vector( 16-1 downto 0 );
    i_re_4 		: in std_logic_vector( 16-1 downto 0 );
    i_re_5 		: in std_logic_vector( 16-1 downto 0 );
    i_re_6 		: in std_logic_vector( 16-1 downto 0 );
    i_re_7 		: in std_logic_vector( 16-1 downto 0 );
    i_im_0 		: in std_logic_vector( 16-1 downto 0 );
    i_im_1 		: in std_logic_vector( 16-1 downto 0 );
    i_im_2 		: in std_logic_vector( 16-1 downto 0 );
    i_im_3 		: in std_logic_vector( 16-1 downto 0 );
    i_im_4 		: in std_logic_vector( 16-1 downto 0 );
    i_im_5 		: in std_logic_vector( 16-1 downto 0 );
    i_im_6 		: in std_logic_vector( 16-1 downto 0 );
    i_im_7 		: in std_logic_vector( 16-1 downto 0 );
    i_valid 	: in std_logic_vector( 1-1 downto 0 );
    i_scale 	: in std_logic_vector( 3-1 downto 0 );

	-- Output data.
    o_re_0 		: out std_logic_vector( 27-1 downto 0 );
    o_re_1 		: out std_logic_vector( 27-1 downto 0 );
    o_re_2 		: out std_logic_vector( 27-1 downto 0 );
    o_re_3 		: out std_logic_vector( 27-1 downto 0 );
    o_re_4 		: out std_logic_vector( 27-1 downto 0 );
    o_re_5 		: out std_logic_vector( 27-1 downto 0 );
    o_re_6 		: out std_logic_vector( 27-1 downto 0 );
    o_re_7 		: out std_logic_vector( 27-1 downto 0 );
    o_im_0 		: out std_logic_vector( 27-1 downto 0 );
    o_im_1 		: out std_logic_vector( 27-1 downto 0 );
    o_im_2 		: out std_logic_vector( 27-1 downto 0 );
    o_im_3 		: out std_logic_vector( 27-1 downto 0 );
    o_im_4 		: out std_logic_vector( 27-1 downto 0 );
    o_im_5 		: out std_logic_vector( 27-1 downto 0 );
    o_im_6 		: out std_logic_vector( 27-1 downto 0 );
    o_im_7 		: out std_logic_vector( 27-1 downto 0 );
    o_valid     : out std_logic_vector( 1-1 downto 0);
    o_scale 	: out std_logic_vector( 3-1 downto 0 )
  );
end component;

-- Vectors with individual I,Q samples.
type data_v is array (SSR-1 downto 0) of std_logic_vector (B-1 downto 0);
signal din_iv 			: data_v;
signal din_qv 			: data_v;
signal dout_iv 			: data_v;
signal dout_qv 			: data_v;

-- Vector with individual I,Q samples (fft out full precision).
type data_vf is array (SSR-1 downto 0) of std_logic_vector (27-1 downto 0);
signal dout_ivf			: data_vf;
signal dout_qvf			: data_vf;

-- I,Q parts of input and output.
signal din_i			: std_logic_vector (SSR*B-1 downto 0);
signal din_q			: std_logic_vector (SSR*B-1 downto 0);
signal dout_i			: std_logic_vector (SSR*B-1 downto 0);
signal dout_q			: std_logic_vector (SSR*B-1 downto 0);

-- FFT scale.
signal o_scale			: std_logic_vector (2 downto 0);

-- FFT output valid.
signal o_axis_tvalid	: std_logic;

-- FFT data output.
signal o_axis_tdata		: std_logic_vector (2*SSR*B-1 downto 0);

-- Registers.
signal scale_reg_i		: std_logic_vector (2 downto 0);
signal qout_reg_i		: unsigned (2 downto 0);

begin

-- Registers.
scale_reg_i <= SCALE_REG (2 downto 0);

-- Full-precision output: 27 bits. Required output: 16 bits.
-- Quantization selection from 0 to 11.
qout_reg_i	<= (others => '0') when ( unsigned(QOUT_REG) > to_unsigned(11,QOUT_REG'length) ) else
				unsigned(QOUT_REG(2 downto 0));

-- Input/output data.
din_i									<= s_axis_tdata (SSR*B-1 downto 0);
din_q									<= s_axis_tdata (2*SSR*B-1 downto SSR*B);
o_axis_tdata(SSR*B-1 downto 0) 			<= dout_i;
o_axis_tdata(2*SSR*B-1 downto SSR*B) 	<= dout_q;

-- Input/output data to vector.
GEN: for I in 0 to SSR-1 generate
	-- Input data to vector.
	din_iv(I)	<= din_i((I+1)*B-1 downto I*B);	
	din_qv(I)	<= din_q((I+1)*B-1 downto I*B);	

	-- Quantization selection.
	dout_iv(I)	<= dout_ivf(I)(to_integer(qout_reg_i)+B-1 downto to_integer(qout_reg_i));
	dout_qv(I)	<= dout_qvf(I)(to_integer(qout_reg_i)+B-1 downto to_integer(qout_reg_i));

	-- Output data to vector.
	dout_i((I+1)*B-1 downto I*B) <= dout_iv(I);
	dout_q((I+1)*B-1 downto I*B) <= dout_qv(I);
end generate GEN;

-- SSR FFT 8x8.
ssr_8x8_i : ssr_8x8
  port map (
	-- Clock signal.
    clk 		=> aclk				,

	-- Input data.
    i_re_0 		=> din_iv(0)		,
    i_re_1 		=> din_iv(1)		,
    i_re_2 		=> din_iv(2)		,
    i_re_3 		=> din_iv(3)		,
    i_re_4 		=> din_iv(4)		,
    i_re_5 		=> din_iv(5)		,
    i_re_6 		=> din_iv(6)		,
    i_re_7 		=> din_iv(7)		,
    i_im_0 		=> din_qv(0)		,
    i_im_1 		=> din_qv(1)		,
    i_im_2 		=> din_qv(2)		,
    i_im_3 		=> din_qv(3)		,
    i_im_4 		=> din_qv(4)		,
    i_im_5 		=> din_qv(5)		,
    i_im_6 		=> din_qv(6)		,
    i_im_7 		=> din_qv(7)		,
    i_valid(0) 	=> s_axis_tvalid	,
    i_scale 	=> scale_reg_i		,

	-- Output data.
    o_re_0 		=> dout_ivf(0)		,
    o_re_1 		=> dout_ivf(1)		,
    o_re_2 		=> dout_ivf(2)		,
    o_re_3 		=> dout_ivf(3)		,
    o_re_4 		=> dout_ivf(4)		,
    o_re_5 		=> dout_ivf(5)		,
    o_re_6 		=> dout_ivf(6)		,
    o_re_7 		=> dout_ivf(7)		,
    o_im_0 		=> dout_qvf(0)		,
    o_im_1 		=> dout_qvf(1)		,
    o_im_2 		=> dout_qvf(2)		,
    o_im_3 		=> dout_qvf(3)		,
    o_im_4 		=> dout_qvf(4)		,
    o_im_5 		=> dout_qvf(5)		,
    o_im_6 		=> dout_qvf(6)		,
    o_im_7 		=> dout_qvf(7)		,
    o_valid(0) 	=> o_axis_tvalid	,
    o_scale 	=> o_scale
  );

-- Assign outputs.
m_axis_tdata	<= o_axis_tdata;
m_axis_tvalid 	<= o_axis_tvalid;

end rtl;

