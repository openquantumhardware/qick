module axis_read # (
   parameter   N = 10 ,  // Memory depth (2**N).
   parameter   B = 16    // Memory width.
)(
   input          aclk_i            ,
   input          aresetn_i         ,
   input  [N-1:0] addr_i            ,
   input  [N-1:0] len_i             ,
   input          exec_i            ,
   output         exec_ack_o        ,
   output         mem_we_o          ,
   output [N-1:0] mem_addr_o        ,
   input  [B-1:0] mem_do_i          ,
   input          m_axis_tready_i   ,
   output [B-1:0] m_axis_tdata_o    ,
   output         m_axis_tlast_o    ,
   output         m_axis_tvalid_o   );

// States.
localparam  INIT_ST     = 0;
localparam  LOAD0_ST    = 1;
localparam  LOAD1_ST    = 2;
localparam  SEND_ST     = 3;
localparam  ACK_ST      = 4;
localparam  END_ST      = 5;

// State register.
reg   [2:0]    state;
// State flags.
reg			load0_state;
reg			load1_state;
reg			send_state;
reg			ack_int;
// Start address and length.
reg	[N-1:0]	addr_r;
reg	[N-1:0]	len_r;
// Counter.
reg	[N-1:0] cnt;
// Selection (0: mem, 1: reg).
reg			sel_r;

// Data register.
reg	[B-1:0]	data_r;
wire		data_en;

// Registers.
always @(posedge aclk_i) begin
   if (~aresetn_i) begin
      // State register.
      state	<= INIT_ST;
      // Start address and length.
      addr_r	<= 0;
      len_r	<= 0;
      // Counter.
      cnt		<= 0;
      // Selection (0: mem, 1: reg).
      sel_r	<= 0;
      // Data register.
      data_r	<= 0;
   end
   else begin
      // State register.
      case(state)
         INIT_ST:
            if (exec_i == 1'b1)
               state <= LOAD0_ST;
         LOAD0_ST:
            state <= LOAD1_ST;
   
         LOAD1_ST:
            state <= SEND_ST;
   
         SEND_ST:
            if (cnt == len_r-1 && m_axis_tready_i)
               state <= ACK_ST;
   
         ACK_ST:
            state <= END_ST;	
   
         END_ST:
            if (exec_i == 1'b0)
               state <= INIT_ST;
      endcase
      // Start address and length.
      if (load0_state)
         addr_r	<= addr_i;
      else if (load1_state || (send_state && m_axis_tready_i))
         addr_r <= addr_r + 1;
      if (load0_state)
         len_r	<= len_i;
      // Counter.
      if (load0_state)
         cnt	<= 0;
      else if (send_state && m_axis_tready_i)
         cnt <= cnt + 1;
      
      // Selection (0: mem, 1: reg).
      if (send_state && ~m_axis_tready_i)
         sel_r	<= 1;
      else
         sel_r	<= 0;
      
      // Data register.
      if (data_en)
         data_r	<= mem_do_i;
   end
end 

// FSM outputs.
always @(state) begin
	// Default.
	load0_state = 0;
	load1_state = 0;
	send_state	= 0;
	ack_int		= 0;
	case (state)
		//INIT_ST:
		LOAD0_ST:   load0_state = 1;
		LOAD1_ST:   load1_state = 1;
		SEND_ST:    send_state  = 1;
		ACK_ST:     ack_int     = 1;
		//END_ST:
	endcase
end

// Data enable.
assign data_en	= m_axis_tready_i | ~sel_r;

// Assign outputs.
assign m_axis_tdata_o   = (sel_r == 1)? data_r : mem_do_i;
assign m_axis_tlast_o   = (cnt == len_r-1) & send_state;
assign m_axis_tvalid_o  = send_state;
assign mem_we_o         = 1'b0;
assign mem_addr_o       = addr_r;
assign exec_ack_o       = ack_int;

endmodule
