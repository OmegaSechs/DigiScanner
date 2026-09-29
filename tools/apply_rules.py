#!/usr/bin/env python3
"""Aplica tools/rules.csv em cards.max_copies / cards.banned.

O CSV é a fonte da verdade: TODAS as cartas voltam para (4, não banida) e depois
as linhas do CSV são aplicadas. Rode de novo sempre que a lista oficial mudar.

  pip install "psycopg[binary]"
  export DATABASE_URL=postgresql://...
  python tools/apply_rules.py --dry-run
  python tools/apply_rules.py
"""
import argparse, csv, os, sys
from pathlib import Path

CSV_PATH = Path(__file__).parent / "rules.csv"


def load_rules(path=CSV_PATH):
    lines = [l for l in Path(path).read_text(encoding="utf-8").splitlines()
             if l.strip() and not l.lstrip().startswith("#")]
    rules = []
    for i, row in enumerate(csv.DictReader(lines), start=2):
        code = (row.get("code") or "").strip().upper()
        if not code:
            raise ValueError(f"linha {i}: código vazio")
        try:
            max_copies = int(row["max_copies"])
        except (KeyError, ValueError):
            raise ValueError(f"linha {i} ({code}): max_copies inválido")
        if max_copies < 0:
            raise ValueError(f"linha {i} ({code}): max_copies negativo")
        banned = (row.get("banned") or "").strip().lower()
        if banned not in ("true", "false"):
            raise ValueError(f"linha {i} ({code}): banned deve ser true ou false")
        rules.append((code, max_copies, banned == "true"))
    return rules


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    rules = load_rules()
    print(f"{len(rules)} regras: " + ", ".join(f"{c}(max {m}{', banida' if b else ''})" for c, m, b in rules))
    if a.dry_run:
        return
    import psycopg
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
        cur.execute("update cards set max_copies = 4, banned = false")
        missing = []
        for code, m, b in rules:
            cur.execute("update cards set max_copies=%s, banned=%s where code=%s", (m, b, code))
            if cur.rowcount == 0:
                missing.append(code)
    print("Regras aplicadas." + (f" Códigos não encontrados no catálogo: {', '.join(missing)}" if missing else ""))


if __name__ == "__main__":
    main()
