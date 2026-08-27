# Recharge Backend — Event Booking API Platform Review

- ID: **BCK09-API-REV-01**
- Version: **0.6**
- Date: **2026-08-28**
- Status: **Contract parity implemented — Hold for runtime feasibility and independent evidence**
- Target: **BCK-09 v1.9 / ECL-03C v1.7 / Booking wire v1**
- Parent review: [BCK09-REV-01 v0.8](BACKEND_EVENT_BOOKING_SPECIALIST_REVIEW_PACKAGE.md)
- Governing API draft: [BCK-03 v0.3.5](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**
- Product API decision:
  [BCK09-API-DEC-01 v0.4](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Named API decision:
  [BCK09-API-NAMED-DEC-01 v0.2 — Accepted with controls](BACKEND_EVENT_BOOKING_NAMED_API_DECISION.md)
- Contract correction plan:
  [BCK09-API-CORR-01 v0.3](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)
- Contract parity evidence:
  [BCK09-API-PAR-01 v0.2 — Implemented / Review](BACKEND_EVENT_BOOKING_API_PARITY_SLICE_SPEC.md)

## 0. Verdict

**Hold, narrowed to runtime adapter feasibility, canonical Node 22 confirmation
and independent evidence.**
BCK09-API-CORR-01 v0.3 closes the command-union and D12 Schema/Dart defects.
BCK09-API-NAMED-DEC-01 v0.2 accepts the exact Booking-v1 callable and semantic
hash decisions, including the revision-field amendment. BCK09-API-PAR-01 v0.2
implements the missing query/read/page/availability roots and independent
Dart/TypeScript semantic-hash evidence without adding runtime. A named
independent API Platform reviewer still must not sign because raw callable-body
feasibility, canonical Node 22, stage/Security evidence and runtime controls
remain incomplete.

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
`664/664` tests and the 380-file boundary scan are green. Node ran on 20.17,
not the repository's canonical Node 22 target, so that rerun remains required.

## 3. Findings

| ID | Severity | Result | Finding | Required closure |
|---|---|---|---|---|
| `BCK09-API-TR-01` | Resolved | Pass | `booking_command.schema.json` contains nine closed command-local variants; Schema, bounded validator, Dart and TypeScript agree on all checked-in command fixtures | Preserve frozen fixture/hash evidence |
| `BCK09-API-TR-02` | Product disposition selected | Planned, not implemented | ECL-03C v1.7 defines atomic `m1_` logical and `r1_` request-attempt records inside `bookingIdempotency` | Later atomicity/contention evidence remains required |
| `BCK09-API-TR-03` | Named decision | Accepted for Booking v1 | Callable v2, `europe-west1` and 10/15/30-second deadlines are exact | Independent API Platform + BCK-05 stage evidence remains required before endpoint scaffold |
| `BCK09-API-TR-04` | Contract portion resolved | Pass / runtime Hold | `booking_semantic_hash_v1` uses RFC 8785 JCS UTF-8, lowercase SHA-256 and includes applicable revision fields; independent Dart/TypeScript goldens agree | Raw callable-body feasibility and independent Security evidence remain required before runtime |
| `BCK09-API-TR-05` | Resolved | Pass | ECL03-D12 opaque request IDs are enforced identically in command Schema/Dart, including scalar bounds, blank set, no rewrite and surrogate rejection | Preserve frozen v0.3 fixtures; no hidden backend-only rule |
| `BCK09-API-TR-06` | Resolved at contract/test scope | Pass / runtime absent | Closed query/read/page/availability schemas and a real TypeScript Draft 2020-12 consumer exist; shared Dart/TypeScript fixtures and hashes pass | Preserve evidence, rerun on Node 22 and keep ECL-03C runtime unauthorized until later runtime gates pass |

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
test-only Dart/TypeScript goldens pass in BCK09-API-PAR-01 v0.2. Runtime remains
blocked until raw callable-body feasibility and independent Security evidence
pass their separately Approved gates.

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
6. remaining runtime-adapter/emulator evidence remains a later activation gate.

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

## 8. Final state

BCK-09 remains Review, ECL-03C runtime remains unapproved and
`BCK09-SIG-API` remains Pending. Product ambiguity, the command-union defect,
D12 command-artifact parity, Booking-v1 named API decisions and the bounded
TypeScript/query/hash contract parity slice are closed. Canonical Node 22
confirmation, raw callable-body feasibility, independent specialist evidence
and runtime controls remain blockers. Further contract or runtime edits require
their own Approved slice.
