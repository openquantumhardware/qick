module dds_behavioral_model_tb();
logic           aclk;
logic           s_axis_phase_tvalid;
logic [71:0]    s_axis_phase_tdata;

logic           m_axis_data_tvalid_os;
logic [31:0]    m_axis_data_tdata_os;

logic           sync;
logic [31:0]    phase_seed;
logic [31:0]    phase_inc;

wire		m_axis_data_tvalid_ip;
wire [31:0]	m_axis_data_tdata_ip;

reg			resync_r;
reg	[31:0]	poff_r;
reg	[31:0]	pinc_r;

integer i;

dds_behavioral_model DUT1 (
    .aclk                   (aclk),
    .s_axis_phase_tvalid    (s_axis_phase_tvalid),
    .s_axis_phase_tdata     (s_axis_phase_tdata),
    .m_axis_data_tvalid     (m_axis_data_tvalid_os),
    .m_axis_data_tdata      (m_axis_data_tdata_os)
);

dds_compiler_0
	DUT2 
	(
  		.aclk					(aclk					),
  		.s_axis_phase_tvalid	(s_axis_phase_tvalid	),
  		.s_axis_phase_tdata		(s_axis_phase_tdata		),
  		.m_axis_data_tvalid		(m_axis_data_tvalid_ip		),
  		.m_axis_data_tdata		(m_axis_data_tdata_ip		)
	);

assign  s_axis_phase_tdata = {7'b0000000, sync, phase_seed, phase_inc};

initial begin
    s_axis_phase_tvalid <= 0;
    sync                <= 0;
    phase_seed          <= 0;
    phase_inc           <= 0;
    resync_r            <= 0;
    poff_r              <= 0;
    pinc_r              <= 0;
    #200;

    @(posedge aclk);
    s_axis_phase_tvalid <= 1;
    sync                <= 1;
    phase_seed          <= 0;
    phase_inc           <= 10000000;
    resync_r            <= 1;
    poff_r              <= 0;
    pinc_r              <= 10000000;

	for (int i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync    			<= 0;
		resync_r            <= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;
    
    @(posedge aclk);
    s_axis_phase_tvalid <= 1;
    sync                <= 1;
    phase_seed          <= 0;
    phase_inc           <= 1300000;
    resync_r            <= 1;
    poff_r              <= 0;
    pinc_r              <= 1300000;

	for (int i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync    			<= 0;
		resync_r            <= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;
    
    @(posedge aclk);
    s_axis_phase_tvalid <= 1;
    sync                <= 1;
    phase_seed          <= 1500;
    phase_inc           <= 1300000;
    resync_r            <= 1;
    poff_r              <= 1500;
    pinc_r              <= 1300000;

	for (int i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync    			<= 0;
		resync_r            <= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;
    
    s_axis_phase_tvalid <= 0;
    sync                <= 0;
    phase_seed          <= 0;
    phase_inc           <= 0;
    resync_r            <= 0;
    poff_r              <= 0;
    pinc_r              <= 0;
    #200;
    
    @(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;
    
    @(posedge aclk);
    s_axis_phase_tvalid <= 1;
    sync                <= 1;
    phase_seed          <= 150000;
    phase_inc           <= 2000000;
    resync_r            <= 1;
    poff_r              <= 150000;
    pinc_r              <= 2000000;

	for (int i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync    			<= 0;
		resync_r            <= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

    #200;

	// 801 pulses of f = 1500;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	phase_seed			<= 0;
	phase_inc			<= 1500;
	resync_r            <= 1;
    poff_r              <= 0;
    pinc_r              <= 1500;

	for (int i=0; i<800; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		sync	    		<= 0;
		resync_r            <= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	sync    			<= 1;
	resync_r            <= 1;

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