import os
from fusesoc.capi2.generator import Generator
from rdl_tools import hdl_gen, html_gen, verilog_header_gen, c_header_gen
import yaml
from yaml import CSafeDumper as YamlDumper

class RDLGenerator(Generator):
    def run(self):
        output_dir = "."
        export_file = list()
        file = self.config["rdl_file"]
        basename = os.path.basename(file)
        (head_file,_) = os.path.splitext(basename)

        if "is_top" not in self.config:
            self.config["is_top"] = False

        if not self.config["is_top"]:
            hdl_gen(output_dir , [os.path.join(self.files_root, file)])

            export_file.append({head_file + '_pkg.sv' : {'file_type' : 'systemVerilogSource'}})
            export_file.append({head_file + '.sv' : {'file_type' : 'systemVerilogSource'}})

        if self.config["documentation"] == 'html':
            raise NotImplementedError("Documentacion html no soportada. Actualizar creacion de directorio con archivos html")

        if self.config["headers"] is not None:
            for header in self.config["headers"]:
                if header == 'verilog':
                    verilog_header_gen(output_dir, [os.path.join(self.files_root, file)], self.config["is_top"])
                    export_file.append({head_file + '.svh' : {'file_type' : 'systemVerilogSource', 'is_include_file': True}})

                if header == 'c':
                    c_header_gen(output_dir, [os.path.join(self.files_root, file)], self.config["is_top"])
                    export_file.append({head_file + '.h' : {'file_type' : 'user', 'is_include_file': True}})

        self.add_files(export_file)

    def yaml_fwrite_ordered(self, content, preamble=""):
        with open(self.core_file, "w") as f:
            f.write(preamble)
            f.write(yaml.dump(content, Dumper=YamlDumper, sort_keys=False))

    def write(self):
        coredata = {
            "name": self.vlnv,
            "filesets": self.filesets,
            "parameters": self.parameters,
            "targets": self.targets,
        }
        return self.yaml_fwrite_ordered(coredata, "CAPI=2:\n")

if __name__ == '__main__':
    g = RDLGenerator()
    g.run()
    g.write()
