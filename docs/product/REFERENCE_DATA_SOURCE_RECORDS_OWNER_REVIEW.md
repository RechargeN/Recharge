# BCK-20 — Source Records Combined-Owner Review Package

- ID: **BCK20-OD02-SRC-REC-REV-01**
- Version: **0.1**
- Date: **2026-09-18**
- Status: **Proposed — exact owner decision required**
- Frozen internal records: [BCK20-OD02-SRC-REC-01 v0.1](REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md)
- Internal-records normalized-LF SHA-256: `c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555`
- Frozen external register: [BCK20-OD02-EXT-EV-01 v0.1](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- External-register normalized-LF SHA-256: `faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d`
- Parent: [BCK-20 v0.2.16](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Proposed owner/signatory: **RechargeN / Product owner**
- Combined roles: **Product/Market + Reference Data + Product Localization + Content/source governance + Mobile + technical Security/Privacy**
- Independence: **none; combined-owner review**
- Qualified Security/Privacy/Legal claim: **none**
- Runtime effect: **none**

---

## 1. Purpose and recommended verdict

This package reviews two exact documentation artifacts:

1. a proposed Recharge-owned source-record baseline for market identity,
   locale, currency, timezone, activation, category binding and policy gates;
2. an external-source evidence work register in which every source remains
   unapproved for ingestion.

Recommended verdict:

> **Accept internal source-record documentation baseline and external evidence
> work queue with retained gates** for the exact frozen revisions and hashes.

This verdict would accept product/documentation meaning only. It would not
accept BCK-20, OD-10, BCK20-OD-02/05, external terms, source artifacts,
translations, service areas, policy copy, schema or runtime.

## 2. Frozen-input verification

| Check | Observed | Result |
|---|---|---|
| Internal target | `BCK20-OD02-SRC-REC-01 v0.1` | Match |
| Internal normalized-LF SHA-256 | `c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555` | Match |
| Documentation source records | 23 | Match |
| Explicit unresolved families | 6 | Match |
| Internal AC | AC-01–20 sequential | Match |
| External target | `BCK20-OD02-EXT-EV-01 v0.1` | Match |
| External normalized-LF SHA-256 | `faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d` | Match |
| External candidates | 8 | Match |
| External AC | AC-01–15 sequential | Match |
| Runtime/schema/network work | none | Pass |

Any target content, version or normalized hash change invalidates this review.

## 3. Review perspectives

### 3.1 Product/Market

- `lv`, `ee` and `lt` are stable Recharge market identities bound to LV, EE
  and LT respectively without conflating country and market concepts.
- Latvia is the first launch candidate, but its baseline status remains
  `disabled` exactly like Estonia and Lithuania.
- EE and LT require independent future activation decisions and cannot inherit
  readiness from Latvia.

Verdict recommendation: **Accept with retained activation gates**.

### 3.2 Reference Data

- 23 records have bounded identity, revision, owner, scope and state.
- Category System v1.4.3 is frozen by exact normalized hash.
- Missing policy references are explicit blocking records rather than nullable
  “latest” lookups.
- Documentation evidence IDs are not misrepresented as server entity IDs.

Verdict recommendation: **Accept documentation composition boundary**.

### 3.3 Product Localization and Content

- LV supports `lv-LV`, `en`, `ru`; EE supports `et-EE`, `en`; LT supports
  `lt-LT`, `en` in the proposed revision.
- Market fallback order applies only to general non-Legal product copy.
- No wording, translation, label snapshot or mandatory copy is accepted.
- Legal/safety copy remains `fallbackForbidden` unless qualified policy says
  otherwise.

Verdict recommendation: **Accept policy shape; retain copy/review gates**.

### 3.4 Mobile

- exact supported locale/fallback state is sufficient for later typed UI
  resolution without device-locale inference;
- missing or forbidden copy remains typed fail-closed state;
- no cache, adapter, generated contract or presentation change is authorized.

Verdict recommendation: **Accept consumer design boundary only**.

### 3.5 Technical Security/Privacy

- market activation and missing policies fail closed;
- policy reference absence cannot be bypassed by external data or cache;
- no credentials, personal data, network retrieval or untrusted parser is
  introduced;
- combined-owner review is not independent Security/Privacy evidence.

Verdict recommendation: **Accept technical boundary with retained gates**.

## 4. Findings

| ID | Finding | Disposition |
|---|---|---|
| `SRC-REC-O-01` | Market fallback order is a product decision, not a translation artifact | exact revision frozen; owner acceptance required |
| `SRC-REC-O-02` | General fallback could be unsafe for mandatory Legal/safety content | `fallbackForbidden` retained unless qualified policy permits otherwise |
| `SRC-REC-O-03` | `en` and `ru` are language-only product locale identifiers | allowed only after pinned BCP 47 validation; no device inference |
| `SRC-REC-O-04` | Initial timezone allowlists are intentionally one-zone-per-market | later expansion requires superseding record and impact review |
| `SRC-REC-O-05` | All markets remain disabled, including Latvia | activation requires a separate signed revision and release evidence |
| `SRC-REC-O-06` | Seven policy-reference slots have no accepted effective revision | explicit blockers preserved; no latest/null fallback |
| `SRC-REC-O-07` | Official external origins have no pinned artifact or accepted terms | every row stays artifact/terms Pending |
| `SRC-REC-O-08` | No network revalidation occurred on 2026-09-18 | inherited observations are marked stale until deliberate recheck |
| `SRC-REC-O-09` | Service areas, translations and mandatory copy remain absent | families stay Blocked/Pending and cannot use demo data |
| `SRC-REC-O-10` | One owner holds all six review perspectives | zero independence and absent qualified claim remain explicit |

No finding requires runtime work or weakens a retained gate.

## 5. Effect of acceptance

If §8 is accepted exactly:

- the 23 internal records become accepted documentation source inputs at
  revision 1;
- the six unresolved families retain their explicit blocking state;
- the eight external candidates remain an accepted work queue only, with no
  source eligible for ingestion;
- canonical BCK-20/D1 documents may record this bounded decision;
- BCK20-OD-02 and BCK20-OD-05 remain Open;
- OD-10 remains Proposed, BCK-20 remains Draft and BCK20-OD-03 remains
  Deferred;
- all markets remain disabled;
- runtime authority remains none.

## 6. Retained gates

- no source artifact, license/terms disposition or pinned ingestion evidence
  is accepted;
- no source snapshot, translation, service area or mandatory policy copy exists;
- independent Security/Privacy and applicable qualified Legal evidence remain
  Pending;
- provider selection, schema, IAM/runtime, Firebase, deployment and activation
  remain unauthorized;
- push and merge remain unauthorized.

## 7. Proposed signature record

```text
Decision input: BCK20-OD02-SRC-REC-REV-01 v0.1
Internal target: BCK20-OD02-SRC-REC-01 v0.1
Internal normalized-LF SHA-256: c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555
External target: BCK20-OD02-EXT-EV-01 v0.1
External normalized-LF SHA-256: faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d
Named reviewer identity: RechargeN / Product owner
Combined roles: Product/Market; Reference Data; Product Localization; Content/source governance; Mobile; technical Security/Privacy
Independence: none; combined-owner review
Qualified Security/Privacy/Legal claim: none
Proposed verdict: Accept internal source-record documentation baseline and external evidence work queue with retained gates
Runtime authority: none
```

## 8. Exact owner decision requested

```text
Одобряю BCK20-OD02-SRC-REC-REV-01 v0.1:
Accept internal source-record documentation baseline and external evidence
work queue with retained gates для точных BCK20-OD02-SRC-REC-01 v0.1 /
SHA-256 c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555
и BCK20-OD02-EXT-EV-01 v0.1 / SHA-256
faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d.
Подтверждаю совмещение ролей RechargeN / Product owner для Product/Market,
Reference Data, Product Localization, Content/source governance, Mobile и
technical Security/Privacy, отсутствие independent review и отсутствие
qualified Security/Privacy/Legal claim.
Все три market остаются disabled. External artifacts, license/terms, pinned
ingestion evidence, translations, service-area data, mandatory policy copy,
independent Security/Privacy и applicable qualified Legal evidence остаются
Pending/Blocked/Deferred.
BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 остаётся Proposed; BCK-20
остаётся Draft; BCK20-OD-03 остаётся Deferred. Network retrieval, provider
selection, schema, IAM/runtime, Firebase, deployment, activation, push и merge
не разрешаю.
```

## 9. Acceptance criteria

1. **BCK20-OD02-SRC-REC-REV-AC-01:** both exact target identities and normalized hashes are frozen.
2. **BCK20-OD02-SRC-REC-REV-AC-02:** all 23 internal source records are covered by the review.
3. **BCK20-OD02-SRC-REC-REV-AC-03:** six unresolved families retain explicit fail-closed states.
4. **BCK20-OD02-SRC-REC-REV-AC-04:** all eight external candidates remain unapproved for ingestion.
5. **BCK20-OD02-SRC-REC-REV-AC-05:** Latvia remains first-launch candidate without activation.
6. **BCK20-OD02-SRC-REC-REV-AC-06:** Estonia and Lithuania remain independently disabled.
7. **BCK20-OD02-SRC-REC-REV-AC-07:** locale/fallback acceptance creates no translation or mandatory-copy acceptance.
8. **BCK20-OD02-SRC-REC-REV-AC-08:** currency and timezone records retain their bounded non-payment and non-Legal meaning.
9. **BCK20-OD02-SRC-REC-REV-AC-09:** missing policy revisions remain explicit blockers without latest/null fallback.
10. **BCK20-OD02-SRC-REC-REV-AC-10:** inherited external observations are not represented as current revalidation.
11. **BCK20-OD02-SRC-REC-REV-AC-11:** external artifact, terms, parser and validation evidence remain separate future gates.
12. **BCK20-OD02-SRC-REC-REV-AC-12:** six combined-owner roles remain attributable with zero independence disclosed.
13. **BCK20-OD02-SRC-REC-REV-AC-13:** no independent or qualified Security/Privacy/Legal claim is created.
14. **BCK20-OD02-SRC-REC-REV-AC-14:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
15. **BCK20-OD02-SRC-REC-REV-AC-15:** no network retrieval, provider, schema, IAM/runtime, Firebase, deployment or activation is authorized.
16. **BCK20-OD02-SRC-REC-REV-AC-16:** no push or merge is authorized.
17. **BCK20-OD02-SRC-REC-REV-AC-17:** any target content/version/hash change requires a new review and owner decision.
18. **BCK20-OD02-SRC-REC-REV-AC-18:** canonical status reconciliation waits for the exact owner decision.

## 10. Next action

Obtain the exact owner decision in §8. Before that decision, do not mark either
target Accepted, update BCK-20/D1 canonical statuses, retrieve external
artifacts or create schema/runtime work.
