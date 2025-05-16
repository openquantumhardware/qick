// Data is I,Q.
// I: lower B bits.
// Q: upper B bits.
module avg (
            // Reset and clock.
            rstn ,
            clk ,

            // Trigger input.
            trigger_i ,

            // Data input.
            din_valid_i ,
            din_i ,

            // Memory interface.
            mem_we_o ,
            mem_addr_o ,
            mem_di_o ,

            // Registers.
            START_REG ,
            ADDR_REG ,
            LEN_REG ,
            PHOTON_MODE_REG,
            H_THRSH_REG ,
            L_THRSH_REG
            );

   ////////////////
   // Parameters //
   ////////////////
   // Memory depth.
   parameter N = 14;

   // Number of bits.
   parameter B = 16;

   ///////////
   // Ports //
   ///////////
   input rstn;
   input clk;

   input trigger_i;

   input din_valid_i;
   input [2*B-1:0] din_i;

   output mem_we_o;
   output [N-1:0] mem_addr_o;
   output [4*B-1:0] mem_di_o;


   input START_REG;
   input [N-1:0] ADDR_REG;
   input [31:0] LEN_REG;
   input PHOTON_MODE_REG;
   input [B-1:0] H_THRSH_REG;
   input [B-1:0] L_THRSH_REG;

   //////////////////////
   // Internal signals //
   //////////////////////
   // States.
   typedef enum { INIT_ST ,
                  START_ST ,
                  TRIGGER_ST ,
                  AVG_ST ,
                  QOUT_ST ,
                  WRITE_MEM_ST ,
                  WAIT_TRIGGER_ST
                  } state_t;

   // State register.
   (* fsm_encoding = "one_hot" *) state_t state;

   reg start_state;
   reg trigger_state;
   reg avg_state;
   reg qout_state;
   reg write_mem_state;

   // Edge counter states.
   reg high_state;
   reg high_state_reg;

   // Counter.
   reg [31:0] cnt;

   // Registers.
   reg [N-1:0] addr_r;
   reg [31:0] len_r;
   reg photon_mode_r;
   reg signed [B-1:0] h_thrsh_r;
   reg signed [B-1:0] l_thrsh_r;


   // Input data.
   wire signed [B-1:0] din_ii, din_qq;

   // Accumulators.
   reg signed [2*B-1:0] acc_i, acc_q;
   reg [4*B-1:0] acc_photon;

   // Quantized outputs.
   reg [4*B-1:0] out_result_r;


   //////////////////
   // Architecture //
   //////////////////
   assign din_ii = din_i[B-1:0];
   assign din_qq = din_i[2*B-1:B];

   // Registers.
   always @(posedge clk) begin
      if (~rstn) begin
         // State register.
         state <= INIT_ST;

         // Counter.
         cnt <= 0;

         // Registers.
         addr_r <= 0;
         len_r <= 0;
         photon_mode_r <= 1'b0;
         h_thrsh_r <= 0;
         l_thrsh_r <= 0;
         high_state <= 1'b0;
         high_state_reg <= 1'b0;

         // Accumulators.
         acc_i <= 0;
         acc_q <= 0;
         acc_photon <= 0;

         // Quantized outputs.
         out_result_r <= 0;

      end
      else begin
         // State register.
         case (state)
           INIT_ST:
             state <= START_ST;

           START_ST:
             if ( START_REG == 1'b1)
               state <= TRIGGER_ST;

           TRIGGER_ST:
             if ( START_REG == 1'b0 )
               state <= START_ST;
             else if ( trigger_i == 1'b1 )
               state <= AVG_ST;

           AVG_ST:
             if ( cnt == len_r-1 && din_valid_i == 1'b1 )
               state <= QOUT_ST;

           QOUT_ST:
             state <= WRITE_MEM_ST;

           WRITE_MEM_ST:
             state <= WAIT_TRIGGER_ST;

           WAIT_TRIGGER_ST:
             if ( START_REG == 1'b0 )
               state <= START_ST;
             else if ( trigger_i == 1'b0 ) begin
                state <= TRIGGER_ST;
             end
         endcase

         // Counter.
         if ( avg_state == 1'b1 ) begin
            if ( din_valid_i == 1'b1) begin
               cnt <= cnt + 1;
            end
         end
         else begin
            cnt <= 0;
         end

         // Registers.
         if ( start_state == 1'b1 ) begin
            addr_r <= ADDR_REG;
            len_r <= LEN_REG;
            photon_mode_r <= PHOTON_MODE_REG;
            h_thrsh_r <= H_THRSH_REG;
            l_thrsh_r <= L_THRSH_REG;
         end
         else if ( write_mem_state == 1'b1 ) begin
            addr_r <= addr_r + 1;
         end

         // Accumulators.
         if ( trigger_state == 1'b1 ) begin
            acc_i <= 0;
            acc_q <= 0;
            acc_photon <= 0;
            high_state <= 1'b0;
            high_state_reg <= 1'b0;
         end
         else if ( avg_state == 1'b1 && din_valid_i == 1'b1 ) begin
            // Accumulator counter.
            if ( photon_mode_r == 1'b0 ) begin
               acc_i <= acc_i + din_ii;
               acc_q <= acc_q + din_qq;
            end
            // Rising edge counter.
            else if ( high_state == 1'b1 && high_state_reg == 1'b0)
              acc_photon <= acc_photon + 1;
         end

         // Edge counter detect.
         high_state_reg <= high_state;
         if ( din_ii > h_thrsh_r )
           high_state <= 1'b1;
         else if ( din_ii < l_thrsh_r )
           high_state <= 1'b0;

         // Quantized outputs.
         if ( qout_state == 1'b1 ) begin
            if ( photon_mode_r == 1'b0 )
              out_result_r <= {acc_q,acc_i};
            else
              out_result_r <= acc_photon;
         end
      end
   end

   // FSM outputs.
   always_comb begin
      // Default.
      start_state = 0;
      trigger_state = 0;
      avg_state = 0;
      qout_state = 0;
      write_mem_state = 0;

      case (state)
        //INIT_ST:

        START_ST:
          start_state = 1'b1;

        TRIGGER_ST:
          trigger_state = 1'b1;

        AVG_ST:
          avg_state = 1'b1;

        QOUT_ST:
          qout_state = 1'b1;

        WRITE_MEM_ST:
          write_mem_state = 1'b1;

        //WAIT_TRIGGER_ST:
      endcase
   end

   // Assign outputs.

   // BRAM for result storage
   assign mem_we_o = write_mem_state;
   assign mem_addr_o = addr_r;
   assign mem_di_o = out_result_r;

endmodule

