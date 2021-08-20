		// $1: periodic mode.
		regwi 0, $1, 33;
		regwi 0, $2, 1;
		bitwi 0, $2, $2 << 16;
		bitw  0, $1, $1 | $2;
		
		// $4: non-periodic mode.
		regwi 0, $4, 500;

		regwi 1, $1, 100; // i
LOOP:	setbi 7, 0, $4, 0;
		loopnz 1, $1, @LOOP;

	end;

