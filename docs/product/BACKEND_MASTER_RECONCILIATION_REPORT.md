# BCK-01 — Architecture Reconciliation Report

- ID: **BCK-01-REV-01**
- Version: **1.8**
- Date: **2026-08-23**
- Status: **Accepted evidence for Review entry — Approval evidence pending**
- Runtime status: **N/A; documentation evidence only**
- Accountable owner: **Platform Architecture owner**
- Review coordinator: **RechargeN / Product owner**
- Subject: [BCK-01 v0.4.17](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.21](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_MASTER_RECONCILIATION_REPORT.md`

---

## 1. Verdict

BCK-01 v0.4.17 is internally consistent with the tracked Accepted ADR set,
Architecture Baseline and BCK-02 coordination model. Its module and
authoritative-writer maps do not contain a confirmed double writer. All local
anchors exist, 52 AC are sequential, and the revision creates no runtime.

The Product owner assigned `RechargeN / Product owner` as interim review
coordinator across all perspectives required by `BCK-01 §25`. This closes the
procedural blocker for entry into `Review`; it does not constitute independent
specialist approval and cannot authorize BCK-01 Approval, G1, provisioning or
runtime.

## 2. Evidence scope

This audit read the following tracked sources in full or at their applicable
normative sections:

- `AGENTS.md` and `docs/architecture/ARCHITECTURE_BASELINE.md`;
- Accepted ADR 0012, 0013, 0015, 0016, 0017, 0018 and 0019;
- BCK-02 v2.4.21 registry, ownership, §14 template, §15 reconciliation, gates
  and next-package rules;
- BCK-03 v0.3.3 and API Contracts Workflow;
- BCK-04 v0.4.10, coverage matrix v0.3.10, BCK04-OD01-TM-01,
  BCK04-OD09-IR-01 and ready-but-unexecuted BCK04-OD09-TTX-01;
- BCK-05 v0.2.12, BCK05-OD01-TCH-01 v0.3,
  BCK05-OD01-TCH-REV-01 v0.2, BCK-R0-TCH-01 v0.2,
  BCK-R0-TCH-DEC-01, BCK05-OD02-IAM-01,
  BCK05-OD07-REL-01,
  BCK05-OD03-SLO-01, BCK05-OD04-COST-01 v0.2, BCK05-OD05-REC-01,
  BCK05-NUM-REV-01 v0.2 and BCK-20 v0.2.2 plus their
  coverage matrices;
- BCK-09 v1.1, ECL-03 v1.2/ECL-03C v1.1 and BCK-D1-DEC-01;
- BCK-D1-REV-01, BCK-D1-SIG-01 and OD-07/09/10/11 review evidence packages;
- BCK-02-A1 v1.0 Draft Latvia/Baltics roadmap;
- LAUNCH_STATUS current tracked facts.

No source status is raised by citation. Draft/Review/Proposed inputs remain
non-Accepted, and `Present` remains distinct from runtime implementation.

## 3. BCK-02 §14 coverage

| № | Mandatory BCK section | BCK-01 evidence | Verdict |
|---:|---|---|---|
| 1 | ID/version/date/status/runtime/owner | Header | Covered |
| 2 | Parent sources and conflict priority | §3, §3.1 | Covered |
| 3 | Product outcome and measurable non-goals | §1–2, §5.2 | Covered |
| 4 | Included/excluded scope | §5 | Covered |
| 5 | Aggregate/writer/consumer ownership | §8–9 | Covered |
| 6 | Data classification and projections | §12 | Covered |
| 7 | Commands/queries/events/errors | §10 | Covered |
| 8 | Versions/evolution/minimum client | §10.5, §17 | Covered; domain schemas conditional on API-DEC-05 |
| 9 | Authorization/revocation | §13, §13.1 | Covered |
| 10 | Persistence/index/transaction boundaries | §14 | Covered |
| 11 | IDs/references/time/reference data | §11 | Covered |
| 12 | Idempotency/concurrency/retry/partial failure | §10, §14–16 | Covered at master level |
| 13 | Offline/cache/freshness/degraded state | §15 | Covered |
| 14 | Migration/import/compatibility | §16 | Covered |
| 15 | Outbox/delivery/replay/dedupe | §10.3 | Covered; OD-09 remains gated |
| 16 | Privacy/consent/retention/rights | §12–13, delegated to BCK-04 | Covered by boundary |
| 17 | Abuse/rate/App Check/fraud | §13 | Covered by baseline |
| 18 | Logs/SLO/analytics/cost | §18–19 | Covered by ownership boundary |
| 19 | Flags/rollout/rollback/emergency disable | §18, §22 | Covered |
| 20 | Exact implementation map | §17 | Covered as target plan only |
| 21 | Test/evidence matrix | §19 | Covered |
| 22 | AC/DoR/DoD/unimplemented list | §24–27 | Covered; 52 sequential AC |

Coverage is structural design evidence, not proof of an implemented backend.

## 4. Authority and writer reconciliation

| Record family | BCK-01 writer | BCK-02 owner | Peer-spec check | Result |
|---|---|---|---|---|
| Identity/access/page membership | Identity | BCK-06 | ADR 0015 consistent | One writer |
| Reference revisions | Reference Data | BCK-20 | BCK-20 Draft/Present; runtime Absent | One writer |
| Content lifecycle | Content Publication | BCK-07 | Discover consumes projections | One writer |
| Catalog/feed/map/search | Discover | BCK-08 | No source mutation authority | One writer |
| Booking/hold/ledger/audit | Booking | BCK-09 | ADR 0019/BCK-09 consistent | One writer |
| Provider availability | Provider Integration | BCK-16 | Separate from Booking/public composition | One writer |
| Privacy request/task/status | Privacy Orchestration | BCK-04 | Domain handlers retain domain records | One writer |
| Server flags/operational telemetry | Platform Operations | BCK-05 | BCK-05 Draft/Present; runtime Absent | One writer |
| Product analytics | Analytics | BCK-21 | Separate from operational telemetry | One writer |
| Payments | Payments, conditional | BCK-17 | No authority until new Accepted ADR | Fail-closed |

No consumer is granted write authority by this report. Exact record families
must be repeated and refined by their owning BCK spec before schema approval.

## 5. Anchor and status reconciliation

| Anchor | Repository fact | BCK-01 treatment | Result |
|---|---|---|---|
| BCK-02 | Approved v2.4 semantics; v2.4.21 traceability | Coordination authority only | Pass |
| BCK-02-A1 | Draft v1.0, documentation only | Baltic rollout input, not Accepted authority | Pass |
| BCK-03 | Draft v0.3.3, runtime Absent | Combined owner assigned; verdicts remain Pending | Pass with blockers |
| BCK-04 | Draft v0.4.10, runtime Absent | Threat/incident models and tabletop package Present; owner/independent/Legal verdicts and executed result remain | Pass with blockers |
| BCK-05 | Draft v0.2.12, runtime Absent | Full-SHA toolchain technical review, exact R0 plan and decision record are Present but unapproved; OD-01/02/03/04/05/07/08 remain Proposed; compatibility, owner/security, specialist, stage/restore and executable evidence remain | Pass with blockers |
| BCK-09 | Review v1.1, runtime Absent | Booking rules reconciled with fixtures | Pass |
| BCK-20 | Draft v0.2.2, runtime Absent | Combined owner assigned; OD-10 verdicts/executable parity absent | Pass with blockers |
| Firebase Architecture | Proposed | Infrastructure input only | Pass |
| `apps/backend` | Physically absent | Target plan only | Pass |

## 6. Findings resolved through v0.4.16

| ID | Finding | Resolution |
|---|---|---|
| BCK01-F01 | §4 snapshot still described BCK-03/BCK-04 as absent | Updated to exact Draft/Present/runtime Absent facts |
| BCK01-F02 | §17 could be read as authorizing all domain JSON schemas | Non-Booking paths made conditional on Accepted API-DEC-05 |
| BCK01-F03 | §28 asked to create BCK-03/BCK-04 after they already existed | Replaced by the actual Review and D1 completion sequence |
| BCK01-F04 | BCK-02/BCK-03/BCK-04 version traceability had drifted | Reconciled through documentation-only patch revisions |
| BCK01-F05 | BCK-05/BCK-20 were Planned/Absent | Added Draft specs and coverage matrices; runtime remains Absent |
| BCK01-F06 | Booking target required key equality while committed fixtures used distinct values | BCK-D1-DEC-01/ECL03-D11 accepts separate request correlation and logical idempotency identity; no wire migration |
| BCK01-F07 | ECL03-D04 was simultaneously described as Accepted and Open | v1.2 fixes Accepted product policy plus separate Privacy/Legal activation validation |
| BCK01-F08 | BCK-03 D1 readiness depended on the later D2 BCK-18 file | Replaced with a named Mobile Platform boundary review; BCK-18 remains D2 |
| BCK01-F09 | OD-07 demanded cloud measurements before provisioning was allowed | Separated pre-decision models/thresholds from post-provision synthetic validation before traffic |
| BCK01-F10 | Document presence and specialist acceptance had no single audit ledger | BCK-D1-SIG-01 separates assignment, bounded disposition, specialist verdict and signature; most D1 role scopes remain incomplete |
| BCK01-F11 | D1 roles had no accountable named identity | Product owner explicitly assigned `RechargeN / Product owner` to all roles; self-review risk is disclosed and no independent specialist verdict is inferred |
| BCK01-F12 | BCK04-OD-01 had only a partial trust-boundary sketch | BCK04-OD01-TM-01 adds assets, actors, 12 trust boundaries, 36 threats, controls, evidence gates and residual risks; status is Proposed, not Accepted |
| BCK01-F13 | Security/privacy incident handling had no unified severity, GDPR-risk and response contract | BCK04-OD09-IR-01 preserves the existing SEV-1/2/3 scale, separates operational severity from personal-data-breach risk, and defines 25 AC; BCK04-OD-09/BCK05-OD-08 are Proposed pending owner, Legal and tabletop evidence |
| BCK01-F14 | Incident-model acceptance required a tabletop, but no repeatable scenario, evaluator key or honest result record existed | BCK04-OD09-TTX-01 supplies a ready exercise package with 30 AC; execution/result fields remain blank, so no gate or decision is promoted |
| BCK01-F15 | BCK05-OD-04 required numeric budgets, but no workload formula, directional estimate, EUR thresholds or safe containment contract existed | BCK05-OD04-COST-01 adds dated sources, five envelopes, formulas, estimates, EUR guardrails and 40 AC; OD-04 is Proposed, not Accepted |
| BCK01-F16 | BCK05-OD-03 required numeric SLO/error budgets but only structural service classes existed | BCK05-OD03-SLO-01 adds journey-scoped SLIs/SLOs, denominator rules, burn alerts, zero-tolerance invariants and release policy; OD-03 is Proposed, not Accepted |
| BCK01-F17 | BCK05-OD-05 required record-family RPO/RTO and restore design but only generic recovery prose existed | BCK05-OD05-REC-01 adds numerical targets, candidate protection policy, isolated restore, privacy re-deletion, reconciliation and drills; OD-05 is Proposed, not Accepted |
| BCK01-F18 | Cost v0.1 retained four backup copies while recovery v0.1 proposed 26 prod copies | Cost v0.2 and BCK05-NUM-REV-01 reconcile full-size equivalents, correct S/L1/L2/L3 estimates and expose the L3 guardrail conflict; no status is promoted |
| BCK01-F19 | Numerical models had a technical recommendation but no owner disposition | BCK05-NUM-REV-01 v0.2 and BCK-D1-SIG-01 v1.0 record the Product stage-validation baseline, evidence-conditioned Operations/Security perspectives and Inconclusive Finance/Legal scopes; OD/BCK/runtime statuses remain unchanged |
| BCK01-F20 | BCK05-OD-02 named workload identity/approval/break-glass but had no concrete trust, identity or permission model | BCK05-OD02-IAM-01 defines keyless OIDC/WIF, immutable claims, environment/task separation, intended permissions, lifecycle, break-glass and 50 AC; OD-02 is Proposed, not Accepted |
| BCK01-F21 | BCK05-OD-07 named signing/provenance/promotion/rollback but did not distinguish direct OCI from provider-built Functions | BCK05-OD07-REL-01 defines the immutable manifest/state machine and honest source-bundle-to-provider-revision evidence; OD-07 is Proposed and no universal Functions Binary Authorization claim is made |
| BCK01-F22 | BCK05-OD-01 left the backend runtime, compiler, package manager and IaC/deploy ownership unspecified | BCK05-OD01-TCH-01 selects a dated Node.js 22/TypeScript/npm/Firebase CLI/Terraform candidate; BCK-R0-TCH-01 adds a deterministic R0 contract and 60 AC; OD-01 is Proposed, not Accepted |
| BCK01-F23 | The toolchain candidate lacked an exact minimal SDK/lint/JDK package disposition and bounded executable feasibility plan | BCK05-OD01-TCH-REV-01 records a non-owner technical Pass with blockers and BCK-R0-TCH-01 defines an exhaustive local-only file/command/evidence boundary; R0 remains Review/not Approved |
| BCK01-F24 | R0 required full-SHA Actions but did not resolve exact identities, runner inputs or the unsigned Terraform Action risk | Toolchain v0.3/R0 v0.2 pin three verified Action commits, reject the unsigned Terraform Action, fix signed Terraform archive checksums and add BCK-R0-TCH-DEC-01; all verdicts remain Pending |

## 7. Definition of Ready evidence

| BCK-01 §25 condition | Evidence | State |
|---|---|---|
| Anchors exist and links are valid | Automated local-link audit | Pass |
| BCK-02 reflects BCK-01 status | Registry: Review v0.4.17/Present, runtime Absent | Pass |
| No double writer | §4 writer reconciliation | Pass |
| LV/EE/LT agrees with roadmap | Latvia first; EE/LT independently disabled | Pass |
| Open decisions are not called Accepted | §5 status table and BCK-02 OD registry | Pass |
| Review owners appointed | RechargeN / Product owner accepted interim combined coordination on 2026-08-20 | Pass for Review entry |
| Conflicts recorded | Booking idempotency closed by BCK-D1-DEC-01; remaining BCK-04/05/20 blockers linked | Pass |
| Diff is documentation-only | Git scope + boundary/diff evidence | Pass |
| Runtime remains Absent | No `apps/backend`/Firebase/runtime files | Pass |

## 8. Recorded owner confirmation

Product owner instruction dated 2026-08-20 assigns `RechargeN / Product owner`
as combined accountable owner for the following review perspectives. Assignment
does not supply a verdict or independent review:

| Review perspective | Required acknowledgement | Current evidence |
|---|---|---|
| Platform Architecture | Owns BCK-01 target and reconciliation | Assigned; BCK-01 Review entry already recorded |
| API Platform | Accepts delegation to BCK-03 | Assigned; verdict Pending |
| Security/Privacy | Accepts delegation to BCK-04 | Numeric perspective accepted only with required IAM/privacy-resurrection evidence; broader/independent verdict Pending |
| Legal/Privacy | Reviews legal conclusions and market obligations | Numeric scope Inconclusive; qualification not evidenced |
| Platform Operations | Accepts BCK-05 ownership and G1 dependency | Numeric perspective accepted with required stage/restore evidence; broader specialist verdict Pending |
| Reference Data / Localization | Accepts BCK-20 and OD-10 boundaries | Assigned; verdicts Pending |
| Identity / Mobile / domain owners | Confirm delegated boundaries | Assigned; verdicts Pending |

This combined assignment is a repository-owned Review-entry record. Before
`Approved`/G1, Security/Privacy, Legal and Operations decisions that require
specialist evidence remain independently gated by BCK-04/BCK-05 and OD-07/11.

## 9. Review verdict and next action

**Verdict: Review entry accepted; Approval blocked.** BCK-01 v0.4.17 may be
tracked as `Review`. Next:

1. obtain delegated-owner evidence for BCK-03 Review;
2. close remaining BCK-04/BCK-05/BCK-20 specialist and OD blockers;
3. assign real reviewers and complete BCK-D1-SIG-01 without fabricated verdicts;
4. complete final D1 conflict/sign-off report after the required decisions;
5. keep G1, provisioning and runtime unauthorized.
