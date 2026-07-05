`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- dual-clock top wrapper (autonomous sweep controller).
//
//   peak_finder (sweep FSM + argmax) + the QP2 opcode FSM run on `clk` (the
//   fpga/tProc clock).  amplitude_calculator runs on `s_axis_aclk` (the
//   ADC/readout clock) where the IQ stream lives.
//
//   CDC -- each crossing uses the right primitive for its kind (synchronizer.v):
//     trigger              fpga_clk -> adc_clk : synchronizer_n (2-FF) + edge
//     nsamp/averager_value fpga_clk -> adc_clk : synchronizer (quasi-static bus)
//     coherent (SumI)^2+(SumQ)^2 adc_clk -> fpga_clk : synchronizer_handshake (req/ack)
//
// QP2 opcode map:
//   OP 0: dt1=start_freq dt2=nsamp dt3=step dt4=(unused)   -- sweep config
//   OP 4: dt1=n_points   dt2=averager_value                 -- sweep config
//   OP 1: (no data)                                         -- start the sweep
//   OP 2: IP-> dt1=freq_word dt2={30'd0,freq_valid,finish}  -- poll handshake
//   OP 3: (no data)                                         -- reset_max pulse
//
//   OP2.dt2 bit0 = finish (sweep complete; dt1 = freq_at_max)
//   OP2.dt2 bit1 = freq_valid (a new point is ready; dt1 = its freq_word)
//------------------------------------------------------------------------------

module fine_tuning_sweep #(
  parameter MAX_AVG = 64
)(
  // ---- c_clk domain ----
  input wire clk,
  input wire rst_n,

  // QP2 (c_clk)
  input wire qtag_en_i,
  input wire [4:0] qtag_op_i,
  input wire [31:0] qtag_dt1_i,
  input wire [31:0] qtag_dt2_i,
  input wire [31:0] qtag_dt3_i,
  input wire [31:0] qtag_dt4_i,
  output reg qtag_rdy_o,
  output reg [31:0] qtag_dt1_o,
  output reg [31:0] qtag_dt2_o,
  output reg qtag_vld_o,

  // tProc trigger pulse (generated in the tProc t_clk domain -- async here)
  input wire trigger,

  // ---- s_axis_aclk (ro_clk) domain ----
  input wire s_axis_aclk,
  input wire s_axis_aresetn,
  input wire s_axis_tvalid,
  input wire [31:0] s_axis_tdata
);

  localparam AVG_BITS = $clog2(MAX_AVG);

  // =========================================================
  // c_clk: rising-edge detect on qtag_en_i
  // =========================================================
  reg en_d;
  wire en_rise = qtag_en_i & ~en_d;

  always @(posedge clk) begin
    if (!rst_n)
      en_d <= 1'b0;
    else
      en_d <= qtag_en_i;
  end

  wire start_now = en_rise & (qtag_op_i == 5'd1);
  wire reset_max_now = en_rise & (qtag_op_i == 5'd3);
  wire op2_read = en_rise & (qtag_op_i == 5'd2);

  // =========================================================
  // c_clk: config registers + QP2 opcode FSM
  // =========================================================
  (* mark_debug = "true" *) reg [31:0] reg_start;
  (* mark_debug = "true" *) reg [31:0] reg_step;
  (* mark_debug = "true" *) reg [31:0] reg_nsamp;
  (* mark_debug = "true" *) reg [31:0] reg_npoints;
  (* mark_debug = "true" *) reg [31:0] reg_avg;

  // from peak_finder (c_clk)
  wire [31:0] pf_freq_word;
  wire pf_freq_valid;
  wire pf_finish;
  wire [79:0] max_amplitude;
  wire [31:0] freq_at_max;

  // sticky handshake flags (so a polling tProc never misses a 1-cycle pulse)
  (* mark_debug = "true" *) reg sticky_freq_valid;
  (* mark_debug = "true" *) reg sticky_finish;

  always @(posedge clk) begin
    if (!rst_n) begin
      qtag_vld_o <= 1'b0;
      qtag_dt1_o <= 32'd0;
      qtag_dt2_o <= 32'd0;
      reg_start <= 32'd0;
      reg_step <= 32'd0;
      reg_nsamp <= 32'd0;
      reg_npoints <= 32'd0;
      reg_avg <= 32'd0;
    end else begin
      if (en_rise) begin
        case (qtag_op_i)
          5'd0: begin
            // sweep config: start/step/nsamp
            reg_start <= qtag_dt1_i;
            reg_step <= qtag_dt3_i;
            reg_nsamp <= qtag_dt2_i;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd4: begin
            // sweep config: n_points/averager_value
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_nsamp <= reg_nsamp;
            reg_npoints <= qtag_dt1_i;
            reg_avg <= qtag_dt2_i;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd1: begin
            // start the sweep -- start_now pulse drives peak_finder directly
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_nsamp <= reg_nsamp;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd2: begin
            // poll handshake -- return freq_word + sticky flags
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_nsamp <= reg_nsamp;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= pf_freq_word;
            qtag_dt2_o <= {30'd0, sticky_freq_valid, sticky_finish};
            qtag_vld_o <= 1'b1;
          end

          5'd3: begin
            // reset_max -- reset_max_now pulse drives peak_finder directly
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_nsamp <= reg_nsamp;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          default: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_nsamp <= reg_nsamp;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end
        endcase
      end else begin
        // no opcode strobe: hold config + outputs, pulse vld low
        reg_start <= reg_start;
        reg_step <= reg_step;
        reg_nsamp <= reg_nsamp;
        reg_npoints <= reg_npoints;
        reg_avg <= reg_avg;
        qtag_dt1_o <= qtag_dt1_o;
        qtag_dt2_o <= qtag_dt2_o;
        qtag_vld_o <= 1'b0;
      end
    end
  end

  // sticky_freq_valid: set when peak_finder presents a new point; cleared when
  // the tProc consumes it via an OP2 read. Set wins on a coincidence.
  always @(posedge clk) begin
    if (!rst_n)
      sticky_freq_valid <= 1'b0;
    else if (pf_freq_valid)
      sticky_freq_valid <= 1'b1;
    else if (op2_read)
      sticky_freq_valid <= 1'b0;
    else
      sticky_freq_valid <= sticky_freq_valid;
  end

  // sticky_finish: set when the sweep completes; cleared when the next sweep
  // starts (OP1). Survives any number of OP2 polls in between.
  always @(posedge clk) begin
    if (!rst_n)
      sticky_finish <= 1'b0;
    else if (pf_finish)
      sticky_finish <= 1'b1;
    else if (start_now)
      sticky_finish <= 1'b0;
    else
      sticky_finish <= sticky_finish;
  end

  // qtag_rdy_o: "answer ready" the tProc waits on (s_status bit_qpb_rdy #h0400).
  // reset=1 (idle), low on OP1, high on finish.
  always @(posedge clk) begin
    if (!rst_n)
      qtag_rdy_o <= 1'b1;
    else if (start_now)
      qtag_rdy_o <= 1'b0;
    else if (pf_finish)
      qtag_rdy_o <= 1'b1;
    else
      qtag_rdy_o <= qtag_rdy_o;
  end

  // =========================================================
  // CDC fpga_clk -> adc_clk
  // =========================================================
  wire [31:0] nsamp_ro;
  wire [AVG_BITS-1:0] averager_value_ro;

  synchronizer #(.WIDTH(32)) u_sync_nsamp (
    .clk   (s_axis_aclk),
    .rst_n (s_axis_aresetn),
    .d_in  (reg_nsamp),
    .d_out (nsamp_ro)
  );

  synchronizer #(.WIDTH(AVG_BITS)) u_sync_avg (
    .clk   (s_axis_aclk),
    .rst_n (s_axis_aresetn),
    .d_in  (reg_avg[AVG_BITS-1:0]),
    .d_out (averager_value_ro)
  );

  wire trig_resync;
  synchronizer_n #(.N(2)) u_trig_sync (
    .clk      (s_axis_aclk),
    .rstn     (s_axis_aresetn),
    .data_in  (trigger),
    .data_out (trig_resync)
  );
  reg trig_resync_d;
  always @(posedge s_axis_aclk) begin
    if (!s_axis_aresetn)
      trig_resync_d <= 1'b0;
    else
      trig_resync_d <= trig_resync;
  end
  wire trigger_ro = trig_resync & ~trig_resync_d;   // one clean adc-clk pulse

  // =========================================================
  // adc_clk: amplitude_calculator
  // =========================================================
  wire [79:0] amp_data_ro;
  wire amp_valid_ro;

  amplitude_calculator #(
    .MAX_AVG     (MAX_AVG),
    .ACCUM_WIDTH (80)
  ) u_amplitude_calculator (
    .clk            (s_axis_aclk),
    .rst_n          (s_axis_aresetn),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tdata   (s_axis_tdata),
    .trigger        (trigger_ro),
    .nsamp          (nsamp_ro),
    .averager_value (averager_value_ro),
    .m_axis_tdata   (amp_data_ro),
    .m_axis_tvalid  (amp_valid_ro)
  );

  // =========================================================
  // CDC adc_clk -> fpga_clk: coherent (SumI)^2+(SumQ)^2 + valid (req/ack handshake)
  // =========================================================
  wire [79:0] amp_data_c;
  wire amp_valid_c;

  synchronizer_handshake #(.WIDTH(80)) u_amp_cdc (
    .clk_src  (s_axis_aclk),
    .rst_n_src(s_axis_aresetn),
    .clk_dst  (clk),
    .rst_n_dst(rst_n),
    .valid_in (amp_valid_ro),
    .data_in  (amp_data_ro),
    .valid_out(amp_valid_c),
    .data_out (amp_data_c)
  );

  // =========================================================
  // c_clk: peak_finder (sweep FSM + argmax) -- consumes the handshaked result
  // =========================================================
  peak_finder #(
    .ACCUM_WIDTH (80)
  ) u_peak_finder_v2 (
    .clk           (clk),
    .rstn          (rst_n),
    .start         (start_now),
    .start_freq    (reg_start),
    .step          (reg_step),
    .n_points      (reg_npoints),
    .reset_max     (reset_max_now),
    .amp_valid     (amp_valid_c),
    .amp_data      (amp_data_c),
    .freq_word     (pf_freq_word),
    .freq_valid    (pf_freq_valid),
    .finish        (pf_finish),
    .max_amplitude (max_amplitude),
    .freq_at_max   (freq_at_max)
  );

  // ============================== DEBUG PROBES ==============================
  // ILA taps grouped by clock domain (one debug core per clock). Registers that
  // already exist are mark_debug'd in place above; the two blocks below sample
  // the signals that are NOT registers (input ports, the trigger_ro pulse, and
  // the sync/handshake output wires) into a flop so the debug hub only connects
  // to a register output.
  //
  // synchronizer.v is left untouched (no mark_debug inside the CDC primitive),
  // but BOTH sides of every crossing are probed here so the ILA can confirm the
  // synchronizer carried the value faithfully:
  //   nsamp : reg_nsamp (c_clk, in place)  <-> nsamp_ro_dbg          (adc)
  //   avg   : reg_avg    (c_clk, in place)  <-> averager_value_ro_dbg (adc)
  //   trig  : trigger_dbg (c_clk)           <-> trigger_ro_dbg        (adc)
  //   amp   : amp_valid_c_dbg/amp_data_c_dbg (c_clk) <-> amp_valid_ro_dbg/amp_data_ro_dbg (adc)
  //
  // Wide buses (s_axis_tdata / nsamp_ro / amp_data_*) register full width; trim
  // bit-selection in Vivado Set Up Debug if the 552 MHz adc domain is routing/
  // timing-tight.

  // ---- c_clk domain: destination side of the adc->fpga amp handshake +
  //      fabric-side view of the trigger before it crosses into s_axis_aclk.
  //      The trigger originates in the tProc t_clk domain, so even this
  //      debug-only view goes through a 2-FF synchronizer first: sampling the
  //      raw async net into trigger_dbg was the one genuine CDC Critical in
  //      the design (CDC-1). ----
  wire trigger_c_dbg;
  synchronizer_n #(.N(2)) u_trig_dbg_sync (
    .clk      (clk),
    .rstn     (rst_n),
    .data_in  (trigger),
    .data_out (trigger_c_dbg)
  );
  (* mark_debug = "true" *) reg        trigger_dbg;
  (* mark_debug = "true" *) reg        amp_valid_c_dbg;
  (* mark_debug = "true" *) reg [79:0] amp_data_c_dbg;
  always @(posedge clk) begin
    if (!rst_n) begin
      trigger_dbg <= 1'b0;
      amp_valid_c_dbg <= 1'b0;
      amp_data_c_dbg <= 80'd0;
    end else begin
      trigger_dbg <= trigger_c_dbg;
      amp_valid_c_dbg <= amp_valid_c;
      amp_data_c_dbg <= amp_data_c;
    end
  end

  // ---- s_axis_aclk (adc) domain ----
  (* mark_debug = "true" *) reg        s_axis_aresetn_dbg;
  (* mark_debug = "true" *) reg        s_axis_tvalid_dbg;
  (* mark_debug = "true" *) reg [31:0] s_axis_tdata_dbg;
  (* mark_debug = "true" *) reg        trigger_ro_dbg;
  (* mark_debug = "true" *) reg [31:0] nsamp_ro_dbg;
  (* mark_debug = "true" *) reg [AVG_BITS-1:0] averager_value_ro_dbg;
  (* mark_debug = "true" *) reg        amp_valid_ro_dbg;
  (* mark_debug = "true" *) reg [79:0] amp_data_ro_dbg;
  always @(posedge s_axis_aclk) begin
    if (!s_axis_aresetn) begin
      s_axis_aresetn_dbg <= 1'b0;
      s_axis_tvalid_dbg <= 1'b0;
      s_axis_tdata_dbg <= 32'd0;
      trigger_ro_dbg <= 1'b0;
      nsamp_ro_dbg <= 32'd0;
      averager_value_ro_dbg <= {AVG_BITS{1'b0}};
      amp_valid_ro_dbg <= 1'b0;
      amp_data_ro_dbg <= 80'd0;
    end else begin
      s_axis_aresetn_dbg <= s_axis_aresetn;
      s_axis_tvalid_dbg <= s_axis_tvalid;
      s_axis_tdata_dbg <= s_axis_tdata;
      trigger_ro_dbg <= trigger_ro;
      nsamp_ro_dbg <= nsamp_ro;
      averager_value_ro_dbg <= averager_value_ro;
      amp_valid_ro_dbg <= amp_valid_ro;
      amp_data_ro_dbg <= amp_data_ro;
    end
  end

endmodule
