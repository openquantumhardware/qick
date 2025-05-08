set proj_dir [get_property DIRECTORY [current_project]]
set bitstream_dir "${proj_dir}/../../../fpga/bitstream"

# delete folders
exec rm -rf ${proj_dir}/../../../fpga/bitstream

# create folders
exec mkdir -p ${proj_dir}/../../../fpga/bitstream


##########
## STAGE 1
##########

# Obtener lista de archivos .bit y .bit.bin en el directorio $proj_dir
set file_bit [glob "$proj_dir/*.bit"]

# Verificar si se encontraron archivos .bit y si es que existe se crea .bit.bin
# y se copia al directorio final

if {[llength $file_bit] > 0} {
  # Tomar el primer archivo de la lista
  set filename_bit [lindex $file_bit 0]

  ############
  ## STAGE 1.1
  ############

  # Establecer el nombre del archivo .bif temporal
  set bif_tempfile [file join [file dirname $proj_dir] "hw_tmp.bif"]

  # Crear el contenido del archivo .bif temporal
  set bif_content "all:\n{\n  [list $filename_bit] \n}"

  # Escribir el contenido en el archivo .bif temporal
  set bif_file [open $bif_tempfile "w"]
  puts $bif_file $bif_content
  close $bif_file

  # Ejecutar bootgen con el archivo .bif temporal
  exec bootgen -image $bif_tempfile -arch zynqmp -process_bitstream bin -w

  # Eliminar el archivo .bif temporal
  file delete $bif_tempfile

  ############
  ## STAGE 1.2
  ############

  # Obtener el nombre del archivo sin la extensión ".bit"
  set filename_bit_without_ext [file rootname [file tail $filename_bit]]

  # Generar el nombre de archivo con la extensión ".xsa"
  set xsa_filename "${filename_bit_without_ext}.xsa"

  # Generar el archivo .xsa
  write_hw_platform -fixed -include_bit -force -file $bitstream_dir/$xsa_filename

  ############
  ## STAGE 1.3
  ############

  # Copiar el archivo al directorio $bitstream_dir
  file copy -force $filename_bit $bitstream_dir

} else {
  # No se encontraron archivos .bit en el directorio $proj_dir
  puts "No se encontraron archivos .bit en el directorio $proj_dir"
}

##########
## STAGE 2
##########

set file_bit_bin [glob "$proj_dir/*.bit.bin"]

# Verificar si se encontraron archivos .bit que se deberian generar en anterior stage
if {[llength $file_bit_bin] > 0} {
  # Tomar el primer archivo de la lista
  set filename_bit_bin [lindex $file_bit_bin 0]

  # Copiar el archivo al directorio $bitstream_dir
  file copy -force $filename_bit_bin $bitstream_dir
} else {
  # No se encontraron archivos .bit en el directorio $proj_dir
  puts "No se encontraron archivos .bit en el directorio $proj_dir"
}
