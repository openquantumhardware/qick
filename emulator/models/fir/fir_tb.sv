`timescale 1ns/1ps

module fir_tb;

	// Parameters (match DUT)
	localparam int CHANNELS   = 2;
	localparam int DW         = 16;
	localparam int TAP_COUNT  = 120;
	localparam int COEFW      = 16;
	localparam int DECIM      = 8;
	localparam int PSAMPLES   = 8;
	localparam int CLK_PER    = 10;   // 100 MHz
	
	// Parameters for CORDIC
	localparam CORDIC_CLK_PERIOD = 2;
	localparam signed [15:0] PI_POS = 16'h6488;
	localparam signed [15:0] PI_NEG = 16'h9878;
	localparam PHASE_INC_50MHz = 5000;   // phase jump for 50MHz sine 
	localparam PHASE_INC_2MHz = 200; // phase jump for 2MHz sine wave
	
	// internal variables for CORDIC
	logic cordic_clk = 1'b0;
	logic phase_tvalid = 1'b0;
	logic signed [15:0] phase_50MHz = 0;
	logic signed [15:0] phase_2MHz = 0;
	logic sincos_50MHz_tvalid;
	logic sincos_2MHz_tvalid;
	logic signed [15:0] sin_50MHz, cos_50MHz;
	logic signed [15:0] sin_2MHz, cos_2MHz;
	
	logic signed [15:0] noisy_signal = 0;
	logic signed [15:0] filtered_signal;
	
	// Debug signals for xilinx FIR compiler
	logic signed [15:0] m_tdata_half;
	logic signed [15:0] xil_m_tdata_half;

	// DUT I/O
	logic clk;
	logic resetn;                     // active low reset in DUT is "nrst"
	logic s_tvalid;
	logic s_tready;
	logic [CHANNELS*DW*PSAMPLES-1:0] s_tdata;
	logic m_tvalid;
	logic signed [31:0]     m_tdata;
	logic signed            xil_s_tdata;
	logic signed [31:0]     xil_m_tdata;
	
	// Queues
	logic [15:0] expected_outputs [$];
	logic [15:0] outputs [$];

	// Instantiate DUT
	fir #(
		.TAP_COUNT (TAP_COUNT),
		.DATA_WIDTH(DW),
		.COEF_WIDTH(COEFW),
		.DECIM     (DECIM),
		.CHANNELS  (CHANNELS)
	) dut (
		.clk      (clk),
		.nrst     (resetn),
		.s_tvalid (s_tvalid),
		.s_tready (s_tready),
		.s_tdata  (s_tdata),
		.m_tvalid (m_tvalid),
		.m_tdata  (m_tdata)
	);
	
	// Create a 2 MHz sine wave
	cordic_0 cordic_inst_0(
	   .aclk                   (cordic_clk),
	   .s_axis_phase_tvalid    (phase_tvalid),
	   .s_axis_phase_tdata     (phase_2MHz),
	   .m_axis_dout_tvalid     (sincos_2MHz_tvalid),
	   .m_axis_dout_tdata      ({sin_2MHz, cos_2MHz})
	);
	
	// Create a 50 MHz
	cordic_0 cordic_inst_1(
           .aclk                   (cordic_clk),
           .s_axis_phase_tvalid    (phase_tvalid),
           .s_axis_phase_tdata     (phase_50MHz),
           .m_axis_dout_tvalid     (sincos_50MHz_tvalid),
           .m_axis_dout_tdata      ({sin_50MHz, cos_50MHz})
        );
	
	// Instantiate Xilinx FIR Compiler
	fir_compiler_0 fir_xil(
	       .aclk(clk), 
	       .aresetn(resetn), 
	       .s_axis_data_tvalid(s_tvalid),
	       .s_axis_data_tready(xil_s_tready),
	       .s_axis_data_tdata(s_tdata),
	       .m_axis_data_tvalid(xil_m_tvalid),
	       .m_axis_data_tdata(xil_m_tdata)
	);

	// Clock
	always begin clk = 1'b0; #(CLK_PER/2); clk = 1'b1; #(CLK_PER/2); end

	// Coeffs loaded with same file as DUT
	logic signed [15:0] coef  [0:TAP_COUNT-1];
	
	task impulse();
		@(posedge clk);
		s_tvalid <= 1;
		wait(s_tready);
		@(posedge clk);
		s_tdata[255:240] <= 16'h7fff;
		s_tdata[15:0] <= 16'h7fff;
		@(posedge clk);
		s_tdata <= '0;
		s_tvalid <= 0;
	
	endtask
	
	task step();
		@(posedge clk);
		s_tvalid <= 1;
		@(posedge clk);
		wait(s_tready);
		for(int i=0;i<'d527;i++)
			s_tdata[255:240] <= (i < 16) ? '0 : 16'sh7fff;
		@(posedge clk);
		s_tdata <= '0;
		s_tvalid <= 0;
	endtask
	
	// phase sweep
	always @ (posedge cordic_clk)
	   begin
	       phase_tvalid <= 1'b1;
	       
	       // sweep phase to execute 50MHz sine
	       if (phase_50MHz + PHASE_INC_50MHz < PI_POS) begin
	           phase_50MHz <= phase_50MHz + PHASE_INC_50MHz;
	       end else begin 
	           phase_50MHz <= PI_NEG + (phase_50MHz + PHASE_INC_50MHz - PI_POS);
	       end
	       
	       // sweep phase to execute 2MHz sine
	       if (phase_2MHz + PHASE_INC_2MHz < PI_POS) begin
               phase_2MHz <= phase_2MHz + PHASE_INC_2MHz;
           end else begin 
               phase_2MHz <= PI_NEG + (phase_2MHz + PHASE_INC_2MHz - PI_POS);
           end
	       
	   end
	   
	 // create 500 MHz Cordic clock
	   always begin 
	       cordic_clk = #(CORDIC_CLK_PERIOD/2) ~cordic_clk;
	   end
	   
	// sinudoid table
	task sinusoid();
	   begin 
	       @(posedge clk);
           s_tvalid <= 1;
           @(posedge clk);
           wait(s_tready);
           @(posedge clk);
           for (int i = 0; i < 528; i++) begin 
            @(posedge clk);
            s_tdata[255:240] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[239:224] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[223:208] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[207:192] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[191:176] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[175:160] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[159:144] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[143:128] = (sin_50MHz + sin_2MHz) / 2;
            
            s_tdata[127:112] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[111:96] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[95:80] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[79:64] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[63:48] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[47:32] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[31:16] = (sin_50MHz + sin_2MHz) / 2;
            s_tdata[15:0] = (sin_50MHz + sin_2MHz) / 2;
           end
           @(posedge clk);
           s_tdata <= '0;
           s_tvalid <= 0;   
	   end
	endtask
	
	// Fill queues
	always begin 
	   if (xil_m_tvalid)
	       expected_outputs.push_back($signed(xil_m_tdata));
	   @(posedge clk);
	   end
	
	always begin 
	   if (m_tvalid)
          outputs.push_back($signed(m_tdata[31:16]));
      @(posedge clk);
      end
      
    // Visual debugging vectors
    assign m_tdata_half = m_tdata[15:0];
    assign xil_m_tdata_half = xil_m_tdata[15:0];
      
	// check lower 16-bit output values
    task automatic check();
              logic signed [15:0] expected_data;
              logic signed [15:0] received_data;
          
              if (expected_outputs.size() != 0) begin
                  expected_data = expected_outputs.pop_front();
                  received_data = outputs.pop_front();
          
                  if (received_data !== expected_data) begin
                      $error("DATA MISMATCH! Expected %0d, Got %0d", expected_data, received_data);
                  end
                  else begin
                      $display("DATA MATCH! Expected %0d, Got %0d", expected_data, received_data);
                  end
              end
              else begin
                  $error("Received unexpected data! Expected queue is empty");
              end
          endtask
	
	// Reset & init
	initial begin
		clk      = 0;
		resetn   = 0;
		s_tvalid = 0;
		s_tdata  = 256'h0;

		$readmemh("fir_coe.txt", coef);

		// Release reset after some clocks
		repeat (5) @(posedge clk);
		resetn = 1;
		
		// send an impulse
		//impulse();
		//repeat (25) @(posedge clk);

		// send an input step
		//step();
		@(posedge clk);

		// send a sinusoid
		sinusoid();
		repeat (400) @(posedge clk);
		
		while (expected_outputs.size() > 0) begin
            check();
        end

		$display("Simulation done.");
		$finish;
	end

	// Add a timeout
	always begin
		#50_000_000; // 50ms
		$error("Simulation didn't finish");
		$stop;
	end


endmodule