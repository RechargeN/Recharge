# BCK-20 — EXT-B P6 Consolidated Evidence Record

- ID: `BCK20-OD02-EXT-B-P6-EV-01`
- Version: `0.1`
- Date: `2026-09-19`
- Status: **Recorded — technical evidence complete; terms/use and source acceptance Pending**
- Source: `SRC-UNICODE-CLDR`
- Release: `CLDR 48.2`
- Parent plan: `BCK20-OD02-EXT-EV-PLAN-01` v0.1
- Parent plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Owner boundary: RechargeN / Product owner combined technical evidence;
  no independent or qualified Security/Privacy/Legal claim

## 1. Purpose and verdict

This record consolidates the bounded external-evidence work completed for
EXT-B. It stores only permitted metadata, hashes, provenance, inventory and
technical validation results. Raw Unicode pages, terms, archives and selected
CLDR members remain in authorization-specific OS temporary storage and are not
committed.

Technical verdict:

- the exact CLDR 48.2 common-data archive is structurally valid for the
  selected Recharge locale-data scope;
- archive inventory and bounded in-memory XML validation: **Pass**;
- official checksum reconciliation: **Pass with recorded upstream filename
  anomaly** — the two official artifact URIs are byte-identical and match the
  provider SHA-512 published for `core.zip`, while the manifest's separate
  `cldr-common-48.2.zip` line does not match those bytes;
- Unicode License v3 evidence: **Captured, allowed-use disposition Pending**;
- UTS #35 evidence: **current generic page captured, immutable CLDR 48.2
  specification pin Pending**;
- external source state: **Pending**, not `eligible_for_slice_review`;
- parser, fixtures, repository ingestion, runtime, Firebase and markets:
  **not authorized and not implemented**.

Technical Pass does not accept the source for production use and does not
resolve license, notice, redistribution, modification or commercial/mobile-use
obligations.

## 2. Execution provenance

| Stage | Authorization / run ID | Exact scope | Result |
|---|---|---|---|
| P1/P2 discovery | `02c9fba7-a7d1-4091-9b63-3a55ebc1da71` | CLDR 48.2 release page, Unicode license and UTS #35 page | `ext_b_discovery_pass` |
| artifact metadata | `1d30fca0-3dff-4713-aef4-6f7dd85d78dc` | HEAD common archive; GET hashes index | `ext_b_artifact_metadata_pass` |
| P3 acquisition | `6710ec1e-9d14-410c-a534-41c6f179af10` | exact SHA-512 manifest and common archive | initial filename-specific checksum mismatch |
| P4 inventory | same P3–P6 evidence root | list-only `bsdtar 3.8.8` inventory | Pass |
| P5 selected validation | same P3–P6 evidence root | 13 XML members and bundled `LICENSE`, streamed to memory | Pass after local validator reconciliation |
| provider-alias reconciliation | same P3–P6 evidence root | exact official `core.zip` acquisition and byte comparison | `official_alias_identity_confirmed` |

All network operations used public unauthenticated HTTPS endpoints without
credentials, cookies, request bodies or automatic retries. Redirect and size
limits were enforced. No temporary evidence was copied into application,
runtime, fixture or repository-data paths.

## 3. Discovery, terms and specification evidence

| Evidence | Bytes | SHA-256 | Disposition |
|---|---:|---|---|
| CLDR 48.2 release directory HTML | 3,471 | `55905f3ea6ccd5aa25786842eafc1bd188adb5e8f9c17eb6207872f13a5a2028` | exact release/artifact-link evidence |
| Unicode License v3 text | 1,995 | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` | captured; no allowed-use conclusion |
| UTS #35 generic page HTML | 392,315 | `c04d92e36279b1b353cf4e6964c28383567709026c9fa69420e093961fe774dc` | current reference only; not immutable 48.2 pin |
| corrected candidate-link inventory | 1,581 | `28b9f7be03ddb621e6492c8cebe3c4ccbe0eb785ac0961bf08f56d1e098969e0` | supersedes local discovery dedup false-negative |
| candidate-link reconciliation | 509 | `417a31f97710676cdc3b288620d0cd453017fc7386f9b2b2450db46cf39f54c3` | no additional network access |
| hashes-index HTML | 1,361 | `2634857b6546be517fdc28455eaba791279b67e0636f9cf1290e0f83ba08d1ae` | checksum-link discovery only |
| `SHASUM512.txt` | 882 | `887b6111af840b169a879058a16f9941298ca914936b4ccefd52879f19cbb2b9` | exact provider checksum evidence |

The initial discovery inventory undercounted candidates because of a local
deduplication defect. The corrected inventory was derived from the already
captured release page; no source response changed and no network request was
repeated. `cldr-common-48.2.zip` is the only selected artifact. Code, tools,
keyboards and unrelated archives remain excluded.

## 4. Artifact identity and checksum reconciliation

### 4.1 Selected artifact

| Field | Evidence |
|---|---|
| Exact selected URI | `https://www.unicode.org/Public/cldr/48.2/cldr-common-48.2.zip` |
| Media type | `application/zip` |
| Content length | 36,044,097 bytes |
| HEAD ETag | `"225fd41-64d3182980100"` |
| HEAD Last-Modified | `2026-03-17T05:21:40Z` |
| Local SHA-256 | `d2844f9dbf6124d11a7b047f5381a467902d82a673be3d658f4c0791ffa0b83b` |
| Local SHA-512 | `de8660f5371e0fcfd03a42e3b4fc4c686ec6cd602b402f1e3d227844005a54eb7952873894443523837d5828c42874a1a267a19f91ded207a2d166144791fa62` |
| Initial P3 result SHA-256 | `460d464b9d2bec9d883fbba08af6e365bf1e51a110ab67e0a8a081c73bd93c43` |

### 4.2 Provider-manifest anomaly

The exact provider manifest publishes:

- `cldr-common-48.2.zip` SHA-512:
  `4dd00bed4ea525d834cc50b03ab74e6e0b553fed2b16fc9312d6e3b80712cd3b90ffa69a6bf9c6288c16aae9812225a488999dfc75dbaeb32d6c36d8a9af307f`;
- `core.zip` SHA-512:
  `de8660f5371e0fcfd03a42e3b4fc4c686ec6cd602b402f1e3d227844005a54eb7952873894443523837d5828c42874a1a267a19f91ded207a2d166144791fa62`.

The exact official `core.zip` URI was then acquired under the explicit
reconciliation authorization. It returned 36,044,097 bytes, SHA-256
`d2844f9dbf6124d11a7b047f5381a467902d82a673be3d658f4c0791ffa0b83b`
and the second SHA-512 above. Length, SHA-256 and SHA-512 are identical to the
selected common archive, establishing byte identity without relying on file
names alone.

Therefore:

- the selected bytes match a provider-published SHA-512 for the byte-identical
  official `core.zip` alias;
- the filename-specific `cldr-common-48.2.zip` checksum entry remains
  inconsistent and is not silently rewritten or reported as matching;
- the anomaly is retained as evidence and must remain visible to any future
  source-acceptance review;
- provider-alias reconciliation evidence SHA-256:
  `f44a56e5944da1143cf442ca70e0c95fb18bc8ce9a2b5c1d2bd60140378ebdb0`.

## 5. P4 archive inventory

List-only `bsdtar 3.8.8` inventory found 2,984 entries with:

- zero absolute or traversal paths;
- zero case-insensitive duplicate paths;
- zero nested archive candidates;
- zero symlink or hardlink entries;
- zero list errors and zero stderr bytes;
- all 13 required XML members and the root `LICENSE` present.

No general extraction or execution occurred.

## 6. P5 bounded in-memory validation

Exactly the following members were streamed to memory. Raw member files were
not written:

| Member | Bytes | SHA-256 |
|---|---:|---|
| `common/main/root.xml` | 290,870 | `f69ab139130793ab721b6d1be8c1385b9a051e0b7c5893615533bcfa7bab0448` |
| `common/main/en.xml` | 478,255 | `68ab8c8e382b959a8761dd23e28ffd795b5ef398248f197176f2a08575b32081` |
| `common/main/ru.xml` | 852,325 | `ed906893a87b1d90595ef1cf1c2581ae91aa7667c8fed98abc489e7b14eef2d7` |
| `common/main/lv.xml` | 459,608 | `e3aba20874900ae3cef28a1ddf4b90ae3b6eb023fa655deeccfc75117ddb0ff0` |
| `common/main/et.xml` | 309,851 | `fad7c2cb0dedcb92c1215d2ad4b4650be9a23582e3d879578563d48778031445` |
| `common/main/lt.xml` | 622,234 | `2bd0ebd04680c20b77e9b50f39f98348446f84c1bb704ca9d5025dd1357a7ff3` |
| `common/supplemental/supplementalData.xml` | 399,983 | `cd2af39aef82fdbfba4d591c87548203350538ad2318486d104b3b38b8d62f1a` |
| `common/supplemental/supplementalMetadata.xml` | 180,141 | `36e807ce72b15304dd993f132216f408351be1c4376edaa2fe9e9547e2efcac1` |
| `common/supplemental/likelySubtags.xml` | 919,361 | `b0049bc6420715b1e3010f43d95745dca227c5aa60357d1d89a1bdcb06287312` |
| `common/supplemental/plurals.xml` | 26,048 | `d701d8b461afd2ba5eb21f9c1d645c8a661de225596afcf0f492ee36c69d727d` |
| `common/supplemental/ordinals.xml` | 10,751 | `129bf4aa6f41d47931bf908ebaa261ec0b73b768f1fe3be90c06ab11fb49880a` |
| `common/supplemental/numberingSystems.xml` | 11,834 | `c5b9b208c6fe7bd3ce4e1c6cbb8f3337480aca620c9cf703ef3b6c74d4258c16` |
| `common/supplemental/metaZones.xml` | 95,076 | `3c77661c4af8067b5c384590e8032b040bf3725b24cc51428b8eac01f0f69545` |
| `LICENSE` | 2,036 | `780ed0d1e595f6bb3e7cad757ea147315596b96e75d6a271ae95e882185c8aa7` |

The selected total was 4,658,373 bytes, below both per-member and aggregate
bounds. XML was parsed with DTD processing ignored, the external resolver set
to `null`, entity expansion disabled and an 8 MiB document limit.

Technical validation passed:

- locale identity is exact for `root`, `en`, `ru`, `lv`, `et` and `lt`;
- all selected locale files have the expected `ldml` root;
- all selected supplemental files have the expected `supplementalData` root;
- likely-subtag mappings exist for `en`, `ru`, `lv`, `et` and `lt`;
- cardinal plural rules cover all five language locales;
- 25 ordinal rule sets are present;
- 12 parent-locale records and one default-content record establish the
  selected inheritance metadata boundary;
- `LV`, `EE` and `LT` currency histories each contain `EUR`;
- 97 unique numbering-system identifiers are present;
- metazone data contains `Europe/Riga`, `Europe/Tallinn` and
  `Europe/Vilnius`.

The first local diagnostic looked for `parentLocale` in the wrong selected
module. The corrected validator found those records in
`supplementalData.xml`, retained default-content evidence from
`supplementalMetadata.xml`, made no network request and did not change raw
evidence. Corrected P4/P5 diagnostic SHA-256:
`cb8e587130f62dc669b636571c040b66b1a7a73a139450ae8deca37784f56662`.

## 7. Dimension-by-dimension status

| Dimension | CLDR 48.2 result |
|---|---|
| official HTTPS release path | Pass |
| exact archive identity and local hashes | Pass |
| provider checksum | Pass through byte-identical official `core.zip`; filename-specific anomaly retained |
| archive structural safety | Pass |
| bounded parser compatibility | Pass for selected XML evidence only |
| locale/inheritance/Baltic semantic checks | Pass for selected scope |
| license evidence captured | Pass as evidence only |
| allowed-use/legal disposition | **Pending** |
| immutable UTS #35 48.2 pin | **Pending** |
| production parser/fixtures | **Absent** |
| repository ingestion | **Unauthorized** |
| source status | **Pending** |

## 8. Temporary evidence locations

The following directories remain outside the repository pending an explicit
cleanup or retention decision:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-b-cldr-discovery-02c9fba7-a7d1-4091-9b63-3a55ebc1da71
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-b-cldr-metadata-1d30fca0-3dff-4713-aef4-6f7dd85d78dc
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-b-cldr-p3p6-6710ec1e-9d14-410c-a534-41c6f179af10
```

This record does not authorize deletion. Raw evidence must not be committed by
default.

## 9. Retained gates

- Unicode license/notice obligations and allowed-use questions for storage,
  parsing, derived output, redistribution, modification and commercial/mobile
  use remain Pending;
- an immutable CLDR 48.2 UTS #35 specification pin remains Pending;
- no qualified Legal or independent Security/Privacy review is claimed;
- `SRC-UNICODE-CLDR` remains Pending and not
  `eligible_for_slice_review`;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- provider selection, production parser, fixtures, schema, IAM/runtime,
  Firebase, repository ingestion, deployment, activation, push and merge
  remain unauthorized.

## 10. Next bounded work

1. obtain an applicable qualified terms/use disposition for the exact Unicode
   license hash and bundled archive `LICENSE` hash;
2. pin the CLDR 48.2-applicable UTS #35 specification evidence or formally
   document why the generic page is sufficient;
3. retain or delete each temporary evidence root only through an explicit
   cleanup decision;
4. if terms/use permits, prepare one separately Approved parser/fixture slice
   consuming only the exact fields required by Recharge;
5. keep the provider filename-checksum anomaly visible in all downstream
   source and parser reviews;
6. do not place raw CLDR data in the repository before source acceptance and
   the storage/notice obligations are settled.

## 11. Acceptance criteria

1. **BCK20-OD02-EXT-B-P6-EV-AC-01:** the record identifies the exact CLDR release, source URIs, artifact length and local hashes.
2. **BCK20-OD02-EXT-B-P6-EV-AC-02:** raw Unicode/CLDR content remains outside the repository.
3. **BCK20-OD02-EXT-B-P6-EV-AC-03:** discovery, license, specification, artifact, checksum, inventory and selected validation evidence remain distinct.
4. **BCK20-OD02-EXT-B-P6-EV-AC-04:** the candidate-link correction supersedes only the local discovery false negative and does not rewrite source evidence.
5. **BCK20-OD02-EXT-B-P6-EV-AC-05:** the filename-specific checksum mismatch is explicit and is not reported as a direct match.
6. **BCK20-OD02-EXT-B-P6-EV-AC-06:** official `core.zip` byte identity and its provider checksum are recorded as reconciliation evidence.
7. **BCK20-OD02-EXT-B-P6-EV-AC-07:** archive safety and selected XML validation are independently recorded.
8. **BCK20-OD02-EXT-B-P6-EV-AC-08:** DTD/external-entity controls and size bounds are explicit.
9. **BCK20-OD02-EXT-B-P6-EV-AC-09:** Unicode license capture is not presented as allowed-use or Legal approval.
10. **BCK20-OD02-EXT-B-P6-EV-AC-10:** the generic UTS #35 page is not presented as an immutable CLDR 48.2 specification pin.
11. **BCK20-OD02-EXT-B-P6-EV-AC-11:** `SRC-UNICODE-CLDR` remains Pending and not eligible for slice review.
12. **BCK20-OD02-EXT-B-P6-EV-AC-12:** production parser, fixtures, ingestion, runtime, Firebase, deployment, activation, push and merge remain absent or unauthorized.
13. **BCK20-OD02-EXT-B-P6-EV-AC-13:** temporary evidence deletion is not authorized by this record.
