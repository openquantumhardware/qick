from .averager_program import AveragerProgram, RAveragerProgram, NDAveragerProgram
from .qick_asm import QickConfig, QickProgram
import os

def get_version():
    """
    qick_lib/qick/VERSION is a text file containing only the version number.
    """
    versionpath = os.path.join(os.path.dirname(__file__), 'VERSION')
    with open(versionpath) as version_file:
        version = version_file.read().strip()
        return version

__version__ = get_version()

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
