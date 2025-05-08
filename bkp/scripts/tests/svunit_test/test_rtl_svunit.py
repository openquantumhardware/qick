import pytest
import subprocess
from pathlib import Path
from models.cmd_utils import *
#from cmd_utils import *

repo_root = Path(__file__).resolve().parent.parent.parent.parent
tmp_folder = repo_root / "tmp"

if subprocess.run(['test', '-d', tmp_folder]).returncode == 1:
    cmd = f"mkdir {tmp_folder}"
    shell_cmd(cmd=cmd,wd="./",timeout=None)

file_core_name = open(tmp_folder / "cores_list.txt", 'r')

battery_tests = file_core_name.read().splitlines()

ignore_battery_tests = [
]

failing_battery_tests = [
]

@pytest.mark.svunit_test
@pytest.mark.parametrize("test_name", battery_tests)
def test_simulation(test_name):
    run_sim_and_check_errors(test_name, wd=tmp_folder, target="test", msg_check="[testrunner]: PASSED", timeout=None, cores_root = repo_root, deep_log = 20)
    dump_file(source_path="./tmp/build/", name_file="tests.xml", dest_path="./report_svunit/")

@pytest.mark.skip(reason="tests not implemented")
@pytest.mark.parametrize("test_name", ignore_battery_tests)
def test_ignore_simulation(test_name):
    run_sim_and_check_errors(test_name, wd=tmp_folder,target="sim", timeout=None)

@pytest.mark.xfail(strict=True)
@pytest.mark.parametrize("test_name", failing_battery_tests)
def test_failed_simulation(test_name):
    run_sim_and_check_errors(test_name, wd=tmp_folder,target="sim", timeout=None)
