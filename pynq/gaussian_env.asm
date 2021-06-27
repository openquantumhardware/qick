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

        // channels 6, 7 -> DAC 229 CH2/3.
        memri 1, $1, 17;     // freq.
        regwi 1, $2, 15000;  // gain.        
        memri 1, $3, 18;     // nsamp.
        regwi 1, $4, 0x8;    // b01000 -> phrst = 0, stdysel = 1, mode = 0, outsel = 00
        bitwi 1, $4, $4 << 16;
        bitw  1, $3, $3 | $4;
        regwi 1, $5, 0;  
        
        synci 200;
        
        // Signal start and trigger average block.
        regwi 0, $1, 0x4001;
        seti 0, 0, $1, 0;
     
        // Loop.
        memri 0, $9, 19; // Nsync.
        memri 0, $4, 33; // Number of repetitions.
LOOP:   set 6, 1, $1, $0, $0, $2, $3, $5;
        set 7, 1, $1, $0, $0, $2, $3, $5;
        mathi 1, $2, $2 + 1000;
        sync 0, $9;
        loopnz 0, $4, @LOOP;
        
        // Wait and read average value.
        waiti 0, 1000;
        read 0, 3, lower $1; // Lower 32-bit on register $1 of page 3.
        read 0, 3, upper $2; // Upper 32-bit on register $2 of page 3.                
        
        // Write values back into memory.
        memwi 3, $1, 55;
        memwi 3, $2, 56;
        
        // Signal end.
        seti 0, 0, $0, 0;        
        
        end;