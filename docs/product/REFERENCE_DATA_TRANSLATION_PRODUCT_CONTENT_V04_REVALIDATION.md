# BCK-20 — Translation Product/Content v0.4 Revalidation

- ID: **BCK20-OD02-PC-REVAL-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — owner verdict required through consolidated package**
- Exact target: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Historical v0.3 decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Correction decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Proposed sign-offs: **BCK20-OD02-SIG-L10N + BCK20-OD02-SIG-CONTENT**
- Proposed reviewer: **RechargeN / Product owner**
- Combined roles: **interim Product Localization owner + interim Content/source-governance owner**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; combined-owner technical revalidation**
- Legal qualification: **not claimed**
- Runtime effect: **none**

## 1. Revalidation outcome

> **Revalidate both prior bounded verdicts as Accept design boundary with
> retained gates for the exact workflow v0.4 hash.**

Workflow v0.4 changes Mobile/Security consumption and authority controls. It
does not weaken or replace source meaning, translation classes, glossary,
review depth, qualified Legal authority, market isolation or provider gates.
The two verdicts remain separate even though one owner performs both reviews.
They are not effective until the consolidated owner decision is recorded.

## 2. Frozen-input verification

| Input | Observed state | Result |
|---|---|---|
| Workflow identity | `BCK20-OD02-L10N-01 v0.4` | Match |
| Normalized-LF SHA-256 | `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975` | Match |
| Workflow AC | AC-01–62 sequential | Match |
| Prior exact target | v0.3 / `f244b00b…14309` | Historical only |
| New correction scope | MS-F-001–MS-F-007 | Fully dispositioned below |
| Source-authority values | absent | Retained fail-closed gate |
| Qualified Legal evidence | absent | Retained gate |

Any target version/hash change invalidates this revalidation.

## 3. Amendment impact disposition

| Amendment | Product Localization disposition | Content disposition | Reason / retained gate |
|---|---|---|---|
| MS-F-001 render profile | Accept | Accept | makes format interpretation revision-bound; does not change approved meaning |
| MS-F-002 atomic install | Accept | Accept | prevents mixed copy revisions; distribution mechanics remain BCK20-OD-03 |
| MS-F-003 monotonic invalidation | Accept | Accept | strengthens withdrawal/correction and prevents unsafe resurrection |
| MS-F-004 actor authority | Accept | Accept | strengthens role enforcement and attribution without changing role ownership |
| MS-F-005 artifact inventory | Accept with retained gate | Accept with retained gate | conservative classification added; exact Legal/retention/processor facts remain absent |
| MS-F-006 integrity/origin split | Accept | Accept | prevents wrong-origin content from becoming authoritative; exact mechanism remains gated |
| MS-F-007 safe rendering | Accept | Accept | strengthens structural fidelity, links and Unicode/markup controls without permitting semantic truncation |

No amendment lowers review depth, permits fallback, changes stable IDs, fills
source-authority values, selects a provider or supplies qualified Legal
approval.

## 4. Prior checklist and vector continuity

| Evidence group | v0.4 disposition |
|---|---|
| Product Localization checklist 1–12 | Revalidated with the same retained provider/authority gates |
| Content/source-governance checklist 1–12 | Revalidated with source-authority matrix values still absent |
| PC-V01/V04/V05 — identity and impact | Revalidated; new render/invalidation revisions strengthen exact identity |
| PC-V02/V03 — long/structured text | Revalidated; safe render profile strengthens, never permits meaning loss |
| PC-V06 — policy conflict | Unchanged; accountable owners must reconcile |
| PC-V07/V09/V10 — revoke/withdraw/rollback | Revalidated with monotonic resolution precedence |
| PC-V08 — publication conflict | Unchanged; manifest intent/receipt reconciliation preserved |
| PC-V11 — provider deletion | Unchanged; unconfirmed deletion remains typed escalation |
| PC-V12 — EE/LT isolation | Unchanged; disabled markets cannot inherit Latvia evidence |
| PC-V13 — user-authored content | Unchanged and separately gated |
| PC-V14 — provider-disabled path | Unchanged; human/offline route remains required |

## 5. Retained observations

| ID | Observation | Required treatment |
|---|---|---|
| BCK20-OD02-PC-REVAL-O-01 | one owner combines Product Localization and Content | preserve non-independence disclosure and separate verdict IDs |
| BCK20-OD02-PC-REVAL-O-02 | source-authority matrix values remain absent | missing record-family entry stays blocked, never inferred |
| BCK20-OD02-PC-REVAL-O-03 | qualified Legal evidence remains absent | keep BCK20-OD-05 Open and mandatory copy fail-closed |
| BCK20-OD02-PC-REVAL-O-04 | provider/schema/distribution/runtime evidence remains absent | keep all later executable gates closed |
| BCK20-OD02-PC-REVAL-O-05 | Mobile/Security verdicts are separate | this revalidation cannot satisfy them |

## 6. Proposed separate signature records

### 6.1 Product Localization

```text
Sign-off ID: BCK20-OD02-SIG-L10N
Named reviewer identity: RechargeN / Product owner
Reviewer role: interim Product Localization owner
Independence: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.4
Observed SHA-256: d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975
Verdict: Accept design boundary with retained gates — proposed
Accepted scope: Product Localization checklist 1–12, PC-V01–PC-V14 and MS-F-001–MS-F-007 impact
Retained observations: BCK20-OD02-PC-REVAL-O-01–05
```

### 6.2 Content/source governance

```text
Sign-off ID: BCK20-OD02-SIG-CONTENT
Named reviewer identity: RechargeN / Product owner
Reviewer role: interim Content/source-governance owner
Independence: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.4
Observed SHA-256: d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975
Verdict: Accept design boundary with retained gates — proposed
Accepted scope: Content checklist 1–12, PC-V01–PC-V14 and MS-F-001–MS-F-007 impact
Retained observations: BCK20-OD02-PC-REVAL-O-01–05
```

## 7. Acceptance criteria

1. **BCK20-OD02-PC-REVAL-AC-01:** exact workflow v0.4 identity and hash are frozen.
2. **BCK20-OD02-PC-REVAL-AC-02:** all seven amendments are dispositioned by both roles.
3. **BCK20-OD02-PC-REVAL-AC-03:** prior checklists and PC-V01–PC-V14 remain explicitly traceable.
4. **BCK20-OD02-PC-REVAL-AC-04:** L10N and Content verdicts remain separate.
5. **BCK20-OD02-PC-REVAL-AC-05:** combined-role non-independence is explicit.
6. **BCK20-OD02-PC-REVAL-AC-06:** source-authority values remain absent and fail-closed.
7. **BCK20-OD02-PC-REVAL-AC-07:** qualified Legal evidence is not inferred.
8. **BCK20-OD02-PC-REVAL-AC-08:** Mobile and Security/Privacy reviews remain separate.
9. **BCK20-OD02-PC-REVAL-AC-09:** owner confirmation is required for effectiveness.
10. **BCK20-OD02-PC-REVAL-AC-10:** target/hash change invalidates both proposed verdicts.
11. **BCK20-OD02-PC-REVAL-AC-11:** BCK20-OD-02/05 and OD-10 remain unaccepted.
12. **BCK20-OD02-PC-REVAL-AC-12:** no provider/schema/runtime/Firebase/deployment/push/merge authority is created.

## 8. Next action

Freeze this document's hash in the consolidated v0.4 owner package. Do not
make either verdict effective before the exact consolidated owner decision.
