# Recharge Backend — Event Booking Named API Decision Package

- ID: **BCK09-API-NAMED-DEC-01**
- Version: **0.1**
- Date: **2026-08-27**
- Status: **Proposed — explicit combined-owner verdict required**
- Decisions in scope: **BCK-03 `API-DEC-01` and `API-DEC-03` for Booking v1**
- Accountable roles: **API Platform + BCK-05 Operations; API Platform + Security**
- Assigned combined owner: **RechargeN / Product owner**
- Independence: **none; independent Security/Operations review remains required by later gates**
- Runtime effect: **none**
- Product baseline:
  [BCK09-API-DEC-01 v0.3](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Technical pre-review:
  [BCK09-API-REV-01 v0.4](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Contract correction:
  [BCK09-API-CORR-01 v0.3 — Done](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)
- Parent target:
  [BCK-09 v1.7](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)
- Transaction-core plan:
  [ECL-03C v1.5](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md)
- Canonical path:
  `docs/product/BACKEND_EVENT_BOOKING_NAMED_API_DECISION.md`

---

## 0. Proposed verdict

**Accept both Booking-scoped decisions with controls and one required semantic
amendment.**

- `API-DEC-01` candidate:
  `API01-BCK09-CALLABLE-V2-EU-10-15-30-v1`.
- `API-DEC-03` candidate:
  `API03-BCK09-JCS-SHA256-SEMANTIC-v1`.
- Required amendment: the semantic projection includes every validated
  revision precondition that can change mutation meaning. The earlier Product
  projection omitted `expectedBookingRevision` and
  `occurredAgainstEventRevision`; accepting that omission would permit two
  semantically different attempts to share one payload hash.

This package is a decision proposal, not an implementation approval. Until an
explicit verdict is recorded, both BCK-03 decisions remain `Open`. Even after
Acceptance, no callable, TypeScript runtime module, Firebase resource,
credential, deployment or production mutation is authorized.

## 1. Scope and authority

This package may decide only the Booking-v1 use of BCK-03 `API-DEC-01` and
`API-DEC-03`. It does not decide transport or hashing for another domain and
does not create a platform-wide default outside ADR-authorized Booking.

Authority order remains:

1. Accepted ADR 0019 and ECL-03 D01–D12;
2. Approved ECL-03 and Accepted Event Classification v2.2.3;
3. this named decision after explicit Acceptance;
4. BCK-09/ECL-03C implementation plans;
5. schemas, fixtures and executable consumers.

The Product-selected baseline is input evidence, not a named API, Operations
or Security signature. `RechargeN / Product owner` is the assigned combined
bootstrap owner. That concentration of roles is disclosed and does not claim
independent professional Security, Operations or Legal review.

## 2. Technical reconciliation findings

| ID | Finding | Disposition |
|---|---|---|
| `BCK09-NAPI-TR-01` | Product hash projection omitted top-level revision preconditions | Required amendment in §4.2 |
| `BCK09-NAPI-TR-02` | `safe numeric subset` was named but not bounded exactly | Freeze integer-only cross-language subset in §4.3 |
| `BCK09-NAPI-TR-03` | `resolvedActorScope` had no exact Booking-v1 shape | Freeze verified User scope in §4.2 |
| `BCK09-NAPI-TR-04` | Callable target had no exact five-surface mapping table | Freeze mapping in §3.2 |
| `BCK09-NAPI-TR-05` | Documentation values could be mistaken for deployable configuration | Keep all runtime and evidence gates in §5–§7 |

The command union and D12 request-ID parity are already closed by
`BCK09-API-CORR-01 v0.3`. This package does not reopen those semantics.

## 3. `API-DEC-01` — callable transport profile

### 3.1. Candidate record

| Field | Decision value |
|---|---|
| Decision ID | `API-DEC-01` |
| Candidate ID | `API01-BCK09-CALLABLE-V2-EU-10-15-30-v1` |
| Scope | Booking v1 / ECL-03C five-surface boundary only |
| Transport | Firebase callable Functions v2 |
| Region | explicit `europe-west1` |
| Query client deadline | 10 seconds |
| Mutation client deadline | 15 seconds |
| Server timeout | 30 seconds per callable |
| Generic router | forbidden |
| Runtime status | Absent and unauthorized |

### 3.2. Exact surface map

| Surface | Kind | Deadline | Result boundary |
|---|---|---:|---|
| `createInternalBookingV1` | mutation | 15 s client / 30 s server | existing Booking v1 result/error union |
| `cancelInternalBookingV1` | mutation | 15 s client / 30 s server | existing Booking v1 result/error union |
| `getMyBookingV1` | query | 10 s client / 30 s server | owner-safe Booking projection |
| `listMyBookingsV1` | query | 10 s client / 30 s server | bounded stable page projection |
| `getEventAvailabilityV1` | query | 10 s client / 30 s server | non-reserving authoritative availability |

One deployed function may expose exactly one named surface. A generic method
router, raw Firestore transport, REST double-envelope or alternate success
union is outside the candidate.

### 3.3. Context and outcome rules

- actor authority is derived from current verified Auth context;
- App Check is environment-controlled defense in depth and never substitutes
  for Auth, authorization, validation, idempotency or abuse controls;
- transport success means only that a typed Booking-v1 result was returned;
- connection loss, client deadline or server timeout is an **unknown outcome**,
  never confirmation or deterministic domain rejection;
- a mutation recovery attempt preserves the semantic command and
  `idempotencyKey` but uses a fresh D12 `requestId`;
- an authorized query may resolve an unknown mutation outcome;
- automatic SDK retry cannot create a new logical mutation identity;
- unsupported schema/result/error values fail closed before state is shown as
  confirmed.

### 3.4. Operational controls

The 10/15/30-second profile is the initial Booking-v1 stage candidate. Before
any endpoint or cohort traffic, BCK-05/API Platform evidence must confirm:

1. Functions v2 and dependency support in `europe-west1` for the pinned stack;
2. emulator and stage timeout behavior, including lost-response recovery;
3. p50/p95/p99 latency and cold-start behavior under a bounded load profile;
4. retry amplification, concurrency and cost envelope;
5. Auth/App Check failure mapping without identity or existence leakage;
6. server flags default-off and independent rollback of every surface;
7. no direct client access to operational Booking collections.

Failure of stage evidence amends or defers `API-DEC-01`; it does not justify a
silent timeout/region change.

## 4. `API-DEC-03` — semantic request hash

### 4.1. Candidate record

| Field | Decision value |
|---|---|
| Decision ID | `API-DEC-03` |
| Candidate ID | `API03-BCK09-JCS-SHA256-SEMANTIC-v1` |
| Algorithm ID | `booking_semantic_hash_v1` |
| Canonicalization | RFC 8785 JCS over UTF-8 |
| Digest | SHA-256, lowercase hexadecimal |
| Runtime status | Absent and unauthorized |

The hash is an equality/idempotency control, not encryption, authentication,
authorization or a safe logging representation. Raw commands and hashes are
not analytics identifiers.

### 4.2. Exact semantic projection

After raw JSON duplicate-key detection, closed command validation and trusted
actor resolution, the projection is exactly:

```json
{
  "algorithmVersion": "booking_semantic_hash_v1",
  "commandType": "<canonical Booking v1 command wire value>",
  "commandSchemaVersion": 1,
  "resolvedActorScope": {
    "kind": "user",
    "id": "<verified stable account ID>"
  },
  "expectedBookingRevision": 7,
  "occurredAgainstEventRevision": 11,
  "payload": {}
}
```

The values `7` and `11` are illustrative valid JSON integers. Optional fields
are **omitted** when absent; JSON `null` is not a substitute for absence.
Their inclusion is the required amendment to the earlier Product baseline.

Projection rules:

- `commandType`, `commandSchemaVersion`, both applicable revision fields and
  `payload` come only from the successfully validated closed command variant;
- `resolvedActorScope` comes only from verified server context, never from the
  request body;
- Booking v1 accepts only `kind: user`; another actor kind requires a new
  Accepted decision/algorithm version rather than coercion;
- `requestId`, `idempotencyKey`, transport metadata, raw Auth/App Check
  context, headers, trace IDs and server timestamps are excluded;
- `idempotencyKey` remains part of the logical-mutation key and is deliberately
  not duplicated inside the payload hash;
- an absent optional value and an explicit `null` are distinct; the latter is
  rejected where the command schema does not permit it;
- no Unicode normalization, case folding or trimming occurs after validation.

### 4.3. Cross-language safe value subset

`booking_semantic_hash_v1` accepts recursively only:

- JSON objects with unique keys and recursively safe values;
- JSON arrays with stable order;
- booleans and JSON `null` where the owning schema permits them;
- valid Unicode strings without unpaired surrogates; NFC and NFD remain
  distinct;
- mathematically integral JSON numbers in the inclusive range
  `-9007199254740991..9007199254740991`.

Fractional numbers, out-of-range integers, non-finite values, unpaired
surrogates and duplicate object keys fail with `invalid_contract` before
hashing or mutation. Different JSON number spellings that represent the same
accepted integer canonicalize to the same JCS value. Money remains integer
minor units and is never converted to floating point for hashing.

### 4.4. Required golden vectors

The later parity slice must freeze shared input, canonical UTF-8 bytes and
lowercase digest for at least:

1. object-key reordering equivalence;
2. nested arrays and objects;
3. ASCII and supplementary-plane Unicode;
4. NFC versus NFD distinction;
5. escaped versus literal equivalent Unicode;
6. absent optional revision versus invalid explicit `null`;
7. different `expectedBookingRevision` values;
8. different `occurredAgainstEventRevision` values;
9. safe integer boundaries and equivalent integer spellings;
10. fractional, out-of-range, duplicate-key and unpaired-surrogate rejection;
11. `requestId` changes producing the same semantic hash;
12. `idempotencyKey` changes producing the same semantic hash while producing
    a different logical-mutation identity.

Dart and TypeScript must produce byte-identical canonical bytes and digests.
A test helper that merely reads expected hashes without independently
canonicalizing and hashing is not parity evidence.

## 5. Mandatory controls

1. Acceptance changes documentation decisions only.
2. No Firebase resource, callable export, handler, Rules/IAM binding, App Check
   enforcement, credential, deployment or production data is authorized.
3. `apps/backend` remains the bounded R0 tooling scaffold until a separate
   Approved ECL-03/backend slice.
4. The next allowed implementation proposal is contracts/test parity only:
   query/availability schemas, shared fixtures, test-only TypeScript consumer
   and Dart/TypeScript hash vectors.
5. A test-only TypeScript consumer must not be exported from
   `apps/backend/functions/src/index.ts` or treated as a product handler.
6. Every mutation/runtime surface remains default-off and absent.
7. All nine BCK-09 specialist signatures remain Pending unless their own named
   reviewer records a verdict.
8. Combined-owner Acceptance is disclosed and does not claim independent
   Security or Operations review.
9. Qualified Legal/Privacy gates are unchanged.
10. Push, merge to `main`, provisioning and deployment remain separately
    authorized owner actions.

## 6. Evidence and activation boundary

### Evidence available now

- Accepted ADR/ECL product semantics;
- Booking-v1 closed command Schema/Dart parity;
- 13/13 package tests and independent 14-valid/38-invalid vectors;
- green 664/664 mobile suite and repository boundary gate;
- exact Product-selected transport/hash baseline;
- no deployed Booking producer, endpoint or stored command log.

### Evidence still required before contract parity is Done

- additive closed query/page/availability schemas;
- valid/invalid/forward query fixtures;
- executable test-only TypeScript validation of every shared fixture;
- independent Dart/TypeScript JCS/SHA-256 golden-vector implementation;
- exact raw duplicate-key and unsafe-number rejection;
- package, Node, boundary and full mobile gates.

### Evidence still required before any runtime

- separately Approved ECL-03C/backend runtime slice;
- API Platform, Security and BCK-05 stage evidence for the accepted profiles;
- production Identity/capability authority;
- Firebase provisioning/deployment authority and default-off server flags;
- emulator authorization, concurrency, idempotency and failure suites;
- all required BCK-09 specialist verdicts and market/privacy prerequisites.

## 7. Migration and rollback

No deployed migration exists because product Booking runtime is Absent.

- Before implementation, rollback means changing the decision verdict to
  `Deferred` and leaving current artifacts/runtime unchanged.
- After golden vectors exist but before runtime, rollback reverts the parity
  slice and package version; no stored data is rewritten.
- After an algorithm is ever used for persisted idempotency, its algorithm ID,
  projection and vectors are immutable. Any semantic change requires a new
  algorithm version plus an explicit read/retention/migration plan.
- A callable profile change requires a new decision revision and stage
  evidence; it is never silently edited in deployment configuration.

## 8. Proposed owner verdict record

| Field | Value |
|---|---|
| Decision owner | `RechargeN / Product owner` as assigned combined bootstrap owner |
| API Platform role | assigned, not independently reviewed |
| BCK-05 Operations role | assigned, stage evidence pending |
| Security role | assigned, independent Security review pending |
| Proposed verdict | Accept both candidates with controls and required amendment |
| Signed at UTC | Pending explicit owner instruction |
| Runtime authority | none |

Allowed verdicts:

- `Accept with controls` — accept both exact candidate IDs and the revision-field amendment;
- `Amend` — name the exact field/value to change;
- `Defer` — retain safe defaults and create no parity/runtime implementation.

Recommended explicit approval text:

```text
Одобряю BCK09-API-NAMED-DEC-01: Accept
API01-BCK09-CALLABLE-V2-EU-10-15-30-v1 and
API03-BCK09-JCS-SHA256-SEMANTIC-v1 with the required revision-field
amendment and controls. Combined-owner decision; independent Security and
Operations evidence remains pending. No Firebase or runtime authority.
```

## 9. Acceptance criteria

1. **BCK09-NAPI-AC-01:** both BCK-03 decision IDs and accountable roles are explicit.
2. **BCK09-NAPI-AC-02:** combined-owner concentration and lack of independence are disclosed.
3. **BCK09-NAPI-AC-03:** the decision scope is Booking v1 only.
4. **BCK09-NAPI-AC-04:** five callable surfaces have exact names and kinds.
5. **BCK09-NAPI-AC-05:** generic routing and parallel envelopes are forbidden.
6. **BCK09-NAPI-AC-06:** region and 10/15/30-second profiles are exact.
7. **BCK09-NAPI-AC-07:** timeout and connection loss remain unknown outcomes.
8. **BCK09-NAPI-AC-08:** retry preserves semantic payload/key and renews request ID.
9. **BCK09-NAPI-AC-09:** Auth is authoritative and App Check remains defense in depth.
10. **BCK09-NAPI-AC-10:** stage latency/cost/retry evidence remains mandatory.
11. **BCK09-NAPI-AC-11:** the hash algorithm ID, canonicalization and digest encoding are exact.
12. **BCK09-NAPI-AC-12:** the projection includes all mutation-semantic envelope fields.
13. **BCK09-NAPI-AC-13:** revision-field omission from the Product baseline is explicitly amended.
14. **BCK09-NAPI-AC-14:** request and idempotency identities remain outside the semantic hash.
15. **BCK09-NAPI-AC-15:** resolved actor scope comes only from verified context.
16. **BCK09-NAPI-AC-16:** Booking-v1 actor shape is exact and fail-closed.
17. **BCK09-NAPI-AC-17:** absent and null semantics are distinct.
18. **BCK09-NAPI-AC-18:** Unicode is not normalized or case-folded.
19. **BCK09-NAPI-AC-19:** numeric safety is integer-only and cross-language bounded.
20. **BCK09-NAPI-AC-20:** duplicate keys and unsafe values fail before hashing.
21. **BCK09-NAPI-AC-21:** golden vectors cover equivalence and rejection cases.
22. **BCK09-NAPI-AC-22:** Dart and TypeScript compute independently and byte-identically.
23. **BCK09-NAPI-AC-23:** the hash is not represented as confidentiality or authorization.
24. **BCK09-NAPI-AC-24:** Acceptance authorizes no runtime artifact or Firebase resource.
25. **BCK09-NAPI-AC-25:** the next implementation proposal is contracts/test parity only.
26. **BCK09-NAPI-AC-26:** test-only TypeScript code cannot become an exported handler.
27. **BCK09-NAPI-AC-27:** all specialist/runtime/market/privacy gates remain separate.
28. **BCK09-NAPI-AC-28:** rollback is zero-data before runtime and versioned afterwards.
29. **BCK09-NAPI-AC-29:** explicit owner verdict is required before status synchronization.
30. **BCK09-NAPI-AC-30:** push, `main` merge, provisioning and deployment remain separate actions.

## 10. Next step after explicit verdict

If the exact proposed verdict is Accepted:

1. update BCK-03, BCK-09, ECL-03C, API review, specialist package, coverage,
   BCK-01/BCK-02 and LAUNCH_STATUS without changing runtime status;
2. prepare a separate exact file plan for `BCK09-API-PAR-01`;
3. wait for explicit approval of that contracts/test-only implementation
   slice before changing Schema, Dart or TypeScript files.

If the verdict is Amend or Defer, no implementation plan is authorized.
