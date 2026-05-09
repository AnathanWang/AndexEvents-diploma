# 13. Прочая документация и legacy

## 13.1 Источник истины по текущей системе

При противоречии между документами приоритет:

1. **Исполняемый код** и **`deployments/docker/docker-compose.yml`**
2. Модуль **`docs/technical/`** (данная папка)
3. **`docs/setup.md`**, **`docs/api-reference.md`**, **`docs/services.md`**
4. Прочие файлы в `docs/` — по пометкам об актуальности

## 13.2 Устаревшие или исторические материалы в `docs/`

Следующие документы отражали прежние итерации (Supabase, Prisma, Node.js, монолитный backend и т.д.) или содержат объёмные аналитические выводы фиксированной даты:

- `architecture-analysis.md`
- `detailed-database-and-storage.md` (часть про Prisma)
- `supabase-integration-detailed.md`
- `supabase-image-upload-working-notes.md`
- `local-storage-guide.md`
- отчёт **`legacy/internship-report.md`** — учебный текст, не спецификация продукта

Их можно использовать как **архив решений** и для работы с историей проекта, но поля «как работает сейчас» нужно сверять с **`docs/technical/`** и кодом.

## 13.3 Legacy-код

Старые Go-реализации auth/users/events при наличии описаны в **`docs/changelog.md`** и могут находиться в **`legacy/go-services/`**.

## 13.4 Поддержание модульной документации

При изменении контракта API или инфраструктуры обновляйте:

| Изменение | Где отразить |
|-----------|----------------|
| Новый маршрут Traefik / сервис | `deployments/docker/docker-compose.yml`, [04-api-gateway-traefik.md](./04-api-gateway-traefik.md), `docs/api-reference.md` |
| Новые эндпойнты | `docs/api-reference.md`, при необходимости [05](./05-backend-java.md)/[06](./06-backend-go.md) |
| Новые переменные окружения | `docs/setup.md`, [03-infrastructure-and-docker.md](./03-infrastructure-and-docker.md) |
| Новые бакеты / правила upload | [09-object-storage-uploads.md](./09-object-storage-uploads.md), код `AllowedBucket` |
| Поведение клиента API base URL | [10-flutter-client.md](./10-flutter-client.md), `lib/core/config/app_config.dart` |
