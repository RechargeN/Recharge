# Recharge Backend — D1 Owner Batch B–E Roll-up

- Roll-up ID: **BCK-D1-OWN-BE-ROLLUP-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared — 15 verdicts Pending**
- Runtime status: **N/A; documentation-only review consolidation**
- Accountable coordinator: **RechargeN / Product owner**
- Runtime effect: **none**

## 1. Purpose

This roll-up allows the Product owner to review Batch B, C, D and E in one
action without merging their fifteen bounded verdicts or weakening any retained
gate. It eliminates four repetitive approval turns while preserving exact
source packages and scope.

The roll-up does not itself record a verdict. Until an exact owner response is
accepted and reconciled, all fifteen verdicts remain Pending.

## 2. Frozen batch inputs

| Batch | Exact package | Normalized-LF SHA-256 | Verdict count |
|---|---|---|---:|
| B | [BCK-D1-OWN-B-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_B_REVIEW_PACKAGE.md) | `555ab7e31e892c297da53d44a0669b958628e66c360974974d7e49fc0ad8ab8c` | 6 |
| C | [BCK-D1-OWN-C-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_C_REVIEW_PACKAGE.md) | `998f905ea1de783db491a61b70423e010a18a461c58444a1e04eaa594981e947` | 3 |
| D | [BCK-D1-OWN-D-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_D_REVIEW_PACKAGE.md) | `59026ff06750bfb68cb11faa7625c3bce3c541bb09e0659b5a65097de1bc5d51` | 3 |
| E | [BCK-D1-OWN-E-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_E_REVIEW_PACKAGE.md) | `d0376238f50a23571a4aea0d89974cdd0d568893b612c0dc09d661a74b411646` | 3 |
| **Checksum** | **four immutable packages** | **all exact hashes required** | **15** |

A changed package hash invalidates only its six/three associated verdicts and
requires a new roll-up revision.

## 3. Fifteen-verdict ledger

| # | Verdict ID | Source | Recommended bounded disposition | Remains outside verdict |
|---:|---|---|---|---|
| 1 | `OD10-SIG-REF` | B | Accept documentation design boundary with retained gates | source eligibility, runtime distribution |
| 2 | `OD10-SIG-API` | B | Accept documentation design boundary with retained gates | API-DEC-05, schema, transport/parity |
| 3 | `OD10-SIG-L10N` | B | Accept documentation design boundary with retained gates | final market policy and quality evidence |
| 4 | `OD10-SIG-CONTENT` | B | Accept documentation design boundary with retained gates | source use, mandatory copy, correction execution |
| 5 | `OD10-SIG-MOBILE` | B | Accept documentation design boundary with retained gates | UI/cache/adapter/runtime evidence |
| 6 | `BCK20-OD02-SRC-GOV` | B | Accept source-governance design boundary with retained gates | qualified terms, eligibility, EXT-G5/G6 |
| 7 | `BCK20-OD05-SIG-PRODUCT` | C | Accept Product design boundary with retained qualified/executable gates | Legal sufficiency, exact copy, OD-05 Acceptance |
| 8 | `D1-XREV-HANDOFF-SIG-OWNER` | C | Accept review-routing baseline with retained external verdict gates | identity, qualification, external verdict |
| 9 | `D1-G1-CLOSE-SIG-OWNER` | C | Accept factual closure baseline with blocked verdict | D1 exit, G1 Pass or R1 authority |
| 10 | `OD11-SIG-PRODUCT` | D | Accept Product design boundary with retained gates | numeric age, guardian model, Legal sufficiency |
| 11 | `BCK05-OPS2-SIG-COORD` | D | Accept specialist-review routing with retained gates | five specialist verdicts, OD/BCK promotion |
| 12 | `D1-INT-BLOCK-SIG-OWNER` | D | Accept factual internal blocker baseline | closure of any blocker or stage |
| 13 | `BCK03-PARENT-SIG-COORD` | E | Accept parent-review routing with retained gates | accountable API verdict and BCK-03 Approval |
| 14 | `BCK04-XASSIGN-SIG-OWNER` | E | Accept assignment/routing manifest with retained gates | reviewer identity, assignment or security verdict |
| 15 | `D1-PREFLIGHT-SIG-OWNER` | E | Accept factual parent preflight with blocked verdict | parent Approval, D1/G1/R1 |

## 4. Non-aggregation rule

One owner message may record all fifteen verdicts, but each retains its own ID,
scope, source hash, invalidation rule and downstream gate. The roll-up is not a
sixteenth “overall approval” and cannot be used as a specialist, independent
or qualified signature.

## 5. Status after acceptance

Only the fifteen bounded verdict records become `Recorded/Accepted within
scope`. The following remain unchanged:

- OD-10 Proposed;
- BCK20-OD-02 and BCK20-OD-05 Open;
- OD-11 Open;
- BCK05-OD-03/04/05/08 Proposed and BCK05-OD-06 Open;
- BCK04-OD-01/09 Proposed;
- BCK-03/04/05/20 Draft and BCK-01 Review;
- all source eligibility, external, specialist, independent and qualified
  evidence gates;
- D1/G1 Blocked and R1 unauthorized;
- all markets disabled.

## 6. Supersession semantics

An accepted Batch F roll-up supersedes only the need to send separate owner
responses for B, C, D and E. It does not supersede their documents, hashes,
acceptance criteria or retained gates. Each remains the detailed normative
scope for its verdicts.

If only part of Batch F is accepted, the decision record must enumerate the
accepted verdict IDs; omitted verdicts remain Pending.

## 7. Evidence record

The final record must include:

- all four package hashes;
- all fifteen verdict IDs and dispositions;
- Product-owner identity and combined-role disclosure;
- explicit no-independence/no-qualified-review statement;
- retained statuses and non-authorizations;
- timestamp/timezone and repository commit;
- link to atomic reconciliation evidence.

## 8. Acceptance criteria

1. **D1-BE-ROLLUP-AC-01:** four exact package hashes are pinned.
2. **D1-BE-ROLLUP-AC-02:** verdict checksum is exactly fifteen.
3. **D1-BE-ROLLUP-AC-03:** all verdict IDs remain separately attributable.
4. **D1-BE-ROLLUP-AC-04:** no sixteenth aggregate verdict is created.
5. **D1-BE-ROLLUP-AC-05:** Batch B scopes remain unchanged.
6. **D1-BE-ROLLUP-AC-06:** Batch C scopes remain unchanged.
7. **D1-BE-ROLLUP-AC-07:** Batch D scopes remain unchanged.
8. **D1-BE-ROLLUP-AC-08:** Batch E scopes remain unchanged.
9. **D1-BE-ROLLUP-AC-09:** combined ownership does not create independence.
10. **D1-BE-ROLLUP-AC-10:** Product authority is not qualified Legal authority.
11. **D1-BE-ROLLUP-AC-11:** review routing is not a specialist verdict.
12. **D1-BE-ROLLUP-AC-12:** assignment routing fabricates no identity.
13. **D1-BE-ROLLUP-AC-13:** OD-10 remains Proposed.
14. **D1-BE-ROLLUP-AC-14:** BCK20-OD-02/05 remain Open.
15. **D1-BE-ROLLUP-AC-15:** OD-11 remains Open.
16. **D1-BE-ROLLUP-AC-16:** BCK05 decision statuses remain unchanged.
17. **D1-BE-ROLLUP-AC-17:** BCK04-OD-01/09 remain Proposed.
18. **D1-BE-ROLLUP-AC-18:** BCK-03/04/05/20 remain Draft.
19. **D1-BE-ROLLUP-AC-19:** BCK-01 remains Review.
20. **D1-BE-ROLLUP-AC-20:** D1/G1 remain Blocked.
21. **D1-BE-ROLLUP-AC-21:** R1 remains unauthorized.
22. **D1-BE-ROLLUP-AC-22:** all markets remain disabled.
23. **D1-BE-ROLLUP-AC-23:** partial acceptance is explicit by verdict ID.
24. **D1-BE-ROLLUP-AC-24:** changed package hash requires affected re-review.
25. **D1-BE-ROLLUP-AC-25:** no schema/runtime/cloud state is created.
26. **D1-BE-ROLLUP-AC-26:** Firebase, deployment, activation, push and merge remain unauthorized.

## 9. Current disposition

The roll-up is prepared. All fifteen verdicts remain Pending until an exact
Batch F owner decision is recorded.
