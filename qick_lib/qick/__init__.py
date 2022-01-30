import os
import qick

def bitfile_path():
    src = os.path.join(os.path.dirname(qick.__file__), 'qick.bit')
    return src

try:
    from .qick import QickSoc
except:
    print ("Could not import QickSoc, probably due to not being able to load pynq package.")
from .qick_asm import QickProgram,freq2reg,freq2reg_adc,reg2freq,reg2freq_adc, adcfreq, cycles2us, us2cycles, deg2reg, reg2deg
from .averager_program import AveragerProgram, RAveragerProgram

