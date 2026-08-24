# ECL-03 — Internal free registration and authoritative Booking

- Версия: 1.2
- Дата: 2026-08-20
- Статус: **Approved — implementation contract; production activation gated**
- Канон: [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md),
  Accepted v2.2.3
- Предыдущий обязательный slice:
  [EVENT_CLASSIFICATION_ECL_02_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_02_SLICE_SPEC.md),
  Done
- Architecture proposal:
  [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md), Accepted
- Decision recommendations:
  [EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md),
  Accepted D01–D11 / normative
- Runtime boundary: production/backend; local/mock confirmation запрещена

## 1. Решение и цель

ECL-03 создаёт provider-neutral внутреннюю бесплатную регистрацию Recharge с
авторитетным Booking lifecycle и атомарным inventory ledger.

Slice должен поддержать:

- free internal RSVP/booking/application;
- instant confirmation и manual approval;
- occurrence- и pool-bound Booking;
- атомарное резервирование/освобождение capacity;
- idempotent create/cancel/approve/reconfirm commands;
- organizer-managed и FIFO waitlist;
- ограниченный waitlist hold с TTL;
- cancellation deadlines и reason codes;
- reconfirmation и atomic auto-release;
- единый versioned concurrency cap;
- in-app/push notification outbox и delivery evidence;
- application-based auxiliary admission tracks;
- Viewer My Bookings и Creator management surfaces;
- kill switches, reconciliation, audit и rollback без потери обязательств.

ECL-03 не может быть реализован только во Flutter. ADR 0019 и этот contract
приняты, но production Auth/identity authority, executable backend slice,
notification readiness и exact ECL-03B plan остаются runtime gates. Локальная
кнопка, запись в device storage или mock snapshot не считаются Booking и не
могут отображаться как confirmed.

## 2. Approval и dependency gate

Пользователь 2026-08-08 сначала одобрил ECL-03A documentation package, затем
после представления единого D01–D10 package дал команду продолжать. ADR 0019,
D01–D10 и этот implementation contract приняты без runtime claims.

До ECL-03B code обязательны:

1. отдельная ECL-03B spec содержит bounded contracts/domain scope;
2. exact ECL-03B file plan повторно подтверждён пользователем;
3. API schema/codegen workflow согласован с ADR 0019;
4. все mutation/network/DI/UI flags отсутствуют или выключены.

До backend wiring/production activation дополнительно обязательны:

1. утверждён executable post-stabilization Firebase/backend slice;
2. production Auth Viewer и server-owned user identity доступны;
3. verified Creator/Page authority и `manage_bookings` enforceable backend;
4. deployment environments, regions и service identities проверены;
5. notification delivery и scheduled-worker ownership проверены;
6. retention/deletion table прошла Privacy/Legal validation;
7. emulator/staging/security/operations gates соответствующего этапа зелёные.

Если любой gate не выполнен, допустимы только документы, schemas/examples без
runtime wiring и read-only audits. Нельзя добавлять fake confirmed Booking,
local inventory ledger или UI, который обещает работающую регистрацию.

## 3. Непересматриваемые инварианты

1. Booking, Hold, Audit и Notification — отдельные сущности, не поля Event.
2. Booking всегда ссылается на stable Event и occurrence IDs.
3. Finite allocation ссылается на stable inventory pool ID и channel.
4. Клиент не является authority для Booking state или remaining inventory.
5. Capacity изменяется только trusted atomic transaction.
6. Oversell, процентное overbooking и last-write-wins запрещены.
7. Failure не создаёт partial Booking/hold и не меняет ledger.
8. Один idempotency key не может потребить capacity дважды.
9. Waitlist без active hold не занимает capacity и не считается в cap.
10. Pending application не занимает capacity до atomic approval/offer.
11. Guest units резервируются вместе с основным участником.
12. Hold — бесплатная временная allocation, не Payment/deposit.
13. Reconfirmation auto-release — cancellation reason, не новый lifecycle.
14. Concurrency cap — uniform platform policy, не поле Event/пользователя.
15. Cap проверяется в той же transaction до inventory mutation.
16. Unknown/stale/offline не превращаются в confirmed/available.
17. Backend time является единственным временем для deadlines/TTL.
18. External provider authority не моделируется ECL-03.
19. Paid flow не маскируется как free registration.
20. Никаких reliability score, no-show profile или personal overrides.
21. Auxiliary capacity использует pool общего ledger, не второй счётчик.
22. Private/secret values отсутствуют в Flutter logs/analytics/projection.
23. Rollback не удаляет существующие Booking/holds/audit obligations.
24. Presentation только отображает typed state и вызывает commands.
25. Feature modules не импортируют друг друга напрямую.

## 4. Scope

### 4.1. Входит

Основной admission flow:

- `pricingMode=free`;
- `paymentCollectionMode=none`;
- `registrationMode=internal`;
- `admissionMode=rsvp | booking | application`;
- `confirmationMode=instant | manualApproval`;
- `inventoryAuthority=recharge` для finite capacity;
- known finite capacity либо explicit unlimited registration;
- onsite/online/hybrid pool/channel binding из ECL-02;
- guest policy с capacity accounting;
- registration/application windows;
- supported secretless eligibility evaluation;
- user cancel и organizer cancel/reject;
- occurrence cancellation/reschedule effects;
- waitlist configuration `organizerManaged | fifoAutomatic`;
- attendance/reconfirmation policy;
- versioned uniform Booking concurrency policy;
- application-based internal auxiliary admission tracks;
- authoritative availability projection из ledger;
- My Bookings и Creator management;
- transactional notification outbox;
- API, persistence, security, telemetry и operations.

### 4.2. Явно не входит

- `pricingMode=fixed | ticketTypes | donation` для internal collection;
- Payments, PSP, KYC/KYB, refunds, disputes, payouts;
- денежный deposit/card authorization hold;
- external registration/provider handoff (ECL-04);
- provider Booking mirror/sync (ECL-05);
- Program Items (ECL-06);
- paid tickets/check-in/QR/Attendance proof (ECL-07);
- assigned seating/seat selection (ECL-08);
- `confirmationMode=lottery | providerManaged`;
- `admissionMode=ticket | teamRegistration`;
- public open-entry interest/reminder flow;
- onsite sales и cash collection;
- staff workforce/access credentials outside visitor Booking;
- personalized risk/no-show/reliability decisions;
- creator-editable participant counters;
- offline mutation queue that claims capacity;
- production provider secrets or scraping;
- new Create type.

### 4.3. Bounded launch profile

Первый launch profile ограничивается:

```text
region: Latvia
currency relevance: none (free only)
registration: authenticated internal
confirmation: instant | manualApproval
inventory: generalCapacity and existing finite channel pools
waitlist: organizerManaged | fifoAutomatic
notifications: verified in-app plus approved delivery channel
```

Остальные ECL-02 inventory shapes round-trip и остаются configuration-only,
пока отдельный ECL-03 extension не докажет их allocation semantics.
Наличие enum не является runtime capability.

## 5. Delivery decomposition

### ECL-03A — Contract and architecture gate

- эта slice-spec;
- Proposed/Accepted ADR 0019;
- current coverage/readiness matrix;
- state machine и transaction contract;
- API/security/retention/operations plan;
- no runtime/schema/API generated code.

### ECL-03B — Shared contracts and Booking domain

- language-neutral API schemas;
- Dart/TypeScript compatibility fixtures;
- Booking/Hold/command/result/platform-policy contracts;
- pure state-transition and validation use cases;
- no enabled network commands until backend gate.

### ECL-03C — Authoritative transaction core

- create/cancel/get/list Booking;
- server Booking/Audit/idempotency operational records;
- pool ledger and user usage records;
- idempotency;
- Auth/Rules/capability enforcement;
- instant confirmation and finite/unlimited paths;
- emulator concurrency evidence.

### ECL-03D — Approval and waitlist

- submit application;
- approve/reject;
- organizer/FIFO promotion;
- active hold, accept/decline/expiry;
- next promotion and duplicate-worker safety.

### ECL-03E — Reconfirmation and notifications

- reconfirmation scheduler;
- open/deadline notifications;
- Reconfirm command;
- missed-deadline cancel/release/promote;
- outbox/delivery retry and retention.

### ECL-03F — Concurrency policy and auxiliary tracks

- versioned counting-rule catalog;
- transactional uniform cap;
- auxiliary application links/forms;
- shared-ledger auxiliary pools;
- private management projection.

### ECL-03G — Mobile integration and rollout

- Booking feature layers;
- Event Details CTA/projection;
- Profile/My Bookings;
- Creator management;
- Notifications/deep links;
- Create config additions through typed sections;
- staged enablement and rollback.

### ECL-03H — Production proof

- security, emulator, staging, load and chaos/retry suites;
- observability and reconciliation;
- incident/rollback/data-repair runbooks;
- accessibility/localization evidence;
- full repository gates and status reconciliation.

Каждый этап получает собственный AC subset и не может объявить общий ECL-03
Done до завершения ECL-03H.

## 6. Canonical aggregates

### 6.1. Booking

```text
Booking
  id: ULID
  schemaVersion: 1
  revision: integer
  userId
  eventId
  occurrenceId
  inventoryPoolId?
  channel?: onsite | online | any
  auxiliaryTrackId?
  admissionMode: rsvp | booking | application
  confirmationMode: instant | manualApproval
  state: pending | confirmed | cancelled | expired | waitlisted
  participantUnits: positive integer
  namedGuests[]?
  eligibilitySnapshotRef?
  activeHoldId?
  reconfirmationState: notRequired | notOpen | required | confirmed | missed
  terminalReason?
  createdAt
  updatedAt
  confirmedAt?
  cancelledAt?
  expiredAt?
```

Rules:

- `participantUnits = 1 + capacity-counting guests`;
- named guest PII is private and bounded;
- Event title/publisher display may be cached only as presentation snapshot;
- Booking truth resolves by IDs and revision;
- `pending` is an application awaiting organizer decision;
- `waitlisted` has no allocation unless `activeHoldId` resolves to active;
- `confirmed` finite Booking owns confirmed ledger units;
- terminal states cannot return to active without a new Booking command;
- occurrence ID is mandatory even for one-time Event.

### 6.2. BookingHold

```text
BookingHold
  id: ULID
  bookingId
  userId
  occurrenceId
  inventoryPoolId
  units
  kind: waitlistOffer
  state: active | accepted | declined | expired | released
  createdAt
  expiresAt
  resolvedAt?
  revision
```

Only `active` holds consume inventory and concurrency usage. Transition out of
`active` is monotonic and atomic with allocation/usage changes.

### 6.3. InventoryPoolLedger

```text
InventoryPoolLedger
  occurrenceId
  poolId
  channel
  capacity
  confirmedUnits
  activeHoldUnits
  revision
  updatedAt
```

Invariant:

```text
0 <= confirmedUnits
0 <= activeHoldUnits
confirmedUnits + activeHoldUnits <= capacity
```

Host/offline quota is represented by an explicit separate pool, never an
untracked subtraction or second mutable counter inside the visitor pool.
Derived `availableUnits` is not stored as a second mutable truth unless
transaction tests prove exact consistency.

### 6.4. UserBookingUsage

```text
UserBookingUsage
  userId
  policyVersion
  countingRuleRef
  activeAllocationCount
  activeAllocationIds[] or equivalent bounded index
  revision
  updatedAt
```

Exact storage form is selected for transaction limits and scale, but the
semantic record must prove which allocations are counted. A naked counter
without repairable evidence is insufficient. One confirmed Booking or one
active hold counts as one allocation regardless of guest/participant units;
the same Booking can never contribute both at once.

### 6.5. BookingAuditEvent

```text
BookingAuditEvent
  id
  bookingId
  sequence
  eventType
  actorType: user | creator | system | admin
  actorId?
  reasonCode?
  requestId
  correlationId
  occurredAt
  metadataAllowlist
```

Audit is append-only, contains no access secret and has a versioned retention
class. Ordinary analytics receives enums/counts, not participant identity or
free text.

### 6.6. BookingNotificationOutbox

```text
BookingNotificationOutbox
  id
  bookingId
  userId
  kind
  deliveryKey
  availableAt
  state: pending | delivering | delivered | failed | deadLetter
  attemptCount
  lastAttemptAt?
  deliveredAt?
```

Outbox creation is atomic with the Booking transition. Delivery is at-least-
once internally and user-visible deduplication uses `deliveryKey`.

## 7. Booking state machine

### 7.1. Initial transitions

| Flow | Preconditions | Result |
|---|---|---|
| Instant, available | Valid command; capacity/cap pass | `confirmed` + allocation |
| Instant, full + waitlist | Valid; waitlist open | `waitlisted`, no allocation |
| Instant, full, no waitlist | Valid | typed `sold_out`, no Booking |
| Manual application | Valid application window | `pending`, no allocation |
| Unlimited internal RSVP | Valid; explicit unlimited | `confirmed`, no finite allocation/cap count |

### 7.2. Allowed transitions

```text
pending -> confirmed
pending -> waitlisted
pending -> cancelled(applicationRejected | userCancelled | organizerCancelled)

waitlisted -> confirmed          # only through accepted active hold
waitlisted -> cancelled          # user/organizer/occurrence/offer declined
waitlisted -> expired            # offer expired

confirmed -> cancelled           # user/organizer/occurrence/missedReconfirmation

active hold -> accepted | declined | expired | released
```

`cancelled` and `expired` are terminal. A retry returns the previous result;
it never reopens a terminal Booking. Rejoining creates a new Booking ID subject
to duplicate-active and policy checks.

### 7.3. Duplicate-active invariant

Для `(userId, occurrenceId, admission track)` одновременно допустим максимум
один non-terminal Booking. Repeated create with a new idempotency key returns typed
`already_active` and current authorized projection; it does not create another
Booking or consume capacity.

## 8. Authoritative transaction contract

Every capacity-changing command runs in one trusted transaction or an
equivalent serializable operation with the following order:

1. resolve actor from verified server auth;
2. load idempotency record;
3. load Event operational projection and occurrence;
4. verify lifecycle, cancellation and material revision;
5. verify internal-free ECL-03 capability flag;
6. verify visibility/eligibility/access window;
7. validate participant units and guest policy;
8. resolve exact pool/channel and ledger revision;
9. resolve platform policy version/counting rule;
10. load user usage evidence;
11. reject duplicate active Booking;
12. check concurrency cap before allocation;
13. check capacity before allocation;
14. write Booking/Hold/ledger/usage/audit/outbox/idempotency atomically;
15. return a typed response with authoritative server time/revisions.

No preflight UI check is authoritative. A preflight response may improve UX,
but final command repeats every condition inside the mutation transaction.

### 8.1. Optimistic conflicts

Conflict/retry behavior is bounded. The backend retries transaction contention
according to versioned operational policy, then returns typed `contention`
without partial writes. The mobile application may offer Retry with the same
idempotency key and semantic payload; a new request ID may be used only for
correlation of the retry attempt.

### 8.2. Server time

Backend time decides:

- registration/application window;
- cancellation deadline;
- hold expiry;
- reconfirmation open/deadline;
- future occurrence eligibility.

Device clock may render a countdown but cannot authorize a mutation.

## 9. Idempotency

Each mutation request contains:

```text
requestId: ULID
idempotencyKey: opaque required ID
commandType
actorId (from auth, never trusted from body)
resourceId
expectedRevision?
payloadHash
```

Rules:

- effective key is `(resolvedActorOrServiceIdentity, commandType,
  idempotencyKey)`;
- `requestId` correlates one attempt; `idempotencyKey` identifies the logical
  mutation, and equality is optional;
- same effective key and same hash returns original result even when a retry
  has a new request ID; the semantic outcome is stable while response echo uses
  the current attempt request ID;
- a new attempt generates a fresh request ID; known reuse with another logical
  key/semantic command is invalid and creates no mutation;
- same key with different payload returns `idempotency_conflict`;
- failed validation may be cached only according to explicit contract;
- transient infrastructure failures do not claim success;
- scheduled workers use deterministic operation keys;
- outbox delivery uses a separate stable delivery key;
- retention exceeds the maximum client retry/offline response-cache window.

## 10. Uniform concurrency cap

```text
PlatformBookingConcurrencyPolicy
  schemaVersion
  policyVersion
  scope: internalCapacityHoldingBookings
  maxConcurrentBookings: positive integer
  appliesUniformly: true
  countingRuleRef
  effectiveFrom
  effectiveUntil?
```

The versioned counting-rule catalog defines at minimum:

```text
active_confirmed_and_holds_v1
  count confirmed finite-capacity Booking
  count active waitlist holds
  do not count waitlist without hold
  do not count pending application
  do not count unlimited RSVP
  stop counting atomically on cancel/expiry/release/completion boundary
```

The exact treatment of occurrence completion/grace period is versioned and
must be testable with a fake backend clock. Policy changes never silently
cancel existing Booking. If a new lower cap makes current usage exceed the
limit, existing allocations remain valid and only new allocation is blocked.

UI shows the applicable limit and typed refusal reason before confirmation,
but final enforcement stays transactional.

## 11. Main free-registration flows

### 11.1. Instant finite Booking

1. Viewer selects channel/pool and guest count.
2. Client requests non-authoritative preview.
3. Viewer explicitly confirms.
4. Backend transaction checks all invariants.
5. Response is `confirmed`, `waitlisted` or typed rejection.
6. UI never displays confirmed before step 5.

### 11.2. Manual application

1. Viewer submits bounded typed application fields.
2. Booking becomes `pending`; no capacity is reserved.
3. Creator with exact publisher capability reviews it.
4. Approve transaction rechecks occurrence/window/pool/capacity/user cap.
5. If available, Booking becomes confirmed.
6. If full and waitlist enabled, it becomes waitlisted.
7. Reject becomes terminal cancellation reason `applicationRejected`.

Creator cannot force oversell or bypass platform cap. Any administrative
override requires a separate future policy/ADR and is absent in ECL-03.

### 11.3. Unlimited RSVP

An explicit unlimited internal RSVP may create confirmed Booking without a
finite allocation. It does not contribute to availability remaining or the
capacity-holding cap. Unknown capacity is not treated as unlimited.

## 12. Waitlist and holds

### 12.1. Ordering

FIFO ordering uses authoritative `(joinedAt, bookingId)` ordering. Organizer-
managed mode records the selected Booking and actor in audit. Neither mode may
skip eligibility or policy revalidation at promotion time.

### 12.2. Promotion

Promotion transaction:

1. obtains one pool-scoped lease/serialization key;
2. verifies available units and candidate state;
3. revalidates eligibility, occurrence and requested units;
4. checks concurrency cap;
5. creates one active hold;
6. increments ledger active-hold units and user usage;
7. writes audit/outbox/idempotency;
8. preserves Booking as waitlisted until offer acceptance.

### 12.3. Offer acceptance

Acceptance verifies the hold is active and not expired using backend time.
It atomically converts active-hold units to confirmed units, moves Booking to
confirmed, resolves hold as accepted and emits audit/outbox. Total allocated
units do not change during conversion.

### 12.4. Decline/expiry

Decline or expiry atomically releases hold units and user usage, marks the
Booking terminal, appends audit/outbox and schedules the next promotion.
Duplicate expiry workers are no-ops after the first committed resolution.

`paymentDeadlineMinutes` must be absent for ECL-03 free flows.

## 13. Cancellation, occurrence changes and release

Canonical reason codes include:

```text
userCancelled
organizerCancelled
applicationRejected
occurrenceCancelled
eventCancelled
missedReconfirmation
waitlistOfferDeclined
waitlistOfferExpired
duplicateResolved
policyInvalidated
```

User cancellation enforces the configured free cancellation deadline. After
the deadline, the command returns a typed refusal unless the occurrence/Event
is cancelled or an authorized support path applies. Creator cancellation is
capability-gated, requires a reason and notifies the participant.

Any cancellation of a capacity-holding Booking releases ledger and user usage
in the same transaction, then triggers waitlist promotion. A cancellation is
idempotent and retains audit history.

Occurrence cancellation bulk-processing is resumable and idempotent. New
Booking creation is disabled first; active Booking/holds are then cancelled or
released in bounded batches with per-record audit/outbox. Event/occurrence
documents are never used as embedded participant lists.

Occurrence reschedule retains stable occurrence ID, updates material revision,
notifies affected participants and recomputes future windows. It does not
silently drop existing Booking. Exact opt-out/reconfirmation behavior must be
approved before reschedule runtime is enabled.

## 14. Attendance policy and reconfirmation

```text
AttendancePolicy
  reconfirmationRequired
  reconfirmationOpensHoursBefore
  reconfirmationDeadlineHoursBefore
  autoReleaseOnMissedReconfirm
  cancellationDeadlineHoursBefore?
```

Validation:

- internal registration only;
- finite Recharge-owned inventory only;
- `0 < deadlineHoursBefore < opensHoursBefore`;
- verified notification delivery required;
- auto-release requires active waitlist/ledger transaction readiness;
- all values are occurrence-relative and evaluated in backend time.

Flow:

1. scheduler opens reconfirmation and emits one notification;
2. Booking projection becomes `required`;
3. user Reconfirm command checks Booking/revision/window;
4. success records scoped audit and notification acknowledgement;
5. deadline worker rechecks authoritative state;
6. missed Booking is cancelled with `missedReconfirmation`;
7. ledger/usage release and waitlist promotion are atomic/idempotent.

No cross-event reliability record, user score or Creator-visible individual
history is created. Event-specific aggregate statistics require a separate
Insights slice.

## 15. Auxiliary admission tracks

ECL-03 supports only application-based internal tracks:

```text
AuxiliaryAdmissionTrack
  id
  kind: accreditation | volunteer | vendor | staff | performerGuest
  admissionMode: application
  registrationMode: internal
  confirmationMode: manualApproval
  eligibilityRules[]
  applicationWindow?
  inventoryPoolRef?
  privateFormRef
  enabled
```

Rules:

- absent from main visitor admission UI;
- entered through stable protected link/form;
- access is authenticated and policy-gated;
- capacity-consuming track references a dedicated pool in the same ledger;
- no pool means the track does not consume visitor capacity;
- participant identities are absent from public attendance statistics;
- ordinary accreditation requirement for main flow stays eligibility, not a
  track;
- workforce/access credentials outside visitor Booking remain excluded.

## 16. Authorization and security matrix

| Action | Required authority |
|---|---|
| Read public availability | Authenticated Viewer; safe public projection |
| Create own Booking/application | Authenticated active user; actor-bound |
| Read own Booking | Exact `booking.userId` |
| Cancel/reconfirm own Booking | Exact owner plus state/window policy |
| Read Creator queue | Publisher owner or exact-page `manage_bookings` |
| Approve/reject/promote | Exact publisher capability and occurrence scope |
| Configure Event policy | Verified Creator plus publish/manage capability |
| Support repair | Separate audited Admin capability; no publisher identity |
| Run worker | Dedicated service identity and least privilege |

Security requirements:

- Firestore Rules deny direct client writes to authoritative collections;
- command actor comes only from verified token;
- body user/publisher IDs are treated as resource references, not authority;
- page A membership grants no page B access;
- revoked/disabled accounts fail closed;
- deep links re-run auth and resource authorization;
- App Check/rate limits supplement, never replace, Auth/domain checks;
- logs and analytics exclude names, codes, tokens, waiver text and join links;
- application free text is bounded, access-controlled and retention-classed.

## 17. Notification contract

Required notification kinds:

```text
bookingConfirmed
applicationReceived
applicationApproved
applicationRejected
waitlistJoined
waitlistOfferAvailable
waitlistOfferExpiring
waitlistOfferExpired
reconfirmationOpened
reconfirmationReminder
bookingAutoReleased
bookingCancelled
occurrenceChanged
occurrenceCancelled
```

Every kind has:

- stable template/version;
- localized arguments rather than rendered private text in analytics;
- deterministic delivery key;
- target user ID and safe deep link;
- availableAt/expiry;
- in-app persistence and approved external delivery channel policy;
- retry/dead-letter behavior;
- audit relation to the Booking transition.

Automatic reconfirmation/hold expiry cannot be enabled unless the required
delivery path is verified in staging. Notification delivery failure does not
roll back a committed Booking transaction; it creates an operational alert and
retry obligation.

## 18. API v1 contract

### 18.1. Viewer queries

```text
GetEventBookingReadiness(eventId, occurrenceId)
GetEventAvailability(eventId, occurrenceId, channel?)
GetMyBooking(bookingId)
ListMyBookings(cursor, stateFilter?)
```

### 18.2. Viewer commands

```text
CreateInternalBooking(requestId, idempotencyKey, occurrenceId, poolId?, guestPayload?)
SubmitInternalApplication(requestId, idempotencyKey, occurrenceId, fields)
CancelBooking(requestId, idempotencyKey, bookingId, expectedRevision)
ReconfirmBooking(requestId, idempotencyKey, bookingId, expectedRevision)
AcceptWaitlistOffer(requestId, idempotencyKey, bookingId, holdId, expectedRevision)
DeclineWaitlistOffer(requestId, idempotencyKey, bookingId, holdId, expectedRevision)
```

### 18.3. Creator queries/commands

```text
ListOccurrenceBookings(occurrenceId, cursor, stateFilter?)
ListApplications(occurrenceId, auxiliaryTrackId?, cursor)
ApproveApplication(requestId, idempotencyKey, bookingId, poolId?, expectedRevision)
RejectApplication(requestId, idempotencyKey, bookingId, reasonCode, expectedRevision)
PromoteWaitlist(requestId, idempotencyKey, bookingId, expectedRevision)
CancelManagedBooking(requestId, idempotencyKey, bookingId, reasonCode, expectedRevision)
```

### 18.4. Typed response envelope

```text
ApiResult<T>
  apiVersion
  requestId
  correlationId
  serverTime
  outcome: success | rejected | retryableFailure
  data?: T
  error?: { code, field?, retryAfterSeconds? }
```

Stable rejection codes include:

```text
not_authenticated
not_authorized
feature_disabled
event_unavailable
occurrence_cancelled
registration_not_open
registration_closed
eligibility_not_satisfied
invalid_guest_count
pool_required
pool_unavailable
sold_out
already_active
concurrency_limit_reached
revision_conflict
hold_expired
cancellation_deadline_passed
idempotency_conflict
contention
temporarily_unavailable
```

No response exposes internal stack traces, secrets, other participants or raw
policy evaluation evidence.

## 19. Persistence and backend topology

ADR 0019 proposes `apps/backend`; no directory is created before acceptance.
Logical collections/tables are:

```text
bookings
bookingHolds
bookingAuditEvents
bookingIdempotency
bookingNotificationOutbox
inventoryPoolLedgers
userBookingUsage
bookingPlatformPolicies
workerLeases
```

Event operational projections used by transactions must be immutable or
revisioned inputs derived from published Event, not mutable Create drafts.

Indexes support exact actor/occurrence/state/pool queries without broad scans.
Participant lists are paginated. No unbounded arrays are appended to Event,
occurrence, pool ledger or user documents.

## 20. Mobile architecture

Target module after gates:

```text
apps/mobile/lib/features/booking/
  domain/
  data/
  application/
  presentation/
  booking_feature.dart
```

Responsibilities:

- presentation: render typed state, accessibility, input, controller calls;
- application: orchestration, commands, revision/idempotency lifecycle;
- domain: entities, value objects, state/readiness validation, repository ports;
- data: generated DTO mapping, authenticated API datasource, repositories;
- app layer: cross-feature adapters for Details, Profile, Notifications/Create.

Create stores only Event configuration. Runtime Booking state never enters
`EventCreateBlock`, `EventDraftData`, template JSON or Create autosave.

## 21. Schema and migration

### 21.1. Event configuration schema v4

Event schema v4 may add only explicit Creator configuration:

- `attendancePolicy`;
- `auxiliaryAdmissionTracks`;
- stable refs to approved platform policy/readiness where canonical;
- unknown/newer round-trip.

Schema v3 reads without automatic v4 write. Only explicit ECL-03 config Apply
may write v4. Booking operational records never trigger Event draft migration.

### 21.2. Booking schema v1

Booking begins as an independent server schema v1. Clients reject unsupported
newer mutation semantics while preserving authorized raw response only where
the API contract explicitly allows. Downgrade never converts unknown state to
confirmed/cancelled/free/available.

### 21.3. Existing data

- local/mock ECL-02 snapshots do not migrate into ledger;
- legacy `currentParticipants` is ignored as authority;
- legacy `waitlistEnabled` does not create queue entries;
- `externalBookingUrl` remains external and does not create internal Booking;
- existing Event must be explicitly enabled and reconciled before internal
  registration opens;
- no synthetic historical Booking is generated.

## 22. Feature flags and rollback

Required remotely controlled flags:

```text
event_internal_booking_read
event_internal_booking_create
event_internal_booking_creator_actions
event_internal_booking_waitlist
event_internal_booking_reconfirmation
event_internal_booking_auto_release
event_internal_booking_auxiliary_tracks
```

Rollout order:

1. schemas/backend deployed with every mutation flag off;
2. read-only internal/staff projection;
3. one bounded test Event/occurrence;
4. instant free Booking without waitlist;
5. cancellation/manual approval;
6. waitlist/holds;
7. reconfirmation after delivery proof;
8. auxiliary tracks;
9. bounded Latvia cohort;
10. general enablement after operations review.

Rollback:

- disable new creation before worker/integration rollback;
- keep read/cancel/release paths available;
- stop promotions without abandoning active holds;
- continue safe expiry/release and notification obligations;
- preserve all records/audit/idempotency;
- project unavailable/unknown when authority is unhealthy;
- never revert to local confirmation;
- data repair uses audited backend tools, not Flutter/admin document editing.

## 23. Retention and privacy gate

Before production activation, the accepted table from D04 must be validated
by Privacy/Legal/Product for:

- active and terminal Booking;
- named guest data;
- application fields;
- eligibility evidence references;
- Booking audit;
- idempotency records;
- notification outbox/delivery receipts;
- worker leases and operational logs.

The table must define legal basis, access roles, deletion/anonymization,
support hold, backup propagation and analytics separation. Until exact values
are approved, no production collection or logging may be created.

## 24. Telemetry, reconciliation and operations

Allowed structured metrics:

- command count/outcome/error code;
- transaction contention/retry/latency;
- idempotency hit/conflict;
- pool invariant drift;
- active holds and expiry latency;
- waitlist promotion latency;
- reconfirmation delivery/response/auto-release aggregates;
- outbox retry/dead-letter;
- security denial counts;
- kill-switch state.

Disallowed analytics:

- participant names/contact details;
- application free text;
- access codes/allowlist membership;
- personal no-show history or inferred reliability;
- private Event/location/join secrets.

Reconciliation verifies:

```text
ledger confirmed units == sum active confirmed allocations
ledger hold units == sum active holds
user usage == count/evidence under policy version
every state mutation has audit event
every notification-requiring mutation has outbox/delivery resolution
```

Drift blocks affected pool mutations, alerts operators and uses an audited
repair runbook. It never guesses that capacity is available.

## 25. Staged future runtime file map

This parent map defines ownership, not permission to implement every path.
ECL-03B has a separate bounded exact plan in
[EVENT_CLASSIFICATION_ECL_03B_CONTRACT_DOMAIN_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_03B_CONTRACT_DOMAIN_SLICE_SPEC.md).
Every later stage requires its own confirmed exact file plan. No listed runtime
file was authorized or added by ECL-03A.

### 25.1. Backend — add after Accepted ADR

| Path | Purpose |
|---|---|
| `apps/backend/firebase.json` | Environment/deploy entry configuration |
| `apps/backend/firestore.rules` | Deny direct authoritative writes; scoped reads |
| `apps/backend/firestore.indexes.json` | Bounded Booking/ledger query indexes |
| `apps/backend/functions/src/booking/domain.ts` | Server Booking/Hold/state invariants |
| `apps/backend/functions/src/booking/commands.ts` | Trusted command handlers |
| `apps/backend/functions/src/booking/transactions.ts` | Atomic mutation boundary |
| `apps/backend/functions/src/booking/idempotency.ts` | Request/result deduplication |
| `apps/backend/functions/src/inventory/ledger.ts` | Pool ledger invariants |
| `apps/backend/functions/src/policy/concurrency.ts` | Versioned uniform cap |
| `apps/backend/functions/src/notifications/outbox.ts` | Transactional outbox |
| `apps/backend/functions/src/booking/workers.ts` | Expiry/reconfirmation/promotion jobs |
| `apps/backend/functions/src/booking/reconciliation.ts` | Drift detection/repair input |
| `apps/backend/functions/test/booking/*.test.ts` | Emulator/concurrency/security suites |

Exact TypeScript file split may be refined without changing ownership or
transaction boundaries.

### 25.2. Shared contracts — add/modify

| Path | Purpose |
|---|---|
| `packages/api_contracts/schema/booking/v1/` | Language-neutral source schemas |
| `packages/api_contracts/lib/src/contracts/booking/` | Dart domain-facing contracts |
| `packages/api_contracts/lib/src/dto/request/booking/` | Generated/verified requests |
| `packages/api_contracts/lib/src/dto/response/booking/` | Generated/verified responses |
| `packages/api_contracts/lib/api_contracts.dart` | Public exports |
| `packages/api_contracts/test/booking_contract_test.dart` | Compatibility/fixtures |

### 25.3. Mobile Booking feature — add

| Path | Purpose |
|---|---|
| `features/booking/domain/entities/booking.dart` | Booking aggregate projection |
| `features/booking/domain/entities/booking_hold.dart` | Hold projection |
| `features/booking/domain/entities/booking_failure.dart` | Stable typed failures |
| `features/booking/domain/repositories/booking_repository.dart` | Query/command port |
| `features/booking/domain/usecases/` | Pure readiness/state/command use cases |
| `features/booking/data/datasources/booking_api_datasource.dart` | Authenticated API only |
| `features/booking/data/repositories/booking_repository_impl.dart` | DTO mapping/failures |
| `features/booking/application/controllers/booking_controller.dart` | Viewer orchestration |
| `features/booking/application/controllers/booking_management_controller.dart` | Creator orchestration |
| `features/booking/application/state/` | Immutable typed screen state |
| `features/booking/presentation/pages/my_bookings_page.dart` | Profile-owned list |
| `features/booking/presentation/pages/booking_details_page.dart` | Status/actions |
| `features/booking/presentation/pages/manage_bookings_page.dart` | Creator queue |
| `features/booking/presentation/widgets/` | Presentation-only components |
| `features/booking/booking_feature.dart` | Public feature surface |

Paths are relative to `apps/mobile/lib/`.

### 25.4. App adapters and existing Event config — bounded modifications

| Path | Allowed modification |
|---|---|
| `app/di/service_locator.dart` | Register ports/adapters/flags |
| `app/router/` | Auth/capability guarded Booking routes |
| `app/adapters/` | Details/Profile/Notifications/Create facades |
| `features/create/domain/entities/event_admission.dart` | Attendance/aux config only |
| `features/create/domain/entities/event_draft_data.dart` | Additive explicit schema v4 config |
| `features/create/data/models/event_draft_mapper.dart` | v3/v4 compatibility only |
| `features/create/domain/usecases/validate_event_access_configuration_usecase.dart` | Compose config validation |
| `features/create/application/event_create_coordinator.dart` | Thin config orchestration |
| `features/create/presentation/widgets/event_create_block.dart` | Compose typed config sections only |
| `features/discover/domain/` | Booking readiness/availability ports, no import |
| `features/notifications/domain/` | Typed target/deep-link projection, no lifecycle |
| `features/explore/presentation/pages/profile_page.dart` or its approved successor | My Bookings route entry supplied by app facade; no Booking import |

### 25.5. Documentation/operations — add/modify

| Path | Purpose |
|---|---|
| `docs/api/BOOKING_API_V1.md` | Endpoint/schema/error contract |
| `docs/architecture/BOOKING_SECURITY_MATRIX.md` | Auth/Rules/capability proof |
| `docs/runbooks/booking-incident.md` | Incident containment |
| `docs/runbooks/booking-rollback.md` | Flag/degraded-mode rollback |
| `docs/runbooks/booking-reconciliation.md` | Drift detection/repair |
| `docs/architecture/LAUNCH_STATUS.md` | Evidence only after gates |
| `docs/product/EVENT_CLASSIFICATION_COVERAGE_MATRIX.md` | Cumulative AC status |

### 25.6. Do not modify for ECL-03

- accepted historical ADR files;
- Category System dictionaries;
- Route/Scenario/Quick Plan/Place aggregates;
- provider/Payments models;
- generated files manually;
- Event templates with Booking operational state;
- assets without separate design/media scope.

## 26. Acceptance criteria

1. Booking is a separate aggregate and never embedded in Event draft.
2. Booking references stable Event/occurrence IDs; finite allocation references pool.
3. Only authenticated active users can create their own Booking/application.
4. Creator actions require exact PublisherRef/page capability.
5. Direct client writes to authoritative records are denied.
6. Free internal scope enforces `pricingMode=free/paymentCollectionMode=none`.
7. Unsupported paid/provider/lottery/team/seating flows fail closed.
8. Instant available flow creates one confirmed Booking atomically.
9. Sold-out without waitlist creates no Booking/allocation.
10. Sold-out with waitlist creates one waitlisted Booking and zero allocation.
11. Pending application consumes zero capacity and zero concurrency usage.
12. Approval rechecks every invariant and allocates atomically.
13. Guest units are positive, bounded and included in capacity.
14. Duplicate active Booking is rejected without mutation.
15. Same idempotency request returns identical result without double allocation.
16. Same key/different payload fails with idempotency conflict.
17. Parallel creates cannot exceed pool capacity.
18. Transaction failure leaves Booking/ledger/usage/outbox unchanged.
19. Uniform concurrency cap is checked before allocation in the same transaction.
20. Cap is identical for all users in launch scope and has no personal overrides.
21. Waitlist without hold does not count against capacity or cap.
22. Promotion creates exactly one active TTL hold atomically.
23. Hold accept converts hold units to confirmed units without total drift.
24. Hold decline/expiry releases ledger and usage once, then advances queue.
25. Duplicate promotion/expiry workers are safe no-ops.
26. User/Creator cancellation uses typed reason and releases atomically.
27. Cancellation deadline uses backend time and has typed refusal.
28. Reconfirmation windows satisfy canonical ordering and backend time.
29. Missed reconfirmation cancels, releases and promotes atomically.
30. Reconfirmation creates no reliability/risk profile.
31. Occurrence cancellation prevents new Booking before bounded cleanup.
32. Occurrence reschedule preserves stable occurrence/Booking identity and notifies.
33. Auxiliary capacity uses a dedicated pool in the same ledger.
34. Auxiliary identities are absent from public visitor statistics.
35. Notification outbox is atomic and delivery deduplicated.
36. Offline/stale UI never displays a new Booking as confirmed.
37. Cached availability carries freshness and is rechecked at command time.
38. Secrets/PII are absent from public projection, logs and analytics.
39. Schema v3 reads without automatic Event schema v4 write.
40. Local/mock ECL-02 data never migrates into authoritative ledger.
41. Kill switches block new work without deleting existing obligations.
42. Reconciliation detects ledger/hold/usage drift and fails affected pool closed.
43. Security tests cover cross-user, cross-page, revoked and deep-link denial.
44. API compatibility fixtures prove Dart/backend agreement.
45. 360 dp/150% UI and screen-reader/not-color-only behavior pass.
46. Backend emulator concurrency/idempotency/scheduler suites pass.
47. Full mobile analyzer/tests, backend checks, boundary and diff gates pass.
48. Retention, incident, rollback and reconciliation runbooks are approved.
49. Payments/provider/assigned seating/check-in remain absent.
50. Status documentation claims production readiness only after staging evidence.
51. Booking v1 treats request ID as attempt correlation and idempotency key as
    logical-mutation identity; equal and distinct values are both valid.

## 27. Required test matrix

| Layer | Required evidence |
|---|---|
| Pure domain | State transitions, participant units, policy/readiness, terminal states |
| API contracts | Schema compatibility, stable errors, unknown/newer fail-closed |
| Transaction emulator | create/cancel/approve/accept/reconfirm atomicity |
| Concurrency | parallel final-seat, cap boundary, promotion/expiry races |
| Idempotency | same request, payload conflict, retry after timeout |
| Security Rules | own/cross-user/cross-page/Admin/service access |
| Scheduler | backend clock, leases, duplicate jobs, dead-letter |
| Reconciliation | injected drift detection and fail-closed behavior |
| Mobile application | stale revisions, retries, offline, flags, no optimistic confirmation |
| Widget/accessibility | Viewer/Creator flows, 360 dp/150%, semantics |
| Integration | Details -> Booking -> My Bookings -> cancel/reconfirm |
| Operations | staging rollback, kill switches, alerts, repair dry run |
| Repository | analyzer, full tests, codegen, boundaries, diff |

Minimum race fixtures include 100 parallel attempts for the final finite units,
parallel cap-boundary allocations across occurrences, double waitlist
promotion, accept-vs-expiry, cancel-vs-reconfirm and duplicate scheduled jobs.
Exact load numbers may increase after capacity planning but cannot be reduced
below a meaningful contention proof without documented approval.

## 28. Canonical AC traceability

| Canon AC | ECL-03 target result |
|---:|---|
| 8 | Internal admission axes become authoritative Booking behavior for bounded free flows |
| 14 | Unknown/stale remains non-authoritative; command rechecks server state |
| 15 | SoldOut remains availability projection, not lifecycle |
| 16 | Participant counts derive from ledger/Booking only |
| 17 | Atomic ledger and race tests prohibit oversell |
| 18 | Waitlist promotion uses one TTL hold and atomic release |
| 27/33 | Reconfirmation and auto-release implemented without risk profile |
| 28/36 | Capacity-consuming auxiliary tracks share ledger pools and stay private |
| 29/35 | Hybrid channel/pool bindings remain enforced during allocation |
| 31 | Production Booking has separate Approved slice and kill switches |
| 32 | Booking UI must pass accessibility matrix |
| 41 | Uniform cap is a transactional precondition and idempotent under races |

Deferred AC for provider, Payments, Program Items, assigned seating and
Discover material-revision work remain deferred. ECL-03 cannot mark them Done.

## 29. Risks and controls

| Risk | Control |
|---|---|
| Client shows false confirmation | No optimistic confirmed state; authoritative response only |
| Oversell under contention | Single trusted transaction + emulator race suite |
| Counter drift | Evidence-backed usage + reconciliation + fail-closed pool |
| Duplicate retry/worker | Idempotency records, deterministic worker/delivery keys |
| Waitlist unfairness | Stable FIFO tuple or audited organizer selection |
| Hidden personal discrimination | Uniform policy; no scores/overrides |
| Missed reconfirm notification | Verified delivery gate, outbox retries, alerts |
| Feature rollback strands users | Creation-off/read-cancel-release-on degraded mode |
| Cross-page data leak | Exact capability checks and Rules tests |
| Event draft becomes monolith | Booking separate; Event stores config only |
| Backend structure violates freeze | ADR 0019 must be Accepted first |
| Scope expands into Payments/provider | Typed free-only validation and separate flags/specs |

## 30. Definition of Done

ECL-03 documentation gate (ECL-03A) is ready for approval when:

- ADR 0019 and this spec have no unresolved semantic contradiction;
- all runtime dependencies and open decisions are explicit;
- state/transaction/idempotency/cap/notification/security contracts are fixed;
- exact proposed file plan and AC/test matrix are reviewable;
- coverage/status docs reflect ECL-02 Done and ECL-03 runtime absent;
- links, headings, tables, fences and diff checks pass;
- no runtime/generated/API implementation has been added.

Full ECL-03 is Done only when:

- ADR 0019 and this spec are Approved/Accepted;
- ECL-03B–H pass all 51 AC;
- production Auth/capabilities, backend and notification delivery are live in
  staging and proven through required tests;
- retention/privacy/operations gates are approved;
- rollback preserves all obligations;
- full repository/backend gates are green;
- no excluded scope was introduced.

## 31. Accepted decision register and remaining activation gates

The complete D01-D11 package is Accepted and normative through the
[ECL-03 decision package](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md).
Its exact values must not be replaced by implementation defaults.

| ID | Decision | Required owner |
|---|---|---|
| `ECL03-D01` | Backend topology and new monorepo module | Accepted; physical module remains staged |
| `ECL03-D02` | Firebase regions, environments and service identities | Accepted; verify before deployment |
| `ECL03-D03` | Production Auth/Creator/Page dependency release order | Accepted; Identity remains prerequisite |
| `ECL03-D04` | Exact retention/deletion table | Accepted product policy; Privacy/Legal validation remains activation gate |
| `ECL03-D05` | Notification authority and delivery evidence | Accepted; operational proof remains activation gate |
| `ECL03-D06` | Initial uniform concurrency cap | Accepted |
| `ECL03-D07` | Occurrence reschedule/reconfirmation behavior | Accepted |
| `ECL03-D08` | Initial supported inventory shapes | Accepted |
| `ECL03-D09` | Staging load/SLO/error-budget thresholds | Accepted; staging proof remains activation gate |
| `ECL03-D10` | Support repair authority and workflow | Accepted; support identities/process remain activation gate |
| `ECL03-D11` | Request correlation and logical idempotency identity are separate | Accepted; no wire migration, runtime remains gated |

Acceptance fixes the product and architecture choices. It does not assert
that Identity, Privacy/Legal, Platform, notification or operations readiness
already exists. Runtime remains disabled until the applicable implementation
stage proves those external readiness gates.

## 32. ECL-03A documentation evidence

Documentation package prepared and audited 2026-08-08:

- canonical Event Classification v2.2.3 read completely (1567 lines);
- Accepted ADR 0019 defines the frozen-baseline/backend decision without
  creating `apps/backend`;
- this specification contains 50 sequential AC and 10 Accepted decisions;
- cumulative coverage matrix reconciled from the historical pre-ECL-01
  snapshot to the factual post-ECL-02 baseline: 20 I, 8 P, 2 M, 12 M/G, 1 D;
- all relative Markdown links resolve and all code fences are balanced;
- `flutter analyze --no-pub`: **0 issues**;
- full `flutter test --no-pub`: **647 passed**;
- boundary check: passed with 59 existing allowlist suppressions and no new
  violation;
- `git diff --check`: passed; only existing CRLF conversion warnings;
- no Flutter/backend/generated/API runtime implementation was added for
  ECL-03.

ECL-03A is Done and this specification is Approved. ECL-03 runtime remains
absent: ECL-03B-H and every applicable production activation gate are still
required.
