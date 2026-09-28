# ADR 0020: Event Source Ingestion

- Status: Proposed
- Date: 2026-09-26 (revised 2026-09-27)
- Deciders: Recharge team (pending)
- Related: ADR 0011, ADR 0013, ADR 0015, ADR 0016, ADR 0019,
  `docs/architecture/ARCHITECTURE_BASELINE.md`,
  `docs/api/API_CONTRACTS_WORKFLOW.md`,
  `docs/product/EVENT_CLASSIFICATION_SPEC.md` §15, §18,
  `docs/product/EVENT_CREATE_SPEC.md` §15–§17,
  `docs/product/EVENT_SOURCE_INGESTION_SPEC.md` (v1.7-draft, product specification),
  `docs/product/EVENT_SOURCE_INGESTION_BACKEND_SPEC.md` (BCK-23 v0.4, Draft),
  `docs/product/EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md` (master roadmap),
  `docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md` (§31.1, OD-03)

Нормативный комплект — этот ADR, продуктовая спецификация, BCK-23 и master
roadmap. Бриф, краткий бриф, общий план E0–E9 и концепция — non-normative.

## Context

Операторы заведений публикуют события на своих сайтах и в календарях. Ручной
ввод каждого Event в Recharge не масштабируется. Event Classification §18
определяет source record, ключ уникальности внешних записей, владение полями и
запрет автоматического нечёткого слияния, но не определяет, кто, где и как
получает данные из источников.

Факты на 2026-09-28. Совместимость задаётся минимальными версиями
BCK-документов из шапки BCK-23; last verified against —
`codex/backend-stage8-critical-repair` @ `526f497` (non-normative):

- **local/Emulator backend foundation существует**: R1-платформа,
  Identity/Publisher, Reference Data, Security/Privacy и отключённый Booking;
  BCK-02 v2.4.99 §31.1 резервирует Event Ingestion без номера; BCK-07 v0.7
  содержит входы
  delegated import (`originBinding`, класс изменения, идемпотентность
  не-сессионного актора);
- **отсутствуют**: runtime Event Ingestion, облачные ресурсы, Firestore-хранение
  Content (`BCK07-LOCAL-01` — только in-memory), делегация сервисного модуля в
  BCK-06, связь Page↔Place, принятые сроки хранения (BCK04-OD-07), транспорт
  workers; OD-03 открыт;
- mobile в стабилизации; у Event в mobile нет `placeId` и provenance.

Новая mobile-фича и новый cross-language контракт — изменения baseline:
ADR 0011 и Architecture Baseline п.10 требуют Accepted ADR, API Contracts
Workflow §1 — Accepted ADR для language-neutral схемы нового домена.

## Decision

1. **Модуль.** Backend-модуль Event Source Ingestion (BCK-23,
   `apps/backend/functions/src/modules/event_ingestion/`, item **6E** BCK-02) —
   единственный writer записей `EventSource`, `SyncRun`, `SourceEventRecord`,
   `ReviewItem` и своих async-операций. Event, occurrences, ревизии,
   модерация и `ContentProvenance` — BCK-07; делегация и связь Page↔Place —
   BCK-06; Place — BCK-07; availability и API провайдеров — BCK-16.
2. **Источники.** Источник подключается явно к опубликованному Place с
   подтверждённой страницей оператора и записанным основанием. Поиск
   источников в интернете не выполняется. V1: `ical` и `jsonLd`
   (`origin = apiSynced`); `rss`, `jsonFeed`, `ticketPlatform` (ECL-04/05 через
   BCK-16) — отдельными slices; разбор HTML-вёрстки не имеет разрешённого
   origin (Event spec §18.1).
3. **Граница получения.** V1 не принимает явные credentials и известные
   auth-параметры в URL; человек подтверждает, что endpoint предназначен для
   публичного получения; полный URL — restricted operational data, не
   попадает в projection, audit, ошибки и телеметрию (только хост и hash);
   credential-bearing и приватные фиды — вне V1. JSON-LD — только ограниченное
   извлечение блоков `<script type="application/ld+json">`; DOM scraping,
   визуальный разбор HTML, microdata, RDFa, выполнение JavaScript и переход по
   ссылкам запрещены. iCal V1 — ограниченное подмножество; сложные повторения
   и `RECURRENCE-ID` — отдельным подэтапом после conformance.
4. **Логика только на сервере.** Чтение, разбор, сопоставление и дубли — только
   в BCK-23. Mobile — управление источниками, очередь и отображение provenance.
   Совпадение поведения обеспечивают данные: этот ADR авторизует
   `packages/api_contracts/schema/event_ingestion/v1/` как cross-language
   контракт (схемы, fixtures, conformance-эталоны).
5. **Запись Event.** Ingestion не пишет Event; он вызывает команды BCK-07 от
   делегированного import-актора (`originBinding.kind = delegatedImport`).
   Импортированное событие проходит ту же publish-валидацию и модерацию, что и
   ручное (Create §15–§16); изменения опубликованного — revision policy
   Create §17.2. Публикация без модерации — только по политике BCK-07 §8.4
   отдельным решением.
6. **Делегация.** Worker действует только по постоянной делегации страницы
   `EventIngestionDelegation` (writer — BCK-06: `delegationId`, точная
   страница, scope, ревизия, срок, отзыв) и никогда — от имени
   пользовательской Session. Admin/staff не становится publisher и не
   отправляет события от имени страницы (Event spec §15.1, ADR 0016). Place
   без страницы оператора — вне scope до отдельного ADR.
7. **Идентичность.** Связь внешнего события — `sourceId + externalUid +
   recurrenceKey`; повторная синхронизация — идемпотентный upsert по ней
   (Event spec §18.2). Автоматически одним событием считаются только записи с
   одинаковой идентичностью; похожие и даже точно совпадающие события разных
   источников объединяет только человек (Event spec §18.4).
8. **Владение полями** (Event spec §18.3): operational-поля прикреплённого
   импорта не редактируются в Recharge; content-поля можно закрепить; overlay
   принадлежит Recharge; «отвязать от источника» переводит событие в ручное.
   Классификация берётся из профиля импорта, явно выбранного человеком.
   Отсутствующие цена, изображение и описание остаются отсутствующими;
   обложки по умолчанию нет.
9. **Пропажа и отмена.** Будущая дата, пропавшая из источника на двух
   успешных проверках подряд, скрывается из показа — без отмены и
   уведомлений — и уходит на проверку команде заведения; вернувшаяся в
   источник дата снова показывается. Отменяют только явный статус
   «отменено» в источнике (применяется сразу; server flag — аварийный
   выключатель) или подтверждение команды.
10. **Mobile.** Добавляется фича `apps/mobile/lib/features/event_sources/`
    (`domain/data/application/presentation`, без cross-feature import).
11. **Предпосылки** — Event `placeId` и provenance, опубликованный Place,
    `PagePlaceOperatorLink`, делегация, Content persistence, запрос Content по
    `externalBindingRef` — реализуются владельцами своих модулей.
12. **OD-03.** EVS — вход в OD-03; облачная реализация (EVS-DEV-01 и далее)
    — только после OD-03 Accepted.

## Что разрешает и не разрешает этот ADR

**Принятие ADR само по себе не разрешает код.**

После того как ADR получит статус Accepted, этап B0 master roadmap будет
завершён и отдельный слайс будет утверждён, разрешено только следующее:

1. **EVS-LOCAL-01a (backend-трек, item 6E):** JSON-схемы, fixtures и
   conformance-эталоны в `packages/api_contracts/schema/event_ingestion/v1/`,
   TS-контракты в `apps/backend/functions/src/contracts/` и чистый domain
   `apps/backend/functions/src/modules/event_ingestion/domain/` с unit- и
   contract-тестами — строго по карте BCK-23 §20.1.
2. **Mobile E2 (стабилизация):** фича `features/event_sources/` на
   Dart-фикстурах демо за `EventSourcesRuntimeConfig.enabled = false` и
   mock-capabilities с ID каталога BCK-06 — по отдельному Approved slice spec.

Каждый следующий backend-слайс (01b, 01c, 02, 03, 04, dev, staging,
production) требует своего утверждённого решения по master roadmap.

**Остаются запрещены до своих отдельных решений:**

- Firebase, Firestore-адаптеры, Rules и индексы EVS, Functions exports и
  workers, provisioning и облачные ресурсы;
- любые сетевые запросы к источникам — из backend, mobile и тестов;
- реальные источники и реальные данные заведений;
- публикация, модерация и уведомления по импортированным событиям;
- изменения Event Details, Event Edit и других features;
- служебная staff-страница как publisher;
- `htmlPage`, соцсети, `ticketPlatform`, credential-bearing и приватные фиды;
- новый Create-тип.

## Consequences

- Нужны: регистрация BCK-23 в BCK-02 как 6E; поправки BCK-05 (сеть, бюджет,
  restore), BCK-06 (права, делегация, `PagePlaceOperatorLink`), BCK-20 (набор
  маппинга категорий); сроки хранения в BCK04-OD-07.
- Модель Event расширяется additive-полями, полезными и для ручных событий.
- Часть импортированных событий потребует дополнения оператором (краткое
  описание, обложка) — цена единой publish-валидации.
- До пилота нужны Legal review, robots-политика и публичная страница бота.

## Alternatives considered

- **Импорт на клиенте** — отклонено: SSRF, robots, нагрузка, секреты
  (инвариант №16), нет фоновой синхронизации.
- **Dart-прототип сопоставления в mobile** — отклонено: вторая реализация той
  же логики.
- **Часть BCK-16** — отклонено как основной вариант: BCK-16 — API провайдеров
  с учётными данными, availability и handoff; BCK-16 остаётся транспортом
  `ticketPlatform`.
- **Часть BCK-07** — отклонено: acquisition смешался бы с жизненным циклом
  контента; BCK-07 получает только команды.
- **Действия worker от имени Session согласившегося человека** — отклонено:
  права человека меняются и истекают; нужна постоянная, отзываемая делегация
  страницы.
- **Служебная страница Recharge как publisher** — отложено: противоречит
  Event spec §15.1 и ADR 0016 без отдельного решения.
- **Автоматическое объединение, в том числе по точному совпадению между
  источниками** — отклонено для V1: Event spec §18.4.
- **Hotlink изображений и обложка по умолчанию** — отклонено: раскрытие IP
  пользователей и выдуманный контент.

## Rollback

Флаги `event-ingestion.*` (`FirestoreFeatureFlagGate`, по рынкам) выключены по
умолчанию; `event-ingestion.sync = off` останавливает синхронизацию,
`event-ingestion.source.connect = off` — подключение; импортированные Event
остаются с деградирующей свежестью. Полный откат — revoke источников и
архивирование Event по origin через Admin repair командами Content;
восстановление — coordinated restore BCK-23 §19.1. Mobile-фича скрыта
`EventSourcesRuntimeConfig.enabled = false`.
