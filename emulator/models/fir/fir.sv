module fir #(
    parameter int TAP_COUNT   = 120,   // Number of taps
    parameter int DATA_WIDTH  = 16,    // Input sample width
    parameter int COEF_WIDTH  = 16,    // Coefficient width
    parameter int DECIM       = 8,     // Decimation rate
    parameter int CHANNELS    = 2,     // Dual-path input
    parameter int P_SAMPLES   = 8      // Parallel samples per path
)(
    input  logic                        clk,
    input  logic                        nrst,          // Active-low reset
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic [CHANNELS*P_SAMPLES*DATA_WIDTH-1:0] s_tdata,
    output logic                        m_tvalid,
    output logic signed [31:0]          m_tdata        // combined output {Qs,Is}
);

    // Internal Signals
    logic enable_fir;
    logic signed [47:0] temp_acc0;
    logic signed [47:0] temp_acc1;
    logic signed [31:0] t_data_next;
    logic signed [15:0] acc0;
    logic signed [31:0] acc1;

    logic               s_tready_int;
    assign s_tready = s_tready_int;
    
    logic m_tvalid_next;

    // Delay lines for each path
    logic signed [DATA_WIDTH-1:0] taps0 [0:TAP_COUNT-1] /*= '{default: '0}*/; // Qs
    logic signed [DATA_WIDTH-1:0] taps1 [0:TAP_COUNT-1] /*= '{default: '0}*/; // Is

    // Shared coefficient memory
    logic signed [COEF_WIDTH-1:0] coeffs [0:TAP_COUNT-1];

    // Extra shift register for latency purposes
    logic signed [31:0] delay_tdata [0:65] /*= '{default: '0}*/;
    logic [65:0] delay_tvalid;
    logic taps_have_x;

    // Load coefficients from file
    integer fd;
    initial begin
        fd = $fopen("fir_coe.txt", "r");
        if (fd == 0) begin
            $fatal("### FIR coefficients file not found ###");
        end
        $fclose(fd);
        // $display("Loading FIR coefficients...");
        $readmemh("fir_coe.txt", coeffs);
    end

    // Ready/Valid handshake
    always_ff @(posedge clk) begin
        if (!nrst) begin
            s_tready_int <= 1'b0;
            enable_fir <= 1'b0;
        end else begin
            s_tready_int <= 1'b1;
            enable_fir <= s_tvalid && s_tready_int;
        end
    end

    // Detect invalid data within both tap lines (prevents invalid data propagating through the system during simulation)
    always_comb begin
        taps_have_x = 0;
        for (int i = 0; i < TAP_COUNT; i++) begin
            if ((^taps0[i] === 1'bX) || (^taps1[i] === 1'bX)) begin
                taps_have_x = 1;
            end
        end
    end

    // Delay line shift and load
    always_ff @(posedge clk) begin
        if (!nrst) begin
            for (int i = 0; i < TAP_COUNT; i++) begin
                taps0[i] <= '0;
                taps1[i] <= '0;
            end
        end
        else if (enable_fir) begin 
            for (int i = TAP_COUNT-1; i >= P_SAMPLES; i--) begin
                    taps0[i] <= $signed(taps0[i-P_SAMPLES]);
                    taps1[i] <= $signed(taps1[i-P_SAMPLES]);
            end 
            for (int j = P_SAMPLES-1; j >= 0; j--) begin
                taps0[j] <= $signed(s_tdata[('d240 - (2*(j*DATA_WIDTH)+ DATA_WIDTH)) +: DATA_WIDTH]); // Qs
                taps1[j] <= $signed(s_tdata[('d240 - (2*(j*DATA_WIDTH))) +: DATA_WIDTH]); // Is
            end
    end
    end
    
    // MAC and Normalization Logic
    always_comb begin
        temp_acc0     = '0;
        temp_acc1     = '0;
        acc0          = '0;
        acc1          = '0;
        t_data_next   = '0;
        m_tvalid_next = '0;

        if (nrst && enable_fir && !taps_have_x) begin
            for (int k = 0; k < TAP_COUNT; k++) begin
                temp_acc0 += $signed(taps0[k]) * $signed(coeffs[k]);
                temp_acc1 += $signed(taps1[k]) * $signed(coeffs[k]);
            end
            acc0        = temp_acc0 >>> 19;
            acc1        = temp_acc1 >>> 19;
            t_data_next = {acc1[15:0], acc0[15:0]};
            m_tvalid_next = 1'b1;
        end
    end
    
    // Shift registers to match Xilinx's FIR Compiler delay
    always_ff@(posedge clk) begin
        if (!nrst) begin
            for (int i = 0; i < 65; i++) begin
                delay_tdata[i] <= '0;
            end
            delay_tvalid <= '0;
        end else begin
            for(int i = 0; i < 'd65; i++) begin 
                delay_tdata[i+1] <= delay_tdata[i];
            end
            
            delay_tdata[0] <= t_data_next;       
            delay_tvalid <= {m_tvalid_next, delay_tvalid[64:1]};
        end
    end
    
    // AXIS valid flag output
    assign m_tvalid = delay_tvalid[0];
    
    // AXIS data output
    always_ff@(posedge clk) begin 
        if (!nrst) begin
            m_tdata <= '0;
        end else if (m_tvalid) begin
            m_tdata <= delay_tdata[64];
        end
    end
    
endmodule