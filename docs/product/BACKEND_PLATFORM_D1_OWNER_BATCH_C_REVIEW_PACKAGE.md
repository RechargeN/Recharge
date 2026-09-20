# Recharge Backend — D1 Owner Batch C Review Package

- Package ID: **BCK-D1-OWN-C-REV-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Proposed — one owner action may record three separate bounded verdicts**
- Mandatory-copy review: [BCK20-OD05-POL-REV-01 v0.1](REFERENCE_DATA_MANDATORY_COPY_POLICY_REVIEW.md)
- Mandatory-copy review normalized-LF SHA-256:
  `3ed8d605c8771602f15091c91e4a8b83dda5b549f6ae80f8326c7c135f09d328`
- External-review handoff: [BCK-D1-XREV-HANDOFF-01 v0.1](BACKEND_PLATFORM_D1_EXTERNAL_REVIEW_HANDOFF.md)
- Handoff normalized-LF SHA-256:
  `4bca4d90695cb739a36841aa3041f8fee1a79834814437d3cea03b6fe007ba50`
- D1/G1 closure matrix: [BCK-D1-G1-CLOSE-01 v0.1](BACKEND_PLATFORM_D1_G1_CLOSURE_MATRIX.md)
- Closure matrix normalized-LF SHA-256:
  `eb9ad286e3089887fb48cabe84cdcd4f728a2a0db985393e0a120f88ba748d2f`
- Owner/signatory requested: **RechargeN / Product owner**
- Technical preparer: **OpenAI Codex — evidence preparation only, not a signatory**
- Independence: **none**
- Qualified Legal/Privacy/terms claim: **none**
- Runtime effect: **none**

---

## 1. Purpose

Batch C combines three documentation decisions that can be made safely without
impersonating an external reviewer:

1. `BCK20-OD05-SIG-PRODUCT` — accept the mandatory-copy Product/technical
   classification and fail-closed boundary;
2. `D1-XREV-HANDOFF-SIG-OWNER` — accept the four-lane external-review handoff
   as complete routing input;
3. `D1-G1-CLOSE-SIG-OWNER` — accept the current D1/G1 matrix as the factual
   blocked-state baseline.

These verdicts remain separate. They do not accept BCK20-OD-05, provide an
external verdict, complete D1 or pass G1.

## 2. Why these decisions can share one batch

- Mandatory-copy classification defines the exact Product questions that a
  qualified reviewer must answer.
- The handoff routes that question together with source terms, OD-11 and
  independent security review without merging reviewer authority.
- The closure matrix records how those missing verdicts block D1/G1 and
  separates pre-G1 decisions from later R1 execution evidence.

All three are exact-hash, documentation-only and fail-closed. Accepting them
reduces review ambiguity without changing any operational status.

## 3. Verdict matrix

| Verdict ID | Recommended verdict | Accepted scope | Explicitly not accepted |
|---|---|---|---|
| `BCK20-OD05-SIG-PRODUCT` | Accept Product design boundary with retained qualified/executable gates | copy classes, policy-record boundary, typed outcomes, fail-closed defaults and qualified matrix template | actual Legal sufficiency, locales, copy, BCK20-OD-05 Acceptance |
| `D1-XREV-HANDOFF-SIG-OWNER` | Accept review-routing baseline with retained external verdict gates | four lanes, reviewer eligibility, record envelope, reconciliation order and evidence handling | reviewer identity, qualification, verdict, certification or approval |
| `D1-G1-CLOSE-SIG-OWNER` | Accept factual closure baseline with blocked verdict | current requirement/status/gap mapping and work order | D1 exit, G1 Pass, BCK/OD promotion or R1 authority |

## 4. Batch-wide retained gates

After owner acceptance:

- Batch B remains separately Pending unless independently accepted;
- BCK20-OD-05 remains **Open**;
- OD-10 remains **Proposed**;
- OD-11 remains **Open**;
- BCK04-OD-01 remains **Proposed**;
- BCK-03/04/05/20 remain **Draft** and BCK-01 **Review**;
- D1 exit and G1 remain **Blocked**;
- named qualified Legal/Privacy/terms reviewers remain required;
- independent Security/Privacy and cross-boundary verdicts remain required;
- no source enters `eligible_for_slice_review`;
- all markets remain disabled;
- schema, fixtures, datasets, parser, IAM/runtime, Firebase, deployment,
  activation, push and merge remain unauthorized.

## 5. Exact owner response

```text
Одобряю BCK-D1-OWN-C-REV-01 v0.1 для точных документов:
BCK20-OD05-POL-REV-01 v0.1 / normalized-LF SHA-256
3ed8d605c8771602f15091c91e4a8b83dda5b549f6ae80f8326c7c135f09d328,
BCK-D1-XREV-HANDOFF-01 v0.1 / normalized-LF SHA-256
4bca4d90695cb739a36841aa3041f8fee1a79834814437d3cea03b6fe007ba50
и BCK-D1-G1-CLOSE-01 v0.1 / normalized-LF SHA-256
eb9ad286e3089887fb48cabe84cdcd4f728a2a0db985393e0a120f88ba748d2f.

Принимаю три раздельных bounded verdict:
BCK20-OD05-SIG-PRODUCT — Accept Product design boundary with retained
qualified/executable gates;
D1-XREV-HANDOFF-SIG-OWNER — Accept review-routing baseline with retained
external verdict gates;
D1-G1-CLOSE-SIG-OWNER — Accept factual closure baseline with blocked verdict.

Не заявляю qualified Legal/Privacy/terms verdict, independent review или
specialist certification. BCK20-OD-05 остаётся Open; OD-10 Proposed; OD-11
Open; BCK04-OD-01 Proposed; BCK-03/04/05/20 Draft; BCK-01 Review; D1/G1
Blocked. Batch B остаётся отдельно Pending. Разрешаю только docs-only
reconciliation и один локальный коммит. Network, terms acceptance, schema,
fixtures, datasets, parser, runtime, Firebase, deployment, activation, push и
merge не разрешаю.
```

## 6. Permitted reconciliation after acceptance

One docs-only reconciliation may:

1. create an immutable Batch C owner-decision record;
2. record `BCK20-OD05-SIG-PRODUCT` without closing BCK20-OD-05;
3. mark the external handoff as owner-accepted routing input while every lane
   remains Pending;
4. mark the D1/G1 closure matrix as the accepted factual blocked baseline;
5. update BCK-01/02/04/20, D1 workbook/ledger/review and Launch Status;
6. append stable AC numbers without renumbering earlier criteria;
7. create one local docs-only commit.

No external verdict may be prefilled or inferred during reconciliation.

## 7. Remaining work after Batch C

### Can proceed in parallel

- qualified source terms/access review;
- qualified Latvia mandatory-copy review;
- qualified age/eligibility review;
- independent threat-model review and technical cross-boundary confirmations;
- Batch B owner decision, if accepted separately.

### Must remain sequential after results

1. integrate findings and re-review changed exact versions;
2. issue per-source and Legal/Product decisions;
3. decide OD-11 to at least Proposed and OD-10 to Accepted only with evidence;
4. decide BCK-03/04/05/20 Approval individually;
5. decide BCK-01 Approval and D1 exit;
6. decide G1 separately;
7. only then prepare an Approved R1 slice.

## 8. Invalidation and rollback

- Changed input hash invalidates the affected Batch C verdict until explicit
  impact review.
- A later qualified/independent finding may narrow or reject this design; it
  cannot silently broaden scope.
- Before acceptance, preparation is rolled back by reverting/deleting only the
  Batch C documentation commit.
- After acceptance, preserve decision history and supersede by a new revision
  rather than editing the recorded owner statement.

## 9. Acceptance criteria

1. **BCK-D1-OWN-C-AC-01:** all three inputs are frozen by exact normalized hash.
2. **BCK-D1-OWN-C-AC-02:** three verdict IDs remain separate.
3. **BCK-D1-OWN-C-AC-03:** Codex is not a signatory.
4. **BCK-D1-OWN-C-AC-04:** Product copy classification is not qualified Legal advice.
5. **BCK-D1-OWN-C-AC-05:** handoff completeness does not create reviewer identity or verdict.
6. **BCK-D1-OWN-C-AC-06:** closure-matrix acceptance preserves D1/G1 Blocked.
7. **BCK-D1-OWN-C-AC-07:** Batch B remains separately Pending.
8. **BCK-D1-OWN-C-AC-08:** BCK20-OD-05 remains Open.
9. **BCK-D1-OWN-C-AC-09:** OD-10 remains Proposed and OD-11 Open.
10. **BCK-D1-OWN-C-AC-10:** BCK04-OD-01 remains Proposed.
11. **BCK-D1-OWN-C-AC-11:** BCK-03/04/05/20 remain Draft and BCK-01 Review.
12. **BCK-D1-OWN-C-AC-12:** D1 exit and G1 remain separate and blocked.
13. **BCK-D1-OWN-C-AC-13:** no source becomes eligible for slice review.
14. **BCK-D1-OWN-C-AC-14:** all markets remain disabled.
15. **BCK-D1-OWN-C-AC-15:** external lanes may run in parallel without merging authority.
16. **BCK-D1-OWN-C-AC-16:** later findings require integration and exact re-review.
17. **BCK-D1-OWN-C-AC-17:** reconciliation appends stable AC numbers.
18. **BCK-D1-OWN-C-AC-18:** owner acceptance permits one local docs-only commit.
19. **BCK-D1-OWN-C-AC-19:** no schema, fixture, dataset, parser or runtime authority is created.
20. **BCK-D1-OWN-C-AC-20:** network, terms acceptance, Firebase, deployment, push and merge remain unauthorized.

## 10. Current disposition

Batch C is prepared. Until the exact owner response is recorded, all three
verdicts remain Pending and canonical statuses remain unchanged.
