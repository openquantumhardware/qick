#!/usr/bin/env python3
import yaml
from pathlib import Path

def parse_core_name(core_name: str):
    parts = core_name.split(':')
    if len(parts) >= 3:
        return parts[0], parts[1], parts[2]
    return None, None, None

def find_core_file(core_name: str, cores_root: Path):
    vendor, category, name = parse_core_name(core_name)
    
    if category == 'ip':
        core_path = cores_root / 'ip' / name
    elif category:
        core_path = cores_root / 'lib' / category / name
    else:
        return None
    
    core_file = core_path / f"{name}.core"
    if core_file.exists():
        return core_file
    return None

def read_deps_recursive(core_name: str, cores_root: Path, visited: set = None):
    if visited is None:
        visited = set()
    
    if core_name in visited:
        return visited
    
    visited.add(core_name)
    
    core_file = find_core_file(core_name, cores_root)
    if not core_file:
        print(f"  ⚠️ Core file not found: {core_name}")
        return visited
    
    with open(core_file) as f:
        data = yaml.safe_load(f)
    
    # Look for dependencies in filesets
    if 'filesets' in data:
        for fs_name, fs in data['filesets'].items():
            if isinstance(fs, dict) and 'depend' in fs:
                for dep in fs['depend']:
                    if dep not in visited:
                        print(f"  Found: {dep}")
                        read_deps_recursive(dep, cores_root, visited)
    
    return visited

# Test
cores_root = Path("cores")
deps = read_deps_recursive("qick:ip:xcom", cores_root)
print(f"\n=== All dependencies ===")
for d in sorted(deps):
    print(f"  {d}")
