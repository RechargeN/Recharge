# Recharge Backend — Event Booking API Baseline Decision

- ID: **BCK09-API-DEC-01**
- Version: **0.1**
- Date: **2026-08-27**
- Status: **Product-selected with controls — specialist acceptance Pending**
- Decision target: **BCK09-API-REV-01 v0.1 / BCK-09 v1.4 / ECL-03C v1.2**
- Accountable product verdict: **RechargeN / Product owner**
- Recorded instruction: **`давай` on 2026-08-27, immediately after the
  proposed step “принять рекомендуемые API dispositions”; interpreted only as
  Product target selection under the controls below**
- Required independent owners: **API Platform, Security/Privacy and BCK-05
  Platform Operations**
- Technical evidence:
  [BCK09-API-REV-01 v0.1](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Contract-correction plan:
  [BCK09-API-CORR-01 v0.1](BACKEND_EVENT_BOOKING_CONTRACT_CORRECTION_SLICE_SPEC.md)
- Runtime effect: **none**

## 0. Verdict

The Product owner selects the four dispositions in §2 as the single target
baseline for further BCK-09 contract work. This resolves product ambiguity; it
does **not** impersonate or replace the named API Platform, Security/Privacy or
BCK-05 Operations decisions.

Consequently:

- `BCK09-SIG-API` remains `Pending`;
- BCK-03 `API-DEC-01` and `API-DEC-03` remain open until their named owners
  accept the exact values and evidence;
- the ECL-03 parent still says `requestId: ULID`, so the selected opaque-ID
  interpretation is not normative until an explicit parent amendment is
  accepted;
- the Booking v1 JSON Schema/DTO mismatch remains a blocking defect until the
  separately Approved correction slice is implemented and verified;
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

This is a Product selection, not a silent rewrite of Approved ECL-03. Before
contract or runtime implementation, a separately reviewed `ECL03-D12` parent
amendment must either:

1. accept the opaque bounded identifier consistently across parent prose,
   schemas, fixtures and consumers; or
2. reject this selection and migrate all supported producers/fixtures to strict
   ULID validation through an explicit compatible revision.

Until then, no backend may enforce an undocumented third interpretation.

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
  resolvedActorScope, payload}` after successful closed-variant validation;
- `requestId`, `idempotencyKey`, transport metadata, raw Auth/App Check
  context and server timestamps are excluded;
- duplicate JSON keys, non-finite numbers and values outside the
  cross-language safe numeric subset are rejected before hashing;
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

These values are a Product baseline only. API Platform and BCK-05 must validate
regional support, latency, SDK behavior, cost and operational evidence before
accepting `API-DEC-01` or configuring a deployment.

## 3. Mandatory controls

1. No JSON Schema, Dart DTO, TypeScript, mobile, Firebase or deployment change
   is authorized by this decision.
2. The schema/DTO divergence is corrected only through
   `BCK09-API-CORR-01` after explicit slice approval.
3. The ECL-03 request-ID conflict is corrected only through a separately
   reviewed parent amendment; lower-level prose cannot override it.
4. API-DEC-01/03 stay Open until their named owners sign the exact baseline or
   record amendments.
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
| BCK09-API-TR-01 | Closed discriminated command union | Selected; not implemented | Approve and execute BCK09-API-CORR-01 |
| BCK09-API-TR-02 | Two atomic record kinds in `bookingIdempotency` | Selected for plan | Named API review plus later emulator proof |
| BCK09-API-TR-03 | Callable v2, 10/15/30-second profile | Selected Product baseline | API Platform + BCK-05 acceptance |
| BCK09-API-TR-04 | JCS/SHA-256 semantic hash v1 | Selected Product baseline | API Platform + Security acceptance and goldens |
| BCK09-API-TR-05 | Opaque bounded request ID | Selected but conflicts with parent | Accepted ECL03-D12 amendment |
| BCK09-API-TR-06 | Query/TS parity evidence | Not yet available | Approved contract/runtime slice and tests |

## 5. Acceptance criteria

1. **BCK09-API-DEC-AC-01:** Product selection is distinct from specialist acceptance.
2. **BCK09-API-DEC-AC-02:** all four selected dispositions are exact and versioned.
3. **BCK09-API-DEC-AC-03:** request and idempotency identities remain distinct.
4. **BCK09-API-DEC-AC-04:** the ECL-03 ULID conflict remains explicit until amended.
5. **BCK09-API-DEC-AC-05:** the nine-collection boundary is preserved.
6. **BCK09-API-DEC-AC-06:** logical and attempt records use domain-separated length-prefixed keys.
7. **BCK09-API-DEC-AC-07:** request reuse conflict is rejected atomically before mutation.
8. **BCK09-API-DEC-AC-08:** semantic hashing has one exact projection and algorithm ID.
9. **BCK09-API-DEC-AC-09:** cross-language golden vectors remain mandatory.
10. **BCK09-API-DEC-AC-10:** timeout remains an unknown outcome.
11. **BCK09-API-DEC-AC-11:** transport values remain subject to API/Operations evidence.
12. **BCK09-API-DEC-AC-12:** schema correction requires its own Approved slice.
13. **BCK09-API-DEC-AC-13:** all nine specialist signatures remain Pending.
14. **BCK09-API-DEC-AC-14:** BCK-09/ECL-03C remain Review and runtime Absent.
15. **BCK09-API-DEC-AC-15:** this decision changes no runtime, schema or deployment file.
16. **BCK09-API-DEC-AC-16:** push and `main` merge remain independently authorized.

## 6. Final state

The ambiguity now has one reviewable Product baseline. It is deliberately not
deployable: formal parent-contract reconciliation, contract correction, named
specialist decisions and executable evidence remain required.
