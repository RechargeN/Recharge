# BCK-20 — Translation Governance Security/Privacy Owner Review

- ID: **BCK20-OD02-SEC-REV-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — owner verdict required**
- Sign-off ID: **BCK20-OD02-SIG-SEC**
- Exact target: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Accepted pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Security/Privacy baseline: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Proposed reviewer: **RechargeN / Product owner acting as interim Security/Privacy technical owner**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; combined-owner technical review**
- Security/Privacy/Legal qualification: **not claimed**
- Runtime effect: **none**

## 1. Recommended verdict

> **Accept design boundary with retained gates** for the exact workflow v0.4
> hash above.

The recommendation covers only the combined-owner technical Security/Privacy
boundary. It is not independent, qualified Legal/Privacy advice or production
processing approval, and is not effective until the Product owner records the
exact decision in §7.

## 2. Frozen-input verification

| Input | Observed state | Result |
|---|---|---|
| Workflow identity | `BCK20-OD02-L10N-01 v0.4` | Match |
| Normalized-LF SHA-256 | `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975` | Match |
| Workflow acceptance criteria | AC-01–62 sequential | Match |
| Typed failures | 28 | Match |
| Inventory families/artifacts | 11 conservative rows | Match |
| Mobile/Security corrections | MS-F-001–MS-F-007 integrated | Match |
| Independent/Legal evidence | Absent | Preserved |

Any target version/hash change makes this review stale.

## 3. Security/Privacy checklist disposition

| Item | Disposition | Evidence / retained gate |
|---:|---|---|
| 1 | Accept | actor identity and current scoped authority are distinct and trusted-system resolved |
| 2 | Accept | review, approval, publication, correction, exception and export revalidate authority and retain immutable evidence |
| 3 | Accept | client/provider role claims and cached authority cannot authorize privileged action |
| 4 | Accept with retained gate | conservative artifact inventory exists; exact legal basis, retention, recipients, transfers, ROPA and DPIA remain open |
| 5 | Accept | screenshots/context inherit highest contained class; undeclared personal/Sensitive content is rejected or separately authorized |
| 6 | Accept | logs/metrics exclude raw text and personal data by default while privileged access/export remains auditable |
| 7 | Accept | provider input is minimized, provider output remains untrusted and provider selection/processing is separately gated |
| 8 | Accept | canonical render profile rejects executable markup, arbitrary URIs and unknown nodes |
| 9 | Accept | integrity hash is not confused with trusted origin, publisher, environment, market or current authorization |
| 10 | Accept | monotonic invalidation prevents privacy/safety resurrection through cache, replay, restore or rollback |
| 11 | Accept with retained gate | retention/deletion classes and failed provider deletion are explicit; numeric policies and lawful exceptions require qualified decisions |
| 12 | Accept with retained gate | mandatory/legal copy remains fail-closed under BCK20-OD-05 and qualified Legal authority |

## 4. Paper-vector disposition

| Vector | Disposition | Required outcome |
|---|---|---|
| MS-V03 | Accept | newer tombstone/disable authority wins over cached content |
| MS-V04 | Accept | rollback cannot resurrect invalid content |
| MS-V05 | Accept | lost capability denies publication at current-authority check |
| MS-V06 | Accept | client-supplied actor/capability is not authority |
| MS-V07 | Accept | wrong-environment self-consistent manifest fails trusted-origin check |
| MS-V08 | Accept | script/event/unknown node is quarantined/rejected |
| MS-V09 | Accept | arbitrary URI is rejected; stable approved target required |
| MS-V10 | Accept | undeclared personal-data screenshot is rejected/quarantined or separately governed |
| MS-V11 | Accept | unconfirmed provider deletion remains typed escalation, not success |

MS-V01/02/12 remain primarily Mobile evidence and are not claimed as an
independent Security/Privacy execution test.

## 5. Retained observations

| ID | Observation | Required treatment |
|---|---|---|
| BCK20-OD02-SEC-O-01 | review is combined-owner and non-independent | preserve disclosure; do not claim professional Security/Privacy assurance |
| BCK20-OD02-SEC-O-02 | legal basis, numeric retention, recipients/processors/transfers, ROPA and DPIA are unresolved | complete BCK-04 and qualified Legal/Privacy gates before production processing |
| BCK20-OD02-SEC-O-03 | exact origin-authentication/signature mechanism is intentionally absent | select only under accepted threat/API/distribution design and executable slice |
| BCK20-OD02-SEC-O-04 | Product/Content v0.3 verdicts do not cover v0.4 | require explicit exact-hash revalidation |
| BCK20-OD02-SEC-O-05 | no schema, IAM, provider, storage or runtime evidence exists | keep all production/executable gates closed |
| BCK20-OD02-SEC-O-06 | applicable mandatory-copy Legal review is absent | keep BCK20-OD-05 Open and affected surfaces fail-closed |

No Blocking or Major contradiction remains inside the documentation-only
combined-owner technical boundary after MS-F-001–MS-F-007. These observations
remain production and independence gates.

## 6. Proposed signature record

```text
Sign-off ID: BCK20-OD02-SIG-SEC
Named reviewer identity: RechargeN / Product owner
Organization/team: Recharge
Reviewer role: interim Security/Privacy technical owner
Qualification or authority basis: founder/Product owner accountable for technical product governance; no independent Security/Privacy or Legal credential claimed
Independence/conflict disclosure: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.4
Observed SHA-256: d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975
Verdict: Accept design boundary with retained gates — not effective until owner confirmation
Accepted scope: Security/Privacy checklist 1–12 and MS-V03/04/05/06/07/08/09/10/11
Finding IDs: none after integrated MS-F-001–MS-F-007
Retained observations: BCK20-OD02-SEC-O-01–06
Required amendments before bounded verdict: none
Date/timezone: supplied by recorded owner decision
Evidence reference: BCK20-OD02-SEC-REV-01 v0.1 §§2–5
```

## 7. Exact owner decision requested

```text
Одобряю BCK20-OD02-SEC-REV-01 v0.1:
Accept design boundary with retained gates для BCK20-OD02-SIG-SEC по
точному BCK20-OD02-L10N-01 v0.4 / SHA-256
d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975.
Подтверждаю роль RechargeN / Product owner как interim Security/Privacy
technical owner, отсутствие independent review и отсутствие qualified
Security/Privacy/Legal claim.
BCK20-OD-02 остаётся Open; OD-10 Proposed; BCK-20 Draft; BCK20-OD-03 Deferred;
BCK20-OD-05 Open. Product/Content v0.4 revalidation, independent
Security/Privacy и applicable qualified Legal evidence остаются Pending.
Provider, schema, IAM/runtime, Firebase, deployment, activation, push и merge
не разрешаю.
```

## 8. Acceptance criteria

1. **BCK20-OD02-SEC-REV-AC-01:** exact v0.4 identity and hash are frozen.
2. **BCK20-OD02-SEC-REV-AC-02:** all twelve Security/Privacy checklist items are dispositioned.
3. **BCK20-OD02-SEC-REV-AC-03:** Security/Privacy-owned paper vectors have deterministic outcomes.
4. **BCK20-OD02-SEC-REV-AC-04:** current authority cannot be supplied by client/provider/cached role claims.
5. **BCK20-OD02-SEC-REV-AC-05:** translation artifacts have conservative BCK-04 classification.
6. **BCK20-OD02-SEC-REV-AC-06:** integrity is separate from origin/authenticity.
7. **BCK20-OD02-SEC-REV-AC-07:** retention/processor/transfer/Legal gates remain open.
8. **BCK20-OD02-SEC-REV-AC-08:** owner confirmation is required for effectiveness.
9. **BCK20-OD02-SEC-REV-AC-09:** target/hash change invalidates the review.
10. **BCK20-OD02-SEC-REV-AC-10:** no provider/schema/runtime/Firebase/deployment/push/merge authority is created.

## 9. Next action

Wait for the exact owner decision in §7. Do not record an effective
Security/Privacy verdict or start implementation before that decision.
