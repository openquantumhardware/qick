library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.pfb_ctrl_pkg.ALL;

entity pfb_ctrl is
    Generic (
        -- Number of channels.
        N : Integer := 8
    );
    Port (
        aresetn					: in std_logic;
        aclk     				: in std_logic;

        -- M_AXIS for Configuration.
        m_axis_config_tvalid 	: out std_logic;
        m_axis_config_tready	: in std_logic;
        m_axis_config_tlast  	: out std_logic;
        m_axis_config_tdata  	: out std_logic_vector (7 downto 0);
        
        -- Filter config.
        cfg_en					: in std_logic;
        
        -- Framing.
		tready					: in std_logic;
		tvalid					: in std_logic;
		fr_sync					: in std_logic;
        fr_out  				: out std_logic
        );
end pfb_ctrl;

architecture rtl of pfb_ctrl is

-- PFB configuration.
component pfb_cfg is
    Generic (
        -- Number of channels.
        N : Integer := 8
    );
    Port (
        -- Reset and clock. 
        rstn    : in std_logic;
        clk     : in std_logic;
        
        -- Filter config.
        cfg_en  : in std_logic;
        tready  : in std_logic;
        tvalid  : out std_logic;
        tlast   : out std_logic;
        tdata   : out std_logic_vector (f_nbit_axis(N)-1 downto 0)
        );
end component;

-- PFB framing.
component pfb_framing is
    Generic (
        -- Number of channels.
        N : Integer := 8
    );
    Port (
        -- Reset and clock. 
        rstn    : in std_logic;
        clk     : in std_logic;
        
        -- Framing.
		tready	: in std_logic;
		tvalid	: in std_logic;
		fr_sync	: in std_logic;
        fr_out  : out std_logic
        );
end component;

begin

-- PFB configuration.
cfg_i : pfb_cfg
    Generic map (
        -- Number of channels.
        N => N
    )
    Port map (
        -- Reset and clock. 
        rstn    => aresetn					,
        clk     => aclk						,
        
        -- Filter config.
        cfg_en  => cfg_en  					,
        tready  => m_axis_config_tready  	,
        tvalid  => m_axis_config_tvalid  	,
        tlast   => m_axis_config_tlast   	,
        tdata   => m_axis_config_tdata
	);

-- PFB framing.
framing_i : pfb_framing
    Generic map (
        -- Number of channels.
        N => N
    )
    Port map (
        -- Reset and clock. 
        rstn    => aresetn	,
        clk     => aclk		,  
        
        -- Framing.
		tready	=> tready	,
		tvalid	=> tvalid	,
		fr_sync	=> fr_sync	,
        fr_out  => fr_out
	);

end rtl;

