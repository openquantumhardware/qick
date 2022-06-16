"""
Implements different clock / PLL models for easy manipulation without vendor software.
"""

import json
import re
import numpy as np
from . import utils

# Import compat-lib for python versions older than 3.10
if utils.python_version_lt("3.10.0"):
    from importlib_resources import files
else:
    from importlib.resources import files

class EnumVal:
    def __init__(self, name, value, description):
        self.name = name
        self.value = value
        self.description = description
        self.__doc__ = self.description

    @property
    def __pydoc__(self):
        return self.description

    def get(self):
        return self.value

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

class ConstantField:
    def __init__(self, field):
        self.end = field["end"]
        self.start = field["start"]
        self.value = field["value"]
        self.name = "CONST"
        self.description = ""

        self.width = self.end - self.start + 1
        self.mask = ((1 << self.width) - 1) << self.start

    def get(self):
        return self.value

    def get_raw(self):
        return self.mask & (self.value << self.start)

    def parse(self, obj):
        pass

    @property
    def value_description(self):
        return ""

    def __str__(self):
        return str(self.value)

    def __repr__(self):
        return str(self.value)

class Field:
    def __init__(self, field):
        self.end = field["end"]
        self.start = field["start"]
        self.width = self.end - self.start + 1
        self.mask = ((1 << self.width) - 1) << self.start

        self.name = field["name"]
        self.description = field["description"]
        self.__doc__ = self.description
        self.default = field["default"] if "default" in field else 0
        self.value = self.default

        self.enum_map = {}

        valid = field["valid"]
        self.valid_type = valid["type"]

        if self.valid_type == "int":
            pass # ??
        elif self.valid_type == "constant":
            self.default = valid["value"]
            self.value = valid["value"]
        elif self.valid_type == "enum":
            for value in valid["values"]:
                enum_val = EnumVal(**value)
                assert getattr(self, value["name"], None) is None, f"Duplicate enum value in field {self.name}: {value['name']}"
                setattr(self, value["name"], enum_val)
                self.enum_map[enum_val.value] = enum_val
        else:
            raise RuntimeError("Unknown valid type: " + self.valid_type)

    def get(self):
        if self.valid_type == "enum":
            if self.value in self.enum_map:
                return self.enum_map[self.value]
            else:
                return "BAD ENUM VALUE"
        return self.value

    def set(self, value):
        if self.value_type == "enum":
            if not isinstance(value, EnumVal):
                raise RuntimeError("Expected enum value!")
            else:
                self.value = value.value
        else:
            self.value = value

    def get_raw(self):
        return self.mask & (self.value << self.start)

    def parse(self, data):
        self.value = (data & self.mask) >> self.start

    def set(self, val):
        if isinstance(val, int):
            self.value = val
        elif isinstance(val, EnumVal):
            self.value = val.value
        else:
            raise RuntimeError("Unsupported type!")

    def reset(self):
        self.value = self.default

    @property
    def value_description(self):
        if self.valid_type == "enum":
            if self.value in self.enum_map:
                return self.enum_map[self.value].description
            else:
                return "BAD ENUM VALUE"
        return ""

    def __str__(self):
        return str(self.__dict__)

    def __repr__(self):
        return str(self.__dict__)

class Register:
    def __init__(self, obj, dw=8):
        self.addr = obj["addr"]
        self.fields = []
        self.dw = dw 

        for field in obj["fields"]:
            fieldtype = field["fieldtype"]
            if fieldtype == "constant":
                self.fields.append(ConstantField(field))
            elif fieldtype == "normal":
                self.fields.append(Field(field))
            else:
                raise RuntimeError("Unsupported field type!")

    def reset(self):
        for field in self.fields:
            field.reset()

    def parse(self, val):
        for field in self.fields:
            field.parse(val)

    def __str__(self):
        return str({"addr": self.addr, "fields": self.fields})

    def __repr__(self):
        return str({"addr": self.addr, "fields": self.fields})

    def get_raw(self):
        ret = self.addr << self.dw

        for field in self.fields:
            ret |= field.get_raw()

        return ret

class LMK04828BOutputBranch:
    def __init__(self, parent, i):
        self.parent = parent
        self.i = i

        def ga(n):
            return getattr(self.parent, n)

        self.DIV = ga(f"DCLKout{self.i}_DIV")
        self.CLK_PD = ga(f"CLKout{self.i}_{self.i+1}_PD")
        self.SDCLK_PD = ga(f"SDCLKout{self.i+1}_PD")
        self.DCLK_FMT = ga(f"DCLKout{self.i}_FMT")
        self.SDCLK_FMT = ga(f"SDCLKout{self.i+1}_FMT")
        self.DCLK_POL = ga(f"DCLKout{self.i}_POL")
        self.SDCLK_POL = ga(f"SDCLKout{self.i+1}_POL")

        self.DCLK_MUX = ga(f"DCLKout{self.i}_MUX")
        self.SDCLK_MUX = ga(f"SDCLKout{self.i+1}_MUX")

    def _set_output_status(self, dclk_enable, sdclk_enable):
        if not dclk_enable and not sdclk_enable:
            self.CLK_PD.set(self.CLK_PD.POWERDOWN)
        elif dclk_enable and not sdclk_enable:
            self.CLK_PD.set(self.CLK_PD.ENABLED)
            self.DCLK_FMT.set(self.DCLK_FMT.LVDS)
            self.SDCLK_PD.set(self.SDCLK_PD.POWERDOWN)
        elif not dclk_enable and sdclk_enable:
            self.CLK_PD.set(self.CLK_PD.ENABLED)
            self.DCLK_FMT.set(self.DCLK_FMT.POWERDOWN)
            self.SDCLK_FMT.set(self.SDCLK_FMT.LVDS)
            self.SDCLK_PD.set(self.SDCLK_PD.ENABLED)
        elif dclk_enable and sdclk_enable:
            self.CLK_PD.set(self.CLK_PD.ENABLED)
            self.DCLK_FMT.set(self.DCLK_FMT.LVDS)
            self.SDCLK_FMT.set(self.SDCLK_FMT.LVDS)
            self.SDCLK_PD.set(self.SDCLK_PD.ENABLED)
        else:
            raise RuntimeError("?!")

    @property
    def dclk_active(self):
        return not (self.dclk_fmt == self.DCLK_FMT.POWERDOWN or self.clk_pd == self.CLK_PD.POWERDOWN)

    @dclk_active.setter
    def dclk_active(self, value: bool):
        if self.dclk_active == value:
            return

        self._set_output_status(value, self.sdclk_active)
        self.parent.update()

    @property
    def sdclk_active(self):
        return not (self.sdclk_pd == self.SDCLK_PD.POWERDOWN or self.sdclk_fmt == self.SDCLK_FMT.POWERDOWN or self.clk_pd == self.CLK_PD.POWERDOWN)

    @sdclk_active.setter
    def sdclk_active(self, value: bool):
        if self.sdclk_active == value:
            return

        self._set_output_status(self.dclk_active, value)
        self.parent.update()

    def get_sdclk_freqs(self):
        return self.parent.pll2_output_freq / (np.arange(32)+1)

    def request_freq(self, value, ignore_warning=False):
        _div = self.parent.pll2_output_freq / value
        div = max(1, min(32, round(_div)))

        f_real = self.parent.pll2_output_freq / div

        if abs(div - _div) > 0.01 and not ignore_warning:
            print(f"WARNING: Failed to hit requested frequency of {value:.2f} MHz. Using divider {div} where {_div:.3f} would have been required, thus resulting in output frequency {f_real:.2f} MHz or a frequency error of {f_real - value:.2f} MHz!")

        self.DIV.value = 0x1f & div # 32 maps to 0
        self.update()

        return self.parent.pll2_output_freq / div

    def update(self, printDebug=False):
        def dbg(*s):
            if printDebug:
                print(f"Output Branch {self.i:2d}", *s)

        self.div = self.DIV.get()
        if self.div == 0: # 0 means 32
            self.div = 32

        dbg(f"DIV: {self.div}")

        self.clk_pd = self.CLK_PD.get()
        dbg("CLK_PD:", self.clk_pd)

        self.sdclk_pd = self.SDCLK_PD.get()
        dbg("SDCLK_PD:", self.sdclk_pd)

        self.dclk_fmt = self.DCLK_FMT.get()
        dbg("DCLK_FMT:", self.dclk_fmt)

        self.sdclk_fmt = self.SDCLK_FMT.get()
        dbg("SDCLK_FMT:", self.sdclk_fmt)

        self.dclk_pol = self.DCLK_POL.get()
        dbg("DCLK_POL:", self.dclk_pol)

        self.sdclk_pol = self.SDCLK_POL.get()
        dbg("SDCLK_POL:", self.sdclk_pol)

        self.sdclk_mux = self.SDCLK_MUX.get()
        dbg("SDCLK_MUX:", self.sdclk_mux)

        self.dclk_mux = self.DCLK_MUX.get()
        dbg("DCLK_MUX:", self.dclk_mux)

        pll_freq = self.parent.pll2_output_freq
        sysref_freq = self.parent.sysref_freq

        if self.dclk_mux == self.DCLK_MUX.BYPASS:
            self.dclk_freq = pll_freq
        else:
            self.dclk_freq = pll_freq / self.div

        if self.sdclk_mux == self.SDCLK_MUX.DEVICE_CLOCK_OUTPUT:
            self.sdclk_freq = self.dclk_freq
        else:
            self.sdclk_freq = sysref_freq

        dbg("DCLK_FREQ:", round(self.dclk_freq, ndigits=2))
        dbg("SDCLK_FREQ:", round(self.sdclk_freq, ndigits=2))

        dbg("DCLK_ACTIVE:", self.dclk_active)
        dbg("SDCLK_ACTIVE:", self.sdclk_active)

class RegisterDevice:
    def __init__(self, aw, dw, definition):
        # Address width and data width
        self.aw = aw
        self.dw = dw
        self.registers_by_addr = {}
        self.regname_pattern = re.compile(r"[A-Za-z0-9_]+\[(\d+):(\d+)\]")

        with files("ipq_pynq_utils").joinpath(definition).open() as f:
            regmap = json.load(f)

        for register in regmap:
            addr = register["addr"]
            reg = Register(register)
            self.registers_by_addr[addr] = reg

            for field in reg.fields:
                if isinstance(field, Field) and field.valid_type != "constant":
                    sanitized_name = field.name.replace("[", "_").replace("]", "").replace(":", "_")
                    setattr(self, sanitized_name, field)

    def init_from_file(self, file):
        if hasattr(file, "read"):
            lines = file.read().strip().split("\n")
        else:
            with open(file, "r") as f:
                lines = f.read().strip().split("\n")

        for line in lines:
            a,b = line.split("\t")
            rawdata = int(b, 16)

            addr_mask = (1 << self.aw) - 1
            addr = addr_mask & (rawdata >> self.dw)
            data_mask = (1 << self.dw) - 1
            data = rawdata & data_mask

            if not addr in self.registers_by_addr:
                print(f"Unhandled register: {hex(addr)}, skipping ...")
                print()
                continue

            self.registers_by_addr[addr].parse(data)

        self.update()

    def get_long_register(self, *args):
        ret = 0
        for field in args:
            match = self.regname_pattern.match(field.name)
            if match is None:
                raise RuntimeError("Cannot read non-long field: " + field.name)

            end = int(match.group(1))
            start = int(match.group(2))
            width = end-start+1
            mask = ((1 << width)-1)

            val = (field.value & mask)
            ret |= val << start

        return ret

    def set_long_register(self, value, *args):
        for field in args:
            match = self.regname_pattern.match(field.name)
            if match is None:
                raise RuntimeError("Cannot read non-long field: " + field.name)

            end = int(match.group(1))
            start = int(match.group(2))
            width = end-start+1
            mask = ((1 << width)-1)
            value_mask = mask << start

            field.value = (value & value_mask) >> start

    def get_register_dump(self, with_addr=False):
        ret = []
        for addr in self.register_addresses:
            if not with_addr:
                ret.append(self.registers_by_addr[addr].get_raw())
            else:
                ret.append((addr, self.registers_by_addr[addr].get_raw()))

        return ret

    def print(self):
        for addr in self.register_addresses:
            register = self.registers_by_addr[addr]

            for field in register.fields:
                val = field.get()
                if field.name == "CONST":
                    continue

                print(f"    {field.name}")
                print(f"        Description: {field.description}")
                print(f"        Value:       {val}")
                if field.valid_type == "enum":
                    print(f"        ValDesc:     {field.value_description}")
                print()


class LMX2594(RegisterDevice):
    def __init__(self, f_osc):
        RegisterDevice.__init__(self, 8, 16, "data/lmx2594_regmap.json")

        self.f_osc = f_osc

        # Note that this isn't the complete range, but skips the readback registers which are read-only
        self.register_addresses = list(range(109, -1, -1))

    def update(self):
        if self.OSC_2X.get() == self.OSC_2X.DISABLED:
            f_in = self.f_osc
        else:
            f_in = 2 * self.f_osc

        f_in /= self.PLL_R_PRE.value
        f_in *= self.MULT.value
        f_in /= self.PLL_R.value

        self.f_pd = f_in

        num = self.get_long_register(self.PLL_NUM_31_16, self.PLL_NUM_15_0)
        den = self.get_long_register(self.PLL_DEN_31_16, self.PLL_DEN_15_0)
        pll_n = self.get_long_register(self.PLL_N_18_16, self.PLL_N_15_0)

        self.f_vco = self.f_pd * (pll_n + num/den)

        chdiv_lut = [2, 4, 6, 8, 12, 16, 24, 32, 48, 64, 72, 96, 128, 192, 256, 384, 512, 768]
        self.f_chdiv = self.f_vco / chdiv_lut[self.CHDIV.value]

        if self.OUTA_MUX.get() == self.OUTA_MUX.CHANNEL_DIVIDER:
            self.f_outa = self.f_chdiv
        else:
            self.f_outa = self.f_vco

        sysref_divider_lut = { self.SYSREF_DIV_PRE.DIVIDE_BY_1: 1,
                               self.SYSREF_DIV_PRE.DIVIDE_BY_2: 2,
                               self.SYSREF_DIV_PRE.DIVIDE_BY_4: 4 }
        
        if self.SYSREF_EN.get() == self.SYSREF_EN.ENABLED:
            sysref_div = self.SYSREF_DIV.get()
            sysref_div *= sysref_divider_lut[self.SYSREF_DIV_PRE.get()]
            self.f_sysref = self.f_vco / sysref_div

        outb_mux = self.OUTB_MUX.get()
        if outb_mux == self.OUTB_MUX.CHANNEL_DIVIDER:
            self.f_outb = self.f_chdiv
        elif outb_mux == self.OUTB_MUX.VCO or outb_mux == self.OUTB_MUX.HIGH_IMPEDANCE:
            self.f_outb = self.f_vco
        elif outb_mux == self.SYSREF:
            self.f_outb = self.f_sysref

class LMK04828B(RegisterDevice):
    def __init__(self, clkin0_freq, clkin1_freq, clkin2_freq, vcxo_freq):
        RegisterDevice.__init__(self, 13, 8, "data/lmk04828b_regmap.json")

        self.clkin0_freq = clkin0_freq
        self.clkin1_freq = clkin1_freq
        self.clkin2_freq = clkin2_freq
        self.vcxo_freq = vcxo_freq

        # Dictionaries are unordered, and because the order of operations is important when writing
        # these registers, the correct order of indices is written down in this array:
        self.register_addresses = [0, 2, 3, 4, 5, 6, 12, 13, 256, 257, 258, 259, 260, 261, 262,
                                   263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275,
                                   276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288,
                                   289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301,
                                   302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314,
                                   315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327,
                                   328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340,
                                   341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353,
                                   354, 355, 356, 357, 369, 370, 380, 381, 358, 359, 360, 361, 362,
                                   363, 364, 365, 366, 371, 386, 387, 388, 389, 392, 393, 394, 395,
                                   8189, 8190, 8191]

        self.clock_branches = [LMK04828BOutputBranch(self, 2*i) for i in range(7)]

    def write_register_dump(self, name):
        with open(name, "w") as f:
            f.write(f"R0 (INIT)\t0x000090\n")

            for addr,val in self.get_register_dump(with_addr=True):
                f.write(f"R{addr}\t0x{val:06X}\n")

    def update(self, printDebug=False):
        def dbg(*s):
            if printDebug:
                print(*s)

        sel_mode = self.CLKin_SEL_MODE.get()

        dbg("SEL_MODE:", self.CLKin_SEL_MODE.get())

        if sel_mode == self.CLKin_SEL_MODE.CLK_IN_0_MANUAL:
            assert self.CLKin0_OUT_MUX.get() == self.CLKin0_OUT_MUX.PLL1
            pll1_src_freq = self.clkin0_freq

            divider = self.get_long_register(self.CLKin0_R_13_8, self.CLKin0_R_7_0)

        elif sel_mode == self.CLKin_SEL_MODE.CLK_IN_1_MANUAL:
            assert self.CLKin1_OUT_MUX.get() == self.CLKin1_OUT_MUX.PLL1
            pll1_src_freq = self.clkin1_freq

            divider = self.get_long_register(self.CLKin1_R_13_8, self.CLKin1_R_7_0)

        elif sel_mode == self.CLKin_SEL_MODE.CLK_IN_2_MANUAL:
            assert self.CLKin2_OUT_MUX.get() == self.CLKin2_OUT_MUX.PLL1
            pll1_src_freq = self.clkin2_freq

            divider = self.get_long_register(self.CLKin2_R_13_8, self.CLKin2_R_7_0)
        else:
            raise RuntimeError("sel_mode == " + str(sel_mode) + ", which is not supported!")

        dbg("Input divider:", divider)

        assert self.PLL1_NCLK_MUX.get() == self.PLL1_NCLK_MUX.OSC_IN, "Only configurations using the external VCXO are supported!"

        self.pll1_phase_detector_freq = pll1_src_freq / divider
        dbg("PLL1 Phase Detector Frequency:", self.pll1_phase_detector_freq)

        self.pll1_n_divider = self.get_long_register(self.PLL1_N_13_8, self.PLL1_N_7_0)
        dbg("PLL1N Divider:", self.pll1_n_divider)
        dbg("Expected VCXO Frequency:", self.pll1_n_divider * self.pll1_phase_detector_freq)

        assert self.vcxo_freq == self.pll1_n_divider * self.pll1_phase_detector_freq

        self.pll2_r_divider = self.get_long_register(self.PLL2_R_11_8, self.PLL2_R_7_0)
        pll2_input_freq = self.vcxo_freq / self.pll2_r_divider * (2 if self.PLL2_REF_2X_EN.get() == self.PLL2_REF_2X_EN.ENABLED else 1)
        dbg("PLL2 Input Frequency:", pll2_input_freq)

        assert self.PLL2_NCLK_MUX.get() == self.PLL2_NCLK_MUX.PLL_PRESCALER, "Only configurations using PLL2 feedback from prescaler are supported!"

        pll2_p_raw = self.PLL2_P.get()
        if pll2_p_raw == self.PLL2_P.DIVIDE_2 or pll2_p_raw == self.PLL2_P.DIVIDE_2_2:
            pll2_p = 2
        elif pll2_p_raw == self.PLL2_P.DIVIDE_8:
            pll2_p = 8
        else:
            pll2_p = self.PLL2_P.value

        dbg("PLL2_P:", pll2_p)

        pll2_n = self.get_long_register(self.PLL2_N_17_16, self.PLL2_N_15_8, self.PLL2_N_7_0)
        dbg("PLL2_N:", pll2_n)

        self.pll2_output_freq = pll2_input_freq * pll2_n * pll2_p
        dbg("PLL2 Output Frequency:", round(self.pll2_output_freq, ndigits=2))

        self.sysref_divider = self.get_long_register(self.SYSREF_DIV_12_8, self.SYSREF_DIV_7_0)
        dbg("SYSREF DIVIDER:", self.sysref_divider)

        self.sysref_freq = self.pll2_output_freq / self.sysref_divider
        dbg("SYSREF FREQ:", round(self.sysref_freq, ndigits=5))

        for branch in self.clock_branches:
            branch.update(printDebug)

    def set_refclk(self, refclk, precision=1):
        f_i = int(self.vcxo_freq * 10**precision)

        if 2370 < refclk < 2630:
            vco = 0 # VCO0
        elif 2920 < refclk < 3080:
            vco = 1 # VCO1
        else:
            raise RuntimeError("Requested VCO frequency is not compatible with either VCO")

        refclk = int(refclk * 10**precision)

        div = np.gcd(f_i, refclk)

        R = f_i // div
        N = refclk // div

        if self.vcxo_freq // R > 150:
            print("Phase detector frequency too high, introducing factor")
            fac = np.ceil((self.vcxo_freq // R) / 150)
            R *= fac
            N *= fac

        success = False
        for P in range(2, 9): # Absorb part of N into the prescaler
            if N % P == 0:
                success = True
                break

        if not success:
            raise RuntimeError("Failed to find suitable solution!")

        self.VCO_MUX.value = self.VCO_MUX.VCO_1.value if vco == 1 else self.VCO_MUX.VCO_0.value

        self.set_long_register(R, self.PLL2_R_11_8, self.PLL2_R_7_0)
        self.set_long_register(N // P, self.PLL2_N_17_16, self.PLL2_N_15_8, self.PLL2_N_7_0)
        self.PLL2_P.value = P & 0x7 # 8 is represented as 0

        self.update()

        return R, N // P, P

    def set_sysref(self, value):
        _div = self.pll2_output_freq / value
        div = min(8191, max(8, int(round(_div))))

        f_new = self.pll2_output_freq / div

        if abs(div - _div) / div > 0.01:
            print(f"WARNING: SYSREF_CLK target could not be hit accurately! Requested frequency {value} MHz requires divider {_div:.4f} which is not realizable. The closest integer divider {div} results in a frequency of {f_new} MHz!")

        self.set_long_register(div, self.SYSREF_DIV_12_8, self.SYSREF_DIV_7_0)
        self.update()

class CLK104Output:
    def __init__(self, branch):
        self.branch = branch

    @property
    def freq(self):
        return self.branch.dclk_freq

    @freq.setter
    def freq(self, value):
        return self.branch.request_freq(value)

    @property
    def sysref_freq(self):
        return self.branch.sdclk_freq

    @property
    def enable(self):
        return self.branch.dclk_active

    @property
    def sysref_enable(self):
        return self.branch.sdclk_active

    @enable.setter
    def enable(self, value):
        self.branch.dclk_active = value

    @sysref_enable.setter
    def sysref_enable(self, value):
        self.branch.sdclk_active = value

class CLK104:
    def __init__(self, src=None):
        # 10 MHz reference clock, 156.25 MHz clock input on external SMA, 160 MHz VCO frequency
        self.lmk = LMK04828B(10, 10, 156.25, 160)

        if src is None:
            with files("ipq_pynq_utils").joinpath("data/lmk04828b_regdump_defaults.txt").open() as f:
                self.lmk.init_from_file(f)
        else:
            self.lmk.init_from_file(src)

        self.RF_PLL_ADC_REF = CLK104Output(self.lmk.clock_branches[0])
        self.AMS_SYSREF = CLK104Output(self.lmk.clock_branches[1])
        self.RF_PLL_DAC_REF = CLK104Output(self.lmk.clock_branches[2])
        self.DAC_REFCLK = CLK104Output(self.lmk.clock_branches[3])
        self.PL_CLK = CLK104Output(self.lmk.clock_branches[4])
        self.EXT_REF_OUT = CLK104Output(self.lmk.clock_branches[5])
        self.ADC_REFCLK = CLK104Output(self.lmk.clock_branches[6])

    @property
    def PLL2_FREQ(self):
        return self.lmk.pll2_output_freq

    @PLL2_FREQ.setter
    def PLL2_FREQ(self, value):
        self.lmk.set_refclk(value)

    @property
    def SYSREF_FREQ(self):
        return self.lmk.sysref_freq

    @SYSREF_FREQ.setter
    def SYSREF_FREQ(self, value):
        self.lmk.set_sysref(value)

    def get_register_dump(self):
        return self.lmk.get_register_dump()
