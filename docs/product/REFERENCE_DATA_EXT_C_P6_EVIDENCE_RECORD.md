# BCK-20 — EXT-C P6 Consolidated Evidence Record

- ID: `BCK20-OD02-EXT-C-P6-EV-01`
- Version: `0.1`
- Date: `2026-09-19`
- Status: **Recorded — technical evidence complete; terms/use and source acceptance Pending**
- Sources: `SRC-UN-M49`, `SRC-EU-EURO`
- Parent authorization: `BCK20-OD02-EXT-C-P3P6-AUTH-01` v0.1
- Parent authorization normalized-LF SHA-256:
  `7ea80dff354c05039b5222decb4b33864d75a2170d4866c7edc10808273816f1`
- Authorization instance: `a0508d27-3b56-4fd1-9953-abf7b430e1de`
- Owner boundary: RechargeN / Product owner combined technical evidence;
  no independent or qualified Security/Privacy/Legal claim

## 1. Purpose and verdict

This record consolidates the bounded EXT-C evidence for UN M49 country/code
mappings and European Commission euro-adoption statements. It contains only
permitted metadata, hashes, provenance, validation results and the three
selected Baltic mappings. Raw pages and full third-party tables remain in
authorization-specific OS temporary storage and are not committed.

Technical verdict:

- `SRC-UN-M49`: **technical validation Pass** for the exact captured full-view
  response and selected country/code scope;
- `SRC-EU-EURO`: **technical validation Pass** for the exact captured
  Commission page and the three explicit Baltic adoption facts;
- M49 source identity limitation: **mutable and undated provider response**;
- UN and Commission terms evidence: **Captured, allowed-use disposition
  Pending**;
- both external source states: **Pending**, not
  `eligible_for_slice_review`;
- reusable parser, fixtures, repository data, runtime and Firebase: **absent
  and unauthorized**.

Technical Pass does not accept either source for ingestion and does not make a
Legal conclusion about storage, parsing, derived facts, attribution,
redistribution, modification or commercial/mobile use.

## 2. Execution provenance

| Stage | Authorization / run ID | Exact scope | Result |
|---|---|---|---|
| P1/P2 discovery and terms capture | `bb28a9bf-c907-489b-b321-c58983aecdca` | four exact UN/Commission public pages | `ext_c_p1p2_pass` |
| P1/P2 local reconciliation | same P1/P2 evidence root | classify M49 full-view candidate and explicit Baltic statements | Pass; zero network requests added |
| conditional P3 | `a0508d27-3b56-4fd1-9953-abf7b430e1de` | exact M49 `overview/` GET | response captured directly; no redirect |
| P4/P5 | same P3–P6 evidence root | bounded static-table and prior EU page validation | `ext_c_p3p6_technical_pass` |

Network execution used public unauthenticated HTTPS endpoints without
credentials, cookies, request bodies or retries. Candidate links were not
followed. No JavaScript, active content, spreadsheet, macro or downloaded code
was executed.

## 3. P1/P2 source and terms evidence

| Evidence | Exact URI | Bytes | SHA-256 |
|---|---|---:|---|
| UN M49 landing page | `https://unstats.un.org/unsd/methodology/m49/` | 2,051,368 | `4d5cabcb10ad9ef184553b5e64c0a34ba8deeb20dab2e02cd0be3599b93bb01d` |
| UN terms of use | `https://www.un.org/en/about-us/terms-of-use` | 93,996 | `fc8db19659b8622d474340bf5d26e26ec5cc1e581c8e247c2e05333f51df5f94` |
| Commission euro-area page | `https://economy-finance.ec.europa.eu/euro/what-euro-area_en` | 80,708 | `4ba3e44abb640b631ac5c2433fc52fc1525c9455b402b26e4717c7e82c51d715` |
| Commission legal notice | `https://commission.europa.eu/legal-notice_en` | 152,319 | `53841095389ec2b365b70a7a683426bf40d1df644a3ff7c64155364ea1fff739` |

The initial generic link inventory retained navigation and asset URLs before
local classification. The reconciliation selected only the official M49
`overview/` page for primary-table follow-up and excluded the historical
developed/developing-region workbook from the country/code scope. No response
was changed and no network request was repeated.

## 4. UN M49 P3/P4 evidence

| Field | Evidence |
|---|---|
| Exact URI | `https://unstats.un.org/unsd/methodology/m49/overview/` |
| HTTP result | 200; no redirect |
| Media type | `text/html` |
| Response bytes | 1,721,575 |
| Raw response SHA-256 | `b9048114f6e7f2abda83bf03d4263c9d7cd1bd7230e3d0461025ee7839a7a1fb` |
| Response metadata SHA-256 | `4e4f66d42213ead7ae6f9dfe3f4615eb98ac2d46a7a551b7a936361411268411` |
| Run manifest SHA-256 | `52ba137b67ad2c63628283a5dee15a4951ca4bd0eab74cf405231e56655790a9` |
| Run result SHA-256 | `cb63ed55c9aa0eb8ae8871bfa97da9ca7afcbcecb4af3c8b15fb697081fd6cd6` |
| Validation evidence SHA-256 | `95d40410f645395dcb1da57953b02421aff4da94fa800433bc15e0871cd6e16c` |
| Artifact-candidate inventory | empty JSON array; SHA-256 `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945` |

The response directly contains six static localized tables. Active content was
not executed. No secondary CSV, spreadsheet, API or download URI was required
or followed.

Structural results:

- six tables, each containing 16 columns and 248 data rows;
- zero malformed column-count rows;
- zero invalid three-digit M49 codes;
- zero invalid alpha-2 or alpha-3 codes;
- zero duplicate M49, alpha-2 or alpha-3 identifiers per table;
- all six code sets are identical;
- canonical code-set SHA-256:
  `37fe0345c60b2c6e92fa4187397ec227169d41ec48df135c298208d7f780223b`;
- UN statistical classifications were inspected only as structural columns
  and are explicitly excluded from Recharge market-policy authority.

The provider response exposes neither an immutable release identifier nor a
usable modification date. The exact retrieval evidence and raw hash make this
captured observation reproducible for audit, but the mutable URI remains a
source-acceptance limitation and requires a freshness/update policy before
executable use.

## 5. Selected M49 validation

Only the following mappings are recorded as bounded Baltic evidence:

| Country | Alpha-2 | Alpha-3 | M49 | Result |
|---|---|---|---:|---|
| Estonia | `EE` | `EST` | `233` | Pass in all six tables |
| Latvia | `LV` | `LVA` | `428` | Pass in all six tables |
| Lithuania | `LT` | `LTU` | `440` | Pass in all six tables |

This evidence does not select launch markets, define service areas, accept
localized country copy or replace an ISO licensing/authority decision.

## 6. Selected EU euro validation

The P5 run reused the exact previously captured Commission response by its
SHA-256. It made no additional EU request and confirmed these explicit page
statements:

| Member State | Joined euro area | Result |
|---|---:|---|
| Estonia | 2011 | Pass |
| Latvia | 2014 | Pass |
| Lithuania | 2015 | Pass |

These facts corroborate historical euro adoption only. They do not activate a
Recharge market, assign a production currency, determine price/tax/payment
policy or authorize a commercial feature.

## 7. Terms and allowed-use status

The exact UN terms and Commission legal-notice responses are captured, but no
qualified disposition currently establishes:

- permission to store full source snapshots or derived datasets;
- permission to distribute normalized facts in a commercial mobile product;
- attribution, copyright, source-link or change-notice requirements;
- modification/localization rights;
- automated update frequency and rate conditions;
- withdrawal, replacement and deletion obligations.

Accordingly, terms/use is Pending for both sources. No raw table or reusable
derived dataset may enter the repository or application from this record.

## 8. Dimension-by-dimension status

| Dimension | `SRC-UN-M49` | `SRC-EU-EURO` |
|---|---|---|
| official HTTPS origin/path | Pass | Pass |
| exact captured response and hash | Pass | Pass |
| immutable provider version/date | **Pending — mutable/undated** | **Pending — retrieval-dated page** |
| structural safety | Pass | Pass as bounded page evidence |
| selected Baltic validation | Pass | Pass |
| terms/legal-notice evidence captured | Pass as evidence only | Pass as evidence only |
| allowed-use/legal disposition | **Pending** | **Pending** |
| reusable parser/fixtures | **Absent** | **Absent** |
| repository ingestion | **Unauthorized** | **Unauthorized** |
| source status | **Pending** | **Pending** |

## 9. Temporary evidence locations

Raw and derived evidence remains outside the repository:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p1p2-bb28a9bf-c907-489b-b321-c58983aecdca
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p3p6-a0508d27-3b56-4fd1-9953-abf7b430e1de
```

This record does not authorize deletion.

## 10. Retained gates

- `SRC-UN-M49` and `SRC-EU-EURO` remain Pending and not
  `eligible_for_slice_review`;
- qualified terms/use disposition and a mutable-source freshness decision
  remain required;
- no qualified Legal or independent Security/Privacy review is claimed;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- production parser, fixtures, repository data, provider selection, schema,
  IAM/runtime, Firebase, ingestion, deployment, activation, push and merge
  remain unauthorized.

## 11. Next bounded work

1. include the exact UN and Commission terms hashes in the consolidated
   qualified terms/use review;
2. decide whether retrieval-time hash pinning plus a freshness policy is
   sufficient for the mutable M49/Commission pages or whether a dated provider
   artifact is mandatory;
3. advance neither source until those decisions are explicit;
4. proceed next with the separately authorized EXT-D discovery/evidence batch;
5. do not create parsers, fixtures or repository datasets before EXT-G5 and a
   separately Approved EXT-G6 slice.

## 12. Acceptance criteria

1. **BCK20-OD02-EXT-C-P6-EV-AC-01:** both exact source scopes, URIs, response sizes and hashes are recorded.
2. **BCK20-OD02-EXT-C-P6-EV-AC-02:** raw third-party pages and full tables remain outside the repository.
3. **BCK20-OD02-EXT-C-P6-EV-AC-03:** discovery, terms, artifact and validation evidence remain distinct.
4. **BCK20-OD02-EXT-C-P6-EV-AC-04:** the mutable/undated M49 limitation is explicit and never presented as immutable provider versioning.
5. **BCK20-OD02-EXT-C-P6-EV-AC-05:** identifier widths, uniqueness and cross-table equality are recorded.
6. **BCK20-OD02-EXT-C-P6-EV-AC-06:** only bounded Baltic M49 mappings are included.
7. **BCK20-OD02-EXT-C-P6-EV-AC-07:** only explicit Baltic euro-adoption statements are included.
8. **BCK20-OD02-EXT-C-P6-EV-AC-08:** UN groupings and EU statements cannot create Recharge market or pricing policy.
9. **BCK20-OD02-EXT-C-P6-EV-AC-09:** terms capture is not presented as allowed-use or Legal approval.
10. **BCK20-OD02-EXT-C-P6-EV-AC-10:** both source states remain Pending and not eligible for slice review.
11. **BCK20-OD02-EXT-C-P6-EV-AC-11:** reusable parser, fixtures, repository data and runtime remain absent and unauthorized.
12. **BCK20-OD02-EXT-C-P6-EV-AC-12:** temporary evidence deletion is not authorized.
13. **BCK20-OD02-EXT-C-P6-EV-AC-13:** Firebase, deployment, activation, push and merge remain unauthorized.
