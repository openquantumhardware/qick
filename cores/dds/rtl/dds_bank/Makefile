BUILD_FILE_NAME=build/board

all: create_proj

create_proj: $(BUILD_FILE_NAME)

$(BUILD_FILE_NAME):
	echo create build exists file
	mkdir -p build
	vivado -nolog -nojournal -mode batch -source ./dds_bank.tcl

clean:
	rm -rf build

.PHONY: all create_proj clean
