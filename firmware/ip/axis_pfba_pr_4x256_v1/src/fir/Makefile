all: ipgen copy sedxci clean_proj

ipgen: fir.tcl
	vivado -mode batch -source tcl/ipgen.tcl

copy:
	cp -r `find ./ipgen/ipgen.srcs -type d -name "fir*"` .
	cp -r `find ./ipgen/ipgen.gen -name "fir_0.veo"` .

sedxci:
	sed -i -r 's#(../)+(coef/fir.*.coe)#../\2#' `find . -name "fir*.xci"`

fir.tcl: tcl/fir.tcl.template
	./gen.pl tcl/fir.tcl.template

clean: clean_proj
	rm -rf `find . -type d -name "fir*"`
	rm -rf fir*.veo fir.tcl add.tcl

clean_proj:
	rm -rf ipgen vivado*
