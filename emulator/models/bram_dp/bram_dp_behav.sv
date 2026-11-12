/* verilator lint_off MULTIDRIVEN */

module bram_dp_behav #(
    parameter int OUT_REG_ENA = 0,
    parameter int N = 16,
    parameter int B = 16 ) (

    input  wire             clka,
    input  wire             clkb,
    input  wire             ena,
    input  wire             enb,
    input  wire             wea,
    input  wire             web,
    input  wire  [N-1:0]    addra,
    input  wire  [N-1:0]    addrb,
    input  wire  [B-1:0]    dia,
    input  wire  [B-1:0]    dib,
    output logic [B-1:0]    doa,
    output logic [B-1:0]    dob
    
);

    localparam int DATA_WIDTH      = B                  ;
    localparam int ADDR_WIDTH      = N                  ;
    localparam int ITEMS           = 2**N               ;
    localparam     WRITE_MODE_A    = "NO_CHANGE"        ;
    localparam     WRITE_MODE_B    = "NO_CHANGE"        ;
    localparam bit OUTPUT_REG      = (OUT_REG_ENA != 0) ;
    localparam bit RESET_DATA_PATH = 1                  ;
    localparam bit DEBUG           = 0                  ;

    // interface for Clock A
    logic                  RSTA     ;       // CLK A Sync Reset
    logic                  CLKA     ;       // Clock A
    logic                  PIPE_ENA ;       // Pipe Enable
    logic                  REA      ;       // Read Enable
    logic                  WEA      ;       // Write Enable
    logic [ADDR_WIDTH-1:0] ADDRA    ;       // Address A
    logic [DATA_WIDTH-1:0] DIA      ;       // Data A In
    logic                  DOA_DV   ;       // Data A Valid
    logic [DATA_WIDTH-1:0] DOA      ;       // Data A Out

    // interface for Clock B 
    logic                  RSTB     ;       // CLK B Sync Reset
    logic                  CLKB     ;       // Clock B
    logic                  PIPE_ENB ;       // Pipe Enable
    logic                  REB      ;       // Read Enable
    logic                  WEB      ;       // Write Enable
    logic [ADDR_WIDTH-1:0] ADDRB    ;       // Address A
    logic [DATA_WIDTH-1:0] DIB      ;       // Data A In
    logic                  DOB_DV   ;       // Data A Valid
    logic [DATA_WIDTH-1:0] DOB      ;       // Data A Out

    assign RSTA     = 1'b0;
    assign CLKA     = clka;
    assign PIPE_ENA = ena;
    assign REA      = ena & ~wea;
    assign WEA      = wea;
    assign ADDRA    = addra;
    assign DIA      = dia;
    assign doa      = DOA;

    assign RSTB     = 1'b0;
    assign CLKB     = clkb;
    assign PIPE_ENB = enb;
    assign REB      = enb & ~web;
    assign WEB      = web;
    assign ADDRB    = addrb;
    assign DIB      = dib;
    assign dob      = DOB;

    // unpacked datatype
    // acces through unpacked then packed e.g. [items][data]
    logic [DATA_WIDTH-1:0] memory [ITEMS-1:0];

    // Internal Logic
    logic [DATA_WIDTH-1:0] doa_to_reg, dob_to_reg, reg_doa, reg_dob;
    logic reg_doa_dv1, reg_doa_dv2, reg_dob_dv1, reg_dob_dv2, reset_data_a, reset_data_b;

    // memory Port A
    generate
        if (WRITE_MODE_A == "WRITE_FIRST") begin : gen_write_first_a
            always_ff @(posedge CLKA) begin
                if (PIPE_ENA) begin
                    if (WEA) begin
                        memory[ADDRA] <= DIA;
                    end
                    // read happens after the write in the same clock cycle
                    doa_to_reg <= memory[ADDRA];
                end
            end
        end else if (WRITE_MODE_A == "READ_FIRST") begin : gen_read_first_a
            always_ff @(posedge CLKA) begin
                if (PIPE_ENA) begin
                    // read happens before write
                    doa_to_reg <= memory[ADDRA];
                    if (WEA) begin
                        memory[ADDRA] <= DIA;
                    end
                end
            end
        end else if (WRITE_MODE_A == "NO_CHANGE") begin : gen_no_change_a
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
        if (WRITE_MODE_B == "WRITE_FIRST") begin : gen_write_first_b
            always_ff @(posedge CLKB) begin
                if (PIPE_ENB) begin
                    if (WEB) begin
                        memory[ADDRB] <= DIB;
                    end
                    // read happens after the write in the same clock cycle
                    dob_to_reg <= memory[ADDRB];
                end
            end
        end else if (WRITE_MODE_B == "READ_FIRST") begin : gen_read_first_b
            always_ff @(posedge CLKB) begin
                if (PIPE_ENB) begin
                    // read happens before write
                    dob_to_reg <= memory[ADDRB];
                    if (WEB) begin
                        memory[ADDRB] <= DIB;
                    end
                end
            end
        end else if (WRITE_MODE_B == "NO_CHANGE") begin : gen_no_change_b
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
        if (OUTPUT_REG) begin : gen_output_reg
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

        end else begin : gen_no_output_reg
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
