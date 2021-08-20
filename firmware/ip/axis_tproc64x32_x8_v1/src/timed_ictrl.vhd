library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Timed-instructions dispatcher control.
--
--  31 .. 0 	: r0
--  63 .. 32	: r1
--  95 .. 64	: r2
-- 127 .. 96	: r3
-- 159 .. 128	: r4
-- 207 .. 160	: t
-- 215 .. 208	: opcode
entity timed_ictrl is
    Port ( 
		-- Clock and reset.
        clk    			: in std_logic;
		rstn			: in std_logic;

		-- Master clock.
		t_cnt			: in unsigned (47 downto 0);

		-- Fifo Time control.
		fifo_rd_en		: out std_logic;
		fifo_dout		: in std_logic_vector (215 downto 0);
		fifo_empty		: in std_logic;

		-- Wait handshake.
		waitt			: out std_logic;
		waitt_ack		: in std_logic;

		-- Output AXIS.
		m_axis_tdata	: out std_logic_vector (159 downto 0);
		m_axis_tvalid	: out std_logic;
		m_axis_tready	: in std_logic
    );
end timed_ictrl;

architecture rtl of timed_ictrl is

type fsm_type is (	READ_ST		,
					WAIT_ST		,
					WAIT_ACK_ST	,
					SETI_ST		,
					SETBI_ST	,
					SET_ST		,
					SETB_ST		);

signal state	: fsm_type;

-- Time of actual instruction.
signal t_inst	: unsigned (47 downto 0);

-- Parameters.
signal p0_i		: std_logic_vector (31 downto 0);
signal p1_i		: std_logic_vector (31 downto 0);
signal p2_i		: std_logic_vector (31 downto 0);
signal p3_i		: std_logic_vector (31 downto 0);
signal p4_i		: std_logic_vector (31 downto 0);

-- Opcode.
signal opcode_i	: std_logic_vector (7 downto 0);

signal rd_en_i	: std_logic;
signal tvalid_i	: std_logic;

-- Wait handshake.
signal waitt_i	: std_logic;

-- Output source.
signal src_i	: std_logic;	-- 0: 32 bits, 1: 128 bits.

-- Zeros.
signal zeros_128: std_logic_vector (127 downto 0) := (others => '0');

begin

-- Time of actual instruction.
t_inst		<= unsigned (fifo_dout(207 downto 160));

-- Parameters.
p0_i		<= fifo_dout(31 downto 0);
p1_i		<= fifo_dout(63 downto 32);
p2_i		<= fifo_dout(95 downto 64);
p3_i		<= fifo_dout(127 downto 96);
p4_i		<= fifo_dout(159 downto 128);

-- Opcode.
opcode_i	<= fifo_dout(215 downto 208);

-- Finite State Machine.
process (clk)
begin
    if ( rising_edge(clk) ) then
		if ( rstn = '0' ) then
			state <= READ_ST;
		else
			case (state) is
				when READ_ST =>
					if ( fifo_empty = '0' ) then
						state <= WAIT_ST;
					end if;
					
				when WAIT_ST =>
					if ( t_inst <= t_cnt ) then
						-- waiti/wait
						if ( opcode_i = "00010101" or opcode_i = "01010100") then
							state <= WAIT_ACK_ST;

						-- seti
						elsif ( opcode_i = "00010011" ) then
							state <= SETI_ST;

						-- setbi
						elsif ( opcode_i = "00011010" ) then
							state <= SETBI_ST;

						-- set
						elsif ( opcode_i = "01010001" ) then
							state <= SET_ST;

						-- setb
						elsif ( opcode_i = "01011000" ) then
							state <= SETB_ST;

						-- Read next word.
						else
							state <= READ_ST;

						end if;
					end if;

				when WAIT_ACK_ST =>
					if ( waitt_ack = '1' ) then
						state <= READ_ST;
					end if;

				when SETI_ST =>
					state <= READ_ST;

				when SETBI_ST =>
					if ( m_axis_tready = '1' ) then
						state <= READ_ST;
					end if;

				when SET_ST =>
					state <= READ_ST;

				when SETB_ST =>
					if ( m_axis_tready = '1' ) then
						state <= READ_ST;
					end if;

			end case;
		end if;
    end if;
end process;

-- Output logic.
process (state)
begin
rd_en_i		<= '0';
tvalid_i	<= '0';
waitt_i		<= '0';
src_i		<= '0';
	case (state) is
		when READ_ST =>
			rd_en_i		<= '1';
			
		when WAIT_ST =>

		when WAIT_ACK_ST =>
			waitt_i		<= '1';

		when SETI_ST =>
			tvalid_i	<= '1';
			src_i		<= '0';

		when SETBI_ST =>
			tvalid_i	<= '1';
			src_i		<= '0';

		when SET_ST =>
			tvalid_i	<= '1';
			src_i		<= '1';

		when SETB_ST =>
			tvalid_i	<= '1';
			src_i		<= '1';
	end case;
end process;

-- Assign outputs.
fifo_rd_en		<= rd_en_i;

waitt			<= waitt_i;

m_axis_tdata	<= 	zeros_128 					& p0_i	when src_i = '0' else
					p4_i & p3_i & p2_i & p1_i 	& p0_i;

m_axis_tvalid	<= tvalid_i;

end rtl;

