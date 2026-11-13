# BCK-20 — Translation Product/Content Combined-Owner Decision

- ID: **BCK20-OD02-PC-COMB-DEC-01**
- Version: **0.1**
- Date: **2026-09-17**
- Recorded at: **2026-09-17T11:48:46+03:00**
- Status: **Recorded — two bounded combined-owner verdicts accepted**
- Decision owner: **RechargeN / Product owner**
- Accepted review: [BCK20-OD02-PC-COMB-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_REVIEW.md)
- Review SHA-256 at decision: `619407cc1402be9a9afbcb3490fe6c42aebc84efd615b2735a9ba27b39118d51`
- Exact workflow: [BCK20-OD02-L10N-01 v0.3](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Workflow SHA-256: `f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309`
- Parent: [BCK-20 v0.2.13](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Runtime effect: **none**

## 1. Exact recorded decision

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

## 2. Effective separate verdicts

| Sign-off ID | Human reviewer | Role | Verdict | Effective scope |
|---|---|---|---|---|
| `BCK20-OD02-SIG-L10N` | RechargeN / Product owner | interim Product Localization owner | **Accept design boundary with retained gates** | workflow v0.3 Product Localization checklist and PC-V01–PC-V14 |
| `BCK20-OD02-SIG-CONTENT` | RechargeN / Product owner | interim Content/source-governance owner | **Accept design boundary with retained gates** | workflow v0.3 Content checklist and PC-V01–PC-V14 |

The verdicts are separate but non-independent. Codex prepared technical
evidence and is not a signatory. Neither verdict claims an independent
professional credential or qualified Legal authority.

## 3. Retained gates

- `BCK20-OD02-PC-COMB-O-01…05` remain explicit observations.
- Source-authority owner/policy content remains absent and fail-closed.
- Mobile and Security/Privacy review of exact v0.3 remains required.
- Qualified Legal review remains required for applicable mandatory-copy scope.
- BCK20-OD-02 remains **Open** and BCK20-OD-05 remains **Open**.
- OD-10 remains **Proposed** and BCK-20 remains **Draft**.
- Provider selection, API-DEC-05 schema work, runtime, Firebase, deployment,
  push and merge remain unauthorized.

## 4. Acceptance criteria

1. **BCK20-OD02-PC-COMB-DEC-AC-01:** the exact owner decision is recorded.
2. **BCK20-OD02-PC-COMB-DEC-AC-02:** the accepted review v0.1 hash is frozen.
3. **BCK20-OD02-PC-COMB-DEC-AC-03:** the workflow v0.3 hash is frozen.
4. **BCK20-OD02-PC-COMB-DEC-AC-04:** L10N and Content verdicts remain separate.
5. **BCK20-OD02-PC-COMB-DEC-AC-05:** combined-role non-independence is permanent evidence.
6. **BCK20-OD02-PC-COMB-DEC-AC-06:** Codex is not recorded as a signatory.
7. **BCK20-OD02-PC-COMB-DEC-AC-07:** source-authority content remains absent.
8. **BCK20-OD02-PC-COMB-DEC-AC-08:** Mobile/Security/Privacy/Legal gates remain.
9. **BCK20-OD02-PC-COMB-DEC-AC-09:** BCK20-OD-02 remains Open.
10. **BCK20-OD02-PC-COMB-DEC-AC-10:** OD-10 remains Proposed and BCK-20 Draft.
11. **BCK20-OD02-PC-COMB-DEC-AC-11:** no provider/schema/runtime authority is created.
12. **BCK20-OD02-PC-COMB-DEC-AC-12:** no Firebase/deployment/push/merge authority is created.

## 5. Next action

Prepare separate Mobile and Security/Privacy review of the exact workflow v0.3.
Do not infer qualified Legal evidence and do not start implementation.
