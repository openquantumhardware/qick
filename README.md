# PYNQ\_FUSED environment setup

## Dependencias
Son necesarios pip y virtualenv en python

En ubuntu:

	# apt install python3-venv python3-pip

En Arch:

    # pacman -S python-pip python-virtualenv

PyXSI requiere [fmt](https://github.com/fmtlib/fmt)

En Ubuntu:

	# apt install libfmt-dev

En Arch:

    # pacman -S fmt

## Variables de Entorno
Se necesita que las herramientas de Vivado se encuentren el $PATH (PyXSI a xelab, por ejemplo). Para ello es posible correr

	$ source [PATH INSTALACION DE VIVADO]/settings64.sh
		
Ademas, PyXSI hace uso de la libreria dinamica de Vivado

	$ export LD_LIBRARY_PATH=[PATH INSTALACION DE VIVADO]/lib/lnx64.o

Para que se mantengan estas variables de forma permanente, ambas líneas pueden agrearse al archivo .bashrc (generalmente se encuentra en el directorio por defecto de la terminal).

Nota: Las nuevas terminales leen automáticamente el .bashrc e incorporan las variables de entorno, pero si queremos que el cambio aplique a una terminal ya abierta debemos ejecutar:

	$ source .bashrc

## Paquetes de Python

Crear un entorno virtual

	$ python3 -m venv venv

Acceder a el

	$ source venv/bin/activate

Actualizar pip e instalar las dependencias

	$ pip install --upgrade pip && pip install -r requirements.txt

## Ejecucion
Los tests unitarios, cosimulacion con python y sintesis se corren mediante targets de [FuseSoC](https://github.com/olofk/fusesoc)

La informacion sobre los targets que posee cada bloque, como los sources que lo componen y las dependencias a otros bloques esta contenida en un archivo .core, un conjunto de archivos .core se llama libreria.

FuseSoC necesita saber donde buscar las librerias, para ello usar el script `fusesoc_setup.sh`:

    $ source fusesoc_setup.sh

O de forma manual con el comando `fuseosc library add`, por ejemplo:

	$ fusesoc library add --location $PWD/.fusesoc_libraries/svunit-lib svunit-lib https://github.com/ivanvig/svunit.git

Para mas informacion, esta disponible la documentacion de [FuseSoC](https://fusesoc.readthedocs.io/en/stable/) y [Edalize](https://edalize.readthedocs.io/en/latest/)
