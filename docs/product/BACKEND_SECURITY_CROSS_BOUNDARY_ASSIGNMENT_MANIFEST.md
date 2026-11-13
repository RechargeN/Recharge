# Recharge Backend — Security Cross-Boundary Assignment Manifest

- Manifest ID: **BCK04-OD01-XASSIGN-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared — 0/14 reviewers assigned, 0/14 verdicts recorded**
- Runtime status: **N/A; review-routing artifact**
- Target package: [BCK04-OD01-XREV-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_CROSS_BOUNDARY_REVIEW_PACKAGE.md)
- Target-package normalized-LF SHA-256: `606843d77294a14458531cbef57f6cf51cc541156f61816cac66cd8ab0f6923a`
- Threat model: [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md)
- Threat-model normalized-LF SHA-256: `62ac1b79e3736c22a3e195f214aca28106635c23d45012e0b312c787b54ce297`
- Runtime effect: **none**

## 1. Purpose

The cross-boundary review package defines what reviewers must inspect. This
manifest defines assignment, due-state, evidence and completion bookkeeping
without pre-filling identities or verdicts.

It is not evidence that any reviewer exists, is independent, is qualified or
has completed review.

## 2. Assignment contract

Each assignment must record:

- sign-off ID and exact role;
- named human reviewer;
- organization/team and authority basis;
- independence/conflict disclosure;
- exact target versions/hashes;
- accepted review scope;
- target date and status;
- secure evidence location;
- reassignment/withdrawal history.

Aliases such as “team”, “owner”, “Codex” or “TBD” do not satisfy assignment.

## 3. Assignment ledger

| Sign-off | Role | Required | Assignment | Verdict | Blocking state |
|---|---|---:|---|---|---|
| BCK04-OD01-SIG-SEC | independent Security/Privacy | yes | Unassigned | Pending | blocks OD-01 |
| BCK04-OD01-SIG-API | API Platform | yes | Unassigned | Pending | blocks protected API boundary |
| BCK04-OD01-SIG-OPS | Platform Operations | yes | Unassigned | Pending | blocks provisioning/R1 |
| BCK04-OD01-SIG-ID | Identity | yes | Unassigned | Pending | blocks production Identity |
| BCK04-OD01-SIG-MOBILE | Mobile Platform | yes | Unassigned | Pending | blocks remote adapter/cutover |
| BCK04-OD01-SIG-BOOKING | Booking | yes | Unassigned | Pending | blocks ECL-03 runtime |
| BCK04-OD01-SIG-ADMIN | Admin Operations | yes | Unassigned | Pending | blocks production admin mutation |
| BCK04-OD01-SIG-TRUST | Trust & Safety | yes | Unassigned | Pending | blocks abuse-sensitive cohort |
| BCK04-OD01-SIG-INT | Integrations | yes | Unassigned | Pending | blocks provider activation |
| BCK04-OD01-SIG-MEDIA | Media Platform | yes | Unassigned | Pending | blocks media pipeline |
| BCK04-OD01-SIG-REL | Release Operations | yes | Unassigned | Pending | blocks deployment authority |
| BCK04-OD01-SIG-REF | Reference Data/Localization | yes | Unassigned | Pending | blocks affected market activation |
| BCK04-OD01-SIG-CONTENT | Content Platform | yes | Unassigned | Pending | blocks authoritative publication |
| BCK04-OD01-SIG-AI | AI Platform | conditional; disabled surface still reviewed | Unassigned | Pending | AI remains disabled |

## 4. Routing waves

| Wave | Reviewers | Entry | Exit |
|---|---|---|---|
| X1 | independent Security/Privacy | exact complete target, independence recorded | attributable verdict/findings |
| X2 | API, Operations, Identity, Mobile | X1 findings available; target unchanged or re-frozen | four separate verdicts |
| X3 | Booking, Admin, Trust, Integrations, Media, Release, Reference, Content, AI | prior findings available | nine separate verdicts or explicit Inconclusive/disabled result |
| X4 | reconciliation | all findings collected | amendments integrated and affected re-reviews complete |

Waves may overlap only when every reviewer sees the same frozen target and
later findings cannot invalidate unseen scope. Speed never permits merged
verdicts or hidden amendments.

## 5. Status vocabulary

Assignment: `Unassigned`, `Assigned`, `Withdrawn`, `Reassigned`.

Review: `Pending`, `InReview`, `AmendmentsRequired`, `Accepted`, `Rejected`,
`Inconclusive`, `Superseded`.

Only an attributable exact-target record may change review status.

## 6. Findings and re-review

Every finding receives a stable ID, priority, target threat/control, owner,
required amendment, blocking scope and verification path. Open Critical/High
findings block OD-01. Any changed threat/control requires affected exact-version
re-review; old verdicts remain historical evidence only.

## 7. Combined-role and independence rules

- RechargeN/Product owner may coordinate but does not satisfy a specialist row
  merely by assigning themselves.
- One human may cover several non-independent roles only with a separate record
  and verdict per role.
- The independent Security/Privacy reviewer cannot be the author or approving
  Product owner for the frozen target.
- Qualified Legal/Privacy is a separate lane and is not inferred here.
- Codex may prepare/check artifacts but is not the human specialist signature.

## 8. Evidence hygiene

Review evidence must not contain credentials, production personal data,
unredacted vulnerability exploit details in public Git or copied proprietary
reports. Sensitive evidence uses an access-controlled reference plus a safe
repository summary and checksum where policy permits.

## 9. Completion rule

The manifest is complete only when all mandatory rows have attributable final
verdicts against the same final target, every required amendment is integrated
and re-reviewed, and no blocking finding remains. Completion still does not
accept OD-01; a distinct owner decision is required.

## 10. Acceptance criteria

1. **BCK04-XASSIGN-AC-01:** package and threat-model targets are hash-pinned.
2. **BCK04-XASSIGN-AC-02:** fourteen sign-off rows are explicit.
3. **BCK04-XASSIGN-AC-03:** no reviewer identity is fabricated.
4. **BCK04-XASSIGN-AC-04:** no verdict is pre-filled.
5. **BCK04-XASSIGN-AC-05:** coordination is not specialist authority.
6. **BCK04-XASSIGN-AC-06:** independence is separately evidenced.
7. **BCK04-XASSIGN-AC-07:** each role receives a separate verdict.
8. **BCK04-XASSIGN-AC-08:** qualified Legal/Privacy remains separate.
9. **BCK04-XASSIGN-AC-09:** waves preserve one frozen target.
10. **BCK04-XASSIGN-AC-10:** findings have stable IDs and owners.
11. **BCK04-XASSIGN-AC-11:** Critical/High findings block OD-01.
12. **BCK04-XASSIGN-AC-12:** amendments require affected re-review.
13. **BCK04-XASSIGN-AC-13:** missing evidence is Inconclusive.
14. **BCK04-XASSIGN-AC-14:** AI remains disabled without its addendum/gates.
15. **BCK04-XASSIGN-AC-15:** sensitive evidence is not exposed in public Git.
16. **BCK04-XASSIGN-AC-16:** manifest completion does not accept OD-01.
17. **BCK04-XASSIGN-AC-17:** BCK-04 remains Draft.
18. **BCK04-XASSIGN-AC-18:** D1/G1 remain separate blocked gates.
19. **BCK04-XASSIGN-AC-19:** no runtime/cloud authority is created.
20. **BCK04-XASSIGN-AC-20:** Firebase, deployment, push and merge remain unauthorized.

## 11. Current disposition

The manifest is prepared with 0/14 assignments and 0/14 verdicts. The threat
model remains unchanged and BCK04-OD-01 remains Proposed.
