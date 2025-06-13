package qick_pkg;
    import fxp_pkg::*;
  
    parameter VERSION = "0.1.0";

    /////////// XCOM ////////////
    //Opcodes
    parameter XCOM_RST         = 4'b1111  ;//LOC command
    parameter XCOM_WRITE_MEM   = 4'b0011  ;//LOC command
    parameter XCOM_WRITE_REG   = 4'b0010  ;//LOC command
    parameter XCOM_WRITE_FLAG  = 4'b0001  ;//LOC command
    parameter XCOM_SET_ID      = 4'b0000  ;//LOC command
    parameter XCOM_RFU2        = 4'b1111  ;
    parameter XCOM_RFU1        = 4'b1101  ;
    parameter XCOM_QCTRL       = 4'b1011  ;
    parameter XCOM_UPDATE_DT32 = 4'b1110  ;
    parameter XCOM_UPDATE_DT16 = 4'b1100  ;
    parameter XCOM_UPDATE_DT8  = 4'b1010  ;
    parameter XCOM_AUTO_ID     = 4'b1001  ;
    parameter XCOM_QRST_SYNC   = 4'b1000  ;
    parameter XCOM_SEND_32BIT_2= 4'b0111  ;
    parameter XCOM_SEND_32BIT_1= 4'b0110  ;
    parameter XCOM_SEND_16BIT_2= 4'b0101  ;
    parameter XCOM_SEND_16BIT_1= 4'b0100  ;
    parameter XCOM_SEND_8BIT_2 = 4'b0011  ;
    parameter XCOM_SEND_8BIT_1 = 4'b0010  ;
    parameter XCOM_SET_FLAG    = 4'b0001  ;
    parameter XCOM_CLEAR_FLAG  = 4'b0000  ;

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

    //////////// CONFIG FRAME //////////
    localparam NB_CONFIG_FRAME = 64;

    //////////// DDS   /////////////////
    localparam N_CHN_FREQ = 2;
    localparam NB_DDS_CFG = 32;
    localparam repr_t dds_freq_repr = '{1, 16, 15};
    typedef logic signed [dds_freq_repr.nb-1:0] dds_freq_t [N_CHN_FREQ][2];
    typedef logic signed [N_CHN_FREQ-1:0][1:0][dds_freq_repr.nb-1:0] dds_freq_packed_t;
    typedef logic        [N_CHN_FREQ-1:0][NB_DDS_CFG-1:0] dds_config_packed_t;

    /////////// ADC ////////////
    localparam int unsigned N_CHN_ADC = 2;

    localparam repr_t rcv_sample_repr = '{1, 16, 15};
    typedef logic signed [1:0][rcv_sample_repr.nb-1:0] packed_rcv_sample_t;
    typedef logic signed [N_CHN_ADC-1:0][1:0][rcv_sample_repr.nb-1:0] packed_rcv_sample_vec_t;

    //////////// MIXER /////////////////
    localparam repr_t mixed_sample_full_repr = get_repr(
        get_repr(rcv_sample_repr, dds_freq_repr, MULT),
        get_repr(rcv_sample_repr, dds_freq_repr, MULT),
        SUM
    );
    typedef logic signed [mixed_sample_full_repr.nb-1:0] mixed_sample_fr_t [2];

    localparam repr_t mixed_sample_repr = '{1, 16, 15};
    typedef logic signed [1:0][mixed_sample_repr.nb-1:0] mixed_sample_packed_t;

    //////////// DOWNSAMPLER /////////////////

    localparam repr_t dec_sample_repr = '{1, 16, 15};
    typedef logic signed [1:0][dec_sample_repr.nb-1:0] dec_sample_t;

    //////////// CHANNELIZER ///////////////////
    localparam repr_t interp_beam_repr = '{1, 16, 15};
    typedef logic signed [interp_beam_repr.nb-1:0] interp_beam_t [2];

    //////////// MIXER /////////////////
    localparam repr_t mixed_tx_sample_full_repr = get_repr(
        get_repr(interp_beam_repr, dds_freq_repr, MULT),
        get_repr(interp_beam_repr, dds_freq_repr, MULT),
        SUM
    );
    typedef logic signed [mixed_tx_sample_full_repr.nb-1:0] mixed_tx_sample_fr_t [2];

    localparam repr_t mixed_tx_sample_repr = '{1, 16, 15};
    typedef logic signed [mixed_tx_sample_repr.nb-1:0] mixed_tx_sample_t [2];

    //////////// Memory path /////////////////
    typedef struct packed{
        logic [31:0] araddr;
        logic [ 7:0] arlen;
        logic [ 2:0] arsize;
        logic [ 1:0] arburst;
        logic [ 2:0] arprot;
        logic [ 3:0] arcache;
        logic        arvalid;
        logic        rready;  
    }dma_axi_mm2s_out_t;

    typedef struct packed{
        logic        arready;
        logic [31:0] rdata;
        logic [ 1:0] rresp;
        logic        rlast;
        logic        rvalid;
    }dma_axi_mm2s_in_t;


    //////////////////////////////////////////////////////
    // DMA manager/Memory Manager Unit related parameters
    //////////////////////////////////////////////////////
    localparam integer unsigned NB_LEN_MMU              = 8;  
    localparam integer unsigned NB_WORD_WIDTH_MMU       = 32;
    localparam integer unsigned LOG2_NB_WORD_WIDTH_MMU  = $clog2(NB_WORD_WIDTH_MMU);
    localparam integer unsigned NB_BASE_ADDRESS_MMU     = 16;
    localparam integer unsigned NB_ADDR_TRANSL_OFFSET   = 10;

endpackage
