library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Declare entity
entity axi_protocol is
	generic(
            G_AXIL_DATA_WIDTH    :integer   := 32;                                          --Width of AXI Lite data bus
            G_AXI_ADDR_WIDTH     :integer   := 32;                                          --Width of AXI Lite Address Bu
            G_AXI_ID_WIDTH       :integer   := 8;                                           --Width of AXI ID Bus
            G_AXI_AWUSER_WIDTH   :integer   := 1                                            --Width of AXI AW User bus
	);
	port(	
			--Master clock & reset
			clk 			 :in std_ulogic;                                            --System clock
			reset			 :in std_ulogic;                                            --System reset, async active low

            --! Master AXIS Interface  
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(7 downto 0);
            m_axis_tvalid : out std_logic;

            --! Slave AXIS Interface
            s_axis_tready : out  std_logic;
            s_axis_tdata  : in std_logic_vector(7 downto 0);
            s_axis_tvalid : in std_logic;
            
            --! AXIL Interface
            --!Write address
            axi_awaddr    : out std_logic_vector(G_AXI_ADDR_WIDTH-1 downto 0);                  
            axi_awprot    : out std_logic_vector(2 downto 0);                   
            axi_awvalid   : out std_logic;
            --!write data
            axi_wdata     : out std_logic_vector(G_AXIL_DATA_WIDTH-1 downto 0);  
            axi_wstrb     : out std_logic_vector(G_AXIL_DATA_WIDTH/8-1 downto 0);
            axi_wvalid    : out std_logic; 
            --!write response
            axi_bready    : out std_logic;
            --!read address
            axi_araddr    : out std_logic_vector(G_AXI_ADDR_WIDTH-1 downto 0);               
            axi_arprot    : out std_logic_vector(2 downto 0);                   
            axi_arvalid   : out std_logic; 
            --!read data
            axi_rready    : out std_logic;    
            --write address
            axi_awready   : in std_logic;
            --write data
            axi_wready    : in std_logic;
            --write response
            axi_bresp     : in std_logic_vector(1 downto 0);                   
            axi_bvalid    : in std_logic;
            --read address
            axi_arready   : in std_logic;
            --read data       
            axi_rdata     : in std_logic_vector(G_AXIL_DATA_WIDTH-1 downto 0);  
            axi_rresp     : in std_logic_vector(1 downto 0);                   
            axi_rvalid    : in std_logic 

		);
		
end entity axi_protocol;

architecture rtl of axi_protocol is 

    constant C_SINGLE_READ            : std_logic_vector(7 downto 0) := x"05";
    constant C_SINGLE_WRITE           : std_logic_vector(7 downto 0) := x"09";

    constant C_NUMB_ADDR_BYTES        : integer := 4;
    constant C_NUMB_LENGTH_BYTES      : integer := 1;
    constant C_NUMB_DATA_BYTES        : integer := 4;
    constant C_NUMB_AXIL_DATA_BYTES   : integer := 4;
    constant C_NUMB_CRC_BYTES         : integer := 4;   
    constant C_MAX_NUMB_BYTES         : integer := 4; -- max number of the above constant for number of bytes 
    constant C_ZERO_PAD               : std_logic_vector(7 downto 0) := (others => '0');
    
    type t_fsm is (idle, address, length, dummy, write_payload, read_payload, crc, write_axil, write_axi, read_axi, read_axil);
    type t_op_fsm is (idle, output, check);
    type t_array is array (0 to 7) of std_logic_vector(31 downto 0);
    type axil_read_fsm is (IDLE, START, CHECK_ADDR_RESP, READ_DATA, DONE);
    type axil_write_fsm is (IDLE, START, CHECK_ADDR_RESP, WRITE_DATA, RESP_READY, CHECK_RESP, DONE);
    signal write_state : axil_write_fsm;
    signal read_state  : axil_read_fsm;

    signal s_current_state : t_fsm;

    signal s_command            : std_logic_vector(7 downto 0);
    signal s_address            : std_logic_vector((C_NUMB_ADDR_BYTES * 8)-1 downto 0);
    signal s_length             : std_logic_vector(7 downto 0);
    signal s_length_axi         : std_logic_vector(7 downto 0);
    signal s_buf_cnt            : unsigned(7 downto 0);
    signal s_byte_pos           : integer range 0 to C_MAX_NUMB_BYTES; 
    signal s_num_bytes          : integer range 0 to C_MAX_NUMB_BYTES; 
    signal s_s_tready           : std_logic;
    signal s_write_buffer       : t_array :=(others=>(others=>'0'));
    signal s_read_buffer        : t_array :=(others=>(others=>'0'));
    signal s_write_buffer_temp  : std_logic_vector(31 downto 0);
    signal s_read_buffer_temp   : std_logic_vector(31 downto 0);

    --axil lite data interface 
    signal s_axil_data          : std_logic_vector(G_AXIL_DATA_WIDTH-1 downto 0);
    signal s_axil_valid         : std_logic;
    signal s_axil_idata         : std_logic_vector(G_AXIL_DATA_WIDTH-1 downto 0);


    --axi mstream 
    signal s_opptr              : unsigned(7 downto 0);
    signal s_start              : std_logic;
    signal s_op_state           : t_op_fsm;
    signal s_op_byte            : integer range 0 to C_MAX_NUMB_BYTES; 
    signal start_read           : std_logic;
    signal start_write          : std_logic;
    signal s_m_axis_tvalid      : std_logic;

begin

    s_axis_tready <= s_s_tready;

FSM : process(clk, reset )
begin 
    if (reset = '0') then 
        start_read  <= '0';
        start_write <= '0';

        s_s_tready  <= '0';
    elsif rising_edge(clk) then
        s_s_tready  <= '1';
        s_start     <= '0';
        start_read  <= '0';
        start_write <= '0';
        case s_current_state is

            when idle => -- to do needs to check the command is valid
                s_buf_cnt           <= (others =>'0');
                if (s_axis_tvalid = '1' and s_s_tready = '1') and 
                    (s_axis_tdata = C_SINGLE_READ  or s_axis_tdata = C_SINGLE_WRITE) then
                        s_s_tready <= '0';
                        s_command <= s_axis_tdata;
                        s_current_state <= address;
                        s_byte_pos <= C_NUMB_ADDR_BYTES;
                end if;

            when address =>
                if s_byte_pos = 0 then
                    s_s_tready <= '0';
                    s_byte_pos <= C_NUMB_LENGTH_BYTES;
                    s_current_state <= length;    
                elsif s_axis_tvalid = '1' and s_s_tready = '1'  then
                    s_address <= s_address(s_address'length-8-1 downto 0) & s_axis_tdata;
                    s_byte_pos <= s_byte_pos - 1;
                    if s_byte_pos = 1 then 
                        s_s_tready <= '0';
                    end if; 
                end if;

            when length => 
                if s_byte_pos = 0 then
                    s_s_tready <= '0';
                    if s_command = C_SINGLE_READ and unsigned(s_length) = 1 then
                        s_current_state <= read_axil; 
                        start_read      <= '1';
                        s_num_bytes     <= C_NUMB_AXIL_DATA_BYTES;
                    elsif s_command = C_SINGLE_WRITE then
                        s_buf_cnt       <= (others =>'0');
                        s_byte_pos      <= C_NUMB_AXIL_DATA_BYTES;
                        s_num_bytes     <= C_NUMB_AXIL_DATA_BYTES;
                        s_current_state <= write_payload;
                    end if;    
                elsif s_axis_tvalid = '1' and s_s_tready = '1'  then
                    s_length            <= s_axis_tdata;
                    s_length_axi        <= std_logic_vector(unsigned(s_axis_tdata)-1);
                    s_byte_pos          <= s_byte_pos - 1;
                    s_s_tready <= '0';
                end if;

            when read_axil =>  
                if s_axil_valid = '1' then 
                    s_start             <= '1';
                    s_read_buffer(0)(G_AXIL_DATA_WIDTH-1 downto 0) <= s_axil_data;
                end if;
                if (read_state = DONE) then
                    s_current_state <= read_payload;
                end if;
            

            when write_payload =>
                if s_buf_cnt = unsigned(s_length) then 
                    s_s_tready <= '0';
                    s_current_state <= write_axil;
                    start_write <= '1';
                else
                    if s_byte_pos = 0 then 
                        s_s_tready <= '0';
                        s_byte_pos <= s_num_bytes;
                        s_write_buffer(to_integer(s_buf_cnt)) <= s_write_buffer_temp;
                        s_buf_cnt <= s_buf_cnt + 1;  
                    elsif (s_axis_tvalid = '1' and s_s_tready = '1')  then
                        s_write_buffer_temp <= s_write_buffer_temp(s_write_buffer_temp'length-8-1 downto 0) & s_axis_tdata;
                        s_byte_pos <= s_byte_pos - 1;  
                        if s_byte_pos = 1 then 
                            s_s_tready <= '0';
                        end if;   
                    end if;
                end if;

            when write_axil =>  
                s_s_tready <= '0';
                s_axil_idata <= s_write_buffer(0);
                if (write_state = DONE) then
                    s_current_state <= idle;
                end if;

            when read_payload =>
                s_current_state <= idle;
            when others => null;
        end case;
    end if;

end process;


m_axis_tvalid <= s_m_axis_tvalid;

process(clk, reset)
begin
    if (reset = '0') then 
        s_m_axis_tvalid      <= '0';
        m_axis_tdata        <= (others =>'0');
        s_opptr             <= (others => '0');
        s_op_byte           <= C_NUMB_AXIL_DATA_BYTES;
    elsif rising_edge(clk) then 
        case s_op_state is  
            when idle => 
                s_m_axis_tvalid <= '0';
                if s_start = '1' then 
                    s_opptr     <= (others => '0');
                    s_read_buffer_temp <= s_read_buffer(0);
                    s_op_byte   <= s_num_bytes;
                    s_op_state  <= output;
                end if;
            when output =>
                if s_opptr = unsigned(s_length) then 
                    s_op_state <= idle;
                    s_m_axis_tvalid <= '0';
                else 
                    s_m_axis_tvalid <= '1';
                    m_axis_tdata <= s_read_buffer_temp(7 downto 0);
                    if s_op_byte = 0 then 
                        s_op_byte   <= s_num_bytes;
                        s_opptr     <= s_opptr + 1;
                        s_m_axis_tvalid <= '0';   
                    elsif m_axis_tready = '1'  then 
                        s_m_axis_tvalid <= '1';                  
                        s_read_buffer_temp <= C_ZERO_PAD & s_read_buffer_temp(s_read_buffer_temp'length-1 downto 8);
                        s_op_byte <= s_op_byte - 1; 
                        s_op_state  <= check;  
                    end if;      
                end if;
            when check =>
                s_m_axis_tvalid <= '0';   
                s_op_state  <= output;
        end case;
    end if;

end process;


process(clk, reset)
begin  

    if (reset = '0') then 
        write_state <= IDLE;

        axi_awaddr  <= (others =>'0');
        axi_awprot  <= (others =>'0');
        axi_awvalid <= '0';
        axi_wdata   <= (others =>'0');
        axi_wstrb   <= (others =>'0');
        axi_wvalid  <= '0';
        axi_bready  <= '0';
    elsif rising_edge(clk) then 
        axi_wstrb   <= (others =>'0');
        case write_state is
            --Send write address
            when IDLE =>
                if start_write = '1' then
                    write_state <= START;
                end if;
            when START =>

                axi_awaddr  <= s_address;
                axi_awprot  <= "010";
                axi_awvalid <= '1';
                axi_wdata   <= s_axil_idata;
                axi_wvalid  <= '1';
                axi_wstrb   <= (others =>'1');
                write_state <= WRITE_DATA;--CHECK_ADDR_RESP;

            --Wait for slave to acknowledge receipt
            when CHECK_ADDR_RESP =>

                if (axi_awready = '1' ) then

                    axi_awaddr  <= (others => '0');
                    axi_awprot  <= (others => '0');
                    axi_awvalid <= '0';

                    write_state <= WRITE_DATA;
                else
                    write_state <= CHECK_ADDR_RESP;
                end if;

            --Send write data
            when WRITE_DATA => 

                if (axi_awready = '1' ) then
                    axi_awaddr  <= (others => '0');
                    axi_awprot  <= (others => '0');
                    axi_awvalid <= '0';
                    axi_wstrb   <= (others =>'0');
                end if;
            
                axi_wdata  <= s_axil_idata;
                axi_wvalid <= '1';
                axi_wstrb   <= (others =>'1');
                if (axi_wready = '1') then     
                    write_state <= RESP_READY;
                else
                    write_state <= WRITE_DATA;
                end if;

            --Set response ready
            when RESP_READY => 
                axi_wstrb   <= (others =>'0'); 
                axi_wvalid <= '0';
                axi_bready <= '1';
                write_state <= CHECK_RESP;

            --Check the response
            when CHECK_RESP =>
                if (axi_bvalid = '1') then
                    axi_bready <= '0';
                    write_state <= DONE;
                end if; 

            --Indicate the transaction has completed
            when DONE =>
                write_state <= IDLE;

            when others =>
                write_state <= START;

        end case;
    end if;
end process;

process(clk, reset)
begin  

    if (reset = '0') then 
        read_state <= IDLE;
        
        axi_araddr  <= (others =>'0');
        axi_arprot  <= (others =>'0');
        axi_arvalid <= '0';
        axi_rready  <= '0';

    elsif rising_edge(clk) then 
case read_state is
    when IDLE =>
        if start_read = '1' then
         read_state <= START;
        end if;
    --Send read address
    when START =>

        axi_araddr  <= s_address;
        axi_arprot  <= "010";
        axi_arvalid <= '1';

        s_axil_valid <= '0';

        read_state <= CHECK_ADDR_RESP;

    --Wait for the slave to acknowledge receipt of the address
    when CHECK_ADDR_RESP =>

        if (axi_arready = '1' ) then

            axi_araddr  <= (others => '0');
            axi_arprot  <= (others => '0');
            axi_arvalid <= '0';

            read_state <= READ_DATA;
        else
            read_state <= CHECK_ADDR_RESP;
        end if;

        s_axil_valid <= '0';

    --Read data from the slave
    when READ_DATA =>

        s_axil_data  <= axi_rdata; 

        if (axi_rvalid = '1') then                   
            s_axil_valid <= '1';
            read_state <= DONE;
        else
            s_axil_valid <= '0';
            read_state <= READ_DATA;
        end if;

        axi_rready <= '1';
                    
    --Indicate the transaction has completed
    when DONE =>

        axi_rready <= '0';
        s_axil_data  <= (others => '0');
        s_axil_valid <= '0';
        read_state <= IDLE;
    
    when others =>
         read_state <= START;

end case;
end if;
end process;

end architecture;