# Recharge Backend — D1 External Review Handoff

- Handoff ID: **BCK-D1-XREV-HANDOFF-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Proposed — review inputs consolidated; external verdicts absent**
- Coordination owner: **RechargeN / Product owner**
- Independence: **not created by this document**
- Qualified Legal/Privacy claim: **none**
- Runtime effect: **none**

Frozen review lanes:

| Lane | Exact input | Normalized-LF SHA-256 |
|---|---|---|
| External-source terms/access | [BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01 v0.1](REFERENCE_DATA_EXT_A_D_QUALIFIED_TERMS_ACCESS_REVIEW.md) | `214d6c0dec67b379bfba836ba1c6089e03b14b3fddaf4f38d55be03af41b081b` |
| Mandatory Legal/safety copy | [BCK20-OD05-POL-REV-01 v0.1](REFERENCE_DATA_MANDATORY_COPY_POLICY_REVIEW.md) | `3ed8d605c8771602f15091c91e4a8b83dda5b549f6ae80f8326c7c135f09d328` |
| Minors/age eligibility | [BCK-D1-OD11-LEGAL-01 v0.1](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md) | `307a69964793fa37494f1ca1a7b59b1c49dd59b0a777e95a2932005ae0a44ee8` |
| Threat model and cross-boundary security | [BCK04-OD01-XREV-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_CROSS_BOUNDARY_REVIEW_PACKAGE.md) | `606843d77294a14458531cbef57f6cf51cc541156f61816cac66cd8ab0f6923a` |
| Security/privacy baseline | [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md) | `2b1010edb3c9d97f6e14864ac7454b5f6df517d4d041608114b5822befc97a20` |

---

## 1. Purpose

This handoff converts the remaining external D1 dependencies into four
bounded review lanes with exact inputs, reviewer requirements, outputs and
reconciliation rules. It is a routing and completeness artifact. It does not
perform any review, name a fictional specialist, accept terms, give legal
advice or create independence.

The lanes may run in parallel. Their verdicts remain separate because a
license/terms reviewer, market Legal/Privacy reviewer and independent
Security/Privacy reviewer answer different questions.

## 2. Reviewer eligibility

### 2.1 Qualified terms/access reviewer

Must be able to evaluate the intended commercial use, storage, parsing,
derived facts, redistribution, notices, automated refresh, withdrawal and
account/license conditions for the exact captured evidence. The record must
name the reviewer, capacity, jurisdiction/use assumptions and conflicts.

### 2.2 Qualified market Legal/Privacy reviewer

Must be competent for the relevant Latvia launch question and explicitly state
any EU-level versus Latvia-specific boundary. Estonia and Lithuania require
separate later scope. Product-owner preference, Codex analysis and generic web
summaries are not qualified verdicts.

### 2.3 Independent Security/Privacy reviewer

Must satisfy the independence requirements of BCK04-OD01-XREV-01: not the
owner who accepted the technical model, not its author, complete-input access,
recorded competence/conflicts and freedom to return amendments, Reject or
Inconclusive.

### 2.4 Cross-boundary technical reviewers

API, Operations, Identity, Mobile and affected domain reviewers must hold
authority for the reviewed boundary. Combined roles are disclosed separately
and do not substitute for the independent Security/Privacy lane.

## 3. Lane A — source terms and access

### Required output

One completed `QualifiedTermsAccessVerdict` per applicable source ID,
containing all ten determinations from the frozen package plus controls,
prohibited uses, open questions and re-review triggers.

### Current sources

- IANA Language Subtag Registry;
- IANA TZDB;
- Unicode CLDR;
- UN M49;
- European Commission euro evidence;
- ISO 3166;
- direct ISO 4217;
- SIX 4217 maintenance lists.

### Fail-closed rules

- ISO sources remain Blocked when exact lawful artifact/terms are unavailable;
- SIX remains Inconclusive until current terms/access are reviewed;
- a positive terms verdict does not approve a source;
- no source enters `eligible_for_slice_review` without a later owner decision;
- changed terms, source URI, version, scope or intended use triggers re-review.

## 4. Lane B — mandatory copy and market policy

### Required output

For every intended Latvia launch surface and purpose, complete the exact matrix
from BCK20-OD05-POL-REV-01:

- copy class and rationale;
- required locales;
- fallback rule;
- acknowledgement mode;
- effective/expiry rule;
- retention and lawful exceptions;
- withdrawal/correction behavior;
- accessibility/support route;
- exact reviewer and immutable approval reference.

### Fail-closed rules

- blank or conditional rows remain Pending;
- missing mandatory copy disables the affected surface/action;
- informational fallback is not authoritative acceptance evidence;
- Estonia/Lithuania cannot inherit Latvia's matrix;
- Product acceptance of the taxonomy is not Legal approval of copy.

## 5. Lane C — minors and age eligibility

### Required output

The qualified record must keep distinct:

- legal capacity/consent questions;
- product minimum-account age;
- Find People eligibility and safety controls;
- content creation/publication eligibility;
- Booking/event/provider restrictions;
- guardian/parental-consent mechanics if applicable;
- verification/data-minimization/retention requirements;
- market-specific differences and re-review triggers.

Until a concrete policy is accepted, OD-11 remains Open and affected
age-restricted behavior fails closed. No age rule is inferred from provider
authentication, device data or another feature.

## 6. Lane D — independent security and cross-boundary review

### Required output

- independent full threat-model verdict;
- API, Operations, Identity and Mobile confirmations;
- affected-domain confirmations listed by BCK04-OD01-XREV-01;
- stable finding IDs for every amendment;
- integration into one new exact threat-model revision when required;
- exact-version re-review of all `Accept with amendments` rows;
- confirmation that no Open Critical/High finding remains before OD-01
  Acceptance.

This lane does not close qualified Legal/Privacy decisions, incident tabletop,
runtime controls or deployment gates.

## 7. Common review record envelope

Every external record must contain:

```text
ExternalReviewRecord {
  reviewLaneId
  signOffId
  exactInputIdsAndHashes[]
  reviewerName
  organizationOrTeam
  roleAndQualificationBasis
  independenceAndConflictDisclosure
  jurisdictionAndScopeAssumptions[]
  verdict
  acceptedScope[]
  findings[]
  requiredAmendments[]
  retainedGates[]
  reReviewTriggers[]
  reviewedAtUtc
  attributableEvidenceRef
}
```

Missing identity, scope, exact hash, verdict, qualification/authority basis or
attributable evidence makes the record Inconclusive.

## 8. Verdict vocabulary

| Verdict | Meaning |
|---|---|
| `accept_with_controls` | reviewed scope is acceptable only with enumerated controls and retained gates |
| `accept_with_amendments` | amendments are mandatory; verdict is ineffective until integration and exact re-review |
| `not_allowed` | intended use/policy is rejected for the stated scope |
| `reject` | technical/security boundary is unacceptable and replacement direction is required |
| `inconclusive` | evidence, authority, qualification or scope is insufficient |
| `blocked_by_unavailable_evidence` | required authoritative artifact/terms/input cannot be reviewed |

`Looks good`, document presence, copied chat text or Product-owner approval is
not an external verdict.

## 9. Reconciliation order

1. Freeze exact inputs and distribute the appropriate lane, not the entire
   repository by default.
2. Record reviewer identity, qualification/authority and conflict disclosure.
3. Record verdicts without changing canonical status.
4. Convert amendments into stable findings and assign owners.
5. Integrate accepted amendments into new exact document revisions.
6. Re-review affected `accept_with_amendments` records against the new hashes.
7. Record Product-owner decisions only after the qualified/independent inputs
   exist.
8. Update BCK-01/02/04/20, D1 ledger/review and Launch Status atomically.
9. Run the D1 exit matrix; do not infer G1.
10. Prepare a distinct G1 decision only when every mandatory D1 item passes or
    is explicitly deferred without bypassing its later gate.

## 10. Data handling and disclosure

- Share only the minimum evidence necessary for the lane.
- Do not place temporary third-party source bodies in Git.
- Redact credentials, tokens, personal data and unrelated business data.
- Preserve exact hashes and retrieval identities without copying protected
  source text into review records.
- Store reviewer contact/signature evidence according to an accepted access
  and retention policy.
- Do not publicly claim legal advice, certification or independent audit
  beyond the exact attributable record.

## 11. Completion matrix

| Lane | Input ready | Named eligible reviewer | Verdict | Amendments integrated/re-reviewed | Current state |
|---|---:|---:|---:|---:|---|
| A — terms/access | Yes | No | No | N/A | Pending |
| B — mandatory copy | Yes | No | No | N/A | Pending |
| C — minors/age | Yes | No | No | N/A | Pending |
| D — security/cross-boundary | Yes | No | No | No | Pending |

Document readiness is complete only for routing. Review completion is 0/4.

## 12. Retained gates

- Batch B verdicts remain Pending until separately accepted;
- BCK20-OD-02/05 remain Open, OD-10 Proposed and OD-11 Open;
- BCK04-OD-01 remains Proposed and BCK-04 Draft;
- BCK-20 remains Draft;
- D1/G1 remain incomplete;
- all markets remain disabled;
- source eligibility, Legal policy and independent evidence remain absent;
- schema, fixtures, datasets, parser, IAM/runtime, Firebase, deployment,
  activation, push and merge remain unauthorized.

## 13. Acceptance criteria

1. **BCK-D1-XREV-HANDOFF-AC-01:** all five inputs are frozen by exact normalized hash.
2. **BCK-D1-XREV-HANDOFF-AC-02:** four external review lanes remain separate.
3. **BCK-D1-XREV-HANDOFF-AC-03:** document preparation creates no reviewer identity or verdict.
4. **BCK-D1-XREV-HANDOFF-AC-04:** Product-owner authority is not represented as qualified Legal advice.
5. **BCK-D1-XREV-HANDOFF-AC-05:** combined technical roles do not create independent security review.
6. **BCK-D1-XREV-HANDOFF-AC-06:** source terms verdicts are per source and intended use.
7. **BCK-D1-XREV-HANDOFF-AC-07:** positive terms review does not approve source ingestion.
8. **BCK-D1-XREV-HANDOFF-AC-08:** mandatory-copy decisions are market/surface/purpose scoped.
9. **BCK-D1-XREV-HANDOFF-AC-09:** OD-11 remains Open until concrete qualified/product decisions exist.
10. **BCK-D1-XREV-HANDOFF-AC-10:** independent threat review uses the complete exact target.
11. **BCK-D1-XREV-HANDOFF-AC-11:** every amendment has a stable finding and exact re-review path.
12. **BCK-D1-XREV-HANDOFF-AC-12:** missing reviewer identity/hash/scope/verdict is Inconclusive.
13. **BCK-D1-XREV-HANDOFF-AC-13:** review lanes may run in parallel without merging verdicts.
14. **BCK-D1-XREV-HANDOFF-AC-14:** temporary third-party bodies remain outside Git.
15. **BCK-D1-XREV-HANDOFF-AC-15:** credentials and personal data are excluded from handoff evidence.
16. **BCK-D1-XREV-HANDOFF-AC-16:** canonical status changes only after attributable verdict reconciliation.
17. **BCK-D1-XREV-HANDOFF-AC-17:** D1 exit and G1 decision remain separate.
18. **BCK-D1-XREV-HANDOFF-AC-18:** all markets remain disabled.
19. **BCK-D1-XREV-HANDOFF-AC-19:** no external source becomes eligible from handoff preparation.
20. **BCK-D1-XREV-HANDOFF-AC-20:** no Legal, security or compliance certification is claimed.
21. **BCK-D1-XREV-HANDOFF-AC-21:** no schema, fixture, dataset, parser or runtime authority is created.
22. **BCK-D1-XREV-HANDOFF-AC-22:** Firebase, deployment, activation, push and merge remain unauthorized.

## 14. Next action

Freeze this handoff by normalized-LF SHA-256. The Product owner may accept it
only as the complete routing baseline. Then assign real eligible reviewers to
the four lanes. Do not prefill their verdicts, qualifications, dates or
signatures.
