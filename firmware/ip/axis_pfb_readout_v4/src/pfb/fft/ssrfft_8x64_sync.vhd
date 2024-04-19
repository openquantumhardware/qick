library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ssrfft_8x64_sync is
	Generic
	(
		NFFT	: Integer := 16;
		SSR		: Integer := 4;
		B		: Integer := 16
	);
    Port
    (
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (2*SSR*B-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

		-- AXIS Master.
		m_axis_tdata	: out std_logic_vector (2*SSR*B-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tvalid	: out std_logic;

		-- Registers.
		SCALE_REG		: in std_logic_vector (31 downto 0);
		QOUT_REG		: in std_logic_vector (31 downto 0)
    );
end entity;

architecture rtl of ssrfft_8x64_sync is

-- Framing.
component framing is
    Generic
    (
		-- SSR and FFT Length.
		NFFT	: Integer := 16;
		SSR		: Integer := 4;

		-- Bits.
		B		: Integer := 16
    );
	Port
	(
		-- Reset and clock.
		aresetn			: in std_logic;
		aclk			: in std_logic;

		-- AXIS Slave.
		s_axis_tdata	: in std_logic_vector (2*SSR*B-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

		-- Synced outputs.
		tdata			: out std_logic_vector (2*SSR*B-1 downto 0);
		tvalid			: out std_logic
	);
end component;

-- TLAST Generator.
component tlast_gen is
    Generic
    (
		-- SSR and FFT Length.
		NFFT	: Integer := 16;
		SSR		: Integer := 4
    );
    Port
    (
        -- Input reset and clock.
        rstn				: in std_logic;
        clk 				: in std_logic;

		-- Input enable.
		en					: in std_logic;

		-- TLAST input/output.
		o_tlast				: out std_logic
    );
end component;

-- SSR FFT 8x64.
component ssr_8x64 is
  port (
	-- Clock signal.
    clk 	: in std_logic;

	-- Input data.
    i_re_0 	: in std_logic_vector( 16-1 downto 0 );
    i_re_1 	: in std_logic_vector( 16-1 downto 0 );
    i_re_2 	: in std_logic_vector( 16-1 downto 0 );
    i_re_3 	: in std_logic_vector( 16-1 downto 0 );
    i_re_4 	: in std_logic_vector( 16-1 downto 0 );
    i_re_5 	: in std_logic_vector( 16-1 downto 0 );
    i_re_6 	: in std_logic_vector( 16-1 downto 0 );
    i_re_7 	: in std_logic_vector( 16-1 downto 0 );
    i_im_0 	: in std_logic_vector( 16-1 downto 0 );
    i_im_1 	: in std_logic_vector( 16-1 downto 0 );
    i_im_2 	: in std_logic_vector( 16-1 downto 0 );
    i_im_3 	: in std_logic_vector( 16-1 downto 0 );
    i_im_4 	: in std_logic_vector( 16-1 downto 0 );
    i_im_5 	: in std_logic_vector( 16-1 downto 0 );
    i_im_6 	: in std_logic_vector( 16-1 downto 0 );
    i_im_7 	: in std_logic_vector( 16-1 downto 0 );
    i_valid : in std_logic_vector( 1-1 downto 0 );
    i_scale : in std_logic_vector( 6-1 downto 0 );

	-- Output data.
    o_re_0 	: out std_logic_vector( 27-1 downto 0 );
    o_re_1 	: out std_logic_vector( 27-1 downto 0 );
    o_re_2 	: out std_logic_vector( 27-1 downto 0 );
    o_re_3 	: out std_logic_vector( 27-1 downto 0 );
    o_re_4 	: out std_logic_vector( 27-1 downto 0 );
    o_re_5 	: out std_logic_vector( 27-1 downto 0 );
    o_re_6 	: out std_logic_vector( 27-1 downto 0 );
    o_re_7 	: out std_logic_vector( 27-1 downto 0 );
    o_im_0 	: out std_logic_vector( 27-1 downto 0 );
    o_im_1 	: out std_logic_vector( 27-1 downto 0 );
    o_im_2 	: out std_logic_vector( 27-1 downto 0 );
    o_im_3 	: out std_logic_vector( 27-1 downto 0 );
    o_im_4 	: out std_logic_vector( 27-1 downto 0 );
    o_im_5 	: out std_logic_vector( 27-1 downto 0 );
    o_im_6 	: out std_logic_vector( 27-1 downto 0 );
    o_im_7 	: out std_logic_vector( 27-1 downto 0 );
    o_valid : out std_logic_vector( 1-1 downto 0 );
    o_scale : out std_logic_vector( 6-1 downto 0 )
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

-- I,Q parts of input.
signal din_i			: std_logic_vector (SSR*B-1 downto 0);
signal din_q			: std_logic_vector (SSR*B-1 downto 0);

-- Framing block signals.
signal framing_tdata	: std_logic_vector (2*SSR*B-1 downto 0);
signal framing_tvalid	: std_logic;

-- FFT scale.
signal o_scale			: std_logic_vector (5 downto 0);

-- FFT output valid/last.
signal o_axis_tvalid	: std_logic;
signal o_axis_tlast		: std_logic;

-- FFT data output.
signal o_axis_tdata		: std_logic_vector (2*SSR*B-1 downto 0);

-- Registers.
signal scale_reg_i		: std_logic_vector (5 downto 0);
signal qout_reg_i		: unsigned (3 downto 0);

begin

-- Registers.
scale_reg_i <= SCALE_REG (5 downto 0);

-- Full-precision output: 27 bits. Required output: 16 bits.
-- Quantization selection from 0 to 11.
qout_reg_i	<= (others => '0') when ( unsigned(QOUT_REG) > to_unsigned(11,QOUT_REG'length) ) else
				unsigned(QOUT_REG(3 downto 0));

-- Input/output data to vector.
GEN: for I in 0 to SSR-1 generate
	-- Input data to vector.
	din_iv(I)	<= framing_tdata(I*2*B+B-1 		downto I*2*B	);
	din_qv(I)	<= framing_tdata(I*2*B+2*B-1	downto I*2*B+B	);

	-- Quantization selection.
	dout_iv(I)	<= dout_ivf(I)(to_integer(qout_reg_i)+B-1 downto to_integer(qout_reg_i));
	dout_qv(I)	<= dout_qvf(I)(to_integer(qout_reg_i)+B-1 downto to_integer(qout_reg_i));

	-- Output data to vector.
	o_axis_tdata(I*2*B+B-1 		downto I*2*B	) <= dout_iv(I);
	o_axis_tdata(I*2*B+2*B-1 	downto I*2*B+B	) <= dout_qv(I);
end generate GEN;

-- Framing.
framing_i : framing
    Generic map
    (
		-- SSR and FFT Length.
		NFFT	=> NFFT	,
		SSR		=> SSR	,

		-- Bits.
		B		=> B
    )
	Port map
	(
		-- Reset and clock.
		aresetn			=> aresetn			,
		aclk			=> aclk				,

		-- AXIS Slave.
		s_axis_tdata	=> s_axis_tdata		,
		s_axis_tlast	=> s_axis_tlast		,
		s_axis_tvalid	=> s_axis_tvalid	,

		-- Synced outputs.
		tdata			=> framing_tdata	,
		tvalid			=> framing_tvalid
	);

-- TLAST Generator.
tlast_gen_i : tlast_gen
    Generic map
    (
		-- SSR and FFT Length.
		NFFT	=> NFFT	,
		SSR		=> SSR
    )
    Port map
    (
        -- Input reset and clock.
        rstn	=> aresetn			,
        clk 	=> aclk				,

		-- Input enable.
		en		=> o_axis_tvalid	,

		-- TLAST input/output.
		o_tlast	=> o_axis_tlast
    );

-- SSR FFT 8x1024.
ssr_8x64_i : ssr_8x64
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
    i_valid(0) 	=> framing_tvalid	,
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
m_axis_tlast 	<= o_axis_tlast;
m_axis_tvalid 	<= o_axis_tvalid;

end rtl;

