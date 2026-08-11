# ECL-02 — Local Event admission, inventory configuration and availability

- Версия: 1.2
- Дата: 2026-08-08
- Статус: **Done**
- Parent canon:
  [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md), Accepted
  v2.2.3
- Предыдущий обязательный slice:
  [EVENT_CLASSIFICATION_ECL_01_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_01_SLICE_SPEC.md),
  должен быть Done до runtime ECL-02
- Runtime boundary: local/mock; без real Booking, provider sync и Payments

## 1. Цель

Расширить единый Event Create runtime канонической локальной конфигурацией:

- независимые admission/registration/confirmation оси;
- eligibility, guest, onsite и optional interest policies;
- capacity отдельно от inventory authority/shape/pools;
- все канонические inventory shapes без MVP-only сокращения enum;
- channel-bound onsite/online/any pools для hybrid Event;
- честная mock availability projection с `unknown/stale`;
- admission presets, которые нормализуются в отдельные поля;
- schema v3 migration без silent semantic guesses;
- declarative typed sections без business logic в `EventCreateBlock`.

ECL-02 конфигурирует будущие механики, но не создаёт Booking, hold, waitlist
promotion, payment, provider mirror или authoritative inventory mutation.

## 2. Dependency gate

Документ можно утвердить заранее, но runtime ECL-02 запрещён, пока ECL-01 не
имеет статус Done и green gates.

Обязательные входы из ECL-01:

- Event schema v2 и подтверждённая additive migration;
- shared PublisherRef;
- typed Event classification/application state;
- declarative classification section pattern;
- working Event templates schema/allowlist;
- feature-flag/read compatibility contract.

Если фактическая ECL-01 schema version отличается от `2`, номер ECL-02 schema
пересчитывается перед implementation approval; семантика migration не меняется.

## 3. Непересматриваемые инварианты

1. Admission, registration, confirmation, pricing, payment, inventory,
   visibility и eligibility — независимые оси.
2. UI preset — transient convenience, не persisted source of truth.
3. Capacity configuration не является inventory ledger.
4. `currentParticipants` не вводится Creator и не выводится из capacity.
5. `inventoryAuthority` не является inventory shape.
6. Unknown/stale не становятся free/available/zero.
7. Sold-out — availability projection, не Event lifecycle.
8. External provider operational fields read-only; ECL-02 не создаёт provider
   source of truth.
9. Optional RSVP при open entry не создаёт Booking и не резервирует inventory.
10. Waitlist configuration не запускает promotion/hold до ECL-03/verified
    provider capability.
11. Hybrid Event с finite physical capacity требует bounded onsite pool.
12. Assigned seating не становится selectable без authoritative hold API.
13. Oversell/overbooking не симулируются client-side как production guarantee.
14. Booking/Payment/Attendance/Refund records не вкладываются в Event draft.
15. Presentation не валидирует, не рассчитывает availability и не сохраняет
    JSON.

## 4. Scope

### 4.1 Входит

- `AdmissionMode`: openEntry/rsvp/booking/application/ticket/teamRegistration;
- `RegistrationMode`: none/external/internal;
- `ConfirmationMode`: none/instant/manualApproval/lottery/providerManaged;
- typed eligibility rule kinds;
- guest policy;
- onsite admission policy;
- optional interest/reminder policy;
- waitlist configuration/readiness, без lifecycle;
- registration/application windows configuration;
- capacity known/unknown/unlimited reconciliation;
- `InventoryAuthority`: none/recharge/externalProvider;
- 10 canonical inventory shapes;
- typed inventory pools и channel binding;
- local/mock inventory snapshot port/datasource;
- deterministic availability projection;
- admission presets normalization;
- cross-axis validation §19 canon;
- schema v2 → v3 compatibility read;
- templates allowlist/strip update;
- declarative application/presentation sections;
- local feature flags и rollback.

### 4.2 Не входит

- создание/изменение Booking/hold/inventory ledger;
- waitlist promotion/TTL offers;
- reconfirmation/auto-release behavior;
- uniform Booking concurrency cap;
- notification delivery;
- QR/check-in/Attendance;
- provider OAuth, secrets, handoff, polling/webhooks;
- authoritative external prices/inventory/bookings;
- ticket definitions и paid ticket sales;
- PSP/Payments/refunds/payout;
- interactive assigned seating;
- Program Items/auxiliary admission tracks runtime;
- Discover production projection/API DTO;
- Firebase или новый backend;
- новый Create type;
- изменение Category/archetype/participation dictionaries.

Attendance policy, auxiliary admission tracks и platform Booking concurrency
policy остаются ECL-03: их нельзя включать в ECL-02 через generic JSON.

## 5. Delivery decomposition

### ECL-02A — Admission domain and presets

- independent admission/registration/confirmation values;
- eligibility/guest/onsite/interest policies;
- registration/application windows;
- preset normalization use case;
- canonical cross-validation;
- migration suggestions из legacy registration fields.

### ECL-02B — Inventory configuration

- authority, shapes, pools и channel binding;
- positive/stable pool IDs;
- capacity reconciliation;
- hybrid onsite invariant;
- assigned-seating/provider readiness gates.

### ECL-02C — Mock availability projection

- immutable local snapshot port;
- mock datasource outside Event draft;
- deterministic projection use case;
- explicit knowledge/freshness states;
- no inventory mutations/production promises.

### ECL-02D — Application and presentation

- typed section states/commands;
- preset preview then normalized Apply;
- admission/inventory form sections;
- channel-aware local preview;
- field-level issues and capability disclosures;
- 360 dp / 150% accessibility.

### ECL-02E — Migration, quality and release gate

- v2/v3/newer-schema tests;
- template and other Create regression;
- analyzer/full tests/boundary/diff;
- status docs only after green gates.

## 6. Canonical admission contract

```text
EventAdmissionDraft
  admissionMode: AdmissionMode?
  registrationMode: RegistrationMode?
  confirmationMode: ConfirmationMode?
  eligibilityRules: List<EligibilityRule>
  guestPolicy: GuestPolicy?
  onsiteAdmissionPolicy: OnsiteAdmissionPolicy?
  interestPolicy: InterestPolicy?
  registrationWindow: EventAccessWindow?
  applicationWindow: EventAccessWindow?
  waitlistPolicy: WaitlistConfiguration?

AdmissionMode
  openEntry | rsvp | booking | application | ticket | teamRegistration

RegistrationMode
  none | external | internal

ConfirmationMode
  none | instant | manualApproval | lottery | providerManaged
```

### 6.0 Access windows

Registration/application windows не переиспользуют один абсолютный timestamp
для всей recurring series:

```text
EventAccessWindow
  kind: absolute | occurrenceRelative
  opensAtUtc?                       # absolute, one-time
  closesAtUtc?                      # absolute, one-time
  opensBeforeOccurrenceMinutes?     # relative, multi-date/recurring
  closesBeforeOccurrenceMinutes?    # relative, multi-date/recurring
```

- absolute требует `opensAtUtc < closesAtUtc < occurrence.startAtUtc`;
- occurrenceRelative требует оба positive offsets, причём окно открытия
  начинается раньше окна закрытия;
- multi-date/recurring используют relative rule; исключение конкретной
  occurrence хранится occurrence override по stable ID;
- `applicationWindow` обязателен для lottery configuration;
- это окно регистрации/заявки, а не physical `admissionWindows` расписания;
- window validation выполняется domain use case, не presentation.

### 6.1 Eligibility

```text
EligibilityRule
  id: ULID | loc_*
  kind: invitation | accessCode | membership | allowlist | qualification |
        accreditation | ageRequirement | waiver
  publicExplanation?
  policyRef?
```

- ECL-02 не хранит raw access code, allowlist identities, membership secrets,
  waiver answers или sensitive documents.
- `policyRef` может ссылаться только на существующий local/mock fixture; без
  authoritative policy readiness блокирует publish.
- Sensitive eligibility не используется как ranking tag.

### 6.2 Guest policy

```text
GuestPolicy
  mode: none | plusOne | plusN | namedGuestsOnly
  maxGuests?
  countsAgainstCapacity: true
```

`countsAgainstCapacity=false` не поддерживается в основном visitor flow.
Отдельная unlimited observer category требует отдельного pool/configuration.

### 6.3 Onsite and interest policies

```text
OnsiteAdmissionPolicy
  allowed
  salesAtDoor
  registrationAtDoor
  subjectToAvailability

InterestPolicy
  optionalRsvpEnabled
  reminderConsentRequired: true
  createsBooking: false
  reservesInventory: false
  registrationAtDoorRequired: false
```

Interest CTA не называется Booking/registration guarantee и не попадает в My
Bookings. ECL-02 может показать только local preview; reminder delivery не
входит в scope.

### 6.4 Waitlist configuration

```text
WaitlistConfiguration
  enabled
  promotionMode: organizerManaged | fifoAutomatic
  offerTtlMinutes?
  paymentDeadlineMinutes?
```

В ECL-02 это configuration/readiness only. `enabled=true` допустим только при
finite inventory и internal lifecycle либо explicit verified-provider support.
Поскольку таких authoritative adapters в ECL-02 нет, runtime publish остаётся
fail closed для active automatic waitlist; local UI обязан маркировать preview
как configuration/demo, а не работающую очередь.

## 7. Admission presets

```text
noRegistration
  -> openEntry + none + none

freeRsvp
  -> rsvp + internal + instant

organizerApplication
  -> application + internal + manualApproval

externalRegistration
  -> rsvp|booking + external + explicit confirmation selection

externalTickets
  -> ticket + external + providerManaged

rechargeTickets
  -> ticket + internal + instant|manualApproval

teamRegistration
  -> teamRegistration + internal|external + selected confirmation
```

Правила:

- preset ID не сохраняется как authority;
- если preset допускает варианты, Creator явно выбирает значение до Apply;
- `providerManaged` доступен только при verified provider readiness; без него
  external confirmation остаётся unconfirmed и блокирует publish;
- Apply создаёт одну normalized application command/revision;
- изменение отдельной оси переводит UI в `custom`, не ломая persisted fields;
- ECL-03/04/07-dependent preset может быть видим как locked capability с
  объяснением, но не создаёт publishable configuration без readiness;
- rollback UI не удаляет уже сохранённые normalized fields.

## 8. Inventory configuration

```text
InventoryAuthority
  none | recharge | externalProvider

InventoryShape
  generalCapacity | sharedTicketPool | separateTicketPools | zones |
  assignedSeating | teamSlots | participantRoles | roleBalancedSlots |
  tableInventory | timeSlotInventory

InventoryChannel
  onsite | online | any

EventInventoryConfiguration
  authority: InventoryAuthority
  primaryShape: InventoryShape?
  additionalShapes: Set<InventoryShape>
  pools: List<EventInventoryPoolDraft>

EventInventoryPoolDraft
  id: ULID | loc_*
  label
  shape
  channel
  capacityMode: known | unknown | unlimited
  capacity?
  roleIds[]
  zoneRef?
  providerPoolRef?
```

Правила:

- `known` требует positive capacity; unknown/unlimited хранят `capacity=null`;
- pool IDs стабильны, связи только по ID;
- primary shape не повторяется в additional set;
- shared pool не суммируется повторно через presentation rows;
- при известной Event capacity сумма уникальных consuming pools одного channel
  не превышает Event capacity; shared pool учитывается один раз по stable ID;
- additional shapes описывают тот же pool и не создают скрытую вторую квоту;
- unknown pool не участвует в вычислении известного остатка и переводит
  соответствующую projection в unknown;
- host/offline reserved квота должна быть отдельным pool того же будущего
  ledger, но ECL-02 не уменьшает inventory;
- role IDs берутся из versioned neutral dictionary, не из sensitive labels;
- externalProvider требует providerRef/freshness contract ECL-04/05 и до него
  остаётся non-publishable configuration;
- assignedSeating требует authoritative hold API ECL-08;
- timeSlotInventory не превращает Event в Bookable Session: occurrences
  остаются определёнными Event slots согласно aggregate boundary.

### 8.1 Hybrid channel invariant

- finite physical capacity → минимум один known bounded onsite pool;
- finite online capacity → отдельный online pool;
- unlimited channel обозначается явно;
- `any` не заменяет physical onsite guard;
- channel выбирается до или атомарно с будущим Booking;
- local preview показывает availability отдельно по onsite/online.

## 9. Mock availability projection

### 9.1 Snapshot port

Mock operational input не сохраняется в Event draft:

```text
EventInventorySnapshot
  eventId
  occurrenceId
  source: localMock
  authority
  capturedAtUtc
  expiresAtUtc?
  poolStates[]

InventoryPoolSnapshot
  poolId
  remaining?
  holdCount?
  registrationOpen
  providerStatus?
```

Snapshot immutable и доступен через domain repository port. Local datasource
использует fixtures/in-memory state и не обещает durability/authority.

### 9.2 Projection

```text
EventAvailabilityProjection
  state: available | lowAvailability | soldOut | waitlistAvailable |
         registrationClosed | cancelled | unknown | stale
  channelStates: Map<InventoryChannel, AvailabilityState>
  knowledge: known | unknown
  freshness: current | stale | unknown
  sourceDisclosure: localMock | none
```

Priority rules:

1. cancelled occurrence → cancelled;
2. missing/invalid source → unknown;
3. expired snapshot → stale, без fallback в available;
4. closed registration window → registrationClosed;
5. known snapshot remaining=0 → waitlistAvailable только при verified active
   waitlist support, иначе soldOut;
6. positive remaining → available/lowAvailability по versioned config threshold;
7. hybrid projection считается по каждому channel независимо.

ECL-02 projection предназначена для Creator preview/tests. Discover/Details не
должны выдавать её за production availability.

## 10. Cross-validation contract

Минимальные правила ECL-02:

1. openEntry требует registration none и confirmation none.
2. Optional interest при openEntry не создаёт Booking/inventory reservation.
3. External registration требует safe HTTPS handoff или provider ref, но
   provider-owned confirmation недоступна без readiness.
4. Internal registration отображается как future capability и не становится
   working Booking до ECL-03.
5. manualApproval допустим для internal application/booking.
6. lottery требует application window и auditable selection capability;
   ECL-02 сохраняет config, но publish fail closed.
7. providerManaged требует external registration и provider disclosure.
8. Waitlist требует finite inventory и authoritative lifecycle.
9. Unknown capacity/availability не становится zero/soldOut/available.
10. externalProvider требует provider ref + freshness.
11. assignedSeating требует provider hold capability.
12. multi-date/recurring operational config всегда occurrence-scoped.
13. hybrid finite physical inventory требует bounded onsite pool.
14. private access/secret eligibility остаются gated, raw secrets запрещены.
15. Current participants отсутствует в Creator commands.
16. Inventory pool totals не обещают transactional oversell protection.

Validation возвращает typed field/section/code/severity issues. Presentation не
содержит альтернативную compatibility matrix.

## 11. Schema v3 и migration

### 11.1 Persisted additions

```text
event_details.schemaVersion: 3
event_details.admission?: EventAdmissionDraft
event_details.inventory?: EventInventoryConfiguration
```

Availability snapshots/projections и selected preset ID не сохраняются в Event
draft.

### 11.2 Legacy read

| Existing value | Compatibility result | Automatic write |
|---|---|---|
| registrationMode=none | Suggest `openEntry + none + none` | Нет |
| registrationMode=external | Preserve external mode; admission/confirmation remain unconfirmed | Нет |
| registrationMode=internal | Preserve raw/typed mode; readiness blocked | Нет |
| capacityMode/capacity | Reuse declared capacity configuration | Только после explicit inventory command |
| common approvalRequired | Не выводить confirmation молча | Нет |
| common waitlistEnabled | Не создавать waitlist policy | Нет |
| bookingLink | Existing externalBookingUrl compatibility only | Не создаёт provider/Booking authority |
| unknown/newer fields | Preserve raw; fail closed | Нет downgrade write |

Unrelated autosave v2 draft не повышает schema. Schema v3 записывается после
explicit normalized admission/inventory command. Suggestions transient и не
попадают в JSON до подтверждения.

### 11.3 Deterministic write

- enum sets сохраняются в canonical order;
- pools сортируются stable display order/id без изменения identity;
- `loc_*` pool/rule IDs заменяются permanent IDs только общим publish pipeline;
- unknown fields сохраняются;
- mapper не материализует availability snapshot/current participants;
- envelope schema повышается только при доказанной необходимости.

## 12. Template contract

Reusable после explicit confirmation:

- admission/registration/confirmation axes;
- public non-sensitive eligibility rule kinds/explanations;
- guest/onsite/interest configuration;
- capacity mode и provider-neutral inventory shapes/pool templates;
- channel binding;
- waitlist configuration как disabled template preference, без active state.

Всегда strip/re-default:

- PublisherRef по правилам ECL-01;
- occurrence-specific IDs/overrides;
- provider refs/freshness/snapshots;
- remaining/holds/current participants;
- access codes, allowlists, membership identities, waiver answers;
- Booking/Payment/Attendance data;
- external URLs и unknown fields;
- active capability/readiness status.

Materialization создаёт новые pool/rule `loc_*` IDs и повторно валидирует
hybrid/capability requirements.

## 13. Application/presentation contract

```text
EventAdmissionSectionState
  selectedPreset?
  normalizedAdmission
  capabilityDisclosures[]
  issues[]
  impactPreview?

EventInventorySectionState
  configuration
  poolRows[]
  channelSummary
  availabilityPreview
  issues[]

Commands
  previewAdmissionPreset
  applyAdmissionPreset
  updateAdmissionAxis
  updateEligibility/guest/onsite/interest
  updateCapacityMode
  selectInventoryAuthority/shapes
  add/update/remove/reorderInventoryPool
  refreshMockAvailabilityPreview
  confirmConfigurationImpact
```

Application:

- нормализует preset через use case;
- проверяет draft revision/capability readiness;
- применяет одну atomic command/revision/autosave;
- получает mock snapshot только через repository port;
- project availability через domain use case;
- не создаёт Booking/hold/currentParticipants.

Presentation:

- отображает typed state/disclosures;
- не суммирует pools и не считает remaining;
- не решает cross-axis compatibility;
- не читает datasource/JSON;
- не показывает local mock как live/confirmed;
- вызывает только controller commands.

## 14. Exact file plan

Фактический plan повторно подтверждается перед runtime implementation после
ECL-01 Done.

### Add

| Файл | Назначение |
|---|---|
| `domain/entities/event_admission.dart` | Admission axes и secretless policies |
| `domain/entities/event_inventory.dart` | Authority, shapes, pools и channels |
| `domain/entities/event_availability_projection.dart` | Snapshot/projection value objects |
| `domain/repositories/event_inventory_snapshot_repository.dart` | Read-only local/mock snapshot port |
| `domain/usecases/normalize_event_admission_preset_usecase.dart` | Preset → canonical axes |
| `domain/usecases/validate_event_access_configuration_usecase.dart` | Cross-axis validation |
| `domain/usecases/project_event_availability_usecase.dart` | Deterministic projection |
| `data/datasources/event_mock_inventory_datasource.dart` | Explicit local/mock fixtures |
| `data/repositories/event_inventory_snapshot_repository_impl.dart` | Port implementation |
| `application/event_admission_section.dart` | Declarative config/state/commands |
| `application/event_inventory_section.dart` | Declarative config/state/commands |
| `presentation/widgets/event_admission_section.dart` | Presentation-only admission UI |
| `presentation/widgets/event_inventory_section.dart` | Presentation-only inventory UI |
| `presentation/widgets/event_availability_preview.dart` | Honest local/mock projection UI |
| `test/unit/event_admission_test.dart` | Axes/presets/policy validation |
| `test/unit/event_inventory_test.dart` | Shapes/pools/channels/hybrid rules |
| `test/unit/event_availability_projection_test.dart` | Projection priority/freshness |
| `test/unit/event_access_migration_test.dart` | v2/v3/legacy/newer schema |
| `test/widget/event_admission_inventory_section_test.dart` | UI/accessibility/controller calls |

Пути выше относительны `apps/mobile/lib/features/create/` или
`apps/mobile/test/` согласно первой directory component.

### Modify

| Файл | Ограниченное изменение |
|---|---|
| `domain/entities/event_draft_data.dart` | Additive schema v3 admission/inventory fields |
| `data/models/event_draft_mapper.dart` | v2/v3 compatibility/unknown preservation |
| `domain/usecases/validate_event_draft_usecase.dart` | Compose access validator |
| `application/event_create_config.dart` | Declarative section placement/flags |
| `application/event_create_coordinator.dart` | Thin orchestration/delegation |
| `application/controllers/create_controller.dart` | Thin Event command delegation only |
| `application/create_providers.dart` / DI | Register local ports/use cases |
| `presentation/widgets/event_create_block.dart` | Compose typed sections only |
| `domain/usecases/manage_create_template_usecase.dart` | ECL-02 reusable/strip allowlist |
| `data/models/create_draft_model.dart` | Legacy adapter only if required |
| existing Event tests/support | schema v3 fixtures/regression |
| `AGENTS.md`, `LAUNCH_STATUS.md` | Только после green ECL-02E |

### Не изменять

- ADR, Category registry, Route/Scenario/Quick Plan domain;
- Booking/Payments/provider features;
- `packages/api_contracts`;
- Discover production models;
- generated files/assets.

Существующие `EventRegistrationMode` и `EventCapacityMode` переиспользуются или
перемещаются в один канонический domain source без изменения persisted enum
names. Дублирующие `Legacy*`/`Ecl*` enums запрещены.

## 15. Feature flags and rollback

```text
event_admission_configuration
event_mock_availability
```

Rollout:

1. domain/mapper compatibility enabled;
2. UI flags default off;
3. internal local/mock fixtures;
4. admission UI enable after migration gates;
5. mock availability enable separately after disclosure/accessibility tests.

Rollback:

- flags hide entry points/preview but mapper round-trips v3;
- v3 data не удаляются и не сворачиваются в legacy booleans;
- missing snapshot становится unknown, не available;
- disabling mock datasource removes preview source, not Event config;
- existing Publisher/classification/schedule/occurrence IDs не меняются;
- no Booking/Payment obligations exist in ECL-02.

## 16. Acceptance criteria

1. Все 6 admission, 3 registration и 5 confirmation values доступны в domain.
2. Preset сохраняется только как нормализованные независимые поля.
3. Open entry требует none/none; optional RSVP остаётся interest only.
4. Interest policy не создаёт Booking/reservation/My Bookings state.
5. External/provider-managed configuration fail closed без provider readiness.
6. Internal configuration не обещает working Booking до ECL-03.
7. Lottery config требует window и остаётся gated без auditable selector.
8. Eligibility хранит stable IDs/kinds и не хранит raw secrets/PII.
9. Guest count всегда потребляет capacity основного visitor flow.
10. Capacity known/unknown/unlimited сохраняет каноническую семантику.
11. Все 3 authorities и 10 shapes round-trip без сокращения.
12. Authority не смешивается с shape.
13. Pool IDs stable; известная capacity положительна.
14. Hybrid finite physical capacity требует bounded onsite pool.
15. `any` pool не заменяет onsite physical guard.
16. Assigned seating остаётся gated без hold API.
17. `currentParticipants` отсутствует в Creator input/commands/JSON additions.
18. Mock snapshot не хранится в Event draft.
19. Missing/expired snapshot даёт unknown/stale, не available.
20. Channel availability считается независимо.
21. SoldOut не меняет Event lifecycle.
22. v2 draft читается без automatic v3 write.
23. Legacy booleans/URL не создают admission/provider authority молча.
24. Unknown/newer fields сохраняются; downgrade fail closed.
25. Templates strip operational/authority/secret data и получают новые IDs.
26. `EventCreateBlock` не содержит validation/calculations/persistence.
27. Disabled flags сохраняют v3 read/round-trip без data loss.
28. Другие Create types сохраняют behavior.
29. UI проходит 360 dp / 150% text scale и non-color disclosures.
30. Analyzer, full tests, boundary и scoped diff — green без новых suppressions.

## 17. Required test matrix

| Layer | Обязательное доказательство |
|---|---|
| Domain admission | Cardinality, presets, interest, eligibility, guest/onsite, cross-axis rules |
| Domain inventory | 3 authorities, 10 shapes, pool IDs/capacity/channel/hybrid invariants |
| Projection | cancelled/unknown/stale/closed/soldOut/available priority and channels |
| Migration | v2 no-write, explicit v3 write, legacy ambiguity, unknown/newer/downgrade |
| Template | reusable config; operational/secret/authority strip; new pool IDs |
| Application | preview vs Apply, one revision/autosave, stale revision, flags, no mutations |
| Widget | presets/custom, pool editor, disclosures, 360 dp/150%, controller calls only |
| Regression | ECL-01 classification, Event schedule/pricing/templates/publish; all Create types |
| Repository | analyzer, full suite, boundary, diff/whitespace |

## 18. Canonical AC traceability

| Canon AC | ECL-02 result | Статус после ECL-02 |
|---:|---|---|
| 8 | Independent admission/registration/confirmation/eligibility/waitlist configuration | Local contract satisfied |
| 9 | Preset normalizes to separate canonical fields | Satisfied |
| 12 | Inventory authority separated from shapes/pools | Satisfied |
| 13 | External fields remain read-only and require freshness/provider readiness | Preserved; operational sync deferred ECL-04/05 |
| 14 | Missing/expired source projects unknown/stale | Local projection satisfied |
| 15 | SoldOut remains projection, not lifecycle | Satisfied |
| 16 | Creator cannot input current participants | Satisfied |
| 17 | No client overbooking promise or mutation | Preserved; authoritative proof deferred ECL-03/05 |
| 18 | Waitlist config cannot promote without atomic hold/TTL | Preserved; behavior deferred ECL-03 |
| 19 | Assigned seating remains blocked without hold API | Preserved; deferred ECL-08 |
| 25 | Unknown capacity/price/availability never becomes zero/free/available | Satisfied for ECL-02 scope |
| 30 | Local slice analyzer/tests/boundary/diff gates | Required by DoD |
| 31 | Production Booking/provider/payment remain separate slices/flags | Preserved |
| 32 | 360 dp / 150% and non-color disclosures | Required by AC 29 |
| 35 | Finite hybrid physical capacity has bounded onsite pool | Satisfied |
| 38 | Open-entry optional RSVP is interest only | Satisfied |
| 39 | Category/aggregate behavior unchanged | Regression-required |
| 41 | Uniform transactional Booking cap not stored in Event/config | Deferred ECL-03 |

Traceability не помечает deferred production AC как Done. ECL-02 доказывает
только local configuration/projection semantics и сохранение gates.

## 19. Risks and controls

| Риск | Control |
|---|---|
| UI выглядит как working Booking | Mandatory capability/local-mock disclosures; no Booking repo/entity |
| Capacity принимается за remaining | Separate config/snapshot/projection types and tests |
| Silent mapping legacy booleans | Transient suggestions + explicit normalized command |
| Unknown превращается в available | Projection priority tests and fail-closed defaults |
| Hybrid physical oversell assumption | Required bounded onsite pool; no transactional promise |
| Provider authority invented locally | External config non-publishable until ECL-04/05 |
| Widget monolith | Declarative section state and presentation-only tests |
| Template leaks operational data | Explicit allowlist/strip tests |
| ECL-03 scope creep | Booking/holds/reconfirmation/cap/notifications explicitly excluded |

## 20. Definition of Done

ECL-02 считается Done только когда:

- этот документ Approved до implementation;
- ECL-01 имеет статус Done;
- ECL-02A–E выполнены без scope expansion;
- AC 1–30 имеют automated evidence;
- schema v3 migration/rollback и templates проверены;
- mock availability честно маркирована и не является production promise;
- `EventCreateBlock` остаётся presentation-only;
- analyzer/full tests/boundary/diff зелёные;
- status docs отражают фактический результат;
- отсутствуют Booking, authoritative inventory mutation, provider sync,
  Payments, Firebase и новый Create type.

## 21. Completion evidence

Пользователь повторно подтвердил exact file plan командой `давай` до начала
runtime. ECL-02A–E реализованы 2026-08-08 в утверждённых границах:

- независимые admission/registration/confirmation axes, secretless policies,
  relative/absolute access windows и explicit preset/legacy normalization;
- 3 inventory authorities, все 10 shapes, stable pools, channel binding,
  capacity reconciliation и bounded onsite invariant для finite hybrid Event;
- immutable read-only local/mock snapshot port и deterministic projection с
  отдельными `unknown`, `stale`, `registrationClosed`, `soldOut` и channel
  states;
- schema v3 только после explicit admission/inventory command; schema v2 не
  повышается от autosave или ECL-01 classification; unknown/newer payload
  сохраняется и блокирует mutation/downgrade;
- templates strip PublisherRef, provider/operational/secret data, выключают
  active waitlist и создают новые rule/pool IDs при materialization/publish;
- два независимых rollback flags сохраняют v3 read/round-trip при скрытом UI;
- `EventCreateBlock` только компонует typed sections и controller callbacks;
- targeted ECL-01/ECL-02 regression: **62 passed**; финальная bounded ECL-02
  matrix после повторного аудита: **41 passed**;
- `flutter analyze --no-pub`: **0 issues**;
- полный `flutter test --no-pub`: **647 passed**;
- boundary check: passed с 59 прежними allowlist suppressions и без новых;
- `git diff --check`: passed; только существующие CRLF conversion warnings.

Booking entities/lifecycle, holds, waitlist promotion, reconfirmation,
transactional concurrency cap, provider sync, Payments, Firebase, production
Discover/API projection и assigned-seat interaction не добавлены. Эти
возможности остаются gated последующими ECL slices.
