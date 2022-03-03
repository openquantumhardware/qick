library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mr_buffer is
    Generic
    (
		-- Number of memories.
		NM	: Integer := 8;
		-- Address map of each memory.
		N	: Integer := 8;
		-- Data width.
		B	: Integer := 16
    );
    Port
    (
       	-- Trigger.
		trigger				: in std_logic; 

        -- AXI Stream Slave I/F.
        s_axis_aclk	    	: in std_logic;
		s_axis_aresetn  	: in std_logic;        
		s_axis_tready		: out std_logic;
		s_axis_tdata		: in std_logic_vector(NM*B-1 downto 0);
		s_axis_tstrb		: in std_logic_vector((NM*B/8)-1 downto 0);
		s_axis_tlast		: in std_logic;
		s_axis_tvalid		: in std_logic;
        
        -- AXI Stream Master I/F.
        m_axis_aclk	    	: in std_logic;
		m_axis_aresetn  	: in std_logic;        
        m_axis_tvalid   	: out std_logic;
		m_axis_tdata		: out std_logic_vector(B-1 downto 0);
		m_axis_tstrobe  	: out std_logic_vector((B/8)-1 downto 0);
		m_axis_tlast		: out std_logic;
		m_axis_tready		: in std_logic;
        
        -- Registers.
		DW_CAPTURE_REG		: in std_logic;
		DR_START_REG		: in std_logic
		
    );
end mr_buffer;

architecture Behavioral of mr_buffer is

-- Synchronizer.
component synchronizer is 
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

-- Memory.
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

-- Data writer.
component data_writer is
    Generic
    (
		-- Number of memories.
		NM	: Integer := 8;
		-- Address map of each memory.
		N	: Integer := 8;
		-- Data width.
		B	: Integer := 16
    );
    Port
    (
        rstn            : in std_logic;
        clk             : in std_logic;

		-- Trigger.
		trigger			: in std_logic;
        
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
		CAPTURE_REG		: in std_logic
    );
end component;

-- Data reader.
component data_reader is
    Generic
    (
		-- Number of memories.
		NM	: Integer := 8;
		-- Address map of each memory.
		N	: Integer := 8;
		-- Data width.
		B	: Integer := 16
    );
    Port
    (
        -- Reset and clock.
        rstn        		: in std_logic;
        clk         		: in std_logic;
        
        -- Memory I/F.
        mem_en      		: out std_logic;
        mem_we      		: out std_logic;
        mem_addr    		: out std_logic_vector (N-1 downto 0);
        mem_dout    		: in std_logic_vector (NM*B-1 downto 0);
        
        -- Data out.
        dout        		: out std_logic_vector (B-1 downto 0);
        dready      		: in std_logic;
        dvalid      		: out std_logic;
        dlast               : out std_logic;

        -- Registers.
		START_REG			: in std_logic
    );
end component;

-- Re-sync trigger and registers.
signal DW_CAPTURE_REG_resync: std_logic;
signal DR_START_REG_resync	: std_logic;
signal trigger_resync		: std_logic;

-- ena/enb/wea/web.
signal ena      : std_logic_vector (NM-1 downto 0);
signal enb      : std_logic;
signal wea      : std_logic_vector (NM-1 downto 0);
signal web      : std_logic;

-- addra/addrb.
type addr_array_t is array (NM-1 downto 0) of std_logic_vector (N-1 downto 0);
signal addra : addr_array_t;
signal addrb : std_logic_vector (N-1 downto 0);

-- dia/dib/doa/dob/dout.
type di_do_array_t is array (NM-1 downto 0) of std_logic_vector (B-1 downto 0);
signal dia	: di_do_array_t;
signal dib 	: std_logic_vector (B-1 downto 0);
signal doa 	: di_do_array_t;
signal dob 	: di_do_array_t;
signal dout	: std_logic_vector (B-1 downto 0);

-- Concatenated data for reader.
signal dob_c: std_logic_vector (NM*B-1 downto 0);

-- s_axis_tdata.
type tdata_array_t is array (NM-1 downto 0) of std_logic_vector (B-1 downto 0);
signal s_axis_tdata_i  : tdata_array_t;

-- s_axis_tvalid/tready.
signal s_axis_tvalid_i : std_logic_vector (NM-1 downto 0);
signal s_axis_tready_i : std_logic_vector (NM-1 downto 0);

begin

-- DW_CAPTURE_REG_resync.
DW_CAPTURE_REG_resync_i :  synchronizer
	generic map (
		N	=> 2
	)
	port map (
		rstn	 	=> s_axis_aresetn,
		clk 		=> s_axis_aclk,
		data_in		=> DW_CAPTURE_REG,
		data_out	=> DW_CAPTURE_REG_resync
	);

-- DR_START_REG_resync.
DR_START_REG_resync_i :  synchronizer
	generic map (
		N	=> 2
	)
	port map (
		rstn	 	=> m_axis_aresetn,
		clk 		=> m_axis_aclk,
		data_in		=> DR_START_REG,
		data_out	=> DR_START_REG_resync
	);

-- trigger_resync.
trigger_resync_i :  synchronizer
	generic map (
		N	=> 2
	)
	port map (
		rstn	 	=> s_axis_aresetn,
		clk 		=> s_axis_aclk,
		data_in		=> trigger,
		data_out	=> trigger_resync
	);

GEN: for I in 0 to NM-1 generate

    -- Memory instantiation.
    bram_dp_i : bram_dp
    Generic map
    (
        -- Memory address size.
        N       => N,
        -- Data width.
        B       => B
    )
    Port map
    (
        clka    => s_axis_aclk,
        clkb    => m_axis_aclk,
        ena     => ena(I),
        enb     => enb,
        wea     => wea(I),
        web     => web,
        addra   => addra(I),
        addrb   => addrb,
        dia     => dia(I),
        dib     => dib,
        doa     => doa(I),
        dob     => dob(I)
    );
    
	-- Data writer.
	data_writer_i : data_writer
	Generic map
	(
	    -- Number of memories.
	    NM  => NM,
	    -- Address map of each memory.
	    N   => N,
	    -- Data width.
	    B   => B
	)
	Port map
	(
	    rstn            => s_axis_aresetn		,
	    clk             => s_axis_aclk			,

		-- Trigger.
		trigger			=> trigger_resync		,
	    
	    -- AXI Stream I/F.
	    s_axis_tready	=> s_axis_tready_i(I)	,
		s_axis_tdata	=> s_axis_tdata_i(I)	,
		s_axis_tvalid	=> s_axis_tvalid_i(I)	,
		
		-- Memory I/F.
		mem_en          => ena(I)				,
		mem_we          => wea(I)				,
		mem_addr        => addra(I)				,
		mem_di          => dia(I)				,
		
		-- Registers.
		CAPTURE_REG		=> DW_CAPTURE_REG_resync
	);

	-- Input tdata.
	s_axis_tdata_i(I) 	<= s_axis_tdata((I+1)*B-1 downto I*B);
	s_axis_tvalid_i(I)	<= s_axis_tvalid;
	
	-- Concatenate output data for port b.
	dob_c((I+1)*B-1 downto I*B) <= dob(I);

end generate GEN;

-- Data reader instantiation.
data_reader_i : data_reader
Generic map
(
    -- Number of memories.
    NM  => NM,
    -- Memory address size.
    N   => N,
    -- Data width.
    B   => B
)
Port map
(
    -- Reset and clock.
    rstn        		=> m_axis_aresetn,
    clk         		=> m_axis_aclk,
    
    -- Memory I/F.
    mem_en      		=> enb,
    mem_we      		=> web,
    mem_addr    		=> addrb,
    mem_dout    		=> dob_c,
    
    -- Data out.
    dout        		=> m_axis_tdata,
    dready      		=> m_axis_tready,
    dvalid      		=> m_axis_tvalid,
    dlast               => m_axis_tlast,
    
    -- Registers.
    START_REG   		=> DR_START_REG_resync
);

-- Output assignment.
s_axis_tready     <= s_axis_tready_i(0); 
m_axis_tstrobe    <= (others => '1');

end Behavioral;

