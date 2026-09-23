# Recharge Backend — Route & GPX Specification

- ID: **BCK-11**
- Version: **0.3.1**
- Date: **2026-09-21**
- Spec status: **Draft — Present; owner and cross-boundary review pending**
- Runtime status: **Absent — local Route/GPS/GPX behavior is compatibility input only**
- Accountable owner: **Route owner**
- Coordination baseline: [BCK-02 v2.4.82](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D4 / R7**

## 0. Changelog

### v0.3.1 — 2026-09-21

- normalized Route publication/moderation enum values to the BCK-03
  lowerCamelCase rule;
- preserved lifecycle meaning, writers, Draft status and all runtime gates.

### v0.3 — 2026-09-21

- completed the Stage 5 Route/GPX/recording/Media operational boundary;
- fixed protected source geometry, privacy-trimmed published revision and GPX
  provenance without introducing Scenario semantics;
- added conflict, processing receipt, deletion and rollback requirements while
  preserving every Storage/provider/runtime gate.

### v0.2 — 2026-09-20

- added the Stage 2 normalized Route/GPX entity inventory;
- separated Route semantic authority from Media blob storage and Content/
  Discover publication projections;
- normalized privacy, lifecycle, migration, rollback, flags and evidence.

### v0.1 — 2026-09-20

- created the first canonical backend contract for Route, geometry and GPX;
- separated protected source geometry from publishable route revisions;
- defined secure GPX import/export, media handoff, sync, conflicts, provenance,
  privacy trimming and rollback;
- preserved Route independence from Scenario and provider-neutral geometry rules.

## 1. Verdict and status semantics

This file defines BCK-11 design requirements. It is not proof of a deployed
Route backend, cloud storage, provider rights, production GPS processing or
public activation. `Draft` remains fail-closed until owner, Security/Privacy,
Media, Mobile and Operations boundaries are accepted.

Current mobile Route creation, GPX inspection/export and GPS recording are
valuable implementation evidence but cannot establish server authorization,
remote persistence, licensing, retention, collaboration or production SLOs.

## 2. Parents, priority and reconciliation

BCK-11 inherits without silently overriding:

1. Accepted ADRs and the frozen
   [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md);
2. [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) architecture and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md) coordination;
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md),
   [BCK-14](MEDIA_STORAGE_BACKEND_SPEC.md),
   [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md) and
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md);
4. the [Route Builder](ROUTE_BUILDER_SPEC.md) product contract and approved
   Route slice specifications;
5. current code, fixtures and local/mock behavior.

Once Approved, BCK-11 is the owning-domain specification for Route, but it
still cannot override an Accepted ADR or an Accepted cross-cutting policy.

Inherited rules include immutable typed IDs, server-resolved actor context,
BCK-07 publication, BCK-14 media ownership, BCK-18 mobile sync/import,
BCK-20 reference versions and BCK-04 privacy/security controls.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-11 defines authoritative ownership for a continuous Route track created by
anchors/routing, freehand, GPS recording, GPX import or accepted generation.
It provides a complete design contract for source revisions, derived geometry,
waypoints, provenance, publication, import/export, synchronization and privacy.

### 3.2 Non-goals

BCK-11 does not own:

- Scenario days/stops/logistics or Quick Plan;
- catalog/publication lifecycle outside the typed BCK-07 handoff;
- media blobs/transforms, user identity, sanctions or notifications;
- provider availability, Booking, payment or live navigation;
- raw mobile sensor collection implementation;
- map/routing/elevation provider selection or license acceptance;
- Firebase resources, deployment or activation.

## 4. Scope

### 4.1 In scope

- Route create/save/archive and immutable revision history;
- source/normalized/display/public geometry distinction;
- anchors, ordered segments, waypoints, profiles and provenance;
- secure GPX 1.0/1.1 import and bounded export;
- protected GPS/GPX source retention and privacy trimming;
- BCK-14 media references for waypoint content;
- optimistic concurrency, idempotency and deterministic conflicts;
- BCK-07 publication and BCK-08 projection handoff;
- offline/import migration, multi-market paths and rollback.

### 4.2 Disabled until later gates

- production remote save, sync and publication;
- server-side routing/elevation/generation providers;
- live navigation, tracking or location sharing;
- background upload of raw GPS journals;
- import of unsupported XML/extensions without explicit contract;
- public geometry where privacy, license or moderation policy is unresolved.

## 5. Aggregate ownership and single writers

| Record/projection | Authoritative writer | Consumers |
|---|---|---|
| `RouteRecord` / current revision | Route command service | Owner/mobile/workers |
| `RouteRevision` | Route command service | Owner/publication/export |
| `RouteSourceArtifact` metadata | Route import/source service | Route processing/audit |
| Protected source object/blob | BCK-14-controlled storage path | Authorized Route processor |
| `RouteProcessingReceipt` | Route processing service | Owner/support/audit |
| Public Route content/revision | BCK-07 | BCK-08/mobile |
| Waypoint media | BCK-14 | Route stores approved media IDs only |
| User/Page/capabilities | BCK-06 | BCK-11 consumer |
| Report/sanction/appeal | BCK-22 | Typed enforcement consumer |
| Scenario reference to Route | BCK-10 | Typed consumer; no geometry ownership |

Clients and staff tools never write source or public records directly. Derived
statistics and display geometry never become authority over the accepted
source revision without a new explicit Route command.

## 6. Actors, capabilities and revocation

| Actor | Allowed | Denied |
|---|---|---|
| Authenticated owner | Own draft/save/import/export/archive | Foreign protected Route |
| Authorized editor | Edit accepted scope if future collaboration is approved | Ownership/access/publish authority |
| Verified Creator/Page member | Request publication with capability | Bypass validation/moderation |
| Public reader | Read accepted public projection/export | Raw GPS/source/private waypoint data |
| Route processor | Bounded transform for exact revision | Arbitrary source mutation |
| BCK-14 worker | Media/blob lifecycle | Route business decisions |
| Support/Admin | Audited BCK-19 command | Direct geometry/blob mutation |

Minimum logical capabilities are `create_route`, `edit_own_route`,
`export_own_route`, `publish_route`, `manage_page_content` where applicable and
registered staff repair capabilities. Revocation is checked at command time;
cached capability or Page membership never extends server authority.

## 7. Data classification and projection boundary

| Data | Class | Public behavior |
|---|---|---|
| Raw GPS timestamps/accuracy/source journal | Sensitive private | Never public |
| Raw imported GPX and extensions | Private/restricted | Never public by default |
| Private endpoints/trim decisions | Sensitive private | Never public |
| Draft geometry/waypoint notes | Private | Owner/editor only |
| Published privacy-trimmed geometry | Public | Accepted revision only |
| Public stats/waypoints/attribution | Public derived | Same policy/revision as geometry |
| Processing/idempotency/audit records | Operational | Service/audit only |

Public output excludes raw timestamps, accuracy samples, device metadata,
source filenames/paths, upload credentials, EXIF/GPS media metadata and private
trimmed sections.

## 8. Canonical domain model

```text
RouteRecord {
  routeId, ownerUserId, publisherRef?, status, visibility,
  currentRevisionId, publishedRevisionId?, revision,
  createdAtUtc, updatedAtUtc, archivedAtUtc?
}

RouteRevision {
  routeRevisionId, routeId, revisionNumber, schemaVersion,
  title, description?, movementProfileRef, marketRefs[], locale,
  sourceKind, anchors[], segments[], waypoints[], geometryPolicyRef,
  sourceArtifactRefs[], statistics, qualityIssues[], attributionRefs[],
  contentHash, createdByUserId, createdAtUtc
}

RouteSegment {
  segmentId, order, sourceKind, provenanceRef,
  encodedGeometry, geometryEncoding, pointCount,
  distanceM, elevationSummary?, durationModel, qualityFlags[]
}

RouteWaypoint {
  waypointId, order, coordinate, distanceFromStartM,
  typeRef, title?, note?, mediaIds[], visibilityClass
}

RouteSourceArtifact {
  sourceArtifactId, routeId, ownerUserId, kind,
  blobRef?, sourceHash, parserVersion?, status,
  retentionClass, createdAtUtc, deletedAtUtc?
}

RouteProcessingReceipt {
  receiptId, routeId, inputRevisionId, operation,
  policyVersions[], outputRevisionId?, warnings[], createdAtUtc
}
```

Source kinds are closed/versioned: `routed`, `generated`, `freehand`,
`recordedGps`, `importedGpx`, `intentionalDirect`, `fallbackDirect`. A segment's
provenance cannot be collapsed into an untyped boolean.

## 9. Geometry, topology and statistics invariants

1. Route is a continuous track, not an ordered collection of independent stops.
2. Ordered segments form a deterministic topology or expose typed gaps.
3. Source, normalized, display and public geometry are distinguishable.
4. Display simplification never rewrites protected source geometry.
5. Published geometry, stats, waypoint distances and export share one accepted
   geometry policy/version.
6. Intentional direct and fallback direct segments remain distinguishable.
7. Distance/elevation/duration are derived from the accepted revision and
   calculation model; manual duration carries reason and seconds together.
8. Route revisions never contain Scenario fields or Quick Plan state.

## 10. Lifecycle

Route content lifecycle, moderation outcome and processing state are separate.
The persisted content lifecycle follows the shared content contract:

```text
draft -> pendingReview -> published -> archived
  ^           |              |
  |           v              v
  +-------- rejected       hidden

deleted — soft-delete terminal state until retention cleanup
```

`rejected`/`changesRequested` are moderation outcomes, not alternative content
aggregates. Source processing has its own `queued | running | succeeded |
failed | cancelled` state and never auto-publishes. Failed processing preserves
the last complete revision and a typed receipt. Editing a published Route
creates a new draft revision; BCK-07 atomically switches the public pointer only
after acceptance.

## 11. GPX import contract

Only bounded GPX 1.0/1.1 XML is considered. Import must:

1. validate size, signature/encoding and decompression policy before parsing;
2. disable DTD, external entities, XInclude and network resolution;
3. bound elements, points, nesting, text, extensions, tracks and waypoints;
4. parse in a resource-bounded mode and reject malformed/non-finite coordinates;
5. inventory tracks/segments/routes/waypoints before user selection;
6. preserve source hash, parser version and accepted selections;
7. expose gaps and normalization decisions for explicit confirmation;
8. sanitize names/notes and reject executable/remote attachment semantics;
9. create ordered `importedGpx` segments plus provenance;
10. commit one complete revision or nothing.

Unknown extensions are ignored only under an explicit allow/ignore policy and
are never copied blindly into public or exported output.

## 12. GPS source and privacy trimming

Mobile GPS collection remains governed by platform permissions and local secure
storage. Upload is separate, explicit and resumable; no background journal is
uploaded merely because the user opened Create or synchronized another object.

Server intake validates actor, source hash, chunk/order manifest, limits and
declared policy. Processing removes or segregates timestamps/accuracy/device
metadata, detects gaps/anomalies and offers bounded trim decisions. Start/end
privacy trimming is recorded as policy/version and never destroys the owner's
source before retention/deletion rules permit it.

Live tracking and sharing are outside BCK-11.

## 13. GPX export contract

Export is generated from one authorized immutable Route revision. Draft export
is owner-only; public export uses the exact published privacy-trimmed geometry.
The exporter emits bounded GPX, safe text, declared namespaces, compatible
coordinates/elevation and approved waypoints. It excludes internal IDs where
not required, private notes, raw timestamps, device metadata, source paths,
access data and unapproved extensions.

Export receipt identifies route/revision, policy, schema, checksum and time.
Repeated export of unchanged canonical input is deterministic except for
explicit metadata fields. Authorization is rechecked before each export.

## 14. Commands, queries and typed outcomes

Commands:

- `CreateRoute`, `SaveRouteRevision`, `ArchiveRoute`;
- `RegisterRouteSource`, `ProcessRouteSource`, `ApplyRouteProcessingResult`;
- `RequestGpxImport`, `ConfirmGpxImport`, `CancelGpxImport`;
- `RequestRouteExport`;
- `RequestRoutePublication`, `WithdrawRoutePublication`;
- bounded typed repair/reprocess commands through BCK-19.

Queries:

- owner Route list and authorized current/history reads;
- import inventory/processing receipt/status;
- export status/download authorization;
- public Route projection through BCK-08/BCK-07, not source storage.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, archived,
revision_conflict, idempotency_conflict, processing_in_progress,
source_missing, source_hash_mismatch, source_unsupported,
payload_too_large, point_limit_exceeded, malformed_gpx,
unsafe_xml, invalid_geometry, topology_gap, policy_blocked,
license_blocked, media_not_ready, publication_blocked,
market_disabled, rate_limited, temporarily_unavailable
```

## 15. Contract versions and compatibility

Every mutation declares contract/schema version, operation ID and expected
revision. Route geometry encoding, calculation, parser, normalization, privacy
and export policies are versioned independently and pinned in receipts.

Unknown source kinds, encodings, policy versions or enum values fail closed.
Breaking changes require new version, fixtures, migration and minimum-client
evidence. The backend preserves readable historical revisions or returns a
typed unsupported-version state; it never guesses geometry semantics.

## 16. Persistence, indexes and transaction boundaries

Source blobs, Route records, immutable revisions, processing receipts, export
receipts, idempotency/audit and public projections are separate. BCK-14 owns
blob lifecycle and signed delivery; BCK-11 owns Route meaning and references.

Required atomic boundaries:

- record pointer plus immutable revision;
- accepted processing result plus receipt/current pointer;
- archive state plus outbox/audit;
- publication request plus exact source revision reference.

Large geometry is not hidden in an unbounded Firestore document. Exact physical
representation, chunking and limits require an approved slice with measured
emulator/load evidence.

## 17. IDs, coordinates, time and reference data

- permanent IDs are server-issued immutable ULID/UUID-style IDs;
- segment/waypoint IDs remain stable inside revision evolution where semantics
  are preserved, but identity is never inferred from order/title/coordinate;
- coordinates use an explicit WGS84 contract and validated finite ranges;
- instants are UTC; any local-date behavior carries IANA timezone ID;
- profile/surface/difficulty/market/locale refs use versioned BCK-20 values;
- media links are BCK-14 IDs, never paths or URLs as identity;
- no floating point Money is introduced by Route cost metadata.

## 18. Idempotency, concurrency, retries and partial failure

Create/save/import-confirm/export/publication commands are idempotent by actor,
family and target. Same key with changed canonical payload fails. Optimistic
revision checks prevent silent overwrite of geometry and waypoint order.

Processing jobs use input hash/revision and lease/fencing token; stale output
cannot replace a newer draft. Chunk retries dedupe by manifest/chunk hash.
Import confirmation commits one revision or none. Export failure does not alter
Route state. Publication worker retries reconcile exact revision and event ID.

## 19. Offline, cache and degraded states

Encrypted local drafts/source journals remain available under BCK-18. A local
save is never labelled server-synced. Reconnect offers explicit upload/rebase,
replace or copy-as-new when source revision diverged; geometry is never merged
point-by-point without an approved deterministic user-visible algorithm.

Routing/elevation/provider outage does not block manual/freehand/GPS/GPX local
work or safe reads/exports. Missing provider data is labelled unavailable or
stale. Publication fails closed if license, privacy or source provenance cannot
be verified.

## 20. Migration and local-to-cloud import

Import requires explicit owner consent, dry-run, source hash, limits and durable
local/server ID mapping. Existing local Route IDs with `loc_*` are temporary;
remote authoritative create returns a permanent ID. Duplicate detection is
advisory and user-visible, never name-based auto-merge.

Migration preserves source kind, segment provenance, gaps, manual duration,
quality issues and privacy decisions. Unsupported/ambiguous legacy fields
produce typed blockers or explicit omissions in a receipt. Rollback stops new
imports while preserving evidence and local originals.

## 21. Events, outbox and replay

After Accepted OD-09 and runtime authorization, minimized events may include:

- `route.created`, `route.revisionSaved`, `route.archived`;
- `route.sourceRegistered`, `route.processingCompleted`;
- `route.importConfirmed`, `route.exportCompleted`;
- `route.publicationRequested`.

Events carry IDs/revisions/status codes, not geometry, coordinates, GPX, notes
or signed URLs. Outbox commits with source state. Consumers dedupe by event ID,
verify source revision and tolerate replay/out-of-order delivery. Async effects
remain disabled before OD-09 acceptance.

## 22. Privacy, retention, DSR and Legal/license gates

Routes can disclose home/work, habits, health-related activity and precise
movement. Privacy review covers lawful purpose, minimization, access, public
trim policy, source/public separation, DSR, backups and incident response.

DSR export distinguishes original source (when eligible), authored revision,
public revision, media and operational evidence. Erasure/restriction follows
BCK-04 exceptions and reconciles public projection/media. Retention periods for
raw GPS, GPX, processing/export receipts and published revisions require named
qualified review before production persistence.

Provider-produced geometry/elevation/tiles cannot be stored, exported or
republished without accepted license/attribution evidence. A provider response
is not permission. Unresolved rights block only the affected adapter/source.

## 23. Abuse, rate limits and security controls

Bound actor/device/account/source-size/risk controls cover upload, parse,
processing, export and publication. Defenses include XML hardening, content
sniffing, decompression/resource limits, malware policy for containers,
checksum verification, signed URL scoping, SSRF prohibition and worker
sandboxing. App Check supplements but never replaces AuthN/AuthZ.

Abusive public Routes, unsafe links and malicious uploads route to BCK-22/BCK-19
through typed cases. Moderators never download raw source outside an audited,
time-bounded BCK-19 access scope.

## 24. Observability, SLO, analytics and cost

Operational metrics cover mutation latency, conflicts, source sizes, parser
outcomes, processing duration, queue lag, point/segment counts, export failures,
projection lag, abuse blocks and storage growth. Logs contain bounded codes and
IDs only; geometry, coordinates, names, notes and signed URLs are prohibited.

Product analytics flows only through BCK-21. BCK-05 accepts numeric SLOs,
alerts and budgets before persistent runtime. Cost controls bound upload bytes,
point counts, processing CPU/memory/time, revision count, export frequency,
storage class and public projection size.

## 25. Flags, rollout, rollback and emergency disable

Independent default-off flags cover remote save, source upload, GPX import,
processing family, export, publication, provider routing/elevation/generation
and each market. Emergency controls can stop upload/parse/export/publication
without deleting existing Routes or blocking safe owner reads.

Rollback pins the last supported policy/parser, stops new work, drains or
quarantines jobs and preserves receipts. A bad derived/public revision is
withdrawn by pointer/typed lifecycle; source history is not silently rewritten.

## 26. Conditional implementation file map

No physical work is authorized by this document alone. An Approved slice may
create:

```text
packages/api_contracts/schemas/route/
packages/api_contracts/fixtures/route/
apps/backend/functions/src/modules/route/domain/
apps/backend/functions/src/modules/route/application/
apps/backend/functions/src/modules/route/data/
apps/backend/functions/src/modules/route/transport/
apps/backend/functions/src/modules/route/workers/
apps/backend/functions/test/contract/route/
apps/backend/functions/test/emulator/route/
apps/mobile/lib/features/create/data/remote/route/
```

BCK-14 owns blob/media adapters. Provider integrations use BCK-16 adapters and
must not be embedded into the Route domain. Generated files are generator-only.

## 27. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Domain | topology, provenance, calculations, lifecycle, visibility |
| Property | geometry round-trip, distance/stats consistency, stable ordering |
| Parser | hostile XML, limits, malformed data, extensions, multi-track/gaps |
| Export | deterministic bounded GPX, privacy allowlist, authorization |
| Authorization | owner/editor/publisher/staff/public and revocation |
| Concurrency | stale revision, stale processor, idempotency and chunk retry |
| Privacy | source/public separation, trim, logs, signed URL and DSR |
| Emulator | transactions, indexes, Rules/IAM, blob refs, outbox/projection |
| Migration | legacy fixtures, ID map, provenance and rollback |
| Resilience | worker crash/replay, provider outage, poison source/quarantine |
| Baltic | LV/EE/LT/cross-border geometry, timezone/market/visibility |
| Load/cost | max size/points/segments/revisions/export abuse |
| End-to-end | GPS/GPX/freehand save, publish, view, export and withdraw |

Unrun, timed-out or environment-blocked checks are `Inconclusive`.

## 28. Dependency and delivery gates

Approval requires applicable BCK-03/04/06/07/14/18/20 boundaries, accepted
Route owner decisions, Security/Privacy, Mobile, Media and Operations review.
Runtime requires R7 entry plus an exact Approved implementation slice.

Provider adapters additionally require BCK-16/vendor/license/cost approval.
Public UGC requires BCK-22/OD-06 where applicable. Persistent precise-location
processing requires qualified Privacy/Legal disposition and BCK-04 retention.

## 29. Definition of Ready

BCK-11 is ready for owner review when:

- source/public geometry ownership and Route/Scenario separation are accepted;
- source formats, data classes and provider/license blockers are inventoried;
- Security/Privacy, Media, Mobile and Operations reviewers are named;
- every unresolved numeric/policy decision has owner and fail-closed default;
- test/evidence mapping covers hostile input and precise-location risk.

## 30. Definition of Done

BCK-11 becomes `Approved` only after current attributable verdicts, resolved
blocking decisions, accepted contract/file boundaries, traceable AC and atomic
BCK-01/BCK-02/LAUNCH_STATUS reconciliation. Runtime Done remains separate and
requires code, green gates, measured limits, rollback proof and activation.

## 31. Acceptance criteria

1. **BCK-11-AC-01:** Route remains separate from Scenario and Quick Plan.
2. **BCK-11-AC-02:** Route represents one continuous ordered track.
3. **BCK-11-AC-03:** Scenario stores only a bounded Route reference snapshot.
4. **BCK-11-AC-04:** Source, display and public geometry are distinguishable.
5. **BCK-11-AC-05:** Display simplification never rewrites source geometry.
6. **BCK-11-AC-06:** Every segment retains typed source and provenance.
7. **BCK-11-AC-07:** Intentional and fallback direct segments remain distinct.
8. **BCK-11-AC-08:** Topology gaps are explicit and user-resolved.
9. **BCK-11-AC-09:** Published geometry/stats/export use one policy revision.
10. **BCK-11-AC-10:** Published revision is immutable.
11. **BCK-11-AC-11:** Server actor/capability is checked for each command.
12. **BCK-11-AC-12:** Cached Page/Creator state grants no server authority.
13. **BCK-11-AC-13:** Staff repair uses BCK-19 registered commands.
14. **BCK-11-AC-14:** Public reads never expose raw GPS/GPX/private fields.
15. **BCK-11-AC-15:** Waypoint media uses BCK-14 IDs only.
16. **BCK-11-AC-16:** Route data never stores upload credentials or paths.
17. **BCK-11-AC-17:** GPX XML disables DTD/entities/network resolution.
18. **BCK-11-AC-18:** GPX parsing enforces resource and structural limits.
19. **BCK-11-AC-19:** Import inventories content before user confirmation.
20. **BCK-11-AC-20:** Unknown extensions are never copied blindly.
21. **BCK-11-AC-21:** Import commits one complete revision or none.
22. **BCK-11-AC-22:** GPS upload is explicit and independent of normal sync.
23. **BCK-11-AC-23:** Raw GPS timestamps/device metadata are not public.
24. **BCK-11-AC-24:** Privacy trim policy/version is recorded.
25. **BCK-11-AC-25:** Live tracking/sharing is outside this contract.
26. **BCK-11-AC-26:** Export uses one authorized immutable revision.
27. **BCK-11-AC-27:** Public export matches published privacy-trimmed geometry.
28. **BCK-11-AC-28:** Export excludes private/internal metadata.
29. **BCK-11-AC-29:** Export receipt records revision/policy/checksum.
30. **BCK-11-AC-30:** Contract and geometry policies are versioned explicitly.
31. **BCK-11-AC-31:** Unknown encoding/policy/source kind fails closed.
32. **BCK-11-AC-32:** Breaking changes require migration/client evidence.
33. **BCK-11-AC-33:** Large geometry uses an explicitly tested representation.
34. **BCK-11-AC-34:** Source/blob and Route business ownership stay separate.
35. **BCK-11-AC-35:** Save commits revision/current pointer atomically.
36. **BCK-11-AC-36:** Stale processor output cannot replace a newer draft.
37. **BCK-11-AC-37:** Idempotency hash mismatch is a typed conflict.
38. **BCK-11-AC-38:** Export failure never mutates Route state.
39. **BCK-11-AC-39:** Offline save is not labelled server-synced.
40. **BCK-11-AC-40:** Geometry conflicts require explicit user resolution.
41. **BCK-11-AC-41:** Provider outage preserves manual/local safe paths.
42. **BCK-11-AC-42:** Publication fails closed on rights/privacy uncertainty.
43. **BCK-11-AC-43:** Import uses explicit consent, dry-run and ID mapping.
44. **BCK-11-AC-44:** Names/coordinates never become identity.
45. **BCK-11-AC-45:** Migration preserves provenance/gaps/manual duration.
46. **BCK-11-AC-46:** Outbox is atomic and payload is geometry-free.
47. **BCK-11-AC-47:** Replay/dedupe uses event and source revision.
48. **BCK-11-AC-48:** Async effects remain disabled before OD-09.
49. **BCK-11-AC-49:** Coordinates and time/reference semantics are explicit.
50. **BCK-11-AC-50:** Provider storage/export requires license evidence.
51. **BCK-11-AC-51:** Retention is accepted before precise data persistence.
52. **BCK-11-AC-52:** DSR reconciles source, revisions, media and projections.
53. **BCK-11-AC-53:** App Check never replaces authorization/security controls.
54. **BCK-11-AC-54:** Upload/parser/export have layered abuse limits.
55. **BCK-11-AC-55:** Logs/analytics exclude geometry and precise locations.
56. **BCK-11-AC-56:** Processing/storage/export have measured cost budgets.
57. **BCK-11-AC-57:** Risky capabilities and markets have default-off flags.
58. **BCK-11-AC-58:** Emergency disable preserves safe owner access.
59. **BCK-11-AC-59:** LV/EE/LT cross-border fixtures test visibility/policy.
60. **BCK-11-AC-60:** Documentation acceptance claims no runtime/activation.

## 32. Explicit unimplemented list and owner decisions

Unimplemented:

- shared API schemas, fixtures and generated clients;
- backend Route persistence, source storage, processors and exports;
- Rules/IAM, indexes, queues, outbox and public projection;
- mobile remote adapter/import migration;
- provider routing/elevation/generation;
- production retention, SLO, load, DR and activation evidence.

Required decisions:

| Decision | Owner | Fail-closed default | Gate |
|---|---|---|---|
| Physical geometry/chunk/blob representation | Route + Data | remote save disabled | Runtime slice |
| Raw GPS/GPX retention and DSR exceptions | Privacy/Legal | no production upload | Persistent stage |
| Privacy trim policy and public precision | Privacy + Product | publication disabled | Public cohort |
| Parser/upload/point/revision limits | Security + Operations | conservative reject | R7 |
| Routing/elevation provider rights | Integrations + Legal | adapter disabled | Provider slice |
| GPX extension allow/ignore list | Route + Security | ignore/reject unknown | Import slice |
| Cross-market publication policy | Product/Market + Legal | affected market hidden | Activation |

## 33. Final statement

BCK-11 establishes a provider-neutral, privacy-preserving Route backend design
where source artifacts, authored revisions and published geometry remain
traceable but distinct. It does not authorize Firebase, providers, source
uploads, deployment or production publication.

## 34. Stage 2 normalized Route and GPX entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| Route | Route / Route command handler | owner/editor view and publication handoff | routeId; never Scenario/Quick Plan ID |
| RouteRevision | Route / revision handler | preview, readiness and BCK-07 handoff | immutable routeRevisionId + source revision/hash |
| TrackGeometry | Route / geometry handler | map/elevation/POI projections | geometryId + routeRevisionId + coordinate-system/precision metadata |
| GpxSourceRecord | Route / GPX source-record handler; Media writes the separate blob | safe inspection/import audit | sourceRecordId + mediaAssetId + checksum/provenance; blob is not Route authority |
| RoutePoi | Route / aggregate command handler | Route details/map projection | poiId + distance/anchor reference; catalog link by object ID |
| RecordingImportMapping | Route / explicit import/apply command | owner audit and BCK-18 migration | mappingId + local source ID + permanent route/revision ID |

Routes move draft → validated → revisioned → publication-ready/archived;
source inspection never auto-applies geometry. Unsafe GPX, silent track rewrite,
cross-owner import and Route↔Scenario mutation are forbidden. Import/apply/
publish commands use content hash/idempotency and expected revision; route
revision creation is atomic, while Media finalize and publication use typed
handoffs. Location/track data classification, access, retention/deletion and
privacy trim follow BCK-04. Audit stores IDs/checksums/decisions, not raw hidden
track; telemetry is privacy-bounded. Migration maps local IDs and preserves raw
provenance; rollback selects a prior compatible revision or disables
publication. Import/recording/publication/provider flags fail closed. Evidence
covers hostile GPX, checksum, precision/privacy, concurrency, owner isolation,
migration, projection rebuild and rollback.

## 35. Stage 5 Route, GPX, recording and Media contract

### 35.1 Source and projection boundaries

| Record | Writer | Boundary |
|---|---|---|
| Route draft/current revision | BCK-11 Route commands | Route-only anchors, segments, geometry, POI/elevation metadata; no Scenario/Quick Plan fields |
| GPX source bytes | BCK-14 Media | protected opaque mediaAssetId, generation, checksum and access policy |
| GPX inspection/import record | BCK-11 | provenance, parser/schema revision, warnings and explicit apply receipt |
| Recording source/import mapping | BCK-11 after explicit mobile import | local encrypted journal stays BCK-18/mobile concern until uploaded and accepted |
| Publishable Route revision | BCK-11 source plus BCK-07 publication handoff | privacy-trimmed immutable revision; BCK-08 owns public projection |

Media readiness never makes GPX or geometry a Route automatically. GPX
inspection is non-mutating; explicit apply creates a new Route revision after
owner, checksum, parser, coordinate, size and privacy validation.

### 35.2 Recording, import and conflicts

Mobile recording may contain pauses, gaps, uncertainty and privacy trims. The
backend never invents continuity or auto-resumes a session. Import pins source
generation/checksum, parser revision, coordinate reference, precision and
ordered decision set for gaps/trims. Hostile XML/archive features, external
entities, executable content and unsupported/newer structures fail closed.

Route commands use base revision and semantic content hash. Concurrent geometry
edits return a typed conflict; they never splice or replace tracks silently.
Manual reconciliation creates a new auditable revision with explicit segment/
gap decisions. Provider-derived elevation/POI remains a labelled BCK-16
observation and cannot overwrite authored geometry.

### 35.3 Publication, deletion and rollback

Only a validated privacy-trimmed Route revision may enter BCK-07 publication.
Protected raw track/recording/GPX is never copied into Discover. Media deletion
coordinates attachment/hold/generation receipts with BCK-14; Route tombstones
or replacement revisions remain BCK-11-owned. Rollback disables imports,
recording sync or publication, selects a compatible Route revision and revokes
public projections without making quarantined/deleted/raw geometry public.

### 35.4 Additional acceptance criteria

61. **BCK-11-AC-61:** Route contains continuous-track semantics only, never Scenario/Quick Plan fields.
62. **BCK-11-AC-62:** BCK-14 owns GPX/media bytes; BCK-11 owns Route meaning and revisions.
63. **BCK-11-AC-63:** Media readiness never auto-applies GPX or creates Route authority.
64. **BCK-11-AC-64:** GPX inspection is non-mutating and explicit apply creates a new revision.
65. **BCK-11-AC-65:** Import pins generation, checksum, parser, precision and gap/trim decisions.
66. **BCK-11-AC-66:** Unsafe XML/archive/external/executable/newer input fails closed.
67. **BCK-11-AC-67:** Recording gaps/pauses remain explicit and backend never invents continuity.
68. **BCK-11-AC-68:** Concurrent geometry edits return typed conflict without silent splice/overwrite.
69. **BCK-11-AC-69:** Reconciliation creates a new auditable Route revision.
70. **BCK-11-AC-70:** Provider observations cannot overwrite authored geometry.
71. **BCK-11-AC-71:** Publication uses only validated privacy-trimmed immutable revision.
72. **BCK-11-AC-72:** Protected raw track/recording/GPX never enters Discover projection.
73. **BCK-11-AC-73:** Media deletion uses attachment/hold/generation receipts across BCK-11/14.
74. **BCK-11-AC-74:** Rollback cannot expose quarantined, deleted or untrimmed geometry.
75. **BCK-11-AC-75:** v0.3.1 authorizes no Storage, parser, sync, provider or Firebase runtime.
