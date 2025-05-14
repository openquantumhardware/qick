module axi_lite_slave #(
    parameter integer C_S_AXI_ADDR_WIDTH = 6, // Address width.  Adjust as needed.
    parameter integer C_S_AXI_DATA_WIDTH = 32  // Data width (32 or 64).
) (
    input  logic                            clk,          // System clock
    input  logic                            reset_n,      // Active-low reset
    // Write address channel signals
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,   // Write address
    input  logic                            s_axi_awvalid,  // Write address valid
    output logic                            s_axi_awready,  // Write address ready
    // Write data channel signals
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   s_axi_wdata,    // Write data
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,    // Write strobes
    input  logic                            s_axi_wvalid,   // Write data valid
    output logic                            s_axi_wready,   // Write data ready
    // Write response channel signals
    output logic [1:0]                      s_axi_bresp,    // Write response
    output logic                            s_axi_bvalid,   // Write response valid
    input  logic                            s_axi_bready,   // Write response ready
    // Read address channel signals
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,   // Read address
    input  logic                            s_axi_arvalid,  // Read address valid
    output logic                            s_axi_arready,  // Read address ready
    // Read data channel signals
    output logic [C_S_AXI_DATA_WIDTH-1:0]   s_axi_rdata,    // Read data
    output logic [1:0]                      s_axi_rresp,    // Read response
    output logic                            s_axi_rvalid,   // Read data valid
    input  logic                            s_axi_rready    // Read data ready
    // Registers.
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_xcom_ctrl,    //out std_logic_vector ( 5 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_xcom_cfg,     //out std_logic_vector ( 3 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_dt1,      //out std_logic_vector (31 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_dt2,      //out std_logic_vector (31 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_addr,     //out std_logic_vector ( 3 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_board_id,     //in  std_logic_vector ( 3 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_flag,    //in  std_logic ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_dt1,     //in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_dt2,     //in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_mem,     //in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_rx_dt,   //in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_tx_dt,   //in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_status,  //in  std_logic_vector (28 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_debug    //in  std_logic_vector (31 downto 0) );
);

    //-------------------------------------------------------------------------
    // Local parameters
    //-------------------------------------------------------------------------

    // Example: Define the memory map for this slave.  Start at address 0.
    localparam integer REG_OFFSET_0  = 0;       // Example register 0 offset
    localparam integer REG_OFFSET_1  = 4;       // Example register 1 offset
    localparam integer REG_OFFSET_2  = 8;
    localparam integer REG_OFFSET_3  = 12;
    localparam integer REG_OFFSET_4  = 16;
    localparam integer REG_OFFSET_5  = 20;
    localparam integer REG_OFFSET_6  = 24;
    localparam integer REG_OFFSET_7  = 28;
    localparam integer REG_OFFSET_8  = 32;
    localparam integer REG_OFFSET_9  = 36;
    localparam integer REG_OFFSET_10 = 40;
    localparam integer REG_OFFSET_11 = 44;
    localparam integer REG_OFFSET_12 = 48;
    localparam integer REG_OFFSET_13 = 52;
    localparam integer REG_OFFSET_14 = 56;
    localparam integer REG_OFFSET_15 = 60;

    //-------------------------------------------------------------------------
    // Local signals
    //-------------------------------------------------------------------------

    // Write address channel
    logic awready_reg;
    logic awvalid_reg;
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;

    // Write data channel
    logic wready_reg;
    logic wvalid_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;
    logic [C_S_AXI_DATA_WIDTH/8-1:0] wstrb_reg;

    // Write response channel
    logic bvalid_reg;
    logic [1:0] bresp_reg;

    // Read address channel
    logic arready_reg;
    logic arvalid_reg;
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;

    // Read data channel
    logic rvalid_reg;
    logic [1:0] rresp_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] rdata_reg;

    // Internal register array to store data.  Example with 16 registers.
    logic [C_S_AXI_DATA_WIDTH-1:0] slave_registers [0:15];

    // FSM state for write operations
    typedef enum logic [1:0] {
        WRITE_IDLE,
        WRITE_ADDR_RCVD,
        WRITE_DATA_RCVD,
        WRITE_RESP
    } write_state_t;
    write_state_t write_state_reg, write_state_next;

    // FSM state for read operations
      typedef enum logic [1:0] {
        READ_IDLE,
        READ_ADDR_RCVD,
        READ_DATA_SENT
    } read_state_t;
    read_state_t read_state_reg, read_state_next;

    //-------------------------------------------------------------------------
    // I/O assignments
    //-------------------------------------------------------------------------

    // Drive the ready signals.  Simplest behavior: always ready (no buffering).
    s_axi_awready <= awready_reg;
    s_axi_wready  <= wready_reg;
    s_axi_arready <= arready_reg;

    // Drive the response and data signals
    s_axi_bresp   <= bresp_reg;
    s_axi_bvalid  <= bvalid_reg;
    s_axi_rdata   <= rdata_reg;
    s_axi_rresp   <= rresp_reg;
    s_axi_rvalid  <= rvalid_reg;

    //-------------------------------------------------------------------------
    // Finite State Machines
    //-------------------------------------------------------------------------

    // Write FSM state register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_state_reg <= WRITE_IDLE;
        end else begin
            write_state_reg <= write_state_next;
        end
    end

    // Write FSM next-state logic
    always_comb begin
        write_state_next = write_state_reg; // Default: stay in the same state
        case (write_state_reg)
            WRITE_IDLE:
                if (s_axi_awvalid)
                    write_state_next = WRITE_ADDR_RCVD;
            WRITE_ADDR_RCVD:
                if (s_axi_wvalid)
                    write_state_next = WRITE_DATA_RCVD;
            WRITE_DATA_RCVD:
                write_state_next = WRITE_RESP;
            WRITE_RESP:
                if (s_axi_bready)
                    write_state_next = WRITE_IDLE;
            default:
                write_state_next = WRITE_IDLE;
        endcase
    end

      // Read FSM state register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            read_state_reg <= READ_IDLE;
        end else begin
            read_state_reg <= read_state_next;
        end
    end

    // Read FSM next-state logic
    always_comb begin
        read_state_next = read_state_reg; // Default: stay in the same state
        case (read_state_reg)
            READ_IDLE:
                if (s_axi_arvalid)
                    read_state_next = READ_ADDR_RCVD;
            READ_ADDR_RCVD:
                read_state_next = READ_DATA_SENT;
            READ_DATA_SENT:
                if(s_axi_rready)
                    read_state_next = READ_IDLE;
            default:
                read_state_next = READ_IDLE;
        endcase
    end

    //-------------------------------------------------------------------------
    // Register logic
    //-------------------------------------------------------------------------

    // Capture AWVALID and WVALID, and address/data
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            awvalid_reg <= 1'b0;
            awaddr_reg  <= '0;
            wvalid_reg   <= 1'b0;
            wdata_reg    <= '0;
            wstrb_reg    <= '0;
        end else begin
            awvalid_reg <= s_axi_awvalid;
            if (s_axi_awvalid) begin
                awaddr_reg <= s_axi_awaddr;
            end
            wvalid_reg <= s_axi_wvalid;
            if (s_axi_wvalid) begin
                wdata_reg <= s_axi_wdata;
                wstrb_reg <= s_axi_wstrb;
            end
        end
    end

     always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            arvalid_reg <= 1'b0;
            araddr_reg  <= '0;
        end else begin
            arvalid_reg <= s_axi_arvalid;
            if (s_axi_arvalid) begin
                araddr_reg <= s_axi_araddr;
            end
        end
    end

    // Write response logic
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bvalid_reg <= 1'b0;
            bresp_reg  <= 2'b00;  // OKAY
        end else begin
            case (write_state_reg)
                WRITE_ADDR_RCVD:
                    awready_reg <= 1'b1;
                    wready_reg  <= 1'b1;
                WRITE_DATA_RCVD:
                    awready_reg <= 1'b0;
                    wready_reg  <= 1'b0;
                    bvalid_reg  <= 1'b1;
                    bresp_reg   <= 2'b00;  // OKAY
                WRITE_RESP:
                    if (s_axi_bready)
                        bvalid_reg <= 1'b0;
                default:
                    bvalid_reg <= 1'b0;
                    awready_reg <= 1'b0;
                    wready_reg  <= 1'b0;
            endcase
        end
    end

    // Read data and response logic
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rvalid_reg <= 1'b0;
            rdata_reg  <= '0;
            rresp_reg  <= 2'b00; //OKAY
        end
        else begin
            case(read_state_reg)
                READ_ADDR_RCVD:
                    arready_reg <= 1'b0;
                    rvalid_reg  <= 1'b1;
                    rresp_reg   <= 2'b00;
                    case (araddr_reg[C_S_AXI_ADDR_WIDTH-1:0])
                        REG_OFFSET_0:  rdata_reg <= slave_registers[0];
                        REG_OFFSET_1:  rdata_reg <= slave_registers[1];
                        REG_OFFSET_2:  rdata_reg <= slave_registers[2];
                        REG_OFFSET_3:  rdata_reg <= slave_registers[3];
                        REG_OFFSET_4:  rdata_reg <= slave_registers[4];
                        REG_OFFSET_5:  rdata_reg <= slave_registers[5];
                        REG_OFFSET_6:  rdata_reg <= slave_registers[6];
                        REG_OFFSET_7:  rdata_reg <= slave_registers[7];
                        REG_OFFSET_8:  rdata_reg <= slave_registers[8];
                        REG_OFFSET_9:  rdata_reg <= slave_registers[9];
                        REG_OFFSET_10: rdata_reg <= slave_registers[10];
                        REG_OFFSET_11: rdata_reg <= slave_registers[11];
                        REG_OFFSET_12: rdata_reg <= slave_registers[12];
                        REG_OFFSET_13: rdata_reg <= slave_registers[13];
                        REG_OFFSET_14: rdata_reg <= slave_registers[14];
                        REG_OFFSET_15: rdata_reg <= slave_registers[15];
                        default:          rdata_reg <= '0; // Or some error value
                    endcase
                READ_DATA_SENT:
                    if(s_axi_rready)
                        rvalid_reg <= 1'b0;
                default:
                    rvalid_reg <= 1'b0;
                    arready_reg <= 1'b1;
            endcase
        end
    end

    // Register write logic.  This is where you write to your slave registers.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            slave_registers[0]  <= '0;
            slave_registers[1]  <= '0;
            slave_registers[2]  <= '0;
            slave_registers[3]  <= '0;
            slave_registers[4]  <= '0;
            slave_registers[5]  <= '0;
            slave_registers[6]  <= '0;
            slave_registers[7]  <= '0;
            slave_registers[8]  <= '0;
            slave_registers[9]  <= '0;
            slave_registers[10] <= '0;
            slave_registers[11] <= '0;
            slave_registers[12] <= '0;
            slave_registers[13] <= '0;
            slave_registers[14] <= '0;
            slave_registers[15] <= '0;
        end else begin
            if (awvalid_reg && wvalid_reg) begin
                case (awaddr_reg[C_S_AXI_ADDR_WIDTH-1:0])
                    REG_OFFSET_0:
                        if (s_axi_wstrb[0]) slave_registers[0][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[0][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[0][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[0][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_1:
                        if (s_axi_wstrb[0]) slave_registers[1][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[1][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[1][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[1][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_2:
                        if (s_axi_wstrb[0]) slave_registers[2][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[2][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[2][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[2][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_3:
                        if (s_axi_wstrb[0]) slave_registers[3][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[3][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[3][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[3][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_4:
                        if (s_axi_wstrb[0]) slave_registers[4][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[4][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[4][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[4][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_5:
                        if (s_axi_wstrb[0]) slave_registers[5][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[5][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[5][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[5][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_6:
                        if (s_axi_wstrb[0]) slave_registers[6][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[6][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[6][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[6][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_7:
                        if (s_axi_wstrb[0]) slave_registers[7][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[7][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[7][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[7][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_8:
                        if (s_axi_wstrb[0]) slave_registers[8][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[8][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[8][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[8][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_9:
                        if (s_axi_wstrb[0]) slave_registers[9][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[9][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[9][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[9][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_10:
                        if (s_axi_wstrb[0]) slave_registers[10][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[10][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[10][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[10][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_11:
                        if (s_axi_wstrb[0]) slave_registers[11][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[11][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[11][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[11][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_12:
                        if (s_axi_wstrb[0]) slave_registers[12][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[12][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[12][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[12][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_13:
                        if (s_axi_wstrb[0]) slave_registers[13][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[13][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[13][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[13][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_14:
                        if (s_axi_wstrb[0]) slave_registers[14][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[14][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[14][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[14][31:24] <= s_axi_wdata[31:24];
                    REG_OFFSET_15:
                        if (s_axi_wstrb[0]) slave_registers[15][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) slave_registers[15][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) slave_registers[15][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) slave_registers[15][31:24] <= s_axi_wdata[31:24];
                    default: ; // Do nothing for invalid address, or return an error
                endcase
            end
        end
    end

endmodule
