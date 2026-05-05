#!/usr/bin/env python3
"""
Sync único: CSV + Supabase + BGG API.

Fluxo:
1) Lê o CSV de carteados.
2) Garante que todo jogo do CSV exista em public.games (upsert por bgg_id ou nome).
3) Garante links em public.game_external_links (bgg/ludopedia/regras/pagat).
4) Percorre jogos com bgg_id no Supabase e preenche campos faltantes em public.games
   usando a API do BGG (geekdo):
   - description
   - year_published
   - playing_time_min
   - min_players
   - max_players
   - image_url

Uso:
  pip3 install requests
  export SUPABASE_URL="https://<project>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service_role_key>"
  export CSV_PATH="/Volumes/HD_Ext_Ital/Board/App/Biriapp/carteados.csv"
  python3 Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
"""

from __future__ import annotations

import csv
import os
import re
import sys
import time
from typing import Any

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
CSV_PATH = os.environ.get("CSV_PATH", "carteados.csv")

BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "250"))
SLEEP_MS = int(os.environ.get("SLEEP_MS", "120"))
ONLY_FILL_EMPTY = os.environ.get("ONLY_FILL_EMPTY", "1") == "1"

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.", file=sys.stderr)
    sys.exit(1)

HEADERS = {
    "apikey": SUPABASE_SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}


class Rest:
    def __init__(self, base: str, headers: dict[str, str]) -> None:
        self.base = base
        self.headers = headers

    def call(
        self,
        path: str,
        method: str = "GET",
        params: dict[str, Any] | None = None,
        payload: Any = None,
        extra_headers: dict[str, str] | None = None,
    ) -> Any:
        url = f"{self.base}/rest/v1/{path}"
        headers = dict(self.headers)
        if extra_headers:
            headers.update(extra_headers)
        resp = requests.request(method, url, headers=headers, params=params, json=payload, timeout=90)
        if resp.status_code >= 300:
            raise RuntimeError(f"{method} {path} -> {resp.status_code}: {resp.text[:600]}")
        if not resp.text:
            return None
        return resp.json()


def parse_bgg_id(url: str) -> str | None:
    if not url:
        return None
    m = re.search(r"/boardgame/(\d+)", url)
    return m.group(1) if m else None


def to_int(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        digits = "".join(ch for ch in value if ch.isdigit())
        return int(digits) if digits else None
    return None


def parse_players_range(raw: str) -> tuple[int | None, int | None]:
    if not raw:
        return (None, None)
    nums = [int(n) for n in re.findall(r"\d+", raw)]
    if not nums:
        return (None, None)
    if len(nums) == 1:
        return (nums[0], nums[0])
    return (min(nums[0], nums[1]), max(nums[0], nums[1]))


def clean_text(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def fetch_bgg_item(bgg_id: str) -> dict[str, Any]:
    url = f"https://api.geekdo.com/api/geekitems?objectid={bgg_id}&objecttype=thing"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    raw_item = data.get("item")
    if isinstance(raw_item, dict):
        return raw_item
    if isinstance(raw_item, list) and raw_item:
        return raw_item[0]
    return {}


def bgg_to_game_patch(item: dict[str, Any]) -> dict[str, Any]:
    image_url = None
    images = item.get("images")
    if isinstance(images, dict):
        image_url = images.get("original")
    image_url = image_url or item.get("imageurl")

    description = item.get("description")
    if isinstance(description, str):
        description = clean_text(description)

    return {
        "description": description,
        "year_published": to_int(item.get("yearpublished")),
        "playing_time_min": to_int(item.get("playingtime")),
        "min_players": to_int(item.get("minplayers")),
        "max_players": to_int(item.get("maxplayers")),
        "image_url": image_url,
    }


def chunked(seq: list[Any], size: int) -> list[list[Any]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def main() -> None:
    api = Rest(SUPABASE_URL, HEADERS)

    # 1) Carrega CSV
    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        csv_rows = list(csv.DictReader(f))

    # 2) Carrega jogos atuais
    db_games = api.call(
        "games",
        "GET",
        params={"select": "id,bgg_id,name,min_players,max_players,description,image_url,year_published,playing_time_min", "limit": "10000"},
    ) or []

    by_bgg: dict[str, dict[str, Any]] = {}
    by_name: dict[str, dict[str, Any]] = {}
    for g in db_games:
        if g.get("bgg_id"):
            by_bgg[str(g["bgg_id"])] = g
        by_name[str(g.get("name", "")).strip().lower()] = g

    inserted = 0
    updated = 0
    missing_from_db = 0

    # 3) Garante jogos do CSV no Supabase
    for row in csv_rows:
        name = (row.get("Nome") or "").strip()
        if not name:
            continue

        bgg_url = (row.get("BGG") or "").strip()
        bgg_id = parse_bgg_id(bgg_url)
        min_p, max_p = parse_players_range((row.get("Jogadores_Range") or "").strip())

        existing = by_bgg.get(bgg_id) if bgg_id else by_name.get(name.lower())
        if existing is None:
            missing_from_db += 1
            payload = {
                "bgg_id": bgg_id,
                "name": name,
                "alt_name": (row.get("Nome Alt") or "").strip() or None,
                "min_players": min_p,
                "max_players": max_p,
                "players_text": (row.get("No. Jogadores") or "").strip() or None,
                "best_player_count": to_int(row.get("Melhor_em_dados")),
                "primary_category": (row.get("Categoria") or "").strip() or None,
                "primary_category_display": (row.get("Categoria_Display") or "").strip() or None,
                "image_url": (row.get("Image") or "").strip() or None,
                "subtitle": (row.get("Subtitulo") or "").strip() or None,
                "pagat_url": (row.get("Pagat") or "").strip() or None,
                "source": "bgg" if bgg_id else "manual",
                "is_active": True,
            }
            out = api.call("games", "POST", payload=[payload]) or []
            if out:
                g = out[0]
                inserted += 1
                if g.get("bgg_id"):
                    by_bgg[str(g["bgg_id"])] = g
                by_name[str(g.get("name", "")).strip().lower()] = g
                existing = g

        # Atualiza link BGG/Ludopedia/Regras/Pagat
        if existing:
            link_payload = {
                "game_id": existing["id"],
                "bgg_url": bgg_url or None,
                "ludopedia_url": (row.get("Ludopedia") or "").strip() or None,
                "rules_url": (row.get("Regras") or "").strip() or None,
                "pagat_url": (row.get("Pagat") or "").strip() or None,
                "player_aid_image_url": (row.get("BD_PA_Img") or "").strip() or None,
            }
            try:
                api.call(
                    "game_external_links",
                    "POST",
                    params={"on_conflict": "game_id"},
                    payload=[link_payload],
                    extra_headers={"Prefer": "resolution=merge-duplicates,return=representation"},
                )
            except RuntimeError as e:
                if "409" in str(e):
                    api.call(
                        "game_external_links",
                        "PATCH",
                        params={"game_id": f"eq.{existing['id']}"},
                        payload=link_payload,
                    )
                else:
                    raise

    print(f"CSV total: {len(csv_rows)}")
    print(f"Faltantes no DB (detectados): {missing_from_db}")
    print(f"Inseridos no DB: {inserted}")

    # 4) Recarrega jogos após inserts
    db_games = api.call(
        "games",
        "GET",
        params={"select": "id,bgg_id,name,min_players,max_players,description,image_url,year_published,playing_time_min", "limit": "10000"},
    ) or []

    # 5) Backfill via BGG API
    for idx, game in enumerate(db_games, start=1):
        bgg_id = str(game.get("bgg_id") or "").strip()
        if not bgg_id:
            continue

        try:
            item = fetch_bgg_item(bgg_id)
            if not item:
                continue
            patch = bgg_to_game_patch(item)
        except Exception as e:
            print(f"[{idx}] erro BGG {game.get('name')} ({bgg_id}): {e}")
            continue

        if ONLY_FILL_EMPTY:
            final_patch: dict[str, Any] = {}
            for key, value in patch.items():
                current = game.get(key)
                if current in (None, "") and value not in (None, ""):
                    final_patch[key] = value
        else:
            final_patch = {k: v for k, v in patch.items() if v not in (None, "")}

        if final_patch:
            api.call("games", "PATCH", params={"id": f"eq.{game['id']}"}, payload=final_patch)
            updated += 1

        if idx % 20 == 0:
            print(f"Progresso: {idx}/{len(db_games)} | Atualizados: {updated}")

        time.sleep(SLEEP_MS / 1000)

    print("----")
    print(f"Jogos no Supabase analisados: {len(db_games)}")
    print(f"Jogos atualizados com dados BGG: {updated}")
    print("Concluído.")


if __name__ == "__main__":
    main()
