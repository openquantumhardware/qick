module ser2par #(
    parameter DWIDTH = 8
) (
    input  logic              i_clk,
    input  logic              i_rstn,
    input  logic              i_data,
    input  logic              i_load, // Signal to indicate when a new serial bit is valid
    output logic [DWIDTH-1:0] o_data,
    output logic              o_ready // Signal indicating a complete parallel word is assembled
);

    // Internal signals
    logic [DWIDTH-1:0]         s_shift_reg;
    logic [$clog2(DWIDTH)-1:0] bit_counter;

    // State to track reception progress
    typedef enum logic {
        IDLE,
        RECEIVING
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

    // FSM next state logic
    always_comb begin
        state_n = state_r;
        case (state_r)
            IDLE: begin
                if (i_load) begin
                    state_n = RECEIVING;
                end
            end
            RECEIVING: begin
                if (bit_counter == DWIDTH - 1 && i_load) begin
                    state_n = IDLE;
                end
            end
            default: state_n = IDLE;
        endcase
    end

    // Data shifting and counter
    always_ff @(posedge i_clk) begin
        if (!i_rstn) begin
            s_shift_reg <= '0;
            bit_counter <= '0;
        end else begin
            if (i_load) begin
                if (state_r == IDLE) begin
                    s_shift_reg <= {i_data, s_shift_reg[DWIDTH-1:1]};
                    bit_counter    <= 1;
                end else if (state_r == RECEIVING) begin
                    s_shift_reg <= {i_data, s_shift_reg[DWIDTH-1:1]};
                    if (bit_counter < DWIDTH - 1) begin
                        bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                    end
                end
            end
        end
    end

    // Output logic
    assign o_data = s_shift_reg;
    assign o_ready = (state_r == IDLE) && (bit_counter == 0) && i_load;

endmodule
