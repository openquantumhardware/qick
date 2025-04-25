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
module axis_exec_op_wrapper #(
                      parameter integer DATA_WIDTH = 32,
                      parameter integer ADDR_WIDTH = 4,
                      parameter integer MAX_DEPTH_BITS = 3
) (
                         input wire                           ACLK,
                         input wire                           ARESETN,
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
                         input wire                           S_AXI_RREADY,
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
                         input wire                           S_AXIS_TVALID
);
    
    axis_exec_op 
    #(
        .DATA_WIDTH     (DATA_WIDTH     ),
        .ADDR_WIDTH     (ADDR_WIDTH     ),
        .MAX_DEPTH_BITS (MAX_DEPTH_BITS )
    )
    axis_exec_op(
    	.ACLK          (ACLK          ),
        .ARESETN       (ARESETN       ),
        .M_AXIS_TREADY (M_AXIS_TREADY ),
        .M_AXIS_TDATA  (M_AXIS_TDATA  ),
        .M_AXIS_TKEEP  (M_AXIS_TKEEP  ),
        .M_AXIS_TLAST  (M_AXIS_TLAST  ),
        .M_AXIS_TVALID (M_AXIS_TVALID ),
        .S_AXIS_TREADY (S_AXIS_TREADY ),
        .S_AXIS_TDATA  (S_AXIS_TDATA  ),
        .S_AXIS_TKEEP  (S_AXIS_TKEEP  ),
        .S_AXIS_TLAST  (S_AXIS_TLAST  ),
        .S_AXIS_TVALID (S_AXIS_TVALID ),
        .S_AXI_AWADDR  (S_AXI_AWADDR  ),
        .S_AXI_AWPROT  (S_AXI_AWPROT  ),
        .S_AXI_AWVALID (S_AXI_AWVALID ),
        .S_AXI_AWREADY (S_AXI_AWREADY ),
        .S_AXI_WDATA   (S_AXI_WDATA   ),
        .S_AXI_WSTRB   (S_AXI_WSTRB   ),
        .S_AXI_WVALID  (S_AXI_WVALID  ),
        .S_AXI_WREADY  (S_AXI_WREADY  ),
        .S_AXI_BRESP   (S_AXI_BRESP   ),
        .S_AXI_BVALID  (S_AXI_BVALID  ),
        .S_AXI_BREADY  (S_AXI_BREADY  ),
        .S_AXI_ARADDR  (S_AXI_ARADDR  ),
        .S_AXI_ARPROT  (S_AXI_ARPROT  ),
        .S_AXI_ARVALID (S_AXI_ARVALID ),
        .S_AXI_ARREADY (S_AXI_ARREADY ),
        .S_AXI_RDATA   (S_AXI_RDATA   ),
        .S_AXI_RRESP   (S_AXI_RRESP   ),
        .S_AXI_RVALID  (S_AXI_RVALID  ),
        .S_AXI_RREADY  (S_AXI_RREADY  )
    );
    

endmodule