onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+axi_mst_0 -L xilinx_vip -L xil_defaultlib -L xpm -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_5 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.axi_mst_0 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {axi_mst_0.udo}

run -all

endsim

quit -force
