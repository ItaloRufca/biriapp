#!/usr/bin/env python3
"""
Importador batch do carteados.csv para o schema BiriApp v2.

Uso:
  export SUPABASE_URL="https://<project>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
  export CSV_PATH="/Volumes/HD_Ext_Ital/Board/App/Biriapp/carteados.csv"
  python3 Biriapp/Biriapp/Support/Scripts/import_carteados_csv.py
"""

from __future__ import annotations

import csv
import os
import re
import sys
import unicodedata
from dataclasses import dataclass
from typing import Any

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
CSV_PATH = os.environ.get("CSV_PATH", "carteados.csv")
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "300"))

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


@dataclass
class RestClient:
    base_url: str
    headers: dict[str, str]

    def request(self, path: str, method: str = "GET", params: dict[str, Any] | None = None, payload: Any = None) -> Any:
        url = f"{self.base_url}/rest/v1/{path}"
        resp = requests.request(method, url, headers=self.headers, params=params, json=payload, timeout=90)
        if resp.status_code >= 300:
            raise RuntimeError(f"{method} {path} -> {resp.status_code}: {resp.text[:600]}")
        if not resp.text:
            return None
        try:
            return resp.json()
        except Exception:
            return None


def slug(value: str) -> str:
    base = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    base = re.sub(r"[^a-zA-Z0-9]+", "-", base.strip().lower()).strip("-")
    return base or "user"


def parse_bgg_id(url: str) -> str | None:
    if not url:
        return None
    match = re.search(r"/boardgame/(\d+)", url)
    return match.group(1) if match else None


def parse_best_count(raw: str) -> int | None:
    if not raw:
        return None
    match = re.search(r"\d+", raw)
    return int(match.group(0)) if match else None


def parse_players_range(raw: str) -> tuple[int | None, int | None]:
    if not raw:
        return (None, None)
    nums = [int(n) for n in re.findall(r"\d+", raw)]
    if not nums:
        return (None, None)
    if len(nums) == 1:
        return (nums[0], nums[0])
    return (min(nums[0], nums[1]), max(nums[0], nums[1]))


def split_mechanics(raw: str) -> list[str]:
    if not raw:
        return []
    parts = re.split(r"[;,/|]", raw)
    cleaned = [p.strip(" -\t\r\n") for p in parts if p.strip(" -\t\r\n")]
    # dedupe preservando ordem
    seen: set[str] = set()
    out: list[str] = []
    for item in cleaned:
        key = item.lower()
        if key not in seen:
            seen.add(key)
            out.append(item)
    return out


def to_int_rating(raw: Any) -> int | None:
    if raw is None:
        return None
    text = str(raw).strip().replace(",", ".")
    if not text:
        return None
    try:
        value = int(float(text))
    except Exception:
        return None
    return value if 1 <= value <= 5 else None


def chunked(seq: list[Any], size: int) -> list[list[Any]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def fetch_bgg_metadata(bgg_id: str) -> dict[str, Any]:
    url = f"https://api.geekdo.com/api/geekitems?objectid={bgg_id}&objecttype=thing"
    try:
        resp = requests.get(url, timeout=25)
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

    def as_int(value: Any) -> int | None:
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(value)
        if isinstance(value, str):
            digits = "".join(ch for ch in value if ch.isdigit())
            return int(digits) if digits else None
        return None

    return {
        "description": item.get("description"),
        "year_published": as_int(item.get("yearpublished")),
        "playing_time_min": as_int(item.get("playingtime")),
        "min_players": as_int(item.get("minplayers")),
        "max_players": as_int(item.get("maxplayers")),
        "image_url": (item.get("images") or {}).get("original") if isinstance(item.get("images"), dict) else item.get("imageurl"),
    }


def main() -> None:
    client = RestClient(SUPABASE_URL, HEADERS)

    # caches para reduzir chamadas
    game_by_bgg: dict[str, str] = {}
    game_by_name: dict[str, str] = {}
    mechanic_by_name: dict[str, str] = {}
    legacy_user_by_code: dict[str, str] = {}

    # pré-carrega jogos existentes
    existing_games = client.request("games", "GET", params={"select": "id,bgg_id,name"}) or []
    for g in existing_games:
        if g.get("bgg_id"):
            game_by_bgg[str(g["bgg_id"])] = g["id"]
        game_by_name[str(g.get("name", "")).strip().lower()] = g["id"]

    existing_mechanics = client.request("mechanics", "GET", params={"select": "id,name"}) or []
    for m in existing_mechanics:
        mechanic_by_name[str(m["name"]).strip().lower()] = m["id"]

    existing_legacy = client.request("legacy_users", "GET", params={"select": "id,access_code"}) or []
    for u in existing_legacy:
        legacy_user_by_code[str(u["access_code"])] = u["id"]

    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    game_payloads: list[dict[str, Any]] = []
    game_rows_map: list[dict[str, Any]] = []

    for row in rows:
        name = (row.get("Nome") or "").strip()
        if not name:
            continue

        bgg_url = (row.get("BGG") or "").strip()
        bgg_id = parse_bgg_id(bgg_url)
        min_p, max_p = parse_players_range(row.get("Jogadores_Range") or "")
        bgg_meta = fetch_bgg_metadata(bgg_id) if bgg_id else {}

        payload = {
            "bgg_id": bgg_id,
            "name": name,
            "alt_name": (row.get("Nome Alt") or "").strip() or None,
            "min_players": min_p if min_p is not None else bgg_meta.get("min_players"),
            "max_players": max_p if max_p is not None else bgg_meta.get("max_players"),
            "players_text": (row.get("No. Jogadores") or "").strip() or None,
            "best_player_count": parse_best_count(row.get("Melhor_em_dados") or ""),
            "primary_category": (row.get("Categoria") or "").strip() or None,
            "primary_category_display": (row.get("Categoria_Display") or "").strip() or None,
            "image_url": (row.get("Image") or "").strip() or bgg_meta.get("image_url") or None,
            "subtitle": (row.get("Subtitulo") or "").strip() or None,
            "description": bgg_meta.get("description"),
            "year_published": bgg_meta.get("year_published"),
            "playing_time_min": bgg_meta.get("playing_time_min"),
            "pagat_url": (row.get("Pagat") or "").strip() or None,
            "source": "bgg" if bgg_id else "manual",
            "is_active": True,
        }
        game_payloads.append(payload)
        game_rows_map.append(row)

    # upsert games em lotes: por bgg_id quando existe, por nome quando não existe bgg
    with_bgg = [p for p in game_payloads if p.get("bgg_id")]
    no_bgg = [p for p in game_payloads if not p.get("bgg_id")]

    for batch in chunked(with_bgg, BATCH_SIZE):
        inserted = client.request("games", "POST", params={"on_conflict": "bgg_id"}, payload=batch) or []
        for g in inserted:
            if g.get("bgg_id"):
                game_by_bgg[str(g["bgg_id"])] = g["id"]
            game_by_name[str(g["name"]).strip().lower()] = g["id"]

    for item in no_bgg:
        key = str(item["name"]).strip().lower()
        if key in game_by_name:
            game_id = game_by_name[key]
            client.request("games", "PATCH", params={"id": f"eq.{game_id}"}, payload=item)
        else:
            inserted = client.request("games", "POST", payload=[item]) or []
            if inserted:
                game_by_name[key] = inserted[0]["id"]

    # refetch mínimo para garantir cache completo
    existing_games = client.request("games", "GET", params={"select": "id,bgg_id,name"}) or []
    for g in existing_games:
        if g.get("bgg_id"):
            game_by_bgg[str(g["bgg_id"])] = g["id"]
        game_by_name[str(g.get("name", "")).strip().lower()] = g["id"]

    links_payloads: list[dict[str, Any]] = []
    content_payloads: list[dict[str, Any]] = []
    raw_payloads: list[dict[str, Any]] = []
    game_mechanics_payloads: list[dict[str, Any]] = []
    legacy_ratings_payloads: list[dict[str, Any]] = []

    def ensure_legacy_user(display_name: str) -> str:
        code = f"LEG-{slug(display_name)}"
        existing = legacy_user_by_code.get(code)
        if existing:
            return existing

        created = client.request(
            "legacy_users",
            "POST",
            params={"on_conflict": "access_code"},
            payload=[{"access_code": code, "display_name": display_name}],
        ) or []

        if created:
            legacy_id = created[0]["id"]
        else:
            found = client.request(
                "legacy_users",
                "GET",
                params={"select": "id", "access_code": f"eq.{code}", "limit": 1},
            ) or []
            if not found:
                raise RuntimeError(f"Não foi possível criar legacy user: {display_name}")
            legacy_id = found[0]["id"]

        legacy_user_by_code[code] = legacy_id
        return legacy_id

    def ensure_mechanic(name: str) -> str:
        key = name.strip().lower()
        if key in mechanic_by_name:
            return mechanic_by_name[key]

        created = client.request(
            "mechanics",
            "POST",
            params={"on_conflict": "name"},
            payload=[{"name": name.strip()}],
        ) or []

        if created:
            mechanic_id = created[0]["id"]
        else:
            found = client.request(
                "mechanics",
                "GET",
                params={"select": "id", "name": f"eq.{name.strip()}", "limit": 1},
            ) or []
            if not found:
                raise RuntimeError(f"Não foi possível criar mecânica: {name}")
            mechanic_id = found[0]["id"]

        mechanic_by_name[key] = mechanic_id
        return mechanic_id

    for row in game_rows_map:
        name_key = (row.get("Nome") or "").strip().lower()
        if not name_key:
            continue

        bgg_id = parse_bgg_id((row.get("BGG") or "").strip())
        game_id = game_by_bgg.get(bgg_id) if bgg_id else None
        if not game_id:
            game_id = game_by_name.get(name_key)
        if not game_id:
            continue

        links_payloads.append(
            {
                "game_id": game_id,
                "bgg_url": (row.get("BGG") or "").strip() or None,
                "ludopedia_url": (row.get("Ludopedia") or "").strip() or None,
                "rules_url": (row.get("Regras") or "").strip() or None,
                "pagat_url": (row.get("Pagat") or "").strip() or None,
                "player_aid_image_url": (row.get("BD_PA_Img") or "").strip() or None,
            }
        )

        content_payloads.append(
            {
                "game_id": game_id,
                "birideck_markdown": row.get("BiriDeck") or None,
                "birideck_display": row.get("BiriDeck_Display") or None,
                "bd_adaptacao": row.get("BD_Adaptação") or None,
                "bd_informacao": row.get("BD_Informação") or None,
                "bd_player_aid": row.get("BD_PlayerAid") or None,
                "magana_notes": row.get("Magana") or None,
                "resumo_vaza": row.get("Resumo_Vaza") or None,
                "com_resumo": row.get("Com Resumo") or None,
                "resumo_outros": row.get("Resumo_Outros") or None,
                "resumo_climbing": row.get("Resumo_Climbing") or None,
            }
        )

        raw_payloads.append(
            {
                "game_id": game_id,
                "conta_notas": row.get("Conta_Notas") or None,
                "dummy1": row.get("Dummy1") or None,
                "dummy2": row.get("Dummy2") or None,
                "dummy3": row.get("Dummy3") or None,
                "dummy4": row.get("Dummy4") or None,
                "dummy5": row.get("Dummy5") or None,
                "dummy6": row.get("Dummy6") or None,
                "dummy7": row.get("Dummy7") or None,
                "dummy8": row.get("Dummy8") or None,
                "dummy9": row.get("Dummy9") or None,
                "dummy10": row.get("Dummy10") or None,
                "media": row.get("Media") or None,
                "emoji_media": row.get("Emoji_Media") or None,
            }
        )

        for mech in split_mechanics(row.get("Mecânicas Secundárias") or ""):
            mechanic_id = ensure_mechanic(mech)
            game_mechanics_payloads.append({"game_id": game_id, "mechanic_id": mechanic_id})

        for col, val in row.items():
            if col in NON_RATING_COLUMNS:
                continue
            rating = to_int_rating(val)
            if rating is None:
                continue
            legacy_user_id = ensure_legacy_user(col)
            legacy_ratings_payloads.append(
                {"legacy_user_id": legacy_user_id, "game_id": game_id, "rating": rating}
            )

    for batch in chunked(links_payloads, BATCH_SIZE):
        client.request("game_external_links", "POST", params={"on_conflict": "game_id"}, payload=batch)

    for batch in chunked(content_payloads, BATCH_SIZE):
        client.request("game_content", "POST", params={"on_conflict": "game_id"}, payload=batch)

    for batch in chunked(raw_payloads, BATCH_SIZE):
        client.request("legacy_import_raw", "POST", params={"on_conflict": "game_id"}, payload=batch)

    # dedupe game_mechanics e legacy_ratings antes de inserir
    gm_seen = set()
    gm_unique = []
    for gm in game_mechanics_payloads:
        key = (gm["game_id"], gm["mechanic_id"])
        if key not in gm_seen:
            gm_seen.add(key)
            gm_unique.append(gm)

    for batch in chunked(gm_unique, BATCH_SIZE):
        client.request("game_mechanics", "POST", params={"on_conflict": "game_id,mechanic_id"}, payload=batch)

    lr_seen = set()
    lr_unique = []
    for lr in legacy_ratings_payloads:
        key = (lr["legacy_user_id"], lr["game_id"])
        if key not in lr_seen:
            lr_seen.add(key)
            lr_unique.append(lr)

    for batch in chunked(lr_unique, BATCH_SIZE):
        client.request("legacy_ratings", "POST", params={"on_conflict": "legacy_user_id,game_id"}, payload=batch)

    print("Import concluído com sucesso.")
    print(f"Jogos processados: {len(game_rows_map)}")
    print(f"Mecânicas vinculadas: {len(gm_unique)}")
    print(f"Ratings legadas: {len(lr_unique)}")


if __name__ == "__main__":
    main()
