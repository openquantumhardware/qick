///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 
// Assembled memory access module. Three modes of accessing the memory:
//
// * Single access using the in/out ports. It's only available when busy_o = 0.
//
// * AXIS read: this mode allows to send data using m_axis_* interface, using
// ADDR_REG as the starting address and LEN_REG to indicate the number of
// samples to be transferred. The last sample will assert m_axis_tlast_o to
// indicate the external block transaction is done. Similar to AXIS write
// mode, the user needs to set START_REG = 1 to start the process.
//
// * AXIS write: this mode receives data from s_axis_* interface and writes
// into the memory using ADDR_REG as the starting address. The user must also
// provide the START_REG = 1 to allow starting receiving data. The block will
// rely on s_axis_tlast_i = 1 to finish the writing process.
//
// When not performing any AXIS transaction, the block will grant access to
// the memory using the single access interface. This is a very basic
// handshake interface to allow external blocks to easily communicate and
// perform single-access transaction. 
//
// Once a AXIS transaction is done, the user must set START_REG = 0 and back
// to 1 if a new AXIS transaction needs to be executed. START_REG = 1 steady
// will not allow further AXIS transactions, and will only allow
// single-access.
//
// Registers:
//
// MODE_REG : indicates the type of the next AXIS transaction.
// * 0 : AXIS Read (from memory to m_axis).
// * 1 : AXIS Write (from s_axis to memory).
//
// START_REG : starts execution of indicated AXIS transaction.
// * 0 : Stop.
// * 1 : Execute Operation.
//
// ADDR_REG : starting memory address for either AXIS read or write.
//
// LEN_REG : number of samples to be transferred in AXIS read mode.
//
*/
//////////////////////////////////////////////////////////////////////////////

module qproc_mem_ctrl # (
   parameter PMEM_AW = 16 ,
   parameter DMEM_AW = 16 ,
   parameter WMEM_AW = 16 
)(
   // CLK & RST.
   input  wire                ps_clk_i     ,
   input  wire                ps_rst_ni    ,
// EXTERNAL MEMORY ACCESS
   output wire [1:0]       ext_core_sel_o      ,
   output wire [1:0]       ext_mem_sel_o   , //00-NONE 01-PMEM 10-DMEM 11-WMEM
   output wire             ext_mem_we_o    ,
   output wire [15:0]      ext_mem_addr_o  ,
   output wire [167:0]     ext_mem_w_dt_o  ,
   input  wire [167:0]     ext_mem_r_dt_i  ,
// AXIS Slave
   input  wire [255:0]     s_axis_tdata_i ,
   input  wire             s_axis_tlast_i ,
   input  wire             s_axis_tvalid_i,
   output wire             s_axis_tready_o,
// AXIS Master for sending data.
   output wire [255:0]     m_axis_tdata_o ,
   output wire             m_axis_tlast_o ,
   output wire             m_axis_tvalid_o,
   input  wire             m_axis_tready_i,
//Control Regiters
   input  wire [6 :0]       MEM_CTRL       ,
   input  wire [15:0]       MEM_ADDR       ,
   input  wire [15:0]       MEM_LEN        ,
   input  wire [31:0]       MEM_DT_I       ,
   output wire [31:0]       MEM_DT_O       ,
   output wire [7 :0]       STATUS_O       ,
   output wire [15:0]       DEBUG_O        );

// SIGNALS
wire           ar_exec, ar_end     ;
wire           aw_exec, aw_end      ;
wire           mem_start, mem_op, mem_source ;
wire [1:0]     mem_sel ;
wire           mem_we_single, mem_we_axis;
wire [31:0]    mem_w_dt_single;
wire [255:0]   mem_w_dt_axis; 
wire [15:0]    mem_w_addr_axis, mem_r_addr_axis ;
wire [15:0]    axis_addr,  mem_addr_single, ext_mem_addr;
wire [1:0]     core_sel;

assign mem_start   = MEM_CTRL[ 0 ] ; // 1-Start Go to 0 For Next
assign mem_op      = MEM_CTRL[ 1 ] ; // 0-READ , 1-WRITE
assign mem_sel     = MEM_CTRL[3:2] ; // 01-Pmem , 10-Dmem , 11-Wmem
assign mem_source  = MEM_CTRL[ 4 ] ; // 0-AXIS, 1-REGISTERS (Single)
assign core_sel    = MEM_CTRL[6:5] ; // Core Selection 

wire start_single;
assign start_axis   = mem_start & ~mem_source ;
assign start_single = mem_start & mem_source ;

assign axis_addr    = mem_op     ? mem_w_addr_axis : mem_r_addr_axis  ;
assign ext_mem_addr = mem_source ? mem_addr_single : axis_addr       ;



wire [255:0]   mem_r_dt;
assign mem_r_dt  =  ext_mem_r_dt_i;

wire [31 :0] freq, phase, env, gain, lenght, conf;
assign freq   = mem_w_dt_axis[ 31 :  0] ; // 32-bit FREQ
assign phase  = mem_w_dt_axis[ 63 : 32] ; // 32-bit PHASE
assign env    = mem_w_dt_axis[ 95 : 64] ; // 32-bit ENV
assign gain   = mem_w_dt_axis[127 : 96] ; // 32-bit GAIN 
assign lenght = mem_w_dt_axis[159 :128] ; // 32-bit LENGHT
assign conf   = mem_w_dt_axis[191 :160] ; // 32-bit CONF

 
wire [71 :0] ext_pmem_w_dt;
wire [31 :0] ext_dmem_w_dt;
wire [167:0] ext_wmem_w_dt;

assign ext_pmem_w_dt  = mem_w_dt_axis[ 71 :  0];
assign ext_dmem_w_dt  = mem_source ? mem_w_dt_single   : mem_w_dt_axis[31:0]   ;
assign ext_wmem_w_dt  = {conf[15:0], lenght, gain, env[23:0], phase, freq} ;


// Registe-READ ONLY with DMEM
                   
assign dmem_we_single = mem_we_single & mem_sel == 2'b10;

// OUTPUTS
assign ext_core_sel_o      = core_sel;
assign ext_mem_sel_o       = mem_sel;
assign ext_mem_we_o        = dmem_we_single | mem_we_axis ;
assign ext_mem_addr_o      = ext_mem_addr;

assign ext_mem_w_dt_o  = (mem_sel == 2'b01)? ext_pmem_w_dt  : 
                         (mem_sel == 2'b10)? ext_dmem_w_dt	:
                         (mem_sel == 2'b11)? ext_wmem_w_dt	:
                         0;

data_mem_ctrl #(
      .N(16)
   ) data_mem_ctrl_i (
      .aclk_i        ( ps_clk_i      ) ,
      .aresetn_i     ( ps_rst_ni   ) ,
      .ar_exec_o     ( ar_exec            ) ,  
      .ar_exec_ack_i ( ar_end             ) ,
      .aw_exec_o     ( aw_exec            ) ,  
      .aw_exec_ack_i ( aw_end             ) ,
      .busy_o        ( busy_o             ) ,
      .mem_op_i      ( mem_op             ) ,
      .mem_start_i   ( start_axis         ) );

mem_rw  #(
   .N( 16 ),
   .B( 32 )
) mem_rw_i (
   .aclk_i           ( ps_clk_i      ) ,
   .aresetn_i        ( ps_rst_ni     ) ,
   .rw_i             ( mem_op             ) ,
   .exec_i           ( start_single       ) ,
   .exec_ack_o       ( end_single_o       ) ,
   .addr_i           ( MEM_ADDR           ) ,
   .di_i             ( MEM_DT_I           ) ,
   .do_o             ( MEM_DT_O           ) ,
   .mem_we_o         ( mem_we_single      ) ,
   .mem_di_o         ( mem_w_dt_single    ) ,
   .mem_do_i         ( mem_r_dt[31:0]     ) ,
   .mem_addr_o       ( mem_addr_single    )	);

axis_read #(
   .N( 16 ),
   .B( 256 )
) axis_read_i (
   .aclk_i           ( ps_clk_i      ) ,
   .aresetn_i        ( ps_rst_ni   ) ,
   .m_axis_tdata_o   ( m_axis_tdata_o     ) ,
   .m_axis_tlast_o   ( m_axis_tlast_o     ) ,
   .m_axis_tvalid_o  ( m_axis_tvalid_o    ) ,
   .m_axis_tready_i  ( m_axis_tready_i    ) ,
   .mem_do_i         ( mem_r_dt           ) ,
   .mem_addr_o       ( mem_r_addr_axis    ) ,
   .exec_i           ( ar_exec            ) ,
   .exec_ack_o       ( ar_end             ) ,
   .addr_i           ( MEM_ADDR           ) ,
   .len_i            ( MEM_LEN            ) );

axis_write #(
   .N( 16 ),
   .B( 256 )
) axis_write_i (
   .aclk_i           ( ps_clk_i      ) ,
   .aresetn_i        ( ps_rst_ni   ) ,
   .s_axis_tdata_i   ( s_axis_tdata_i     ) ,
   .s_axis_tlast_i   ( s_axis_tlast_i     ) ,
   .s_axis_tvalid_i  ( s_axis_tvalid_i    ) ,
   .s_axis_tready_o  ( s_axis_tready_o    ) ,
   .mem_we_o         ( mem_we_axis        ) ,
   .mem_di_o         ( mem_w_dt_axis      ) ,
   .mem_addr_o       ( mem_w_addr_axis    ) ,
   .exec_i           ( aw_exec            ) ,
   .exec_ack_o       ( aw_end             ) ,
   .addr_i           ( MEM_ADDR           ) );

//assign STATUS_O[7:0]  = { mem_op, start_single, mem_we_single, ar_exec, aw_exec, end_single_o, aw_end, ar_end} ;
assign STATUS_O[7:0]  = { 6'b0, ar_exec, aw_exec} ;
assign DEBUG_O[15:8]  = ext_mem_addr [7:0] ;
assign DEBUG_O[7:0]   = ext_mem_w_dt_o[7:0] ;

endmodule
