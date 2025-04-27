module blink_gen 
#(
     parameter integer unsigned IP_FREQ   = 100000000,
     parameter integer unsigned NB_CNTR   = 32
     )
(
    input logic                         i_clk        ,
    input logic                         i_rst        ,

    input logic [NB_CNTR-1 : 0]         i_blink_time ,
    input logic                         i_enable     ,
    output logic                        o_blink     
);

  logic [NB_CNTR-1 : 0] one_sec_cnt_r ;      
  logic [NB_CNTR-1 : 0] one_sec_cnt_n ;      
  logic                 blink_s       ;

  always_ff @(posedge i_clk)
    if (i_rst) begin
      one_sec_cnt_r <= '0; 
    end else begin
      one_sec_cnt_r <= one_sec_cnt_n;
    end 

  //next state
  always_comb
  begin
    one_sec_cnt_n = one_sec_cnt_r;

    if (one_sec_cnt_r == 2*i_blink_time-1) begin
      one_sec_cnt_n = '0;
    end else begin
      one_sec_cnt_n = one_sec_cnt_r + 1;
    end

    if (one_sec_cnt_r < i_blink_time) begin 
      blink_s = 1'b1;
    end else begin
      blink_s = 1'b0;
    end

  end

  assign o_blink = (i_enable) ? blink_s : 1'b0;

endmodule
