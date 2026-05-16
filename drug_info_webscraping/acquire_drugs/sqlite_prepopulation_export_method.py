import json
from pathlib import Path
import sqlite3

from utils import import_table_from_json, import_informative_bill_from_json

OUTPUT_DIR = Path(__file__).parent.parent / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = OUTPUT_DIR / "meds_infomed.sqlite"


def create_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = OFF;")
    return conn


def create_tables(conn: sqlite3.Connection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            n_registo INTEGER,
            dci TEXT NOT NULL,
            nome_medicamento TEXT NOT NULL,
            forma_farmaceutica TEXT,
            dosagem TEXT,
            tamanho_embalagem TEXT,
            cnpem INTEGER,
            price_pvp TEXT,
            price_pvp_notified TEXT,
            price_utente TEXT,
            price_pensionist TEXT,
            commercialized TEXT,
            is_generic INTEGER,
            info_url TEXT UNIQUE
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS informative_bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dci TEXT NOT NULL,
            medicamento TEXT NOT NULL,
            pdf_url TEXT,
            indicacoes_json TEXT,
            efeitos_json TEXT,
            conservacao TEXT,
            aviso_critico TEXT,
            source_key TEXT UNIQUE
        )
    """)

    conn.execute("CREATE INDEX IF NOT EXISTS idx_medications_dci ON medications(dci)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_medications_nome ON medications(nome_medicamento)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_bills_dci ON informative_bills(dci)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_bills_medicamento ON informative_bills(medicamento)")


def insert_medications(conn: sqlite3.Connection, records: list[dict]) -> None:
    rows = []
    for record in records:
        rows.append((
            record.get("nRegisto"),
            record.get("dci", ""),
            record.get("nome_medicamento", ""),
            record.get("forma_farmaceutica", ""),
            record.get("dosagem", ""),
            record.get("tamanho_embalagem", ""),
            record.get("cnpem"),
            record.get("pricePVP", ""),
            record.get("pricePVPnotified", ""),
            record.get("priceUtente", ""),
            record.get("pricePensionist", ""),
            record.get("commercialized", ""),
            1 if record.get("isGeneric") else 0,
            record.get("infoUrl", ""),
        ))

    conn.executemany("""
        INSERT OR REPLACE INTO medications (
            n_registo, dci, nome_medicamento, forma_farmaceutica, dosagem,
            tamanho_embalagem, cnpem, price_pvp, price_pvp_notified,
            price_utente, price_pensionist, commercialized, is_generic, info_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, rows)


def insert_informative_bills(conn: sqlite3.Connection, records: list[dict]) -> None:
    rows = []
    for record in records:
        info_pdf = record.get("info_pdf", {})
        if not isinstance(info_pdf, dict):
            info_pdf = {}

        rows.append((
            record.get("dci", ""),
            record.get("medicamento", ""),
            record.get("pdf_url", ""),
            json.dumps(info_pdf.get("indicacoes", []), ensure_ascii=False),
            json.dumps(info_pdf.get("efeitos_indesejaveis", {}), ensure_ascii=False),
            info_pdf.get("conservacao", ""),
            info_pdf.get("aviso_critico", ""),
            f"{record.get('dci', '')}|{record.get('medicamento', '')}",
        ))

    conn.executemany("""
        INSERT OR REPLACE INTO informative_bills (
            dci, medicamento, pdf_url, indicacoes_json, efeitos_json,
            conservacao, aviso_critico, source_key
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, rows)


def export_sqlite_database() -> None:
    try:
        medications = import_table_from_json()
        informative_bills = import_informative_bill_from_json()
    except Exception as e:
        print(f"  [ERRO] Erro ao importar dados: {e}")
        return

    conn = create_connection()
    try:
        create_tables(conn)
        insert_medications(conn, medications)
        insert_informative_bills(conn, informative_bills)
        conn.commit()
        print(f"✓ SQLite exportado para {DB_PATH}")
    finally:
        conn.close()


if __name__ == "__main__":
    export_sqlite_database()