//-------------------------------------------------------------------------
// TEST 1: Write and Read basic in the same port (Port A)
//-------------------------------------------------------------------------
`SVTEST(basic_write_read_port_a)
  
  // Write a value in Port A
  port_a_if.write_data(10'h004, 32'hDEADBEEF);
  
  // Read the data from Port A
  port_a_if.read_data(10'h004, read_val);
  
  // Verify
  `FAIL_IF_LOG(read_val !== 32'hDEADBEEF, "The data read from Port A does not match the data written");

`SVTEST_END


//-------------------------------------------------------------------------
// TEST 2: True Dual-Port (Write in Port A, Read in Port B)
//-------------------------------------------------------------------------
`SVTEST(tdp_cross_port_communication)
  
  // Write a value using Port A
  port_a_if.write_data(10'h010, 32'hCAFEF00D);
  
  @(port_a_if.tb_cb); // Wait for a clock edge to ensure the write is processed
  @(port_b_if.tb_cb); // Wait for a clock edge to ensure the write is processed
  // Read the data from Port B
  port_b_if.read_data(10'h010, read_val);
  
  // Verify that the data crosses correctly
  `FAIL_IF_LOG(read_val !== 32'hCAFEF00D, "Failed to cross data from Port A to Port B");

  repeat(4) @(port_b_if.tb_cb); // Wait for a clock edge to ensure the write is processed

`SVTEST_END

`SVTEST(tdp_simultaneous_rw)
    // Precargar datos conocidos en ambas direcciones
    port_a_if.write_data(10'h030, 32'hAAAA_BBBB);
    port_b_if.write_data(10'h031, 32'h1234_5678);
    repeat(2) @(port_a_if.tb_cb);
    repeat(2) @(port_b_if.tb_cb);

    // Acceso simultáneo a direcciones distintas
    fork
        port_a_if.write_data(10'h032, 32'hDEAD_BEEF);
        port_b_if.read_data(10'h031, read_val);
    join

    `FAIL_IF_LOG(read_val !== 32'h1234_5678, "Simultaneous RW failed on Port B");

    repeat(2) @(port_a_if.tb_cb);
    repeat(2) @(port_b_if.tb_cb);
    port_b_if.read_data(10'h032, read_val);
    `FAIL_IF_LOG(read_val !== 32'hDEAD_BEEF, "Port A write during simultaneous RW failed");
`SVTEST_END

`SVTEST(tdp_b_writes_a_reads)
    port_b_if.write_data(10'h040, 32'hDEAD_C0DE);
    repeat(2) @(port_b_if.tb_cb);
    repeat(2) @(port_a_if.tb_cb);
    port_a_if.read_data(10'h040, read_val);
    `FAIL_IF_LOG(read_val !== 32'hDEAD_C0DE, "Port B write / Port A read failed");
`SVTEST_END

`SVTEST(tdp_reset_preserves_data)
    port_a_if.write_data(10'h050, 32'hBEEF_CAFE);
    // Reset
    @(port_a_if.tb_cb);
    tb_rstn <= 1'b0;
    repeat(3) @(port_a_if.tb_cb);
    tb_rstn <= 1'b1;
    repeat(5) @(port_a_if.tb_cb);
    // Dato debe seguir en memoria
    port_a_if.read_data(10'h050, read_val);
    `FAIL_IF_LOG(read_val !== 32'hBEEF_CAFE, "Reset should not clear BRAM content");
`SVTEST_END

`SVTEST(tdp_write_collision_same_addr)
    // Comportamiento no definido — solo verificar que no hay X en la salida
    fork
        port_a_if.write_data(10'h060, 32'hAAAA_AAAA);
        port_b_if.write_data(10'h060, 32'hBBBB_BBBB);
    join
    repeat(2) @(port_a_if.tb_cb);
    port_a_if.read_data(10'h060, read_val);
    // No verificamos el valor — solo que no sea X
    `FAIL_IF_LOG($isunknown(read_val), "Write collision produced X");
    $display("[INFO] Write collision result: 0x%08X (undefined behavior)", read_val);
    repeat(2) @(port_a_if.tb_cb);
`SVTEST_END

////-------------------------------------------------------------------------
//// TEST 3: Verify Byte-Enable functionality (Modify only one byte)
////-------------------------------------------------------------------------
//`SVTEST(byte_enable_partial_write)
//  
//  // 1. Write a complete word initially
//  port_a_if.write_data(10'h020, 32'h11223344);
//
//  // 2. Simulate a manual write only of the most significant byte (MSB)
//  @(port_a_if.tb_cb);
//  port_a_if.en   <= 1'b1;
//  port_a_if.we_be<= 4'b1000;         // We just activate the enable bit for byte 3
//  port_a_if.addr <= 10'h020;
//  port_a_if.din  <= 32'hAA000000;    // We want to inject 'AA' in the upper part
//  @(port_a_if.tb_cb);
//  port_a_if.en   <= 1'b0;
//  port_a_if.we_be<= 4'b0000;
//
//  // 3. Read and verify the combined result
//  port_a_if.read_data(10'h020, read_val);
//  
//  // Wait only high byte change: AA (new) 22 33 44 (old)
//  `FAIL_IF_LOG(read_val !== 32'hAA223344, $sformatf("Failed in the byte-enable logic: Expected 0xAA223344, got 0x%08X", read_val));
//
//`SVTEST_END