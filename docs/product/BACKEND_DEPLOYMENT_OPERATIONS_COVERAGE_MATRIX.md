# BCK-05 — Deployment & Operations Coverage Matrix

- ID: **BCK-05-PRE**
- Version: **0.2.14**
- Date: **2026-08-24**
- Status: **Draft — preparatory audit artifact**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Platform Operations owner**
- Target: [BCK-05 v0.2.14](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.23](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_DEPLOYMENT_OPERATIONS_COVERAGE_MATRIX.md`

## 1. Purpose

This matrix proves structural completeness and identifies exact blockers. It is
not a second operations standard and does not accept OD-07, provision Firebase,
select credentials, create runtime files or authorize production processing.

## 2. Source reconciliation

| Source | Tracked status | Treatment |
|---|---|---|
| Accepted ADR / Architecture Baseline | Accepted/Frozen | Cannot be weakened |
| BCK-01 v0.4.19 | Review; local R0 scaffold Present, product/cloud runtime Absent | Parent architecture |
| BCK-02 v2.4.23 | Approved semantic baseline | Registry/gates/template |
| BCK-03 v0.3.3 | Draft; runtime Absent | API/event input; split-key conflict closed, not Approved |
| BCK-04 v0.4.10 | Draft; runtime Absent; OD-01/09 Proposed | Security/privacy input, not Accepted |
| BCK-20 v0.2.2 | Draft; runtime Absent | Market/reference revision input, not Accepted |
| BCK-02-A1 v1.0 | Draft; docs only | Latvia/Baltics execution input |
| Firebase Architecture v2.2 | Proposed | Candidate topology only |
| ENV/CI policies | Accepted repository policy | Mandatory environment/CI constraints |
| BCK-05 v0.2.14 | Draft; local R0 scaffold Present, product/cloud runtime Absent; OD-01/02/03/04/05/07/08 Proposed | Single target operations standard; bounded R0 is Approved and locally/hosted executed, Windows/Linux parity is Pass, while Moderate-advisory disposition, specialist evidence and every cloud/product gate remain pending |

## 3. Coverage — BCK-02 §14

| # | Requirement | Coverage | Evidence/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Full | Header |
| 2 | Parents/priority | Full | §2 |
| 3 | Outcome/non-goals | Full | §3 |
| 4 | Scope | Full | §5 |
| 5 | Ownership | Full | §6 |
| 6 | Data classes/projections | Full at design level | §7 |
| 7 | Commands/queries/events/errors | Full at semantic level | §8; BCK-03 Draft blocker |
| 8 | Versions/evolution/client | Full | §9 |
| 9 | AuthZ/revocation | Full at target level | §10 plus BCK05-OD02-IAM-01; exact claims/roles/runtime evidence pending |
| 10 | Persistence/transactions | Full boundary | §11; runtime absent |
| 11 | IDs/time/reference | Full | §12 |
| 12 | Idempotency/concurrency/failure | Full | §13 |
| 13 | Offline/cache/degraded | Full | §14 |
| 14 | Migration/compatibility | Full | §15 |
| 15 | Outbox/replay/dedupe | Full boundary | §16; OD-09 blocker |
| 16 | Privacy/retention/Legal | Full boundary | §17; BCK-04/OD-07 blocker |
| 17 | Abuse/rate/App Check/fraud | Full | §18 |
| 18 | Logs/SLO/alerts/analytics/cost | Full structure | §19–21; numeric SLO/cost proposals Present; verdict/runtime evidence absent |
| 19 | Flags/rollout/rollback | Full | §22–23 |
| 20 | Exact file map | Full conditional plan | §24; no runtime claim |
| 21 | Test matrix | Full | §25 |
| 22 | AC/DoR/DoD/unimplemented | Full | §27–30; 50 AC |

**Coverage verdict: 22/22 addressed; Approval readiness not claimed.**

## 4. Single-writer reconciliation

| Family | Writer | Forbidden overlap |
|---|---|---|
| Environment/resource registry | Platform Operations | Domain modules/Flutter |
| Release/promotion/rollback evidence | Release Operations | Domain writers |
| Server flag policy/effective revision | Platform Operations | Client Remote Config |
| Operational telemetry/SLO/budgets | Platform Operations | BCK-21 product analytics |
| Backup/restore evidence | Platform Operations | Domain repair authority |
| Domain data/audit | Owning BCK domain | BCK-05 direct write |
| Reference revisions | BCK-20 | Environment config |

No double writer is introduced at design level.

## 5. OD-07 reconciliation contract

Candidate values in BCK-05 are Proposed, not Accepted. Before acceptance:

The review comparison, official source snapshot and exact evidence/signature
contract are in
[BCK-D1-OD07-EV-01](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md).

1. compare Standard vs Enterprise edition against actual query/cost needs;
2. verify exact Firestore, Storage, Functions and other resource locations;
3. record dated published/modelled Latvia/Baltics latency, residency,
   processor/transfer and egress facts plus predeclared validation thresholds;
4. document immutable/migration-sensitive choices and export/rollback path;
5. confirm dev/stage/prod isolation and billing ownership;
6. obtain Platform Operations and Security/Privacy specialist approvals;
7. update BCK-02 OD-07 atomically with decision evidence.

## 6. Review blockers

| ID | Blocker | Owner | Exit evidence |
|---|---|---|---|
| BCK05-PRE-01 | Combined-owner numeric disposition recorded; full D1-SIG-OPS scope and independent evidence remain incomplete | Assigned owner | Completed D1-SIG-OPS review record in [BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md) |
| BCK05-PRE-02 | BCK-03/BCK-04 remain Draft | API + Security/Privacy | Accepted/reconciled boundaries or explicit Review-safe treatment |
| BCK05-PRE-03 | OD-07 only Proposed | Platform + Security/Privacy | Evidence-backed Accepted record |
| BCK05-PRE-04 | Product baseline for numeric SLO/error budgets recorded; Operations/domain specialist verdict, stage telemetry and executable alerts absent | Operations + domains | Accepted [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) exact-version specialist review record plus stage evidence |
| BCK05-PRE-05 | Product baseline for corrected cost model recorded; Finance remains Inconclusive and EUR SKU/stage reconciliation is absent | Product + Finance/Operations | Accepted [BCK05-OD04-COST-01 v0.2](BACKEND_INFRASTRUCTURE_COST_MODEL.md) specialist review record plus EUR evidence |
| BCK05-PRE-06 | Product baseline for recovery targets recorded; Privacy/domain/Operations verdict, representative restore drill and executable protection absent | Platform + Privacy + domains | Accepted [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) specialist review record plus restore evidence |
| BCK05-PRE-07 | Runtime/toolchain, IAM/release OD-01/02/07 and OD-08 incident package are Proposed; BCK-R0-TCH-01 is Review/not Approved, BCK-R0-TCH-DEC-01 verdicts are Pending and no compatibility/executed/runtime evidence exists | Applicable owners | Completed [BCK-R0-TCH-DEC-01](BACKEND_R0_APPROVAL_DECISION_RECORD.md), Approved/executed R0 evidence, Accepted BCK05-OD-01/02/07 decisions, incident review and completed [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) record |
| BCK05-PRE-08 | OD-09 transport/effects contract unresolved | API + Operations | Minimum Proposed for D1; Accepted before effects |

## 7. Structural checks

1. All local links resolve.
2. 22/22 mandatory sections have evidence.
3. `BCK-05-AC-01…50` are unique and sequential.
4. All Open Decisions have owner and blocking gate.
5. Candidate resource names/locations are visibly Proposed.
6. Runtime remains Absent and future paths are conditional.
7. Operational monitoring and product analytics stay separate.
8. Environment and market are not conflated.
9. `git diff --check` and boundary gate pass.

## 8. Verdict

BCK-05 v0.2.14 is structurally complete enough for specialist review preparation.
It remains Draft until §6 blockers are addressed. No project, resource,
credential, deployment, backup or runtime is authorized.
