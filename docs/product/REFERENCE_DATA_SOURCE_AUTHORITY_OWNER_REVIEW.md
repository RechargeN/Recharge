# BCK-20 — Source-Authority Combined-Owner Review Package

- ID: **BCK20-OD02-SRC-AUTH-REV-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — exact owner decision required**
- Frozen target: [BCK20-OD02-SRC-AUTH-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Target normalized-LF SHA-256: `3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6`
- Parent: [BCK-20 v0.2.15](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Workflow decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Proposed owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Product Localization + Content/source governance + Mobile + technical Security/Privacy**
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Independence: **none; combined-owner review**
- Qualified Security/Privacy/Legal claim: **none**
- Runtime effect: **none**

---

## 1. Purpose and recommended verdict

This package reviews one exact source-authority matrix revision. It does not
review changed content under the same filename and does not turn candidate
external authorities into approved ingestion sources.

Recommended verdict:

> **Accept source-authority design boundary with retained gates** for
> `BCK20-OD02-SRC-AUTH-01 v0.1` at the frozen hash above.

The verdict is limited to documentation structure, field-level authority,
ownership and fail-closed treatment. It does not close `BCK20-OD-02`, accept
actual source records or translations, approve licensing, provide independent
or qualified review, or authorize implementation.

## 2. Frozen-input verification

| Check | Observed | Result |
|---|---|---|
| Target identity | `BCK20-OD02-SRC-AUTH-01 v0.1` | Match |
| Normalized-LF SHA-256 | `3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6` | Match |
| Workflow target | `BCK20-OD02-L10N-01 v0.4` / `d7cad4f1…d6975` | Match |
| Record-family rows | 20 | Match |
| Source-registry rows | 13 | Match |
| Acceptance criteria | AC-01–18 sequential | Match |
| Local links | all resolved | Pass |
| Runtime/schema changes | none | Pass |

Any target content, version or normalized hash change invalidates this review.

## 3. Review perspectives

The six roles remain attributable even though the same person holds them.
This is zero-independence combined-owner evidence.

### 3.1 Reference Data

Verdict recommendation: **Accept design boundary with retained gates**.

- every included BCK-20 record family has one authority disposition;
- identity, semantics, localization, composition and distribution are distinct;
- source snapshot evidence requires version, retrieval, hash, terms, scope,
  parser and validation result;
- immutable revisions and conflict/freshness failures are explicit;
- unresolved market, service-area, policy, translation and dictionary inputs
  remain blocked.

### 3.2 Product/Market

Verdict recommendation: **Accept design boundary with retained gates**.

- official country/currency/locale/time-zone identifiers do not activate a
  Recharge market;
- market membership, supported locales, currency assignment, allowed zones
  and lifecycle require explicit internal owner records;
- Latvia remains only the first-cohort candidate;
- Estonia and Lithuania remain independently disabled;
- no source is treated as pricing, tax, product-feature or launch authority.

### 3.3 Product Localization

Verdict recommendation: **Accept design boundary with retained gates**.

- every translatable family has a declared class and minimum review;
- source locale is explicit or blocks translation;
- CLDR locale conventions cannot become Recharge product-copy authority;
- fallback remains deterministic, class-bound and market-scoped.

### 3.4 Content/source governance

Verdict recommendation: **Accept design boundary with retained gates**.

- canonical IDs and localized display values are separate;
- UN/CLDR display data cannot silently replace approved Recharge copy;
- translated labels cannot rewrite source meaning;
- approved source snapshots and copy remain absent;
- mandatory Legal/safety copy remains blocked under `BCK20-OD-05`.

### 3.5 Mobile

Verdict recommendation: **Accept design boundary with retained gates**.

- client cache and rendered text never become authority;
- locale, currency and time-zone technical sources have bounded field scope;
- unsupported/stale source revisions remain typed fail-closed states;
- no cache, adapter, supported-build matrix or executable fixture is approved.

### 3.6 Security/Privacy technical boundary

Verdict recommendation: **Accept design boundary with retained gates**.

- provider responses and matching hashes never become semantic authority;
- unknown/stale/conflicting/withdrawn source evidence fails closed;
- source artifacts require conservative evidence and terms tracking;
- independent Security/Privacy, data-inventory completion and qualified Legal
  evidence remain separate later gates.

This perspective is a combined-owner technical boundary only. It is not an
independent Security/Privacy assessment or professional Legal conclusion.

## 4. Source-family disposition audit

| Group | Families | Review disposition | Retained gate |
|---|---:|---|---|
| Accepted internal semantic source | 1 | Category System v1.4.3 exact identity/hash is usable as documentation authority | changed revision requires migration/review |
| External standard candidates | 4 | official source role is bounded correctly | exact pin, license/terms, extraction and executable evidence absent |
| Internal decision sources | 6 | ownership and required decision are explicit | accepted per-market/policy records absent |
| Translation/copy families | 4 | source/class/review separation is correct | approved source snapshots and copy absent |
| Blocked/deferred families | 4 | fail-closed outcome is explicit | service-area source/license, mandatory Legal copy and dictionary source absent |
| Deterministic derived metadata | 1 | manifest authority is correctly derived from approved inputs | schema/publisher/integrity implementation absent |

The grouping count is 20. It is a review aid; the target matrix rows remain the
canonical family-level disposition.

## 5. Findings and retained observations

No Blocking or Major contradiction exists inside the documentation-only
design boundary. The following observations remain mandatory gates:

| ID | Observation | Required treatment |
|---|---|---|
| `SRC-AUTH-O-01` | one person holds four owner roles | preserve separate perspectives and zero-independence disclosure |
| `SRC-AUTH-O-02` | external official source does not imply reusable license or ingestion permission | record exact terms, allowed use and pinned artifact before executable work |
| `SRC-AUTH-O-03` | market/source policy records are absent | keep market activation and affected families fail-closed |
| `SRC-AUTH-O-04` | service-area geometry has no accepted source/license | keep family unavailable; do not derive geometry from labels |
| `SRC-AUTH-O-05` | approved source snapshots and localized copy are absent | do not represent translations as approved or production-ready |
| `SRC-AUTH-O-06` | mandatory policy copy requires qualified Legal evidence | retain BCK20-OD-05 Open and fallback-forbidden behavior |
| `SRC-AUTH-O-07` | independent Security/Privacy review is absent | do not claim independent assurance or close production processing gates |
| `SRC-AUTH-O-08` | provider/schema/IAM/runtime evidence is absent | keep every executable gate closed |

## 6. Effect of acceptance

If §9 is accepted exactly:

1. the matrix becomes the current source-authority **design boundary** for
   BCK20-OD-02 documentation;
2. its 20 family dispositions and 13 source-registry rows may be cited by
   subsequent review packages;
3. candidate external authorities remain candidates until exact terms,
   retrieval/pin and executable evidence are separately approved;
4. internal Pending/Blocked/Deferred rows remain unavailable;
5. `BCK20-OD-02` remains Open because source records, independence and
   applicable qualified evidence are incomplete;
6. canonical BCK-20/D1 status reconciliation may record only the bounded
   design verdict and retained gaps;
7. no dataset, schema, provider, runtime or cloud work starts.

## 7. Retained gates

- `BCK20-OD-02` and `BCK20-OD-05`: **Open**;
- `OD-10`: **Proposed**;
- `BCK-20`: **Draft**;
- `BCK20-OD-03`: **Deferred**;
- market/source policy records: **Pending**;
- service-area source/license: **Blocked**;
- actual translations/source snapshots: **Pending**;
- auxiliary dictionaries: **Deferred**;
- source license/terms and pinned ingestion evidence: **Pending**;
- independent Security/Privacy and applicable qualified Legal evidence:
  **Pending**;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge: **unauthorized**.

## 8. Proposed signature record

```text
Decision input: BCK20-OD02-SRC-AUTH-REV-01 v0.1
Target: BCK20-OD02-SRC-AUTH-01 v0.1
Target normalized-LF SHA-256: 3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6
Named reviewer identity: RechargeN / Product owner
Combined roles: Reference Data owner; Product/Market owner; Product Localization owner; Content/source-governance owner; Mobile owner; technical Security/Privacy owner
Independence: none; combined-owner review
Qualified Security/Privacy/Legal claim: none
Proposed verdict: Accept source-authority design boundary with retained gates
Accepted scope: §§2–5 of this package and all 20 matrix-family dispositions
Retained observations: SRC-AUTH-O-01–08
Runtime authority: none
```

## 9. Exact owner decision requested

```text
Одобряю BCK20-OD02-SRC-AUTH-REV-01 v0.1:
Accept source-authority design boundary with retained gates для точного
BCK20-OD02-SRC-AUTH-01 v0.1 / SHA-256
3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6.
Подтверждаю совмещение ролей RechargeN / Product owner для Reference Data,
Product/Market, Product Localization, Content/source governance, Mobile и
technical Security/Privacy, отсутствие independent review и отсутствие
qualified Security/Privacy/Legal claim.
Внешние registry остаются candidate authority только в указанном field scope;
license/terms, pinned ingestion evidence и executable use остаются Pending.
BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 остаётся Proposed; BCK-20
остаётся Draft; BCK20-OD-03 остаётся Deferred. Unresolved source records,
independent Security/Privacy и applicable qualified Legal evidence остаются
Pending/Blocked/Deferred. Provider selection, schema, IAM/runtime, Firebase,
deployment, activation, push и merge не разрешаю.
```

## 10. Acceptance criteria

1. **BCK20-OD02-SRC-AUTH-REV-AC-01:** exact target identity and normalized-LF hash are frozen.
2. **BCK20-OD02-SRC-AUTH-REV-AC-02:** all 20 target family rows are covered by the review.
3. **BCK20-OD02-SRC-AUTH-REV-AC-03:** all 13 source-registry rows retain their exact bounded role.
4. **BCK20-OD02-SRC-AUTH-REV-AC-04:** six combined-owner roles remain separately attributable.
5. **BCK20-OD02-SRC-AUTH-REV-AC-05:** zero independence and absent professional qualification are explicit.
6. **BCK20-OD02-SRC-AUTH-REV-AC-06:** official external origin does not imply license or ingestion approval.
7. **BCK20-OD02-SRC-AUTH-REV-AC-07:** external standards cannot activate markets or create Recharge policy.
8. **BCK20-OD02-SRC-AUTH-REV-AC-08:** translations and rendered values never become semantic source authority.
9. **BCK20-OD02-SRC-AUTH-REV-AC-09:** missing, stale, conflicting and withdrawn evidence fails closed.
10. **BCK20-OD02-SRC-AUTH-REV-AC-10:** EE/LT remain independently disabled.
11. **BCK20-OD02-SRC-AUTH-REV-AC-11:** mandatory policy copy remains blocked under BCK20-OD-05.
12. **BCK20-OD02-SRC-AUTH-REV-AC-12:** independent Security/Privacy and applicable qualified Legal evidence remain Pending.
13. **BCK20-OD02-SRC-AUTH-REV-AC-13:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
14. **BCK20-OD02-SRC-AUTH-REV-AC-14:** acceptance authorizes only canonical documentation reconciliation.
15. **BCK20-OD02-SRC-AUTH-REV-AC-15:** no provider/schema/IAM/runtime/Firebase/deployment/activation/push/merge authority is created.
16. **BCK20-OD02-SRC-AUTH-REV-AC-16:** any target version/content/hash change requires a new review and owner decision.

## 11. Next action

Obtain the exact owner decision in §9. Before that decision, do not mark the
matrix Accepted, reconcile canonical statuses or create source data/runtime.
