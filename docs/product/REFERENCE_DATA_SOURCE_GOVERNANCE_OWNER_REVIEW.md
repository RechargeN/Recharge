# BCK-20 — EXT-A–D Source Governance Owner Review

- Review ID: **BCK20-OD02-SRC-GOV-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — owner governance verdict required; no source approval**
- Exact source register: [BCK20-OD02-EXT-EV-01 v0.3](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- Register normalized-LF SHA-256:
  `094b70ab9888922f85a16f2b8a9f741c817868aa5ed3e3ad8e16076dbadd36f5`
- Exact source/terms package: [BCK20-OD02-EXT-AD-SRC-TERMS-DEC-PKG-01 v0.1](REFERENCE_DATA_EXT_A_D_SOURCE_TERMS_DECISION_PACKAGE.md)
- Source/terms package normalized-LF SHA-256:
  `596873a51fd09839b4d63f80cdcb0cc5a2c21cfbe97ec377e7678f5173727bd1`
- Qualified-review input: [BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01 v0.1](REFERENCE_DATA_EXT_A_D_QUALIFIED_TERMS_ACCESS_REVIEW.md)
- Qualified-review input normalized-LF SHA-256:
  `214d6c0dec67b379bfba836ba1c6089e03b14b3fddaf4f38d55be03af41b081b`
- Review perspectives: **Reference Data, Product/Market, Product Localization,
  Content/source governance and technical Security/Privacy**
- Coordinator: **RechargeN / Product owner combined role**
- Independence: **none**
- Qualified terms/Legal verdict: **absent**
- Runtime effect: **none**

---

## 1. Purpose and recommended verdict

This review completes the technical owner-governance layer that can be decided
without pretending to supply a qualified terms/license conclusion. It defines
field scope, version identity, refresh posture, changed-hash handling,
withdrawal and fail-closed behavior for all eight EXT-A–D source records.

Recommended verdict:

**Accept source-governance design boundary with retained terms and executable
gates.**

This verdict would not approve any external source, terms, license, artifact,
parser, fixture or ingestion. Every source remains outside
`eligible_for_slice_review` until its exact qualified and owner gates pass.

## 2. Common governance invariants

1. A source has one stable `sourceId`; a URI, label or provider name is not an
   identity substitute.
2. Evidence identity includes exact artifact/page identity, retrieval time,
   upstream version/date when present and locally computed hash.
3. Technical validity, lawful allowed use, freshness and product authority are
   separate dimensions.
4. Each derived field declares one owning source record and any corroborating
   sources separately.
5. A corroborating source cannot silently become normative authority.
6. Changed hash without an expected upstream identity creates a new review
   candidate; it is never blind-applied.
7. Unknown schema, missing required notice, unresolved terms, access denial,
   integrity mismatch or ambiguous authority fails closed.
8. Withdrawal blocks new publication immediately; correction/replacement is a
   separately auditable action.
9. Raw third-party content remains outside Git unless a later qualified
   verdict and Approved executable slice explicitly permit it.
10. Source readiness cannot activate a market, locale, currency, service area
    or Legal copy.

## 3. Freshness classes

The following classes are design defaults for later owner review. They do not
authorize network activity.

| Class | Meaning | Required behavior |
|---|---|---|
| `immutable_release` | upstream release/version is immutable | pin exact version/hash; update only by new reviewed revision |
| `dated_registry` | upstream publishes a source date/version | retain exact date/hash; changed identity enters review |
| `mutable_dated` | mutable page/list exposes a meaningful provider date | enforce maximum observation age before a new slice proposal |
| `mutable_undated` | mutable response has no reliable upstream version | use retrieval/hash evidence, shortest review window and fail closed on unclassified change |
| `corroborating_only` | source supports a fact but cannot own product authority | recheck before affected decision; never publish it as normative authority |
| `blocked` | artifact/terms/access evidence unavailable | no substitute, parser or derived authority |

`Maximum observation age` below is a planning threshold for whether existing
evidence may support a future slice review. It is not an automatic download
schedule, TTL, runtime cache policy or permission to contact the source.

## 4. Per-source governance disposition

| Source | Authority ceiling | Freshness class | Maximum observation age before future slice review | Changed-hash/version action | Current state |
|---|---|---|---:|---|---|
| `SRC-IANA-LANG` | BCP 47 registered subtag identity and canonicalization evidence | `dated_registry` | 45 days | capture as new candidate; compare registry date and semantic delta; re-run exact validation | technical evidence only; terms Pending |
| `SRC-IANA-TZDB` | IANA zone IDs and transition data for pinned release | `immutable_release` plus release monitoring | 45 days since last authorized release check | new release becomes a separate immutable candidate; no overwrite; old release retained for rollback analysis | technical evidence only; terms/integrity disposition Pending |
| `SRC-UNICODE-CLDR` | locale display/format conventions for selected pinned modules | `immutable_release` | no time expiry for the pinned release; recheck upstream/terms before a new executable proposal or after 180 days | new CLDR/UTS revision requires module diff, checksum verification and all affected locale fixtures | technical evidence only; terms/spec pin Pending |
| `SRC-UN-M49` | M49 numeric mappings and bounded UN short-name evidence | `mutable_undated` | 30 days | any changed hash is unclassified until table/schema/row diff and owner review complete | technical evidence only; terms/freshness Pending |
| `SRC-EU-EURO` | corroborating euro-adoption history only | `corroborating_only` | 90 days and always before a market-currency decision | changed fact or page structure requires owner review; never changes MarketConfig automatically | technical evidence only; notice/freshness Pending |
| `SRC-ISO-3166` | direct ISO country-code edition authority only if lawfully acquired | `blocked` | 0 days | remain blocked until exact artifact, edition and permitted use exist | Blocked/Pending |
| `SRC-ISO-4217` | direct ISO currency-standard edition authority only if lawfully acquired | `blocked` | 0 days | remain blocked; SIX/UN evidence cannot be relabelled as direct ISO authority | Blocked/Pending |
| `SRC-SIX-4217` | operational active/historic currency-list evidence for captured list scope | `mutable_dated` | 30 days | new provider date/hash becomes a separate candidate; missing List Two and terms remain explicit | partial technical evidence; terms/integrity Pending |

The thresholds are conservative governance inputs, not claims about provider
publication cadence. A qualified verdict or provider rule may require a
shorter window; a longer window requires a new owner decision with evidence.

## 5. Integrity and provenance controls

Every later candidate source snapshot must carry:

- `sourceId` and source-record revision;
- exact acquisition authorization/evidence ID;
- exact URI and redirect outcome;
- retrieved-at UTC;
- provider version/date/ETag/Last-Modified when available;
- raw byte length and local SHA-256;
- provider checksum/signature identity when available;
- validator/profile version and deterministic result;
- allowed field scope and explicit non-authority;
- terms/access verdict identity and required notices;
- freshness class, observed age and next-review trigger;
- withdrawal/correction state;
- reviewer/decision provenance.

Absence of a provider signature is not silently treated as failure when a
later accepted control allows local hashes, but the absence remains explicit.
Local hashes prove captured-byte identity, not provider authenticity or lawful
use.

## 6. Change, withdrawal and conflict policy

### 6.1 Expected new release

An expected new release/date creates a new candidate revision. The current
accepted revision is not overwritten. Semantic diff, validation, terms impact,
notices and rollback compatibility are reviewed before any pointer change.

### 6.2 Unexpected changed hash

If content changes without a matching expected provider identity:

1. quarantine the candidate;
2. do not update repository or runtime data;
3. record the exact acquisition/evidence chain;
4. classify schema and semantic differences;
5. require owner disposition and qualified re-review when terms/use may have
   changed.

### 6.3 Withdrawal or correction

- stop new publication/use of the affected candidate;
- identify derived revisions and downstream consumers;
- choose replacement, correction, bounded rollback or surface disablement;
- preserve audit evidence only within accepted retention/terms controls;
- never resurrect withdrawn values through fallback or cache.

### 6.4 Cross-source conflict

Conflicting sources are not merged by convenience. The owning field scope and
authority ceiling decide which source can be normative. If authority remains
ambiguous, the affected field and dependent market capability remain disabled.

## 7. Source-specific retained blockers

### IANA

- qualified disposition for captured licensing terms;
- exact notice/attribution delivery requirements;
- TZDB checksum/signature or accepted alternative integrity control;
- executable canonicalization/transition fixtures.

### Unicode CLDR

- qualified Unicode/bundled-license disposition and notice placement;
- immutable UTS #35 48.2 pin;
- checksum filename anomaly disposition;
- exact selected-module and generated-output policy.

### UN and European Commission

- qualified terms/legal-notice dispositions;
- accepted use of derived names/facts and attribution;
- executable maximum-age/change monitoring after separate authorization.

### ISO

- exact lawful artifact, edition and access/license evidence;
- no bypass via alternate sources and no false ISO authority claim.

### SIX

- current terms/access evidence and qualified disposition;
- List Two scope decision;
- accepted integrity control and notice requirements.

## 8. Effect of owner acceptance

| Item | Result |
|---|---|
| common governance invariants | accepted as documentation design boundary |
| freshness classes/thresholds | accepted only as future slice-review gates |
| per-source technical field ceiling | accepted with retained terms gates |
| qualified terms/license verdict | still absent |
| source approval | none |
| `eligible_for_slice_review` | none |
| EXT-G5/G6 | closed |
| BCK20-OD-02/05 | Open |
| OD-10 | Proposed |
| BCK-20 | Draft |
| network/parser/fixtures/runtime | unauthorized |

## 9. Recommended exact owner response

```text
Одобряю BCK20-OD02-SRC-GOV-REV-01 v0.1:
Accept source-governance design boundary with retained terms and executable
gates для точных BCK20-OD02-EXT-EV-01 v0.3 / normalized-LF SHA-256
094b70ab9888922f85a16f2b8a9f741c817868aa5ed3e3ad8e16076dbadd36f5,
BCK20-OD02-EXT-AD-SRC-TERMS-DEC-PKG-01 v0.1 / normalized-LF SHA-256
596873a51fd09839b4d63f80cdcb0cc5a2c21cfbe97ec377e7678f5173727bd1
и BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01 v0.1 / normalized-LF SHA-256
214d6c0dec67b379bfba836ba1c6089e03b14b3fddaf4f38d55be03af41b081b.
Принимаю field-authority ceilings, freshness classes, review thresholds,
changed-hash, withdrawal и conflict rules только как documentation design
boundary. Подтверждаю combined roles и отсутствие independent/qualified
Legal verdict. Ни один source не переводить в eligible_for_slice_review.
EXT-G5/G6 закрыты; BCK20-OD-02/05 Open; OD-10 Proposed; BCK-20 Draft.
Network, terms acceptance, parser, fixtures, datasets, runtime, Firebase,
deployment, activation, push и merge не разрешаю.
```

## 10. Acceptance criteria

1. **BCK20-OD02-SRC-GOV-AC-01:** all three governance inputs are frozen by exact normalized hash.
2. **BCK20-OD02-SRC-GOV-AC-02:** eight source IDs remain separate.
3. **BCK20-OD02-SRC-GOV-AC-03:** technical, terms, freshness and product authority remain independent dimensions.
4. **BCK20-OD02-SRC-GOV-AC-04:** every source has a bounded field-authority ceiling.
5. **BCK20-OD02-SRC-GOV-AC-05:** corroborating evidence never becomes product authority silently.
6. **BCK20-OD02-SRC-GOV-AC-06:** freshness thresholds authorize no network schedule.
7. **BCK20-OD02-SRC-GOV-AC-07:** immutable releases are never overwritten in place.
8. **BCK20-OD02-SRC-GOV-AC-08:** unexpected changed hashes quarantine rather than blind-apply.
9. **BCK20-OD02-SRC-GOV-AC-09:** withdrawal prevents fallback/cache resurrection.
10. **BCK20-OD02-SRC-GOV-AC-10:** cross-source ambiguity fails closed.
11. **BCK20-OD02-SRC-GOV-AC-11:** local hashes do not claim provider authenticity or lawful use.
12. **BCK20-OD02-SRC-GOV-AC-12:** ISO 3166 and direct ISO 4217 remain blocked without substitution.
13. **BCK20-OD02-SRC-GOV-AC-13:** SIX cannot silently prove direct ISO edition authority.
14. **BCK20-OD02-SRC-GOV-AC-14:** CLDR remains limited to selected locale format/display scope.
15. **BCK20-OD02-SRC-GOV-AC-15:** UN/EU evidence cannot activate market or currency policy.
16. **BCK20-OD02-SRC-GOV-AC-16:** qualified terms/access review remains mandatory.
17. **BCK20-OD02-SRC-GOV-AC-17:** no source becomes eligible for slice review from this package.
18. **BCK20-OD02-SRC-GOV-AC-18:** EXT-G5/G6 and all markets remain closed/disabled.
19. **BCK20-OD02-SRC-GOV-AC-19:** owner acceptance permits documentation reconciliation only.
20. **BCK20-OD02-SRC-GOV-AC-20:** network, parser, fixtures, datasets, runtime, Firebase, deployment, push and merge remain unauthorized.

## 11. Next action

Freeze this package by normalized-LF SHA-256. The owner may accept the bounded
governance rules while every source remains Pending/Blocked. The next external
dependency is the already prepared qualified terms/access review; no further
broad source discovery is required before that review identifies a precise
evidence gap.
