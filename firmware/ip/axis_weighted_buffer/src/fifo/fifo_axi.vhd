library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_axi is
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
end fifo_axi;

architecture rtl of fifo_axi is

-- FIFO.
component fifo is
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

-- FIFO read to AXI adapter.
component rd2axi is
    Generic
    (
        -- Data width.
        B : Integer := 16
    );
    Port
    ( 
        rstn		: in std_logic;
        clk 		: in std_logic;

        -- FIFO Read I/F.
        fifo_rd_en 	: out std_logic;
        fifo_dout  	: in std_logic_vector (B-1 downto 0);
        fifo_empty  : in std_logic;
        
        -- Read I/F.
        rd_en 		: in std_logic;
        dout  		: out std_logic_vector (B-1 downto 0);
        empty  		: out std_logic
    );
end component;

signal rd_en_i  : std_logic;
signal dout_i   : std_logic_vector (B-1 downto 0);     
signal empty_i  : std_logic;

begin

-- FIFO.
fifo_i : fifo
    Generic map
    (
        -- Data width.
        B => B,
        
        -- Fifo depth.
        N => N
    )
    Port map
    ( 
        rstn	=> rstn		,
        clk 	=> clk 		,

        -- Write I/F.
        wr_en  	=> wr_en  	,
        din     => din     	,
        
        -- Read I/F.
        rd_en  	=> rd_en_i	,
        dout   	=> dout_i	,
        
        -- Flags.
        full    => full		,
        empty   => empty_i
    );

-- FIFO read to AXI adapter.
rd2axi_i : rd2axi
    Generic map
    (
        -- Data width.
        B => B
    )
    Port map
    ( 
        rstn		=> rstn		,
        clk 		=> clk		,

        -- FIFO Read I/F.
        fifo_rd_en 	=> rd_en_i	,
        fifo_dout  	=> dout_i	,
        fifo_empty  => empty_i	,
        
        -- Read I/F.
        rd_en 		=> rd_en	,
        dout  		=> dout		,
        empty  		=> empty	
    );

end rtl;

