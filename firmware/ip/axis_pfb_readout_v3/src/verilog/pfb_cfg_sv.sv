// -----------------------------------------------------------------------------
// pfb_cfg_sv : SystemVerilog behavioural translation of pfb_cfg.vhd
// -----------------------------------------------------------------------------
// Drives the FIR-compiler reload/config AXIS stream: once cfg_en & tready are
// asserted it streams a counter 0..N-1 (tvalid high, tlast on the last count),
// then holds in END_ST until cfg_en drops.
//
// Cycle-accurate, literal FSM translation of the original VHDL.
// f_nbit_axis(N) comes from pfb_ctrl_pkg_sv.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pfb_cfg_sv
    import pfb_ctrl_pkg_sv::f_nbit_axis;
#(
    // Number of channels.
    parameter int N = 8
)(
    // Reset and clock.
    input  logic                        rstn,
    input  logic                        clk,

    // Filter config.
    input  logic                        cfg_en,
    input  logic                        tready,
    output logic                        tvalid,
    output logic                        tlast,
    output logic [f_nbit_axis(N)-1:0]   tdata
);

    // Number of bits.
    localparam int NBITS = f_nbit_axis(N);

    // FSM states.
    typedef enum logic [1:0] {
        INIT_ST,
        CNT_ST,
        END_ST
    } fsm_type;

    fsm_type current_state, next_state;

    // tlast.
    logic tlast_i;

    // Counter for config.
    logic [NBITS-1:0] cfg_cnt;
    logic             cfg_cnt_en;

    // Registers.
    always_ff @(posedge clk) begin
        if (rstn == 1'b0) begin
            current_state <= INIT_ST;
            cfg_cnt       <= '0;
        end else begin
            current_state <= next_state;
            if (cfg_cnt_en == 1'b1) begin
                cfg_cnt <= cfg_cnt + 1'b1;
            end
        end
    end

    // tlast.
    assign tlast_i = (cfg_cnt == NBITS'(N-1)) ? 1'b1 : 1'b0;

    // Next state logic.
    always_comb begin
        case (current_state)
            INIT_ST: begin
                if (cfg_en == 1'b1 && tready == 1'b1)
                    next_state = CNT_ST;
                else
                    next_state = INIT_ST;
            end
            CNT_ST: begin
                if (cfg_cnt == NBITS'(N-1))
                    next_state = END_ST;
                else
                    next_state = CNT_ST;
            end
            END_ST: begin
                if (cfg_en == 1'b1)
                    next_state = END_ST;
                else
                    next_state = INIT_ST;
            end
            default: next_state = INIT_ST;
        endcase
    end

    // Output logic.
    always_comb begin
        cfg_cnt_en = 1'b0;
        case (current_state)
            INIT_ST: ;
            CNT_ST:  cfg_cnt_en = 1'b1;
            END_ST:  ;
            default: ;
        endcase
    end

    // Assign outputs.
    assign tvalid = cfg_cnt_en;
    assign tlast  = tlast_i;
    assign tdata  = cfg_cnt;

endmodule
