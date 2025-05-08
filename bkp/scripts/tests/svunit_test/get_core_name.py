import subprocess
from pathlib import Path
from models.cmd_utils import shell_cmd

repo_root = Path(__file__).resolve().parent.parent.parent.parent
tmp_folder = repo_root / "tmp"

if subprocess.run(['test', '-d', tmp_folder]).returncode == 1:
    cmd = f"mkdir {tmp_folder}"
    shell_cmd(cmd=cmd,wd="./",timeout=None)

# Function to get list with cores name
def get_core_name(keyword=""):
    """
    Method that executes shell commands to obtain a list of core names.
    Argument:
        keyword: keyword that must contain the name of the CORE.
    Returns:
        subprocess: result of executing the shell command
    """
        
    return shell_cmd(cmd=f'fusesoc --cores-root . list-cores | grep "{keyword}"',wd="./",timeout=None)

# Function which find target
def get_core_target(core_name="", target=""):
    """
    Method that obtains the targets of the selected core file.
    Argument:
        core_name: full name of the core to be searched.
        target: target that should be inside the core file.
    Returns:
        True: the target is inside the core file.
        False: the target isn't inside the core file.
    """
    core_info = shell_cmd(cmd=f'fusesoc --cores-root . core-info {core_name}',wd="./",timeout=None)
    core_info = core_info.stdout.decode()
    index_start_find = core_info.find("Targets:")
    targets = core_info[index_start_find+9:].splitlines()
    targets = [targets[i].split(" ")[0] for i in range(len(targets))]

    if target in targets:
        return True
    else:
        return False

##################################################################################################################

# Execution of the method
cores_list_plus_description = get_core_name(keyword=":rts")

# Decode subprocess
cores_list_plus_description = cores_list_plus_description.stdout.decode().splitlines()

# Splits the text and gets the cores name.
cores_name_list = [cores_list_plus_description[i].split(" ")[0] for i in range(len(cores_list_plus_description))]

# Core name selection that contains the selected target.
cores_name_list_valid = [x+"\n" for x in cores_name_list if get_core_target(x, "test")]

# Open the file to save the core names.
file_cores_list = open(tmp_folder / "cores_list.txt", "w")

# Write name of the cores files.
file_cores_list.writelines(cores_name_list_valid)

