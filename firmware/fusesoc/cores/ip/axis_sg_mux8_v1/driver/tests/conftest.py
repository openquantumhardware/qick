import sys
from pathlib import Path

# driver/tests/ -> ../../rdl/ contains axis_sg_mux8_v1_regmap_pkg/
_RDL_DIR = Path(__file__).resolve().parents[2] / "rdl"
if str(_RDL_DIR) not in sys.path:
    sys.path.insert(0, str(_RDL_DIR))
