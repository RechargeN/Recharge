# BCK-20 — Translation Mobile/Security Pre-Review Owner Decision

- ID: **BCK20-OD02-MS-PRE-DEC-01**
- Version: **0.1**
- Date: **2026-09-17**
- Recorded at: **2026-09-17T12:13:25+03:00**
- Status: **Accepted documentation-only correction boundary**
- Decision owner: **RechargeN / Product owner**
- Accepted input: [BCK20-OD02-MS-PRE-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW.md)
- Accepted input normalized-LF SHA-256: `e3edbf1c1ba495bca73c5c8ac3f5d40ac7dd77b574cd24f2047bcdfe8775651d`
- Integrated target: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Integrated target normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Runtime effect: **none**

## 1. Exact recorded decision

```text
Одобряю BCK20-OD02-MS-PRE-01 v0.1:
интегрировать MS-F-001–MS-F-007 как documentation-only technical corrections
до Mobile и Security/Privacy owner review.
BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed; BCK-20 остаётся Draft;
BCK20-OD-03 остаётся Deferred.
Product Localization/Content verdicts по v0.3 остаются историческим
exact-hash evidence и требуют revalidation для v0.4.
Independent Security/Privacy и applicable qualified Legal evidence не заявляю.
Source-authority content, provider selection, schema, runtime, Firebase,
deployment, push и merge не разрешаю.
```

## 2. Effective scope

The decision authorizes only documentation corrections MS-F-001–MS-F-007:

1. revision-bound consumer/render compatibility;
2. atomic whole-manifest consumer installation;
3. monotonic revoke/withdraw/disable precedence over cache and rollback;
4. trusted current actor-authority evidence for privileged actions;
5. a conservative BCK-04 translation-artifact inventory;
6. separation of integrity from trusted origin/authenticity;
7. safe structured rich-content rendering through the final client boundary.

The corrected workflow preserves AC-01–50 and appends AC-51–62. It does not
select a schema, transport, cache, signature mechanism, provider or runtime.

## 3. Status and evidence effect

- `BCK20-OD02-L10N-01 v0.4` is the current corrected review target.
- The two Product/Content verdicts remain immutable historical evidence for
  exact v0.3 only and are not rebound to v0.4.
- Product Localization and Content revalidation for the v0.4 hash is Pending.
- `BCK20-OD02-SIG-MOBILE` remains Pending.
- `BCK20-OD02-SIG-SEC` remains Pending.
- Independent Security/Privacy and applicable qualified Legal evidence remain
  absent.
- BCK20-OD-02 remains Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03
  Deferred.

## 4. Explicit non-authority

This decision authorizes no source-authority content, provider/tool selection,
API-DEC-05 schema, endpoint, DTO, cache, mobile/backend runtime, Firebase,
credential, cloud resource, deployment, activation, push or merge.

## 5. Acceptance criteria

1. **BCK20-OD02-MS-PRE-DEC-AC-01:** the exact owner wording is recorded.
2. **BCK20-OD02-MS-PRE-DEC-AC-02:** the accepted v0.1 pre-review hash is frozen.
3. **BCK20-OD02-MS-PRE-DEC-AC-03:** the integrated v0.4 workflow hash is frozen.
4. **BCK20-OD02-MS-PRE-DEC-AC-04:** MS-F-001–MS-F-007 are the complete authorized correction scope.
5. **BCK20-OD02-MS-PRE-DEC-AC-05:** workflow AC-01–50 remain stable.
6. **BCK20-OD02-MS-PRE-DEC-AC-06:** Product/Content v0.3 evidence is not rebound to v0.4.
7. **BCK20-OD02-MS-PRE-DEC-AC-07:** Mobile and Security/Privacy verdicts remain separate and Pending.
8. **BCK20-OD02-MS-PRE-DEC-AC-08:** independent and qualified Legal evidence is not inferred.
9. **BCK20-OD02-MS-PRE-DEC-AC-09:** BCK20-OD-02 remains Open.
10. **BCK20-OD02-MS-PRE-DEC-AC-10:** OD-10 remains Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
11. **BCK20-OD02-MS-PRE-DEC-AC-11:** no source-authority/provider/schema/runtime authority is created.
12. **BCK20-OD02-MS-PRE-DEC-AC-12:** no Firebase/deployment/push/merge authority is created.

## 6. Next action

Prepare two separate proposed owner reviews for the exact v0.4 hash: Mobile and
Security/Privacy. Revalidate Product Localization and Content against the same
hash before any claim that the complete OD-02 boundary is accepted. Do not
start implementation.
