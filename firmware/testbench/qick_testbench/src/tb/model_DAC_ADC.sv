///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// DAC RF frontend model
///////////////////////////////////////////////////////////////////////////
module model_DAC #(
   parameter integer DAC_W = 16
)(
   input wire clk_DAC,
   input wire [DAC_W-1:0] dac_sample,
   output real dac_signal_rf
);

   // DAC processing
   always @(posedge clk_DAC) begin
      dac_signal_rf = $signed(dac_sample) / 2.0**(DAC_W-1);

      // $display("[%0t ns] DAC sample: %f", $time, dac_signal_rf);
   end

endmodule


///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// ADC RF frontend model
///////////////////////////////////////////////////////////////////////////
module model_ADC #(
   parameter integer ADC_W = 16,
   parameter integer BUFFER_SIZE = 16
)(
   input wire clk_DAC,
   input real dac_signal_rf,
   input wire clk_ADC,
   input wire mode,  // 0 = ZOH, 1 = linear
   output logic [ADC_W-1:0] adc_sample
);

   // DAC samples Buffer
   real buffer_samples[BUFFER_SIZE];
   real buffer_times[BUFFER_SIZE];
   int wr_ptr = 0;

   // Internal Signals
   real sampled_ADC;

   initial begin
      for (int i=0; i<BUFFER_SIZE; i++) begin
         buffer_samples[i] = 0.0;
         buffer_times[i] = 0.0;
      end
   end

   // DAC processing
   always @(posedge clk_DAC) begin
      real t_dac = $realtime * 1e-9;

      buffer_samples[wr_ptr] = dac_signal_rf;
      buffer_times[wr_ptr] = t_dac;
      wr_ptr = (wr_ptr + 1) % BUFFER_SIZE;
   end

   // ADC processing
   always @(posedge clk_ADC) begin
      real t_adc = $realtime * 1e-9;
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

      if (val > 1.0)          sampled_ADC = 1.0;
      else if (val < -1.0)    sampled_ADC = -1.0;
      else                    sampled_ADC = val;
      adc_sample = sampled_ADC * $signed(2**(ADC_W-1)-1);

      // $display("[%0t ns] ADC sample (mode %0d): %f", $time, mode, sampled_ADC);
   end

endmodule