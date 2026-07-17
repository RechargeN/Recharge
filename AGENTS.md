# RECHARGE — инструкции для coding-агентов

Версия: 2026-07-17. Канонический файл инструкций репозитория.
CLAUDE.md ссылается сюда. При обновлении меняй дату версии.

## Приоритет документов (при конфликте — верхний побеждает)

1. **Accepted ADR** — `docs/adr/` (архитектурные решения)
2. **Spec текущего slice** — активная задача
3. **LAUNCH_STATUS** — `docs/architecture/LAUNCH_STATUS.md`
4. **Product vision** — продуктовое видение (раздел ниже + docs/)

Этот файл описывает правила работы; фактическая архитектура —
в `docs/architecture/ARCHITECTURE_BASELINE.md`. Если код противоречит
Accepted ADR — прав ADR; исправление кода оформляется задачей,
изменение решения — новым ADR, суперсидящим старый.

## Структура репозитория (monorepo)

```
apps/mobile/               # Flutter-приложение
packages/design_system/    # дизайн-токены, общие UI-компоненты
packages/api_contracts/    # контракты данных
docs/adr/                  # ADR (источник истины по решениям)
docs/architecture/         # ARCHITECTURE_BASELINE, LAUNCH_STATUS
```

Слои внутри apps/mobile: domain / data / **application** (контроллеры,
по frozen baseline) / presentation. Дизайн-токены живут в
`packages/design_system`, НЕ в app/theme.

## Команды (рабочая директория обязательна)

- Из корня: Melos-скрипты (см. melos.yaml)
- Или из `apps/mobile/`: `flutter pub get`, `flutter analyze`,
  `flutter test`, `flutter run`
- Перед завершением любого slice: `flutter analyze` и `flutter test`
  должны быть зелёными. Slice без зелёных проверок не считается Done.

## Разрешённые конфликты (решения приняты, не пересматривать молча)

1. **Роли** — по ADR 0013: `User / Creator / Admin` +
   capability-based permissions. «Pro generator» — это НЕ отдельная
   роль, а Creator + закреплённая ManagedPage + capabilities
   (manage_page, view_insights, manage_bookings). Продуктовые
   «3 уровня» — терминология UI, не модели.
2. **ID** — по ADR: ULID/UUID, генерация на клиенте. Временные `loc_*`
   допустимы ТОЛЬКО для несохранённых локальных черновиков и обязаны
   заменяться постоянным ULID при публикации. Все связи между
   сущностями — только по id, без ссылок по имени.
3. **Firebase** — целевой бэкенд (Auth: Google/Apple, Firestore,
   Storage). Текущее состояние — mock datasources. Подключение
   Firebase — отдельный slice ПОСЛЕ стабилизации.
4. **Create Hub** — целевой скоуп 10 типов через единый form engine.
   Базовый runtime всех 10 типов реализован через единый config-driven
   flow и Category System v1.4.1. Специализированные секции конкретных
   типов расширять только отдельными acceptance criteria.
5. **Регион запуска** — Рига/Латвия, EUR. Дефолтные координаты
   в конфиге: 56.9496, 24.1052 (сейчас неверные — задача бэклога).
   Локализация en/ru/lv — целевая, фактически НЕ настроена
   (нет lib/l10n) — отдельный slice.

## Текущий slice: СТАБИЛИЗАЦИЯ (активен)

Никаких новых фич, пока не выполнены критерии приёмки:
1. Рабочее дерево чистое: изменения раскиданы по осмысленным коммитам,
   build/cache-артефакты удалены из индекса и добавлены в .gitignore.
2. `flutter analyze` — 0 ошибок (из apps/mobile).
3. `flutter test` — все тесты проходят; тесты, требующие починки, —
   починить или явно пометить skip с TODO-ссылкой на задачу.
4. Slices в статусе Review перепроверены: либо подтверждены зелёными
   проверками, либо возвращены в Doing с описанием, что сломано.
5. LAUNCH_STATUS.md обновлён до фактического состояния.
6. README заменён с Flutter-заглушки на краткое описание проекта
   и команд.
7. Placeholder-URL (example.com для Privacy/Terms/Support) собраны
   в один конфиг с TODO — не разбросаны по коду.

## Статусы фич (обновлять при изменении)

| Область | Статус |
|---|---|
| Discover (search/map/feed/details) | mock-данные |
| Create Hub: 10 типов | базовый config-driven runtime реализован, на mock |
| Category System v1.4.1 | реализовано: 28 категорий / 516 подкатегорий, legacy migration |
| Auth | mock, целевое: Firebase Google/Apple |
| Роли/capabilities guards | НЕ реализовано (router проверяет только auth) |
| Publisher / ManagedPage модель | запланировано |
| Отзывы (Review) | запланировано (в MVP) |
| Smart Search | реализовано: rule-based parser, история и route-intent; mock-хранилище |
| Route/Scenario Builder | реализовано: локальные маршруты и handoff между Search/Map/Create |
| Локализация en/ru/lv | не настроена |
| Бронирование | MVP: редирект на externalBookingUrl; оплата — post-MVP |
| Геолокация | mock current location |

## Правила разработки

1. UI не содержит бизнес-логику; контроллеры — в слое application.
2. Сложная логика — в usecases; новый usecase → интерфейс
   в domain/repositories.
3. Все сущности имеют ULID `id`; связи только по id. Publisher-модель:
   контент публикуется от имени `{type: user | page, id}`.
4. Create-типы — только через form engine и декларативный конфиг
   секций; НЕ создавать отдельный флоу-код на тип. Секции могут быть
   типо-специфичными (RouteMapBuilder, RecurrenceSchedule и т.д.).
5. Не хардкодить регион/язык/валюту — enum + модель.
6. Данные из бэкенда — только через data/datasources; UI и domain
   не знают про Firestore.
7. Дизайн-токены и общие компоненты — в packages/design_system.
   Основной цвет: #0B3028, стиль: минимализм, скруглённые карточки.
8. Не трогать без запроса: сгенерированные файлы (*.g.dart,
   *.freezed.dart), docs/adr (только новые ADR, не правка старых),
   assets.
9. Перед крупным куском — план файлов без кода, ждать подтверждения.
   После изменений — краткий список затронутых файлов.
10. Ссылки/детали продуктового видения (экраны, filter flow, роли UI,
    10 create-типов) — см. docs/product/VISION.md (перенести туда
    текущий CLAUDE-контент; до переноса — раздел ниже).

## Product vision (кратко; приоритет 4)

Recharge — приложение подбора и создания досуга: события, места,
маршруты, активности. Ядро: единый filter flow
search → filters → map → feed → details с одним общим состоянием
фильтров (обычный Search, Smart Search, карта, категории, лента).
Bottom nav: Home / Favorites / Smart Search / Notifications / Profile;
Search и Map — кнопки на Home. Карта: радиус-зона, двухстрочный блок
фильтров, левая шторка объектов. Route/Scenario Builder — ключевая
уникальность (точки, логистика, суммарный бюджет/время).
Карта-провайдер: Google Maps. Отзывы и рейтинги — в MVP.
Find People — полноценный MapObject в общей выдаче.
