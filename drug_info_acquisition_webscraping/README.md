# Infarmed Medication Scraper Pipeline

Automated pipeline to scrape the official Portuguese medication registry ([Infomed Extranet](https://extranet.infarmed.pt/INFOMED-fo/)) and integrate the data into the SafeMed Flutter app.

## Quick Start

```powershell
# 1. Install dependencies (one-time)
.\install_pip_dependencies.bat

# 2. Run full pipeline
python run_pipeline.py

# 3. Rebuild Flutter app to include updated assets
flutter pub get && flutter run
```

## Individual Phases

### Phase 1 — Table Scraper
```powershell
# Scrape all ~9,639 authorized medications (takes ~30-60 min)
python infarmed_scraper.py

# Test run (3 pages = ~200 records)
python infarmed_scraper.py --pages 3 --skip-detail --no-headless

# Resume from checkpoint (if interrupted)
python infarmed_scraper.py --resume

# Show browser window (useful for debugging)
python infarmed_scraper.py --no-headless
```

**Output:** `outputs/medicamentos_infomed.csv` and `outputs/medicamentos_infomed.json`

### Phase 2 — PDF Leaflet Parser
```powershell
# Enrich scraped data with clinical info from Patient Leaflets (FI PDFs)
python pdf_leaflet_parser.py

# Use 8 parallel workers for faster processing
python pdf_leaflet_parser.py --workers 8

# Test with first 50 records
python pdf_leaflet_parser.py --limit 50
```

**Output:** `outputs/medicamentos_infomed_enriched.json`

### Phase 3 — Dart/Assets Generator
```powershell
# Generate assets JSON and Dart file from enriched data
python dart_code_generator.py

# Use raw data (if Phase 2 was skipped)
python dart_code_generator.py --input raw

# Generate only the assets JSON (skip Dart static file)
python dart_code_generator.py --assets-only
```

**Output:**
- `../assets/medications_infarmed.json` (loaded at runtime by the app)
- `../lib/data/medications_database_infarmed.dart` (optional static Dart file)

## Architecture

```
Infomed Portal
     │
     ▼
infarmed_scraper.py ──────► outputs/medicamentos_infomed.json
     │
     ▼
pdf_leaflet_parser.py ────► outputs/medicamentos_infomed_enriched.json
     │                       (+ outputs/pdfs/ — cached PDF files)
     ▼
dart_code_generator.py ───► assets/medications_infarmed.json
                             lib/data/medications_database_infarmed.dart
```

## Flutter Integration

The app loads medications at startup via `InfarmedMedicationService`:

```dart
// main.dart — already integrated:
await infarmedMedicationService.init();

// Search anywhere in the app:
final results = infarmedMedicationService.search('paracetamol');
final byCode = infarmedMedicationService.findByCnpem('636382');
```

The `MedicationExplorerService` (used by camera/OCR features) automatically
searches the Infarmed database alongside the existing PT/BR dictionaries.

## Data Fields

| Field | Source | Description |
|-------|--------|-------------|
| `nomeComercial` | Table col 1 | Commercial brand name |
| `substanciaAtiva` | Table col 2 | Active substance (DCI) |
| `formaFarmaceutica` | Table col 3 | Pharmaceutical form |
| `dosagem` | Table col 4 | Dosage/strength |
| `titularAIM` | Table col 5 | Marketing authorization holder |
| `cnpem` | Table col 0 | Portuguese drug registry code |
| `fiUrl` | Table col 7 | Patient Leaflet PDF URL |
| `rcmUrl` | Table col 7 | Summary of Product Characteristics PDF URL |
| `therapeuticIndications` | Phase 2 (PDF) | Indications extracted from FI |
| `warnings` | Phase 2 (PDF) | Warnings extracted from FI |
| `adverseReactions` | Phase 2 (PDF) | Adverse reactions from FI |
| `pregnancyWarning` | Phase 2 (PDF) | Pregnancy/breastfeeding paragraph |
| `pregnancyRiskHint` | Phase 2 (PDF) | Heuristic FDA category (A/B/C/D/X) |
| `minAgeHint` | Phase 2 (PDF) | Minimum age extracted from FI |

## Known Limitations

- The portal shows **~9,639 authorized medications** (AIM status = Autorizado).
- Detail page visits require JSF state (back-navigation) — use `--skip-detail` for speed.
- Pregnancy risk categories and minimum ages are **heuristic** (extracted from PDF text);
  verify critical values against official sources.
- The FI PDF download is rate-limited — Phase 2 uses 4 parallel workers by default.
