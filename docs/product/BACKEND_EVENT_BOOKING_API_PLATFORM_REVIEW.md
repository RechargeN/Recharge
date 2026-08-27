# Recharge Backend — Event Booking API Platform Review

- ID: **BCK09-API-REV-01**
- Version: **0.3**
- Date: **2026-08-27**
- Status: **Product baseline selected — Hold for contract correction and named sign-off**
- Target: **BCK-09 v1.6 / ECL-03C v1.4 / Booking wire v1**
- Parent review: [BCK09-REV-01 v0.5](BACKEND_EVENT_BOOKING_SPECIALIST_REVIEW_PACKAGE.md)
- Governing API draft: [BCK-03 v0.3.3](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**
- Product API decision:
  [BCK09-API-DEC-01 v0.2](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Contract correction plan:
  [BCK09-API-CORR-01 v0.2](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)

## 0. Verdict

**Hold, narrowed.** The Product owner selected exact target dispositions for
request binding, semantic hashing, transport/deadlines and request-ID format.
The existing Booking v1 Dart contract tests are green and the target
preserves the committed result union, split request/idempotency identity,
unknown-outcome semantics and fail-closed forward compatibility. A named API
Platform reviewer must not sign yet because the command/request-ID schema
correction, named API/Security/Operations decisions and
executable parity evidence still block an API.

This is a technical preparation record, not an independent specialist
signature. `BCK09-SIG-API` remains `Pending`.

## 1. Scope reviewed

- BCK-09 §§10, 13, 20–21 and AC-28..30, AC-50, AC-63..65;
- ECL-03C §§4, 6–7, 10–12;
- BCK-03 command/result/error/idempotency/timeout/version rules;
- all six Booking v1 JSON Schema roots;
- Booking command/result/error Dart DTOs;
- valid, invalid and forward fixtures plus their nine current Dart tests.

Security authorization, Event projection ownership, Notifications, Operations,
Mobile cutover and qualified Legal/Privacy verdicts remain separate reviews.

## 2. Evidence executed

```text
cwd: packages/api_contracts
dart test
result: 9 passed
```

An independent Draft 2020-12 validator was also run against the checked-in
`booking_command.schema.json`. The schema accepted all three inputs below,
while `BookingCommandDto` rejects them:

```text
createBooking + empty payload                         -> schema accepted
createBooking + payload.bookingId only                -> schema accepted
cancelBooking + payload.occurrenceId only             -> schema accepted
```

This is not a failing current Dart test: it proves that the fixture-tested Dart
consumer is stricter than the document declared to be the sole wire source.

## 3. Findings

| ID | Severity | Result | Finding | Required closure |
|---|---|---|---|---|
| `BCK09-API-TR-01` | Blocking | Fail | `booking_command.schema.json` lists a shared payload property bag but does not encode the command-specific required/allowed matrix implemented by Dart | Make the schema a true closed discriminated union or explicitly replace the “sole wire source” claim with a second normative semantic matrix; add cross-language invalid fixtures |
| `BCK09-API-TR-02` | Product disposition selected | Planned, not implemented | ECL-03C v1.4 defines atomic `m1_` logical and `r1_` request-attempt records inside `bookingIdempotency` | Named API review and later atomicity/contention evidence remain required |
| `BCK09-API-TR-03` | Product disposition selected | Specialist decision Open | Callable v2, `europe-west1` and 10/15/30-second deadlines are the target | API Platform + BCK-05 must accept API-DEC-01 before endpoint scaffold |
| `BCK09-API-TR-04` | Product disposition selected | Specialist decision Open | `booking_semantic_hash_v1` selects RFC 8785 JCS UTF-8 plus lowercase SHA-256 and exact projection | API Platform + Security must accept API-DEC-03 and golden vectors before runtime |
| `BCK09-API-TR-05` | Parent semantic resolved | Artifact conformance Pending | ECL03-D12 accepts exact opaque bounded request IDs and removes the parent ULID rule | Implement identical Schema/Dart constraints and fixtures through BCK09-API-CORR-01; no hidden backend-only rule |
| `BCK09-API-TR-06` | Runtime evidence | Pending | Query/page/availability schemas and TypeScript consumer do not exist yet | Keep ECL-03C runtime unauthorized until an Approved contract slice creates them and proves Dart/TypeScript parity |

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

### 5.3. Candidate `API-DEC-03` disposition

Recommended baseline:

- algorithm ID: `booking_semantic_hash_v1`;
- project exactly `{algorithmVersion, commandType, commandSchemaVersion,
  resolvedActorScope, payload}` after command-variant validation;
- exclude `requestId`, transport metadata, Auth/App Check context and server
  timestamps; `idempotencyKey` scopes the record and is not duplicated inside
  the semantic hash;
- reject duplicate JSON keys, non-finite numbers and values outside the
  cross-language safe subset;
- canonicalize the projection with
  [RFC 8785 JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html);
- hash exact UTF-8 canonical bytes with SHA-256 and encode lowercase hex;
- freeze Dart/TypeScript golden vectors, including Unicode, key ordering,
  absent-versus-null, integers and arrays.

This is now the Product-selected baseline. It remains non-executable until API
Platform + Security accept `API-DEC-03`.

### 5.4. Candidate `API-DEC-01` disposition

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

Exact values are now Product-selected, but require Platform load/latency
evidence and joint API/BCK-05 acceptance. Until then they are not deployable
configuration.

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
6. required contract/parity/emulator evidence remains a later activation gate.

## 7. Review acceptance criteria

1. **BCK09-API-REV-AC-01:** the reviewed target versions are explicit.
2. **BCK09-API-REV-AC-02:** this technical review is not a named signature.
3. **BCK09-API-REV-AC-03:** JSON Schema/DTO divergence is evidenced.
4. **BCK09-API-REV-AC-04:** current nine Dart tests are recorded as green.
5. **BCK09-API-REV-AC-05:** command variants require one normative closed matrix.
6. **BCK09-API-REV-AC-06:** request-attempt reuse has an atomic physical owner.
7. **BCK09-API-REV-AC-07:** request and idempotency identities remain distinct.
8. **BCK09-API-REV-AC-08:** Booking ID is not conflated with either identity.
9. **BCK09-API-REV-AC-09:** timeout remains an unknown outcome.
10. **BCK09-API-REV-AC-10:** canonical hashing requires versioned golden vectors.
11. **BCK09-API-REV-AC-11:** unknown schema/enum cannot mutate state.
12. **BCK09-API-REV-AC-12:** target-only error values cannot leak into v1.
13. **BCK09-API-REV-AC-13:** query schemas remain runtime prerequisites.
14. **BCK09-API-REV-AC-14:** API-DEC-01/03 have exact Product baselines but remain named-owner blocking decisions.
15. **BCK09-API-REV-AC-15:** `BCK09-SIG-API` remains Pending.
16. **BCK09-API-REV-AC-16:** no runtime, schema, DTO, Firebase or deployment file changes are authorized by this review.

## 8. Final state

BCK-09 remains Review, ECL-03C remains unapproved for implementation and
`BCK09-SIG-API` remains Pending. Product ambiguity is closed by
`BCK09-API-DEC-01`, and ECL03-D12 closes the parent semantic conflict. However,
`BCK09-API-CORR-01`, named API-DEC-01/03 decisions and parity evidence remain
blockers. Contract/schema/runtime edits
require their own Approved slice.
