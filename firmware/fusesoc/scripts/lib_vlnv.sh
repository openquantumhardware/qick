#!/bin/bash
# lib_vlnv.sh - deriva "vendor:library:name:MAJOR.MINOR" del .core del IP.
core_vlnv() {
    local ip="$1"
    local core_file
    core_file=$(find cores -name "${ip}.core" ! -name "*_regmap.core" | head -1)
    if [ -z "$core_file" ]; then
        echo "qick:ip:${ip}:1.0"   # fallback
        return 0
    fi
    local full vln version majmin
    full=$(grep -m1 '^name:' "$core_file" | sed 's/name:[[:space:]]*//' | tr -d ' ')
    vln=${full%:*}
    version=${full##*:}
    majmin=$(echo "$version" | cut -d. -f1-2)
    echo "${vln}:${majmin}"
}
