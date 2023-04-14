from .averager_program import AveragerProgram, RAveragerProgram, NDAveragerProgram
from .qick_asm import QickConfig, QickProgram
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


# only import the hardware drivers if running on a Zynq
if platform.machine() in ['aarch64', 'armv7l']:
    try:
        from .qick import QickSoc
    except Exception as e:
        print("Could not import QickSoc:", e)
