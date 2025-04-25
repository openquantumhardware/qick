/*****************************************************************************
// (c) 2021 Lucas Brasilino <lucas.brasilino@gmail.com> 
//
// This IP module contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
*******************************************************************************/
`timescale 1ns/1ps

`define NONE   4'h0
`define ADD    4'h1
`define SUB    4'h2
`define AND    4'h3
`define XOR    4'h4
`define OR     4'h5
`define NAND   4'h6
`define NOR    4'h7

module axis_exec_op #(
                      parameter integer DATA_WIDTH = 32,
                      parameter integer ADDR_WIDTH = 4,
                      parameter integer MAX_DEPTH_BITS = 3
                      ) (
                         input wire                           ACLK,
                         input wire                           ARESETN,
                         // Master AXI-Stream
                         input wire                           M_AXIS_TREADY,
                         output wire [ DATA_WIDTH-1 : 0 ]     M_AXIS_TDATA,
                         output wire [ (DATA_WIDTH/8)-1 : 0 ] M_AXIS_TKEEP,
                         output wire                          M_AXIS_TLAST,
                         output wire                          M_AXIS_TVALID,
                         // Slave AXI-Stream
                         output wire                          S_AXIS_TREADY,
                         input wire [ DATA_WIDTH-1 : 0 ]      S_AXIS_TDATA,
                         input wire [ (DATA_WIDTH/8)-1 : 0 ]  S_AXIS_TKEEP,
                         input wire                           S_AXIS_TLAST,
                         input wire                           S_AXIS_TVALID,

                         // slave axi-lite write address channel signals
                         input wire [ ADDR_WIDTH-1 : 0 ]      S_AXI_AWADDR,
                         input wire [ 2 : 0 ]                 S_AXI_AWPROT,
                         input wire                           S_AXI_AWVALID,
                         output wire                          S_AXI_AWREADY,

                         // slave axi-lite write data channel signals
                         input wire [ DATA_WIDTH-1:0]         S_AXI_WDATA,
                         input wire [DATA_WIDTH/8-1:0]        S_AXI_WSTRB,
                         input wire                           S_AXI_WVALID,
                         output wire                          S_AXI_WREADY,

                         // slave axi-lite write response channel signals
                         output wire [ 1 : 0 ]                S_AXI_BRESP,
                         output wire                          S_AXI_BVALID,
                         input wire                           S_AXI_BREADY,

                         // slave axi-lite read address channel signals
                         input wire [ ADDR_WIDTH-1 : 0 ]      S_AXI_ARADDR,
                         input wire [ 2 : 0 ]                 S_AXI_ARPROT,
                         input wire                           S_AXI_ARVALID,
                         output wire                          S_AXI_ARREADY,

                         // slave axi-lite read data channel signals
                         output wire [ DATA_WIDTH-1 : 0 ]     S_AXI_RDATA,
                         output wire [ 1 : 0 ]                S_AXI_RRESP,
                         output wire                          S_AXI_RVALID,
                         input wire                           S_AXI_RREADY
                         );

   localparam KEEP_WIDTH = DATA_WIDTH/8;
   localparam FIFO_WIDTH = KEEP_WIDTH+DATA_WIDTH;

   wire                                                       exec_en;
   wire [ 2 : 0 ]                                             op;
   wire [ 3 : 0 ]                                             op_sel;
   wire [ 1 : 0 ] [ DATA_WIDTH-1 : 0 ]                        operand;
   reg [ DATA_WIDTH-1 : 0 ]                                   op_result;
   wire [ DATA_WIDTH-1 : 0 ]                                  op_result_and, op_result_or;
   wire [3:0] [DATA_WIDTH-1:0]                                reg_out;
   wire [DATA_WIDTH-1:0]                                      reg_out_idx [ 0 : 3];

   wire                                                       tlast;
   wire [KEEP_WIDTH-1 : 0 ]                                   tkeep;

   /* FIFO Signals */
   wire [ FIFO_WIDTH : 0 ]                                    din, dout;
   wire                                                       wr_en;
   wire                                                       rd_en;
   wire                                                       empty, nearly_full;

   generate
      genvar                                                  i;
      for (i = 0; i < 3; i = i + 1) begin
         assign reg_out_idx[i] = reg_out[i];
      end
   endgenerate

   /* I/O Ports */
   generate
      for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
         assign M_AXIS_TDATA[(8*i) +: 8] = tkeep[i] ? op_result[(8*i) +: 8] : operand[0][(8*i) +: 8];
      end
   endgenerate
   assign M_AXIS_TKEEP = tkeep;
   assign M_AXIS_TLAST = tlast;
   assign M_AXIS_TVALID = ~empty;
   assign S_AXIS_TREADY = ~nearly_full;

   /* FIFO logic */
   assign wr_en = ~nearly_full && S_AXIS_TVALID;
   assign rd_en = ~empty && M_AXIS_TREADY;
   assign din = {S_AXIS_TLAST,S_AXIS_TKEEP,S_AXIS_TDATA};
   assign {tlast,tkeep,operand[0]} = dout;
   fallthrough_small_fifo 
     #(
       .WIDTH               (FIFO_WIDTH+1        ),
       .MAX_DEPTH_BITS      (MAX_DEPTH_BITS    )
       )
   input_fifo (
               .din         (din         ),
               .wr_en       (wr_en       ),
               .rd_en       (rd_en       ),
               .dout        (dout        ),
               .nearly_full (nearly_full ),
               .empty       (empty       ),
               .reset       (~ARESETN    ),
               .clk         (ACLK        )
               );
   
   /* Register map logic */
   assign operand[1]   = reg_out[1];
   assign exec_en      = reg_out[0][0];
   assign op           = reg_out[0][4:2];
   easyaxil_out #(
      .C_AXI_ADDR_WIDTH (ADDR_WIDTH),
      .C_AXI_DATA_WIDTH (DATA_WIDTH)
   ) register_map(
                  .S_AXI_ACLK    (ACLK    ),
                  .S_AXI_ARESETN (ARESETN ),
                  .reg_out       (reg_out),
                  .S_AXI_AWVALID (S_AXI_AWVALID ),
                  .S_AXI_AWREADY (S_AXI_AWREADY ),
                  .S_AXI_AWADDR  (S_AXI_AWADDR[3:0]),
                  .S_AXI_AWPROT  (S_AXI_AWPROT  ),
                  .S_AXI_WVALID  (S_AXI_WVALID  ),
                  .S_AXI_WREADY  (S_AXI_WREADY  ),
                  .S_AXI_WDATA   (S_AXI_WDATA   ),
                  .S_AXI_WSTRB   (S_AXI_WSTRB   ),
                  .S_AXI_BVALID  (S_AXI_BVALID  ),
                  .S_AXI_BREADY  (S_AXI_BREADY  ),
                  .S_AXI_BRESP   (S_AXI_BRESP   ),
                  .S_AXI_ARVALID (S_AXI_ARVALID ),
                  .S_AXI_ARREADY (S_AXI_ARREADY ),
                  .S_AXI_ARADDR  (S_AXI_ARADDR[3:0]),
                  .S_AXI_ARPROT  (S_AXI_ARPROT  ),
                  .S_AXI_RVALID  (S_AXI_RVALID  ),
                  .S_AXI_RREADY  (S_AXI_RREADY  ),
                  .S_AXI_RDATA   (S_AXI_RDATA   ),
                  .S_AXI_RRESP   (S_AXI_RRESP   )
                  );
   

   /* Operation logic */
   assign op_sel = {~exec_en,op};
   assign op_result_and = (operand[0] & operand[1]);
   assign op_result_or  = (operand[0] | operand[1]);
   always @(*) begin
      casez (op_sel)
        4'b1???: op_result = operand[0];
        `NONE: op_result = operand[0];
        `ADD:  op_result = operand[0] + operand[1];
        `SUB:  op_result = operand[0] - operand[1];
        `AND:  op_result = op_result_and;
        `XOR:  op_result = operand[0] ^ operand[1];
        `OR:   op_result = op_result_or;
        `NAND: op_result = ~op_result_and;
        `NOR:  op_result = ~op_result_or;
      endcase
   end

`ifdef __ICARUS__
   wire [DATA_WIDTH-1:0]            sim_reg_out [0 : 1];
   assign sim_reg_out[0] = reg_out[0];
   assign sim_reg_out[1] = reg_out[1];
   initial begin
      $dumpfile("dump.vcd");
      $dumpvars(2, axis_exec_op);
      #1;
   end
`endif

endmodule
