# ADR 0019: Authoritative Internal Booking Ledger

- Status: Accepted
- Date: 2026-08-08
- Deciders: Recharge team
- Related: ADR 0011, ADR 0012, ADR 0013, ADR 0015,
  `docs/product/EVENT_CLASSIFICATION_SPEC.md` v2.2.3,
  `docs/product/EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md`,
  `docs/product/EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md`
- Scope: architecture decision only; Accepted status does not authorize runtime
  or production activation by itself

## Context

Event Classification v2.2.3 reserves ECL-03 for internal free registration,
authoritative Booking, atomic inventory, approval, waitlist, reconfirmation,
notifications and a uniform capacity-holding concurrency cap.

ECL-01 and ECL-02 intentionally stop at local Event configuration and honest
mock availability. The repository currently contains only the Flutter mobile
application, Dart API-contract package and local/mock datasources. It has no
production backend module, authoritative identity enforcement, transaction
processor, notification delivery or reconciliation worker.

A client-only implementation cannot prove capacity, prevent oversell, apply a
cross-event concurrency cap, expire holds or promote a waitlist atomically.
Persisting a local `confirmed` Booking would therefore create a false product
promise and violate the canonical Event contract.

ADR 0011 freezes the current monorepo tree. Adding a production backend or a
new top-level module requires an Accepted ADR. ADR 0015 additionally requires
server-owned authentication, Creator verification and page-scoped capability
checks for authoritative operations.

## Decision

### 1. Add an authoritative backend application

This Accepted ADR authorizes the target. Only after the separate
post-stabilization Firebase implementation gate is approved may the monorepo
physically gain one production backend application:

```text
apps/backend/
  firebase.json
  firestore.rules
  firestore.indexes.json
  functions/
    package.json
    tsconfig.json
    src/
      booking/
      inventory/
      notifications/
      policy/
      shared/
      generated/
    test/
```

The target implementation uses Firebase Auth as identity input, Firestore as
the durable store and trusted Cloud Functions as the command boundary. Exact
runtime versions, regions, environments and deployment identities are fixed
by the implementation plan before code is added.

This is an accepted expansion of the frozen baseline. Physical creation of the
directory remains controlled by the Approved ECL-03 implementation stages and
does not occur in ECL-03A.

### 2. Keep Booking separate from Event

`Booking`, `BookingHold`, inventory ledger records, notification delivery and
audit records are separate aggregates/operational records. Event stores only
versioned configuration such as admission, inventory, attendance policy and
auxiliary admission tracks.

Every Booking references stable IDs:

```text
userId
eventId
occurrenceId
inventoryPoolId?
channel?
auxiliaryTrackId?
```

Booking, holds, participant lists and counters are never embedded in Event or
Event draft JSON.

### 3. Use trusted commands for every capacity mutation

Mobile clients may read authorized projections but cannot directly create or
mutate Booking, holds, inventory counters, user concurrency usage or audit
records in Firestore. Firestore Rules deny those writes.

Capacity-changing actions go through versioned trusted commands. One
authoritative transaction checks all applicable preconditions before any
write:

1. authenticated active user;
2. Event/occurrence and registration readiness;
3. visibility, eligibility and access window;
4. inventory authority, pool, channel and requested units;
5. the uniform concurrency policy;
6. current ledger revision and remaining capacity;
7. command idempotency.

Failure creates no partial Booking/hold and changes no inventory.

### 4. Make inventory a ledger with explicit invariants

For each finite Recharge-owned occurrence pool:

```text
confirmedUnits + activeHoldUnits <= capacity
availableUnits = capacity - confirmedUnits - activeHoldUnits
```

Waitlisted entries without a hold consume zero units. Pending applications do
not reserve capacity. Approval, waitlist-offer acceptance, cancellation,
expiry and auto-release update Booking, hold, pool ledger and user concurrency
usage in the same authoritative transaction.

Host/offline quotas and capacity-consuming auxiliary tracks use explicit pools
in the same ledger. They are not a second mutable counter inside a visitor
pool, and a parallel participant list is not a source of truth.

### 5. Treat holds as expiring allocations, not payment commitments

`BookingHold` is a short-lived inventory allocation used only for free
waitlist promotion and race-safe confirmation. It has an expiry timestamp and
an idempotent release path. It is not a deposit, card authorization, Payment
or price guarantee.

The Booking lifecycle remains compatible with ADR 0013:

```text
pending | confirmed | cancelled | expired | waitlisted
```

An active waitlist offer is represented by a `waitlisted` Booking plus a
separate active hold. Accepting the offer moves the Booking to `confirmed`;
expiry or decline releases the hold and moves the Booking to its terminal
state according to the ECL-03 state-machine contract.

### 6. Enforce one uniform concurrency policy transactionally

The versioned `platformBookingConcurrencyPolicy` is backend-owned and is not
stored in Event or Event draft. It applies only to internal Booking/holds that
currently reserve finite capacity.

A per-user authoritative usage record is updated in the same transaction as
the allocation. The policy is identical for all users in the configured
launch scope and cannot depend on category, price, no-show history, inferred
reliability or other personal traits. There are no per-user overrides.

### 7. Use idempotent command and outbox records

Every mutation carries a client-generated immutable request ID. The backend
stores an idempotency record scoped to actor, command and request ID. A retry
returns the original typed result and cannot allocate twice.

Booking state changes append immutable audit events and transactional
notification-outbox entries. Delivery workers may retry independently; a
stable delivery key prevents duplicate user-visible notifications.

### 8. Use backend time and scheduled workers

Registration windows, hold expiry, cancellation deadlines and reconfirmation
deadlines are evaluated against authoritative backend time. Mobile time is
never trusted for eligibility or inventory mutation.

Scheduled workers process hold expiry, reconfirmation opening/deadlines and
retryable notification delivery. Every worker is lease-protected,
idempotent, bounded and safe to run more than once.

### 9. Share language-neutral API schemas

`packages/api_contracts` remains the contract source, extended with
language-neutral versioned schemas for Booking commands and responses. Dart
mobile DTOs and TypeScript backend validators are generated from the same
schema or verified against the same compatibility fixtures. Generated files
are never edited manually.

No raw infrastructure exception crosses the API boundary. Responses use
stable typed outcome/error codes, server timestamps, resource revisions and
correlation IDs.

### 10. Keep cross-feature integration behind facades

The mobile Booking product is an isolated `features/booking` module with
domain/data/application/presentation layers. Event Details, Create,
Notifications and Profile do not import it directly. App-level adapters and
facades connect features and satisfy their domain ports.

`EventCreateBlock` may render typed attendance/auxiliary configuration and
invoke controller commands, but it never contains Booking lifecycle,
inventory, transaction, notification or persistence logic.

### 11. Require online authority for mutation

Cached Booking and availability projections may be displayed with explicit
freshness. Offline clients may queue neither a confirmed Booking nor a
capacity-changing mutation. They show a retryable offline state until an
authoritative response is received.

### 12. Roll out behind independent kill switches

At minimum, independent remotely controlled switches exist for:

- new internal Booking creation;
- Creator approval actions;
- waitlist promotion and offer acceptance;
- reconfirmation scheduling;
- reconfirmation auto-release;
- auxiliary admission tracks.

Disabling a switch blocks new work but never deletes Booking, holds, audit or
notification obligations. Cancellation, safe release and participant access
remain available through a documented degraded-mode path.

## Explicit exclusions

This decision does not authorize:

- Payments, deposits, card authorization, refunds or payouts;
- paid internal tickets;
- external provider handoff or provider synchronization;
- lottery selection;
- team registration;
- assigned seating;
- QR/check-in or verified Attendance;
- personal reliability/risk scoring;
- scraping;
- secrets in Flutter, Event draft, analytics or logs.

## Security and privacy consequences

- Production Auth and exact resource capabilities are prerequisites, not
  client hints.
- Viewer commands are actor-bound; one user cannot read or mutate another
  user's Booking.
- Creator management requires PublisherRef ownership or exact-page
  `manage_bookings` capability.
- Admin support access is separately capability-gated and audited.
- Access codes, allowlists, waiver documents and private join/location data
  use protected references and are absent from public projections.
- Audit, idempotency, notification and Booking retention durations require an
  approved retention table before runtime rollout.

## Operational consequences

- Firebase emulator suites become mandatory for transactions, Rules,
  scheduled jobs and retries.
- Reconciliation jobs compare Booking allocations, active holds, user usage
  and pool ledgers; drift fails closed and alerts operators.
- Structured metrics cover command outcome, contention, idempotency hits,
  hold expiry, promotion latency, notification delivery and invariant drift.
- Incident and rollback runbooks are required before production enablement.

## Rejected alternatives

### Local/mock confirmed Booking

Rejected because a device cannot authoritatively reserve shared capacity or
apply a cross-event cap. A local confirmation would be misleading.

### Direct client writes to Booking and inventory documents

Rejected because Security Rules cannot replace the full multi-record domain
transaction, idempotency and audit contract.

### Store participant arrays and counters inside Event

Rejected because it mixes aggregates, produces hot/unbounded Event documents
and creates multiple sources of truth.

### Use last-write-wins for inventory

Rejected because last-write-wins permits oversell and lost releases.

### Count waitlist entries against capacity or cap

Rejected because a waitlist entry without a hold reserves nothing.

### Personal no-show scores or individual limits

Rejected by Event Classification v2.2.3. Any such system requires a separate
Trust/Risk, privacy, fairness and appeals decision.

## Implementation and production gates

The architecture decision is Accepted. Runtime implementation and production
activation remain independently gated by:

1. Firebase backend module and deployment topology;
2. production Auth/identity/capability dependency sequence;
3. Booking/hold/ledger transaction and idempotency model;
4. language-neutral API-schema/codegen approach;
5. notification delivery and scheduler ownership;
6. data region, retention and deletion policy;
7. security Rules and privileged support-access model;
8. kill-switch/degraded-mode behavior;
9. emulator, staging, load and reconciliation gates;
10. ECL-03 slice specification.

Until the applicable gate is complete, ECL-03 runtime remains blocked and
ECL-02 local/mock behavior is the only implemented Event availability
capability.

## Acceptance record

On 2026-08-08 the product owner instructed the work to continue immediately
after receiving the complete D01–D10 recommendation package and the explicit
notice that continuation meant acceptance. This records product/architecture
acceptance of D01–D10 exactly as documented in
`EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md` v1.1.

Privacy/Legal validation of retention/legal basis, Platform verification of
environment/region/service identities and production Identity readiness remain
activation gates. They do not silently replace the accepted values; a conflict
requires a documented ADR/spec revision.
