# Сводка документации Andex Events

Этот файл — краткий ориентир по документам, которые чаще всего используются при разработке и сопровождении проекта.

## Основные документы

- `../README.md` — обзор репозитория и краткий быстрый старт
- **`technical/README.md`** — модульная техническая документация по текущей архитектуре (основной опорный документ)
- `setup.md` — локальная разработка: инфраструктура, сервисы, переменные окружения, секреты
- `architecture.md` — текущее описание архитектуры (Flutter + backend на Java/Go, PostgreSQL/PostGIS, MinIO, Traefik)
- `api-reference.md` — справочник API (публичные пути через Traefik)
- `services.md` — обзор сервисов и зоны ответственности
- `production-deployment.md` + `../DEPLOYMENT_CHECKLIST.md` — выпуск и деплой
- `../ROADMAP.md` — список задач и статус реализации

## Диаграммы и расширенные материалы

- `architecture-diagrams.md` — диаграммы (ERD / data flow / последовательности)
- `security_hardening.md` — меры безопасности и практики hardening

## Исторические/исследовательские документы

В репозитории есть материалы, подготовленные для предыдущих итераций (например, Supabase/Prisma/Node). Их можно использовать как справочную базу и историю решений, но они могут не соответствовать текущей реализации.

- `architecture-analysis.md`
- `conclusions-and-recommendations.md`
- `quick-reference.md` (обновляется отдельно; некоторые разделы могут отсылать к legacy)
- `supabase-integration-detailed.md`
- `supabase-image-upload-working-notes.md`
- `detailed-database-and-storage.md`

## Учебные материалы

- `legacy/internship-report.md`