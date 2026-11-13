# BCK-21 — Product Analytics & Telemetry Coverage Matrix

- ID: **BCK-21-PRE**
- Version: **0.2**
- Status: **Review — documentation only**
- Runtime status: **N/A / Absent**
- Date: **2026-08-26**
- Target: [ANALYTICS_TELEMETRY_BACKEND_SPEC.md](ANALYTICS_TELEMETRY_BACKEND_SPEC.md)

## 0. Changelog

### v0.2 — 2026-08-26

- completed 22/22 BCK-02 categories;
- reconciled BCK-04/BCK-05 purpose and telemetry boundaries;
- audited taxonomy/catalog/runtime drift and unsafe identifier use;
- added 24 preparatory AC and ten owner decisions.

### v0.1 — 2026-08-26

- initial audit draft.

## 1. Verdict

**Coverage: 22/22. Recommendation: BCK-21 v0.2 enters Review.**

This does not approve OD-05, a destination, SDK, dataset, production
collection, processing, migration or deployment.

## 2. Sources and status

| Source | Status used | Role |
|---|---|---|
| BCK-01 v0.4.36 | Review | Architecture/ownership |
| BCK-02 v2.4.40 | Approved baseline + amendments | Registry/22 categories |
| BCK-03 | Draft | API/event compatibility proposal |
| BCK-04 | Draft | Privacy/legal/DSR blockers |
| BCK-05 | Draft | Operational telemetry/SLO/cost boundary |
| BCK-06 v0.2 | Review | Identity/account lifecycle |
| BCK-18 v0.2 | Review | Mobile queue/cutover behavior |
| Analytics taxonomy/catalog | Documentation Done, legacy/local | Inventory input |
| Current mobile telemetry | Console/local | Compatibility evidence only |

Draft/Review inputs are not silently promoted to Accepted policy.

## 3. Current implementation inventory

| Evidence | Observed fact | Consequence |
|---|---|---|
| Analytics service | Console logger with arbitrary parameter map | Not production transport/schema |
| Common envelope | Not constructed by service | Required before ingestion |
| Literal emitters | 66 distinct names | Full producer inventory required |
| Catalog | 27 actual definitions | Material drift |
| Catalog ownership | 27/27 rows contain TBD owners | No active production definition |
| Emitted not catalogued | At least 45 literal names | Reject until governed |
| Catalogued not emitted | Six names excluding header | Reconcile/remove/migrate |
| Parameters | Raw user/workspace/item/notification IDs observed | Production-blocking privacy debt |
| Backend/destination | Absent | No cloud collection claim |

Counts are the 2026-08-26 static literal audit and may undercount dynamic calls.

## 4. Mandatory BCK-02 coverage

| # | Category | BCK-21 | Result |
|---:|---|---|---|
| 1 | Outcome/non-goals | §§3–4 | Covered |
| 2 | Actors/roles/capabilities | §6 | Covered |
| 3 | Entities/value objects/states | §§7, 10 | Covered |
| 4 | Commands/use cases | §11 | Covered |
| 5 | Queries/read models | §§12, 17 | Covered |
| 6 | Data classification/projections | §§7–9 | Covered |
| 7 | Ownership/single writers | §5 | Covered |
| 8 | Events/outbox/effects | §§10, 13 | Covered |
| 9 | Failure vocabulary | §§7, 11, 13 | Covered |
| 10 | Persistence/index/transaction | §§13, 16 | Covered |
| 11 | IDs/time/revisions | §§7, 9, 14 | Covered |
| 12 | Idempotency/concurrency/replay | §§14–16 | Covered |
| 13 | Offline/cache/multi-device | §15 | Covered |
| 14 | Migration/cutover/compatibility | §§10, 23 | Covered |
| 15 | Security/abuse | §21 | Covered |
| 16 | Privacy/consent/retention/DSR | §§19–20 | Covered |
| 17 | Observability/SLO/analytics/cost | §22 | Covered |
| 18 | Flags/rollout/rollback | §24 | Covered |
| 19 | Dependencies/delivery gates | §25 | Covered |
| 20 | Exact file map | §26 | Covered/conditional |
| 21 | Tests/acceptance/evidence | §§27–29 | Covered |
| 22 | Owner decisions/blockers | §31 | Covered |

## 5. Single-writer reconciliation

| Concern | Owner | BCK-21 posture |
|---|---|---|
| Product event definitions/ingestion | BCK-21 | Owns |
| Curated datasets/metrics | BCK-21 | Owns |
| Operational logs/SLO/alerts | BCK-05 | Correlates only |
| Domain facts/audit | Owning domains | Allowlisted derivative input |
| Identity/account deletion | BCK-06/BCK-04 | Consumes commands/state |
| Enforcement | BCK-22 | Analytics advisory only |
| Staff access/repair | BCK-19 | Audited workflow only |
| Mobile queue/adapters | BCK-18 | Orchestration only |

No proposed analytics record has two authoritative writers.

## 6. Gap register

| Gap | Severity | Closure |
|---|---|---|
| OD-05 destination/transport Open | Blocks all production analytics | OD-01/global OD-05 |
| Purpose/legal basis/consent unresolved | Blocks collection | OD-02 |
| Subject/session key policy unresolved | Blocks identifiers | OD-03 |
| Retention/DSR/anonymization unresolved | Blocks persistence | OD-04 |
| 66/27 catalog drift and TBD owners | Blocks definitions | OD-05 |
| Sampling/late/correction policy absent | Blocks metrics | OD-06 |
| Access/privacy thresholds absent | Blocks datasets | OD-07 |
| Experiment/profiling policy absent | Blocks experiments | OD-08 |
| Mobile queue/cutover absent | Blocks client transport | OD-09 |
| SLO/capacity/quality/cost absent | Blocks cohort | OD-10 |
| Contracts/backend/IAM/destination absent | Blocks runtime | Approved slices |

## 7. Fail-closed defaults

- production analytics and all destinations off;
- unregistered/unknown/unsafe events rejected;
- no raw IDs, free text, prompt/query or exact location;
- no stable pre-auth/cross-purpose identity;
- aggregate-only ordinary access;
- no log backfill or automatic migration;
- no experiments/personalization;
- no generic retention/privacy threshold;
- product remains functional with collection disabled.

## 8. Owner decisions

The target defines `BCK21-OD-01..10`; OD-01 is the BCK-21 resolution surface
for global `OD-05`. Every decision has an owner and fail-closed default. Review
does not accept any of them automatically.

## 9. Preparatory acceptance criteria

1. **BCK-21-PRE-AC-01:** All 22 categories map to target sections.
2. **BCK-21-PRE-AC-02:** Product analytics is separate from operations.
3. **BCK-21-PRE-AC-03:** Domain/audit facts remain domain-owned.
4. **BCK-21-PRE-AC-04:** Analytics cannot authorize enforcement.
5. **BCK-21-PRE-AC-05:** Event definitions have one governance writer.
6. **BCK-21-PRE-AC-06:** Raw/pseudonymous analytics is classified by content.
7. **BCK-21-PRE-AC-07:** Current internal IDs are identified as privacy debt.
8. **BCK-21-PRE-AC-08:** Current console service is not production transport.
9. **BCK-21-PRE-AC-09:** The 66/27 drift is recorded honestly.
10. **BCK-21-PRE-AC-10:** TBD catalog ownership blocks activation.
11. **BCK-21-PRE-AC-11:** Legacy logs cannot be backfilled automatically.
12. **BCK-21-PRE-AC-12:** Subject keys are scoped and server-derived.
13. **BCK-21-PRE-AC-13:** Free text/exact location is prohibited.
14. **BCK-21-PRE-AC-14:** Policy/consent is validated at ingress.
15. **BCK-21-PRE-AC-15:** Datasets/metrics have versioned lineage.
16. **BCK-21-PRE-AC-16:** Retention/DSR has no invented default.
17. **BCK-21-PRE-AC-17:** Experiments remain separately gated.
18. **BCK-21-PRE-AC-18:** Ordinary access is aggregate-only.
19. **BCK-21-PRE-AC-19:** Flags/rollback are independently scoped.
20. **BCK-21-PRE-AC-20:** Ten decisions have fail-closed defaults.
21. **BCK-21-PRE-AC-21:** Target AC are sequential `01..60`.
22. **BCK-21-PRE-AC-22:** Links/fences/whitespace are verifiable.
23. **BCK-21-PRE-AC-23:** Runtime remains explicitly Absent.
24. **BCK-21-PRE-AC-24:** Review authorizes no provider/deployment.

## 10. Evidence summary

- design coverage: **22/22**;
- target AC: **60**;
- preparatory AC: **24**;
- owner decisions: **10**;
- audited literal events/catalog definitions: **66/27**;
- runtime files changed: **0**;
- runtime evidence: **Absent**.

## 11. Recommendation

Register BCK-21 v0.2 as **Review / Present / runtime Absent**. Before Approval,
resolve OD-05 and all blocking BCK21 decisions. Before runtime, complete typed
catalog/contracts, privacy/legal/IAM/destination/DSR/load/cost evidence in
separately Approved slices.
