// Signal Generator V4.
// 31  ..   0 : frequency.
// 63  ..  32 : phase.
// 79  ..  64 : addr.
// 95  ..  80 : xxxx (not used).
// 111 ..  96 : gain.
// 127 .. 112 : xxxx (not used).
// 143 .. 128 : nsamp.
// 145 .. 144 : outsel  (00: product, 01: dds, 10: table, 11: zero value).
//        146 : mode    (0: nsamp, 1: periodic).
//        147 : stdysel (0: last value, 1: zero value).
//        148 : phrst   (not implemented yet).
// 159 .. 149 : xxxx (not used).

        // channels 4, 5, 6, 7 -> DAC 229 CH0/1/2/3.
        memri 1, $1, 123;    // freq.
        memri 1, $2, 124;    // phase.
        regwi 1, $3, 32000;  // gain.        
        regwi 1, $4, 10;     // nsamp. Generator will consume 16*nsamp DAC values.
        regwi 1, $5, 0x4;    // b00100 -> phrst = 0, stdysel = 0, mode = 1, outsel = 00
        bitwi 1, $5, $5 << 16;
        bitw  1, $4, $4 | $5;
//        regwi 1, $6, 785;      // start time.
        regwi 1, $6, 0;      // start time.
        
        synci 1000;
        
        regwi 0, $1, 0x1; // Send a pulse on pmod 0_0 (pin 1 on J48 on the ZCU111).
        seti 0, 0, $1, 0; // Start the pulse.
        seti 0, 0, $0, 100; // End the pulse after 100 ticks (260 ns).
        
        // Program signal generators in periodic mode.
        set 1, 1, $1, $2, $0, $3, $4, $6;
        set 2, 1, $1, $2, $0, $3, $4, $6;
        set 3, 1, $1, $2, $0, $3, $4, $6;
        set 4, 1, $1, $2, $0, $3, $4, $6;
        set 5, 1, $1, $2, $0, $3, $4, $6;        
        set 6, 1, $1, $2, $0, $3, $4, $6;
        set 7, 1, $1, $2, $0, $3, $4, $6;
        
        synci 1000;
        
        // Set trigger.
        regwi 0, $1, 0xc000; // Trigger both ADC channels.
        seti 0, 0, $1, 0;
        seti 0, 0, $0, 100;
      
        end;