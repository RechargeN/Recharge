# Recharge Backend — Booking callable raw-body feasibility slice

- ID: **BCK09-API-RAW-01**
- Version: **0.2**
- Date: **2026-08-28**
- Status: **Implemented/Review — local contract gates pass; canonical Node 22 hosted evidence pending**
- Target: **BCK-09 v1.10 / ECL-03C v1.8 / Booking wire v1**
- Parent review:
  [BCK09-API-REV-01 v0.7](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Contract parity:
  [BCK09-API-PAR-01 v0.3 — Done](BACKEND_EVENT_BOOKING_API_PARITY_SLICE_SPEC.md)
- Runtime effect: **none**
- Firebase resource effect: **none**
- Deployment authority: **none**
- Plan commit: **`cd6e28e`**
- Implementation commit: **`d4621c5`**

---

## 0. Outcome

The Product owner approved only **Phase A**, and the bounded contracts/test-only
implementation now exists in commit `d4621c5`. It proves locally that a strict
adapter can inspect the complete callable envelope before trusting
`request.data`, reject pre-decode ambiguity and preserve all existing Booking
semantic-hash evidence. It creates no callable, runtime, Firebase access,
configuration or deployment surface.

Phase B, an actual Firebase Emulator callable-path proof, remains a separate
future approval. Exact Node 22.23.2 hosted evidence cannot be obtained without
the separately prohibited push, so Phase A remains `Implemented/Review`, not
`Done`. It cannot promote BCK-09, ECL-03C or any specialist signature and cannot
turn the current runtime/evidence Hold into Pass.

### 0.1. v0.2 implementation reconciliation

- added a pure test-only raw-envelope inspector with a closed typed failure
  vocabulary, 64 KiB bound, fatal UTF-8/BOM checks, exact `data` envelope,
  protocol-wrapper denial and raw/framework equality guard;
- hardened the existing strict number reader so mathematically fractional
  underflow or rounded fractions cannot collapse into accepted integers;
- added five Phase A subtests covering all valid commands, every frozen
  semantic-hash vector, key-order equivalence, malformed wire inputs,
  decode mismatch and invalid/forward commands;
- retained byte-identical backend `src/**`, all 19 Booking schemas/fixtures,
  Firebase configuration, mobile code and Accepted ADRs;
- kept RAW-B, runtime, Firebase changes, callable exports, push, merge and
  deployment unauthorized.

## 1. Why this slice exists

`booking_semantic_hash_v1` must reject duplicate JSON keys, invalid UTF-8,
unpaired Unicode surrogates and unsafe numbers before ordinary decoding can
erase or reinterpret them. The completed parity slice proves this behavior for
checked-in raw command fixtures, but it does not prove that the future Firebase
Functions v2 callable adapter can access the same wire representation.

The current public and pinned-SDK surfaces support a feasible design:

1. Firebase Functions v2 `CallableRequest<T>` exposes `rawRequest`;
2. Firebase `Request` exposes `rawBody: Buffer`, described as the wire-format
   representation of the request body;
3. the callable protocol requires one top-level `data` field and rejects other
   top-level body fields;
4. the current pinned `firebase-functions 7.3.2` type declarations expose the
   same property chain.

These facts establish **static API availability**, not end-to-end byte
preservation in the emulator or production platform. The gate therefore stays
split and fail-closed.

### 1.1. Evidence inputs

Public primary sources inspected for this plan:

- [Firebase Functions v2 `CallableRequest`](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.https.callablerequest)
  documents `rawRequest: Request`;
- [Firebase Functions v2 `Request`](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.https.request)
  documents `rawBody: Buffer` as the wire-format request body;
- [the `https.onCall` protocol](https://firebase.google.com/docs/functions/callable-reference)
  requires the top-level `data` member, rejects additional body members and
  documents automatic callable serialization/decoding.

Repository evidence inspected at the pinned `firebase-functions 7.3.2` and
`firebase-tools 15.28.1` versions:

- `functions/lib/common/providers/https.d.ts` exposes the same property chain;
- `functions/lib/common/providers/https.js` passes the raw request into the v2
  callable handler context before invoking product handler code;
- the Functions Emulator implementation assigns `req.rawBody` from received
  bytes, but source inspection alone is not accepted as emulator execution
  evidence.

All external facts must be refreshed if either pinned Firebase package changes.

## 2. Authority and precedence

The slice is governed by, in order:

1. Accepted ADR 0019;
2. ECL-03 v1.3 and Accepted D01–D12;
3. ECL-03C v1.8;
4. BCK-09 v1.10;
5. Accepted BCK09-API-NAMED-DEC-01 v0.2;
6. BCK09-API-PAR-01 v0.3 frozen contract/hash evidence;
7. this bounded feasibility plan.

This document cannot alter Booking wire v1, the semantic-hash projection,
request/idempotency identity, callable count, collection count, authorization,
retention, availability or transaction behavior.

## 3. Gate model

| Gate | Scope | Required authority | Result allowed |
|---|---|---|---|
| `RAW-A` | Pinned SDK API/type inspection plus pure test-only callable-envelope adapter | Approval of this document | `Static feasible` or `Fail` |
| `RAW-B` | Disposable emulator-only Functions v2 callable exercised over HTTP protocol bytes | Separate explicit owner approval | `Emulator feasible` or `Fail` |
| `RAW-C` | Later ECL-03C disabled runtime adapter and stage evidence | Separate ECL-03C/backend authorization | Runtime evidence only |

`RAW-A` must never be reported as `RAW-B` or `RAW-C`. A skipped, mocked,
timed-out or version-mismatched gate is `Inconclusive`, never Pass.

## 4. Phase A — approved and implemented bounded scope

### 4.1. Included

Phase A adds a test-only adapter that:

1. accepts a Firebase callable `rawBody` as `Buffer` and the already-decoded
   `request.data` only as a comparison input;
2. enforces a maximum raw request size before text decoding;
3. decodes UTF-8 with fatal error handling and rejects a BOM;
4. parses the complete callable envelope with the existing strict JSON reader,
   so duplicate keys at the envelope or nested command level are rejected;
5. requires a plain top-level object with exactly one own key, `data`;
6. requires `data` to be a plain JSON object compatible with Booking command v1;
7. rejects unsupported callable protocol typed wrappers rather than silently
   converting them into Booking values;
8. compares the strictly parsed `data` value with `request.data` using a
   deterministic, prototype-independent JSON-value comparison;
9. passes the strictly parsed Booking command to the existing schema and
   semantic-hash evidence path;
10. returns only a typed internal success/failure result and never logs or
    returns the raw body.

The adapter is evidence code only. It cannot be imported by `src/`, exported by
the functions package or consumed by mobile code.

### 4.2. Excluded

Phase A must not:

- modify `apps/backend/functions/src/**`;
- modify `apps/backend/functions/src/index.ts`;
- add `onCall`, `onRequest` or any Cloud Function export;
- change `firebase.json`, Rules, indexes, Terraform, IAM or project aliases;
- start the Firebase Emulator Suite as proof of this gate;
- access Auth, App Check, Firestore, Storage, Pub/Sub or the network;
- add credentials, secrets, environment-specific configuration or project IDs;
- implement Booking commands, queries, transactions or repositories;
- change schemas, shared fixtures, Dart DTOs or semantic-hash goldens;
- modify `apps/mobile/**`;
- claim independent API, Security or Operations approval;
- push, merge, deploy or enable anything.

## 5. Raw-envelope contract

### 5.1. Accepted input shape

The only accepted protocol-envelope shape for the future Booking callable is
one `data` member whose value must separately pass the complete Booking command
schema. The shortened example below illustrates the envelope, not a complete
valid command fixture:

```json
{"data":{"schemaVersion":1,"commandType":"createBooking","requestId":"example","idempotencyKey":"example","payload":{}}}
```

Whitespace and JSON escape spelling may vary. Semantic hashing remains based on
the validated Booking projection and RFC 8785 canonical bytes, not on lexical
whitespace or original key order.

### 5.2. Fail-closed conditions

The adapter rejects before hashing when any of the following is present:

- empty body, invalid UTF-8 or UTF-8 BOM;
- non-object top-level JSON;
- missing `data`, duplicate `data` or any additional top-level member;
- duplicate key at any nesting depth;
- fractional, non-finite or unsafe integer representation;
- unpaired surrogate or invalid JSON escape;
- depth greater than 64;
- top-level callable protocol typed wrapper such as an object that attempts to
  encode a non-Booking integer through `@type`;
- parsed raw `data` and Firebase-decoded `request.data` are not exactly equal as
  bounded JSON values;
- Booking command schema or semantic-hash validation fails.

Failure produces a stable internal reason category. It must not echo field
values, request bodies, tokens or personally identifiable data.

### 5.3. Required limits

| Limit | Phase A value | Later change rule |
|---|---:|---|
| raw callable body | 64 KiB | BCK-03/API decision plus load evidence |
| JSON nesting depth | 64 | Contract revision |
| Booking string/list/numeric limits | Existing Booking v1 schemas | Contract revision |
| accepted character encoding | UTF-8 without BOM | Breaking transport decision |

The 64 KiB cap is a conservative Booking-specific application limit, not a
claim about Firebase's platform maximum.

## 6. Comparison semantics

The raw parse is authoritative for pre-decode safety checks. The framework
value is authoritative only for detecting an unexpected callable-protocol
transformation. Equality must:

- compare null, booleans, strings and safe integers by exact value;
- compare arrays by length, order and recursively equal members;
- compare objects by exact own-key set and recursively equal members;
- ignore JavaScript prototype identity and insertion order;
- reject `undefined`, functions, symbols, bigint, dates, class instances and
  non-finite numbers;
- never normalize Unicode, trim strings or case-fold keys/values.

Any mismatch is `callable_decode_mismatch` and blocks mutation. There is no
fallback to the framework-decoded value.

## 7. Exact Phase A file plan

### 7.1. Add

| Path | Purpose |
|---|---|
| `apps/backend/functions/test/support/booking_callable_raw_body.ts` | Pure bounded callable-envelope extraction and decoded-value comparison |
| `apps/backend/functions/test/contract/booking_callable_raw_body.test.ts` | Positive, negative and metamorphic evidence |

### 7.2. Modify

| Path | Exact change |
|---|---|
| `apps/backend/functions/package.json` | Add the compiled test path to `test:contract`; no dependency or export change |
| `apps/backend/functions/test/support/booking_raw_json.ts` | Harden exact JSON-number handling so mathematically fractional underflow cannot collapse to accepted zero; preserve all existing verdicts |
| `docs/product/BACKEND_EVENT_BOOKING_RAW_BODY_FEASIBILITY_SLICE_SPEC.md` | After verified implementation only: evidence, hashes and status reconciliation |

### 7.3. Must remain byte-identical

- `apps/backend/functions/src/**`;
- `apps/backend/firebase.json`, Rules, indexes, infrastructure and scripts;
- `packages/api_contracts/**`;
- `apps/mobile/**`;
- Accepted ADRs and the frozen Booking v1 contract fixtures.

If implementation requires another file, dependency, generated artifact or
runtime import, stop and revise this plan before editing.

## 8. Test matrix

### 8.1. Positive vectors

- every valid command kind wrapped as the sole `data` member;
- whitespace and top-level/key-order variations with equal semantic result;
- escaped versus literal equivalent Unicode;
- supplementary Unicode scalar values;
- safe integer minimum, zero and maximum;
- raw/framework object key-order difference with equal bounded JSON value.

### 8.2. Negative vectors

- missing, duplicate and extra top-level fields;
- duplicate nested Booking keys;
- invalid UTF-8, BOM and trailing bytes;
- literal and escaped unpaired surrogates;
- fractional, exponent-to-fractional, overflow and underflow numbers;
- unsafe positive and negative integers;
- excessive depth and body size;
- array, scalar or null `data`;
- `@type`/proto integer wrapper in a Booking field;
- raw/framework data mismatch, missing field, null-versus-absent and changed
  revision;
- schema-invalid and forward/unsupported Booking commands.

### 8.3. Metamorphic assertions

- whitespace and key order do not change semantic hash;
- request ID and idempotency key preserve the Accepted hash/identity split;
- changing an applicable Booking/Event revision changes the semantic hash;
- any pre-decode rejection reaches neither schema hashing nor a mutation seam;
- expected fixture digest is never used as computed output.

## 9. Verification gates

1. record the pre-change SHA-256 of every `functions/src` file and all frozen
   Booking schema/fixture files;
2. run backend format check, ESLint and strict TypeScript typecheck;
3. run the complete Node unit, contract and R0 emulator suites;
4. run reproducibility, generated-clean and no-cloud-context checks;
5. run root boundary and diff/whitespace checks;
6. confirm `r0ToolchainProbe` remains the sole exported Cloud Function;
7. confirm no Firebase/cloud network target or credential variable was used;
8. compare post-change hashes for every must-remain-identical surface;
9. run the canonical hosted Ubuntu/Windows R0 matrix before `Done`;
10. record exact Node, npm, firebase-functions and firebase-tools versions.

Local green evidence may move Phase A only to `Implemented/Review`. `Done`
requires the hosted matrix on the exact commit. It still does not close Phase B.

## 10. Phase B — deliberately not authorized

Phase B must use a separately approved disposable emulator-only callable probe
to demonstrate that actual HTTP bytes sent to the local Functions Emulator are
available unchanged as `request.rawRequest.rawBody` inside an `onCall` handler.
Its future plan must define:

- an isolated test-only export and guaranteed non-production discovery path;
- exact raw HTTP request corpus, including duplicate keys and invalid Unicode;
- callable protocol status/result expectations;
- proof that no Firestore/Admin mutation path is reachable;
- zero cloud context and loopback-only hosts;
- teardown and byte-identical restoration/removal of the probe;
- Linux and Windows evidence;
- a stop condition if the emulator normalizes or discards the required bytes.

Approval of Phase A does not approve any item above.

## 11. Definition of Ready for Phase A

1. the Product owner explicitly approves `BCK09-API-RAW-01 v0.1 Phase A`;
2. the worktree is clean and synchronized with the reviewed branch head;
3. BCK09-API-NAMED-DEC-01 v0.2 and BCK09-API-PAR-01 v0.3 are unchanged;
4. exact baseline hashes are captured;
5. pinned dependencies are already available or network use is separately
   authorized;
6. no runtime, Firebase, callable export, push, merge or deployment permission
   is inferred.

## 12. Definition of Done for Phase A

Phase A is Done only when:

1. the exact §7 file plan is respected;
2. all §8 vectors and metamorphic assertions pass;
3. raw input is rejected before ordinary decoding can hide duplicate keys or
   invalid Unicode;
4. the decoded-value mismatch check is deterministic and fail-closed;
5. all §9 local and hosted gates pass on the exact commit;
6. `src/**`, Firebase, contract, mobile and ADR hashes remain unchanged;
7. no function export, Firebase access or network side effect exists;
8. evidence records exact versions and LF-normalized file hashes;
9. status is reported only as `Static feasible — RAW-B still blocked`;
10. BCK-09/ECL-03C remain Review/runtime Absent and all nine signatures remain
    Pending.

### 12.1. Current evidence at commit `d4621c5`

Passed locally:

```text
npm run format:check                 Pass
npm run lint                         Pass
npm run typecheck                    Pass
npm run test:contract                Pass — 15/15
npm run verify:cloud-context         Pass
npm run verify:reproducibility       Pass
npm run verify:generated             Pass — 26 files
git diff --check                     Pass
```

Reproducible logical build digest:
`feb602f946ebaa6482c4702556c70d4f7bcdce3551f0a43ed28bd8aec2e688b8`.

The baseline/post-change comparison covered both tracked files under
`apps/backend/functions/src/` plus all 19 Booking v1 schema/fixture files:
21/21 LF-normalized SHA-256 values are byte-identical. Git scope confirms no
Firebase, infrastructure, mobile, shared contract or ADR change.

Implementation LF-normalized SHA-256:

| File | SHA-256 |
|---|---|
| `apps/backend/functions/package.json` | `6dd5bd750958df541740cc0213a6597324056214b9ff15782ec8707f3ec007e0` |
| `apps/backend/functions/test/support/booking_raw_json.ts` | `59fa2aaa97517998503f8d985b25f920aa7f03acf14c55dfea8a37feb944c592` |
| `apps/backend/functions/test/support/booking_callable_raw_body.ts` | `8b3dbe969d4d3da1e429511f4d54c4a90ccb0517f5cc39cd7bfa493304da2688` |
| `apps/backend/functions/test/contract/booking_callable_raw_body.test.ts` | `e363645f4eb0e7bd0e3e4528b52d15fd330a0b6e2186586e1c0f9d6565bebe6c` |

Inconclusive/blocked evidence:

- the local host exposes Node `20.17.0` / npm `10.8.2`, not the canonical Node
  `22.23.2` / npm `10.9.8`; `verify:toolchain` therefore correctly failed;
- `test:unit` reached an existing Node-20-only CommonJS/ESM dependency error
  before executing its R0 probe; this is environment evidence, not a Pass;
- the boundary command produced no output for 180 seconds and was stopped, so
  it is Inconclusive;
- the existing R0 emulator suite was not claimed on the wrong Node/Java
  toolchain;
- the hosted Ubuntu/Windows matrix is unavailable because push remains
  explicitly unauthorized.

Accordingly, the only honest result is:
**`Static adapter implemented locally — canonical RAW-A evidence pending`; RAW-B
remains blocked.**

## 13. Rollback

Rollback is one revert of the isolated Phase A implementation commit and, if
created, one documentation reconciliation commit. Because Phase A adds no
runtime, state, deployment or consumer, rollback requires no data migration,
Firebase cleanup or mobile compatibility window.

## 14. Stop conditions

Stop and return the slice to Review if:

- `rawRequest.rawBody` is absent from the pinned public type surface;
- the adapter cannot reject duplicates before ordinary JSON decoding;
- callable protocol decoding changes an accepted Booking value;
- any valid frozen Booking fixture changes meaning;
- any implementation change escapes §7;
- an endpoint/export, emulator config or new dependency is required;
- any required gate fails, is skipped or is unavailable;
- the workspace contains overlapping uncommitted owner changes.

## 15. Acceptance criteria

1. **BCK09-RAW-AC-01:** the slice is test-only and has no runtime effect.
2. **BCK09-RAW-AC-02:** RAW-A, RAW-B and RAW-C cannot be conflated.
3. **BCK09-RAW-AC-03:** only Phase A was approved and implemented.
4. **BCK09-RAW-AC-04:** the public callable property chain is explicit.
5. **BCK09-RAW-AC-05:** public API availability is not emulator evidence.
6. **BCK09-RAW-AC-06:** the full callable envelope is inspected before decoding.
7. **BCK09-RAW-AC-07:** exactly one top-level `data` member is accepted.
8. **BCK09-RAW-AC-08:** duplicate keys fail at every nesting depth.
9. **BCK09-RAW-AC-09:** invalid UTF-8, BOM and unpaired surrogates fail closed.
10. **BCK09-RAW-AC-10:** only safe integral JSON numbers are accepted.
11. **BCK09-RAW-AC-11:** body size and nesting depth are bounded.
12. **BCK09-RAW-AC-12:** protocol typed wrappers cannot bypass Booking schema.
13. **BCK09-RAW-AC-13:** raw and framework-decoded data must agree exactly.
14. **BCK09-RAW-AC-14:** Unicode is not normalized, folded or trimmed.
15. **BCK09-RAW-AC-15:** semantic hashing remains projection/JCS based.
16. **BCK09-RAW-AC-16:** request and idempotency identities remain distinct.
17. **BCK09-RAW-AC-17:** failure reasons expose no raw or personal values.
18. **BCK09-RAW-AC-18:** the adapter is inaccessible from backend `src`.
19. **BCK09-RAW-AC-19:** no Cloud Function export is added.
20. **BCK09-RAW-AC-20:** no Firebase file or resource is changed.
21. **BCK09-RAW-AC-21:** no mobile or shared contract file is changed.
22. **BCK09-RAW-AC-22:** all frozen fixtures preserve their verdicts.
23. **BCK09-RAW-AC-23:** positive, negative and metamorphic tests are required.
24. **BCK09-RAW-AC-24:** source and frozen-contract hashes are compared.
25. **BCK09-RAW-AC-25:** local and hosted exact-version gates are required.
26. **BCK09-RAW-AC-26:** unavailable evidence is Inconclusive, not Pass.
27. **BCK09-RAW-AC-27:** Phase A can claim only static feasibility.
28. **BCK09-RAW-AC-28:** Phase B requires separate explicit approval.
29. **BCK09-RAW-AC-29:** BCK-09/ECL-03C statuses do not advance.
30. **BCK09-RAW-AC-30:** all nine specialist signatures remain Pending.
31. **BCK09-RAW-AC-31:** push, merge and deployment remain separate actions.
32. **BCK09-RAW-AC-32:** rollback is commit-bounded and has no data operation.

## 16. Recorded approval

```text
Одобряю BCK09-API-RAW-01 v0.1 Phase A для contracts/test-only implementation.
RAW-B emulator probe, runtime, Firebase changes, callable exports, push, merge и
deployment не разрешаю.
```

The owner supplied this exact approval before implementation commit `d4621c5`.
It does not authorize RAW-B, runtime, Firebase changes, callable exports, push,
merge or deployment.
