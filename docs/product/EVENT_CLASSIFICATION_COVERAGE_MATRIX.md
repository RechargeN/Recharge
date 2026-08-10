# Event Classification v2.2.3 — cumulative runtime coverage matrix

- Версия аудита: 2026-08-09
- Статус: **ECL-00–ECL-03B Done; ECL-03C exact plan Review; runtime absent**
- Канон: [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md),
  Accepted v2.2.3, SHA-256
  `62EC444B74CD737AE8AEC9D5E140F31DD5E2660577D8D15940F180D54ED05BFB`
- Следующий gate: explicit acceptance of
  [ECL-03C exact plan](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md)
  plus post-stabilization backend and production Identity prerequisites;
  implementation is not yet authorized

## 1. Назначение и правила оценки

Матрица фиксирует фактическое состояние Event runtime после ECL-02 и отделяет
реализованную local configuration/mock projection от production authority.
Наличие enum, config, CTA или документа не доказывает Booking, inventory
mutation, provider sync, Payments либо backend capability.

Статусы:

- **I — Implemented:** каноническая семантика реализована в указанном scope и
  имеет прямое автоматическое покрытие;
- **P — Partial:** полезное подмножество реализовано, но полный канонический
  контракт ещё не обеспечен;
- **M — Missing:** требуемого typed runtime-контракта нет;
- **G — Gated:** поведение намеренно запрещено до отдельного Approved gate;
- **M/G — Missing and gated:** runtime отсутствует и не должен появляться без
  production/backend/provider/Payments readiness;
- **D — Docs/process:** governance requirement, не runtime capability.

`I` относится только к описанному contract surface. Например, implemented
inventory configuration не означает implemented authoritative ledger.

## 2. Проверенная фактическая база после ECL-02

| Слой | Фактический источник | Что подтверждено |
|---|---|---|
| Domain/classification | `event_classification.dart` | 34 archetypes, 17 participation modes, physical facets, PublisherRef-compatible classification |
| Domain/admission | `event_admission.dart` | 6 admission, 3 registration, 5 confirmation modes; eligibility, guest, onsite, interest, windows, waitlist configuration, presets |
| Domain/inventory | `event_inventory.dart` | 3 authorities, 10 shapes, stable pools and onsite/online/any channels |
| Domain/projection | `event_availability_projection.dart` | Immutable local/mock snapshot and explicit unknown/stale/closed/soldOut states |
| Validation | `validate_event_classification_usecase.dart`, `validate_event_access_configuration_usecase.dart` | Aggregate/classification/access/config cross-axis invariants and fail-closed readiness |
| Application | typed Event section definitions/state plus `event_create_coordinator.dart` | Declarative classification/admission/inventory state and controller command orchestration |
| Data | `event_draft_mapper.dart` | Additive schema v2/v3, legacy/no-silent-write behavior, unknown/newer round-trip and downgrade guard |
| Templates | `manage_create_template_usecase.dart` | Publisher/authority/provider/operational/secret stripping and regenerated relation/rule/pool IDs |
| Presentation | split Event classification/admission/inventory widgets | Presentation-only typed rendering, 360 dp/150% coverage; `EventCreateBlock` remains compositor |
| Availability data | local mock snapshot datasource/repository | Read-only fixtures; no ledger, mutation or production promise |
| Contracts | `packages/api_contracts` | ECL-03B: JSON Schema v1 source, closed wire vocabulary, immutable fixture-verified Dart DTOs, valid/invalid/forward fixtures; no client/backend |
| Booking domain | `features/booking/domain` | Immutable Booking/Hold/policy/failure/action projections plus pure fail-closed validation/readiness/transition use cases; no repository or command execution |
| Backend | absent | No Firebase Functions/Rules/transactions/scheduler/notification delivery |
| Discover | no production Event operational projection | No authoritative channel availability or material-revision return flow |

Completion evidence recorded in ECL-02: analyzer 0 issues, full Flutter suite
647 passed, boundary gate passed with 59 existing suppressions and no new
violation, diff/whitespace passed.

## 3. Canon to runtime coverage

| Canonical block | Status | Current coverage | Remaining owner/gate |
|---|:---:|---|---|
| Event aggregate boundaries | I | Typed boundary resolver/tests preserve Event vs adjacent aggregates | New aggregate decisions remain separate ADR/spec |
| Required future occurrence | P | Publish validation/materialization require future occurrence | Discover exclusion/material revision return remains separate |
| 34 archetypes | I | Closed enum, validation, UI, mapper, tests | Dictionary revision only through canon |
| Participation modes | I | 17-value dictionary; primary + max 3 secondary | - |
| Category System v1.4.3 | I | Canonical 28 groups/530 registry and Event applicability tests | Future Category revisions |
| Archetype/category/access/pricing independence | I | Separate fields and cross-axis tests | - |
| Format/schedule | I | offline/online/hybrid, physical facets, one/multi/recurring, DST/occurrences | Edit scopes/material revision not complete |
| Location/online access | P | Existing typed Event subset and fail-closed protected/provider settings | Full place/venue/area/protected-reference contract |
| PublisherRef | I | Shared typed user/page ref, new-draft default and non-rewrite behavior | Production authority waits for Identity backend |
| Admission axes/presets | I | Independent normalized local configuration | Authoritative internal behavior ECL-03; provider ECL-04/05 |
| Eligibility/guest/onsite/interest/windows | I | Typed secretless configuration and validation | Server evaluation for ECL-03 supported subset |
| Waitlist configuration | I | Finite/readiness config; automatic lifecycle fail closed | ECL-03 authoritative queue/hold/TTL |
| Waitlist lifecycle | M/G | No Booking/hold/promotion | ECL-03 + Accepted ADR/backend |
| Attendance/reconfirmation | M/G | Config reserved; no scheduler/release | ECL-03 |
| Uniform Booking concurrency policy | M/G | Correctly absent from Event draft | ECL-03 backend platform-policy catalog |
| Capacity mode | I | known/unknown/unlimited canonical configuration | - |
| Inventory authority/shapes/pools/channel | I | 3 authorities, all 10 shapes, stable channel pools | Recharge ledger ECL-03; provider ECL-05; seating ECL-08 |
| Availability projection | P | Honest deterministic local/mock projection | Authoritative projection ECL-03/05 |
| Pricing/payment | P | Free/fixed and separated collection baseline | ticket/donation/internal payments ECL-07 |
| Money | I | Minor units + currency in Event contract | Legacy common double projection remains migration debt |
| Audience requirements | P | Existing age/family/pets/amenities subset | Full sensitive-policy governance deferred |
| Event relations/unlinked credits | M | Not in current bounded runtime | Separate approved Event relations scope |
| Lifecycle/moderation/visibility | P | Create lifecycle and public/unlisted baseline | Occurrence operational/material revision projection |
| Auxiliary admission tracks | M/G | No track/Booking/ledger runtime | ECL-03 supported application subset |
| Program Items | M/G | Absent | ECL-06 |
| Source/provenance/provider authority | M/G | External config fails closed | ECL-04/05 |
| Duplicate/merge provenance | M/G | Absent | Provider/dedup approved slice |
| Secrets boundary | P | Secret-like draft values rejected; no production secret store | Protected refs/backend security gate |
| Additive migration | I | v1/v2/v3 compatibility, explicit write, unknown/newer preservation | v4 only through approved ECL-03 config |
| Declarative Event Create | I | Typed sections and renderer-only widgets | Continue preventing Booking logic in Create |
| Accessibility | I | ECL-01/ECL-02 360 dp and 150% text-scale tests | Production Booking screens need own matrix |
| API contracts | P | Booking v1 schemas/DTO/fixtures implemented; no client, backend consumer or network mapping | ECL-03C backend contract consumer; ECL-03G mobile integration |
| Production backend | M/G | No backend module | Accepted ADR 0019; executable post-stabilization gate still required |
| Localization en/ru/lv | M/G | No `lib/l10n` | Separate localization slice; production copy blocked |

## 4. Coverage всех 43 canonical acceptance criteria

| AC | Статус | Доказательство / точный разрыв |
|---:|:---:|---|
| 1 | I | Event has one confirmed archetype and one typed PublisherRef. |
| 2 | I | Category System v1.4.3 remains the single thematic registry. |
| 3 | I | Archetype, category, access and pricing remain independent. |
| 4 | I | Typed boundary resolver/tests cover canonical adjacent aggregates. |
| 5 | I | Series remains one Event with recurrence/occurrences. |
| 6 | I | All-day is bool; multi-day is occurrence duration. |
| 7 | P | Publish requires a future occurrence; production Discover projection is absent. |
| 8 | I | Admission/registration/confirmation/eligibility/waitlist are independent typed fields. |
| 9 | I | Presets normalize to separate canonical axes only after explicit Apply. |
| 10 | P | Current pricing does not encode deposit/membership/display; complete pricing contract is deferred. |
| 11 | I | Payment collection remains separate from pricing. |
| 12 | I | Inventory authority is separate from shapes and pools. |
| 13 | M/G | Provider-owned/freshness operational model requires ECL-04/05. |
| 14 | P | Local availability unknown/stale is honest; full price/provider projection remains gated. |
| 15 | I | SoldOut is a projection, never Event lifecycle. |
| 16 | I | Creator cannot enter authoritative participant count; snapshots are read-only. |
| 17 | M/G | No authoritative inventory transaction; ECL-03/05. |
| 18 | M/G | Waitlist promotion/hold/TTL absent; ECL-03. |
| 19 | M/G | Assigned seating remains non-selectable; ECL-08. |
| 20 | M | Full routeRef/location relation contract remains absent. |
| 21 | M | Event relations/unlinked credits remain absent. |
| 22 | P | Exactly one PublisherRef exists; full co-organizer relation model is absent. |
| 23 | M/G | Provider import is absent. |
| 24 | M/G | DuplicateCandidate/merge is absent. |
| 25 | M/G | Source provenance after merge is absent. |
| 26 | P | Scraping is prohibited but production source-policy enforcement is absent. |
| 27 | P | Secret-like local fields fail closed; protected backend references are absent. |
| 28 | I | Legacy/newer Event reads without mandatory migration write. |
| 29 | I | Active workspace does not rewrite existing PublisherRef. |
| 30 | I | ECL-01/ECL-02 passed analyzer/full tests/boundary/diff gates. |
| 31 | P | Independent local flags exist; production Booking/provider/payment kill switches are pending. |
| 32 | I | ECL-01/ECL-02 typed UI has 360 dp/150% and non-color disclosure evidence. |
| 33 | M/G | Reconfirmation/atomic auto-release absent; ECL-03. |
| 34 | M/G | Discover direct-link/completed/cancelled projection absent. |
| 35 | I | Finite hybrid config requires bounded onsite pool and channel projection. |
| 36 | M/G | Auxiliary tracks/shared authoritative ledger absent; ECL-03. |
| 37 | P | No Announcement Create type; external discovery candidate model absent. |
| 38 | I | Open-entry interest remains non-Booking/non-reserving configuration. |
| 39 | I | Full Category registry is Event-applicable without aggregate inference. |
| 40 | M/G | Material revision/moderation before Discover return is absent. |
| 41 | M/G | Transactional uniform concurrency cap absent; ECL-03. |
| 42 | D | Deferred decisions retain IDs/owners/artifact gates and add no runtime. |
| 43 | I | §1.2 boundary priority is represented by canonical resolver/tests. |

Current total after ECL-02: **20 I, 8 P, 2 M, 12 M/G, 1 D**.
Production Booking remains zero despite the increase in implemented local
classification/configuration coverage.

## 5. ECL-03 readiness matrix

| Required capability | Current state | Runtime gate |
|---|---|---|
| Approved ECL-03 spec | Approved v1.1 | ECL-03A Done; staged implementation only |
| Backend architecture ADR | ADR 0019 Accepted | Physical creation only in Approved executable stage |
| D01–D10 decision package | Accepted and normative | External readiness proof still required where specified |
| Backend module | Absent | Accepted target; post-stabilization implementation gate |
| Production Viewer Auth | Mock only | IDP production/Firebase gate |
| Creator/Page Booking capability | Local preview only | Server-owned exact scope |
| Booking API schemas | Implemented in ECL-03B | Shared schema/fixture source; backend consumer still absent |
| Pure Booking domain | Implemented in ECL-03B | No application/data/presentation or command execution |
| ECL-03C exact plan | Review v1.0 | Docs/file plan only; external authorization and Identity/Platform prerequisites remain |
| Atomic inventory ledger | Absent | Trusted backend transaction |
| Idempotency store | Absent | Backend contract + retention |
| Uniform cap policy catalog | Docs only | Approved version/value/counting rule |
| Waitlist hold/scheduler | Absent | Transaction + worker proof |
| Reconfirmation delivery | Absent | Verified notifications + scheduler |
| Retention/privacy table | Product values accepted | Privacy/Legal validation before activation |
| Security Rules tests | Absent | Emulator suite |
| Reconciliation/runbooks | Absent | Operations gate |

Conclusion: ECL-03A and bounded ECL-03B are Done. ECL-03C now has a bounded
production-grade exact plan, but ECL-03 runtime remains correctly absent. No
missing implementation, authorization or activation gate can be replaced by
Flutter-only code, emulator evidence or mock data.

## 6. Automated evidence map

| Existing suite | What it proves | What it does not prove |
|---|---|---|
| Event classification tests | 34/17 dictionaries, boundaries, independent axes | Booking authority |
| Event admission tests | presets, policies, windows, fail-closed readiness | server eligibility/action |
| Event inventory tests | authorities/shapes/pools/channels/hybrid config | ledger atomicity/oversell |
| Availability projection tests | unknown/stale/closed/soldOut priority | production freshness |
| Migration tests | v1/v2/v3 explicit write and unknown/newer safety | Booking schema/backend migration |
| Controller/widget tests | typed commands, flags, 360 dp/150% | authoritative confirmation |
| Template tests | authority/secret/operational strip and new IDs | Booking obligations |
| Contract package suite (9) | Booking schemas/DTO/fixtures and fail-closed compatibility | backend consumer/runtime |
| Full Flutter suite (659) | local repository regression through ECL-03B pure domain | Firebase/backend/security/load |

## 7. Audit conclusion

ECL-01 and ECL-02 provide a strong compatible local foundation: canonical
classification, PublisherRef, admission/inventory configuration and honest
mock availability. They intentionally do not provide internal Booking.

The next safe step is explicit review of the ECL-03C exact plan. Physical
backend work may start only after the post-stabilization authorization and
applicable Identity/Platform prerequisites are approved; network mutations,
production activation, notification delivery, retention and operations proof
remain separately gated. Until then, the public product must continue using
honest external handoff or explicitly unavailable/internal-coming-later states
rather than local confirmation.
