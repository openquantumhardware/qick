//--------------------------------------
// TEST STIMULI
//--------------------------------------

logic tb_test_run_start;
logic tb_test_run_done;
logic tb_test_read_start;
logic tb_test_read_done;

integer ro_length;
integer ro_decimated_length;
integer ro_average_length;

initial begin

   // Create agents.
   axi_mst_tproc_agent  = new("axi_mst_tproc VIP Agent",tb_qick.u_axi_mst_tproc_0.inst.IF);
   // Set tag for agents.
   axi_mst_tproc_agent.set_agent_tag("axi_mst_tproc VIP");
   // Start agents.
   axi_mst_tproc_agent.start_master();

   // Create agents.
   axi_mst_sg_agent   = new("axi_mst_sg_0 VIP Agent",tb_qick.u_axi_mst_sg_0.inst.IF);
   // Set tag for agents.
   axi_mst_sg_agent.set_agent_tag("axi_mst_sg_0 VIP");
   // Start agents.
   axi_mst_sg_agent.start_master();

   // Create agents.
   axi_mst_avg_agent   = new("axi_mst_avg_0 VIP Agent",tb_qick.u_axi_mst_avg_0.inst.IF);
   // Set tag for agents.
   axi_mst_avg_agent.set_agent_tag("axi_mst_avg_0 VIP");
   // Start agents.
   axi_mst_avg_agent.start_master();

   // Create agents.
   axi_mst_qemu_agent   = new("axi_mst_qemu_0 VIP Agent",tb_qick.u_axi_mst_qemu_0.inst.IF);
   // Set tag for agents.
   axi_mst_qemu_agent.set_agent_tag("axi_mst_qemu_0 VIP");
   // Start agents.
   axi_mst_qemu_agent.start_master();

   $display("*** Start Test ***");
   
   $display("AXI_WDATA_WIDTH %0d",  `AXI_WDATA_WIDTH);

   $display("LFSR %0d",  `LFSR);
   $display("DIVIDER %0d",  `DIVIDER);
   $display("ARITH %0d",  `ARITH);
   $display("TIME_READ %0d",  `TIME_READ);

   $display("DMEM_AW %0d",  `DMEM_AW);
   $display("WMEM_AW %0d",  `WMEM_AW);
   $display("REG_AW %0d",  `REG_AW);
   $display("IN_PORT_QTY %0d",  `IN_PORT_QTY);
   $display("OUT_DPORT_QTY %0d",  `OUT_DPORT_QTY);
   $display("OUT_WPORT_QTY %0d",  `OUT_WPORT_QTY);
   
  
   // Load tProc Memories with Program
   tproc_load_mem(TEST_NAME);


   // INITIAL VALUES

   qnet_dt_i               = '{default:'0} ;
   rst_ni                  = 1'b0;
   axi_dt                  = 0 ;
   // axis_dma_start          = 1'b0;
   s1_axis_tvalid          = 1'b0 ;
   port_1_dt_i             = 0;
   qcom_rdy_i              = 0 ;
   qp2_rdy_i               = 0 ;
   periph_dt_i             = {0,0} ;
   qnet_rdy_i              = 0 ;
   qnet_dt_i [2]           = {0,0} ;
   proc_start_i            = 1'b0;
   proc_stop_i             = 1'b0;
   core_start_i            = 1'b0;
   core_stop_i             = 1'b0;
   time_rst_i              = 1'b0;
   time_init_i             = 1'b0;
   time_updt_i             = 1'b0;
   offset_dt_i             = 0 ;
   // periph_vld_i            = 1'b0;

   tb_load_mem             = 1'b0;
   tb_load_mem_done        = 1'b0;

   tb_test_run_start       = 1'b1;
   tb_test_run_done        = 1'b0;
   tb_test_read_start      = 1'b1;
   tb_test_read_done       = 1'b0;

   ro_length               = 0;
   ro_decimated_length     = 0;
   ro_average_length       = 0;

   sg_s0_axis_tvalid       = 0;
   sg_s0_axis_tdata        = 0;

   m1_axis_buf_dec_tready      = 1'b1;

   m_dma_axis_tready_i     = 1'b1; 
   // max_value               = 0;
   #10ns;

   // Hold Reset
   repeat(16) @ (posedge s_ps_dma_aclk); #0.1ns;
   // Release Reset
   rst_ni = 1'b1;

   #1us;

   // Load Signal Generator Envelope Table Memory.
   sg_load_mem(TEST_NAME);

   #1us;

   // Configure TPROC
   // LFSR Enable (1: Free Running, 2: Step on s1 Read, 3: Step on s0 Write)
   WRITE_AXI( REG_CORE_CFG , 1);
   #100ns;
   WRITE_AXI( REG_CORE_CFG , 0);
   #100ns;
   WRITE_AXI( REG_CORE_CFG , 2);
   #100ns;


   #100ns;

   repeat (REPEAT_EXEC) begin

      config_decimated_readout(0, ro_length);
      config_average_readout(0, ro_length);

      wait(tb_test_run_start);

      WRITE_AXI( REG_TPROC_CTRL , 4); //PROC_START

      #(TEST_RUN_TIME);

      
      WRITE_AXI( REG_TPROC_CTRL , 8); //PROC_STOP
      
      tb_test_run_done = 1'b1;

      wait(tb_test_read_start);

      // Read Decimated Buffer
      read_decimated_readout(0, ro_decimated_length);

      // Read Averaged Buffer (number of triggers in experiment)
      read_average_readout(0, ro_average_length);

      #(TEST_READ_TIME);

      tb_test_read_done = 1'b1;

   end
    
//   WRITE_AXI( REG_TPROC_CTRL , 16); //CORE_START 
//   #1000;
//   WRITE_AXI( REG_TPROC_CTRL , 128); //PROC_RUN
//   #900;
   
   #1us;

   $display("*** End Test ***");
   $finish();
end

initial begin
   integer N;

   $display("*** %t - Waiting for general reset to deassert ***", $realtime());
   wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);

   tb_test_run_start    = 1'b1;
   tb_test_read_start   = 1'b1;
   
   // Default Readout Config
   ro_length            = 1000.0 / (2.0*T_RO_CLK);
   ro_decimated_length  = 1000.0 / (2.0*T_RO_CLK);
   ro_average_length    = 1;


   if (TEST_NAME == "test_basic_pulses") begin
      $display("*** %t - Start test_basic_pulses Test ***", $realtime());
      ro_length            = 2000.0 / (2.0*T_RO_CLK);
      ro_decimated_length  = 2000.0 / (2.0*T_RO_CLK);
      ro_average_length    = 1;

      TEST_READ_TIME       = 10us;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;

      $display("*** %t - End of test_basic_pulses Test ***", $realtime());
   end


   if (TEST_NAME == "test_many_envelopes") begin
      $display("*** %t - Start test_many_envelopes Test ***", $realtime());
      ro_length            = 2000.0 / (2.0*T_RO_CLK);
      ro_decimated_length  = 2000.0 / (2.0*T_RO_CLK);
      ro_average_length    = 1;

      TEST_READ_TIME       = 10us;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;

      $display("*** %t - End of test_many_envelopes Test ***", $realtime());
   end


   if (TEST_NAME == "test_tproc_basic") begin
      TEST_RUN_TIME = 50us;
      forever begin
         $display("*** %t - Start test_tproc_basic Test ***", $realtime());
         wait (tb_qick.AXIS_QPROC.QPROC.QPROC_CTRL.core_en_o == 1'b1);
         N = 11;
         wait (tb_qick.AXIS_QPROC.QPROC.time_abs_o > 2**N+100);
         fork
            begin
               while (N < 48) begin
                  N = N+1;
                  
                  // Force time_abs
                  $display("*** %t - Changing time_abs to get to %0u ***", $realtime(), (2**N)-100);
                  force tb_qick.AXIS_QPROC.QPROC.QPROC_CTRL.QTIME_CTRL.TIME_ADDER.RESULT = (2**N)-100;
                  #100ns;
                  release tb_qick.AXIS_QPROC.QPROC.QPROC_CTRL.QTIME_CTRL.TIME_ADDER.RESULT;
         
                  $display("*** Waiting for trigger ***");
                  wait (tb_qick.AXIS_QPROC.trig_0_o);

                  $display("*** %t - Waiting for time_abs to get to %0u ***", $realtime(), 2**N+100);
                  wait (tb_qick.AXIS_QPROC.QPROC.time_abs_o > 2**N+100);
               end
            end
            begin
               integer M = 15;
               logic [47:0] new_ref_time;
               while (M < 48) begin
                  $display("*** %t - Waiting for r15 == %0d ***", $realtime(), M);
                  wait (tb_qick.AXIS_QPROC.QPROC.CORE_0.CORE_CPU.reg_bank.dreg_32_dt[15] == M);
                  new_ref_time = 2**M;

                  $display("*** %t - Changing c_time_ref_dt to get to %0u ***", $realtime(), new_ref_time);
                  force tb_qick.AXIS_QPROC.QPROC.c_time_ref_dt = new_ref_time;
                  #100ns;
                  release tb_qick.AXIS_QPROC.QPROC.c_time_ref_dt;

                  M = M + 1;
               end
            end
         join
         $display("*** %t - End of test_tproc_basic Test ***", $realtime());
         wait (tb_qick.AXIS_QPROC.QPROC.QPROC_CTRL.core_en_o == 1'b0);
      end
   end


   if (TEST_NAME == "test_qubit_emulator") begin
      $display("*** %t - Start test_qubit_emulator Test ***", $realtime());
      // TEST_OUT_CONNECTION  = "TEST_OUT_QEMU";
      TEST_RUN_TIME        = 50us;
      TEST_READ_TIME       = 10us;
      REPEAT_EXEC          = 1;

      ro_length            = 500;
      ro_decimated_length  = 500;
      ro_average_length    = 21;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;
      qubit_emulator_config();
      #100ns;
      // Configure Readout

      $display("*** %t - End of test_qubit_emulator Test ***", $realtime());
   end


   if (TEST_NAME == "test_randomized_benchmarking") begin
      $display("*** %t - Start test_randomized_benchmarking Test ***", $realtime());
      TEST_RUN_TIME        = 500us;
      REPEAT_EXEC          = 1;

      ro_length            = 1000.0 / (2.0*T_RO_CLK);
      ro_decimated_length  = 1000.0 / (2.0*T_RO_CLK);
      // ro_average_length    = 9 + (9 % 2);
      ro_average_length    = 9;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;
      $display("*** %t - End of test_randomized_benchmarking Test ***", $realtime());
   end


   if (TEST_NAME == "test_issue361") begin
      $display("*** %t - Start test_issue361 Test ***", $realtime());
      TEST_RUN_TIME        = 25us;
      REPEAT_EXEC          = 1;

      ro_length            = 200;
      ro_decimated_length  = 30;
      ro_average_length    = 5;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;

      wait(tb_test_run_done);

      for (int i=0; i<1000; i++) begin
         @(negedge s_ps_dma_aclk);
         m1_axis_buf_dec_tready   = i[4:0] > 15;
      end

      $display("*** %t - End of test_issue361 Test ***", $realtime());
   end


   if (TEST_NAME == "test_issue53") begin
      $display("*** %t - Start test_issue53 Test ***", $realtime());
      TEST_RUN_TIME        = 10us;
      REPEAT_EXEC          = 2;

      ro_length            = 500;
      ro_decimated_length  = 50;
      ro_average_length    = 10;

      wait (tb_qick.AXIS_QPROC.t_resetn == 1'b1);
      #100ns;

      wait(tb_test_run_done);

      $display("*** %t - End of test_issue53 Test ***", $realtime());
   end

end
