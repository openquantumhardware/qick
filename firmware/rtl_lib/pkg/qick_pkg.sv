`ifndef QICK_PKG_SV
`define QICK_PKG_SV

package qick_pkg;

  localparam VERSION = "0.1.0";

  /////////// XCOM ////////////
  //Opcodes
  localparam int XCOM_RST         = 4'b1111  ;//LOC command
  localparam int XCOM_WRITE_MEM   = 4'b0011  ;//LOC command
  localparam int XCOM_WRITE_REG   = 4'b0010  ;//LOC command
  localparam int XCOM_WRITE_FLAG  = 4'b0001  ;//LOC command
  localparam int XCOM_SET_ID      = 4'b0000  ;//LOC command
  localparam int XCOM_RFU2        = 4'b1111  ;
  localparam int XCOM_RFU1        = 4'b1101  ;
  localparam int XCOM_QCTRL       = 4'b1011  ;
  localparam int XCOM_UPDATE_DT32 = 4'b1110  ;
  localparam int XCOM_UPDATE_DT16 = 4'b1100  ;
  localparam int XCOM_UPDATE_DT8  = 4'b1010  ;
  localparam int XCOM_AUTO_ID     = 4'b1001  ;
  localparam int XCOM_QRST_SYNC   = 4'b1000  ;
  localparam int XCOM_SEND_32BIT_2= 4'b0111  ;
  localparam int XCOM_SEND_32BIT_1= 4'b0110  ;
  localparam int XCOM_SEND_16BIT_2= 4'b0101  ;
  localparam int XCOM_SEND_16BIT_1= 4'b0100  ;
  localparam int XCOM_SEND_8BIT_2 = 4'b0011  ;
  localparam int XCOM_SEND_8BIT_1 = 4'b0010  ;
  localparam int XCOM_SET_FLAG    = 4'b0001  ;
  localparam int XCOM_CLEAR_FLAG  = 4'b0000  ;

  // Register ADDRESS
  localparam int REG_XCOM_CTRL      = 0  * 4 ;
  localparam int REG_XCOM_CFG       = 1  * 4 ;
  localparam int REG_XCOM_AXI_DATA1 = 2  * 4 ;
  localparam int REG_XCOM_AXI_DATA2 = 3  * 4 ;
  localparam int REG_XCOM_ADDR      = 4  * 4 ;
  localparam int REG_XCOM_EMPTY1    = 5  * 4 ;
  localparam int REG_XCOM_ID        = 6  * 4 ;
  localparam int REG_XCOM_FLAG      = 7  * 4 ;
  localparam int REG_XCOM_DATA1     = 8  * 4 ;
  localparam int REG_XCOM_DATA2     = 9  * 4 ;
  localparam int REG_XCOM_MEM       = 10  * 4 ;
  localparam int REG_XCOM_EMPTY2    = 11  * 4 ;
  localparam int REG_XCOM_RX_DATA   = 12  * 4 ;
  localparam int REG_XCOM_TX_DATA   = 13  * 4 ;
  localparam int REG_XCOM_STATUS    = 14  * 4 ;
  localparam int REG_XCOM_DEBUG     = 15  * 4 ;

  typedef struct packed {
    logic [32-1:0] xcom_debug   ;
    logic [32-1:0] xcom_status  ;
    logic [32-1:0] xcom_tx_data ;
    logic [32-1:0] xcom_rx_data ;
    logic [32-1:0] xcom_tbd_1   ;//To be defined 1
    logic [32-1:0] xcom_mem     ;
    logic [32-1:0] xcom_data_2  ;
    logic [32-1:0] xcom_data_1  ;
    logic          xcom_flag    ;
    logic [5-1:0]  board_id     ;
    logic [32-1:0] xcom_tbd_2   ; //To be defined 2
    logic [5-1:0]  axi_addr     ;
    logic [32-1:0] axi_data_2   ;
    logic [32-1:0] axi_data_1   ;
    logic [5-1:0]  xcom_cfg     ;
    logic [6-1:0]  xcom_ctrl    ;
  } xcom_register_t;

  typedef struct packed {
    logic [5-1:0] rst           ;//LOC command
    logic [5-1:0] write_mem     ;//LOC command
    logic [5-1:0] write_reg     ;//LOC command
    logic [5-1:0] write_flag    ;//LOC command
    logic [5-1:0] set_id        ;//LOC command
    logic [5-1:0] rfu2          ;
    logic [5-1:0] rfu1          ;
    logic [5-1:0] qctrl         ;
    logic [5-1:0] update_dt32   ;
    logic [5-1:0] update_dt16   ;
    logic [5-1:0] update_dt8    ;
    logic [5-1:0] auto_id       ;
    logic [5-1:0] qrst_sync     ;
    logic [5-1:0] send_32bit_2  ;
    logic [5-1:0] send_32bit_1  ;
    logic [5-1:0] send_16bit_2  ;
    logic [5-1:0] send_16bit_1  ;
    logic [5-1:0] send_8bit_2   ;
    logic [5-1:0] send_8bit_1   ;
    logic [5-1:0] set_flag      ;
    logic [5-1:0] clear_flag    ;
  } xcom_cmd_t;

  typedef struct packed {
    logic [5-1:0] rst           ;//LOC command
    logic [5-1:0] write_mem     ;//LOC command
    logic [5-1:0] write_reg     ;//LOC command
    logic [5-1:0] write_flag    ;//LOC command
    logic [5-1:0] set_id        ;//LOC command
    logic [5-1:0] rfu2          ;
    logic [5-1:0] rfu1          ;
    logic [5-1:0] qctrl         ;
    logic [5-1:0] update_dt32   ;
    logic [5-1:0] update_dt16   ;
    logic [5-1:0] update_dt8    ;
    logic [5-1:0] auto_id       ;
    logic [5-1:0] qrst_sync     ;
    logic [5-1:0] send_32bit_2  ;
    logic [5-1:0] send_32bit_1  ;
    logic [5-1:0] send_16bit_2  ;
    logic [5-1:0] send_16bit_1  ;
    logic [5-1:0] send_8bit_2   ;
    logic [5-1:0] send_8bit_1   ;
    logic [5-1:0] set_flag      ;
    logic [5-1:0] clear_flag    ;
  } xcom_opcode_t;

endpackage

`endif // QICK_PKG_SV
