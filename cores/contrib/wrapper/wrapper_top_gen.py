import shutil
import sys
import os
import os.path as path
import glob
import subprocess
from jinja2 import Environment, FileSystemLoader

#check if environment vars are setted
sys.path.append('../common')
import common_functions

env_vars = ["STRATUM_COMMON"]

if not common_functions.check_env_vars(env_vars):
    print("Environment must be configured in order to run this script.. Exiting..")
    exit()

AXI4_LITE_INTF_PATH         = os.getenv('STRATUM_COMMON')+"/interfaces/axi4_lite/src/axi4lite_intf.sv"
AXI4_STREAM_INTF_PATH       = os.getenv('STRATUM_COMMON')+"/interfaces/axi4_stream/src/axi4_stream_if.sv"
DATA_STREAM_INTF_PATH       = os.getenv('STRATUM_COMMON')+"/interfaces/data_stream/src/data_stream_if.sv"
CONFIG_STREAM_INTF_PATH     = os.getenv('STRATUM_COMMON')+"/interfaces/config_stream/src/config_stream_if.sv"

import verible_verilog_syntax
import anytree

def process_data_parsed(path: str, module_data: verible_verilog_syntax.SyntaxData):

    if not module_data.tree:
        print("Could not find data tree in parsed file..")
        print("Exiting..")
        return

    # Collect information about each module declaration in the file
    for module in module_data.tree.iter_find_all({"tag": "kModuleDeclaration"}):
        module_info = {
            "name"                  : "",
            "port_name"             : [],
            "port_type"             : [],
            "port_direction"        : [],
            "interface_name"        : [],
            "interface_type"        : [],
            "interface_modport"     : [],
            "parameter_name"        : [],
            "parameter_value"       : [],
            "imports"               : []
        }

        # Find module header
        header = module.find({"tag": "kModuleHeader"})
        if not header:
            continue

        # Find module name
        name = header.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]},
                            iter_=anytree.PreOrderIter)
        if not name:
            continue
        module_info["name"] = name.text

        # Get the list of ports
        ports_tmp = []
        ports_type_tmp = []
        for port in header.iter_find_all({"tag": ["kPortDeclaration", "kPort"]}):
            port_id = port.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]})
            ports_tmp.append(port_id.text)
            # Get the type of the ports
            port_type = port.find({"tag": ["kDataType", "kDataTypePrimitive"]})
            ports_type_tmp.append(port_type.text)

        # Get the port name, type and direction
        for index, port in enumerate(ports_tmp):
            if ports_type_tmp[index].find("logic") > -1:
                module_info["port_name"].append(ports_tmp[index])
                module_info["port_type"].append(ports_type_tmp[index])

        # Get the direction of the ports
        port_direction = ""
        for port in module_info["port_name"]:
            if(port.find("i_")) > -1:
                port_direction = "input"
            elif(port.find("o_")) > -1:
                port_direction = "output"
            module_info["port_direction"].append(port_direction)

        # Filtrate interfaces on port list and create an interface list
        for index, port in enumerate(ports_type_tmp):
            if port.find("axi4_stream_if") > -1 or port.find("axi4lite_intf") > -1 or port.find("data_stream_if") > -1 or port.find("config_stream_if") > -1:
                intf_split = ports_type_tmp[index].split(".")
                module_info["interface_name"].append(ports_tmp[index])
                module_info["interface_type"].append(intf_split[0])
                module_info["interface_modport"].append(intf_split[1])

        # Get the list of parameters
        for param in header.iter_find_all({"tag": ["kParamDeclaration"]}):
            param_id = param.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]})
            module_info["parameter_name"].append(param_id.text)
            param_value = param.find({"tag": ["kNumber", "TK_DecNumber"]})
            module_info["parameter_value"].append(param_value.text)

    return module_info

def process_interface_parsed(module_info: dict, axi4_stream_if_data: verible_verilog_syntax.SyntaxData, axi4lite_intf_data: verible_verilog_syntax.SyntaxData, data_stream_if_data: verible_verilog_syntax.SyntaxData, config_stream_if_data: verible_verilog_syntax.SyntaxData):
    #Array of dicts. Each entry of the array contains the information of the interfaces used in a module
    axi4_stream_interface_info_tmp = {}
    axi4lite_interface_info_tmp = {}
    data_stream_interface_info_tmp = {}
    config_stream_interface_info_tmp = {}

    interfaces_info = { "interface_name"                    : [],
                        "interface_instance_name"           : [],
                        "interface_type"                    : [],
                        "interface_ports"                   : [],
                        "interface_instance_parameter_name" : [],
                        "interface_parameter_name"          : [],
                        "interface_parameter_value"         : [],
                        "interface_localparam_name"         : [],
                        "interface_localparam_value"        : [],
                        "interface_data_logic_list"         : [],
                        "interface_data_logic_pack_dim"     : [],
                        "interface_data_logic_unpack_dim"   : [],
                        "interface_modport"                 : [],
                        "interface_modport_ports"           : [],
                        "interface_modport_ports_dir"       : []
                    }

    #If aren't null, process interface files
    #This creates a dictionary that cointains information of a single interface
    if axi4_stream_if_data is not None:
        axi4_stream_interface_info_tmp = get_interface_data(axi4_stream_if_data)

    if axi4lite_intf_data is not None:
        axi4lite_interface_info_tmp = get_interface_data(axi4lite_intf_data)

    if data_stream_if_data is not None:
        data_stream_interface_info_tmp = get_interface_data(data_stream_if_data)

    if config_stream_if_data is not None:
        config_stream_interface_info_tmp = get_interface_data(config_stream_if_data)

    #Iterate over all interfaces of a module and remove them to extend the interface_info dict generated previously
    for module_index, module_interface in enumerate(module_info["interface_type"]):
        #save tmp info to extend it
        interfaces_info["interface_name"].append(module_info["interface_name"][module_index])
        interfaces_info["interface_instance_name"].append("u_"+module_info["name"]+"_"+interfaces_info["interface_name"][module_index])
        interfaces_info["interface_type"].append(module_info["interface_type"][module_index])
        interfaces_info["interface_modport"].append(module_info["interface_modport"][module_index])

        if module_interface == "axi4_stream_if":
            interfaces_info["interface_parameter_name"].append(axi4_stream_interface_info_tmp["interface_parameter_name"])
            interfaces_info["interface_instance_parameter_name"].append(list(map(lambda x: "AXIS_" + x, axi4_stream_interface_info_tmp["interface_parameter_name"])))
            interfaces_info["interface_parameter_value"].append(axi4_stream_interface_info_tmp["interface_parameter_value"])
            interfaces_info["interface_ports"].append(axi4_stream_interface_info_tmp["interface_ports"])
            interfaces_info["interface_modport_ports"].append(axi4_stream_interface_info_tmp["interface_modport_ports"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_modport_ports_dir"].append(axi4_stream_interface_info_tmp["interface_modport_ports_dir"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_data_logic_list"].append(axi4_stream_interface_info_tmp["interface_data_logic_list"])
            interfaces_info["interface_data_logic_pack_dim"].append(axi4_stream_interface_info_tmp["interface_data_logic_pack_dim"])
            interfaces_info["interface_data_logic_unpack_dim"].append(axi4_stream_interface_info_tmp["interface_data_logic_unpack_dim"])

            for index, interface_modport_port in enumerate(interfaces_info["interface_modport_ports"][module_index]):
                if interfaces_info["interface_modport"][module_index] == "master":
                    interface_modport_port = "m0"+str(module_index)+"_axis_"+interface_modport_port
                else:
                    interface_modport_port = "s0"+str(module_index)+"_axis_"+interface_modport_port
                interfaces_info["interface_modport_ports"][module_index][index] = interface_modport_port

        elif module_interface == "axi4lite_intf":
            interfaces_info["interface_parameter_name"].append(axi4lite_interface_info_tmp["interface_parameter_name"])
            interfaces_info["interface_instance_parameter_name"].append(list(map(lambda x: "AXIL_" + x, axi4lite_interface_info_tmp["interface_parameter_name"])))
            interfaces_info["interface_parameter_value"].append(axi4lite_interface_info_tmp["interface_parameter_value"])
            interfaces_info["interface_ports"].append(axi4lite_interface_info_tmp["interface_ports"])
            interfaces_info["interface_modport_ports"].append(axi4lite_interface_info_tmp["interface_modport_ports"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_modport_ports_dir"].append(axi4lite_interface_info_tmp["interface_modport_ports_dir"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_data_logic_list"].append(axi4lite_interface_info_tmp["interface_data_logic_list"])
            interfaces_info["interface_data_logic_pack_dim"].append(axi4lite_interface_info_tmp["interface_data_logic_pack_dim"])
            interfaces_info["interface_data_logic_unpack_dim"].append(axi4lite_interface_info_tmp["interface_data_logic_unpack_dim"])

            for index, interface_modport_port in enumerate(interfaces_info["interface_modport_ports"][module_index]):
                if interfaces_info["interface_modport"][module_index] == "master":
                    interface_modport_port = "m0"+str(module_index)+"_axil_"+interface_modport_port
                else:
                    interface_modport_port = "s0"+str(module_index)+"_axil_"+interface_modport_port
                interfaces_info["interface_modport_ports"][module_index][index] = interface_modport_port

        elif module_interface == "data_stream_if":
            interfaces_info["interface_parameter_name"].append(data_stream_interface_info_tmp["interface_parameter_name"])
            interfaces_info["interface_instance_parameter_name"].append(list(map(lambda x: "DATAS_" + x + "_" + str(module_index), data_stream_interface_info_tmp["interface_parameter_name"])))
            interfaces_info["interface_parameter_value"].append(data_stream_interface_info_tmp["interface_parameter_value"])
            interfaces_info["interface_ports"].append(data_stream_interface_info_tmp["interface_ports"])
            interfaces_info["interface_modport_ports"].append(data_stream_interface_info_tmp["interface_modport_ports"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_modport_ports_dir"].append(data_stream_interface_info_tmp["interface_modport_ports_dir"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_data_logic_list"].append(data_stream_interface_info_tmp["interface_data_logic_list"])
            interfaces_info["interface_data_logic_pack_dim"].append(data_stream_interface_info_tmp["interface_data_logic_pack_dim"])
            interfaces_info["interface_data_logic_unpack_dim"].append(data_stream_interface_info_tmp["interface_data_logic_unpack_dim"])

            for index, interface_modport_port in enumerate(interfaces_info["interface_modport_ports"][module_index]):
                if interfaces_info["interface_modport"][module_index] == "master":
                    interface_modport_port = "m0"+str(module_index)+"_datas_"+interface_modport_port
                else:
                    interface_modport_port = "s0"+str(module_index)+"_datas_"+interface_modport_port
                interfaces_info["interface_modport_ports"][module_index][index] = interface_modport_port

        elif module_interface == "config_stream_if":
            interfaces_info["interface_parameter_name"].append(config_stream_interface_info_tmp["interface_parameter_name"])
            interfaces_info["interface_instance_parameter_name"].append(list(map(lambda x: "CONFIGS_" + x + "_" + str(module_index), config_stream_interface_info_tmp["interface_parameter_name"])))
            interfaces_info["interface_parameter_value"].append(config_stream_interface_info_tmp["interface_parameter_value"])
            interfaces_info["interface_ports"].append(config_stream_interface_info_tmp["interface_ports"])
            interfaces_info["interface_modport_ports"].append(config_stream_interface_info_tmp["interface_modport_ports"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_modport_ports_dir"].append(config_stream_interface_info_tmp["interface_modport_ports_dir"][interfaces_info["interface_modport"][module_index]])
            interfaces_info["interface_data_logic_list"].append(config_stream_interface_info_tmp["interface_data_logic_list"])
            interfaces_info["interface_data_logic_pack_dim"].append(config_stream_interface_info_tmp["interface_data_logic_pack_dim"])
            interfaces_info["interface_data_logic_unpack_dim"].append(config_stream_interface_info_tmp["interface_data_logic_unpack_dim"])

            for index, interface_modport_port in enumerate(interfaces_info["interface_modport_ports"][module_index]):
                if interfaces_info["interface_modport"][module_index] == "master":
                    interface_modport_port = "m0"+str(module_index)+"_configs_"+interface_modport_port
                else:
                    interface_modport_port = "s0"+str(module_index)+"_configs_"+interface_modport_port
                interfaces_info["interface_modport_ports"][module_index][index] = interface_modport_port

    return interfaces_info

def get_interface_data(interface_data: verible_verilog_syntax.SyntaxData):
    interface_info = {
    "interface_ports"                   : [],
    "interface_parameter_name"          : [],
    "interface_parameter_value"         : [],
    "interface_data_logic_list"         : [],
    "interface_data_logic_pack_dim"     : [],
    "interface_data_logic_unpack_dim"   : [],
    "interface_modport"                 : [],
    "interface_modport_ports"           : {"master": [], "slave":[]},
    "interface_modport_ports_dir"       : {"master": [], "slave":[]}
    }

    for interface in interface_data.tree.iter_find_all({"tag": "kInterfaceDeclaration"}):
        #Get interface header on syntax tree
        # Find module header
        header = interface.find({"tag": "kModuleHeader"})

        # Get the list of ports
        for port in header.iter_find_all({"tag": ["kPortDeclaration", "kPort"]}):
            port_id = port.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]})
            interface_info["interface_ports"].append(port_id.text)

        # Get the list of parameters
        for param in header.iter_find_all({"tag": ["kParamDeclaration"]}):
            param_id = param.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]})
            interface_info["interface_parameter_name"].append(param_id.text)
            param_value = param.find({"tag": ["kTraillingAssign", "kNumber", "TK_DecNumber"]})
            if param_value is None:
                param_value = param.find({"tag": ["kTraillingAssign", "kUnqualifiedId"]})
            interface_info["interface_parameter_value"].append(param_value.text)

        module_internal_header = interface.find({"tag": "kModuleItemList"})

        #Get the data declaration list
        for data_declaration in module_internal_header.iter_find_all({"tag": ["kDataDeclaration"]}):
            data_name = data_declaration.find({"tag": ["kGateInstanceRegisterVariableList", "kRegisterVariable"]})
            interface_info["interface_data_logic_list"].append(data_name.text)
            data_packed_dim = data_declaration.find({"tag": ["kPackedDimensions", "kDeclarationDimentions"]})
            data_unpacked_dim = data_declaration.find({"tag": ["kUnpackedDimensions"]})
            interface_info["interface_data_logic_pack_dim"].append(data_packed_dim.text)
            interface_info["interface_data_logic_unpack_dim"].append(data_unpacked_dim.text)

        #Get the modport
        for modport in module_internal_header.iter_find_all({"tag": ["kModportDeclaration"]}):
            modport_id = modport.find({"tag": ["SymbolIdentifier", "EscapedIdentifier"]})
            modport_portlist = modport.find({"tag": ["kModportPortList", "kModportSimplePort"]})
            interface_info["interface_modport"].append(modport_id.text)
            modport_ports_tmp = [modport_port for modport_port in modport_portlist.text.split(",\n") if modport_port != ", "]
            for item in modport_ports_tmp:
                #remove leading whitespaces
                item = item.lstrip("\n ")
                if(item.find("output ") > -1):
                    item = item.lstrip("output")
                    interface_info["interface_modport_ports_dir"][modport_id.text].append("output")
                else:
                    item = item.lstrip("input ")
                    interface_info["interface_modport_ports_dir"][modport_id.text].append("input")
                interface_info["interface_modport_ports"][modport_id.text].append(item.strip())

    return interface_info

def generate_wrapper(module_info: dict, interface_info:dict):
    template_name           = "module_wrapper_template.j2"
    wrapper_name            = module_info["name"]+"_wrapper"
    out_file                = wrapper_name+".sv"
    script_dir              = path.dirname(__file__)

    # print(interface_info)

    print("Rendering template..")
    env = Environment(loader=FileSystemLoader(script_dir), trim_blocks=True, lstrip_blocks=True)
    template = env.get_template(template_name)
    template_result = template.render(  wrapper_name                        = wrapper_name,
                                        module_name                         = module_info["name"],
                                        module_param_name                   = module_info["parameter_name"],
                                        module_param_value                  = module_info["parameter_value"],
                                        module_port_type                    = module_info["port_type"],
                                        module_port_dir                     = module_info["port_direction"],
                                        module_port_name                    = module_info["port_name"],
                                        interfaces_name                     = interface_info["interface_name"],
                                        interfaces_instance_name            = interface_info["interface_instance_name"],
                                        interfaces_type                     = interface_info["interface_type"],
                                        interfaces_port                     = interface_info["interface_ports"],
                                        interfaces_instance_param_name      = interface_info["interface_instance_parameter_name"],
                                        interfaces_param_name               = interface_info["interface_parameter_name"],
                                        interfaces_param_value              = interface_info["interface_parameter_value"],
                                        interfaces_data_logic               = interface_info["interface_data_logic_list"],
                                        interfaces_data_logic_packed_dim    = interface_info["interface_data_logic_pack_dim"],
                                        interfaces_data_logic_unpacked_dim  = interface_info["interface_data_logic_unpack_dim"],
                                        interfaces_modport                  = interface_info["interface_modport"],
                                        interfaces_modport_ports            = interface_info["interface_modport_ports"],
                                        interfaces_modport_ports_dir        = interface_info["interface_modport_ports_dir"]
                                    )

    with open(out_file, "w") as fh:
        fh.write(template_result)

def main():
    module_filepath                 = ""
    interface_filepath              = ""
    axi4_stream_if_data_parsed      = None
    axi4lite_intf_data_parsed       = None
    data_stream_if_data_parsed      = None
    config_stream_if_data_parsed    = None

    if len(sys.argv) < 1:
        print("Please, indicate the systemverilog/verilog file to wrap as a argument of the script..")
        print("Exiting..")

    for file_to_wrap in sys.argv[1:]:
        if path.isfile(file_to_wrap) is not True:
            print("Error: File " + '\033[91m' + file_to_wrap + '\033[0m' + " not exists..")
        else:
            module_filepath = sys.argv[1]

    print("Wrapping existing files..")

    parser              = verible_verilog_syntax.VeribleVerilogSyntax(executable=shutil.which('verible-verilog-syntax'))
    module_data_parsed  = parser.parse_file(module_filepath)

    module_info = process_data_parsed(module_filepath, module_data_parsed)

    if "axi4_stream_if" in module_info["interface_type"]:
        axi4_stream_if_data_parsed = parser.parse_file(AXI4_STREAM_INTF_PATH)
    
    if "axi4lite_intf" in module_info["interface_type"]:
        axi4lite_intf_data_parsed = parser.parse_file(AXI4_LITE_INTF_PATH)

    if "data_stream_if" in module_info["interface_type"]:
        data_stream_if_data_parsed = parser.parse_file(DATA_STREAM_INTF_PATH)

    if "config_stream_if" in module_info["interface_type"]:
        config_stream_if_data_parsed = parser.parse_file(CONFIG_STREAM_INTF_PATH)
        

    interface_info = process_interface_parsed(module_info, axi4_stream_if_data_parsed, axi4lite_intf_data_parsed, data_stream_if_data_parsed, config_stream_if_data_parsed)

    generate_wrapper(module_info, interface_info)


if __name__ == "__main__":
    sys.exit(main())