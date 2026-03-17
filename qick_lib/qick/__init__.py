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
            'RFSoC4x2' :'qick_4x2.bit',
            'RFSoC2x4' :'qick_2x4.bit'}
    filename = board2file[os.environ['BOARD']]
    src = os.path.join(os.path.dirname(qick.__file__), filename)
    return src

# Check for supported PYNQ versions that are compatible with QICK library
# only do the check if running on a Zynq
if platform.machine() in ['aarch64', 'armv7l']:
    import pkg_resources

    pynq_version = pkg_resources.get_distribution("pynq").version
    if pkg_resources.parse_version(pynq_version) >= pkg_resources.parse_version("3.1"):
        raise RuntimeError(
            f"Unsupported PYNQ version {pynq_version}. "
            "QICK library requires PYNQ < 3.1."
        )

# tie in to rpyc, if using
try:
    from rpyc.utils.classic import obtain
except ModuleNotFoundError:
    def obtain(i):
        return i

from .averager_program import AveragerProgram, RAveragerProgram, NDAveragerProgram
from .qick_asm import QickConfig
from .asm_v1 import QickProgram

# only import the hardware drivers if running on a Zynq
# also import if we're in the ReadTheDocs Sphinx build (the imports won't really work but they will be mocked)
if platform.machine() in ['aarch64', 'armv7l'] or os.getenv('READTHEDOCS', default='False')=='True':

    # version check
    #import pynq
    #if isinstance(pynq.__version__, str): # don't do the version check if pynq is an autodoc mock import
    #    import packaging.version
    #    PYNQ_TOONEW = '3.1'
    #    if packaging.version.parse(pynq.__version__) >= packaging.version.parse(PYNQ_TOONEW):
    #        raise RuntimeError("Unsupported PYNQ version %s, QICK requires PYNQ < %s" % (pynq.__version__, PYNQ_TOONEW))

    from .qick import QickSoc
