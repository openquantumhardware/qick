// Block to execute single read/write operation over a memory.
module mem_rw # (
   parameter	N = 10 ,	// Memory depth (2**N).
   parameter 	B = 16  // Memory width.
)(
   input  wire            aclk_i     ,
   input  wire            aresetn_i  ,
   input  wire            rw_i       , //0-READ , 1-Write
   input  wire            exec_i     ,
   output wire            exec_ack_o ,
   input  wire   [N-1:0]  addr_i     ,
   input  wire   [B-1:0]  di_i       ,
   output wire   [B-1:0]  do_o       ,
   output wire            mem_we_o   ,
   output wire   [B-1:0]  mem_di_o   ,
   input  wire   [B-1:0]  mem_do_i   ,
   output wire   [N-1:0]  mem_addr_o );

// States.
localparam  INIT_ST  = 0;
localparam  READ0_ST = 1;
localparam  READ1_ST = 2;
localparam  WRITE_ST = 3;
localparam  ACK_ST   = 4;

// State register.
reg   [2:0] state;

// Flags.
reg      init_state;
reg      re_int;
reg      we_int;
reg      ack_int;

// Address/data register.
reg   [N-1:0] addr_r;
reg   [B-1:0] din_r;
reg   [B-1:0] dout_r;

// Registers.
always @(posedge aclk_i) begin
   if (~aresetn_i) begin
      state    <= INIT_ST;
      addr_r   <= 0;
      din_r    <= 0;
      dout_r   <= 0;
   end else begin
		// State register.
   case(state)
      INIT_ST:
         if (exec_i == 1'b1)
            if (rw_i == 1'b0)
               state <= READ0_ST;
            else
               state <= WRITE_ST;
      READ0_ST:
         state <= READ1_ST;
      READ1_ST:
         state <= ACK_ST;
      WRITE_ST:
         state <= ACK_ST;
      ACK_ST:
         if (exec_i == 1'b0)
            state <= INIT_ST;
   endcase	
   // Address/data register.
   if (init_state) begin
      addr_r	<= addr_i;
      din_r	<= di_i;
   end
   if (re_int)
      dout_r	<= mem_do_i;
	end
end 

// FSM outputs.
always @(state) begin
   // Default.
   init_state	= 0;
   re_int		= 0;
   we_int		= 0;
   ack_int		= 0;
   case (state)
      INIT_ST:
         init_state	= 1;
      //READ0_ST:
      READ1_ST:
         re_int		= 1;
      WRITE_ST:
         we_int		= 1;
      ACK_ST:
         ack_int		= 1;
   endcase
end

// Assign outputs.
assign exec_ack_o = ack_int;
assign do_o       = dout_r ;
assign mem_we_o   = we_int ;
assign mem_di_o   = din_r  ;
assign mem_addr_o = addr_r ;

endmodule
