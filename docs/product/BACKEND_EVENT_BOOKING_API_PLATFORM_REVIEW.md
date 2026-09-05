# Recharge Backend — Event Booking API Platform Review

- ID: **BCK09-API-REV-01**
- Version: **0.10**
- Date: **2026-09-03**
- Status: **RAW-C hosted pass — Hold for independent evidence and deployment authority**
- Target: **BCK-09 v1.13 / ECL-03C v1.11 / Booking wire v1**
- Parent review: [BCK09-REV-01 v0.12](BACKEND_EVENT_BOOKING_SPECIALIST_REVIEW_PACKAGE.md)
- Governing API draft: [BCK-03 v0.3.7](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **disabled local/Emulator source only; no deployment or activation**
- Product API decision:
  [BCK09-API-DEC-01 v0.4](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Named API decision:
  [BCK09-API-NAMED-DEC-01 v0.2 — Accepted with controls](BACKEND_EVENT_BOOKING_NAMED_API_DECISION.md)
- Contract correction plan:
  [BCK09-API-CORR-01 v0.3](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)
- Contract parity evidence:
  [BCK09-API-PAR-01 v0.3 — Done](BACKEND_EVENT_BOOKING_API_PARITY_SLICE_SPEC.md)
- Raw-body transport evidence:
  [BCK09-API-RAW-B-01 v0.1 — Done](BACKEND_EVENT_BOOKING_RAW_BODY_EMULATOR_SLICE_SPEC.md)
- Product-adapter evidence:
  [BCK09-API-RAW-C-01 v0.3 — hosted pass / independent verdicts Pending](BACKEND_EVENT_BOOKING_DISABLED_RUNTIME_ADAPTER_SLICE_SPEC.md)

## 0. Verdict

**Hold, narrowed to independent evidence and deployment authority;
deployed product runtime remains unauthorized.**
BCK09-API-CORR-01 v0.3 closes the command-union and D12 Schema/Dart defects.
BCK09-API-NAMED-DEC-01 v0.2 accepts the exact Booking-v1 callable and semantic
hash decisions, including the revision-field amendment. BCK09-API-PAR-01 v0.3
implements the missing query/read/page/availability roots and independent
Dart/TypeScript semantic-hash evidence without adding runtime.
BCK09-API-RAW-B-01 v0.1 additionally proves 19/19 synthetic raw-body vectors
through a disposable Functions Emulator callable on Ubuntu and Windows. RAW-C
v0.1 now supplies disabled local adapter evidence: unit 13/13, contract 15/15
and disposable Emulator 23/23 pass on local Node 22.23.2. A named independent
Exact hosted npm/JDK Ubuntu/Windows evidence now passes at head
`75818f78c67e9bcfa06edbc12820424235c39627`. An API Platform reviewer still
must not sign because the evidence has not been independently reviewed together
with stage/Security controls.

This is a technical preparation record, not an independent specialist
signature. `BCK09-SIG-API` remains `Pending`.

## 1. Scope reviewed

- BCK-09 §§10, 13, 20–21 and AC-28..30, AC-50, AC-63..65;
- ECL-03C §§4, 6–7, 10–12;
- BCK-03 command/result/error/idempotency/timeout/version rules;
- all ten Booking v1 JSON Schema roots plus common definitions;
- Booking command/result/error Dart DTOs and bounded query/hash validators;
- mutation/query valid, invalid and forward fixtures plus semantic-hash vectors;
- independent test-only Dart and TypeScript contract consumers.

Security authorization, Event projection ownership, Notifications, Operations,
Mobile cutover and qualified Legal/Privacy verdicts remain separate reviews.

## 2. Evidence executed

```text
cwd: packages/api_contracts
dart analyze
result: 0 issues

dart test
result: 20 passed
```

The independent Python `jsonschema 4.17.3` Draft 2020-12 validator was rerun
against the corrected `booking_command.schema.json`:

```text
14/14 valid commands accepted
38/38 invalid commands rejected
```

The bounded Dart validator and `BookingCommandDto` agree with those vectors.
The independent Node contract suite passes `10/10` with Ajv 8.20.0 Draft
2020-12 validation, strict raw-JSON rejection and byte-identical JCS/SHA-256
goldens. Backend format, lint and strict typecheck pass; full Flutter analyze,
`664/664` tests and the 380-file boundary scan are green. Hosted runs
`33127684319` and `33127686757` pass on exact Node 22.23.2 for both
`ubuntu-24.04` and `windows-2025`.

RAW-C local evidence on 2026-09-03 adds 13/13 unit, 15/15 contract and 23/23
disposable Emulator checks, generated verification over 88 files and
reproducibility digest
`a5202fe025855d175c6c58add5614859fc568e48547717ad499ff7c4776ddecd`.
The current RAW-C revision passes push run `33689696133` and pull-request run
`33689700189` on Ubuntu 24.04 and Windows 2025. Its boundary gate passes over
380 files with 0 violations and 71/71 tracked suppressions. These results are
technical evidence, not this document's independent API signature.

## 3. Findings

| ID | Severity | Result | Finding | Required closure |
|---|---|---|---|---|
| `BCK09-API-TR-01` | Resolved | Pass | `booking_command.schema.json` contains nine closed command-local variants; Schema, bounded validator, Dart and TypeScript agree on all checked-in command fixtures | Preserve frozen fixture/hash evidence |
| `BCK09-API-TR-02` | Hosted evidence present | Pass hosted / independent Hold | RAW-C implements atomic `m1_` logical and `r1_` request-attempt records inside `bookingIdempotency`; contention/idempotency suites pass on Ubuntu and Windows | Independent review remains required |
| `BCK09-API-TR-03` | Named decision | Accepted for Booking v1 | Callable v2, `europe-west1` and 10/15/30-second deadlines are exact | Independent API Platform + BCK-05 stage evidence remains required before endpoint scaffold |
| `BCK09-API-TR-04` | Hosted adapter evidence present | Pass hosted / product runtime Hold | `booking_semantic_hash_v1` uses RFC 8785 JCS UTF-8, lowercase SHA-256 and includes applicable revision fields; RAW-C validates raw input and all five callable paths on Ubuntu and Windows | Independent Security/API review remains required before deployment |
| `BCK09-API-TR-05` | Resolved | Pass | ECL03-D12 opaque request IDs are enforced identically in command Schema/Dart, including scalar bounds, blank set, no rewrite and surrogate rejection | Preserve frozen v0.3 fixtures; no hidden backend-only rule |
| `BCK09-API-TR-06` | Resolved at contract/test scope | Pass / runtime absent | Closed query/read/page/availability schemas and a real TypeScript Draft 2020-12 consumer exist; shared Dart/TypeScript fixtures and hashes pass on Node 22.23.2 | Preserve evidence and keep ECL-03C runtime unauthorized until later runtime gates pass |

## 4. Passing checks

| ID | Result | Evidence |
|---|---|---|
| `BCK09-API-PASS-01` | Pass | Booking v1 result keeps `succeeded / rejected / retryableFailure / unsupportedContract` without inventing a second wire envelope |
| `BCK09-API-PASS-02` | Pass | `requestId` and `idempotencyKey` have distinct accepted roles; retry may use a fresh request ID with the same logical key/payload |
| `BCK09-API-PASS-03` | Pass | Timeout is unknown outcome, never false success or false rejection |
| `BCK09-API-PASS-04` | Pass | Unknown schema/enum fails closed before mutation |
| `BCK09-API-PASS-05` | Pass | Server-issued Booking ID is stable across Firestore callback retries and returned only after commit |
| `BCK09-API-PASS-06` | Pass | `unsupported_flow` is explicitly target-only and cannot be emitted until added to a verified contract revision |
| `BCK09-API-PASS-07` | Pass | Page size 20/default and 50/domain maximum are compatible with BCK-03's broader maximum of 100 |

## 5. Required amendments

### 5.1. Closed Booking command union

Recommended contract shape:

```text
BookingCommandV1 = oneOf(
  createBooking payload,
  cancelBooking payload,
  approveApplication payload,
  rejectApplication payload,
  joinWaitlist payload,
  leaveWaitlist payload,
  acceptWaitlistHold payload,
  declineWaitlistHold payload,
  reconfirmBooking payload
)
```

Each variant fixes `commandType=const`, closes both envelope and payload, and
declares its own required fields. The bounded Dart schema test helper currently
does not support `oneOf`/`if`/`then`; changing that helper and the normative v1
schema requires a separately Approved contract-correction slice with fixtures,
not a silent documentation or backend-only interpretation.

Minimum new invalid vectors:

- empty payload per command;
- field from another command variant;
- missing pool/channel pair;
- forbidden authority at every nesting depth;
- `expectedBookingRevision` present/absent against the exact command matrix;
- unknown command and unknown payload field;
- payload size/list/string boundaries.

### 5.2. Atomic request-attempt binding

Keep the nine ECL-03C collections, but define two document kinds inside
`bookingIdempotency`:

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

logicalMutation: payloadHash, completedResult, createdAt, expiresAt
requestAttempt: commandType, idempotencyKeyRef, payloadHash, createdAt, expiresAt
```

Both records are read before writes and created in the same transaction as the
Booking mutation. Same request binding may return the same logical result;
same request ID with another command/key/hash returns `invalid_contract`
without mutation. Retention must be no shorter than the idempotency retry
window. Hash tuple encoding and privacy rules require the same exactness as the
active-key contract.

### 5.3. Accepted `API-DEC-03` disposition

Recommended baseline:

- algorithm ID: `booking_semantic_hash_v1`;
- project exactly `{algorithmVersion, commandType, commandSchemaVersion,
  resolvedActorScope, expectedBookingRevision?,
  occurredAgainstEventRevision?, payload}` after command-variant validation;
- exclude `requestId`, transport metadata, Auth/App Check context and server
  timestamps; `idempotencyKey` scopes the record and is not duplicated inside
  the semantic hash;
- reject duplicate JSON keys, fractional/non-finite numbers, integers outside
  `-9007199254740991..9007199254740991`, unpaired surrogates and invalid nulls;
- do not normalize Unicode, case-fold or trim after validation;
- canonicalize the projection with
  [RFC 8785 JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html);
- hash exact UTF-8 canonical bytes with SHA-256 and encode lowercase hex;
- freeze Dart/TypeScript golden vectors, including Unicode, key ordering,
  absent-versus-null, integers and arrays.

This is Accepted for Booking v1 by BCK09-API-NAMED-DEC-01 v0.2. Independent
test-only Dart/TypeScript goldens pass in BCK09-API-PAR-01 v0.3 and disposable
Emulator transport feasibility passes in BCK09-API-RAW-B-01 v0.1. RAW-C is
implemented only as a disabled local adapter. Product deployment and activation
remain blocked until it is independently reviewed together with
Security/Operations evidence.

### 5.4. Accepted `API-DEC-01` disposition

Recommended ECL-03C transport profile:

- callable Functions v2, explicit `europe-west1`, Auth and App Check context;
- one callable per five named ECL-03C surfaces; no generic method router;
- client deadlines: 10 seconds for queries, 15 seconds for mutations;
- server timeout: 30 seconds for each ECL-03C callable;
- mutation deadline/connection loss returns unknown outcome; controller retries
  only with the same idempotency key/payload and a fresh request ID;
- transport status maps to the existing Booking v1 result/error contract and
  never bypasses domain result parsing;
- automatic SDK retry is not treated as a new logical mutation.

Exact values are Accepted for Booking v1, but still require independent
Platform load/latency and BCK-05 operational evidence. Until those gates pass,
they are not deployable configuration.

## 6. Named reviewer checklist

A named API Platform reviewer may return `Accept with runtime controls` only
after:

1. TR-01 has an accepted schema/semantic-source resolution;
2. TR-02 has an exact atomic record/key/retention contract;
3. API-DEC-01 and API-DEC-03 are Accepted or explicitly Deferred with this
   signature remaining Pending;
4. TR-05's Accepted ECL03-D12 semantics are implemented consistently across
   schema, Dart and fixtures;
5. no unverified error value or transport envelope is introduced;
6. RAW-C hosted adapter evidence is independently reviewed and runtime/Security
   controls are accepted.

## 7. Review acceptance criteria

1. **BCK09-API-REV-AC-01:** the reviewed target versions are explicit.
2. **BCK09-API-REV-AC-02:** this technical review is not a named signature.
3. **BCK09-API-REV-AC-03:** the former JSON Schema/DTO divergence and its verified closure are evidenced.
4. **BCK09-API-REV-AC-04:** current twenty Dart package tests and ten Node contract tests are recorded as green.
5. **BCK09-API-REV-AC-05:** command variants require one normative closed matrix.
6. **BCK09-API-REV-AC-06:** request-attempt reuse has an atomic physical owner.
7. **BCK09-API-REV-AC-07:** request and idempotency identities remain distinct.
8. **BCK09-API-REV-AC-08:** Booking ID is not conflated with either identity.
9. **BCK09-API-REV-AC-09:** timeout remains an unknown outcome.
10. **BCK09-API-REV-AC-10:** canonical hashing requires versioned golden vectors.
11. **BCK09-API-REV-AC-11:** unknown schema/enum cannot mutate state.
12. **BCK09-API-REV-AC-12:** target-only error values cannot leak into v1.
13. **BCK09-API-REV-AC-13:** query schemas are verified but create no runtime authority.
14. **BCK09-API-REV-AC-14:** API-DEC-01/03 are Accepted for Booking v1 without satisfying executable or independent specialist gates.
15. **BCK09-API-REV-AC-15:** `BCK09-SIG-API` remains Pending.
16. **BCK09-API-REV-AC-16:** no runtime, schema, DTO, Firebase or deployment file changes are authorized by this review.
17. **BCK09-API-REV-AC-17:** RAW-B proves exact raw-body visibility only for the disposable Emulator corpus.
18. **BCK09-API-REV-AC-18:** RAW-B grants no product export, Firestore/Admin access or specialist signature.
19. **BCK09-API-REV-AC-19:** RAW-C local evidence grants no API signature, deployment or activation authority.

## 8. Final state

BCK-09 remains Review, ECL-03C deployed runtime remains unapproved and
`BCK09-SIG-API` remains Pending. Product ambiguity, the command-union defect,
D12 command-artifact parity, Booking-v1 named API decisions and the bounded
TypeScript/query/hash contract parity slice and canonical Node 22 confirmation
are closed. Disposable callable raw-body transport feasibility is also closed
by RAW-B, and disabled RAW-C behavior passes exact hosted matrices. Independent
specialist evidence plus runtime controls remain
blockers. Further deployment, activation or later-stage edits require their
own Approved slice.
