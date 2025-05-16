// Data is I,Q.
// I: lower B bits.
// Q: upper B bits.
module avg_buffer (
                   // Reset and clock for readout data path
                   s_axis_aclk ,
                   s_axis_aresetn ,

                   // Reset and clock for writing weights
                   s_axi_aclk ,
                   s_axi_aresetn ,

                   // Trigger input.
                   trigger ,

                   // AXIS Slave for memory programming
                   s1_axis_tvalid,
                   s1_axis_tdata,
                   s1_axis_tready,

                   // AXIS Slave for input data.
                   s_axis_tvalid ,
                   s_axis_tready ,
                   s_axis_tdata ,

                   // Reset and clock for m0, m1 and m2.
                   m_axis_aclk ,
                   m_axis_aresetn ,

                   // AXIS Master for averaged output.
                   m0_axis_tvalid ,
                   m0_axis_tready ,
                   m0_axis_tdata ,
                   m0_axis_tlast ,

                   // AXIS Master for raw output.
                   m1_axis_tvalid ,
                   m1_axis_tready ,
                   m1_axis_tdata ,
                   m1_axis_tlast ,

                   // AXIS Master for register output.
                   m2_axis_tvalid ,
                   m2_axis_tready ,
                   m2_axis_tdata ,

                   // Registers.
                   AVG_START_REG ,
                   AVG_ADDR_REG ,
                   AVG_LEN_REG ,
                   AVG_PHOTON_MODE_REG ,
                   AVG_H_THRSH_REG ,
                   AVG_L_THRSH_REG ,
                   AVG_DR_START_REG ,
                   AVG_DR_ADDR_REG ,
                   AVG_DR_LEN_REG ,
                   BUF_START_REG ,
                   BUF_ADDR_REG ,
                   BUF_LEN_REG ,
                   BUF_DR_START_REG ,
                   BUF_DR_ADDR_REG ,
                   BUF_DR_LEN_REG,
                   WGT_DW_ADDR_REG,
                   WGT_DW_START_REG
                   );

   ////////////////
   // Parameters //
   ////////////////
   // Memory depth.
   parameter N_AVG = 14;
   parameter N_BUF = 14;
   parameter N_WGT = 14;

   // Number of bits.
   parameter B = 16;

   ///////////
   // Ports //
   ///////////
   input s_axis_aclk;
   input s_axis_aresetn;

   input s_axi_aclk;
   input s_axi_aresetn;

   input trigger;

   input s_axis_tvalid;
   output s_axis_tready;
   input [2*B-1:0] s_axis_tdata;

   input s1_axis_tvalid;
   input [2*B-1:0] s1_axis_tdata;
   output s1_axis_tready;

   input m_axis_aclk;
   input m_axis_aresetn;

   output m0_axis_tvalid;
   input m0_axis_tready;
   output [4*B-1:0] m0_axis_tdata;
   output m0_axis_tlast;

   output m1_axis_tvalid;
   input m1_axis_tready;
   output [2*B-1:0] m1_axis_tdata;
   output m1_axis_tlast;

   output m2_axis_tvalid;
   input m2_axis_tready;
   output [4*B-1:0] m2_axis_tdata;

   input AVG_START_REG;
   input [N_AVG-1:0] AVG_ADDR_REG;
   input [31:0] AVG_LEN_REG;
   input AVG_PHOTON_MODE_REG;
   input [B-1:0] AVG_H_THRSH_REG;
   input [B-1:0] AVG_L_THRSH_REG;
   input AVG_DR_START_REG;
   input [N_AVG-1:0] AVG_DR_ADDR_REG;
   input [N_AVG-1:0] AVG_DR_LEN_REG;
   input BUF_START_REG;
   input [N_BUF-1:0] BUF_ADDR_REG;
   input [N_BUF-1:0] BUF_LEN_REG;
   input BUF_DR_START_REG;
   input [N_BUF-1:0] BUF_DR_ADDR_REG;
   input [N_BUF-1:0] BUF_DR_LEN_REG;

   input [N_WGT-1:0] WGT_DW_ADDR_REG;
   input WGT_DW_START_REG;


   //////////////////////
   // Internal signals //
   //////////////////////

   wire trigger_resync;

   wire [2*B-1 : 0] s_axis_filtered_tdata;
   wire s_axis_filtered_tvalid;


   //////////////////
   // Architecture //
   //////////////////

   // trigger_resync
   synchronizer_n
     #(
       .N (2)
       )
   trigger_resync_i (
                     .rstn (s_axis_aresetn ),
                     .clk (s_axis_aclk ),
                     .data_in (trigger ),
                     .data_out (trigger_resync )
                     );

   matched_filter
     #(
       .N (N_WGT),
       .B (B)
       )
   matchfilt_i
     (
      .clk (s_axis_aclk),

      .write_rstn (s_axi_aresetn),
      .write_clk (s_axi_aclk),

      .trigger_i (trigger_resync),
      .trigger_o (trigger_dsp_latency_compensated),

      .s_axis_tready(s1_axis_tready),
      .s_axis_tvalid(s1_axis_tvalid),
      .s_axis_tdata(s1_axis_tdata),

      .din_valid_i (s_axis_tvalid),
      .din_i (s_axis_tdata),

      .dout_valid_o (s_axis_filtered_tvalid),
      .dout_o (s_axis_filtered_tdata),

      .DW_ADDR_REG(WGT_DW_ADDR_REG),
      .WE_REG(WGT_DW_START_REG),
      .LEN_REG(AVG_LEN_REG)
      );


   // Average block.
   avg_top
     #(
       .N (N_AVG ),
       .B (B )
       )
   avg_top_i
     (
      // Reset and clock.
      .rstn (s_axis_aresetn ),
      .clk (s_axis_aclk ),

      // Trigger input.
      .trigger_i (trigger_dsp_latency_compensated ),

      // Data input.
      .din_valid_i (s_axis_filtered_tvalid ),
      .din_i (s_axis_filtered_tdata ),

      // Reset and clock for M_AXIS_*
      .m_axis_aclk (m_axis_aclk ),
      .m_axis_aresetn (m_axis_aresetn ),

      // AXIS Master for output.
      .m0_axis_tvalid (m0_axis_tvalid ),
      .m0_axis_tready (m0_axis_tready ),
      .m0_axis_tdata (m0_axis_tdata ),
      .m0_axis_tlast (m0_axis_tlast ),

      // AXIS Master for register output.
      .m1_axis_tvalid (m2_axis_tvalid ),
      .m1_axis_tready (m2_axis_tready ),
      .m1_axis_tdata (m2_axis_tdata ),

      // Registers.
      .AVG_START_REG (AVG_START_REG ),
      .AVG_ADDR_REG (AVG_ADDR_REG ),
      .AVG_LEN_REG (AVG_LEN_REG ),
      .DR_START_REG (AVG_DR_START_REG ),
      .DR_ADDR_REG (AVG_DR_ADDR_REG ),
      .DR_LEN_REG (AVG_DR_LEN_REG ),
      .AVG_PHOTON_MODE_REG (AVG_PHOTON_MODE_REG),
      .AVG_H_THRSH_REG (AVG_H_THRSH_REG ),
      .AVG_L_THRSH_REG (AVG_L_THRSH_REG )
      );

   // Buffer block.
   buffer_top
     #(
       .N (N_BUF ),
       .B (B )
       )
   buffer_top_i
     (
      // Reset and clock.
      .rstn (s_axis_aresetn ),
      .clk (s_axis_aclk ),

      // Trigger input.
      .trigger_i (trigger_dsp_latency_compensated ),

      // Data input.
      .din_valid_i (s_axis_filtered_tvalid ),
      .din_i (s_axis_filtered_tdata ),

      // AXIS Master for output.
      .m_axis_aclk (m_axis_aclk ),
      .m_axis_aresetn (m_axis_aresetn ),
      .m_axis_tvalid (m1_axis_tvalid ),
      .m_axis_tready (m1_axis_tready ),
      .m_axis_tdata (m1_axis_tdata ),
      .m_axis_tlast (m1_axis_tlast ),

      // Registers.
      .BUF_START_REG (BUF_START_REG ),
      .BUF_ADDR_REG (BUF_ADDR_REG ),
      .BUF_LEN_REG (BUF_LEN_REG ),
      .DR_START_REG (BUF_DR_START_REG ),
      .DR_ADDR_REG (BUF_DR_ADDR_REG ),
      .DR_LEN_REG (BUF_DR_LEN_REG )
      );

   // Assign outputs.
   assign s_axis_tready = 1'b1;

endmodule

