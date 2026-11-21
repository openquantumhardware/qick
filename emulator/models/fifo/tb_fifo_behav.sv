
module tb;

   logic aresetn, aclk, fifo_wr_en, fifo_rd_en;
   logic fifo_empty_sv, fifo_full_sv, fifo_empty_xpm, fifo_full_xpm;
   logic fifo_empty_ai, fifo_full_ai;
   logic [159:0] fifo_din, fifo_dout_sv, fifo_dout_xpm, fifo_dout_ai;

   fifo_behav
   #(
      // Data width.
      .B  (160),
     
      // Fifo depth.
      .N  (16)
   )
   DUT
   (
      .rstn  (aresetn ),
      .clk   (aclk    ),

      // Write I/F.
      .wr_en    (fifo_wr_en ),
      .din    (fifo_din  ),
     
      // Read I/F.
      .rd_en    (fifo_rd_en ),
      .dout     (fifo_dout_sv  ),
     
      // Flags.
      .full   (fifo_full_sv ),
      .empty  (fifo_empty_sv   )
   );
   
   fifo_behav_ai
   #(
      // Data width.
      .B  (160),
     
      // Fifo depth.
      .N  (16)
   )
   DUT_AI
   (
      .rstn  (aresetn ),
      .clk   (aclk    ),

      // Write I/F.
      .wr_en    (fifo_wr_en ),
      .din    (fifo_din  ),
     
      // Read I/F.
      .rd_en    (fifo_rd_en ),
      .dout     (fifo_dout_ai  ),
     
      // Flags.
      .full   (fifo_full_ai ),
      .empty  (fifo_empty_ai   )
   );
   
   fifo_xpm
   #(
      // Data width.
      .B  (160),
     
      // Fifo depth.
      .N  (16)
   )
   REF
   (
      .rstn  (aresetn ),
      .clk   (aclk    ),

      // Write I/F.
      .wr_en    (fifo_wr_en ),
      .din    (fifo_din  ),
     
      // Read I/F.
      .rd_en    (fifo_rd_en ),
      .dout     (fifo_dout_xpm  ),
     
      // Flags.
      .full   (fifo_full_xpm ),
      .empty  (fifo_empty_xpm   )
   );

   initial begin
   
     fifo_din = 0;
     fifo_wr_en = 0;
     fifo_rd_en = 0;
     aresetn = 0; #22; aresetn = 1;
   
   end
   
   always begin
   
     aclk = 1; #5; aclk = 0; #5;
   
   end
   
   initial begin
   
     #50; @(posedge aclk); // #2;
     
     @(negedge aclk);
     fifo_rd_en = 1;
     
     #20;
    @(negedge aclk);     
     fifo_wr_en = 1;
     
     #30;
     @(negedge aclk);

     fifo_rd_en = 0;

     
     #170;
     @(negedge aclk);

     fifo_rd_en = 1;
     
     #10;
     @(negedge aclk);
     
     fifo_wr_en = 0;
     
     #50;
     @(negedge aclk);
     
     fifo_wr_en = 1;
     
     #10;
     @(negedge aclk);
     
     fifo_wr_en = 0;
     
     #50;
     @(negedge aclk);
     
     fifo_rd_en = 0;
     
     #20;
     @(negedge aclk);
     
     fifo_rd_en = 1;
     
     #10;
     @(negedge aclk);
     
     fifo_rd_en = 0;
     
     #10;
     @(negedge aclk);
     
     fifo_rd_en = 1;
     
     #200;
     @(negedge aclk);
     
     fifo_rd_en = 0;
     
     #20;
     @(negedge aclk);
     
     fifo_wr_en = 1;
     fifo_rd_en = 1;
     
     #30;
     @(negedge aclk);
     
     fifo_wr_en = 0;
     fifo_rd_en = 0;
     
     #40;
     @(negedge aclk);
     
     fifo_wr_en = 1;
     
     #10;
     @(negedge aclk);
     
     fifo_wr_en = 0;
     
     #50;
     @(negedge aclk);
     
     fifo_rd_en = 1;
     
     #10;
     @(negedge aclk);
     
     fifo_rd_en = 0;
     
     #100;
     @(negedge aclk);
     
     $finish();
   
   end
   
   always @(posedge aclk) begin
   
     if(aresetn) begin
       #2; 
       @(negedge aclk);
       fifo_din <= fifo_din + 1;
     end
     
   end


  logic [15:0] fifo_din_15_0, fifo_dout_sv_15_0, fifo_dout_xpm_15_0, fifo_dout_ai_15_0;
  assign fifo_din_15_0 = fifo_din[15:0];
  assign fifo_dout_sv_15_0 = fifo_dout_sv[15:0];
  assign fifo_dout_xpm_15_0 = fifo_dout_xpm[15:0];
  assign fifo_dout_ai_15_0 = fifo_dout_ai[15:0];



endmodule


// // tb_fifo_behav.sv 
// // Purpose: testbench to verify hand translated VHDL to SV
// // Checks output consistency with the params used in the system (B=160, N=16)
// // and an optional random value provided via paramters from the simulator script


// module tb_fifo_behav; import std::*;

//     // add arbitary number of parameter configurations
//     localparam int numIter = 1;
//     localparam int B [numIter] = '{160};
//     localparam int N [numIter] = '{16};

//     logic rstn;
//     logic clk;

//     // clock generation
//     always begin
//         clk = 1; #5; clk = 0; #5;
//     end

//     // reset generation
//     initial begin
//         rstn = 0; #45; rstn = 1;
//     end

//     // End simuation after 10000 clk cycles
//     initial begin
//         repeat (10000) @(posedge clk);
//         $stop;
//     end

// // generate 2 copies if random params are given for B and N
// generate for (genvar i = 0; i < numIter; i++) begin : genBlk

//     logic wr_en;
//     logic rd_en;
//     logic full1, empty1;
//     logic full2, empty2;
//     logic full3, empty3;

//     logic [B[i]-1 : 0] din = 0;
//     logic [B[i]-1 : 0] dout1;
//     logic [B[i]-1 : 0] dout2;
//     logic [B[i]-1 : 0] dout3;

//         logic [B[i]-1 : 0] gated_dout1;
//         logic [B[i]-1 : 0] gated_dout2;
//         logic [B[i]-1 : 0] gated_dout3;

//     initial begin
//         wr_en = 0;
//         rd_en = 0;
//         din   = 0;
//         #150;

//         // random input stream generation
//         forever @(posedge clk) begin // TODO: weird reset behavior...'
//             std::randomize(wr_en);
//             std::randomize(rd_en);
//             #1; std::randomize(din);
//         end
//     end

//     // // Check output consistency
//     // always @(negedge clk) begin
//     //     assert((dout1 == dout2) && (dout1 == dout3)) else begin
//     //         $error(
//     //             "ERROR: Data out mismatch! -- B=%d, N=%d\n    SV:     %h\n    VHDL:   %h\n    XILINX: %h\n",
//     //             B[i], N[i], dout1, dout2, dout3
//     //             );
//     //     end

//     //     assert((empty1 == empty2) && (empty1 == empty3)) else begin
//     //         $error(
//     //             "ERROR: Empty signal mismatch! -- B=%d, N=%d\n    SV:     %b\n    VHDL:   %b\n    XILINX: %b\n",
//     //             B[i], N[i], empty1, empty2, empty3
//     //             );
//     //     end

//     //     assert((full1 == full2) && (full1 == full3)) else begin
//     //         $error(
//     //             "ERROR: full signal mismatch! -- B=%d, N=%d\n    SV:     %b\n    VHDL:   %b\n    XILINX: %b\n",
//     //             B[i], N[i], full1, full2, full3
//     //             );
//     //     end
//     // end


//     // our hand translation
//     fifo_behav #(
//         .B (B[i]),
//         .N (N[i])
//     ) fifo_behav (
//         .rstn  ( rstn ),
//         .clk   ( clk ),
//         .wr_en ( wr_en ),
//         .din   ( din ),
//         .rd_en ( rd_en ),
//         .dout  ( dout1 ),
//         .full  ( full1 ),
//         .empty ( empty1 )
//     );

//     // VHDL implementation from SigGen v5 
//     fifo #(
//         .B (B[i]),
//         .N (N[i])
//     ) fifo (
//         .rstn  ( rstn ),
//         .clk   ( clk ),
//         .wr_en ( wr_en ),
//         .din   ( din ),
//         .rd_en ( rd_en ),
//         .dout  ( dout2 ),
//         .full  ( full2 ),
//         .empty ( empty2 )
//     );

//     // Xilinx IP based fifo 
//     fifo_xpm #(
//         .B (B[i]),
//         .N (N[i])
//     ) fifo_xmp (
//         .rstn  ( rstn ),
//         .clk   ( clk ),
//         .wr_en ( wr_en ),
//         .din   ( din ),
//         .rd_en ( rd_en ),
//         .dout  ( dout3 ),
//         .full  ( full3 ),
//         .empty ( empty3 )
//     );


//     assign gated_dout1 = rd_en ? dout1 : '0;
//     assign gated_dout2 = rd_en ? dout2 : '0;
//     assign gated_dout3 = rd_en ? dout3 : '0;

// end endgenerate


// endmodule