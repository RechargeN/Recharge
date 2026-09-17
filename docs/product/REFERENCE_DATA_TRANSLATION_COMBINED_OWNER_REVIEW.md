# BCK-20 — Translation Product Localization and Content Combined-Owner Review

- ID: **BCK20-OD02-PC-COMB-REV-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — exact owner confirmation required; no signature recorded**
- Proposed reviewer: **RechargeN / Product owner**
- Proposed combined roles: **interim Product Localization owner + interim Content/source-governance owner**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; combined-role founder review**
- Legal qualification: **not claimed**
- Review package: [BCK20-OD02-PC-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_REVIEW_PACKAGE.md)
- Exact target: [BCK20-OD02-L10N-01 v0.3](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target SHA-256: `f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309`
- Parent: [BCK-20 v0.2.12](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Runtime effect: **none**

## 1. Purpose and authority boundary

This document prepares two separate owner verdicts for a two-member working
model: the Product owner carries accountable human responsibility and Codex
prepares technical evidence. Codex cannot provide a human, independent,
professional or Legal signature and cannot accept either verdict for the
owner.

The proposed reviewer may hold both roles because the combination is explicit,
each verdict remains separate and the owner is accountable for product meaning,
launch locales and canonical content governance. The review is not independent.
It cannot replace Mobile, Security/Privacy or qualified Legal review and cannot
authorize source-authority content, provider selection, schema, runtime,
Firebase, deployment, push or merge.

Until the exact §9 decision is explicitly confirmed, both
`BCK20-OD02-SIG-L10N` and `BCK20-OD02-SIG-CONTENT` remain
`Pending — owner confirmation required`.

## 2. Frozen-input verification

| Input | Observed state | Result |
|---|---|---|
| Workflow identity | `BCK20-OD02-L10N-01 v0.3` | Match |
| Normalized LF SHA-256 | `f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309` | Match |
| Workflow acceptance criteria | AC-01–50 sequential | Match |
| Translation classes | five | Match |
| Named workflow roles | nine | Match |
| Semantic record types | ten | Match |
| Typed failures | 23 | Match |
| Specialist signatures before this review | both Pending | Preserved |

The review becomes stale if the target version or normalized hash changes.

## 3. Product Localization checklist disposition

| Item | Disposition | Evidence / retained gate |
|---:|---|---|
| 1 | Accept | `lv-LV`, `en` and `ru` remain distinct from viewer/content/source locale semantics |
| 2 | Accept with retained gate | Canonicalization is revision-bound; accepted alias/profile content remains OD-10/BCK-20 evidence |
| 3 | Accept | Five classes define no-lowering and escalation behavior |
| 4 | Accept | High-impact and mandatory copy require independent per-unit review; bounded sampling is limited to approved reference-standard plans |
| 5 | Accept | Translator, reviewers, approver and publisher responsibilities are separated and attributable |
| 6 | Accept | Glossary revision changes create attributable impact and re-review evidence |
| 7 | Accept | Placeholder, plural/select, rich-text, link, Unicode and message-format failures are typed and fail closed |
| 8 | Accept | Assisted translation is untrusted draft input and cannot publish automatically or lower review depth |
| 9 | Accept with retained gate | Provider-neutral export/deletion and portability are required; no provider is selected or authorized |
| 10 | Accept | Freshness, manifest/receipt separation, correction, withdrawal and safe rollback are coherent |
| 11 | Accept | Quality telemetry excludes raw text and personal data by default and creates no Legal authority |
| 12 | Accept | Human/offline operation remains required when every external provider is disabled |

Recommended `BCK20-OD02-SIG-L10N` verdict:
**Accept design boundary with retained gates**. This recommendation is not an
effective signature until the owner confirms §9.

## 4. Content/source-governance checklist disposition

| Item | Disposition | Evidence / retained gate |
|---:|---|---|
| 1 | Accept with retained gate | Source-authority entry shape is complete; actual owner/policy content remains intentionally absent pending accountable population |
| 2 | Accept | Source snapshot ID, record/field ID, immutable revision/hash and reason preserve meaning |
| 3 | Accept | Policy conflicts are typed and routed to accountable Product/domain/Legal authority rather than resolved by translators |
| 4 | Accept | Source/glossary/policy changes create attributable impact sets; incomplete/unknown high-impact analysis blocks publication |
| 5 | Accept with retained gate | Product/Content boundaries are explicit; exact mandatory Legal classes remain BCK20-OD-05 scope |
| 6 | Accept | Publication, market/feature activation and client rollout are separate authorities |
| 7 | Accept | Candidate withdrawal, manifest revocation and surface disablement have closed typed target/action combinations |
| 8 | Accept | Correction and rollback preserve immutable history and reject restricted, erased, expired or invalid targets |
| 9 | Accept | Exceptions are attributable, expiring, state-coherent and unable to weaken core controls |
| 10 | Accept | User-authored content stays outside this authority without a separate accepted contract |
| 11 | Accept | Local/mock strings are migration candidates, never automatic source authority |
| 12 | Accept | Disabled EE/LT markets cannot inherit Latvia activation, glossary or approval evidence |

Recommended `BCK20-OD02-SIG-CONTENT` verdict:
**Accept design boundary with retained gates**. This recommendation is not an
effective signature until the owner confirms §9.

## 5. Mandatory paper-vector disposition

| Vector | L10N disposition | Content disposition | Required result |
|---|---|---|---|
| PC-V01 | Accept | Accept | stable-ID reference-standard path |
| PC-V02 | Accept | Accept | preserve meaning and raise Mobile finding; no silent truncation |
| PC-V03 | Accept | Accept | typed structural rejection |
| PC-V04 | Accept | Accept | impact set and re-review; stale approval cannot publish |
| PC-V05 | Accept | Accept | new source-bound candidate/review; no rebinding |
| PC-V06 | Accept | Accept | typed policy conflict and accountable reconciliation |
| PC-V07 | Accept | Accept | revoked/expired approval blocks publication and rollback |
| PC-V08 | Accept | Accept | typed conflict and authoritative receipt/pointer reconciliation |
| PC-V09 | Accept | Accept | typed withdrawal/revocation/disable action; unsafe text not exposed |
| PC-V10 | Accept | Accept | unsafe rollback refused |
| PC-V11 | Accept | Accept | `deletion_unconfirmed` and open escalation evidence |
| PC-V12 | Accept | Accept | no EE/LT publication or activation through LV evidence |
| PC-V13 | Accept | Accept | reject user-authored text from this authority |
| PC-V14 | Accept | Accept | provider-independent human/offline path remains available |

No paper vector is treated as executable, production or Legal evidence.

## 6. Findings and retained observations

No new Blocking or Major design contradiction was found in the frozen v0.3
target. The following retained observations are gates, not silently accepted
implementation facts:

| ID | Observation | Required treatment |
|---|---|---|
| BCK20-OD02-PC-COMB-O-01 | Source-authority matrix values are intentionally absent | Accountable owners populate and approve exact record-family content later; missing entry fails closed |
| BCK20-OD02-PC-COMB-O-02 | One owner combines both reviewed roles | Preserve zero-independence disclosure; obtain independent revalidation only where an owning gate explicitly requires it |
| BCK20-OD02-PC-COMB-O-03 | Qualified Legal evidence is absent | Keep BCK20-OD-05 and every applicable mandatory-copy decision Open/fail-closed |
| BCK20-OD02-PC-COMB-O-04 | Mobile and Security/Privacy have not reviewed v0.3 | Keep BCK20-OD-02 Open after Product/Content confirmation |
| BCK20-OD02-PC-COMB-O-05 | No executable schema/provider/runtime evidence exists | Preserve API-DEC-05, G1 and separately Approved executable-slice gates |

## 7. Separate proposed signature records

### 7.1 Product Localization

```text
Sign-off ID: BCK20-OD02-SIG-L10N
Named reviewer identity: RechargeN / Product owner
Organization/team: Recharge
Reviewer role: interim Product Localization owner
Qualification or authority basis: founder/Product owner directly accountable for product locale policy and internal localization governance; no independent professional credential claimed
Independence/conflict disclosure: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.3
Observed SHA-256: f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309
Verdict: Accept design boundary with retained gates — proposed, not yet signed
Accepted scope: Product Localization checklist 1–12 and PC-V01–PC-V14
Finding IDs: none
Retained observations: O-01–O-05
Required amendments: none before this owner verdict
Date/timezone: pending owner confirmation
Evidence reference: BCK20-OD02-PC-COMB-REV-01 v0.1 §§2–6
```

### 7.2 Content/source governance

```text
Sign-off ID: BCK20-OD02-SIG-CONTENT
Named reviewer identity: RechargeN / Product owner
Organization/team: Recharge
Reviewer role: interim Content/source-governance owner
Qualification or authority basis: founder/Product owner directly accountable for canonical product meaning and internal content governance; no independent professional credential claimed
Independence/conflict disclosure: combined owner; no independent reviewer
Target: BCK20-OD02-L10N-01 v0.3
Observed SHA-256: f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309
Verdict: Accept design boundary with retained gates — proposed, not yet signed
Accepted scope: Content checklist 1–12 and PC-V01–PC-V14
Finding IDs: none
Retained observations: O-01–O-05
Required amendments: none before this owner verdict
Date/timezone: pending owner confirmation
Evidence reference: BCK20-OD02-PC-COMB-REV-01 v0.1 §§2–6
```

## 8. Effect of a future exact owner confirmation

After explicit confirmation of §9:

- both Product/Content signature records become effective only for this exact
  v0.3 hash;
- the Product/Content boundary becomes complete under the review package result
  matrix;
- combined-role and non-independence disclosures remain permanent evidence;
- BCK20-OD-02 still remains Open for Mobile, Security/Privacy and applicable
  qualified Legal review;
- OD-10 remains Proposed and BCK-20 remains Draft;
- no implementation or external-system authority is created.

## 9. Exact owner decision requested

```text
Одобряю BCK20-OD02-PC-COMB-REV-01 v0.1:
принимаю два раздельных verdict — BCK20-OD02-SIG-L10N и
BCK20-OD02-SIG-CONTENT — как Accept design boundary with retained gates для
точного BCK20-OD02-L10N-01 v0.3 / SHA-256
f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309.
Подтверждаю совмещение ролей RechargeN / Product owner и отсутствие
independent review. BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed;
BCK-20 остаётся Draft. Mobile, Security/Privacy и applicable qualified Legal
reviews, source-authority content, provider selection, schema, runtime,
Firebase, deployment, push и merge не разрешаю.
```

## 10. Acceptance criteria

1. **BCK20-OD02-PC-COMB-AC-01:** exact v0.3 identity and hash are frozen.
2. **BCK20-OD02-PC-COMB-AC-02:** the owner and Codex roles are not conflated.
3. **BCK20-OD02-PC-COMB-AC-03:** L10N and Content verdicts remain separate.
4. **BCK20-OD02-PC-COMB-AC-04:** combined-role and zero independence are explicit.
5. **BCK20-OD02-PC-COMB-AC-05:** all 24 checklist items are dispositioned.
6. **BCK20-OD02-PC-COMB-AC-06:** both roles disposition PC-V01–PC-V14.
7. **BCK20-OD02-PC-COMB-AC-07:** retained observations are not false findings closure.
8. **BCK20-OD02-PC-COMB-AC-08:** source-authority content remains absent.
9. **BCK20-OD02-PC-COMB-AC-09:** qualified Legal authority is not claimed.
10. **BCK20-OD02-PC-COMB-AC-10:** owner confirmation is required for effectiveness.
11. **BCK20-OD02-PC-COMB-AC-11:** stale target/hash invalidates both verdicts.
12. **BCK20-OD02-PC-COMB-AC-12:** Mobile and Security/Privacy remain separate.
13. **BCK20-OD02-PC-COMB-AC-13:** BCK20-OD-02 remains Open after confirmation.
14. **BCK20-OD02-PC-COMB-AC-14:** OD-10 remains Proposed and BCK-20 Draft.
15. **BCK20-OD02-PC-COMB-AC-15:** no provider/schema/runtime/Firebase/deploy/push/merge authority is created.

## 11. Next action

Obtain the exact §9 owner decision. Do not update the canonical sign-off ledger,
BCK-20 status or frozen review package until that decision is explicitly
recorded.
