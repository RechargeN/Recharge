# BCK-20 — Internal Reference Source Records

- ID: **BCK20-OD02-SRC-REC-01**
- Version: **0.2**
- Date: **2026-09-18**
- Status: **Owner decision recorded — documentation source baseline accepted with retained gates**
- Parent: [BCK-20 v0.2.17](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Authority boundary: [BCK20-OD02-SRC-AUTH-01 v0.2](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Source-record decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- Accountable owner: **RechargeN / Product owner acting as Product/Market and Reference Data owner**
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled**
- Runtime effect: **none**

---

## 1. Purpose and bounded outcome

This document turns the accepted source-authority design into reviewable
Recharge-owned source records. It fixes proposed product meaning for market
identity, locale policy, currency assignment, timezone policy, activation
baseline and policy-reference gates without creating a schema, dataset,
database row or runtime configuration.

An owner decision may accept these records as documentation source inputs. It
must not be interpreted as market activation, Legal approval, translation
approval, external-source licensing, executable ingestion or BCK-20 Approval.

## 2. Record semantics

The IDs below are immutable documentation evidence IDs, not server entity IDs.
A later executable slice must assign contract-compliant permanent IDs and bind
them to the accepted evidence IDs without changing their meaning.

Each record has:

- one immutable `recordId` and `revision`;
- one accountable semantic owner;
- explicit market and field scope;
- exact proposed values or an explicit unresolved state;
- required evidence and review gates;
- `publishability`, which is always `documentation_only` in this revision.

No field may resolve from device locale, geolocation, provider response,
Firestore contents, display labels or an unpinned “latest” source.

## 3. Internal source records

### 3.1 Market identity

| Record ID | Revision | Market ID | Country | Semantic owner | State |
|---|---:|---|---|---|---|
| `SRCREC-MARKET-LV-001` | 1 | `lv` | `LV` | Product/Market owner | proposed; first launch market, not activated |
| `SRCREC-MARKET-EE-001` | 1 | `ee` | `EE` | Product/Market owner | proposed; disabled expansion market |
| `SRCREC-MARKET-LT-001` | 1 | `lt` | `LT` | Product/Market owner | proposed; disabled expansion market |

Rules:

- market IDs are stable Recharge identifiers and are not derived from country
  codes at runtime;
- one market maps to one launch country in revision 1;
- changing an ID or country association requires a superseding record and
  migration review; in-place mutation is prohibited;
- presence in this table does not make a market discoverable or enabled.

### 3.2 Supported locale policy

| Record ID | Market | Primary locale | Supported product locales | Market fallback order | State |
|---|---|---|---|---|---|
| `SRCREC-LOCALE-LV-001` | `lv` | `lv-LV` | `lv-LV`, `en`, `ru` | `lv-LV` → `en` → `ru` | proposed for general non-Legal product copy |
| `SRCREC-LOCALE-EE-001` | `ee` | `et-EE` | `et-EE`, `en` | `et-EE` → `en` | proposed; market disabled; `ru` excluded until a later accepted record |
| `SRCREC-LOCALE-LT-001` | `lt` | `lt-LT` | `lt-LT`, `en` | `lt-LT` → `en` | proposed; market disabled; additions require a later accepted record |

Rules:

- locale identifiers require pinned IANA/BCP 47 validation before executable
  use;
- fallback is restricted to locales listed for the same effective market;
- exact requested locale and explicitly configured language fallback precede
  the market fallback order as defined by OD-10;
- `legal_safety_mandatory` content never inherits this general fallback order;
  it remains `fallbackForbidden` unless qualified policy explicitly permits it;
- translations and source copy remain absent; this record accepts no wording.

### 3.3 Currency assignment

| Record ID | Market | Allowed currency | Semantic owner | Evidence dependency | State |
|---|---|---|---|---|---|
| `SRCREC-CURRENCY-LV-001` | `lv` | `EUR` | Product/Market owner | pinned ISO 4217/SIX identity and EU adoption evidence | proposed; executable evidence pending |
| `SRCREC-CURRENCY-EE-001` | `ee` | `EUR` | Product/Market owner | same, independently pinned | proposed; market disabled |
| `SRCREC-CURRENCY-LT-001` | `lt` | `EUR` | Product/Market owner | same, independently pinned | proposed; market disabled |

These records select a market currency only. They do not define price,
exchange rate, tax, merchant settlement, payment provider or money runtime.
Amounts remain integer minor units plus explicit ISO currency under the owning
domain contract.

### 3.4 Timezone policy

| Record ID | Market | Default zone | Allowed zones revision 1 | Evidence dependency | State |
|---|---|---|---|---|---|
| `SRCREC-TZ-LV-001` | `lv` | `Europe/Riga` | `Europe/Riga` | pinned IANA tzdb release | proposed; executable evidence pending |
| `SRCREC-TZ-EE-001` | `ee` | `Europe/Tallinn` | `Europe/Tallinn` | pinned IANA tzdb release | proposed; market disabled |
| `SRCREC-TZ-LT-001` | `lt` | `Europe/Vilnius` | `Europe/Vilnius` | pinned IANA tzdb release | proposed; market disabled |

The allowed-zone set is deliberately narrow for the initial country markets.
An object with its own authoritative IANA zone continues to use that zone for
local calendar semantics. This policy is not a legal claim about borders or
political status.

### 3.5 Activation baseline

| Record ID | Market | Baseline status | Cohort authority | State |
|---|---|---|---|---|
| `SRCREC-ACT-LV-001` | `lv` | `disabled` | separate signed release decision after all named gates | proposed; first cohort candidate only |
| `SRCREC-ACT-EE-001` | `ee` | `disabled` | independent EE decision | proposed; no Latvia inheritance |
| `SRCREC-ACT-LT-001` | `lt` | `disabled` | independent LT decision | proposed; no Latvia inheritance |

No documentation acceptance may change `disabled`. `internal`, `invited`,
`cohort`, `enabled` and `suspended` transitions require a later immutable
activation record with effective time, required policy revisions, Operations
evidence, rollback and explicit owner decision.

### 3.6 Category source binding

| Record ID | Dataset | Exact source | Normalized-LF SHA-256 | State |
|---|---|---|---|---|
| `SRCREC-CATEGORY-143-001` | Recharge taxonomy | Category System v1.4.3 | `5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9` | accepted semantic source; executable dataset absent |

This binding freezes semantic identity only. Localized labels, generated
artifacts, snapshot manifests, database storage and distribution remain
separate gated work.

### 3.7 Policy-reference gate record

| Record ID | Required reference | Current value | State/default |
|---|---|---|---|
| `SRCREC-POLICY-GATE-001` | content policy revision | none accepted for MarketConfig | Pending; activation blocked |
| `SRCREC-POLICY-GATE-002` | privacy policy revision | none accepted for MarketConfig | Pending; activation blocked |
| `SRCREC-POLICY-GATE-003` | minors/age policy revision | OD-11 remains unresolved | Blocked; age-sensitive surfaces fail closed |
| `SRCREC-POLICY-GATE-004` | trust & safety policy revision | no accepted MarketConfig reference | Pending; affected surface disabled |
| `SRCREC-POLICY-GATE-005` | provider registry revision | provider selection unauthorized | Deferred; no provider runtime |
| `SRCREC-POLICY-GATE-006` | support policy revision | no accepted market revision | Pending; activation blocked |
| `SRCREC-POLICY-GATE-007` | feature-flags revision | no executable revision | Deferred to authorized runtime slice |

`none accepted` is an explicit blocking value, not a null-to-latest lookup.
BCK-20 composes accepted references but cannot author or infer their meaning.

## 4. Explicitly unresolved record families

| Family | State | Required next evidence |
|---|---|---|
| service-area identity/geometry | Blocked | accountable Market/Geo owner, exact official/licensed geometry source, allowed-use evidence and immutable revision |
| service-area labels | Blocked with parent | accepted parent geometry plus locale/source review |
| taxonomy localized labels | Pending | source snapshots, source locale, approved copy and review records |
| country/currency/locale display data | Pending | pinned external source artifacts and localization review |
| mandatory policy copy | Blocked | exact source copy, qualified Legal and independent review under BCK20-OD-05 |
| auxiliary dictionaries | Deferred | BCK20-OD-06 source and governance decision |

These families are not omitted from scope and cannot be filled with demo data,
free text or provider output.

## 5. Required external evidence bindings

Before executable use, each referenced external source must have a record in
[BCK20-OD02-EXT-EV-01](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
with a pinned artifact/release, normalized hash, retrieval provenance,
license/terms disposition, allowed-use scope, parser/extraction version and
validation result. A URL or official-domain observation is insufficient.

## 6. Review and change control

1. Product/Market owns market identity, locale policy, currency assignment,
   timezone policy and activation meaning.
2. Reference Data verifies composition, stable identifiers and exact source
   bindings without becoming the policy author.
3. Product Localization, Content and Mobile review locale/fallback behavior.
4. Security/Privacy reviews fail-closed and activation implications.
5. Qualified Legal review remains mandatory wherever policy, license or
   market-specific legal judgment applies.
6. One person may hold the technical/product roles only with zero independence
   disclosed; that never satisfies independent or qualified gates.
7. Any accepted value change creates revision 2 or a superseding record. The
   revision-1 record is immutable history.

## 7. Retained gates and non-authority

- `BCK20-OD-02` and `BCK20-OD-05` remain **Open**;
- `OD-10` remains **Proposed**, `BCK-20` remains **Draft** and
  `BCK20-OD-03` remains **Deferred**;
- all three markets remain **disabled**;
- external license/terms and pinned ingestion evidence remain **Pending**;
- actual translations, service-area data and mandatory copy remain absent;
- independent Security/Privacy and applicable qualified Legal evidence remain
  Pending;
- schema, provider selection, IAM/runtime, Firebase, deployment, activation,
  push and merge are unauthorized.

## 8. Acceptance criteria

1. **BCK20-OD02-SRC-REC-AC-01:** documentation evidence IDs are not represented as server entity IDs.
2. **BCK20-OD02-SRC-REC-AC-02:** LV, EE and LT market identities are explicit and immutable by revision.
3. **BCK20-OD02-SRC-REC-AC-03:** market identity remains distinct from country identity and activation.
4. **BCK20-OD02-SRC-REC-AC-04:** Latvia is first-launch candidate without being activated.
5. **BCK20-OD02-SRC-REC-AC-05:** Estonia and Lithuania remain independently disabled.
6. **BCK20-OD02-SRC-REC-AC-06:** supported locales and deterministic market fallback orders are explicit.
7. **BCK20-OD02-SRC-REC-AC-07:** general fallback never authorizes fallback for mandatory Legal/safety copy.
8. **BCK20-OD02-SRC-REC-AC-08:** currency assignment creates no pricing, tax, exchange-rate, settlement or payment authority.
9. **BCK20-OD02-SRC-REC-AC-09:** timezone policy uses exact IANA identifiers and creates no legal/geopolitical claim.
10. **BCK20-OD02-SRC-REC-AC-10:** every activation baseline remains disabled until a later signed revision.
11. **BCK20-OD02-SRC-REC-AC-11:** Category System v1.4.3 identity and normalized hash are frozen.
12. **BCK20-OD02-SRC-REC-AC-12:** missing policy revisions are explicit blocking values, never latest lookups.
13. **BCK20-OD02-SRC-REC-AC-13:** unresolved service-area, translation, display-data, mandatory-copy and dictionary families fail closed.
14. **BCK20-OD02-SRC-REC-AC-14:** every external dependency requires a separately pinned evidence record before executable use.
15. **BCK20-OD02-SRC-REC-AC-15:** a changed accepted value creates a superseding immutable revision.
16. **BCK20-OD02-SRC-REC-AC-16:** combined ownership never implies independent or qualified review.
17. **BCK20-OD02-SRC-REC-AC-17:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
18. **BCK20-OD02-SRC-REC-AC-18:** no translation, dataset, service area, policy copy or executable artifact is approved.
19. **BCK20-OD02-SRC-REC-AC-19:** schema, provider, IAM/runtime, Firebase, deployment and activation remain unauthorized.
20. **BCK20-OD02-SRC-REC-AC-20:** this document authorizes no push or merge.

## 9. Recorded disposition and next action

BCK20-OD02-SRC-REC-DEC-01 accepts the frozen v0.1 internal records at
normalized-LF SHA-256
`c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555`
as documentation source inputs with retained gates. This v0.2 revision adds
status traceability only and does not change the accepted revision-1 meaning.

Next, prepare external artifact/license evidence and the unresolved source
families as separate reviewable packages. No network retrieval, ingestion,
schema or runtime is authorized by this disposition.
