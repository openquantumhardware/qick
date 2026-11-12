#!/usr/bin/env python3
"""
dds_dedup_analyze.py — Agrupa instancias de una IP de Xilinx (ej. dds_compiler_0)
por equivalencia FUNCIONAL real, comparando el hash combinado de .vho+.xml+.veo
(la interfaz y configuracion generada), ignorando el .xci (que carga metadata
de proyecto que no afecta la funcionalidad: nombre de proyecto, rutas, a veces
IP_REVISION).

Uso:
    python3 dds_dedup_analyze.py --ip-root ../ip --name dds_compiler_0

    # Para buscar cualquier IP duplicada sin especificar nombre:
    python3 dds_dedup_analyze.py --ip-root ../ip --scan-all

Salida: grupos de equivalencia, cada uno con la lista de cores padre que
usan esa configuracion, y cual archivo tomar como representante canonico
para migrar a rtl_lib/xci/<nombre>/.

NO mueve ni modifica nada — es solo diagnostico para decidir el mapeo
core_padre -> core_de_libreria antes de tocar la estructura.
"""
import argparse
import hashlib
from collections import defaultdict
from pathlib import Path


def md5_of(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def find_ip_dirs(ip_root: Path, name: str):
    """Encuentra directorios .../<parent_core>/src/<name>/ bajo ip_root."""
    pattern = f"*/src/{name}"
    return sorted(ip_root.glob(pattern))


def scan_all_names(ip_root: Path):
    """Detecta todos los nombres de subdirectorio bajo */src/*/ que se repiten
    en mas de un core padre (candidatos a IP duplicada)."""
    counts = defaultdict(list)
    for src_dir in ip_root.glob("*/src/*"):
        if src_dir.is_dir():
            counts[src_dir.name].append(src_dir)
    return {name: dirs for name, dirs in counts.items() if len(dirs) > 1}


def analyze_group(name: str, dirs: list[Path]):
    print(f"\n{'='*70}")
    print(f"IP: {name}  ({len(dirs)} instancias encontradas)")
    print(f"{'='*70}")

    groups = defaultdict(list)
    xci_hashes = {}

    for d in dirs:
        parent_core = d.parent.parent.name  # .../<parent_core>/src/<name>
        parts_hash = []
        missing = []
        for ext in ("vho", "xml", "veo"):
            f = d / f"{name}.{ext}"
            if f.exists():
                parts_hash.append(md5_of(f))
            else:
                missing.append(ext)
        key = tuple(parts_hash) if not missing else ("INCOMPLETE",) + tuple(missing)

        xci = d / f"{name}.xci"
        xci_hashes[parent_core] = md5_of(xci) if xci.exists() else "(sin .xci)"

        groups[key].append(parent_core)

    for i, (key, cores) in enumerate(sorted(groups.items(), key=lambda kv: -len(kv[1])), 1):
        if key[0] == "INCOMPLETE":
            print(f"\n  [grupo {i}] INCOMPLETO (faltan: {key[1:]}) -> revisar manualmente")
        else:
            print(f"\n  [grupo {i}] {len(cores)} core(s) padre comparten vho+xml+veo "
                  f"(hash: {key[0][:10]}.../{key[1][:10]}.../{key[2][:10]}...)")
        for c in cores:
            print(f"      - {c}   (.xci hash: {xci_hashes[c][:10]}...)")
        if key[0] != "INCOMPLETE":
            canonical = sorted(cores)[0]
            print(f"      -> representante canonico sugerido: {canonical}"
                  f"  (cualquiera sirve, son funcionalmente identicos)")

    n_groups = len([k for k in groups if k[0] != "INCOMPLETE"])
    print(f"\n  Resumen: {len(dirs)} instancias -> {n_groups} configuracion(es) "
          f"funcional(es) distinta(s) real(es)"
          + (f" + {len(groups) - n_groups} incompleta(s)" if len(groups) - n_groups else ""))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ip-root", required=True, type=Path,
                     help="directorio raiz de las IPs viejas (ej. ../ip)")
    ap.add_argument("--name", help="nombre de la IP a analizar (ej. dds_compiler_0)")
    ap.add_argument("--scan-all", action="store_true",
                     help="detecta automaticamente todos los nombres de IP repetidos")
    args = ap.parse_args()

    if args.scan_all:
        candidates = scan_all_names(args.ip_root)
        if not candidates:
            print("No se encontraron nombres de IP repetidos entre cores padre.")
            return
        print(f"Nombres de IP que aparecen en mas de un core padre: "
              f"{', '.join(sorted(candidates))}\n")
        for name, dirs in candidates.items():
            analyze_group(name, dirs)
    else:
        if not args.name:
            ap.error("especifica --name o usa --scan-all")
        dirs = find_ip_dirs(args.ip_root, args.name)
        if not dirs:
            print(f"No se encontraron instancias de '{args.name}' bajo {args.ip_root}")
            return
        analyze_group(args.name, dirs)


if __name__ == "__main__":
    main()
