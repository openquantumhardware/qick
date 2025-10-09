/* verilator lint_off MULTIDRIVEN */

module bram_dp_behav #(
    parameter int DATA_WIDTH = 32,
    parameter int ITEMS = 1024,
    parameter WRITE_MODE_A = "WRITE_FIRST",
    parameter WRITE_MODE_B = "WRITE_FIRST",
    parameter bit OUTPUT_REG = 1,
    parameter bit RESET_DATA_PATH = 1,
    parameter bit DEBUG = 0,
    parameter int ADDR_WIDTH = $clog2(ITEMS)) (
// interface for Clock A
input logic RSTA,                           // CLK A Sync Reset
input logic CLKA,                           // Clock A
input logic PIPE_ENA,                       // Pipe Enable
input logic REA,                            // Read Enable
input logic WEA,                            // Write Enable
input logic [ADDR_WIDTH-1:0] ADDRA,         // Address A
input logic [DATA_WIDTH-1:0] DIA,           // Data A In
output logic DOA_DV,                        // Data A Valid
output logic [DATA_WIDTH-1:0] DOA,          // Data A Out

// interface for Clock B 
input logic RSTB,                           // CLK B Sync Reset
input logic CLKB,                           // Clock B
input logic PIPE_ENB,                       // Pipe Enable
input logic REB,                            // Read Enable
input logic WEB,                            // Write Enable
input logic [ADDR_WIDTH-1:0] ADDRB,         // Address A
input logic [DATA_WIDTH-1:0] DIB,           // Data A In
output logic DOB_DV,                        // Data A Valid
output logic [DATA_WIDTH-1:0] DOB           // Data A Out
);

    // unpacked datatype
    // acces through unpacked then packed e.g. [items][data]
    logic [DATA_WIDTH-1:0] memory [ITEMS-1:0];

    // Internal Logic
    logic [DATA_WIDTH-1:0] doa_to_reg, dob_to_reg, reg_doa, reg_dob;
    logic reg_doa_dv1, reg_doa_dv2, reg_dob_dv1, reg_dob_dv2, reset_data_a, reset_data_b;

    // memory Port A
    generate
        // GEN_WRITE_FIRST_A
        if (WRITE_MODE_A == "WRITE_FIRST") begin
            always_ff @(posedge CLKA) begin
                if (PIPE_ENA) begin
                    if (WEA) begin
                        memory[ADDRA] <= DIA;
                    end
                    // read happens after the write in the same clock cycle
                    doa_to_reg <= memory[ADDRA];
                end
            end
        // GEN_READ_FIRST_A
        end else if (WRITE_MODE_A == "READ_FIRST") begin
            always_ff @(posedge CLKA) begin
                if (PIPE_ENA) begin
                    // read happens before write
                    doa_to_reg <= memory[ADDRA];
                    if (WEA) begin
                        memory[ADDRA] <= DIA;
                    end
                end
            end
        // GEN_NO_CHANGE_A
        end else if (WRITE_MODE_A == "NO_CHANGE") begin
            // prevents write from changing output
            always_ff @(posedge CLKA) begin
                if (PIPE_ENA) begin
                    if (WEA && ~REA) begin
                        memory[ADDRA] <= DIA;
                    end
                    doa_to_reg <= memory[ADDRA];
                end
            end
        end
    endgenerate

    // memory Port B
    generate
        // GEN_WRITE_FIRST_B
        if (WRITE_MODE_B == "WRITE_FIRST") begin
            always_ff @(posedge CLKB) begin
                if (PIPE_ENB) begin
                    if (WEB) begin
                        memory[ADDRB] <= DIB;
                    end
                    // read happens after the write in the same clock cycle
                    dob_to_reg <= memory[ADDRB];
                end
            end
        // GEN_READ_FIRST_B
        end else if (WRITE_MODE_B == "READ_FIRST") begin
            always_ff @(posedge CLKB) begin
                if (PIPE_ENB) begin
                    // read happens before write
                    dob_to_reg <= memory[ADDRB];
                    if (WEB) begin
                        memory[ADDRB] <= DIB;
                    end
                end
            end
        // GEN_NO_CHANGE_B
        end else if (WRITE_MODE_B == "NO_CHANGE") begin
            // prevents write from changing output
            always_ff @(posedge CLKB) begin
                if (PIPE_ENB) begin
                    if (WEB && ~REB) begin
                        memory[ADDRB] <= DIB;
                    end
                    dob_to_reg <= memory[ADDRB];
                end
            end
        end
    endgenerate

    // Reset Logic
    assign reset_data_a = RESET_DATA_PATH ? RSTA : 1'b0;
    assign reset_data_b = RESET_DATA_PATH ? RSTB : 1'b0;

    // Output Registers
    generate
        // OUTPUT_REG_GEN
        if (OUTPUT_REG) begin
            // DOA Data and Data Valid
            always_ff @(posedge CLKA) begin
                if (RSTA) begin                 // control path reset
                    reg_doa_dv1 <= 1'b0;
                    reg_doa_dv2 <= 1'b0;
                end else if (PIPE_ENA) begin
                    reg_doa_dv1 <= REA;
                    reg_doa_dv2 <= reg_doa_dv1;
                end

                if (reset_data_a) begin
                    reg_doa <= '0;              // data path reset
                end else if (PIPE_ENA) begin
                    reg_doa <= doa_to_reg;
                end
            end

            // DOB Data and Data Valid
            always_ff @(posedge CLKB) begin
                if (RSTB) begin                 // control path reset
                    reg_dob_dv1 <= 1'b0;
                    reg_dob_dv2 <= 1'b0;
                end else if (PIPE_ENA) begin
                    reg_dob_dv1 <= REB;
                    reg_dob_dv2 <= reg_dob_dv1;
                end

                if (reset_data_b) begin
                    reg_dob <= '0;              // data path reset
                end else if (PIPE_ENB) begin
                    reg_dob <= dob_to_reg;
                end
            end

            // Register to Output
            assign DOA = reg_doa;
            assign DOB = reg_dob;
            assign DOA_DV = reg_doa_dv2;
            assign DOB_DV = reg_dob_dv2;

        // NO_OUTPUT_REG_GEN
        end else begin
            // no output registers
            always_ff @(posedge CLKA) begin
                if (RSTA) begin
                    DOA_DV <= 1'b0;
                end else if (PIPE_ENA) begin
                    DOA_DV <= REA;
                end
            end

            always_ff @(posedge CLKB) begin
                if (RSTB) begin
                    DOB_DV <= 1'b0;
                end else if (PIPE_ENB) begin
                    DOB_DV <= REB;
                end
            end

            // memory read to output
            assign DOA = doa_to_reg;
            assign DOB = dob_to_reg;
        end
    endgenerate
endmodule

/* verilator lint_on MULTIDRIVEN */