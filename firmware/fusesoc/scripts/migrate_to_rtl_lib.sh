#!/bin/bash
# migrate_to_rtl_lib.sh - Migrate all cores to rtl_lib/ structure
# Run from: firmware/fusesoc/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUSESOC_DIR="$SCRIPT_DIR"
FIRMWARE_DIR="$(dirname "$FUSESOC_DIR")"
RTL_LIB_DIR="$FIRMWARE_DIR/rtl_lib"
CORES_DIR="$FUSESOC_DIR/cores"
LIB_DIR="$CORES_DIR/lib"
IP_DIR="$CORES_DIR/ip"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Migrating cores to rtl_lib/ structure${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Firmware dir: ${YELLOW}$FIRMWARE_DIR${NC}"
echo -e "RTL lib dir:  ${YELLOW}$RTL_LIB_DIR${NC}"
echo ""

# Create rtl_lib directory structure
mkdir -p "$RTL_LIB_DIR"/{axi,cdc,fifo,interfaces,utils,memory,math}

# Function to copy RTL file to rtl_lib and create symlink
migrate_rtl_to_lib() {
    local source_file="$1"
    local target_cat="$2"
    local target_name="$3"
    
    local target_dir="$RTL_LIB_DIR/$target_cat"
    local target_file="$target_dir/$target_name"
    
    mkdir -p "$target_dir"
    
    if [ -f "$source_file" ]; then
        echo -e "  Copying RTL: ${YELLOW}$source_file${NC} -> ${GREEN}$target_file${NC}"
        cp "$source_file" "$target_file"
    elif [ -L "$source_file" ]; then
        local resolved=$(readlink -f "$source_file")
        echo -e "  Copying RTL (from symlink): ${YELLOW}$resolved${NC} -> ${GREEN}$target_file${NC}"
        cp "$resolved" "$target_file"
    else
        echo -e "  ${RED}WARNING: Source not found: $source_file${NC}"
        return 1
    fi
    return 0
}

# Function to create symlink in core's hdl directory
create_symlink() {
    local core_hdl_dir="$1"
    local target_cat="$2"
    local target_name="$3"
    
    local rtl_source="../../../../rtl_lib/$target_cat/$target_name"
    
    # Remove existing hdl dir/file
    if [ -e "$core_hdl_dir" ]; then
        rm -rf "$core_hdl_dir"
    fi
    
    mkdir -p "$(dirname "$core_hdl_dir")"
    ln -sf "$rtl_source" "$core_hdl_dir"
    echo -e "  Created symlink: ${GREEN}$core_hdl_dir${NC} -> ${YELLOW}$rtl_source${NC}"
}

echo -e "${BLUE}Step 1: Migrating LIB cores RTL to rtl_lib/${NC}"
echo ""

# Process each core in lib/
for core_category in axi cdc fifo interfaces utils; do
    category_dir="$LIB_DIR/$core_category"
    if [ ! -d "$category_dir" ]; then
        continue
    fi
    
    for core_path in "$category_dir"/*/; do
        if [ ! -d "$core_path" ]; then
            continue
        fi
        
        core_name=$(basename "$core_path")
        echo -e "\n${BLUE}Processing:${NC} $core_category/$core_name"
        
        # Look for RTL source files
        src_found=""
        
        # Check src/ directory
        if [ -f "$core_path/src"*.sv 2>/dev/null ] || [ -d "$core_path/src" ]; then
            for src_file in "$core_path/src"/*.sv "$core_path/src"/*.v; do
                if [ -f "$src_file" ]; then
                    migrate_rtl_to_lib "$src_file" "$core_category" "$core_name.sv"
                    src_found="yes"
                fi
            done
        fi
        
        # Check hdl/ directory for actual files (not symlinks)
        if [ -d "$core_path/hdl" ] && [ ! -L "$core_path/hdl" ]; then
            for hdl_file in "$core_path/hdl"/*.sv "$core_path/hdl"/*.v; do
                if [ -f "$hdl_file" ] && [ ! -L "$hdl_file" ]; then
                    migrate_rtl_to_lib "$hdl_file" "$core_category" "$core_name.sv"
                    src_found="yes"
                fi
            done
        fi
        
        # Check rtl/ directory
        if [ -d "$core_path/rtl" ]; then
            for rtl_file in "$core_path/rtl"/*.sv "$core_path/rtl"/*.v; do
                if [ -f "$rtl_file" ]; then
                    migrate_rtl_to_lib "$rtl_file" "$core_category" "$core_name.sv"
                    src_found="yes"
                fi
            done
        fi
        
        # If no source found but there's a symlink, copy the target
        if [ -z "$src_found" ] && [ -L "$core_path/hdl" ]; then
            target=$(readlink -f "$core_path/hdl")
            if [ -f "$target" ]; then
                migrate_rtl_to_lib "$target" "$core_category" "$core_name.sv"
                src_found="yes"
            elif [ -d "$target" ]; then
                # Directory symlink - copy all .sv files
                for sv_file in "$target"/*.sv "$target"/*.v; do
                    if [ -f "$sv_file" ]; then
                        migrate_rtl_to_lib "$sv_file" "$core_category" "$(basename "$sv_file")"
                        src_found="yes"
                    fi
                done
            fi
        fi
        
        # After copying RTL to rtl_lib, create new symlink
        if [ "$src_found" = "yes" ]; then
            create_symlink "$core_path/hdl" "$core_category" "$core_name.sv"
        else
            echo -e "  ${YELLOW}No RTL source found for $core_name${NC}"
        fi
        
        # Ensure test and data directories exist (keep them)
        mkdir -p "$core_path/test" "$core_path/data" "$core_path/lint" 2>/dev/null || true
    done
done

echo -e "\n${BLUE}Step 2: Migrating XCOM submodules (currently in ip/) to rtl_lib/${NC}"
echo ""

# XCOM submodules that are currently in ip/ but should be in lib/
xcom_submodules=(
    "xcom_axil_slv:axi"
    "xcom_cdc:cdc"
    "xcom_cmd:utils"
    "xcom_link_rx:utils"
    "xcom_link_tx:utils"
    "xcom_qctrl:utils"
    "xcom_txrx:utils"
)

for entry in "${xcom_submodules[@]}"; do
    submodule="${entry%:*}"
    category="${entry#*:}"
    
    source_ip_dir="$FIRMWARE_DIR/ip/$submodule/src"
    target_rtl="$RTL_LIB_DIR/$category/$submodule.sv"
    
    if [ -d "$source_ip_dir" ]; then
        for sv_file in "$source_ip_dir"/*.sv; do
            if [ -f "$sv_file" ]; then
                echo -e "  Copying: ${YELLOW}$sv_file${NC} -> ${GREEN}$target_rtl${NC}"
                cp "$sv_file" "$target_rtl"
                
                # Create symlink in lib/
                lib_core_dir="$LIB_DIR/$category/$submodule"
                mkdir -p "$lib_core_dir"
                create_symlink "$lib_core_dir/hdl" "$category" "$submodule.sv"
                
                # Create basic .core file if doesn't exist
                if [ ! -f "$lib_core_dir/$submodule.core" ]; then
                    cat > "$lib_core_dir/$submodule.core" << EOF
CAPI=2:
name: qick:$category:$submodule:1.0.0
description: $submodule - part of XCOM

filesets:
  hdl:
    files:
      - hdl/$submodule.sv
    file_type: systemVerilogSource

targets:
  default:
    filesets: [hdl]
    toplevel: $submodule
EOF
                    echo -e "  Created .core: ${GREEN}$lib_core_dir/$submodule.core${NC}"
                fi
            fi
        done
    fi
done

echo -e "\n${BLUE}Step 3: Updating .core files to use new dependencies${NC}"
echo ""

# Update .core files to use new library paths
find "$CORES_DIR" -name "*.core" -type f | while read core_file; do
    # Skip if it's a lib core (they already have correct names)
    if [[ "$core_file" == *"/lib/"* ]]; then
        continue
    fi
    
    echo -e "  Checking: ${YELLOW}$core_file${NC}"
    
    # Update dependencies from old paths to new library names
    sed -i \
        -e 's/qick:ip:xcom_axil_slv/qick:axi:xcom_axil_slv/g' \
        -e 's/qick:ip:xcom_cdc/qick:cdc:xcom_cdc/g' \
        -e 's/qick:ip:xcom_cmd/qick:utils:xcom_cmd/g' \
        -e 's/qick:ip:xcom_txrx/qick:utils:xcom_txrx/g' \
        -e 's/qick:ip:xcom_link_rx/qick:utils:xcom_link_rx/g' \
        -e 's/qick:ip:xcom_link_tx/qick:utils:xcom_link_tx/g' \
        "$core_file"
done

echo -e "\n${BLUE}Step 4: Cleaning up old files${NC}"
echo ""

# Remove now-empty directories in ip/ for xcom submodules
for submodule in xcom_axil_slv xcom_cdc xcom_cmd xcom_link_rx xcom_link_tx xcom_qctrl xcom_txrx; do
    if [ -d "$FIRMWARE_DIR/ip/$submodule" ]; then
        echo -e "  Removing: ${YELLOW}ip/$submodule/${NC} (RTL moved to rtl_lib/)"
        rm -rf "$FIRMWARE_DIR/ip/$submodule"
    fi
done

# Remove duplicate RTL files from lib/ that were copied to rtl_lib/
find "$LIB_DIR" -name "*.sv" -type f ! -path "*/hdl/*" | while read dup_file; do
    if [ -f "$dup_file" ]; then
        echo -e "  Removing duplicate: ${YELLOW}$dup_file${NC}"
        rm -f "$dup_file"
    fi
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Migration complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Review changes: ${YELLOW}git status${NC}"
echo -e "  2. Test with:      ${YELLOW}make list-cores${NC}"
echo -e "  3. Test xcom:      ${YELLOW}make sim IP=xcom${NC}"
echo -e "  4. Commit changes: ${YELLOW}git add rtl_lib/ cores/ ip/ && git commit -m 'migrate to rtl_lib structure'${NC}"
