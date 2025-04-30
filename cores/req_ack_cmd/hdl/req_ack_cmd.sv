///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: req_ack_cmd.sv
// Project: QICK 
// Description: Board communication peripheral
//
//
// Change history: 10/20/24 - v2 Started by @mdifederico
//                 04/27/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                          in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module req_ack_cmd 
(
    input  logic          i_clk       ,
    input  logic          i_rstn      ,
    // Command Input
    input  logic          i_valid     , //data valid
    input  logic [ 5-1:0] i_op        , //data operation
    input  logic [ 4-1:0] i_addr      , //data addr
    input  logic [32-1:0] i_data      , //data
    // Command Execution
    input  logic          i_ack       ,
    output logic          o_req_loc   ,
    output logic          o_req_net   ,
    output logic [ 8-1:0] o_op        ,
    output logic [32-1:0] o_data      ,
    output logic [ 4-1:0] o_data_cntr
);

    logic [ 8-1:0]   cmd_op_r, cmd_op_n;
    logic [32-1:0]   cmd_dt_r, cmd_dt_n;
    logic [ 4-1:0]   cmd_cnt_r, cmd_cnt_n;

    typedef enum logic [2-1:0] {IDLE    = 2'b00, 
                                LOC_REQ = 2'b01, 
                                NET_REQ = 2'b10, 
                                ACK     = 2'b11
    } state_t;
    
    state_t state_r, state_n;

    //State register
    always_ff @ (posedge i_clk) begin
        if ( !i_rstn ) state_r <= IDLE;
        else           state_r <= state_n;
    end

    //next state logic
    always_comb begin
        state_n   = state_r; 
        o_req_loc = 1'b0;
        o_req_net = 1'b0;
        case (state_r)
            IDLE: begin
               if( i_valid )  begin
                  if (i_op[4]) begin
                     //o_req_loc = 1'b1;
                     state_n   = LOC_REQ;
                  end else begin
                     //o_req_net = 1'b1;
                     state_n   = NET_REQ;
                  end
               end else begin
                  state_n = IDLE;
               end
            end
            LOC_REQ:  begin
               o_req_loc = 1'b1;
               if (i_ack) state_n = ACK;
               else       state_n = LOC_REQ;     
            end
            NET_REQ:  begin
               o_req_net = 1'b1;
               if (i_ack) state_n = ACK;     
               else       state_n = NET_REQ;
            end
            ACK:  begin
               if (!i_ack) state_n = IDLE;  
               else        state_n = ACK;   
            end
            default: 
                state_n = state_r;
        endcase
    end

    always_ff @(posedge i_clk) 
        if (!i_rstn) begin
            cmd_op_r   <= '0;
            cmd_dt_r   <= '0;
            cmd_cnt_r  <= '0;
        end else begin
            cmd_op_r   <= cmd_op_n;
            cmd_dt_r   <= cmd_dt_n;
            cmd_cnt_r  <= cmd_cnt_n;
        end
    //next state logic
    assign cmd_op_n  = i_valid ? {i_op[4-1:0], i_addr} : cmd_op_r;
    assign cmd_dt_n  = i_valid ? i_data                : cmd_dt_r;
    assign cmd_cnt_n = i_valid ? cmd_cnt_r + 1'b1      : cmd_cnt_r;//FIXME:check this


    // OUTPUTS
    ///////////////////////////////////////////////////////////////////////////////
    assign o_op   = cmd_op_r;
    assign o_data = cmd_dt_r;

    // DEBUG
    ///////////////////////////////////////////////////////////////////////////////
    assign o_data_cntr = cmd_cnt_r; 

endmodule
