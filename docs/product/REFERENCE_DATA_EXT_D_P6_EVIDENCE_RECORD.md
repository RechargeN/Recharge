# BCK-20 — EXT-D P6 Consolidated Evidence Record

- ID: `BCK20-OD02-EXT-D-P6-EV-01`
- Version: `0.1`
- Date: `2026-09-19`
- Status: **Recorded — mixed technical evidence complete; source acceptance Pending/Blocked**
- Sources: `SRC-ISO-3166`, `SRC-ISO-4217`, `SRC-SIX-4217`
- Parent authorization: `BCK20-OD02-EXT-D-ALL-AUTH-01` v0.1
- Parent authorization normalized-LF SHA-256:
  `e646b11478aab164ea795dd59ac74c7865bedc3eaf66f81710546b2bf046713d`
- Authorization instance: `1c4ba623-e0cb-47db-82b8-ce297f954d56`
- Owner boundary: RechargeN / Product owner combined technical evidence;
  no independent or qualified Security/Privacy/Legal claim

## 1. Purpose and bounded verdict

This record consolidates the single authorized EXT-D P1–P6 run. It records
each source and evidence dimension independently. A blocked ISO page, missing
SIX artifact or unresolved terms page is not converted into a batch-wide Pass
and was not bypassed.

Verdict:

- `SRC-ISO-3166`: **Blocked** for executable-source review — the exact public
  landing and ISO copyright pages returned HTTP 403; no ISO 3166 artifact was
  authorized or acquired;
- `SRC-ISO-4217`: **Pending/Blocked** for direct ISO standard identity and ISO
  terms — the exact ISO standard and copyright pages returned HTTP 403;
- `SRC-SIX-4217`: **technical evidence Pass with gaps** for the maintenance
  role, current List One and historic List Three;
- SIX List Two XML: **Absent at the exact approved URI** — HTTP 404; the page
  exposes a `.doc` candidate that was recorded but not followed;
- ISO terms: **Blocked by HTTP 403**;
- SIX terms: **Pending** — the approved legacy disclaimer URI returned 404 and
  a current terms candidate was recorded but not followed;
- provider checksum/signature: **not identified**; locally computed hashes are
  evidence, not provider signatures;
- all three source states remain Pending or Blocked and not
  `eligible_for_slice_review`;
- reusable parser, fixtures, repository datasets, runtime and Firebase remain
  absent and unauthorized.

## 2. Exact execution result

| Metric | Result |
|---|---:|
| exact initial GET requests | 8 |
| redirects | 0 |
| captured bodies | 3 |
| HTTP failures | 4 |
| exact artifact 404 outcomes | 1 |
| credentials, cookies, retries | 0 |
| discovered links followed | 0 |
| total captured body bytes | 291,302 |

Evidence hashes:

| Evidence | SHA-256 |
|---|---|
| run manifest | `7985b234de0bdfb6dd0118808efb29f85ea4f4c2d55ed49894a30037eab121a1` |
| network result | `d4d1034c50328e43cadf8fed37f43978226a5e7b22759619b6164b1cc41cd158` |
| candidate-link disposition | `2611d8c70a822670337b9f73e40ac6f931b0fcbc97f314dc880e70e8f25fe760` |
| P4/P5 validation result | `5f458b80d0246ce96bc420992f48c9ce526352eddb6c0115dcee9c8200369881` |
| consolidated run result | `05b927b17513272ee11c3e66da9da4181e4b35725ae3c333cbefab344ad90b3a` |

## 3. ISO evidence disposition

### 3.1 ISO 3166

| Exact URI | HTTP outcome | Disposition |
|---|---:|---|
| `https://www.iso.org/iso-3166-country-codes.html` | 403 | landing/standard evidence unavailable to the authorized unauthenticated client |
| `https://www.iso.org/privacy-and-copyright.html` | 403 | terms/copyright evidence unavailable |

No account, authenticated browser, paywall, click-through, alternate client,
guessed API or source substitution was attempted. No ISO 3166 code-list
artifact was acquired. Existing UN M49 or CLDR evidence is not relabelled as
ISO 3166 evidence.

Result: `SRC-ISO-3166` remains **Blocked/Pending** for exact artifact, edition,
terms, storage, derivative and redistribution evidence.

### 3.2 ISO 4217

| Exact URI | HTTP outcome | Disposition |
|---|---:|---|
| `https://www.iso.org/standard/64758.html` | 403 | exact standard identity/edition/status not revalidated |
| `https://www.iso.org/privacy-and-copyright.html` | 403 | ISO terms/copyright evidence unavailable |

SIX maintenance data provides technical code-list evidence but cannot silently
replace the unavailable ISO standard edition and ISO terms evidence.

Result: `SRC-ISO-4217` remains **Pending/Blocked** for direct standard and
terms dimensions.

## 4. SIX authority-page evidence

The exact SIX data-standards page returned HTTP 200:

| Field | Evidence |
|---|---|
| Exact URI | `https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html` |
| Bytes | 213,173 |
| SHA-256 | `f45e164ed2f9dcd68d4f95711b7d09b49cb2d69adf27e9e9fbb05057161d1584` |

The captured page explicitly states that SIX:

- is the official Maintenance Agency for ISO 4217 currency codes;
- maintains and updates the currency-code lists;
- makes the lists available online and free of charge;
- distinguishes current List One, funds List Two and historic List Three.

“Free of charge” is access evidence only. It is not treated as permission for
repository storage, derivative datasets, redistribution or commercial/mobile
use.

## 5. SIX List One — current currency and funds

| Field | Evidence |
|---|---|
| Exact URI | `https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml` |
| HTTP/media type | 200 / `application/xml` |
| Provider publication date | `2026-09-17` |
| Bytes | 47,491 |
| SHA-256 | `33139b438657d1cee116ba737807ea71d19d6de4b90f799a09c56f0cc6a1b0ff` |
| ETag | `"b983-65bcd398d889d"` |
| Last-Modified | `2026-09-19T03:00:52Z` |

Safe XML controls:

- DTD prohibited;
- external resolver disabled;
- entity expansion disabled;
- 10 MiB maximum document size;
- no XSLT or processing-instruction execution;
- no extracted row or normalized dataset written to disk or repository.

Validation result:

| Check | Result |
|---|---:|
| total entity rows | 280 |
| rows with currency code | 277 |
| rows without currency code | 3 |
| distinct currency codes | 178 |
| invalid alphabetic codes | 0 |
| invalid numeric codes | 0 |
| invalid minor-unit markers | 0 |
| minor unit above accepted bound | 0 |
| duplicate entry identities | 0 |
| conflicting numeric/minor semantics per code | 0 |

Observed minor-unit values are `0`, `2`, `3`, `4` and provider marker
`N.A.`.

Bounded Baltic/EUR evidence:

| Entity | Alphabetic | Numeric | Minor unit | Result |
|---|---|---:|---:|---|
| Estonia | `EUR` | `978` | `2` | Pass |
| Latvia | `EUR` | `978` | `2` | Pass |
| Lithuania | `EUR` | `978` | `2` | Pass |

List One contains 37 entity rows using EUR. Only the three selected Baltic
rows are included in this evidence record.

## 6. SIX List Two — funds

The exact approved XML URI returned HTTP 404:

```text
https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-two.xml
```

The captured SIX page instead exposes this unapproved candidate:

```text
https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-two.doc
```

The `.doc` candidate was not requested, downloaded, parsed or executed. List
Two remains **Absent/Pending** and no URI substitution was performed.

## 7. SIX List Three — historic currencies and funds

| Field | Evidence |
|---|---|
| Exact URI | `https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-three.xml` |
| HTTP/media type | 200 / `application/xml` |
| Provider publication date | `2026-01-01` |
| Bytes | 30,638 |
| SHA-256 | `98fde2423cdb916dd59dcf5fe96222edad8fa198d865c1c83dbc464b9cc52387` |
| ETag | `"77ae-65bcd3b8d6bd9"` |
| Last-Modified | `2026-09-19T03:01:25Z` |

Validation result:

| Check | Result |
|---|---:|
| historic rows | 169 |
| distinct historic codes | 137 |
| invalid alphabetic codes | 0 |
| invalid present numeric codes | 0 |
| missing withdrawal fields | 0 |
| duplicate historic entry identities | 0 |

Eight codes occur in both current and historic evidence: `EUR`, `IDR`, `MWK`,
`PEN`, `RON`, `SDG`, `SZL`, and `TRY`. This is retained as temporal/entity
history evidence, not treated as a current-list conflict, and no historic row
is promoted to active.

## 8. SIX terms disposition

The approved legacy disclaimer URI returned HTTP 404:

```text
https://www.six-group.com/en/site/disclaimer.html
```

The captured standards page exposed the following current candidate, which was
recorded but not followed:

```text
https://www.six-group.com/en/services/legal/terms-and-conditions.html
```

Therefore terms/use remains **Inconclusive/Pending**. Technical accessibility
and a public download do not establish storage, automation, derivative,
notice, redistribution or commercial-use rights.

## 9. Dimension-by-dimension status

| Dimension | `SRC-ISO-3166` | `SRC-ISO-4217` | `SRC-SIX-4217` |
|---|---|---|---|
| official landing authority | **Blocked — 403** | **Blocked — 403** | Pass |
| exact public artifact | **Absent** | SIX evidence cannot replace ISO edition | List One/List Three Pass; List Two Absent |
| provider version/date | **Absent** | direct ISO evidence Absent | Pass for Lists One/Three |
| structural safety | not reached | not reached directly | Pass for Lists One/Three |
| bounded semantic validation | not reached | direct ISO evidence Pending | Pass with List Two gap |
| provider checksum/signature | **Absent** | **Absent** | not identified; local hashes only |
| terms evidence | **Blocked — 403** | **Blocked — 403** | **Pending — approved URI 404** |
| allowed-use/legal disposition | **Pending/Blocked** | **Pending/Blocked** | **Pending** |
| parser/fixtures | **Absent** | **Absent** | **Absent** |
| repository ingestion | **Unauthorized** | **Unauthorized** | **Unauthorized** |
| source state | **Blocked/Pending** | **Blocked/Pending** | **Pending** |

## 10. Temporary evidence location

Raw pages, XML and derived validation evidence remain outside the repository:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-d-all-1c4ba623-e0cb-47db-82b8-ce297f954d56
```

This record does not authorize deletion.

## 11. Retained gates

- no source advances to `eligible_for_slice_review`;
- ISO access/terms and SIX current terms require separate lawful resolution;
- no account, paid access, click-through, authenticated browser or technical
  bypass is authorized;
- no qualified Legal or independent Security/Privacy review is claimed;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- all markets remain disabled;
- parser, fixtures, repository datasets, provider selection, schema,
  IAM/runtime, Firebase, ingestion, deployment, activation, push and merge
  remain unauthorized.

## 12. Next bounded work

1. include ISO 403 evidence, the current SIX terms candidate and all exact
   hashes in the consolidated qualified terms/access review;
2. decide whether ISO evidence requires a licensed artifact/account or whether
   the affected ISO source must remain unavailable;
3. if owner review still requires List Two, authorize the exact `.doc` only in
   a separately bounded non-executing inspection slice;
4. do not treat SIX List One/List Three technical Pass as ISO terms acceptance;
5. consolidate EXT-A through EXT-D into the source/terms decision package
   before any EXT-G6 parser or repository-data proposal.

## 13. Acceptance criteria

1. **BCK20-OD02-EXT-D-P6-EV-AC-01:** all eight exact requests and outcomes are represented without fallback substitution.
2. **BCK20-OD02-EXT-D-P6-EV-AC-02:** ISO 403 results remain Blocked/Pending and are not bypassed.
3. **BCK20-OD02-EXT-D-P6-EV-AC-03:** ISO 3166 evidence is not reconstructed from UN, CLDR or memory.
4. **BCK20-OD02-EXT-D-P6-EV-AC-04:** SIX authority-page, active-list, funds-list and historic-list dimensions remain distinct.
5. **BCK20-OD02-EXT-D-P6-EV-AC-05:** the unavailable List Two XML is not silently replaced by the unapproved `.doc` candidate.
6. **BCK20-OD02-EXT-D-P6-EV-AC-06:** XML safety controls and exact hashes are explicit.
7. **BCK20-OD02-EXT-D-P6-EV-AC-07:** EUR `978` minor unit `2` is recorded only for the three selected Baltic entities.
8. **BCK20-OD02-EXT-D-P6-EV-AC-08:** historic/current code overlap never promotes historic rows to active.
9. **BCK20-OD02-EXT-D-P6-EV-AC-09:** local hashes are not presented as provider signatures.
10. **BCK20-OD02-EXT-D-P6-EV-AC-10:** free public access is not presented as allowed-use or Legal approval.
11. **BCK20-OD02-EXT-D-P6-EV-AC-11:** raw pages, XML and full third-party lists remain outside the repository.
12. **BCK20-OD02-EXT-D-P6-EV-AC-12:** all source states remain Pending or Blocked and not eligible for slice review.
13. **BCK20-OD02-EXT-D-P6-EV-AC-13:** reusable parser, fixtures, datasets and runtime remain absent and unauthorized.
14. **BCK20-OD02-EXT-D-P6-EV-AC-14:** Firebase, deployment, activation, push and merge remain unauthorized.
