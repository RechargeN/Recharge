# Recharge Backend — Booking disabled runtime adapter slice

- ID: **BCK09-API-RAW-C-01**
- Version: **0.3**
- Date: **2026-09-03**
- Status: **Review — disabled implementation and cross-platform hosted evidence present; independent verdicts pending**
- Target: **ECL-03C disabled authoritative core / Booking wire v1**
- Product status after this document: **disabled local source Present; deployed runtime Absent**
- Firebase/Firestore/Admin effect of this document: **demo-recharge Emulator-only Rules/index/source and test evidence; no cloud effect**
- Callable export effect of this document: **exactly five disabled Emulator-only Booking v1 exports; no deployment or traffic**
- Deployment/activation authority: **none**
- Parent architecture:
  [ADR 0019 — Accepted](../adr/0019-authoritative-internal-booking-ledger.md)
- Parent product plan:
  [ECL-03C v1.11 — Review; disabled source and hosted evidence Present](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md)
- Backend contract:
  [BCK-09 v1.13 — Review; deployed runtime Absent](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)
- API review:
  [BCK09-API-REV-01 v0.10 — independent-evidence runtime Hold](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Required predecessor evidence:
  [BCK09-API-RAW-B-01 v0.1 — Done](BACKEND_EVENT_BOOKING_RAW_BODY_EMULATOR_SLICE_SPEC.md)

---

## 0. Decision and execution record

The owner granted the exact v0.1 executable permission recorded in §18. That
permission allowed only the tracked §8 backend files, exactly five Booking v1
callable exports and local `demo-recharge` Emulator-only Firestore/Admin use.
It did not authorize production/staging projects, credentials, cloud resources,
deployment, activation, mobile changes, ECL-03D–H, push or merge.

No broader RAW-C authority is implied by:

- approval of ADR 0019, BCK-09 or ECL-03C prose;
- completion of contract parity, RAW-A or RAW-B;
- this evidence reconciliation;
- an emulator pass, pull request, reviewer comment or green generic CI job.

Versions 0.2–0.3 record implementation and hosted evidence only. They change no v0.1 scope,
contract, runtime authority or activation boundary.

## 1. Outcome

RAW-C must answer one bounded question:

> Can the accepted Booking-v1 callable adapter and ECL-03C transaction core be
> implemented as a disabled, fail-closed, emulator-proven backend without
> changing wire semantics, creating a second writer, overselling inventory or
> creating any production/cloud effect?

The only valid final verdicts are:

- `Done — disabled core verified in Emulator`;
- `Fail — invariant or boundary violated`;
- `Inconclusive — required evidence missing, skipped, timed out or unpinned`.

Even `Done` means source and emulator evidence exist while the product remains
disabled. It does not mean deployed, production-ready, legally approved or
available to mobile clients.

## 2. Authority and invariants

Precedence is:

1. Accepted ADR 0019;
2. ECL-03 v1.3 and Accepted ECL03-D01–D12;
3. ECL-03C v1.11;
4. BCK-09 v1.13;
5. Accepted BCK09-API-NAMED-DEC-01 v0.2;
6. Booking wire v1 schemas, fixtures and semantic-hash vectors;
7. this RAW-C plan.

RAW-C must preserve:

- online server authority; local/mock state never confirms Booking;
- one Booking writer and one inventory-ledger writer inside BCK-09;
- BCK-07 as sole published Event lifecycle/config writer;
- BCK-08 as sole public composed availability writer;
- BCK-13 as sole notification delivery writer;
- BCK-19 as sole repair proposal/approval writer;
- server-derived actor, capabilities and time;
- separate `requestId`, `idempotencyKey` and server-issued `bookingId`;
- atomic finite-capacity allocation, duplicate-active protection and usage cap;
- explicit-unlimited behavior without silently treating unknown capacity as
  unlimited;
- immutable `suppressedPreActivation` outbox evidence with no dispatcher;
- no ECL-03D–H behavior or inherited authorization.

## 3. Prerequisites and blockers

### 3.1. Required before implementation starts

All of the following must be recorded:

1. explicit Product/Architecture approval of this exact v0.1 implementation;
2. explicit permission for tracked backend source, five callable exports and
   local Emulator-only Admin SDK/Firestore use;
3. clean or isolated checkout with exact base commit and protected-file hashes;
4. BCK09-API-RAW-B-01 v0.1 still Done on the pinned toolchain;
5. Booking wire v1 schemas/fixtures and semantic hashes unchanged;
6. independent API Platform and Security reviewers assigned for the resulting
   evidence; a Codex or combined-owner review is not their signature;
7. no real Firebase project, ADC, token, service-account key or production data
   available to the test process;
8. Node 22, npm, Firebase CLI, Functions/Admin SDK and Java versions remain
   exactly pinned by R0.

### 3.2. Still required after RAW-C

RAW-C cannot close:

- all nine BCK-09 specialist signatures;
- production Identity/account/capability/revocation authority;
- BCK-07 Event-projection writer and revision-safe handoff;
- qualified Latvia/market Legal and Privacy decisions;
- staging load, SLO, cost, restore, incident and rollback evidence;
- deployment IAM, project provisioning or release provenance;
- mobile remote adapter/cutover;
- any ECL-03D–H capability.

## 4. Included scope

Only the ECL-03C subset is included:

- authenticated Viewer self-service;
- free, instant, general-capacity Booking;
- finite capacity or explicit unlimited capacity;
- create and owner cancel mutations;
- owner get/list queries;
- authenticated non-reserving Event availability query;
- atomic Booking, ledger, usage, active-key, idempotency, audit and suppressed
  outbox records;
- fail-closed feature flags, auth/capability checks and server clock;
- direct-client deny Rules and exact required query indexes;
- isolated Emulator fixtures, concurrency/security tests and evidence;
- no activation: every product mutation flag remains false.

## 5. Explicit exclusions

RAW-C excludes:

- paid Booking, Payments, refunds or payment providers;
- external provider reservation or synchronization;
- applications, waitlists, holds, Creator approve/reject and reconfirmation;
- notification dispatch, FCM, email, task/queue worker or outbox replay;
- admin repair execution or direct/manual data repair;
- production/staging Firebase projects, IAM, billing, secrets or data;
- deployment, traffic, cohort, market enablement or release;
- mobile repository/data/application/presentation/DI changes;
- Event/Create/Discover runtime changes;
- migration/import of local bookings, participant counters or demo data;
- modifications to Accepted ADRs or Booking wire v1 semantics.

Any excluded behavior stops the slice and requires a new plan/decision.

## 6. Exact surfaces and records

### 6.1. Callable surfaces

If implementation is separately authorized, exactly these five v1 surfaces may
be exported:

| Surface | Type | Maximum client deadline | Disabled behavior |
|---|---|---:|---|
| `createInternalBookingV1` | mutation | 15 s | typed unavailable; no write |
| `cancelInternalBookingV1` | mutation | 15 s | typed unavailable; no write |
| `getMyBookingV1` | query | 10 s | typed unavailable; no read |
| `listMyBookingsV1` | query | 10 s | typed unavailable; no read |
| `getEventAvailabilityV1` | query | 10 s | typed unavailable; no read |

Every server timeout is 30 seconds. There is no generic method router and no
sixth debug/admin endpoint. Raw JSON is inspected before decoded `request.data`
is trusted. Auth, App Check mode, account/capability, feature flag and domain
checks execute in a fixed fail-closed order.

### 6.2. Operational collections

The collection count is exactly nine:

| Collection | Owner | RAW-C use |
|---|---|---|
| `bookingEventProjections` | BCK-07 writes; BCK-09 reads | synthetic Emulator fixture only until real handoff exists |
| `bookings` | BCK-09 | authoritative Booking aggregate |
| `bookingPoolLedgers` | BCK-09 | finite-capacity counters |
| `bookingUserUsage` | BCK-09 | active finite-allocation policy evidence |
| `bookingActiveKeys` | BCK-09 | deterministic non-terminal uniqueness lock |
| `bookingIdempotency` | BCK-09 | `m1_` logical mutation and `r1_` attempt records |
| `bookingAudit` | BCK-09 | append-only minimized mutation facts |
| `bookingOutbox` | BCK-09 | immutable `suppressedPreActivation` obligation evidence |
| `bookingFeatureFlags` | BCK-05 writes; BCK-09 reads | synthetic disabled-by-default Emulator fixture |

No tenth collection, nested shadow authority or alternate Event projection is
allowed. Test fixture seeding is isolated from product handlers and does not
establish production ownership.

## 7. Fail-closed execution order

Each callable must follow the same observable order:

1. capture correlation metadata without logging raw body or personal values;
2. require expected callable method/region/version;
3. inspect exact `rawRequest.rawBody` with the completed RAW-A rules;
4. validate closed Booking wire v1 command/query shape;
5. compare strict raw value with framework-decoded `request.data`;
6. resolve verified Auth actor; reject absent/disabled/unknown account state;
7. apply environment-specific App Check policy;
8. resolve server-owned capability and market/cohort gates;
9. require the relevant product flag to be explicitly enabled;
10. execute query or one Admin SDK Firestore transaction;
11. map only through the accepted Booking v1 typed result vocabulary;
12. emit privacy-minimized audit/metrics after the authoritative outcome.

Before activation, step 9 always denies product operations. Emulator tests may
enable a synthetic test-only flag only inside a per-test isolated project and
must reset it during cleanup. Missing, malformed or unreadable configuration is
disabled, never permissive.

## 8. Exact implementation file plan

This section is a plan, not authorization. Paths not listed here require a plan
revision and new approval before editing.

### 8.1. Added under the recorded v0.1 approval

| Path | Purpose |
|---|---|
| `apps/backend/functions/src/contracts/booking_v1.ts` | fixture-backed TypeScript Booking wire consumer |
| `apps/backend/functions/src/shared/auth_context.ts` | verified actor/account boundary |
| `apps/backend/functions/src/shared/feature_flags.ts` | fail-closed environment and market gates |
| `apps/backend/functions/src/shared/server_clock.ts` | server-time port |
| `apps/backend/functions/src/shared/failures.ts` | stable callable/domain error mapping |
| `apps/backend/functions/src/booking/domain.ts` | ECL-03C state and invariants |
| `apps/backend/functions/src/booking/idempotency.ts` | semantic hash and split-key records |
| `apps/backend/functions/src/booking/transactions.ts` | single Admin SDK transaction boundary |
| `apps/backend/functions/src/booking/create_internal_booking.ts` | create orchestration |
| `apps/backend/functions/src/booking/cancel_internal_booking.ts` | cancel orchestration |
| `apps/backend/functions/src/booking/booking_queries.ts` | owner get/list projections |
| `apps/backend/functions/src/booking/availability_query.ts` | non-reserving availability query |
| `apps/backend/functions/src/inventory/ledger.ts` | finite-capacity invariants |
| `apps/backend/functions/src/inventory/active_key.ts` | duplicate-active key contract |
| `apps/backend/functions/src/policy/concurrency.ts` | D06 policy v1 usage cap |
| `apps/backend/functions/src/audit/booking_audit.ts` | minimized append-only audit fact |
| `apps/backend/functions/src/notifications/outbox.ts` | suppressed obligation writer only |
| `apps/backend/functions/test/support/booking_emulator.ts` | loopback demo-project lifecycle and cleanup |
| `apps/backend/functions/test/support/booking_fixtures.ts` | synthetic account/Event/pool fixtures |
| `apps/backend/functions/test/support/fake_clock.ts` | deterministic server time |
| `apps/backend/functions/test/unit/booking_domain.test.ts` | finite/unlimited/cap/guest invariants |
| `apps/backend/functions/test/unit/booking_idempotency.test.ts` | split-key/hash/replay matrix |
| `apps/backend/functions/test/unit/booking_active_key.test.ts` | tuple/hash/mismatch tests |
| `apps/backend/functions/test/unit/booking_outbox.test.ts` | suppression/non-replay tests |
| `apps/backend/functions/test/emulator/booking_create.test.ts` | atomic create/refusal tests |
| `apps/backend/functions/test/emulator/booking_cancel.test.ts` | atomic cancellation/release tests |
| `apps/backend/functions/test/emulator/booking_queries.test.ts` | authorization/pagination/freshness tests |
| `apps/backend/functions/test/emulator/booking_contention.test.ts` | oversell/cap/idempotency contention tests |
| `apps/backend/functions/test/emulator/booking_security.test.ts` | Rules/Auth/App Check/flag denial matrix |

### 8.2. Modified under the recorded v0.1 approval

| Path | Exact bounded change |
|---|---|
| `apps/backend/functions/src/index.ts` | retain R0 probe and add exactly five disabled Booking v1 exports |
| `apps/backend/functions/package.json` | add bounded unit/emulator scripts; no unapproved dependency range |
| `apps/backend/functions/package-lock.json` | change only if an explicitly approved pinned dependency is necessary |
| `apps/backend/firebase.json` | register existing Functions/Firestore Emulator inputs only; no project alias/deploy target |
| `apps/backend/firestore.rules` | deny direct access to all nine authoritative collections |
| `apps/backend/firestore.indexes.json` | add only fixture-backed owner/date query indexes |
| `apps/backend/scripts/run-emulator-tests.mjs` | orchestrate isolated RAW-C suite and cleanup |
| `.github/workflows/backend-r0.yml` | run RAW-C gates on Ubuntu/Windows with no cloud credentials |
| affected BCK-09/ECL-03C/status docs | record exact evidence without promoting activation |

### 8.3. Must remain unchanged

- `apps/mobile/**`;
- `packages/api_contracts/schema/booking/v1/**` and frozen valid/invalid/forward
  fixtures unless a separate contract-major/correction slice is approved;
- `docs/adr/**`;
- Event/Create/Discover application runtime;
- Terraform provider/resource topology;
- `.firebaserc`, production aliases, credentials and deployment workflows.

## 9. Implementation phases

RAW-C implementation must remain reviewable and stop between phases:

### RAW-C0 — baseline freeze

- record base commit, tool versions and protected-file hashes;
- prove current R0, parity and RAW-B suites green;
- verify no cloud context and no untracked dependency on generated output.

### RAW-C1 — pure core and adapters

- implement contract consumer, domain invariants, keys, result mapping and
  ports without Firestore execution;
- unit-test every accepted/refused/unknown-outcome path;
- preserve raw-body and semantic-hash vectors byte-for-byte.

### RAW-C2 — disabled Emulator persistence

- implement the single Admin SDK transaction boundary and nine-collection
  model for `demo-recharge` only;
- keep product flags false by default;
- test finite/unlimited create, cancel, owner reads and non-reserving
  availability with synthetic fixtures.

### RAW-C3 — concurrency and security evidence

- prove atomicity, no oversell, active-key uniqueness, five-slot policy,
  idempotent replay and request-attempt conflict behavior;
- prove direct client access denied, actor isolation, disabled flags and
  missing/invalid Auth/App Check fail closed;
- run on pinned Ubuntu and Windows hosted CI.

### RAW-C4 — reconciliation only

- record exact commit/run/job/tool versions and test counts;
- verify no deployment, cloud resource or residual fixture exists;
- keep BCK-09/ECL-03C in Review unless their own approval conditions pass;
- keep all product flags off and all specialist signatures Pending unless a
  named specialist independently signs their bounded scope.

## 10. Required test matrix

### 10.1. Contract and adapter

- all valid/invalid/forward Booking fixtures;
- all RAW-A/RAW-B Unicode, duplicate-key, numeric and wrapper vectors;
- raw/framework equality and stable semantic hashes;
- exact five methods, deadlines, region and error mappings;
- unknown schema, enum, flow and result fail closed.

### 10.2. Transaction invariants

- finite create/cancel and exact ledger/usage release;
- explicit-unlimited path with no ledger or usage allocation;
- unknown capacity refusal;
- same idempotency key/hash replay without second write;
- same key/different hash conflict without mutation;
- same request ID/different command/key/hash refusal;
- stable server-generated Booking ID across callback retries;
- transaction exception leaves no partial Booking, key, ledger, usage, audit,
  outbox or idempotency record;
- sold out creates no waitlist record.

### 10.3. Concurrency

- at least 100 parallel same-actor/same-scope creates with distinct logical
  keys commit exactly one active Booking for finite and unlimited paths;
- finite pool contention never exceeds capacity;
- actor usage never exceeds five active finite allocations;
- parallel cancellation/retry releases exactly once;
- dangling or mismatched active key fails closed and is not auto-repaired.

### 10.4. Authorization and privacy

- unauthenticated, inactive, revoked, unknown and wrong-owner requests deny;
- body-supplied actor/role/capability/time is ignored and rejected where
  contract-forbidden;
- direct client reads/writes to nine collections deny;
- another user's Booking existence is not disclosed;
- logs/results exclude raw body, tokens, contact data, idempotency keys and
  internal collection paths;
- outbox is non-dispatchable and cannot be replayed or upgraded.

## 11. Verification gates

Every gate is mandatory; skipped or timed-out means `Inconclusive`:

1. no-cloud-context and exact toolchain verification;
2. Prettier, ESLint and strict TypeScript typecheck;
3. all existing R0, contract, RAW-A and RAW-B tests;
4. RAW-C unit, emulator, Rules and contention suites;
5. generated-output and reproducibility checks;
6. repository boundary and protected-diff checks;
7. full mobile `flutter analyze` and `flutter test` regression gate;
8. Ubuntu and Windows hosted CI on the exact commit;
9. no temporary Emulator source/data/config/process after success or failure;
10. no cloud resource, credential, deployment or real project access;
11. all product flags false in tracked/default state;
12. draft pull request remains unmerged.

## 12. Evidence record

The completion record must include:

- exact base/head commit hashes and clean/dirty status;
- immutable input hashes for Booking wire v1 and RAW-B corpus;
- Node/npm/Java/Firebase CLI/Functions/Admin/TypeScript versions;
- Ubuntu and Windows run/job URLs or IDs;
- per-suite test counts, duration and verdict;
- Emulator project ID, ports and cleanup proof;
- Rules/index snapshot and direct-access denial results;
- list of five exports and nine collections;
- proof that production flags, deployments and cloud resources remain absent;
- failures and retries, not only the final green run.

### 12.1. Local evidence — 2026-09-03

| Gate | Result |
|---|---|
| Base commit | `3b1df20` |
| RAW-C implementation commit | `02c6e79` |
| Node unit suite | Pass, 13/13 on Node 22.23.2 |
| Booking contract suite | Pass, 15/15 on Node 22.23.2 |
| Disposable Firebase Emulator suite | Pass, 23/23; cleanup completed |
| Formatting, lint, strict TypeScript | Pass |
| No-cloud-context check | Pass |
| Generated-output verification | Pass, 88 files |
| Reproducibility | Pass, digest `a5202fe025855d175c6c58add5614859fc568e48547717ad499ff7c4776ddecd` |
| Mobile regression | `flutter analyze --no-pub` pass; `flutter test --no-pub` 664/664 pass |
| Protected diff | No mobile, frozen Booking schema or Accepted ADR edit |
| Repository boundary gate | Pass: 380 files, 71/71 suppressed, 0 violations, 0 stale/expired exceptions |
| Exact hosted toolchain | Pass on Ubuntu 24.04 and Windows 2025 with pinned Node/npm/JDK/workflow checks |
| Ubuntu/Windows hosted CI | Pass at `75818f78c67e9bcfa06edbc12820424235c39627`; push run `33689696133` and pull-request run `33689700189` |
| Independent specialist verdicts | Pending |

Local and hosted implementation/Emulator behavior pass their bounded checks.
The slice verdict remains **Inconclusive** only because the mandatory
independent specialist verdicts in §11 are Pending. No cloud project, credential, deployment,
activation, mobile runtime integration or production data was used.

## 13. Stop conditions

Stop immediately and return to Review if:

- any requested edit is outside §8;
- wire semantics or a frozen fixture/hash must change;
- a sixth endpoint or tenth collection appears;
- a domain write becomes non-atomic or crosses ownership boundaries;
- any contention run oversells, duplicates active Booking or exceeds policy;
- real project credentials, non-loopback endpoints or cloud deployment are
  required;
- a product flag defaults true or a handler can bypass it;
- Auth/App Check/account/capability uncertainty becomes allow;
- Windows and Ubuntu results disagree;
- cleanup, reproducibility, boundaries or mobile regression fails;
- an independent required reviewer returns Hold/Reject.

No workaround may replace callable transport, loosen validation, use local/mock
authority or disable a gate without a versioned decision.

## 14. Rollback

Before deployment, rollback is commit-bounded:

1. keep every Booking flag false;
2. revert the isolated RAW-C implementation commits;
3. remove only runner-owned validated Emulator artifacts;
4. rerun R0, parity, RAW-B, boundary and mobile regression gates;
5. reconcile docs back to runtime Absent/RAW-C not Done.

RAW-C never deletes or rewrites production data because it is forbidden from
creating or touching production data. A rollback requiring a cloud console or
manual Firestore edit proves the slice exceeded its authority.

## 15. Definition of Ready

RAW-C implementation entered execution only after the exact §18 permission was
recorded and the §8 plan was revalidated. This readiness record grants no
permission beyond v0.1.

## 16. Definition of Done

RAW-C is Done only when:

- all phases C0–C4 and all §11 gates pass on the exact commit;
- the five surfaces and nine collections match the accepted contracts exactly;
- concurrency, idempotency, authorization and privacy evidence is complete;
- all tracked/default product flags remain off;
- no mobile adapter, cloud resource, deployment or production data exists;
- independent reviews record their real verdicts without being inferred;
- BCK-09 and ECL-03C are reconciled honestly as disabled/Review unless their
  separate approval conditions are met.

`Done — disabled core verified in Emulator` still does not authorize staging,
production, activation, ECL-03D–H, mobile cutover or merge to `main`.

## 17. Acceptance criteria

1. **BCK09-RAW-C-AC-01:** v0.1 scope received exact implementation approval; v0.2–0.3 only reconcile evidence.
2. **BCK09-RAW-C-AC-02:** implementation authority is limited to the exact §18 permission.
3. **BCK09-RAW-C-AC-03:** RAW-B is a prerequisite, not runtime authority.
4. **BCK09-RAW-C-AC-04:** Booking wire v1 remains unchanged.
5. **BCK09-RAW-C-AC-05:** Accepted ADR 0019 and D01–D12 remain authoritative.
6. **BCK09-RAW-C-AC-06:** scope is ECL-03C only.
7. **BCK09-RAW-C-AC-07:** ECL-03D–H inherit no permission.
8. **BCK09-RAW-C-AC-08:** exactly five callable surfaces exist after authorized implementation.
9. **BCK09-RAW-C-AC-09:** there is no generic router or debug/admin endpoint.
10. **BCK09-RAW-C-AC-10:** raw bytes are validated before decoded data is trusted.
11. **BCK09-RAW-C-AC-11:** actor/capability/time are server-derived.
12. **BCK09-RAW-C-AC-12:** unknown identity or configuration denies.
13. **BCK09-RAW-C-AC-13:** product flags default false.
14. **BCK09-RAW-C-AC-14:** test-only enablement is isolated and cleaned.
15. **BCK09-RAW-C-AC-15:** collection count remains nine.
16. **BCK09-RAW-C-AC-16:** there is no parallel Event or availability writer.
17. **BCK09-RAW-C-AC-17:** finite allocation is one atomic transaction.
18. **BCK09-RAW-C-AC-18:** explicit unlimited never creates ledger/usage allocation.
19. **BCK09-RAW-C-AC-19:** unknown capacity never confirms.
20. **BCK09-RAW-C-AC-20:** create and cancel maintain active-key consistency.
21. **BCK09-RAW-C-AC-21:** one hundred same-scope creates commit exactly one active Booking.
22. **BCK09-RAW-C-AC-22:** pool contention never oversells.
23. **BCK09-RAW-C-AC-23:** the five-active-finite policy is atomic.
24. **BCK09-RAW-C-AC-24:** idempotent replay never allocates twice.
25. **BCK09-RAW-C-AC-25:** conflicting key/attempt reuse fails before mutation.
26. **BCK09-RAW-C-AC-26:** one server Booking ID survives callback retries.
27. **BCK09-RAW-C-AC-27:** transaction failure leaves no partial records.
28. **BCK09-RAW-C-AC-28:** sold out creates no waitlist.
29. **BCK09-RAW-C-AC-29:** owner reads do not disclose another user.
30. **BCK09-RAW-C-AC-30:** availability reserves nothing.
31. **BCK09-RAW-C-AC-31:** direct client access to nine collections is denied.
32. **BCK09-RAW-C-AC-32:** logs/results contain no raw or personal secrets.
33. **BCK09-RAW-C-AC-33:** outbox records are suppressed and non-replayable.
34. **BCK09-RAW-C-AC-34:** no notification dispatcher exists.
35. **BCK09-RAW-C-AC-35:** no repair or cross-domain mutation is introduced.
36. **BCK09-RAW-C-AC-36:** only demo project and loopback are allowed.
37. **BCK09-RAW-C-AC-37:** no ADC, token, key or real data is used.
38. **BCK09-RAW-C-AC-38:** no cloud resource is provisioned.
39. **BCK09-RAW-C-AC-39:** no deployment or traffic assignment occurs.
40. **BCK09-RAW-C-AC-40:** mobile/Create/Event/Discover runtime is unchanged.
41. **BCK09-RAW-C-AC-41:** exact pinned toolchains are verified.
42. **BCK09-RAW-C-AC-42:** Ubuntu and Windows evidence is mandatory.
43. **BCK09-RAW-C-AC-43:** skipped/timeout evidence is Inconclusive.
44. **BCK09-RAW-C-AC-44:** existing R0/parity/RAW-B gates remain green.
45. **BCK09-RAW-C-AC-45:** cleanup and reproducibility failures fail the slice.
46. **BCK09-RAW-C-AC-46:** protected boundaries and full mobile gates remain green.
47. **BCK09-RAW-C-AC-47:** all nine specialist signatures remain independent.
48. **BCK09-RAW-C-AC-48:** RAW-C Done does not equal production readiness.
49. **BCK09-RAW-C-AC-49:** staging/production requires a later exact approval.
50. **BCK09-RAW-C-AC-50:** push and merge remain separately authorized.

AC numbers are stable. New criteria append; a semantic change requires a new
version and a reference migration note.

## 18. Recorded implementation approval

The owner recorded the following exact approval before implementation:

```text
Одобряю BCK09-API-RAW-C-01 v0.1 для disabled ECL-03C
implementation и disposable Firebase Emulator evidence. Разрешаю только
перечисленные в §8 tracked backend-файлы, ровно пять Booking v1 callable
exports и локальный demo-recharge Emulator-only Firestore/Admin access.
Production/staging projects, credentials, cloud resources, deployment,
activation, mobile changes, ECL-03D–H, push и merge не разрешаю.
```

This approval is consumed only by RAW-C v0.1. It does not authorize push,
merge, staging, production, deployment, activation, mobile integration or a
later ECL-03 stage.
