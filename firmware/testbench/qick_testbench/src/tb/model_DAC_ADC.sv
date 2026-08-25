///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// DAC RF frontend model
///////////////////////////////////////////////////////////////////////////

`timescale 1ns/1fs

module automatic model_DAC #(
   parameter integer DAC_W = 16,
   parameter integer N_DDS = 16
)(
   input wire clk_DAC,
   input wire axis_tvalid,
   input wire [N_DDS*DAC_W-1:0] axis_tdata,
   output logic axis_tready,
   output real dac_signal_rf
);

   logic signed [DAC_W-1:0] dac_sample;
   logic [$clog2(N_DDS)-1:0] dac_samp_cnt;

   // Behavioral DAC model always accepts input samples.
   assign axis_tready = 1'b1;

   // SG to DAC unpacking: consume one lane per dac_fs edge while tvalid is high.
   always_ff @(posedge clk_DAC) begin
      if (axis_tvalid) begin
         dac_sample    <= axis_tdata[DAC_W*dac_samp_cnt +: DAC_W];
         dac_samp_cnt  <= dac_samp_cnt + 'd1;
      end
      else begin
         dac_sample    <= 'd0;
         dac_samp_cnt  <= 'd0;
      end
   end

   // DAC processing
   always @(posedge clk_DAC) begin
      dac_signal_rf <= $signed(dac_sample) / 2.0**(DAC_W-1);

      // $display("[%0t ns] DAC sample: %f", $time, dac_signal_rf);
   end

endmodule


///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// ADC RF frontend model
///////////////////////////////////////////////////////////////////////////
module automatic model_ADC #(
   parameter integer ADC_W = 16,
   parameter integer BUFFER_SIZE = 16,
   parameter integer N_DDS = 8,
   parameter real ADC_NOISE_STD = 0.0,
   // Coarse mixer at -Fs/4 + decimate-by-2
   parameter bit MIXER_FS4_EN = 1'b0
)(
   input wire clk_DAC,
   input real dac_signal_rf,
   input wire clk_ADC,
   input wire axis_tready,
   input wire mode,  // 0 = ZOH, 1 = linear
   output logic axis_tvalid,
   output logic [N_DDS*ADC_W-1:0] axis_tdata
);

   if (MIXER_FS4_EN) begin : gen_mixer_fs4_check
      // N_DDS must be a multiple of 4 so the free-running mix_phase stays aligned
      // with axis_samp_cnt's parity across every group wrap.
      if ((N_DDS % 4) != 0)
         $fatal(1, "model_ADC: N_DDS must be a multiple of 4 when MIXER_FS4_EN=1 (got %0d)", N_DDS);
   end

   logic [ADC_W-1:0] adc_sample;

   // DAC samples Buffer
   real buffer_samples[BUFFER_SIZE];
   real buffer_times[BUFFER_SIZE];
   int wr_ptr = 0;

   // Internal Signals
   real sampled_ADC;
   logic [$clog2(N_DDS)-1:0] axis_samp_cnt;
   logic [$clog2(N_DDS)-1:0] axis_stream_cnt;
   logic                     rf_signal_valid;
   logic [N_DDS*ADC_W-1:0]   rf_signal_data;

   // -Fs/4 mixer state: free-running so pair-sign parity survives group
   // boundaries; phase 0/2=I beat (sign +/-), 1/3=Q beat (sign +/-).
   logic [1:0]        mix_phase;
   logic [ADC_W-1:0]  pending_i;

   initial begin
      axis_samp_cnt   = '0;
      axis_stream_cnt = '0;
      rf_signal_valid  = 1'b0;
      axis_tvalid      = 1'b0;
      axis_tdata       = '0;
      rf_signal_data   = '0;
      mix_phase        = 2'd0;
      pending_i        = '0;
   end

   initial begin
      for (int i=0; i<BUFFER_SIZE; i++) begin
         buffer_samples[i] = 0.0;
         buffer_times[i] = 0.0;
      end
   end

   // DAC processing
   always @(posedge clk_DAC) begin
      real t_dac = $realtime /* * 1e-9*/;

      buffer_samples[wr_ptr] = dac_signal_rf;
      buffer_times[wr_ptr] = t_dac;
      wr_ptr = (wr_ptr + 1) % BUFFER_SIZE;
   end

   // // To see buffer in Verilator
   // real buf_time_0 = buffer_times[0];
   // real buf_time_1 = buffer_times[1];
   // real buf_time_2 = buffer_times[2];
   // real buf_time_3 = buffer_times[3];

   real adc_noise;
   int noise_seed = 1;

   // ADC processing
   always @(posedge clk_ADC) begin
      real t_adc = $realtime /* * 1e-9*/;
      real val;

      case (mode)
         0: begin
               // ZOH: last value
               int idx_last = (wr_ptr + BUFFER_SIZE - 1) % BUFFER_SIZE;
               val = buffer_samples[idx_last];
         end
         1: begin
               // Linear: use last 2 samples to interpolate
               int idx_curr = (wr_ptr + BUFFER_SIZE - 1) % BUFFER_SIZE;
               int idx_prev = (wr_ptr + BUFFER_SIZE - 2) % BUFFER_SIZE;
               real t1 = buffer_times[idx_prev];
               real t2 = buffer_times[idx_curr];
               real y1 = buffer_samples[idx_prev];
               real y2 = buffer_samples[idx_curr];
               if (t2 != t1)
                  val = y1 + (t_adc - t1) * (y2 - y1)/(t2 - t1);
               else
                  val = y2;
         end
         default: val = 0.0;
      endcase

      noise_seed = noise_seed + 1;
      adc_noise = ADC_NOISE_STD * $dist_normal(noise_seed, 0, 1000) / 1000.0;
      // $display("[%0t ns] ADC noise: %f", $time, adc_noise);

      if (val + adc_noise > 1.0)          sampled_ADC = 1.0;
      else if (val + adc_noise < -1.0)    sampled_ADC = -1.0;
      else                                sampled_ADC = val + adc_noise;
      adc_sample = sampled_ADC * $signed(2**(ADC_W-1)-1);

      if (axis_samp_cnt < N_DDS-1) begin
         axis_samp_cnt  <= axis_samp_cnt + 1;
         rf_signal_valid <= 1'b0;
      end
      else begin
         axis_samp_cnt  <= 0;
         rf_signal_valid <= 1'b1;
      end

      if (MIXER_FS4_EN) begin : gen_mixer_fs4_pack
         // -Fs/4 real->I/Q identity: complex[k] = (-1)^k*(adc[2k]+j*adc[2k+1]).
         logic [ADC_W-1:0] adc_signed_neg;
         // Negate in two's complement with saturation (min-negative has no positive counterpart).
         adc_signed_neg = (adc_sample == {1'b1, {(ADC_W-1){1'b0}}}) ?
                          {1'b0, {(ADC_W-1){1'b1}}} : (~adc_sample + 1'b1);

         case (mix_phase)
            2'd0: pending_i <= adc_sample;
            2'd1: rf_signal_data[ADC_W*(axis_samp_cnt-1) +: 2*ADC_W] <= {adc_sample, pending_i};
            2'd2: pending_i <= adc_signed_neg;
            2'd3: rf_signal_data[ADC_W*(axis_samp_cnt-1) +: 2*ADC_W] <= {adc_signed_neg, pending_i};
         endcase
         mix_phase <= mix_phase + 2'd1;
      end
      else begin : gen_mixer_bypass_pack
         rf_signal_data[ADC_W*axis_samp_cnt +: ADC_W] <= adc_sample;
      end

      if (axis_stream_cnt == 0) begin
         axis_tvalid <= rf_signal_valid;
         axis_tdata  <= rf_signal_data;
      end

      if (rf_signal_valid || axis_tvalid) begin
         axis_stream_cnt <= axis_stream_cnt + 1;
      end
      else begin
         axis_stream_cnt <= 0;
      end

      // $display("[%0t ns] ADC sample (mode %0d): %f", $time, mode, sampled_ADC);
   end

endmodule