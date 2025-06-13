# Copyright (C) 2025 FNAL
# SPDX-License-Identifier: BSD-3-Clause


import os
os.environ['BOARD'] = 'ZCU216'
import xrfclk
import rfsystem
from smbus2 import SMBus, i2c_msg
import pynq
import pynq.lib




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
            #LED R
            self.leds_r = self.leds_r.channel1
            self.leds_r.setdirection('out')
            self.leds_r.setlength(8)
            #LED G
            self.leds_g = self.leds_g.channel1
            self.leds_g.setdirection('out')
            self.leds_g.setlength(8)
            #LED B
            self.leds_b = self.leds_b.channel1
            self.leds_b.setdirection('out')
            self.leds_b.setlength(8)

            self.buttons = self.btns_gpio.channel1
            self.buttons.setdirection('in')
            self.buttons.setlength(5)
            self.switches = self.sws_gpio.channel1
            self.switches.setdirection('in')
            self.switches.setlength(8)

            self.gpio_initialized = False
            self.i2c_initialized = False
            self.display_port_initialized = False

    def init_gpio(self):
        """Initialize the GPIO control drivers.

        The GPIO pins will control the I2C-SPI converter chip read data path.

        """
        for gpio_num in [330, 331]:
            if not os.path.exists("/sys/class/gpio/gpio{}".format(gpio_num)):
                with open("/sys/class/gpio/export", 'w') as f:
                    f.write('{}'.format(gpio_num))
            with open("/sys/class/gpio/gpio{}/direction".format(
                    gpio_num), 'w') as f:
                f.write('out')
            with open("/sys/class/gpio/gpio{}/value".format(
                    gpio_num), 'w') as f:
                f.write('1')
        self.gpio_initialized = True

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
        """Initialize the I2C control drivers on ZCU216.
        This should happen after a bitstream is loaded since I2C reset
        is connected to PL pins. The I2C-related drivers are made loadable
        modules so they can be removed or inserted.
        """
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



