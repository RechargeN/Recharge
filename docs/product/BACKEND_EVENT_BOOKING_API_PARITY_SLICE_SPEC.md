# Recharge Backend — Event Booking API Contract Parity Slice

- ID: **BCK09-API-PAR-01**
- Version: **0.3**
- Date: **2026-08-28**
- Status: **Done — contracts and test-only parity verified on canonical Node 22.23.2**
- Scope: **Booking v1 contracts and test-only Dart/TypeScript parity**
- Runtime effect: **none**
- Firebase effect: **none**
- Accountable owner: **API Platform / RechargeN combined bootstrap owner**
- Parent named decision:
  [BCK09-API-NAMED-DEC-01 v0.2 — Accepted with controls](BACKEND_EVENT_BOOKING_NAMED_API_DECISION.md)
- API standard:
  [BCK-03 v0.3.6](BACKEND_API_CONTRACT_STANDARD.md)
- Booking target:
  [BCK-09 v1.10](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)
- Transaction-core plan:
  [ECL-03C v1.8](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md)
- Contract workflow:
  [API Contracts Workflow v1.1](../api/API_CONTRACTS_WORKFLOW.md)
- Canonical path:
  `docs/product/BACKEND_EVENT_BOOKING_API_PARITY_SLICE_SPEC.md`

---

## 0. Verdict

**The owner-approved v0.1 scope is implemented in commit `a7296f5` and verified
on the canonical hosted Node 22.23.2 toolchain. This bounded slice is Done.**

The slice closes only `BCK09-API-TR-06` contract parity and the pre-runtime
golden-vector part of `BCK09-API-TR-04`. It creates no handler, callable,
Firestore access, Rules/IAM binding, App Check enforcement, Firebase resource,
credential, deployment, mobile adapter or persisted Booking state.

Two amendments were required and are implemented:

1. ECL-03C names request/page/availability schemas but has no separate typed
   single-read response for `getMyBookingV1`. This slice adds
   `booking_read.schema.json`; a bare `Booking` object is not an adequate query
   result because it cannot carry `requestId`, `serverTime`, not-found privacy
   semantics or unsupported-contract handling.
2. The pre-slice TypeScript test only parsed schema/fixture JSON. Parseability is
   not schema validation, and `JSON.parse` cannot prove duplicate-key rejection.
   This slice adds an actual Draft 2020-12 consumer and an independent strict
   raw-JSON/hash test path.

No amendment expanded the approved scope. The implementation added no handler,
callable export, backend source, mobile code, Firebase resource, credential or
deployment configuration.

### 0.1. Recorded implementation evidence

- `packages/api_contracts` advanced to `0.3.0`;
- all four closed schema roots and the shared query/hash fixture corpora exist;
- Dart analyze is clean and the complete package suite passes `20/20`;
- Ajv 8.20.0 / ajv-formats 3.0.1 validate the shared schemas and the Node
  contract suite passes `10/10`;
- backend format, lint and strict typecheck pass;
- full mobile analyzer passes and the Flutter suite passes `664/664`;
- boundary scan passes: 380 files, 71/71 suppressions, 0 violations, 0 stale,
  0 expired;
- backend `src/`, mobile, Firebase/deployment files and Accepted ADRs are
  unchanged; `r0ToolchainProbe` remains the only backend export.

Initial local Node evidence was executed on Node 20.17. Commit `b734367` repaired
only the stale Ubuntu Temurin registry selector, preserving the locked
21.0.12+8 build. Hosted push run `33127684319` and pull-request run
`33127686757` then passed on both `ubuntu-24.04` and `windows-2025` with exact
Node 22.23.2, including Booking contract parity, emulator isolation,
reproducibility and Terraform gates. Codegen, lint, boundaries and the complete
mobile test workflow also passed on the same head SHA.

## 1. Authority and non-authority

The slice inherits exactly these Accepted Booking-v1 decisions:

- five named surfaces, no generic router;
- callable Functions v2 target in `europe-west1`;
- 10-second query, 15-second mutation and 30-second server deadlines;
- `booking_semantic_hash_v1` using RFC 8785 JCS UTF-8 and lowercase SHA-256;
- trusted `{kind: "user", id}` actor scope;
- applicable `expectedBookingRevision` and
  `occurredAgainstEventRevision` inside the semantic projection;
- `requestId` and `idempotencyKey` excluded from the semantic hash;
- integer-only range `-9007199254740991..9007199254740991`;
- no Unicode normalization, case folding or trimming after validation.

Acceptance of this plan would authorize only the exact files in §8. It would
not authorize anything under `apps/backend/functions/src/`, including
`index.ts`, nor change `apps/backend` from an R0 tooling scaffold into a
product backend.

## 2. Current-state findings

| ID | Current fact | Risk | Required disposition |
|---|---|---|---|
| `BCK09-PAR-TR-01` | Seven Booking schema roots exist; query/read/page/availability roots do not | Runtime could invent wire shape | Add four closed roots from one Booking-v1 source |
| `BCK09-PAR-TR-02` | Existing TypeScript test parses files but validates no fixture | False parity claim | Use a real Draft 2020-12 validator against shared bytes |
| `BCK09-PAR-TR-03` | Normal `JSON.parse` discards duplicate-key evidence | Unsafe input can appear validated | Use raw JSON vectors and duplicate-aware pre-parse inspection |
| `BCK09-PAR-TR-04` | `common.schema.json` revision has no safe-integer maximum | JCS implementations may disagree above IEEE-754 safe range | Bound all hashed revisions to the Accepted maximum |
| `BCK09-PAR-TR-05` | `applicationFields` may contain recursively open JSON | Fractional/unsafe nested numbers may reach hashing | Hash validator rejects every unsafe recursive value fail-closed |
| `BCK09-PAR-TR-06` | ECL-03C has no single-read response root | Get response/error privacy can drift | Add `booking_read.schema.json` |
| `BCK09-PAR-TR-07` | Callable framework receives parsed data | Later runtime may lack duplicate-key evidence | Keep runtime blocked until adapter/emulator proves raw-byte access |
| `BCK09-PAR-TR-08` | `src/index.ts` exports only `r0ToolchainProbe` | Test helper could accidentally become a product handler | Keep `src/` byte-identical and gate its export list |

## 3. Exact contract decisions proposed by this slice

### 3.1. Query request union

`booking_query.schema.json` is a closed `oneOf` union. Every variant requires:

```text
schemaVersion = 1
queryType = one exact variant
requestId = Accepted ECL03-D12 opaque bounded attempt ID
payload = closed variant-local object
```

Exact variants:

| `queryType` | Required payload | Optional payload | Forbidden |
|---|---|---|---|
| `getMyBooking` | `bookingId` | none | actor/user/page IDs, cursor, filters |
| `listMyBookings` | none | `pageSize`, `cursor`, `stateFilter` | actor/user/page IDs, arbitrary sort/filter |
| `getEventAvailability` | `eventId`, `occurrenceId` | `channel` | actor claims, requested capacity, reservation fields |

Rules:

- `pageSize` is an integer `1..50`, omitted means `20`;
- `cursor` is an opaque printable-ASCII token of 1–2048 characters, absent on
  the first page and never `null`;
- `stateFilter` is one current Booking-v1 state, not an arbitrary expression;
- IDs reuse the existing bounded Booking-v1 ID definition;
- unknown envelope/payload fields, unknown query types and explicit nulls fail
  closed as `invalid_contract` before any future repository call.

### 3.2. Single-read response

`booking_read.schema.json` is the response for `getMyBookingV1` and requires:

```text
schemaVersion = 1
queryType = "getMyBooking"
requestId
serverTime
kind = "found" | "notFound" | "unsupportedContract"
```

- `found` requires exactly one owner-safe `booking` projection;
- `notFound` contains no Booking or identity detail and is identical for an
  absent ID and an ID outside the actor's visibility;
- `unsupportedContract` carries only a bounded opaque `unsupportedPayload`;
- transport/internal failures are not encoded as empty `notFound` success;
- `requestId` is echoed exactly and is never treated as authorization.

### 3.3. Booking page response

`booking_page.schema.json` requires the same version/query/request/time fields
and a closed result union:

- `succeeded` requires `page`;
- `unsupportedContract` requires only bounded `unsupportedPayload`;
- `page.items` contains `0..50` owner-safe Booking projections;
- `page.nextCursor` is optional, never null, and uses the same cursor bound;
- `page.asOf` is a UTC server timestamp;
- `page.sort` is constant `createdAtDescIdDesc`;
- `page.consistency` is constant `liveKeyset`.

`liveKeyset` promises deterministic keyset ordering and query-bound cursors,
not a multi-page database snapshot. A later runtime cursor must bind version,
actor visibility, state filter, sort, last `(createdAt, bookingId)` tuple and
expiry. Cursor signing/verification is runtime work and is not implemented here.

### 3.4. Availability response

`booking_availability.schema.json` separates protocol result from domain
availability:

```text
kind = "succeeded" | "unsupportedContract"
availability.status =
  "available" | "limited" | "soldOut" | "closed" |
  "stale" | "unknown" | "unsupported"
availability.authority = "authoritative" | "nonAuthoritative"
availability.capacityMode = "finite" | "unlimited" | "notApplicable"
```

All successful projections require `eventId`, `occurrenceId`, `asOf`,
`eventRevision` and the resolved channel when applicable.

| Case | Required | Forbidden |
|---|---|---|
| finite authoritative | `ledgerRevision`, `availableUnits >= 0` | negative/fractional units |
| unlimited authoritative | `capacityMode=unlimited` | `availableUnits`, fake ledger allocation |
| `soldOut` finite | `availableUnits=0` | positive units |
| `stale/unknown/unsupported` | `authority=nonAuthoritative`, bounded `reasonCode` | reservable/confirmed wording |
| unsupported contract | bounded opaque payload only | domain availability |

`reasonCode` is closed: `source_stale`, `source_unavailable`,
`flow_unsupported`, `channel_unsupported` or `temporarily_unavailable`.
`stale` permits only `source_stale`; `unknown` permits
`source_unavailable|temporarily_unavailable`; `unsupported` permits
`flow_unsupported|channel_unsupported`.
`unsupportedPayload` is bounded in both consumers to 4096 canonical UTF-8
bytes, depth 8, 16 keys per object, 32 items per array and 512 Unicode scalar
values per string.

`getEventAvailabilityV1` remains non-reserving. No state in this schema can be
presented as a confirmed Booking.

### 3.5. Safe numeric and raw JSON boundary

`common.schema.json` gains a reusable safe integer definition. Existing
revision definitions are constrained to `0..9007199254740991`. This is a
pre-runtime corrective restriction required by the Accepted hash decision;
there is no deployed producer, stored command log or migration input.
The exported Dart `requireNonNegativeInt` primitive gains the same upper bound
so JSON Schema and `BookingCommandDto` cannot disagree on revisions.

The semantic hash path additionally checks every recursive value, including
open `applicationFields`. It rejects:

- duplicate object keys before ordinary JSON decoding;
- fractional and non-finite numbers;
- integers outside the Accepted safe range;
- unpaired UTF-16 surrogates;
- explicit null where the owning schema permits only absence;
- unsupported JSON/runtime value types.

### 3.6. Semantic projection and canonicalization

Both test consumers independently build exactly:

```json
{
  "algorithmVersion": "booking_semantic_hash_v1",
  "commandType": "<validated Booking v1 wire value>",
  "commandSchemaVersion": 1,
  "resolvedActorScope": {"kind": "user", "id": "<verified stable ID>"},
  "expectedBookingRevision": 7,
  "occurredAgainstEventRevision": 11,
  "payload": {}
}
```

Applicable revision fields are omitted when absent. The shown revision values
are illustrative integers. JCS object keys use RFC 8785/ECMAScript UTF-16 code
unit ordering; strings and integers serialize to exact UTF-8 bytes; SHA-256 is
lowercase hexadecimal. Neither language may read the expected digest as its
computed result.

## 4. Shared fixture corpus

### 4.1. Query fixtures

Add three independent fixture containers:

- `query_valid.json`: minimal/full request and result variants for all three
  queries, empty/non-empty/final pages, finite/unlimited availability;
- `query_invalid.json`: wrong types, missing/extra fields, null optionals,
  page bounds, cursor bounds/control characters, actor injection, inconsistent
  result unions and impossible availability combinations;
- `query_forward.json`: newer schema/query/status/critical enum values that
  must be rejected or preserved only as bounded unsupported payload.

### 4.2. Hash fixtures

`semantic_hash_vectors.json` stores, for every accepted case:

- exact raw Booking command JSON string;
- trusted resolved actor scope;
- expected projection object for audit;
- expected canonical UTF-8 bytes encoded as lowercase hexadecimal;
- expected lowercase SHA-256;
- optional equivalence/difference group ID.

`semantic_hash_invalid.json` stores raw strings and one stable expected reason
category. It must preserve duplicate keys and escaped unpaired surrogates as
raw text; no fixture loader may parse those strings before the strict consumer.

The corpus covers all 12 categories required by BCK09-API-NAMED-DEC-01:

1. key-order equivalence;
2. nested arrays/objects;
3. ASCII and supplementary Unicode;
4. NFC versus NFD distinction;
5. escaped versus literal equivalent Unicode;
6. absent revision versus invalid null;
7. changed Booking revision;
8. changed Event revision;
9. safe integer boundaries/equivalent spellings;
10. fractional/out-of-range/duplicate-key/unpaired-surrogate rejection;
11. changed `requestId` with equal semantic hash;
12. changed `idempotencyKey` with equal hash but different logical identity.

For category 12, logical identity means the Accepted tuple
`(resolved actor, commandType, idempotencyKey)`. This slice proves tuple
inequality; it does not create or persist the future Firestore record key.

## 5. Independent consumers

### 5.1. Dart

The Dart implementation lives only under `packages/api_contracts/test/` and:

- receives raw command JSON plus trusted actor scope;
- detects duplicate keys/unpaired surrogates before normal decoding;
- uses the existing closed Booking DTO/validator after raw checks;
- validates the recursive safe-value subset;
- constructs, canonicalizes and hashes the projection independently;
- asserts its bytes/digest against the shared fixture corpus.

`crypto 3.0.7` becomes an exact direct dev dependency; no runtime/mobile export
is added to `api_contracts.dart`.

### 5.2. TypeScript

The TypeScript implementation lives only under
`apps/backend/functions/test/` and:

- uses direct pinned dev dependencies `ajv 8.20.0` and
  `ajv-formats 3.0.1` for Draft 2020-12 fixture validation;
- runs Ajv 2020 with strict schemas, all errors enabled and format validation;
- registers every Booking-v1 root by canonical `$id`;
- validates the same valid/invalid/forward bytes as Dart;
- independently performs strict raw checks, JCS serialization and SHA-256;
- never imports Firebase Admin/Functions and never writes state;
- is not re-exported by `src/index.ts`.

The existing parse-only test is upgraded; it cannot remain the sole
TypeScript parity evidence.

## 6. Compatibility classification

| Change | Classification | Reason |
|---|---|---|
| four query/read/page/availability roots | additive | No current deployed consumer or endpoint |
| separate single-read response | required plan amendment | Prevents bare-entity/error ambiguity |
| safe revision maximum | corrective/restrictive pre-runtime | Required cross-language bound; no stored/deployed producer |
| new query/hash fixtures | additive evidence | No runtime behavior |
| `api_contracts` `0.2.1 -> 0.3.0` | pre-1.0 minor | Adds roots and test contract while preserving mutation wire names |
| direct dev dependencies | tooling only | Not exported into mobile or backend runtime |

No existing valid checked-in fixture may change meaning. If an existing
fixture becomes invalid, implementation stops and the plan returns to Review.

## 7. Explicit exclusions

This slice must not:

- modify any file under `apps/backend/functions/src/`;
- export `createInternalBookingV1`, `cancelInternalBookingV1` or any query;
- add Firebase configuration, project IDs, Rules, indexes, IAM, App Check,
  credentials, secrets, deploy scripts or production flags;
- create Firestore repositories, transactions, idempotency records or cursors;
- modify `apps/mobile/lib/`, `apps/mobile/test/`, Create/Event UI or DI;
- implement Booking lifecycle, inventory, availability calculation or actor
  authorization;
- add a generator or hand-edit generated files;
- claim `BCK09-SIG-API`, Security or Operations approval;
- change BCK-09/ECL-03C from Review or runtime from Absent.

Raw-body availability in Firebase callable v2 is deliberately not proven by
this slice. A later runtime adapter/emulator gate must prove duplicate-key
inspection is possible before any callable implementation can satisfy the
Accepted decision.

## 8. Exact implementation file plan

### 8.1. Add

| Path | Purpose |
|---|---|
| `packages/api_contracts/schema/booking/v1/booking_query.schema.json` | Closed three-query request union |
| `packages/api_contracts/schema/booking/v1/booking_read.schema.json` | Typed single-read response; required amendment |
| `packages/api_contracts/schema/booking/v1/booking_page.schema.json` | Bounded owner-safe list response |
| `packages/api_contracts/schema/booking/v1/booking_availability.schema.json` | Honest non-reserving availability response |
| `packages/api_contracts/schema/booking/v1/fixtures/query_valid.json` | Shared valid query/result cases |
| `packages/api_contracts/schema/booking/v1/fixtures/query_invalid.json` | Shared fail-closed cases |
| `packages/api_contracts/schema/booking/v1/fixtures/query_forward.json` | Forward/unsupported cases |
| `packages/api_contracts/schema/booking/v1/fixtures/semantic_hash_vectors.json` | Canonical bytes/digest corpus |
| `packages/api_contracts/schema/booking/v1/fixtures/semantic_hash_invalid.json` | Raw rejection corpus |
| `packages/api_contracts/test/support/booking_semantic_hash.dart` | Independent test-only Dart implementation |
| `packages/api_contracts/test/booking_query_fixture_test.dart` | Dart query/schema fixture proof |
| `packages/api_contracts/test/booking_semantic_hash_test.dart` | Dart hash/rejection proof |
| `apps/backend/functions/test/support/booking_schema_registry.ts` | Ajv Draft 2020-12 registry |
| `apps/backend/functions/test/support/booking_raw_json.ts` | Strict raw duplicate/surrogate inspection |
| `apps/backend/functions/test/support/booking_semantic_hash.ts` | Independent test-only TS JCS/SHA-256 |
| `apps/backend/functions/test/contract/booking_query_parity.test.ts` | Query/result fixture validation |
| `apps/backend/functions/test/contract/booking_semantic_hash.test.ts` | TS byte/digest/rejection proof |

### 8.2. Modify

| Path | Exact bounded change |
|---|---|
| `packages/api_contracts/schema/booking/v1/common.schema.json` | Safe integer, cursor/page/result primitives; revision maximum |
| `packages/api_contracts/lib/src/contracts/booking/booking_contract.dart` | Enforce the same maximum in shared Dart integer validation |
| `packages/api_contracts/test/support/booking_schema_fixture_validator.dart` | Register/validate new supported Draft 2020-12 roots only |
| `packages/api_contracts/test/booking_contract_test.dart` | Root IDs/closed vocabulary/safe-bound checks |
| `packages/api_contracts/test/booking_fixture_test.dart` | Preserve existing command/result fixture verdicts |
| `packages/api_contracts/pubspec.yaml` | Version `0.3.0`; exact test-only `crypto` dependency |
| `packages/api_contracts/pubspec.lock` | Mechanical dependency resolution |
| `packages/api_contracts/CHANGELOG.md` | Compatibility, evidence and frozen LF hashes |
| `apps/backend/functions/test/contract/booking_fixture_parity.test.ts` | Replace parse-only claim with actual schema validation |
| `apps/backend/functions/package.json` | Exact direct dev dependencies; `test:contract` uses `node --test` with the three explicit built test paths and no shell glob |
| `apps/backend/functions/package-lock.json` | Mechanical pinned lock update |

### 8.3. Must remain byte-identical

- `apps/backend/functions/src/index.ts`;
- every other file under `apps/backend/functions/src/`;
- `packages/api_contracts/lib/api_contracts.dart` and every Dart DTO file;
- `apps/backend/firebase.json`, Rules, indexes and infrastructure files;
- every file under `apps/mobile/`;
- Accepted ADRs.

### 8.4. Documentation after verified implementation

Only after all gates pass, a separate reconciliation commit may update:

- this slice to `Implemented/Review` or `Done` with exact evidence;
- BCK09-API-REV-01, BCK09-REV-01, BCK-09-PRE, BCK-09 and ECL-03C;
- BCK-03, BCK-01, BCK-02 and `LAUNCH_STATUS.md`.

Those status edits are not part of the initial contract/test implementation
commit and may not claim a specialist signature or runtime authority.

## 9. Verification matrix

| Gate | Required evidence |
|---|---|
| Diff scope | only §8.1–§8.2 implementation files; §8.3 byte-identical |
| Schema structure | all `$id` values unique, refs resolve, Draft 2020-12 roots parse |
| Dart package | `dart analyze` and full `dart test` green in `packages/api_contracts` |
| TypeScript | format check, ESLint, strict typecheck and all contract tests green |
| Shared parity | both languages consume the same committed query/hash bytes |
| Hash independence | neither implementation returns fixture expected bytes/digest as computation |
| Negative raw JSON | duplicate keys and unpaired surrogates rejected before ordinary decoding |
| Numeric boundary | min/max accepted; fractional/out-of-range rejected recursively |
| Compatibility | every existing valid/invalid/forward fixture keeps its verdict |
| R0 boundary | no product export; `r0ToolchainProbe` remains the only `index.ts` export |
| Cloud safety | no network call, emulator mutation, Firebase provisioning or deployment |
| Workspace | boundary checker, root diff check, Flutter analyzer and full tests green |
| Frozen evidence | LF-normalized SHA-256 recorded for schemas and fixture containers |

An unavailable dependency download, timeout, skipped test, parse-only check or
single-language result is `inconclusive`, never Pass.

## 10. Definition of Ready

Implementation may start only when:

1. this exact v0.1 plan is explicitly Approved by the Product owner;
2. the working tree is clean or unrelated owner changes are isolated;
3. baseline schema/fixture hashes are recorded before modification;
4. `BCK09-API-NAMED-DEC-01 v0.2` remains Accepted and unchanged;
5. the required `booking_read.schema.json` amendment is accepted;
6. dependency resolution is reproducible from pinned locks/cache or separately
   authorized network access;
7. no runtime/Firebase authorization is inferred from approval.

## 11. Definition of Done

The slice is Done only when:

1. all exact roots and fixture containers in §8 exist;
2. existing mutation/result contract verdicts remain unchanged;
3. all three query request and response families are closed and bounded;
4. not-found visibility is enumeration-safe;
5. availability states cannot imply reservation or confirmation;
6. Dart and TypeScript produce byte-identical JCS and SHA-256 results;
7. both independently reject every raw/numeric invalid vector;
8. all commands in §9 complete successfully;
9. `src/index.ts` and all backend runtime files are byte-identical;
10. no mobile, Firebase, deployment, data or credential file changed;
11. frozen hashes and exact tool versions are recorded;
12. documentation reconciliation reports runtime `Absent` and every specialist
    signature `Pending`.

## 12. Rollback

Before runtime, rollback is one revert of the isolated parity commit plus the
documentation reconciliation commit, if created. No data rollback, schema
migration, Firebase cleanup or client cutover exists.

The committed v0.2.1 package and its fixtures remain the recovery baseline.
Package `0.3.0` must not be consumed by a runtime or mobile adapter in this
slice, so rollback has no production compatibility window.

## 13. Risks and stop conditions

Stop and return the slice to Review if:

- query result vocabulary conflicts with an Accepted higher-priority contract;
- Ajv and Dart disagree on any shared fixture;
- exact JCS bytes differ between languages;
- duplicate-key rejection cannot be proven from raw fixture bytes;
- an existing fixture changes verdict;
- a required change escapes §8 or touches backend `src/`/mobile/Firebase;
- full repository gates expose a regression;
- dependency resolution requires unapproved network or lock drift.

## 14. Acceptance criteria

1. **BCK09-PAR-AC-01:** scope is contracts/test parity only.
2. **BCK09-PAR-AC-02:** implementation requires a separate explicit approval.
3. **BCK09-PAR-AC-03:** runtime and Firebase authority remain none.
4. **BCK09-PAR-AC-04:** four exact query/read/page/availability roots are named.
5. **BCK09-PAR-AC-05:** the missing single-read response is an explicit amendment.
6. **BCK09-PAR-AC-06:** query request variants are closed and actor-free.
7. **BCK09-PAR-AC-07:** page size defaults to 20 and is bounded by 50.
8. **BCK09-PAR-AC-08:** cursor is opaque, bounded, absent-first-page and never null.
9. **BCK09-PAR-AC-09:** not-found behavior is enumeration-safe.
10. **BCK09-PAR-AC-10:** page semantics disclose live keyset consistency.
11. **BCK09-PAR-AC-11:** availability is explicitly non-reserving.
12. **BCK09-PAR-AC-12:** non-authoritative states cannot expose reservable units.
13. **BCK09-PAR-AC-13:** safe integer bounds include all hashed revisions.
14. **BCK09-PAR-AC-14:** recursive open JSON is checked before hashing.
15. **BCK09-PAR-AC-15:** raw duplicate keys fail before normal decoding.
16. **BCK09-PAR-AC-16:** unpaired surrogates fail closed.
17. **BCK09-PAR-AC-17:** Unicode is not normalized, folded or trimmed.
18. **BCK09-PAR-AC-18:** semantic projection includes applicable revision fields.
19. **BCK09-PAR-AC-19:** request/idempotency identities remain outside the hash.
20. **BCK09-PAR-AC-20:** JCS bytes and lowercase SHA-256 are frozen.
21. **BCK09-PAR-AC-21:** all 12 named-decision vector categories are covered.
22. **BCK09-PAR-AC-22:** expected fixture hashes are not used as computed output.
23. **BCK09-PAR-AC-23:** Dart and TypeScript implementations are independent.
24. **BCK09-PAR-AC-24:** TypeScript performs real schema validation, not parsing only.
25. **BCK09-PAR-AC-25:** every canonical schema `$id` is registered exactly once.
26. **BCK09-PAR-AC-26:** existing fixture verdicts remain unchanged.
27. **BCK09-PAR-AC-27:** package change is classified and versioned `0.3.0`.
28. **BCK09-PAR-AC-28:** dependencies are direct, exact and lockfile-backed.
29. **BCK09-PAR-AC-29:** no generated file is hand-edited.
30. **BCK09-PAR-AC-30:** backend `src/` remains byte-identical.
31. **BCK09-PAR-AC-31:** `r0ToolchainProbe` remains the only exported function.
32. **BCK09-PAR-AC-32:** no mobile file is changed.
33. **BCK09-PAR-AC-33:** no emulator/runtime evidence is claimed by contract tests.
34. **BCK09-PAR-AC-34:** raw callable-body feasibility remains a later blocker.
35. **BCK09-PAR-AC-35:** all package/Node/workspace gates are explicit.
36. **BCK09-PAR-AC-36:** skipped, timed-out or unavailable gates are inconclusive.
37. **BCK09-PAR-AC-37:** frozen LF-normalized hashes are recorded.
38. **BCK09-PAR-AC-38:** rollback is zero-data and commit-bounded.
39. **BCK09-PAR-AC-39:** all nine specialist signatures remain Pending.
40. **BCK09-PAR-AC-40:** push, merge, provisioning and deployment remain separate actions.

## 15. Recorded approval

```text
Одобряю BCK09-API-PAR-01 v0.1 для contracts/test-only implementation.
Runtime, Firebase, callable exports и deployment не разрешаю.
```

The owner supplied this exact approval before commit `a7296f5`. It authorized
only the §8 contracts/test implementation. This reconciliation records the
result and does not authorize runtime work, push, merge, provisioning or
deployment.
