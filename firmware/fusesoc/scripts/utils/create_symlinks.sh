#!/bin/bash
# Crea hdl/ symlinks para todos los cores que existen en fusesoc/cores/
# apuntando a ip/<name>/src/ en el repo HOG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUSESOC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIRMWARE_DIR="$(cd "$FUSESOC_DIR/.." && pwd)"
IP_DIR="$FIRMWARE_DIR/ip"
CORES_DIR="$FUSESOC_DIR/cores"

echo "FUSESOC_DIR : $FUSESOC_DIR"
echo "FIRMWARE_DIR: $FIRMWARE_DIR"
echo "IP_DIR      : $IP_DIR"
echo "CORES_DIR   : $CORES_DIR"

for core_dir in "$CORES_DIR"/*/; do
    [ -d "$core_dir" ] || continue
    core_name=$(basename "$core_dir")
    ip_src="$IP_DIR/$core_name/src"
    symlink="$core_dir/hdl"

    if [ -e "$symlink" ]; then
        echo "  already exists: fusesoc/cores/$core_name/hdl"
    elif [ -d "$ip_src" ]; then
        # symlink relativo para que funcione independientemente del clone path
        ln -s "../../../ip/$core_name/src" "$symlink"
        echo "✓ fusesoc/cores/$core_name/hdl -> ip/$core_name/src"
    else
        echo "  no ip/src for: $core_name (hdl lives inside core dir)"
    fi
done
