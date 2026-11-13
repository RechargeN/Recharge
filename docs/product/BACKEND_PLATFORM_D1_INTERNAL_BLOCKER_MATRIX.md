# Recharge Backend — D1 Internal Blocker Matrix

- Matrix ID: **BCK-D1-INT-BLOCK-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared factual work queue — no gate promotion**
- Runtime status: **N/A; documentation control artifact**
- Accountable coordinator: **RechargeN / Product owner**
- Parent closure matrix: [BCK-D1-G1-CLOSE-01 v0.1](BACKEND_PLATFORM_D1_G1_CLOSURE_MATRIX.md)
- Parent normalized-LF SHA-256: `eb9ad286e3089887fb48cabe84cdcd4f728a2a0db985393e0a120f88ba748d2f`
- Runtime effect: **none**

---

## 1. Purpose

The D1/G1 closure matrix states what is blocked. This companion matrix states
who can unblock each item and whether the work is:

- `Internal-now` — a bounded design verdict can be produced without runtime;
- `External-now` — an eligible independent or qualified reviewer is required;
- `Post-G1` — executable evidence correctly waits for separately authorized
  provisioning/runtime;
- `Sequential` — depends on another exact verdict;
- `Deferred` — intentionally assigned to a later named gate and unused now.

The matrix prevents repeated planning, premature emulator/cloud work and false
progress percentages that ignore a mandatory blocker.

## 2. Classification rules

1. A row has exactly one primary next owner.
2. Combined roles are disclosed and never counted as independence.
3. Product-owner decisions cannot satisfy qualified Legal/Privacy evidence.
4. Documentation may define a test/evidence contract, but not claim its result.
5. A post-G1 measurement is not pulled into D1 merely to make a document look
   complete.
6. A mandatory pre-G1 design decision is not deferred into runtime.
7. Every Deferred row names the future gate and fail-closed default.

## 3. Critical-path blockers

| ID | Boundary | Current | Class | Primary next owner | Exact next artifact/result |
|---|---|---|---|---|---|
| INT-01 | Owner Batch B | six verdicts Pending | Internal-now | Product owner | exact Batch B response or rejection |
| INT-02 | Owner Batch C | three verdicts Pending | Internal-now | Product owner | exact Batch C response or rejection |
| INT-03 | OD-11 Product boundary | unselected | Internal-now | Product owner | exact OD11 Product verdict |
| INT-04 | BCK-05 remaining design | five verdicts Pending | Internal-now + specialist | Operations/affected owners | exact BCK05-OPS-REV-02 verdicts |
| EXT-01 | source terms/access | Pending | External-now | qualified terms/Legal reviewer | attributable lane A verdicts |
| EXT-02 | mandatory copy | Pending | External-now | qualified Legal/Privacy reviewer | Latvia market/surface/purpose matrix verdict |
| EXT-03 | minors/age | Pending | External-now | qualified Legal/Privacy reviewer | attributable OD-11 market verdict |
| EXT-04 | threat/cross-boundary | Pending | External-now | independent Security + named owners | lane D findings/verdicts |
| SEQ-01 | per-source eligibility | Blocked | Sequential | Reference Data owner | disposition after EXT-01 |
| SEQ-02 | OD-10/BCK20-OD-05 | Proposed/Open | Sequential | named owners | decision after B/C and EXT-01/02 |
| SEQ-03 | OD-11 Proposed | Open | Sequential | Product + qualified/cross-boundary owners | decision after INT-03 and EXT-03 |
| SEQ-04 | parent BCK Approvals | Draft/Review | Sequential | accountable owners | exact final reconciliation after child closure |
| SEQ-05 | D1 exit | Blocked | Sequential | platform/product owners | all mandatory D1 rows pass |
| SEQ-06 | G1 | Blocked | Sequential | platform owner | distinct G1 decision after D1 exit |

## 4. BCK-03 API blockers

| Work item | Class | Needed for D1/G1 | Later evidence | Fail-closed default |
|---|---|---:|---|---|
| reconcile accepted bounded API/Operations/Security/Mobile amendments | Internal-now | yes | conformance tests later | BCK-03 stays Draft |
| disposition API-DEC-01–05 scopes not needed now | Internal-now/Deferred | yes | exact slices at named gates | no new API surface |
| independent full-scope confirmation | External-now | yes for Approval | executable parity later | no parent Approval |
| Booking RAW-C runtime proof | already bounded, not sufficient | no | later approved activation | exports remain disabled |

## 5. BCK-04 Security/Privacy blockers

| Work item | Class | Needed for D1/G1 | Later evidence | Fail-closed default |
|---|---|---:|---|---|
| OD-11 Product boundary | Internal-now | yes | implementation later | age-sensitive surfaces disabled |
| qualified OD-11 review | External-now | yes | revalidation before activation | OD-11 Open |
| independent threat assessment | External-now | yes | runtime security tests later | BCK04-OD-01 Proposed |
| Identity/Booking/Content/Operations cross-boundary confirmations | External-now/owner | yes | integration tests later | affected paths disabled |
| incident model owner review | Internal-now | yes | routes/tabletop later | OD-09 Proposed |
| executed tabletop | Post-G1 before applicable production gate | no for design closure | actual result/findings | no incident-readiness claim |
| qualified privacy/legal decisions | External-now | where specified | operational proof later | BCK-04 Draft |

## 6. BCK-05 Operations blockers

| Work item | Class | Needed for D1/G1 | Later evidence | Fail-closed default |
|---|---|---:|---|---|
| OD-03 SLO design verdict | Internal-now + specialist | yes | telemetry/alerts/drill | no production SLO claim |
| OD-04 cost-control design verdict | Internal-now + Finance | yes | EUR/tax/SKU/invoice/usage | no irreversible provisioning |
| OD-05 recovery design verdict | Internal-now + external where legal | yes | timed restore/PITR/IAM | no recoverability claim |
| OD-06 OD-09 alignment | Sequential | minimum Proposed for D1 | worker/replay tests later | no async effects |
| OD-08 incident operations design | Internal-now | yes | real routes/tabletop later | no readiness claim |
| pre-R1 revalidation of accepted OD-01/02/07 | Post-G1 | no | fresh toolchain/IAM/provenance evidence | no R1 execution |

## 7. BCK-20 Reference/Localization blockers

| Work item | Class | Needed for D1/G1 | Later evidence | Fail-closed default |
|---|---|---:|---|---|
| Batch B five OD-10 perspectives | Internal-now | yes | fixtures/schema later | OD-10 Proposed |
| Batch B source-governance verdict | Internal-now | yes | parser/ingestion later | no source eligible |
| Batch C Product copy boundary | Internal-now | yes | executable copy delivery later | BCK20-OD-05 Open |
| qualified source terms/access | External-now | yes | pinned acquisition later | sources blocked |
| qualified mandatory-copy matrix | External-now | yes | locale content and acceptance UI later | fallback forbidden where uncertain |
| per-source dispositions | Sequential after terms | yes | ingestion at later slice | all markets disabled |
| independent Security/Privacy review | External-now | yes for Approval | runtime controls later | BCK-20 Draft |

## 8. Explicit post-G1 queue

The following must not be used to block completion of design work when their
contracts, thresholds, owners and stop conditions are already accepted:

- actual Firebase project/resource creation;
- real IAM bindings and workload identity execution;
- stage telemetry, alert delivery and SLO measurements;
- provider invoice/SKU and measured cost reconciliation;
- restore/PITR drills at representative size;
- worker replay, dedupe, poison-message and capacity tests;
- production-like security tests and incident routes;
- parser/fixture/ingestion evidence;
- mobile/network integration and activation.

They remain mandatory at their named R-stage/production gates.

## 9. Safe parallel work now

These actions may proceed in parallel without runtime:

1. exact Product responses to Batch B and Batch C;
2. Product review of OD-11 boundary;
3. Operations/Finance/Security/domain review of BCK05-OPS-REV-02;
4. assignment and execution of external review lanes A–D;
5. preparation of amendment patches from attributable findings;
6. registry reconciliation after each accepted exact verdict.

Per-source disposition, OD-10/OD-11 promotion and parent Approval remain
sequential after their prerequisites.

## 10. Closure order

```text
internal owner packages + external lanes
  -> integrate findings and re-freeze changed targets
  -> per-source / OD-10 / OD-11 decisions
  -> BCK-03 / BCK-04 / BCK-05 / BCK-20 final reviews
  -> BCK-01 reconciliation and D1 exit
  -> distinct G1 decision
  -> separately authorized R1
```

## 11. Acceptance criteria

1. **D1-INT-AC-01:** every blocker has one primary next owner.
2. **D1-INT-AC-02:** internal, external, sequential and post-G1 work are distinct.
3. **D1-INT-AC-03:** combined ownership is not counted as independence.
4. **D1-INT-AC-04:** Product authority is not represented as Legal authority.
5. **D1-INT-AC-05:** Batch B remains Pending until exact response.
6. **D1-INT-AC-06:** Batch C remains Pending until exact response.
7. **D1-INT-AC-07:** OD-11 remains Open until its complete decision contract passes.
8. **D1-INT-AC-08:** BCK-03 remains Draft pending full closure.
9. **D1-INT-AC-09:** BCK-04 remains Draft pending full closure.
10. **D1-INT-AC-10:** BCK-05 remains Draft pending full closure.
11. **D1-INT-AC-11:** BCK-20 remains Draft pending full closure.
12. **D1-INT-AC-12:** BCK-01 remains Review pending child closure.
13. **D1-INT-AC-13:** D1 exit remains blocked.
14. **D1-INT-AC-14:** G1 remains a distinct blocked decision.
15. **D1-INT-AC-15:** R1 remains separately unauthorized.
16. **D1-INT-AC-16:** post-G1 evidence is not demanded before provisioning.
17. **D1-INT-AC-17:** pre-G1 design decisions are not deferred into runtime.
18. **D1-INT-AC-18:** source eligibility waits for qualified terms evidence.
19. **D1-INT-AC-19:** mandatory copy waits for qualified market evidence.
20. **D1-INT-AC-20:** age eligibility waits for Product and qualified evidence.
21. **D1-INT-AC-21:** parent Approval waits for required child decisions.
22. **D1-INT-AC-22:** unresolved critical/high security findings block closure.
23. **D1-INT-AC-23:** accepted bounded R0/RAW-C evidence is not platform Approval.
24. **D1-INT-AC-24:** all markets remain disabled.
25. **D1-INT-AC-25:** Latvia cannot activate Estonia or Lithuania.
26. **D1-INT-AC-26:** progress percentages cannot override a mandatory blocker.
27. **D1-INT-AC-27:** changed hashes require affected re-review.
28. **D1-INT-AC-28:** reconciliation updates canonical records atomically.
29. **D1-INT-AC-29:** this matrix creates no schema/runtime/cloud authority.
30. **D1-INT-AC-30:** Firebase, deployment, activation, push and merge remain unauthorized.

## 12. Current disposition

The work queue is prepared. No blocker is closed by this matrix. D1 exit and
G1 remain `Blocked`; R1 remains unauthorized.
