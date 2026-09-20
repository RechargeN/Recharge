# Recharge Backend — D1 Parent Approval Preflight

- Preflight ID: **BCK-D1-PARENT-PREFLIGHT-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared factual preflight — all four parent approvals blocked**
- Runtime status: **N/A; documentation control artifact**
- Parent work queue: [BCK-D1-INT-BLOCK-01 v0.1](BACKEND_PLATFORM_D1_INTERNAL_BLOCKER_MATRIX.md)
- Parent normalized-LF SHA-256: `bfc2f1cd4e3b042928220f71a653ac9c1bc88d37509c90b5e67727917eb65d5a`
- Runtime effect: **none**

## 1. Purpose

This preflight defines the final evidence shape for BCK-03, BCK-04, BCK-05
and BCK-20 parent Approval. It is intentionally prepared before the verdicts
exist so later closure is mechanical and cannot silently omit a blocker.

It does not approve a parent, close D1, pass G1 or authorize runtime.

## 2. Universal parent-approval contract

Every parent requires:

1. exact final target and normalized hash;
2. accountable owner verdict;
3. all mandatory specialist/independent/qualified verdicts;
4. required amendments integrated and re-reviewed;
5. child OD/decision statuses sufficient for the parent gate;
6. no unresolved contradiction or Critical/High finding;
7. migration/rollback and later executable evidence disposition;
8. atomic registry/coverage/D1 reconciliation;
9. explicit statement that Approval is still not runtime authorization.

## 3. Parent readiness matrix

| Parent | Current | Design evidence present | Missing pre-Approval evidence | Result |
|---|---|---|---|---|
| BCK-03 | Draft | 87 AC; bounded API/OPS/SEC/MOBILE verdicts; Booking evidence | accountable parent verdict, independent/full-scope confirmation, deferred-decision sufficiency | Blocked |
| BCK-04 | Draft | 65 AC; technical owner/threat verdicts; OD-11 Product package | 14 threat/cross-boundary verdicts, qualified Legal/Privacy, OD-01/09/11 closure as required | Blocked |
| BCK-05 | Draft | 51 AC; accepted toolchain/IAM/release baselines; operations package | five specialist verdicts, pre-G1 decision sufficiency, qualified evidence where required | Blocked |
| BCK-20 | Draft | 69 AC; exact source/OD-10 evidence; Batch B/C | owner batches, qualified terms/copy, per-source decisions, independent review | Blocked |

## 4. BCK-03 preflight

- Exact BCK03-PARENT-REV-01 verdict is required.
- Booking-v1 API-DEC-01/03 Acceptance is preserved.
- Deferred API-DEC decisions remain valid only with protected surfaces disabled.
- OD-09 Proposed satisfies only the D1 minimum; effects remain disabled.
- Platform schemas, generators and runtime remain later executable slices.

## 5. BCK-04 preflight

- Independent Security/Privacy plus all mandatory cross-boundary verdicts are
  required against one final threat-model revision.
- OD-11 needs Product, qualified Legal/Privacy and named boundary evidence.
- Incident/tabletop design and actual execution are distinguished.
- Qualified decisions cannot be replaced by combined Product ownership.
- Open Critical/High findings block Approval.

## 6. BCK-05 preflight

- OD-03/04/05/06/08 each retain a separate decision contract.
- Pre-G1 design verdicts are required now; actual stage measurements remain
  mandatory at their post-R1/pre-traffic gates.
- Accepted OD-01/02/07 baselines require fresh pre-R1 revalidation, not D1
  re-litigation.
- No provisioning occurs through parent Approval alone.

## 7. BCK-20 preflight

- Batch B/C exact owner actions remain separate.
- Qualified terms/access precedes per-source eligibility.
- Mandatory copy requires a market/surface/purpose matrix.
- OD-10 and BCK20-OD-02/05 close only through their own decision contracts.
- Latvia cannot activate Estonia or Lithuania.

## 8. Parent decision record

Each eventual record includes ID/version/date, target/hash, reviewer identity
and authority, exact scope, incorporated child verdicts, unresolved/deferred
items, migration/rollback, executable gates, disposition and evidence links.

Allowed disposition: `Approve design with retained executable gates`, `Accept
with required amendments`, `Reject`, or `Inconclusive`. Only the first may
change parent status after all mandatory rows pass.

## 9. Atomic reconciliation

For each accepted parent decision, update in one docs change:

- target spec and coverage matrix;
- BCK-01 architecture/reconciliation report;
- BCK-02 registry/gates/checksum;
- D1 review, ledger and workbook;
- LAUNCH_STATUS;
- every direct current-version reference.

Historical changelog and frozen exact-hash evidence remain historical.

## 10. D1 exit relation

Parent Approvals are necessary but not alone sufficient for D1 exit. After all
four parent records pass, rerun the D1 closure matrix, verify OD-07/09/10/11
requirements and issue a distinct D1 exit decision. G1 remains a later
separate decision, and R1 remains separately authorized.

## 11. Acceptance criteria

1. **D1-PREFLIGHT-AC-01:** all four parents are explicit.
2. **D1-PREFLIGHT-AC-02:** every parent remains currently Blocked.
3. **D1-PREFLIGHT-AC-03:** exact targets/hashes are mandatory.
4. **D1-PREFLIGHT-AC-04:** accountable and independent verdicts remain distinct.
5. **D1-PREFLIGHT-AC-05:** qualified Legal/Privacy cannot be self-inferred.
6. **D1-PREFLIGHT-AC-06:** amendments require exact re-review.
7. **D1-PREFLIGHT-AC-07:** Critical/High findings block Approval.
8. **D1-PREFLIGHT-AC-08:** child decisions retain their own gates.
9. **D1-PREFLIGHT-AC-09:** Booking-v1 Acceptance is preserved.
10. **D1-PREFLIGHT-AC-10:** Deferred API decisions remain fail-closed.
11. **D1-PREFLIGHT-AC-11:** OD-11 remains Open until complete evidence.
12. **D1-PREFLIGHT-AC-12:** pre-G1 and post-R1 evidence are separated.
13. **D1-PREFLIGHT-AC-13:** source eligibility waits for terms evidence.
14. **D1-PREFLIGHT-AC-14:** Latvia cannot activate EE/LT.
15. **D1-PREFLIGHT-AC-15:** parent Approval is not runtime authorization.
16. **D1-PREFLIGHT-AC-16:** D1 exit remains a distinct decision.
17. **D1-PREFLIGHT-AC-17:** G1 remains a distinct decision after D1.
18. **D1-PREFLIGHT-AC-18:** R1 requires separate explicit authorization.
19. **D1-PREFLIGHT-AC-19:** canonical reconciliation is atomic.
20. **D1-PREFLIGHT-AC-20:** historical exact evidence is not rewritten.
21. **D1-PREFLIGHT-AC-21:** no schema/runtime/cloud resource is created.
22. **D1-PREFLIGHT-AC-22:** Firebase, deployment, activation, push and merge remain unauthorized.

## 12. Current disposition

The preflight is prepared. BCK-03/04/05/20 remain Draft; D1/G1 remain Blocked
and no parent decision has been recorded.
