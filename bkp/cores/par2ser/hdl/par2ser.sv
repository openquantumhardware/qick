///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: par2ser.sv
// Project: QICK 
// Description: Parallel input, serial output converter. 
//              Data width is a parameter
//
//
// Change history: 05/05/25 - v0.1.0 Started by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////

module par2ser #(
    parameter DWIDTH = 8
) (
    input  logic              i_clk,
    input  logic              i_rstn,
    input  logic              i_load, // Signal to indicate when a new parallel data is valid
    input  logic [DWIDTH-1:0] i_data,
    output logic              o_data,
    output logic              o_valid // Signal indicating a complete serial word is assembled
);


    // Internal signals
    logic [DWIDTH-1:0]         s_shift_reg;
    logic [$clog2(DWIDTH)-1:0] bit_counter;
    logic                      s_data_valid;

    // State to track reception progress
    typedef enum logic {
        IDLE         = 1'b0,
        TRANSMITTING = 1'b1
    } state_t;

    state_t state_r, state_n;

    // FSM state register
    always_ff @(posedge i_clk) begin
        if (!i_rstn) begin
            state_r <= IDLE;
        end else begin
            state_r <= state_n;
        end
    end

    // Next State Logic
    always_comb begin
        state_n = state_r;
        case (state_r)
            IDLE: begin
                if (i_load) begin
                    state_n = TRANSMITTING;
                end
            end
            TRANSMITTING: begin
                if (bit_counter == DWIDTH - 1) begin
                    state_n = IDLE;
                end
            end
            default: state_n = IDLE;
        endcase
    end

    // Data Path Logic
    always_ff @(posedge i_clk) begin
        if (!i_rstn) begin
            s_shift_reg  <= '0;
            bit_counter  <= '0;
            s_data_valid <= 1'b0;
        end else begin
            case (state_r)
                IDLE: begin
                    if (i_load) begin
                        s_shift_reg  <= i_data;
                        bit_counter  <= '0;
                        s_data_valid <= 1'b1; // First bit valid in the next cycle
                    end else begin
                        s_data_valid <= 1'b0;
                    end
                end
                TRANSMITTING: begin
                    if (bit_counter < DWIDTH - 1) begin
                        s_shift_reg  <= {s_shift_reg[DWIDTH-2:0], 1'b0}; // Shift left
                        bit_counter  <= bit_counter + 1'b1;
                        s_data_valid <= 1'b1;
                    end else begin
                        s_data_valid <= 1'b0; // Transmission complete
                        bit_counter  <= bit_counter + 1'b1; // Prevent further shifting in the next cycle
                    end
                end
                default: begin
                    s_shift_reg  <= '0;
                    bit_counter  <= '0;
                    s_data_valid <= 1'b0;
                end
            endcase
        end
    end

    // Output logic
    assign o_data  = s_shift_reg[DWIDTH-1];
    assign o_valid = s_data_valid;

endmodule
