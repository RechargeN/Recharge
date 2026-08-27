# ECL-03C — Authoritative Booking transaction core

- Версия: 1.5
- Дата: 2026-08-27
- Статус: **Review — exact implementation plan; runtime not authorized**
- Parent:
  [EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md),
  Approved v1.3
- Architecture:
  [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md), Accepted
- Decisions:
  [EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md),
  Accepted D01–D12
- Dependency:
  [EVENT_CLASSIFICATION_ECL_03B_CONTRACT_DOMAIN_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_03B_CONTRACT_DOMAIN_SLICE_SPEC.md),
  Done v1.1
- Runtime effect of this revision: **none**
- Product API baseline:
  [BCK09-API-DEC-01 v0.3](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Contract correction evidence:
  [BCK09-API-CORR-01 v0.3](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)

## 0. Changelog

### v1.5 — 2026-08-27

- registered the verified nine-variant command union and D12 Schema/Dart
  parity from BCK09-API-CORR-01 v0.3;
- retained TypeScript/query parity, named API decisions and explicit runtime
  authorization as blockers;
- changed no callable, collection, AC or runtime scope.

### v1.4 — 2026-08-27

- inherited Accepted ECL03-D12 opaque bounded request-ID semantics from parent
  ECL-03 v1.3 and removed the semantic ULID conflict;
- retained Schema/Dart/TypeScript conformance as a blocking
  BCK09-API-CORR-01 implementation requirement;
- changed no callable scope, collection, AC count, schema or runtime artifact.

### v1.3 — 2026-08-27

- added exact logical-mutation and request-attempt record kinds inside the
  existing `bookingIdempotency` collection, preserving nine collections;
- selected a Product-level JCS/SHA-256 semantic hash and callable 10/15/30
  deadline target while keeping named API/Security/Operations acceptance open;
- exposed the Approved-parent ULID versus Booking-v1 opaque request-ID conflict
  as a fail-closed `ECL03-D12` prerequisite rather than silently overriding it;
- linked the bounded Booking v1 schema/DTO correction plan and added six AC;
- changed no schema, DTO, backend, Firebase, mobile or deployment file.

### v1.2 — 2026-08-26

- replaced an unspecified duplicate-active query with one deterministic
  `bookingActiveKeys` transaction record per `(actorId, occurrenceId,
  admissionTrackId)` scope;
- made create/cancel atomically acquire/release that record and required
  dangling/mismatched keys to fail closed for reconciliation;
- confirmed one server-issued, callback-retry-stable Booking v1 ID path without
  changing its command schema or conflating entity/request/idempotency identity;
- froze ECL-03C outbox records as terminal `suppressedPreActivation` evidence
  that can never be delivered or replayed before a later Accepted handoff;
- added exact implementation/test ownership and three appended AC without
  changing the five callable surfaces or enabling runtime.

## 1. Outcome

ECL-03C is the first executable backend stage of internal free Booking. It
defines one trusted Firebase transaction core for:

- creating an instant free Booking;
- cancelling the actor's Booking;
- reading one actor-owned Booking;
- listing actor-owned Bookings with bounded cursor pagination;
- reading an authoritative occurrence availability projection;
- maintaining finite-capacity pool ledger and user concurrency usage;
- acquiring and releasing one deterministic duplicate-active key per scope;
- storing idempotency, audit and notification-obligation records atomically;
- denying direct client writes and proving no oversell under contention.

The slice supports only authenticated Viewer self-service and only `instant`
general-capacity registration. A successful finite-capacity command returns a
server-confirmed Booking only after the Firestore transaction commits. An
explicit unlimited RSVP may confirm without a ledger allocation. Unknown
capacity is never treated as unlimited.

Booking v1 create does not accept `bookingId` from the command payload. The
trusted handler therefore issues exactly one request-scoped candidate Booking
ULID before entering the Firestore transaction callback and reuses that same
candidate across every internal callback retry. It becomes authoritative and
is returned only when the transaction commits. A refusal/failure persists no
Booking or mapping. This follows ADR 0013's server-ID baseline and BCK-03's
explicit server-returned mapping branch; it does not conflate `bookingId`,
`requestId` or `idempotencyKey`, and requires no Booking v1 wire change.

This document is the required exact plan. It does not create `apps/backend`,
connect Firebase, deploy anything, collect production data or change mobile
runtime.

## 2. Authorization and prerequisites

### 2.1. Current gate

The plan may be reviewed during stabilization. Physical backend creation and
runtime implementation may start only after all of the following are true:

1. this exact plan is explicitly accepted;
2. a separate post-stabilization Firebase implementation authorization, or an
   Accepted ADR/slice exception of equal authority, permits `apps/backend`;
3. the production Identity dependency sequence from Accepted D03 has a
   implemented and verified server-owned Auth/account/capability authority;
4. Platform confirms dev/staging/prod project ownership, `eur3` Firestore,
   `europe-west1` Functions and environment-scoped service identities;
5. no unresolved higher-priority ADR conflicts with this slice.

Implementation approval is not production activation. Every production
mutation flag remains off until the later staging, security, legal and
operations gates explicitly allow activation.

### 2.2. Why Identity is a hard dependency

Current local/mock `User`, verified Creator and Professional Page previews are
not server authority. ECL-03C may use emulator auth fixtures in tests, but
production code must derive `actorId`, active-account state and capabilities
from verified server context. It must never accept them from a command body.

ECL-03C does not implement Creator/Page management commands, but its shared
authorization boundary must fail closed so ECL-03D can add exact
`manage_bookings` checks without replacing the transaction architecture.

## 3. Fixed scope

### 3.1. Included

1. Firebase Auth input and server-owned active-account assertion.
2. Cloud Functions v2 callable query/command boundary.
3. Node.js 22 and strict TypeScript backend module.
4. Firestore `eur3`; functions in `europe-west1`.
5. Separate Firebase aliases for dev, staging and prod; no secrets in Git.
6. Booking v1 TypeScript consumer verified against ECL-03B fixtures.
7. Additive query/page/availability schemas required by get/list/readiness.
8. `createBooking` for instant, internal, free registration.
9. `cancelBooking` by the owning actor.
10. `getMyBooking`, `listMyBookings` and `getEventAvailability` queries.
11. Finite `generalCapacity` pool/channel allocation.
12. Explicit unlimited RSVP without capacity allocation or concurrency usage.
13. Duplicate-active prevention through an exact transaction key.
14. Platform policy v1: maximum five active finite-capacity Bookings per user.
15. Atomic Booking, active-key, ledger, usage, audit, outbox and idempotency writes.
16. Stable typed rejections and retryable failures.
17. Feature flags with all production mutations disabled by default.
18. Rules/IAM boundary documentation and emulator Rules tests.
19. Unit, contract, transaction, idempotency and contention tests.
20. Privacy-safe structured logs and metrics contract; no analytics payloads
    containing participant data.

### 3.2. Explicitly excluded

- manual applications and Creator approve/reject;
- waitlist, promotion, active holds, TTL workers or queue ordering;
- reconfirmation, occurrence-change workers or automatic release;
- notification delivery, FCM, inbox UI or outbox dispatcher;
- auxiliary admission tracks;
- attendance, check-in, QR or no-show policy;
- provider sync, provider inventory, Payments, deposits or paid admission;
- team registration, lottery, assigned seating or reserved areas;
- production Event publishing/synchronization into the operational projection;
- mobile API client, repository, datasource, DI, controller, route or UI;
- Event draft schema v4 or Event Create changes;
- support repair commands, reconciliation repair or direct document editing;
- deployment, production flags, credentials or real user data.

If an occurrence enables an excluded allocation mode, the backend returns
`unsupported_flow`; it does not approximate it.

## 4. Public backend surface

All surfaces use the Booking v1 envelope/result vocabulary and return only the
actor-authorized projection. Callable transport is not authorization by
itself; every handler repeats Auth, App Check mode, feature flag and domain
checks.

| Surface | Kind | ECL-03C behavior |
|---|---|---|
| `createInternalBookingV1` | mutation | Instant finite or explicit unlimited free Booking |
| `cancelInternalBookingV1` | mutation | Owner cancellation; atomic capacity/usage release |
| `getMyBookingV1` | query | Exact ID, owner-only projection |
| `listMyBookingsV1` | query | Owner-only, stable cursor, bounded page |
| `getEventAvailabilityV1` | query | Authenticated, non-reserving authoritative projection |

Rules:

- `schemaVersion=1` is mandatory;
- `requestId` follows Accepted ECL03-D12: exact case-sensitive, non-blank,
  1–128 Unicode scalar values, opaque and not normalized/interpreted as ULID;
- `idempotencyKey` remains a separate opaque required logical-mutation ID;
- command Schema/Dart parity is proven by BCK09-API-CORR-01 v0.3; no endpoint
  may be implemented until TypeScript/query fixture parity is also proven;
- `actorId`, roles, capabilities and server time are never accepted from body;
- queries have a maximum page size of 50 and default of 20;
- cursors are opaque, signed/versioned server tokens or stable backend-owned
  `(createdAt, bookingId)` tokens; clients cannot inject arbitrary paths;
- response includes authoritative `serverTime`, Booking revision and, where
  applicable, ledger/material revisions;
- unsupported schema/enum/flow fails closed;
- no endpoint returns audit, idempotency, usage, outbox or private eligibility
  records.

App Check starts in observe mode in dev/staging and is enforced only through
the accepted environment rollout. Auth and idempotency remain mandatory even
when App Check is enforced. Firebase documents callable Auth/App Check context
and `enforceAppCheck` for Functions v2:
[callable functions](https://firebase.google.com/docs/functions/callable) and
[App Check enforcement](https://firebase.google.com/docs/app-check/cloud-functions).

### 4.1. Product-selected transport target

The target is one Functions v2 callable in `europe-west1` per named surface,
with no generic router, 10-second query client deadlines, 15-second mutation
client deadlines and a 30-second server timeout. A mutation timeout or lost
connection is an unknown outcome; recovery preserves semantic payload and
idempotency key while using a fresh request ID, or reads authorized state.

This is the Product baseline from `BCK09-API-DEC-01`, not an Accepted
`API-DEC-01`. API Platform and BCK-05 Operations must validate the values and
SDK/latency/cost behavior before endpoint scaffold or deploy configuration.

## 5. Authoritative operational records

Operational collections are separate from Event drafts and from one another.
Names below are normative for ECL-03C.

| Collection | Key | Purpose | Client access |
|---|---|---|---|
| `bookingEventProjections` | `occurrenceId` | Immutable-for-command Event/admission/inventory input and revisions | deny |
| `bookings` | `bookingId` | Booking aggregate projection | deny; callable query only |
| `bookingPoolLedgers` | hash of occurrence/pool/channel | capacity and confirmed allocation counters | deny |
| `bookingUserUsage` | `userId` | policy version plus active finite Booking evidence | deny |
| `bookingActiveKeys` | SHA-256 of versioned actor/occurrence/admission-track tuple | one non-terminal Booking lock and Booking reference | deny |
| `bookingIdempotency` | domain-separated hash; `m1_` logical or `r1_` attempt kind | logical payload/result or atomic request-attempt binding | deny |
| `bookingAudit` | `auditId` | append-only privacy-safe mutation fact | deny |
| `bookingOutbox` | deterministic obligation ID | post-commit notification obligation only | deny |
| `bookingFeatureFlags` | flag/environment | server-owned disabled-by-default gate | deny |

No collection stores participant arrays inside Event. Named guest data and
application answers are absent from ECL-03C. IDs in document paths are stable
ULID/opaque hashes; raw email, phone, access code or payload is not used as a
path key.

### 5.1. Idempotency record kinds

The collection count does not change. `bookingIdempotency` stores exactly two
closed record kinds derived with length-prefixed UTF-8 tuple encoding:

```text
encode(value) = uint32be(length(UTF8(value))) || UTF8(value)

logicalMutationId = "m1_" + lowercaseHex(SHA-256(
  encode("booking_logical_mutation_v1") || encode(actorId) ||
  encode(commandType) || encode(idempotencyKey)
))

requestAttemptId = "r1_" + lowercaseHex(SHA-256(
  encode("booking_request_attempt_v1") || encode(actorId) ||
  encode(requestId)
))
```

The logical record stores its kind, actor scope, command/key reference,
semantic hash, completed result and server-owned timestamps. The attempt
record stores its kind, actor scope, command/key reference, semantic hash and
server-owned timestamps. Both records are read before writes and created in
the same transaction as the domain mutation. Retention is no shorter than the
logical retry window. Raw IDs, keys and payloads are excluded from logs.

### 5.2. Duplicate-active key

For the Accepted parent scope `(userId, occurrenceId, admission track)`, the
server derives:

```text
scopeVersion = booking_active_scope_v1
admissionTrackId = general
encode(value) = uint32be(length(UTF8(value))) || UTF8(value)
activeKeyId = lowercaseHex(SHA-256(
  encode(scopeVersion) || encode(actorId) ||
  encode(occurrenceId) || encode(admissionTrackId)
))
```

For Viewer self-service, resolved `actorId` is the authoritative `userId` in
the parent duplicate-active invariant. Length-prefix encoding prevents tuple
ambiguity; all implementations and fixtures use the exact UTF-8 bytes above.
The input IDs are already opaque server-bound identifiers. Raw email, phone,
display name, payload or access secret is never used. The key document stores
only `scopeVersion`, actor/occurrence/track IDs, `bookingId`, Booking revision,
created/updated server time and a schema version.

Create reads the exact key before any write. An existing valid key returns
`already_active` and the authorized current Booking projection. A missing key
is created atomically with the new Booking. A dangling, mismatched or malformed
key fails closed as `temporarily_unavailable`, blocks that scope for
reconciliation and never creates a second Booking.

Cancellation reads and verifies the same key, transitions the referenced
Booking and deletes the key in the same transaction. A concurrent rejoin can
therefore proceed only after the terminal transition commits and must allocate
a new Booking ULID. This record is required for finite and explicit-unlimited
Bookings; it is separate from the finite-only concurrency usage counter.

### 5.3. Event operational projection

The emulator suite seeds a minimal projection containing:

```text
eventId, occurrenceId, publisherRef, lifecycle, materialRevision,
registrationWindow, cancellationDeadline, pricingMode,
paymentCollectionMode, registrationMode, inventoryAuthority,
inventoryShape, poolId, channel, capacityMode, totalCapacity,
guestPolicy, eligibilityMode, bookingEnabled
```

ECL-03C has no production writer for this projection. A production mutation
cannot be enabled until a later approved publishing/synchronization slice
provides revision-safe source ownership. Manual console seeding is prohibited.

### 5.4. Pre-activation outbox disposition

Every ECL-03C `bookingOutbox` record has immutable
`effectDisposition=suppressedPreActivation` plus the resolved policy revision.
It is terminal evidence that the Booking transaction intentionally emitted no
cross-domain notification effect while OD-09/BCK-13 handoff was unavailable.
It is not a delivery backlog, is excluded from delivery-lag breach, and must
never be dispatched, mutated to `handoffRequired` or replayed after activation.

A later Approved notification stage may allow only new post-activation
transactions to write `effectDisposition=handoffRequired`; BCK-13 then owns its
dedupe and terminal receipt/quarantine/dead-letter. ECL-03C contains no outbox
dispatcher, inbox writer, push worker or compatibility path that upgrades old
suppressed records.

## 6. Transaction contract

Every create/cancel command executes one deterministic Admin SDK Firestore
transaction. Firestore can rerun a transaction after concurrent edits, so the
transaction closure has no external side effects; outbox delivery happens only
after commit in a later stage. Firestore guarantees all-or-nothing writes and
documents retry behavior in
[transactions and batched writes](https://firebase.google.com/docs/firestore/manage-data/transactions).

For create, the trusted handler generates `candidateBookingId` once before the
callback. The callback receives it as immutable input; it never calls an ID
generator. Concurrent attempts may have different candidates, but idempotency
and the active-key read ensure that only the committed result becomes visible.

### 6.1. Create, in exact order

1. validate transport shape before privileged reads;
2. resolve verified actor and active-account authority;
3. evaluate environment/App Check/`internal_booking_create_v1` flag;
4. validate the closed command variant and calculate its canonical payload hash;
5. derive/read both logical-mutation and request-attempt idempotency records;
6. read occurrence operational projection;
7. verify published/open lifecycle and material revision;
8. verify internal authority, free pricing and no payment collection;
9. verify instant mode, window, eligibility and guest units;
10. resolve exact general-capacity pool/channel and ledger revision;
11. read actor usage under policy `active_confirmed_finite_v1`;
12. derive and read the exact `bookingActiveKeys` record;
13. enforce maximum five active finite-capacity Bookings;
14. enforce finite capacity, or verify explicit unlimited mode;
15. bind the handler's immutable `candidateBookingId` to this completed result;
    the client-supplied `requestId`/`idempotencyKey` remain distinct;
16. write Booking plus its active key and, for finite capacity, ledger/usage;
17. write one append-only audit record;
18. write one deterministic outbox record with immutable
    `effectDisposition=suppressedPreActivation`;
19. write the completed logical result and atomic attempt binding;
20. commit, then return the stored typed result.

The transaction reads all required documents before writes. Any contention
retry repeats the deterministic decision against current data. Bounded retry
exhaustion returns `contention`; it never reports confirmation.

### 6.2. Cancel, in exact order

1. validate transport and resolve verified actor;
2. evaluate `internal_booking_cancel_v1` flag;
3. validate/hash the command and read both logical and attempt records;
4. read Booking and verify owner;
5. verify state/revision and authoritative cancellation deadline;
6. derive/read the exact active key and verify it references this Booking;
7. read exact ledger and user usage records when allocation is finite;
8. transition Booking to terminal `cancelled` with server time/reason;
9. delete the active key and release exact finite units/usage when applicable;
10. write audit, terminal `suppressedPreActivation` outbox evidence, completed
    logical result and atomic attempt binding;
11. commit, then return stored result.

Repeated cancellation with the same key returns the original result. A new
key against an already terminal Booking returns the authorized current
projection without releasing units again.

### 6.3. Finite and unlimited invariants

```text
0 <= confirmedUnits <= totalCapacity
remainingUnits = totalCapacity - confirmedUnits
ledger confirmedUnits = sum(active finite Booking participantUnits)
user usage = count(active finite Booking allocations under policy v1)
one Booking counts once for policy even when participantUnits > 1
explicit unlimited Booking has no ledger allocation and no policy usage
unknown capacity is neither finite-available nor unlimited
```

Sold out returns `sold_out`. Even when waitlist configuration exists, ECL-03C
does not create a waitlisted Booking; waitlist becomes authoritative only in
ECL-03D.

## 7. Idempotency contract

The effective key is `(resolvedActorOrServiceIdentity, commandType,
idempotencyKey)`. `requestId` correlates one request attempt;
`idempotencyKey` identifies one logical mutation across retries. Values may be
equal, but equality is not required. A retry may use a new request ID only when
it preserves the original idempotency key and normalized semantic payload.
Neither body field is trusted as actor identity or a global key. The selected
semantic hash algorithm is `booking_semantic_hash_v1`: validate one closed
command variant, project exactly `{algorithmVersion, commandType,
commandSchemaVersion, resolvedActorScope, payload}`, serialize it as RFC 8785
JCS UTF-8 and encode the SHA-256 digest as lowercase hexadecimal. It excludes
`requestId`, `idempotencyKey`, transport metadata, raw Auth/App Check context
and server timestamps. Duplicate keys, non-finite numbers and values outside
the cross-language safe numeric subset are rejected before hashing. Dart and
TypeScript golden vectors must cover Unicode, key ordering, absent versus
null, integers, arrays and nested objects. This remains a Product-selected
target until API Platform and Security accept BCK-03 `API-DEC-03`.

- same effective key and same hash returns the byte-equivalent stored domain
  result after authorization inside a response envelope that echoes the current
  attempt request ID and may use new attempt correlation metadata;
- same effective key and different hash returns `idempotency_conflict`;
- success and authenticated deterministic domain refusals may be stored;
- unauthenticated, malformed, unsupported-contract, contention, unavailable
  and internal failures are not stored as successful completion;
- no idempotency record is written before actor binding;
- retention follows Accepted D04 and must exceed every supported retry window;
- logs contain only hashed request correlation, not command payload.
- a new idempotency key remains subject to duplicate-active, capacity, policy
  and revision invariants and cannot bypass them.
- every new attempt uses a fresh request ID; detected reuse of one request ID
  with another key or semantic command is invalid and creates no mutation.
- the logical and attempt records from §5.1 are checked and written in the same
  transaction as every successful or stored deterministic domain result.

## 8. Security boundary

1. Firestore Rules deny every direct mobile write to all nine collections.
2. ECL-03C also denies direct client reads; callable queries return minimized
   projections. A later direct-read design requires an explicit spec revision.
3. Admin SDK bypasses Rules, therefore IAM/service-account least privilege is
   a separate mandatory control and is documented in the security matrix.
4. No production service-account JSON or Firebase secret enters Git, Flutter,
   fixtures, logs or analytics.
5. Viewer queries and commands are actor-bound.
6. Unknown account state, capability state, Event revision or flag state
   denies mutation.
7. Error shape prevents existence probing: unauthorized callers do not learn
   whether a foreign Booking exists.
8. Emulator Rules tests cover unauthenticated, wrong-user, forged claims,
   direct ledger/audit/idempotency/outbox access and attempted direct writes.

Firebase notes that server libraries bypass Firestore Security Rules, which is
why both Rules tests and IAM proof are required:
[Firestore Rules emulator guidance](https://firebase.google.com/docs/firestore/security/test-rules-emulator).

## 9. Feature flags and activation

```text
internal_booking_reads_v1       default off
internal_booking_create_v1      default off
internal_booking_cancel_v1      default off
internal_booking_app_check_v1   observe only, then enforced by environment
```

Flags are server-owned, environment-specific and fail closed on missing,
stale or invalid configuration. A client hint cannot enable a command. The
emulator test harness may inject explicit test flags. No ECL-03C completion
claim turns production flags on.

Rollback order is:

1. disable create;
2. keep authorized reads available when safe;
3. keep cancel available unless incident containment requires fail closed;
4. preserve committed Booking/ledger truth;
5. never replace server confirmation with local/mock confirmation;
6. escalate drift to the later audited repair/reconciliation runbook.

## 10. Exact implementation file plan

This section authorizes no files by itself. After all prerequisites and a
separate implementation confirmation, ECL-03C may change only the paths below
plus mechanically generated lockfiles.

### 10.1. Backend — add

| Path | Purpose |
|---|---|
| `apps/backend/.firebaserc` | Non-secret dev/staging/prod aliases only |
| `apps/backend/firebase.json` | Functions/Firestore/emulator configuration; Node 22 source |
| `apps/backend/firestore.rules` | Deny direct authoritative reads/writes |
| `apps/backend/firestore.indexes.json` | Exact owner/state/date query indexes only |
| `apps/backend/package.json` | Pinned Firebase CLI orchestration scripts |
| `apps/backend/package-lock.json` | Reproducible root toolchain lock |
| `apps/backend/README.md` | Local emulator commands and no-production guard |
| `apps/backend/functions/package.json` | Pinned Functions/Admin/runtime/test dependencies |
| `apps/backend/functions/package-lock.json` | Reproducible Functions lock |
| `apps/backend/functions/tsconfig.json` | Strict TypeScript build |
| `apps/backend/functions/src/index.ts` | Export only five approved v1 surfaces |
| `apps/backend/functions/src/contracts/booking_v1.ts` | Fixture-verified closed TypeScript wire consumer |
| `apps/backend/functions/src/shared/auth_context.ts` | Verified actor/account boundary |
| `apps/backend/functions/src/shared/feature_flags.ts` | Fail-closed environment flags |
| `apps/backend/functions/src/shared/server_clock.ts` | Server clock port and production adapter |
| `apps/backend/functions/src/shared/failures.ts` | Stable callable/domain error mapping |
| `apps/backend/functions/src/booking/domain.ts` | Server Booking invariants and projection |
| `apps/backend/functions/src/booking/idempotency.ts` | Canonical hash/key/result rules |
| `apps/backend/functions/src/booking/transactions.ts` | Single Admin SDK transaction boundary |
| `apps/backend/functions/src/booking/create_internal_booking.ts` | Create command orchestration |
| `apps/backend/functions/src/booking/cancel_internal_booking.ts` | Cancel command orchestration |
| `apps/backend/functions/src/booking/booking_queries.ts` | Get/list owner projections |
| `apps/backend/functions/src/booking/availability_query.ts` | Non-reserving authoritative availability |
| `apps/backend/functions/src/inventory/ledger.ts` | General-capacity ledger invariants |
| `apps/backend/functions/src/inventory/active_key.ts` | Deterministic duplicate-active scope key and validation |
| `apps/backend/functions/src/policy/concurrency.ts` | D06 policy v1 and usage evidence |
| `apps/backend/functions/src/audit/booking_audit.ts` | Append-only privacy-safe mutation facts |
| `apps/backend/functions/src/notifications/outbox.ts` | Obligation record only; no delivery |

Node.js 22 is selected because it is a current supported Firebase Functions
runtime; the runtime is pinned in both deploy config and `engines`. Firebase's
current runtime table lists Node 22 and 20 as supported:
[manage Functions runtimes](https://firebase.google.com/docs/functions/manage-functions).

### 10.2. Backend tests — add

| Path | Proof |
|---|---|
| `apps/backend/functions/test/support/emulator.ts` | Isolated demo-project environment, cleanup and flags |
| `apps/backend/functions/test/support/fixtures.ts` | Minimal Event/pool/account fixtures, no real PII |
| `apps/backend/functions/test/support/fake_clock.ts` | Window/deadline determinism |
| `apps/backend/functions/test/unit/contract_fixtures.test.ts` | Same ECL-03B valid/invalid/forward fixtures |
| `apps/backend/functions/test/unit/idempotency.test.ts` | Canonical hash and replay matrix |
| `apps/backend/functions/test/unit/booking_id.test.ts` | One server candidate per request, stable across callback retries and absent on refusal |
| `apps/backend/functions/test/unit/active_key.test.ts` | Canonical tuple/hash, malformed and mismatch cases |
| `apps/backend/functions/test/unit/outbox_disposition.test.ts` | Suppressed record is immutable, non-dispatchable and non-replayable |
| `apps/backend/functions/test/unit/booking_domain.test.ts` | Finite/unlimited/cap/guest invariants |
| `apps/backend/functions/test/emulator/create_booking.test.ts` | Atomic success/refusal/no-partial-write |
| `apps/backend/functions/test/emulator/cancel_booking.test.ts` | Exact release and terminal retry |
| `apps/backend/functions/test/emulator/booking_queries.test.ts` | Owner scope, pagination, minimized projection |
| `apps/backend/functions/test/emulator/security_rules.test.ts` | Direct access denied and auth matrix |
| `apps/backend/functions/test/emulator/contention.test.ts` | Parallel same-scope creates, active-key uniqueness, cap and idempotency proof |

Security tests use the Local Emulator Suite and
`@firebase/rules-unit-testing`, the Firebase-supported mechanism for mocked
Auth Rules contexts:
[Rules unit testing](https://firebase.google.com/docs/rules/unit-tests).

### 10.3. Shared contracts — add/modify

| Path | Change |
|---|---|
| `packages/api_contracts/schema/booking/v1/booking_query.schema.json` | Add closed get/list/availability request union |
| `packages/api_contracts/schema/booking/v1/booking_page.schema.json` | Add bounded page/cursor response |
| `packages/api_contracts/schema/booking/v1/booking_availability.schema.json` | Add honest authoritative availability projection |
| `packages/api_contracts/schema/booking/v1/fixtures/*.json` | Add valid/invalid/forward query fixtures |
| `packages/api_contracts/test/booking_contract_test.dart` | Register new roots and closed vocabulary |
| `packages/api_contracts/test/booking_fixture_test.dart` | Verify additive fixtures |
| `packages/api_contracts/pubspec.yaml` | Backward-compatible package bump to `0.3.0` |
| `packages/api_contracts/pubspec.lock` | Mechanical resolution update if required |

Existing Dart mutation/read DTOs remain unchanged in ECL-03C. Mobile query
DTOs/client mapping belong to ECL-03G. The backend TypeScript consumer must
pass the shared fixtures before any command handler is exported.

### 10.4. Documentation — add/modify

| Path | Change |
|---|---|
| `docs/api/BOOKING_API_V1.md` | Five surfaces, schemas, errors and examples |
| `docs/architecture/BOOKING_SECURITY_MATRIX.md` | Auth/App Check/Rules/IAM/flags evidence |
| `docs/product/EVENT_CLASSIFICATION_COVERAGE_MATRIX.md` | ECL-03C evidence only after tests |
| `docs/architecture/LAUNCH_STATUS.md` | Honest stage status and command evidence |
| `AGENTS.md` | Current ECL status only after verified implementation |

### 10.5. Must not change

- any file under `apps/mobile/lib/` or `apps/mobile/test/`;
- `event_create_block.dart` and all Event Create/application/domain/data files;
- accepted historical ADRs;
- provider, payment, Route, Scenario, Quick Plan, Place or identity runtime;
- generated Dart/TypeScript files;
- production Firebase console state, project credentials or deployment config
  containing real IDs/secrets.

## 11. Verification matrix

| Gate | Required command/evidence |
|---|---|
| Backend formatting/typecheck | pinned npm scripts; zero errors |
| Contract compatibility | shared Dart suite plus TypeScript fixture consumer |
| Unit tests | domain/idempotency/fake-clock suite green |
| Emulator integration | Auth + Firestore + Functions through `emulators:exec` |
| Rules | unauthenticated/wrong-user/direct operational access denied |
| Capacity contention | at least 100 parallel attempts into bounded pools; zero oversell |
| Duplicate idempotency | 100 same-key retries; exactly one allocation/result |
| Transaction retry ID | forced callback rerun preserves one server candidate and returns only the committed ID |
| Duplicate active | 100 distinct-key parallel creates for one actor/scope; exactly one Booking/key, including explicit unlimited |
| Outbox suppression | ECL-03C writes only immutable `suppressedPreActivation`; no dispatcher/replay path exists |
| User cap contention | parallel events cannot create more than five active finite allocations |
| Failure atomicity | injected failure at each write boundary leaves no partial mutation |
| Query pagination | stable order, no duplicate/omitted item across bounded pages |
| Repository boundary | existing boundary script, no mobile/provider imports |
| Mobile regression | `flutter analyze` and full `flutter test` stay green |
| Diff hygiene | `git diff --check`; no secrets, generated output or cache artifacts |

Emulator evidence is necessary but not production proof. Staging load/SLO,
reconciliation, incident/rollback/repair, Legal and production activation
remain ECL-03H or later gates.

## 12. Acceptance criteria

1. This plan is explicitly accepted before implementation.
2. Physical `apps/backend` creation has the required post-stabilization
   authorization.
3. Production Identity dependency is documented and no mock authority is
   accepted by runtime code.
4. Backend uses Node.js 22, strict TypeScript and Cloud Functions v2.
5. Firestore/Functions locations match Accepted D02.
6. No secret or service-account key is committed.
7. Exactly five approved v1 callable surfaces are exported.
8. TypeScript wire consumer passes the shared Booking fixtures.
9. Query/page/availability schemas are additive and fail closed.
10. Direct client writes to every authoritative collection are denied.
11. Direct client reads of operational collections are denied.
12. Viewer command actor is derived only from verified Auth context.
13. Missing/inactive/unknown account state denies commands.
14. Create supports only internal, free, instant, general-capacity flows.
15. Unsupported paid/provider/application/waitlist/complex-shape flow fails
    without Booking or allocation.
16. Explicit unlimited RSVP confirms without ledger or cap usage.
17. Unknown capacity never confirms as unlimited.
18. Finite create writes Booking/ledger/usage/audit/outbox/idempotency in one
    transaction.
19. Cancel releases exactly its allocation and usage in that transaction.
20. Transaction failure leaves no partial writes.
21. Duplicate-active Booking is prevented.
22. Policy v1 prevents more than five active finite-capacity allocations.
23. Guest units consume capacity but one Booking consumes one policy slot.
24. Parallel create never oversells a pool.
25. Same idempotency key/hash returns the stored result without double write.
26. Same idempotency key with different payload returns conflict.
27. Infrastructure/transport failure never reports confirmation.
28. Sold out creates no waitlisted Booking in ECL-03C.
29. Owner get/list cannot expose another user's Booking or existence.
30. Pagination is bounded and stable.
31. Availability query is authoritative at response time but reserves nothing.
32. Server time decides every window/deadline.
33. Audit/log/metric records contain no participant contact or access secret.
34. ECL-03C outbox is immutable `suppressedPreActivation` evidence only: no
    delivery is claimed, no dispatcher consumes it and later activation cannot
    replay or upgrade it.
35. All production mutation flags remain off after implementation.
36. No mobile/Create/Event runtime file changes in ECL-03C.
37. Backend, contract, emulator, boundary and full mobile regression gates are
    green with recorded commands/counts.
38. ECL-03C may be marked Done only as a disabled authoritative core; internal
    Booking product/runtime remains not activated until later stages.
39. The versioned duplicate-active tuple and SHA-256 encoding are canonical and
    fixture-tested across the TypeScript implementation and test helpers.
40. Create/cancel writes or deletes the exact active key atomically with the
    Booking and every applicable ledger/usage/audit/outbox/idempotency record.
41. One hundred parallel distinct-idempotency creates for the same actor/scope
    commit exactly one Booking/key for both finite and explicit-unlimited paths.
42. `bookingIdempotency` has closed logical-mutation and request-attempt record
    kinds without creating a tenth operational collection.
43. Both idempotency record kinds are read and written atomically with the
    applicable domain mutation and reject request reuse conflicts fail closed.
44. `booking_semantic_hash_v1` has one exact JCS/SHA-256 projection and requires
    cross-language golden vectors before runtime.
45. Callable region and 10/15/30-second deadlines remain Product-selected
    targets until named API Platform, Security and BCK-05 decisions are effective.
46. Accepted ECL03-D12 defines opaque bounded request IDs; command Schema/Dart
    enforcement is proven, while endpoint TypeScript parity remains blocked.
47. Booking command schema correction was separately Approved and verified in
    `BCK09-API-CORR-01 v0.3`; this plan still grants no runtime authority.

## 13. Rollback and stop conditions

Stop implementation and keep ECL-03C not Done if any of these occurs:

- production/mock identity boundaries cannot be separated;
- a transaction requires sequential non-atomic writes;
- any contention test oversells or exceeds user cap;
- idempotency can allocate twice;
- Rules/IAM permits unapproved direct access;
- Event operational projection lacks stable IDs/material revision;
- a paid/provider/unsupported mode is silently coerced;
- tests require real Firebase projects or real user data;
- a mobile/UI fallback claims local confirmation;
- repository gates regress or unrelated dirty changes are overwritten.

Rollback removes only uncommitted/unactivated backend deployment artifacts or
disables flags. It never deletes committed Booking truth, rewrites an accepted
ADR or edits production documents manually.

## 14. Handoff

After this document is accepted and the external prerequisites are actually
met, implementation proceeds in four reviewable commits:

1. shared query contracts and TypeScript fixture consumer;
2. backend scaffold, Rules and disabled callable queries;
3. create/cancel transactions, ledger, usage, audit/outbox/idempotency;
4. emulator contention/security evidence and status reconciliation.

ECL-03D remains the next product stage only after ECL-03C is verified. Until
then Recharge continues to present provider handoff or an explicitly
unavailable internal action; it must not display a local/mock Booking as
confirmed.
