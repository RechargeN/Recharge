# BCK-20 — Translation Governance Mobile Owner Review

- ID: **BCK20-OD02-MOB-REV-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — owner verdict required**
- Sign-off ID: **BCK20-OD02-SIG-MOBILE**
- Exact target: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Accepted pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Mobile baseline: [BCK-18 v0.5](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
- Proposed reviewer: **RechargeN / Product owner acting as interim Mobile owner**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; combined-owner technical review**
- Runtime effect: **none**

## 1. Recommended verdict

> **Accept design boundary with retained gates** for the exact workflow v0.4
> hash above.

The recommendation is limited to the Mobile semantic boundary. It is not
effective until the Product owner records the exact decision in §7. It does not
approve BCK-18, BCK20-OD-03, schema, cache, adapter, runtime, Firebase,
deployment, activation, push or merge.

## 2. Frozen-input verification

| Input | Observed state | Result |
|---|---|---|
| Workflow identity | `BCK20-OD02-L10N-01 v0.4` | Match |
| Normalized-LF SHA-256 | `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975` | Match |
| Workflow acceptance criteria | AC-01–62 sequential | Match |
| Typed failures | 28 | Match |
| Mobile/Security corrections | MS-F-001–MS-F-007 integrated | Match |
| Product/Content v0.4 revalidation | Pending | Preserved |

Any target version/hash change makes this review stale.

## 3. Mobile checklist disposition

| Item | Disposition | Evidence / retained gate |
|---:|---|---|
| 1 | Accept | render profile, message format, placeholder schema, market and locale revisions are separate identity/freshness inputs |
| 2 | Accept | unsupported render profile is atomic typed state, not empty or partial output |
| 3 | Accept with retained gate | full-bundle stage/verify/atomic-switch semantics are defined; transport/cache/delta remain BCK20-OD-03 |
| 4 | Accept | mixed-manifest key merging and partial activation are forbidden |
| 5 | Accept | monotonic resolution markers dominate stale cache, replay, restore and rollback |
| 6 | Accept | offline cannot make stale/revoked text fresh or authoritative |
| 7 | Accept | canonical safe rich-content nodes, escaping and approved link targets define the final render boundary |
| 8 | Accept | layout, scaling, truncation, state meaning and screen-reader evidence cannot weaken product/legal meaning |
| 9 | Accept | wrong environment/origin and manifest-integrity failures are distinct fail-closed states |
| 10 | Accept | privacy-safe telemetry excludes raw product text and personal data by default |
| 11 | Accept | publication remains separate from market, feature and client activation |
| 12 | Accept with retained gate | executable fixtures, adapters, local cache policy and supported-build matrix require later Approved slices |

## 4. Paper-vector disposition

| Vector | Disposition | Required outcome |
|---|---|---|
| MS-V01 | Accept | `render_profile_unsupported`; no partial rendering |
| MS-V02 | Accept | prior complete authorized bundle or typed unavailable; never mixed revision |
| MS-V03 | Accept | newer resolution marker wins over cached content |
| MS-V04 | Accept | rollback refuses revoked/expired/restricted target |
| MS-V07 | Accept | wrong-environment origin mismatch fails closed despite matching hash |
| MS-V08 | Accept | unsafe node/script/event content is rejected |
| MS-V09 | Accept | arbitrary translator URI is rejected |
| MS-V12 | Accept | meaning is preserved at supported width/scale or publication blocks |

MS-V05/06/10/11 remain primarily Security/Privacy evidence and are not claimed
by this Mobile review.

## 5. Retained observations

| ID | Observation | Required treatment |
|---|---|---|
| BCK20-OD02-MOB-O-01 | BCK20-OD-03 distribution/cache/delta design is Deferred | no physical bundle/cache implementation or freshness default |
| BCK20-OD02-MOB-O-02 | no executable client fixture or supported-build matrix exists | require a separately Approved slice and reproducible evidence |
| BCK20-OD02-MOB-O-03 | Product/Content v0.3 verdicts do not cover v0.4 | require explicit exact-hash revalidation |
| BCK20-OD02-MOB-O-04 | Security/Privacy and applicable Legal evidence remain separate | do not infer those verdicts from Mobile acceptance |
| BCK20-OD02-MOB-O-05 | no source-authority content or runtime exists | keep BCK20-OD-02 Open and product surfaces disabled |

No Blocking or Major contradiction remains inside the documentation-only Mobile
boundary after MS-F-001–MS-F-007. The observations above remain gates.

## 6. Proposed signature record

```text
Sign-off ID: BCK20-OD02-SIG-MOBILE
Named reviewer identity: RechargeN / Product owner
Organization/team: Recharge
Reviewer role: interim Mobile owner
Qualification or authority basis: founder/Product owner accountable for the mobile product boundary; no independent specialist credential claimed
Independence/conflict disclosure: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.4
Observed SHA-256: d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975
Verdict: Accept design boundary with retained gates — not effective until owner confirmation
Accepted scope: Mobile checklist 1–12 and MS-V01/02/03/04/07/08/09/12
Finding IDs: none after integrated MS-F-001–MS-F-007
Retained observations: BCK20-OD02-MOB-O-01–05
Required amendments before bounded verdict: none
Date/timezone: supplied by recorded owner decision
Evidence reference: BCK20-OD02-MOB-REV-01 v0.1 §§2–5
```

## 7. Exact owner decision requested

```text
Одобряю BCK20-OD02-MOB-REV-01 v0.1:
Accept design boundary with retained gates для BCK20-OD02-SIG-MOBILE по
точному BCK20-OD02-L10N-01 v0.4 / SHA-256
d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975.
Подтверждаю роль RechargeN / Product owner как interim Mobile owner и
отсутствие independent review.
BCK20-OD-02 остаётся Open; OD-10 Proposed; BCK-20 Draft; BCK20-OD-03 Deferred.
Product/Content v0.4 revalidation, Security/Privacy и applicable qualified
Legal evidence остаются Pending. Schema, cache/adapter/runtime, Firebase,
deployment, activation, push и merge не разрешаю.
```

## 8. Acceptance criteria

1. **BCK20-OD02-MOB-REV-AC-01:** exact v0.4 identity and hash are frozen.
2. **BCK20-OD02-MOB-REV-AC-02:** all twelve Mobile checklist items are dispositioned.
3. **BCK20-OD02-MOB-REV-AC-03:** Mobile-owned paper vectors have deterministic outcomes.
4. **BCK20-OD02-MOB-REV-AC-04:** unsupported/mixed/revoked client states fail closed.
5. **BCK20-OD02-MOB-REV-AC-05:** rich content remains untrusted through final rendering.
6. **BCK20-OD02-MOB-REV-AC-06:** BCK20-OD-03 ownership and Deferred status are preserved.
7. **BCK20-OD02-MOB-REV-AC-07:** Product/Content revalidation and Security/Legal evidence remain separate.
8. **BCK20-OD02-MOB-REV-AC-08:** owner confirmation is required for effectiveness.
9. **BCK20-OD02-MOB-REV-AC-09:** target/hash change invalidates the review.
10. **BCK20-OD02-MOB-REV-AC-10:** no schema/runtime/Firebase/deployment/push/merge authority is created.

## 9. Next action

Wait for the exact owner decision in §7. Do not record an effective Mobile
verdict or start implementation before that decision.
