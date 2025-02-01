//tb_rd_enable
//tb_delta
//tb_sigma
//tb_enable
//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_reset_test)

    tb_rst <= 1'b1;

    clock_nedge(1);

    `ASSERT_IMMEDIATE(tb_enable == 1'b0);

    tb_rst <= 1'b0;

    clock_nedge(1);

    `ASSERT_IMMEDIATE(tb_enable == 1'b0);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_work_with_similar_rate_test)

    tb_sigma = 'd5;
    tb_delta = 'd4;

    clock_nedge(1);

    while (count_iter < 50) begin
        tb_rd_enable <= 1'b1;
        
        t1 = 0;
        t2 = 0;

        while(count_time++ < 100)begin
            
            clock_nedge(1);
            if (tb_enable) begin
                t1 ++;
            end else begin
                t2 ++;
            end

        end
        
        count_time = 0;
        tb_rd_enable <= 1'b0;
        count_iter++;
        
        clock_nedge(1);


        `ASSERT_IMMEDIATE($itor(tb_delta)/$itor(tb_sigma) == $itor(t1)/$itor(t1+t2))

        tb_sigma = 'd5*(count_iter + 1);
        tb_delta = 'd4*(count_iter + 1);

    end

    count_iter = 0;

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_work_with_random_rate_test)
    
        tb_sigma = $urandom(12)%255;
        tb_delta = $urandom(13)%255;
        if(tb_sigma == 0) tb_sigma = 1;
        if(tb_delta == 0) tb_delta = 1;

        while(tb_delta > tb_sigma) begin
            tb_delta = tb_delta - tb_sigma;
        end
    
        clock_nedge(1);
    
        while (count_iter < 100) begin
            tb_rd_enable <= 1'b1;
            
            t1 = 0;
            t2 = 0;
    
            while(count_time++ < 100*tb_sigma)begin
                
                clock_nedge(1);
                if (tb_enable) begin
                    t1 ++;
                end else begin
                    t2 ++;
                end
    
            end
            
            count_time = 0;
            tb_rd_enable <= 1'b0;
            count_iter++;
            
            clock_nedge(1);
    
            rate_ideal = $itor(tb_delta)/$itor(tb_sigma);
            rate_real  = $itor(t1)/$itor(t1+t2);
            `ASSERT_IMMEDIATE(((rate_ideal - rate_real)) > -0.05 && ((rate_ideal - rate_real)) < 0.05)
    
            tb_sigma = $urandom(count_iter + 010)%255;
            tb_delta = $urandom(count_iter + 100)%255;
            if(tb_sigma == 0) tb_sigma = 1;
            if(tb_delta == 0) tb_delta = 1;

            while(tb_delta > tb_sigma) begin
                tb_delta = tb_delta - tb_sigma;
            end
    
        end
    
        count_iter = 0;
    
    `SVTEST_END