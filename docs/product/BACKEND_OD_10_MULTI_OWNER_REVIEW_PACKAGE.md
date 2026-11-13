# BCK-D1 — OD-10 Multi-Owner Review Package

- Review ID: **OD10-OWN-COMB-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — five separate owner verdicts required**
- Exact evidence: [BCK-D1-OD10-EV-01 v0.2](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Evidence normalized-LF SHA-256:
  `dceebb4ed1f993523393c8a979099ae5b02798d50d8349275109ae92c8063cfd`
- Exact canonical proposal: [BCK-20 v0.2.20](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Canonical proposal normalized-LF SHA-256:
  `075be0f95c6d1dd1123e4b1f8742e876c6ce7b688ccfcb4f98e90937a0930e08`
- Review coordinator: **RechargeN / Product owner combined role**
- Independence: **none unless a later reviewer record proves otherwise**
- Qualified Legal/Privacy claim: **none**
- Runtime effect: **none**

---

## 1. Purpose and recommended disposition

This package replaces five serial documentation-review rounds with one frozen
input and five separately attributable verdicts:

1. `OD10-SIG-REF` — Reference Data;
2. `OD10-SIG-API` — API Platform;
3. `OD10-SIG-L10N` — Product Localization;
4. `OD10-SIG-CONTENT` — Content/source governance;
5. `OD10-SIG-MOBILE` — Mobile integration boundary.

The recommended verdict for every row is **Accept documentation design
boundary with retained gates**. One combined-role owner may record all five in
one exact response, but the verdicts remain separate and disclose zero
independence. Codex prepares evidence and is not a signatory.

The package does not accept OD-10. Qualified Legal/Product policy,
independent review and executable parity remain separate gates.

## 2. Common design boundary accepted for review

The frozen v0.2 evidence consistently defines:

- stable IDs/enums/references that never become localized labels;
- one bounded `LocalizedTextV1` documentation shape;
- revision-bound locale normalization identity;
- duplicate-member rejection before map materialization;
- canonical-equivalent locale-key rejection after normalization;
- deterministic, non-recursive, MarketConfig-bound fallback;
- separate viewer-read and authoritative-use behavior for unsupported locales;
- a discriminated `Resolved | Unresolved` result;
- candidate filtering for withdrawal, revocation, expiry, market,
  environment, freshness and integrity;
- content-free telemetry and diagnostics;
- explicit LV evidence and EE/LT isolation;
- fail-closed Legal/safety behavior;
- separation of documentation evidence from schema, fixtures and runtime.

No perspective may reinterpret this common boundary silently. A semantic
change requires a new evidence revision and revalidation of all affected
verdicts.

## 3. Separate perspective verdicts

### 3.1 `OD10-SIG-REF` — Reference Data

**Recommended verdict:** Accept documentation design boundary with retained
gates.

Accepted within this perspective:

- dataset and MarketConfig revisions remain explicit resolution inputs;
- published revision identity is immutable and content-hashed;
- locale normalization profile identity is revision-bound;
- default and fallback candidates are eligible only inside the effective
  market/environment policy;
- withdrawn, revoked, stale mandatory and integrity-failed values cannot be
  resurrected by fallback or rollback;
- EE/LT cannot inherit Latvia activation readiness.

Retained gates:

- exact normalization algorithm/library/registry pin remains deferred to
  API-DEC-05 and an Approved executable slice;
- external-source allowed use and source eligibility remain unresolved;
- snapshot storage, parser, dataset publication and distribution remain
  unauthorized;
- BCK20-OD-02/03/05 remain Open/Deferred as currently recorded.

### 3.2 `OD10-SIG-API` — API Platform

**Recommended verdict:** Accept documentation design boundary with retained
gates.

Accepted within this perspective:

- success and failure are structurally distinct;
- unresolved results carry no fake resolved locale or success kind;
- unsupported viewer read is distinct from unsupported authoring,
  publication and mutation;
- unsupported/newer critical contract revisions fail closed;
- raw duplicate object members must be rejected before ordinary map decode;
- request/result revision identity is explicit enough for later schema work.

Retained gates:

- JSON Schema/IDL, enum encoding, field optionality and generated-client
  behavior remain deferred to API-DEC-05;
- exact transport envelope and wire error mapping remain part of the future
  executable contract slice;
- no schema, generated client, callable export or endpoint is authorized;
- compatibility must later be proven with cross-language fixtures.

### 3.3 `OD10-SIG-L10N` — Product Localization

**Recommended verdict:** Accept documentation design boundary with retained
gates.

Accepted within this perspective:

- approved text is never silently trimmed, Unicode-normalized or rewritten
  during resolution;
- whitespace-only values are missing rather than successful translations;
- viewer locale, source/content locale and target locale remain distinct;
- fallback order is deterministic and never arbitrary map iteration;
- fallback/missing/unsupported states remain visible to downstream product
  policy;
- Latvia evidence does not invent Estonia or Lithuania policy.

Retained gates:

- exact LV supported-locale, fallback and mandatory-copy policy still needs
  an attributable market/product record;
- EE/LT locale tables require independent future market decisions;
- translation quality, reviewer qualification and source-copy evidence remain
  outside this verdict;
- machine translation and silent auto-publication remain prohibited.

### 3.4 `OD10-SIG-CONTENT` — Content/source governance

**Recommended verdict:** Accept documentation design boundary with retained
gates.

Accepted within this perspective:

- content language is owned by the content record, not inferred from viewer
  locale;
- reference labels and user-authored content remain different families;
- withdrawn/revoked/expired content is ineligible before lookup;
- search/indexing may use declared translations only with provenance;
- telemetry contains no localized values or user-authored text;
- source and Legal permissions are not inferred from technical availability.

Retained gates:

- source-authority content, lawful allowed use and notices remain Pending;
- mandatory local copy and fallback-forbidden families remain BCK20-OD-05;
- correction, withdrawal and re-publication workflows require later
  executable evidence;
- this verdict supplies no copy approval or qualified Legal conclusion.

### 3.5 `OD10-SIG-MOBILE` — Mobile boundary

**Recommended verdict:** Accept documentation design boundary with retained
gates.

Accepted within this perspective:

- Mobile consumes typed resolved/unresolved state rather than reimplementing
  fallback in presentation;
- unsupported-request success remains distinguishable from exact support;
- stale, unsupported-contract and translation-missing states are explicit;
- authoritative mutation never proceeds from a viewer-only fallback result;
- locale/dataset/market revisions remain available for cache and diagnostic
  decisions without logging content;
- newer critical revisions fail closed rather than being guessed by clients.

Retained gates:

- indicator/copy/accessibility behavior depends on later Product/L10N policy;
- cache TTL, invalidation and offline policy remain BCK20-OD-03/BCK-18 work;
- mapper, repository, datasource, controller and UI integration remain absent;
- executable parity and minimum-client behavior require a separately Approved
  slice.

## 4. Cross-perspective conflict resolution

If perspective requirements conflict:

1. Legal/safety fail-closed policy wins over viewer convenience;
2. effective market/environment eligibility wins over stored-value presence;
3. content ownership and source authority win over display fallback;
4. API contract identity wins over client-local inference;
5. unknown critical revision, integrity mismatch or ambiguous authority fails
   closed;
6. the conflict is recorded as a new finding rather than resolved silently.

## 5. Exact retained gates after all five verdicts

Even if all five recommended verdicts are recorded:

- OD-10 remains **Proposed**;
- BCK-20 remains **Draft**;
- BCK20-OD-02 and BCK20-OD-05 remain **Open**;
- BCK20-OD-03 remains **Deferred**;
- API-DEC-05 remains the physical schema/toolchain gate;
- qualified Legal/Product policy for mandatory copy remains Pending;
- independent review is not created by combined roles;
- external-source terms, eligibility and source-copy gates remain open;
- LV market policy is not made executable and EE/LT remain disabled;
- schema, fixtures, datasets, parser, mobile adapters, runtime, Firebase,
  deployment, activation, push and merge remain unauthorized.

## 6. Status effect of owner acceptance

| Item | Result after exact owner acceptance |
|---|---|
| five perspective verdict IDs | recorded for the exact frozen hashes only |
| documentation design review | complete under disclosed combined ownership |
| independent review | still absent |
| qualified Legal/Product policy | still absent |
| OD-10 | Proposed |
| BCK-20 | Draft |
| API-DEC-05 | Deferred |
| executable parity | absent |
| runtime/cloud/markets | unchanged and unauthorized |

Any target-hash change invalidates the affected verdicts until an impact
review explicitly revalidates them.

## 7. Recommended exact owner response

```text
Одобряю OD10-OWN-COMB-REV-01 v0.1:
принимаю пять раздельных verdict — OD10-SIG-REF, OD10-SIG-API,
OD10-SIG-L10N, OD10-SIG-CONTENT и OD10-SIG-MOBILE — как Accept
documentation design boundary with retained gates для точных
BCK-D1-OD10-EV-01 v0.2 / normalized-LF SHA-256
dceebb4ed1f993523393c8a979099ae5b02798d50d8349275109ae92c8063cfd
и BCK-20 v0.2.20 / normalized-LF SHA-256
075be0f95c6d1dd1123e4b1f8742e876c6ce7b688ccfcb4f98e90937a0930e08.
Подтверждаю совмещение ролей RechargeN / Product owner и отсутствие
independent review или qualified Legal/Privacy claim. OD-10 остаётся
Proposed; BCK-20 Draft; BCK20-OD-02/05 Open; BCK20-OD-03 и API-DEC-05
Deferred. Schema, executable fixtures, datasets, parser, runtime, Firebase,
deployment, activation, push и merge не разрешаю.
```

## 8. Acceptance criteria

1. **OD10-OWN-COMB-AC-01:** evidence v0.2 and BCK-20 v0.2.20 are frozen by exact normalized hash.
2. **OD10-OWN-COMB-AC-02:** five perspective verdict IDs remain separate.
3. **OD10-OWN-COMB-AC-03:** one owner may hold disclosed combined roles without creating independence.
4. **OD10-OWN-COMB-AC-04:** Codex is not a signatory.
5. **OD10-OWN-COMB-AC-05:** Reference Data accepts only the documentation revision/eligibility boundary.
6. **OD10-OWN-COMB-AC-06:** API accepts no physical schema or transport mapping.
7. **OD10-OWN-COMB-AC-07:** Localization accepts no final market locale table or translation workflow execution.
8. **OD10-OWN-COMB-AC-08:** Content accepts no source, copy or Legal approval.
9. **OD10-OWN-COMB-AC-09:** Mobile accepts no adapter, cache or UI implementation.
10. **OD10-OWN-COMB-AC-10:** viewer fallback never grants mutation authority.
11. **OD10-OWN-COMB-AC-11:** unknown critical revisions and integrity ambiguity fail closed.
12. **OD10-OWN-COMB-AC-12:** EE/LT policy and activation remain undecided and disabled.
13. **OD10-OWN-COMB-AC-13:** BCK20-OD-02/05 remain Open and BCK20-OD-03 Deferred.
14. **OD10-OWN-COMB-AC-14:** API-DEC-05 remains the schema/toolchain gate.
15. **OD10-OWN-COMB-AC-15:** qualified Legal/Product policy remains mandatory where applicable.
16. **OD10-OWN-COMB-AC-16:** combined-role verdicts do not claim independent review.
17. **OD10-OWN-COMB-AC-17:** target-hash change invalidates affected verdicts pending impact review.
18. **OD10-OWN-COMB-AC-18:** OD-10 remains Proposed and BCK-20 Draft.
19. **OD10-OWN-COMB-AC-19:** owner acceptance permits documentation reconciliation only.
20. **OD10-OWN-COMB-AC-20:** schema, fixtures, datasets, runtime, Firebase, deployment, push and merge remain unauthorized.

## 9. Next action

Freeze this package by normalized-LF SHA-256. The owner may accept all five
separate verdicts with the exact response in §7. Only after that decision may
canonical ledgers record the five bounded verdicts; OD-10 still cannot advance
without retained qualified/executable gates.
