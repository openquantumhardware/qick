#!/usr/bin/env python3
"""
dds_dedup_analyze_xci.py — Agrupa instancias de una IP de Xilinx comparando
los parametros CONFIG.* reales dentro del .xci (fuente de verdad), en vez de
depender de .vho/.xml/.veo (subproductos regenerables que pueden faltar si
nunca se corrio "Generate Output Products" o no se commitearon a git).

Soporta los DOS formatos de .xci que genera Vivado segun la version:
  - XML/IP-XACT (viejo):  <spirit:configurableElementValue
                            spirit:referenceId="PARAM_VALUE.Nombre">valor</...>
  - JSON (Vivado 2020.2+): {"ip_inst": {"parameters": {"component_parameters":
                            {...}, "model_parameters": {...}, ...}}}
    (Vivado reescribe el .xci al formato JSON la primera vez que abris el
    proyecto con una version mas nueva, aunque no toques parametros — no es
    corrupcion, es normal tener ambos formatos conviviendo en un repo viejo.)

Solo se comparan component_parameters + model_parameters (la configuracion
funcional real). project_parameters y runtime_parameters (DEVICE, PACKAGE,
SWVERSION, OUTPUTDIR, etc.) son metadata de entorno/proyecto y se ignoran
siempre.

Ademas, filtra los presets de frecuencia/fase de la GUI (Output_FrequencyN,
PINCN, Phase_Offset_AnglesN, POFFN) cuando Phase_Increment/Phase_offset estan
en modo "Streaming": en ese modo esos campos son solo preview de la GUI y no
afectan la logica generada. Si el modo NO es Streaming, se avisa y no se
filtran (podrian ser funcionales).

Uso:
    python3 dds_dedup_analyze_xci.py --ip-root ../ip --name dds_compiler_0

    # Ver el diff de parametros entre dos instancias puntuales:
    python3 dds_dedup_analyze_xci.py --diff \
        ../ip/axis_signal_gen_v4/src/dds_compiler_0/dds_compiler_0.xci \
        ../ip/axis_signal_gen_v5/src/dds_compiler_0/dds_compiler_0.xci
"""
import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

# Campos que son metadata de proyecto/entorno, no configuracion funcional de
# la IP. Ajustar esta lista si aparecen otros campos irrelevantes en tus xci.
IGNORE_KEYS = {
    "Component_Name",
    "ModuleName",
    "GUI_SYNTH_LANGUAGE",
    "GUI_SIM_LANGUAGE",
    "ipCoreLanguage",
    "SYNTHESIS_BOARD_PART",
    "BOARD_PART",
    "IP_REVISION",
    "PACKAGE_TCC_FILES",
    "PACKAGE_MADE",
    "CORE_REVISION",
    "GENERATED_TYPE",
}

# Presets de frecuencia/fase de la GUI del DDS Compiler: solo se usan para
# preview y NO afectan la logica generada en modo Streaming (pinc/phase
# llegan por s_axis_phase en runtime, como en QICK).
_PRESET_RE = re.compile(r'^(Output_Frequency|PINC|Phase_Offset_Angles|POFF)\d+$')

XML_PARAM_RE = re.compile(
    r'spirit:referenceId="(?:PARAM_VALUE|MODELPARAM_VALUE)\.([^"]+)"[^>]*>'
    r'\s*([^<]*?)\s*</spirit:configurableElementValue>',
    re.MULTILINE,
)


def _first_value(entry):
    """component_parameters/model_parameters values son listas de dicts;
    toma el campo 'value' del primer elemento."""
    if isinstance(entry, list) and entry and isinstance(entry[0], dict):
        return str(entry[0].get("value", ""))
    return str(entry)


def extract_config(xci_path: Path) -> dict:
    text = xci_path.read_text(errors="replace")
    params = {}

    if text.lstrip().startswith("{"):
        # Formato JSON (Vivado 2020.2+)
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            return {}
        ip_params = data.get("ip_inst", {}).get("parameters", {})
        for section in ("component_parameters", "model_parameters"):
            for name, entry in ip_params.get(section, {}).items():
                if name in IGNORE_KEYS:
                    continue
                params[name] = _first_value(entry)
    else:
        # Formato XML/IP-XACT (viejo)
        for name, value in XML_PARAM_RE.findall(text):
            if name in IGNORE_KEYS:
                continue
            params[name] = value.strip()

    return params


def filter_presets(params: dict):
    """Saca los presets de frecuencia/fase (ruido de GUI) si el modo es
    Streaming. Devuelve (params_filtrados, lista_de_avisos)."""
    streaming = params.get("Phase_Increment") == "Streaming" and \
        params.get("Phase_offset") == "Streaming"
    if not streaming:
        warn = ("Phase_Increment/Phase_offset no estan en modo Streaming: "
                "los presets Output_FrequencyN/PINCN/etc. SI podrian ser "
                "funcionales aca — no se filtraron, revisar a mano.")
        return params, [warn]
    filtered = {k: v for k, v in params.items() if not _PRESET_RE.match(k)}
    return filtered, []


def config_signature(params: dict) -> str:
    items = sorted(params.items())
    blob = "\n".join(f"{k}={v}" for k, v in items)
    return hashlib.md5(blob.encode()).hexdigest()


def find_ip_dirs(ip_root: Path, name: str):
    return sorted(ip_root.glob(f"*/src/{name}"))


def cmd_diff(args):
    a = extract_config(args.diff[0])
    b = extract_config(args.diff[1])
    if not args.no_filter:
        a, warn_a = filter_presets(a)
        b, warn_b = filter_presets(b)
        for w in warn_a + warn_b:
            print(f"[aviso] {w}")
    keys = sorted(set(a) | set(b))
    diffs = [(k, a.get(k, "<falta>"), b.get(k, "<falta>"))
             for k in keys if a.get(k) != b.get(k)]
    if not diffs:
        print("Sin diferencias funcionales (parametros CONFIG.* identicos).")
        return
    print(f"\n{len(diffs)} parametro(s) distinto(s):\n")
    w = max(len(k) for k, _, _ in diffs)
    for k, va, vb in diffs:
        print(f"  {k.ljust(w)}  A={va!r:20s}  B={vb!r}")


def cmd_analyze(args):
    dirs = find_ip_dirs(args.ip_root, args.name)
    if not dirs:
        print(f"No se encontraron instancias de '{args.name}' bajo {args.ip_root}")
        return

    groups = defaultdict(list)
    no_xci = []
    parse_fail = []
    all_warnings = {}

    for d in dirs:
        parent_core = d.parent.parent.name
        xci = d / f"{args.name}.xci"
        if not xci.exists():
            no_xci.append(parent_core)
            continue
        params = extract_config(xci)
        if not params:
            parse_fail.append(parent_core)
            continue
        if not args.no_filter:
            params, warnings = filter_presets(params)
            if warnings:
                all_warnings[parent_core] = warnings
        sig = config_signature(params)
        groups[sig].append(parent_core)

    print(f"\n{'='*70}\nIP: {args.name}  ({len(dirs)} instancias)\n{'='*70}")
    for i, (sig, cores) in enumerate(sorted(groups.items(), key=lambda kv: -len(kv[1])), 1):
        print(f"\n  [grupo {i}] {len(cores)} core(s) padre — misma configuracion "
              f"funcional (firma {sig[:10]}...)")
        for c in sorted(cores):
            flag = "  [!] ver aviso abajo" if c in all_warnings else ""
            print(f"      - {c}{flag}")
        canonical = sorted(cores)[0]
        print(f"      -> representante canonico sugerido: {canonical}")

    if all_warnings:
        print(f"\n  Avisos de filtrado:")
        for c, warns in all_warnings.items():
            for w in warns:
                print(f"      [{c}] {w}")

    if parse_fail:
        print(f"\n  [warn] no se pudo parsear (formato inesperado, revisar a mano): "
              f"{', '.join(parse_fail)}")
    if no_xci:
        print(f"\n  [aviso] sin .xci: {', '.join(no_xci)}")

    print(f"\n  Resumen: {len(dirs)} instancias -> {len(groups)} configuracion(es) "
          f"funcional(es) distinta(s) real(es)"
          + (f", {len(parse_fail)} sin parsear" if parse_fail else ""))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ip-root", type=Path, help="directorio raiz de las IPs (ej. ../ip)")
    ap.add_argument("--name", help="nombre de la IP (ej. dds_compiler_0)")
    ap.add_argument("--diff", nargs=2, type=Path, metavar=("XCI_A", "XCI_B"),
                     help="comparar dos .xci puntuales y mostrar que parametros difieren")
    ap.add_argument("--no-filter", action="store_true",
                     help="no filtrar los presets de frecuencia/fase (comparacion cruda)")
    args = ap.parse_args()

    if args.diff:
        cmd_diff(args)
    else:
        if not args.ip_root or not args.name:
            ap.error("especifica --ip-root y --name (o usa --diff A B)")
        cmd_analyze(args)


if __name__ == "__main__":
    main()
