`timescale 1ns/1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axi_slv_tprocv1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axi_slv_tprocv1.sv
//!
//! @brief   Custom AXI4-Lite slave for the QICK tProcessor (axis_tprocv1). It provides
//!
//! @details
//!
//!
//! two distinct, address-decoded access regions over a SINGLE AXI-Lite port:
//!
//! 1. Register region  (byte address <  NREG_BYTE = 256 bytes)
//!
//!
//! - Maps to an internal 8-register file (reg0..reg7), 32-bit each.
//! - Registers are read/written directly with an OKAY response.
//! - These expose the control registers consumed by the rest of the IP:
//! reg0 -> start_src_reg  (bit 0)
//! reg1 -> start_reg      (bit 0)
//! reg2 -> mem_mode_reg   (bit 0)
//! reg3 -> mem_start_reg  (bit 0)
//! reg4 -> mem_addr_reg   (full 32-bit)
//! reg5 -> mem_len_reg    (full 32-bit)
//!
//! 2. Memory region    (byte address >= NREG_BYTE)
//!
//!
//! - Maps to the external data memory (DMEM) via a single-access
//! handshake (exec_o / exec_ack_i, oper_o, addr_o, dwrite_o, dread_i).
//!
//!
//! - The byte address is offset by NREG_BYTE and converted to a
//! sample (word) address (addr_o = (awaddr - 256) / 4).
//!
//!
//! - This is what the Python driver uses for single_read()/single_write():
//! self.mmio.array[addr + NREG]   (NREG = 64 words = 256 bytes)
//!
//! Coherency / busy handling:
//! When the external memory arbiter (dmem) is running an AXIS stream
//! transaction, busy_i = 1 and the memory cannot be accessed by single
//! read/write. In that case the slave returns an AXI error response:
//! RRESP / BRESP = 2'b10 (SLVERR)   — see AXI spec.
//! Any other (successful) access returns:
//! RRESP / BRESP = 2'b00 (OKAY).
//! This avoids bus dead-locks by never blocking while memory is busy.
//!
//! Notes / simplifications (intentional, matching the original):
//!
//!
//! - Address map is DATA_WIDTH (word) based for the memory region, not byte.
//! - WSTRB (write strobes) is NOT implemented: writes are always full-word.
//! - Maximum 16-bit address space; lower part = registers, upper = memory.
//!
//! AXI handshake FSM (one-hot encoded):
//! INIT -> AWADDR -> WDATA -> {REG_WR | mem_WR | BRESP_ERR} -> BRESP_OK/ERR
//!
//!
//! -> BRESP -> INIT
//! INIT -> ARADDR -> {REG_RD | mem_RD | RRESP_ERR} -> RRESP_OK/ERR
//!
//!
//! -> RDATA -> INIT
//! mem_WR/MEM_RD wait for exec_ack_i, then WR_ACK/RD_ACK wait for it to
//! deassert (full level handshake with the memory arbiter).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axi_slv_tprocv1 (
    //--------------------------------------------------------------------------
    // Reset and clock
    //--------------------------------------------------------------------------
    input  logic        aclk_i,
    input  logic        aresetn_i,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Address Channel
    //--------------------------------------------------------------------------
    input  logic [31:0] awaddr_i,
    input  logic [2:0]  awprot_i,
    input  logic        awvalid_i,
    output logic        awready_o,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Data Channel
    //--------------------------------------------------------------------------
    input  logic [31:0] wdata_i,
    input  logic [3:0]  wstrb_i,    // accepted but ignored (full-word writes)
    input  logic        wvalid_i,
    output logic        wready_o,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Response Channel
    //--------------------------------------------------------------------------
    output logic [1:0]  bresp_o,
    output logic        bvalid_o,
    input  logic        bready_i,

    //--------------------------------------------------------------------------
    // AXI4-Lite Read Address Channel
    //--------------------------------------------------------------------------
    input  logic [31:0] araddr_i,
    input  logic [2:0]  arprot_i,
    input  logic        arvalid_i,
    output logic        arready_o,

    //--------------------------------------------------------------------------
    // AXI4-Lite Read Data Channel
    //--------------------------------------------------------------------------
    output logic [31:0] rdata_o,
    output logic [1:0]  rresp_o,
    output logic        rvalid_o,
    input  logic        rready_i,

    //--------------------------------------------------------------------------
    // Single-Access Handshake (to external memory arbiter, dmem)
    //--------------------------------------------------------------------------
    input  logic        busy_i,      // 1 = memory busy with AXIS stream
    output logic        oper_o,      // 0 = read, 1 = write
    output logic [31:0] addr_o,      // sample (word) address into DMEM
    output logic [31:0] dwrite_o,    // write data
    input  logic [31:0] dread_i,     // read data
    output logic        exec_o,      // execute single access
    input  logic        exec_ack_i,  // acknowledge from arbiter

    //--------------------------------------------------------------------------
    // Control registers (exposed to the rest of the IP)
    //--------------------------------------------------------------------------
    output logic        start_src_reg,
    output logic        start_reg,
    output logic        mem_mode_reg,
    output logic        mem_start_reg,
    output logic [31:0] mem_addr_reg,
    output logic [31:0] mem_len_reg
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam int DATA_WIDTH           = 32;
    localparam int DATA_WIDTH_BYTE      = DATA_WIDTH / 8;             // 4
    localparam int DATA_WIDTH_BYTE_LOG2 = $clog2(DATA_WIDTH_BYTE);    // 2
    localparam int NREG                 = 64;                         // # words reserved
    localparam int NREG_BYTE            = NREG * DATA_WIDTH_BYTE;     // 256 bytes

    //--------------------------------------------------------------------------
    // FSM state encoding (one-hot for timing)
    //--------------------------------------------------------------------------
    typedef enum logic [15:0] {
        INIT_ST      = 16'h0001,  // Idle / wait for awvalid or arvalid
        AWADDR_ST    = 16'h0002,  // Accept write address
        WDATA_ST     = 16'h0004,  // Accept write data
        BRESP_ST     = 16'h0008,  // Drive write response (bvalid)
        ARADDR_ST    = 16'h0010,  // Accept read address
        RDATA_ST     = 16'h0020,  // Drive read data (rvalid)
        REG_WR_ST    = 16'h0040,  // Register write (low address)
        mem_WR_ST    = 16'h0080,  // Memory single write (high address)
        REG_RD_ST    = 16'h0100,  // Register read (low address)
        mem_RD_ST    = 16'h0200,  // Memory single read (high address)
        WR_ACK_ST    = 16'h0400,  // Wait for write exec_ack to deassert
        RD_ACK_ST    = 16'h0800,  // Wait for read exec_ack to deassert
        BRESP_OK_ST  = 16'h1000,  // Latch BRESP = OKAY
        BRESP_ERR_ST = 16'h2000,  // Latch BRESP = SLVERR
        RRESP_OK_ST  = 16'h4000,  // Latch RRESP = OKAY
        RRESP_ERR_ST = 16'h8000   // Latch RRESP = SLVERR
    } state_t;

    (* fsm_encoding = "one_hot" *) state_t state;

    //--------------------------------------------------------------------------
    // Control flags (combinational FSM outputs)
    //--------------------------------------------------------------------------
    logic reg_rw;     // 1 = register write enable
    logic sel_int;    // 0 = register data, 1 = external memory read data
    logic data_en;    // enable read-data capture register
    logic addr_sel;   // 0 = awaddr, 1 = araddr
    logic resp_en;    // enable response register update
    logic [1:0] resp_int; // 2'b00 = OKAY, 2'b10 = SLVERR

    //--------------------------------------------------------------------------
    // Address / data / response registers
    //--------------------------------------------------------------------------
    logic [31:0] addr_r;
    logic [31:0] addr_mux;
    logic [31:0] addr_out;

    logic [DATA_WIDTH-1:0] wdata_r;
    logic [DATA_WIDTH-1:0] data_r;
    logic [DATA_WIDTH-1:0] data_mux;

    logic [1:0] resp_r;

    //--------------------------------------------------------------------------
    // Internal register file (8 x 32-bit)
    //--------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] reg0, reg1, reg2, reg3;
    logic [DATA_WIDTH-1:0] reg4, reg5, reg6, reg7;
    logic [DATA_WIDTH-1:0] reg_int;  // selected register read value

    //--------------------------------------------------------------------------
    // Sequential: FSM state, address/data/resp registers, register file
    //--------------------------------------------------------------------------
    always_ff @(posedge aclk_i) begin
        if (~aresetn_i) begin
            state   <= INIT_ST;
            addr_r  <= '0;
            wdata_r <= '0;
            data_r  <= '0;
            resp_r  <= '0;
            reg0    <= '0;
            reg1    <= '0;
            reg2    <= '0;
            reg3    <= '0;
            reg4    <= '0;
            reg5    <= '0;
            reg6    <= '0;
            reg7    <= '0;
        end else begin
            //------------------------------------------------------------------
            // State register
            //------------------------------------------------------------------
            unique case (state)
                INIT_ST:
                    if (awvalid_i)
                        state <= AWADDR_ST;
                    else if (arvalid_i)
                        state <= ARADDR_ST;

                AWADDR_ST:
                    state <= WDATA_ST;

                WDATA_ST:
                    if (wvalid_i) begin
                        if (addr_r < NREG_BYTE)
                            state <= REG_WR_ST;          // register write
                        else if (busy_i)
                            state <= BRESP_ERR_ST;       // memory busy -> SLVERR
                        else
                            state <= mem_WR_ST;          // memory single write
                    end

                BRESP_ST:
                    if (bready_i)
                        state <= INIT_ST;

                ARADDR_ST:
                    if (araddr_i < NREG_BYTE)
                        state <= REG_RD_ST;              // register read
                    else if (busy_i)
                        state <= RRESP_ERR_ST;           // memory busy -> SLVERR
                    else
                        state <= mem_RD_ST;              // memory single read

                RDATA_ST:
                    if (rready_i)
                        state <= INIT_ST;

                REG_WR_ST:
                    state <= BRESP_OK_ST;

                mem_WR_ST:
                    if (exec_ack_i)
                        state <= WR_ACK_ST;

                REG_RD_ST:
                    state <= RRESP_OK_ST;

                mem_RD_ST:
                    if (exec_ack_i)
                        state <= RD_ACK_ST;

                WR_ACK_ST:
                    if (~exec_ack_i)
                        state <= BRESP_OK_ST;

                RD_ACK_ST:
                    if (~exec_ack_i)
                        state <= RRESP_OK_ST;

                BRESP_OK_ST:   state <= BRESP_ST;
                BRESP_ERR_ST:  state <= BRESP_ST;
                RRESP_OK_ST:   state <= RDATA_ST;
                RRESP_ERR_ST:  state <= RDATA_ST;

                default:       state <= INIT_ST;
            endcase

            //------------------------------------------------------------------
            // Address register: latch on accepted AW or AR handshake
            //------------------------------------------------------------------
            if ((awvalid_i && awready_o) || (arvalid_i && arready_o))
                addr_r <= addr_mux;

            //------------------------------------------------------------------
            // Write-data register: latch on accepted W handshake
            //------------------------------------------------------------------
            if (wvalid_i && wready_o)
                wdata_r <= wdata_i;

            //------------------------------------------------------------------
            // Read-data capture register
            //------------------------------------------------------------------
            if (data_en)
                data_r <= data_mux;

            //------------------------------------------------------------------
            // Response register
            //------------------------------------------------------------------
            if (resp_en)
                resp_r <= resp_int;

            //------------------------------------------------------------------
            // Register file write (word-addressed, byte address decoded)
            //------------------------------------------------------------------
            if (reg_rw) begin
                unique case (addr_r)
                    32'd0:  reg0 <= wdata_r;
                    32'd4:  reg1 <= wdata_r;
                    32'd8:  reg2 <= wdata_r;
                    32'd12: reg3 <= wdata_r;
                    32'd16: reg4 <= wdata_r;
                    32'd20: reg5 <= wdata_r;
                    32'd24: reg6 <= wdata_r;
                    32'd28: reg7 <= wdata_r;
                    default: ; // ignore other addresses in register region
                endcase
            end
        end
    end

    //--------------------------------------------------------------------------
    // Combinational: FSM outputs
    //--------------------------------------------------------------------------
    always_comb begin
        // Defaults
        awready_o = 1'b0;
        wready_o  = 1'b0;
        bvalid_o  = 1'b0;
        arready_o = 1'b0;
        rvalid_o  = 1'b0;
        oper_o    = 1'b0;   // 0 = read, 1 = write
        exec_o    = 1'b0;
        reg_rw    = 1'b0;
        sel_int   = 1'b0;
        data_en   = 1'b0;
        addr_sel  = 1'b0;
        resp_en   = 1'b0;
        resp_int  = 2'b00;

        unique case (state)
            INIT_ST: ;  // idle

            AWADDR_ST: begin
                awready_o = 1'b1;
                addr_sel  = 1'b0;  // select awaddr
            end

            WDATA_ST:
                wready_o = 1'b1;

            BRESP_ST:
                bvalid_o = 1'b1;

            ARADDR_ST: begin
                arready_o = 1'b1;
                addr_sel  = 1'b1;  // select araddr
            end

            RDATA_ST:
                rvalid_o = 1'b1;

            REG_WR_ST:
                reg_rw = 1'b1;

            mem_WR_ST: begin
                oper_o = 1'b1;     // write
                exec_o = 1'b1;
            end

            REG_RD_ST: begin
                reg_rw  = 1'b0;
                sel_int = 1'b0;    // select register data
                data_en = 1'b1;
            end

            mem_RD_ST: begin
                oper_o  = 1'b0;    // read
                exec_o  = 1'b1;
                sel_int = 1'b1;    // select memory read data
                data_en = 1'b1;
            end

            WR_ACK_ST: ; // hold, wait for exec_ack to deassert
            RD_ACK_ST: ; // hold, wait for exec_ack to deassert

            BRESP_OK_ST: begin
                resp_en  = 1'b1;
                resp_int = 2'b00;  // OKAY
            end
            BRESP_ERR_ST: begin
                resp_en  = 1'b1;
                resp_int = 2'b10;  // SLVERR
            end
            RRESP_OK_ST: begin
                resp_en  = 1'b1;
                resp_int = 2'b00;  // OKAY
            end
            RRESP_ERR_ST: begin
                resp_en  = 1'b1;
                resp_int = 2'b10;  // SLVERR
            end

            default: ;
        endcase
    end

    //--------------------------------------------------------------------------
    // Address computation and muxes
    //--------------------------------------------------------------------------
    // Memory region: byte address offset by the register region size.
    assign addr_out = addr_r - NREG_BYTE;

    // Address source mux: write (awaddr) vs read (araddr).
    assign addr_mux = (addr_sel == 1'b0) ? awaddr_i : araddr_i;

    // Read-data source mux: internal register vs external memory read data.
    assign data_mux = (sel_int == 1'b0) ? reg_int : dread_i;

    // Register read mux (word-addressed).
    always_comb begin
        unique case (addr_r)
            32'd0:  reg_int = reg0;
            32'd4:  reg_int = reg1;
            32'd8:  reg_int = reg2;
            32'd12: reg_int = reg3;
            32'd16: reg_int = reg4;
            32'd20: reg_int = reg5;
            32'd24: reg_int = reg6;
            32'd28: reg_int = reg7;
            default: reg_int = '0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------
    assign bresp_o  = resp_r;
    assign rresp_o  = resp_r;
    assign rdata_o  = data_r;

    // Byte address -> sample (word) address for the memory region.
    assign addr_o   = addr_out[31:DATA_WIDTH_BYTE_LOG2];
    assign dwrite_o = wdata_r;

    // Control register field extraction.
    assign start_src_reg = reg0[0];
    assign start_reg     = reg1[0];
    assign mem_mode_reg  = reg2[0];
    assign mem_start_reg = reg3[0];
    assign mem_addr_reg  = reg4;
    assign mem_len_reg   = reg5;

endmodule
