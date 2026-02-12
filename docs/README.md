# Andex Events - Документация проекта

Добро пожаловать в документацию проекта **Andex Events**! 

## 📚 Содержание документации

### 🎯 Начало работы

Если вы впервые работаете с проектом, начните с главного [README.md](../README.md) в корне проекта.

### 📖 Архитектурная документация

1. **[Architecture Analysis](./architecture-analysis.md)** ⭐ **ГЛАВНЫЙ ДОКУМЕНТ**
   - Полный анализ архитектуры проекта
   - Модель данных (Prisma Schema)
   - Система хранения изображений
   - Аутентификация и авторизация
   - Backend и Frontend архитектура
   - Геолокация и PostGIS
   - Безопасность
   - Рекомендации по улучшению

2. **[Architecture Diagrams](./architecture-diagrams.md)**
   - Визуальные диаграммы системы
   - Entity Relationship Diagram (ERD)
   - Потоки данных (Data Flow)
   - Диаграммы последовательности
   - Схемы безопасности
   - BLoC архитектура

3. **[Quick Reference](./quick-reference.md)** ⚡ **ШПАРГАЛКА**
   - Быстрые команды для разработки
   - API endpoints справочник
   - PostGIS запросы примеры
   - BLoC паттерны
   - Prisma CLI команды
   - Отладка и troubleshooting

4. **[Conclusions and Recommendations](./conclusions-and-recommendations.md)**
   - Итоговые выводы по проекту
   - Сильные и слабые стороны
   - План приоритизации улучшений
   - Метрики успеха
   - Roadmap развития

### 🔧 Специфичная документация

5. **[Local Storage Guide](./local-storage-guide.md)**
   - Локальное хранилище изображений
   - Альтернатива Supabase Storage
   - Архитектура хранения файлов

6. **[Supabase Image Upload Notes](./supabase-image-upload-working-notes.md)**
   - Рабочий вариант загрузки в Supabase
   - Troubleshooting guide
   - Важные детали реализации

### 📝 Документация для учебных заведений

7. **[Отчет по практике](./internship-report.md)** 🎓 **ДЛЯ КОЛЛЕДЖА**
   - Полный отчет по практике на тему "Проектирование модели данных"
   - Все разделы для защиты практики
   - Анализ предметной области
   - ER-диаграммы и SQL-скрипты
   - Оптимизация и безопасность
   - Список литературы и приложения

8. **[Детальное описание БД и хранилища](./detailed-database-and-storage.md)** 📊
   - Подробное описание каждой таблицы с примерами
   - Все поля, типы данных, ограничения
   - Индексы и их обоснование
   - Примеры SQL запросов
   - Бизнес-правила для каждой таблицы
   - Prisma Schema для всех моделей

9. **[Интеграция Supabase](./supabase-integration-detailed.md)** 🔐
   - Полная настройка Supabase проекта
   - Authentication (Email, Google, Apple)
   - Storage buckets и policies
   - Верификация JWT на backend
   - Сравнение подходов к хранению файлов
   - Код примеры для Flutter и Node.js

---

## 🚀 Быстрый старт для разработчиков

### Backend

```bash
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

### Flutter

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

### Настройка Yandex MapKit

```bash
sh ./scripts/store_yandex_key.sh <YANDEX_MAPKIT_KEY>
```

---

## 📊 Структура документации

```
docs/
├── README.md                                    # Этот файл
├── java-migration-plan-users-auth-events.md      # План миграции Go→Java (users/auth/events)
├── architecture-analysis.md                     # Полный анализ (ГЛАВНЫЙ)
├── architecture-diagrams.md                     # Визуальные диаграммы
├── quick-reference.md                           # Шпаргалка разработчика
├── conclusions-and-recommendations.md           # Выводы и рекомендации
├── local-storage-guide.md                       # Локальное хранилище
├── supabase-image-upload-working-notes.md      # Supabase заметки
├── internship-report.md                         # Отчет по практике (для колледжа)
├── detailed-database-and-storage.md            # Детальное описание БД
└── supabase-integration-detailed.md            # Интеграция Supabase
```

---

## 🎓 Для кого эта документация

### Новые разработчики
👉 Начните с [Quick Reference](./quick-reference.md) для быстрого старта

### Архитекторы и Tech Leads
👉 Читайте [Architecture Analysis](./architecture-analysis.md) для полного понимания системы

### DevOps инженеры
👉 Смотрите раздел "Deployment" в [Architecture Analysis](./architecture-analysis.md)

### Тестировщики
👉 Изучите [Quick Reference](./quick-reference.md) → раздел "API Endpoints"

### Product Managers
👉 Читайте [Conclusions and Recommendations](./conclusions-and-recommendations.md) для понимания состояния проекта

### Студенты и учащиеся
👉 Используйте [Internship Report](./internship-report.md) как основу для отчета по практике
👉 Изучите [Detailed Database and Storage](./detailed-database-and-storage.md) для глубокого понимания БД

### Database Administrators
👉 Смотрите [Detailed Database and Storage](./detailed-database-and-storage.md) для полной схемы БД и индексов

### Backend разработчики
👉 Читайте [Supabase Integration](./supabase-integration-detailed.md) для настройки аутентификации и storage

---

## 🔑 Ключевые концепции проекта

### Модель данных

```
User ──1:N──> Event (создатель)
User ──N:M──> Event (через Participant)
User ──N:M──> User (через Match - Tinder-style)
User ──1:N──> Notification
```

### Технологический стек

**Frontend:** Flutter 3.9.2+ (BLoC, Material 3, Yandex MapKit)  
**Backend:** Node.js + TypeScript (Express, Prisma, PostgreSQL + PostGIS)  
**Auth:** Supabase Auth (JWT)  
**Storage:** Supabase Storage / Local files  

### Основные фичи

- 🗺️ Карта событий с Yandex MapKit
- 📍 Геопоиск событий в радиусе (PostGIS)
- 💘 Tinder-style матчинг пользователей
- 🎫 Создание и участие в событиях
- 👤 Профили с интересами
- 📸 Загрузка и оптимизация изображений

---

## 📈 Текущее состояние проекта

**Версия:** MVP (60-70% готовности)  
**Статус:** Active development  

### ✅ Реализовано

- Аутентификация (Email/Password, Google, Apple)
- Создание и просмотр событий
- Карта событий
- Матчинг пользователей
- Профили и онбординг
- Загрузка изображений

### 🚧 В разработке

- Чаты между матчами
- Push-уведомления (FCM)
- Отзывы о событиях
- Расширенная модерация

### 📋 Планируется

- Unit и E2E тесты
- Кеширование (Redis)
- Горизонтальное масштабирование
- Monitoring (Prometheus + Grafana)

---

## 🐛 Нашли ошибку в документации?

Если вы нашли неточность или устаревшую информацию:

1. Создайте Issue в репозитории
2. Или сразу отправьте Pull Request с исправлениями
3. Укажите какой документ и какой раздел нуждается в обновлении

---

## 📞 Контакты и поддержка

- **GitHub Issues:** [github.com/YOUR_USERNAME/andexevents/issues](https://github.com)
- **Email:** support@andexevents.com (если применимо)
- **Telegram:** @andexevents (если применимо)

---

## 📝 История изменений документации

| Дата | Версия | Изменения |
|------|--------|-----------|
| 2024-12-13 | 1.0 | Первая версия полной документации |
| 2024-12-13 | 1.1 | Добавлены: отчет по практике, детальное описание БД, интеграция Supabase |

---

**Составлено:** 2024-12-13  
**Последнее обновление:** 2024-12-13  

---

## 📦 Полный список файлов документации

### Для разработчиков:
- ✅ `architecture-analysis.md` - 1854 строки - Полный анализ архитектуры
- ✅ `architecture-diagrams.md` - 1314 строк - Визуальные диаграммы
- ✅ `quick-reference.md` - 604 строки - Шпаргалка
- ✅ `conclusions-and-recommendations.md` - 991 строка - Выводы и план развития

### Для студентов:
- 🎓 `internship-report.md` - 1363 строки - Отчет по практике
- 📊 `detailed-database-and-storage.md` - 1512 строк - Детальное описание БД
- 🔐 `supabase-integration-detailed.md` - 1230 строк - Интеграция Supabase

### Специализированные гайды:
- 📁 `local-storage-guide.md` - Локальное хранилище
- 📝 `supabase-image-upload-working-notes.md` - Рабочие заметки

**Общий объем документации:** ~8,900+ строк кода и текста 📚

**Happy Coding! 🚀**