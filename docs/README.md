# Документация Andex Events

Этот файл — **индекс** документации. Актуальный обзор проекта и быстрый старт находятся в корневом `../README.md`.

## Техническая документация (актуальный стек)

- **`technical/README.md`** — модульная техническая документация (оглавление и ссылки на все разделы)
- **`TECHNICAL.md`** — короткая переадресация на папку `technical/`

## 🎯 С чего начать

- **Проект в целом**: `../README.md`
- **Локальный запуск (актуально)**: `setup.md`
- **Roadmap**: `../ROADMAP.md`
- **Production**: `production-deployment.md` + `../DEPLOYMENT_CHECKLIST.md`

## 🧩 Архитектура

- `technical/01-overview.md` и остальные файлы в `technical/` — развёрнутое техническое описание
- `architecture.md` — краткое описание текущей архитектуры (англ.)
- `architecture-diagrams.md` — диаграммы (ERD/flows и т.д.)
- `services.md` — обзор сервисов и их ответственность

## 🔌 API / интеграции

- **`BACKEND_COMPLETE_REFERENCE.md`** — единый подробный конспект по всему backend (Java + Go + Docker + БД + Traefik + секреты)
- `api-reference.md` — справочник по API (если разделы устарели, сверяйтесь с кодом сервисов)
- `flutter-backend-integration-plan.md` — заметки по интеграции клиента с backend

## 🔐 Безопасность

- `security_hardening.md` — чеклист и идеи по усилению безопасности

## 📝 Планы и исследования (могут быть устаревшими)

В репозитории есть документы, написанные под предыдущие итерации (например, Supabase/Prisma/Node). Их можно использовать как справочные заметки, но **не считать источником истины** для текущей реализации.

- `architecture-analysis.md`
- `conclusions-and-recommendations.md`
- `quick-reference.md`
- `supabase-integration-detailed.md`
- `supabase-image-upload-working-notes.md`
- `local-storage-guide.md`
- `java-migration-plan-users-auth-events.md`
- `GOLANG_MIGRATION_PLAN.md`

## 📁 Архив черновиков

- `archive/README.md` — старые планы (`dev-notes/`) и списки рефакторинга, перенесённые из корня репозитория

## 🎓 Legacy / учебные материалы

- `legacy/internship-report.md`