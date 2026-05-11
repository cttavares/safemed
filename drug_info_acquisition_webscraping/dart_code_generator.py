"""
dart_code_generator.py
========================
Phase 3: Convert the enriched Infomed JSON into:
  1. A Dart source file with Medication(...) entries (static database)
  2. A runtime-loadable JSON in assets/ that the app reads dynamically

The generator maps Infomed fields → SafeMed Medication model fields.
For fields not available from Infomed (pregnancy category, min age), it
uses the heuristic data extracted from FI PDFs, then falls back to safe
defaults mapped from DCI name patterns.

Run (after pdf_leaflet_parser.py):
    python dart_code_generator.py [--input enriched|raw] [--max N]

Flags:
    --input enriched   Use medicamentos_infomed_enriched.json (default)
    --input raw        Use medicamentos_infomed.json (no PDF enrichment)
    --max N            Only emit first N medications (for testing)
    --assets-only      Only write the assets JSON, skip Dart file
"""

import argparse
import json
import re
import sys
import textwrap
from pathlib import Path

# ──────────────────────────── Paths ──────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent

OUTPUT_DIR = SCRIPT_DIR / "outputs"
ENRICHED_JSON = OUTPUT_DIR / "medicamentos_infomed_enriched.json"
RAW_JSON = OUTPUT_DIR / "medicamentos_infomed.json"

# Output Dart file
DART_DB_PATH = PROJECT_ROOT / "lib" / "data" / "medications_database_infarmed.dart"
# Output JSON for assets (runtime loading)
ASSETS_JSON_PATH = PROJECT_ROOT / "assets" / "medications_infarmed.json"

# ──────────────────────────── Pregnancy risk mapping ─────────────────────────
# DCI → known FDA pregnancy category (based on established pharmacology)
# This handles the majority of common medications without PDF data.

DCI_PREGNANCY_MAP: dict[str, str] = {
    # Category A
    "levotiroxina": "A",
    "ácido fólico": "A",
    "acido folico": "A",
    "ferro": "A",

    # Category B
    "paracetamol": "B",
    "amoxicilina": "B",
    "ampicilina": "B",
    "cefalexina": "B",
    "cefuroxima": "B",
    "azitromicina": "B",
    "metformina": "B",
    "insulina": "B",
    "prednisolona": "B",
    "hidrocortisona": "B",
    "loratadina": "B",
    "cetirizina": "B",
    "omeprazol": "B",
    "pantoprazol": "B",

    # Category C
    "ibuprofeno": "C",  # generally C in 1st/2nd trimester
    "tramadol": "C",
    "fluconazol": "C",
    "metronidazol": "C",
    "ciprofloxacina": "C",
    "levofloxacina": "C",
    "sertralina": "C",
    "fluoxetina": "C",
    "citalopram": "C",
    "escitalopram": "C",
    "amiodarona": "C",
    "amlodipina": "C",
    "atorvastatina": "C",
    "sinvastatina": "C",
    "furosemida": "C",
    "pseudoefedrina": "C",
    "dexametasona": "C",
    "prednisolona": "C",

    # Category D
    "ácido acetilsalicílico": "D",
    "acido acetilsalicilico": "D",
    "aspirina": "D",
    "diclofenaco": "D",
    "lisinopril": "D",
    "enalapril": "D",
    "ramipril": "D",
    "valsartan": "D",
    "losartan": "D",
    "diazepam": "D",
    "alprazolam": "D",
    "fenitoína": "D",
    "fenitoina": "D",
    "carbamazepina": "D",
    "ácido valpróico": "D",
    "acido valproico": "D",
    "tetraciclina": "D",
    "doxiciclina": "D",
    "sulfametoxazol": "D",

    # Category X
    "isotretinoína": "X",
    "isotretinoina": "X",
    "talidomida": "X",
    "varfarina": "X",
    "acenocumarol": "X",
    "metotrexato": "X",
    "misoprostol": "X",
    "finasterida": "X",
    "estatinas": "X",  # contraindicated in pregnancy as a class
}

# ──────────────────────────── Minimum age mapping ────────────────────────────
# DCI → known minimum age from product monographs

DCI_MIN_AGE_MAP: dict[str, int | None] = {
    "paracetamol": 0,       # safe for all ages (with appropriate dose)
    "ibuprofeno": 6,        # months (we store years → 0 = <1 year not ideal, use 0)
    "amoxicilina": 0,
    "ampicilina": 0,
    "azitromicina": 0,
    "cetirizina": 2,
    "loratadina": 2,
    "omeprazol": 1,
    "metformina": 10,
    "atorvastatina": 10,
    "lisinopril": 18,
    "varfarina": 18,
    "isotretinoína": 12,
    "isotretinoina": 12,
    "talidomida": 18,
    "diazepam": 0,
    "sertralina": 6,
    "fluoxetina": 8,
    "ácido acetilsalicílico": 12,
    "acido acetilsalicilico": 12,
    "diclofenaco": 14,
    "furosemida": 0,
    "amlodipina": 6,
    "prednisolona": 0,
}

# ──────────────────────────── MSRM → prescription flag ───────────────────────

def is_prescription(dispens_class: str) -> bool:
    """MSRM and MSRM-E require a prescription; MNSRM does not."""
    c = (dispens_class or "").upper()
    return c.startswith("MSRM")


# ──────────────────────────── Pregnancy risk resolver ────────────────────────

def resolve_pregnancy_risk(record: dict) -> str:
    """
    Priority order:
    1. PDF-extracted hint (pregnancyRiskHint) — validated from official leaflet
    2. DCI name lookup in our reference table
    3. Default: B (cautious, non-teratogenic assumption)
    """
    hint = record.get("pregnancyRiskHint", "")
    if hint and hint in ("A", "B", "C", "D", "X"):
        return hint

    dci_lower = (record.get("substanciaAtiva") or "").lower().strip()
    for key, cat in DCI_PREGNANCY_MAP.items():
        if key in dci_lower:
            return cat

    return "B"  # safe default


# ──────────────────────────── Min age resolver ────────────────────────────────

def resolve_min_age(record: dict) -> int | None:
    """
    Priority order:
    1. PDF-extracted hint (minAgeHint)
    2. DCI lookup
    3. None (no known restriction)
    """
    hint = record.get("minAgeHint")
    if isinstance(hint, int) and 0 <= hint <= 18:
        return hint

    dci_lower = (record.get("substanciaAtiva") or "").lower().strip()
    for key, age in DCI_MIN_AGE_MAP.items():
        if key in dci_lower:
            return age

    return None


# ──────────────────────────── ID generator ───────────────────────────────────

def make_id(record: dict, index: int) -> str:
    nome = re.sub(r"[^\w]", "_", (record.get("nomeComercial") or "med").lower())
    nome = re.sub(r"_+", "_", nome).strip("_")[:20]
    return f"inf_{index:05d}_{nome}"


# ──────────────────────────── Dart string helper ─────────────────────────────

def dart_str(s: str) -> str:
    """Escape a Python string for use as a Dart string literal."""
    if s is None:
        return "''"
    escaped = str(s).replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def dart_list(items: list[str]) -> str:
    if not items:
        return "const []"
    inner = ", ".join(dart_str(i) for i in items)
    return f"[{inner}]"


# ──────────────────────────── Record → Dart ───────────────────────────────────

def record_to_dart(record: dict, index: int) -> str:
    med_id = make_id(record, index)
    cnp = re.sub(r"\D", "", record.get("cnpem", "") or "")
    nome = (record.get("nomeComercial") or "").strip()
    forma = (record.get("formaFarmaceutica") or "").strip()
    substancia = (record.get("substanciaAtiva") or "").strip()
    dosagem = (record.get("dosagem") or "").strip()

    pregnancy = resolve_pregnancy_risk(record)
    min_age = resolve_min_age(record)
    prescription = is_prescription(record.get("dispensacaoClass", ""))

    # Adverse reactions → list (split on semicolons/newlines, take first 5)
    adverse_raw = record.get("adverseReactions", "") or ""
    adverse_lines = [l.strip() for l in re.split(r"[;\n•\-–—]", adverse_raw) if len(l.strip()) > 5][:5]

    # Warnings → contraindications keywords (simplified — we store the raw text in a separate field)
    # For the Dart model we extract key contraindication pathology IDs from known keywords
    contraind = []
    warnings_text = (record.get("warnings", "") or "").lower()
    if any(k in warnings_text for k in ["insuficiência renal", "doença renal", "renal"]):
        contraind.append("insuficiencia_renal")
    if any(k in warnings_text for k in ["insuficiência hepática", "doença hepática", "hepát"]):
        contraind.append("insuficiencia_hepatica")
    if any(k in warnings_text for k in ["úlcera", "hemorragia gastrointestinal"]):
        contraind.append("ulcera_gastrica")
    if any(k in warnings_text for k in ["asma", "broncoespasmo"]):
        contraind.append("asma")
    if any(k in warnings_text for k in ["hipertensão", "pressão arterial"]):
        contraind.append("hipertensao")
    if any(k in warnings_text for k in ["insuficiência cardíaca"]):
        contraind.append("insuficiencia_cardiaca")
    if any(k in warnings_text for k in ["diabetes"]):
        contraind.append("diabetes")

    min_age_dart = str(min_age) if min_age is not None else "null"

    return textwrap.dedent(f"""\
      Medication(
        id: {dart_str(med_id)},
        cnp: {dart_str(cnp)},
        nomeComercial: {dart_str(nome)},
        formaFarmaceutica: {dart_str(forma)},
        substanciaAtiva: {dart_str(substancia)},
        dosagem: {dart_str(dosagem)},
        riscoGravidez: PregnancyRiskCategory.{pregnancy},
        idadeMinima: {min_age_dart},
        sujeitoReceitaMedica: {str(prescription).lower()},
        contraindicacoes: {dart_list(contraind)},
        efeitosSecundariosComuns: {dart_list(adverse_lines)},
        interacoesComSubstancias: const [],
      )""")


# ──────────────────────────── Dart file generator ────────────────────────────

DART_HEADER = """\
// AUTO-GENERATED by dart_code_generator.py — DO NOT EDIT MANUALLY
// Source: Infomed (https://extranet.infarmed.pt/INFOMED-fo/)
// To regenerate: python drug_info_acquisition_webscraping/dart_code_generator.py

import 'package:safemed/models/medication.dart';

/// Base de dados de medicamentos obtida do Infomed (Infarmed, Portugal).
/// Gerada automaticamente a partir do scraper oficial.
const List<Medication> medicamentosInfarmed = [
"""

DART_FOOTER = """\
];

/// Look up by ID
Medication? getMedicationInfarmedById(String id) {
  try {
    return medicamentosInfarmed.firstWhere((m) => m.id == id);
  } catch (_) {
    return null;
  }
}

/// Search by name or active substance
List<Medication> searchInfarmed(String query) {
  final q = query.toLowerCase();
  return medicamentosInfarmed
      .where((m) =>
          m.nomeComercial.toLowerCase().contains(q) ||
          m.substanciaAtiva.toLowerCase().contains(q))
      .toList();
}
"""


def generate_dart(records: list[dict], max_count: int | None) -> str:
    subset = records[:max_count] if max_count else records
    entries = []
    for i, record in enumerate(subset):
        try:
            entries.append(record_to_dart(record, i + 1))
        except Exception as exc:
            print(f"  [WARN] Skipped record {i} ({record.get('nomeComercial', '?')}): {exc}",
                  file=sys.stderr)
    return DART_HEADER + ",\n\n".join(entries) + ",\n" + DART_FOOTER


# ──────────────────────────── Assets JSON generator ──────────────────────────

def generate_assets_json(records: list[dict], max_count: int | None) -> list[dict]:
    """
    Generate a cleaned JSON array suitable for runtime loading in the Flutter app.
    Each entry matches the Medication.fromJson() schema.
    """
    subset = records[:max_count] if max_count else records
    out = []
    for i, record in enumerate(subset):
        try:
            med_id = make_id(record, i + 1)
            cnp = re.sub(r"\D", "", record.get("cnpem", "") or "")
            entry = {
                "id": med_id,
                "cnp": cnp,
                "nomeComercial": (record.get("nomeComercial") or "").strip(),
                "formaFarmaceutica": (record.get("formaFarmaceutica") or "").strip(),
                "substanciaAtiva": (record.get("substanciaAtiva") or "").strip(),
                "dosagem": (record.get("dosagem") or "").strip(),
                "riscoGravidez": resolve_pregnancy_risk(record),
                "idadeMinima": resolve_min_age(record),
                "sujeitoReceitaMedica": is_prescription(record.get("dispensacaoClass", "")),
                "contraindicacoes": [],
                "efeitosSecundariosComuns": [],
                "interacoesComSubstancias": [],
                # Extended fields (not in Medication model but useful for UI)
                "titularAIM": (record.get("titularAIM") or "").strip(),
                "aimStatus": (record.get("aimStatus") or "").strip(),
                "pricePVP": record.get("pricePVP"),
                "isGeneric": (record.get("isGeneric") or "").strip(),
                "therapeuticIndications": (record.get("therapeuticIndications") or "").strip()[:2000],
                "warnings": (record.get("warnings") or "").strip()[:3000],
                "adverseReactions": (record.get("adverseReactions") or "").strip()[:2000],
                "howToStore": (record.get("howToStore") or "").strip()[:500],
                "pregnancyWarning": (record.get("pregnancyWarning") or "").strip()[:1000],
                "fiUrl": record.get("fiUrl", ""),
                "rcmUrl": record.get("rcmUrl", ""),
            }
            out.append(entry)
        except Exception as exc:
            print(f"  [WARN] Skipped asset record {i}: {exc}", file=sys.stderr)
    return out


# ──────────────────────────── Main ───────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Dart code from Infomed JSON")
    parser.add_argument("--input", choices=["enriched", "raw"], default="enriched",
                        help="Input JSON file (default: enriched)")
    parser.add_argument("--max", type=int, default=None,
                        help="Max number of medications to include")
    parser.add_argument("--assets-only", action="store_true",
                        help="Only write assets/medications_infarmed.json")
    args = parser.parse_args()

    json_path = ENRICHED_JSON if args.input == "enriched" else RAW_JSON
    if not json_path.exists():
        # Fall back to raw if enriched not found
        if args.input == "enriched" and RAW_JSON.exists():
            print("[WARN] Enriched JSON not found, using raw JSON instead.", file=sys.stderr)
            json_path = RAW_JSON
        else:
            print(f"[ERROR] {json_path} not found. Run the scraper first.", file=sys.stderr)
            sys.exit(1)

    with json_path.open(encoding="utf-8") as f:
        records: list[dict] = json.load(f)

    print(f"[*] Loaded {len(records)} records from {json_path.name}")

    # ── Assets JSON ──────────────────────────────────────────────────────────
    ASSETS_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    assets_data = generate_assets_json(records, args.max)
    with ASSETS_JSON_PATH.open("w", encoding="utf-8") as f:
        json.dump(assets_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Assets JSON → {ASSETS_JSON_PATH}  ({len(assets_data)} entries)")

    # ── Dart file ────────────────────────────────────────────────────────────
    if not args.assets_only:
        dart_code = generate_dart(records, args.max)
        DART_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        DART_DB_PATH.write_text(dart_code, encoding="utf-8")
        print(f"✅ Dart file   → {DART_DB_PATH}")


if __name__ == "__main__":
    main()
