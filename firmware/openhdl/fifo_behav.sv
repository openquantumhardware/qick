// Verilog behavioral implementation of the modified XPM based FIFO in qick/firmware/hdl/fiio_xpm.sv

module fifo_behav 

    #(
        // Data width.
        parameter int B = 16,
        
        // Fifo depth.
        parameter int N = 4
    )

    (
        input  logic           rstn,
        input  logic           clk, 

        // write I/F.
        input  logic           wr_en,
        input  logic [B-1 : 0] din,

        // read I/F.
        input  logic           rd_en,
        output logic [B-1 : 0] dout,

        // Flags.
        output logic full,
        output logic empty
    );

    // Pointers.
    logic [$clog2(N)-1 : 0] wptr;
    logic [$clog2(N)-1 : 0] rptr;

    // Memory signals.
    logic                mem_wea;
    logic [B-1 : 0]      mem_dob;

    // Flags.
    logic                full_i;
    logic                empty_i;

    bram_simple_dp_behav #(
        .N     ( $clog2(N) ),
        .B     ( B         )
    ) bram (
        .clk   ( clk       ),
        .ena   ( 1'b1      ),
        .enb   ( rd_en     ),
        .wea   ( mem_wea   ),
        .addra ( wptr      ),
        .addrb ( rptr      ),
        .dia   ( din       ),
        .dob   ( mem_dob   )
    );

    // Memory connections.
    assign mem_wea = (full_i == 1'b0) ? wr_en : 1'b0;

    // Full/empty signals.
    assign full_i  = (wptr == rptr-1) ? 1'b1 : 1'b0;
    assign empty_i = (wptr == rptr  ) ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin
        if ( rstn == 1'b0 ) begin
            wptr <= 0;
            rptr <= 0;
        end else begin
            // Write.
            if ( wr_en == 1'b1 && full_i == 1'b0 ) begin
                // write data.

                // write pointer.
                wptr <= wptr + 1;
            end

            // Read.
            if ( rd_en == 1'b1 && empty_i == 1'b0 ) begin
                // Read data.
                
                // Increment pointer.
                rptr <= rptr + 1;
            end
        end
    end

    // Assign outputs.
    assign dout  = mem_dob;
    assign full  = full_i;
    assign empty = empty_i;


endmodule