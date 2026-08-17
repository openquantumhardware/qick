`timescale 1ns / 1ps

module axi_slv_pfb_ro_v3_pfb_ro_v3
#(
  parameter integer DATA_WIDTH = 32,
  parameter integer ADDR_WIDTH = 6
)
(
  input  wire aclk,
  input  wire aresetn,

  // Write Address Channel.
  input  wire [ADDR_WIDTH-1:0] awaddr,
  input  wire [2:0] awprot,
  input  wire awvalid,
  output wire awready,

  // Write Data Channel.
  input  wire [DATA_WIDTH-1:0] wdata,
  input  wire [(DATA_WIDTH/8)-1:0] wstrb,
  input  wire wvalid,
  output wire wready,

  // Write Response Channel.
  output wire [1:0] bresp,
  output wire bvalid,
  input  wire bready,

  // Read Address Channel.
  input  wire [ADDR_WIDTH-1:0] araddr,
  input  wire [2:0] arprot,
  input  wire arvalid,
  output wire arready,

  // Read Data Channel.
  output wire [DATA_WIDTH-1:0] rdata,
  output wire [1:0] rresp,
  output wire rvalid,
  input  wire rready,

  // Registers.
  output wire [15:0] ID0_REG,
  output wire [15:0] ID1_REG,
  output wire [15:0] ID2_REG,
  output wire [15:0] ID3_REG,
  output wire [31:0] PINC0_REG,
  output wire [31:0] POFF0_REG,
  output wire [31:0] PINC1_REG,
  output wire [31:0] POFF1_REG,
  output wire [31:0] PINC2_REG,
  output wire [31:0] POFF2_REG,
  output wire [31:0] PINC3_REG,
  output wire [31:0] POFF3_REG
);

  // AXI4LITE signals
  reg [ADDR_WIDTH-1:0] axi_awaddr;
  reg axi_awready;
  reg axi_wready;
  reg [1:0] axi_bresp;
  reg axi_bvalid;
  reg [ADDR_WIDTH-1:0] axi_araddr;
  reg axi_arready;
  reg [DATA_WIDTH-1:0] axi_rdata;
  reg [1:0] axi_rresp;
  reg axi_rvalid;

  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2)
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  localparam integer ADDR_LSB = (DATA_WIDTH/32)+ 1;
  localparam integer OPT_MEM_ADDR_BITS = 3;
  //----------------------------------------------
  //-- Signals for user logic register space example
  //------------------------------------------------
  //-- Number of Slave Registers 16
  reg [DATA_WIDTH-1:0] slv_reg0;
  reg [DATA_WIDTH-1:0] slv_reg1;
  reg [DATA_WIDTH-1:0] slv_reg2;
  reg [DATA_WIDTH-1:0] slv_reg3;
  reg [DATA_WIDTH-1:0] slv_reg4;
  reg [DATA_WIDTH-1:0] slv_reg5;
  reg [DATA_WIDTH-1:0] slv_reg6;
  reg [DATA_WIDTH-1:0] slv_reg7;
  reg [DATA_WIDTH-1:0] slv_reg8;
  reg [DATA_WIDTH-1:0] slv_reg9;
  reg [DATA_WIDTH-1:0] slv_reg10;
  reg [DATA_WIDTH-1:0] slv_reg11;
  reg [DATA_WIDTH-1:0] slv_reg12;
  reg [DATA_WIDTH-1:0] slv_reg13;
  reg [DATA_WIDTH-1:0] slv_reg14;
  reg [DATA_WIDTH-1:0] slv_reg15;
  reg slv_reg_rden;
  reg slv_reg_wren;
  reg [DATA_WIDTH-1:0] reg_data_out;
  integer byte_index;
  reg aw_en;

  // I/O Connections assignments

  assign awready  = axi_awready;
  assign wready   = axi_wready;
  assign bresp    = axi_bresp;
  assign bvalid   = axi_bvalid;
  assign arready  = axi_arready;
  assign rdata    = axi_rdata;
  assign rresp    = axi_rresp;
  assign rvalid   = axi_rvalid;
  // Implement axi_awready generation
  // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
  // de-asserted when reset is low.

  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end else begin
      if (axi_awready == 1'b0 && awvalid == 1'b1 && wvalid == 1'b1 && aw_en == 1'b1) begin
        // slave is ready to accept write address when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
           axi_awready <= 1'b1;
           aw_en <= 1'b0;
        end else if (bready == 1'b1 && axi_bvalid == 1'b1) begin
           aw_en <= 1'b1;
           axi_awready <= 1'b0;
      end else begin
        axi_awready <= 1'b0;
      end
    end
  end

  // Implement axi_awaddr latching
  // This process is used to latch the address when both
  // S_AXI_AWVALID and S_AXI_WVALID are valid.

  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_awaddr <= {(ADDR_WIDTH){1'b0}};
    end else begin
      if (axi_awready == 1'b0 && awvalid == 1'b1 && wvalid == 1'b1 && aw_en == 1'b1) begin
        // Write Address latching
        axi_awaddr <= awaddr;
      end
    end
  end

  // Implement axi_wready generation
  // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
  // de-asserted when reset is low.

  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_wready <= 1'b0;
    end else begin
      if (axi_wready == 1'b0 && wvalid == 1'b1 && awvalid == 1'b1 && aw_en == 1'b1) begin
          // slave is ready to accept write data when
          // there is a valid write address and write data
          // on the write address and data bus. This design
          // expects no outstanding transactions.
          axi_wready <= 1'b1;
      end else begin
        axi_wready <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  assign slv_reg_wren = axi_wready && wvalid && axi_awready && awvalid;

  always @(posedge aclk)
  begin
    reg [OPT_MEM_ADDR_BITS:0] loc_addr;
    if (aresetn == 1'b0) begin
      slv_reg0 <= {(DATA_WIDTH){1'b0}};
      slv_reg1 <= {(DATA_WIDTH){1'b0}};
      slv_reg2 <= {(DATA_WIDTH){1'b0}};
      slv_reg3 <= {(DATA_WIDTH){1'b0}};
      slv_reg4 <= {(DATA_WIDTH){1'b0}};
      slv_reg5 <= {(DATA_WIDTH){1'b0}};
      slv_reg6 <= {(DATA_WIDTH){1'b0}};
      slv_reg7 <= {(DATA_WIDTH){1'b0}};
      slv_reg8 <= {(DATA_WIDTH){1'b0}};
      slv_reg9 <= {(DATA_WIDTH){1'b0}};
      slv_reg10 <= {(DATA_WIDTH){1'b0}};
      slv_reg11 <= {(DATA_WIDTH){1'b0}};
      slv_reg12 <= {(DATA_WIDTH){1'b0}};
      slv_reg13 <= {(DATA_WIDTH){1'b0}};
      slv_reg14 <= {(DATA_WIDTH){1'b0}};
      slv_reg15 <= {(DATA_WIDTH){1'b0}};
    end else begin
      loc_addr = axi_awaddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB];
      if (slv_reg_wren == 1'b1) begin
        case (loc_addr)
          4'b0000: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 0
                slv_reg0[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0001: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 1
                slv_reg1[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0010: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 2
                slv_reg2[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0011: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 3
                slv_reg3[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0100: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 4
                slv_reg4[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0101: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 5
                slv_reg5[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0110: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 6
                slv_reg6[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b0111: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 7
                slv_reg7[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1000: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 8
                slv_reg8[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1001: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 9
                slv_reg9[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1010: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 10
                slv_reg10[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1011: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 11
                slv_reg11[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1100: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 12
                slv_reg12[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1101: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 13
                slv_reg13[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1110: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 14
                slv_reg14[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          4'b1111: begin
            for (byte_index = 0; byte_index <= (DATA_WIDTH/8-1); byte_index = byte_index + 1) begin
              if (wstrb[byte_index] == 1'b1) begin
                // Respective byte enables are asserted as per write strobes
                // slave registor 15
                slv_reg15[byte_index*8+7 -: 8] <= wdata[byte_index*8+7 -: 8];
              end
            end
          end
          default: begin
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
          end
        endcase
      end
    end
  end

  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave
  // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
  // This marks the acceptance of address and indicates the status of
  // write transaction.

  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_bvalid  <= 1'b0;
      axi_bresp   <= 2'b00; //need to work more on the responses
    end else begin
      if (axi_awready == 1'b1 && awvalid == 1'b1 && axi_wready == 1'b1 && wvalid == 1'b1 && axi_bvalid == 1'b0) begin
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b00;
      end else if (bready == 1'b1 && axi_bvalid == 1'b1) begin   //check if bready is asserted while bvalid is high)
        axi_bvalid <= 1'b0;                                 // (there is a possibility that bready is always asserted high)
      end
    end
  end

  // Implement axi_arready generation
  // axi_arready is asserted for one S_AXI_ACLK clock cycle when
  // S_AXI_ARVALID is asserted. axi_awready is
  // de-asserted when reset (active low) is asserted.
  // The read address is also latched when S_AXI_ARVALID is
  // asserted. axi_araddr is reset to zero on reset assertion.

  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_arready <= 1'b0;
      axi_araddr  <= {(ADDR_WIDTH){1'b1}};
    end else begin
      if (axi_arready == 1'b0 && arvalid == 1'b1) begin
        // indicates that the slave has acceped the valid read address
        axi_arready <= 1'b1;
        // Read Address latching
        axi_araddr  <= araddr;
      end else begin
        axi_arready <= 1'b0;
      end
    end
  end

  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_ARVALID and axi_arready are asserted. The slave registers
  // data are available on the axi_rdata bus at this instance. The
  // assertion of axi_rvalid marks the validity of read data on the
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid
  // is deasserted on reset (active low). axi_rresp and axi_rdata are
  // cleared to zero on reset (active low).
  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_rvalid <= 1'b0;
      axi_rresp  <= 2'b00;
    end else begin
      if (axi_arready == 1'b1 && arvalid == 1'b1 && axi_rvalid == 1'b0) begin
        // Valid read data is available at the read data bus
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b00; // 'OKAY' response
      end else if (axi_rvalid == 1'b1 && rready == 1'b1) begin
        // Read data is accepted by the master
        axi_rvalid <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign slv_reg_rden = axi_arready && arvalid && (!axi_rvalid);

  always @(*)
  begin
      reg [OPT_MEM_ADDR_BITS:0] loc_addr;
      // Address decoding for reading registers
      loc_addr = axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB];
      case (loc_addr)
        4'b0000: reg_data_out = slv_reg0;
        4'b0001: reg_data_out = slv_reg1;
        4'b0010: reg_data_out = slv_reg2;
        4'b0011: reg_data_out = slv_reg3;
        4'b0100: reg_data_out = slv_reg4;
        4'b0101: reg_data_out = slv_reg5;
        4'b0110: reg_data_out = slv_reg6;
        4'b0111: reg_data_out = slv_reg7;
        4'b1000: reg_data_out = slv_reg8;
        4'b1001: reg_data_out = slv_reg9;
        4'b1010: reg_data_out = slv_reg10;
        4'b1011: reg_data_out = slv_reg11;
        4'b1100: reg_data_out = slv_reg12;
        4'b1101: reg_data_out = slv_reg13;
        4'b1110: reg_data_out = slv_reg14;
        4'b1111: reg_data_out = slv_reg15;
        default: reg_data_out = {(DATA_WIDTH){1'b0}};
      endcase
  end

  // Output register or memory read data
  always @(posedge aclk)
  begin
    if (aresetn == 1'b0) begin
      axi_rdata  <= {(DATA_WIDTH){1'b0}};
    end else begin
      if (slv_reg_rden == 1'b1) begin
        // When there is a valid read address (S_AXI_ARVALID) with
        // acceptance of read address by the slave (axi_arready),
        // output the read dada
        // Read address mux
          axi_rdata <= reg_data_out;     // register read data
      end
    end
  end

  // Output Registers.
  assign ID0_REG   = slv_reg0 [15:0];
  assign ID1_REG   = slv_reg1 [15:0];
  assign ID2_REG   = slv_reg2 [15:0];
  assign ID3_REG   = slv_reg3 [15:0];
  assign PINC0_REG = slv_reg4;
  assign POFF0_REG = slv_reg5;
  assign PINC1_REG = slv_reg6;
  assign POFF1_REG = slv_reg7;
  assign PINC2_REG = slv_reg8;
  assign POFF2_REG = slv_reg9;
  assign PINC3_REG = slv_reg10;
  assign POFF3_REG = slv_reg11;

endmodule
