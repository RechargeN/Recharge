# Recharge Backend — Event Booking API Baseline Decision

- ID: **BCK09-API-DEC-01**
- Version: **0.4**
- Date: **2026-08-27**
- Status: **Reconciled — named Booking API decisions Accepted; specialist signatures Pending**
- Decision target: **BCK09-API-REV-01 v0.5 / BCK-09 v1.8 / ECL-03C v1.6**
- Accountable product verdict: **RechargeN / Product owner**
- Recorded instruction: **`давай` on 2026-08-27, immediately after the
  proposed step “принять рекомендуемые API dispositions”; interpreted only as
  Product target selection under the controls below**
- Required independent owners: **API Platform, Security/Privacy and BCK-05
  Platform Operations**
- Named decision:
  [BCK09-API-NAMED-DEC-01 v0.2 — Accepted with controls](BACKEND_EVENT_BOOKING_NAMED_API_DECISION.md)
- Technical evidence:
  [BCK09-API-REV-01 v0.5](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Contract-correction plan:
  [BCK09-API-CORR-01 v0.3](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)
- Parent request-ID decision:
  [ECL03-D12 Accepted](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md)
- Runtime effect: **none**

## 0. Verdict

The Product owner selects the four dispositions in §2 as the single target
baseline for further BCK-09 contract work. This resolves product ambiguity; it
does **not** impersonate or replace the named API Platform, Security/Privacy or
BCK-05 Operations decisions.

Version 0.4 records that ECL03-D12 is Accepted, BCK09-API-CORR-01 v0.3 has
closed command Schema/Dart parity. Consequently:

- `BCK09-SIG-API` remains `Pending`;
- BCK-03 `API-DEC-01` and `API-DEC-03` are Accepted for Booking v1 through
  BCK09-API-NAMED-DEC-01 v0.2, including the revision-field amendment;
- the ECL-03 parent now normatively uses the selected opaque bounded attempt ID;
- Schema/Dart enforcement of that exact bound is fixture-verified;
- command union and null/boundary parity defects are closed without a deployed
  wire migration;
- BCK-09 and ECL-03C remain `Review`, and backend runtime remains absent.

## 1. Decision question

May Recharge use one precise Product baseline to close the ambiguity found by
`BCK09-API-REV-01`, while preserving fail-closed specialist and runtime gates?

**Yes, with the controls in this document.**

## 2. Selected dispositions

### 2.1. Request identity

The selected wire target keeps `requestId` as an opaque, bounded,
client-generated identifier accepted by Booking wire v1. It identifies one
transport attempt; it is not a Booking ID, idempotency key, actor identity or
authorization fact. A retry of the same logical mutation may use a fresh
`requestId` only with the same `idempotencyKey` and semantic payload.

This Product selection is now reconciled by Accepted ECL03-D12. It specifies
an exact case-sensitive string of 1–128 Unicode scalar values with at least one
scalar outside D12's versioned blank set and no normalization/rewrite.
Contract artifacts are aligned by BCK09-API-CORR-01 v0.3; no backend may
enforce a hidden ULID-only or otherwise divergent interpretation.

### 2.2. Atomic request-attempt binding

Keep the nine ECL-03C collections. The existing `bookingIdempotency`
collection contains two closed document kinds:

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

`logicalMutation` stores `recordKind`, `actorScope`, `commandType`,
`idempotencyKeyRef`, `payloadHash`, `completedResult`, `createdAt` and
`expiresAt`. `requestAttempt` stores `recordKind`, `actorScope`, `commandType`,
`idempotencyKeyRef`, `payloadHash`, `createdAt` and `expiresAt`.

Both records are read before writes and created atomically with the domain
mutation. Reuse of the same request binding for the same logical mutation may
return the stored result. Reuse with another command, key or semantic hash
returns `invalid_contract` without mutation. Retention is no shorter than the
logical idempotency retry window. Raw IDs and payloads are not logged.

The length-prefixed tuple is normative for this Product baseline; string
concatenation with separators is forbidden.

### 2.3. Semantic request hash

The selected target for BCK-03 `API-DEC-03` is:

- algorithm ID `booking_semantic_hash_v1`;
- exact projection `{algorithmVersion, commandType, commandSchemaVersion,
  resolvedActorScope, expectedBookingRevision?,
  occurredAgainstEventRevision?, payload}` after successful closed-variant
  validation;
- `requestId`, `idempotencyKey`, transport metadata, raw Auth/App Check
  context and server timestamps are excluded;
- duplicate JSON keys, fractional/non-finite numbers, integers outside
  `-9007199254740991..9007199254740991`, unpaired surrogates and invalid nulls
  are rejected before hashing;
- Unicode normalization, case folding and trimming are forbidden after
  validation;
- canonical bytes are RFC 8785 JCS UTF-8;
- digest is SHA-256 encoded as lowercase hexadecimal;
- Dart and TypeScript share frozen golden vectors for Unicode, key ordering,
  absent versus null, integers, arrays and nested objects.

`idempotencyKey` scopes the logical record and is intentionally not duplicated
inside the semantic hash. The named API Platform and Security owners must
still accept the algorithm and vectors before mutation runtime.

### 2.4. Callable transport and deadlines

The selected target for BCK-03 `API-DEC-01` is:

- Firebase callable Functions v2 in explicit `europe-west1`;
- one callable per five named ECL-03C surfaces, with no generic method router;
- verified Auth context and environment-controlled App Check enforcement;
- client deadline 10 seconds for queries and 15 seconds for mutations;
- server timeout 30 seconds for each ECL-03C callable;
- mutation timeout or connection loss is an unknown outcome, never success or
  domain rejection;
- recovery retries the same semantic payload and idempotency key with a fresh
  request ID, or performs an authorized query;
- transport mapping terminates in the existing Booking v1 result union and
  never invents a parallel success/error envelope.

These values are the Accepted Booking-v1 documentation decision. Independent
API Platform and BCK-05 evidence must still validate regional support,
latency, SDK behavior, cost and operational behavior before any deployment
configuration or endpoint activation.

## 3. Mandatory controls

1. No JSON Schema, Dart DTO, TypeScript, mobile, Firebase or deployment change
   is authorized by this decision.
2. The schema/DTO divergence was corrected only through the separately
   Approved `BCK09-API-CORR-01` slice.
3. ECL03-D12 is the parent authority for request-ID semantics; lower-level
   prose or code cannot override it.
4. API-DEC-01/03 are Accepted only for Booking v1 under
   BCK09-API-NAMED-DEC-01 v0.2; this does not sign BCK09-SIG-API/SEC/OPS.
5. All nine BCK-09 specialist signatures stay Pending.
6. Unknown schema, command variant, enum, actor state, App Check mode or
   request binding fails before mutation.
7. Contract tests and emulator evidence are activation gates, not inferred
   from documentation.
8. Push, merge to `main`, provisioning, credentials and production data remain
   independently authorized actions.

## 4. Closure map

| Finding | Product disposition | Current state | Required closure |
|---|---|---|---|
| BCK09-API-TR-01 | Closed discriminated command union | Implemented and verified in BCK09-API-CORR-01 v0.3 | Preserve fixtures and hashes |
| BCK09-API-TR-02 | Two atomic record kinds in `bookingIdempotency` | Selected for plan | Later emulator atomicity/contention proof |
| BCK09-API-TR-03 | Callable v2, 10/15/30-second profile | Accepted for Booking v1 | Independent API Platform + BCK-05 stage evidence |
| BCK09-API-TR-04 | JCS/SHA-256 semantic hash v1 with revision fields | Accepted for Booking v1 | Independent cross-language goldens and Security evidence |
| BCK09-API-TR-05 | Opaque bounded request ID | Parent and command artifacts reconciled | Preserve D12 Schema/DTO fixture parity |
| BCK09-API-TR-06 | Query/TS parity evidence | Not yet available | Approved contract/runtime slice and tests |

## 5. Acceptance criteria

1. **BCK09-API-DEC-AC-01:** Product selection is distinct from specialist acceptance.
2. **BCK09-API-DEC-AC-02:** all four selected dispositions are exact and versioned.
3. **BCK09-API-DEC-AC-03:** request and idempotency identities remain distinct.
4. **BCK09-API-DEC-AC-04:** Accepted ECL03-D12 is the sole Booking-v1 request-ID semantic authority.
5. **BCK09-API-DEC-AC-05:** the nine-collection boundary is preserved.
6. **BCK09-API-DEC-AC-06:** logical and attempt records use domain-separated length-prefixed keys.
7. **BCK09-API-DEC-AC-07:** request reuse conflict is rejected atomically before mutation.
8. **BCK09-API-DEC-AC-08:** semantic hashing has one exact projection and algorithm ID.
9. **BCK09-API-DEC-AC-09:** cross-language golden vectors remain mandatory.
10. **BCK09-API-DEC-AC-10:** timeout remains an unknown outcome.
11. **BCK09-API-DEC-AC-11:** transport values remain subject to API/Operations evidence.
12. **BCK09-API-DEC-AC-12:** schema correction was executed only through its separately Approved slice.
13. **BCK09-API-DEC-AC-13:** all nine specialist signatures remain Pending.
14. **BCK09-API-DEC-AC-14:** BCK-09/ECL-03C remain Review and runtime Absent.
15. **BCK09-API-DEC-AC-15:** this decision changes no runtime, schema or deployment file.
16. **BCK09-API-DEC-AC-16:** push and `main` merge remain independently authorized.

## 6. Final state

The ambiguity now has one Accepted Booking-v1 named decision and its
command-artifact correction is complete. It remains deliberately
non-deployable: all specialist signatures and TypeScript/query/runtime evidence
are still required.
