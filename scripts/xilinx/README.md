# Scripts Vivado

Se describe que funcionalidad tiene cada uno de los scrips. Estos scripts se integran en un .core y se incluye en el .core top del proyecto


Estos scripts se utilizan en la stage de build de edalize.

| Script                | Descripción                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| cfg_warning.tcl       | Este script configura los warnings. Aca es donde uno podria cambiar que un warning se considere como critical warning, info, etc. |
| cfg_project.tcl       | Este script realiza algunas configuraciones a nivel project.                                                                      |
| create_bitbin_xsa.tcl | Este script genera el .xsa y el .bit.bin como tambien copia todos los binarios a la carpeta fpga/bitstream.                       |
| create_reports.tcl    | Este script genera los reportes de utilizacion y timing. como tambien copia todos los reportes en fpga/reports/*                  |
