// Lets the real FIR Compiler (VHDL, renamed fir_ip_real by run_vendor_check.sh) be instantiated by down_conversion_dynro / readout_top_dynro
// under the name and with the parameters of the model fir_decim8_dynro.
`timescale 1ns/1ps
module fir_decim8_dynro #(parameter int N_DDS = 8, parameter int LATENCY = 67)(
  input logic aclk, input logic s_axis_data_tvalid, output logic s_axis_data_tready,
  input logic [N_DDS*32-1:0] s_axis_data_tdata, output logic m_axis_data_tvalid, output logic [31:0] m_axis_data_tdata);
  fir_ip_real u (.aclk(aclk), .s_axis_data_tvalid(s_axis_data_tvalid), .s_axis_data_tready(s_axis_data_tready),
                 .s_axis_data_tdata(s_axis_data_tdata), .m_axis_data_tvalid(m_axis_data_tvalid), .m_axis_data_tdata(m_axis_data_tdata));
endmodule
