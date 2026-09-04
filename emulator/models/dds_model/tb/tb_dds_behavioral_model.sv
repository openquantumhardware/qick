module tb_dds_behavioral_model();
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

integer cycle_count;
integer compared_samples;
integer mismatch_count;
integer valid_mismatch_count;
integer data_mismatch_count;
integer mismatch_print_count;
integer mismatch_print_limit;

int unsigned rand_seed;

// The DDS IP can dither output LSBs while the behavioral model does not.
// Treat differences within this signed-amplitude tolerance as equivalent.
localparam int DITHER_LSB_TOL = 2**5;

logic signed [15:0] os_i;
logic signed [15:0] os_q;
logic signed [15:0] ip_i;
logic signed [15:0] ip_q;
logic [15:0] diff_i_abs;
logic [15:0] diff_q_abs;
logic data_match_within_dither_tol;


dds_behavioral_model #(
	.DDS_LATENCY (10)
) DUT1 (
    .aclk                   (aclk),
    .s_axis_phase_tvalid    (s_axis_phase_tvalid),
    .s_axis_phase_tdata     (s_axis_phase_tdata),
    .m_axis_data_tvalid     (m_axis_data_tvalid_os),
    .m_axis_data_tdata      (m_axis_data_tdata_os)
);

sg_v6_dds_compiler_0
	DUT2 
	(
  		.aclk					(aclk					),
  		.s_axis_phase_tvalid	(s_axis_phase_tvalid	),
  		.s_axis_phase_tdata		(s_axis_phase_tdata		),
  		.m_axis_data_tvalid		(m_axis_data_tvalid_ip		),
  		.m_axis_data_tdata		(m_axis_data_tdata_ip		)
	);

assign  s_axis_phase_tdata = {7'b0000000, sync, phase_seed, phase_inc};
assign  os_i = $signed(m_axis_data_tdata_os[15:0]);
assign  os_q = $signed(m_axis_data_tdata_os[31:16]);
assign  ip_i = $signed(m_axis_data_tdata_ip[15:0]);
assign  ip_q = $signed(m_axis_data_tdata_ip[31:16]);
assign  diff_i_abs = (os_i >= ip_i) ? (os_i - ip_i) : (ip_i - os_i);
assign  diff_q_abs = (os_q >= ip_q) ? (os_q - ip_q) : (ip_q - os_q);
assign  data_match_within_dither_tol = (diff_i_abs <= DITHER_LSB_TOL) && (diff_q_abs <= DITHER_LSB_TOL);

task automatic drive_cycle(
	input logic vld,
	input logic sync_stb,
	input logic [31:0] seed,
	input logic [31:0] inc
);
begin
	s_axis_phase_tvalid <= vld;
	sync                <= sync_stb;
	phase_seed          <= seed;
	phase_inc           <= inc;
	@(posedge aclk);
end
endtask

task automatic drive_idle(input integer cycles);
begin
	for (int i = 0; i < cycles; i = i + 1) begin
		drive_cycle(1'b0, 1'b0, 32'd0, 32'd0);
	end
end
endtask

task automatic run_constant_burst(
	input string scenario_name,
	input logic [31:0] seed,
	input logic [31:0] inc,
	input integer cycles
);
begin
	$display("[TB] Scenario: %s (seed=%0d, inc=%0d, cycles=%0d)", scenario_name, seed, inc, cycles);
	for (int i = 0; i < cycles; i = i + 1) begin
		drive_cycle(1'b1, (i == 0), seed, inc);
	end
end
endtask

task automatic run_sparse_valid_random(
	input string scenario_name,
	input integer cycles,
	input integer valid_pct,
	input integer sync_pct
);
	logic vld;
	logic sync_stb;
	logic [31:0] seed;
	logic [31:0] inc;
begin
	$display("[TB] Scenario: %s (cycles=%0d, valid_pct=%0d, sync_pct=%0d)", scenario_name, cycles, valid_pct, sync_pct);
	for (int i = 0; i < cycles; i = i + 1) begin
		vld      = ($urandom(rand_seed) % 100) < valid_pct;
		seed     = $urandom(rand_seed);
		inc      = $urandom(rand_seed);
		sync_stb = vld && (($urandom(rand_seed) % 100) < sync_pct);
		drive_cycle(vld, sync_stb, seed, inc);
	end
end
endtask

initial begin
	s_axis_phase_tvalid = 0;
	sync                = 0;
	phase_seed          = 0;
	phase_inc           = 0;

	cycle_count         = 0;
	compared_samples    = 0;
	mismatch_count      = 0;
	valid_mismatch_count = 0;
	data_mismatch_count = 0;
	mismatch_print_count = 0;
	mismatch_print_limit = 20;

	rand_seed           = 32'h1a2b3c4d;

	// Start after some settle time.
	repeat (10) @(posedge aclk);

	run_constant_burst("high_inc_long_burst", 32'd0,          32'd10000000, 1100);
	drive_idle(20);

	run_constant_burst("mid_inc_long_burst",  32'd0,          32'd1300000,  1100);
	drive_idle(20);

	run_constant_burst("seeded_mid_inc",      32'd1500,       32'd1300000,  1100);
	drive_idle(20);

	run_constant_burst("zero_inc_dc",         32'd123456789,  32'd0,        256);
	drive_idle(20);

	run_constant_burst("max_inc_wrap",        32'hfffff000,   32'hffffffff, 512);
	drive_idle(20);

	// Back-to-back sync strobes with changing seed/inc.
	$display("[TB] Scenario: back_to_back_sync");
	drive_cycle(1'b1, 1'b1, 32'd0,         32'd1500);
	drive_cycle(1'b1, 1'b1, 32'd100000,    32'd2000000);
	drive_cycle(1'b1, 1'b1, 32'hffff0000,  32'h00010001);
	for (int i = 0; i < 200; i = i + 1) begin
		drive_cycle(1'b1, 1'b0, 32'hffff0000, 32'h00010001);
	end
	drive_idle(20);

	// Sync pulses separated by invalid cycles.
	$display("[TB] Scenario: sync_with_bubbles");
	drive_cycle(1'b1, 1'b1, 32'd777,  32'd150000);
	drive_cycle(1'b0, 1'b0, 32'd0,    32'd0);
	drive_cycle(1'b0, 1'b0, 32'd0,    32'd0);
	drive_cycle(1'b1, 1'b1, 32'd2048, 32'd2500000);
	for (int i = 0; i < 300; i = i + 1) begin
		drive_cycle(1'b1, 1'b0, 32'd2048, 32'd2500000);
	end
	drive_idle(20);

	run_sparse_valid_random("sparse_valid_random", 1200, 60, 5);
	drive_idle(20);

	run_sparse_valid_random("dense_valid_random",  1500, 95, 8);

	// Flush pipeline for final comparisons.
	drive_idle(64);

	$display("[TB] Compared samples: %0d", compared_samples);
	$display("[TB] Mismatch summary: total=%0d, valid=%0d, data=%0d",
		mismatch_count, valid_mismatch_count, data_mismatch_count);

	if (mismatch_count > 0) begin
		$fatal(1, "[TB] FAIL: Found %0d mismatches between behavioral model and DDS IP.", mismatch_count);
	end

	$display("[TB] PASS: No mismatches detected between behavioral model and DDS IP.");
	$finish();
end

always @(posedge aclk) begin
	cycle_count <= cycle_count + 1;

	if (m_axis_data_tvalid_os !== m_axis_data_tvalid_ip) begin
		mismatch_count <= mismatch_count + 1;
		valid_mismatch_count <= valid_mismatch_count + 1;
		if (mismatch_print_count < mismatch_print_limit) begin
			$display("[TB][VALID_MISMATCH] cycle=%0d os_valid=%b ip_valid=%b in_valid=%b in_sync=%b seed=0x%08h inc=0x%08h",
				cycle_count, m_axis_data_tvalid_os, m_axis_data_tvalid_ip,
				s_axis_phase_tvalid, sync, phase_seed, phase_inc);
			mismatch_print_count <= mismatch_print_count + 1;
		end
	end

	if (m_axis_data_tvalid_os && m_axis_data_tvalid_ip) begin
		compared_samples <= compared_samples + 1;
		if (!data_match_within_dither_tol) begin
			mismatch_count <= mismatch_count + 1;
			data_mismatch_count <= data_mismatch_count + 1;
			if (mismatch_print_count < mismatch_print_limit) begin
				$display("[TB][DATA_MISMATCH] cycle=%0d os_data=0x%08h ip_data=0x%08h abs_diff_i=%0d abs_diff_q=%0d tol=%0d in_valid=%b in_sync=%b seed=0x%08h inc=0x%08h",
					cycle_count, m_axis_data_tdata_os, m_axis_data_tdata_ip,
					diff_i_abs, diff_q_abs, DITHER_LSB_TOL,
					s_axis_phase_tvalid, sync, phase_seed, phase_inc);
				mismatch_print_count <= mismatch_print_count + 1;
			end
		end
	end
end

always begin
	aclk <= 0;
	#10;
	aclk <= 1;
	#10;
end

endmodule