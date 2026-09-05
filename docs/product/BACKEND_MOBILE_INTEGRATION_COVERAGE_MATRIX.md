# BCK-18 — Mobile Backend Integration Coverage Matrix

- ID: **BCK-18-PRE**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Mobile Platform owner**
- Target: [BCK-18 v0.2](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
- Coordination baseline: [BCK-02 v2.4.34](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2 — 2026-08-25

- reconciled the matrix to BCK-18 v0.2 Review;
- verified 22/22 design coverage, 60 target AC and eight aligned BCK18
  decisions plus the mobile request-ID erratum and M2 Money prerequisite;
- preserved all runtime, contract-generation, OD-04/08/10 and production gates;
- recorded zero new boundary suppressions and no runtime file changes.

### v0.1 — 2026-08-25

- created the source/runtime/gap audit and 24 preparatory AC;
- mapped the 22 mandatory BCK sections and reconciliation boundaries.

## 1. Verdict

BCK-18 v0.2 is Present in Review. Current mobile code provides useful
local/mock ports, repositories, mappers, caches and one shared Booking contract
family, but no production product-backend adapter or Firebase integration.

Runtime implementation is
blocked by unfinished mobile Money migration, non-Approved platform/domain
dependencies and Open OD-04/OD-08. This matrix creates no schemas, adapters,
Firebase dependencies, imports, migrations, credentials or backend writes.

## 2. Source reconciliation

| Source | Current status | BCK-18 treatment |
|---|---|---|
| Accepted ADR and Architecture Baseline | Accepted/Frozen | Layering, generated-code and authoritative backend boundaries cannot be weakened |
| Mobile Architecture v3.1 | Accepted mobile target | Ports/adapters, states, M8/M9 and mobile UX semantics; one request-ID erratum logged below |
| BCK-01 v0.4.29 | Review | Parent backend architecture; runtime claims remain Absent |
| BCK-02 v2.4.34 | Approved coordination | Ownership, sequencing, gates and 22-section template |
| BCK-03 v0.3.3 | Draft with Accepted split-key decision | Wire envelope, result/error, version, idempotency and retry semantics |
| BCK-04 v0.4.16 | Draft | Mobile security/privacy overlay; no client authority |
| BCK-06 v0.2 | Review | Identity/access/publisher authority input; runtime Absent |
| BCK-20 v0.2.2 | Draft | Market/reference/localization input; OD-10 Proposed |
| API Contracts Workflow v1.1 | Accepted repository workflow | Booking-only cross-language schema exception until another Accepted authorization |
| Current mobile runtime | Local/mock plus bounded provider HTTP | Evidence/debt only; not target backend authority |
| OD-04 | Open | Import mapping/conflict/checkpoint/retry/dedupe/rollback unresolved |
| OD-08 | Open | Account/provider/local identity mapping unresolved |
| OD-10 | Proposed | LocalizedText/reference wire policy not Accepted |

## 3. Current implementation inventory

| Area | Present | Gap to target |
|---|---|---|
| Layering | feature domain/data/application/presentation plus composition root | Legacy boundary suppressions remain; no general remote seam policy |
| DI | `get_it` binds mock/local implementations; Riverpod presents state | No environment-safe product backend binding registry |
| Auth | mock remote datasource + secure local session | No Firebase Auth/App Check, target provider adapter or authoritative access snapshot |
| Discover | mock remote datasource/repository | No production catalog transport, revision/freshness parity or feed/map/search reconciliation adapter |
| Create | rich local datasources/mappers, idempotent local persistence | No per-domain remote command adapters; Money migration incomplete |
| Identity | local workspace/page repository | No BCK-06 remote adapter and mock grants cannot migrate |
| Library | local favorites/visits/notifications | No server sync/import contracts; each owning domain still writes its aggregate |
| Provider HTTP | Latvia GTFS fetch is a bounded external reference/provider adapter | Must not be mistaken for Recharge product backend integration |
| API contracts | Booking v1 schemas/fixtures and immutable Dart DTOs | No common generated mobile client or non-Booking identity/content/reference contracts |
| Firebase SDK | No mobile Firebase Auth/Firestore/Storage/App Check dependency found | Addition requires separate Approved executable slice |
| Boundary gate | 380 Dart files, 71 exact suppressions, 0 violations | Budget is full; no new suppression permitted by this slice |

## 4. Mandatory BCK-02 §14 coverage plan

| # | Requirement | BCK-18 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; split-key conflict reconciled |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope | §4 | Full |
| 5 | Ownership | §5–6 | Full; no aggregate authority leakage |
| 6 | Data/projections | §7–8 | Full semantic algebra; runtime types remain per feature |
| 7 | Commands/queries/events/errors | §9–10 and §18 | Full semantic mapping; executable clients absent |
| 8 | Versions/evolution/client | §11 | Full; non-Booking generation decision open |
| 9 | AuthZ/revocation | §12 | Full target boundary; BCK-06/runtime absent |
| 10 | Persistence/index/transactions | §13 and §16 | Full client boundary; import/runtime absent |
| 11 | IDs/time/reference | §17 | Full; M2 Money and OD-10 block cutover |
| 12 | Idempotency/concurrency/retry/failure | §9, §10 and §15 | Full; mobile erratum remains editorial debt |
| 13 | Offline/cache/freshness | §8, §13–14 | Full semantic contract; exact domain defaults open |
| 14 | Migration/import/compat | §16 | Full fail-closed design; OD-04/08 block execution |
| 15 | Outbox/replay/dedupe | §18 | Full mobile-consumer boundary; event runtime absent |
| 16 | Privacy/retention/Legal | §19 | Full boundary; per-family decisions/evidence absent |
| 17 | Abuse/rate/App Check | §12 and §20 | Full; production controls absent |
| 18 | Logs/SLO/analytics/cost | §21 | Full structure; numeric evidence absent |
| 19 | Flags/rollout/rollback | §22–23 | Full; production binding/cutover decisions open |
| 20 | Exact file map | §25 | Full conditional map; no runtime authorization |
| 21 | Test matrix | §26 | Full planned evidence; executable evidence absent |
| 22 | AC/DoR/DoD/unimplemented | §27–30 | Full; 60 sequential AC and explicit absent list |

**Coverage verdict:** 22/22 addressed at Review design level; Approval and
runtime completion are not claimed.

## 5. Reconciliation contract

| Concern | Single source/writer | BCK-18 responsibility | Forbidden behavior |
|---|---|---|---|
| Wire schema | `packages/api_contracts` under Accepted workflow | Consume/version/map | Feature-local duplicate DTO semantics |
| Domain invariant | Owning feature domain/BCK spec | Preserve in mapper/repository | DTO becomes domain entity |
| Backend authority | Owning BCK domain | Call/query and map result | Direct client authoritative Firestore write |
| Mobile orchestration | Feature application controller/use case | State, cancellation and intent | Business rules in presentation/data |
| Transport | Feature data adapter/core technical client | Auth/App Check/envelope/error mapping | Firebase/HTTP in domain/presentation |
| Cache/local data | Owning feature data layer | Metadata, migration, deletion and freshness | Cache treated as server grant |
| Import orchestration | BCK-18 session/checkpoint | Route each item to owning domain command | BCK-18 writes imported aggregate directly |
| Identity mapping | BCK-06 + OD-08 | Consume explicit mapping | Email/name/device inference |
| Reference values | BCK-20 | Carry stable ID/revision/fallback | Baltic hardcoded wire enums |
| Effects/events | Owning producer/consumer BCK | Consume checkpointed projection/events | Client becomes outbox authority |

## 6. Detected conflicts and gaps

| ID | Finding | Required disposition |
|---|---|---|
| BCK18-GAP-01 | Closed: BCK-18 v0.2 is Present in Review | Preserve runtime Absent and complete owner decisions before Approval |
| BCK18-GAP-02 | Mobile Architecture §19/AC-42 says unknown retry keeps `requestId`; BCK-03 Accepted split-key requires fresh attempt `requestId` and stable logical `idempotencyKey` | BCK-03 wire rule wins at backend seam; record mobile v3.1 erratum without renumbering AC |
| BCK18-GAP-03 | M2 Money migration incomplete and normalized `double` fields remain | M8 remote writes blocked until minor-unit migration/fixtures pass |
| BCK18-GAP-04 | API workflow authorizes cross-language schema source only for Booking | Non-Booking schema/codegen needs Accepted API decision; no hand-authored generated files |
| BCK18-GAP-05 | Mock/local binding is centralized but production exclusion is not evidenced | Define build/runtime binding manifest and fail-closed startup |
| BCK18-GAP-06 | Feature cache/freshness states are inconsistent | Define one semantic state algebra without requiring one shared UI class |
| BCK18-GAP-07 | OD-04 import contract is Open | No local-to-cloud import execution |
| BCK18-GAP-08 | OD-08 identity mapping is Open | No user/page/grant migration |
| BCK18-GAP-09 | OD-10 localization wire is only Proposed | No content/reference cutover dependent on it |
| BCK18-GAP-10 | BCK-03/04/20 Draft and BCK-06 Review | Review-safe drafting allowed; runtime/Approval remains blocked |
| BCK18-GAP-11 | Current direct GTFS HTTP may be mistaken for Recharge backend | Classify as external reference/provider adapter with independent freshness/security |
| BCK18-GAP-12 | Boundary exception budget is 71/71 | BCK-18 adds zero suppressions; any executable slice must remove or separately approve debt |

## 7. Open decisions

| ID | Decision | Owner | Gate | Default |
|---|---|---|---|---|
| BCK18-OD-01 / OD-04 | Import session, checkpoint, conflict, dedupe, retry, disclosure and rollback | Mobile Platform + domains | Any import | Disabled |
| BCK18-OD-02 / OD-08 | Local user/page mapping to production identity | Identity + Mobile | Identity/import | No inference/import |
| BCK18-OD-03 | Common mobile transport/client generation strategy after Booking exception | API + Mobile | Non-Booking remote adapters | No new generated contract family |
| BCK18-OD-04 | Canonical cache/read-state semantic algebra and freshness defaults | Mobile + domains | M8/M9 | Domain-specific local state only; no server claim |
| BCK18-OD-05 | Production binding manifest, flavor gates and mock exclusion proof | Mobile + Operations/Security | Any production build | Remote-required features unavailable |
| BCK18-OD-06 | Per-domain cutover order, shadow-read thresholds and rollback window | Mobile + domain owners | M9/R3 | Local/mock remains explicitly non-production |
| BCK18-OD-07 | Secure local cache classification, encryption and deletion policy per family | Mobile + Privacy/domains | Production personal data | No production cache |
| BCK18-OD-08 / OD-10 | LocalizedText/reference adapter contract | Reference + API + Mobile | Content/reference cutover | Unsupported/disabled |

## 8. Fail-closed defaults

- no Firebase product adapter or direct authoritative write;
- no production build with mock authority;
- no remote write while Money remains normalized as `double`;
- no account/page/grant import;
- no implicit merge or last-write-wins;
- no unknown-outcome retry with a new idempotency key;
- no newer unsupported contract partial application;
- no stale cache authorization;
- no content/reference cutover relying on unaccepted OD-10;
- no App Check bypass or client capability grant.

## 9. Conditional file plan

Documentation:

```text
docs/product/MOBILE_BACKEND_INTEGRATION_STANDARD.md
docs/product/BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md
```

Future executable work, only after separate authorization:

```text
packages/api_contracts/schema/<domain>/<version>/*
packages/api_contracts/lib/src/contracts/<domain>/*
packages/api_contracts/lib/src/dto/<domain>/*
apps/mobile/lib/core/network/*
apps/mobile/lib/app/di/backend_binding_manifest.dart
apps/mobile/lib/features/<feature>/data/{datasources,mappers,repositories}/*
apps/mobile/lib/features/<feature>/application/*
apps/mobile/test/{unit,integration}/backend_integration/*
```

Physical paths require exact per-domain slice review and must follow the actual
repository structure. This matrix authorizes none of them.

## 10. Approval-review prerequisites

Review entry evidence is complete. Advancement beyond Review requires:

1. full target continues to address 22/22 sections;
2. split-key conflict is explicit;
3. M2 Money → M8 dependency is blocking;
4. mock, cache and server authority cannot be conflated;
5. OD-04/08/10 remain exact and fail-closed;
6. import never becomes aggregate writer;
7. contract source/codegen rules preserve the Booking-only exception;
8. current runtime inventory remains factual;
9. all future files are conditional;
10. links, AC, fences, diff and boundary checks pass.

## 11. Preparatory acceptance criteria

1. **BCK-18-PRE-AC-01:** Target absence and mobile/backend runtime absence are explicit.
2. **BCK-18-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-18-PRE-AC-03:** BCK-03 owns wire attempt/idempotency semantics.
4. **BCK-18-PRE-AC-04:** A retry uses a fresh request ID and stable idempotency key.
5. **BCK-18-PRE-AC-05:** Mobile AC-42 conflict is logged without silent renumbering.
6. **BCK-18-PRE-AC-06:** Money migration blocks remote writes through M8.
7. **BCK-18-PRE-AC-07:** API contracts remain the wire source of truth.
8. **BCK-18-PRE-AC-08:** Booking is the only currently authorized cross-language schema exception.
9. **BCK-18-PRE-AC-09:** DTO, mapper and domain types remain separate.
10. **BCK-18-PRE-AC-10:** Transport remains outside domain/presentation.
11. **BCK-18-PRE-AC-11:** Mock selection occurs only in composition.
12. **BCK-18-PRE-AC-12:** Production has no mock-authority fallback.
13. **BCK-18-PRE-AC-13:** Cache state never grants authority.
14. **BCK-18-PRE-AC-14:** Import routes through owning domain commands.
15. **BCK-18-PRE-AC-15:** OD-04 blocks all import execution.
16. **BCK-18-PRE-AC-16:** OD-08 blocks identity inference/migration.
17. **BCK-18-PRE-AC-17:** OD-10 remains Proposed and dependent cutover disabled.
18. **BCK-18-PRE-AC-18:** External GTFS HTTP is not Recharge backend authority.
19. **BCK-18-PRE-AC-19:** Newer unsupported contracts fail closed.
20. **BCK-18-PRE-AC-20:** User cancellation differs from unknown remote outcome.
21. **BCK-18-PRE-AC-21:** Boundary suppressions do not increase.
22. **BCK-18-PRE-AC-22:** Documentation checks are not runtime evidence.
23. **BCK-18-PRE-AC-23:** Future files remain conditional.
24. **BCK-18-PRE-AC-24:** Firebase, runtime, push and `main` remain untouched.

## 12. Next controlled step

Integrate the real BCK-18 Review/Present/runtime-Absent state into
BCK-01/BCK-02/LAUNCH_STATUS. Then prepare BCK-14 in the approved sequence.
No BCK-18 Approval, contract generation or executable slice is implied.
