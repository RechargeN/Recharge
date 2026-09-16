# BCK-20 — Translation Governance Owner Decision

- ID: **BCK20-OD02-DEC-01**
- Version: **0.1**
- Date: **2026-09-16**
- Status: **Accepted with required amendments — combined-owner technical translation-governance boundary only**
- Decision owner: **RechargeN / Product owner**
- Review: [BCK20-OD02-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_REVIEW.md)
- Integrated workflow: [BCK20-OD02-L10N-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Parent: [BCK-20 v0.2.11](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Runtime effect: **none**

## 1. Recorded decision

On 2026-09-16 the Product owner recorded:

> Accept with required amendments for the combined-owner technical
> translation-governance boundary.

Exact bounded instruction:

```text
Одобряю BCK20-OD02-REV-01 v0.1:
Accept with required amendments для combined-owner technical translation-governance boundary.
BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed; BCK-20 остаётся Draft.
Product Localization, Content, Mobile, Security/Privacy и qualified Legal
verdicts, provider selection, schema, runtime, Firebase, deployment, push и
merge не разрешаю.
```

All sixteen amendments from BCK20-OD02-REV-01 v0.1 are integrated in workflow
v0.2. This is technical governance evidence, not Product Localization,
Content, Mobile, Security/Privacy or qualified Legal sign-off.

## 2. Status effects

- BCK20-OD-02 remains **Open** pending the named specialist evidence.
- OD-10 remains **Proposed**.
- BCK-20 remains **Draft**.
- BCK20-OD-05 remains **Open** for mandatory-copy and fallback policy.
- API-DEC-05 and BCK20-OD-01 remain **Deferred**.
- BCK20-OD-03/04/06/07 retain their existing Deferred gates.
- Estonia and Lithuania remain independently disabled.
- Provider selection, schema, storage, runtime, Firebase, deployment, push and
  merge remain unauthorized.

## 3. Binding technical controls

The technical baseline requires:

1. stable IDs and immutable source/candidate/publication revisions;
2. canonical locale, MarketConfig, message-format and placeholder identity;
3. attributable provenance and independent per-unit high-impact review;
4. typed policy conflict, change impact and approval freshness;
5. atomic integrity-checked manifest publication;
6. publication authority separated from activation authority;
7. rollback that cannot resurrect withdrawn or invalid text;
8. expiring attributable exceptions that cannot bypass mandatory controls;
9. explicit retention classes, provider-export deletion evidence and semantic
   portability;
10. privacy-safe metrics that cannot auto-publish or prove Legal correctness;
11. distinct candidate withdrawal, manifest revocation and surface disablement;
12. separate authorization for any user-authored translation feature.

## 4. Evidence still required

- Product Localization workflow and terminology verdict;
- Content/source-owner authority confirmation;
- Mobile layout, accessibility and typed-state review;
- Security/Privacy retention, access, provider and deletion review;
- qualified Legal review where mandatory local copy or fallback prohibition
  applies;
- separately approved executable contracts, migration, rollback and negative
  tests after schema/runtime authorization.

Until those exact boundaries pass, BCK20-OD-02 cannot become Accepted.

## 5. Acceptance criteria

1. **BCK20-OD02-DEC-AC-01:** the exact owner wording is recorded without scope
   expansion.
2. **BCK20-OD02-DEC-AC-02:** all sixteen review amendments are integrated in
   workflow v0.2.
3. **BCK20-OD02-DEC-AC-03:** BCK20-OD-02 remains Open.
4. **BCK20-OD02-DEC-AC-04:** OD-10 remains Proposed and BCK-20 remains Draft.
5. **BCK20-OD02-DEC-AC-05:** named specialist and qualified Legal evidence is
   not inferred.
6. **BCK20-OD02-DEC-AC-06:** provider and schema decisions remain separate.
7. **BCK20-OD02-DEC-AC-07:** EE/LT remain independently disabled.
8. **BCK20-OD02-DEC-AC-08:** no runtime, Firebase, deployment, push or merge
   authority is created.

## 6. Rollback

If this documentation decision is superseded, publish a new attributable
decision and workflow revision. Do not rewrite this historical record and do
not treat documentation rollback as runtime or data rollback.
