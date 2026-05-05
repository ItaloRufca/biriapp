#!/usr/bin/env python3
"""
Reconstrói o legado a partir do CSV de carteados.

Formato de saída (normalizado):
- legacy_users: display_name (nome do usuário), access_code (código único)
- legacy_ratings: legacy_user_id + game_id + rating

Observação:
- Em banco relacional, "uma coluna por jogo" não escala bem.
- Este script mantém o modelo que o app já usa (legacy_users + legacy_ratings),
  mas o resultado lógico é o mesmo: cada usuário tem uma nota por jogo.

Uso:
  pip3 install requests
  export SUPABASE_URL="https://<project>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service_role_key>"
  export CSV_PATH="/Volumes/HD_Ext_Ital/Board/App/Biriapp/carteados.csv"
  python3 /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/rebuild_legacy_from_csv.py
"""

from __future__ import annotations

import csv
import os
import re
import secrets
import string
import sys
from collections import defaultdict
from typing import Any

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
CSV_PATH = os.environ.get("CSV_PATH", "carteados.csv")
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "400"))

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.", file=sys.stderr)
    sys.exit(1)

HEADERS = {
    "apikey": SUPABASE_SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

NON_RATING_COLUMNS = {
    "Nome", "Jogadores_Range", "Melhor_em_dados", "No. Jogadores", "Categoria",
    "Categoria_Display", "Image", "BGG", "Ludopedia", "Regras", "BiriDeck",
    "BiriDeck_Display", "BD_Adaptação", "Magana", "Conta_Notas", "Dummy1", "Dummy2",
    "Dummy3", "Dummy4", "Dummy5", "Dummy6", "Dummy7", "Dummy8", "Dummy9", "Dummy10",
    "Media", "Emoji_Media", "Subtitulo", "Nome Alt", "Resumo_Vaza", "Com Resumo",
    "Mecânicas Secundárias", "Resumo_Outros", "BD_Informação", "BD_PlayerAid",
    "Resumo_Climbing", "BD_PA_Img", "Pagat",
}

EMOJI_RATING = {
    "💩": 1,
    "👍": 2,
    "👍🏻": 2,
    "✅": 3,
    "✅✅": 4,
    "✅✅✅": 5,
}


class Rest:
    def __init__(self, base: str, headers: dict[str, str]) -> None:
        self.base = base
        self.headers = headers

    def call(self, path: str, method: str = "GET", params: dict[str, Any] | None = None, payload: Any = None) -> Any:
        url = f"{self.base}/rest/v1/{path}"
        resp = requests.request(method, url, headers=self.headers, params=params, json=payload, timeout=90)
        if resp.status_code >= 300:
            raise RuntimeError(f"{method} {path} -> {resp.status_code}: {resp.text[:600]}")
        if not resp.text:
            return None
        try:
            return resp.json()
        except Exception:
            return None


def chunked(seq: list[Any], size: int) -> list[list[Any]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def parse_bgg_id(url: str) -> str | None:
    if not url:
        return None
    m = re.search(r"/boardgame/(\d+)", url)
    return m.group(1) if m else None


def normalize_rating(raw: Any) -> int | None:
    if raw is None:
        return None

    text = str(raw).strip()
    if not text:
        return None

    if text in EMOJI_RATING:
        return EMOJI_RATING[text]

    compact = text.replace(" ", "")
    if compact in EMOJI_RATING:
        return EMOJI_RATING[compact]

    # formato misto, ex.: "✅✅ (4)" / "👍🏻 2"
    digit_match = re.search(r"([1-5])", text)
    if digit_match:
        return int(digit_match.group(1))

    # fallback numérico (ex.: 1, 2, 3, 4, 5)
    text_num = text.replace(",", ".")
    try:
        val = int(float(text_num))
        if 1 <= val <= 5:
            return val
    except Exception:
        pass

    return None


def random_code(used: set[str], length: int = 10) -> str:
    alphabet = string.ascii_uppercase + string.digits
    while True:
        code = "LEG-" + "".join(secrets.choice(alphabet) for _ in range(length))
        if code not in used:
            used.add(code)
            return code


def print_progress(done: int, total: int, prefix: str) -> None:
    width = 30
    ratio = 0 if total == 0 else done / total
    filled = int(width * ratio)
    bar = "█" * filled + "-" * (width - filled)
    print(f"\r{prefix} [{bar}] {done}/{total}", end="", flush=True)
    if done == total:
        print()


def main() -> None:
    api = Rest(SUPABASE_URL, HEADERS)

    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        sample = f.read(8192)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;|\t")
            delimiter = dialect.delimiter
        except Exception:
            delimiter = ","
        reader = csv.DictReader(f, delimiter=delimiter)
        rows = list(reader)

    if not rows:
        print("CSV vazio.")
        return

    headers = list(rows[0].keys())
    user_columns = [h for h in headers if h and h not in NON_RATING_COLUMNS]

    print(f"CSV carregado: {len(rows)} jogos | delimitador detectado: '{delimiter}'")
    print(f"Usuários legados detectados: {len(user_columns)}")

    # mapa de jogos existentes
    games = api.call("games", "GET", params={"select": "id,name,bgg_id", "limit": "10000"}) or []
    by_name = {str(g.get("name", "")).strip().lower(): g["id"] for g in games}
    by_bgg = {str(g.get("bgg_id")): g["id"] for g in games if g.get("bgg_id")}

    # limpa legado atual
    print("Limpando legado atual...")
    api.call("legacy_ratings", "DELETE", params={"id": "gt.00000000-0000-0000-0000-000000000000"})
    api.call("legacy_users", "DELETE", params={"id": "gt.00000000-0000-0000-0000-000000000000"})

    # cria usuários legados com código único
    used_codes: set[str] = set()
    legacy_users_payload = []
    for name in user_columns:
        legacy_users_payload.append({
            "display_name": name,
            "access_code": random_code(used_codes),
        })

    inserted_users = []
    for batch in chunked(legacy_users_payload, BATCH_SIZE):
        out = api.call("legacy_users", "POST", payload=batch) or []
        inserted_users.extend(out)

    user_id_by_name = {u["display_name"]: u["id"] for u in inserted_users}
    print(f"Usuários legados criados: {len(inserted_users)}")

    # gera ratings
    ratings_payload: list[dict[str, Any]] = []
    skipped_games = 0

    total_rows = len(rows)
    for idx, row in enumerate(rows, start=1):
        game_name = str(row.get("Nome") or "").strip()
        bgg_id = parse_bgg_id(str(row.get("BGG") or "").strip())

        game_id = by_bgg.get(bgg_id) if bgg_id else None
        if not game_id:
            game_id = by_name.get(game_name.lower())

        if not game_id:
            skipped_games += 1
            print_progress(idx, total_rows, "Processando jogos")
            continue

        for user_name in user_columns:
            rating = normalize_rating(row.get(user_name))
            if rating is None:
                continue

            legacy_user_id = user_id_by_name.get(user_name)
            if not legacy_user_id:
                continue

            ratings_payload.append({
                "legacy_user_id": legacy_user_id,
                "game_id": game_id,
                "rating": rating,
                "is_active": True,
            })

        print_progress(idx, total_rows, "Processando jogos")

    print(f"Ratings extraídos do CSV: {len(ratings_payload)}")

    # dedupe por (legacy_user_id, game_id)
    dedup: dict[tuple[str, str], dict[str, Any]] = {}
    for r in ratings_payload:
        dedup[(r["legacy_user_id"], r["game_id"])] = r
    ratings_payload = list(dedup.values())

    total_batches = len(chunked(ratings_payload, BATCH_SIZE))
    done_batches = 0
    inserted = 0

    for batch in chunked(ratings_payload, BATCH_SIZE):
        out = api.call(
            "legacy_ratings",
            "POST",
            params={"on_conflict": "legacy_user_id,game_id"},
            payload=batch,
        ) or []
        inserted += len(out)
        done_batches += 1
        print_progress(done_batches, total_batches, "Inserindo ratings")

    print("----")
    print(f"Jogos não encontrados no Supabase: {skipped_games}")
    print(f"Ratings legados inseridos/upsert: {inserted}")
    print("Concluído.")


if __name__ == "__main__":
    main()
