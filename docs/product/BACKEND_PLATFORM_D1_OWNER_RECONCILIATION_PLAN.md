# Recharge Backend — D1 Owner Decision Reconciliation Plan

- Plan ID: **BCK-D1-OWN-RECON-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared — executable only after exact Batch F owner acceptance**
- Runtime status: **N/A; documentation-only atomic update plan**
- Runtime effect: **none**

## 1. Purpose

This plan defines the single docs-only change required after an exact Batch F
decision. It prevents partial registry drift, double-counted signatures and
accidental OD/BCK/stage promotion.

The plan is not permission to execute reconciliation before the decision.

## 2. Preconditions

All must be true:

1. exact Batch F response is attributable to the Product owner;
2. four source-package hashes match the roll-up;
3. all fifteen verdict IDs/dispositions are explicit;
4. retained gates and non-authorizations are preserved;
5. no source package changed after review;
6. repository status is checked and unrelated work is excluded.

Failure of any precondition makes reconciliation Inconclusive and no canonical
status is changed.

## 3. Decision artifact

Create one immutable document:

`BACKEND_PLATFORM_D1_OWNER_BATCH_F_DECISION.md`

It records the exact response, four hashes, fifteen verdicts, combined-role
disclosure, retained statuses, timestamp and reconciliation commit. Separate
B–E decision files are unnecessary when Batch F is accepted in full.

## 4. Atomic file set

The reconciliation must update, as applicable:

- BCK-20 spec/coverage and OD-10 review records for verdicts 1–7;
- D1 external handoff/closure state descriptions for verdicts 8–9;
- BCK-04/OD-11 records for verdict 10;
- BCK-05 operations records for verdict 11;
- internal blocker matrix description for verdict 12;
- BCK-03 parent-review state for verdict 13;
- Security assignment manifest state description for verdict 14;
- parent preflight state description for verdict 15;
- BCK-01/reconciliation report and BCK-02 registry;
- D1 review, ledger, workbook and LAUNCH_STATUS.

Frozen source packages remain byte-identical historical inputs.

## 5. Allowed status transitions

| Item | Before | After full Batch F reconciliation |
|---|---|---|
| fifteen bounded verdicts | Pending | Recorded/Accepted within exact scope |
| separate B/C/D/E response requirement | Pending | Superseded by exact Batch F decision |
| external/specialist/qualified verdicts | Pending/Unassigned | unchanged |
| OD-10 | Proposed | unchanged |
| BCK20-OD-02/05 | Open | unchanged |
| OD-11 | Open | unchanged |
| BCK05 OD statuses | Open/Proposed/Accepted as recorded | unchanged |
| BCK04-OD-01/09 | Proposed | unchanged |
| BCK-03/04/05/20 | Draft | unchanged |
| BCK-01 | Review | unchanged |
| D1/G1 | Blocked | unchanged |

## 6. Prohibited reconciliation

Do not:

- mark Product/coordination verdicts as independent or specialist;
- mark a source eligible;
- invent reviewer identity or qualification;
- choose numeric age/guardian/provider/schema details;
- promote an OD or BCK merely because its review route is accepted;
- mark D1/G1 complete;
- edit code, schema, Firebase config or deployment state;
- include unrelated working-tree files.

## 7. Validation

Before commit:

1. verify exact hashes and fifteen unique verdict IDs;
2. validate all local links and Markdown fences;
3. validate sequential AC in every changed canonical document;
4. search for stale current-version/status references;
5. run `git diff --check`;
6. inspect staged names and ensure docs-only scope;
7. record commit hash in the decision evidence if governance requires a
   follow-up metadata revision.

## 8. Rollback

Because reconciliation is docs-only, rollback reverts the decision record and
its canonical status descriptions as one unit. It must not erase the original
B–E packages or rewrite their hashes. Partial rollback that leaves some of the
fifteen verdicts recorded is prohibited unless a new explicit owner decision
names the retained subset.

## 9. Acceptance criteria

1. **D1-OWN-RECON-AC-01:** reconciliation requires exact attributable acceptance.
2. **D1-OWN-RECON-AC-02:** four source hashes must match.
3. **D1-OWN-RECON-AC-03:** fifteen verdict IDs must be unique and explicit.
4. **D1-OWN-RECON-AC-04:** one immutable Batch F decision is created.
5. **D1-OWN-RECON-AC-05:** B–E source packages remain byte-identical.
6. **D1-OWN-RECON-AC-06:** only bounded verdict statuses change.
7. **D1-OWN-RECON-AC-07:** specialist/qualified/independent rows remain open.
8. **D1-OWN-RECON-AC-08:** no source eligibility changes.
9. **D1-OWN-RECON-AC-09:** no OD status changes.
10. **D1-OWN-RECON-AC-10:** no parent BCK status changes.
11. **D1-OWN-RECON-AC-11:** D1/G1 remain Blocked.
12. **D1-OWN-RECON-AC-12:** all markets remain disabled.
13. **D1-OWN-RECON-AC-13:** canonical documents update atomically.
14. **D1-OWN-RECON-AC-14:** historical evidence is not rewritten.
15. **D1-OWN-RECON-AC-15:** unrelated worktree changes are excluded.
16. **D1-OWN-RECON-AC-16:** stale current references fail validation.
17. **D1-OWN-RECON-AC-17:** partial reconciliation is prohibited.
18. **D1-OWN-RECON-AC-18:** rollback is atomic and evidence-preserving.
19. **D1-OWN-RECON-AC-19:** no schema/runtime/cloud file is changed.
20. **D1-OWN-RECON-AC-20:** Firebase, deployment, activation, push and merge remain unauthorized.

## 10. Current disposition

The plan is prepared but not executable. It becomes applicable only after the
exact Batch F owner response.
