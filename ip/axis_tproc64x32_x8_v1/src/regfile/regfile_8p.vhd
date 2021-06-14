library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Regfile block.
--
-- 7 registers can be read in parallel. One clock cycle latency.
-- 1 register can be written.
-- 8 pages allow 32x8 = 256 total registers.
-- In any page, reading register 0 gives 0.

entity regfile_8p is
    Generic (
        -- Data width.
        B	: Integer := 16
    );
    Port ( 
		-- Clock and reset.
        clk    	: in std_logic;
		rstn	: in std_logic;

		-- Read address.
        addr0	: in std_logic_vector (4 downto 0);
		addr1	: in std_logic_vector (4 downto 0);
        addr2	: in std_logic_vector (4 downto 0);
		addr3	: in std_logic_vector (4 downto 0);
		addr4	: in std_logic_vector (4 downto 0);
		addr5	: in std_logic_vector (4 downto 0);
		addr6	: in std_logic_vector (4 downto 0);

		-- Write address.
		addr7	: in std_logic_vector (4 downto 0);

		-- Write data.
		din7	: in std_logic_vector (B-1 downto 0);
		wen7	: in std_logic;

		-- Page number.
		pnum	: in std_logic_vector (2 downto 0);

		-- Output registers.
		dout0	: out std_logic_vector (B-1 downto 0);
		dout1	: out std_logic_vector (B-1 downto 0);
		dout2	: out std_logic_vector (B-1 downto 0);
		dout3	: out std_logic_vector (B-1 downto 0);
		dout4	: out std_logic_vector (B-1 downto 0);
		dout5	: out std_logic_vector (B-1 downto 0);
		dout6	: out std_logic_vector (B-1 downto 0)
    );
end regfile_8p;

architecture rtl of regfile_8p is

constant N	: Integer := 5;

-- Register file.
component regfile is
    Generic (
        -- Data width.
        B   : Integer := 16;
		-- Map size.
		N	: Integer := 4
    );
    Port ( 
		-- Clock.
        clk    	: in std_logic;

		-- Read address.
        addr0	: in std_logic_vector (N-1 downto 0);
		addr1	: in std_logic_vector (N-1 downto 0);
        addr2	: in std_logic_vector (N-1 downto 0);
		addr3	: in std_logic_vector (N-1 downto 0);
		addr4	: in std_logic_vector (N-1 downto 0);
		addr5	: in std_logic_vector (N-1 downto 0);
		addr6	: in std_logic_vector (N-1 downto 0);

		-- Write address.
		addr7	: in std_logic_vector (N-1 downto 0);

		-- Write data.
		din7	: in std_logic_vector (B-1 downto 0);
		wen7	: in std_logic;

		-- Output registers.
		dout0	: out std_logic_vector (B-1 downto 0);
		dout1	: out std_logic_vector (B-1 downto 0);
		dout2	: out std_logic_vector (B-1 downto 0);
		dout3	: out std_logic_vector (B-1 downto 0);
		dout4	: out std_logic_vector (B-1 downto 0);
		dout5	: out std_logic_vector (B-1 downto 0);
		dout6	: out std_logic_vector (B-1 downto 0)
    );
end component;

-- Regfile 0.
signal wen7_0	: std_logic;
signal dout0_0	: std_logic_vector (B-1 downto 0);
signal dout1_0	: std_logic_vector (B-1 downto 0);
signal dout2_0	: std_logic_vector (B-1 downto 0);
signal dout3_0	: std_logic_vector (B-1 downto 0);
signal dout4_0	: std_logic_vector (B-1 downto 0);
signal dout5_0	: std_logic_vector (B-1 downto 0);
signal dout6_0	: std_logic_vector (B-1 downto 0);

-- Regfile 1.
signal wen7_1	: std_logic;
signal dout0_1	: std_logic_vector (B-1 downto 0);
signal dout1_1	: std_logic_vector (B-1 downto 0);
signal dout2_1	: std_logic_vector (B-1 downto 0);
signal dout3_1	: std_logic_vector (B-1 downto 0);
signal dout4_1	: std_logic_vector (B-1 downto 0);
signal dout5_1	: std_logic_vector (B-1 downto 0);
signal dout6_1	: std_logic_vector (B-1 downto 0);

-- Regfile 2.
signal wen7_2	: std_logic;
signal dout0_2	: std_logic_vector (B-1 downto 0);
signal dout1_2	: std_logic_vector (B-1 downto 0);
signal dout2_2	: std_logic_vector (B-1 downto 0);
signal dout3_2	: std_logic_vector (B-1 downto 0);
signal dout4_2	: std_logic_vector (B-1 downto 0);
signal dout5_2	: std_logic_vector (B-1 downto 0);
signal dout6_2	: std_logic_vector (B-1 downto 0);

-- Regfile 3.
signal wen7_3	: std_logic;
signal dout0_3	: std_logic_vector (B-1 downto 0);
signal dout1_3	: std_logic_vector (B-1 downto 0);
signal dout2_3	: std_logic_vector (B-1 downto 0);
signal dout3_3	: std_logic_vector (B-1 downto 0);
signal dout4_3	: std_logic_vector (B-1 downto 0);
signal dout5_3	: std_logic_vector (B-1 downto 0);
signal dout6_3	: std_logic_vector (B-1 downto 0);

-- Regfile 4.
signal wen7_4	: std_logic;
signal dout0_4	: std_logic_vector (B-1 downto 0);
signal dout1_4	: std_logic_vector (B-1 downto 0);
signal dout2_4	: std_logic_vector (B-1 downto 0);
signal dout3_4	: std_logic_vector (B-1 downto 0);
signal dout4_4	: std_logic_vector (B-1 downto 0);
signal dout5_4	: std_logic_vector (B-1 downto 0);
signal dout6_4	: std_logic_vector (B-1 downto 0);

-- Regfile 5.
signal wen7_5	: std_logic;
signal dout0_5	: std_logic_vector (B-1 downto 0);
signal dout1_5	: std_logic_vector (B-1 downto 0);
signal dout2_5	: std_logic_vector (B-1 downto 0);
signal dout3_5	: std_logic_vector (B-1 downto 0);
signal dout4_5	: std_logic_vector (B-1 downto 0);
signal dout5_5	: std_logic_vector (B-1 downto 0);
signal dout6_5	: std_logic_vector (B-1 downto 0);

-- Regfile 6.
signal wen7_6	: std_logic;
signal dout0_6	: std_logic_vector (B-1 downto 0);
signal dout1_6	: std_logic_vector (B-1 downto 0);
signal dout2_6	: std_logic_vector (B-1 downto 0);
signal dout3_6	: std_logic_vector (B-1 downto 0);
signal dout4_6	: std_logic_vector (B-1 downto 0);
signal dout5_6	: std_logic_vector (B-1 downto 0);
signal dout6_6	: std_logic_vector (B-1 downto 0);

-- Regfile 7.
signal wen7_7	: std_logic;
signal dout0_7	: std_logic_vector (B-1 downto 0);
signal dout1_7	: std_logic_vector (B-1 downto 0);
signal dout2_7	: std_logic_vector (B-1 downto 0);
signal dout3_7	: std_logic_vector (B-1 downto 0);
signal dout4_7	: std_logic_vector (B-1 downto 0);
signal dout5_7	: std_logic_vector (B-1 downto 0);
signal dout6_7	: std_logic_vector (B-1 downto 0);

-- Muxed output data.
signal dout0_i	: std_logic_vector (B-1 downto 0);
signal dout1_i	: std_logic_vector (B-1 downto 0);
signal dout2_i	: std_logic_vector (B-1 downto 0);
signal dout3_i	: std_logic_vector (B-1 downto 0);
signal dout4_i	: std_logic_vector (B-1 downto 0);
signal dout5_i	: std_logic_vector (B-1 downto 0);
signal dout6_i	: std_logic_vector (B-1 downto 0);

-- Pipe on page selection.
signal pnum_r	: std_logic_vector (2 downto 0);

begin

-- Register file 0.
regfile_0_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_0	,

		-- Output registers.
		dout0	=> dout0_0	,
		dout1	=> dout1_0	,
		dout2	=> dout2_0	,
		dout3	=> dout3_0	,
		dout4	=> dout4_0	,
		dout5	=> dout5_0	,
		dout6	=> dout6_0
    );

-- Register file 1.
regfile_1_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_1	,

		-- Output registers.
		dout0	=> dout0_1	,
		dout1	=> dout1_1	,
		dout2	=> dout2_1	,
		dout3	=> dout3_1	,
		dout4	=> dout4_1	,
		dout5	=> dout5_1	,
		dout6	=> dout6_1
    );

-- Register file 2.
regfile_2_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_2	,

		-- Output registers.
		dout0	=> dout0_2	,
		dout1	=> dout1_2	,
		dout2	=> dout2_2	,
		dout3	=> dout3_2	,
		dout4	=> dout4_2	,
		dout5	=> dout5_2	,
		dout6	=> dout6_2
    );

-- Register file 3.
regfile_3_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_3	,

		-- Output registers.
		dout0	=> dout0_3	,
		dout1	=> dout1_3	,
		dout2	=> dout2_3	,
		dout3	=> dout3_3	,
		dout4	=> dout4_3	,
		dout5	=> dout5_3	,
		dout6	=> dout6_3
    );

-- Register file 4.
regfile_4_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_4	,

		-- Output registers.
		dout0	=> dout0_4	,
		dout1	=> dout1_4	,
		dout2	=> dout2_4	,
		dout3	=> dout3_4	,
		dout4	=> dout4_4	,
		dout5	=> dout5_4	,
		dout6	=> dout6_4
    );

-- Register file 5.
regfile_5_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_5	,

		-- Output registers.
		dout0	=> dout0_5	,
		dout1	=> dout1_5	,
		dout2	=> dout2_5	,
		dout3	=> dout3_5	,
		dout4	=> dout4_5	,
		dout5	=> dout5_5	,
		dout6	=> dout6_5
    );

-- Register file 6.
regfile_6_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_6	,

		-- Output registers.
		dout0	=> dout0_6	,
		dout1	=> dout1_6	,
		dout2	=> dout2_6	,
		dout3	=> dout3_6	,
		dout4	=> dout4_6	,
		dout5	=> dout5_6	,
		dout6	=> dout6_6
    );

-- Register file 7.
regfile_7_i : regfile
    Generic map (
        -- Data width.
        B   => B 	,
		-- Map size.
		N	=> N
    )
    Port map ( 
		-- Clock.
        clk    	=> clk		,

		-- Read address.
        addr0	=> addr0	,
		addr1	=> addr1	,
        addr2	=> addr2	,
		addr3	=> addr3	,
		addr4	=> addr4	,
		addr5	=> addr5	,
		addr6	=> addr6	,

		-- Write address.
		addr7	=> addr7	,

		-- Write data.
		din7	=> din7		,
		wen7	=> wen7_7	,

		-- Output registers.
		dout0	=> dout0_7	,
		dout1	=> dout1_7	,
		dout2	=> dout2_7	,
		dout3	=> dout3_7	,
		dout4	=> dout4_7	,
		dout5	=> dout5_7	,
		dout6	=> dout6_7
    );


-- Registers.
process (clk)
begin
	if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			-- Pipe on page selection.
			pnum_r	<= (others => '0');
		else
			-- Pipe on page selection.
			pnum_r	<= pnum;
		end if;
	end if;
end process;

-- Muxed write enable signals.
wen7_0	<= wen7 when pnum = "000" else '0';
wen7_1	<= wen7 when pnum = "001" else '0';
wen7_2	<= wen7 when pnum = "010" else '0';
wen7_3	<= wen7 when pnum = "011" else '0';
wen7_4	<= wen7 when pnum = "100" else '0';
wen7_5	<= wen7 when pnum = "101" else '0';
wen7_6	<= wen7 when pnum = "110" else '0';
wen7_7	<= wen7 when pnum = "111" else '0';

-- Muxed output data.
dout0_i	<= 	dout0_0 when pnum_r = "000" else
			dout0_1 when pnum_r = "001" else
			dout0_2 when pnum_r = "010" else
			dout0_3	when pnum_r = "011" else
			dout0_4	when pnum_r = "100" else
			dout0_5	when pnum_r = "101" else
			dout0_6	when pnum_r = "110" else
			dout0_7;

dout1_i	<= 	dout1_0 when pnum_r = "000" else
			dout1_1 when pnum_r = "001" else
			dout1_2 when pnum_r = "010" else
			dout1_3	when pnum_r = "011" else
			dout1_4	when pnum_r = "100" else
			dout1_5	when pnum_r = "101" else
			dout1_6	when pnum_r = "110" else
			dout1_7;

dout2_i	<= 	dout2_0 when pnum_r = "000" else
			dout2_1 when pnum_r = "001" else
			dout2_2 when pnum_r = "010" else
			dout2_3	when pnum_r = "011" else
			dout2_4	when pnum_r = "100" else
			dout2_5	when pnum_r = "101" else
			dout2_6	when pnum_r = "110" else
			dout2_7;

dout3_i	<= 	dout3_0 when pnum_r = "000" else
			dout3_1 when pnum_r = "001" else
			dout3_2 when pnum_r = "010" else
			dout3_3	when pnum_r = "011" else
			dout3_4	when pnum_r = "100" else
			dout3_5	when pnum_r = "101" else
			dout3_6	when pnum_r = "110" else
			dout3_7;

dout4_i	<= 	dout4_0 when pnum_r = "000" else
			dout4_1 when pnum_r = "001" else
			dout4_2 when pnum_r = "010" else
			dout4_3	when pnum_r = "011" else
			dout4_4	when pnum_r = "100" else
			dout4_5	when pnum_r = "101" else
			dout4_6	when pnum_r = "110" else
			dout4_7;

dout5_i	<= 	dout5_0 when pnum_r = "000" else
			dout5_1 when pnum_r = "001" else
			dout5_2 when pnum_r = "010" else
			dout5_3	when pnum_r = "011" else
			dout5_4	when pnum_r = "100" else
			dout5_5	when pnum_r = "101" else
			dout5_6	when pnum_r = "110" else
			dout5_7;

dout6_i	<= 	dout6_0 when pnum_r = "000" else
			dout6_1 when pnum_r = "001" else
			dout6_2 when pnum_r = "010" else
			dout6_3	when pnum_r = "011" else
			dout6_4	when pnum_r = "100" else
			dout6_5	when pnum_r = "101" else
			dout6_6	when pnum_r = "110" else
			dout6_7;

-- Assign outputs.
dout0	<= dout0_i;
dout1	<= dout1_i;
dout2	<= dout2_i;
dout3	<= dout3_i;
dout4	<= dout4_i;
dout5	<= dout5_i;
dout6	<= dout6_i;

end rtl;

