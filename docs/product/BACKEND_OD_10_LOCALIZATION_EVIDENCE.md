# BCK-D1 — OD-10 Localization Contract Evidence

- Evidence ID: **BCK-D1-OD10-EV-01**
- Version: **0.2**
- Date: **2026-09-19**
- Decision status: **Proposed — not Accepted**
- Evidence status: **Review — F-001–F-012 integrated; specialist/Legal gates pending**
- Runtime status: **Absent**
- Accountable owner: **Reference Data owner**
- Required co-owners: **API Platform, Product Localization, Content, Mobile and Legal/Privacy**
- Canonical proposal: [BCK-20 §21](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Owner review: [OD10-DOC-REV-01 v0.1](BACKEND_OD_10_LOCALIZATION_OWNER_REVIEW.md)
- Owner decision: [OD10-DOC-DEC-01 v0.1](BACKEND_OD_10_LOCALIZATION_OWNER_DECISION.md)
- Runtime effect: **none**

---

## 0. v0.2 reconciliation

OD10-DOC-DEC-01 integrates F-001–F-012 from the exact frozen owner review.
This revision corrects the unreachable `value_default` example, separates
unsupported viewer reads from authoritative writes, defines discriminated
results and closes ambiguity around normalization, duplicate keys, fallback,
withdrawal, cache/integrity and telemetry semantics.

OD-10 remains Proposed. This revision is documentation evidence only and does
not supply independent/qualified review or executable fixture parity.

## 1. Purpose and verdict

This package makes OD-10 reviewable with deterministic examples. It does not
replace BCK-20 and does not create executable schema, generated client,
dataset, mobile adapter or backend distribution service.

`LocalizedTextV1` and the fallback algorithm are internally coherent and stay
`Proposed`. Acceptance remains blocked by fixture execution, owner sign-off,
Legal-copy rules and full LV/EE/LT market review.

## 2. Contract under review

```text
LocalizedTextV1 {
  defaultLocale: BCP47
  values: Map<BCP47, non-empty Unicode string>
}
```

Required invariants:

- `defaultLocale` exists in `values`;
- `defaultLocale` is a resolution candidate only when enabled by the effective
  MarketConfig;
- locale keys are canonical BCP 47 and duplicate-equivalent keys are rejected;
- the wire decoder rejects duplicate object members before map materialization;
- empty or whitespace-only strings are absent, not translations;
- approved text is not silently trimmed, Unicode-normalized or rewritten;
- locale identity includes `localeNormalizationProfileRevision`; unknown or
  newer critical profiles fail closed;
- IDs/enums remain stable and are never replaced by localized labels;
- reference labels and user-authored content are different record families;
- no machine translation or arbitrary “first map key” fallback in v1;
- legal/safety-critical values may forbid fallback and then fail closed.

## 3. Deterministic resolution algorithm

Inputs:

```text
resolveLocalizedText(
  value,
  requestedLocale,
  effectiveMarketConfig,
  fallbackForbidden
)
```

Candidate order for non-Legal text:

1. exact requested supported locale;
2. explicitly configured fallback for that requested locale;
3. market `fallbackLocaleOrder` in stored order;
4. `value.defaultLocale`;
5. typed `translation_missing`.

Before lookup, candidates are canonicalized using the exact normalization
profile, deduplicated and restricted to locales enabled by the effective
MarketConfig revision. V1 reads only the requested locale's configured ordered
fallback list and performs no recursive graph traversal. Self-reference,
canonical duplicates and any recursive/cyclic form are invalid configuration.

Candidate eligibility is checked before value lookup. Withdrawn, revoked,
expired, wrong-market, wrong-environment and disallowed stale values are never
resolved or resurrected by fallback/rollback. If `fallbackForbidden=true`,
only the exact required locale policy defined for that legal/safety record may
succeed; a generic language fallback is not used.

For a non-Legal viewer read, an unsupported requested locale may continue
through its explicitly configured fallback list and then the market fallback
order, but the success remains explicitly marked
`requestedLocaleStatus=unsupported`. Authoring, publication, mutation and
fallback-forbidden resolution reject an unsupported requested locale with
`unsupported_locale`.

The result is a discriminated union:

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

An unresolved result carries neither fake `resolvedLocale` nor success kind.

## 4. Review fixture vectors

These vectors are documentation evidence. They must later become executable
contract fixtures only after the required schema/tooling decision.

### 4.1 Latvia baseline

```json
{
  "marketId": "lv",
  "supportedLocales": ["lv-LV", "en", "ru"],
  "fallbackLocaleOrder": ["lv-LV", "en", "ru"],
  "explicitLocaleFallbacks": {"lv": ["lv-LV"], "en-GB": ["en"]}
}
```

| Case | Requested/value | Expected |
|---|---|---|
| LV-01 exact | request `lv-LV`; values include `lv-LV` | `lv-LV`, `exact` |
| LV-02 configured | request `en-GB`; values include `en` | `en`, `configured_fallback`, requested status `unsupported` |
| LV-03 market order | request `lv-LV`; only `en`,`ru`; default `ru` | `en`, `market_fallback` |
| LV-04 value default | case-specific config keeps `ru` enabled but omits it from market fallback order; default `ru` exists | `ru`, `value_default` |
| LV-05 missing | no enabled candidate has a value | `translation_missing` |
| LV-06 forbidden | Legal `lv-LV` required, only `en` exists | `translation_missing`, fail closed |
| LV-07 empty | `lv-LV` is whitespace only | treated absent; continue or fail by policy |
| LV-08 unknown viewer read | request `de-DE`, not enabled; non-Legal read; `lv-LV` exists | `lv-LV`, `market_fallback`, requested status `unsupported` |
| LV-09 unsupported authoritative use | authoring/publication/mutation requests `de-DE` | `unsupported_locale` |
| LV-10 disabled default | default value exists but its locale is disabled by effective market | `translation_missing` |
| LV-11 duplicate wire member | exact locale member appears twice in raw object | decoder rejection before map creation |
| LV-12 canonical duplicate | raw keys `en-us` and `en-US` | contract invalid after canonicalization |
| LV-13 withdrawn optional exact | exact value withdrawn; safe fallback exists | exact excluded; fallback only when class policy permits |
| LV-14 withdrawn mandatory | required exact Legal/safety value withdrawn | unresolved; fail closed |

### 4.2 Estonia and Lithuania isolation

| Case | Market state | Expected |
|---|---|---|
| EE-01 | EE disabled; valid `et-EE` data exists | no EE activation or publication |
| LT-01 | LT disabled; valid `lt-LT` data exists | no LT activation or publication |
| EE-02 | enabling EE revision | changes EE effective pointer only; LV/LT unchanged |
| LT-02 | rollback LT revision | restores previous LT pointer only; LV/EE unchanged |
| BAL-01 | newer unsupported schema | typed unsupported/stale state; no mutation |

These vectors prove isolation only. They do not decide future EE/LT
`supportedLocales`, fallback order or mandatory-copy policy, and Latvia
fallback cannot satisfy EE/LT activation readiness.

### 4.3 Invalid contract vectors

- missing `defaultLocale` value;
- duplicate-equivalent locale keys after canonicalization;
- empty `values` map;
- whitespace-only translation;
- malformed or unsupported locale key;
- fallback candidate outside effective MarketConfig;
- recursive fallback, self-reference, cycle or duplicate chain;
- mutable reuse of an already published dataset revision;
- localized label used as entity ID/reference;
- Legal value resolving through forbidden fallback;
- server-enabled market without required Legal/support/localization evidence.

## 5. Content-language boundary

- `contentLocale` records the author-declared source language;
- `availableLocales` lists explicit stored translations, not inferred languages;
- viewer locale never rewrites source content;
- search indexes record locale and provenance per indexed representation;
- translation is a new attributable representation, not silent mutation;
- publication readiness rules belong to BCK-07/domain policy;
- legal document revision and accepted locales belong to Legal/Privacy, while
  BCK-20 distributes only an approved reference.

Diagnostics may record canonical locale codes, typed result, revision IDs,
freshness class and timing. They must not contain localized values,
user-authored text or arbitrary raw locale input. Attempted-candidate evidence
is bounded to configured canonical locale IDs.

## 6. Compatibility and revision evidence

Documentation outcomes are:

| Case | Required result |
|---|---|
| current supported contract/revision | resolve normally |
| previous compatible contract | resolve only inside the declared compatibility window |
| newer unsupported critical revision | `unsupported_contract_revision`; no mutation |
| known stale optional cache | typed stale state; bounded read only when class policy permits |
| stale mandatory/Legal cache | unresolved; fail closed |
| integrity/hash mismatch | unresolved; quarantine/re-fetch only through an authorized path |
| withdrawn translation | never resolve or return through rollback |
| safe compatible rollback | atomic pointer change to a verified eligible revision |
| unsafe/incompatible rollback | disable affected surface/mutation |

Later executable evidence requires fixtures for:

- current, previous compatible and newer unsupported contract versions;
- immutable dataset revision/hash and atomic effective pointer;
- cached current/stale/unsupported states;
- alias/deprecation without ID reuse;
- repeatable publish and rollback;
- LV activation leaving EE/LT disabled;
- consumer behavior when a required translation disappears or is withdrawn;
- minimum-client and observation window before destructive retirement.

The documentation matrix does not satisfy executable parity.

## 7. Owner review questions

| Owner | Must decide |
|---|---|
| Reference Data | normalization profile/revision, revision/hash and publish authority |
| API Platform | exact wire/result/error mapping and forward compatibility |
| Product Localization | LV/EE/LT locale/fallback tables and quality workflow |
| Content | source language, translated representation and readiness policy |
| Mobile | cache/freshness/fallback indicator/accessibility behavior |
| Legal/Privacy | which copy forbids fallback and required locale/revision evidence |

## 8. Acceptance and runtime gates

OD-10 becomes `Accepted` only when:

1. all fixture vectors have expected outputs approved by the named owners;
2. exact LV/EE/LT locale and fallback policies are attached;
3. legal/safety fallback-forbidden families are enumerated;
4. schema evolution and minimum-client behavior are accepted;
5. dataset publish/rollback/withdrawal evidence is reviewable;
6. Category System v1.4.3 identity and 28/530 integrity remain preserved;
7. BCK-01/02/03/07/18/20 and LAUNCH_STATUS update atomically.
8. applicable source terms/access and executable-source gates are resolved.

Acceptance does not authorize schema files or runtime. Those require
API-DEC-05 where applicable and a separately Approved executable slice.

## 9. Fail-closed state now

- OD-10 remains `Proposed`;
- BCK-20 remains Draft;
- Latvia runtime localization is not declared implemented;
- Estonia and Lithuania remain independently disabled;
- no dynamic backend configuration may introduce an unknown locale/schema;
- missing mandatory Legal/safety text blocks the affected activation.

## 10. Evidence acceptance criteria

1. **OD10-EV-AC-01:** one `LocalizedTextV1` shape is used.
2. **OD10-EV-AC-02:** default locale must have a non-empty value.
3. **OD10-EV-AC-03:** fallback order is deterministic and deduplicated.
4. **OD10-EV-AC-04:** arbitrary map iteration is never fallback.
5. **OD10-EV-AC-05:** missing translation is typed.
6. **OD10-EV-AC-06:** Legal/safety fallback can fail closed.
7. **OD10-EV-AC-07:** IDs never become localized strings.
8. **OD10-EV-AC-08:** source language is not viewer locale.
9. **OD10-EV-AC-09:** LV/EE/LT activation is isolated.
10. **OD10-EV-AC-10:** Category System v1.4.3 identity is preserved.
11. **OD10-EV-AC-11:** Acceptance and executable schema/runtime are separate.
12. **OD10-EV-AC-12:** this document changes no dataset or application behavior.
13. **OD10-EV-AC-13:** viewer-read fallback from an unsupported locale remains typed and distinct from authoritative-use rejection.
14. **OD10-EV-AC-14:** resolved and unresolved outcomes are structurally distinct.
15. **OD10-EV-AC-15:** approved text is never silently trimmed or Unicode-normalized during resolution.
16. **OD10-EV-AC-16:** locale normalization identity is revision-bound and unknown critical profiles fail closed.
17. **OD10-EV-AC-17:** duplicate raw members and canonical-equivalent locale keys are rejected at the correct boundary.
18. **OD10-EV-AC-18:** v1 fallback is non-recursive and rejects cyclic configuration.
19. **OD10-EV-AC-19:** withdrawn, revoked, stale mandatory or integrity-failed values cannot resolve through fallback/rollback.
20. **OD10-EV-AC-20:** EE/LT disabled-state evidence does not decide future locale policy.
21. **OD10-EV-AC-21:** compatibility cases have exact documentation outcomes but no executable-pass claim.
22. **OD10-EV-AC-22:** telemetry contains no localized or user-authored text.
23. **OD10-EV-AC-23:** qualified Legal and external-source allowed-use gates remain independent and Pending.
24. **OD10-EV-AC-24:** OD10-DOC-DEC-01 creates no schema, fixture, runtime, Firebase, deployment, push or merge authority.
