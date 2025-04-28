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
//
///////////////////////////////////////////////////////////////////////////////
module req_ack_cmd (
    input  logic        i_clk       ,
    input  logic        i_rstn      ,
    // Command Input
    input  logic        i_valid     ,
    input  logic [ 4:0] i_op        ,
    input  logic [ 3:0] i_addr      ,
    input  logic [31:0] i_data      ,
    // Command Execution
    output logic        o_loc_req   ,
    output logic        o_net_req   ,
    input  logic        i_async_ack ,
    input  logic        i_sync_ack  ,
    output logic [ 7:0] o_op        ,
    output logic [31:0] o_data      ,
    output logic  [3:0] o_data_cntr
);

    logic [ 7:0]   cmd_op_r, cmd_op_n;
    logic [31:0]   cmd_dt_r, cmd_dt_n;
    logic [ 3:0]   cmd_cnt_r, cmd_cnt_n;

    sync_n #(.N(2)) sync_ack (
        .i_clk     ( i_clk       ),
        .rst_ni    ( i_rstn      ),
        .dt_i      ( i_async_ack ),
        .dt_o      ( async_ack_s )
    );

    assign ack_s = i_sync_ack | async_ack_s ;

    typedef enum logic [1:0] {IDLE    = 2'b00, 
                              LOC_REQ = 2'b01, 
                              NET_REQ = 2'b10, 
                              ACK     = 2'b11
    } state_r, state_n;

    //State register
    always_ff @ (posedge i_clk) begin
        if ( !i_rstn ) state_r <= IDLE;
        else           state_r <= state_n;
    end

    //next state logic
    always_comb begin
        state_n  = state_r; 
        o_loc_req   = 1'b0;
        o_net_req   = 1'b0;
        case (state_r)
            IDLE: begin
                if ( i_valid ) begin 
                    if (i_op[4]) begin
                        state_n   = LOC_REQ;
                        o_loc_req = 1'b1;
                    end else begin
                        state_n   = NET_REQ;
                        o_net_req = 1'b1;
                    end
                end
            end
            LOC_REQ:  begin
                o_loc_req = 1'b1;
                if ( ack_s ) state_n = ACK;     
            end
            NET_REQ:  begin
                o_net_req = 1'b1;
                if ( ack_s ) state_n = ACK;     
            end
            ACK:  begin
                if ( !ack_s ) state_n = IDLE;     
            end
            default: 
                state_n = state_r;
        endcase
    end

    always_ff @(posedge i_clk) 
        if (!i_rstn) begin
            cmd_op_r   <= '{default:'0};
            cmd_dt_r   <= '{default:'0};
            cmd_cnt_r  <= 4'd0;
        end else begin
            cmd_op_r   <= cmd_op_n;
            cmd_dt_r   <= cmd_dt_n;
            cmd_cnt_r  <= cmd_cnt_n;
        end
    //next state logic
    assign cmd_op_n  = i_valid ? {i_op[3:0], i_addr} : cmd_op_r;
    assign cmd_dt_n  = i_valid ? i_data              : cmd_dt_r;
    assign cmd_cnt_n = i_valid ? cmd_cnt_r + 1'b1    : cmd_cnt_r;


    // OUTPUTS
    ///////////////////////////////////////////////////////////////////////////////
    assign o_op   = cmd_op_r;
    assign o_data = cmd_dt_r;
    //assign o_op   = i_valid ? {i_op[3:0], i_addr} : cmd_op_r;
    //assign o_data = i_valid ? i_data              : cmd_dt_r;

    // DEBUG
    ///////////////////////////////////////////////////////////////////////////////
    assign o_data_cntr = cmd_cnt; 

endmodule
