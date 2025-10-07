module dds_behavioral_model_tb();
logic           aclk;
logic           s_axis_phase_tvalid;
logic [71:0]    s_axis_phase_tdata;
logic           m_axis_data_tvalid;
logic [31:0]    m_axis_data_tdata;

logic           sync;
logic [31:0]    phase_seed;
logic [31:0]    phase_inc;

dds_behavioral_model DUT (
    .aclk                   (aclk),
    .s_axis_phase_tvalid    (s_axis_phase_tvalid),
    .s_axis_phase_tdata     (s_axis_phase_tdata),
    .m_axis_data_tvalid     (m_axis_data_tvalid),
    .m_axis_data_tdata      (m_axis_data_tdata)
);

assign  s_axis_phase_tdata = {7'b0000000, sync, phase_seed, phase_inc};

initial begin
    s_axis_phase_tvalid <= 0;
    sync                <= 0;
    phase_seed          <= 0;
    phase_inc           <= 0;
    #200;

    @(posedge aclk);
    s_axis_phase_tvalid <= 1;
    sync                <= 1;
    phase_seed          <= 0;
    phase_inc           <= 10000000;

	for (int i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync    			<= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;

	// 801 pulses of f = 1500;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	phase_seed			<= 0;
	phase_inc			<= 1500;

	for (int i=0; i<800; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync	    		<= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

	#10000;
end
always begin
	aclk <= 0;
	#10;
	aclk <= 1;
	#10;
end
endmodule