import os

def bitfile_path():
    if os.environ['BOARD']=='ZCU216':
        src = os.path.join(os.path.dirname(qick.__file__), 'qick_216.bit')
    else: #assume ZCU111
        src = os.path.join(os.path.dirname(qick.__file__), 'qick_111.bit')
    return src

try:
    from .qick import QickSoc
except:
    print ("Could not import QickSoc, probably due to not being able to load pynq package.")
from .qick_asm import QickConfig, QickProgram, deg2reg, reg2deg
from .averager_program import AveragerProgram, RAveragerProgram

