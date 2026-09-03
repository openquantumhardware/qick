// -----------------------------------------------------------------------------
// rd2axi_sv : SystemVerilog behavioural translation of rd2axi.vhd
// -----------------------------------------------------------------------------
// Adapts the standard (registered-read) FIFO read interface into a
// first-word-fall-through / AXIS-style read interface. A 4-state FSM issues an
// initial pre-fetch (READ_FIRST) then keeps data valid while the FIFO is
// non-empty, handling the last-word drain.
//
// Cycle-accurate, literal FSM translation of the original VHDL.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module rd2axi_sv #(
    // Data width.
    parameter int B = 16
)(
    input  logic            rstn,
    input  logic            clk,

    // FIFO Read I/F.
    output logic            fifo_rd_en,
    input  logic [B-1:0]    fifo_dout,
    input  logic            fifo_empty,

    // Read I/F.
    input  logic            rd_en,
    output logic [B-1:0]    dout,
    output logic            empty
);

    // FSM states.
    typedef enum logic [1:0] {
        WAIT_EMPTY_ST,
        READ_FIRST_ST,
        READ_ST,
        READ_LAST_ST
    } fsm_state;

    fsm_state current_state, next_state;

    logic wait_empty_state;
    logic read_first_state;
    logic read_state;

    logic fifo_rd_en_i;
    logic empty_i;

    // State register.
    always_ff @(posedge clk) begin
        if (rstn == 1'b0) begin
            current_state <= WAIT_EMPTY_ST;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic.
    always_comb begin
        case (current_state)
            WAIT_EMPTY_ST: begin
                if (fifo_empty == 1'b1)
                    next_state = WAIT_EMPTY_ST;
                else
                    next_state = READ_FIRST_ST;
            end
            READ_FIRST_ST: begin
                next_state = READ_ST;
            end
            READ_ST: begin
                if (fifo_empty == 1'b0) begin
                    next_state = READ_ST;
                end else begin
                    if (rd_en == 1'b1)
                        next_state = WAIT_EMPTY_ST;
                    else
                        next_state = READ_LAST_ST;
                end
            end
            READ_LAST_ST: begin
                if (rd_en == 1'b0)
                    next_state = READ_LAST_ST;
                else
                    next_state = WAIT_EMPTY_ST;
            end
            default: next_state = WAIT_EMPTY_ST;
        endcase
    end

    // Output logic.
    always_comb begin
        wait_empty_state = 1'b0;
        read_first_state = 1'b0;
        read_state       = 1'b0;
        empty_i          = 1'b0;
        case (current_state)
            WAIT_EMPTY_ST: begin
                wait_empty_state = 1'b1;
                read_first_state = 1'b0;
                read_state       = 1'b0;
                empty_i          = 1'b1;
            end
            READ_FIRST_ST: begin
                wait_empty_state = 1'b0;
                read_first_state = 1'b1;
                read_state       = 1'b0;
                empty_i          = 1'b1;
            end
            READ_ST: begin
                wait_empty_state = 1'b0;
                read_first_state = 1'b0;
                read_state       = 1'b1;
                empty_i          = 1'b0;
            end
            READ_LAST_ST: begin
                wait_empty_state = 1'b0;
                read_first_state = 1'b0;
                read_state       = 1'b0;
                empty_i          = 1'b0;
            end
            default: ;
        endcase
    end

    // FIFO read enable signal.
    assign fifo_rd_en_i = read_first_state | (read_state & rd_en);

    // Assign outputs.
    assign fifo_rd_en = fifo_rd_en_i;
    assign dout       = (empty_i == 1'b0) ? fifo_dout : '0;
    assign empty      = empty_i;

endmodule
