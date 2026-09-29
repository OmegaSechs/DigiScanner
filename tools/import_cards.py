#!/usr/bin/env python3
"""Importa o catálogo do digimoncard.io para o Postgres (Supabase).

Uso:
  pip install requests psycopg[binary]
  export DATABASE_URL="postgresql://postgres:SENHA@db.xxxx.supabase.co:5432/postgres"
  python tools/import_cards.py            # baixa (1 requisição) e importa
  python tools/import_cards.py --offline  # usa o cache cards_raw.json
  python tools/import_cards.py --dry-run  # só mapeia e mostra estatísticas
"""
import argparse, json, os, re, sys
from collections import defaultdict
from pathlib import Path

API = "https://digimoncard.io/api-public/getAllCards.php"
PARAMS = {"series": "Digimon Card Game", "sort": "code", "sortdirection": "asc"}
CACHE = Path(__file__).parent / "cards_raw.json"
CODE_RE = re.compile(r"^([A-Z]+\d*)-\d+$", re.I)


def pick(d, *keys):
    """Primeiro valor não vazio entre nomes de campo possíveis."""
    for k in keys:
        v = d.get(k)
        if v not in (None, "", "-", "null"):
            return v
    return None


def to_int(v):
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return None


def map_card(r):
    code = pick(r, "id", "cardnumber", "card_number")
    if not code:
        return None
    code = str(code).strip().upper()
    evos = []
    cost = to_int(pick(r, "evolution_cost", "evo_cost"))
    if cost is not None:
        evos.append({"cost": cost,
                     "color": pick(r, "evolution_color", "evo_color"),
                     "level": to_int(pick(r, "evolution_level", "evo_level"))})
    return {
        "code": code,
        "name": pick(r, "name") or code,
        "type": pick(r, "type") or "Unknown",
        "color": pick(r, "color"),
        "color2": pick(r, "color2"),
        "level": to_int(pick(r, "level")),
        "play_cost": to_int(pick(r, "play_cost")),
        "dp": to_int(pick(r, "dp")),
        "form": pick(r, "form"),
        "attribute": pick(r, "attribute"),
        "digi_types": [t for t in (pick(r, "digi_type"), pick(r, "digi_type2")) if t],
        "stage": pick(r, "stage"),
        "main_effect": pick(r, "main_effect"),
        "source_effect": pick(r, "source_effect", "inherited_effect"),
        "alt_effect": pick(r, "alt_effect"),
        "evolutions": json.dumps(evos),
    }


def map_all(rows):
    """Devolve (sets, cards, prints). Várias linhas com o mesmo código = impressões."""
    cards, sets, by_code = {}, {}, defaultdict(list)
    for r in rows:
        c = map_card(r)
        if not c:
            continue
        cards.setdefault(c["code"], c)
        by_code[c["code"]].append(r)
    prints = []
    for code, group in by_code.items():
        group.sort(key=lambda r: str(pick(r, "image_url") or ""))
        m = CODE_RE.match(code)
        set_code = m.group(1).upper() if m else None
        if set_code:
            set_name = pick(group[0], "set_name", "pack") or set_code
            if isinstance(set_name, list):
                set_name = set_name[0] if set_name else set_code
            sets.setdefault(set_code, str(set_name))
        for i, r in enumerate(group):
            prints.append({
                "id": code if i == 0 else f"{code}_P{i}",
                "card_code": code,
                "set_code": set_code,
                "rarity": pick(r, "rarity"),
                "artist": pick(r, "artist"),
                "image_url": pick(r, "image_url", "image"),
                "is_alternate": i > 0,
            })
    return sets, cards, prints


def fetch(use_cache):
    if use_cache and CACHE.exists():
        return json.loads(CACHE.read_text())
    import requests
    resp = requests.get(API, params=PARAMS, timeout=120,
                        headers={"User-Agent": "digimon-scanner-import/0.1"})
    resp.raise_for_status()
    data = resp.json()
    CACHE.write_text(json.dumps(data))
    return data


def upsert(conn, table, rows, pk):
    if not rows:
        return
    cols = list(rows[0].keys())
    updates = ", ".join(f"{c}=excluded.{c}" for c in cols if c != pk)
    sql = (f"insert into {table} ({','.join(cols)}) values ({','.join(['%s']*len(cols))}) "
           f"on conflict ({pk}) do update set {updates}")
    with conn.cursor() as cur:
        cur.executemany(sql, [[r[c] for c in cols] for r in rows])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--refresh", action="store_true")
    a = ap.parse_args()
    if a.offline and not CACHE.exists():
        sys.exit("cards_raw.json não existe; rode sem --offline uma vez.")
    rows = fetch(use_cache=not a.refresh)
    if isinstance(rows, dict):  # algumas respostas vêm embrulhadas
        rows = rows.get("data") or rows.get("cards") or []
    sets, cards, prints = map_all(rows)
    print(f"{len(rows)} linhas -> {len(sets)} sets, {len(cards)} cartas, "
          f"{len(prints)} impressões ({sum(p['is_alternate'] for p in prints)} alternativas)")
    if a.dry_run:
        return
    import psycopg
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        upsert(conn, "sets", [{"code": k, "name": v} for k, v in sets.items()], "code")
        upsert(conn, "cards", list(cards.values()), "code")
        upsert(conn, "prints", prints, "id")
    print("Importação concluída.")


if __name__ == "__main__":
    main()
