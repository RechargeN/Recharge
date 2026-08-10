# ECL-03 — Decision package D01–D10

- Версия: 1.1
- Дата: 2026-08-08
- Статус: **Accepted — normative D01–D10 product/architecture decisions**
- Parent spec:
  [EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md)
- Architecture proposal:
  [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md)
- Runtime effect: none

## 1. Назначение

Этот пакет фиксирует принятые значения ECL03-D01–D10. Parent spec включает
его по ссылке как normative contract, ADR 0019 имеет статус Accepted. Принятие
не включает runtime/deployment: production activation остаётся за Identity,
Privacy/Legal, Platform, notification и operations gates.

Рекомендации оптимизированы для первого Latvia launch, бесплатных внутренних
Booking, минимального operational риска и честного fail-closed поведения.

## 2. Решения в одном экране

| ID | Recommended decision | Status |
|---|---|---|
| `ECL03-D01` | `apps/backend` + Firebase Auth/Firestore + trusted Cloud Functions v2 commands; no direct client writes | Accepted |
| `ECL03-D02` | Separate dev/staging/prod projects; Firestore `eur3`; Functions/Scheduler `europe-west1`; App Check staged then enforced | Accepted |
| `ECL03-D03` | Production Auth/identity/page capability before Booking writes; contracts/backend/read-only/mobile/mutations in that order | Accepted |
| `ECL03-D04` | Data-minimizing retention table: 30/90/180-day classes; no indefinite ordinary retention | Accepted; legal validation before activation |
| `ECL03-D05` | Authoritative in-app inbox + FCM; FCM metrics are not per-booking proof; auto-release flag off until approved delivery evidence | Accepted |
| `ECL03-D06` | Policy v1: max 5 active finite-capacity Booking/holds per user; one allocation per Booking regardless of guest units | Accepted |
| `ECL03-D07` | Same-date shift under 2h keeps confirmation; date/≥2h shift requires reconfirmation when safely deliverable | Accepted |
| `ECL03-D08` | Launch with general-capacity pools only, including channel/auxiliary pools; complex shapes remain config-only | Accepted |
| `ECL03-D09` | 99.9% command availability target, p95 command 1.5s, zero oversell, one-minute worker targets, mandatory contention tests | Accepted |
| `ECL03-D10` | Audited backend-only repair; two-person approval for allocation/state repair; no direct document editing | Accepted |

## 3. D01 — Backend topology

### Recommendation

Accept the structural proposal from ADR 0019:

```text
apps/backend/
  firebase.json
  firestore.rules
  firestore.indexes.json
  functions/                 # Node.js/TypeScript, Cloud Functions v2
```

Use:

- Firebase Auth token as identity input;
- trusted callable/HTTPS Cloud Functions as mutation boundary;
- Firestore transactions for Booking/hold/ledger/usage/idempotency/outbox;
- Firestore Rules denying direct mobile writes to authoritative collections;
- language-neutral schemas in `packages/api_contracts`;
- generated/fixture-verified Dart and TypeScript DTOs;
- scheduled Functions for expiry/reconfirmation/reconciliation;
- app-level facades between mobile features.

Firestore transactions atomically apply all writes or none and may rerun on
contention, which is why transaction functions must be deterministic and side
effects must use an outbox after commit. The official transaction contract is
documented in [Firebase: transactions and batched writes](https://firebase.google.com/docs/firestore/manage-data/transactions).

### Rejected for v1

- direct mobile Firestore writes;
- REST endpoint that mutates separate records sequentially;
- local/offline confirmed Booking;
- Event-embedded participant arrays;
- a separate database or provider-specific Booking model.

### Acceptance record and implementation condition

ADR 0019 and D02–D10 were accepted as one package. Physical backend creation
still requires an explicit post-stabilization implementation authorization;
the Accepted architecture decision is not that authorization.

## 4. D02 — Regions, environments and service identities

### Recommendation

Use three physically separate Firebase/GCP projects:

```text
recharge-dev
recharge-staging
recharge-prod
```

Do not use one project with only runtime flags as environment isolation.

Location proposal:

```text
Firestore:       eur3 (Europe multi-region)
Cloud Functions: europe-west1 (Belgium)
Cloud Scheduler: europe-west1
API endpoint:    explicit europe-west1 client configuration
```

Firebase documents `eur3` as a European multi-region using Belgium and the
Netherlands with a Finland witness, and maps `eur3` to `europe-west1` as the
closest Functions region. See [Firestore locations](https://firebase.google.com/docs/firestore/locations)
and [Cloud Functions locations](https://firebase.google.com/docs/functions/locations).

Identity proposal:

- runtime command service account: Booking transaction access only;
- scheduler service account: invoke exact worker endpoints only;
- notification worker: outbox read/update and messaging permission only;
- CI deploy identity: environment-scoped deploy rights, no application read;
- support repair identity: disabled by default, short-lived elevation;
- no service-account JSON in repository or developer Flutter configuration.

App Check rollout:

1. integrate SDK and observe missing/invalid metrics in dev/staging;
2. verify legitimate mobile traffic;
3. enforce on mutation functions in production;
4. use replay protection only for high-risk commands after latency testing;
5. keep Auth/domain/idempotency checks mandatory because App Check is not user
   authorization.

Official guidance supports monitoring before enforcement and rejecting
missing/invalid tokens once enabled: [App Check for Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions).

### Approval caveat

Product location does not by itself settle GDPR/legal processing. Privacy and
Legal must approve D04 plus the final Firebase/GCP data-processing setup.

## 5. D03 — Dependency and release order

### Recommendation

Mandatory order:

1. production Firebase Auth for every Viewer;
2. server-owned active account/Creator verification/Page membership;
3. exact `manage_bookings`/publisher capability evaluation;
4. language-neutral Booking API schemas and compatibility fixtures;
5. backend deployment with all mutation flags off;
6. Security Rules/IAM/emulator proof;
7. read-only internal Booking readiness/availability projections;
8. mobile Booking module and routes with mutations disabled;
9. one staging Event with staff accounts;
10. production create/cancel flag for a bounded cohort;
11. approval/waitlist;
12. notification/reconfirmation after D05 evidence;
13. auxiliary tracks;
14. broader rollout after D09 operational review.

No step may infer production authority from current local/mock identity
fixtures. A blocked dependency keeps later flags off without creating a local
fallback.

## 6. D04 — Retention and deletion table

### Recommended beta table

| Data class | Active retention | Terminal retention | Terminal action |
|---|---:|---:|---|
| Booking core IDs/state | Through occurrence/obligation | 90 days | Remove user linkage; keep anonymous aggregate only if needed |
| Named guest identity | Through occurrence | 30 days | Delete |
| Application form fields | Until decision/occurrence | 30 days | Delete content; retain decision code |
| Eligibility evidence ref | Until final decision/occurrence | 30 days | Delete/revoke protected ref |
| Active hold | Until resolution | 30 days | Delete payload; retain audit event |
| Idempotency key/result | Command lifecycle | 30 days | Delete after retry window |
| Notification payload/outbox | Until delivered/dead-letter | 30 days | Delete rendered/private arguments |
| Delivery metadata | From delivery attempt | 90 days | Aggregate/anonymize |
| Booking audit | From occurrence/terminal state | 180 days | Pseudonymize or delete by approved policy |
| Security/support repair audit | From action | 180 days | Restricted archive/delete by policy |
| Ordinary structured operational logs | From emission | 30 days | Delete |
| Dead-letter diagnostic payload | Until resolved | Maximum 30 days | Delete after resolution |

Rules:

- retention is calculated by backend time and versioned policy;
- deletion workers are idempotent and produce privacy-safe completion audit;
- user deletion immediately blocks access and starts the approved deletion or
  pseudonymization workflow;
- no indefinite ordinary retention;
- no analytics copy of PII/free text/access evidence;
- backup propagation limit and exceptional legal/security hold must be fixed
  by Privacy/Legal before production;
- changing retention is a versioned policy migration, not a console-only edit.

These values are product recommendations, not legal advice. D04 remains open
until Privacy/Legal/Product approve the exact table and backup behavior.

## 7. D05 — Notification and reconfirmation delivery

### Recommendation

Use two surfaces:

1. authoritative in-app Notification inbox linked to Booking audit/outbox;
2. Firebase Cloud Messaging push as the first external delivery channel.

FCM reporting is useful for aggregate trends but may be delayed and does not
cover every delivery outcome. It must not be treated as proof that a specific
user received a reconfirmation request. See
[Firebase: understanding message delivery](https://firebase.google.com/docs/cloud-messaging/understand-delivery).

Therefore rollout is:

```text
event_internal_booking_reconfirmation = on (manual reconfirm only)
event_internal_booking_auto_release = off
```

Auto-release remains off until a separately approved delivery policy proves
the required user notice and defines failure handling across Android/iOS,
disabled notification permission, expired device tokens and device offline
states.

Minimum notification mechanics:

- transactional outbox entry with deterministic delivery key;
- in-app record written independently from push attempt;
- FCM token registration/revocation lifecycle;
- no Event/location/access secrets in push payload;
- safe deep link re-runs Auth/authorization;
- retry and dead-letter with operational alert;
- app-level acknowledgement when technically available;
- user-visible notification settings and consent;
- resend never creates a second Booking transition.

Scheduled Functions may overlap or invoke more than once, so every worker must
be idempotent and lease-protected. Official Firebase documentation explicitly
warns about overlapping scheduled invocations:
[Schedule functions](https://firebase.google.com/docs/functions/schedule-functions).

### Full ECL-03 requirement

ECL-03 cannot be Done with permanent `auto_release=off`; the flag is only the
safe initial rollout. Full approval requires resolving the delivery/fairness
policy rather than assuming that accepted-by-FCM means received-by-user.

## 8. D06 — Uniform concurrency policy v1

### Recommendation

```text
policyVersion: booking_concurrency_lv_v1
scope: internalCapacityHoldingBookings
maxConcurrentBookings: 5
appliesUniformly: true
countingRuleRef: active_confirmed_and_holds_v1
completionGraceMinutes: 120
```

Counting rule:

- one finite-capacity confirmed Booking counts as one;
- one active waitlist hold counts as one;
- guest/participant units do not increase the Booking count;
- one Booking can never be counted as both hold and confirmed;
- pending application, plain waitlist and unlimited RSVP do not count;
- cancellation, expiry, release or occurrence end + 120 minutes stops counting
  atomically;
- all future capacity-holding Booking count, not only a category/time window;
- no personal/category/publisher exceptions;
- lowering the cap never cancels existing Booking; it blocks new allocations;
- UI shows `5 active limited-place bookings` before final confirmation.

`5` is a recommended bounded-beta value, not a hidden permanent product rule.
Any change requires a new policy version, rollout note and before/after usage
simulation.

## 9. D07 — Occurrence reschedule behavior

### Recommendation

Classify reschedule by difference from the previously confirmed occurrence:

| Change | Booking behavior |
|---|---|
| Same local date and start shift under 2 hours | Keep confirmed; notify; preserve cancel option |
| Local date changes or start shift is 2 hours or more | Mark `reconfirmation required` if safe window exists |
| Venue/online mode materially changes | Require reconfirmation even when time shift is small |
| New start is under 24 hours away | Keep allocation; notify urgently; do not auto-release |
| Occurrence cancelled | Cancel/release all through bounded idempotent workflow |

Additional rules:

- stable occurrence and Booking IDs remain unchanged on reschedule;
- previous/new schedule and material revision are audited;
- reconfirmation deadline must leave at least 12 hours after verified notice
  and at least 6 hours before occurrence;
- if a valid notice/deadline cannot be formed, allocation remains confirmed;
- reschedule never silently moves a user to waitlist;
- user cancellation after a material reschedule is allowed regardless of the
  ordinary free cancellation deadline;
- auto-release follows D05 and remains disabled until delivery policy approval.

Thresholds are versioned launch policy and must be localized in user copy.

## 10. D08 — Initial inventory shapes

### Recommendation

Enable authoritative allocation only for:

- `generalCapacity`;
- one or more finite general-capacity pools;
- explicit `onsite`/`online` channel pools for hybrid Event;
- dedicated general-capacity auxiliary-track pools;
- explicit unlimited internal RSVP with no finite ledger allocation.

Keep configuration/read-only only for:

```text
sharedTicketPool
separateTicketPools with price/ticket semantics
zones
assignedSeating
teamSlots
participantRoles
roleBalancedSlots
tableInventory
timeSlotInventory
```

No enum is removed. Unsupported shapes fail closed with a capability reason
and retain ECL-02 round-trip. A later bounded extension needs shape-specific
allocation, cancellation, waitlist and race tests.

## 11. D09 — Staging SLO, load and stop conditions

### Recommended targets

| Signal | Target |
|---|---:|
| Valid command service availability | 99.9% monthly, excluding typed user/policy rejection |
| Booking command latency | p95 <= 1.5 s, p99 <= 3 s |
| Authorized read latency | p95 <= 750 ms |
| Oversell | 0 tolerated |
| Duplicate allocation/idempotency breach | 0 tolerated |
| Ledger/usage reconciliation drift | 0 unresolved; affected pool fails closed immediately |
| Hold-expiry worker lag | p95 <= 60 s; p99 <= 180 s |
| Outbox dispatch start | p95 <= 60 s |
| Dead-letter alert | <= 5 min |

Mandatory staging tests:

- 100 parallel requests competing for final capacity;
- 100 repeats of the same idempotency key;
- parallel allocations at cap boundary across occurrences;
- approve-vs-cancel;
- waitlist promote-vs-promote;
- hold accept-vs-expiry;
- cancel-vs-reconfirm;
- duplicate/overlapping scheduled workers;
- Rules tests for cross-user/cross-page/revoked identity;
- kill-switch activation during in-flight operations;
- reconciliation with intentionally corrupted fixtures.

Automatic rollout stop:

- any oversell;
- any duplicate confirmed allocation;
- any unauthorized read/write;
- any unexplained ledger/usage drift;
- p95 command latency above 3 seconds for 15 minutes;
- error rate above 2% for valid commands for 10 minutes;
- outbox dead-letter growth without bounded recovery.

Stop disables new create/approve/promote commands while preserving read,
cancel and safe release paths.

## 12. D10 — Support repair authority

### Recommendation

Capabilities:

```text
booking_support_read
booking_support_repair_propose
booking_support_repair_approve
booking_support_emergency_disable
```

Repair contract:

- backend-only internal tool or signed CLI; never Flutter/mobile console UI;
- production access uses short-lived identity elevation;
- every proposal requires incident/support ticket ID and reason code;
- dry-run returns affected IDs, invariant delta and before/after hashes;
- allocation/Booking-state repair requires a different second approver;
- proposer cannot approve own repair;
- exact command is idempotent and append-only audited;
- no direct Firestore console editing as supported procedure;
- repair cannot invent eligibility, bypass cap for a new Booking or create
  Payments/provider state;
- customer-visible state change emits the appropriate notification/outbox;
- emergency disable may stop new mutations immediately but cannot delete data;
- reconciliation verifies the repair before closing the incident.

Read-only investigation may use one authorized support actor. Any data export
or broad participant query requires a separately audited privacy-approved
workflow.

## 13. Acceptance effect

D01–D10 are accepted exactly as recommended:

1. copy the decisions into parent ECL-03 spec as normative values;
2. update ADR 0019 from Proposed to Accepted with decision evidence;
3. set ECL-03 spec from Review to Approved;
4. add the backend expansion to architecture baseline through ADR 0019;
5. keep every runtime flag off;
6. prepare and reconfirm the exact ECL-03B file plan;
7. allow only fixture-verified contracts/pure domain after that confirmation;
8. keep network mutations/backend activation blocked until production
   identity and the executable backend stage are ready.

Acceptance of this package does not authorize Firebase deployment,
production secrets, data collection or ECL-03 runtime by itself. Those actions
remain bounded by the approved implementation stages and environment gates.

## 14. Acceptance record

The product owner instructed the work to continue on 2026-08-08 immediately
after the assistant requested explicit acceptance of D01–D10, ADR 0019 and the
ECL-03 spec. The instruction is recorded as acceptance of the single complete
recommended package presented in v1.0; v1.1 changes status/record only and does
not alter the accepted values.
