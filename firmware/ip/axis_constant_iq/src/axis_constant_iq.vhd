library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_constant_iq is
	Generic
	(
		-- Number of bits of I/Q.
		B	: Integer := 16;
		-- Number of parallel outputs.
		N	: Integer := 4
	);
	Port
	(
		-- AXI-Lite Slave I/F.
		s_axi_aclk	 	: in std_logic;
		s_axi_aresetn	: in std_logic;

		s_axi_awaddr	: in std_logic_vector(5 downto 0);
		s_axi_awprot	: in std_logic_vector(2 downto 0);
		s_axi_awvalid	: in std_logic;
		s_axi_awready	: out std_logic;

		s_axi_wdata	 	: in std_logic_vector(31 downto 0);
		s_axi_wstrb	 	: in std_logic_vector(3 downto 0);
		s_axi_wvalid	: in std_logic;
		s_axi_wready	: out std_logic;

		s_axi_bresp	 	: out std_logic_vector(1 downto 0);
		s_axi_bvalid	: out std_logic;
		s_axi_bready	: in std_logic;

		s_axi_araddr	: in std_logic_vector(5 downto 0);
		s_axi_arprot	: in std_logic_vector(2 downto 0);
		s_axi_arvalid	: in std_logic;
		s_axi_arready	: out std_logic;

		s_axi_rdata	 	: out std_logic_vector(31 downto 0);
		s_axi_rresp	 	: out std_logic_vector(1 downto 0);
		s_axi_rvalid	: out std_logic;
		s_axi_rready	: in std_logic;

		-- AXIS Master I/F.
		m_axis_aclk		: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tdata	: out std_logic_vector(2*B*N-1 downto 0);
		m_axis_tvalid	: out std_logic
	);
end axis_constant_iq;

architecture rtl of axis_constant_iq is

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

-- AXI Slave.
component axi_slv is
	Generic 
	(
		DATA_WIDTH	: integer	:= 32;
		ADDR_WIDTH	: integer	:= 6
	);
	Port 
	(
		aclk		: in std_logic;
		aresetn		: in std_logic;

		-- Write Address Channel.
		awaddr		: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		awprot		: in std_logic_vector(2 downto 0);
		awvalid		: in std_logic;
		awready		: out std_logic;

		-- Write Data Channel.
		wdata		: in std_logic_vector(DATA_WIDTH-1 downto 0);
		wstrb		: in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		wvalid		: in std_logic;
		wready		: out std_logic;

		-- Write Response Channel.
		bresp		: out std_logic_vector(1 downto 0);
		bvalid		: out std_logic;
		bready		: in std_logic;

		-- Read Address Channel.
		araddr		: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		arprot		: in std_logic_vector(2 downto 0);
		arvalid		: in std_logic;
		arready		: out std_logic;

		-- Read Data Channel.
		rdata		: out std_logic_vector(DATA_WIDTH-1 downto 0);
		rresp		: out std_logic_vector(1 downto 0);
		rvalid		: out std_logic;
		rready		: in std_logic;

		-- Registers.
		REAL_REG	: out std_logic_vector (31 downto 0);
		IMAG_REG	: out std_logic_vector (31 downto 0);
		WE_REG		: out std_logic
	);
end component;

-- Number of bits of IQ combined.
constant BIQ : Integer := 2*B;

-- Registers.
signal REAL_REG	: std_logic_vector (31 downto 0);
signal IMAG_REG	: std_logic_vector (31 downto 0);
signal WE_REG	: std_logic;

-- we.
signal we		: std_logic;
signal we_r		: std_logic;
signal we_int	: std_logic;

-- i/q.
signal real_r	: std_logic_vector (B-1 downto 0);
signal imag_r	: std_logic_vector (B-1 downto 0);

begin

-- Synchronizer.
WE_REG_resync_i : synchronizer_n
	port map (
		rstn	    => m_axis_aresetn	,
		clk 		=> m_axis_aclk		,
		data_in		=> WE_REG			,
		data_out	=> we
	);

-- AXI Slave.
axi_slv_i : axi_slv
	Port map
	(
		aclk		=> s_axi_aclk	 	,
		aresetn		=> s_axi_aresetn	,

		-- Write Address Channel.
		awaddr		=> s_axi_awaddr		,
		awprot		=> s_axi_awprot		,
		awvalid		=> s_axi_awvalid	,
		awready		=> s_axi_awready	,

		-- Write Data Channel.
		wdata		=> s_axi_wdata	 	,
		wstrb		=> s_axi_wstrb	 	,
		wvalid		=> s_axi_wvalid		,
		wready		=> s_axi_wready		,

		-- Write Response Channel.
		bresp		=> s_axi_bresp	 	,
		bvalid		=> s_axi_bvalid		,
		bready		=> s_axi_bready		,

		-- Read Address Channel.
		araddr		=> s_axi_araddr		,
		arprot		=> s_axi_arprot		,
		arvalid		=> s_axi_arvalid	,
		arready		=> s_axi_arready	,

		-- Read Data Channel.
		rdata		=> s_axi_rdata	 	,
		rresp		=> s_axi_rresp	 	,
		rvalid		=> s_axi_rvalid		,
		rready		=> s_axi_rready		,

		-- Registers.
		REAL_REG	=> REAL_REG			,
		IMAG_REG	=> IMAG_REG			,
		WE_REG		=> WE_REG
	);

process (m_axis_aclk)
begin
	if (rising_edge(m_axis_aclk)) then
		if ( m_axis_aresetn = '0' ) then
			-- we.
			we_r	<= '0';

			-- i/q.
			real_r	<= (others => '0');
			imag_r	<= (others => '0');
		else
			-- we.
			we_r	<= we;
		
			-- i/q.
			if (we_int = '1') then
				real_r	<= REAL_REG(B-1 downto 0);
				imag_r	<= IMAG_REG(B-1 downto 0);
			end if;
		end if;
	end if;
end process;

-- we generation.
we_int	<= not(we_r) and we;

-- Output generation.
GEN_OUT: for I in 0 to N-1 generate
	m_axis_tdata	(  B + BIQ*I-1 downto BIQ*I		) <= real_r;
	m_axis_tdata	(2*B + BIQ*I-1 downto BIQ*I + B	) <= imag_r;
end generate GEN_OUT;

m_axis_tvalid <= '1';

end rtl;

