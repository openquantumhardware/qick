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
        regwi 1, $2, 15000;  // gain.        
        regwi 1, $3, 300;    // nsamp.
        regwi 1, $4, 0x5;    // b00101 -> phrst = 0, stdysel = 0, mode = 1, outsel = 01
        bitwi 1, $4, $4 << 16;
        bitw  1, $3, $3 | $4;
        regwi 1, $5, 0;  
        
        // Program signal generators in periodic mode.
        set 4, 1, $1, $0, $0, $2, $3, $5;
        set 5, 1, $1, $0, $0, $2, $3, $5;        
        set 6, 1, $1, $0, $0, $2, $3, $5;
        set 7, 1, $1, $0, $0, $2, $3, $5;
        
        // Set trigger.
        regwi 0, $1, 0xc000;
        seti 0, 0, $1, 0;
      
        end;