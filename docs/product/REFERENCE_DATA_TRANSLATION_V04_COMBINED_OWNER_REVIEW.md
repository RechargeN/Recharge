# BCK-20 — Translation Governance v0.4 Combined-Owner Review Package

- ID: **BCK20-OD02-V04-COMB-REV-01**
- Version: **0.2**
- Date: **2026-09-17**
- Status: **Owner decision recorded — four exact-v0.4 verdicts effective with retained gates**
- Exact workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Workflow normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Product/Content revalidation: [BCK20-OD02-PC-REVAL-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_V04_REVALIDATION.md)
- Product/Content review SHA-256: `799d8bb0ebad2683a0f61b25f6f1b6abf49ebcd0e807710ed7c285bcf66bedcd`
- Mobile review: [BCK20-OD02-MOB-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_OWNER_REVIEW.md)
- Mobile review SHA-256: `d9f9b76302f1b57e03e4577005448a2a59be359174c1f61565b774ffce9bccf2`
- Security/Privacy review: [BCK20-OD02-SEC-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_SECURITY_PRIVACY_OWNER_REVIEW.md)
- Security/Privacy review SHA-256: `1b0db67df34e54af5433e1e3cfd172717c7e4911267a6d1ab094b07b89c435a7`
- Owner/signatory: **RechargeN / Product owner**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; one owner holds four disclosed interim roles**
- Qualified Legal/Security/Privacy claim: **none**
- Runtime effect: **none**
- Decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)

## 1. Purpose

This package provides one exact owner action while preserving four separate
verdicts:

1. `BCK20-OD02-SIG-L10N` — Product Localization;
2. `BCK20-OD02-SIG-CONTENT` — Content/source governance;
3. `BCK20-OD02-SIG-MOBILE` — Mobile boundary;
4. `BCK20-OD02-SIG-SEC` — combined-owner technical Security/Privacy boundary.

One owner may confirm all four in a single statement because the combined roles
and zero independence are explicit. The verdicts do not merge. Codex does not
sign any row. This package does not provide independent professional review or
qualified Legal/Privacy/Security judgment.

## 2. Frozen evidence matrix

| Review | Frozen result | Recommended verdict | Unresolved boundary |
|---|---|---|---|
| Product Localization | 12-item checklist, PC-V01–V14 and MS-F-001–007 impact dispositioned | Accept design boundary with retained gates | source-authority values, provider and Legal gates |
| Content/source governance | 12-item checklist, PC-V01–V14 and MS-F-001–007 impact dispositioned | Accept design boundary with retained gates | source-authority values and applicable Legal gates |
| Mobile | 12-item checklist and Mobile-owned MS vectors dispositioned | Accept design boundary with retained gates | BCK20-OD-03, executable cache/adapter/build evidence |
| Security/Privacy technical | 12-item checklist and Security-owned MS vectors dispositioned | Accept design boundary with retained gates | independent review, legal basis, retention, processor/transfer, ROPA/DPIA |

All reviews target exactly the same workflow v0.4 hash. A changed workflow or
review hash invalidates the package before decision recording.

## 3. Common retained gates

- BCK20-OD-02 remains **Open** because source-authority content and applicable
  qualified Legal evidence are not complete.
- BCK20-OD-05 remains **Open** for mandatory-copy/fallback policy.
- OD-10 remains **Proposed** and BCK-20 remains **Draft**.
- BCK20-OD-03 remains **Deferred**; no distribution/cache/delta design is
  selected.
- Independent Mobile and Security/Privacy evidence is not claimed.
- Exact legal basis, numeric retention, processors/subprocessors, transfers,
  ROPA/DPIA and professional Legal conclusions remain open where applicable.
- EE/LT remain independently disabled.
- Source-authority matrix values remain absent and fail closed.
- Provider/tool selection, API-DEC-05 schema, IAM/runtime, Firebase, cloud,
  deployment, activation, push and merge remain unauthorized.

## 4. Effect of owner acceptance

Under the exact decision recorded in §6:

- the four verdict IDs become effective only for the frozen workflow v0.4
  hash and their stated bounded scopes;
- the prior Product/Content v0.3 verdicts remain immutable historical evidence
  and are superseded only as the current review target by the v0.4
  revalidation, not erased;
- combined-role and zero-independence disclosure becomes permanent evidence;
- none of the common retained gates in §3 closes;
- canonical BCK-20/D1/BCK-01/BCK-02/roadmap/status records may be reconciled
  documentation-only;
- no implementation may start from this decision.

## 5. Recorded signature summary

| Sign-off ID | Reviewer role | Recorded verdict | Effective only for |
|---|---|---|---|
| `BCK20-OD02-SIG-L10N` | interim Product Localization owner | Accept design boundary with retained gates | workflow v0.4 + PC revalidation scope |
| `BCK20-OD02-SIG-CONTENT` | interim Content/source-governance owner | Accept design boundary with retained gates | workflow v0.4 + PC revalidation scope |
| `BCK20-OD02-SIG-MOBILE` | interim Mobile owner | Accept design boundary with retained gates | workflow v0.4 + Mobile review scope |
| `BCK20-OD02-SIG-SEC` | interim Security/Privacy technical owner | Accept design boundary with retained gates | workflow v0.4 + Security/Privacy review scope |

Reviewer identity for every row is `RechargeN / Product owner`. None is an
independent verdict, and `SIG-SEC` is not a qualified professional or Legal
assurance claim.

## 6. Recorded exact owner decision

```text
Одобряю BCK20-OD02-V04-COMB-REV-01 v0.1:
принимаю четыре раздельных verdict — BCK20-OD02-SIG-L10N,
BCK20-OD02-SIG-CONTENT, BCK20-OD02-SIG-MOBILE и BCK20-OD02-SIG-SEC — как
Accept design boundary with retained gates для точного
BCK20-OD02-L10N-01 v0.4 / SHA-256
d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975.
Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
review и отсутствие qualified Security/Privacy/Legal claim.
BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 остаётся Proposed; BCK-20
остаётся Draft; BCK20-OD-03 остаётся Deferred. Source-authority content,
independent Security/Privacy и applicable qualified Legal evidence остаются
Pending. Provider selection, schema, IAM/runtime, Firebase, deployment,
activation, push и merge не разрешаю.
```

## 7. Acceptance criteria

1. **BCK20-OD02-V04-COMB-AC-01:** workflow v0.4 identity and hash are frozen.
2. **BCK20-OD02-V04-COMB-AC-02:** all three review-document hashes are frozen.
3. **BCK20-OD02-V04-COMB-AC-03:** four verdict IDs remain separate.
4. **BCK20-OD02-V04-COMB-AC-04:** one decision may record four disclosed combined roles without merging them.
5. **BCK20-OD02-V04-COMB-AC-05:** Codex is not a signatory.
6. **BCK20-OD02-V04-COMB-AC-06:** no independent or qualified professional claim is inferred.
7. **BCK20-OD02-V04-COMB-AC-07:** prior v0.3 evidence remains immutable history.
8. **BCK20-OD02-V04-COMB-AC-08:** source-authority values remain absent and fail-closed.
9. **BCK20-OD02-V04-COMB-AC-09:** BCK20-OD-02 and BCK20-OD-05 remain Open.
10. **BCK20-OD02-V04-COMB-AC-10:** OD-10 remains Proposed and BCK-20 Draft.
11. **BCK20-OD02-V04-COMB-AC-11:** BCK20-OD-03 remains Deferred.
12. **BCK20-OD02-V04-COMB-AC-12:** EE/LT remain independently disabled.
13. **BCK20-OD02-V04-COMB-AC-13:** owner confirmation is required for effectiveness.
14. **BCK20-OD02-V04-COMB-AC-14:** changed workflow/review hash invalidates the package.
15. **BCK20-OD02-V04-COMB-AC-15:** acceptance authorizes documentation reconciliation only.
16. **BCK20-OD02-V04-COMB-AC-16:** no provider/schema/runtime/Firebase/deployment/push/merge authority is created.

## 8. Recorded disposition and next action

`BCK20-OD02-V04-COMB-DEC-01` freezes reviewed package v0.1 at normalized-LF
SHA-256 `33cf3205a497bee00a9cc684d62e7421acedf9209d27101d7f4a701e425ac41f`.
This v0.2 revision records the result only. Reconcile canonical documentation,
then obtain the still-Pending source-authority, independent Security/Privacy
and applicable qualified Legal evidence. No implementation is authorized.
