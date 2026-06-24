#!/usr/bin/env python3
"""Download Unsplash images referenced in seed SQL and upload to MinIO."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT / "scripts" / "seed_assets" / "unsplash"
MAPPING_FILE = ROOT / "scripts" / "seed_assets" / "unsplash_mapping.json"

UNSPLASH_RE = re.compile(
    r"https://images\.unsplash\.com/(photo-[a-zA-Z0-9-]+)(?:\?[^'\"\s]*)?"
)

SEED_SQL_FILES = [
    ROOT / "scripts" / "seed_demo_events.sql",
    ROOT / "scripts" / "seed_fake_match_profiles.sql",
    ROOT / "scripts" / "seed_fake_match_profiles_local.sql",
]

MINIO_ALIAS = "local"
MINIO_ENDPOINT = "http://minio:9000"
MINIO_USER = "andexevents"
MINIO_PASSWORD = "andexevents_minio_secret"
MINIO_CONTAINER = "andexevents-minio"

# Demo event covers (slug -> filename in events/seed/).
EVENT_PHOTOS: dict[str, str] = {
    "photo-1514525253161-7a46d19cd819": "demo-jazz-party.jpg",
    "photo-1476480862126-209bfaa8dba8": "demo-run.jpg",
    "photo-1460661419201-fd4cecdfde94": "demo-art.jpg",
    "photo-1540575467063-178a50c2df87": "demo-tech.jpg",
}

# Unsplash removed some legacy photo IDs; download close substitutes instead.
DOWNLOAD_FALLBACKS: dict[str, str] = {
    "photo-1476480862126-209bfaa8dba8": "photo-1534438327276-14e5300c3a48",
    "photo-1460661419201-fd4cecdfde94": "photo-1547891654-e66ed7ebb968",
}

DEMO_EVENT_IMAGE_PATHS = {
    "demo-event-kirov-jazz": "demo-jazz-party.jpg",
    "demo-event-kirov-run": "demo-run.jpg",
    "demo-event-kirov-art": "demo-art.jpg",
    "demo-event-kirov-tech": "demo-tech.jpg",
    "demo-event-kirov-party": "demo-jazz-party.jpg",
}

USER_AGENT = "AndexEvents-Seed/1.0"


def unsplash_download_url(slug: str, width: int = 900) -> str:
    slug = DOWNLOAD_FALLBACKS.get(slug, slug)
    return f"https://images.unsplash.com/{slug}?w={width}&auto=format&fit=crop&q=80"


def public_upload_path(bucket: str, filename: str) -> str:
    return f"/uploads/{bucket}/seed/{filename}"


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
    if dest.exists() and dest.stat().st_size > 0:
        print(f"  skip download (exists) {dest.name}")
        return

    subprocess.run(
        [
            "curl",
            "-fsSL",
            "-A",
            USER_AGENT,
            "-o",
            str(dest),
            url,
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    size = dest.stat().st_size
    if size < 1024:
        raise RuntimeError(f"Suspiciously small download ({size} bytes) for {url}")

    print(f"  downloaded {dest.name} ({size // 1024} KB)")


def upload_to_minio(local_file: Path, bucket: str, filename: str) -> None:
    object_key = f"seed/{filename}"
    container_dest = f"/tmp/{bucket}-{filename}"

    subprocess.run(
        ["docker", "cp", str(local_file), f"{MINIO_CONTAINER}:{container_dest}"],
        check=True,
        capture_output=True,
        text=True,
    )

    run_mc(
        "cp",
        container_dest,
        f"{MINIO_ALIAS}/{bucket}/{object_key}",
        "--attr",
        "Content-Type=image/jpeg",
    )
    print(f"  uploaded {bucket}/{object_key}")


def collect_profile_slugs_from_sql() -> dict[str, str]:
    """slug -> bucket (avatars or photos)"""
    result: dict[str, str] = {}
    for sql_file in SEED_SQL_FILES:
        if sql_file.name == "seed_demo_events.sql":
            continue
        if not sql_file.exists():
            continue
        text = sql_file.read_text(encoding="utf-8")
        lines = text.splitlines()
        in_photo_url = False
        for line in lines:
            if '"photoUrl"' in line or line.strip().startswith('"photoUrl"'):
                in_photo_url = True
            for match in UNSPLASH_RE.finditer(line):
                slug = match.group(1)
                if slug in EVENT_PHOTOS:
                    continue
                if in_photo_url or '"photoUrl"' in line:
                    result[slug] = "avatars"
                else:
                    result.setdefault(slug, "photos")
            if line.strip().endswith("ARRAY[") or line.strip().startswith("ARRAY["):
                in_photo_url = False
            if line.strip().startswith("'") and '"photoUrl"' not in line:
                in_photo_url = False
    return result


def slug_to_upload_path(slug: str, bucket: str) -> str:
    if slug in EVENT_PHOTOS:
        return public_upload_path("events", EVENT_PHOTOS[slug])
    return public_upload_path(bucket, f"{slug}.jpg")


def build_url_mapping(profile_slugs: dict[str, str]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    all_slugs = set(profile_slugs) | set(EVENT_PHOTOS)
    for slug in all_slugs:
        if slug in EVENT_PHOTOS:
            path = public_upload_path("events", EVENT_PHOTOS[slug])
        else:
            path = public_upload_path(profile_slugs[slug], f"{slug}.jpg")
        for width in (800, 900, None):
            if width:
                mapping[f"https://images.unsplash.com/{slug}?w={width}"] = path
            mapping[f"https://images.unsplash.com/{slug}"] = path
    return mapping


def patch_sql_files(url_mapping: dict[str, str]) -> None:
    for sql_file in SEED_SQL_FILES:
        if not sql_file.exists():
            continue
        original = sql_file.read_text(encoding="utf-8")
        updated = original
        for old_url, new_path in sorted(url_mapping.items(), key=lambda x: -len(x[0])):
            updated = updated.replace(old_url, new_path)
        updated = UNSPLASH_RE.sub(
            lambda m: slug_to_upload_path(
                m.group(1),
                "events" if m.group(1) in EVENT_PHOTOS else "photos",
            ),
            updated,
        )
        if updated != original:
            sql_file.write_text(updated, encoding="utf-8")
            print(f"patched {sql_file.relative_to(ROOT)}")


def patch_demo_events_sql() -> None:
    sql_file = ROOT / "scripts" / "seed_demo_events.sql"
    text = sql_file.read_text(encoding="utf-8")
    for event_id, filename in DEMO_EVENT_IMAGE_PATHS.items():
        path = public_upload_path("events", filename)
        pattern = re.compile(
            rf"('{re.escape(event_id)}',[\s\S]*?\n\s*0,\n\s*)''",
            re.MULTILINE,
        )
        text, count = pattern.subn(rf"\1'{path}'", text, count=1)
        if count == 0:
            pattern2 = re.compile(
                rf"('{re.escape(event_id)}',[\s\S]*?\n\s*0,\n\s*)'[^']*'",
                re.MULTILINE,
            )
            text, _ = pattern2.subn(rf"\1'{path}'", text, count=1)
    sql_file.write_text(text, encoding="utf-8")
    print(f"patched demo event images in {sql_file.relative_to(ROOT)}")


def write_db_update_sql() -> Path:
    lines = ["-- Point demo events at MinIO-hosted seed images.", "BEGIN;", ""]
    for event_id, filename in DEMO_EVENT_IMAGE_PATHS.items():
        path = public_upload_path("events", filename)
        lines.append(
            f'UPDATE events."Event" SET "imageUrl" = \'{path}\', "updatedAt" = NOW()\n'
            f'WHERE "id" = \'{event_id}\';'
        )
    lines.extend(["", "COMMIT;", ""])
    out = ROOT / "scripts" / "update_demo_event_images.sql"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main() -> int:
    profile_slugs = collect_profile_slugs_from_sql()
    print(f"Profile photos: {len(profile_slugs)} slug(s), events: {len(EVENT_PHOTOS)} slug(s)")

    ensure_mc_alias()

    uploaded_keys: set[str] = set()

    for slug, filename in EVENT_PHOTOS.items():
        key = f"events/seed/{filename}"
        if key in uploaded_keys:
            continue
        local_file = ASSETS_DIR / "events" / filename
        download_image(unsplash_download_url(slug, width=800), local_file)
        upload_to_minio(local_file, "events", filename)
        uploaded_keys.add(key)

    for slug, bucket in sorted(profile_slugs.items()):
        filename = f"{slug}.jpg"
        key = f"{bucket}/seed/{filename}"
        if key in uploaded_keys:
            continue
        local_file = ASSETS_DIR / bucket / filename
        download_image(unsplash_download_url(slug, width=900), local_file)
        upload_to_minio(local_file, bucket, filename)
        uploaded_keys.add(key)

    url_mapping = build_url_mapping(profile_slugs)
    MAPPING_FILE.parent.mkdir(parents=True, exist_ok=True)
    MAPPING_FILE.write_text(
        json.dumps(url_mapping, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {MAPPING_FILE.relative_to(ROOT)}")

    patch_sql_files(url_mapping)
    patch_demo_events_sql()
    db_sql = write_db_update_sql()
    print(f"wrote {db_sql.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout or str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
