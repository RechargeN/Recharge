# ECL-01 — Local Event classification foundation

- Версия: 1.1
- Дата: 2026-08-08
- Статус: **Approved and Done**
- Approval evidence: явное «поехали» от product owner 2026-08-08 до
  runtime-изменений
- Parent canon:
  [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md), Accepted
  v2.2.3
- Reconciliation:
  [EVENT_CLASSIFICATION_ECL_00_RECONCILIATION_SPEC.md](EVENT_CLASSIFICATION_ECL_00_RECONCILIATION_SPEC.md),
  ECL-00 Done
- Runtime boundary: local/mock; без Firebase, Booking, Payments и providers

## 1. Цель

Добавить в существующий Event Create runtime каноническую локальную
classification foundation:

- ровно один `EventArchetype` из 34 значений;
- один primary и до трёх дополнительных `ParticipationMode`;
- один shared `PublisherRef {type: user | page, id}`;
- безопасное чтение legacy Event без обязательного migration write;
- explicit confirmation для legacy suggestions;
- versioned additive Event draft schema;
- декларативную Event classification section в общем form engine;
- typed application state/commands без бизнес-логики в presentation.

ECL-01 не добавляет admission/inventory configuration ECL-02 и не включает
никакую production capability.

## 2. Непересматриваемые инварианты

1. Accepted ADR выше этого slice.
2. Archetype, Category, participation, format, admission и pricing независимы.
3. Category System v1.4.3 не копируется в Event enum.
4. `eventType: String` — legacy input, не archetype source of truth.
5. Suggestion не становится persisted decision без явной команды Creator.
6. Новый draft получает PublisherRef из active workspace один раз; workspace
   switch не переписывает существующий draft.
7. Legacy organizer fields не являются authority.
8. Mapper сохраняет unknown future fields и fail closed для unsupported newer
   schema.
9. `EventCreateBlock` только отображает typed view state и вызывает commands.
10. Не создаются отдельные формы/flows для 34 archetypes.
11. Event, Place, Route, Scenario, Quick Plan, Bookable Session и Find People
    остаются разными aggregates.
12. Наличие enum/field не включает ECL-02–08 capability.

## 3. Scope

### 3.1 Входит

- 34 archetype enum values без сокращённого MVP-набора;
- 17 participation mode values из канона;
- value object для primary/additional participation;
- shared PublisherRef consumption в Event;
- typed classification validation/readiness issues;
- deterministic legacy archetype suggestion с reason/confidence;
- Event schema v1 → v2 compatibility read;
- explicit confirmation command;
- mapper round-trip/downgrade behavior;
- Event template reusable/authority allowlist;
- declarative section definition и typed view state;
- Event UI selector, suggestion disclosure и `other` reason;
- accessibility 360 dp / 150% text scale;
- telemetry только из allowlisted enum/reason/status;
- feature flag и non-destructive rollback.

### 3.2 Не входит

- admission presets/modes и confirmation policy;
- inventory authority/shapes/pools/availability;
- Booking/waitlist/reconfirmation/concurrency cap;
- external provider handoff/sync/provenance;
- Program Items, tickets, payments, seating;
- Discover ranking/filter migration;
- production API/Firebase/backend authority;
- изменение Category System 28/530;
- новый Create type;
- изменение Route/Scenario/Quick Plan models;
- массовая migration write существующих drafts/events.

## 4. Delivery decomposition

### ECL-01A — Shared/domain contracts

- shared PublisherRef prerequisite;
- `EventArchetype` и `ParticipationMode`;
- `EventParticipation` value object;
- `EventClassificationDraft` либо эквивалентная cohesive typed value;
- validation use case;
- table-driven aggregate boundary policy.

### ECL-01B — Schema, mapper и legacy suggestions

- `EventDraftData.currentSchemaVersion = 2`;
- additive classification fields;
- v1 compatibility read без automatic write;
- deterministic suggestion use case;
- explicit confirmed/unconfirmed state;
- template migration/allowlist;
- downgrade/unknown-field tests.

### ECL-01C — Application orchestration

- typed classification section state;
- controller commands select/confirm/clear/change;
- impact calculation при смене archetype;
- autosave только confirmed persisted values;
- readiness integration;
- feature-flag behavior.

### ECL-01D — Presentation

- declarative classification section;
- primary/additional participation selector;
- legacy suggestion disclosure;
- `other` reason input;
- field-level issues/semantics;
- без validation/migration/persistence в widget.

### ECL-01E — Quality and release gate

- migration, mapper, domain, application и widget tests;
- other Create-type regression;
- analyzer/full suite/boundary/diff;
- status docs update только после green gates.

Подэтапы выполняются по порядку. Ни один промежуточный commit не объявляет
ECL-01 Done.

## 5. Canonical domain contract

```text
EventArchetype
  performance | screening | exhibition | open_stage | meet_greet |
  talk | discussion | conference | networking | social_meetup |
  hosted_game | open_play | competition |
  class_session | workshop | retreat_camp | wellness_session |
  tasting | shared_meal |
  party | celebration | festival |
  market_fair | auction | launch_promotion | open_day |
  tour_excursion | outdoor_gathering |
  community_action | volunteering | fundraiser | family_program |
  ceremony | other

ParticipationMode
  watch | attend | play | compete | perform | practice | learn | create |
  meet_people | date | visit | explore | eat_drink | shop | support |
  volunteer | travel

EventParticipation
  primary: ParticipationMode
  additional: Set<ParticipationMode> // 0..3, unique, excludes primary

EventClassificationDraft
  archetype: EventArchetype?
  participation: EventParticipation?
  otherReason: String?
```

Domain rules:

- new publish/material revision requires archetype + participation;
- `other` requires normalized non-empty reason and moderation signal;
- non-`other` clears `otherReason` through an explicit normalized command;
- additional modes are unique and limited to three;
- unusual archetype/category combination is not blocked without an explicit
  canonical rule;
- classification never mutates Category, admission, format or pricing.

## 6. PublisherRef prerequisite

В текущем runtime `PublisherRef` объявлен внутри `place_draft_data.dart`, а
Event использует legacy organizer fields. ECL-01 не создаёт Event-specific
копию.

До ECL-01B должен быть выполнен один из вариантов:

1. IDP-04A предоставляет shared PublisherRef/default contract; либо
2. ECL-01A атомарно извлекает существующие `PublisherType/PublisherRef` в
   общий Create domain file, переводит Place на import без изменения behavior
   и добавляет regression tests.

Event schema допускает `publisherRef=null` только как in-memory legacy
compatibility state. Новый draft получает non-null default. Legacy
`organizerId` может породить suggestion `{type:user,id}`, но:

- suggestion не сериализуется до подтверждения;
- autosave не выполняет silent migration;
- publish блокируется до подтверждения;
- workspace switch не меняет suggestion/existing PublisherRef;
- page Publisher не выводится из organizer name/email.

## 7. Schema v2 и migration

### 7.1 Persisted additions

```text
event_details.schemaVersion: 2
event_details.publisherRef?: { type, id }
event_details.classification?:
  archetype
  primaryParticipationMode
  additionalParticipationModes[]
  otherReason?
```

`confirmation` и suggestion confidence/reason являются transient application
state и не входят в persisted Event JSON.

### 7.2 Read rules

| Input | Результат чтения | Write |
|---|---|---|
| v2 valid classification | Typed confirmed state | Обычный round-trip |
| v2 missing required field | Draft читается, readiness blocking issue | Только после user command |
| v1 + deterministic match | Unconfirmed suggestion | Нет automatic write |
| v1 ambiguous/no match | Empty classification | Нет automatic write |
| version > 2 | Raw unknown contract сохраняется; editing/publish fail closed | Нет downgrade write |
| unknown enum | Raw field сохраняется; typed value не подменяется `other` | Нет destructive write |

Suggestion input priority:

1. canonical/legacy subcategory ID;
2. legacy `eventType` только как secondary evidence;
3. отсутствие уверенного совпадения → no suggestion.

Suggestion output содержит proposed archetype, stable reason code и confidence
bucket. Свободный title/description не анализируется ECL-01 и не отправляется в
analytics.

### 7.3 Write rules

- schema v2 записывается после первой explicit classification/Publisher
  confirmation либо изменения canonical field;
- unrelated autosave v1 draft не повышает schema и не подтверждает suggestion;
- write сохраняет `unknownFields`;
- changing archetype создаёт одну application command/revision;
- persisted additional participation сортируются в canonical enum order для
  deterministic JSON, семантически оставаясь set;
- envelope `CreateDraftModel.schemaVersion` не повышается без доказанной
  необходимости: nested Event schema версионируется самостоятельно.

## 8. Template contract

Reusable:

- confirmed archetype;
- primary/additional participation;
- `otherReason`, только если archetype остаётся `other` и reason не содержит
  запрещённых данных после bounded validation.

Всегда strip/re-default:

- PublisherRef и legacy organizer authority;
- suggestion/confirmation transient state;
- dates, occurrences, overrides, deadlines;
- URLs/provider/source/freshness;
- media/lifecycle/moderation/access secrets;
- unknown fields.

Materialized template создаёт новый draft с PublisherRef текущего active
workspace и не наследует Publisher исходного Event.

## 9. Application/presentation contract

```text
EventClassificationSectionState
  enabled
  selectedArchetype?
  suggestedArchetype?
  suggestionReason?
  suggestionConfidence?
  primaryParticipation?
  additionalParticipation[]
  otherReason
  issues[]
  impactPreview?

Commands
  confirmSuggestedArchetype
  selectArchetype
  selectPrimaryParticipation
  toggleAdditionalParticipation
  updateOtherReason
  confirmClassificationImpact
```

Application controller/coordinator:

- вызывает domain validation/suggestion use cases;
- проверяет source draft revision;
- создаёт normalized command result;
- обновляет draft атомарно;
- запускает существующий autosave pipeline;
- не меняет Category/admission/pricing;
- возвращает typed issues/impact presentation.

Presentation:

- не считает confidence, requiredness или impact;
- не читает/пишет JSON;
- не вызывает repository/datasource;
- не содержит mapping 530 subcategories → 34 archetypes;
- не реализует 34 отдельных code paths;
- только rendering/input/controller calls.

## 10. Exact file plan

Финальный implementation plan подтверждается ещё раз перед runtime edit, если
фактические имена/границы изменились после approval.

### Add

| Файл | Назначение |
|---|---|
| `apps/mobile/lib/features/create/domain/entities/publisher_ref.dart` | Shared PublisherRef, только если prerequisite не завершён IDP-04A |
| `apps/mobile/lib/features/create/domain/entities/event_classification.dart` | 34 archetypes, participation и typed classification values |
| `apps/mobile/lib/features/create/domain/usecases/suggest_event_classification_usecase.dart` | Deterministic legacy suggestion |
| `apps/mobile/lib/features/create/domain/usecases/validate_event_classification_usecase.dart` | Domain invariants/readiness issues |
| `apps/mobile/lib/features/create/application/event_classification_section.dart` | Declarative config + typed application view state/commands contract |
| `apps/mobile/lib/features/create/presentation/widgets/event_classification_section.dart` | Presentation-only section |
| `apps/mobile/test/unit/event_classification_test.dart` | Enum/value/boundary/validation coverage |
| `apps/mobile/test/unit/event_classification_migration_test.dart` | v1/v2/newer/unknown/suggestion coverage |
| `apps/mobile/test/widget/event_classification_section_test.dart` | UX/accessibility/controller-call coverage |

### Modify

| Файл | Ограниченное изменение |
|---|---|
| `event_draft_data.dart` | Additive schema v2 classification + PublisherRef fields |
| `event_draft_mapper.dart` | v1/v2 round-trip, unknown/unsupported fail-closed behavior |
| `place_draft_data.dart` / `place_draft_mapper.dart` | Только shared PublisherRef import migration при необходимости; behavior unchanged |
| `validate_event_draft_usecase.dart` | Композиция classification validator; без дублирования rules |
| `event_create_config.dart` | Declarative classification section placement |
| `event_create_coordinator.dart` | Typed command orchestration/readiness composition |
| `create_controller.dart` | Тонкие delegation methods; новая business logic запрещена |
| `event_create_block.dart` | Только композиция новой section и чтение typed state |
| `manage_create_template_usecase.dart` | Explicit reusable/strip allowlist |
| `create_draft_model.dart` | Только legacy context adapter, если mapper требует persisted organizer evidence |
| `create_providers.dart` / DI | Регистрация новых use cases/state dependencies |
| существующие Event tests/support | Fixtures и regression expectations для schema v2 |
| `AGENTS.md`, `LAUNCH_STATUS.md` | Только после green ECL-01E gate |

### Не изменять

- `docs/adr/*`;
- Route/Scenario/Quick Plan domain models;
- Category System registry/IDs;
- `packages/api_contracts`;
- Booking/Payments/provider code;
- generated files и assets.

## 11. Feature flag и rollback

Flag: `event_classification_ui`.

Rollout:

1. mapper/domain enabled for compatibility reads;
2. UI disabled by default in first integration commit;
3. internal local/mock fixtures;
4. UI enabled после migration/widget/full gates.

Rollback:

- flag hides classification section/new-draft entry behavior;
- mapper продолжает читать и round-trip v2 fields;
- existing v2 data не удаляется и не преобразуется в legacy `eventType`;
- unsupported classification блокирует material publish, но draft остаётся
  доступным для recovery/export;
- rollback не меняет PublisherRef, Category или occurrence IDs;
- template sanitizer продолжает fail closed для unknown fields.

## 12. Acceptance criteria

1. Ровно 34 unique archetype values соответствуют Accepted canon.
2. Participation dictionary содержит ровно 17 unique values.
3. Draft принимает один primary и не более трёх unique additional modes.
4. Primary не может одновременно находиться в additional set.
5. Новый Event draft получает ровно один valid PublisherRef.
6. Workspace switch не переписывает PublisherRef существующего draft.
7. Legacy organizer не становится Page Publisher автоматически.
8. v1 draft читается без обязательного write/schema bump.
9. Legacy suggestion не сериализуется до explicit confirmation.
10. Ambiguous legacy input не получает fabricated archetype.
11. Unknown enum/newer schema не подменяется `other` и не теряется.
12. v2 mapper round-trip сохраняет typed и unknown fields.
13. Archetype selection не меняет Category/admission/format/pricing.
14. `other` требует reason и moderation signal.
15. Template сохраняет reusable classification и удаляет Publisher/instance/
    unknown/secret data.
16. `EventCreateBlock` не получает validation/migration/persistence logic.
17. Все §1.2 aggregate boundary fixtures дают canonical result.
18. UI работает на 360 dp при 150% text scale, с semantics и non-color issues.
19. Disabled flag сохраняет read/round-trip и не удаляет v2 data.
20. Другие девять Create types сохраняют прежнее поведение.
21. `flutter analyze --no-pub` — 0 issues.
22. Полный `flutter test --no-pub` — green.
23. Boundary и scoped diff checks — green, новых suppressions нет.

## 13. Required test matrix

| Layer | Обязательное доказательство |
|---|---|
| Domain | 34/17 cardinality, participation invariants, `other`, independence, boundaries |
| Migration | v1 no-write, confirmed write, ambiguous/no suggestion, unknown enum, newer schema, downgrade |
| Publisher | new-draft default, legacy suggestion, workspace non-rewrite, invalid/revoked readiness |
| Mapper | deterministic v2 JSON, unknown preservation, corrupt/partial input fail closed |
| Template | reusable classification, authority/instance/unknown stripping, new Publisher default |
| Application | one command/revision/autosave, stale revision rejection, impact confirmation |
| Widget | suggestion disclosure, selection, additional cap, other reason, errors, 360 dp/150% |
| Regression | Event schedule/mapper/publish/templates; Place PublisherRef; all Create types |
| Repository | analyzer, full suite, boundary, diff/whitespace |

## 14. Risks and controls

| Риск | Control |
|---|---|
| Silent migration через defaults/autosave | Nullable legacy state + transient suggestion + explicit command tests |
| PublisherRef duplication | Shared contract prerequisite; Event-specific class запрещён |
| 34-way widget monolith | Declarative section config/state; no archetype switch in presentation |
| Category coupling | Independence domain tests; mapping only in suggestion use case |
| Future field loss | unknownFields round-trip and downgrade fixtures |
| Template authority leak | Explicit allowlist/strip tests |
| Regression other Create types | Envelope and all-type controller/widget tests |
| ECL-02 scope creep | Admission/inventory fields and UI explicitly excluded |

## 15. Definition of Done

ECL-01 считается Done только когда:

- этот документ получил явный статус Approved before implementation;
- ECL-01A–E выполнены без расширения scope;
- AC 1–23 имеют automated evidence;
- Event schema migration/rollback проверены;
- `EventCreateBlock` остаётся presentation-only;
- analyzer/full tests/boundary/diff зелёные;
- `LAUNCH_STATUS.md` отражает фактический результат;
- нет Firebase, Booking, Payments, provider integration или нового Create type.

## 16. Completion evidence

- ECL-01A–E реализованы без admission/inventory/Booking/provider/payment scope;
- Event nested schema v2 читает v1 без silent write, сохраняет unknown/newer
  payload fail closed и пишет classification только после explicit command;
- shared PublisherRef извлечён из Place contract, новый Event/шаблон получает
  active Personal/Page workspace один раз, existing draft не переписывается;
- `EventCreateBlock` только компонует typed state и controller callbacks;
- `flutter analyze --no-pub`: **0 issues**;
- `flutter test --no-pub`: **612 passed**;
- boundary: passed, **59 существующих suppressions**, новых нет;
- scoped diff/whitespace: passed.

ECL-01 завершён 2026-08-08. ECL-02 остаётся отдельным slice и не был начат
этой реализацией.
