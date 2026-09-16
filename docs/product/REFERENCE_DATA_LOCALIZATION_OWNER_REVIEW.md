# BCK-20 — Reference Data & Localization Owner Review

- ID: **BCK20-OWN-REV-01**
- Version: **0.1**
- Date: **2026-09-16**
- Status: **Proposed — owner decision required**
- Review target: [BCK-20 v0.2.9](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Coverage input: [BCK-20-PRE v0.2.9](REFERENCE_DATA_LOCALIZATION_COVERAGE_MATRIX.md)
- OD-10 evidence: [BCK-D1-OD10-EV-01 v0.1](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Runtime effect: **none**

## 1. Review outcome

BCK-20 is structurally complete as a target design and preserves Category
System v1.4.3 identity, but it is not ready for Review or Approval. The useful
next step is a bounded Product-owner disposition of its decision backlog, not
schema/runtime implementation and not premature specialist review.

Recommended verdict:

> **Accept with required amendments — combined-owner technical BCK-20
> boundary only.**

This verdict would accept the direction and the decision triage in §3. It
would not accept BCK-20, OD-10, any specialist sign-off or qualified Legal
policy. BCK-20 stays Draft and runtime stays Absent.

## 2. Facts preserved

- Latvia launch locales remain `lv-LV`, `en` and `ru`.
- Estonia and Lithuania remain modeled but independently disabled.
- Market, country, locale, currency, environment, timezone and service area
  remain different concepts.
- Category System v1.4.3 remains the taxonomy source with 28 categories and
  530 subcategories under its accepted counting rules.
- Stable IDs and revisions, not translated labels, form relationships.
- LocalizedText v1 performs no silent or automatic translation.
- Legal/safety copy may forbid fallback and then fails closed.
- `contentLocale` is not the viewer locale.
- API-DEC-05 remains Deferred; no language-neutral schema is authorized.
- Publishing reference data does not activate a feature or market.
- Documentation vectors are not executable fixture evidence.

## 3. Recommended decision triage

| Decision | Recommendation now | Reason | Fail-closed result |
|---|---|---|---|
| OD-10 | Retain **Proposed** | LocalizedText/fallback vectors are coherent, but Product Localization, Content, Mobile and qualified Legal evidence is incomplete | no executable contract or mandatory-copy activation |
| BCK20-OD-01 | **Deferred** until API-DEC-05 | Choosing Dart-only versus cross-language artifacts before the contract toolchain decision creates churn | no schema/code generation |
| BCK20-OD-02 | **Prepare next**; remain Open | Translation source, review, approval, provenance and emergency correction workflow is needed before locale content | no production translation publication |
| BCK20-OD-03 | **Deferred** to executable distribution slice | Snapshot/delta, TTL and artifact-size choices require measured payload/client evidence | no backend distribution/cache contract |
| BCK20-OD-04 | **Deferred** to EE/LT market activation | Additional Estonian/Lithuanian locale policy is unnecessary for Latvia-first documentation | EE/LT remain disabled with no LV fallback |
| BCK20-OD-05 | Retain **Open** for qualified Legal + Product | Mandatory local-copy and fallback-forbidden classes cannot be invented technically | affected market/legal surface remains disabled |
| BCK20-OD-06 | **Deferred** until a product requires each auxiliary dictionary | No accepted source exists for genres/music genres/topics | dictionary remains absent; no ad-hoc values |
| BCK20-OD-07 | **Deferred** until minimum-client evidence exists | Exact retirement window is premature before executable contracts and adoption telemetry | additive/deprecated compatibility only; no destructive retirement |

`Deferred` means a named later gate with an explicit safe default. It does not
mean implicitly Accepted or optional.

## 4. Required amendments before the verdict is effective

1. Correct stale `v0.2.2` wording in the conditional file-map and explicitly
   unimplemented sections to the integrated target revision.
2. Record the §3 dispositions in the BCK-20 Open Decisions table without
   changing OD-10 or BCK-20 status.
3. State that BCK20-OD-01 cannot reopen API-DEC-05 or introduce a private
   parallel schema toolchain.
4. State that BCK20-OD-03 is selected only from measured snapshot size,
   change frequency, client storage and stale-read requirements.
5. State that BCK20-OD-04 has no cross-market fallback: disabled EE/LT cannot
   consume Latvia policy or content as an activation substitute.
6. State that BCK20-OD-05 remains a qualified Legal/Product decision and is
   not satisfied by the technical owner verdict.
7. State that BCK20-OD-06 defaults to dictionary absence, not free-text values
   masquerading as canonical reference IDs.
8. State that BCK20-OD-07 forbids destructive removal until an Accepted
   support window, minimum-client rule, observation period and rollback exist.
9. Add a Product Localization workflow proposal covering source authority,
   translation, independent review, approval, provenance, withdrawal and
   emergency correction for BCK20-OD-02.
10. Keep fallback resolution, content-language rules and translation workflow
    as separate concerns.
11. Preserve typed missing/fallback/unsupported/stale results in future API and
    Mobile reviews.
12. Reconcile BCK-20, coverage, D1 records, BCK-01/02 and LAUNCH_STATUS in one
    documentation revision after explicit owner approval.

## 5. BCK20-OD-02 workflow requirements

The next documentation artifact must define at least:

- canonical source owner per record family;
- source locale and immutable source revision;
- translator identity or approved provider provenance;
- reviewer identity separated from the translator for mandatory/high-impact
  copy;
- locale-specific approval and publication authority;
- terminology/glossary revision and prohibited substitutions;
- machine-assistance disclosure; no automatic publication;
- change reason, diff, timestamp and audit record;
- withdrawal, rollback and emergency correction;
- missing/stale/unsupported states;
- market isolation and no EE/LT activation through Latvia fallback;
- qualified Legal approval reference for mandatory Legal/safety copy;
- accessibility and layout review for Mobile-visible text;
- retention rules that avoid placing user content or secrets in translation
  tooling.

The artifact defines governance only. It must not select a paid provider,
upload product data, create credentials or authorize runtime.

## 6. Why BCK-05 is not the immediate next target

BCK-05 already contains coherent proposed SLO, cost, recovery and incident
models. Its remaining progress depends on stage telemetry, EUR provider/SKU
evidence, restore/tabletop execution and specialist Operations, Finance,
Security/Privacy or domain verdicts. Producing more prose now would duplicate
those gates rather than close them.

BCK-20 has one useful owner-controlled documentation gap: the translation
governance workflow. Therefore BCK20-OD-02 should be prepared before returning
to evidence-bound BCK-05 decisions.

## 7. Status after proposed approval

If the Product owner approves this review exactly:

- the twelve amendments become binding and are integrated in a new BCK-20
  documentation revision;
- BCK20-OD-01/03/04/06/07 become explicitly Deferred with the stated gates;
- BCK20-OD-02 and BCK20-OD-05 remain Open;
- OD-10 remains Proposed;
- BCK-20 remains Draft;
- Reference Data, Localization, API, Content, Mobile and Legal specialist
  verdicts are not inferred;
- D1/G1, schema, runtime, Firebase, deployment, push and merge are unchanged.

## 8. Acceptance criteria

1. **BCK20-OWN-REV-AC-01:** the review targets exact BCK-20 v0.2.9.
2. **BCK20-OWN-REV-AC-02:** Category System v1.4.3 identity is preserved.
3. **BCK20-OWN-REV-AC-03:** OD-10 remains Proposed.
4. **BCK20-OWN-REV-AC-04:** BCK-20 remains Draft.
5. **BCK20-OWN-REV-AC-05:** five premature decisions receive exact Deferred
   gates and safe defaults.
6. **BCK20-OWN-REV-AC-06:** BCK20-OD-02 remains Open and is prepared next.
7. **BCK20-OWN-REV-AC-07:** BCK20-OD-05 remains qualified Legal/Product scope.
8. **BCK20-OWN-REV-AC-08:** API-DEC-05 is not bypassed.
9. **BCK20-OWN-REV-AC-09:** EE/LT remain independently disabled.
10. **BCK20-OWN-REV-AC-10:** absent dictionaries do not become free-text IDs.
11. **BCK20-OWN-REV-AC-11:** destructive retirement remains prohibited.
12. **BCK20-OWN-REV-AC-12:** translation and fallback are separate concerns.
13. **BCK20-OWN-REV-AC-13:** Product Localization workflow requirements are
    explicit and provider-neutral.
14. **BCK20-OWN-REV-AC-14:** technical owner approval is not specialist or
    Legal evidence.
15. **BCK20-OWN-REV-AC-15:** no schema, dataset, runtime or infrastructure is
    authorized.
16. **BCK20-OWN-REV-AC-16:** no Firebase, deployment, push or merge authority
    is created.

## 9. Exact owner decision requested

```text
Одобряю BCK20-OWN-REV-01 v0.1:
Accept with required amendments для combined-owner technical BCK-20 boundary.
OD-10 остаётся Proposed; BCK-20 остаётся Draft.
BCK20-OD-01/03/04/06/07 — Deferred с указанными gates и fail-closed defaults.
BCK20-OD-02 и BCK20-OD-05 остаются Open.
Specialist/Legal verdicts, schema, runtime, Firebase, deployment, push и merge
не разрешаю.
```

Until that explicit decision exists, this file is a Proposed recommendation
only and changes no decision status.
