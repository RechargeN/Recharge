# Recharge Backend — D1 to G1 Closure Matrix

- Matrix ID: **BCK-D1-G1-CLOSE-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared factual closure baseline — D1 exit and G1 blocked**
- Canonical gate source: [BCK-02 v2.4.72](RECHARGE_BACKEND_DELIVERY_MAP.md)
- BCK-02 normalized-LF SHA-256:
  `f0299ec5011b9a1a08d133ef769c4bc03047fa6bd1b03c7bacaa600c3549df63`
- D1 evidence source: [BCK-D1-REV-01 v1.32](BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md)
- D1 evidence normalized-LF SHA-256:
  `a1af14b875855979b808f2c53c29f2713b0f183d65f6c219a4c3a87331e7d85f`
- Architecture source: [BCK-01 v0.4.66](RECHARGE_BACKEND_MASTER_SPEC.md)
- BCK-01 normalized-LF SHA-256:
  `e305b77eaa00ee1fa08ac605057dfad6a571ba25a149c9b9004370122dd52314`
- Accountable coordinator: **RechargeN / Product owner**
- Runtime effect: **none**

---

## 1. Purpose

This matrix gives one current, non-inflated answer to three questions:

1. what must be true for D1 exit;
2. what must be true for G1;
3. which remaining items are documentation/review work versus later R1
   executable evidence.

It does not supersede BCK-02 or create a second roadmap. BCK-02 remains the
gate authority. This file is a closure ledger that must be regenerated or
revalidated when any frozen source changes.

## 2. Status vocabulary

| Status | Meaning |
|---|---|
| `Satisfied` | exact attributable evidence meets the current requirement |
| `Bounded` | a narrower boundary is accepted, but the parent requirement is not satisfied |
| `Prepared` | review/evidence package exists; no effective verdict yet |
| `Pending` | responsible review/decision/evidence is absent |
| `Blocked` | a prerequisite or external authority is absent |
| `Deferred` | explicitly assigned to a later gate and cannot be used now |
| `N/A pre-G1` | executable proof correctly belongs after G1/R1 and is not a design-acceptance blocker |

Document presence alone is never `Satisfied`.

## 3. Canonical G1 contract

BCK-02 requires all of the following:

1. BCK-01, BCK-03, BCK-04, BCK-05 and BCK-20 are Approved and reconciled;
2. OD-07 and OD-10 are Accepted;
3. OD-09 and OD-11 are at least Proposed;
4. API evolution, environments, IAM, data classes, resource locations, cost,
   backup/export and rollback are agreed;
5. BCK-04 defines fail-closed boundaries for every OD-11-dependent feature;
6. executable slices and post-stabilization authorization remain separately
   mandatory after G1.

No partial percentage or aggregate score can override a failed mandatory row.

## 4. Specification approval matrix

| Requirement | Current state | Evidence already present | Exact missing closure | Result |
|---|---|---|---|---|
| BCK-01 Approved/reconciled | Review v0.4.66 | architecture, ownership, reconciliation report | child platform approvals and final owner decision | Blocked |
| BCK-03 Approved | Draft v0.3.14 | API/Operations/Security/Mobile bounded verdicts; Booking parity evidence | independent/attributable full-scope closure, deferred-decision disposition and final Approval | Blocked |
| BCK-04 Approved | Draft v0.4.23 | technical owner review, threat model, incident model/tabletop package | independent Security/Privacy, cross-boundary confirmations, qualified Legal decisions, OD/tabletop closure and final Approval | Blocked |
| BCK-05 Approved | Draft v0.2.30 | accepted toolchain/IAM/release baselines; SLO/cost/recovery proposals | accountable Operations and affected specialist verdicts, pre-G1 decision closure and final Approval | Blocked |
| BCK-20 Approved | Draft v0.2.21 | taxonomy, source evidence, OD-10 v0.2, Batch B prepared | Batch B verdicts, qualified terms/copy policy, source decisions, independent review and final Approval | Blocked |

All five mandatory specifications fail the Approved requirement today.

## 5. Open-decision matrix

| Decision | G1 requirement | Current state | Evidence/gap | Result |
|---|---|---|---|---|
| OD-07 infrastructure topology | Accepted | Accepted with controls | revalidation still mandatory before provisioning; no cloud authority | Satisfied for design only |
| OD-10 localization contract | Accepted | Proposed | v0.2 semantics fixed; Batch B five-perspective review prepared but unsigned; Legal/executable gates open | Blocked |
| OD-09 events/outbox | minimum Proposed | Proposed | later transport/effects evidence retained | Satisfied for G1 minimum only |
| OD-11 age eligibility | minimum Proposed | Open | legal brief prepared; no concrete Product/qualified policy | Blocked |
| BCK04-OD-01 threat model | required for BCK-04 | Proposed | technical decision recorded; independent/cross-boundary package ready | Blocked |
| BCK04-OD-09 incident response | required for BCK-04 | Proposed | model and tabletop package ready; exercise/result absent | Blocked |
| BCK20-OD-02 source/translation | required for BCK-20 | Open | technical/source evidence exists; qualified terms and per-source decisions absent | Blocked |
| BCK20-OD-05 mandatory copy | required for OD-10/BCK-20 | Open | Product policy package prepared; qualified market matrix absent | Blocked |

## 6. Cross-cutting design matrix

| G1 topic | Current design evidence | Remaining pre-G1 decision/review | Later executable evidence | Current result |
|---|---|---|---|---|
| API evolution | BCK-03 versioning/compatibility and Booking parity | full-scope API closure; API-DEC gates preserved | generated/schema parity under Approved slice | Bounded |
| environments | OD-07 topology; BCK-05 environment model | final BCK-05 specialist/Approval | actual project isolation under R1 | Bounded |
| IAM | accepted keyless WIF design | final BCK-04/05 reconciliation | deployed identities/policies/negative tests under R1 | Bounded |
| data classes/privacy | BCK-04 classification and threat model | qualified Legal/Privacy and independent review | storage/rules/log tests later | Blocked |
| resource locations | OD-07 accepted topology | dated revalidation before irreversible action | provisioned-location evidence under R1 | Satisfied for design only |
| cost | cost envelopes and alert/containment proposals | Operations/Finance disposition using current EUR assumptions | measured stage cost after R1 | Bounded |
| backup/export | recovery model and export/rollback boundaries | Operations/Security/Privacy/domain verdicts | restore drill after authorized environment exists | Bounded |
| rollback | release, config and data rollback designs | specialist reconciliation and unsafe-rollback stop rules | executed rollback evidence later | Bounded |
| localization/reference | BCK-20/OD-10/source governance | Batch B, qualified terms/copy and source decisions | parser/fixture/distribution evidence later | Blocked |
| age-dependent fail-closed | BCK-04 design and OD-11 brief | concrete Product + qualified policy; map every affected feature | executable negative tests at later gate | Blocked |

Executable cloud measurements that logically require R1 are not fabricated as
pre-G1 evidence. Their target, threshold, owner and stop condition must be
accepted before G1; the measurement itself follows the separately Approved
runtime slice and precedes traffic.

## 7. Owner and external-review lanes

### Lane A — combined Product/technical owner

Ready now:

- Batch B exact response for five OD-10 perspectives and source governance;
- Batch C Product mandatory-copy classification and closure/handoff baseline;
- concrete Product proposal for OD-11, still subject to qualified review;
- reconciliation of bounded decisions without claiming independence.

### Lane B — qualified Legal/terms

Required:

- per-source terms/access verdicts;
- Latvia mandatory-copy market/surface/purpose matrix;
- concrete age/eligibility conclusions and product constraints;
- other BCK-04 purposes/bases/retention/processor/transfer decisions where
  professional judgment is required.

### Lane C — independent Security/Privacy and cross-boundary reviewers

Required:

- independent threat-model verdict;
- API/Operations/Identity/Mobile and affected-domain confirmations;
- findings integration and exact-version re-review;
- no unresolved Critical/High contradiction.

### Lane D — specification owners

Only after A–C evidence exists:

- decide BCK-03/04/05/20 Approval separately;
- reconcile BCK-01 and decide its Approval;
- verify OD-07/09/10/11 exact state;
- issue an explicit G1 verdict rather than inferring it.

## 8. D1 closure checklist

| ID | Requirement | Current state | Pass evidence |
|---|---|---|---|
| D1-C01 | current anchors/hashes reconciled | satisfied for this snapshot | BCK-D1-REV-01 and this matrix |
| D1-C02 | BCK-03 accountable closure | blocked | final exact owner/specialist record |
| D1-C03 | BCK-04 accountable closure | blocked | independent/cross-boundary/qualified results plus Approval |
| D1-C04 | BCK-05 accountable closure | blocked | Operations/specialist decisions plus Approval |
| D1-C05 | BCK-20 accountable closure | blocked | Batch B, qualified/source decisions, OD-10 and Approval |
| D1-C06 | OD-07 exact accepted topology retained | satisfied for design | OD07-DEC-01 v0.2 |
| D1-C07 | OD-10 Accepted | blocked | exact acceptance record after retained gates |
| D1-C08 | OD-09 at least Proposed | satisfied for minimum | current OD ledger |
| D1-C09 | OD-11 at least Proposed | blocked | concrete Product proposal with fail-closed boundary |
| D1-C10 | conflicts and amendments reconciled | pending | zero unresolved required amendments across exact versions |
| D1-C11 | required independent/qualified evidence attributable | blocked | named, scoped, hash-pinned records |
| D1-C12 | status registries updated atomically | pending | one final reconciliation commit after verdicts |
| D1-C13 | runtime non-authorization preserved | satisfied | no R1/G1 authority in current docs |
| D1-C14 | final D1 exit verdict | blocked | explicit owner decision after C01–C13 |

## 9. G1 decision checklist

G1 may be marked Passed only when:

- D1-C01–C14 are Satisfied;
- the five mandatory BCK specifications are Approved;
- OD-07/10 are Accepted and OD-09/11 are at least Proposed;
- the cross-cutting design topics in §6 have an accepted pre-G1 disposition;
- unresolved items are either blockers or explicitly Deferred to a named later
  gate without being used as present evidence;
- BCK-01/02, affected BCK specs/matrices, D1 ledger/review and Launch Status
  agree in the same commit;
- the decision explicitly states that R1 still requires its own exact file
  plan, rollback and authorization.

## 10. Recommended work order

1. record Batch B owner decision if accepted;
2. prepare/record Batch C Product boundaries without claiming external review;
3. assign eligible reviewers through BCK-D1-XREV-HANDOFF-01;
4. integrate and re-review amendments;
5. close OD-11 to at least Proposed and OD-10 to Accepted only with evidence;
6. decide BCK-03/04/05/20 Approval individually;
7. reconcile and decide BCK-01 Approval;
8. record D1 exit;
9. make a separate explicit G1 decision;
10. only then prepare a separately authorized R1 slice.

## 11. Explicit non-authorizations

This matrix does not authorize:

- accepting Batch B or Batch C verdicts;
- naming or impersonating external reviewers;
- accepting terms, licenses, Legal policy or residual risk;
- schema, fixtures, parser, dataset or application changes;
- credentials, cloud projects, IAM, Firebase or deployment;
- R1, traffic, production data, market activation, push or merge.

## 12. Acceptance criteria

1. **BCK-D1-G1-CLOSE-AC-01:** the three canonical inputs are hash-pinned.
2. **BCK-D1-G1-CLOSE-AC-02:** BCK-02 remains the gate authority.
3. **BCK-D1-G1-CLOSE-AC-03:** D1 exit and G1 remain separate decisions.
4. **BCK-D1-G1-CLOSE-AC-04:** all five mandatory BCK Approval rows are explicit.
5. **BCK-D1-G1-CLOSE-AC-05:** OD-07/09 minimums are not overstated into broader completion.
6. **BCK-D1-G1-CLOSE-AC-06:** OD-10 Proposed fails its Accepted requirement.
7. **BCK-D1-G1-CLOSE-AC-07:** OD-11 Open fails its Proposed minimum.
8. **BCK-D1-G1-CLOSE-AC-08:** document presence is not verdict evidence.
9. **BCK-D1-G1-CLOSE-AC-09:** bounded owner reviews do not satisfy parent Approval automatically.
10. **BCK-D1-G1-CLOSE-AC-10:** qualified and independent evidence remains attributable and separate.
11. **BCK-D1-G1-CLOSE-AC-11:** pre-G1 design evidence is separated from post-R1 measurements.
12. **BCK-D1-G1-CLOSE-AC-12:** no circular cloud-evidence prerequisite is invented for G1.
13. **BCK-D1-G1-CLOSE-AC-13:** later executable evidence still has an accepted target/threshold/owner/stop condition.
14. **BCK-D1-G1-CLOSE-AC-14:** Latvia and EE/LT activation remain separate.
15. **BCK-D1-G1-CLOSE-AC-15:** source eligibility cannot substitute for OD-10/BCK-20 Approval.
16. **BCK-D1-G1-CLOSE-AC-16:** Batch B and Batch C remain Pending until exact acceptance.
17. **BCK-D1-G1-CLOSE-AC-17:** BCK-04 owns fail-closed OD-11-dependent boundaries.
18. **BCK-D1-G1-CLOSE-AC-18:** unresolved Critical/High security findings block closure.
19. **BCK-D1-G1-CLOSE-AC-19:** every Deferred item names a later gate and is not used now.
20. **BCK-D1-G1-CLOSE-AC-20:** canonical status updates are atomic.
21. **BCK-D1-G1-CLOSE-AC-21:** G1 never authorizes R1 implicitly.
22. **BCK-D1-G1-CLOSE-AC-22:** RAW-C/R0 evidence does not satisfy platform Approval.
23. **BCK-D1-G1-CLOSE-AC-23:** mock/local state is not production authority.
24. **BCK-D1-G1-CLOSE-AC-24:** external review routing does not create a verdict.
25. **BCK-D1-G1-CLOSE-AC-25:** exact target/hash changes require revalidation.
26. **BCK-D1-G1-CLOSE-AC-26:** incomplete or Inconclusive evidence remains blocking.
27. **BCK-D1-G1-CLOSE-AC-27:** percentage progress cannot override a failed mandatory row.
28. **BCK-D1-G1-CLOSE-AC-28:** runtime non-authorization is preserved through closure work.
29. **BCK-D1-G1-CLOSE-AC-29:** this matrix changes no application/backend code or cloud state.
30. **BCK-D1-G1-CLOSE-AC-30:** Firebase, deployment, activation, push and merge remain unauthorized.

## 13. Current verdict

**D1 exit: Blocked. G1: Blocked.**

The documentation is sufficiently organized to run the remaining owner,
qualified and independent reviews without another planning phase. The next
useful action is verdict collection and reconciliation, not runtime work.
