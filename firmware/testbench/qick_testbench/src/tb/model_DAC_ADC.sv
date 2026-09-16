///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// DAC-ADC RF frontend model
///////////////////////////////////////////////////////////////////////////

module model_DAC_ADC #(
   parameter integer DAC_W = 16,
   parameter integer ADC_W = 16,
   parameter integer BUFFER_SIZE = 16
)(
   input wire clk_DAC,
   input wire [DAC_W-1:0] dac_sample,

   input wire clk_ADC,
   output logic [ADC_W-1:0] adc_sample,

   input int mode  // 0 = ZOH, 1 = linear
);

   // Parameters
   real pi = 3.14159265358979;

   // DAC samples Buffer
   real buffer_samples[BUFFER_SIZE];
   real buffer_times[BUFFER_SIZE];
   int wr_ptr = 0;

   // Internal Signals
   real signal_in;
   real sampled_ADC;

   initial begin
      for (int i=0; i<BUFFER_SIZE; i++) begin
         buffer_samples[i] = 0.0;
         buffer_times[i] = 0.0;
      end
   end

   // DAC processing
   always @(posedge clk_DAC) begin
      real t_now = $realtime * 1e-9;
      signal_in = $signed(dac_sample) / 2.0**(DAC_W-1);

      buffer_samples[wr_ptr] = signal_in;
      buffer_times[wr_ptr] = t_now;
      wr_ptr = (wr_ptr + 1) % BUFFER_SIZE;

      // $display("[%0t ns] DAC sample: %f", $time, signal_in);
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