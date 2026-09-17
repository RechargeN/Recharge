# BCK-01 — Architecture Reconciliation Report

- ID: **BCK-01-REV-01**
- Version: **1.24**
- Date: **2026-09-17**
- Status: **Accepted evidence for Review entry — Approval evidence pending**
- Runtime status: **N/A; documentation evidence only**
- Accountable owner: **Platform Architecture owner**
- Review coordinator: **RechargeN / Product owner**
- Subject: [BCK-01 v0.4.64](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_MASTER_RECONCILIATION_REPORT.md`

---

## 0. BCK-20 source-authority decision reconciliation

This revision records BCK20-OD02-SRC-AUTH-DEC-01 and BCK-20 v0.2.16 against
the reconciled post-RAW-C snapshot. The frozen source-authority design boundary
is accepted under six combined roles with zero independence. The BCK-01
Review-entry verdict is unchanged; actual source records, external-source
license/terms and pinned evidence, independent Security/Privacy, qualified
Legal and runtime evidence remain absent.

## 1. Verdict

BCK-01 v0.4.64 is internally consistent with the tracked Accepted ADR set,
Architecture Baseline and BCK-02 coordination model. Its module and
authoritative-writer maps do not contain a confirmed double writer. All local
anchors exist, 59 AC are sequential, and the revision creates no runtime.

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
- BCK-02 v2.4.68 registry, ownership, §14 template, §15 reconciliation, gates
  and next-package rules;
- BCK-03 v0.3.14, BCK03-OPS-DEC-01 v0.1, BCK03-SEC-DEC-01 v0.1,
  BCK03-MOB-REV-01 v0.2, BCK03-MOB-DEC-01 v0.1 and API Contracts Workflow;
- BCK-04 v0.4.23, coverage matrix v0.3.23, BCK04-SEC-REV/DEC-01,
  BCK04-OD01-TM-01 v0.2 and BCK04-OD01-REV/DEC-01,
  BCK04-OD09-IR-01 and ready-but-unexecuted BCK04-OD09-TTX-01;
- BCK-05 v0.2.30, BCK05-OD01-TCH-01 v0.3.4,
  BCK05-OD01-TCH-REV-01 v0.2, BCK-R0-TCH-01 v0.2,
  BCK-R0-TCH-DEC-01, BCK05-OD02-IAM-01,
  BCK05-OD07-REL-01,
  BCK05-OD03-SLO-01, BCK05-OD04-COST-01 v0.2, BCK05-OD05-REC-01,
  BCK05-NUM-REV-01 v0.2 and BCK-20 v0.2.16 plus their
  coverage matrices;
- BCK-09 v1.13, ECL-03 v1.3/ECL-03C v1.11, RAW-C v0.3,
  BCK-D1-DEC-01 v0.14, BCK-D1-OWN-A-DEC-01 v0.1, BCK20-OWN-DEC-01 v0.1,
  BCK20-OD02-DEC-01 v0.1 and BCK20-OD02-PC-COMB-DEC-01 v0.1;
- BCK-D1-REV-01 v1.28, BCK-D1-SIG-01 v1.26,
  BCK-D1-OWN-REV-01 v1.24, BCK-D1-OWN-A-DEC-01 v0.1 and OD-07/09/10/11
  review evidence packages;
- BCK-02-A1 v1.12 Draft Latvia/Baltics roadmap;
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
| BCK-02 | Approved v2.4 semantics; v2.4.68 traceability | Coordination authority only | Pass |
| BCK-02-A1 | Draft v1.12, documentation only | Baltic rollout input, not Accepted authority | Pass |
| BCK-03 | Draft v0.3.14; API/Operations/Security/Mobile boundary reviews Accept with required amendments; deployed/mobile API runtime Absent | Independent evidence Pending | Pass with blockers |
| BCK-04 | Draft v0.4.23; BCK-04 and threat-model combined-owner technical verdicts recorded; product/cloud runtime Absent | BCK04-OD-01 remains Proposed pending independent/cross-boundary evidence; qualified Legal, OD-09 and tabletop remain | Pass with blockers |
| BCK-05 | Draft v0.2.30; bounded R0/RAW-C local evidence boundary, product/cloud runtime Absent | BCK-03/BCK-04/threat-model owner-boundary evidence recorded; full BCK-05 specialist/stage/executable evidence remains | Pass with blockers |
| BCK-09 | Review v1.13; disabled RAW-C v0.3 Present, cloud/mobile runtime Absent | Booking rules and bounded local/hosted behavior reconciled; nine independent signatures Pending | Pass with blockers |
| BCK-20 | Draft v0.2.16, runtime Absent | source-authority design boundary accepted with zero independence; actual source records, external evidence, independent Security/Privacy and qualified Legal evidence pending; OD-10 Proposed, BCK20-OD-02/05 Open | Pass with blockers |
| Firebase Architecture | Proposed | Infrastructure input only | Pass |
| `apps/backend` | Bounded R0 plus disabled Emulator-only RAW-C source Present | Separate approvals only; no G1/G4/R1/cloud/mobile authority | Pass with blockers |

## 6. Findings retained and resolved through v0.4.61

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
| BCK01-F12 | BCK04-OD-01 had only a partial trust-boundary sketch | BCK04-OD01-TM-01 v0.2 adds stable assets/actors, 12 trust boundaries, 49 classified threats, per-threat owners/gates/residual state and checksum; combined-owner technical verdict is Present, OD remains Proposed |
| BCK01-F13 | Security/privacy incident handling had no unified severity, GDPR-risk and response contract | BCK04-OD09-IR-01 preserves the existing SEV-1/2/3 scale, separates operational severity from personal-data-breach risk, and defines 25 AC; BCK04-OD-09/BCK05-OD-08 are Proposed pending owner, Legal and tabletop evidence |
| BCK01-F14 | Incident-model acceptance required a tabletop, but no repeatable scenario, evaluator key or honest result record existed | BCK04-OD09-TTX-01 supplies a ready exercise package with 30 AC; execution/result fields remain blank, so no gate or decision is promoted |
| BCK01-F15 | BCK05-OD-04 required numeric budgets, but no workload formula, directional estimate, EUR thresholds or safe containment contract existed | BCK05-OD04-COST-01 adds dated sources, five envelopes, formulas, estimates, EUR guardrails and 40 AC; OD-04 is Proposed, not Accepted |
| BCK01-F16 | BCK05-OD-03 required numeric SLO/error budgets but only structural service classes existed | BCK05-OD03-SLO-01 adds journey-scoped SLIs/SLOs, denominator rules, burn alerts, zero-tolerance invariants and release policy; OD-03 is Proposed, not Accepted |
| BCK01-F17 | BCK05-OD-05 required record-family RPO/RTO and restore design but only generic recovery prose existed | BCK05-OD05-REC-01 adds numerical targets, candidate protection policy, isolated restore, privacy re-deletion, reconciliation and drills; OD-05 is Proposed, not Accepted |
| BCK01-F18 | Cost v0.1 retained four backup copies while recovery v0.1 proposed 26 prod copies | Cost v0.2 and BCK05-NUM-REV-01 reconcile full-size equivalents, correct S/L1/L2/L3 estimates and expose the L3 guardrail conflict; no status is promoted |
| BCK01-F19 | Numerical models had a technical recommendation but no owner disposition | BCK05-NUM-REV-01 v0.2 and BCK-D1-SIG-01 v1.0 record the Product stage-validation baseline, evidence-conditioned Operations/Security perspectives and Inconclusive Finance/Legal scopes; OD/BCK/runtime statuses remain unchanged |
| BCK01-F20 | BCK05-OD-02 named workload identity/approval/break-glass but had no concrete trust, identity or permission model | BCK05-OD02-IAM-01 v0.2.1 defines keyless OIDC/WIF, immutable claims, environment/task separation, intended permissions, lifecycle, break-glass and 50 AC; OD-02 is Accepted with controls, while executable IAM remains absent |
| BCK01-F21 | BCK05-OD-07 named signing/provenance/promotion/rollback but did not distinguish direct OCI from provider-built Functions | BCK05-OD07-REL-01 v0.2.1 separates manifest/plan/provider receipt/promotion record, selects dual provenance and keeps Functions outside any universal Binary Authorization claim; OD-07 is Accepted with controls while executable evidence remains absent |
| BCK01-F22 | BCK05-OD-01 left the backend runtime, compiler, package manager and IaC/deploy ownership unspecified | BCK05-OD01-TCH-01 selects a dated Node.js 22/TypeScript/npm/Firebase CLI/Terraform candidate; BCK-R0-TCH-01 adds a deterministic R0 contract and 60 AC; OD-01 is Proposed, not Accepted |
| BCK01-F23 | The toolchain candidate lacked an exact minimal SDK/lint/JDK package disposition and bounded executable feasibility plan | BCK05-OD01-TCH-REV-01 records a non-owner technical Pass with blockers and BCK-R0-TCH-01 defines an exhaustive local-only file/command/evidence boundary; R0 remains Review/not Approved |
| BCK01-F24 | R0 required full-SHA Actions but did not resolve exact identities, runner inputs or the unsigned Terraform Action risk | Toolchain v0.3/R0 v0.2 pin three verified Action commits, reject the unsigned Terraform Action, fix signed Terraform archive checksums and add BCK-R0-TCH-DEC-01; all verdicts remain Pending |
| BCK01-F25 | Post-RAW-C platform documents pointed to incompatible parent and coordination snapshots | D1-B reconciles BCK-03/04/05/20, their matrices and the D1 review/sign-off chain to BCK-01 v0.4.51/BCK-02 v2.4.55 without status promotion |
| BCK01-F26 | Review evidence still described `apps/backend` as physically absent | Current evidence separates bounded R0/disabled RAW-C source from absent product/cloud deployment, activation and mobile integration |
| BCK01-F27 | Owner Batch A could appear to demote Accepted Booking-v1 API-DEC-01/03 | BCK-D1-OWN-A-DEC-01 defers only their broader platform scope and preserves the accepted Booking-v1 decisions |
| BCK01-F28 | A bounded BCK-03 Operations verdict could be read as BCK-05 or runtime approval | BCK03-OPS-DEC-01 explicitly limits the verdict to the API boundary and preserves BCK-05/D1/G1/runtime blockers |
| BCK01-F29 | Idempotent replay could disclose a protected historic result after current access was revoked | BCK03-SEC-DEC-01 requires current disclosure authorization without re-executing the committed mutation and preserves anti-enumerating failure behavior |
| BCK01-F30 | Query retry identity and Mobile v3.1 AC-42 could reuse one attempt request ID or conflate transport cancellation with a server result | BCK03-MOB-DEC-01 and Mobile Architecture v3.1.1 require a fresh request ID per attempt, stable logical idempotency identity and typed cancellation/unknown-outcome separation |
| BCK01-F31 | BCK-04 DSR flow reused attempt request ID as logical and persistent request identity and its AC-06 retained a resolved contradiction | BCK04-SEC-DEC-01/BCK-04 v0.4.23 separate requestId, idempotencyKey and privacyRequestId and add current-read/export/restore safeguards without accepting Legal/OD/runtime gates |
| BCK01-F32 | Threat-model v0.1 declared classification but omitted category, per-threat owner, evidence state and residual disposition fields | BCK04-OD01-DEC-01 and v0.2 integrate the twenty amendments; independent Security/Privacy and cross-boundary evidence still block OD-01 Acceptance |
| BCK01-F33 | BCK-20 carried seven Open decisions despite five depending on later executable/market evidence | BCK20-OWN-DEC-01 defers OD-01/03/04/06/07 with exact fail-closed gates, retains OD-02/05 Open, OD-10 Proposed and BCK-20 Draft |
| BCK01-F34 | Translation governance lacked exact approval freshness, atomic publication, exception, safe rollback and retention/deletion controls | BCK20-OD02-DEC-01 records the bounded technical verdict and workflow v0.2 integrates sixteen amendments while OD-02 and specialist/Legal/runtime gates stay open |
| BCK01-F35 | Product/Content pre-review found incomplete source authority, publication-outcome, revocation, correction-target, impact, approval-authority, exception-closure and locale-normalization semantics | BCK20-OD02-PC-PRE-DEC-01 integrates F-001–F-008 in workflow v0.3, re-freezes specialist review and leaves OD-02 Open, OD-10 Proposed, BCK-20 Draft and all specialist/Legal/runtime gates closed |
| BCK01-F36 | The two-person team required attributable Product Localization and Content verdicts without fabricating independent specialists | BCK20-OD02-PC-COMB-DEC-01 records two separate combined-owner verdicts, discloses zero independence and preserves Mobile/Security/Privacy/Legal/source-authority/runtime gates |
| BCK01-F37 | Mobile/Security pre-review found unresolved consumer compatibility, atomic install, monotonic invalidation, actor-authority, inventory, origin-authentication and safe-render boundaries | BCK20-OD02-MS-PRE-DEC-01 integrates MS-F-001–MS-F-007 in workflow v0.4, re-freezes exact-hash reviews and preserves every source-authority/provider/schema/runtime gate |
| BCK01-F38 | Four exact-v0.4 design perspectives required attributable disposition without implying independence or professional qualification | BCK20-OD02-V04-COMB-DEC-01 records four separate verdict IDs under one disclosed owner with zero independence and preserves source-authority, independent Security/Privacy, qualified Legal and every implementation gate |
| BCK01-F39 | Source-authority assignments required bounded acceptance without treating official registries as licensed executable sources or closing unresolved records | BCK20-OD02-SRC-AUTH-DEC-01 accepts only the frozen design boundary, discloses six combined roles and retains source/license/pin/independent/Legal/runtime gates |

## 7. Definition of Ready evidence

| BCK-01 §25 condition | Evidence | State |
|---|---|---|
| Anchors exist and links are valid | Automated local-link audit | Pass |
| BCK-02 reflects BCK-01 status | Registry: Review v0.4.64/Present; bounded local source separated from product/cloud runtime Absent | Pass |
| No double writer | §4 writer reconciliation | Pass |
| LV/EE/LT agrees with roadmap | Latvia first; EE/LT independently disabled | Pass |
| Open decisions are not called Accepted | §5 status table and BCK-02 OD registry | Pass |
| Review owners appointed | RechargeN / Product owner accepted interim combined coordination on 2026-08-20 | Pass for Review entry |
| Conflicts recorded | Booking idempotency closed by BCK-D1-DEC-01; remaining BCK-04/05/20 blockers linked | Pass |
| Diff is documentation-only | Git scope + boundary/diff evidence | Pass |
| Product/cloud runtime remains Absent | Bounded R0/RAW-C source only; no cloud project, deployment, activation or mobile integration | Pass |

## 8. Recorded owner confirmation

Product owner instruction dated 2026-08-20 assigns `RechargeN / Product owner`
as combined accountable owner for the following review perspectives. Assignment
does not supply a verdict or independent review:

| Review perspective | Required acknowledgement | Current evidence |
|---|---|---|
| Platform Architecture | Owns BCK-01 target and reconciliation | Assigned; BCK-01 Review entry already recorded |
| API Platform | Accepts delegation to BCK-03 | Combined-owner verdict: Accept with required amendments; independent evidence and peer boundaries Pending |
| Security/Privacy | Accepts bounded technical BCK-03/BCK-04 boundaries | Combined-owner verdicts recorded; BCK-04 remains Draft pending independent, qualified Legal, BCK04-OD-01/09 and tabletop evidence |
| Legal/Privacy | Reviews legal conclusions and market obligations | Numeric scope Inconclusive; qualification not evidenced |
| Platform Operations | Accepts BCK-03 operations boundary and BCK-05 ownership/G1 dependency | BCK-03 boundary Accept with required amendments; BCK-05 specialist/stage/restore evidence Pending |
| Reference Data / Localization | Accepts BCK-20 and OD-10 boundaries | Translation-governance technical verdict recorded; named specialist verdicts Pending |
| Identity / Mobile / domain owners | Confirm delegated boundaries | Assigned; verdicts Pending |

This combined assignment is a repository-owned Review-entry record. Before
`Approved`/G1, Security/Privacy, Legal and Operations decisions that require
specialist evidence remain independently gated by BCK-04/BCK-05 and OD-07/11.

## 9. Review verdict and next action

**Verdict: Review entry accepted; Approval blocked.** BCK-01 v0.4.64 remains
tracked as `Review`. Next:

1. obtain delegated-owner evidence for BCK-03 Review;
2. close remaining BCK-04/BCK-05/BCK-20 specialist and OD blockers;
3. assign real reviewers and complete BCK-D1-SIG-01 without fabricated verdicts;
4. complete final D1 conflict/sign-off report after the required decisions;
5. keep G1, provisioning and runtime unauthorized.
