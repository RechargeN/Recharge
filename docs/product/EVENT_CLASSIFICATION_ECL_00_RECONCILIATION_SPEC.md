# ECL-00 — Event Classification canonical reconciliation contract

- Версия: 1.2
- Дата: 2026-08-05
- Статус: **Done — docs alignment и repository gate завершены**
- Parent canon:
  [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md), Accepted
  v2.2.3
- Coverage evidence:
  [EVENT_CLASSIFICATION_COVERAGE_MATRIX.md](EVENT_CLASSIFICATION_COVERAGE_MATRIX.md)

## 1. Решение ECL-00

Recharge принимает Event Classification v2.2.3 как канонический
product/domain контракт classification, admission, inventory, provider,
availability и Event boundaries. `EVENT_CREATE_SPEC.md` остаётся источником
Creator UX/form flow, но не может задавать альтернативную доменную семантику.
EVT-CRT-01 остаётся валидным реализованным C0 + schedule-C1 baseline.

ECL-00 является исключительно reconciliation/documentation slice:

- runtime, persisted JSON, UI, DI и API contracts не меняются;
- существующие draft не мигрируются и не перезаписываются;
- наличие целевого поля в документах не включает capability;
- ECL-01–08 начинаются только по собственному Approved scope;
- Accepted ADR всегда выше этого документа.

## 2. Scope

### 2.1 Входит

1. Фактическая canon → runtime/test coverage matrix по всем 43 AC.
2. Единый словарь ownership и приоритета полей.
3. Решения по конфликтам Classification ↔ Event Create ↔ legacy runtime.
4. Additive migration contract и обязательные rollback свойства.
5. Архитектурные границы presentation/application/domain/data.
6. Зависимости и gates для ECL-01–08.
7. Тестовый contract, который каждый следующий slice обязан расширять.

### 2.2 Не входит

- изменение `event_create_block.dart` или Dart runtime;
- добавление enums/value objects/mappers;
- изменение schemaVersion;
- миграция legacy drafts/templates/events;
- Booking, inventory mutation, waitlist, attendance, Payments;
- provider connector/sync/scraping;
- Publisher backend authority, Firebase или production API;
- Program Items/seating;
- новый Create-тип или Announcement.

## 3. Иерархия контрактов

| Область | Источник истины | Правило |
|---|---|---|
| Architecture/identity/lifecycle/security | Accepted ADR | Всегда выше product/slice spec |
| Event classification/admission/inventory/provider semantics | `EVENT_CLASSIFICATION_SPEC.md` v2.2.3 | Канон для новых ECL slices |
| Creator UX, 5-step flow, publish/edit behavior | `EVENT_CREATE_SPEC.md` | Применяется, пока не конфликтует с Classification/ADR |
| Реализованный local/mock baseline | `EVENT_CREATE_CORE_SCHEDULE_SLICE_SPEC.md` | Честное подмножество, не полный canon |
| Theme taxonomy | `CATEGORY_SYSTEM.md` v1.4.3 | Не дублируется Event enum-ом |
| Identity/Publisher | ADR 0015–0017 + `IDENTITY_PUBLISHER_SLICE_SPEC.md` | Один shared PublisherRef и capability/scope checks |
| DTO/API clients | `packages/api_contracts` | Обязателен до production integration |

При конфликте slice останавливается. Нельзя «временно» вводить второй enum,
дублирующее поле или параллельную Event модель в presentation/sectionData.

## 4. Обязательные reconciliation decisions

### R-01 — Archetype не равен legacy `eventType`

`eventArchetype` — закрытый versioned enum из 34 значений. Текущий
`CreateDraftEntity.eventType: String` не переименовывается и не считается
каноническим автоматически. ECL-01 обязан:

- добавить typed поле в Event domain;
- читать legacy value только как migration input;
- формировать deterministic **suggestion**, а не silent persisted decision;
- требовать подтверждение Creator перед material publish revision;
- не выводить из archetype category, admission или pricing.

### R-02 — Category остаётся общей таксономией

Event использует ID Category System v1.4.3. ECL-01 не копирует 28/530 в Event
enum. Validator должен проверять canonical IDs и сохранять documented legacy
read aliases. Отдельный contract test доказывает применимость всех 27
предметных групп и `other` к Event без автоматического выбора aggregate.

### R-03 — Один shared PublisherRef

Нельзя добавлять второй Event-only Publisher class. Требуется shared domain
contract `{type: user|page, id}` согласно ADR 0015 и IDP-04A. Новый draft
получает default только из active workspace; существующий draft никогда не
переписывается при workspace switch. Legacy organizer name/email/profile
остаются display/contact migration data, но не authority.

ECL-01 publish readiness, зависящая от PublisherRef, блокируется до готовности
shared Publisher default/capability contract. UI preview не является
authority.

### R-04 — Admission decomposes; legacy booleans не повышаются

`registrationRequired`, `approvalRequired`, `waitlistEnabled` и `bookingLink`
не образуют канонический admission contract. Цель:

```text
admissionMode
registrationMode
confirmationMode
eligibilityRules
guestPolicy
waitlistPolicy
onsiteAdmissionPolicy
interestPolicy
attendancePolicy
```

Legacy mapping используется только как явный compatibility adapter с
warning/confirmation при неоднозначности. `bookingLink` может дать один
`externalBookingUrl`; он не создаёт internal Booking, confirmation либо
inventory authority.

### R-05 — Pricing, payment и knowledge независимы

Текущие free/fixed + minor-unit Money сохраняются как baseline. ECL не
использует legacy `isFree`/`double basePrice` как новый источник истины.
`unknown` external price не нормализуется в free. Deposit/membership/display
modifier не становятся pricing modes. Internal money flows остаются ECL-07.

### R-06 — Capacity configuration не равна inventory

`capacityMode/capacity` описывает declared limit, но не создаёт ledger.
`currentParticipants` не вводится Creator и не проецируется как достоверный
ноль без Booking/provider authority. Inventory authority, shapes, pools и
channel binding вводятся отдельно; UI calculations не резервируют места.

### R-07 — Availability является projection

`available/lowAvailability/soldOut/waitlistAvailable/registrationClosed/
cancelled/unknown/stale` не добавляются в Event lifecycle. До authoritative
source mock projection обязана быть явно local/demo и не превращать unknown в
available. `discoverEligible` также отдельная projection.

### R-08 — Occurrence остаётся identity boundary

Существующие stable occurrence IDs и atomic replacement сохраняются.
Booking/inventory для multi-date/series всегда ссылаются на occurrence ID.
ECL-01 не вкладывает Booking в occurrence/draft. Occurrence status,
reschedule revision и moderation добавляются отдельным bounded scope.

### R-09 — Event/Create aggregate boundaries fail closed

§1.2 Classification нормативен, §6.2 только поясняет. ECL-01 добавляет
table-driven boundary tests. Route связывается только `routeRef`; Program
Item не становится Scenario stop; без occurrence Event не публикуется;
Announcement не создаётся.

### R-10 — Provider fields имеют field authority

Provider-owned schedule/price/inventory/seat/booking/refund fields нельзя
редактировать Recharge overlay. Пока ECL-04/05 не готовы, таких operational
полей в runtime нет. Provider refs, freshness и provenance не кладутся в
`sectionData` как свободный обход schema.

### R-11 — Templates требуют явного ECL allowlist

Текущий sanitizer корректно удаляет instance data, URLs, Publisher/organizer,
occurrences, media metadata, lifecycle и unknown fields. При ECL-01 каждое
новое поле классифицируется:

- reusable: archetype, participation, non-sensitive presets/facets;
- instance-bound: occurrence/deadline/provider freshness;
- authority-bound: PublisherRef/capabilities;
- secret/sensitive: всегда strip/reference-only.

Unknown fields продолжают удаляться из template snapshots: это security
boundary, а не нарушение Event mapper forward compatibility.

### R-12 — Presentation остаётся renderer

`event_create_block.dart` не содержит validation, inventory calculations,
Booking lifecycle, provider sync, migration или persistence. Целевая форма:

```text
EventCreateBlock
  -> reads EventCreateViewState + declarative section configs
  -> renders reusable/typed section widgets
  -> emits typed controller commands

Event application controller/coordinator
  -> orchestration, commands, autosave/readiness

Event domain
  -> entities, value objects, normalization, validation, use cases

Event data
  -> mapper, repository implementations, datasources, adapters
```

ECL-01 не добавляет 34 ветки archetype в widget. Archetype-specific
видимость/requiredness вычисляется config/rule engine в application/domain и
передаётся presentation как typed section state.

## 5. Конфликты с текущим Event Create и их разрешение

| Текущий контракт/поле | Конфликт | Решение |
|---|---|---|
| `eventType: String` | Не 34 archetype enum | Legacy input only; typed suggestion + Creator confirmation |
| `organizerId/name/...` | Organizer смешан с publisher/contacts | Shared PublisherRef authority; display/contact отдельно |
| `registrationMode` без admission/confirmation | Недостаточно для канона | Additive independent axes; no inference beyond explicit adapter |
| `approvalRequired` | Boolean не выражает instant/manual/lottery/provider | Не переносить молча; map only when unambiguous |
| `waitlistEnabled` | Нет policy/hold/finite inventory | Не включать до ECL-03; legacy false не объявлять support |
| `bookingLink` | Смешивает handoff semantics | Единственный compatibility map в `externalBookingUrl` |
| `currentParticipants=0` | Ноль выглядит авторитетным | Public projection nullable/unknown до authority |
| `pricingModel: String` | Смешение enum/display legacy | Typed pricing model in ECL-02; legacy adapter only |
| `double basePrice` | Не canonical Money | Event Money minor units остаётся source; legacy projection временная |
| `capacityMode/capacity` | Может быть ошибочно принят за inventory | Configuration only; separate authority/shape/pools |
| future Event enum values | Enum наличие выглядит capability | Validator/readiness/feature flags остаются fail closed |
| `unknownFields` | Возможна потеря при migration/template | Event mapper round-trip; template sanitizer intentionally strips |
| 5 step configs + widget `if` | Не полноценный declarative engine | Typed section definitions/state; split presentation widgets |
| no Event API contracts | Production model некуда публиковать | Versioned `api_contracts` до backend slices |
| no Discover projection | AC 7/34/40 неполны | Separate projection contract before marking those AC Done |

## 6. Обязательная вторая документальная фаза ECL-00

Исходная версия `EVENT_CREATE_SPEC.md` не содержала `eventArchetype`,
`participationModes`, `admissionMode`, `confirmationMode`, inventory authority,
channel-bound pools, price knowledge, Discover eligibility и другие
канонические оси. В docs-only фазе 2026-08-05 parent UX spec обновлён до v1.4
без runtime/schema/API изменений.

Выполнено:

1. В §0/§4 закрепить приоритет Event Classification для classification,
   admission, inventory, provider и availability semantics.
2. В Step 1 добавить progressive archetype/participation UX, не выводящий
   автоматически Category или access.
3. В Step 4 заменить трехрежимное описание registration на независимые
   admission/registration/confirmation/policy оси и отделить interest RSVP.
4. Развести capacity configuration, inventory authority/shapes/pools/channel
   и availability projection; удалить двусмысленность `currentParticipants=0`.
5. Добавить external `priceKnowledge`, provider field authority/freshness и
   explicit unknown/stale presentation.
6. Дополнить target Event draft schema ссылками на PublisherRef,
   classification, admission/inventory configs, provenance и Program Items,
   не вкладывая Booking/Payment records.
7. Согласовать publish/edit/Discover правила future occurrences, material
   revision и moderation before return.
8. Добавить ссылки на deferred IDs `EVT-ANN-01`, `EVT-TRUST-01`,
   `EVT-PAY-01`, не расширяя Create/runtime scope.
9. Добавить cross-references к ECL-01–08 и обновить Event Create AC только
   как product targets с capability/gate labels.
10. После этого обновить `LAUNCH_STATUS.md` и `AGENTS.md` отдельным точным
    status-only diff, не объявляя ECL-01 runtime реализованным.

Пункты 1–9 внесены в `EVENT_CREATE_SPEC.md` v1.4. Пункт 10 отражён в status
files. Repository gate завершён: analyzer — 0 issues, полный Flutter suite —
590 passed. Runtime ECL-01 этим не разрешается.

## 7. Additive schema and migration contract

### 7.1 Read path

1. Сначала определить source schemaVersion.
2. Known legacy fields читать текущими безопасными defaults.
3. Unknown future fields сохранять byte/semantic-equivalent round-trip, пока
   runtime способен интерпретировать container.
4. Unsupported newer Event schema не публиковать после downgrade.
5. Legacy archetype/category/admission mapping возвращает suggestion +
   confidence/reason, но не выполняет write.
6. `capacity<=0` нормализовать в unknown только в compatibility projection.
7. Workspace switch никогда не участвует в migration existing draft.

### 7.2 Write path

- Новый ECL field записывается только после явного user command либо
  deterministic system materialization, разрешённой slice spec.
- Новая material revision требует заполнить новые обязательные поля.
- Autosave не должен сам подтверждать migration suggestion.
- Schema bump атомарен вместе с новыми typed fields.
- Duplicate legacy и canonical fields получают один documented owner и
  projection direction; dual-write не может быть бессрочным.
- Published permanent IDs остаются stable; `loc_*` заменяются атомарно.

### 7.3 Template migration

Template schema version независим от Event draft schema. Materialization
всегда создаёт новый draft ID, новый Publisher default и новые occurrence IDs.
Перед schema bump required tests доказывают reusable/stripped ECL allowlist.

### 7.4 Downgrade/rollback

- raw versioned ECL fields не удаляются;
- старый runtime не объявляет unknown price/capacity/availability свободными;
- classification UI flag не отключает чтение/round-trip данных;
- rollback не меняет PublisherRef и не откатывает permanent IDs;
- provider kill switch даёт stale/unknown и сохраняет refs;
- Booking/Payment/Attendance obligations никогда не удаляются rollback-ом.

## 8. Delivery sequence и зависимости

| Slice | Разрешённый результат | Обязательные зависимости/gates |
|---|---|---|
| ECL-00 | Matrix + reconciliation, no runtime | Accepted v2.2.3; docs review |
| ECL-01 | Local archetype/participation/schema/migration/form sections | Approved ECL-01; shared PublisherRef decision; taxonomy contract tests; no backend |
| ECL-02 | Local admission/inventory config + honest mock projection | Approved ECL-02; ECL-01; no real Booking |
| ECL-03 | Internal free Booking/ledger/waitlist/reconfirmation/cap | Separate production/backend Approved spec; authoritative transactions; notifications; kill switch |
| ECL-04 | External provider handoff | Provider ADR, legal/commercial contract, backend secrets/OAuth, safe-link policy |
| ECL-05 | Provider mirror/sync | Verified webhooks/polling, idempotency, provenance, freshness, reconciliation |
| ECL-06 | Program Items | Stable venue refs and child-boundary contract |
| ECL-07 | Internal paid tickets | Payments/KYC/KYB/PSP/refund/payout Approved scope |
| ECL-08 | Assigned seating presentation | Approved provider hold API; no local seating editor |

Cross-cutting blockers that must not be hidden inside Event presentation:

- shared PublisherRef/default for all 10 Create types is still an IDP-04A
  dependency;
- `packages/api_contracts` contains no Event contracts;
- localization en/ru/lv is not configured;
- Discover has no canonical Event availability/discoverEligible projection;
- production Firebase/auth/provider authority remains outside stabilization
  exceptions.

## 9. Required ECL test contract

### 9.1 ECL-01 minimum

1. 34 archetypes round-trip and unknown enum values fail closed.
2. Exactly one archetype; one primary + at most 3 unique secondary
   participation modes.
3. Archetype never mutates category/admission/pricing.
4. All §1.2 boundary cases are table-driven; §6.2 cannot override them.
5. Category registry IDs/aliases validate; all groups are Event-applicable.
6. Legacy suggestion does not write until explicit confirmation.
7. Existing schema v1 draft round-trips without data loss.
8. Newer schema/downgrade preserves raw fields and blocks unsafe publish.
9. PublisherRef defaults new draft only; workspace switch preserves existing.
10. Templates retain reusable classification and strip authority/instance/
    unknown/secret data.
11. Declarative section visibility is tested without widget business logic.
12. Widget 360 dp + 150% text scale, keyboard/screen-reader labels and
    not-color-only errors.

### 9.2 Cumulative AC ledger

Каждый ECL slice обновляет отдельную machine-readable или table-driven mapping
`canonical AC -> test name -> layer -> status`. AC нельзя пометить Done по
одному widget snapshot либо существованию enum. Для ECL-03/05/07 обязательны
concurrency, idempotency, authority, retry/reconciliation и kill-switch tests.

### 9.3 Repository gates

Для каждого runtime slice обязательны:

- `flutter analyze` из `apps/mobile` — 0 ошибок;
- полный `flutter test` — green;
- architecture boundary check;
- diff/generated-file check;
- targeted migration/mapper/domain/application/widget suites;
- 360 dp / 150% accessibility gate для изменённого UI.

## 10. Observability, privacy и security contract

- Analytics использует enum IDs и coarse reason codes, не descriptions,
  access codes, join links, attendee PII или provider secrets.
- Migration telemetry сообщает source/target version, suggestion outcome и
  error code без draft content.
- External URL disclosure показывает домен; secret links выдаются только
  через protected reference после confirmed access.
- Provider callbacks/lookup являются backend responsibility.
- No scraping, silent fuzzy merge, client authority или hidden capability.

## 11. Rollout и rollback ECL-01+

Независимые flags минимум:

```text
event_classification_ui
event_admission_configuration
event_mock_availability
event_internal_booking
event_external_provider
event_program_items
event_internal_payments
event_assigned_seating
```

Flag выключает entry point/behavior, но не mapper compatibility. Rollout:
internal fixtures → opted-in local demo → bounded market cohort → wider
release только после slice gates. Rollback reason и version фиксируются;
данные не очищаются автоматически.

## 12. Acceptance criteria ECL-00

1. Accepted v2.2.3 прочитан из repository file и идентифицирован hash-ом.
2. Матрица покрывает все канонические блоки и все AC 1–43.
3. Implemented/partial/missing/gated не смешиваются.
4. EVT-CRT-01 признан валидным baseline без ложного заявления full coverage.
5. Все legacy semantic conflicts имеют одно reconciliation решение.
6. PublisherRef, Category, occurrence и aggregate boundaries согласованы с
   Accepted ADR и repository instructions.
7. `EventCreateBlock` закреплён как presentation renderer, не business layer.
8. Migration additive, explicit, forward-compatible и rollback-safe.
9. ECL-01–08 имеют зависимости и запрещённые shortcuts.
10. ECL-00 не изменяет Dart/runtime/tests/API schema/persisted data.
11. Документ не объявляет ECL-01 Approved и не включает production capability.
12. Документальные ссылки и repository gates проверены перед Done.

## 13. Definition of Done

ECL-00 завершён:

- reconciliation decisions R-01–R-12 согласованы с Accepted canon/ADR;
- `EVENT_CREATE_SPEC.md` v1.4 обновлён без runtime/schema/API changes;
- coverage matrix содержит все AC 1–43;
- ссылки, fences, AC sequence, whitespace и scoped diff проверены;
- `flutter analyze --no-pub` завершён с 0 issues;
- полный `flutter test --no-pub` завершён: 590 passed;
- boundary check прошёл с 59 существующими allowlist suppressions и без нового
  нарушения;
- фактический статус отражён в `LAUNCH_STATUS.md` и `AGENTS.md`.

ECL-01 runtime остаётся запрещён до отдельной Approved ECL-01 slice spec с
собственными bounded scope, migration/rollback, acceptance criteria и gates.
