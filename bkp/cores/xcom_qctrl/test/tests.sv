`SVTEST(test00_reset)

//`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
//repeat(5) @(tb_cb);
for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
    //`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
repeat(5) @(tb_cb);
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_wsync)

tb_cb.tb_i_ctrl_data   <= $urandom();     
$display("i_ctrl_data: %d",tb_i_ctrl_data);
tb_cb.tb_i_sync_req <= 1'b1;
@(tb_cb);
tb_cb.tb_i_sync_req <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_ctr_req)

//tb_cb.tb_i_ctrl_data   <= $urandom();     
tb_cb.tb_i_ctrl_data   <= 3'b010; //time_rst     
$display("i_ctrl_data: %d",tb_i_ctrl_data);
tb_cb.tb_i_ctrl_req <= 1'b1;
@(tb_cb);
tb_cb.tb_i_ctrl_req <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_loop)

logic [3-1:0] ctrl_data [6] = { 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111};

foreach (ctrl_data[i]) begin
    tb_cb.tb_i_ctrl_data   <= ctrl_data[i]; //time_rst  
    $display("i_ctrl_data: %d",tb_i_ctrl_data);
    tb_cb.tb_i_ctrl_req <= 1'b1;
    @(tb_cb);
    tb_cb.tb_i_ctrl_req <= 1'b0;
    repeat(200) @(tb_cb);
end
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
