`SVTEST(test01_rd_file)

    if(MEM_BIN_FILE != "") begin
        $display({"Reading ", MEM_BIN_FILE});
        $readmemb(MEM_BIN_FILE, tb_bram_data);
        $display("BRAM FILE: ");
        $display(tb_bram_data);
        tb_rd_enb_in  = 1'b1;
        for (int i = 0 ; i < 2**NB_ADDR ; i++) begin
            tb_rd_addr_in = i;
            ## 1;
            `ASSERT_IMMEDIATE(tb_bram_data [i] == tb_data_out);
        end
    end

    `SVTEST_END

`SVTEST(test02_WRandRD_data)

    for (int i = 0 ; i < 2**NB_ADDR ; i++) begin
        bin_memory_queue.push_front($urandom());
    end
    $display(bin_memory_queue);
    tb_wr_enb_in  = 1'b1;

    for (int i = 0 ; i < 2**NB_ADDR ; i++) begin
        tb_wr_addr_in   = i;
        tb_data_in      = bin_memory_queue [i];
        tb_bram_data [i]   = tb_data_in;
        `ASSERT_IMMEDIATE(bin_memory_queue [i] == tb_bram_data [i]);
        ## 1;
    end

    tb_wr_enb_in  = 1'b0;
    tb_rd_enb_in  = 1'b1;

    for (int j = 0 ; j < 2**NB_ADDR ; j++) begin
        tb_rd_addr_in = j;
        ## 1;
        `ASSERT_IMMEDIATE(bin_memory_queue [j] == tb_data_out);
    end

    `SVTEST_END

`SVTEST(test03_read_first)

    for (int h = 0 ; h < 2**NB_ADDR ; h++) begin
        bin_memory_queue.delete(h);
        bin_memory_queue.push_front($urandom());
    end
    $display(bin_memory_queue);

    for (int k = 0 ; k < 2**NB_ADDR ; k++) begin
        tb_rd_addr_in = k;
        tb_wr_addr_in = k;

        tb_rd_enb_in = 1'b1;
        tb_wr_enb_in = 1'b1;

        tb_data_in = bin_memory_queue [k];
        $display("data_in: ",tb_data_in);
        ## 1;
        $display("data_out: ",tb_data_out);
        $display("data_past: ",tb_bram_data [k]);
        $display("_________________________");
        `ASSERT_IMMEDIATE(tb_bram_data [k] == tb_data_out);

        ## 1;
        tb_wr_enb_in  = 1'b0;
        tb_rd_enb_in  = 1'b0;
        ## 1;
    end

    tb_rd_enb_in  = 1'b1;

    for (int j = 0 ; j < 2**NB_ADDR ; j++) begin
        tb_rd_addr_in = j;
        ## 1;
        `ASSERT_IMMEDIATE(bin_memory_queue [j] == tb_data_out);
    end

    tb_rd_enb_in  = 1'b0;

    `SVTEST_END
