# BCK-D1 — OD-10 Localization Documentation-Vector Owner Review

- Review ID: **OD10-DOC-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — owner disposition required**
- Target: [BCK-D1-OD10-EV-01 v0.1](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Target normalized-LF SHA-256:
  `82c31bd8b03b7b627e1ebf978a135696311800fb0f4e01e9dc2b4af6800a299d`
- Review perspectives: **Reference Data, API Platform, Product Localization,
  Content, Mobile and technical Security/Privacy**
- Review coordinator: **RechargeN / Product owner combined role**
- Independence: **none**
- Qualified Legal/Privacy claim: **none**
- Runtime effect: **none**

---

## 1. Verdict

**Accept design direction with required amendments. Keep OD-10 Proposed.**

The v0.1 evidence establishes a coherent high-level `LocalizedTextV1`
boundary, deterministic fallback intent, market isolation and explicit
separation between documentation vectors and executable contracts. It is not
ready for OD-10 Acceptance because two vectors are semantically inconsistent
and several wire/result/policy decisions remain underspecified.

This review authorizes no amendment by itself. If accepted by the owner, the
findings in §4 are integrated into evidence v0.2 and BCK-20 in one docs-only
reconciliation. OD-10 remains Proposed after that reconciliation until the
retained gates in §6 pass.

## 2. Scope reviewed

The review checks only documentation semantics for:

- `LocalizedTextV1` shape and value validity;
- locale canonicalization identity;
- deterministic read-time resolution;
- typed success/failure results;
- LV vectors and EE/LT isolation;
- content-language, withdrawal and cache boundaries;
- API/Mobile compatibility and Legal-copy gates.

It does not review or authorize JSON Schema, code generation, executable
fixtures, parser/library selection, datasets, Firebase, deployment or market
activation.

## 3. Accepted design properties

The following properties are internally sound and should be preserved:

1. IDs, enum values and references are never localized labels.
2. `defaultLocale` must have a non-empty corresponding value.
3. Locale keys are compared only after deterministic canonicalization.
4. Empty/whitespace-only text is missing, never successful translation.
5. Fallback is ordered, deduplicated and MarketConfig-bound.
6. Arbitrary map iteration is never a fallback rule.
7. Missing translation is typed and observable without logging text.
8. Mandatory Legal/safety copy can prohibit fallback and fail closed.
9. `contentLocale`, viewer locale and target locale remain distinct.
10. Latvia, Estonia and Lithuania have independent effective revisions.
11. Dataset publication does not activate a market.
12. Documentation acceptance and executable schema/runtime remain separate.

## 4. Required amendments

### F-001 — `LV-04 value_default` is unreachable as written

The baseline fallback order is `lv-LV`, `en`, `ru`. The case says only default
`ru` exists and expects `value_default`, but step 3 already resolves `ru` as
`market_fallback`.

Required amendment:

- make `LV-04` use a case-specific MarketConfig where `ru` remains enabled but
  is intentionally absent from `fallbackLocaleOrder`; or remove the separate
  `value_default` step;
- retain the separate step and use the first option so its behavior stays
  testable;
- state that `defaultLocale` succeeds only when enabled by the effective
  MarketConfig.

### F-002 — unsupported requested locale has two competing meanings

`LV-08` permits market fallback from unsupported `de-DE`, while the accepted
translation workflow defines typed `unsupported_locale`.

Required amendment:

- distinguish a viewer read request from authoring/publication authority;
- for non-Legal read presentation, an unsupported requested locale may resolve
  through the market fallback order, but the result must carry
  `requestedLocaleStatus=unsupported` and must not claim exact support;
- authoring, publication, mutation and `fallbackForbidden` resolution return
  typed `unsupported_locale` without fallback;
- Mobile must expose the fallback-language indicator when product policy
  requires it.

### F-003 — result contract is not a discriminated union

The v0.1 result lists success fields but leaves missing/unsupported/error
payloads implicit.

Required amendment: define the documentation contract as:

```text
LocalizedTextResolutionV1 =
  Resolved {
    requestedLocale,
    requestedLocaleStatus: supported | unsupported,
    resolvedLocale,
    resolutionKind: exact | configured_fallback | market_fallback |
      value_default,
    marketConfigRevision,
    datasetRevision
  }
  | Unresolved {
    requestedLocale,
    requestedLocaleStatus: supported | unsupported,
    code: translation_missing | unsupported_locale |
      unsupported_contract_revision | stale_reference_data,
    marketConfigRevision,
    datasetRevision?
  }
```

No unresolved outcome may carry a fake `resolvedLocale` or success kind.

### F-004 — text “normalization” is ambiguous

`non-empty normalized string` does not define whether the server trims,
Unicode-normalizes or otherwise mutates approved text. Silent mutation would
change hashes and could alter Legal copy.

Required amendment:

- use `non-empty Unicode string` in the v1 shape;
- validate emptiness after a defined Unicode-whitespace check;
- do not silently trim, normalize or rewrite stored approved text;
- any future text-normalization profile must be named, revision-bound and
  applied before approval/hash generation, not during resolution.

### F-005 — canonical locale identity needs an exact profile

“Canonical BCP 47” alone does not state casing, alias or registry-revision
behavior.

Required amendment:

- introduce `localeNormalizationProfileRevision` as an identity input;
- define at documentation level the casing/profile boundary and alias
  comparison behavior;
- pin the applicable IANA evidence before executable implementation;
- reject unknown/newer critical profile revisions;
- do not claim that the recorded IANA technical evidence is an approved
  executable source while terms/access remain Pending.

### F-006 — duplicate-key detection must occur before ordinary map decoding

Canonical-equivalent keys such as `en-us` and `en-US` can be checked after
decode, but exact duplicate JSON object members may already have been lost by
a permissive decoder.

Required amendment:

- require duplicate-member rejection at the wire decoder boundary before map
  materialization;
- then canonicalize locale keys and reject canonical-equivalent duplicates;
- keep the physical JSON shape deferred to API-DEC-05 and the executable
  contract slice.

### F-007 — fallback graph behavior is underspecified

The invalid vectors mention cycles, while the algorithm does not say whether
explicit fallbacks are recursively traversed.

Required amendment:

- v1 performs no recursive graph traversal;
- it reads only the requested locale's configured ordered fallback list;
- candidates are canonicalized and deduplicated before lookup;
- self-reference, canonical duplicates and any future recursive/cyclic form
  are invalid configuration and fail closed.

### F-008 — withdrawn and stale translations need candidate filtering

The evidence lists withdrawal compatibility but does not state whether a
withdrawn value can reappear through another fallback step or rollback.

Required amendment:

- candidate eligibility is checked before value lookup;
- withdrawn, revoked, expired, wrong-market, wrong-environment and stale
  mandatory values are excluded;
- fallback cannot resurrect them;
- unknown revision or integrity mismatch returns a typed unresolved state.

### F-009 — EE/LT evidence proves isolation, not locale policy

The current cases correctly keep EE/LT disabled but do not define complete
future `supportedLocales`, explicit fallback and mandatory-copy matrices.

Required amendment:

- keep EE/LT disabled-state vectors as accepted documentation evidence;
- do not describe future EE/LT locale policy as decided;
- require separate market-owner evidence before activation;
- prohibit Latvia fallback configuration from satisfying EE/LT readiness.

### F-010 — compatibility vectors lack exact expected outcomes

Section 6 names current/previous/newer, stale cache, rollback and withdrawal
cases but does not state their deterministic result.

Required amendment: append a documentation matrix covering at least:

| Case | Required result |
|---|---|
| current supported contract/revision | resolve normally |
| previous compatible contract | resolve only under declared compatibility window |
| newer unsupported critical revision | `unsupported_contract_revision`; no mutation |
| known stale optional cache | typed stale state; bounded read only if policy permits |
| stale mandatory/Legal cache | unresolved/fail closed |
| integrity/hash mismatch | unresolved; quarantine/re-fetch through authorized path |
| withdrawn translation | never resolve or return through rollback |
| safe compatible rollback | atomic pointer change to verified eligible revision |
| unsafe/incompatible rollback | disable affected surface/mutation |

### F-011 — telemetry and diagnostics must stay content-free

Required amendment:

- diagnostics may record locale codes, typed result, revision IDs, freshness
  class and timing;
- do not log localized values, user-authored text or arbitrary raw locale
  input;
- bound attempted-candidate reporting to canonical configured locale IDs.

### F-012 — Legal and source gates remain genuinely external

Required amendment:

- BCK20-OD-05 must enumerate mandatory/fallback-forbidden classes and exact
  locale/revision evidence before OD-10 Acceptance where applicable;
- qualified Legal/Privacy judgment cannot be supplied by this combined-owner
  technical review;
- external IANA/CLDR/source technical evidence does not become lawful-use or
  ingestion approval by citation.

## 5. Required v0.2 vector additions

The amended evidence should contain these exact new cases:

| ID | Input boundary | Expected documentation result |
|---|---|---|
| LV-04R | `ru` enabled, omitted from market order, is value default | `ru`, `value_default` |
| LV-08R | unsupported viewer `de-DE`, non-Legal read, `lv-LV` available | `lv-LV`, `market_fallback`, requested status `unsupported` |
| LV-09 | unsupported authoring/mutation locale | `unsupported_locale` |
| LV-10 | default locale exists but is disabled by effective market | `translation_missing` |
| LV-11 | exact duplicate JSON member | decoder rejection before map creation |
| LV-12 | canonical-equivalent `en-us` / `en-US` | contract invalid |
| LV-13 | withdrawn exact value plus safe fallback | exact excluded; fallback only if class policy permits |
| LV-14 | withdrawn mandatory value | unresolved/fail closed |
| CMP-01 | newer critical contract revision | `unsupported_contract_revision` |
| CMP-02 | stale optional cached revision | typed stale bounded read only |
| CMP-03 | stale mandatory cached revision | unresolved/fail closed |
| CMP-04 | dataset integrity mismatch | unresolved; no activation |

## 6. Retained blockers after amendments

Even after integration, OD-10 remains Proposed until:

1. Reference Data and Product Localization give attributable full-scope
   verdicts;
2. API, Content and Mobile accept the exact amended documentation vectors;
3. qualified Legal/Product policy closes applicable BCK20-OD-05 classes;
4. exact LV policy is accepted and EE/LT remain explicitly disabled or later
   receive separate market policy;
5. locale/source terms and executable-source gates are resolved where needed;
6. migration, withdrawal, rollback and minimum-client rules are accepted;
7. canonical status files are reconciled atomically.

API-DEC-05 and a separately Approved exact-file slice remain mandatory before
schema, generated clients or executable fixture parity.

## 7. Integration file map if owner accepts this review

Docs-only reconciliation:

- `docs/product/BACKEND_OD_10_LOCALIZATION_EVIDENCE.md` → v0.2;
- `docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md` → next factual revision;
- `docs/product/REFERENCE_DATA_LOCALIZATION_COVERAGE_MATRIX.md` → matching
  revision;
- `docs/product/BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md` → review evidence
  recorded, signatures/status unchanged;
- `docs/product/BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md` → current
  source/status reconciliation;
- `docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md` and
  `docs/architecture/LAUNCH_STATUS.md` → factual version/status only.

No application, backend runtime, schema, fixture, Firebase or deployment file
is in scope.

## 8. Proposed owner disposition

Recommended exact decision:

> Одобряю OD10-DOC-REV-01 v0.1 для target BCK-D1-OD10-EV-01 v0.1 /
> normalized-LF SHA-256
> 82c31bd8b03b7b627e1ebf978a135696311800fb0f4e01e9dc2b4af6800a299d:
> Accept design direction with required amendments F-001–F-012. Разрешаю
> docs-only integration и подготовку amended evidence v0.2. OD-10 остаётся
> Proposed; BCK-20 Draft; BCK20-OD-02/05 Open. Independent/qualified Legal
> verdict, schema, executable fixtures, runtime, Firebase, deployment, push и
> merge не разрешаю.

## 9. Acceptance criteria

1. **OD10-DOC-REV-AC-01:** the exact v0.1 target is pinned by normalized hash.
2. **OD10-DOC-REV-AC-02:** accepted properties and required amendments remain separate.
3. **OD10-DOC-REV-AC-03:** the unreachable `value_default` vector is identified and corrected without deleting the semantic step.
4. **OD10-DOC-REV-AC-04:** unsupported viewer read and authoring/mutation behavior are distinguished.
5. **OD10-DOC-REV-AC-05:** resolved and unresolved results form an explicit discriminated union.
6. **OD10-DOC-REV-AC-06:** approved text is not silently trimmed or Unicode-normalized.
7. **OD10-DOC-REV-AC-07:** locale normalization is revision-bound and executable source use remains gated.
8. **OD10-DOC-REV-AC-08:** duplicate wire members and canonical-equivalent locale keys fail closed.
9. **OD10-DOC-REV-AC-09:** fallback is non-recursive, deterministic and cycle-safe.
10. **OD10-DOC-REV-AC-10:** withdrawal, revocation, staleness and integrity failures cannot resurrect unsafe text.
11. **OD10-DOC-REV-AC-11:** EE/LT isolation evidence does not invent future locale policy.
12. **OD10-DOC-REV-AC-12:** compatibility vectors gain exact expected outcomes.
13. **OD10-DOC-REV-AC-13:** telemetry remains free of localized/user-authored content.
14. **OD10-DOC-REV-AC-14:** qualified Legal and source-use gates are not impersonated.
15. **OD10-DOC-REV-AC-15:** OD-10 remains Proposed after review and amendment integration.
16. **OD10-DOC-REV-AC-16:** no schema, executable fixture, runtime, Firebase, deployment, push or merge authority is created.
