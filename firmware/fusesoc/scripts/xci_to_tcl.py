#!/usr/bin/env python3
"""
xci_to_tcl.py — Genera el Tcl de Vivado para recrear una IP a partir de un
.xci existente, bajo un module_name NUEVO, preservando todos los parametros
CONFIG.* funcionales tal cual estan.

Util para resolver colisiones de nombre de modulo cuando varias
customizaciones distintas de la misma IP (ej. dds_compiler) comparten
Component_Name — cada una genera un modulo Verilog con ESE nombre, asi que
si dos conviven en el mismo build, colisionan. Este script te da el Tcl para
regenerar cada variante con un nombre unico, sin tocar ningun parametro
funcional.

Soporta .xci en formato JSON (Vivado 2020.2+) y XML/IP-XACT (viejo).

Uso:
    python3 xci_to_tcl.py --xci dds_compiler_0.xci --module-name dds_compiler_signal_gen
    python3 xci_to_tcl.py --xci dds_compiler_0.xci --module-name dds_compiler_readout \
        --out regen_readout.tcl

El .tcl generado se corre dentro de una sesion de Vivado con un proyecto
abierto (o en modo batch con -mode batch), y termina con
generate_target para producir el .veo/.vho/.xml nuevos.
"""
import argparse
import json
import re
import sys
from pathlib import Path

XML_PARAM_RE = re.compile(
    r'spirit:referenceId="PARAM_VALUE\.([^"]+)"[^>]*>'
    r'\s*([^<]*?)\s*</spirit:configurableElementValue>',
    re.MULTILINE,
)
XML_COMPONENTREF_RE = re.compile(
    r'spirit:componentRef\s+spirit:vendor="([^"]+)"\s+spirit:library="([^"]+)"'
    r'\s+spirit:name="([^"]+)"\s+spirit:version="([^"]+)"'
)
IGNORE = {"Component_Name"}


def _first_value(entry):
    if isinstance(entry, list) and entry and isinstance(entry[0], dict):
        return str(entry[0].get("value", ""))
    return str(entry)


def parse_xci(xci_path: Path):
    """Devuelve (vendor, library, ip_name, version, params_dict)."""
    text = xci_path.read_text(errors="replace")

    if text.lstrip().startswith("{"):
        data = json.loads(text)
        ip_inst = data.get("ip_inst", {})
        ref = ip_inst.get("component_reference", "xilinx.com:ip:UNKNOWN:0.0")
        vendor, library, ip_name, version = ref.split(":")
        params = {}
        for entry in ip_inst.get("parameters", {}).get("component_parameters", {}).items():
            name, val = entry
            if name in IGNORE:
                continue
            params[name] = _first_value(val)
        return vendor, library, ip_name, version, params
    else:
        params = {}
        for name, value in XML_PARAM_RE.findall(text):
            if name in IGNORE:
                continue
            params[name] = value.strip()
        m = XML_COMPONENTREF_RE.search(text)
        if m:
            vendor, library, ip_name, version = m.groups()
            return vendor, library, ip_name, version, params
        # No se pudo extraer automaticamente (xci con formato inusual):
        # el usuario debe pasar --ip-vlnv a mano.
        return None, None, None, None, params


def tcl_quote(value: str) -> str:
    # Envolver en llaves es seguro para la gran mayoria de valores de IP
    # (numeros, strings simples, listas separadas por coma). Si el valor ya
    # contiene llaves, Tcl las anida sin problema.
    return "{" + value + "}"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--xci", required=True, type=Path, help="xci representante del grupo")
    ap.add_argument("--module-name", required=True, help="nuevo Component_Name/module name")
    ap.add_argument("--ip-vlnv", help="vendor:library:name:version "
                     "(requerido si el xci es formato XML viejo)")
    ap.add_argument("--out", type=Path, help="archivo .tcl de salida (default: stdout)")
    args = ap.parse_args()

    vendor, library, ip_name, version, params = parse_xci(args.xci)

    if vendor is None:
        if not args.ip_vlnv:
            print("[error] xci en formato XML viejo: falta --ip-vlnv "
                  "(ej. xilinx.com:ip:dds_compiler:6.0)", file=sys.stderr)
            sys.exit(1)
        vendor, library, ip_name, version = args.ip_vlnv.split(":")

    lines = []
    lines.append(f"# Generado desde {args.xci.name} -> module_name={args.module_name}")
    lines.append(f"# Parametros funcionales preservados tal cual (sin cambios de CONFIG.*)")
    lines.append(f"create_ip -name {ip_name} -vendor {vendor} -library {library} "
                 f"-version {version} -module_name {args.module_name}")
    lines.append("set_property -dict [list \\")
    items = sorted(params.items())
    for i, (k, v) in enumerate(items):
        sep = " \\" if i < len(items) - 1 else ""
        lines.append(f"    CONFIG.{k} {tcl_quote(v)}{sep}")
    lines.append(f"] [get_ips {args.module_name}]")
    lines.append(f"generate_target {{instantiation_template}} "
                 f"[get_files [get_property IP_FILE [get_ips {args.module_name}]]]")

    out_text = "\n".join(lines) + "\n"
    if args.out:
        args.out.write_text(out_text)
        print(f"[ok] escrito {args.out} ({len(items)} parametros)", file=sys.stderr)
    else:
        print(out_text)


if __name__ == "__main__":
    main()
