# Copyright (C) 2022 Xilinx, Inc
# SPDX-License-Identifier: BSD-3-Clause

# check mcp4716 data sheet for register value meanings
DAC101C081_I2C_BUS = 0x1
DAC101C081_SLAVE_ADDR = 0xD
DAC101C081_REG = {
    3.3: [0x00, 0x6C],
    2.5: [0x04, 0xF0],
    1.8: [0x08, 0xB8],
    1.2: [0x0C, 0x2C],
}
