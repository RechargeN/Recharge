# Recharge Backend — Booking callable raw-body emulator slice

- ID: **BCK09-API-RAW-B-01**
- Version: **0.1**
- Date: **2026-08-28**
- Status: **Done — Emulator feasible on Ubuntu and Windows**
- Target: **RAW-B only / BCK-09 v1.10 / ECL-03C v1.8**
- Parent evidence:
  [BCK09-API-RAW-01 v0.3 — RAW-A Done](BACKEND_EVENT_BOOKING_RAW_BODY_FEASIBILITY_SLICE_SPEC.md)
- Runtime effect: **none**
- Persistent Firebase effect: **none**
- Cloud/deployment authority: **none**

---

## 0. Owner decision and current verdict

The Product owner approved this exact v0.1 scope on 2026-08-28. A disposable
**Firebase Functions Emulator/test-only** proof is now present and sends exact
HTTP callable protocol bytes through a temporary Functions v2 export to verify
what the handler receives as `request.rawRequest.rawBody`.

The approval permits only one temporary test-fixture callable export created
inside a cleanup-bound generated emulator source directory. It does not permit
a product callable, a tracked Firebase resource/configuration change, Firestore
access, runtime implementation, deployment, push or merge.

The implementation is **Done** with the bounded transport verdict
**Emulator feasible**. Exact Node 22.23.2 / npm 10.9.8 / Temurin 21.0.12+8
jobs passed on both Ubuntu 24.04 and Windows 2025 at commit `e043218`. This is
emulator-only evidence: it does not authorize or establish production runtime,
security, identity, persistence, deployment or operational readiness.

## 1. Outcome required

RAW-A proved that the pinned TypeScript surface and pure adapter can inspect a
bounded callable envelope. RAW-B must now answer the remaining physical
question:

> When exact bytes traverse the pinned Firebase Functions Emulator and the v2
> `onCall` middleware, are those same bytes available to the test handler as
> `request.rawRequest.rawBody` before the handler trusts `request.data`?

The only valid outcomes are:

- `Emulator feasible` — every required invariant passes on Ubuntu and Windows;
- `Fail` — required bytes are normalized/lost or a safety invariant fails;
- `Inconclusive` — toolchain, dependency, timeout, cleanup or evidence is
  incomplete.

No RAW-B result is production evidence. RAW-C and ECL-03C remain separately
authorized future work.

## 2. Governing boundaries

1. Accepted ADR 0019 and ECL-03 D01–D12 remain unchanged.
2. Booking wire v1 and `booking_semantic_hash_v1` remain unchanged.
3. RAW-A v0.3 is the only adapter/contract input.
4. `apps/backend/functions/src/index.ts` remains byte-identical and keeps
   `r0ToolchainProbe` as its sole export.
5. The probe may run only against project ID `demo-recharge` and loopback.
6. No Admin SDK client, Firestore repository, Auth user or App Check token is
   needed for this transport proof.
7. A probe result cannot grant `BCK09-SIG-API`, Security or Operations approval.

## 3. Isolation architecture

```text
checked-in test fixture TypeScript
              |
              v
normal tsc output under functions/lib/test
              |
              v
runner copies only required JS into validated temporary source
              |
              v
temporary package exports bookingRawBodyProbeV1
              |
              v
Firebase Functions Emulator on 127.0.0.1:5101 / demo-recharge
              |
              v
raw Node HTTP client sends exact committed byte vectors
              |
              v
runner terminates emulator and removes temporary source/config
```

The temporary package is never referenced by the tracked product
`functions/package.json`, `src/index.ts` or `firebase.json`. If the temporary
source remains after the run, the gate fails.

## 4. Probe handler contract

The test fixture may export exactly one callable named
`bookingRawBodyProbeV1`. Inside the handler it:

1. reads `request.rawRequest.rawBody` without logging or converting it first;
2. computes only byte length and lowercase SHA-256 for comparison with the
   committed test vector;
3. calls the completed RAW-A inspector with raw bytes, `request.data` and the
   Booking command validator;
4. returns one minimized test result:

```text
accepted: {kind, rawByteLength, rawSha256, semanticHash}
rejected: {kind, reason, rawByteLength, rawSha256}
```

The response must never contain the raw body, command payload, request ID,
idempotency key, actor data, headers or tokens. Test inputs use synthetic values
only.

## 5. Exact transport corpus

### 5.1. Handler-reaching vectors

The following must reach the callable handler and prove exact byte digest:

1. valid Booking command with compact JSON;
2. the same command with leading/trailing protocol whitespace and reordered
   nested keys;
3. supplementary Unicode encoded literally;
4. the same Unicode encoded with JSON escapes;
5. duplicate nested Booking key;
6. duplicate top-level `data` key;
7. escaped unpaired surrogate;
8. fractional and rounded-to-integer numeric forms;
9. mathematical underflow (`1e-400`);
10. callable `@type` integer wrapper attempting protocol transformation;
11. raw/framework mismatch vector where callable decoding changes the value.

Accepted vectors must preserve RAW-A/JCS semantic results. Rejection vectors
must return the expected closed RAW-A reason and must never return `accepted`.

### 5.2. Framework-rejected vectors

These may be rejected before the handler, but must fail closed with callable
protocol `INVALID_ARGUMENT`/HTTP 400 and no success body:

- invalid UTF-8 byte sequence;
- UTF-8 BOM if middleware rejects it before handler;
- missing `data`;
- extra top-level member;
- non-JSON and trailing bytes;
- request larger than the test/application limit.

The test records whether rejection occurred at framework or adapter boundary.
It must not reinterpret framework rejection as adapter evidence.

## 6. Temporary source contract

The runner creates a uniquely named directory under
`apps/backend/functions/.raw-body-probe-*` only after resolving and validating
that its absolute path remains inside `apps/backend/functions`.

It copies compiled test JS and required support JS while preserving relative
imports, then writes a temporary package manifest and emulator config. Node
module resolution may use the existing pinned parent `node_modules`; no second
dependency installation or lockfile is allowed.

The temporary config contains only:

- Functions source pointing to that temporary directory;
- runtime `nodejs22`;
- Functions Emulator host `127.0.0.1`, port `5101`;
- UI disabled and single-project mode enabled.

The runner must remove the temporary source and config in `finally`, after
terminating only its own recorded emulator child. Recursive removal is allowed
only after revalidating the exact resolved temporary target.

## 7. Network and cloud denial

1. `verify-no-cloud-context.mjs` passes before emulator start.
2. Required dependencies already exist from the frozen install.
3. Every endpoint URI resolves to `127.0.0.1` or `localhost`.
4. Firebase CLI always receives `--project demo-recharge` and explicit temp
   `--config`.
5. No `.firebaserc`, ADC, Firebase token, OAuth token or real project variable
   may exist.
6. No download, deploy, API enablement, billing, IAM or credential operation is
   allowed.
7. Unexpected outbound socket intent fails the gate.

## 8. Exact implementation file plan

### 8.1. Add

| Path | Purpose |
|---|---|
| `apps/backend/functions/test/emulator/booking_callable_raw_body_probe.ts` | Test-fixture Functions v2 callable export; never imported by product `src` |
| `apps/backend/functions/test/emulator/booking_callable_raw_body_probe_client.ts` | Exact raw HTTP corpus and protocol assertions |
| `apps/backend/scripts/run-booking-raw-body-probe.mjs` | Safe build/temp-source/emulator/cleanup orchestrator |

### 8.2. Modify

| Path | Exact bounded change |
|---|---|
| `apps/backend/functions/package.json` | Add `test:emulator:raw-body`; no dependency or product `main` change |
| `.github/workflows/backend-r0.yml` | Run the new loopback-only probe after existing Booking contract parity on Ubuntu and Windows |
| `docs/product/BACKEND_EVENT_BOOKING_RAW_BODY_EMULATOR_SLICE_SPEC.md` | Evidence/status reconciliation after verified implementation |

### 8.3. Must remain byte-identical

- `apps/backend/functions/src/**`;
- tracked `apps/backend/firebase.json`, Rules, indexes and Terraform;
- `apps/backend/functions/package-lock.json`;
- all `packages/api_contracts/**` schemas, fixtures and Dart code;
- all `apps/mobile/**` files;
- Accepted ADRs.

Any additional tracked implementation file requires a plan revision and new
approval before editing.

## 9. Test assertions

The suite must prove:

- received raw byte length and SHA-256 equal the client-sent bytes;
- callable middleware-decoded `request.data` agrees with strict raw parsing for
  every accepted Booking value;
- duplicate keys remain visible in raw bytes and are rejected by RAW-A;
- unpaired surrogate, unsafe number and protocol wrapper attempts fail closed;
- valid lexical differences preserve the Accepted semantic hash;
- framework-level rejection is distinguishable from adapter rejection;
- no probe result exposes raw values or request metadata;
- no Admin SDK initialization, Firestore access or side effect occurs;
- only the temporary package exposes `bookingRawBodyProbeV1`;
- product `src/index.ts` still exports only `r0ToolchainProbe`;
- the temporary directory/config is absent after success and failure paths.

## 10. Verification gates

1. record baseline LF-normalized SHA-256 for all must-remain-identical files;
2. format, ESLint and strict TypeScript typecheck pass;
3. unit and complete Booking contract suites pass;
4. RAW-B probe passes with exact Node 22.23.2 on local available toolchain or is
   reported Inconclusive;
5. existing R0 emulator isolation/default-deny suite remains green;
6. generated-output and reproducibility gates pass;
7. Terraform and no-cloud-context gates remain green;
8. root boundaries and diff/whitespace checks pass;
9. Ubuntu 24.04 and Windows 2025 hosted RAW-B jobs pass on the exact commit;
10. post-run filesystem scan finds no `.raw-body-probe-*` artifact;
11. baseline/post hashes match for every immutable surface;
12. draft PR remains unmerged.

### 10.1. Current local evidence

| Gate | Result |
|---|---|
| Prettier check | Pass |
| ESLint | Pass |
| strict TypeScript typecheck | Pass |
| Booking contract suite | Pass — 15/15 |
| generated-output safety | Pass — 30 files |
| reproducible logical build | Pass — `a9a84bc49bb2e49b828c7567ed74c63fdcfcefbb265ab3463bd803290f38b0e6` |
| repository boundary gate | Pass — 0 violations, 0 stale/expired exceptions |
| immutable Git diff from approved plan commit `ab31c22` | Pass |
| leftover `.raw-body-probe-*` directories | Pass — 0 |
| RAW-B emulator corpus | Pass hosted — 19/19 vectors on Ubuntu and Windows |
| existing R0 unit/emulator suites | Pass hosted on Ubuntu and Windows |
| Initial Ubuntu/Windows hosted evidence | Fail — runs `33206783480` and `33206787424` exposed a temporary ESM bootstrap incompatibility before any handler result |
| Corrected Ubuntu/Windows hosted evidence | Pass — runs `33207838539` and `33207840478` at `e043218` |
| hosted reproducible logical build | Pass — identical digest `e9443933cf9b823819e95ebdd921c62909c3dc38a618092348ac8f0ac775d8e4` |
| repository lint/boundaries/codegen/mobile tests | Pass on `e043218` |

The completed hosted probe establishes only that the pinned Functions Emulator
preserved and exposed the required bytes for the committed synthetic corpus.

The initial hosted failure was fail-safe and infrastructure-only: Firebase
Emulator attempted synchronous `require()` of a generated ESM entry containing
top-level `await`, then the runner reached its 300-second timeout. Both operating
systems reported the same cause. The repair uses a temporary Node 22 synchronous
CJS bootstrap, declares the already pinned parent `firebase-admin` dependency
without installing or importing Admin SDK in the probe, and bounds every client
request to 20 seconds. The corrected jobs passed on both operating systems.

## 11. Definition of Ready

Implementation started only after:

1. the Product owner explicitly approved this exact v0.1 slice;
2. the owner explicitly permitted the narrowly scoped disposable test-fixture
   callable export while retaining the product-export prohibition;
3. RAW-A v0.3 remains Done and unchanged;
4. the working tree was clean at approved plan commit `ab31c22`;
5. the exact baseline hashes were recorded;
6. Node/Firebase dependencies remained pinned and installed;
7. no runtime, tracked Firebase config, cloud, push, merge or deployment
   permission was inferred.

## 12. Definition of Done

RAW-B is Done only when:

1. the exact §8 plan is respected;
2. all required handler-reaching byte digests match;
3. all rejection vectors fail at the recorded boundary;
4. RAW-A semantic-hash evidence remains unchanged;
5. Ubuntu and Windows hosted evidence passes on the exact commit;
6. all existing R0 and repository gates remain green;
7. cleanup succeeds on normal and induced-failure paths;
8. no temporary artifact, product export or Firebase resource remains;
9. documentation reports only `Emulator feasible`;
10. BCK-09/ECL-03C remain Review/runtime Absent and all specialist signatures
    remain Pending.

All ten conditions passed at `e043218`. RAW-C, product callable exports,
Booking runtime, Firebase resource changes, Firestore/Admin access, deployment
and merge remain outside this verdict and require separate authorization.

## 13. Stop conditions

Stop and return to Review if:

- the handler does not receive byte-identical `rawBody`;
- required duplicate/surrogate/numeric vectors are normalized before the
  adapter and cannot be distinguished safely;
- the probe requires editing product `src`, tracked Firebase config or lockfile;
- Firebase CLI attempts non-loopback access or a non-demo project;
- a temporary artifact survives cleanup;
- Windows and Ubuntu disagree;
- an existing contract, R0 or repository gate regresses;
- any gate is skipped, times out or runs on an unpinned toolchain.

Failure of RAW-B means the future transport design must return to API review.
It does not authorize switching silently from callable to generic HTTP.

## 14. Rollback

Before runtime, rollback is one revert of the isolated implementation commit
plus its documentation reconciliation commit. The runner removes its own
temporary artifacts. There is no data, Firebase resource, deployment, mobile
consumer or migration rollback.

## 15. Acceptance criteria

1. **BCK09-RAW-B-AC-01:** RAW-B is emulator/test-only.
2. **BCK09-RAW-B-AC-02:** implementation requires separate explicit approval.
3. **BCK09-RAW-B-AC-03:** the disposable export is not a product export.
4. **BCK09-RAW-B-AC-04:** product `src/index.ts` remains byte-identical.
5. **BCK09-RAW-B-AC-05:** tracked Firebase configuration remains byte-identical.
6. **BCK09-RAW-B-AC-06:** only `demo-recharge` and loopback are allowed.
7. **BCK09-RAW-B-AC-07:** no Auth/App Check identity evidence is claimed.
8. **BCK09-RAW-B-AC-08:** no Admin SDK or Firestore access exists.
9. **BCK09-RAW-B-AC-09:** sent and received raw byte digests must match.
10. **BCK09-RAW-B-AC-10:** raw and decoded values are compared.
11. **BCK09-RAW-B-AC-11:** duplicate keys remain detectable.
12. **BCK09-RAW-B-AC-12:** Unicode failures remain detectable or fail earlier.
13. **BCK09-RAW-B-AC-13:** unsafe numeric forms fail closed.
14. **BCK09-RAW-B-AC-14:** callable typed wrappers cannot bypass the contract.
15. **BCK09-RAW-B-AC-15:** framework and adapter rejection are distinct.
16. **BCK09-RAW-B-AC-16:** semantic hash remains projection/JCS based.
17. **BCK09-RAW-B-AC-17:** responses contain no raw or personal values.
18. **BCK09-RAW-B-AC-18:** the exact test corpus is committed.
19. **BCK09-RAW-B-AC-19:** temporary source stays inside a validated directory.
20. **BCK09-RAW-B-AC-20:** cleanup runs in `finally`.
21. **BCK09-RAW-B-AC-21:** cleanup failure fails the gate.
22. **BCK09-RAW-B-AC-22:** no second dependency install or lock drift occurs.
23. **BCK09-RAW-B-AC-23:** exact Node/Firebase versions are verified.
24. **BCK09-RAW-B-AC-24:** existing R0 gates remain green.
25. **BCK09-RAW-B-AC-25:** Ubuntu and Windows evidence is mandatory.
26. **BCK09-RAW-B-AC-26:** unavailable or timed-out evidence is Inconclusive.
27. **BCK09-RAW-B-AC-27:** no cloud, IAM, billing or credential action occurs.
28. **BCK09-RAW-B-AC-28:** no push, merge or deployment is implied.
29. **BCK09-RAW-B-AC-29:** RAW-B does not authorize RAW-C or ECL-03C runtime.
30. **BCK09-RAW-B-AC-30:** all specialist signatures remain Pending.
31. **BCK09-RAW-B-AC-31:** failure returns the transport design to API review.
32. **BCK09-RAW-B-AC-32:** switching transport requires an explicit decision.
33. **BCK09-RAW-B-AC-33:** rollback is commit-bounded and zero-data.
34. **BCK09-RAW-B-AC-34:** temporary artifacts are absent after every run.
35. **BCK09-RAW-B-AC-35:** evidence records exact commit and run IDs.
36. **BCK09-RAW-B-AC-36:** BCK-09/ECL-03C remain Review/runtime Absent.

## 16. Approval phrase

```text
Одобряю BCK09-API-RAW-B-01 v0.1 для disposable emulator/test-only
implementation. Разрешаю только временный test-fixture callable export,
создаваемый runner внутри cleanup-bound temporary source. Product src/index.ts,
tracked Firebase config, Booking runtime, Firestore/Admin access, cloud,
deployment, push и merge не разрешаю.
```
