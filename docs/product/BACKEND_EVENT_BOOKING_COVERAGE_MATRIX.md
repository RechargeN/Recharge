# BCK-09 — Event Booking Coverage and Reconciliation Matrix

- ID: **BCK-09-PRE**
- Version: **1.3**
- Status: **Review — documentation only**
- Runtime status: **N/A / Absent**
- Date: **2026-08-26**
- Target: [EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)

## 0. Changelog

### v1.3 — 2026-08-26

- registered BCK09-API-REV-01 v0.1 technical Hold and BCK09-REV-01 v0.3;
- recorded schema/DTO, request-attempt binding, transport/hash, request-ID and
  executable parity gaps without changing 22/22 design coverage or 27 AC;
- kept BCK-09/ECL-03C Review and runtime Absent.

### v1.2 — 2026-08-26

- reconciled BCK09-REV-01 findings TR-09..11 into BCK-09 v1.4 and ECL-03C v1.2;
- added one deterministic active-key record, exact BCK-19/BCK-09 repair
  ownership and fail-closed outbox suppression/handoff semantics;
- preserved all 24 preparatory AC and appended AC-25..27; runtime remains Absent.

### v1.1 — 2026-08-26

- recorded BCK09-DEC-01 v0.2 Product acceptance with controls;
- reconciled six Accepted design dispositions and four Deferred/Open decisions;
- preserved BCK-09 Review, ECL-03C Review and runtime Absent boundaries.

### v1.0 — 2026-08-26

- audited BCK-09 against all 22 BCK-02 mandatory categories;
- reconciled ADR 0019, ECL-03 v1.2, D01–D11, ECL-03B and ECL-03C v1.1;
- preserved committed Booking v1 wire semantics and exact ECL-03C records;
- separated Booking, Content, Discover, Notifications, Operations and Admin
  single writers;
- recorded 24 preparatory acceptance criteria and ten activation decisions;
- created no backend, Firebase, contract, mobile or deployment runtime.

## 1. Verdict

**Coverage: 22/22. API technical review: Hold. Recommendation: keep BCK-09
v1.4 as Review / Present / runtime Absent.**

The document is internally reconcilable and suitable for owner review. It is
not Approved, executable, deployed or production-ready. The first possible
runtime remains the separately approved, bounded ECL-03C transaction core.

## 2. Sources and authority

| Source | Status used | Reconciliation role |
|---|---|---|
| ADR 0019 | Accepted | Booking architecture and hard invariants |
| Event Classification v2.2.3 | Accepted | Canonical Event/admission product semantics |
| ECL-03 v1.2 | Approved, activation gated | Parent implementation contract |
| ECL03-D01–D11 | Accepted / normative | Product/architecture decisions |
| ECL-03B v1.1 | Done, contracts/domain only | Committed wire and Dart evidence |
| ECL-03C v1.2 | Review, runtime not authorized | Exact first executable plan with deterministic active key |
| BCK-01 v0.4.41 | Review | Parent modular/single-writer architecture |
| BCK-02 v2.4.45 | Approved baseline + amendments | Registry, categories, OD/gates |
| BCK-03 v0.3.3 | Draft | Common API proposal and Booking v1 reconciliation |
| BCK-04 v0.4.16 | Draft | Security/privacy/Legal activation blockers |
| BCK-05 v0.2.23 | Draft | Environments, flags, operations and release controls |
| BCK09-DEC-01 v0.2 | Accepted with controls | Product baseline selection and explicit ten-decision dispositions; no runtime authority |
| BCK09-REV-01 v0.3 | Specialist review in progress | API technical Hold; all nine named sign-offs remain Pending |
| BCK09-API-REV-01 v0.1 | Technical Hold | Schema/DTO, request binding, API-DEC-01/03, request-ID and parity findings; not a named signature |
| BCK-06 v0.2 | Review | Identity/capability authority target |
| BCK-07 v0.2 | Review | Published Event lifecycle/config writer target |
| BCK-08 v0.2 | Review | Public composed availability writer target |
| BCK-13 v0.2 | Review | Inbox/preferences/push/delivery writer target |
| BCK-19 v0.2 | Review | Staff case/proposal/approval writer target |

Draft/Review dependencies remain blockers. This matrix does not silently
promote any dependency or owner decision.

## 3. Current implementation inventory

| Area | Repository fact | Consequence |
|---|---|---|
| ECL-03A | Accepted/Approved documents only | Architecture is fixed; runtime absent |
| ECL-03B | Booking v1 JSON schemas/fixtures and Dart DTO/domain tests | Contract evidence, not backend |
| ECL-03C | Exact v1.2 plan in Review | Implementation not authorized |
| ECL-03D–H | Full target behavior only | Separate specs/evidence required |
| Event runtime | Local/mock availability and external handoff | Never Booking authority |
| Backend scaffold | R0 tooling only; no product handlers/resources | Cannot claim Booking runtime |
| Firebase | No product provisioning/deployment/data evidence | Runtime Absent |

## 4. Mandatory BCK-02 coverage

| # | Category | BCK-09 section | Result |
|---:|---|---|---|
| 1 | Outcome/non-goals | §§2–3 | Covered |
| 2 | Actors/roles/capabilities | §7 | Covered |
| 3 | Entities/value objects/states | §§8–9 | Covered |
| 4 | Commands/use cases | §§10–12 | Covered |
| 5 | Queries/read models | §§9–10 | Covered |
| 6 | Data classification/projections | §§8–9, 17 | Covered |
| 7 | Ownership/single writers | §§4, 8–9, 15, 19 | Covered |
| 8 | Events/outbox/effects | §§12–15 | Covered/gated |
| 9 | Failure vocabulary | §§10, 21 | Covered |
| 10 | Persistence/index/transaction | §§8, 11–12 | Covered |
| 11 | IDs/time/revisions | §§8–13, 20 | Covered |
| 12 | Idempotency/concurrency/replay | §§11–14 | Covered |
| 13 | Offline/cache/multi-device | §21 | Covered |
| 14 | Migration/cutover/compatibility | §§20, 22, 30 | Covered |
| 15 | Security/abuse/moderation | §§7, 16, 19 | Covered |
| 16 | Privacy/consent/retention/DSR | §§16–17 | Covered/gated |
| 17 | Observability/SLO/analytics/cost | §§18, 23 | Covered/gated |
| 18 | Flags/rollout/rollback | §§22, 24, 29 | Covered |
| 19 | Dependencies/delivery gates | §§3, 28–31 | Covered |
| 20 | Exact file map | §25 + ECL-03C §10 | Covered/conditional |
| 21 | Tests/acceptance/evidence | §§26–29 | Covered |
| 22 | Owner decisions/blockers | §31 | Covered |

## 5. Single-writer reconciliation

| Record/capability | Single writer | BCK-09 posture |
|---|---|---|
| Published Event lifecycle/config revision | BCK-07 Content | Consume pinned input only |
| Booking/active-key/hold/ledger/usage/idempotency/audit | BCK-09 Booking | Own |
| Booking notification obligation | BCK-09 Booking | Own atomic outbox fact |
| Inbox/preferences/device registration/delivery attempt | BCK-13 Notifications | Emit Accepted intent only |
| Internal availability source | BCK-09 Booking | Own ledger-derived source |
| Public composed availability | BCK-08 Discover | Supply sourced/fresh input only |
| Feature-flag registry/change audit | BCK-05 Operations | Consume current resolved value |
| Identity/account/capability/revocation | BCK-06 Identity | Re-evaluate trusted server input |
| Staff case/proposal/approval | BCK-19 Admin | Execute only owning-domain repair command |
| Privacy request orchestration | BCK-04 Privacy | Execute scoped Booking handler only |

No reconciled record has two writers. Console/mobile/manual writes are not a
writer path.

## 6. Contract and collection reconciliation

| Concern | Previous risk | v1.4 disposition |
|---|---|---|
| Booking result | Invented `ApiResult` drift | Preserve committed Booking v1 `kind`; BCK-03 adapter/new major gated |
| Cancellation wording | Domain cancel confused with transport cancel | `CancelBooking` success is distinct from common `cancelled` outcome |
| Retry identity | Request and logical mutation could be conflated | D11 split-key contract preserved; fresh attempt ID on retry |
| ECL-03C collections | Full-target names could override exact plan | Exact nine ECL-03C names are normative; active key is part of C |
| Holds/workers/repair collections | Appeared prematurely executable | Conditional until ECL-03D–H exact plans |
| Notification delivery | BCK-09 looked like second delivery writer | BCK-13 owns inbox/channel attempts; BCK-09 owns only obligation |
| Feature flags | Domain appeared to own platform registry | BCK-05 writer; BCK-09 fail-closed consumer |
| Waitlist on sold out | Full target could leak into ECL-03C | ECL-03C always rejects; waitlist starts in ECL-03D |
| Duplicate-active | Query prose did not name a contention point | Deterministic versioned active-key record is atomic for finite/unlimited create/cancel |
| Repair operations | BCK-09 surface could absorb BCK-19 proposal/approval | BCK-19 owns proposal/approval; BCK-09 owns only approved execution |
| Disabled outbox | Suppressed obligations could look overdue or replay later | Immutable suppressed/required disposition; pre-activation records never replay |

## 7. Gap register

| Gap | Severity | Closure evidence |
|---|---|---|
| ECL-03C plan/runtime authorization absent | Blocks executable work | BCK09-OD-01 exact verdict and slice approval |
| API transport/hash implementation open | Blocks mutation runtime | API-DEC-01/03 + BCK09-OD-02 |
| API technical pre-review Hold | Blocks API signature | BCK09-API-TR-01..06 closure and named API Platform verdict |
| Production Identity/capability absent | Blocks all production commands | BCK-06/BCK-18 runtime evidence |
| Event projection writer/handoff absent | Blocks production mutation | BCK-07 runtime + BCK09-OD-04 |
| OD-09/BCK-13 effect handoff not Accepted/runtime | Blocks notifications/workers | BCK09-OD-05 |
| Retention/legal basis/DSR validation absent | Blocks production data | BCK09-OD-06 qualified verdict |
| OD-11 Open | Blocks applicable age-sensitive paths | BCK09-OD-07 per market |
| SLO/cost/RPO/RTO/restore evidence absent | Blocks cohort/GA | BCK09-OD-08 + BCK-05 evidence |
| Repair seam/runtime absent | Blocks manual repair | BCK09-OD-09 + BCK-19/domain command |
| ECL-03D–H exact specs absent | Blocks advanced scope | BCK09-OD-10 per-stage approval |

## 8. Fail-closed defaults

- no local/mock/offline confirmation or inventory mutation;
- no ECL-03C waitlist, hold, Creator action, FCM or reconfirmation;
- no unsupported wire enum or silent Booking v1 rewrite;
- no production command without current Identity and pinned Event input;
- no age-sensitive path while OD-11 is Open;
- no notification effect while OD-09/BCK-13 handoff is unresolved;
- no console/support direct write or automatic drift repair;
- no production processing, cohort, Firebase provisioning or deployment from
  documentation status.

## 9. Preparatory acceptance criteria

1. **BCK-09-PRE-AC-01:** All 22 BCK-02 categories map to target sections.
2. **BCK-09-PRE-AC-02:** ADR 0019 and ECL-03 remain higher-authority anchors.
3. **BCK-09-PRE-AC-03:** ECL-03B evidence is not represented as runtime.
4. **BCK-09-PRE-AC-04:** ECL-03C remains Review and not authorized.
5. **BCK-09-PRE-AC-05:** ECL-03D–H are independently staged targets.
6. **BCK-09-PRE-AC-06:** Existing Booking v1 wire shape is preserved.
7. **BCK-09-PRE-AC-07:** BCK-03 target never silently double-wraps v1.
8. **BCK-09-PRE-AC-08:** D11 split-key semantics are preserved.
9. **BCK-09-PRE-AC-09:** Retry uses the same logical key/payload and fresh attempt ID.
10. **BCK-09-PRE-AC-10:** Exact ECL-03C record names remain normative.
11. **BCK-09-PRE-AC-11:** Later records require later Approved plans.
12. **BCK-09-PRE-AC-12:** Every authoritative record has one writer.
13. **BCK-09-PRE-AC-13:** BCK-07 remains Event publication writer.
14. **BCK-09-PRE-AC-14:** BCK-08 remains public availability writer.
15. **BCK-09-PRE-AC-15:** BCK-13 remains inbox/delivery writer.
16. **BCK-09-PRE-AC-16:** BCK-05 remains feature-flag writer.
17. **BCK-09-PRE-AC-17:** BCK-19 cannot directly repair Booking records.
18. **BCK-09-PRE-AC-18:** ECL-03C sold out never creates waitlist.
19. **BCK-09-PRE-AC-19:** OD-09 effects are disabled until Accepted.
20. **BCK-09-PRE-AC-20:** OD-11-sensitive paths are disabled per market.
21. **BCK-09-PRE-AC-21:** Ten owner decisions have recorded dispositions and explicit safe defaults.
22. **BCK-09-PRE-AC-22:** Target AC remain stable `1..75` and append `76..79`.
23. **BCK-09-PRE-AC-23:** Runtime remains explicitly Absent.
24. **BCK-09-PRE-AC-24:** Review authorizes no Firebase/deployment/main merge.
25. **BCK-09-PRE-AC-25:** ECL-03C exact nine-record plan includes one deterministic finite/unlimited active key.
26. **BCK-09-PRE-AC-26:** BCK-19 proposal/approval and BCK-09 repair execution remain separate writers.
27. **BCK-09-PRE-AC-27:** Suppressed pre-activation outbox records never replay as late effects.

## 10. Evidence summary

- design coverage: **22/22**;
- target AC: **79 sequential criteria**;
- preparatory AC: **27 sequential criteria**;
- owner decisions: **6 Accepted at bounded design scope; 4 Deferred/Open; all
  runtime-sensitive defaults remain fail-closed**;
- runtime files changed: **0**;
- runtime evidence: **Absent**.

## 11. Recommendation

Register BCK-09 v1.4 as **Review / Present / runtime Absent**. The Product
baseline is Accepted with controls, while Approval still requires the named
independent boundary reviews and closure of the four Deferred/Open decisions.
Executable work may begin only through a separately Approved ECL-03C slice;
later behavior requires its own ECL-03D–H approval and evidence.
