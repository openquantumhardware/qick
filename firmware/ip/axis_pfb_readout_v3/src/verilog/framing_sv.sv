// -----------------------------------------------------------------------------
// framing_sv : SystemVerilog behavioural translation of framing.vhd
// -----------------------------------------------------------------------------
// Aligns the incoming stream to FFT frame boundaries before the SSR FFT.
// After an initial NWAIT=256 reset period it passes data through (valid_i high)
// while monitoring s_axis_tlast against an internal CYCLES=NFFT/SSR counter; if
// tlast lands in the wrong position it re-syncs (S1/S2) and drops one frame.
// tdata/tvalid are delayed by two pipeline stages.
//
// Cycle-accurate, literal FSM translation of the original VHDL.
// ceil(log2(x)) -> $clog2(x).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module framing_sv #(
    // SSR and FFT Length.
    parameter int NFFT = 16,
    parameter int SSR  = 4,
    // Bits.
    parameter int B    = 16
)(
    // Reset and clock.
    input  logic                    aresetn,
    input  logic                    aclk,

    // AXIS Slave.
    input  logic [2*SSR*B-1:0]      s_axis_tdata,
    input  logic                    s_axis_tlast,
    input  logic                    s_axis_tvalid,

    // Synced outputs.
    output logic [2*SSR*B-1:0]      tdata,
    output logic                    tvalid
);

    localparam int NWAIT        = 256;
    localparam int NWAIT_LOG2   = $clog2(NWAIT);
    localparam int CYCLES       = NFFT/SSR;
    localparam int CYCLES_LOG2  = (CYCLES > 1) ? $clog2(CYCLES) : 1;

    localparam int DATA_W       = 2*SSR*B;

    // FSM states.
    typedef enum logic [2:0] {
        INIT_ST,
        RST_ST,
        S0_ST,
        S1_ST,
        S2_ST
    } fsm_type;

    fsm_type current_state, next_state;

    logic                   rst_state;

    logic [DATA_W-1:0]      data_r;
    logic [DATA_W-1:0]      data_rr;

    logic                   valid_i;
    logic                   valid_r;
    logic                   valid_rr;

    logic [NWAIT_LOG2-1:0]  cnt_nwait;
    logic [CYCLES_LOG2-1:0] cnt;

    // Registers.
    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            current_state <= INIT_ST;
            data_r        <= '0;
            data_rr       <= '0;
            valid_r       <= 1'b0;
            valid_rr      <= 1'b0;
            cnt_nwait     <= '0;
            cnt           <= '0;
        end else begin
            current_state <= next_state;

            // Pipeline registers.
            data_r   <= s_axis_tdata;
            data_rr  <= data_r;
            valid_r  <= valid_i;
            valid_rr <= valid_r;

            // Counters.
            if (rst_state == 1'b1) begin
                cnt_nwait <= cnt_nwait + 1'b1;
            end

            if (valid_i == 1'b1) begin
                if (cnt < CYCLES_LOG2'(CYCLES-1))
                    cnt <= cnt + 1'b1;
                else
                    cnt <= '0;
            end
        end
    end

    // Next state logic.
    always_comb begin
        case (current_state)
            INIT_ST: begin
                next_state = RST_ST;
            end
            RST_ST: begin
                if (cnt_nwait < NWAIT_LOG2'(NWAIT-1))
                    next_state = RST_ST;
                else
                    next_state = S0_ST;
            end
            S0_ST: begin
                if (s_axis_tlast == 1'b1) begin
                    // Check if tlast is in the right position.
                    if (cnt == CYCLES_LOG2'(CYCLES-1))
                        next_state = S0_ST;
                    else
                        next_state = S1_ST;   // tlast in the wrong position.
                end else begin
                    next_state = S0_ST;
                end
            end
            S1_ST: begin
                // Wait until a frame is completed.
                if (cnt == CYCLES_LOG2'(CYCLES-1))
                    next_state = S2_ST;
                else
                    next_state = S1_ST;
            end
            S2_ST: begin
                // Wait for the next tlast.
                if (s_axis_tlast == 1'b1)
                    next_state = S0_ST;
                else
                    next_state = S2_ST;
            end
            default: next_state = INIT_ST;
        endcase
    end

    // Output logic.
    always_comb begin
        rst_state = 1'b0;
        valid_i   = 1'b0;
        case (current_state)
            INIT_ST: ;
            RST_ST:  rst_state = 1'b1;
            S0_ST:   valid_i   = 1'b1;
            S1_ST:   valid_i   = 1'b1;
            S2_ST:   ;
            default: ;
        endcase
    end

    // Assign outputs.
    assign tdata  = data_rr;
    assign tvalid = valid_rr;

endmodule
