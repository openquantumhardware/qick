`SVTEST(test00_reset)

for (integer k = 0; k < 10; k = k + 1) begin
  cb.tb_rstn <= 1'b0;
  @(cb);
  cb.tb_rstn <= 1'b1;
  @(cb);
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_ps_write_net)

@(cb);
for (int j=0;j<16;j=j+1) begin
  random_data  = $urandom_range(0,32);     
  write_ps(random_data,j);
  repeat($urandom_range(1,100)) @(cb);
end
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_ps_write_loc)

@(cb);
for (int j=16;j<32;j=j+1) begin
  random_data  = $urandom_range(0,32);     
  write_ps(random_data,j);
  repeat($urandom_range(1,100)) @(cb);
end
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_tproc_write_net)

@(cb);
for (int j=0;j<16;j=j+1) begin
  random_data  = $urandom_range(0,32);     
  write_core(random_data,j);
  repeat($urandom_range(1,100)) @(cb);
end
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test05_tproc_write_loc)

@(cb);
for (int j=16;j<32;j=j+1) begin
  random_data  = $urandom_range(0,32);     
  write_core(random_data,j);
  repeat($urandom_range(1,100)) @(cb);
end
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
