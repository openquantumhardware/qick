// -----------------------------------------------------------------------------
// pfb_ctrl_pkg_sv : SystemVerilog translation of pfb_ctrl_pkg.vhd
// -----------------------------------------------------------------------------
// Provides f_nbit_axis(): rounds ceil(log2(ARG)) up to the next multiple of 8
// (8/16/24/32), returning the AXIS tdata width used by the PFB config path.
// Returns -1 if the required width exceeds 32 bits (matches VHDL behaviour).
//
// Literal translation of the original VHDL function.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

package pfb_ctrl_pkg_sv;

    function automatic int f_nbit_axis(input int arg);
        int arg_log2;
        int tmp;
        begin
            arg_log2 = $clog2(arg);   // ceil(log2(arg))
            if (arg_log2 <= 8)        tmp = 8;
            else if (arg_log2 <= 16)  tmp = 16;
            else if (arg_log2 <= 24)  tmp = 24;
            else if (arg_log2 <= 32)  tmp = 32;
            else                      tmp = -1;
            return tmp;
        end
    endfunction

endpackage
