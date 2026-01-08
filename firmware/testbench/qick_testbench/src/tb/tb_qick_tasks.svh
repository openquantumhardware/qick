task WRITE_AXI(integer PORT_AXI, DATA_AXI);
   $display("Running WRITE_AXI() Task");
   //$display("PORT %d",  PORT_AXI);
   //$display("DATA %d",  DATA_AXI);
   @(posedge s_ps_dma_aclk); #0.1;
   axi_mst_tproc_agent.AXI4LITE_WRITE_BURST(PORT_AXI, prot, DATA_AXI, resp);
endtask

task READ_AXI(integer ADDR_AXI);
   integer DATA_RD;
   $display("Running READ_AXI() Task");
   @(posedge s_ps_dma_aclk); #0.1;
   axi_mst_tproc_agent.AXI4LITE_READ_BURST(ADDR_AXI, 0, DATA_RD, resp);
   $display("READ AXI_DATA %d",  DATA_RD);
endtask


task tproc_load_mem(string test_name);
   string pmem_file, wmem_file, dmem_file;

   $display("### Task tproc_load_mem() start ###");
   $display("Loading Test: %s", test_name);

   pmem_file = {"../../../../src/tb/",test_name,"/pmem.mem"};
   wmem_file = {"../../../../src/tb/",test_name,"/wmem.mem"};
   dmem_file = {"../../../../src/tb/",test_name,"/dmem.mem"};

   $readmemh(pmem_file, AXIS_QPROC.QPROC.CORE_0.CORE_MEM.P_MEM.RAM);
   $readmemh(wmem_file, AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM);
   $readmemh(dmem_file, AXIS_QPROC.QPROC.CORE_0.CORE_MEM.D_MEM.RAM);

   $display("### Task sg_load_mem() end ###");

endtask


// Load pulse data into memory.
task sg_load_mem(string test_name) /*, input logic tb_load_mem, output logic tb_load_mem_done)*/;
   string sg_file;
   int fd,vali,valq;
   bit signed [15:0] ii,qq;
   
   $display("### %t - Task sg_load_mem() start ###", $realtime());

   sg_s0_axis_tvalid = 0;
   sg_s0_axis_tdata  = 0;

   
   $display("################################");
   $display("### Load envelope into Table ###");
   $display("################################");
   $display("t = %0t", $time);

   // start_addr.
   data_wr = 0;
   axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_START_ADDR, prot, data_wr, resp);
   #100ns;
   
   // we.
   data_wr = 1;
   axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_WE, prot, data_wr, resp);
   #100ns;
   
   // Load Envelope Table Memory.
   tb_load_mem    = 1;

   // File must be relative to where the simulation is run from (i.e.: xxx.sim/sim_x/behav/xsim)
   sg_file = {"../../../../src/tb/",test_name,"/sg_0.mem"};
   fd = $fopen(sg_file,"r");

   wait (sg_s0_axis_tready);

   while($fscanf(fd,"%d,%d", vali,valq) == 2) begin
      // $display("I,Q: %d, %d", vali,valq);
      ii = vali;
      qq = valq;
      @(posedge sg_s0_axis_aclk);
      sg_s0_axis_tvalid    = 1;
      sg_s0_axis_tdata     = {qq,ii};
   end
   $fclose(fd);

   @(posedge sg_s0_axis_aclk);
   sg_s0_axis_tvalid    = 0;

   tb_load_mem_done = 1;

   $display("### %t - Task sg_load_mem() end ###", $realtime());
endtask

task config_decimated_readout(integer channel, integer length);

   // Stop Decimated Buffer Capture
   data_wr = 0;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_START_REG, prot, data_wr, resp);
   #100ns;

   // Set Decimated Buffer Capture Length
   data_wr = length;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_LEN_REG, prot, data_wr, resp);
   #100ns;

   // Start Decimated Buffer Capture
   data_wr = 1;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_START_REG, prot, data_wr, resp);
   #100ns;

   // // Readout Decimated Buffer Data
   // data_wr = 0;
   // axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_DR_START_REG, prot, data_wr, resp);
   // #100ns;

endtask

task config_average_readout(integer channel, integer length);

   // Stop Average Buffer Capture
   data_wr = 0;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_START_REG, prot, data_wr, resp);
   #100ns;

   // Set Average Buffer Capture Length
   data_wr = length;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_LEN_REG, prot, data_wr, resp);
   #100ns;

   // Start Average Buffer Capture
   data_wr = 1;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_START_REG, prot, data_wr, resp);
   #100ns;

endtask

task read_decimated_readout(integer channel, integer length);

   // Set Decimated Buffer Read Length
   data_wr = length;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_DR_LEN_REG, prot, data_wr, resp);
   #100ns;

   // Readout Decimated Buffer Data
   data_wr = 1;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_DR_START_REG, prot, data_wr, resp);
   #100ns;

   // Stop Readout Decimated Buffer Data
   data_wr = 0;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(BUF_DR_START_REG, prot, data_wr, resp);
   #100ns;

endtask

task read_average_readout(integer channel, integer length);

   // Set Average Buffer Capture Length
   data_wr = length;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_DR_LEN_REG, prot, data_wr, resp);
   #100ns;

   // Start Average Buffer Read
   data_wr = 1;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_DR_START_REG, prot, data_wr, resp);
   #100ns;

   // Stop Average Buffer Read
   data_wr = 0;
   axi_mst_avg_agent.AXI4LITE_WRITE_BURST(AVG_DR_START_REG, prot, data_wr, resp);
   #100ns;

endtask



task qubit_emulator_config();

   // From https://github.com/openquantumhardware/QCE2024/blob/main/labs_solns/LabDay1_Resonator.ipynb
   // soc.config_resonator(c0=0.85, c1=0.8, verbose=True)
      // SimuChain: f = 500.0 MHz, fd = -114.39999999999998 MHz, k = 232, fdds = 0.8000000000000114 MHz
      // AxisKidsimV3: sel        = resonator
      // AxisKidsimV3: channel    = 232
      // AxisKidsimV3: lane       = 0
      // AxisKidsimV3: punct_id   = 29
      // AxisKidsimV3: iir_c0     = 0.85
      // AxisKidsimV3: iir_c1     = 0.8
      // AxisKidsimV3: iir_g      = 0.9729729729729729
      // AxisKidsimV3: dds_freq   = 0.8000000000000114
      // AxisKidsimV3: dds_wait   = 95
      // AxisKidsimV3: sweep_freq = 2.0
      // AxisKidsimV3: sweep_time = 10.0
      // AxisKidsimV3: nstep      = 1
      // freq = 5461, bval = 13653, slope = 13653, steps = 1, wait = 95
      // c0 = 27853, c1 = 26214, g = 15882
      // sel = 0, punct_id = 29, addr = 0
      // def config_resonator(self, simu_ch=0, q_adc=6, q_dac=0, f=500.0, df=2.0, dt=10.0, c0=0.99, c1=0.8, verbose=False):
         // simu.set_resonator(cfg, verbose=verbose)
            // kidsim_b.set_resonator(cfg, verbose=verbose)
               // self.set_resonator_config(config, verbose)
               // self.set_resonator_regs(config, verbose)

   real     qemu_f      = 100.0;      // in MHz
   // real     qemu_df     = 2.0;      // in MHz
   // real     qemu_dt     = 10.0;     // in us
   real     qemu_c0     = 0.98;
   real     qemu_c1     = 0.85;
   real     qemu_g      = 0.9;
   integer  qemu_sel    = 0;        // 0: 'resonator', 1: 'dds', 2: 'bypass'

   // xil_axi_ulong   QEMU_DDS_BVAL_REG     = 4 * 0;
   // xil_axi_ulong   QEMU_DDS_SLOPE_REG    = 4 * 1;
   // xil_axi_ulong   QEMU_DDS_STEPS_REG    = 4 * 2;
   // xil_axi_ulong   QEMU_DDS_WAIT_REG     = 4 * 3;
   // xil_axi_ulong   QEMU_DDS_FREQ_REG     = 4 * 4;
   // xil_axi_ulong   QEMU_IIR_C0_REG       = 4 * 5;
   // xil_axi_ulong   QEMU_IIR_C1_REG       = 4 * 6;
   // xil_axi_ulong   QEMU_IIR_G_REG        = 4 * 7;
   // xil_axi_ulong   QEMU_OUTSEL_REG       = 4 * 8;
   // xil_axi_ulong   QEMU_PUNCT_ID_REG     = 4 * 9;
   // xil_axi_ulong   QEMU_ADDR_REG         = 4 * 10;
   // xil_axi_ulong   QEMU_WE_REG           = 4 * 11;

   // data_wr = qemu_f * 1e6 / (/*f_adc*/ (1/(2.0*T_RO_CLK*1e-9)) / 2.0**16);
   data_wr = qemu_f * 1e6 / (/*f_adc*/ (1*8/(2.0*T_RO_CLK*1e-9)) / 2.0**16);
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_DDS_FREQ_REG, prot, data_wr, resp);
   #100ns;

   data_wr = qemu_c0 * 2**(16-1);
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_IIR_C0_REG, prot, data_wr, resp);
   #100ns;

   data_wr = qemu_c1 * 2**(16-1);
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_IIR_C1_REG, prot, data_wr, resp);
   #100ns;

   data_wr = qemu_g * 2**(16-1);
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_IIR_G_REG, prot, data_wr, resp);
   #100ns;

   // Write Enable Pulse
   data_wr = 1;
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_WE_REG, prot, data_wr, resp);
   #100ns;

   data_wr = 0;
   axi_mst_qemu_agent.AXI4LITE_WRITE_BURST(QEMU_WE_REG, prot, data_wr, resp);
   #100ns;

endtask
