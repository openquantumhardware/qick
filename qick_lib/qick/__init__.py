from .averager_program import AveragerProgram, RAveragerProgram
from .qick_asm import QickConfig, QickProgram
import os

__version__ = "0.2"

def bitfile_path():
    board2file =  {'ZCU216' :'qick_216.bit',
            'ZCU111' :'qick_111.bit',
            'RFSoC4x2' :'qick_4x2.bit'}
    filename = board2file[os.environ['BOARD']]
    src = os.path.join(os.path.dirname(qick.__file__), filename)
    return src


try:
    from .qick import QickSoc
except Exception as e:
    print("Could not import QickSoc:", e)
