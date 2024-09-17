library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_slv_qproc is
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
        TPROC_CTRL       : out std_logic_vector (15 downto 0) ; -- Register AUTORESET
        TPROC_CFG        : out std_logic_vector (15 downto 0) ;
        MEM_ADDR         : out std_logic_vector (15 downto 0) ;
        MEM_LEN          : out std_logic_vector (15 downto 0) ;
        MEM_DT_I         : out std_logic_vector (31 downto 0) ;
        TPROC_W_DT1      : out std_logic_vector (31 downto 0) ;
        TPROC_W_DT2      : out std_logic_vector (31 downto 0) ;
        CORE_CFG         : out std_logic_vector (7 downto 0) ;
        READ_SEL         : out std_logic_vector (7 downto 0) ;
        MEM_DT_O         : in  std_logic_vector (31 downto 0) ;
        TPROC_R_DT1      : in  std_logic_vector (31 downto 0) ;
        TPROC_R_DT2      : in  std_logic_vector (31 downto 0) ;
        TIME_USR         : in  std_logic_vector (31 downto 0) ;
        TPROC_STATUS     : in  std_logic_vector (31 downto 0) ;
        TPROC_DEBUG      : in  std_logic_vector (31 downto 0) );
        end axi_slv_qproc;

architecture rtl of axi_slv_qproc is

	-- AXI4LITE signals
	signal axi_awaddr	: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB  : integer := (DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 3;
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	---- Number of Slave Registers 16
	signal slv_reg0	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg1	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg2	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg3	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg4	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg5	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg6	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg7	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg8	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg9	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg10	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg11	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg12	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg13	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg14	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg15	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;
	signal aw_en	: std_logic;

begin
	-- I/O Connections assignments

	awreadY	<= axi_awready;
	wready	<= axi_wready;
	bresp	<= axi_bresp;
	bvalid	<= axi_bvalid;
	arreadY	<= axi_arready;
	rdata	<= axi_rdata;
	rresp	<= axi_rresp;
	rvalid	<= axi_rvalid;
	-- Implement axi_awready generation
	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	-- de-asserted when reset is low.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and awvalid = '1' and wvalid = '1' and aw_en = '1') then
	        -- slave is ready to accept write address when
	        -- there is a valid write address and write data
	        -- on the write address and data bus. This design 
	        -- expects no outstanding transactions. 
	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (bready = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- Implement axi_awaddr latching
	-- This process is used to latch the address when both 
	-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and awvalid = '1' and wvalid = '1' and aw_en = '1') then
	        -- Write Address latching
	        axi_awaddr <= awaddr;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_wready generation
	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	-- de-asserted when reset is low. 

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and wvalid = '1' and awvalid = '1' and aw_en = '1') then
	          -- slave is ready to accept write data when 
	          -- there is a valid write address and write data
	          -- on the write address and data bus. This design 
	          -- expects no outstanding transactions.           
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	-- The write data is accepted and written to memory mapped registers when
	-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	-- select byte enables of slave registers while writing.
	-- These registers are cleared when reset (active low) is applied.
	-- Slave register write enable is asserted when valid address and data are available
	-- and the slave is ready to accept the write address and write data.
	slv_reg_wren <= axi_wready and wvalid and axi_awready and awvalid ;

	process (aclk)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      slv_reg0 <= (others => '0');
	      slv_reg1 <= (others => '0');
	      slv_reg2 <= (others => '0');
	      slv_reg3 <= (others => '0');
	      slv_reg4 <= (others => '0');
	      slv_reg5 <= (others => '0');
	      slv_reg6 <= (others => '0');
	      slv_reg7 <= (others => '0');
	      slv_reg8 <= (others => '0');
	      slv_reg9 <= (others => '0');
	      slv_reg10 <= (others => '0');
	      slv_reg11 <= (others => '0');
	      slv_reg12 <= (others => '0');
	      slv_reg13 <= (others => '0');
	      slv_reg14 <= (others => '0');
	      slv_reg15 <= (others => '0');
	    else
	      loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
         -- Reset 
         if (unsigned(slv_reg0) /= 0) then slv_reg0 <= (others => '0'); end if;
         if (slv_reg_wren = '1') then
	        case loc_addr is
	          when b"0000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 0
	                slv_reg0(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 1
	                slv_reg1(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 2
	                slv_reg2(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 3
	                slv_reg3(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 4
	                slv_reg4(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 5
	                slv_reg5(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 6
	                slv_reg6(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"0111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 7
	                slv_reg7(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 8
	                slv_reg8(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 9
	                slv_reg9(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 10
	                slv_reg10(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 11
	                slv_reg11(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 12
	                slv_reg12(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 13
	                slv_reg13(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 14
	                slv_reg14(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"1111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 15
	                slv_reg15(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when others =>
	            slv_reg0 <= slv_reg0;
	            slv_reg1 <= slv_reg1;
	            slv_reg2 <= slv_reg2;
	            slv_reg3 <= slv_reg3;
	            slv_reg4 <= slv_reg4;
	            slv_reg5 <= slv_reg5;
	            slv_reg6 <= slv_reg6;
	            slv_reg7 <= slv_reg7;
	            slv_reg8 <= slv_reg8;
	            slv_reg9 <= slv_reg9;
	            slv_reg10 <= slv_reg10;
	            slv_reg11 <= slv_reg11;
	            slv_reg12 <= slv_reg12;
	            slv_reg13 <= slv_reg13;
	            slv_reg14 <= slv_reg14;
	            slv_reg15 <= slv_reg15;
	        end case;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement write response logic generation
	-- The write response and response valid signals are asserted by the slave 
	-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	-- This marks the acceptance of address and indicates the status of 
	-- write transaction.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00"; --need to work more on the responses
	    else
	      if (axi_awready = '1' and awvalid = '1' and axi_wready = '1' and wvalid = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (bready = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arready generation
	-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
	-- S_AXI_ARVALID is asserted. axi_awready is 
	-- de-asserted when reset (active low) is asserted. 
	-- The read address is also latched when S_AXI_ARVALID is 
	-- asserted. axi_araddr is reset to zero on reset assertion.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and arvalid = '1') then
	        -- indicates that the slave has acceped the valid read address
	        axi_arready <= '1';
	        -- Read Address latching 
	        axi_araddr  <= araddr;           
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arvalid generation
	-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	-- data are available on the axi_rdata bus at this instance. The 
	-- assertion of axi_rvalid marks the validity of read data on the 
	-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
	-- cleared to zero on reset (active low).  
	process (aclk)
	begin
	  if rising_edge(aclk) then
	    if aresetn = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and arvalid = '1' and axi_rvalid = '0') then
	        -- Valid read data is available at the read data bus
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
	      elsif (axi_rvalid = '1' and rready = '1') then
	        -- Read data is accepted by the master
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	-- Implement memory mapped register select and read logic generation
	-- Slave register read enable is asserted when valid address is available
	-- and the slave is ready to accept the read address.
	slv_reg_rden <= axi_arready and arvalid and (not axi_rvalid) ;

	-- 4 : TAVG_LOW_REG	(r).
	-- 5 : TAVG_HIGH_REG(r).

	process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8, MEM_DT_O, TPROC_R_DT1, TPROC_R_DT2, TIME_USR, TPROC_STATUS, TPROC_DEBUG, axi_araddr, aresetn, slv_reg_rden)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
	    -- Address decoding for reading registers
	    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	    case loc_addr is
	      when b"0000" =>
	        reg_data_out <= slv_reg0;
	      when b"0001" =>
	        reg_data_out <= slv_reg1;
	      when b"0010" =>
	        reg_data_out <= slv_reg2;
	      when b"0011" =>
	        reg_data_out <= slv_reg3;
	      when b"0100" =>
	        reg_data_out <= slv_reg4;
	      when b"0101" =>
	        reg_data_out <= slv_reg5;
	      when b"0110" =>
	        reg_data_out <= slv_reg6;
	      when b"0111" =>
	        reg_data_out <= slv_reg7;
	      when b"1000" =>
	        reg_data_out <= slv_reg8;
	      when b"1001" =>
	        reg_data_out <= "00000000000000000000000000001001";
	      when b"1010" =>
	        reg_data_out <= MEM_DT_O;
	      when b"1011" =>
	        reg_data_out <= TPROC_R_DT1;
	      when b"1100" =>
	        reg_data_out <= TPROC_R_DT2;
	      when b"1101" =>
	        reg_data_out <= TIME_USR;
	      when b"1110" =>
	        reg_data_out <= TPROC_STATUS;
	      when b"1111" =>
	        reg_data_out <= TPROC_DEBUG;
	      when others =>
	        reg_data_out  <= (others => '0');
	    end case;
	end process; 

	-- Output register or memory read data
	process( aclk ) is
	begin
	  if (rising_edge (aclk)) then
	    if ( aresetn = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	        -- When there is a valid read address (S_AXI_ARVALID) with 
	        -- acceptance of read address by the slave (axi_arready), 
	        -- output the read dada 
	        -- Read address mux
	          axi_rdata <= reg_data_out;     -- register read data
	      end if;   
	    end if;
	  end if;
	end process;

-- Output Registers.
TPROC_CTRL        <= slv_reg0(15 downto 0);
TPROC_CFG         <= slv_reg1(15 downto 0);
MEM_ADDR          <= slv_reg2(15 downto 0);
MEM_LEN           <= slv_reg3(15 downto 0);
MEM_DT_I          <= slv_reg4(31 downto 0);
TPROC_W_DT1       <= slv_reg5(31 downto 0);
TPROC_W_DT2       <= slv_reg6(31 downto 0);
CORE_CFG          <= slv_reg7(7 downto 0);
READ_SEL          <= slv_reg8(7 downto 0);


end rtl;
