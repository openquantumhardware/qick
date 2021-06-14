library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
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
end regfile;

architecture rtl of regfile is

type mem_array_t is array ((2**N-1) downto 0) of std_logic_vector (B-1 downto 0);
signal mem_array	: mem_array_t;

begin

process (clk)
begin
	if ( rising_edge(clk) ) then
		-- Write.
		if ( wen7 = '1' ) then
			mem_array(to_integer(unsigned(addr7)))	<= din7;
		end if;

		-- Read.
		if ( unsigned(addr0) = 0 ) then
			dout0	<= (others => '0');
		else
			dout0	<= mem_array(to_integer(unsigned(addr0)));
		end if;

		if ( unsigned(addr1) = 0 ) then
			dout1	<= (others => '0');
		else
			dout1	<= mem_array(to_integer(unsigned(addr1)));
		end if;

		if ( unsigned(addr2) = 0 ) then
			dout2	<= (others => '0');
		else
			dout2	<= mem_array(to_integer(unsigned(addr2)));
		end if;

		if ( unsigned(addr3) = 0 ) then
			dout3	<= (others => '0');
		else
			dout3	<= mem_array(to_integer(unsigned(addr3)));
		end if;

		if ( unsigned(addr4) = 0 ) then
			dout4	<= (others => '0');
		else
			dout4	<= mem_array(to_integer(unsigned(addr4)));
		end if;

		if ( unsigned(addr5) = 0 ) then
			dout5	<= (others => '0');
		else
			dout5	<= mem_array(to_integer(unsigned(addr5)));
		end if;

		if ( unsigned(addr6) = 0 ) then
			dout6	<= (others => '0');
		else
			dout6	<= mem_array(to_integer(unsigned(addr6)));
		end if;
	end if;
end process;

end rtl;

