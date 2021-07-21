### tProcesser-64 ASM_Program() cheat sheet

## Python calls

`soc.tproc.single_write(addr=imm, data=variable)` writes the value `variable` to the data memory `imm`

## ASM_Program calls
`p.memri(p, r, imm, 'comment')` -- read the data memory at the address specified by `imm` and write the result into page `p`, register `r`. 

`p.regwi(p,r,value)`  -- write the `value` to page `p`, register `r`.

`p.bitwi(p, rDst, rSrc, operation, value)` -- performs the bitwise `operation` on the contents of page `p`, register `rSrc` and `value` and write the result in page `p`, register `rDst`.  `rSrc` and `rDst` may be the same or register.  

`p.bitw(p, rDst, rSrc1, operation, rSrc2` -- performs the bitwise `operation` on two source registers (`rSrc1` and `rSrc2`) and put the result in the destination register `rDst`, where all three registers are on the same page `p`.

`p.seti(channel, p, rSrc, time)` -- take the value at page `p`, register `rSrc` and send it to `channel` that the specifified `time`.  Note that 

`p.label(labelName)` -- mark this location in the program, for use by the `loopz` and `condj` commands.

`p.set(channel, p, ra, rb,rc,rd,rd,time)` -- sent the values on page `p` registers `ra`,`rb`,`rc`,`rd`,`re` to `channel` at `time`. 

`p.sync(p,r)` -- synchronize internal time offset to the value specified by page `p`,register `r`

`p.synci(p,timeOffset)` -- synchronize internal time offset by `timeOffset`

### ASM_Program bitwise operations

* `<<` -- shift bits left by `value` bits, ignores `rSrc`
* `|` -- or
* `&` -- and
* `^` -- exclusive or
* `~` -- not `value`, ignores `rSrc`

