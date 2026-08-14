# Recharge Backend — Master Specification and Initial Architecture Audit

- ID: **BCK-01**
- Version: **0.3**
- Date: **2026-08-14**
- Spec status: **Draft — architecture review required**
- Runtime status: **Absent**
- Accountable owner: **Platform Architecture owner**
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled independently**
- Runtime effect of this revision: **none**
- Canonical repository path: `docs/product/RECHARGE_BACKEND_MASTER_SPEC.md`
- Link base: all relative links resolve from repository directory
  `docs/product/`, even when a review copy is distributed through Downloads

## 0. Changelog

### v0.3 — 2026-08-14

- повторно проверено фактическое состояние repository: BCK-02 v2.4 существует
  и Approved, Latvia/Baltics roadmap существует как Draft BCK-02-A1, BCK-09
  существует как Review v1.0; runtime всех трёх документов остаётся none/Absent;
- полезные уточнения промежуточной v0.2 перенесены без её ошибочных заявлений
  об отсутствующих документах: добавлены AGENTS/LAUNCH_STATUS, ADR 0016–0018 и
  фактическое local/mock Identity/Event groundwork;
- source priority заменён scope-aware reconciliation contract: repository
  instructions, architecture decisions, implementation status и delivery
  coordination больше не образуют ложную единую лестницу;
- authoritative ownership дополнен import, privacy orchestration, server flags,
  provider, AI и условным Payments authority;
- target `packages/api_contracts` сохраняет фактический `schema/<domain>/vN`
  layout; необоснованная миграция `schema/` → `schemas/` запрещена;
- gated AI/provider directories исключены из initial scaffold, а Payments
  directory запрещён до отдельного Accepted ADR и Approved slice;
- version-specific формулировки DoD/AC/unimplemented list исправлены на v0.3
  или `current revision`; добавлены AC-46–AC-52;
- runtime effect остаётся none; application/Firebase/backend runtime не создан.

### v0.2 — 2026-08-14 — rejected review copy

- не являлась канонической repository revision;
- ошибочно объявляла существующие BCK-02 v2.4, BCK-02-A1 и BCK-09
  отсутствующими и поэтому не принимается как источник истины;
- полезные изменения перенесены выборочно в v0.3 после повторной проверки.

### v0.1 — 2026-08-14

- выполнен первичный аудит repository/backend readiness;
- зафиксирована модель одного логического backend Recharge без создания
  монолитного domain-модуля;
- определены обязательные архитектурные слои, bounded modules и направления
  зависимостей;
- описаны target file map, authoritative ownership, data/projection boundaries,
  cross-cutting invariants и документационные пакеты;
- отделены принятые решения от открытых OD и от будущего runtime;
- сформированы Definition of Ready, Definition of Done и последовательные AC.

## 1. Verdict

Recharge нужен **один backend продукта**, но его нельзя реализовывать как один
неразделённый файл, одну Cloud Function, одну коллекцию или один универсальный
service.

Целевая модель:

```text
одна backend-платформа Recharge
  + одна identity/capability authority
  + один PublisherRef contract
  + один API/error/idempotency standard
  + один environment/security/operations baseline
  + один writer для каждого authoritative record type
  + изолированные bounded domain modules
  + отдельно построенные read projections
  + independently gated entrypoints/workers
```

На начальном масштабе Латвии и подготовке Балтии это должен быть **модульный
backend application на Firebase/GCP**, а не набор преждевременно выделенных
микросервисов. Модули разделяются контрактами, ownership и CI boundaries;
transport entrypoints и workers могут развёртываться независимо. Выделение
модуля в отдельный сервис допускается позднее только по измеримым причинам:
отдельный scaling profile, security boundary, availability objective,
ownership или cost profile — и только через новый Accepted ADR.

Нужен также не один гигантский документ, а система документации:

1. этот BCK-01 задаёт общую конструкцию и инварианты;
2. BCK-03–BCK-22 детализируют cross-cutting и domain-контракты;
3. RUN-01–RUN-06 описывают эксплуатацию фактически реализованной topology;
4. bounded executable slice разрешает конкретный runtime-код;
5. gates отдельно разрешают Emulator, staging, production cohort и GA.

## 2. Назначение и результат

BCK-01 отвечает на пять вопросов:

1. что именно считается единым backend Recharge;
2. из каких слоёв и bounded modules он состоит;
3. кто является authority и единственным writer каждого типа данных;
4. какие документы и решения обязательны до физической реализации;
5. как последовательно перейти от local/mock приложения к Latvia production и
   подготовить EE/LT без параллельных моделей.

После Approval документа команда должна иметь возможность проектировать
BCK-03, BCK-04, BCK-05 и BCK-20 независимо, не расходясь в module boundaries,
identity, IDs, time, money, market, API и ownership semantics.

### 2.1. Измеримый результат BCK-01

- у каждой capability есть ровно один owning module;
- у каждого authoritative record type есть ровно один writer;
- mobile, backend и shared-contract boundaries однозначны;
- Firebase остаётся infrastructure detail за ports, а не domain model;
- LV/EE/LT используют одну модель account/content, но независимые market gates;
- каждый будущий BCK-spec может ссылаться на конкретный раздел и AC этого
  документа;
- никакой runtime не считается разрешённым только из-за существования BCK-01.

## 3. Источники истины и разрешение конфликтов

Источники имеют разные области владения; их нельзя сводить к одной лестнице,
где status-документ случайно меняет архитектуру или coordination map — domain
инвариант.

1. Accepted ADR побеждает при архитектурном конфликте.
2. Approved spec текущего domain/runtime slice побеждает внутри своего bounded
   scope, если не противоречит Accepted ADR.
3. [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md) и
   cross-cutting policies владеют module/layer boundaries.
4. [LAUNCH_STATUS](../architecture/LAUNCH_STATUS.md) владеет фактическим
   implementation/runtime status, но не переписывает target architecture.
5. [BCK-02 Backend Delivery Map](RECHARGE_BACKEND_DELIVERY_MAP.md) владеет
   registry, accountable owners, dependencies, waves, OD/risks и gates.
6. Этот BCK-01 владеет shared backend target, layers, module boundaries и
   cross-domain invariants, которых нет в более высоком источнике.
7. Product vision и Draft/Review proposals не переопределяют пункты выше.

[AGENTS.md](../../AGENTS.md) является канонической repository-level
инструкцией для выполнения работы: он определяет активный slice, разрешённые
изменения и обязательные проверки. Это execution authority для coding-agent,
а не параллельный product/architecture spec.

BCK-01 не supersede и не копирует domain flows. Конфликт между BCK-01 и BCK-02
разрешается по ownership: architecture/shared invariants принадлежат BCK-01,
coordination/status sequencing — BCK-02; нерешаемое пересечение блокирует
Approval и требует reconciliation либо Accepted ADR.

### 3.1. Канонические anchors

| Область | Источник | Обязательство BCK-01 |
|---|---|---|
| Repository execution | [AGENTS.md](../../AGENTS.md) | Не расширять активный slice и не считать documentation runtime-разрешением |
| Monorepo и layers | [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md) | Сохранить frozen boundaries; backend target создаётся только разрешённым slice |
| Implementation status | [LAUNCH_STATUS](../architecture/LAUNCH_STATUS.md) | Различать target, docs/contracts, implemented, deployed и enabled evidence |
| Technology defaults | [ADR 0012](../adr/0012-tech-stack-defaults.md) | Не вводить параллельный mobile stack; backend deviations документировать |
| Domain/security policy | [ADR 0013](../adr/0013-domain-policy-baseline.md) | Сохранить IDs, lifecycle, UTC/IANA, privacy, audit с учётом superseding ADR |
| Identity/Publisher | [ADR 0015](../adr/0015-authenticated-viewer-verified-creator-professional-page.md) | Mandatory Auth, verified Creator, exact-page capabilities, PublisherRef |
| Bounded local Identity/workspace | [ADR 0016](../adr/0016-bounded-identity-workspace-during-stabilization.md), [ADR 0017](../adr/0017-admin-experience-preview-and-user-created-pages.md) | Не выдавать local/mock access snapshot, ManagedPage или Admin preview за production authority |
| AI boundary | [ADR 0018](../adr/0018-provider-neutral-ai-assistance-capability.md) | Сохранить horizontal provider-neutral facade; production proxy/provider остаётся gated |
| Booking authority | [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md) | Trusted commands, ledger, online authority, separate aggregates |
| Backend sequencing | [BCK-02 v2.4](RECHARGE_BACKEND_DELIVERY_MAP.md) | Сохранить registry, owners, OD, risks, D/R waves и G0–G7 |
| Baltic rollout | [Latvia/Baltics roadmap](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md) | Latvia-first, EE/LT prepared and disabled independently |
| Firebase target | [Firebase Architecture](../architecture/FIREBASE_ARCHITECTURE.md) | Использовать как Proposed infrastructure input, не как runtime evidence |
| Shared contracts | [API Contracts Workflow](../api/API_CONTRACTS_WORKFLOW.md) | Language-neutral source, fixtures, generated/verified consumers |
| Event/Booking | [Event Classification v2.2.3](EVENT_CLASSIFICATION_SPEC.md), [BCK-09](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md), [ECL-03C plan](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md) | Не создавать вторую Event/Booking модель; BCK-09 до Approval reconciles с exact ECL-03B/C groundwork |
| Scenario | [Scenario Builder](SCENARIO_BUILDER_SPEC.md) | Scenario не равен Route или Quick Plan |
| Route | [Route Builder](ROUTE_BUILDER_SPEC.md) | Route остаётся continuous track/GPX aggregate |

Mobile- и backend-дорожные карты имеют независимые namespaces. Например,
mobile M8 adapter preparation не равен backend R8. Ссылка всегда содержит
префикс документа/track, а не только номер этапа.

## 4. Первичный аудит текущего состояния

Дата снимка: **2026-08-14**.

| Область | Текущее evidence | Gap | Вывод |
|---|---|---|---|
| Mobile app | Flutter, layered features, local/mock datasources | Нет production remote authority | Не считать mock production backend |
| Shared contracts | `packages/api_contracts`, Booking schemas/fixtures/DTO | Нет общего backend API standard BCK-03 | Расширять один workflow, не создавать второй |
| Backend application | `apps/backend` отсутствует | Нет functions, Rules, indexes, tests, deployment | Runtime **Absent** |
| Firebase projects | В repository нет project/options/config evidence | Не приняты topology, edition и locations | OD-07 блокирует provisioning |
| Identity | Target принят ADR 0015; ADR 0016/0017 разрешили bounded local/mock access snapshot, user-created ManagedPage, workspace/capability guards и Admin preview | Нет production Auth/capability/revocation authority; local exception не является production evidence | BCK-06 + BCK-18 до product migration; сохранить compatibility без переноса mock grants |
| Content/Create | 10 типов local/config-driven | Нет trusted publication lifecycle и catalog source | BCK-07, затем BCK-08 |
| Discover | Mock/local projections | Нет rebuildable server projections/search decision | BCK-08 + OD-01/03 |
| Event Booking | ADR 0019 Accepted; BCK-09 Review v1.0; ECL-03B shared schemas/fixtures/mobile domain Done; ECL-03C exact transaction-core plan Review | Нет authoritative transaction runtime | Reconcile BCK-09 после platform set; затем только отдельный Approved ECL-03C runtime slice |
| Media/Notifications | Local/mobile foundations | Нет protected storage pipeline и delivery authority | BCK-13/14 |
| Library/Reviews/T&S | Visit History local-first; reviews backend absent | Нет sync, rating aggregate, report/block/enforcement | BCK-12/22 |
| Planning/Route | Mature local-first capability | Нет cloud sync/publication contracts | BCK-10/11 |
| Operations | Общие CI/env/runbook policies существуют | Нет backend SLO, budgets, IAM, backup/restore evidence | BCK-05 + actual runbooks |
| Privacy | Общий policy baseline | Нет backend data inventory/retention/DSR orchestration | BCK-04 |
| Baltic markets | Roadmap и target MarketConfig определены | Нет versioned backend reference distribution | BCK-20 + OD-10 |

### 4.1. Главный gap

Проблема не в отсутствии ещё одного общего описания Firebase. Главный gap —
отсутствие согласованного **platform contract**, связывающего product domains,
authority, transport, persistence, projections, security, operations и mobile
migration. BCK-01 закрывает этот gap на уровне архитектуры, но не закрывает
runtime gaps из таблицы.

## 5. Scope

### 5.1. Входит

- единая platform boundary для LV/EE/LT;
- слои backend и правила зависимостей;
- bounded modules и их responsibility;
- authoritative ownership и projection ownership;
- shared contracts, IDs, time, money, market и revision semantics;
- baseline для commands, queries, events, idempotency и typed failures;
- security/privacy/operations requirements на уровне master contract;
- target repository map;
- документационные и runtime gates;
- migration/cutover principles;
- acceptance criteria BCK-01.

### 5.2. Не входит

- создание `apps/backend`, Firebase project или cloud resources;
- Functions, Firestore Rules, indexes, Storage Rules или deployment;
- secrets, credentials, production data или real-user processing;
- точные JSON Schemas/API fields отдельных domains;
- UI/mobile runtime changes;
- выбор Search vendor, email provider, analytics destination или resource
  location до соответствующего OD;
- Payments runtime: он требует отдельного Accepted ADR;
- production AI/provider integration;
- подмена BCK-03–BCK-22 этим master-документом.

## 6. Целевая системная граница

```mermaid
flowchart LR
  M["Flutter mobile"] -->|"versioned commands/queries"| T["Transport boundary"]
  A["Admin/support surface"] -->|"privileged commands"| T
  T --> APP["Application use cases"]
  APP --> DOM["Domain policies and aggregates"]
  APP --> PORTS["Domain/application ports"]
  PORTS --> INFRA["Firebase/GCP adapters"]
  INFRA --> AUTH["Auth / App Check"]
  INFRA --> DB["Firestore"]
  INFRA --> OBJ["Storage"]
  APP --> OUT["Transactional outbox"]
  OUT --> W["Idempotent workers"]
  W --> PROJ["Read projections"]
  PROJ --> T
  CONTRACTS["packages/api_contracts"] --> M
  CONTRACTS --> T
```

Mobile не знает Firestore schema и не пишет authoritative collections
напрямую. Backend domain не знает Firebase SDK. Infrastructure реализует ports,
а transport переводит wire contracts в application commands/queries.

## 7. Обязательные архитектурные слои

| Слой | Ответственность | Может зависеть от | Не содержит |
|---|---|---|---|
| Contract/schema | Language-neutral request/response/event schemas, fixtures, compatibility | Только schema tooling | Firebase records, UI models, domain execution |
| Transport/interface | Auth/App Check context, decoding, version negotiation, rate envelope, response mapping | Application, contracts, shared technical adapters | Business policy и direct Firestore mutation |
| Application | Orchestration, use cases, command/query handlers, transaction intent, ports | Domain, contracts | Firebase documents/SDK и presentation logic |
| Domain | Aggregates, value objects, invariants, policies, typed domain outcomes | Pure shared primitives only | Network, Firebase, clocks without port, logging SDK |
| Infrastructure/data | Repository implementations, Firestore/Auth/Storage/provider adapters, transaction runner | Application/domain ports, SDKs | Product decisions, обход use cases |
| Projection/read model | Rebuildable catalog/feed/map/search/availability/inbox views | Accepted domain events/source readers | Authority над source aggregates |
| Effects/workers | Outbox consumption, notifications, expiry, cleanup, projection rebuild/replay | Application commands, accepted event contract | Unbounded retries, direct foreign aggregate writes |
| Platform/operations | Bootstrap, config, flags, IAM, deploy, observability, backups, budgets | Cross-cutting standards | Domain-specific shortcuts |

### 7.1. Dependency rules

1. Dependencies point inward: transport/infrastructure → application → domain.
2. Domain code is deterministic and infrastructure-free.
3. One domain never imports another domain's persistence model.
4. Cross-domain mutations use a typed command owned by the target domain.
5. Cross-domain asynchronous effects use the accepted outbox/event envelope.
6. A projection may compose sources, but cannot mutate or redefine them.
7. Shared code contains primitives and technical policy, not hidden product
   workflows.
8. Firebase document shape never becomes a mobile or domain public contract.
9. Unknown/newer schema or policy revision fails closed when authority,
   money, privacy, eligibility or capacity can be affected.

## 8. Bounded module map

| Module | Owns | Does not own | Detailed spec |
|---|---|---|---|
| Platform foundation | bootstrap, environment config, flags, common telemetry, task/event infrastructure | Product aggregates | BCK-03/04/05 |
| Identity & Publisher | account/session/access snapshot, Creator verification, ManagedPage membership/capabilities, PublisherRef eligibility | Content lifecycle | BCK-06 |
| Reference Data | MarketConfig, taxonomy/region/currency/locale revisions | User content | BCK-20 |
| Privacy Orchestration | DSR/export/deletion request coordination and completion evidence | Silent direct deletion of foreign domain records | BCK-04 |
| Mobile Integration | import sessions, checkpoints, local-to-permanent ID mapping and adapter compatibility | Direct writes to owning aggregates | BCK-18 |
| Content Publication | drafts/import, trusted publish lifecycle, 10 Create-type records, publisher/provenance refs | Search index, Booking ledger | BCK-07 |
| Discover & Catalog | feed/map/search/catalog projections, ranking, freshness, availability composition | Source aggregates and Booking decision | BCK-08 |
| Booking | Booking, hold, inventory ledger, usage, audit, idempotency, Booking outbox | Event content and payment ledger | BCK-09 |
| Planning | Scenario and separate Quick Plan sync/collaboration/publication | Route track | BCK-10 |
| Route | Route/GPX aggregate, track metadata and publication handoff | Scenario/Quick Plan | BCK-11 |
| User Library & Reviews | favorites, explicit Visit History, reviews and rating aggregates | Report/sanction cases | BCK-12 |
| Notifications | inbox/preferences/tokens/delivery attempts | Source domain state | BCK-13 |
| Media | upload/finalize metadata, blob ownership, transforms, protected delivery, cleanup | Content lifecycle | BCK-14 |
| Admin & Support | cases, privileged reads, propose/approve/execute repair workflow | Silent direct record editing | BCK-19 |
| Trust & Safety | reports, block/mute, sanctions, appeals, enforcement evidence | Content storage ownership | BCK-22 |
| Analytics | governed product-event ingestion and datasets | Operational alert source | BCK-21 |
| AI | provider-neutral proxy, redaction, quota and eval metadata | Product aggregate authority | BCK-15, gated |
| Provider Integration | provider adapters, provenance, cache/live-check/handoff | Internal Booking ledger | BCK-16, gated |
| Payments | payment intent/ledger/webhooks/refunds/disputes | Booking inventory ledger | BCK-17, new ADR required |

## 9. Authoritative ownership contract

Основное правило: **один authoritative record type — один writer**.

| Record family | Writer | Разрешённые consumers |
|---|---|---|
| Account/session/access/verification/page membership | Identity | Все modules читают bounded access decisions |
| Market/taxonomy/locale/reference revisions | Reference Data | Все modules хранят stable IDs/revisions |
| Personal Create drafts/import mapping and published content lifecycle | Content Publication | Mobile syncs through port; Discover, Booking config reader, Media links, T&S commands consume bounded projections |
| Search/feed/map/catalog projections | Discover | Mobile queries; source modules не пишут projection напрямую |
| Booking/hold/inventory/usage/idempotency/audit | Booking | Authorized mobile/admin projections, Discover availability reader |
| Provider availability and external booking reference/provenance | Provider Integration | Discover composes honest source/freshness; mobile performs approved handoff/live-check |
| Scenario/Quick Plan | Planning | Content/Discover только через published projection |
| Route/track references | Route | Media stores blobs; Discover reads published projection |
| Favorites/visits/reviews/ratings | User Library & Reviews | Discover reads rating projection |
| Notification delivery state | Notifications | Source domains append accepted outbox only |
| Media metadata/blob lifecycle | Media | Owning domains store protected reference |
| Import session/checkpoint/source-to-permanent-ID mapping | Mobile Integration | Owning domain validates and writes each aggregate through command |
| Reports/sanctions/appeals | Trust & Safety | Domains accept typed enforcement commands |
| Repair cases/execution audit | Admin & Support | Owning domain executes approved repair command |
| Privacy request/deletion orchestration | Privacy Orchestration | Domain-owned handlers execute scoped export/deletion work |
| Server flags/kill switches | Platform Operations | Domains read current server decision before mutation |
| Operational metrics/logs | Platform Operations | Operators and alerts |
| Product analytics records | Analytics | Governed analytics consumers |
| AI request/quota/evaluation metadata | AI Platform | Product domains consume provider-neutral facade only after BCK-15 gate |
| Payment intent/ledger/webhook/refund/dispute state | Payments | Conditional authority only after new Accepted ADR, BCK-17 and Approved executable slice |

Никакой consumer не получает write authority только потому, что ему удобно
денормализовать данные. Денормализация создаёт rebuildable projection с
отдельным revision/freshness, а не второй источник истины.

## 10. Commands, queries, events и errors

### 10.1. Commands

Каждая mutation:

- проходит trusted backend boundary;
- содержит actor/session context, immutable request ID и contract version;
- проверяет capability, scope, market policy и current resource revision;
- исполняется owning application use case;
- возвращает typed outcome и authoritative server timestamp;
- не сообщает успех до durable commit;
- при неизвестном результате допускает повтор только с тем же idempotency key.

### 10.2. Queries

Query contract содержит достаточный context: actor visibility, market/service
area, filters, cursor, projection revision и freshness. Cursor opaque и
привязан к query/version. Query не выдаёт private/protected fields через public
projection.

Discover feed/map/search одного логического query используют общую query
revision/freshness contract. Допустимые различия — viewport, clustering,
ranking window и pagination. Несогласованность обозначается typed
`stale/inconsistent_projection`, а не скрывается как нормальный результат.

### 10.3. Events/outbox

Cross-domain event:

- создаётся после/вместе с authoritative transition согласно transaction
  contract;
- имеет stable event ID, type, schema version, aggregate ID/revision,
  occurredAt, correlation/causation и minimized payload;
- доставляется at-least-once, поэтому consumer обязан deduplicate;
- допускает bounded replay и poison-message handling;
- не является разрешением чужому module напрямую менять source aggregate.

Точный envelope, ordering и retention закрывает OD-09/BCK-03/BCK-05.

### 10.4. Typed outcomes

Обязательные cross-cutting категории:

```text
success
cancelled
invalid_argument
unauthenticated
permission_denied
not_found
conflict
idempotency_conflict
failed_precondition
rate_limited
unavailable
deadline_exceeded
unsupported_client
unsupported_schema
stale_revision
internal
```

`cancelled` — отдельный non-success outcome, а не infrastructure failure.
Domain specs добавляют коды, но не меняют семантику общих категорий. Raw SDK
exceptions и stack traces не пересекают API boundary.

### 10.5. Contract evolution и minimum client

- каждый request, response, event и persisted policy имеет явную version или
  revision;
- additive optional field допустим только при доказанной backward/forward
  compatibility;
- удаление, переименование, изменение типа или семантики поля требует новой
  major contract version и migration window;
- enum имеет documented unknown-value behavior; для authority/security/money/
  eligibility/capacity неизвестное значение fail-closed;
- server публикует minimum supported client/build policy и typed
  `unsupported_client`, а не ломает старый client неструктурированной ошибкой;
- deprecation содержит owner, announce date, last-supported date, telemetry и
  rollback;
- source schemas и compatibility fixtures предшествуют generated/verified Dart
  и TypeScript consumers;
- persisted schema migration и public API evolution — разные процессы и не
  получают общий version counter автоматически;
- exact envelope, compatibility window и codegen mechanics принадлежат BCK-03.

## 11. Shared data semantics

### 11.1. IDs и references

- persistent entities используют immutable ULID/UUID;
- `loc_*` допустим только для несохранённого local draft;
- authoritative create/import выдаёт permanent ID и explicit mapping;
- связи выполняются по ID, никогда по display name;
- PublisherRef имеет форму `{type: user | page, id}`;
- event occurrence, inventory pool, media и policy revision имеют собственные
  stable IDs.

### 11.2. Time

- authoritative timestamps — UTC instant с backend time;
- локальная календарная семантика хранит IANA timezone объекта/occurrence;
- timezone устройства не меняет persisted business date;
- Visit History date интерпретируется в IANA-зоне Place;
- DST overlap/gap имеет явную validation policy в domain spec.

### 11.3. Money

- wire/persistence money — integer minor units + ISO 4217 currency;
- floating-point `double` запрещён на authoritative границах;
- currency не выводится из market, даже когда LV/EE/LT используют EUR;
- rounding и maximum bounds задаются versioned policy;
- mobile Money migration должна завершиться до production remote adapter,
  чтобы boundary не выполнял тихую double-конверсию.

### 11.4. Market и localization

`market`, `country`, `locale`, `currency`, `environment` и `timezone` — разные
понятия. Target использует versioned MarketConfig и reference revisions.

| Market | Currency | Initial locales | Default IANA zone | Initial activation |
|---|---|---|---|---|
| Latvia | EUR | `lv-LV`, `en`, `ru` | `Europe/Riga` | First cohort/GA |
| Estonia | EUR | `et-EE`, `en`; `ru` by approved policy | `Europe/Tallinn` | Prepared, server-disabled |
| Lithuania | EUR | `lt-LT`, `en`; additions by policy | `Europe/Vilnius` | Prepared, server-disabled |

Точные LocalizedText/fallback/revision semantics принадлежат BCK-20/OD-10.

## 12. Data classes и projections

Каждый BCK-spec классифицирует record/field до schema approval:

| Class | Примеры | Базовое обращение |
|---|---|---|
| Public | Published title, public geo/category, approved publisher snapshot | Только через sanitized public projection |
| Protected | User Booking, private Scenario, page membership, precise private location | Actor/scope authorization required |
| Sensitive | Verification evidence, access code, support evidence, abuse report | Minimized, encrypted/service-restricted, never public |
| Operational | Idempotency, lease, outbox, job state, audit | Backend-only except bounded admin projection |
| Derived | Search index, availability/rating counters, feed/map projection | Rebuildable, revisioned, freshness-labelled |

Для каждого record family BCK-04 и owning spec фиксируют purpose, legal basis,
access, retention, export/deletion behavior, backup treatment и log/analytics
exclusions. Наличие Firestore collection не является data inventory.

## 13. Security, privacy и abuse baseline

1. Firebase Auth подтверждает session identity, но capability решает backend.
2. Creator verification, page membership и grants server-owned и revocable.
3. App Check — дополнительный signal, не замена AuthZ/rate/abuse controls.
4. Firestore/Storage Rules deny direct authoritative writes и cross-user/scope
   reads.
5. Privileged operations используют least-privilege service identities.
6. Production secrets живут только в approved secret manager/CI context.
7. Logs, analytics, events и errors проходят redaction/minimization.
8. Rate limits учитывают actor, device/app signal, command risk и global abuse
   protection; exact thresholds принадлежат domain/security specs.
9. Admin access audited; repair использует propose/approve/execute и не обходит
   owning domain invariant.
10. Account deletion/DSR координируется BCK-04, а domain handlers удаляют или
    анонимизируют только собственные records согласно approved policy.
11. OD-11-gated minors/age-sensitive functions остаются server-disabled и
    fail-closed до Accepted market-specific policy.
12. Client guards улучшают UX, но не дают authority.

### 13.1. Master authorization matrix

| Principal/context | Базово разрешено | Всегда требуется дополнительно | Запрещено |
|---|---|---|---|
| No valid session | Auth bootstrap only | Approved provider flow | Product queries, profile, mutation |
| Authenticated active User | Authorized consumer reads; own library/profile commands | Exact actor/resource checks | Creator/page/admin authority |
| Verified Creator personal context | Personal create/submit/publish where capability exists | Active account, verification, type/action capability, lifecycle | Page publication without membership |
| ManagedPage member | Exact-page actions in granted scope | Active membership, exact page ID, page capability, market eligibility | Cross-page access or global grant |
| Admin/support principal | Explicit tool/case action only | Dedicated capability, reason/case, audit; two-person repair where required | Publisher/workspace impersonation and silent direct writes |
| Service identity/worker | Exact scheduled/event task | Least-privilege IAM, accepted event/lease/idempotency contract | General user/domain access outside task |

Revocation applies fail-closed. Every authoritative mutation evaluates current
server-owned access; a stale mobile role/workspace snapshot never authorizes
the command. Long-running/retry work records initiating actor and policy
revision, but re-evaluates the revocation rules defined by the owning spec
before any new privileged effect. Session, verification, membership, capability
or market suspension invalidates affected cached access and produces a typed
outcome without leaking whether an inaccessible resource exists.

## 14. Persistence и transaction boundaries

- Firestore — target durable store, но collection/index topology фиксируется
  owning spec и BCK-05 после OD-07;
- aggregate transaction принадлежит одному module;
- multi-record invariant изменяется атомарно либо через documented saga с
  compensating/reconciliation contract;
- direct cross-module Firestore writes запрещены;
- large blobs принадлежат Storage, Firestore хранит governed metadata/ref;
- counters являются authority только если owning domain прямо определил
  transaction invariant; иначе это derived projection;
- audit immutable и append-only в пределах retention policy;
- every retryable worker lease-protected, idempotent и bounded;
- backups не заменяют domain reconciliation и restore tests.

Booking сохраняет более строгие правила ADR 0019: ledger, usage, hold,
idempotency, audit и outbox обновляются в принятой authoritative transaction;
last-write-wins недопустим.

## 15. Offline, cache и degraded states

Client state типизирован как минимум:

```text
local | cache | server | stale | unavailable | unsupported
```

- local draft не является published server record;
- cached projection показывает source revision/fetchedAt/expiresAt, где это
  влияет на решение пользователя;
- offline mutation не создаёт authoritative Booking/payment/publication result;
- network timeout mutation означает unknown/recoverable outcome; retry сохраняет
  request ID;
- newer/unknown critical contract не silently downgrades;
- server feature flag определяет доступность authoritative action;
- degraded mode сохраняет cancellation/release/safety paths, определённые
  owning spec, и блокирует рискованные новые mutations.

## 16. Migration local/mock → backend

Migration выполняется по capability/domain, не одним bulk upload:

1. инвентаризация local schemas и owner namespaces;
2. классификация `importable | local-only | demo-seed | stale | corrupt`;
3. принятие OD-04/OD-08 и owning import contract;
4. dry-run identity/publisher/ID/schema mapping;
5. explicit user disclosure/consent, когда требуется;
6. import session с checkpoint, source revision и idempotency key;
7. каждый record проходит command owning domain;
8. conflict/duplicate возвращает typed result;
9. partial failure resumable;
10. rollback затрагивает только imported mutable state, не стирая lawful audit;
11. demo/mock records никогда не становятся production user claims;
12. mobile adapter переключается feature-by-feature с server kill switch и
    обратимым fallback там, где fallback не создаёт ложную authority.

Production mobile presentation/application/domain не импортируют Firebase SDK
или Firestore schemas. BCK-18 определяет adapters и cutover evidence.

## 17. Target repository map

Следующая структура является **target plan**, а не разрешением создать файлы:

```text
apps/backend/
  firebase.json
  .firebaserc.example
  firestore.rules
  firestore.indexes.json
  storage.rules
  functions/
    package.json
    tsconfig.json
    src/
      bootstrap/
        app.ts
        config.ts
        composition_root.ts
      shared/
        auth/
        contracts/
        errors/
        ids/
        money/
        time/
        transactions/
        observability/
        flags/
      modules/
        identity/
        reference_data/
        content/
        discover/
        booking/
        planning/
        route/
        library_reviews/
        notifications/
        media/
        admin_support/
        trust_safety/
        analytics/
      transport/
        callable/
        http/
      workers/
        outbox/
        schedules/
        projections/
        cleanup/
      generated/
    test/
      unit/
      contract/
      emulator/
      rules/
      integration/
      load/
      reconciliation/

packages/api_contracts/
  schema/
    booking/
      v1/
        *.schema.json
        fixtures/
    <domain>/
      vN/
        *.schema.json
        fixtures/
  lib/
    src/
      contracts/
      dto/{request,response}/
      serializers/
      clients/
      generated/
  test/
```

Внутри каждого `modules/<name>/` target pattern:

```text
domain/
application/
infrastructure/
transport/
```

Модуль может опустить неприменимый слой, но не смешать его ответственность с
другим. `generated/` редактируется только генератором. Exact files, runtime
versions, dependency pins, Firebase project IDs, regions and deploy identities
принадлежат Approved BCK-03/04/05 и executable slice.

`packages/api_contracts/schema/booking/v1` уже существует и является
compatibility anchor. BCK-03 расширяет versioned `schema/<domain>/vN` layout и
не переименовывает `schema/` в `schemas/`, не переносит существующие fixtures и
не создаёт второй contract source без отдельного Approved migration plan.

Initial scaffold не создаёт пустые `ai/`, `providers/` или `payments/`
directories «на будущее». AI/provider modules появляются только в собственном
Approved executable slice после BCK-15/BCK-16. Payments module и любая его
physical directory дополнительно требуют новый Accepted Payments ADR и
Approved BCK-17 slice. Отсутствие директории является корректным fail-closed
состоянием, а не architecture gap.

Root `transport/` содержит только общий endpoint registry, middleware и
composition. `modules/<name>/transport/` содержит принадлежащие модулю wire ↔
application mappers/handlers. Ни один из них не содержит domain policy или
direct persistence shortcut.

## 18. Environments, deployment и operations

Target environments: `dev`, `stage`, `prod`, с отдельными credentials и
fail-closed mapping. Local Emulator не является четвёртым production
environment.

До provisioning BCK-05 обязан определить:

- project/resource separation и blast radius;
- Firestore edition и immutable/semimmutable resource locations через OD-07;
- workload/service identities и IAM matrix;
- secret lifecycle and rotation;
- CI/CD provenance, approvals and artifact promotion;
- server-owned flags с default-off risky mutations;
- SLO/SLI, alerts, on-call and incident severity;
- cost budgets, quota alarms and automatic containment;
- backup/export, accepted RPO/RTO and restore drill;
- deployment and data rollback distinctions;
- event/task topology после OD-09.

Operational logs/metrics принадлежат BCK-05. Product analytics принадлежат
BCK-21. Они могут использовать общий correlation ID, но не смешивают purpose,
access и retention.

## 19. Test and evidence baseline

| Test family | Что доказывает | Первый обязательный gate |
|---|---|---|
| Unit | Pure domain/application invariants | R0/executable slice |
| Schema/contract | Backward/forward compatibility, unknown values | BCK-03/R0 |
| Shared fixtures | Dart/TypeScript semantic parity | R0 |
| Emulator integration | Auth/Functions/Firestore/Storage behavior | R1 |
| Rules/IAM negative | Direct/cross-user/cross-page denial | R1/R2 |
| Idempotency/retry/fault | Safe duplicate, timeout and partial failure | Per mutation module |
| Projection replay | Rebuildability and revision/freshness | R3 |
| Migration/dry-run | No loss, duplication or wrong owner | Before domain cutover |
| Concurrency/contention | No oversell/lost updates | Booking R5 |
| Reconciliation/repair | Drift detection and safe correction | Before persistent staging |
| Security/abuse | Rate/App Check/AuthZ/privilege controls | Before cohort |
| Privacy DSR/deletion | Complete governed data handling | Before personal-data production |
| Load/soak/cost | SLO, capacity and budget behavior | Before cohort/GA |
| Backup/restore/DR | Accepted RPO/RTO with actual restore | Before source-of-truth production |
| Market isolation | Disabled markets and policy revisions fail closed | Every LV/EE/LT activation |

Каждый evidence artifact содержит date, commit/build ID, environment, command,
result, owner и known limitations. Timeout, skipped test или ручной happy path
— `inconclusive`, не `pass`.

## 20. Документационный комплект

### 20.1. Один backend, несколько specifications

| Wave | Documents | Зачем |
|---|---|---|
| D0 | BCK-02 | Registry, ownership, sequence, decisions, risks, gates |
| D1 | BCK-01, затем BCK-03/04/05/20 | Platform, API, Security/Privacy, Operations, Reference Data |
| D2 | BCK-06, BCK-18, затем BCK-07/08 | Authority, mobile seam, publication, catalog |
| D3 | BCK-13/14/19/21; reconcile BCK-09; BCK-12/22 | User effects, media, ops, analytics, Booking, safety |
| D4 | BCK-10/11 | Planning and Route cloud contracts |
| D5 | BCK-15/16; BCK-17 only after ADR | Optional AI/providers/payments |
| D6 | RUN-01–06 from actual topology | Incident, rollback, repair, privacy, DR, security/abuse |

Итого baseline BCK-02: **22 BCK specs + 6 production runbooks**. Это не 28
backend systems: это 28 контролируемых документов для одного backend.

### 20.2. Что BCK-01 фиксирует, а что делегирует

| BCK-01 фиксирует | Детализируется ниже |
|---|---|
| One backend / bounded modules | Exact module APIs in domain BCK specs |
| Layer directions | Exact commands and data schemas in BCK-03/domain specs |
| One writer per record | Exact collections/indexes in owning spec/BCK-05 |
| Mandatory Auth/capability/PublisherRef | Identity lifecycle in BCK-06 |
| Contract-first, typed errors, idempotency | Exact envelope/version window in BCK-03 |
| LV-first and independent Baltic flags | MarketConfig wire format in BCK-20 |
| Security/privacy/ops are gates | Exact controls/retention/SLO in BCK-04/05 |
| Mobile never becomes backend authority | Adapter/import contract in BCK-18 |

## 21. Open decisions and fail-closed defaults

BCK-01 не закрывает OD доказательствами, которых ещё нет.

| Decision | Owner document | Пока не Accepted |
|---|---|---|
| OD-01 Search/geo engine | BCK-08 + BCK-05 | Search runtime не активируется |
| OD-02 Transactional email | BCK-13 | Email channel отсутствует/disabled |
| OD-03 Cold-start catalog source | BCK-07/08 | Seed не становится production authority |
| OD-04 Local-to-cloud import | BCK-18 | Production import запрещён |
| OD-05 Analytics destination | BCK-21 | Не отправлять production product analytics |
| OD-06 T&S enforcement | BCK-22 | UGC cohort blocked where controls required |
| OD-07 Firebase topology/edition/locations | BCK-04/05 | Не создавать location-bound resources |
| OD-08 Account linking/recovery/mapping | BCK-06/18 | Production identity migration blocked |
| OD-09 Event/outbox contract | BCK-03/05/13 | Cross-domain effects/workers disabled |
| OD-10 LocalizedText/reference revisions | BCK-20/03 | Publication contract Approval blocked |
| OD-11 Minors/age policy | BCK-04/06/07/09/22 | Applicable functions server-disabled |

`TBD` без owner, decision document, gate и safe default блокирует Approval.

## 22. Rollout, rollback и activation

Documentation approval, code completion and feature activation — разные
состояния:

```text
Draft/Review/Approved spec
  != Runtime Absent/Scaffolded/Implemented/Deployed
  != Disabled/Internal/Cohort/Enabled product state
```

Runtime sequence управляется BCK-02 R0–R12 и Latvia/Baltics roadmap. Минимум:

1. D1 platform set Approved и G1;
2. отдельный Approved executable slice;
3. Emulator/toolchain evidence без production resources;
4. environment/IAM scaffold с mutations default-off;
5. production Identity and mobile boundary;
6. domain-by-domain implementation and import;
7. persistent staging only after reconciliation/repair/operations readiness;
8. bounded Latvia cohort;
9. observation window and G7 before Latvia GA;
10. EE/LT activated independently with market/legal/locale evidence.

Rollback имеет три разных уровня:

- **feature rollback:** server flag blocks new mutations, safe exits remain;
- **deployment rollback:** previous verified artifact/config restored;
- **data reconciliation:** owning domain detects/proposes/executes repair with
  immutable audit; blind database restore не заменяет reconciliation.

## 23. Risks and prohibited designs

Запрещено:

1. один `backend_service.ts` со всей business logic;
2. direct mobile writes в authoritative collections;
3. Firestore documents как public API contract;
4. два writers одного record/counter/projection;
5. Booking/holds/participants inside Event;
6. Route, Scenario и Quick Plan в одном aggregate;
7. global `Pro` role вместо verified Creator + page-scoped capability;
8. client-granted role, verification, membership или admin authority;
9. provider Booking/internal Booking/Payments в одном ledger;
10. raw SDK errors и unversioned dynamic maps на boundary;
11. float money, device-authoritative time или display-name references;
12. unbounded array/document, worker, retry или query;
13. silent last-write-wins для capacity/ownership/publication;
14. projection без source revision/freshness/rebuild path;
15. analytics/logging как скрытое sensitive-data storage;
16. global market enable, автоматически включающий EE/LT вместе с LV;
17. создание Firebase resources до OD-07 и Approved executable slice;
18. runbook, описывающий вымышленную, ещё не реализованную topology;
19. status `Done` без reproducible evidence;
20. microservice split без Accepted ADR и измеримой необходимости.

## 24. Definition of Ready для физического backend

Создание `apps/backend` не Ready, пока одновременно не выполнено:

- активный STABILIZATION slice из `AGENTS.md` завершён либо применимый новый
  Accepted ADR и Approved slice явно разрешают exact backend exception;
- BCK-01, BCK-03, BCK-04, BCK-05 и BCK-20 Approved/reconciled;
- G1 passed;
- OD-07 и OD-10 Accepted;
- OD-09 и OD-11 имеют требуемый BCK-02 status;
- выбран exact bounded executable slice и перечислены exact files;
- определены runtime/toolchain pins и local Emulator path;
- initial server flags default-off;
- написаны rollback и evidence plan;
- подтверждено отсутствие production credentials/data в first scaffold;
- получено отдельное post-stabilization authorization, если его требует
  Architecture Baseline/ADR/domain gate.

Для ECL-03 Booking дополнительно действуют ADR 0019, BCK-09 и ECL-03 gates.

## 25. Definition of Done BCK-01 v0.3

BCK-01 может перейти из Draft в Review, когда:

- все anchors существуют и ссылки валидны;
- BCK-02 registry обновлён с `BCK-01 Planned/Absent` на фактический
  `Draft v0.3/Present, runtime Absent`, а ownership reconciliation не содержит
  двойных writers;
- target layers/modules не создают второго writer;
- LV/EE/LT boundary согласована с roadmap;
- open decisions не представлены как принятые;
- review owners Platform, API, Security/Privacy, Operations, Identity, Mobile
  Architecture и ключевых domains назначены;
- conflicts записаны явно;
- repository diff содержит только documentation changes;
- runtime status остаётся `Absent`.

Approval требует reconciliation report и sign-off владельцев, но не требует
создания backend runtime.

## 26. Acceptance criteria

1. **BCK-01-AC-01:** документ определяет один logical Recharge backend.
2. **BCK-01-AC-02:** один backend не интерпретируется как один monolithic module.
3. **BCK-01-AC-03:** initial topology использует modular application с bounded
   modules и independently gated entrypoints/workers.
4. **BCK-01-AC-04:** microservice split требует measured need и Accepted ADR.
5. **BCK-01-AC-05:** contract, transport, application, domain, infrastructure,
   projection, effects и operations responsibilities разделены.
6. **BCK-01-AC-06:** domain не зависит от Firebase/transport/framework.
7. **BCK-01-AC-07:** mobile не знает Firestore schema и не пишет authority
   напрямую.
8. **BCK-01-AC-08:** каждый authoritative record type имеет одного writer.
9. **BCK-01-AC-09:** cross-domain mutation вызывает owning command.
10. **BCK-01-AC-10:** projections rebuildable, revisioned и freshness-labelled.
11. **BCK-01-AC-11:** Discover feed/map/search одного query имеют общий
    revision/freshness reconciliation contract.
12. **BCK-01-AC-12:** mandatory Auth и server-owned capability authority
    соответствуют ADR 0015.
13. **BCK-01-AC-13:** PublisherRef ID-based; Personal/Page scopes различимы.
14. **BCK-01-AC-14:** Booking boundaries соответствуют ADR 0019/BCK-09.
15. **BCK-01-AC-15:** Scenario, Quick Plan и Route не смешаны.
16. **BCK-01-AC-16:** provider, internal Booking и Payments authority разделены.
17. **BCK-01-AC-17:** mutations versioned, idempotent и возвращают typed result.
18. **BCK-01-AC-18:** `cancelled` — typed non-success outcome.
19. **BCK-01-AC-19:** unknown critical version/revision fails closed.
20. **BCK-01-AC-20:** IDs immutable ULID/UUID; references ID-based.
21. **BCK-01-AC-21:** authoritative timestamps UTC; local semantics use object
    IANA timezone.
22. **BCK-01-AC-22:** Visit History date uses Place IANA timezone.
23. **BCK-01-AC-23:** Money uses integer minor units + ISO currency.
24. **BCK-01-AC-24:** market, locale, country, currency, environment and timezone
    are distinct.
25. **BCK-01-AC-25:** Latvia activates first; EE/LT remain independently gated.
26. **BCK-01-AC-26:** every data family receives class, retention and
    export/deletion treatment before schema Approval.
27. **BCK-01-AC-27:** App Check supplements but never replaces AuthZ/rate/abuse
    controls.
28. **BCK-01-AC-28:** admin repair cannot bypass owning domain invariants.
29. **BCK-01-AC-29:** offline/cache/server/unknown outcome states are honest and
    typed.
30. **BCK-01-AC-30:** local-to-cloud migration is explicit, checkpointed,
    idempotent and domain-owned.
31. **BCK-01-AC-31:** demo/mock records never become production authority.
32. **BCK-01-AC-32:** target file map keeps one `apps/backend` application and
    module-level layers.
33. **BCK-01-AC-33:** `packages/api_contracts` remains the shared contract
    source/workflow.
34. **BCK-01-AC-34:** environments, credentials, IAM, flags and resource
    locations are fail-closed until BCK-04/05 and OD-07.
35. **BCK-01-AC-35:** operational telemetry and product analytics remain
    purpose-separated.
36. **BCK-01-AC-36:** test evidence is reproducible; timeout/skip is not pass.
37. **BCK-01-AC-37:** BCK-01 does not replace BCK-03–22 or RUN-01–06.
38. **BCK-01-AC-38:** open decisions retain owner, gate and disabled default.
39. **BCK-01-AC-39:** documentation Approval does not imply runtime permission.
40. **BCK-01-AC-40:** physical backend waits for G1 and a separate Approved
    executable slice.
41. **BCK-01-AC-41:** no `apps/backend`, Firebase config/resource, credential,
    deployment, production schema or application code is created by current
    documentation revision.
42. **BCK-01-AC-42:** runtime status after acceptance remains `Absent` until
    independently evidenced.
43. **BCK-01-AC-43:** schema/API/event evolution и minimum-client policy имеют
    versioning, compatibility fixtures, deprecation и typed rejection.
44. **BCK-01-AC-44:** authoritative authorization re-evaluates current
    server-owned grants and revocation; cached client state не даёт authority.
45. **BCK-01-AC-45:** root transport registry и module transport handlers имеют
    разные ответственности и не содержат domain/persistence shortcuts.
46. **BCK-01-AC-46:** BCK-02 v2.4, BCK-02-A1 и BCK-09 представлены с их
    фактическими status/evidence и не объявлены отсутствующими.
47. **BCK-01-AC-47:** source reconciliation различает execution instructions,
    architecture authority, implementation status и delivery coordination.
48. **BCK-01-AC-48:** ownership matrix покрывает import, privacy orchestration,
    server flags, provider, AI и conditional Payments records.
49. **BCK-01-AC-49:** shared contracts продолжают фактический
    `schema/<domain>/vN` layout без необоснованного rename/duplicate source.
50. **BCK-01-AC-50:** gated AI/provider directories не создаются initial
    scaffold; Payments directory невозможна до Accepted ADR и Approved slice.
51. **BCK-01-AC-51:** BCK-02 отражает фактический spec/runtime status BCK-01 до
    перевода BCK-01 в Review.
52. **BCK-01-AC-52:** distributed review copy явно указывает canonical
    repository path/link base и не переопределяет repository anchors.

Номера AC этой ревизии стабильны: новые criteria добавляются в конец. Удаление
или изменение смысла существующего AC требует новой version и migration note
для ссылок.

## 27. Unimplemented list

На дату v0.3 не реализованы:

- physical `apps/backend` application;
- Firebase projects/resources/configuration;
- backend command/query/event runtime;
- Firestore/Storage Rules and indexes;
- production Auth/capability/Publisher authority;
- content publication/catalog/search backend;
- authoritative Event Booking transaction core;
- media/notification/library/review/T&S/admin backend;
- Scenario/Quick Plan/Route cloud backend;
- privacy deletion/export orchestration;
- monitoring/SLO/budgets/backups/restore;
- production AI/provider integrations/Payments;
- production migrations and market activation.

Existing local/mock capability and docs/contracts do not change this list.

## 28. Следующий пакет

После review BCK-01 работа остаётся документационной:

1. reconciliation report BCK-01 ↔ BCK-02 ↔ Architecture Baseline ↔ ADR;
2. BCK-03 `BACKEND_API_CONTRACT_STANDARD.md`;
3. BCK-04 `BACKEND_SECURITY_PRIVACY_SPEC.md`;
4. BCK-05 `BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md`;
5. BCK-20 `REFERENCE_DATA_LOCALIZATION_SPEC.md`;
6. initial proposals OD-07/09/10/11;
7. обновление BCK-02 status/evidence до перевода BCK-01 в Review.

До завершения этого пакета и отдельного разрешения backend code, Firebase
provisioning, credentials, deployments и production data processing не
начинаются.

## 29. Итог

Recharge строит **один backend**, разделённый на архитектурные слои и bounded
product modules. Общие правила и authority едины; domain logic, persistence,
projections и operational effects не смешиваются. BCK-01 является первичным
master-контрактом для дальнейшего проектирования, а не попыткой вместить весь
backend в один файл и не разрешением на физическую реализацию.
