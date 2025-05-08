import os
import subprocess
import shutil
import pytest
from pathlib import Path

exclusion = [
    "warning: [common 17-1221]",
    "warning: [vrfc 10-2821]",
    "warning: [vrfc 10-3499] library name 'dds_compiler_v6_0_21'",
    "warning: [vrfc 14-3499]", #warning de dds compiler
    "warning: [wavedata 42-558]",
    "warning: [vrfc 10-4969] module 'sip_gtye4_common'"
]
# Function to execute commands in shell
def shell_cmd(cmd, wd, timeout=None, deep_log : int = 0):
    """
    Method that executes shell commands within a path.
    If an error occurs, it is reported to the console.
    Argument:
        cmd: shell commands to execute.
        wd: path where to execute the command.
        timeout: maximum time to execute the command.
        deep_log: Maximum number of lines to save to the internal log file.
    Returns:
        NULL  
    """
    try:
        return subprocess.run(
            cmd,
            cwd=wd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            shell=True,
        )
    except subprocess.CalledProcessError as e:
        log = e.stderr.decode().splitlines()
        pytest.fail(
            "".join(
                [
                    "Process failed:\n",
                    cmd,
                    "\n\ncwd: ",
                    str(wd),
                    "\n\nstdout:\n",
                    e.output.decode(),
                    "\n\nstderr:\n",
                    "\n".join(log[-deep_log:])
                ]
            ),
            pytrace=False,
        )
    except subprocess.TimeoutExpired as e:
        log = e.stderr.decode().splitlines()
        pytest.fail(
            "".join(
                [
                    "Process failed:\n",
                    cmd,
                    "\n\ncwd: ",
                    str(wd),
                    "\n\nstdout:\n",
                    e.output.decode(),
                    "\n\nstderr:\n",
                    "\n".join(log[-deep_log:])

                ]
            ),
            pytrace=False,
        )
# Function for check errors in VIVADO
def __check_vivado_logs(log_contents):
    """
    Method that filters phrases or lines by predefined warning or error. 
    If the error or warning is found, return pytest.fail.
    Argument:
        log_contents: string list with simulation logs
    Returns:
        NULL   
    """
    messages = []
    found_errors = False
    for line in log_contents:
        lower_line = line.lower()
        if (
            (
                lower_line.startswith("error")
                and not lower_line.startswith('error: [vrfc 10-449] cannot open file "/tools/Xilinx/Vivado/2021.2/data/xsim/')
                and not lower_line.startswith("error: [labtoolstcl 44-513] hw target shutdown.")
            )
            or lower_line.startswith("critical")
            or lower_line.startswith("fatal")
            or (
                lower_line.startswith("warning")
                and (lower_line in exclusion)
            )
        ):
            found_errors = True
            messages.append(line)

    msg = "\n".join(messages)
    if found_errors:
        pytest.fail(msg, pytrace=False)

    if len(messages):
        warnings.warn(msg, VivadoWarning, stacklevel=2)

# Function to run command with fusesoc
def run_sim_and_check_errors(source, wd, target, msg_check="FAIL", timeout=None, cores_root = "./", deep_log : int = 0):
    """
    Method that runs the simulation using the fusesoc command. 
    It also checks for errors, warnings, or critical warnings and saves it to the log file. 
    If the test case fails, the method saves it to the log file.
    Argument:
        source: Core name of the module to test.
        wd: Path to save simulation result files.
        target: Target name of the simulation module.
        msg_check: Checks that the message is in the log file if a previous error has not occurred.
                   If it is not found, the error is returned.
        timeout: Maximum time to execute the command.
        cores_root: Path where the cores are located to find.
        deep_log: Maximum number of lines to save to the internal log file.
    Returns:
        NULL
    """
    xsim_dir = wd / "build" / source.replace(":","_") / f"{target}-xsim"
    xsim_dir = Path(str(xsim_dir).replace("/_","/")) 
    try:
        # run simulation
        cmd = f"""fusesoc --cores-root={cores_root} run --target={target} {source}"""
        ret = shell_cmd(cmd, wd=wd, timeout=timeout, deep_log=deep_log)
        
        # copy simulation source
        for file in os.listdir(xsim_dir):
            if file.endswith (".vcd"):
                shutil.copy(xsim_dir/file, wd)

        # read all logs
        simulate_log = xsim_dir / "xsim.log"
        log_contents = []
        simulate_contents = []
        if simulate_log.exists():
            simulate_contents = simulate_log.read_text().splitlines()
        for l in (x for x in xsim_dir.iterdir() if x.suffix == ".log"):
            log_contents.extend(l.read_text().splitlines())
        
        # check all logs
        __check_vivado_logs(log_contents)
        
        if msg_check != "":
            # check if simulation ended with a special text
            test_ok = any(l.find(msg_check) for l in simulate_contents)
            if not test_ok:
                msg = """ test failed, last 20 lines of log:\n{}""".format("\n".join(simulate_contents[-21:-1]))
                pytest.fail(reason=msg, pytrace=False)
        
    finally:
        print("")

# Function to send report file to hub folder.
def dump_file(source_path : str = "./", name_file : str = "", dest_path : str = "./"):
    """
    Method to send report file to hub folder.
    Arguments:
        source_path: an String path. Path root where search files.
        name_file: an String. Name of files to search.
        dest_path: an String path. Path where to save files.
    Returns:
        NULL
    """
    if source_path != "" and name_file != "":
        roots = subprocess.run("find ./tmp/build/ -type f -iname tests.xml",stdout=subprocess.PIPE,shell=True).stdout
        roots = ((roots.decode('utf-8')).replace(name_file,"")).split("\n")

        for root in roots:
            if root != "":
                if subprocess.run(['test', '-d', dest_path+root]).returncode == 1:
                    cmd = f"mkdir -p {dest_path}{root}"
                    shell_cmd(cmd=cmd,wd="./",timeout=None)
                
                cmd = f"cp {root}/{name_file} {dest_path}{root}"
                shell_cmd(cmd=cmd,wd="./",timeout=None)