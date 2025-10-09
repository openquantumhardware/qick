// tb_fifo_behav.sv 
// Purpose: testbench to verify hand translated VHDL to SV
// Checks output consistency with the params used in the system (B=160, N=16)
// and an optional random value provided via paramters from the simulator script


module tb_fifo_behav;

    // add arbitary number of parameter configurations
    localparam int numIter = 1;
    localparam int B [numIter] = '{160};
    localparam int N [numIter] = '{16};

    logic rstn;
    logic clk;

    // clock generation
    always begin
        clk = 1; #5; clk = 0; #5;
    end

    // reset generation
    initial begin
        rstn = 0; #45; rstn = 1;
    end

    // End simuation after 10000 clk cycles
    initial begin
        repeat (10000) @(posedge clk);
        $stop;
    end

// generate 2 copies if random params are given for B and N
generate for (genvar i = 0; i < numIter; i++) begin : genBlk

    logic wr_en;
    logic rd_en;
    logic full1, empty1;
    logic full2, empty2;
    logic full3, empty3;

    logic [B[i]-1 : 0] din = 0;
    logic [B[i]-1 : 0] dout1;
    logic [B[i]-1 : 0] dout2;
    logic [B[i]-1 : 0] dout3;

    // random input stream generation
    always @(negedge clk) begin // TODO: weird reset behavior...
        std::randomize(wr_en);
        std::randomize(rd_en);
        std::randomize(din);
    end

    // Check output consistency
    always @(negedge clk) begin
        assert((dout1 == dout2) && (dout1 == dout3)) else begin
            $error(
                "ERROR: Data out mismatch! -- B=%d, N=%d\n    SV:     %h\n    VHDL:   %h\n    XILINX: %h\n",
                B[i], N[i], dout1, dout2, dout3
                );
        end

        assert((empty1 == empty2) && (empty1 == empty3)) else begin
            $error(
                "ERROR: Empty signal mismatch! -- B=%d, N=%d\n    SV:     %b\n    VHDL:   %b\n    XILINX: %b\n",
                B[i], N[i], empty1, empty2, empty3
                );
        end

        assert((full1 == full2) && (full1 == full3)) else begin
            $error(
                "ERROR: full signal mismatch! -- B=%d, N=%d\n    SV:     %b\n    VHDL:   %b\n    XILINX: %b\n",
                B[i], N[i], full1, full2, full3
                );
        end
    end


    // our hand translation
    fifo_behav #(
        .B (B[i]),
        .N (N[i])
    ) fifo_behav (
        .rstn  ( rstn ),
        .clk   ( clk ),
        .wr_en ( wr_en ),
        .din   ( din ),
        .rd_en ( rd_en ),
        .dout  ( dout1 ),
        .full  ( full1 ),
        .empty ( empty1 )
    );

    // VHDL implementation from SigGen v5 
    fifo #(
        .B (B[i]),
        .N (N[i])
    ) fifo (
        .rstn  ( rstn ),
        .clk   ( clk ),
        .wr_en ( wr_en ),
        .din   ( din ),
        .rd_en ( rd_en ),
        .dout  ( dout2 ),
        .full  ( full2 ),
        .empty ( empty2 )
    );

    // Xilinx IP based fifo 
    fifo_xpm #(
        .B (B[i]),
        .N (N[i])
    ) fifo_xmp (
        .rstn  ( rstn ),
        .clk   ( clk ),
        .wr_en ( wr_en ),
        .din   ( din ),
        .rd_en ( rd_en ),
        .dout  ( dout3 ),
        .full  ( full3 ),
        .empty ( empty3 )
    );


end endgenerate


endmodule