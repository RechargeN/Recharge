# EVENT CREATE — полная логика создания события

- Статус: **Review — reconciled with Accepted Event Classification v2.2.3**
- Версия: 1.4
- Дата: 2026-08-05
- Область: целевая логика блока `Event` в едином Create Hub

> Этот документ описывает конечное production-поведение Event Create, а не
> урезанный MVP-вариант. Он пока не является принятой спецификацией и не
> утверждает, что описанное уже реализовано. Финансовые и booking-возможности
> требуют отдельных ADR, provider selection и legal approval до запуска, но их
> пользовательская и доменная логика зафиксирована здесь полностью.

Связанные источники истины:

- [VISION.md](VISION.md) — продуктовая модель Create Hub и пятишаговый Event flow;
- [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md) — **Accepted
  canonical contract** для Event classification, admission, inventory,
  availability, provenance и границ со смежными aggregates;
- [CATEGORY_SYSTEM.md](CATEGORY_SYSTEM.md) — категории, подкатегории и dynamic criteria;
- [S3_CRT_01_CREATE_SPEC.md](S3_CRT_01_CREATE_SPEC.md) — текущий baseline черновика и публикации;
- [ADR 0013](../adr/0013-domain-policy-baseline.md) — ownership, capabilities,
  lifecycle, ULID, время, бронирование, offline/conflict и moderation;
- [SEARCH_FILTERS_TIME_SPEC.md](SEARCH_FILTERS_TIME_SPEC.md) — event slots и time-fit.

Граница ответственности: этот документ описывает Creator UX, пятишаговый form
flow и production-намерение Event Create. `EVENT_CLASSIFICATION_SPEC.md`
является каноническим источником доменных осей и их инвариантов. При
расхождении по classification, admission, inventory, availability, provenance
или границе со смежным aggregate действует Accepted Event Classification.
Ни один последующий slice не должен создавать параллельную Event-модель.

---

## 0. Как читать документ

### 0.1 Непересматриваемые архитектурные решения

Следующие решения в этой спецификации не являются предметом повторного выбора:

- Event создаётся внутри единого config-driven form engine;
- роли — `User / Creator / Admin`, действия проверяются capabilities;
- Publisher имеет вид `{type: user | page, id}`;
- постоянные идентификаторы — ULID, локальный `loc_*` допустим только до
  публикации;
- timestamps сохраняются в UTC вместе с IANA timezone;
- market запуска — Riga / Latvia, currency — EUR, значения приходят из config;
- cover обязателен для Publish;
- новый Event после Publish входит в moderation pipeline; прямой обход
  capability/moderation policy запрещён;
- payment data обрабатывает только сертифицированный PSP; Recharge не хранит
  PAN/CVV и другие raw card credentials;
- Firebase остаётся целевым application backend, а provider-specific booking,
  payment и media детали изолируются data/integration boundaries.

### 0.2 Фактическое состояние на дату документа

| Область | Уже есть в приложении | Целевое расширение по этой спецификации |
|---|---|---|
| Create type | Config `event` и специализированный пятишаговый Event block внутри общего Create Hub | Декларативные typed section configs/state без отдельного flow и без archetype-ветвления в widget |
| Access | Mock full-access session; router проверяет в основном auth | Creator/capability и Publisher-scoped guards |
| Draft | Typed Event schema v1, local autosave/restore и пользовательские templates; template materialization создаёт независимый draft | Conflict/recovery UX, список drafts и additive ECL schema migration |
| Classification/taxonomy | Category System v1.4.3 materialized 28/530; archetype и participation modes отсутствуют | 34 archetype, primary + secondary participation, canonical ID validation и explicit legacy confirmation |
| Time | Local input → UTC occurrences; one-time/all-day/multi-day/multi-date/recurrence, DST policies и persisted overrides | Override editor, typed admission windows, material revisions и Discover projection |
| Location | Offline/online/hybrid, city/address/meeting point, coordinates и confirmed pin | Typed location kind, Place/venue/Route refs, area/disclosure policies |
| Media | Cover/gallery metadata, required alt text и rights confirmation на local/mock | Production processing, moderation, source/licence and retention pipeline |
| Price/admission | Free/fixed Money; none/onsite/external payment; none/external registration; internal/future modes fail closed | Independent admission/confirmation policies, inventory authority/pools, Booking, provider sync, tickets, payments and refunds |
| Publisher | Legacy organizer-поля; Event typed PublisherRef отсутствует | Один shared PublisherRef `{type, id}`, new-draft workspace default и server-side capability checks |
| Visibility | Public/unlisted; private fail closed | Private access policies и protected secret references |
| Publish | Idempotent local/mock publish → `pending_review`; permanent Event/occurrence IDs | Backend authority, material revision/moderation, Discover eligibility и полный error mapping |
| Post-publish | Базовый success state | Risk-based moderation, revisions, occurrence/series cancel, check-in и refunds |

Этот документ не переводит перечисленные целевые пункты в статус Done и сам по
себе не разрешает реализацию всего production scope. Во время активного
stabilization slice можно реализовывать Event-specific блоки только внутри
существующего config-driven Create Hub, на текущих mock boundaries и по
отдельному Approved slice spec. Firebase, internal Booking, PSP, Payments и
другие backend integrations требуют собственных разрешённых slices и gates.

### 0.3 Product promise

Event Create должен давать Creator ощущение профессионального event-пульта, а
не длинной административной формы:

- любой Event — от бесплатной встречи до платной многодневной series —
  создаётся в одном понятном пятишаговом flow;
- draft невозможно потерять из-за закрытия приложения, сети или неуспешной
  оплаты/публикации;
- Preview совпадает с тем, что увидит attendee;
- schedule, inventory, tickets, access и refund rules прозрачны до Publish;
- Creator всегда понимает, что блокирует публикацию и как это исправить;
- attendee никогда не получает ложного обещания места, цены, возврата или
  online access;
- Publisher может безопасно управлять Event, не получая лишний доступ к payout
  или персональным данным.

### 0.4 UX-принципы

1. Progressive disclosure: сложные ticketing/recurrence настройки появляются
   только после выбора соответствующего режима.
2. Safe defaults: public, market timezone/currency, no registration и zero
   buffers задаются из config, но каждое значение видно и изменяемо.
3. Explainability: автоматическая миграция, derived status или блокировка имеет
   видимую причину.
4. Reversibility: до Publish любое действие обратимо; после Publish destructive
   action показывает attendee/refund impact preview.
5. One source of truth: цена, inventory, occurrence и access status не
   вычисляются независимо в нескольких UI.
6. Accessibility by construction: keyboard/screen-reader flow, alt text,
   contrast и понятные errors входят в Definition of Done.

## 1. Цель

Creator должен иметь возможность создать публичное событие, сохранить его как
локальный черновик, предварительно просмотреть и отправить на публикацию. Форма
должна покрывать:

- описание и медиа;
- одну основную механику `eventArchetype` и роль посетителя;
- категорию и категорийные критерии;
- физическую, онлайн- или гибридную локацию;
- одноразовое или повторяющееся расписание;
- возможности площадки и требования к участникам;
- стоимость, вместимость, регистрацию и внешнее бронирование;
- независимые admission, confirmation, eligibility и inventory настройки;
- публикацию от имени пользователя или ManagedPage;
- восстановление после закрытия приложения, offline-режим и понятные ошибки.

Event остаётся одним из декларативных типов общего form engine. Для него нельзя
создавать отдельный независимый create flow, отдельное хранилище черновиков или
копии общих секций.

Общий form engine и reusable sections проектируются как production-capable, без
MVP-only API. Этот документ полностью задаёт Event block; остальные девять
Create blocks получают собственные production configs/specs и не обязаны
наследовать Event-only booking, schedule или ticketing поля.

## 2. Scope полноценного продукта

### Входит в production Event Create

- создание и редактирование Event draft;
- одноразовое событие;
- one-time, all-day, multi-day, multi-date и recurring series;
- daily/weekly/monthly/yearly recurrence, custom intervals и exceptions;
- occurrence-specific overrides времени, локации, capacity и ticket inventory;
- один обязательный archetype и primary/secondary participation modes;
- независимые admission, registration, confirmation, eligibility, guest,
  interest, waitlist и attendance policies;
- offline/local draft, multi-device sync, version conflict recovery;
- production media pipeline для cover, gallery, video и accessibility metadata;
- бесплатные события, платные билеты, donation/pay-what-you-want и price tiers;
- отсутствие регистрации, external booking и internal Recharge booking;
- approval, waitlist, booking windows, ticket inventory, promo/access codes;
- PSP payment, payout readiness, fees/taxes disclosure, cancellation/refund policy;
- public, unlisted и private access policies;
- capacity, attendee requirements, QR/check-in configuration;
- честную availability projection с `unknown/stale`, channel-bound hybrid
  inventory и provider source/freshness disclosure;
- preview;
- moderation, publish, revisions и resubmission;
- архивирование, cancellation occurrence/series и attendee notifications.

### Не входит именно в Event Create

- реализация PSP, KYC/KYB и payout ledger — отдельный Payments domain;
- операторский интерфейс moderation — отдельный Admin domain;
- attendee chat/community — отдельный Communications domain;
- собственный video-streaming transport; Event хранит только integration/access;
- seating-chart editor уровня билетного оператора; Event поддерживает ticket
  types/zones, а сложную рассадку делегирует ticketing provider;
- bulk/import UI; импорт использует тот же Event validation contract через
  отдельный integration flow.

### 2.1 Capability levels и infrastructure readiness

Полный semantic contract, form engine и модель §23 проектируются сразу под
полноценный продукт. Уровни ниже — rollout packages, а не урезанные версии
контракта и не отдельные роли. Они кумулятивны по умолчанию, но каждая рискованная
возможность дополнительно управляется собственной capability и feature flag.

| Level | Название | Включаемый продуктовый scope |
|---|---|---|
| **C0** | Core Event Create | Пять шагов; личный Publisher; one-time, all-day и multi-day; offline/online/hybrid; public online link; `free`/`fixed`; registration `none`/`external`; `public`; cover/alt text; autosave/restore/duplicate; Publish → `pending_review`. |
| **C1** | Advanced Schedule & Access | Multi-date, recurrence, occurrence overrides, DST policy, rolling projection, conflict UX, `unlisted`, typed deadlines и production media pipeline. |
| **C2** | Internal Booking | Бесплатный internal Booking, inventory, approval, waitlist, ticket delivery, QR/check-in. |
| **C3** | Payments & Protected Access | PSP payments, paid ticket types, online donations, refunds, KYC/payout readiness, `private` и protected access secrets. |

Capability level не определяет backend автоматически. Infrastructure readiness
отслеживается независимо:

| Readiness | Значение |
|---|---|
| **R0 — mock/local** | Локальный runtime и mock datasources; не production backend. |
| **R1 — contract-ready** | Domain/repository/API contracts и failure semantics готовы, provider ещё не подключён. |
| **R2 — Firebase-ready** | Firebase integration реализована отдельным post-stabilization slice и прошла security/migration gates. |
| **R3 — provider-ready** | Booking/PSP/media providers подключены, webhooks/reconciliation/legal gates закрыты. |

Например, recurrence может быть реализована и протестирована на R0/R1 без
Firebase. C2/C3 нельзя включить в production только потому, что form fields уже
существуют: требуется соответствующая backend readiness и gates §27.

Маппинг acceptance criteria §25:

| Level | Acceptance criteria |
|---|---|
| C0 | AC-01…06, 08…15, 17…20, 34 |
| C1 | AC-07, 21…23, 33, 35, 36 |
| C2 | AC-24, 27, 31, 38 |
| C3 | AC-25, 26, 28…30, 39 |
| Cross-level, для включённого scope | AC-16, 32, 37, 40…44 |

Этот mapping задаёт минимальный набор доказательств, но не отменяет общие
quality gates. Локализация en/ru/lv и Firebase остаются отдельными repository
slices: Event slice не должен незаметно поглощать их реализацию.

## 3. Термины

| Термин | Значение |
|---|---|
| Event | Публикуемая сущность события. |
| Draft | Изменяемый локальный или синхронизированный черновик Event. |
| Publisher | Субъект, от имени которого публикуется Event: `user` или `page`. |
| Event archetype | Ровно одна основная механика из 34 значений канонического реестра; не тема и не Create-тип. |
| Participation mode | Что делает посетитель; один primary и до трёх дополнительных режимов. |
| Series | Повторяющееся событие с одним правилом recurrence. |
| Occurrence | Конкретное проведение Event с собственными start/end в UTC. |
| Event slot | Интервал одной occurrence, используемый availability и time-fit. |
| Occurrence override | Изменение конкретной occurrence без разрушения series rule. |
| Capability | Явное разрешение на действие, например `create.event` или `publish.event`. |
| Booking | Резервирование участия/билета на конкретную occurrence или Event. |
| Admission mode | Основная механика входа: open entry, RSVP, booking, application, ticket или team registration. |
| Inventory authority | Единственный источник истины inventory: none, Recharge или external provider. |
| Availability projection | Производное состояние occurrence/inventory/windows/freshness; не lifecycle Event. |
| Ticket type | Тариф/квота с ценой, inventory, sales window и правилами возврата. |
| Payment | Финансовая операция PSP, связанная с Booking, но не хранящая card data в Recharge. |
| Access policy | Правило видимости и входа: public, unlisted или private. |
| Существенное изменение (`material edit`) | Изменение уже опубликованного Event, влияющее на решение посетителя: время, локация, цена, содержание, Publisher или правила участия. |

## 4. Основные инварианты

1. UI не принимает бизнес-решения. Переходы, нормализация, валидация,
   сохранение и публикация оркестрируются application-контроллером и usecases.
2. Event собирается form engine из декларативного `CreateTypeConfig` и общих
   секций. Event-specific логика допускается только в специализированных
   секциях, например `RecurrenceScheduleSection`.
3. Все связи хранятся по immutable id, не по имени.
4. Несохранённый локальный draft использует `loc_*`. Перед первой отправкой на
   backend клиент создаёт постоянный ULID и заменяет временный id атомарно.
5. Время хранится в UTC, а выбранная IANA timezone хранится отдельно.
6. Категории и системные теги выбираются только из Category System. Произвольный
   текст не создаёт новую категорию.
7. Публикация разрешена capability-проверкой, а не только названием роли.
8. Publish не означает немедленное появление в выдаче: успешная отправка
   переводит Event в `pending_review`.
9. Платный Event использует external checkout либо internal Booking/Payments
   integration через PSP; UI всегда показывает получателя, итоговую цену,
   комиссии, валюту и refund policy до подтверждения.
10. Черновик никогда не теряется из-за ошибки сети, загрузки медиа или
    серверной валидации.
11. Event Publish, recurrence, internal Booking и Payments имеют независимые
    remote-config kill switches. Отключение блокирует новые рискованные
    операции, но сохраняет draft и управление существующими обязательствами;
    payment kill switch не блокирует refunds.
12. Booking inventory изменяется только транзакционно/idempotently; UI никогда
    не вычисляет остаток мест локально как источник истины.
13. Raw payment credentials не проходят через Event domain, logs или analytics.
14. Каждый новый публикуемый Event имеет ровно один `eventArchetype`, один
    `PublisherRef` и хотя бы одну определённую будущую occurrence.
15. Archetype, Category System, participation, format, admission, pricing,
    payment и inventory являются независимыми осями. UI preset может заполнить
    несколько осей, но сохраняет их раздельно.
16. `unknown` и `stale` никогда не отображаются как `free`, `0` или
    `available`; `soldOut` и `discoverEligible` являются projections, а не
    Event lifecycle states.
17. `currentParticipants` не вводится Creator и выводится только из
    подтверждённых Booking либо verified provider sync.
18. Event не поглощает Place, Route, Scenario, Quick Plan, Bookable Session или
    Find People. Пограничные случаи разрешаются нормативной таблицей §1.2
    Event Classification; связи — только по stable ID.
19. `EventCreateBlock` только отображает typed view state и вызывает controller
    commands. Validation, inventory calculations, Booking lifecycle, provider
    sync, migration и persistence находятся вне presentation.
20. Новое поле в enum/schema не включает capability: unsupported combinations
    остаются fail closed до собственного Approved ECL slice и kill switch.

## 5. Доступ и Publisher

### 5.1 Вход в flow

Event creation открывается из:

- Create Hub → `Event`;
- Profile → Created → `Create event`;
- Details → `Create similar`;
- Search, Home или Map → создание из текущего контекста;
- списка черновиков → продолжение существующего draft;
- отклонённого Event → исправление и повторная отправка.

### 5.2 Проверка доступа

При открытии система выполняет проверки в следующем порядке:

1. Сессия восстановлена.
2. Пользователь авторизован.
3. У пользователя есть `create.event`.
4. Для выбранного Publisher есть право создавать контент от его имени.
5. Для Publish отдельно проверяется `publish.event`; доступ к форме сам по себе
   не даёт право на публикацию.

Для личного Publisher capability проверяется на аккаунте. Для Publisher типа
`page` одновременно нужны доступ к конкретной ManagedPage (`manage_page` или
более узкая эквивалентная capability) и разрешение создать/опубликовать Event от
её имени. Глобальная роль Creator не даёт доступ ко всем Page.

Internal booking требует `manage_bookings` для Publisher, а изменение payout/
financial configuration — отдельной finance capability. Право Publish Event не
даёт автоматически доступ к payout settings или attendee personal data.

Если пользователь не авторизован, сохраняется intended route и открывается
Auth. После успешного входа пользователь возвращается в Event flow.

Если авторизованный User не имеет `create.event`, показывается экран Upgrade с
объяснением, без создания пустого draft.

### 5.3 Выбор Publisher

- Если доступен только личный Publisher, он выбирается автоматически.
- Если доступны личный профиль и одна или несколько ManagedPage, на первом шаге
  обязательно показывается `Publish as`.
- Выбранное значение сохраняется как `{type: user | page, id}`.
- Имя, аватар и verified-status Publisher — отображаемый snapshot, но права
  всегда проверяются по id.
- При отзыве права управления Page draft остаётся доступен владельцу draft, но
  Publish блокируется до выбора разрешённого Publisher.

## 6. Общий сценарий

```text
Entry
  → auth/capability check
  → load existing draft OR create loc_* draft
  → apply seed if safe
  → Step 1: Basics & Media
  → Step 2: Location & Schedule
  → Step 3: Amenities & Requirements
  → Step 4: Price & Participants
  → Step 5: Preview & Publish
  → full validation
  → media readiness
  → generate permanent ULID if needed
  → idempotent publish request
  → pending_review
  → moderation outcome: published OR rejected
```

Пользователь может свободно возвращаться на уже открытые шаги. Переход вперёд
проверяет текущий шаг, но полная publish-валидация запускается только на шаге 5.

### 6.1 Карта пяти шагов

| Шаг | Пользователь решает | Основные секции | Условие перехода вперёд |
|---|---|---|---|
| 1. Основное и медиа | Кто публикует, что происходит и что делает посетитель | Publisher, Archetype, Participation, Name/Description, Category, Criteria, Media | Publisher, archetype, participation, taxonomy path и обязательные criteria валидны |
| 2. Локация и расписание | Где и когда проходит | Format, Location, Schedule/Recurrence | Есть валидная условная локация и минимум одна будущая occurrence |
| 3. Возможности | Что доступно и кому подходит | Amenities, Accessibility, Audience, Requirements | Заполнены обязательные category-dependent требования |
| 4. Цена и участники | Как попасть, сколько стоит и кто контролирует места | Admission preset/axes, Pricing, Capacity, Inventory, Booking/Provider, Access | Admission, price/payment, authority/pools, availability и access policy согласованы |
| 5. Preview и Publish | Как Event увидит посетитель | Readiness, Details preview, Legal confirmations | Полная проверка не содержит blocking errors |

### 6.2 Назад, закрыть и продолжить позже

- Переход назад никогда не блокируется validation errors.
- Закрытие flow сначала запускает local save.
- Если local save успешен, flow закрывается без дополнительного диалога.
- Если local save неуспешен и есть dirty changes, пользователь явно выбирает
  `Retry save`, `Stay` или `Discard unsaved changes`.
- `Continue later` сохраняет текущий step id и возвращает в Create Hub.
- Нажатие системной кнопки Back следует тем же правилам, что явное закрытие.

## 7. Состояния

### 7.1 Состояния UI/application

| Состояние | Поведение |
|---|---|
| `initial` | Контроллер ещё не загружал draft. |
| `loading` | Читается локальный draft и восстанавливается сессия. |
| `ready` | Форма доступна для редактирования. |
| `dirty` | Есть локальные изменения, ещё не зафиксированные autosave. |
| `autosaving` | Идёт фоновое сохранение; навигация по форме не блокируется. |
| `saved` | Последняя версия безопасно сохранена. |
| `offline` | Локальное редактирование доступно, синхронизация отложена. |
| `uploadingMedia` | Медиа обрабатывается/загружается; редактирование доступно. |
| `publishing` | Publish заблокирован от повторного нажатия. |
| `publishSuccess` | Сервер/репозиторий принял Event в `pending_review`. |
| `conflict` | Обнаружена более новая версия; требуется предупреждение и выбор. |
| `error` | Операция не завершилась; draft остаётся сохранённым. |

`dirty`, `autosaving`, `saved`, `offline` и `uploadingMedia` могут быть
представлены составным состоянием, а не одним enum, если это требуется модели.

### 7.2 Три независимые оси persisted state

Lifecycle, moderation и visibility нельзя смешивать в один enum или показывать
как один статус.

| Ось | Значения production | Кто изменяет |
|---|---|---|
| Lifecycle | `draft`, `pending_review`, `published`, `archived`, `hidden`, `deleted` | Application usecases; `hidden` — только система/модерация |
| Moderation | `none`, `pending`, `approved`, `rejected` | Moderation pipeline |
| Visibility | `public`, `unlisted`, `private` | Creator в пределах capability и access policy |

Основные переходы:

```text
draft / none
  → pending_review / pending
      → published / approved
      → draft / rejected

published / approved
  → archived / approved          // действие Creator
  → hidden / pending|approved    // действие системы/модерации
  → deleted / approved           // soft delete policy
```

`rejected` — результат модерации, а не lifecycle. Отклонённый Event возвращается
в редактируемый `draft`, сохраняя moderation reason и историю попытки.

### 7.3 Связанные, но независимые state machines

Event lifecycle не поглощает состояния дочерних процессов:

- occurrence: `scheduled`, `cancelled`, а `sold_out` вычисляется projection;
- Booking: `pending`, `confirmed`, `cancelled`, `expired`, `waitlisted`;
- Attendance: `not_checked_in`, `checked_in`, `no_show`;
- Payment: состояния §13.3.1;
- Media: `local`, `processing`, `ready`, `failed`, `removed`;
- PublishAttempt: `prepared`, `sent`, `accepted`, `failed`.

Изменение одной оси запускает явные usecases и projections, но не переписывает
другие enum «для удобства».

## 8. Создание и восстановление draft

### 8.1 Новый draft

После успешной capability-проверки создаётся draft со значениями:

- `id = loc_<ULID>`;
- `objectType = event`;
- Publisher из доступного контекста;
- market = Riga / Latvia из market config, а не из UI-хардкода;
- currency = EUR из market config;
- timezone = IANA timezone из market config (`Europe/Riga` для запуска), с
  возможностью явно изменить её;
- availability = `eventSlots`;
- lifecycle = `draft`;
- пустые пользовательские поля.

### 8.2 Autosave

Autosave запускается:

- после configurable debounce (default 800 мс) с момента последнего изменения;
- при переходе на другой шаг;
- при уходе приложения в background;
- перед открытием preview;
- перед выходом назад из flow.

Autosave сохраняет draft локально даже при невалидных полях. Ошибка валидации
никогда не мешает сохранить незавершённую работу.

Protected join/access secrets сохраняются через encrypted secure storage или
server-side secret reference. Raw payment credentials и attendee data не
являются частью Event draft autosave.

### 8.3 Возврат в flow

При наличии незавершённого Event draft пользователь видит:

- название или `Untitled event`;
- последний изменённый шаг;
- дату последнего сохранения;
- readiness в процентах/по обязательным секциям;
- действия `Continue`, `Duplicate`, `Archive draft`.

Duplicate создаёт новый `loc_*` draft и новые `loc_*` occurrence ids, сбрасывает
lifecycle/moderation/publish attempt и published timestamps. Контент копируется
только при сохранённом праве на исходного Publisher; taxonomy, время, ссылки и
медиа повторно проходят актуальную валидацию.

Booking/Payment/Attendance records, sold counts, access secrets и promo codes не
копируются. Ticket definitions можно скопировать только с новыми ids и пустым
inventory usage; payout readiness проверяется заново.

### 8.4 Конфликт версий

Baseline — last-write-wins с предупреждением. До перезаписи система показывает:

- время локальной и удалённой версии;
- устройство/сессию, если информация доступна;
- `Use this version`;
- `Use newer version`;
- `Duplicate both` для сохранения обеих версий.

Молчаливое уничтожение локальных изменений запрещено.

### 8.5 Draft quota и защита от abuse

Значение из config `draftSoftWarningThreshold` (baseline 20 на Publisher) —
только порог предупреждения, а не безусловный продуктовый лимит. После него UI
предлагает продолжить, архивировать или удалить ненужные drafts, но не теряет
работу и не блокирует профессионального Creator молча.

Отдельная server-side hard quota может зависеть от risk policy, capability и
storage limits. Она возвращает структурированную ошибку с recovery action,
никогда не удаляет существующие drafts автоматически и не маскируется под
validation error формы. Creator publish velocity limit из ADR применяется
независимо от draft quota.

## 9. Seed/prefill

Seed использует source-aware allowlist. Search/Home/Map могут передать
необязательную archetype suggestion с reason, category/subcategory,
город/координаты, price knowledge и стартовое время.
Details другого Publisher может передать taxonomy/format/location context, но
не копирует дословно title, descriptions, media или booking URL. Полное
копирование собственного Event выполняется через Duplicate, а не через seed.

Правила применения:

1. Seed применяется один раз к новому пустому draft.
2. Seed не перезаписывает непустой восстановленный draft без подтверждения.
3. Значения category/subcategory нормализуются через Category System.
4. Неизвестная или запрещённая подкатегория отбрасывается, а не создаётся.
5. Время seed интерпретируется с явно переданной timezone; без timezone
   показывается подтверждение локального времени.
6. Источник seed сохраняется только как технический context/analytics и не
   влияет на ownership.
7. Пользователь видит `Seeded from Search / Map / Details` и может очистить
   подставленные значения.
8. Seed никогда не задаёт Publisher, entity/occurrence ids, moderation/lifecycle,
   participant counts, ticket inventory, Booking/Payment, booking URL или
   private access data.
9. Cover/media можно перенести только из собственного draft/Event при
   подтверждённом праве повторного использования asset.
10. Archetype suggestion не записывается как подтверждённый archetype до
    явного выбора Creator и не меняет category/admission/pricing.

## 10. Шаг 1 — Основное и медиа

### 10.1 Порядок секций

1. `Publish as` — если Publisher больше одного.
2. `EventClassificationSection` — archetype и participation.
3. `NameDescriptionSection`.
4. `CategorySection`.
5. `DynamicCriteriaSection`.
6. `MediaSection`.

### 10.2 Поля

| Поле | Обязательность | Правило |
|---|---:|---|
| Publisher | Да | Существующий `user/page` id с правом создания; право Publish повторно проверяется на шаге 5. |
| Event archetype | Да для новой publication/material revision | Ровно одно из 34 канонических значений; `other` требует reason и moderation. |
| Primary participation | Да | Одно значение из канонического participation dictionary. |
| Additional participation | Нет | До трёх уникальных значений, отличных от primary. |
| Title | Да | После trim 3–100 символов. |
| Main category | Да | Только id из актуального реестра. |
| Subcategory | Да | Канонический id, принадлежащий main category; тема сама не выбирает aggregate/Create type. |
| Short description | Да | 20–240 символов; используется в карточках. |
| Full description | Да | 50–20 000 символов; structured rich text из allowlist-блоков, без произвольного HTML. |
| Criteria | Условно | Required-поля профиля выбранной subcategory обязательны. |
| Tags | Нет | До 10 платформенных/разрешённых тегов. |
| Cover | Да для Publish | Одно изображение, прошедшее обработку. |
| Gallery | Нет | Лимит и форматы приходят из media config. |
| Video/trailer | Нет | Upload либо безопасная provider integration. |

### 10.3 Категория и dynamic criteria

1. Пользователь выбирает main category.
2. UI использует канонический реестр Category System. Все 27 предметных групп
   и service `other` доступны при occurrence-инварианте; theme-only фильтр не
   может молча перенести объект в другой aggregate.
3. Выбранная subcategory определяет `profileId`.
4. `GetCategoryCriteriaUseCase` возвращает поля профиля.
5. Значения записываются в `sectionData['criteria']` по стабильным field id.
6. При смене subcategory:
   - совместимые значения сохраняются;
   - несовместимые значения не удаляются немедленно, а помечаются как
     неактивные до сохранения;
   - пользователь получает предупреждение перед окончательным удалением;
   - новые обязательные критерии подсвечиваются.
7. Fallback `open_event` не добавляет динамических полей.
8. Category не выбирает archetype, admission, pricing или aggregate.
9. Все 27 предметных групп и сервисная `other` применимы к Event только при
   выполнении occurrence-инварианта; доступность конкретной подкатегории
   проверяется по каноническому реестру и его compatibility aliases.

### 10.3a Archetype и participation

- Creator сначала выбирает понятную механику происходящего; UI может
  предлагать archetype по legacy subcategory, но показывает suggestion как
  неподтверждённую.
- Archetype selector строится из versioned domain catalog, а не из 34
  `if/switch` веток в `EventCreateBlock`.
- Выбор archetype активирует только declarative section visibility/default
  suggestions. Requiredness и cross-validation возвращают domain/application
  rules.
- Participation влияет на copy/filter/ranking metadata, но не выдаёт
  capability и не меняет access policy.
- Смена archetype сохраняет независимые поля и показывает impact preview для
  полей, которые становятся нерелевантными; silent deletion запрещён.

### 10.4 Медиа

- Cover обязателен только для Publish, но не для сохранения draft.
- Поддерживаемые форматы и точные лимиты должны приходить из media config.
- Клиент выполняет preview, compression и проверку типа/размера.
- Backend выполняет MIME/signature validation, malware scan и moderation.
- Оригинал и обработанный asset имеют независимый upload status.
- Удаление медиа из draft удаляет ссылку сразу, а физический orphan очищается
  отложенным процессом.
- Ошибка одного gallery item не блокирует сохранение остальных полей.
- Publish блокируется, пока обязательный cover находится в `processing`,
  `failed` или не имеет готовой постоянной ссылки.
- Для cover и каждого информативного media asset alt text обязателен. Система
  может предложить черновик описания, но Publisher подтверждает/редактирует его.
- Asset хранит copyright/source/license metadata; Publish блокируется при
  отсутствии подтверждения прав на используемый контент.

### 10.5 Переход к шагу 2

Для перехода нужны Publisher, title, category, subcategory, short description
и заполненные required criteria. Full description и cover можно завершить до
Publish, чтобы пользователь не блокировался слишком рано.

## 11. Шаг 2 — Локация и расписание

### 11.1 Формат проведения

`format` принимает одно из значений:

- `offline`;
- `online`;
- `hybrid`.

Условные требования:

| Format | Физическая локация | Online access |
|---|---|---|
| `offline` | Обязательна | Не показывается |
| `online` | Не требуется | Public link, internal booking access или external provider |
| `hybrid` | Обязательна | Public link, internal booking access или external provider |

Для online/hybrid пользователь выбирает access mode:

- `Public online link` — `publicOnlineUrl` сохраняется в Event и виден всем;
- `Access after internal booking` — secret join data шифруется и выдаётся только
  подтверждённому Booking в разрешённый момент;
- `Access via external registration` — в Recharge хранится только
  `externalBookingUrl`, а закрытую ссылку участнику выдаёт внешний организатор.

`Access via external registration` принудительно устанавливает registration
mode `external`; internal access — `internal`. При `Public online link`
регистрация может быть `none`, `external` или `internal`, но сама ссылка не
считается закрытой.

Secret join data никогда не попадает в public Event projection, analytics,
notifications preview или logs. Доступ отзывается при cancellation/refund в
соответствии с access policy.

`publicOnlineUrl` проходит ту же HTTPS/scheme-проверку и открывается тем же safe
external-link handler, что `externalBookingUrl`.

### 11.2 Физическая локация

Поля:

- country;
- city/marketCityId;
- venueName;
- address components;
- latitude/longitude;
- meetingPoint;
- location accuracy/source.

Правила:

- Location выбирается через общий location component, а не только текстом.
- Для offline/hybrid обязательны city, подтверждённая точка и отображаемый адрес
  либо meetingPoint с координатами.
- Online Event всё равно получает `marketCityId` как рынок публикации, но не
  получает фиктивные latitude/longitude и не рисуется как физический marker на
  карте.
- Геокодирование не изменяет вручную подтверждённую точку молча.
- Если pin и адрес расходятся существенно, пользователь выбирает источник истины.
- Контент остаётся привязан к market id, а не к строке `Riga`.
- Для физической точки система может предложить timezone по координатам, но
  смена уже заполненного расписания всегда требует подтверждения по правилам
  раздела 11.7.

### 11.3 Режим расписания

Пользователь выбирает:

- `One-time event`;
- `Multi-date event`;
- `Recurring event`.

Общие поля:

- IANA timezone;
- all-day flag;
- local start date/time;
- local end date/time или duration;
- `allowsPartialAttendance` и `minimumVisitDurationMinutes`;
- onsite buffer before/after в минутах, default `0`.

Для Event `availabilityKind` всегда равен `eventSlots`: список slots обязан быть
непустым, `openingHours` — пустым, onsite buffers — неотрицательными. Эти
инварианты проверяет общий `ValidateCreateAvailabilityUseCase`.

При `allowsPartialAttendance = true` minimum visit duration обязательна,
положительна и не превышает duration occurrence; при `false` она очищается.

### 11.4 Одноразовое и multi-day событие

1. Пользователь вводит локальные start и end.
2. UI показывает выбранную timezone рядом со временем.
3. Application слой конвертирует значения в UTC.
4. Создаётся один event slot: `[startAtUtc, endAtUtc]`.
5. `durationMinutes = end - start`.

Валидация:

- start находится в будущем на момент Publish;
- end строго позже start;
- duration положительна; UI использует 1–8 часов как рекомендованный быстрый
  диапазон, но domain поддерживает короткие, all-day и multi-day Events;
- чрезмерная длительность вызывает policy warning/review, а не скрытый hardcode;
- all-day хранит local dates и timezone, а UTC boundaries вычисляются usecase;
- buffer before/after неотрицательны.

### 11.5 Multi-date событие

Multi-date используется, когда occurrences не образуют одно recurrence rule:

- Creator добавляет произвольные local date/time intervals;
- интервалы нормализуются в timezone Event и сортируются;
- дубликаты и пересечения показываются до сохранения;
- каждая occurrence получает стабильный id и может иметь override;
- общие Event-поля наследуются всеми occurrences;
- Publish требует минимум одну будущую occurrence.

### 11.6 Повторяющееся событие

Production recurrence поддерживает:

- `daily`: каждый N-й день;
- `weekly`: выбранные дни недели, одинаковые local start и duration;
- `monthly`: day-of-month, last day, weekday + ordinal/last weekday;
- `yearly`: month/day либо ordinal weekday конкретного месяца;
- custom interval `N` для каждой frequency;
- завершение `never`, inclusive `untilDate` или `occurrenceCount`;
- exception dates и occurrence overrides.

Series rule хранится без искусственного ограничения по сроку. Search/Feed не
материализуют бесконечность: background job поддерживает rolling projection
horizon из server config, а при приближении границы достраивает следующие slots.
Лимит occurrences на одну command/query защищает инфраструктуру, но не обрезает
само пользовательское recurrence rule.

Семантическая модель:

```text
EventRecurrenceDraft
  frequency: daily | weekly | monthly | yearly
  interval: int                 // default = 1
  byWeekdays: Set<int>          // ISO 1..7
  byMonthDays: Set<MonthDaySelector> // day(1..31) | lastDay
  bySetPositions: Set<int>      // напр. 1, 2, -1
  byMonths: Set<int>            // 1..12
  localStartTime: HH:mm
  allDay: bool
  durationMinutes: int
  timezone: IANA string
  startsOn: local date
  endMode: never | untilDate | occurrenceCount
  endsOn: local date?           // inclusive
  occurrenceCount: int?
  exceptionLocalDates: Set<LocalDate>
  exceptionOccurrenceIds: Set<id>    // уже materialized occurrences
  dstGapPolicy: shiftForward | reject
  dstOverlapPolicy: earlierOffset | laterOffset
```

Правила recurrence:

- `interval >= 1`;
- frequency-specific BY-поля не противоречат друг другу;
- для weekly `byWeekdays` непустой;
- для monthly/yearly выбрана валидная комбинация month/day/weekday/position;
- end fields соответствуют `endMode`; при `never` оба пусты;
- если выбранного дня/ordinal weekday в месяце нет, этот месяц пропускается; при
  `occurrenceCount` генерация продолжается до набора указанного количества;
- после exceptions остаётся минимум одна будущая occurrence;
- сгенерированные slots уникальны и отсортированы по `startAtUtc`;
- политика разрешения DST gap/overlap сохраняется в recurrence rule, чтобы
  повторная генерация была детерминированной.

Генерация slots выполняется usecase, а не UI:

1. Проверить recurrence rule.
2. Сгенерировать local occurrences.
3. Для каждой occurrence применить IANA timezone и DST rules.
4. Сохранить start/end в UTC и исходную timezone.
5. Стабильно идентифицировать occurrence через ULID/id, не через дату.
6. Исключённые даты хранить как exceptions, не удаляя series.

Recurrence rule — источник истины для series, а materialized `eventSlots` —
источник истины для availability/time-fit внутри rolling horizon. Для совместимости
top-level `startDateTimeUtc/endDateTimeUtc` у one-time Event совпадают с
единственным slot, а у multi-date/recurring draft — с первой occurrence. Публичный read
model вычисляет `nextOccurrenceAtUtc` из будущих slots и не перезаписывает
историю series при каждом наступившем событии.

Published Event без будущих non-cancelled occurrences получает
`discoverEligible=false` и исключается из Search/Map/Feed, но его lifecycle не
меняется. Прямая ссылка продолжает показывать completed/cancelled state.
Добавление, перенос или замена occurrence является material revision; возврат
в Discover возможен только после применимой revision/moderation policy.

До публикации occurrence использует локальный `loc_*` id. Во время Publish все
materialized occurrences получают постоянные ULID вместе с Event. Rule-level
исключения используют `LocalDate` в timezone series; overrides, Booking и
остальные entity-связи используют occurrence id.

При DST-сдвиге сохраняется выбранное локальное время события. Если локальное
время не существует или двусмысленно, пользователь должен подтвердить
предложенный вариант до Publish.

### 11.7 Изменение timezone

При смене timezone после ввода расписания UI спрашивает:

- `Keep local time` — например, 19:00 остаётся 19:00, UTC меняется;
- `Keep exact moment` — UTC остаётся прежним, локальное отображение меняется.

Без подтверждения массовая перестройка slots запрещена.

### 11.8 Occurrence overrides

По умолчанию occurrence наследует series-level значения. Для конкретной
occurrence Creator может переопределить:

- start/end;
- location/online access;
- capacity и ticket inventory;
- price/ticket availability;
- registration deadline;
- status (`scheduled`, `cancelled`).

Override хранит только изменённые поля и ссылку на occurrence id. Удаление
override возвращает наследование; оно не меняет recurrence rule.
`sold_out` вычисляется Booking/inventory projection и не редактируется Creator.
Capacity/inventory нельзя снизить ниже confirmed bookings + active holds без
явного cancellation/reallocation flow и attendee impact preview.

### 11.9 Переход к шагу 3

Нужны валидные format, условная location, timezone и минимум один валидный
event slot. Для recurring также требуется валидное правило завершения series.

## 12. Шаг 3 — Возможности и требования

### 12.1 Amenities

`AmenitiesSection` читает выбранные category/subcategory/format и получает
доступные amenity groups из `AmenityTaxonomy`. Список нельзя хардкодить внутри
Event page.

Примеры групп:

- accessibility: wheelchair access, accessible WC, lift;
- facilities: WC, shower, changing room, parking;
- food & drink: water, cafe/bar, food available;
- equipment: equipment provided, rental available;
- comfort/safety: indoor shelter, lockers, first aid;
- connectivity: Wi-Fi, charging;
- family/pets: kids area, stroller access, pets allowed.

Выбранные значения сохраняются по стабильным amenity id. Недоступные для новой
категории значения после её смены проходят тот же review, что dynamic criteria.

### 12.2 Audience и требования

Поля:

- ageMin/ageMax;
- familyFriendly;
- kidsAllowed;
- petFriendly;
- wheelchairAccessible;
- language — если требует criteria profile;
- что взять с собой;
- dress code/skill/equipment — через dynamic criteria, без дублирования;
- правила безопасности и противопоказания — если применимо.

Cross-field правила:

- `ageMin <= ageMax`;
- kidsAllowed согласуется с age range;
- required criteria не дублируются отдельными Event-полями;
- wheelchairAccessible отражает агрегированный статус amenities, но не заменяет
  точные accessibility amenities;
- потенциально опасная активность требует safety information, если её
  category profile помечен соответствующим флагом.

### 12.3 Переход к шагу 4

Обязательны все category-dependent requirements. Amenities по умолчанию
необязательны, кроме полей, которые конкретный профиль помечает required.

## 13. Шаг 4 — Цена и участники

### 13.1 Цена

Pricing mode:

- `free` — цена отсутствует;
- `fixed` — одна цена `per_person` или `fixed_group`;
- `ticketTypes` — несколько тарифов/квот;
- `donation` — optional suggested/minimum amount.

Pricing shape не определяет, где принимается оплата. Это отдельная ось:

- `none` — денежного расчёта нет; обязательно для `free`;
- `onsite` — расчёт происходит на месте, Recharge не подтверждает факт оплаты;
- `external` — checkout контролирует внешний provider;
- `internal` — Recharge оркестрирует PSP payment через Payments domain.

Для external checkout Event хранит `externalPaymentUrl` либо provider reference,
а также `externalPricePolicy: informational | providerSynced`. При
`informational` UI явно предупреждает, что итоговая цена подтверждается на
сайте provider; при `providerSynced` цена обновляется только проверенным
connector и provider остаётся source of truth. Регистрационная ссылка и ссылка
оплаты могут совпадать физически, но имеют разные семантические назначения и не
должны неявно перезаписывать друг друга.

Для manual/internal Event Creator выбирает pricing mode явно. Для external
provider record цена моделируется независимо:

```text
priceKnowledge: known | unknown
priceDisplay: exact | from | range | providerConfirmedAtCheckout
externalPricePolicy: informational | providerSynced
```

`priceKnowledge=unknown` не создаёт `pricingMode=free`, нулевую Money или
обещание цены. Provider-owned price доступна Creator только для чтения вместе
с source/freshness disclosure.

Для `free`: `isFree = true`, canonical `price = null` и
`pricingModel = null`; legacy `basePrice <= 0` нормализуется в `null`.

`isFree` выводится из обязательства attendee, а не только из названия режима:
для `fixed`/`ticketTypes` он равен `false`; для `donation` равен `true`, если
minimum отсутствует или равен нулю, и `false`, если задан обязательный
положительный minimum. Fixed/ticket amounts положительны, donation amounts
неотрицательны, currency приходит из market/event config. Все внутренние ticket
types одного Event используют одну settlement currency; конвертация для
отображения не меняет сумму charge.

Для `donation` optional suggested/minimum amount хранится как `Money`. Online
donation через `external` или `internal` проходит соответствующие payment/
provider readiness checks. Взнос на месте использует `onsite`; UI не обещает
online payment и не считает такой Event бесплатным, если взнос обязателен.

Ticket type содержит:

- ULID (`loc_*` в draft), name/description;
- price `Money`, fee/tax display policy;
- inventory pool id и scope: Event, каждая occurrence или конкретные occurrences;
- min/max quantity per booking;
- sales start/end;
- eligibility/access code/membership rule;
- refund policy id;
- display order и active/hidden/sold-out state.

Сумма заказа рассчитывается Booking/Pricing usecase из неизменяемого price
snapshot. UI не передаёт итог как доверенное значение.

Цена не должна храниться форматированной строкой или floating-point числом как
каноническим значением. Целевой domain value object —
`Money(amountMinor: int, currency: CurrencyCode)`; presentation отвечает за
ввод десятичного значения и locale-форматирование. Текущий `double basePrice`
потребует совместимой миграции отдельным slice.

### 13.2 Участники

Поля:

- minParticipants — необязательный operational минимум;
- capacity mode: `known`, `unknown`, `unlimited`;
- maxParticipants/capacity — положительный лимит для `known`;
- inventory pools — общие/раздельные квоты, на которые ссылаются ticket types;
- currentParticipants — server-derived агрегат подтверждённых Booking.

Правила:

- `known` требует положительную capacity, в том числе больше 500;
- `unknown` хранит `capacity = null` и не обещает наличие мест;
- `unlimited` хранит отдельный explicit mode; его нельзя выводить только из
  `capacity = null`;
- `capacity <= 0` при чтении legacy data нормализуется в
  `{capacityMode: unknown, capacity: null}`;
- minParticipants положителен и не больше capacity, если оба значения заданы;
- `currentParticipants` не вводится Creator; его меняют только подтверждённые
  Booking lifecycle transitions (confirm/cancel/expire) или проверяемая
  provider sync; refund сам по себе attendance count не меняет;
- без Booking/provider source public projection передаёт
  `participantsCount = null`, а не выдуманный `0`;
- effective суммарная квота inventory pools не превышает occurrence capacity,
  если общий лимит задан; shared pool не суммируется повторно по ticket types;
- inventory hold имеет TTL; expired hold атомарно возвращает места;
- oversell запрещён транзакционной проверкой backend;
- у recurring Event capacity/inventory наследуются каждой occurrence и могут
  переопределяться occurrence override;
- `players_min/max` из профиля `game_session` не заменяет capacity: это состав
  игры, а capacity — лимит записи.

#### 13.2.1 Inventory authority, shapes и availability

Capacity не определяет, кто имеет право менять остаток. Creator настраивает
provider-neutral configuration, а authority выбирается явно:

```text
inventoryAuthority: none | recharge | externalProvider
inventoryShapes: generalCapacity | sharedTicketPool | separateTicketPools |
                 zones | assignedSeating | teamSlots | participantRoles |
                 roleBalancedSlots | tableInventory | timeSlotInventory
inventoryPools[]
  id
  shape
  channel: onsite | online | any
  capacityMode
  capacity?
```

- `externalProvider` — authority, а не shape; provider-owned pools, prices,
  holds и availability редактировать в Recharge нельзя.
- Hybrid Event с конечной физической capacity требует отдельный bounded
  `onsite` pool. `any`/shared entitlement не может быть единственным physical
  capacity guard; online и onsite availability проецируются раздельно.
- Assigned seating интерактивна только при authoritative hold API; иначе UI
  предлагает честный external handoff.
- Auxiliary press/volunteer/vendor pools находятся в том же атомарном ledger,
  если потребляют venue capacity, но не входят в основной admission UI или
  public participant count.
- Availability имеет значения `available`, `lowAvailability`, `soldOut`,
  `waitlistAvailable`, `registrationClosed`, `cancelled`, `unknown`, `stale`.
  Это projection, не Event lifecycle и не ручное поле формы.

### 13.3 Регистрация и booking

Creator сначала выбирает admission preset, который нормализуется в независимые
поля и остаётся редактируемым:

```text
admissionMode: openEntry | rsvp | booking | application | ticket |
               teamRegistration
registrationMode: none | external | internal
confirmationMode: none | instant | manualApproval | lottery |
                  providerManaged
eligibilityRules[]
guestPolicy?
waitlistPolicy?
onsiteAdmissionPolicy?
interestPolicy?
attendancePolicy?
```

`confirmationMode=none` допустим только для open entry. Lottery требует
application window и auditable result. Provider-managed confirmation нельзя
показывать без verified callback/lookup. Eligibility, visibility, pricing и
participation не заменяют друг друга.

При `openEntry` разрешён optional interest/reminder RSVP, но он имеет
`createsBooking=false`, `reservesInventory=false` и не попадает в My Bookings.
Если пользователю гарантируется конечное место, используется rsvp/booking с
inventory. Бесплатный internal finite-capacity Event может требовать
reconfirmation и атомарно release Booking при пропуске deadline; это не
создаёт reliability score и реализуется только ECL-03.

`registrationMode` содержит три режима:

1. `No registration` — attendance booking CTA отсутствует; остаются подходящие
   действия вроде Directions, Add to calendar или Public online link.
2. `External registration` — CTA ведёт на `externalBookingUrl`.
3. `Internal booking` — Recharge создаёт Booking, управляет inventory,
   approval/waitlist, ticket delivery и при необходимости PSP payment.

При `No registration`:

- `registrationRequired = false`;
- `externalBookingUrl` отсутствует;
- на Details нет CTA `Записаться`.

При `External registration`:

- `registrationRequired = true`;
- `externalBookingUrl` обязателен;
- CTA явно помечает переход на внешний сайт;
- без provider integration Recharge не обещает подтверждение места, не меняет
  inventory и не управляет cancellation/refund;
- при integration connector подписанные webhooks могут синхронизировать
  availability/status, но внешний provider остаётся source of truth.

При `Internal booking` Creator настраивает:

- booking open/close window;
- instant confirmation или manual approval;
- waitlist и auto-promotion policy;
- maximum tickets per user/order;
- обязательные attendee fields и consent text;
- cancellation/refund policy;
- ticket delivery: in-app, email, QR/barcode;
- check-in mode, допустимое окно и разрешённый offline signed-ticket scan;
- transfer/guest-name change policy;
- occurrence scope для series.

Booking lifecycle использует baseline ADR:

```text
pending → confirmed → cancelled
   ├→ expired
   └→ waitlisted → pending | confirmed | expired
```

Attendance (`not_checked_in`, `checked_in`, `no_show`) и Payment status —
отдельные оси, не новые Booking lifecycle states.

Offline check-in использует подписанный непрозрачный ticket payload без PII,
локальный append-only scan log и idempotent sync. Конфликт повторного scan не
создаёт второй Attendance и виден оператору.

Approval и waitlist правила:

- legacy `approvalRequired` является compatibility input; канонический режим —
  `confirmationMode=manualApproval`;
- legacy `waitlistEnabled` является compatibility input; канонический
  `waitlistPolicy` требует конечный inventory/capacity;
- promotion из waitlist создаёт ограниченный по времени hold;
- при платном Event promoted attendee получает payment deadline;
- истёкший hold возвращает место следующему кандидату idempotently.

Текущий draft field `bookingLink` при реализации должен быть однозначно
сопоставлен с публичным `externalBookingUrl`; два конкурирующих поля вводить
нельзя.

Текущий одиночный `registrationDeadlineUtc` покрывает one-time Event. Для series
нужен typed deadline rule; переиспользовать один абсолютный timestamp для всех
occurrences нельзя.

Deadline rule находится в Registration section шага 4, но валидируется вместе
с расписанием:

- one-time: абсолютный local deadline, сохраняемый как UTC и находящийся раньше
  start;
- recurring: положительный offset до каждой occurrence, например за 2 часа;
- multi-date: absolute deadline на occurrence либо общий offset;
- `No registration`: deadline отсутствует.

```text
RegistrationDeadlineRule
  kind: none | absolute | beforeOccurrence
  absoluteAtUtc: DateTime?       // только one-time
  offsetMinutes: int?            // recurring/multi-date, > 0
```

Per-occurrence absolute deadline для multi-date задаётся occurrence override
§11.8, а не расширением общего rule: rule хранит общий offset либо `none`,
исключение — absolute deadline конкретной occurrence.

#### 13.3.1 Internal payments

Платный internal booking разрешён только если:

- Publisher прошёл требуемый KYC/KYB и имеет активный payout account;
- market/payment config разрешает currency, taxes и payment methods;
- выбран refund/cancellation policy;
- Terms, fee breakdown и итоговая сумма доступны до подтверждения;
- PSP integration и webhook verification здоровы.

Payment lifecycle отделён от Booking:

```text
not_required | requires_payment | processing | authorized | captured
failed | cancelled | partially_refunded | refunded | disputed
```

Backend создаёт PaymentIntent/idempotency key, проверяет amount по server-side
price snapshot, обрабатывает SCA/3DS через PSP SDK и доверяет итоговому status
только подписанному webhook/provider lookup. Raw PAN/CVV не хранится и не
логируется Recharge.

Cancellation запускает refund usecase согласно policy. Booking не становится
`refunded`: он остаётся `cancelled`, а refund отражается Payment axis. Partial
refund хранит Money amount и причину. Chargeback/dispute не редактируется из
Event Create и обрабатывается Payments/Admin domains.

URL-валидация:

- только HTTPS;
- запрещены `javascript:`, `data:` и локальные схемы;
- домен отображается пользователю до перехода;
- ссылка открывается через общий safe external-link handler;
- отсутствие URL блокирует Publish только при выбранном External registration.

### 13.4 Видимость

Creator выбирает:

- `public` — Event участвует в Discover/Map/Search после moderation;
- `unlisted` — доступен по стабильной ссылке, не участвует в общей выдаче;
- `private` — доступен только по invitation, allowlist, membership rule или
  access code.

Private access policy определяет, можно ли видеть metadata до авторизации,
передавать приглашение, использовать access code повторно и кто может booking.
Secret/access code хранится hashed, имеет expiry/revocation и не попадает в
analytics. Unlisted не означает private: любой обладатель ссылки может открыть
Event, если дополнительная policy не задана.

### 13.5 Матрица совместимости режимов

Publish валидирует как минимум независимые `admissionMode`,
`registrationMode`, `confirmationMode`, `pricingMode`,
`paymentCollectionMode`, `inventoryAuthority`, shapes/pools, eligibility и
visibility. Несовместимая комбинация блокирует Publish и указывает все
конфликтующие поля. Таблица ниже покрывает price/payment subset и не заменяет
полную cross-validation matrix §19 Accepted Event Classification.

| Pricing | Допустимый payment collection | Обязательные условия |
|---|---|---|
| `free` | `none` | `price = null`, charge CTA отсутствует. |
| `fixed` | `onsite`, `external`, `internal` | Положительный `Money`; `internal` требует C3 readiness. |
| `ticketTypes` | `external`, `internal` | Для `internal` обязательны inventory и C3; для `external` provider является source of truth. |
| `donation` | `onsite`, `external`, `internal` | Minimum/suggested amount согласованы; online-сбор требует provider/payment readiness. |

Дополнительные правила:

- `registrationMode = none` не создаёт Booking; допустимы `none`, `onsite` или
  отдельный external donation/payment CTA без обещания места;
- `registrationMode = external` требует `externalBookingUrl`; Booking,
  availability и payment status не обещаются без approved connector;
- бесплатный `registrationMode = internal` использует
  `paymentCollectionMode = none` и требует C2;
- платный `registrationMode = internal` использует
  `paymentCollectionMode = internal` и требует C3;
- `onlineAccessMode = internalBooking` требует internal registration;
- `onlineAccessMode = externalRegistration` требует external registration;
- approval, waitlist, Recharge inventory и check-in допустимы только для
  internal registration;
- `openEntry` требует registration none; optional RSVP остаётся только
  interest/reminder intent;
- waitlist/reconfirmation требуют конечный inventory и authoritative
  lifecycle;
- external provider fields read-only и всегда имеют freshness;
- unknown/stale price или availability не проецируются как free/available;
- external registration/payment URLs проходят §13.3 URL validation независимо.

## 14. Шаг 5 — Preview и публикация

### 14.1 Preview

Preview использует тот же presentation model, что Event Details, и показывает:

- cover/gallery;
- title, Publisher и moderation-independent badges;
- archetype и primary/additional participation modes;
- category/subcategory и criteria;
- local date/time/timezone;
- recurrence summary и ближайшие occurrences;
- location/map или online/hybrid label;
- description;
- amenities/accessibility;
- price/ticket types, fees/taxes и sales windows;
- admission/confirmation disclosure, capacity/channel availability,
  registration/booking/external-provider CTA;
- inventory/provider source, freshness и explicit unknown/stale states;
- cancellation/refund policy;
- visibility/access summary;
- online access disclosure без показа secret join data;
- предупреждения о незаполненных полях.

Preview не создаёт отдельную копию данных. Он читает текущий draft snapshot.

### 14.2 Readiness

Readiness группирует проблемы:

- `Blocking` — Publish невозможен;
- `Warning` — Publish разрешён, но качество карточки снижено;
- `Ready` — секция заполнена.

Нажатие на проблему возвращает пользователя к конкретному шагу и полю.

### 14.3 Подтверждения

Перед Publish Creator подтверждает:

- право публиковать контент и медиа;
- корректность времени, адреса и цены;
- корректность применимых ticket inventory, fees/taxes и
  refund/cancellation policy;
- для internal paid — право принимать платежи от имени Publisher и
  актуальность payout data;
- согласие с Terms/Community rules;
- отсутствие запрещённого или вводящего в заблуждение контента.

Ссылки Terms/Support берутся из единого legal-links config.

## 15. Полная publish-валидация

Publish выполняет проверки в фиксированном порядке:

1. Draft существует и не архивирован.
2. Сессия действительна.
3. Capability `publish.event` доступна для Publisher.
4. PublisherRef валиден, не изменился от workspace switch и является
   единственным Publisher Event.
5. Обязательные общие поля, ровно один archetype и participation заполнены.
6. Category/subcategory активны и разрешены для Event; category не выбирала
   aggregate/archetype/admission автоматически.
7. Required dynamic criteria заполнены и типизированы.
8. Format, location и online access согласованы.
9. Availability имеет kind `eventSlots`, непустые slots, пустые opening hours и
   неотрицательные buffers.
10. Schedule/recurrence/partial-attendance rules валидны и имеют будущую
   occurrence.
11. Amenities/requirements не противоречат category rules.
12. Admission/registration/confirmation/eligibility/interest/guest/waitlist/
    attendance policies согласованы.
13. Pricing, price knowledge, payment collection, inventory authority,
    shapes/pools/channel, capacity и provider freshness согласованы.
14. Registration, confirmation/waitlist и deadline rules валидны.
15. Pricing/admission/registration/payment combination разрешена матрицей
    §13.5 и канонической §19;
    необходимые external URLs либо internal Booking/Payment config готовы.
16. Для internal paid Event Publisher payout/KYC, tax/fee и refund policy готовы.
17. Visibility/access policy валидна, private secrets не попали в projection.
18. Provider-owned поля не были изменены Recharge overlay.
19. Cover/media полностью обработаны, промодерированы и имеют rights metadata.
20. Нет незавершённого conflict resolution/migration suggestion.
21. Пройдены duplicate/spam checks без silent fuzzy merge.
22. Подтверждены legal assertions.

Repository/backend повторяет все критичные проверки независимо от клиента,
применяет baseline publish velocity limit `100/day` на Creator и запускает
duplicate/suspicious-activity checks moderation pipeline. Клиентская проверка
не является security boundary.

Ошибки возвращаются структурой:

```text
fieldId
stepId
code
localizedMessageKey
severity: blocking | warning
```

Бизнес-логика не должна зависеть от английского текста сообщения.

## 16. Publish pipeline

1. Запустить autosave и зафиксировать immutable draft snapshot.
2. Выполнить полную валидацию snapshot.
3. Дождаться обязательных media uploads.
4. Повторно проверить auth/capabilities.
5. Для Event и всех publishable child entities с `loc_*` (occurrences,
   overrides, ticket types, inventory pools, media records) создать постоянные
   ULID на клиенте и подготовить mapping table.
6. Нормализовать timestamps, money, tickets/inventory, category ids, access
   policy и URL; secret access data передать только в защищённый contract.
7. Сформировать idempotency key для конкретной publish attempt.
8. До сетевого запроса атомарно сохранить `PublishAttempt` со state `prepared`,
   mapping table, idempotency key и snapshot hash.
9. Вызвать repository/usecase, не datasource напрямую из UI.
10. После отправки отметить attempt как `sent`; после подтверждения —
    `accepted` или `failed` с типизированным error code.
11. При успехе финализировать все local id → permanent id mappings.
12. Установить lifecycle `pending_review`, moderation `pending`.
13. Записать audit event create/publish.
14. Открыть success screen с permanent id и ожидаемым статусом.

Повторный tap, timeout или повтор запроса с тем же idempotency key не должен
создавать дубликат Event.

После перезапуска `prepared/sent` attempt проверяется по permanent id и
idempotency key до создания нового запроса. Если backend принял Event, а
локальная финализация не успела сохраниться, mapping и `pending_review`
восстанавливаются из ответа repository.

### 16.1 Успешный экран

Показывает:

- `Event sent for review`;
- title и Publisher;
- ожидаемый статус `Pending review`;
- действия `View submission`, `Back to Profile`, `Create another`;
- отсутствие обещания, что Event уже виден в Discover.

`View submission` использует permanent Event id и тот же стабильный deep-link/
route contract, что будущие push и внешние ссылки; pending content видит только
авторизованный Publisher с соответствующим доступом.

Пока Event находится в `pending_review`, public booking/sales закрыты. Они
открываются только после `published`, наступления sales window и успешного
Booking/Payment readiness check.

### 16.2 Результат модерации

- `approved` → Event становится `published` и участвует в выдаче согласно
  visibility и времени;
- `rejected` → публичная версия не создаётся; Creator видит причины, исправляет
  вернувшийся в `draft` Event и отправляет повторно (`resubmission`); термин
  revision используется только для изменений уже опубликованного Event §17;
- `hidden` → Event убирается из публичного доступа системно/модерацией;
- пять уникальных жалоб за 24 часа запускают auto-hide baseline ADR, но не
  заменяют ручное moderation review.

## 17. Редактирование после публикации

### 17.1 Несущественные изменения

Исправление опечатки или alt text может применяться без снятия публикации, если
moderation policy относит поле к нематериальному. Каждое изменение попадает в
audit trail.

### 17.2 Существенные изменения

К существенным изменениям относятся:

- start/end/timezone/recurrence;
- location или online/offline format;
- цена и условия регистрации;
- Publisher;
- существенная смена title/category/content;
- отмена occurrence или всей series.

Production revision policy:

1. Каждое редактирование создаёт immutable revision с author/time/reason.
2. Опечатки, alt text и другие low-risk поля применяются сразу с audit trail.
3. Операционные изменения времени, локации и cancellation применяются сразу,
   получают post-moderation и запускают attendee/subscriber notifications.
4. Publisher, category, основные description/media и access-policy изменения
   проходят pre-moderation; до approval остаётся предыдущая публичная revision.
5. Price/ticket changes действуют только на новые Booking; существующий Booking
   сохраняет price/terms snapshot.
6. Refund/cancellation policy нельзя ретроактивно ухудшить для уже купленных
   билетов.
7. После approval revision атомарно становится current; отклонённая revision
   остаётся в audit history, но не в public projection.
8. Для external booking Publisher отвечает за синхронное уведомление клиентов
   внешнего provider; Recharge уведомляет доступных подписчиков/Booking.

### 17.3 Редактирование series

Production UI поддерживает три scope изменения:

- `This occurrence`;
- `This and future occurrences`;
- `Entire series`.

У каждой occurrence стабильный id. Уже завершённые occurrences не изменяются.
Отмена создаёт cancellation status/exception, а не удаляет запись без следа.
Отмена всей series помечает будущие occurrences отменёнными и архивирует Event;
новое lifecycle-значение `cancelled` не вводится, поскольку его нет в ADR.

Изменение rule не переиспользует ids для семантически других occurrences.
Удаляемая occurrence с активными Booking проходит cancel/refund flow; новая
получает новый ULID. Existing Booking никогда не «переезжает» на другую дату
молчаливо.

## 18. Архивирование и удаление

- Archive убирает Event из публичной выдачи, но само по себе не отменяет
  подтверждённые Booking или будущие occurrences.
- При active future Booking Archive требует отдельного подтверждения и сохраняет
  attendee-only access к билетам, join/location updates и support; скрыть эти
  данные вместе с публичной карточкой нельзя.
- Cancel occurrence/series — отдельная доменная команда с reason, effective
  scope, notification plan и refund preview до подтверждения.
- Delete — soft delete с retention 30 дней.
- Hard delete выполняется после retention или по legal request.
- Creator не может самостоятельно переводить Event в `hidden`: это системный
  moderation status.
- Event с активными internal Booking нельзя удалить до cancellation/refund
  resolution; cancel атомарно закрывает inventory и запускает policy-based
  refunds/notifications.
- Для external booking Publisher подтверждает, что выполнил обязательства
  внешнего provider; Recharge сохраняет audit acknowledgement.

## 19. Ошибки и восстановление

| Ситуация | Поведение |
|---|---|
| Нет сети | Редактирование и local autosave продолжаются; Publish предлагает повторить после восстановления сети. |
| Ошибка local save | Показывается persistent warning; выход требует подтверждения риска. |
| Cover upload failed | Остальная форма сохраняется; у файла есть Retry/Replace/Remove. |
| Сессия истекла | Draft сохраняется, Auth открывается с возвратом в тот же draft/step. |
| Capability отозвана | Редактирование локальной копии возможно; Publish заблокирован до выбора разрешённого Publisher. |
| Feature flag отключён | Draft остаётся доступен; Publish/recurrence action блокируется с понятным сообщением и без потери полей. |
| Category устарела | Показывается миграция к актуальной категории; silent remap допустим только по принятой migration table. |
| Время уже прошло | Поле schedule получает blocking error и действие `Choose new time`. |
| Publish timeout | Запрос проверяется по idempotency key; нельзя сразу создавать второй Event. |
| Publish rate limit | Draft сохраняется; показывается время следующей попытки, если оно возвращено backend. |
| Server validation | Ошибки маппятся к step/field; draft остаётся на месте. |
| Version conflict | Показывается conflict UI; локальные данные не уничтожаются. |
| Приложение закрыто во время Publish | При возврате восстанавливается publish attempt и проверяется результат по id. |
| Payout/KYC не готов | Paid internal Publish блокируется, free/external modes остаются доступны. |
| Inventory изменился | Backend возвращает актуальный остаток; UI пересобирает order, не допускает oversell. |
| Payment requires action | Booking hold сохраняется на ограниченный TTL, пользователь возвращается в PSP flow. |
| Payment failed/timeout | Status сверяется с PSP по idempotency key; повторный charge без проверки запрещён. |
| Booking webhook задержан | Показывается pending state; provider lookup/reconciliation восстанавливает итог. |
| Refund failed | Booking остаётся cancelled, Payment получает refund-pending/error и попадает в operations queue. |

## 20. Уведомления

После реализации notification slice Event должен создавать события:

- публикация одобрена/отклонена;
- booking request/approval/rejection;
- payment action required/succeeded/failed;
- waitlist entry/promotion/expiry;
- ticket/QR issued;
- напоминание перед occurrence;
- изменилось время;
- изменилась локация;
- occurrence/series отменена;
- refund initiated/completed/failed;
- check-in reminder/result;
- запрос отзыва после завершения.

Для internal Booking источником служат Booking/Payment state transitions. Для
external provider Recharge отправляет transactional status только при наличии
проверенной integration/webhook; простой URL не позволяет обещать confirmation,
waitlist или refund status.

Точный канал, consent и timing задаются notification policy, а не Event page.

## 21. Analytics и observability

При реализации новые analytics events сначала добавляются в
`docs/analytics/EVENT_CATALOG.md`.

Имена следуют принятому формату `<feature>_<object>_<action>`. Успех/ошибка по
возможности передаются параметром `result`, а не создают два конкурирующих
события.

| Событие | Статус относительно каталога | Минимальный Event-контекст |
|---|---|---|
| `create_event_started` | Новый кандидат | `source,publisher_type` |
| `create_event_step_viewed` | Новый кандидат | `step_id,source` |
| `create_event_step_completed` | Новый кандидат | `step_id,result,error_count` |
| `create_draft_saved` | Уже есть | `draft_type=event,result,error_code?` |
| `create_draft_restored` | Новый кандидат | `draft_type=event,source,result` |
| `create_media_upload_failed` | Новый кандидат | `media_role,error_code` |
| `create_ticketing_configured` | Новый кандидат | `ticket_type_count,booking_mode,paid` |
| `create_access_policy_selected` | Новый кандидат | `visibility,access_mode` |
| `create_publish_validation_failed` | Новый кандидат | `entity_type=event,step_id,error_codes` |
| `create_publish_submitted` | Уже есть | `entity_type=event,source` |
| `create_publish_completed` | Уже есть | `entity_type=event,result,error_code?` |
| `create_moderation_result_received` | Новый кандидат | `entity_type=event,result` |

Текущие runtime-имена `create_draft_loaded` и `create_publish_succeeded` должны
быть сверены с каталогом в будущем analytics slice. Эта спецификация не
легализует события, отсутствующие в `EVENT_CATALOG.md`.

Не отправлять в analytics description, адрес, email, phone, booking URL,
access code, join secret, attendee answers, ticket/QR payload, PaymentIntent id
или другие персональные/финансовые значения. Допустимы ids справочников,
обезличенные статусы, duration, currency и агрегированные количества ошибок.

Analytics отправляется только при действующем consent для рынка; для EU
применяется opt-in baseline ADR.

Structured logs должны связывать publish attempt через correlation/idempotency
id и не содержать секретов.

## 22. Локализация, доступность и форматирование

- В UI нет захардкоженных пользовательских строк: все labels/errors/policies
  имеют en/ru/lv l10n keys и locale-aware fallback.
- Дата/время вводятся в локальном формате, но timezone всегда видима.
- Цена форматируется по locale и currency.
- Ошибка обозначается не только цветом.
- Каждый input имеет label, hint и accessibility semantics.
- Stepper доступен с screen reader и сообщает текущий шаг.
- Изображения поддерживают alt text/описание.
- Touch targets и контраст соответствуют design system.

## 23. Целевой семантический контракт Event draft

Это логическая модель, а не обязательное указание создать один огромный класс.
Конкретные value objects должны следовать слоям domain/application/data.

```text
EventDraft
  id: ULID | loc_*
  objectType: event
  publisherRef: { type: user | page, id: ULID }

  eventArchetype: EventArchetype
  primaryParticipationMode: ParticipationMode
  additionalParticipationModes: Set<ParticipationMode> // max 3

  title
  mainCategoryId
  subcategoryId
  tags[]
  shortDescription
  fullDescription
  criteria: Map<fieldId, typedValue>

  format: offline | online | hybrid
  onlineAccessMode?: publicLink | internalBooking | externalRegistration
  publicOnlineUrl?
  protectedOnlineAccessRef?
  timezone: IANA
  scheduleMode: oneTime | multiDate | recurring
  startAtUtc
  endAtUtc
  durationMinutes
  recurrence?
  eventSlots[]
  occurrenceOverrides[]
  allowsPartialAttendance
  minimumVisitDurationMinutes?
  bufferBeforeMinutes
  bufferAfterMinutes
  registrationDeadlineRule?
  admissionWindows[]

  marketCityId
  countryCode
  address?
  lat?
  lng?
  meetingPoint?
  locationAccuracy?

  amenityIds[]
  requirements
  audience

  pricingMode: free | fixed | ticketTypes | donation
  price: Money?
  pricingModel?
  ticketTypes[]
  inventoryPools[]
  capacityMode: known | unknown | unlimited
  capacity: int?
  inventoryAuthority: none | recharge | externalProvider
  inventoryShapes[]
  inventoryPools[]
  admissionMode: openEntry | rsvp | booking | application | ticket |
                 teamRegistration
  registrationMode: none | external | internal
  confirmationMode: none | instant | manualApproval | lottery |
                    providerManaged
  eligibilityRules[]
  guestPolicy?
  waitlistPolicy?
  onsiteAdmissionPolicy?
  interestPolicy?
  attendancePolicy?
  externalBookingUrl?
  paymentCollectionMode: none | onsite | external | internal
  priceKnowledge: known | unknown
  priceDisplay?
  externalPaymentUrl?
  externalPricePolicy?: informational | providerSynced
  bookingPolicy?
  refundPolicy?
  checkInPolicy?
  paymentConfigurationRef?

  cover: MediaAssetRef
  gallery: MediaAssetRef[]
  videos: MediaAssetRef[]

  lifecycleStatus
  moderationStatus
  visibility: public | unlisted | private
  accessPolicy?
  eventRelations[]
  unlinkedCredits[]
  routeRef?
  programItemRefs[]
  sourceRecords[]
  fieldAuthority?
  freshness?
  schemaVersion
  revisionVersion
  createdAtUtc
  updatedAtUtc
  publishedAtUtc?
```

### 23.1 Соответствие текущему CreateDraftEntity

Уже присутствуют основные поля title, category/subcategory, descriptions,
`sectionData`, start/end/duration/timezone, availability slots, location,
participants/audience, price, booking, organizer, media и statuses.

Перед реализацией нужно выполнить следующие контрактные миграции:

- заменить organizer-only ownership на канонический Publisher;
- добавить typed archetype/participation и explicit legacy suggestion без
  silent write;
- выделить typed recurrence model;
- добавить multi-date и typed occurrence overrides;
- заменить одиночный deadline на typed one-time/recurring deadline rule;
- ввести typed amenities storage;
- унифицировать `bookingLink` и `externalBookingUrl`;
- выделить `paymentCollectionMode`; не смешивать registration URL, payment URL
  и способ оплаты в одном legacy `bookingLink`;
- выделить TicketType/BookingPolicy/RefundPolicy/CheckInPolicy value objects;
- хранить protected online access и private access secrets только через
  encrypted secret references, не в draft JSON/plain projection;
- добавить Booking/Payments API contracts и webhook/idempotency models;
- сопоставить `publisher.type/id` с обязательными `owner_type/owner_id` ADR и
  не хранить параллельные конфликтующие связи по имени;
- не проецировать текущий default `currentParticipants = 0` как подтверждённый
  ноль при external registration: без источника Discover получает `null`;
- расширить API/Discover projection явным `capacityMode`, не меняя принятую
  семантику `capacity = null` как unknown в legacy contract;
- добавить `discoverEligible`, channel availability, source/freshness и
  nullable participants projection без смешения с lifecycle;
- хранить permanent ULID вместо текущего временного `draft_*` при публикации;
- добавить schema version и migration для новых draft fields.

Create domain не импортирует `discover/domain`: cross-feature взаимодействие
идёт только через contracts/facades, а опубликованный Event преобразуется в
Discover projection на data/API boundary. Существующий `packages/api_contracts`
— единственный источник истины для DTO и API clients по frozen architecture;
расширение его contracts выполняется отдельным slice без создания параллельного
глобального domain-модуля или app-local API contract.

Event draft хранит только Ticket/Booking/Refund/Check-in configuration и
references. Реальные Booking, Attendance, Payment, Refund и payout ledger —
отдельные entities/repositories; их нельзя сериализовать внутрь Event draft или
редактировать через `CreateController` как вложенный список.

## 24. Конфигурация form engine

Целевой Event config концептуально выглядит так:

```text
CreateTypeConfig(event)
  steps:
    1. BasicsAndMedia
       EventClassificationSection(archetypeRequired, participationRequired)
       NameDescriptionSection(required)
       CategorySection(required)
       DynamicCriteriaSection(dynamic)
       MediaSection(coverRequiredOnPublish)

    2. LocationAndSchedule
       FormatSection(required)
       LocationSection(requiredWhenOfflineOrHybrid)
       ScheduleModeSection(required)
       MultiDateSection(whenMultiDate)
       RecurrenceScheduleSection(whenRecurring)
       OccurrenceOverridesSection(dynamic)

    3. AmenitiesAndRequirements
       AmenitiesSection(taxonomyDriven)
       AudienceRequirementsSection(dynamic)

    4. PriceAndParticipants
       AdmissionPresetSection(required, normalizedToIndependentAxes)
       AdmissionPolicySection(dynamic)
       PricingSection(required)
       TicketTypesSection(whenTicketed)
       InventoryAuthoritySection(requiredWhenFiniteOrProvider)
       InventoryPoolsSection(whenFiniteOrTicketed)
       ChannelInventorySection(whenHybridAndFinite)
       CapacitySection(optional)
       RegistrationConfirmationSection(required)
       InterestPolicySection(whenOpenEntryOptionalRsvp)
       AttendancePolicySection(whenInternalFinite)
       BookingPolicySection(whenInternal)
       PaymentReadinessSection(whenInternalPaid)
       RefundPolicySection(whenInternal)
       CheckInPolicySection(whenInternal)
       VisibilityAccessSection(required)

    5. PreviewAndPublish
       ReadinessSection
       EventPreviewSection
       LegalConfirmationSection
       PublishAction
```

Порядок, видимость и required rules задаёт config/usecases. Event page не должен
содержать длинный набор `if (objectType == event)` или 34 archetype-ветки для
всех бизнес-правил. `EventCreateBlock` читает typed view state/config и только
вызывает controller commands; domain rules остаются в value objects/usecases.

## 25. Acceptance criteria

Этот раздел проверяет Creator flow и production Event Create behavior.
Дополнительно и без дублирования обязательны все 43 acceptance criteria
Accepted `EVENT_CLASSIFICATION_SPEC.md` §24. Статус каждого ECL slice ведётся
кумулятивно как `canonical AC -> automated test/manual gate -> layer -> status`.
Наличие похожего legacy field или enum не считается выполнением канонического
AC.

### AC-01 — Новый draft

- **Given:** авторизованный пользователь с `create.event`.
- **When:** он выбирает Event в Create Hub.
- **Then:** создаётся `loc_*` draft типа Event с new-draft PublisherRef default
  из active workspace, пустым обязательным archetype и market defaults; draft
  открывается на шаге 1.
- **And:** последующий workspace switch этот PublisherRef не переписывает.

### AC-02 — Нет capability

- **Given:** авторизованный User без `create.event`.
- **When:** он открывает Event create route.
- **Then:** draft не создаётся и показывается Upgrade/access explanation.

### AC-03 — Autosave и restore

- **Given:** пользователь изменил поля и закрыл приложение.
- **When:** он возвращается.
- **Then:** восстанавливаются значения и последний открытый шаг.

### AC-04 — Category-driven form

- **Given:** выбрана Event subcategory.
- **When:** она имеет criteria profile.
- **Then:** форма показывает только поля профиля и блокирует переход при пустых
  required criteria.
- **And:** category не выбирает archetype, aggregate, admission или pricing.

### AC-05 — Безопасная смена категории

- **Given:** criteria уже заполнены.
- **When:** пользователь меняет subcategory.
- **Then:** совместимые значения сохраняются, несовместимые показываются перед
  удалением, новые required fields добавляются.

### AC-06 — One-time schedule

- **Given:** выбран one-time режим.
- **When:** заданы валидные local start/end и timezone.
- **Then:** создаётся один UTC event slot с корректной duration.

### AC-07 — Recurring schedule

- **Given:** выбран daily/weekly/monthly/yearly режим с end policy.
- **When:** правило и завершение валидны.
- **Then:** usecase генерирует стабильные occurrences/event slots в UTC,
  сохраняет local time/DST policy, а rolling projection продолжает series без
  обрезания исходного rule.

### AC-08 — Условная location

- **Given:** format offline, online или hybrid.
- **When:** пользователь продолжает flow.
- **Then:** обязательность физической точки и online access следует таблице
  format.

### AC-09 — Pricing

- **Given:** выбраны pricing, registration и payment collection modes.
- **When:** amount нарушает правила режима либо комбинация не разрешена §13.5.
- **Then:** Publish блокируется field-level ошибками всех конфликтующих полей.
- **And:** optional donation без положительного minimum проецируется как
  `isFree = true`, а donation с обязательным minimum — как `isFree = false`.

### AC-10 — External registration

- **Given:** выбран режим External registration.
- **When:** `externalBookingUrl` отсутствует или небезопасен.
- **Then:** Publish блокируется; internal approval/waitlist state не создаётся
  без provider integration.

### AC-11 — Cover

- **Given:** cover отсутствует или ещё загружается.
- **When:** пользователь нажимает Publish.
- **Then:** Publish не отправляется, а UI ведёт к Media section.

### AC-12 — Publish idempotency

- **Given:** пользователь дважды нажал Publish или повторил запрос после
  timeout.
- **When:** используется одна publish attempt.
- **Then:** создаётся не более одного permanent Event.

### AC-13 — Permanent id

- **Given:** валидный draft имеет `loc_*` id.
- **When:** начинается первая публикация.
- **Then:** клиент генерирует ULID, сохраняет mapping и все новые связи
  используют только permanent id.

### AC-14 — Moderation

- **Given:** repository принял Publish.
- **When:** success screen открыт.
- **Then:** статус равен `pending_review`, а приложение не утверждает, что Event
  уже опубликован.

### AC-15 — Offline failure

- **Given:** сеть пропала во время редактирования или Publish.
- **When:** операция завершается ошибкой.
- **Then:** локальный draft сохранён, повтор доступен, дубликат не создаётся.

### AC-16 — Publisher permission revoked

- **Given:** право управления Page было отозвано.
- **When:** пользователь пытается Publish.
- **Then:** операция блокируется до выбора доступного Publisher, draft не
  удаляется.

### AC-17 — Preview parity

- **Given:** Event готов к публикации.
- **When:** открыт Preview.
- **Then:** ключевые данные отображаются так же, как в будущей Event Details
  model, без отдельной копии draft.

### AC-18 — Безопасный seed

- **Given:** Create similar открыт для Event другого Publisher.
- **When:** формируется новый draft.
- **Then:** переносятся только разрешённые taxonomy/format/location hints;
  Publisher, ids, тексты, media и booking URL не копируются.

### AC-19 — Availability contract

- **Given:** Event готовится к Publish.
- **When:** запускается полная валидация.
- **Then:** `availabilityKind = eventSlots`, slots непусты, opening hours пусты,
  slot ids допустимы и onsite buffers неотрицательны.
- **And:** это schedule/time-fit contract, а не доказательство authoritative
  inventory availability.

### AC-20 — Неизвестная capacity

- **Given:** Creator не указывает лимит участников.
- **When:** Event публикуется.
- **Then:** сохраняется `{capacityMode: unknown, capacity: null}`, а UI не
  интерпретирует это как `500+`, unlimited или sold out без explicit mode.

### AC-21 — Crash recovery Publish

- **Given:** приложение закрыто после отправки Publish, но до локального success.
- **When:** пользователь возвращается в flow.
- **Then:** сохранённый publish attempt проверяется по permanent id/idempotency
  key и второй Event не создаётся.

### AC-22 — Multi-date

- **Given:** Creator выбирает несколько несистемных дат.
- **When:** интервалы валидны.
- **Then:** создаются отсортированные occurrences со стабильными ids без
  искусственного recurrence rule.

### AC-23 — Occurrence override

- **Given:** recurring Event имеет конкретную occurrence.
- **When:** Creator меняет её время, location или inventory.
- **Then:** сохраняется override по occurrence id, а series rule и остальные
  occurrences не меняются.

### AC-24 — Internal free booking

- **Given:** выбран Internal booking для бесплатного Event.
- **When:** attendee бронирует последнее место.
- **Then:** inventory изменяется транзакционно, Booking получает корректный
  lifecycle status, oversell невозможен.
- **And:** uniform concurrency cap проверяется в той же транзакции до inventory
  mutation; отказ не создаёт Booking/hold и остаётся идемпотентным.
- **And:** если включена reconfirmation, пропущенный deadline атомарно
  освобождает Booking с reason `missedReconfirmation` и запускает waitlist без
  персонального reliability score.

### AC-25 — Internal paid booking

- **Given:** Event имеет платные ticket types.
- **When:** payout/KYC, refund policy или PSP integration не готовы.
- **Then:** Publish блокируется с конкретным readiness error; Creator может
  переключиться на free или external mode без потери draft.

### AC-26 — Ticket price snapshot

- **Given:** существующий Booking куплен по старой цене.
- **When:** Creator меняет ticket price.
- **Then:** новая цена применяется только к новым Booking, а существующий
  сохраняет неизменяемый price/terms snapshot.

### AC-27 — Waitlist promotion

- **Given:** освободилось место и waitlist включён.
- **When:** система продвигает следующего attendee.
- **Then:** создаётся TTL hold; expiry атомарно возвращает inventory и
  продвигает следующего кандидата без дублирования.

### AC-28 — Private access

- **Given:** visibility равен `private`.
- **When:** пользователь без invitation/allowlist/access code открывает link.
- **Then:** protected metadata, booking и join secrets недоступны; access secret
  не появляется в URL analytics или logs.

### AC-29 — Cancellation и refund

- **Given:** occurrence с подтверждёнными paid Booking отменяется.
- **When:** Creator подтверждает cancel preview.
- **Then:** inventory закрывается, Booking отменяются, policy-based refunds и
  notifications запускаются idempotently.

### AC-30 — Payment idempotency

- **Given:** PSP webhook доставлен повторно или checkout возвращается после
  timeout.
- **When:** reconciliation обрабатывает один PaymentIntent.
- **Then:** charge/capture/refund применяется один раз, а Booking и inventory
  приходят к одному итоговому состоянию.

### AC-31 — Check-in

- **Given:** подтверждённый ticket предъявлен в допустимое check-in window.
- **When:** QR/barcode сканируется повторно.
- **Then:** первый запрос фиксирует Attendance, повторный показывает уже
  использованный ticket и не увеличивает participants count.

### AC-32 — Проверки проекта

После будущей реализации `flutter analyze` должен вернуть 0 ошибок, а полный
`flutter test` — пройти без новых skip. Нужны unit-тесты usecases/controller,
widget-тесты пяти шагов, contract tests Booking/Payments/webhooks и integration
paths draft → pending_review, internal booking/payment/refund и series edits.
Каждый изменённый Event UI проходит 360 dp при 150% text scale и не кодирует
ошибку/availability только цветом.

### AC-33 — Draft conflict

- **Given:** один draft изменён на двух устройствах или локально и на backend.
- **When:** sync обнаруживает более новую revision.
- **Then:** применяется принятый last-write-wins policy с user warning, обе
  версии доступны для сравнения/recovery, а скрытая потеря подтверждённых данных
  невозможна.

### AC-34 — All-day и multi-day

- **Given:** Creator создаёт all-day или многодневный Event.
- **When:** он меняет timezone, даты или формат all-day/timed.
- **Then:** local calendar dates и exclusive/inclusive boundary semantics
  сохраняются явно, UTC slots пересчитываются детерминированно, duration не
  становится отрицательной и Preview показывает правильные даты.

### AC-35 — DST boundary

- **Given:** occurrence попадает в DST gap или overlap IANA timezone.
- **When:** recurrence materializer применяет сохранённую DST policy.
- **Then:** результат детерминирован, local-time intent не меняется молча,
  Creator видит сдвиг/rejection, а повторная генерация даёт те же UTC slots и
  occurrence ids.

### AC-36 — Media pipeline и права

- **Given:** Creator добавил cover/gallery/video.
- **When:** media загружается, обрабатывается, отклоняется или удаляется до
  Publish.
- **Then:** состояние и retry видимы, Publish принимает только ready cover с
  подтверждёнными rights и alt text, а abandoned/orphan assets очищаются по
  retention policy без удаления используемого media.

### AC-37 — Server-side Publisher guard

- **Given:** клиент показывает разрешённый Publisher, но capability, membership
  или ownership были изменены после открытия формы.
- **When:** выполняется save, Publish, edit, cancel, refund или export attendee
  data.
- **Then:** backend повторно проверяет action-specific capability и Publisher
  scope; изменение блокируется без утечки данных и без потери draft.

### AC-38 — Конкурентный inventory

- **Given:** несколько attendee одновременно запрашивают последнее место либо
  один запрос повторяется после timeout.
- **When:** backend создаёт hold/Booking.
- **Then:** подтверждается не больше доступной квоты, остальные получают
  waitlist/sold-out result, а retry с тем же idempotency key не списывает
  inventory повторно.

### AC-39 — Protected online access

- **Given:** online/hybrid Event выдаёт join access только подтверждённым
  attendee.
- **When:** Booking подтверждается, отменяется, refunded или Event переносится.
- **Then:** доступ выдаётся/ротируется/отзывается policy-driven, raw join secret
  не хранится в Event projection и не попадает в push preview, URL analytics,
  logs или неавторизованный attendee response.

### AC-40 — Material revision

- **Given:** опубликованный Event имеет Booking или followers.
- **When:** Creator меняет время, location, цену, содержание, Publisher либо
  participation/refund rules.
- **Then:** до подтверждения показан impact preview, создаётся immutable
  revision, запускаются нужные re-moderation и notifications, а существующие
  Booking сохраняют применимый terms/price snapshot.
- **And:** Event не возвращается в Discover до применимой moderation policy;
  отсутствие будущих non-cancelled occurrences меняет только
  `discoverEligible`, не lifecycle.

### AC-41 — Series edit/cancel scope

- **Given:** recurring Event имеет прошлые и будущие occurrences, overrides и
  Booking.
- **When:** Creator выбирает `this occurrence`, `this and future` или
  `entire series`.
- **Then:** usecase меняет только выбранный scope, не переписывает историю,
  пересчитывает affected inventory/refunds и перед подтверждением показывает
  точное число затронутых attendee.

### AC-42 — Локализация и accessibility

- **Given:** Create открыт на en/ru/lv с keyboard, screen reader, dynamic text
  или повышенным contrast.
- **When:** пользователь проходит все пять шагов и исправляет ошибки.
- **Then:** focus order стабилен, поля имеют label/hint/error association,
  layout не обрезает критические действия, а date/time/currency/pluralization
  соответствуют locale и IANA timezone.

### AC-43 — Observability без утечки secrets

- **Given:** Create/Publish/Booking/Payment завершается успехом, retry или
  ошибкой.
- **When:** пишутся analytics, audit, logs и crash diagnostics.
- **Then:** события имеют correlation/idempotency ids и достаточный error
  context, но не содержат access codes, join links, raw payment data, attendee
  answers или другую PII вне утверждённой allowlist/retention policy.

### AC-44 — Staged rollout и rollback

- **Given:** production capability включается по feature flag для части market
  или Publisher.
- **When:** SLO/error budget нарушен и capability выключается.
- **Then:** новые входы безопасно блокируются, существующие Event/Booking/
  Payment/refund obligations продолжают обслуживаться, данные не теряются, а
  повторное включение не создаёт duplicate business effects.

## 26. Предлагаемое разбиение будущей реализации

Каноническая последовательность задаётся Event Classification и не может быть
заменена одним «полным Event» implementation slice:

| Slice | Результат | Жёсткая граница |
|---|---|---|
| ECL-00 | Canonical reconciliation, coverage matrix и docs alignment | Без runtime/schema/API changes |
| ECL-01 | Local archetype, participation, migration suggestions, typed validation и declarative form section | Без backend/provider/payment; shared PublisherRef dependency |
| ECL-02 | Local admission/inventory configuration и честная mock availability | Без real Booking/inventory mutation |
| ECL-03 | Internal free registration/Booking, atomic ledger, waitlist, reconfirmation и uniform concurrency cap | Отдельный Approved backend slice; без Payments |
| ECL-04 | External provider handoff | Provider ADR, legal/commercial contract, backend secrets и safe-link disclosure |
| ECL-05 | Verified provider availability/Booking mirror | Webhooks/polling, idempotency, freshness и reconciliation |
| ECL-06 | Program Items | Stable room/stage refs и child entity boundary |
| ECL-07 | Internal paid tickets | Payments/KYC/KYB/PSP/refund/payout gates |
| ECL-08 | Assigned seating presentation | Только authoritative provider hold API; без seating editor |

EVT-CRT-01 остаётся реализованным local/mock C0 + schedule-C1 baseline.
CRT-TPL-01 остаётся local-first template extension. Каждый следующий slice
сохраняет единый form engine, получает собственную Approved spec и проходит
analyzer, full tests, boundary, diff/migration и применимые accessibility/
concurrency/security gates. Документальное упоминание capability не разрешает
её runtime.

## 27. Обязательные production gates

Canonical Event contract фиксирует текущие решения, но не разрешает deferred
product scope: Announcement без occurrence (`EVT-ANN-01`), персональный
Trust/Risk scoring (`EVT-TRUST-01`) и денежный deposit/authorization hold
(`EVT-PAY-01`) требуют собственных обязательных артефактов. До production
rollout также обязательны:

1. Новый Booking/Payments ADR, расширяющий принятый MVP baseline ADR 0013.
2. Выбор PSP, KYC/KYB/payout model и PCI scope review.
3. Market-specific legal approval для taxes, fees, refund/cancellation,
   consumer rights и invoice/receipt requirements.
4. Security threat model для access codes, join secrets, QR/tickets, webhooks,
   idempotency и account takeover.
5. Privacy/DPIA и retention policy для attendee answers, Booking и Payment data.
6. Provider reconciliation, webhook retry/dead-letter и financial audit SLO.
7. Risk-based moderation policy для новых Events и material revisions.
8. Remote-config rollout/rollback plan и staged release по market/Publisher.
9. Provider ADR, source-authority/freshness contract и commercial/legal
   approval до ECL-04/05/08.
10. Versioned Event/Booking/inventory DTO в `packages/api_contracts` до любой
    production integration.

Gate блокирует включение соответствующей capability, но не удаляет её из
целевого продукта и не требует упрощать общий form/data contract.

| Gate | Минимальный scope блокировки |
|---|---|
| 1. Booking/Payments ADR | Booking-часть блокирует C2; Payments-часть блокирует C3. Решение может быть одним или несколькими ADR. |
| 2. PSP/KYC/KYB/PCI | C3 internal payments и online donations. |
| 3. Legal/taxes/refunds | C3 и любая market-specific платная capability. |
| 4. Security threat model | C2; C3; любая C1/C3 access capability, использующая secrets. |
| 5. Privacy/DPIA/retention | C2/C3 и любой attendee-data collection сверх минимального external redirect. |
| 6. Reconciliation/webhooks/audit SLO | C3 и provider connector, который синхронизирует Booking/Payment state. |
| 7. Moderation policy | Любой production Publish, начиная с C0; material revision rules — C1+. |
| 8. Rollout/rollback plan | Любой production rollout, начиная с C0. |
| 9. Provider authority | ECL-04/05/08 и любой provider-owned operational field. |
| 10. API contracts | Любой production Event/Booking/provider backend boundary. |

R0 mock/local не считается production rollout и не может обходить gates под
названием C0. Gate применяется по реально включаемой capability и данным, а не
по максимальному level документа.

## 28. Production quality bar

Этот раздел задаёт release-blocking целевые показатели. Они не описывают
текущее состояние приложения: capability нельзя считать production-ready, пока
для неё не собраны измерения, тестовые доказательства и operational ownership.

### 28.1 Надёжность и сохранность данных

| Область | Обязательный показатель |
|---|---|
| Draft durability | После показанного пользователю подтверждения сохранения RPO = 0: подтверждённая версия draft не теряется при crash, restart, offline или повторном входе. |
| Autosave | Подтверждение локального autosave — p95 ≤ 300 ms; server sync не блокирует редактирование и явно показывает `synced / pending / conflict / failed`. |
| Recovery | Последняя подтверждённая версия и незавершённый PublishAttempt восстанавливаются автоматически; пользователь возвращается к работе не более чем за 30 секунд после запуска приложения. |
| Publish | Повтор одного `idempotencyKey` даёт один business effect; timeout/crash не создаёт duplicate Event, inventory или charge. |
| Inventory | Oversell = 0; hold, confirm, expire, cancel и refund проверяются конкурентными и failure-injection тестами. |
| Payment | Каждый provider event имеет exactly-once business effect поверх at-least-once delivery; расхождения попадают в reconciliation и alerting. |

### 28.2 Производительность и доступность сервиса

| Область | Целевой SLO |
|---|---|
| Открытие Create | Интерактивная форма с доступным локальным draft — p95 ≤ 2 s на поддерживаемом устройстве и типовой production-сети. |
| Step transition | Переход между уже загруженными шагами — p95 ≤ 200 ms без потери фокуса или введённых данных. |
| Publish acknowledgement | Ответ принятия Publish — p95 ≤ 3 s без учёта асинхронной media processing/moderation. |
| Booking decision | Confirm/reject/waitlist result — p95 ≤ 3 s; при неопределённом результате UI не обещает место и безопасно повторяет запрос. |
| Webhook processing | 99% валидных payment/booking webhooks применены или помещены в видимый retry/reconciliation flow не позднее 5 минут. |
| Stability | Crash-free sessions для Create/Booking — ≥ 99.9%; деградация выше error budget блокирует дальнейший rollout. |

Метрики измеряются отдельно по platform, app version, market, Publisher type,
network class и capability; среднее значение не может скрывать провал сегмента.

### 28.3 UX, accessibility и доверие

- все пять шагов полностью доступны с keyboard, screen reader и dynamic text;
- интерфейс и контент соответствуют WCAG 2.2 AA, включая focus order, contrast,
  error association, non-color cues и touch targets;
- Preview проходит visual/contract parity tests с attendee details для каждого
  location, schedule, pricing, booking и visibility mode;
- destructive действия требуют impact preview и не используют dark patterns;
- цена до оплаты показывает currency, налоги, fee, refund/cancellation policy и
  итог; скрытые обязательные платежи запрещены;
- все validation/moderation/provider errors имеют понятное действие для
  восстановления, correlation id и локализованный fallback;
- критический flow покрыт en/ru/lv и корректно работает с pluralization,
  timezone, decimal/currency и длинными строками.

### 28.4 Security, privacy и abuse resistance

- capability и Publisher scope проверяются server-side для каждого mutation;
- access code, join secret, ticket token и webhook secret не попадают в Event,
  analytics, logs, crash reports или clipboard без явного действия;
- raw PAN/CVV никогда не проходят через клиент или backend Recharge;
- PII шифруются in transit/at rest, имеют purpose, retention, export/delete flow
  и least-privilege audit trail;
- rate limits, replay protection, signed webhooks, idempotency и abuse controls
  проверяются threat-model тестами;
- high-risk изменения payout, refund, capacity, access и Publisher ownership
  создают неизменяемую audit event и требуют step-up verification по policy.

### 28.5 Definition of Done для production rollout

Capability считается готовой только когда одновременно выполнено следующее:

1. Все применимые acceptance criteria из раздела 25 и все 43 канонических AC
   Event Classification имеют автоматизированное доказательство или формально
   утверждённый manual test protocol.
2. Domain/application/data/presentation boundaries соблюдены; Event Create
   остаётся config-driven и не создаёт отдельный flow вне form engine.
3. Schema migration, backward/forward compatibility, seed/duplicate и rollback
   проверены на реальных версиях draft и Event contract.
4. Unit, widget, integration, contract, concurrency, offline/recovery,
   accessibility и security tests зелёные; `flutter analyze` и `flutter test`
   проходят без ошибок.
5. Dashboards, SLO/error-budget alerts, audit, reconciliation, dead-letter,
   incident/runbook ownership и customer-support diagnostics готовы до rollout.
6. Feature flag поддерживает staged enable/disable по market и capability без
   потери уже созданных Booking/Payment/Event данных.
7. ADR, PSP, security, privacy, moderation и legal gates из раздела 27 закрыты
   для реально включаемого scope.
8. Product, Design, Engineering, QA, Security, Legal и Operations подписали
   release checklist; открытый P0/P1 дефект блокирует rollout.

## 29. История документа

| Версия | Дата | Изменения |
|---|---|---|
| 1.4 | 2026-08-05 | ECL-00 reconciliation с Accepted Event Classification v2.2.3: добавлены archetype/participation UX, независимые admission axes, price knowledge, inventory authority/shapes/channel, availability/Discover projections, shared PublisherRef и provider authority; target schema/form config и roadmap согласованы с ECL-01–08; `EventCreateBlock` закреплён presentation-only. Runtime этим обновлением не меняется. |
| 0.1 | 2026-07-18 | Первоначальная полная логика Event create flow. |
| 0.2 | 2026-07-18 | Повторный аудит по ADR/VISION/runtime: добавлена карта текущего и целевого состояния; MVP booking ограничен `externalBookingUrl`; разделены lifecycle/moderation/visibility; уточнены online access, Publisher permissions, recurrence ids/deadlines, Money model, analytics taxonomy, feature flags и acceptance criteria. |
| 0.3 | 2026-07-18 | Финальный двойной аудит: deadline перенесён в Registration; capacity согласована с Accepted time-fit contract; добавлены availability invariants, безопасный seed/duplicate, deterministic recurrence/DST, persisted publish attempt и crash recovery; устранены дубли полей semantic contract. |
| 1.0 | 2026-07-18 | Scope переведён с MVP на полноценный production product: unrestricted recurrence/multi-date/overrides, internal/external Booking, tickets/inventory/waitlist/check-in, PSP payments/refunds, public/unlisted/private access, protected online access и risk-based revision policy. |
| 1.1 | 2026-07-18 | Документ доведён до статуса Ready for approval: зафиксированы product promise, UX-принципы, 44 сквозных acceptance criteria и измеримый production quality bar для reliability, performance, accessibility, security, privacy и release readiness. |
| 1.2 | 2026-07-19 | Промежуточный consistency audit: добавлены rollout tiers, pricing compatibility, deadline/donation уточнения, draft threshold и traceability; версия отправлена на архитектурную проверку. |
| 1.3 | 2026-07-19 | Финальный аудит: роли возвращены к `User / Creator / Admin`; capability levels отделены от infrastructure readiness и implementation authorization; исправлены gate mappings; pricing, registration и payment collection разделены; draft threshold сделан soft; contracts приведены к `packages/api_contracts` и frozen feature boundaries. |
