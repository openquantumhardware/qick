# Copyright (C) 2022 Xilinx, Inc
# SPDX-License-Identifier: BSD-3-Clause

import os
os.environ['BOARD'] = 'RFSoC4x2'
import xrfclk
import rfsystem
from smbus2 import SMBus, i2c_msg
import pynq
import pynq.lib
from .constants import *

class BaseOverlay(pynq.Overlay):
    """Base overlay for the board.

    The base overlay contains Pmod 0 and 1, LEDs, RGBLEDs, push buttons,
    switches, and pin control gpio.

    After reloading the base overlay, the I2C and display port should become
    available as well.

    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.is_loaded():
            self.iop_pmod0.mbtype = "Pmod"
            self.iop_pmod1.mbtype = "Pmod"
            self.PMOD0 = self.iop_pmod0.mb_info
            self.PMOD1 = self.iop_pmod1.mb_info
            self.PMODA = self.PMOD0
            self.PMODB = self.PMOD1

            self.leds = self.leds_gpio.channel1
            self.leds.setdirection('out')
            self.leds.setlength(4)

            self.rgbleds = [pynq.lib.RGBLED(i) for i in range(2)]

            self.buttons = self.btns_gpio.channel1
            self.buttons.setdirection('in')
            self.buttons.setlength(5)

            self.switches = self.sws_gpio.channel1
            self.switches.setdirection('in')
            self.switches.setlength(4)
            
            self.dma = self.CMAC.axi_dma
            self.cmac = self.CMAC.cmac

            #self.gpio_initialized = False
            self.i2c_initialized = False
            self.display_port_initialized = False

    def set_syzygy_vio(self, voltage):
        """Set syzygy VIO setting to enable syzygy interface.
        This method will assert the sygyzy interface enable signal first;
        users should be able to see D46 LED is on.
        Then this method will set the specified VIO setting.
        Only volatile memory will be written.
        Parameters
        ----------
        voltage : float
            The desired VIO voltage level.
        """
        if voltage not in DAC101C081_REG:
            raise ValueError("Voltage value not supported.")

        with SMBus(DAC101C081_I2C_BUS) as bus:
            msg = i2c_msg.write(DAC101C081_SLAVE_ADDR, DAC101C081_REG[voltage])
            bus.i2c_rdwr(msg)

    def init_dp(self, service='pynq-x11', force=False):
        """Initialize the display port drivers.

        This should happen after a bitstream is loaded since the display port
        control pins are connected to EMIO pins coming out from PL.

        Parameters
        ----------
        service : str
            The name of the service that uses the display port.
        force : bool
            To force the corresponding service to restart or not.

        """
        if force:
            cmd = "systemctl restart {0}".format(service)
        else:
            cmd = "if systemctl list-units -a --state=active | grep {0} ; " \
                  "then systemctl restart {0} ; fi".format(service)
        ret = os.system(cmd)
        if ret:
            raise RuntimeError(
                'Restarting {} service failed.'.format(service))
        self.display_port_initialized = True

    def init_i2c(self):
        """Initialize the I2C control drivers on RFSoC4x2.
        This should happen after a bitstream is loaded since I2C reset
        is connected to PL pins. The I2C-related drivers are made loadable
        modules so they can be removed or inserted.
        """
        # may be required in syzygy - still in progress
        module_list = ['i2c_dev', 'i2c_mux_pca954x', 'i2c_mux']
        for module in module_list:
            cmd = "if lsmod | grep {0}; then rmmod {0}; fi".format(module)
            ret = os.system(cmd)
            if ret:
                raise RuntimeError(
                    'Removing kernel module {} failed.'.format(module))

        module_list.reverse()
        for module in module_list:
            cmd = "modprobe {}".format(module)
            ret = os.system(cmd)
            if ret:
                raise RuntimeError(
                    'Inserting kernel module {} failed.'.format(module))

        self.i2c_initialized = True

    def init_rf_clks(self, lmk_freq=245.76, lmx_freq=491.52):
        """Initialise the LMK and LMX clocks for the radio hierarchy.

        The radio clocks are required to talk to the RF-DCs and only need
        to be initialised once per session.

        """        
        xrfclk.set_ref_clks(lmk_freq=lmk_freq, lmx_freq=lmx_freq)
