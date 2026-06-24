#!/usr/bin/env python3
"""Download Unsplash covers for sim-event-* rows and upload to MinIO."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT / "scripts" / "seed_assets" / "unsplash" / "events"
OUT_SQL = ROOT / "scripts" / "update_sim_event_images.sql"

MINIO_ALIAS = "local"
MINIO_ENDPOINT = "http://minio:9000"
MINIO_USER = "andexevents"
MINIO_PASSWORD = "andexevents_minio_secret"
MINIO_CONTAINER = "andexevents-minio"
POSTGRES_CONTAINER = "andexevents-postgres"

USER_AGENT = "AndexEvents-Seed/1.0"

DOWNLOAD_FALLBACKS: dict[str, str] = {
    "photo-1476480862126-209bfaa8dba8": "photo-1534438327276-14e5300c3a48",
    "photo-1460661419201-fd4cecdfde94": "photo-1547891654-e66ed7ebb968",
}

# Curated Unsplash slugs per event category.
CATEGORY_SLUGS: dict[str, list[str]] = {
    "concert": [
        "photo-1514525253161-7a46d19cd819",
        "photo-1493225457124-a3eb161ffa5f",
        "photo-1511671782729-637a64f97c4b",
        "photo-1459745421170-9bed5c7eb924",
        "photo-1501386761578-eac5c94b800a",
    ],
    "sport": [
        "photo-1534438327276-14e5300c3a48",
        "photo-1476480862126-209bfaa8dba8",
        "photo-1571019614242-c5c5dee9f50b",
        "photo-1517649763962-0c62306601b7",
        "photo-1461896836934-ffe607ba8211",
    ],
    "exhibition": [
        "photo-1547891654-e66ed7ebb968",
        "photo-1460661419201-fd4cecdfde94",
        "photo-1561214115-f2f134cc4912",
        "photo-1541961017774-22349e4a1262",
        "photo-1515405295578-7b8ad0a83637",
    ],
    "conference": [
        "photo-1540575467063-178a50c2df87",
        "photo-1505373877841-8d25f8d46684",
        "photo-1524178232363-1fb2b075b655",
        "photo-1552664730-d307ca884978",
        "photo-1517245386807-bb43f82c33c4",
    ],
    "party": [
        "photo-1514525253161-7a46d19cd819",
        "photo-1533174072545-7a4b6ecd7ba0",
        "photo-1429962714459-bb934995d308",
        "photo-1470229722913-7c0e2dbbafd3",
        "photo-1516450360452-9312f5e86fc7",
    ],
    "theater": [
        "photo-1503099644803-47d0275d558c",
        "photo-1507676184212-d03ab07a01bf",
        "photo-1514306191717-6bf45626301b",
        "photo-1489599849927-2fa91ead3a61",
        "photo-1516450360452-9312f5e86fc7",
    ],
    "cinema": [
        "photo-1489599849927-2fa91ead3a61",
        "photo-1536440136628-849c177e76a1",
        "photo-1440404653325-ab127d49abc1",
        "photo-1478720568477-152d9bafd690",
        "photo-1594909123335-c11ef189677a",
    ],
    "other": [
        "photo-1511795409834-ef04bbd61622",
        "photo-1529156069898-49953e39b3ac",
        "photo-1511578314322-379afb476865",
        "photo-1540575467063-178a50c2df87",
        "photo-1501281668745-f7f57925c3b4",
    ],
}


def unsplash_download_url(slug: str, width: int = 900) -> str:
    slug = DOWNLOAD_FALLBACKS.get(slug, slug)
    return f"https://images.unsplash.com/{slug}?w={width}&auto=format&fit=crop&q=80"


def public_upload_path(filename: str) -> str:
    return f"/uploads/events/seed/{filename}"


def run_mc(*args: str) -> None:
    subprocess.run(
        ["docker", "exec", MINIO_CONTAINER, "mc", *args],
        check=True,
        capture_output=True,
        text=True,
    )


def ensure_mc_alias() -> None:
    run_mc("alias", "set", MINIO_ALIAS, MINIO_ENDPOINT, MINIO_USER, MINIO_PASSWORD)


def download_image(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1024:
        print(f"  skip download (exists) {dest.name}")
        return

    subprocess.run(
        ["curl", "-fsSL", "-A", USER_AGENT, "-o", str(dest), url],
        check=True,
        capture_output=True,
        text=True,
    )
    size = dest.stat().st_size
    if size < 1024:
        raise RuntimeError(f"Bad download ({size} bytes): {url}")
    print(f"  downloaded {dest.name} ({size // 1024} KB)")


def download_slug_with_fallback(slugs: list[str], dest: Path) -> str:
    last_error: Exception | None = None
    for slug in slugs:
        try:
            download_image(unsplash_download_url(slug), dest)
            return slug
        except (subprocess.CalledProcessError, RuntimeError) as exc:
            last_error = exc
            if dest.exists():
                dest.unlink(missing_ok=True)
            print(f"  warn: failed {slug}, trying next")
    raise RuntimeError(f"All slugs failed for {dest.name}") from last_error


def upload_to_minio(local_file: Path, filename: str) -> None:
    object_key = f"seed/{filename}"
    container_dest = f"/tmp/events-{filename}"
    subprocess.run(
        ["docker", "cp", str(local_file), f"{MINIO_CONTAINER}:{container_dest}"],
        check=True,
        capture_output=True,
        text=True,
    )
    run_mc(
        "cp",
        container_dest,
        f"{MINIO_ALIAS}/events/{object_key}",
        "--attr",
        "Content-Type=image/jpeg",
    )
    print(f"  uploaded events/{object_key}")


def fetch_sim_events() -> list[tuple[str, str]]:
    result = subprocess.run(
        [
            "docker",
            "exec",
            POSTGRES_CONTAINER,
            "psql",
            "-U",
            "andexevents",
            "-d",
            "andexevents",
            "-t",
            "-A",
            "-F",
            ",",
            "-c",
            'SELECT id, category FROM events."Event" WHERE id LIKE \'sim-event-%\' ORDER BY id;',
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    rows: list[tuple[str, str]] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        event_id, category = line.split(",", 1)
        rows.append((event_id.strip(), category.strip()))
    return rows


def pick_slug(category: str, event_id: str) -> str:
    slugs = CATEGORY_SLUGS.get(category) or CATEGORY_SLUGS["other"]
    num = int(event_id.rsplit("-", 1)[-1])
    return slugs[(num - 1) % len(slugs)]


def slug_candidates(category: str, event_id: str) -> list[str]:
    slugs = CATEGORY_SLUGS.get(category) or CATEGORY_SLUGS["other"]
    num = int(event_id.rsplit("-", 1)[-1])
    start = (num - 1) % len(slugs)
    ordered = slugs[start:] + slugs[:start]
    # Global fallback pool if category slugs are stale.
    return ordered + CATEGORY_SLUGS["concert"] + CATEGORY_SLUGS["sport"]


def write_update_sql(updates: list[tuple[str, str]]) -> None:
    lines = [
        "-- Point sim-event-* rows at MinIO-hosted Unsplash covers.",
        "BEGIN;",
        "",
    ]
    for event_id, path in updates:
        lines.append(
            f"UPDATE events.\"Event\" SET "
            f"\"imageUrl\" = '{path}', "
            f"\"imageUrls\" = ARRAY['{path}']::TEXT[], "
            f"\"updatedAt\" = NOW() "
            f"WHERE \"id\" = '{event_id}';"
        )
    lines.extend(["", "COMMIT;", ""])
    OUT_SQL.write_text("\n".join(lines), encoding="utf-8")


def apply_sql() -> None:
    subprocess.run(
        [
            "docker",
            "exec",
            "-i",
            POSTGRES_CONTAINER,
            "psql",
            "-U",
            "andexevents",
            "-d",
            "andexevents",
        ],
        input=OUT_SQL.read_text(encoding="utf-8"),
        text=True,
        check=True,
        capture_output=True,
    )


def main() -> int:
    events = fetch_sim_events()
    if not events:
        print("No sim-event-* rows found in database.")
        return 1

    print(f"Found {len(events)} simulation event(s)")
    ensure_mc_alias()

    sql_updates: list[tuple[str, str]] = []
    used_files: set[str] = set()

    for event_id, category in events:
        filename = f"{event_id}.jpg"
        local_file = ASSETS_DIR / filename
        path = public_upload_path(filename)

        candidates = slug_candidates(category, event_id)
        print(f"{event_id} ({category})")
        slug = download_slug_with_fallback(candidates, local_file)
        print(f"  using {slug}")
        if filename not in used_files:
            upload_to_minio(local_file, filename)
            used_files.add(filename)
        sql_updates.append((event_id, path))

    write_update_sql(sql_updates)
    print(f"wrote {OUT_SQL.relative_to(ROOT)}")
    apply_sql()
    print("database updated")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout or str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
