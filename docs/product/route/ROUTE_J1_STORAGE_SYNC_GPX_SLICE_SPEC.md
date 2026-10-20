# J1 — Route storage, sync and safe GPX import/export

Date: 2026-10-20. Status: **Review — bounded local/Emulator scope**, owner
acceptance pending. Base: `codex/recharge-integration` `b23cb99` (after I3).
Evidence: `docs/verification/ROUTE_J1_VERIFICATION.md`.

Task authorization covers bounded local/Emulator implementation only: no push,
deploy, production data, Storage upload, publication or provider integration.
BCK-11 v0.3.1 stays Draft; this slice fixes the bounded decisions it leaves to
"an approved slice" (§16, §32) as proposals with fail-closed defaults.

## 1. Verified starting point

- Product contract: `ROUTE_BUILDER_SPEC.md` v3.2; backend design: BCK-11 v0.3.1
  (`ROUTE_GPX_BACKEND_SPEC.md`). Route stays a continuous track; no Scenario
  fields, planning stops, publication or external routing in this slice.
- Mobile already has one streaming GPX parser (`RouteGpxInspector`, `xml`
  event parser), an importer, an exporter, the transfer controller (preview →
  apply → export), `ApplyRouteGpxImport` (atomic draft apply), the recording
  privacy trim (`ProcessRouteRecordingUseCase`, endpoint radius ≤ 2000 m) and
  local Create persistence. No backend Route module existed.
- Reused patterns: I1 owner-only CAS/receipt/tombstone service, the I1/I2
  encrypted per-installation/owner journal, the Emulator Identity session
  transport, the Emulator group runner and the default-off test entry guard.

Defects found in the existing flow and fixed here: the importer re-parsed the
file with a DOM after inspection (second parse path); a confirmed `direct` gap
was spliced into the imported polyline and labelled `importedGpx`; consecutive
duplicates were dropped silently; the file picker read the whole file before
checking size; compressed bytes and XInclude were not rejected explicitly;
text outside captured fields was unbounded; exported gaps failed instead of
becoming separate `<trkseg>`.

## 2. Canonical geometry contract (`wgs84-e7-dm-v1`)

| Item | Rule |
|---|---|
| Coordinates | WGS84, integers in 1e-7°: `latE7` ∈ [−900 000 000, 900 000 000], `lonE7` ∈ [−1 800 000 000, 1 800 000 000] |
| Elevation | optional per point, integer decimetres ∈ [−5 000, 90 000] (−500…9 000 m) |
| Time | none. Timestamps never enter the canonical model, sync, storage or export |
| Segments | `order` 0…n−1, unique and contiguous; each ≥ 2 points; point order is preserved exactly |
| Continuity | segments `i`, `i+1` are connected iff `toAnchorId(i) == fromAnchorId(i+1)`; otherwise it is an explicit gap. Nothing is ever inserted to close it |
| Anchors | unique IDs; every referenced anchor exists; `turningAnchorId` references an anchor |
| Source kind | closed enum. Accepted for storage: `importedGpx`, `recordedGps`, `freehand`, `intentionalDirect`, `fallbackDirect`. `routed`/`generated` are provider geometry and fail closed with `license_blocked` (BCK-11 §22) |
| Wire encoding | per segment: encoded polyline at precision 7 (lat/lon) and a non-delta signed varint stream for elevation with an "absent" sentinel. The server decodes, range-checks and requires re-encoding to reproduce the input byte-for-byte |

Explicit, verifiable transformations (nothing else is applied):

1. `strip-timestamps`, `strip-metadata` — mandatory on GPX import (existing rule);
   the canonical schema has no field that could carry them.
2. `drop-consecutive-duplicates` — import only, counted in a `gpx_duplicates_removed`
   source issue; the server verifies imported segments contain no consecutive duplicates.
3. `direct-gap-bridge` — only for a gap the user confirmed as direct: a separate
   2-point `intentionalDirect` segment between the two imported parts; the
   server verifies the count and that each bridge joins the neighbouring parts.
4. `quantize-e7-dm` — at the sync boundary (≤ 0.5e-7° and ≤ 0.05 m). Re-encoding
   a decoded canonical Route is an identity.

No simplification, smoothing, re-ordering, interpolation or gap joining.

## 3. Data classes

| Data | Stored | Exported |
|---|---|---|
| Full owner geometry, anchors, waypoints with notes | server, owner-only; encrypted mobile journal | owner full export from the local draft only |
| Privacy trim decision | server, owner-only | never (only its effect) |
| Trimmed geometry + trimmed waypoints + trimmed summary | derived on read | trimmed export |
| Provenance (origin, import source token, declared transformations, parser version) | server, owner-only | never |
| GPX file bytes, local path, file name, author, creator, extensions, timestamps, bounds | never | never |
| Command receipts | server: hash + compact result (no geometry) | never |

The import source token is `gpx-<first 16 hex of SHA-256>` of the file (the
existing provenance ID); it is a pseudonymous lineage token, not the file.

## 4. Limits and where each one is enforced

GPX input (the single parser `RouteGpxInspector`; values are the existing
`RouteGpxImportConfig` defaults plus three new bounds):

| Limit | Value | Enforced |
|---|---|---|
| Raw bytes | 5 MiB (5 242 880) | picker: `XFile.length()` before any read, then a bounded stream read that stops at limit+1; source store `register`; inspector before decoding |
| Archive/compressed bytes | rejected (gzip, zip, bzip2, xz, zstd, 7z, rar magic) | inspector, on the first bytes before decoding |
| Encoding | strict UTF-8 (BOM allowed); first non-space byte `<` | before parsing |
| DTD, `ENTITY`, `SYSTEM`, `PUBLIC` | rejected | byte pre-scan before parsing and `XmlDoctypeEvent` |
| Processing instructions (except the declaration), XInclude namespace/elements | rejected | parse events |
| XML depth | 64 | each start element |
| XML events (elements, text, …) | 1 000 000 | each event |
| Attributes per element | 32 (new) | each start element |
| Attribute value | 2 048 chars (new) | each start element |
| Any text/CDATA node, captured or not | 10 000 chars (now global) | each text event, before buffering |
| Tracks + routes | 1 000 | candidate start |
| Track segments + routes | 5 000 | segment start |
| Source points (`trkpt`, `rtept`, `wpt`) | 200 000 | point start, before the point is allocated |
| Waypoints | 10 000 | waypoint start |
| Numbers | decimal lexical form only (no exponent, `NaN`, `Infinity`, hex); finite; lat/lon/elevation ranges | point start / `ele` end |
| GPX version | 1.0, 1.1 | root element |

Canonical Route (mobile encoder before enqueue and server before any read or
transaction; values reuse the existing `demoRouteCreateConfig` policy):

| Limit | Value |
|---|---|
| Canonical `route` JSON | 200 KiB (204 800 bytes), checked first |
| Total points | 10 000 (counter aborts decoding at 10 001) |
| Segments / anchors / waypoints | 120 / 100 / 250 |
| Title | 200 chars; waypoint title 120; description, note, safety note 1 000 |
| Tokens (`typeId`, profile id, `sourceId`) | `[A-Za-z0-9._:-]{1,64}` |
| Privacy trim | integer metres 0…2 000 each end (existing recording maximum) |
| Mobile journal | 2 MiB per installation/owner (same as I2); only re-fetchable cache is evicted |
| Owner list page | 50 |

Callable payloads stay below the existing 256 KiB mobile response budget.

## 5. Provenance

The server derives provenance from the command family, never from a client flag:

- `import` creates the Route; every non-bridge segment is stamped `importedGpx`,
  bridges `intentionalDirect`; the origin is `gpxImport` and the import source
  token is registered on the Route.
- `save` may carry `importedGpx` only for segments whose `sourceId` is a token
  registered by an import of the same Route; a segment ID already stored keeps
  its source kind and parent. `recordedGps` is accepted as `deviceDeclared`.
- No J1 field can express a verified activity or a verified recording;
  `verification` is always `unverified`. Imported GPX never becomes `recordedGps`.

## 6. Privacy trim (`endpoint-radius-v1`)

Same semantics as the existing recording trim, now persisted per Route and
applied by the server when it builds the trimmed view:

- remove the longest prefix of points closer than `startMeters` to the first
  point and the longest suffix closer than `endMeters` to the last point,
  across segment and gap boundaries; no point is interpolated;
- a segment left with < 2 points is dropped; surviving segments keep their order
  and explicit gaps; anchors are not part of the trimmed view;
- waypoints closer than the radius to the original start or end are removed;
  elevation stays only on surviving points; no timestamps exist;
- summary (points, segments, gaps, distance, ascent/descent, min/max elevation)
  is recomputed from the trimmed geometry only; no bounds are returned;
- if fewer than 2 points survive, the trimmed view fails with
  `privacy_trim_empty`; setting such a trim is refused for the current
  geometry; a later edit that makes it empty blocks export, never falls back;
- points that re-enter a radius after the trimmed prefix stay and are reported
  as `reenteredStart`/`reenteredEnd` warnings for the author;
- the trimmed view carries `revision` and `variantHash`; a query with a stale
  `expectedRevision` fails; preview and export are built from the same view object.

The full geometry stays owner-only; the trimmed path is a separate query that
reads the pinned revision and returns only the derived allowlist.

## 7. Persistence, sync and conflicts

Collections (server-only, client access denied): `routes/{owner}:{routeId}`
(current revision, status, geometry, trim, provenance, summary) and
`routeCommandReceipts/{owner}:{sha256(key)}` (hash + compact result). One
Firestore transaction checks session, flag, receipt and CAS and writes Route
plus receipt together: no partially imported or partially saved Route.

Commands carry `ownerContext`, `idempotencyKey`, `routeId` and
`expectedRevision`; every command increments the single Route revision.

| Case | Rule |
|---|---|
| edit/edit | compare-and-set; first commit wins, the second gets `revision_conflict`; no merge by index |
| trim/edit, edit/trim | same CAS; `save` cannot carry trim fields, so a save never removes a trim; only an explicit `setPrivacyTrim` changes it |
| edit/delete | delete wins in both orders (I1 precedent); the tombstone drops geometry, trim and provenance; later `save`/`import`/`setPrivacyTrim` get `deleted` |
| repeated key, same payload | the stored compact receipt is returned; no state change |
| repeated key, changed payload | `idempotency_conflict` |
| import onto an existing/deleted ID | `id_collision` / `deleted` |
| old client or replayed command | stale revision → conflict; replay → historical receipt; the client re-reads current state |

Mobile `RouteSyncClient` persists each immutable command in the encrypted
journal before dispatch, drains strictly in order, checks the session owner
before each dispatch and after each answer, keeps a rejected command with its
payload in `conflicts` for an explicit `keepServer` or `reapplyLocal` (a new
intent on the current revision), keeps the queue on transport and
`unauthenticated` failures, and never sends one owner's queue under another.
Local `loc_*` IDs are mapped to permanent ULIDs once, in the same journal write
as the command; the mapping is reused on every later save, and mappings of IDs
the draft no longer uses are dropped (queued and refused commands already carry
their encoded payloads), so editing history does not grow the journal.

## 8. Commands and queries

`routeCommandV1`: `import`, `save`, `setPrivacyTrim`, `delete`.
`routeQueryV1`: `get` (owner entry or `null`), `list` (owner, paginated, no
geometry), `trimmedView` (pinned to `expectedRevision`). Typed failures:
`request_invalid`, `unauthenticated`, `owner_changed`, `feature_disabled`,
`revision_conflict`, `idempotency_conflict`, `id_collision`, `deleted`,
`not_found`, `payload_too_large`, `point_limit_exceeded`, `invalid_geometry`,
`license_blocked`, `provenance_unverified`, `privacy_trim_invalid`,
`privacy_trim_empty`. Default-off flag `route.owner_sync`; mobile entry
`RECHARGE_TEST_ROUTE_SYNC` with the same four guard conditions as other entries.

## 9. Files, rollback and limitations

Backend: `modules/route/{route_contract,route_geometry,firestore_route_service}.ts`,
callables in `index.ts`, rules/manifest/allowlists, unit and Emulator tests,
group `route-j1`. Mobile: inspector/importer/exporter/picker hardening,
`ApplyRouteGpxImport` bridges, canonical codec, `RouteSyncClient` behind the
domain port `RouteSyncRepository`, test-entry composition, unit and backend-local tests.

Rollback: turn the flag off (no new commands or reads); local drafts and
journals stay; no automatic upload, deletion or migration.

Not in J1: revision history (only current revision + tombstone), GPS journal
upload, Storage/Media for GPX bytes, publication/Discover projection, routed
or generated geometry persistence, non-geometry Route details (conditions,
quality, media), collaboration, production retention/DSR decisions.

## 10. Required evidence

The ten checks of the J1 task (valid GPX round trip, hostile XML, limit
boundaries, coordinates/versions, escaping/allowlist, trim, two-client
conflicts, recovery, account isolation, real Flutter adapters against
Emulator, no Quick Plan/Scenario/network side effects) plus launcher
self-tests, fixture cleanup, the full Emulator suite in one session, Flutter
analyze/test, affected backend gates, boundary and diff checks.
