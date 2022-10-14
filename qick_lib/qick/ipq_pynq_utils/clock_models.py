"""
Implements different clock / PLL models for easy manipulation without vendor software.
"""

import json
import re
import numpy as np
#from . import utils
import os
import fractions
from collections import defaultdict

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
        self.regdef = obj

        for field in self.regdef["fields"]:
            fieldtype = field["fieldtype"]
            if fieldtype == "constant":
                self.fields.append(ConstantField(field))
            elif fieldtype == "normal":
                newfield = Field(field)
                newfield.index = len(self.fields)
                self.fields.append(newfield)
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

class MultiRegister:
    def __init__(self, parent, name, fields):
        self.parent = parent
        self.fields = fields
        self.name = name

    @property
    def value(self):
        return self.parent.get_long_register(*self.fields)

    @value.setter
    def value(self, v):
        self.parent.set_long_register(v, *self.fields)

class RegisterDevice:
    def __init__(self, aw, dw, definition):
        # Address width and data width
        self.aw = aw
        self.dw = dw
        self.registers_by_addr = {}
        self.regname_pattern = re.compile(r"[A-Za-z0-9_]+\[(\d+):(\d+)\]")

        defpath = os.path.join(os.path.dirname(__file__), definition)
        with open(defpath) as f:
            regmap = json.load(f)

        multi_regs = {}

        for register in regmap:
            addr = register["addr"]
            reg = Register(register, dw=dw)
            self.registers_by_addr[addr] = reg

            for field in reg.fields:
                field.addr = addr
                if isinstance(field, Field) and field.valid_type != "constant":
                    sanitized_name = field.name.replace("[", "_").replace("]", "").replace(":", "_")
                    if field.name.endswith("]"): # Multi-field
                        name = field.name[:field.name.index("[")]
                        multi_regs[name] = multi_regs.get(name, []) + [field]
                    setattr(self, sanitized_name, field)

        for k,v in multi_regs.items():
            setattr(self, k, MultiRegister(self, k, v))

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

LMX2594_VCOs = [
        (1,  7500,  8600, 164, 12, 299, 240),
        (2,  8600,  9800, 165, 16, 356, 247),
        (3,  9800, 10800, 158, 19, 324, 224),
        (4, 10800, 12000, 140,  0, 383, 244),
        (5, 12000, 12900, 183, 36, 205, 146),
        (6, 12900, 13900, 155,  6, 242, 163),
        (7, 13900, 15000, 175, 19, 323, 244)
    ]

CAL_NO_ASSIST = 0
CAL_PARTIAL_ASSIST = 1
CAL_CLOSE_FREQUENCY_ASSIST = 2
CAL_FULL_ASSIST = 3

CHDIV_TABLE = [
        (2, 15000, 3750, 7500),
        (4, 15000, 1875, 3750),
        (6, 15000, 1250, 2500),
        (8, 11500, 937.5, 1437.5),
        (12, 11500, 625, 958.333),
        (16, 11500, 468.75, 718.75),
        (24, 11500, 312.5, 479.167),
        (32, 11500, 234.375, 359.375),
        (48, 11500, 156.25, 239.583),
        (64, 11500, 117.1875, 179.6875),
        (72, 11500, 104.167, 159.722),
        (96, 11500, 78.125, 119.792),
        (128, 11500, 58.594, 89.844),
        (192, 11500, 39.0625, 59.896),
        (256, 11500, 29.297, 44.922),
        (384, 11500, 19.531, 29.948),
        (512, 11500, 14.648, 22.461),
        (768, 11500, 9.766, 14.974),
        (1, 15000, 10, 15000)
        ]

class LMX2594(RegisterDevice):

    def __init__(self, f_osc):
        RegisterDevice.__init__(self, 8, 16, "lmx2594_regmap.json")

        self.f_osc = f_osc

        # Note that this isn't the complete range, but skips the readback registers
        self.register_addresses = list(range(109, -1, -1))

    def get_multiplier_freqs(self):
        """
        Enumerate all possible multiplier output frequencies.
        """
        f2conf = defaultdict(list)
        # config tuple order is mult, osc_x, r_pre - we want this to be sortable
        # we prefer smaller mult first, then smaller osc_x
        # add no-multiplier configs (there are no limits on using r_pre in this mode, but you usually don't need it)
        f2conf[self.f_osc].append((1,1,1))
        f2conf[2*self.f_osc].append((1,2,1))
        for osc_x in [1,2]:
            if osc_x==2 and self.f_osc>200: # max input freq of doubler
                continue
            for mult in range(3,8):
                # apply limits on the multiplier's input and output freqs
                min_r_pre = int(np.ceil(max(1, self.f_osc*osc_x/70.0, self.f_osc*osc_x*mult/250.0)))
                max_r_pre = int(np.floor(min(255, self.f_osc*osc_x/30.0, self.f_osc*osc_x*mult/180.0)))
                for r_pre in range(min_r_pre, max_r_pre+1):
                    mult_out = self.f_osc*(osc_x*mult/r_pre)
                    f2conf[mult_out].append((mult, osc_x, r_pre))

        f2conf = dict(sorted(f2conf.items()))
        for freq in f2conf.keys():
            f2conf[freq].sort()
            #for conf in f2conf[freq]:
            #    print(freq, conf)
            f2conf[freq] = f2conf[freq][0]
        return f2conf

    def set_output_frequency(self, f_target, pwr=31, solution=None, en_b=False, osc_2x=False, verbose=True):
        # We only support integer mode right now
        self.MASH_ORDER.value = 0
        self.MASH_RESET_N.set(self.MASH_RESET_N.RESET)
        self.PLL_NUM.value = 0
        self.PLL_DEN.value = 0

        self.OUTA_PWR.value = pwr
        self.OUTA_PD.set(self.OUTA_PD.NORMAL_OPERATION)
        if en_b:
            self.OUTB_PWR.value = pwr
            self.OUTB_PD.set(self.OUTB_PD.NORMAL_OPERATION)
        else:
            self.OUTB_PWR.value = 0
            self.OUTB_PD.set(self.OUTB_PD.POWERDOWN)

        chdivs = []
        f_vco_min = 7500

        mult = 1
        osc_x = 2 if osc_2x else 1
        for i,(div,f_vco_max,f_out_min,f_out_max) in enumerate(CHDIV_TABLE):
            if not (f_out_min <= f_target <= f_out_max):
                continue

            f_vco = f_target * div

            if not (f_vco_min <= f_vco <= f_vco_max):
                continue

            chdivs.append((i, div, f_vco))

        if len(chdivs) < 1:
            raise RuntimeError("No possible integer solutions found!")

        solutions = []
        if verbose:
            print("  i |   f_vco  | DIV | DLY_SEL |   n  | osc_2x |   R  | mult | R_pre |  f_pfd  |   f_out  | Delta f |   Metric   ")
            print("----|----------|-----|---------|------|--------|------|------|-------|---------|----------|---------|------------")

        metric_min = np.inf
        metric_min_idx = None
        for idx,(i,div,f_vco) in enumerate(chdivs):
            min_n,dly_sel = LMX2594.get_modulator_constraints(self.MASH_ORDER.value, f_vco)

            ratio = fractions.Fraction(f_vco / (self.f_osc*osc_x)).limit_denominator(255)
            n = ratio.numerator
            R = ratio.denominator

            R_pre = 1

            assert n != 0, "N can't be zero!"

            while n < min_n or self.f_osc / (R * R_pre) > 400:
                n *= 2

                if R*2 <= 255:
                    R *= 2
                elif R_pre * 2 < 128:
                    R_pre *= 2
                else:
                    raise RuntimeError("Failed to find solution, N limit can't be met!")

            f_pd = self.f_osc * osc_x / (R * R_pre)

            metric = R_pre * R * n * div
            if metric < metric_min:
                metric_min_idx = idx
                metric_min = metric

            f_out = f_vco / div
            delta_f = abs(f_out - f_target)

            metric += delta_f*1e6

            if verbose:
                print(f" {idx:>2d} | {f_vco:8.2f} | {div:3d} | {dly_sel:7d} | {n:4d} | {'  True' if osc_x==2 else ' False'} | {R:4d} | {mult:4d} | {R_pre:5d} | {f_pd:7.2f} | {f_out:8.2f} | {delta_f:7.2f} | {metric:6.4e}")

            solutions.append((i, div, f_vco, dly_sel, n, osc_x, R, mult, R_pre))

        if verbose: print()
        if solution is None:
            if verbose: print(f"Choosing solution {metric_min_idx} with minimal metric {metric_min}.")
            solution = metric_min_idx

        chdiv_i,chdiv,f_vco,dly_sel,n,osc_x,R,mult,R_pre = solutions[solution]

        self.CHDIV.value = chdiv_i % 18
        self.PFD_DLY_SEL.value = dly_sel
        self.PLL_N.value = n
        self.OSC_2X.value = osc_x - 1
        self.PLL_R_PRE.value = R_pre
        self.MULT.value = mult
        self.PLL_R.value = R

        if chdiv_i == 18:
            self.OUTA_MUX.set(self.OUTA_MUX.VCO)
            self.OUTB_MUX.set(self.OUTB_MUX.VCO)
            self.CHDIV_DIV2.set(self.CHDIV_DIV2.DISABLED)
        else:
            self.OUTA_MUX.set(self.OUTA_MUX.CHANNEL_DIVIDER)
            self.OUTB_MUX.set(self.OUTB_MUX.CHANNEL_DIVIDER)

            # Enable CHDIV_DIV2 driver for CHDIV > 2
            self.CHDIV_DIV2.set(self.CHDIV_DIV2.DISABLED if chdiv_i == 0 else self.CHDIV_DIV2.ENABLED)

        self.update()
        self.configure_calibration()

        return f_vco / chdiv

    def configure_calibration(self, assistance_level=0):
        if self.f_pd <= 100:
            if self.f_pd >= 10:
                self.FCAL_LPFD_ADJ.value = 0
            elif self.f_pd >= 5:
                self.FCAL_LPFD_ADJ.value = 1
            elif self.f_pd >= 2.5:
                self.FCAL_LPFD_ADJ.value = 2
            else:
                self.FCAL_LPFD_ADJ.value = 3

            self.FCAL_HPFD_ADJ.value = 0
        elif self.f_pd <= 150:
            self.FCAL_HPFD_ADJ.value = 1
        elif self.f_pd <= 200:
            self.FCAL_HPFD_ADJ.value = 2
        else:
            self.FCAL_HPFD_ADJ.value = 3

        # Optimize for phase noise performance (At the cost of locking time)
        self.CAL_CLK_DIV.value = 3
        self.ACAL_CMP_DLY.value = 25

        # Don't output clock signal during calibration
        self.OUT_MUTE.value = 1
        self.OUT_FORCE.value = 0

        # VCO calibration settings
        if 11900 <= self.f_vco <= 12100:
            self.VCO_SEL.value = 4
            self.QUICK_RECAL_EN.value = 0
            self.VCO_SEL_FORCE.value = 0
            self.VCO_DACISET_FORCE.value = 0
            self.VCO_CAPCTRL_FORCE.value = 0

            self.VCO_DACISET_STRT.value = 300
            self.VCO_CAPCTRL_STRT.value = 183 

        elif assistance_level == CAL_NO_ASSIST:
            self.QUICK_RECAL_EN.value = 0
            self.VCO_SEL_FORCE.value = 0
            self.VCO_DACISET_FORCE.value = 0
            self.VCO_CAPCTRL_FORCE.value = 0
            self.VCO_SEL.value = 7

        else:
            for vco_id, f_min, f_max, c_min, c_max, a_min, a_max in LMX2594_VCOs:
                if f_min <= self.f_vco <= f_max:
                    self.VCO_SEL.value = vco_id
                    self.VCO_DACISET_STRT.value = round(c_min - (c_min - c_max) * (f_vco - f_min) / (f_max - f_min))
                    self.VCO_CAPCTRL_STRT.value = round(a_min + (a_max - a_min) * (f_vco - f_min) / (f_max - f_min))
                    break

                if vco_id == 7:
                    raise RuntimeError("Failed to find acceptable VCO??")

            if assistance_level == CAL_PARTIAL_ASSIST:
                self.QUICK_RECAL_EN.value = 0
                self.VCO_SEL_FORCE.value = 0
                self.VCO_DACISET_FORCE.value = 0
                self.VCO_CAPCTRL_FORCE.value = 0

            elif assistance_level == CAL_CLOSE_FREQUENCY_ASSIST:
                self.QUICK_RECAL_EN.value = 1
                self.VCO_SEL_FORCE.value = 0
                self.VCO_DACISET_FORCE.value = 0
                self.VCO_CAPCTRL_FORCE.value = 0

            elif assistance_level == CAL_FULL_ASSIST:
                self.QUICK_RECAL_EN.value = 0
                self.VCO_SEL_FORCE.value = 1
                self.VCO_DACISET_FORCE.value = 1
                self.VCO_CAPCTRL_FORCE.value = 1

    def get_modulator_constraints(mash_order, f_vco):
        if mash_order == 0: # for now, it's always 0
            if f_vco <= 12500:
                min_n = 28
                dly_sel = 1
            else:
                min_n = 32
                dly_sel = 2
        elif mash_order == 1:
            if f_vco <= 10000:
                min_n = 28
                dly_sel = 1
            elif 10000 < f_vco < 12500:
                min_n = 32
                dly_sel = 2
            else:
                min_n = 36
                dly_sel = 3
        elif mash_order == 2:
            if f_vco <= 10000:
                min_n = 32
                dly_sel = 2
            else:
                min_n = 36
                dly_sel = 3
        elif mash_order == 3:
            if f_vco <= 10000:
                min_n = 36
                dly_sel = 3
            else:
                min_n = 40
                dly_sel = 4
        elif mash_order == 4:
            if f_vco <= 10000:
                min_n = 44
                dly_sel = 5
            else:
                min_n = 48
                dly_sel = 6
        else:
            raise RuntimeError(f"Can't handle unknown mash order: {mash_order}")

        return min_n, dly_sel

    def update(self):
        """
        Compute the output frequencies from the register values.
        """
        if self.OSC_2X.get() == self.OSC_2X.ENABLED:
            f_in = 2 * self.f_osc
        else:
            f_in = self.f_osc

        f_in /= self.PLL_R_PRE.value
        f_in *= self.MULT.value
        f_in /= self.PLL_R.value

        self.f_pd = f_in

        num = self.PLL_NUM.value
        den = self.PLL_DEN.value
        pll_n = self.PLL_N.value

        if den != 0 and num != 0:
            self.f_vco = self.f_pd * (pll_n + num/den)
        else:
            self.f_vco = self.f_pd * pll_n

        if not (7500 <= self.f_vco <= 15000):
            raise RuntimeError(f"VCO frequency f_vco = {round(self.f_vco, ndigits=2)} out of range: 7500 MHz <= f_vco <= 15000")

        self.f_chdiv = self.f_vco / CHDIV_TABLE[self.CHDIV.value][0]

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

            divider = self.CLKin0_R.value

        elif sel_mode == self.CLKin_SEL_MODE.CLK_IN_1_MANUAL:
            assert self.CLKin1_OUT_MUX.get() == self.CLKin1_OUT_MUX.PLL1
            pll1_src_freq = self.clkin1_freq

            divider = self.CLKin1_R.value

        elif sel_mode == self.CLKin_SEL_MODE.CLK_IN_2_MANUAL:
            assert self.CLKin2_OUT_MUX.get() == self.CLKin2_OUT_MUX.PLL1
            pll1_src_freq = self.clkin2_freq

            divider = self.CLKin2_R.value
        else:
            raise RuntimeError("sel_mode == " + str(sel_mode) + ", which is not supported!")

        dbg("Input divider:", divider)

        assert self.PLL1_NCLK_MUX.get() == self.PLL1_NCLK_MUX.OSC_IN, "Only configurations using the external VCXO are supported!"

        self.pll1_phase_detector_freq = pll1_src_freq / divider
        dbg("PLL1 Phase Detector Frequency:", self.pll1_phase_detector_freq)

        self.pll1_n_divider = self.PLL1_N.value
        dbg("PLL1N Divider:", self.pll1_n_divider)
        dbg("Expected VCXO Frequency:", self.pll1_n_divider * self.pll1_phase_detector_freq)

        assert self.vcxo_freq == self.pll1_n_divider * self.pll1_phase_detector_freq

        self.pll2_r_divider = self.PLL2_R.value
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

        pll2_n = self.PLL2_N.value
        dbg("PLL2_N:", pll2_n)

        self.pll2_output_freq = pll2_input_freq * pll2_n * pll2_p
        dbg("PLL2 Output Frequency:", round(self.pll2_output_freq, ndigits=2))

        self.sysref_divider = self.SYSREF_DIV.value
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

        self.PLL2_R.value = R
        self.PLL2_N.value = N // P
        self.PLL2_P.value = P & 0x7 # 8 is represented as 0

        self.update()

        return R, N // P, P

    def set_sysref(self, value):
        _div = self.pll2_output_freq / value
        div = min(8191, max(8, int(round(_div))))

        f_new = self.pll2_output_freq / div

        if abs(div - _div) / div > 0.01:
            print(f"WARNING: SYSREF_CLK target could not be hit accurately! Requested frequency {value} MHz requires divider {_div:.4f} which is not realizable. The closest integer divider {div} results in a frequency of {f_new} MHz!")

        self.SYSREF_DIV.value = div
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
        # 10 MHz reference clock, 10 MHz clock input on external SMA, 160 MHz VCO frequency
        self.lmk = LMK04828B(10, 10, 10, 160)
        self.lmx_adc = LMX2594(245.76)
        self.lmx_dac = LMX2594(245.76)

        if src is None:
            with files("ipq_pynq_utils").joinpath("data/lmk04828b_regdump_defaults.txt").open() as f:
                self.lmk.init_from_file(f)
        else:
            self.lmk.init_from_file(src)

        with files("ipq_pynq_utils").joinpath("data/clockFiles/LMX2594_REF-245M76__OUT-9830M40_10172019_I.txt").open() as f:
            self.lmx_adc.init_from_file(f)

        with files("ipq_pynq_utils").joinpath("data/clockFiles/LMX2594_REF-245M76__OUT-9830M40_10172019_I.txt").open() as f:
            self.lmx_dac.init_from_file(f)

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
        return {
                "LMK": self.lmk.get_register_dump()
                }
