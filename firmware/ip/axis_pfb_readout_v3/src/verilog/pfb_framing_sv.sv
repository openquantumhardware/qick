// -----------------------------------------------------------------------------
// pfb_framing_sv : SystemVerilog behavioural translation of pfb_framing.vhd
// -----------------------------------------------------------------------------
// Generates the periodic framing pulse (fr_out) for the polyphase FIR bank.
// A free-running mod-N counter (advanced only when tready & tvalid) asserts
// fr_out at count N-1. An FSM re-aligns on fr_sync then waits WAIT_C = 10*N
// cycles before re-checking sync.
//
// Cycle-accurate, literal FSM translation of the original VHDL.
// ceil(log2(x)) -> $clog2(x).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pfb_framing_sv #(
    // Number of channels.
    parameter int N = 8
)(
    // Reset and clock.
    input  logic rstn,
    input  logic clk,

    // Framing.
    input  logic tready,
    input  logic tvalid,
    input  logic fr_sync,
    output logic fr_out
);

    // Number of bits of N.
    localparam int N_LOG2      = (N > 1) ? $clog2(N) : 1;

    // Wait value.
    localparam int WAIT_C      = 10*N;
    localparam int WAIT_C_LOG2 = (WAIT_C > 1) ? $clog2(WAIT_C) : 1;

    // FSM states.
    typedef enum logic [1:0] {
        INIT_ST,
        SHIFT_ST,
        WAIT_ST
    } fsm_type;

    fsm_type current_state, next_state;

    // Free running counter for framing.
    logic [N_LOG2-1:0]      fr_cnt;
    logic                   fr_cnt_en;

    // Counter for waiting until next calibration.
    logic [WAIT_C_LOG2-1:0] wait_cnt;
    logic                   wait_cnt_en;

    // Framing sync.
    logic                   fr_i;

    // Registers.
    always_ff @(posedge clk) begin
        if (rstn == 1'b0) begin
            current_state <= INIT_ST;
            fr_cnt        <= '0;
            wait_cnt      <= '0;
        end else begin
            current_state <= next_state;

            if (fr_cnt_en == 1'b1 && tready == 1'b1 && tvalid == 1'b1) begin
                if (fr_cnt < N_LOG2'(N-1))
                    fr_cnt <= fr_cnt + 1'b1;
                else
                    fr_cnt <= '0;
            end

            if (wait_cnt_en == 1'b1) begin
                if (wait_cnt < WAIT_C_LOG2'(WAIT_C-1))
                    wait_cnt <= wait_cnt + 1'b1;
                else
                    wait_cnt <= '0;
            end
        end
    end

    // Framing sync.
    assign fr_i = (fr_cnt == N_LOG2'(N-1)) ? 1'b1 : 1'b0;

    // Next state logic.
    always_comb begin
        case (current_state)
            INIT_ST: begin
                if (fr_sync == 1'b0)
                    next_state = INIT_ST;
                else
                    next_state = SHIFT_ST;
            end
            SHIFT_ST: begin
                next_state = WAIT_ST;
            end
            WAIT_ST: begin
                if (wait_cnt == WAIT_C_LOG2'(WAIT_C-1))
                    next_state = INIT_ST;
                else
                    next_state = WAIT_ST;
            end
            default: next_state = INIT_ST;
        endcase
    end

    // Output logic.
    always_comb begin
        fr_cnt_en   = 1'b0;
        wait_cnt_en = 1'b0;
        case (current_state)
            INIT_ST: begin
                fr_cnt_en   = 1'b1;
            end
            SHIFT_ST: ;
            WAIT_ST: begin
                fr_cnt_en   = 1'b1;
                wait_cnt_en = 1'b1;
            end
            default: ;
        endcase
    end

    // Assign outputs.
    assign fr_out = fr_i;

endmodule
