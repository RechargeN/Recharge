# BCK-12 — User Library & Reviews Coverage Matrix

- ID: **BCK-12-PRE**
- Version: **0.2**
- Status: **Review — documentation only**
- Runtime status: **N/A / Absent**
- Date: **2026-08-26**
- Target: [USER_LIBRARY_REVIEWS_BACKEND_SPEC.md](USER_LIBRARY_REVIEWS_BACKEND_SPEC.md)

## 0. Changelog

### v0.2 — 2026-08-26

- completed 22/22 BCK-02 mandatory categories;
- reconciled VIS-HIST-01 and current local Favorites/Visit runtime;
- separated Library source, Review source, rating projection and BCK-22 cases;
- added 24 preparatory acceptance criteria and ten owner decisions.

### v0.1 — 2026-08-26

- initial audit draft.

## 1. Verdict

**Coverage: 22/22. Recommendation: enter BCK-12 v0.2 into Review.**

This is design coverage, not Approval, runtime readiness, Firebase authority,
migration permission, production processing or deployment.

## 2. Sources and status

| Source | Status used | Role |
|---|---|---|
| BCK-01 v0.4.35 | Review | Parent architecture/ownership |
| BCK-02 v2.4.39 | Approved baseline + amendments | Registry/22 categories |
| BCK-03 | Draft | API/compatibility proposal |
| BCK-04 | Draft | Privacy/security proposal/blockers |
| BCK-06 v0.2 | Review | Actor/public-author identity |
| BCK-08 v0.2 | Review | Catalog identity/rating consumer |
| BCK-18 v0.2 | Review | Mobile cache/import/idempotency |
| VIS-HIST-01 v1.0 | Approved | Explicit Visit invariant |
| Current mobile | Local/mock | Migration evidence only |

Draft/Review sources are not silently promoted to Accepted authority.

## 3. Current implementation inventory

| Area | Current fact | Consequence |
|---|---|---|
| Favorites | Local display snapshot and optional target route | Exact typed mapping required |
| Visit History | Local owner-scoped v2 explicit self-report | Explicit reviewed import only |
| Visit v1 | Seeded demo intentionally ignored | Permanently non-importable |
| Reviews | Product concept; no authority/runtime | Start empty; no fixture import |
| Ratings | No authoritative aggregate | Rebuildable projection required |
| Backend/Firebase | Product runtime absent | Documentation-only status |

## 4. Mandatory BCK-02 coverage

| # | Category | BCK-12 | Result |
|---:|---|---|---|
| 1 | Outcome/non-goals | §§3–4 | Covered |
| 2 | Actors/roles/capabilities | §6 | Covered |
| 3 | Entities/value objects/states | §§7–10 | Covered |
| 4 | Commands/use cases | §11 | Covered |
| 5 | Queries/read models | §§12–13 | Covered |
| 6 | Data classification/projections | §§7, 9 | Covered |
| 7 | Ownership/single writers | §5 | Covered |
| 8 | Events/outbox/effects | §14 | Covered |
| 9 | Failure vocabulary | §14 | Covered |
| 10 | Persistence/index/transaction | §16 | Covered |
| 11 | IDs/time/revisions | §17 | Covered |
| 12 | Idempotency/concurrency/replay | §§11, 17 | Covered |
| 13 | Offline/cache/multi-device | §18 | Covered |
| 14 | Migration/cutover/compatibility | §§15, 19 | Covered |
| 15 | Security/abuse/moderation | §21 | Covered |
| 16 | Privacy/consent/retention/DSR | §20 | Covered |
| 17 | Observability/SLO/analytics/cost | §22 | Covered |
| 18 | Flags/rollout/rollback | §23 | Covered |
| 19 | Dependencies/delivery gates | §24 | Covered |
| 20 | Exact file map | §25 | Covered/conditional |
| 21 | Tests/acceptance/evidence | §§26–29 | Covered |
| 22 | Owner decisions/blockers | §31 | Covered |

## 5. Single-writer reconciliation

| Concern | Owner | BCK-12 posture |
|---|---|---|
| Favorite/Visit source | User Library | Owns |
| Review source/rating projection | Reviews | Owns |
| Catalog target/visibility | BCK-08 | Consumes |
| Identity/public author | BCK-06 | Consumes |
| Attendance proof | Booking/provider authority | Trusted input only |
| Reports/sanctions/appeals | BCK-22 | Typed integration only |
| Staff cases/repair | BCK-19 | Audited; no direct write |
| Mobile cache/import | BCK-18 | Orchestration only |

No proposed record has two writers.

## 6. Gap register

| Gap | Severity | Closure |
|---|---|---|
| Scale/lifecycle/eligibility not Accepted | Blocks Approval | OD-01/02/03 |
| Confirmed attendance source absent | Blocks feature | OD-04; disabled |
| Retention/legal basis/DSR values absent | Blocks production | OD-05 |
| Local import policy absent | Blocks migration | OD-06 |
| Rating SLO/freshness absent | Blocks exposure | OD-07 |
| Favorite scope/tombstone policy pending | Blocks broad scope | OD-08 |
| Abuse thresholds/BCK-22 runtime absent | Blocks Reviews runtime | OD-09 |
| Market/minors/incentive policy pending | Blocks sensitive paths | OD-10 |
| Contracts/Rules/indexes/backend absent | Blocks runtime | Approved slices |

## 7. Open owner decisions

The target contains `BCK12-OD-01..10`. Every decision has an owner and
fail-closed default. Review does not accept any decision automatically.

## 8. Fail-closed defaults

- no automatic local upload or passive Visit;
- no client-confirmed attendance;
- no production Reviews/ratings or public library/history;
- no title/category/route guessing during migration;
- no generic retention default or direct cross-domain/staff write;
- no automatic sanction from a score;
- no runtime/deployment inference from documentation.

## 9. Preparatory acceptance criteria

1. **BCK-12-PRE-AC-01:** All 22 categories map to target sections.
2. **BCK-12-PRE-AC-02:** Library and Reviews are separate aggregates.
3. **BCK-12-PRE-AC-03:** Every record/projection has one writer.
4. **BCK-12-PRE-AC-04:** Catalog identity remains BCK-08-owned.
5. **BCK-12-PRE-AC-05:** Public-author identity remains BCK-06-owned.
6. **BCK-12-PRE-AC-06:** Reports/enforcement cases remain BCK-22-owned.
7. **BCK-12-PRE-AC-07:** Staff cannot directly write domain records.
8. **BCK-12-PRE-AC-08:** Library is not a public profile projection.
9. **BCK-12-PRE-AC-09:** Favorites use typed ID references.
10. **BCK-12-PRE-AC-10:** VIS-HIST-01 explicit action is preserved.
11. **BCK-12-PRE-AC-11:** Place timezone defines Visit date.
12. **BCK-12-PRE-AC-12:** Self-report is not verified attendance.
13. **BCK-12-PRE-AC-13:** Review source/rating projection are separate.
14. **BCK-12-PRE-AC-14:** Rating is rebuildable/revisioned/freshness-labelled.
15. **BCK-12-PRE-AC-15:** Rating uses fixed-point arithmetic.
16. **BCK-12-PRE-AC-16:** Offline/local state is not authority.
17. **BCK-12-PRE-AC-17:** Favorite migration cannot guess identity.
18. **BCK-12-PRE-AC-18:** Visit v1 seed is non-importable.
19. **BCK-12-PRE-AC-19:** Demo review data is non-importable.
20. **BCK-12-PRE-AC-20:** Privacy/retention gaps block production.
21. **BCK-12-PRE-AC-21:** Ten decisions have fail-closed defaults.
22. **BCK-12-PRE-AC-22:** Target AC are sequential `01..60`.
23. **BCK-12-PRE-AC-23:** Runtime remains explicitly Absent.
24. **BCK-12-PRE-AC-24:** Review authorizes no Firebase/deployment.

## 10. Evidence summary

- design coverage: **22/22**;
- target AC: **60**;
- preparatory AC: **24**;
- owner decisions: **10**;
- runtime files changed: **0**;
- runtime evidence: **Absent**.

## 11. Recommendation

Register BCK-12 v0.2 as **Review / Present / runtime Absent**. Approval requires
qualified decisions and dependency verdicts. Runtime requires separately
Approved contract, backend, security, migration and rollout slices.
