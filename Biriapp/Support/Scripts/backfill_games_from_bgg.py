#!/usr/bin/env python3
"""
Backfill de metadados BGG direto na tabela public.games.

Atualiza, quando disponível:
- description
- year_published
- playing_time_min
- min_players
- max_players
- image_url

Uso:
  export SUPABASE_URL="https://<project>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
  python3 Biriapp/Biriapp/Support/Scripts/backfill_games_from_bgg.py
"""

from __future__ import annotations

import os
import sys
import time
from typing import Any

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "300"))
SLEEP_MS = int(os.environ.get("SLEEP_MS", "120"))

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.", file=sys.stderr)
    sys.exit(1)

HEADERS = {
    "apikey": SUPABASE_SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}


def request(path: str, method: str = "GET", params: dict[str, Any] | None = None, payload: Any = None) -> Any:
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    resp = requests.request(method, url, headers=HEADERS, params=params, json=payload, timeout=90)
    if resp.status_code >= 300:
        raise RuntimeError(f"{method} {path} -> {resp.status_code}: {resp.text[:500]}")
    if not resp.text:
        return None
    return resp.json()


def as_int(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        digits = "".join(ch for ch in value if ch.isdigit())
        return int(digits) if digits else None
    return None


def fetch_bgg_metadata(bgg_id: str) -> dict[str, Any]:
    url = f"https://api.geekdo.com/api/geekitems?objectid={bgg_id}&objecttype=thing"
    try:
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        payload = resp.json()
    except Exception:
        return {}

    raw_item = payload.get("item")
    if isinstance(raw_item, list) and raw_item:
        item = raw_item[0]
    elif isinstance(raw_item, dict):
        item = raw_item
    else:
        return {}

    image_url = None
    if isinstance(item.get("images"), dict):
        image_url = item["images"].get("original")
    if not image_url:
        image_url = item.get("imageurl")

    return {
        "description": item.get("description"),
        "year_published": as_int(item.get("yearpublished")),
        "playing_time_min": as_int(item.get("playingtime")),
        "min_players": as_int(item.get("minplayers")),
        "max_players": as_int(item.get("maxplayers")),
        "image_url": image_url,
    }


def chunked(seq: list[Any], size: int) -> list[list[Any]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def main() -> None:
    games = request(
        "games",
        "GET",
        params={"select": "id,bgg_id,name,description,year_published,playing_time_min,min_players,max_players,image_url", "is_active": "eq.true"},
    ) or []

    updates: list[dict[str, Any]] = []
    touched = 0

    for game in games:
        bgg_id = str(game.get("bgg_id") or "").strip()
        if not bgg_id:
            continue

        metadata = fetch_bgg_metadata(bgg_id)
        if not metadata:
            continue

        payload = {"id": game["id"]}
        changed = False

        for key in ["description", "year_published", "playing_time_min", "min_players", "max_players", "image_url"]:
            current = game.get(key)
            new_value = metadata.get(key)
            if current in (None, "") and new_value not in (None, ""):
                payload[key] = new_value
                changed = True

        if changed:
            updates.append(payload)
            touched += 1

        time.sleep(SLEEP_MS / 1000)

    for batch in chunked(updates, BATCH_SIZE):
        request("games", "POST", params={"on_conflict": "id"}, payload=batch)

    print(f"Jogos lidos: {len(games)}")
    print(f"Jogos atualizados: {touched}")


if __name__ == "__main__":
    main()
