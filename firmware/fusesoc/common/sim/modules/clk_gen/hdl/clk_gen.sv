///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : clk_gen
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    clk_gen.sv
//!
//! @brief   Simulation clock: frequency, phase and duty cycle as parameters.
//!
//! @details
//!
//! FREQ is in Hz, PHASE in degrees of one period, DUTY_CYCLE in percent of the
//! period spent high. Times are in the time unit of the simulation (the
//! testbenches use 1 ns: -timescale of their xsim target, which cov_run.py also
//! hands to Verilator).
//!
//! o_clk is low until i_enable is high; PHASE later it rises and then toggles.
//! At t=0 with i_enable already high it starts at once (every testbench ties
//! .i_enable(1'b1)). When i_enable drops, the period in progress completes and
//! o_clk stays low until i_enable rises again, PHASE after which it restarts.
//!
//! Written for xsim and for Verilator --timing (no reliance on an x->1 event at
//! t=0, which Verilator does not produce).
//!
//! @author  QICK Development Team
//!
//! @version 2.0

module clk_gen #(
    parameter FREQ       = 100e6, //! Hz
    parameter PHASE      = 0,     //! degrees
    parameter DUTY_CYCLE = 50     //! percent high
)(
    input  logic i_enable,
    output logic o_clk
);

    localparam real PERIOD    = 1.0e9 / FREQ;
    localparam real HIGH_TIME = PERIOD * DUTY_CYCLE / 100.0;
    localparam real LOW_TIME  = PERIOD - HIGH_TIME;
    localparam real DELAY     = PERIOD * PHASE / 360.0;

    initial $display("clk_gen: %0.3f MHz (period %0.3f), phase %0d deg, duty %0d %%",
                     FREQ / 1.0e6, PERIOD, PHASE, DUTY_CYCLE);

    initial begin
        o_clk = 1'b0;
        forever begin
            wait (i_enable === 1'b1);
            #(DELAY);
            while (i_enable === 1'b1) begin
                o_clk = 1'b1;
                #(HIGH_TIME);
                o_clk = 1'b0;
                #(LOW_TIME);
            end
        end
    end

endmodule
