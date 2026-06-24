#!/usr/bin/env python3
"""Generate diploma appendix: caption + full file (4–5 files, ~30 pages each)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

# ~42 lines/page → 30 pages ≈ 1260 lines of code per document
MAX_LINES_PER_DOC = 1260

FileBlock = tuple[str, str]

CLIENT_FILES: list[FileBlock] = [
    ("lib/presentation/home/screens/map_explore_screen.dart", "Экран карты и загрузка событий по viewport"),
    ("lib/presentation/auth/bloc/auth_bloc.dart", "BLoC авторизации"),
    ("lib/core/utils/match_recommendation_utils.dart", "Ранжирование кандидатов для ленты"),
    ("lib/core/http/api_client.dart", "HTTP-клиент с Bearer-токеном"),
]

SERVER_FILES: list[FileBlock] = [
    (
        "services-java/events-service/src/main/java/com/andexevents/events/repo/EventRepository.java",
        "Репозиторий событий (PostGIS)",
    ),
    (
        "services-java/users-service/src/main/java/com/andexevents/users/util/MatchRecommendationScorer.java",
        "Скорер ленты знакомств",
    ),
    (
        "services/match-service/internal/repository/match_repository.go",
        "Репозиторий свайпов и взаимных матчей",
    ),
    (
        "services-java/events-service/src/main/java/com/andexevents/events/auth/AuthFilter.java",
        "Фильтр JWT-авторизации",
    ),
    (
        "services-java/events-service/src/main/java/com/andexevents/events/auth/FirebaseJwtVerifier.java",
        "Верификация Firebase JWT (JWKS)",
    ),
]


def file_line_count(rel_path: str) -> int:
    path = ROOT / rel_path
    if not path.exists():
        return 0
    return len(path.read_text(encoding="utf-8", errors="replace").splitlines())


def render_file(rel_path: str, caption: str) -> str:
    path = ROOT / rel_path
    if not path.exists():
        code = f"// файл не найден: {rel_path}"
    else:
        code = path.read_text(encoding="utf-8", errors="replace").rstrip("\n")
    return f"{rel_path} — {caption}\n\n{code}"


def build(files: list[FileBlock]) -> str:
    return "\n\n".join(render_file(path, caption) for path, caption in files) + "\n"


def main() -> None:
    client_path = DOCS / "appendix_client_code.md"
    server_path = DOCS / "appendix_server_code.md"

    for label, files in [("client", CLIENT_FILES), ("server", SERVER_FILES)]:
        total = sum(file_line_count(p) for p, _ in files)
        # caption lines: 2 per file + blank between blocks
        overhead = len(files) * 3
        est = total + overhead
        print(f"{label}: {len(files)} files, {total} LOC, ~{est / 42:.0f} pp")
        if est > MAX_LINES_PER_DOC + 80:
            print(f"  warning: may exceed 30 pages")

    client = build(CLIENT_FILES)
    server = build(SERVER_FILES)
    client_path.write_text(client, encoding="utf-8")
    server_path.write_text(server, encoding="utf-8")
    print(f"wrote {client_path} ({len(client.splitlines())} lines)")
    print(f"wrote {server_path} ({len(server.splitlines())} lines)")


if __name__ == "__main__":
    main()
