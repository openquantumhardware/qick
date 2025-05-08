import os
import glob
import subprocess
import shutil
from fusesoc.capi2.generator import Generator
from jinja2 import Environment, FileSystemLoader

class IPGenerator(Generator):
    def generate_file(self):
        # Generate tcl script
        self.export_files = list()
        template_name = "create_ip_tcl.j2"
        self.out_file_name = "create_ip"
        script_dir = os.path.dirname(__file__)

        env = Environment(loader=FileSystemLoader(script_dir), trim_blocks=True, lstrip_blocks=True)
        template = env.get_template(template_name)

        # Copy files needed
        if "required_files" in self.config.keys():
            dest_path = os.path.join(os.getcwd(), self.config["module_name"])
            os.makedirs(dest_path, exist_ok=True)

            for file in self.config["required_files"]:
                shutil.copy(os.path.join(self.files_root, file),
                            os.path.join(dest_path, os.path.basename(file)))

        # Define board part used
        if "board_part" not in self.config.keys():
            self.config["board_part"] = "xczu15eg-ffvb1156-2-e"

        # Build .tcl and include files
        if "synthesis" in self.config["targets"]:
            # Create .tcl
            template.stream(self.config, target_generate = "synthesis").dump(self.out_file_name + "_synth.tcl")
            # Include tclsource source
            self.export_files.append({'tool_vivado ? ('+self.out_file_name+'_synth.tcl)' : {'file_type' : 'tclSource'}})

        if "simulation" in self.config["targets"]:
            # Create .tcl
            template.stream(self.config, target_generate = "simulation").dump(self.out_file_name + "_sim.tcl")

            # Execute tcl script
            args = [
                'vivado',
                '-mode',
                'batch',
                '-source',
                self.out_file_name + "_sim.tcl"
            ]
            rc = subprocess.call(args)
            if rc:
                exit(1)

            # Remove vivado logs
            for f in glob.glob("vivado*"):
                os.remove(f)

            # Include outputs files and add flag to key
            self.export_files.extend([{f"tool_xsim ? ({key})": value for key, value in item.items()} for item in self.config['output']])


    def run(self):
        self.generate_file()
        self.add_files(self.export_files)


if __name__ == '__main__':
    g = IPGenerator()
    g.run()
    g.write()
