"""
flutter_exporter.py
====================
Converts the scraper outputs (table + informative bill Gemini summaries) into
the JSON asset format consumed by Flutter's InfarmedMedicationService.

Expected Flutter asset schema (assets/medications_infarmed.json):
[
  {
    "id": str,                       <- nRegisto as string
    "cnp": str,                      <- cnpem as string
    "nomeComercial": str,            <- nome_medicamento
    "formaFarmaceutica": str,        <- forma_farmaceutica
    "substanciaAtiva": str,          <- dci
    "dosagem": str,                  <- dosagem
    "riscoGravidez": str,            <- "B" default (not in scraper data)
    "idadeMinima": int | null,       <- null (not in scraper data)
    "sujeitoReceitaMedica": bool,    <- false default (not in scraper data)
    "contraindicacoes": [],          <- from Gemini efeitos_indesejaveis.outros
    "efeitosSecundariosComuns": [],  <- from Gemini efeitos_indesejaveis.frequentes
    "titularAIM": str,               <- "" (not in new scraper schema)
    "aimStatus": str,                <- "Autorizado" (all results are authorized)
    "pricePVP": float | null,        <- parsed from pricePVP string
    "isGeneric": str,                <- "Sim" / "Não"
    "therapeuticIndications": str,   <- from Gemini indicacoes joined
    "warnings": str,                 <- from Gemini aviso_critico
    "adverseReactions": str,         <- from Gemini all efeitos_indesejaveis joined
    "howToStore": str,               <- from Gemini conservacao
    "pregnancyWarning": str,         <- from Gemini aviso_critico (reused)
    "fiUrl": str,                    <- infoUrl (detail page; FI PDF not directly scraped)
    "rcmUrl": str,                   <- "" (not in new scraper schema)
  },
  ...
]

Scraper table schema (medicamentos_infomed.json records):
  nRegisto, dci, nome_medicamento, forma_farmaceutica, dosagem,
  tamanho_embalagem, cnpem, pricePVP, pricePVPnotified, priceUtente,
  pricePensionist, commercialized, isGeneric (bool), infoUrl

Informative bill schema (informative_bill_per_dci.json records):
  dci, medicamento, pdf_url,
  info_pdf: {
    dci, medicamento,
    indicacoes: [],
    efeitos_indesejaveis: { frequentes: [], outros: [] },
    conservacao: str,
    aviso_critico: str,
    resumo: str   <- fallback if Gemini returned raw text
  }
"""

import json
import re
from pathlib import Path
from typing import Iterable

# ── Path to Flutter assets folder (two levels up from acquire_drugs/) ──────────
_REPO_ROOT = Path(__file__).parent.parent.parent   # drug_info_webscraping/../.. = safemed/
FLUTTER_ASSET_PATH = _REPO_ROOT / "assets" / "medications_infarmed.json"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_pvp(raw: str | None) -> float | None:
    """Convert '€ 2,51' or 'preço livre' or '' to float or None."""
    if not raw:
        return None
    text = raw.strip()
    if not text or "preço livre" in text.lower() or "preco livre" in text.lower():
        return None
    # Remove currency symbol and thousands separators, normalise decimal comma
    text = re.sub(r"[€\s]", "", text)
    text = text.replace(".", "").replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return None


def _join_list(items: list | None, separator: str = "; ") -> str:
    """Join a list of strings into a single string."""
    if not items or not isinstance(items, list):
        return ""
    return separator.join(str(i).strip() for i in items if str(i).strip())


def _build_dci_index(fi_records: Iterable[dict]) -> dict[str, dict]:
    """Build a lookup {normalised_dci -> fi_record} for fast merging."""
    index: dict[str, dict] = {}
    for record in fi_records:
        raw_dci = str(record.get("dci", "")).strip()
        key = raw_dci.casefold()
        if key and key not in index:
            index[key] = record
    return index


def _extract_clinical(fi_record: dict | None) -> dict:
    """Pull clinical fields out of a Gemini summary record."""
    if not fi_record:
        return {
            "therapeuticIndications": "",
            "warnings": "",
            "adverseReactions": "",
            "howToStore": "",
            "pregnancyWarning": "",
        }

    info_pdf = fi_record.get("info_pdf", {})

    # Gemini sometimes returns a nested JSON string under "resumo" when it
    # couldn't produce clean JSON — try to parse it.
    if isinstance(info_pdf, dict) and "resumo" in info_pdf and len(info_pdf) == 1:
        raw_resumo = info_pdf["resumo"]
        try:
            parsed = json.loads(raw_resumo)
            if isinstance(parsed, dict):
                info_pdf = parsed
        except Exception:
            pass

    # indicacoes
    indicacoes = info_pdf.get("indicacoes", [])
    therapeutic = _join_list(indicacoes)

    # efeitos_indesejaveis
    efeitos = info_pdf.get("efeitos_indesejaveis", {})
    if isinstance(efeitos, dict):
        frequentes = efeitos.get("frequentes", [])
        outros = efeitos.get("outros", [])
        pouco_freq = efeitos.get("pouco_frequentes", [])
        raros = efeitos.get("raros", [])
        adverse_all = frequentes + pouco_freq + raros + outros
    else:
        frequentes = []
        adverse_all = []

    aviso_critico = str(info_pdf.get("aviso_critico", "")).strip()
    conservacao = str(info_pdf.get("conservacao", "")).strip()

    return {
        "therapeuticIndications": therapeutic,
        "warnings": aviso_critico,
        "adverseReactions": _join_list(adverse_all),
        "howToStore": conservacao,
        "pregnancyWarning": aviso_critico,   # best available proxy
        # efeitosSecundariosComuns and contraindicacoes stay separate
        "_frequentes": frequentes,
        "_outros": [str(o) for o in outros],
    }


def _convert_record(table_record: dict, fi_record: dict | None) -> dict:
    """Map one scraper table row + its Gemini data to the Flutter schema."""
    clinical = _extract_clinical(fi_record)

    is_generic_raw = table_record.get("isGeneric", False)
    is_generic_str = "Sim" if is_generic_raw is True else "Não"

    # Prefer non-empty price: PVP first, then PVPnotified
    pvp = _parse_pvp(table_record.get("pricePVP"))
    if pvp is None:
        pvp = _parse_pvp(table_record.get("pricePVPnotified"))

    n_registo = table_record.get("nRegisto", 0)
    cnpem = table_record.get("cnpem", 0)

    return {
        "id": str(n_registo),
        "cnp": str(cnpem),
        "nomeComercial": str(table_record.get("nome_medicamento", "")).strip(),
        "formaFarmaceutica": str(table_record.get("forma_farmaceutica", "")).strip(),
        "substanciaAtiva": str(table_record.get("dci", "")).strip(),
        "dosagem": str(table_record.get("dosagem", "")).strip(),
        "riscoGravidez": "B",          # not available from scraper
        "idadeMinima": None,            # not available from scraper
        "sujeitoReceitaMedica": False,  # not available from scraper
        "contraindicacoes": clinical.get("_outros", []),
        "efeitosSecundariosComuns": clinical.get("_frequentes", []),
        "titularAIM": "",               # not in new scraper schema
        "aimStatus": "Autorizado",
        "pricePVP": pvp,
        "isGeneric": is_generic_str,
        "therapeuticIndications": clinical["therapeuticIndications"],
        "warnings": clinical["warnings"],
        "adverseReactions": clinical["adverseReactions"],
        "howToStore": clinical["howToStore"],
        "pregnancyWarning": clinical["pregnancyWarning"],
        "fiUrl": str(table_record.get("infoUrl", "")).strip(),
        "rcmUrl": "",                   # not in new scraper schema
    }


# ── Public API ────────────────────────────────────────────────────────────────

def export_to_flutter(
    table_records: Iterable[dict],
    fi_records: Iterable[dict],
    output_path: Path | None = None,
) -> int:
    """Convert scraper outputs to Flutter asset JSON and write to disk.

    Parameters
    ----------
    table_records : list[dict]
        Records from medicamentos_infomed.json (table_scrapper output).
    fi_records : list[dict]
        Records from informative_bill_per_dci.json (Gemini summaries).
    output_path : Path, optional
        Override the default assets/medications_infarmed.json location.

    Returns
    -------
    int
        Number of medication records written.
    """
    dest = Path(output_path) if output_path else FLUTTER_ASSET_PATH
    dest.parent.mkdir(parents=True, exist_ok=True)

    dci_index = _build_dci_index(fi_records)

    flutter_records: list[dict] = []
    seen_ids: set[str] = set()

    for record in table_records:
        dci_key = str(record.get("dci", "")).strip().casefold()
        fi_record = dci_index.get(dci_key)
        converted = _convert_record(record, fi_record)

        # Deduplicate by nRegisto (unique per presentation)
        record_id = converted["id"]
        if record_id in seen_ids:
            continue
        seen_ids.add(record_id)

        flutter_records.append(converted)

    with dest.open("w", encoding="utf-8") as f:
        json.dump(flutter_records, f, ensure_ascii=False, indent=2)

    print(f"✓ Flutter asset escrito em: {dest}")
    print(f"  {len(flutter_records)} medicamentos exportados.")
    return len(flutter_records)
