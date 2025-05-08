module axi_lite_slave #(
    parameter integer C_S_AXI_ADDR_WIDTH = 6, // Address width. Adjust as needed.
    parameter integer C_S_AXI_DATA_WIDTH = 32,  // Data width (32 or 64).
    parameter integer C_NUM_REGISTERS  = 16  // Configurable number of registers
) (
    input  logic                                 clk,          // System clock
    input  logic                                 reset_n,      // Active-low reset
    // Write address channel signals
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,   // Write address
    input  logic                                 s_axi_awvalid,  // Write address valid
    output logic                                 s_axi_awready,  // Write address ready
    // Write data channel signals
    input  logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_wdata,    // Write data
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0]s_axi_wstrb,    // Write strobes
    input  logic                                 s_axi_wvalid,   // Write data valid
    output logic                                 s_axi_wready,   // Write data ready
    // Write response channel signals
    output logic [1:0]                          s_axi_bresp,    // Write response
    output logic                                 s_axi_bvalid,   // Write response valid
    input  logic                                 s_axi_bready,   // Write response ready
    // Read address channel signals
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_araddr,   // Read address
    input  logic                                 s_axi_arvalid,  // Read address valid
    output logic                                 s_axi_arready,  // Read address ready
    // Read data channel signals
    output logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_rdata,    // Read data
    output logic [1:0]                          s_axi_rresp,    // Read response
    output logic                                 s_axi_rvalid,   // Read data valid
    input  logic                                 s_axi_rready    // Read data ready
    // Registers.
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_xcom_ctrl,    //: out std_logic_vector ( 5 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_xcom_cfg,     //: out std_logic_vector ( 3 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_dt1,      //: out std_logic_vector (31 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_dt2,      //  : out std_logic_vector (31 downto 0) ;
    output logic [C_S_AXI_DATA_WIDTH-1:0]   o_axi_addr,     //  : out std_logic_vector ( 3 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_board_id,     //   : in  std_logic_vector ( 3 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_flag,    //   : in  std_logic ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_dt1,     // : in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_dt2,     //  : in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_mem,     // : in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_rx_dt,   //  : in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_tx_dt,   //  : in  std_logic_vector (31 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_status,  //  : in  std_logic_vector (28 downto 0) ;
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   i_xcom_debug    //: in  std_logic_vector (31 downto 0) );
);

    //-------------------------------------------------------------------------
    // Local parameters
    //-------------------------------------------------------------------------

    // Example: Define the memory map for this slave.  Start at address 0.
    // Generate address offsets based on the number of registers.
    localparam integer [31:0] REG_OFFSET [0:C_NUM_REGISTERS-1];
    generate
        for (genvar i = 0; i < C_NUM_REGISTERS; i++) begin : gen_reg_offset
            if (i == 0) begin
                assign REG_OFFSET[i] = 0;
            end else begin
                assign REG_OFFSET[i] = REG_OFFSET[i-1] + (C_S_AXI_DATA_WIDTH/8); // Increment by byte width.
            end
        end
    endgenerate

    //-------------------------------------------------------------------------
    // Local signals
    //-------------------------------------------------------------------------

    // Write address channel signals
    logic awready_reg;
    logic awvalid_reg;
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;

    // Write data channel signals
    logic wready_reg;
    logic wvalid_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;
    logic [C_S_AXI_DATA_WIDTH/8-1:0] wstrb_reg;

    // Write response channel signals
    logic bvalid_reg;
    logic [1:0] bresp_reg;

    // Read address channel signals
    logic arready_reg;
    logic arvalid_reg;
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;

    // Read data channel signals
    logic rvalid_reg;
    logic [1:0] rresp_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] rdata_reg;

    // Internal register array to store data.
    logic [C_S_AXI_DATA_WIDTH-1:0] slave_registers [0:C_NUM_REGISTERS-1];

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
                        default: rdata_reg <= '0;
                        for (genvar i = 0; i < C_NUM_REGISTERS; i++) begin : gen_read_data
                            if (araddr_reg[C_S_AXI_ADDR_WIDTH-1:0] == REG_OFFSET[i]) begin
                                rdata_reg <= slave_registers[i];
                            end
                        end
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
            for (genvar i = 0; i < C_NUM_REGISTERS; i++) begin : gen_reset_regs
                slave_registers[i] <= '0;
            end
        end else begin
            if (awvalid_reg && wvalid_reg) begin
                case (awaddr_reg[C_S_AXI_ADDR_WIDTH-1:0])
                    default: ;
                    for (genvar i = 0; i < C_NUM_REGISTERS; i++) begin : gen_write_data
                        if (awaddr_reg[C_S_AXI_ADDR_WIDTH-1:0] == REG_OFFSET[i]) begin
                            if (s_axi_wstrb[0]) slave_registers[i][7:0]   <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1]) slave_registers[i][15:8]  <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2]) slave_registers[i][23:16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3]) slave_registers[i][31:24] <= s_axi_wdata[31:24];
                        end
                    end
                endcase
            end
        end
    end

endmodule

