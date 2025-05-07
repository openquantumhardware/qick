/***********************************************
 *
 *  File: axil_ram_wr.sv
 *  Description: Interface between AXI4-Lite and DP BRAM block
 *
 *
 * ********************************************/

module axil_ram_wr
#(
  parameter integer unsigned AXI_DWIDTH  = 32,
  parameter integer unsigned AXI_AWIDTH  = 16
)
(
  input  logic                        i_clk,
  input  logic                        i_rst,

  // Slave side
  axi4lite_intf.slave                 i_axil,

  // BRAM port
  bram_if.master_write                o_bram_if
);

  localparam integer ADDR_LSB = $clog2(AXI_DWIDTH/8);

  logic                    awready_s, awvalid_s;
  logic                    wready_s, wvalid_s;
  logic                    bready_s, bvalid_s;
  logic [AXI_AWIDTH-1:0]   awaddr_s;
  logic [AXI_DWIDTH-1:0]   wdata_s;
  logic [AXI_DWIDTH/8-1:0] wstrb_s;

  assign awready_s = wvalid_s & bready_s ;
  assign wready_s  = awvalid_s & bready_s;
  assign bvalid_s  = awvalid_s & wvalid_s;

  in_buffer #(
    .DWIDTH(AXI_AWIDTH)
  ) u_ibuf_0 (
    .i_clk    ( i_clk          ), 
    .i_rst    ( i_rst          ),
    .i_ready  ( i_axil.AWREADY ), 
    .i_data   ( i_axil.AWADDR  ), 
    .i_valid  ( i_axil.AWVALID ),
    .o_ready  ( awready_s      ), 
    .o_data   ( awaddr_s       ), 
    .o_valid  ( awvalid_s      )
  );

  in_buffer #(
    .DWIDTH(AXI_DWIDTH + AXI_DWIDTH/8)
  ) u_ibuf_1 (
    .i_clk    (i_clk                        ), 
    .i_rst    (i_rst                        ),
    .i_ready  (i_axil.WREADY                ), 
    .i_data   ({i_axil.WSTRB, i_axil.WDATA} ), 
    .i_valid  (i_axil.WVALID                ),
    .o_ready  (wready_s                     ), 
    .o_data   ({wstrb_s, wdata_s}           ), 
    .o_valid  (wvalid_s                     )
  );

  out_buffer #(
    .DWIDTH(1)
  ) u_obuf_0 (
    .i_clk     ( i_clk         ), 
    .i_rst     ( i_rst         ),
    .i_ready   ( bready_s      ), 
    .i_data    ( 1'b0          ), 
    .i_valid   ( bvalid_s      ),
    .o_ready   ( i_axil.BREADY ), 
    .o_valid   ( i_axil.BVALID ),
    .o_data    (               ) 
  );

  assign i_axil.BRESP = 2'd0;

  assign i_axil.ARREADY = 1'b0;
  assign i_axil.RDATA = {(AXI_DWIDTH){1'b0}};
  assign i_axil.RRESP = 2'd0;
  assign i_axil.RVALID = 1'b0;

  assign o_bram_if.addr  = awaddr_s[ADDR_LSB+o_bram_if.NB_ADDR-1:ADDR_LSB];
  assign o_bram_if.data  = wdata_s;
  assign o_bram_if.we    = bvalid_s ? wstrb_s : {(o_bram_if.NB_DATA/8){1'b0}};

endmodule
