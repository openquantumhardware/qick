import os
import platform

def get_version():
    """Read library version from qick_lib/qick/VERSION (a text file containing only the version number).

    Parameters
    ----------

    Returns
    -------
    str
        version number, in major.minor.PR format
    """
    versionpath = os.path.join(os.path.dirname(__file__), 'VERSION')
    with open(versionpath) as version_file:
        version = version_file.read().strip()
        return version

__version__ = get_version()

def bitfile_path():
    """Choose the default firmware path for this board.

    Parameters
    ----------

    Returns
    -------
    str
        absolute path to the firmware bitfile distributed with the QICK library
    """
    board2file =  {'ZCU216' :'qick_216.bit',
            'ZCU111' :'qick_111.bit',
            'RFSoC4x2' :'qick_4x2.bit'}
    filename = board2file[os.environ['BOARD']]
    src = os.path.join(os.path.dirname(qick.__file__), filename)
    return src

# tie in to rpyc, if using
try:
    from rpyc.utils.classic import obtain
except ModuleNotFoundError:
    def obtain(i):
        return i

from .averager_program import AveragerProgram, RAveragerProgram, NDAveragerProgram
from .qick_asm import QickConfig, DummyIp
from .asm_v1 import QickProgram

# only import the hardware drivers if running on a Zynq
# also import if we're in the ReadTheDocs Sphinx build (the imports won't really work but they will be mocked)
if platform.machine() in ['aarch64', 'armv7l'] or os.getenv('READTHEDOCS', default='False')=='True':
    try:
        from .ip import SocIp
        from .qick import QickSoc
    except Exception as e:
        print("Could not import QickSoc:", e)
