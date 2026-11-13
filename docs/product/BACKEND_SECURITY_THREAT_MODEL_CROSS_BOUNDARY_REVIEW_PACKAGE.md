# Recharge Backend — Threat Model Independent and Cross-Boundary Review Package

- ID: **BCK04-OD01-XREV-01**
- Version: **0.1**
- Date: **2026-09-16**
- Status: **Proposed — review package ready; every specialist verdict Pending**
- Exact review target: [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md)
- Parent specification: [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Technical owner decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- Runtime effect: **none**

## 1. Purpose and decision boundary

This package turns the remaining `BCK04-OD-01` review gate into explicit,
auditable work. It does not supply, infer or pre-approve any specialist
verdict. It is the single intake format for:

1. an independent Security/Privacy review of the complete threat model;
2. API, Operations, Identity and Mobile boundary confirmations;
3. confirmations from every affected domain represented in the threat
   register;
4. findings, amendments, re-review and final reconciliation evidence.

Document presence is not review completion. `BCK04-OD-01` remains Proposed
until the exact acceptance sequence in §10 is complete.

## 2. Frozen review input

Every reviewer evaluates the same immutable input:

| Item | Frozen value |
|---|---|
| Threat-model ID/version | `BCK04-OD01-TM-01 v0.2` |
| Assets | 12 (`A-01..A-12`) |
| Actors | 10 (`ACT-01..ACT-10`) |
| Trust boundaries | 12 (`TB-01..TB-12`) |
| Threats | 49 (`TM-01..TM-49`) |
| Priority checksum | Critical 20 / High 28 / Medium 1 |
| Current residual state | 49 `blocked`; 0 `acceptedResidual` |
| Product/cloud control evidence | target only; implemented/verified absent |
| Bounded runtime evidence | RAW-C local/emulator only; no cloud authority |

A reviewer must record the exact target version and checksum. A changed target,
missing threat, checksum mismatch or review against excerpts is Inconclusive.

## 3. Independence and reviewer identity

The independent Security/Privacy reviewer:

- is not the Product owner who issued `BCK04-OD01-DEC-01`;
- did not author the reviewed threat-model revision;
- declares organization/team, relevant competence and conflicts of interest;
- has access to the complete frozen input, not only this checklist;
- can return amendments, Reject or Inconclusive without delivery pressure.

Codex analysis, a Product-owner decision, document generation and a combined
owner self-review are not independent evidence. An internal reviewer may be
independent only when the separation above is recorded and credible.

Named cross-boundary reviewers must hold authority for their stated boundary.
One person may cover more than one role only when each role, authority basis
and verdict is recorded separately. Qualified Legal/Privacy conclusions remain
outside this technical package and are never inferred from a security verdict.

## 4. Required review matrix

| Sign-off ID | Required reviewer role | Scope | Initial status | Blocking condition |
|---|---|---|---|---|
| BCK04-OD01-SIG-SEC | Independent Security/Privacy | Full model, methodology, priority, controls, residuals and privacy misuse cases | Pending — unnamed | No OD-01 Acceptance without independent verdict |
| BCK04-OD01-SIG-API | API Platform | Schemas, authorization boundary, idempotency, events, minimum client and time semantics | Pending — unnamed | No protected API/runtime boundary |
| BCK04-OD01-SIG-OPS | Platform Operations | IAM, secrets, environments, backup/restore, resilience, cost and market isolation | Pending — unnamed | No provisioning, R1 or production operations |
| BCK04-OD01-SIG-ID | Identity | Authentication, grants, workspace/page scope, recovery, revocation and protected-result freshness | Pending — unnamed | No production Identity authority |
| BCK04-OD01-SIG-MOBILE | Mobile Platform | Untrusted-client boundary, typed failures, retry/unknown outcome, freshness and no offline authority | Pending — unnamed | No remote adapter or mobile cutover |
| BCK04-OD01-SIG-BOOKING | Booking domain | Atomicity, inventory, ledger, concurrency and reconciliation | Pending — unnamed | ECL-03 runtime remains gated |
| BCK04-OD01-SIG-ADMIN | Admin Operations | Case-bound access, dual control, audit, export and owning-domain repair | Pending — unnamed | No production admin mutation |
| BCK04-OD01-SIG-TRUST | Trust & Safety | Abuse, scraping, spam, rate strategy and kill switches | Pending — unnamed | No public abuse-sensitive cohort |
| BCK04-OD01-SIG-INT | Integrations | Webhooks, replay, egress, URL handling and provider isolation | Pending — unnamed | No provider activation |
| BCK04-OD01-SIG-MEDIA | Media Platform | Upload authorization, Storage boundary and hostile-file processing | Pending — unnamed | No production media pipeline |
| BCK04-OD01-SIG-REL | Release Operations | Supply chain, provenance, activation and rollback | Pending — unnamed | No R1/deployment authority |
| BCK04-OD01-SIG-REF | Reference Data/Localization | Policy revision, timezone and forbidden fallback behavior | Pending — unnamed | No affected market activation |
| BCK04-OD01-SIG-CONTENT | Content Platform | Public/private projections, deletion propagation and publication boundaries | Pending — unnamed | No authoritative publication boundary |
| BCK04-OD01-SIG-AI | AI Platform | Prompt/tool boundary and provider-specific addendum requirement | Pending — conditional, unnamed | AI surface stays disabled; addendum required before activation |

`BCK04-OD01-SIG-SEC`, API, OPS, ID and MOBILE are always required. Affected
domain rows are also required for the current model. The AI row may conclude
Inconclusive with the surface disabled; it cannot become an activation waiver.

## 5. Primary threat ownership coverage

Each threat appears exactly once below under its accountable owner. Reviewers
also evaluate cross-cutting threats named in their checklist.

| Primary review boundary | Threat IDs | Count |
|---|---|---:|
| Independent Security/Privacy | TM-03, TM-06, TM-16, TM-17, TM-19, TM-20, TM-28, TM-32, TM-35, TM-38, TM-39, TM-45, TM-47, TM-48 | 14 |
| API Platform | TM-08, TM-10, TM-11, TM-12, TM-30, TM-33 | 6 |
| Platform Operations | TM-07, TM-22, TM-23, TM-25, TM-26, TM-27, TM-44, TM-46 | 8 |
| Identity | TM-01, TM-02, TM-04, TM-21, TM-37, TM-49 | 6 |
| Booking | TM-09 | 1 |
| Admin Operations | TM-05, TM-34 | 2 |
| Trust & Safety | TM-18 | 1 |
| Integrations | TM-13, TM-14, TM-40, TM-41 | 4 |
| Media Platform | TM-15, TM-42 | 2 |
| Release Operations | TM-24, TM-36, TM-43 | 3 |
| Reference Data/Localization | TM-29 | 1 |
| AI Platform | TM-31 | 1 |
| **Checksum** | **TM-01..TM-49, no duplicates or omissions** | **49** |

Mobile and Content are cross-boundary confirmations rather than primary owners
in this checksum. Their sign-offs are still mandatory because the client and
projection behavior can violate controls owned elsewhere.

## 6. Review questions

### 6.1 Independent Security/Privacy

- Are assets, actors, boundaries, STRIDE/tags and priorities complete and
  internally consistent for the stated target architecture?
- Does every Critical/High path fail closed before executable evidence exists?
- Are AuthN, current AuthZ, least privilege, audit and privacy controls
  independent rather than circular?
- Can enumeration, inference, stale authorization, DSR replay or restored data
  expose another subject after revocation/deletion?
- Are any risks understated, missing, assigned to the wrong owner or carrying
  an invalid residual disposition?

### 6.2 API Platform

- Do closed schemas and result authorization prevent mass assignment and IDOR?
- Are attempt ID, logical idempotency, canonical hash and server receipt
  distinct where required?
- Are event replay, duplicate, gap, poison and crash-after-effect semantics
  explicit and authority-free?
- Do pagination, minimum-client and server time/timezone rules fail closed?

### 6.3 Platform and Release Operations

- Are IAM/service identities narrower than domain authority and separated by
  environment and market?
- Can secret rotation, restore, rollback or emergency recovery weaken another
  mandatory control?
- Are supply-chain provenance, same-artifact promotion and activation evidence
  independently verifiable?
- Do hot-key, fan-out, stampede, fairness and spend controls have a future
  executable owner and stop condition?

### 6.4 Identity

- Are provider identity, Recharge account, current session and capability
  revision separate and server-resolved?
- Do account linking, recovery, fixation, stuffing, suspension and revocation
  fail closed across personal and page workspaces?
- Are protected reads/results re-authorized after revocation and across
  pagination or out-of-order delivery?

### 6.5 Mobile

- Does the client remain untrusted for identity, role, capability, scope,
  time, price, inventory and completion state?
- Are timeout/cancel/unknown outcomes typed and reconciled without inventing
  success?
- Can stale cache, optimistic UI, offline data or deep links disclose protected
  data or confirm authoritative state?
- Is future remote cutover separately gated and reversible?

### 6.6 Affected domains

Each domain reviewer confirms:

- the named threat scenarios match its invariants and ownership boundary;
- target controls do not require direct writes into another aggregate;
- audit/reconciliation detects drift without silently repairing it;
- data minimization, retention/deletion and publication behavior are explicit;
- future executable evidence and stop/rollback conditions are testable;
- disabled provider, market or AI surfaces remain fail-closed.

Content additionally checks public/private projection and deletion propagation.
Trust & Safety checks abuse controls without treating App Check as authority.
Integration and Media reviewers check hostile ingress and isolated processing.

## 7. Findings register

Every finding uses a stable ID `BCK04-OD01-F-###` and records:

| Field | Required content |
|---|---|
| Reviewer/sign-off | exact sign-off ID and named reviewer |
| Target | exact threat-model version and checksum |
| Threat references | existing TM IDs or a proposed new stable TM ID |
| Priority | Critical / High / Medium / Low; rationale required |
| Finding | concrete contradiction, omission or ambiguity |
| Required amendment | exact normative change, owner and affected documents |
| Blocking scope | OD-01 only, named runtime gate, or both |
| Disposition | Open / Integrated / Rejected with rationale / Superseded |
| Verification | linkable re-review evidence against amended exact version |

Chat comments and generic approval are not the authoritative findings record.
No Open Critical/High finding is compatible with OD-01 Acceptance.

## 8. Allowed verdict vocabulary

Each sign-off uses exactly one verdict:

| Verdict | Meaning |
|---|---|
| `Accept design boundary with runtime controls` | No unresolved design contradiction in the reviewed scope; implementation and activation evidence remain required |
| `Accept with amendments` | Proposed amendments are required; verdict is not effective until integration and exact-version re-review |
| `Reject` | A blocking contradiction and replacement direction are recorded |
| `Inconclusive` | Evidence, authority, qualification or review scope is insufficient; row remains open |

`Pass`, `looks good`, document presence, Product-owner approval or automated
analysis is not a specialist verdict.

## 9. Required signature record

```text
Sign-off ID:
Reviewer role:
Named reviewer identity:
Organization/team:
Qualification or authority basis:
Independence/conflict disclosure:
Target: BCK04-OD01-TM-01 v0.2
Observed checksum: 12 assets / 10 actors / 12 boundaries / 49 threats
Verdict:
Accepted scope:
Threats sampled or reviewed:
Finding IDs:
Required amendments:
Runtime controls retained:
Date/timezone:
Evidence reference:
```

Missing identity, target, checksum, verdict, scope or evidence makes the row
Inconclusive. A signature may be cryptographic, repository-backed approval or
another attributable record accepted by project governance; plain copied text
without attributable evidence is insufficient.

## 10. Reconciliation and final decision sequence

1. Freeze and distribute exact threat-model v0.2 plus this package.
2. Record the independent Security/Privacy verdict and every required
   cross-boundary verdict without fabricating identities or qualifications.
3. Convert every amendment into stable finding IDs.
4. Integrate accepted findings into one new threat-model revision and update
   its checksum and affected specifications atomically.
5. Re-review every `Accept with amendments` row against that exact revision.
6. Confirm no unresolved contradiction and no Open Critical/High finding.
7. Keep Legal/Privacy qualification, OD-09, OD-11, D1/G1, runtime and
   production authorization as separate gates.
8. Only then prepare a distinct Product-owner decision for
   `BCK04-OD-01`; never infer it from this package or individual signatures.

If any required reviewer is unnamed, Inconclusive, Reject, or awaiting
amendment re-review, `BCK04-OD-01` remains Proposed.

## 11. Explicit non-authorizations

This package does not authorize or prove:

- BCK-04 Review/Accepted status or `BCK04-OD-01` Acceptance;
- independent Security/Privacy, qualified Legal/Privacy or domain approval;
- implemented/verified controls, penetration testing or production readiness;
- G1-G7, R1, ECL-03D-H or any other stage transition;
- runtime, Firebase changes, credentials, cloud resources or data processing;
- deployment, activation, push or merge.

## 12. Acceptance criteria

1. **BCK04-OD01-XREV-AC-01:** the package freezes exact threat-model v0.2.
2. **BCK04-OD01-XREV-AC-02:** the frozen checksum matches the target.
3. **BCK04-OD01-XREV-AC-03:** independent review requirements are explicit.
4. **BCK04-OD01-XREV-AC-04:** Product/Codex/self-review is not independence.
5. **BCK04-OD01-XREV-AC-05:** every reviewer identity and authority is recorded.
6. **BCK04-OD01-XREV-AC-06:** Security, API, Operations, Identity and Mobile
   confirmations are mandatory.
7. **BCK04-OD01-XREV-AC-07:** affected-domain confirmations are explicit.
8. **BCK04-OD01-XREV-AC-08:** all 49 threats have one primary review boundary.
9. **BCK04-OD01-XREV-AC-09:** Mobile and Content cross-cutting scope is retained.
10. **BCK04-OD01-XREV-AC-10:** future AI remains disabled and addendum-gated.
11. **BCK04-OD01-XREV-AC-11:** findings receive stable IDs and owners.
12. **BCK04-OD01-XREV-AC-12:** Critical/High findings block Acceptance.
13. **BCK04-OD01-XREV-AC-13:** verdict vocabulary is closed and typed.
14. **BCK04-OD01-XREV-AC-14:** amendment verdicts require exact-version re-review.
15. **BCK04-OD01-XREV-AC-15:** missing signature fields are Inconclusive.
16. **BCK04-OD01-XREV-AC-16:** reviewers cannot silently change the frozen target.
17. **BCK04-OD01-XREV-AC-17:** Legal, OD-09 and OD-11 remain separate gates.
18. **BCK04-OD01-XREV-AC-18:** D1/G1 and executable stages are not advanced.
19. **BCK04-OD01-XREV-AC-19:** OD-01 requires a later distinct owner decision.
20. **BCK04-OD01-XREV-AC-20:** unassigned/Pending rows remain visible blockers.
21. **BCK04-OD01-XREV-AC-21:** document presence is not review completion.
22. **BCK04-OD01-XREV-AC-22:** no runtime, Firebase, deployment, push or merge
    authority is created.

## 13. Current result and next action

The review mechanism is ready. No reviewer identity, specialist verdict or
independent evidence has been recorded. All fourteen sign-off rows are Pending,
so `BCK04-OD-01` remains Proposed.

Next action: assign the independent Security/Privacy reviewer first, record
their attributable review against exact v0.2, and then collect the named
cross-boundary confirmations. Do not pre-fill verdicts on their behalf.
