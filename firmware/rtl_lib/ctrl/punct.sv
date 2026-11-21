`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : punct
// Project: QICK / axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
//! @file    punct.sv
//!
//! @brief   Puncturing / sample selector within a data frame.
//!
//! @details
//!
//! Selects one sample per frame for downstream processing (the KID simulator
//! only needs to act on a single sample position within each incoming frame).
//!
//! A frame is a burst of valid samples terminated by i_din_last. This block
//! keeps a running count of accepted samples in the current frame (reset by
//! the last sample) and asserts o_dout_en exactly on the sample whose index
//! equals i_id_reg. Downstream, the enable is typically ANDed with the valid:
//!
//!     kidsim_din_valid = punct.o_dout_valid & punct.o_dout_en
//!
//! so the KID simulator processes only sample number ID_REG of every frame
//! (i.e. it "punctures" the stream, picking one resonator/sample slot).
//!
//! Timing:
//!   - valid and last are pipelined by 2 stages -> latency = 2.
//!   - the sample counter advances on each output-valid beat and wraps to 0
//!     on the frame's last sample.
//!   - o_dout_en is combinational on the counter, aligned with o_dout_valid.
//!
//! Frame example (ID_REG = 2):
//!   sample idx:  0   1   2   3   4(last)   0   1 ...
//!   o_dout_en:   0   0   1   0   0         0   0 ...
//!
//! @author  @lharnaldi
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module punct (
    input  logic        i_clk,        //! Clock.
    input  logic        i_rstn,       //! Synchronous active-low reset.

    input  logic        i_din_valid,  //! Input sample valid.
    input  logic        i_din_last,   //! Marks the last sample of a frame.

    output logic        o_dout_valid, //! Output valid (latency 2).
    output logic        o_dout_last,  //! Output last (latency 2).
    output logic        o_dout_en,    //! High on the selected sample (idx == ID_REG).

    input  logic [15:0] i_id_reg      //! Index of the sample to select per frame.
);

    //! Valid/last pipeline (2 stages).
    logic valid_r1, valid_r2;
    logic last_r1,  last_r2;

    //! In-frame sample counter.
    logic [15:0] cnt;

    //! Latched selection index.
    logic [15:0] id_reg_r;

    //! Selection flag: current sample index matches the requested one.
    logic flag;
    assign flag = (id_reg_r == cnt);

    always_ff @(posedge i_clk) begin
        if (i_rstn == 1'b0) begin
            valid_r1 <= 1'b0;
            valid_r2 <= 1'b0;
            last_r1  <= 1'b0;
            last_r2  <= 1'b0;
            cnt      <= '0;
            id_reg_r <= '0;
        end else begin
            //! Pipeline valid and last.
            valid_r1 <= i_din_valid;
            valid_r2 <= valid_r1;
            last_r1  <= i_din_last;
            last_r2  <= last_r1;

            //! Count accepted samples in the current frame; wrap on last.
            if (valid_r2 == 1'b1) begin
                if (last_r2 == 1'b1)
                    cnt <= '0;
                else
                    cnt <= cnt + 1'b1;
            end

            //! Latch the selection index.
            id_reg_r <= i_id_reg;
        end
    end

    //! Outputs.
    assign o_dout_valid = valid_r2;
    assign o_dout_last  = last_r2;
    assign o_dout_en    = flag;

endmodule

