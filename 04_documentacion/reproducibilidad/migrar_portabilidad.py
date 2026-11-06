#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
Migración controlada a rutas portables.
Proyecto: TESIS_SEQUIAS_UNCP_GITHUB

Modifica SOLO:
- la detección de ruta_base en los 7 notebooks finales;
- mensajes de rutas en celdas de salida/código;
- README.md;
- AUDITORIA_FINAL_REPRODUCIBILIDAD.md;
- verificar_reproducibilidad.R;
- AUDITORIA_RESUMEN.txt.

NO modifica archivos *_ORIGINAL ni evidencia forense.
Crea un .bak antes de modificar cada archivo.
'''

from pathlib import Path
import argparse
import csv
import json
import re
import shutil
import sys
from datetime import datetime

ROOT_OLD_FWD = "D:/TESIS_SEQUIAS_UNCP_GITHUB"
ROOT_OLD_BCK = r"D:\TESIS_SEQUIAS_UNCP_GITHUB"
HIST_OLD_BCK = r"H:\RESPALDO_USB_ANTES_SSD\PROYECTO_SEQUIAS_COPULAS_UNCP"
HIST_OLD_FWD = "H:/RESPALDO_USB_ANTES_SSD/PROYECTO_SEQUIAS_COPULAS_UNCP"

PORTABLE_R_NOTEBOOK = r'''encontrar_raiz_proyecto <- function(inicio = getwd()) {
  marcadores <- c("01_datos", "02_scripts", "03_resultados", "04_documentacion")
  es_raiz <- function(x) all(dir.exists(file.path(x, marcadores)))

  raiz_env <- Sys.getenv("TESIS_SEQUIAS_ROOT", unset = "")
  if (nzchar(raiz_env)) {
    raiz_env <- normalizePath(raiz_env, winslash = "/", mustWork = FALSE)
    if (es_raiz(raiz_env)) return(raiz_env)
  }

  ruta <- normalizePath(inicio, winslash = "/", mustWork = TRUE)

  repeat {
    if (es_raiz(ruta)) return(ruta)

    padre <- dirname(ruta)
    if (identical(padre, ruta)) {
      stop(
        "No se encontró la raíz del proyecto. ",
        "Ejecute Jupyter dentro del repositorio o defina TESIS_SEQUIAS_ROOT."
      )
    }

    ruta <- padre
  }
}

ruta_base <- encontrar_raiz_proyecto()'''

PORTABLE_R_AUDITOR = r'''obtener_directorio_script <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  arg_file <- grep("^--file=", args, value = TRUE)

  if (length(arg_file) > 0) {
    archivo <- sub("^--file=", "", arg_file[1])
    return(dirname(normalizePath(archivo, winslash = "/", mustWork = TRUE)))
  }

  getwd()
}

encontrar_raiz_proyecto <- function(inicio = obtener_directorio_script()) {
  marcadores <- c("01_datos", "02_scripts", "03_resultados", "04_documentacion")
  es_raiz <- function(x) all(dir.exists(file.path(x, marcadores)))

  raiz_env <- Sys.getenv("TESIS_SEQUIAS_ROOT", unset = "")
  if (nzchar(raiz_env)) {
    raiz_env <- normalizePath(raiz_env, winslash = "/", mustWork = FALSE)
    if (es_raiz(raiz_env)) return(raiz_env)
  }

  ruta <- normalizePath(inicio, winslash = "/", mustWork = TRUE)

  repeat {
    if (es_raiz(ruta)) return(ruta)

    padre <- dirname(ruta)
    if (identical(padre, ruta)) {
      stop(
        "No se encontró la raíz del proyecto. ",
        "Defina TESIS_SEQUIAS_ROOT si ejecuta el script fuera del repositorio."
      )
    }

    ruta <- padre
  }
}

ruta_base <- encontrar_raiz_proyecto()'''

NOTEBOOKS = [
    ("01_regionalizacion",
     "02_scripts/01_regionalizacion/01_analisis_cluster_estaciones.ipynb"),
    ("02_nspei_eventos",
     "02_scripts/02_nspei_eventos/02_nspei_eventos_por_estacion_y_cluster_TESIS.ipynb"),
    ("03_marginales",
     "02_scripts/03_marginales/03_ajuste_marginales_nspei3.ipynb"),
    ("04_copulas",
     "02_scripts/04_copulas/04_ajuste_copulas_nspei3.ipynb"),
    ("05_periodos_retorno",
     "02_scripts/05_periodos_retorno/05_periodos_retorno_and_or_nspei3.ipynb"),
    ("06_riesgo_condicional",
     "02_scripts/06_riesgo_condicional/06_riesgo_condicional_nspei3.ipynb"),
    ("07_montecarlo",
     "02_scripts/07_montecarlo/07_prediccion_montecarlo_nspei3.ipynb"),
]

PUBLIC_TEXT_FILES = [
    "README.md",
    "04_documentacion/reproducibilidad/AUDITORIA_FINAL_REPRODUCIBILIDAD.md",
    "04_documentacion/reproducibilidad/AUDITORIA_RESUMEN.txt",
]

FORENSIC_PATTERNS = (
    "_ORIGINAL",
    "_PRE_ADAPTACION",
    "CELDAS_",
    "CODIGO_COPULAS_ORIGINAL_EXTRAIDO",
    "AUDITORIA_BLOQUE01_CODIGO",
)

SCAN_EXTENSIONS = {".R", ".Rmd", ".qmd", ".ipynb", ".md", ".txt", ".csv"}

PRIVATE_PATTERNS = [
    re.compile(r"/Volumes/USB", re.I),
    re.compile(r"/Users/virgilio", re.I),
    re.compile(r"C:\\Users\\DELL", re.I),
    re.compile(re.escape(ROOT_OLD_FWD), re.I),
    re.compile(re.escape(ROOT_OLD_BCK), re.I),
    re.compile(r"H:\\RESPALDO_USB_ANTES_SSD", re.I),
    re.compile(r"H:/RESPALDO_USB_ANTES_SSD", re.I),
    re.compile(r"PROYECTO_SEQUIAS_COPULAS_UNCP", re.I),
]


def backup(path: Path) -> Path:
    b = Path(str(path) + ".bak")
    if not b.exists():
        shutil.copy2(path, b)
    return b


def source_to_text(source):
    if isinstance(source, list):
        return "".join(source)
    return source or ""


def text_to_source(text, original_source):
    if isinstance(original_source, list):
        return text.splitlines(keepends=True)
    return text


def recursive_replace_strings(obj, replacements):
    if isinstance(obj, str):
        for old, new in replacements:
            obj = obj.replace(old, new)
        return obj
    if isinstance(obj, list):
        return [recursive_replace_strings(x, replacements) for x in obj]
    if isinstance(obj, dict):
        return {k: recursive_replace_strings(v, replacements) for k, v in obj.items()}
    return obj


def patch_notebook(path: Path, block: str):
    with path.open("r", encoding="utf-8") as f:
        nb = json.load(f)

    changed = 0

    for cell in nb.get("cells", []):
        original_source = cell.get("source", [])
        text = source_to_text(original_source)
        new = text

        pattern_root = re.compile(
            r'^[ \t]*ruta_base\s*<-\s*["\']D:/TESIS_SEQUIAS_UNCP_GITHUB["\']'
            r'[^\n]*$',
            re.MULTILINE
        )
        if pattern_root.search(new):
            new = pattern_root.sub(PORTABLE_R_NOTEBOOK, new)

        new = new.replace(
            "D:/TESIS_SEQUIAS_UNCP_GITHUB/01_datos/raw/Base_Datos_Final_ETo_Pivot.csv",
            "01_datos/raw/Base_Datos_Final_ETo_Pivot.csv"
        )

        if block in {"04_copulas", "05_periodos_retorno",
                     "06_riesgo_condicional", "07_montecarlo"}:
            new = re.sub(
                r'cat\("Ruta tablas:",\s*ruta_tablas,\s*"\\n"\)',
                f'cat("Ruta tablas:", file.path("03_resultados", "{block}", "tablas"), "\\n")',
                new
            )
            new = re.sub(
                r'cat\("Ruta figuras:",\s*ruta_figuras,\s*"\\n"\)',
                f'cat("Ruta figuras:", file.path("03_resultados", "{block}", "figuras"), "\\n")',
                new
            )

        if new != text:
            cell["source"] = text_to_source(new, original_source)
            changed += 1

    nb = recursive_replace_strings(
        nb,
        [
            (ROOT_OLD_FWD, "<RAIZ_PROYECTO>"),
            (ROOT_OLD_BCK, "<RAIZ_PROYECTO>"),
        ]
    )

    backup(path)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
        f.write("\n")

    return changed


def patch_auditor(path: Path):
    text = path.read_text(encoding="utf-8")
    new = text

    pattern = re.compile(
        r'ruta_base\s*<-\s*Sys\.getenv\(\s*'
        r'"TESIS_SEQUIAS_ROOT",\s*'
        r'unset\s*=\s*"D:/TESIS_SEQUIAS_UNCP_GITHUB"\s*'
        r'\)',
        re.MULTILINE
    )

    if not pattern.search(new):
        raise RuntimeError(
            "No se encontró el bloque esperado de ruta_base en verificar_reproducibilidad.R"
        )

    new = pattern.sub(PORTABLE_R_AUDITOR, new)

    new = new.replace(
        'paste("Raíz:", ruta_base),',
        '"Raíz: detectada automáticamente",'
    )

    backup(path)
    path.write_text(new, encoding="utf-8", newline="\n")


def patch_public_text(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    new = text

    new = new.replace(ROOT_OLD_FWD, "<RAIZ_REPOSITORIO>")
    new = new.replace(ROOT_OLD_BCK, "<RAIZ_REPOSITORIO>")

    new = new.replace(
        HIST_OLD_BCK,
        "[FUENTE_HISTORICA_PRIVADA_NO_PUBLICADA]"
    )
    new = new.replace(
        HIST_OLD_FWD,
        "[FUENTE_HISTORICA_PRIVADA_NO_PUBLICADA]"
    )

    if path.name == "AUDITORIA_RESUMEN.txt":
        lines = []
        for line in new.splitlines():
            if line.startswith("Raíz:"):
                lines.append("Raíz: detectada automáticamente")
            else:
                lines.append(line)
        new = "\n".join(lines) + "\n"

    if new != text:
        backup(path)
        path.write_text(new, encoding="utf-8", newline="\n")
        return True
    return False


def is_forensic(path: Path):
    name = path.name
    return any(p in name for p in FORENSIC_PATTERNS) or name.endswith(".bak")


def scan_public(root: Path):
    findings = []

    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if is_forensic(path):
            continue
        if path.suffix not in SCAN_EXTENSIONS:
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        for line_no, line in enumerate(text.splitlines(), start=1):
            if any(rx.search(line) for rx in PRIVATE_PATTERNS):
                findings.append(
                    (str(path.relative_to(root)), line_no, line.strip()[:300])
                )

    return findings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        help="Raíz del repositorio. Si se omite, se infiere desde la ubicación de este script."
    )
    args = parser.parse_args()

    if args.root:
        root = Path(args.root).expanduser().resolve()
    else:
        root = Path(__file__).resolve().parents[2]

    markers = ["01_datos", "02_scripts", "03_resultados", "04_documentacion"]
    if not all((root / x).is_dir() for x in markers):
        print("ERROR: no se reconoció la raíz del repositorio:", root)
        print(r'Use: python migrar_portabilidad.py --root D:\TESIS_SEQUIAS_UNCP_GITHUB')
        sys.exit(2)

    report = []

    print("=" * 68)
    print("MIGRACIÓN CONTROLADA A RUTAS PORTABLES")
    print("=" * 68)
    print("Raíz detectada:", root)
    print()

    for block, rel in NOTEBOOKS:
        path = root / rel
        if not path.exists():
            print("FALTA:", rel)
            report.append([rel, "FALTA", "0"])
            continue

        n = patch_notebook(path, block)
        print(f"OK notebook: {rel} | celdas fuente modificadas: {n}")
        report.append([rel, "OK", str(n)])

    auditor = root / "04_documentacion/reproducibilidad/verificar_reproducibilidad.R"
    if auditor.exists():
        patch_auditor(auditor)
        print("OK auditor :", auditor.relative_to(root))
        report.append([str(auditor.relative_to(root)), "OK", "ruta portable"])
    else:
        print("FALTA auditor:", auditor)
        report.append([str(auditor.relative_to(root)), "FALTA", ""])

    for rel in PUBLIC_TEXT_FILES:
        path = root / rel
        if path.exists():
            changed = patch_public_text(path)
            print(
                "OK texto   :",
                rel,
                "| actualizado" if changed else "| sin cambios"
            )
            report.append([rel, "OK", "actualizado" if changed else "sin cambios"])

    report_path = root / "04_documentacion/reproducibilidad/AUDITORIA_MIGRACION_PORTABLE.csv"
    with report_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["archivo", "estado", "detalle"])
        w.writerows(report)

    findings = scan_public(root)

    print()
    print("=" * 68)
    print("CONTROL FINAL DE RUTAS PÚBLICAS")
    print("=" * 68)

    if findings:
        print(f"Quedan {len(findings)} coincidencias por revisar:")
        for rel, line_no, line in findings[:100]:
            print(f"- {rel}:{line_no} | {line}")
        result = "PENDIENTE"
    else:
        print("0 coincidencias de rutas privadas/absolutas en archivos públicos.")
        result = "APROBADO"

    summary = root / "04_documentacion/reproducibilidad/AUDITORIA_PORTABILIDAD_RESUMEN.txt"
    summary.write_text(
        "\n".join([
            "AUDITORÍA DE PORTABILIDAD",
            f"Fecha: {datetime.now():%Y-%m-%d %H:%M:%S}",
            "Raíz: detectada automáticamente",
            f"Coincidencias pendientes: {len(findings)}",
            f"RESULTADO: {result}",
            "",
        ]),
        encoding="utf-8"
    )

    print()
    print("Reporte:", report_path.relative_to(root))
    print("Resumen:", summary.relative_to(root))
    print()
    print("RESULTADO DE PORTABILIDAD:", result)


if __name__ == "__main__":
    main()
