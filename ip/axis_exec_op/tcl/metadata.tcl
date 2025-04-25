set design "axis_exec_op"
set top "${design}_wrapper"
set proj_dir "./ip_proj"

set ip_properties [ list \
    vendor "lucasbrasilino.com" \
    library "AXIS" \
    name ${design} \
    version "1.0" \
    taxonomy "/AXIS_Application" \
    display_name "AXIS Op Execution" \
    description "Executes an operation over AXI4-Stream" \
    vendor_display_name "Lucas Brasilino" \
    company_url "http://lucasbrasilino.com" \
    ]

set family_lifecycle { \
  artix7 Production \
  artix7l Production \
  kintex7 Production \
  kintex7l Production \
  kintexu Production \
  kintexuplus Production \
  virtex7 Production \
  virtexu Production \
  virtexuplus Production \
  zynq Production \
  zynquplus Production \
  aartix7 Production \
  azynq Production \
  qartix7 Production \
  qkintex7 Production \
  qkintex7l Production \
  qvirtex7 Production \
  qzynq Production \
}