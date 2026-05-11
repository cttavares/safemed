"""
run_pipeline.py
================
Convenience script to run all three scraper phases in sequence.

Usage:
    python run_pipeline.py [--phase 1|2|3|all] [--pages N] [--workers N]

Defaults:
    --phase all     Run all phases (1 → 2 → 3)
    --pages None    Scrape all pages (Phase 1)
    --workers 4     Parallel PDF workers (Phase 2)
"""

import argparse
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent


def run(cmd: list[str], label: str) -> int:
    print(f"\n{'='*60}")
    print(f"  PHASE: {label}")
    print(f"{'='*60}\n")
    result = subprocess.run([sys.executable] + cmd, cwd=SCRIPT_DIR)
    return result.returncode


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the full Infarmed scraper pipeline")
    parser.add_argument("--phase", choices=["1", "2", "3", "all"], default="all")
    parser.add_argument("--pages", type=int, default=None,
                        help="Max pages for Phase 1 (default: all)")
    parser.add_argument("--workers", type=int, default=4,
                        help="PDF worker threads for Phase 2")
    parser.add_argument("--no-headless", action="store_true",
                        help="Show browser window during Phase 1")
    parser.add_argument("--resume", action="store_true",
                        help="Resume Phase 1 from last checkpoint")
    parser.add_argument("--skip-detail", action="store_true",
                        help="Skip detail page visits in Phase 1 (faster)")
    args = parser.parse_args()

    phases = ["1", "2", "3"] if args.phase == "all" else [args.phase]

    for phase in phases:
        if phase == "1":
            cmd = ["infarmed_scraper.py"]
            if args.pages:
                cmd += ["--pages", str(args.pages)]
            if args.no_headless:
                cmd += ["--no-headless"]
            if args.resume:
                cmd += ["--resume"]
            if args.skip_detail:
                cmd += ["--skip-detail"]
            rc = run(cmd, "1 — Table Scraper (Infomed)")

        elif phase == "2":
            cmd = ["pdf_leaflet_parser.py", "--workers", str(args.workers)]
            rc = run(cmd, "2 — PDF Leaflet Parser")

        elif phase == "3":
            cmd = ["dart_code_generator.py"]
            rc = run(cmd, "3 — Dart / Assets JSON Generator")

        if rc != 0:
            print(f"\n[ERROR] Phase {phase} exited with code {rc}. Stopping.", file=sys.stderr)
            sys.exit(rc)

    print("\n✅ All selected phases completed successfully.")


if __name__ == "__main__":
    main()
