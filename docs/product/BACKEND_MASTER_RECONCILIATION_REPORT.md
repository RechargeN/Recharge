# BCK-01 — Architecture Reconciliation Report

- ID: **BCK-01-REV-01**
- Version: **0.1**
- Date: **2026-08-20**
- Status: **Draft review evidence — owner confirmation required**
- Runtime status: **N/A; documentation evidence only**
- Accountable owner: **Platform Architecture owner**
- Subject: [BCK-01 v0.4.1](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.4](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_MASTER_RECONCILIATION_REPORT.md`

---

## 1. Verdict

BCK-01 v0.4.1 is internally consistent with the tracked Accepted ADR set,
Architecture Baseline and BCK-02 coordination model. Its module and
authoritative-writer maps do not contain a confirmed double writer. All local
anchors exist, 52 AC are sequential, and the revision creates no runtime.

The document **must remain Draft** until named review owners are recorded.
Role labels in BCK-02 establish accountability categories, but do not prove
that a person or team accepted the review assignment required by `BCK-01 §25`.

## 2. Evidence scope

This audit read the following tracked sources in full or at their applicable
normative sections:

- `AGENTS.md` and `docs/architecture/ARCHITECTURE_BASELINE.md`;
- Accepted ADR 0012, 0013, 0015, 0016, 0017, 0018 and 0019;
- BCK-02 v2.4.4 registry, ownership, §14 template, §15 reconciliation, gates
  and next-package rules;
- BCK-03 v0.2.2 and API Contracts Workflow;
- BCK-04 v0.4.1 and coverage matrix v0.3.1;
- BCK-09 v1.0 Review contract and ECL-03B/C anchors;
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
| Reference revisions | Reference Data | BCK-20 | BCK-20 absent, ownership reserved | One writer |
| Content lifecycle | Content Publication | BCK-07 | Discover consumes projections | One writer |
| Catalog/feed/map/search | Discover | BCK-08 | No source mutation authority | One writer |
| Booking/hold/ledger/audit | Booking | BCK-09 | ADR 0019/BCK-09 consistent | One writer |
| Provider availability | Provider Integration | BCK-16 | Separate from Booking/public composition | One writer |
| Privacy request/task/status | Privacy Orchestration | BCK-04 | Domain handlers retain domain records | One writer |
| Server flags/operational telemetry | Platform Operations | BCK-05 | BCK-05 absent, ownership reserved | One writer |
| Product analytics | Analytics | BCK-21 | Separate from operational telemetry | One writer |
| Payments | Payments, conditional | BCK-17 | No authority until new Accepted ADR | Fail-closed |

No consumer is granted write authority by this report. Exact record families
must be repeated and refined by their owning BCK spec before schema approval.

## 5. Anchor and status reconciliation

| Anchor | Repository fact | BCK-01 treatment | Result |
|---|---|---|---|
| BCK-02 | Approved v2.4 semantics; v2.4.4 traceability | Coordination authority only | Pass |
| BCK-02-A1 | Draft v1.0, documentation only | Baltic rollout input, not Accepted authority | Pass |
| BCK-03 | Draft v0.2.2, runtime Absent | API detail delegated; conflict remains explicit | Pass with blocker |
| BCK-04 | Draft v0.4.1, runtime Absent | Security/privacy detail delegated | Pass with blockers |
| BCK-05 | Planned/Absent | Operations ownership reserved | Pass; required for G1 |
| BCK-09 | Review v1.0, runtime Absent | Stricter Booking rules preserved | Pass |
| BCK-20 | Planned/Absent | Reference ownership reserved | Pass; required for G1 |
| Firebase Architecture | Proposed | Infrastructure input only | Pass |
| `apps/backend` | Physically absent | Target plan only | Pass |

## 6. Findings resolved in v0.4.1

| ID | Finding | Resolution |
|---|---|---|
| BCK01-F01 | §4 snapshot still described BCK-03/BCK-04 as absent | Updated to exact Draft/Present/runtime Absent facts |
| BCK01-F02 | §17 could be read as authorizing all domain JSON schemas | Non-Booking paths made conditional on Accepted API-DEC-05 |
| BCK01-F03 | §28 asked to create BCK-03/BCK-04 after they already existed | Replaced by the actual Review and D1 completion sequence |
| BCK01-F04 | BCK-02/BCK-03/BCK-04 version traceability had drifted | Reconciled through documentation-only patch revisions |

## 7. Definition of Ready evidence

| BCK-01 §25 condition | Evidence | State |
|---|---|---|
| Anchors exist and links are valid | Automated local-link audit | Pass |
| BCK-02 reflects BCK-01 status | Registry: Draft v0.4.1/Present, runtime Absent | Pass |
| No double writer | §4 writer reconciliation | Pass |
| LV/EE/LT agrees with roadmap | Latvia first; EE/LT independently disabled | Pass |
| Open decisions are not called Accepted | §5 status table and BCK-02 OD registry | Pass |
| Review owners appointed | Roles exist; named assignment evidence absent | **Blocked** |
| Conflicts recorded | BCK-03 idempotency and BCK-04 blockers linked | Pass |
| Diff is documentation-only | Git scope + boundary/diff evidence | Pass |
| Runtime remains Absent | No `apps/backend`/Firebase/runtime files | Pass |

## 8. Required owner confirmation

Before changing `Spec status` from Draft to Review, record a real assignee or
team plus acknowledgement for each required perspective:

| Review perspective | Required acknowledgement | Current evidence |
|---|---|---|
| Platform Architecture | Owns BCK-01 target and reconciliation | Role only — pending |
| API Platform | Accepts delegation to BCK-03 | Role only — pending |
| Security/Privacy | Accepts delegation to BCK-04 | Role only — pending |
| Platform Operations | Accepts BCK-05 ownership and G1 dependency | Role only — pending |
| Identity | Confirms ADR 0015/BCK-06 boundary | Role only — pending |
| Mobile Architecture | Confirms adapter/import boundary | Role only — pending |
| Booking, Content/Discover, Planning/Route domain owners | Confirm writer split for applicable domains | Roles only — pending |

The acknowledgement may live in a repository-owned review record or approved
PR review. A document mentioning a role is not self-approval.

## 9. Review verdict and next action

**Verdict: structurally ready, procedurally blocked.** BCK-01 v0.4.1 should
remain Draft until §8 has owner evidence. After that evidence:

1. change BCK-01 to `Review` without changing architecture semantics;
2. update BCK-02 registry and LAUNCH_STATUS atomically;
3. continue BCK-03/BCK-04 blocker closure and create BCK-05/BCK-20;
4. keep G1, provisioning and runtime unauthorized.
