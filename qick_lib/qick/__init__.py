from .averager_program import AveragerProgram, RAveragerProgram
from .qick_asm import QickConfig, QickProgram
import os

__version__ = "0.2"

def bitfile_path():
    if os.environ['BOARD'] == 'ZCU216':
        src = os.path.join(os.path.dirname(qick.__file__), 'qick_216.bit')
    else:  # assume ZCU111
        src = os.path.join(os.path.dirname(qick.__file__), 'qick_111.bit')
    return src


try:
    from .qick import QickSoc
except Exception as e:
    print("Could not import QickSoc:", e)
