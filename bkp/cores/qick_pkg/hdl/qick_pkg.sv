package qick_pkg;
    import fxp_pkg::*;
  
    parameter VERSION = "0.1.0";

    /////////// XCOM ////////////

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

    //////////// SAMPLER //////////////
    localparam int unsigned NB_SAMPLE_CNT = 31;
    typedef struct packed {
        logic [NB_SAMPLE_CNT-1:0] count_val;
        logic                     enable;
    } sampler_info_t;

    /////////////////////////////////////////
    //////////// RX CHAIN   /////////////////
    /////////////////////////////////////////

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

    /////////// BEAMFORMER RX ///////////////////

    localparam N_BEAMS = 2;
    localparam string BF_RX_MEM_FILE_PATTERN = "data/bf_rx_weights_%0d%0d.mem";
    localparam repr_t REPR_BEAM_RX = '{1, 16, 15};
    localparam repr_t REPR_BF_RX_IN = dec_sample_repr;
    localparam repr_t REPR_BF_RX_WEIGHT = '{1, 16, 15};

    typedef logic signed [1:0][REPR_BEAM_RX.nb-1:0] beam_packed_t;
    typedef dec_sample_t bf_rx_in_t;
    typedef beam_packed_t beam_rx_t;
    typedef logic signed [1:0][REPR_BF_RX_WEIGHT.nb-1:0] packed_weight_t;

    /////////// FORMATTER ///////////////////

    localparam N_BEAMS_DATA = N_BEAMS * N_CHN_FREQ;
    typedef struct packed {
        logic [31:0 ] reserved;
        logic [31:0 ] sample_count;
        logic [N_BEAMS_DATA - 1 : 0][31:0] beam_data;
        logic [31:24] beams_count;
        logic [23:16] gtc_id;
        logic [15:8 ] rf_route;
        logic [ 7:0 ] spare_0;
        logic [31:0 ] imu_data;
        logic [31:0 ] utc_time_nanosec;
        logic [31:0 ] utc_time_sec;
        logic [31:8 ] encoder_data;
        logic [ 7:0 ] spare_1;
        logic [31:20] window_id;
        logic [19:8 ] window_count;
        logic [ 7:4 ] spare_2;
        logic [ 3:0 ] control;
        logic [31:20] ssw_count;
        logic [19:8 ] sweeps_count;
        logic [ 7:0 ] sweep_trains_count;
        logic [31:20] ssw_id;
        logic [19:8 ] sweep_id;
        logic [ 7:0 ] sweep_train_id;
        logic [31:20] scan_strategy_id;
        logic [19:8 ] hw_id;
        logic [ 7:4 ] job_id;
        logic [ 3:0 ] scan_id;
        logic [31:16] look_seq_number;
        logic [15:0 ] look_id;
        logic [31:16] slot_id;
        logic [15:0 ] task_id;
        logic [31:24] formatter_protocol_version;
        logic [23:0 ] constant_cafeca;
    } formatter_header_t;
    formatter_header_t static_portmap;

    /////////// PACKETIZER ////////////

    localparam PACKET_BYTE_SIZE = 1040;
    localparam NB_PACKETIZER_BUS = 64;
    typedef struct packed {
        logic [15:0] packet_number  ; // Interal
        logic [15:0] packet_count   ; // from config_frame
        logic [15:0] look_seq_number; // from config_frame
        logic [15:0] look_id        ; // from synchro
        logic [15:0] slot_id        ; // from config_frame
        logic [15:0] task_id        ; // from config_frame
        logic [3:0]  job_id         ; // from config_frame
        logic [3:0]  scan_id        ; // from config_frame
        logic [3:0]  control        ; // from synchro
        logic [7:0]  source_id      ; // from CSR
        logic [7:0]  sources_count  ; // from CSR
        logic [3:0]  protocol_id    ; //
    } packet_header_t;

    /////////////////////////////////////////
    //////////// TX CHAIN   /////////////////
    /////////////////////////////////////////

    localparam N_CHN_DAC  = 2;

    //////////// WAVEFORM GENERATOR ///////////////////
    localparam string PULSE_FILE = "./data/pulse_train.mem";
    localparam LEN_SUBPULSE_1 = 213;
    localparam LEN_SUBPULSE_2 = 3;

    localparam repr_t pulse_repr = '{1, 16, 15};
    typedef logic signed [pulse_repr.nb-1:0] pulse_t [2];

    //////////// BEAMFORMER TX ///////////////////
    localparam string BF_TX_WEIGHTS_FILE = "./data/weight_set_tx.mem";

    localparam repr_t beam_tx_repr = '{1, 16, 15};
    typedef logic signed [beam_tx_repr.nb-1:0] beam_tx_t [2];

    //////////// CHANNELIZER ///////////////////
    localparam repr_t interp_beam_repr = '{1, 16, 15};
    typedef logic signed [interp_beam_repr.nb-1:0] interp_beam_t [2];

    //////////// SD FIFO     ///////////////////
    localparam TX_FIFO_DEPTH = 512;
    typedef logic [N_CHN_DAC-1:0][1:0][interp_beam_repr.nb-1:0] packed_sd_fifo_data_t;

    //////////// MIXER /////////////////
    localparam repr_t mixed_tx_sample_full_repr = get_repr(
        get_repr(interp_beam_repr, dds_freq_repr, MULT),
        get_repr(interp_beam_repr, dds_freq_repr, MULT),
        SUM
    );
    typedef logic signed [mixed_tx_sample_full_repr.nb-1:0] mixed_tx_sample_fr_t [2];

    localparam repr_t mixed_tx_sample_repr = '{1, 16, 15};
    typedef logic signed [mixed_tx_sample_repr.nb-1:0] mixed_tx_sample_t [2];

    //////////// Metadata free running /////////////////
    localparam NB_ENCODER         = 32;
    localparam NB_TIMER           = 64;
    localparam NB_ELEVATION       = 64;
    localparam NB_GENERAL_PURPOSE = 64;
    typedef struct packed{
        logic [NB_ENCODER         - 1 : 0] encoder;
        logic [NB_TIMER           - 1 : 0] timer;
        logic [NB_ELEVATION       - 1 : 0] elevation;
        logic [NB_GENERAL_PURPOSE - 1 : 0] general_purpose;
    }packed_metadata_free_running_t;

    //////////// Metadata synchronized trigger /////////////////
    localparam NB_LOOK_ID   = 32;
    localparam NB_LOOK_CNT  = 16;
    localparam NB_SLOT_ID   = 16;
    typedef struct packed{
        logic [NB_LOOK_ID  - 1 : 0] look_id;
        logic [NB_LOOK_CNT - 1 : 0] look_cnt;
        logic [NB_SLOT_ID  - 1 : 0] slot_id;
    }packed_metadata_synchro_trigger_t;

    //////////// Time control Aurora rst /////////////////
    localparam  PMA_RST_RELEASE    = 400;
    localparam  PB_RST_RELEASE     = 1000;

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

    // Struct that matches memory_data_dispatcher.sv descriptor_t reflecting how transactions are
    // formatted sending Base + Length

    typedef struct packed {
        logic [NB_LEN_MMU -1:0]          length;
        logic [NB_BASE_ADDRESS_MMU -1:0] base_address;
    } descriptor_t;



endpackage
