# BCK-20 — EXT-A P6 Consolidated Evidence Record

- ID: `BCK20-OD02-EXT-A-P6-EV-01`
- Version: `0.1`
- Date: `2026-09-19`
- Status: **Recorded — technical evidence complete; terms/use and runtime authority Pending**
- Sources: `SRC-IANA-LANG`, `SRC-IANA-TZDB`
- Parent plan: `BCK20-OD02-EXT-EV-PLAN-01` v0.1
- Parent plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Owner boundary: RechargeN / Product owner combined technical evidence;
  no independent or qualified Security/Privacy/Legal claim

## 1. Purpose and verdict

This record consolidates the bounded external-evidence work completed for
EXT-A. It stores only permitted metadata, hashes, provenance, technical
results and limitations. Raw third-party landing pages, terms, registry data
and archives remain in authorization-specific OS temporary directories and are
not committed.

Technical verdict:

- `SRC-IANA-LANG`: **technical evidence Pass** for the exact registry snapshot;
- `SRC-IANA-TZDB`: **technical evidence Pass** for release `2026d` and the
  selected Baltic validation scope;
- IANA terms evidence: **Captured, allowed-use disposition Pending**;
- external source state: **Pending**, not `eligible_for_slice_review`;
- parser, repository ingestion, runtime, Firebase and markets: **not
  authorized and not implemented**.

## 2. Execution provenance

| Stage | Authorization / run ID | Exact scope | Result |
|---|---|---|---|
| Initial P1 discovery | `aba31978-ab80-4ca5-9d57-c976e54ebcb2` | two IANA landing pages | `ext_g1_pass` |
| Follow-up endpoint metadata | `3d66a7bd-cc68-4245-9a26-bdcd1bda767c` | HEAD-only language/TZDB candidates | `p1b_endpoint_metadata_pass` |
| TZDB release-page discovery | `739ecc20-c3e1-4a15-afa2-328cae599822` | exact 2026d HTML page | `p1_html_link_discovery_pass` |
| IANA terms capture | `663ccbd6-3cc1-4eef-bd77-53ec7f7e27d6` | exact licensing-terms page | `terms_evidence_captured` |
| TZDB artifact HEAD | `09f32b60-deed-48a3-843c-713bd755f33c` | exact archive metadata | `artifact_endpoint_metadata_pass` |
| TZDB P3/P4 | `39a58b5f-e378-4a40-8bd4-bf885a890ff0` | exact archive acquisition and list-only inventory | `p3p4_inventory_pass` |
| TZDB selected P5 | same P3/P4 evidence root | eight exact members streamed to memory | `p5_selected_validation_pass` |
| Language Registry P3/P5 | `3bfd674a-97cf-4b29-83be-f3fbbeb426d9` | exact registry acquisition and evidence-only validation | corrected `p5_registry_validation_pass` |

All network operations used public unauthenticated HTTPS endpoints without
credentials, cookies, account state, request bodies or automatic retries. No
temporary evidence was copied into application/runtime paths.

## 3. Immutable evidence index

### 3.1 Discovery and terms

| Evidence | Bytes | SHA-256 | Disposition |
|---|---:|---|---|
| language discovery landing HTML | 6,866 | `a35082b840737a0a14b97b76c390d0983a3f73f7febb61c4b72f83229fb1056d` | discovery only |
| TZDB discovery landing HTML | 8,167 | `e47fb8ba6a90efe1a96cc207c31ee24a5a7e24b702a3155d7b9d197bd21450c4` | discovery only |
| TZDB 2026d release HTML | 9,803 | `155475baae06fa7bc72fda56f401b54160a90709f8a8fc0efe9fecda0333a06f` | exact artifact-link evidence |
| IANA licensing-terms HTML | 8,375 | `43cfd90b1cb25ca86933032612a2c466fac94d7afc934ca8ef96a61e2b55e1b3` | evidence captured; no legal conclusion |

The terms page was captured exactly once. This record does not conclude that
its terms authorize storage, parsing, derived output, notices,
redistribution, commercial/mobile use or repository ingestion.

### 3.2 Language Subtag Registry

| Field | Evidence |
|---|---|
| Exact URI | `https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry` |
| Media type | `text/plain` |
| Snapshot bytes | 731,819 |
| Snapshot SHA-256 | `755fad43283be7b41ebe3c89ad054b6eaf928f404f9c0edb74799e0eab74beb1` |
| Registry `File-Date` | `2026-09-17` |
| Corrected validation-result SHA-256 | `9507f55bc8b059e0e9b57ac69d536922bc33b967e2d828aaabc067c63bbe03b6` |
| Validation-reconciliation SHA-256 | `321d4a4d2eb1f7fa9ecc7d6fefbbbaab606f939a0a0f964c3265fbdce92829e1` |

The initial local validation result was a false negative caused by a
PowerShell shorthand filter, an over-narrow identity regex that rejected the
four IANA reserved-range records, and an incorrect ordered-map projection.
The raw snapshot did not change, the network was not repeated, and the exact
corrected validator result supersedes that local result.

Corrected technical evidence:

| Record class | Count |
|---|---:|
| language | 8,276 |
| extlang | 258 |
| script | 225 |
| region | 305 |
| variant | 139 |
| grandfathered | 26 |
| redundant | 67 |
| **Total** | **9,296** |

- four reserved-range identities are recognized explicitly;
- 302 deprecated records and 423 preferred-value mappings are represented;
- record keys and canonicalization source keys are unique;
- known types/fields only; no malformed record lines;
- product languages `en`, `ru`, `lv` are present;
- Baltic languages `lv`, `et`, `lt` and regions `LV`, `EE`, `LT` are present;
- script `Latn` is present.

### 3.3 TZDB 2026d

| Field | Evidence |
|---|---|
| Exact URI | `https://data.iana.org/time-zones/releases/tzdb-2026d.tar.lz` |
| Media type | `application/x-lzip` |
| Content length | 567,332 bytes |
| Last-Modified observed by HEAD | `2026-09-11T22:36:31Z` |
| ETag observed by HEAD | `"8a824-65b3cb74239c0"` |
| Archive SHA-256 | `aab9e59f7b2530b0f98079f7c8645f2cdf59a2cd8992ca0ddfbbec0ec83b65de` |
| P3/P4 run-result SHA-256 | `588efe56c8f1e06348799a98917d7e895ffd17ef54270943a676acc3e26ed288` |
| Selected P5 result SHA-256 | `3d2ad00bd16ed98481555f6ba0295004f69310b3512c722aedecec027ab140e2` |

List-only `bsdtar 3.8.8` inventory found 67 entries with:

- zero unsafe or absolute paths;
- zero duplicate paths;
- zero nested archives;
- zero obvious binary entries;
- zero symlinks and hardlinks;
- zero list errors or stderr output.

Eight exact members were streamed to memory without general filesystem
extraction. Raw member files were not written:

| Member | Bytes | SHA-256 |
|---|---:|---|
| `LICENSE` | 252 | `0613408568889f5739e5ae252b722a2659c02002839ad970a63dc5e9174b27cf` |
| `version` | 6 | `e5991d2ec7b3c5fbd147d25d2ac1344d70da4bdaaf88e9df51525b9f72fb53f0` |
| `europe` | 187,231 | `0fef17177d871af93188f2985e6034029bfd83e43d2a1c3838e4320712dba7c1` |
| `backward` | 14,051 | `b8296b9ef1ece72d813878132c0f17e2c52b26af6004eeb9c37d049b64cd9401` |
| `zone1970.tab` | 17,591 | `cf7a21adf7153794a684c03e499e882ee119f828ad77a579ed99db26ceeae87b` |
| `zone.tab` | 18,808 | `0718261beed45895d9a215d979febfb35c14fdcaa4fa7eec644401e5471d7b65` |
| `iso3166.tab` | 4,841 | `837c80785080c8433fd9d4ea87e78f161ac7a40389301c5153d4f90198baeb2a` |
| `leap-seconds.list` | 5,065 | `db5a895f16853b03bfc865e8d68f9fc8710ef1740e3400c701cd46a5bbbc3433` |

Selected technical validation passed:

- embedded version equals `2026d`;
- 312 unique `zone1970.tab` zone IDs and 418 unique `zone.tab` zone IDs;
- 249 unique ISO country codes;
- `LV`, `EE`, `LT` are present;
- `Europe/Riga`, `Europe/Tallinn`, `Europe/Vilnius` are present and defined;
- 252 backward aliases are unique and do not collide with `zone1970.tab` IDs;
- leap-second rows and expiration marker are present;
- bundled `LICENSE` is present and non-empty.

No provider checksum or signature link was identified in the authorized
release-page evidence. The archive SHA-256 above is locally computed evidence,
not a provider-signed integrity assertion.

## 4. Dimension-by-dimension status

| Dimension | Language Registry | TZDB 2026d |
|---|---|---|
| official HTTPS origin/path | Pass | Pass |
| exact artifact identity and raw hash | Pass | Pass |
| deterministic version/date identity | Pass (`2026-09-17`) | Pass (`2026d`) |
| structural safety | Pass for text-registry structure | Pass for archive inventory |
| selected semantic validation | Pass | Pass for Baltic scope |
| terms evidence captured | Pass as evidence only | external terms + bundled LICENSE evidence captured |
| allowed-use/legal disposition | **Pending** | **Pending** |
| provider signature/checksum | not identified | not identified |
| production parser/fixtures | **Absent** | **Absent** |
| repository ingestion | **Unauthorized** | **Unauthorized** |
| source status | **Pending** | **Pending** |

Technical Pass is not source acceptance. Missing terms/use disposition and
production parser evidence prevent `eligible_for_slice_review`.

## 5. Temporary evidence locations

The following directories remain outside the repository pending explicit
cleanup/retention disposition:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-p1-aba31978-ab80-4ca5-9d57-c976e54ebcb2
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-p1b-3d66a7bd-cc68-4245-9a26-bdcd1bda767c
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-tzdb-2026d-739ecc20-c3e1-4a15-afa2-328cae599822
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-g2-iana-terms-663ccbd6-3cc1-4eef-bd77-53ec7f7e27d6
C:\Users\User\AppData\Local\Temp\recharge-bck20-tzdb-2026d-head-09f32b60-deed-48a3-843c-713bd755f33c
C:\Users\User\AppData\Local\Temp\recharge-bck20-tzdb-2026d-p3p4-39a58b5f-e378-4a40-8bd4-bf885a890ff0
C:\Users\User\AppData\Local\Temp\recharge-bck20-iana-lang-p3p5-3bfd674a-97cf-4b29-83be-f3fbbeb426d9
```

This record does not authorize deletion. Raw evidence must not be committed by
default.

## 6. Retained gates

- terms/use questions for storage, derived output, notices, redistribution and
  commercial/mobile use remain Pending;
- no qualified Legal or independent Security/Privacy review is claimed;
- `SRC-IANA-LANG` and `SRC-IANA-TZDB` remain Pending;
- `EXT-G5` and `EXT-G6` remain closed;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- provider selection, production parser, fixtures, schema, IAM/runtime,
  Firebase, ingestion, deployment, activation, push and merge remain
  unauthorized.

## 7. Next bounded work

1. obtain an applicable qualified terms/use disposition for the exact external
   terms hash and bundled TZDB LICENSE hash;
2. retain or delete each temporary evidence root only through an explicit
   cleanup decision;
3. if terms/use permits, prepare one separately Approved parser/fixture slice
   that consumes only the exact source fields needed by the application;
4. do not place raw registries or TZDB data in the repository before that
   slice and its storage/notice obligations are accepted;
5. only accepted terms/use plus parser/validation evidence may advance a
   source toward `eligible_for_slice_review`.

## 8. Acceptance criteria

1. **BCK20-OD02-EXT-A-P6-EV-AC-01:** the record identifies both exact sources, versions, URIs and hashes.
2. **BCK20-OD02-EXT-A-P6-EV-AC-02:** raw third-party content remains outside the repository.
3. **BCK20-OD02-EXT-A-P6-EV-AC-03:** discovery, terms, artifact, inventory and selected validation evidence are independently distinguished.
4. **BCK20-OD02-EXT-A-P6-EV-AC-04:** the corrected Language Registry validation supersedes only the local false-negative result and does not rewrite raw evidence.
5. **BCK20-OD02-EXT-A-P6-EV-AC-05:** IANA reserved ranges are recognized without weakening record-key validation.
6. **BCK20-OD02-EXT-A-P6-EV-AC-06:** TZDB archive safety and selected Baltic semantic checks are recorded separately.
7. **BCK20-OD02-EXT-A-P6-EV-AC-07:** locally computed hashes are not presented as provider signatures.
8. **BCK20-OD02-EXT-A-P6-EV-AC-08:** terms capture is not presented as allowed-use or legal approval.
9. **BCK20-OD02-EXT-A-P6-EV-AC-09:** both source states remain Pending.
10. **BCK20-OD02-EXT-A-P6-EV-AC-10:** production parser, fixtures and ingestion remain absent and unauthorized.
11. **BCK20-OD02-EXT-A-P6-EV-AC-11:** temporary evidence deletion is not authorized by this record.
12. **BCK20-OD02-EXT-A-P6-EV-AC-12:** EXT-G5/G6, markets, runtime, Firebase, deployment, activation, push and merge remain closed.
