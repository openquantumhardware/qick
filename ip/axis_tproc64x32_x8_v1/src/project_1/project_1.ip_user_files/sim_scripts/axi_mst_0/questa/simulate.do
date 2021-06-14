onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib axi_mst_0_opt

do {wave.do}

view wave
view structure
view signals

do {axi_mst_0.udo}

run -all

quit -force
