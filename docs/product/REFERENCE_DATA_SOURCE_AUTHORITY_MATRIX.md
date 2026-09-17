# BCK-20 — Reference Data Source-Authority Matrix

- ID: **BCK20-OD02-SRC-AUTH-01**
- Version: **0.2**
- Date: **2026-09-17**
- Status: **Owner decision recorded — source-authority design boundary accepted with retained gates**
- Decision served: **BCK20-OD-02 — translation source/review workflow**
- Parent: [BCK-20 v0.2.16](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Exact workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Workflow normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Exact-v0.4 owner decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Source-authority owner decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Canonical taxonomy: [Category System v1.4.3](CATEGORY_SYSTEM.md)
- Accountable owner: **Reference Data owner**
- Required review perspectives: **Product Localization, Content/source governance, Mobile and Security/Privacy; qualified Legal where applicable**
- Runtime effect: **none**

---

## 1. Purpose and bounded verdict

This matrix populates the source-authority fields required by workflow §5.6
without creating a dataset, schema, provider integration or runtime. It tells
future reviewers where each value may come from, who owns its meaning and what
must happen when evidence is missing or stale.

Recorded verdict:

> **Accept source-authority design boundary with retained gates** for this
> exact document revision and hash.

Acceptance would make the matrix the documentation authority for source
selection. It would not accept `BCK20-OD-02`, `BCK20-OD-05`, `OD-10` or
`BCK-20`; approve any actual translation; license external data; authorize
ingestion; or provide independent/qualified professional evidence.

## 2. Authority vocabulary

| Term | Meaning |
|---|---|
| Normative identity source | controls stable code/identifier membership and lifecycle |
| Semantic source | controls the meaning of a Recharge-owned record or field |
| Locale-data source | supplies standardized display/formatting data, not Recharge product policy |
| Composition owner | assembles already approved references without rewriting their meaning |
| Translation source owner | fixes source locale, source text/revision and change reason before translation |
| Distributor | transports an approved immutable revision; never becomes semantic authority |
| Evidence snapshot | immutable record of source version, retrieval time, hash/license and validation result |

Authority never transfers merely because a value was copied, cached,
translated, rendered or distributed. A translation is not a new semantic
source. A provider response, client cache, search index or Firestore document
cannot override the named source.

## 3. Source registry

External sources were checked on **2026-09-17**. “Verified” means the official
source and its stated role were observed; it does not mean automated use,
licensing or a particular release is approved.

| Source ID | Authority and exact role | Current evidence | Status / limitation |
|---|---|---|---|
| `SRC-INT-CAT-143` | Recharge [Category System v1.4.3](CATEGORY_SYSTEM.md) controls taxonomy IDs, aliases, profiles, fields, status and meaning | Accepted; normalized-LF SHA-256 `5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9` | approved internal semantic source; a changed hash/version requires explicit migration/review |
| `SRC-ISO-3166` | [ISO 3166 Maintenance Agency](https://www.iso.org/iso-3166-country-codes.html) controls country code elements | official ISO source observed | candidate normative code source; license/retrieval method must be approved before ingestion |
| `SRC-UN-M49` | [UN Statistics Division M49](https://unstats.un.org/unsd/methodology/m49/) supplies UN short names, numeric M49 and ISO alpha mappings | official UNSD source observed | candidate name/mapping evidence; statistical grouping is not Recharge market policy |
| `SRC-ISO-4217` | [ISO 4217](https://www.iso.org/standard/64758.html) defines alphabetic/numeric currency codes and minor-unit relationship | current standard page observed | candidate standard authority; not exchange-rate, pricing or tax authority |
| `SRC-SIX-4217` | [SIX](https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html) is the ISO 4217 Maintenance Agency | official maintenance role observed | candidate change-feed authority; terms and reproducible retrieval remain gated |
| `SRC-EU-EURO` | [European Commission euro-area record](https://economy-finance.ec.europa.eu/euro/what-euro-area_en) evidences euro adoption by EU Member States | official Commission page observed | corroborates current market-currency association; does not select Recharge markets or pricing policy |
| `SRC-IANA-LANG` | [IANA Language Subtag Registry](https://www.iana.org/assignments/language-subtags-tags-extensions) controls registered BCP 47 subtags/extensions | official registry observed | candidate identifier-validation source; Recharge supported locales remain an internal product decision |
| `SRC-UNICODE-CLDR` | [Unicode CLDR / UTS #35](https://www.unicode.org/reports/tr35/) supplies locale display/formatting data and algorithms | CLDR 48.2 / UTS #35 observed | candidate locale-data source; not authority for Recharge copy, Legal meaning or supported-locale activation |
| `SRC-IANA-TZDB` | [IANA Time Zone Database](https://www.iana.org/time-zones) supplies zone identifiers and civil-time transition data | release 2026d observed | candidate technical source; IANA itself states tzdb is not legal authority for political decisions |
| `SRC-INT-MARKET` | Recharge Product/Market owner decision controls market IDs, lifecycle and enabled product locales | no accepted per-market source record exists | **Pending / fail closed** |
| `SRC-INT-SERVICE-AREA` | Recharge Market/Geo owner controls service-area identity and geometry from an accepted licensed/official source | no accepted source or license exists | **Pending / family unavailable** |
| `SRC-INT-POLICY` | Each owning policy/domain controls its policy revision and meaning | references exist conceptually; exact accepted revisions incomplete | **Pending; BCK-20 may link but not author** |
| `SRC-INT-AUX` | Named Category/Product owner controls each auxiliary dictionary after a source decision | no dictionary source accepted | **Deferred under BCK20-OD-06** |

External sources must be pinned by retrieved artifact/release, retrieval URI,
retrieved-at UTC, content hash, license/terms evidence and parser version before
they can enter an executable slice. A “latest” URL is discovery input only.

## 4. Populated source-authority matrix

The matrix implements every field in `TranslationSourceAuthorityEntry`.
`—` means not translatable. `Pending` is a blocking state, not permission to
invent a value.

| Record family | Field scope | Owning domain | Accountable source owner role | Source locale | Translation class | Minimum review | Policy/fallback | Disposition |
|---|---|---|---|---|---|---|---|---|
| `market_identity` | stable `marketId`, market-to-country link | Reference Data composition; Product/Market semantics | Product/Market owner | — | `identifier` | Product + Reference Data | accepted market decision; no fallback | **Pending**: internal source record absent |
| `market_activation` | disabled/internal/invited/cohort/enabled/suspended and effective revision | Product/Market + Release governance | Product owner; Operations executes only after gates | — | `identifier` | Product + Security/Privacy + Operations; Legal where applicable | market gate references; fail closed | **Pending**; LV is only a candidate, EE/LT disabled |
| `country_codes` | ISO alpha-2/alpha-3 and optional M49 numeric mapping | Reference Data | Reference Data owner using ISO/UN evidence | — | `identifier` | Reference Data; Product for included-market scope | `SRC-ISO-3166`, `SRC-UN-M49`; no fallback for codes | source candidates identified; ingestion/license gate retained |
| `country_display_names` | localized country/territory display label | Reference Data localization | Content/source owner + Product Localization | source-specific | `reference_standard` | translator + Product Localization + Content | UN/CLDR evidence; OD-10 fallback may apply | copy not yet approved |
| `currency_codes` | alphabetic/numeric code and minor-unit metadata | Reference Data; pricing remains outside BCK-20 | Reference Data owner using ISO/SIX | — | `identifier` | Reference Data + owning money/domain reviewer | `SRC-ISO-4217`, `SRC-SIX-4217`; exact code only | source candidates identified; no money runtime authority |
| `market_currency_assignment` | allowed currency code per market revision | Product/Market policy composed by Reference Data | Product/Market owner | — | `identifier` | Product + Reference Data; Finance/Legal where policy requires | official adoption evidence plus explicit Recharge decision | **Pending** despite current LV/EE/LT `EUR` launch input |
| `currency_display_data` | localized names/symbols/format patterns | Mobile/Reference Data consumption | Product Localization using CLDR; Money domain validates meaning | locale record | `reference_standard` | Product Localization + Mobile | pinned CLDR; code always remains visible/available; no semantic fallback for amount/currency mismatch | copy/format release not approved |
| `locale_identifiers` | canonical BCP 47 language/script/region tags | Reference Data | Reference Data owner using IANA | — | `identifier` | Reference Data + Mobile | `SRC-IANA-LANG`; exact canonicalization | source candidate identified |
| `supported_locale_policy` | enabled locales and fallback order per market | Product/Market policy | Product owner + Product Localization owner | — | `identifier` | Product Localization + Content + Mobile + Security/Privacy; Legal where applicable | explicit market revision; no device inference | **Pending**; LV list is a Draft launch input, EE/LT disabled |
| `locale_display_and_format_data` | locale names, plural/number/date/currency formatting conventions | Mobile/localization consumption | Product Localization using Unicode CLDR | locale record | `reference_standard` | Product Localization + Mobile | pinned CLDR; never substitutes Recharge product copy | source candidate identified; executable pin absent |
| `timezone_identifiers_rules` | IANA zone IDs and transition data | Reference Data | Reference Data owner using IANA tzdb | — | `identifier` | Reference Data + platform compatibility review | pinned tzdb release; unknown/removed ID fails closed | candidate technical source identified |
| `market_timezone_policy` | default and allowed zones per market | Product/Market policy composed by Reference Data | Product/Market owner | — | `identifier` | Product + Reference Data | IANA IDs plus explicit market revision | **Pending**; Riga/Tallinn/Vilnius are Draft launch inputs only |
| `taxonomy_semantics` | category/subcategory IDs, aliases, profiles, fields, status and meaning | Category System | Category/Product owner | — for identifiers; explicit per-field source locale before prose translation | `identifier` for IDs; `reference_standard` for descriptions | Category/Product owner; Product Localization for translated labels | `SRC-INT-CAT-143`; OD-10 fallback only for approved labels | internal semantic source accepted |
| `taxonomy_localized_labels` | approved label/description per taxonomy ID and locale | Product Localization/Content | Content source owner + Product Localization | must be declared per source snapshot | `reference_standard` | translator + Product Localization + Content | exact Category version and source snapshot; deterministic OD-10 fallback | **Pending**: approved copy/source snapshots absent |
| `service_area_identity_geometry` | stable area ID, type, geometry/bounds and revision | Market/Geo policy; Reference Data distributes | Market/Geo owner | — | `identifier` | Product + Geo/data-license + Security/Privacy as applicable | accepted official/licensed source; no geometry inferred from label | **Blocked**: source/license/owner evidence absent |
| `service_area_display_labels` | localized area names | Market/Geo + Product Localization | Market/Geo source owner + Product Localization | source-specific | `reference_standard` | translator + Product Localization + local Content review | source geometry revision bound; OD-10 fallback only if approved | **Blocked** with parent family |
| `policy_revision_references` | content/privacy/minors/T&S/provider/support policy IDs and revisions | each owning BCK/domain | owning policy authority | — | `identifier` | owning domain + required Security/Privacy/Legal reviewers | exact accepted policy record; no fallback or inferred “latest” | **Pending**; BCK-20 is link/composition owner only |
| `mandatory_policy_copy` | terms, consent, age/safety, rights, emergency notices | Legal/policy-owning domain | qualified Legal + Product/domain owner | exact market/locale source | `legal_safety_mandatory` | translator + independent reviewer + qualified Legal + Product/domain + Mobile | BCK20-OD-05; `fallbackForbidden` unless qualified policy says otherwise | **Blocked**; no content may be authored here |
| `auxiliary_dictionaries` | genre/topic/music or other future canonical entries | assigned Category/Product domain | named dictionary source owner | declared by future decision | classification assigned before work | future owner-specific review | BCK20-OD-06; no ad-hoc IDs/fallback | **Deferred / absent** |
| `dataset_manifest_metadata` | IDs, revisions, hashes, counts, source refs and compatibility metadata | Reference Data | Reference Data publisher from approved inputs | — | `identifier` | Reference Data + API/Operations integrity review | deterministic derivation; never hand-translated | design-ready; executable schema/publisher absent |

## 5. Latvia/Baltics bounded facts

The following are candidate composition inputs, not an activated dataset:

| Market | Country code | Currency evidence | Locale-policy state | Time-zone-policy state | Activation |
|---|---|---|---|---|---|
| `lv` | `LV` | `EUR` supported by ISO/SIX plus EU adoption evidence | Draft: `lv-LV`, `en`, `ru`; explicit owner source record absent | Draft: `Europe/Riga`; explicit owner source record absent | disabled until named gates; first cohort candidate only |
| `ee` | `EE` | `EUR` supported by ISO/SIX plus EU adoption evidence | Draft: `et-EE`, `en`; `ru` unresolved | Draft: `Europe/Tallinn` | disabled |
| `lt` | `LT` | `EUR` supported by ISO/SIX plus EU adoption evidence | Draft: `lt-LT`, `en`; additions unresolved | Draft: `Europe/Vilnius` | disabled |

No row authorizes hardcoding. Country, currency, locale and timezone remain
different concepts. Market activation requires an internal signed decision
even when every external identifier is valid.

## 6. Evidence record required before ingestion

Every future external or internal source snapshot must contain:

```text
SourceAuthorityEvidence {
  evidenceId
  sourceId
  recordFamily
  sourceOwnerIdentityOrRole
  sourceArtifactVersion
  retrievalUriOrRepositoryPath
  retrievedAtUtc
  normalizedContentHash
  licenseOrTermsReference
  allowedUseScope
  parserOrExtractionVersion
  validationCommandOrMethod
  validationResult: pass | fail | inconclusive
  supersedesEvidenceId?
  reviewedBy[]
  approvedAtUtc?
  expiresOrRecheckAtUtc?
}
```

`pass` proves only the checks explicitly listed. Network success, a matching
hash or official-domain URL alone does not prove correct scope, trusted origin,
license permission, current policy approval or translation quality.

## 7. Conflict and freshness rules

1. Accepted Recharge semantics win for Recharge-owned meaning; external
   registries cannot change product policy.
2. An external maintenance authority wins for the standard identifier fields
   it owns, subject to pinned evidence and migration review.
3. CLDR may supply locale conventions/display data but never Recharge copy,
   supported-locale policy or Legal meaning.
4. IANA tzdb supplies technical civil-time data, not a qualified legal opinion.
5. A source change creates a new evidence revision and impact analysis; it
   never mutates a published ReferenceDatasetRevision.
6. Conflicting authorities produce `source_authority_conflict` and block the
   family until the accountable owner records a decision.
7. Missing, expired, unverifiable or license-inconclusive evidence produces
   `source_authority_missing` or `source_authority_stale` and fails closed.
8. Withdrawal/tombstone authority is monotonic and wins over caches, restore
   and rollback.
9. EE/LT data presence cannot activate those markets or inherit LV policy.
10. Emergency publication cannot bypass source authority, independence or
    qualified Legal gates.

## 8. Retained gates and non-authority

This proposal retains all of the following:

- `BCK20-OD-02` and `BCK20-OD-05` remain **Open**;
- `OD-10` remains **Proposed**, `BCK-20` remains **Draft** and
  `BCK20-OD-03` remains **Deferred**;
- source records for market policy, service areas, translations, policy
  revisions and dictionaries remain Pending/Blocked/Deferred as shown;
- independent Security/Privacy and applicable qualified Legal evidence remain
  Pending;
- source licensing/terms approval remains Pending;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge are unauthorized.

Codex is the technical evidence author only and is not a source owner,
translator, independent reviewer, qualified professional or signatory.

## 9. Review checklist

| # | Check | Recorded result |
|---:|---|---|
| 1 | every BCK-20 included family has one source-authority disposition | Pass |
| 2 | standard identity and Recharge product-policy authority are separated | Pass |
| 3 | codes and localized names are separate fields | Pass |
| 4 | CLDR is not treated as Recharge-copy or Legal authority | Pass |
| 5 | tzdb limitation is disclosed | Pass |
| 6 | Category System exact revision/hash is frozen | Pass |
| 7 | market activation remains an internal signed decision | Pass |
| 8 | source locale is explicit or blocking | Pass |
| 9 | translation class and minimum review are explicit | Pass |
| 10 | service-area and dictionary gaps fail closed | Pass |
| 11 | mandatory copy remains under BCK20-OD-05 | Pass |
| 12 | source snapshots require version/hash/terms/freshness | Pass |
| 13 | EE/LT remain independently disabled | Pass |
| 14 | no external source silently authorizes ingestion or runtime | Pass |
| 15 | no unresolved value is inferred | Pass |

These are documentation results. They are not executable fixture results or
independent review.

## 10. Historical exact owner decision request

```text
Одобряю BCK20-OD02-SRC-AUTH-01 v0.1:
Accept source-authority design boundary with retained gates для точного
документа и SHA-256, указанного в review package.
Подтверждаю RechargeN / Product owner как combined Reference Data, Product/
Market, Product Localization и Content/source-governance owner для этой
documentation-only границы, отсутствие independent review и отсутствие
qualified Security/Privacy/Legal claim.
Внешние registry являются candidate authority только в указанном field scope;
license/terms, pinned ingestion evidence и executable use остаются Pending.
BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 Proposed; BCK-20 Draft;
BCK20-OD-03 Deferred. Independent Security/Privacy, applicable qualified Legal
и unresolved source records остаются Pending/Blocked/Deferred.
Provider selection, schema, IAM/runtime, Firebase, deployment, activation,
push и merge не разрешаю.
```

## 11. Acceptance criteria

1. **BCK20-OD02-SRC-AUTH-AC-01:** every included record family has one explicit source-authority disposition.
2. **BCK20-OD02-SRC-AUTH-AC-02:** normative identity, semantic, locale-data, composition and distribution roles remain distinct.
3. **BCK20-OD02-SRC-AUTH-AC-03:** external authority is limited to its stated fields and cannot create Recharge product policy.
4. **BCK20-OD02-SRC-AUTH-AC-04:** country codes, country names and market membership are not conflated.
5. **BCK20-OD02-SRC-AUTH-AC-05:** currency codes/minor units are separate from prices, exchange rates, tax and market assignment.
6. **BCK20-OD02-SRC-AUTH-AC-06:** BCP 47 identity, CLDR locale data and supported-locale policy are separate authorities.
7. **BCK20-OD02-SRC-AUTH-AC-07:** IANA tzdb is a technical source and not a Legal authority.
8. **BCK20-OD02-SRC-AUTH-AC-08:** Category System v1.4.3 identity, meaning and hash are frozen.
9. **BCK20-OD02-SRC-AUTH-AC-09:** translated labels never become semantic source authority.
10. **BCK20-OD02-SRC-AUTH-AC-10:** missing market, service-area, policy, translation or dictionary evidence fails closed.
11. **BCK20-OD02-SRC-AUTH-AC-11:** every future source snapshot carries version, retrieval, hash, terms, scope, parser and validation evidence.
12. **BCK20-OD02-SRC-AUTH-AC-12:** source updates are immutable revisions with impact analysis, never in-place published mutation.
13. **BCK20-OD02-SRC-AUTH-AC-13:** EE/LT data presence cannot activate those markets or inherit LV policy.
14. **BCK20-OD02-SRC-AUTH-AC-14:** mandatory Legal/safety copy remains blocked under BCK20-OD-05.
15. **BCK20-OD02-SRC-AUTH-AC-15:** external-source license/terms and ingestion remain separately gated.
16. **BCK20-OD02-SRC-AUTH-AC-16:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
17. **BCK20-OD02-SRC-AUTH-AC-17:** independent Security/Privacy and applicable qualified Legal evidence remain Pending.
18. **BCK20-OD02-SRC-AUTH-AC-18:** no provider/schema/IAM/runtime/Firebase/deployment/activation/push/merge authority is created.

## 12. Recorded disposition and next action

BCK20-OD02-SRC-AUTH-DEC-01 accepts the frozen v0.1 matrix at normalized-LF
SHA-256 `3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6`
as a source-authority design boundary with retained gates. This v0.2 revision
adds status traceability only and does not change the accepted v0.1 source
semantics.

Next, create and review the actual Recharge-owned source records and complete
license/terms plus pinned ingestion evidence for any external candidate source.
No dataset, translation, ingestion or runtime may be inferred from this
decision.
