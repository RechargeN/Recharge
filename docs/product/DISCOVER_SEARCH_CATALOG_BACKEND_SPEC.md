# Recharge Backend — Discover, Search and Catalog Specification

- ID: **BCK-08**
- Version: **0.2**
- Date: **2026-08-25**
- Spec status: **Review — documentation only; approval pending**
- Runtime status: **Absent**
- Accountable owner: **Discover owner**
- Review owners: **Content, API, Security/Privacy, Mobile, Reference Data,
  Booking, Integrations, Media, Product, Operations and Legal/Privacy**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.37](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-08-PRE v0.2](BACKEND_DISCOVER_CATALOG_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

### v0.2 — 2026-08-25

- completed the 22/22 BCK-02 design contract and promoted it to Review;
- defined one rebuildable catalog with typed Feed, Map, Search and Details
  projections sharing query fingerprint, projection revision and freshness;
- separated internal/provider/public availability writers and protected honest
  degraded states;
- recorded 60 AC and ten owner decisions without authorizing OD-01/03,
  contracts, Firebase, indexes, migration, runtime or production data.

### v0.1 — 2026-08-25

- created the documentation-only target from canonical docs and current
  local/mock Discover audit;
- recorded object-kind, query-version, universal-card, ranking, Money,
  availability, seed/provenance and pagination debt.

## 1. Verdict and status semantics

BCK-08 defines the target read-side Catalog/Search authority for Recharge. It
is ready for cross-owner Review, not Approval or implementation. Runtime is
Absent.

Review does not select a search vendor, accept OD-01/03, promote BCK-07 to
Approved, authorize mock seeds, provision Firebase/GCP, create an index or add
a mobile remote adapter. Documentation, projection build, deployment and
production enablement remain distinct statuses.

## 2. Parents, priority and reconciliation

Priority:

1. Accepted ADR;
2. Approved source-domain/product contract;
3. Approved BCK architecture/coordination decision;
4. this BCK-08 projection contract;
5. Proposed provider architecture and current runtime evidence.

Inputs:

- [ADR 0013](../adr/0013-domain-policy-baseline.md): geo + freshness baseline,
  zero-result, privacy, cache, feature flags and audit;
- [BCK-03](BACKEND_API_CONTRACT_STANDARD.md): query, cursor, typed errors,
  revision/freshness and version behavior;
- [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md): public allowlist, privacy, age,
  abuse and retention controls;
- [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md): immutable published revision,
  visibility, publisher/provenance and tombstone source;
- [BCK-09](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md): internal availability
  authority, not Catalog mutation authority;
- [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md): versioned market/taxonomy/
  locale values and non-Accepted OD-10 proposal;
- [S2-DISC-02](S2_DISC_02_MAP_SPEC.md): local one-query map/list behavior;
- [Vision](VISION.md): distinct Search/Smart Search entry UX and shared applied
  query across results/map/feed/details.

[Firebase Architecture](../architecture/FIREBASE_ARCHITECTURE.md) is Proposed
input. Geohash/Firestore examples do not decide OD-01 or physical schema.

## 3. Outcome and non-goals

### 3.1 Outcome

One provider-neutral read platform that:

- consumes only authorized published source revisions;
- builds sanitized, immutable/revisioned public projections;
- supports literal Search, filters, geo, time-fit and deterministic ranking;
- keeps Feed, Map, Search and Details membership reconcilable;
- composes honest availability from separately owned sources;
- supports bounded pages, clustering, cache/freshness and zero-result guidance;
- rebuilds, verifies, activates and rolls back projection sets safely.

### 3.2 Non-goals

BCK-08 does not own:

- Content drafts/publication lifecycle or source correction;
- Booking/hold/inventory mutation or confirmation;
- provider integration, live-check or external booking truth;
- reviews/ratings source, Media bytes or reference datasets;
- Smart Search natural-language parsing or AI recommendations;
- saved-search/history sync in this baseline;
- personalized ranking/profiling without a separate privacy/data decision;
- UI/map renderer, Firebase provisioning or production search vendor choice.

## 4. Scope and surfaces

In scope:

- catalog ingestion/rebuild/current projection-set pointer;
- ten-type catalog identity and map eligibility;
- Feed, Map, Search, Details-card/details-family projections;
- applied `DiscoverQuery` normalization/fingerprint;
- geo/text/category/time/budget/people/duration/availability filters;
- deterministic ranking and stable pagination;
- availability composition and freshness/source disclosure;
- cache, stale/degraded/inconsistent states;
- deletion/hide/source-removal propagation;
- migration from mock/local projections and query v2.

Search and Smart Search remain different entry experiences. Literal Search
applies text semantics directly. Smart Search produces a reviewable normalized
query through its owning parser; only then does it enter BCK-08. BCK-08 never
silently reruns or changes the user's parsed intent.

Quick Plan is outside Create Hub/catalog. Unlisted content is not discoverable
and may be resolved only by an authorized explicit-ID path defined with BCK-07;
it never enters feed/map/search indexes.

## 5. Ownership and single writers

| Record/decision | Single writer | BCK-08 boundary |
|---|---|---|
| Published Content/current revision | BCK-07 | Consume source event/read model |
| Catalog projection set/items | BCK-08 | Full rebuild/query/tombstone authority |
| Search documents/index | BCK-08 | Derived and rebuildable |
| Internal availability | BCK-09 | Consume source revision/freshness |
| Provider availability | BCK-16 | Consume source/provenance/freshness |
| Public composed availability | BCK-08 | Read-only display/filter projection |
| Reviews/rating aggregate | BCK-12 | Consume published aggregate |
| Media generation/delivery | BCK-14 | Consume safe ready projection |
| Market/taxonomy/localization | BCK-20 | Pin dataset revisions |
| Search/geo infrastructure | OD-01 + BCK-05 | BCK-08 remains semantic owner |

No source domain writes the catalog/index directly. Denormalization never
becomes a second source aggregate. BCK-08 cannot confirm inventory, grant
visibility, change publication state or repair Content.

## 6. Query and consistency contract

### 6.1 Applied query

```text
DiscoverQueryV1 {
  market/serviceArea
  literalText?
  type/category/subcategory refs
  local-time intent + UTC interval + IANA zone where applicable
  groupSize?
  Money range?
  duration/mood/accessibility facets?
  geo center/radius or applied area?
  openNow/onlyAvailable?
  sortMode
  referenceDatasetRevision
  contractVersion
}
```

Normalization is deterministic and produces `queryFingerprint`. The fingerprint
binds contract/environment/visibility scope and canonical membership fields; it
is opaque, non-reversible in the wire contract and is not treated as anonymous
or reused as a cross-user tracking identifier. Raw literal text or precise geo
is not logged merely because a fingerprint exists. Entry screen, draft map
camera and analytics source are not result-membership fields. Camera movement
changes only draft area; `Search this area` creates a new applied query/
fingerprint.

Unknown/newer query version or unknown required enum/facet returns typed
unsupported result. It is never partially mapped to a default query.

### 6.2 Query response identity

Every surface response includes:

```text
queryFingerprint
projectionSetRevision
surfaceProjectionRevision
rankingPolicyRevision
referenceDatasetRevision
generatedAt
freshness: fresh | stale | unknown
sourceLag?
cursor?
```

`projectionSetRevision` identifies one compatible activated catalog snapshot;
surface revisions may differ only under a declared compatibility manifest.

### 6.3 Feed/Map/Search parity

- Feed is the ordered eligible result set for the applied query.
- Map is the map-eligible subset of that same result set, further limited by
  viewport for rendering and optionally represented by clusters.
- Every Map leaf ID must be Feed-eligible under the same query/snapshot; it may
  be outside the currently loaded Feed page but is reachable through its cursor.
- A Feed item without safe map representation carries `notMappable` reason
  such as `onlineOnly`, `noPublicGeo` or `typePolicy`.
- Search adds declared text-match semantics but uses the same filters and
  activated projection set.
- Details resolves the exact catalog object/revision selected from results;
  stale/missing/current-revision change is explicit.

Mismatch returns `inconsistentProjection` or `stale`; it is never hidden by
merging two independently refreshed sources on the client.

## 7. Projection model

### 7.1 CatalogObjectRef

```text
CatalogObjectRef { contentTypeId, contentId }
```

Identity is type + immutable ID, never title/category/coordinates. Supported
type IDs match BCK-07's ten-type registry; Quick Plan is excluded. Unknown type
stays opaque/unsupported and never defaults to Activity/Event.

### 7.2 CatalogItemProjection

Common allowlist:

- object ref and published content revision;
- public localized title/summary and content language;
- publisher public snapshot ref;
- category/type/market/reference revisions;
- public Media projection ref;
- visibility-safe time/geo/price summary where applicable;
- availability/rating summary refs with source/freshness;
- map eligibility/exclusion reason;
- projection/schema/ranking policy revisions.

Optional fields are governed by per-type projection schema. A universal object
does not require fake coordinates, fake start time, zero price or dummy
capacity merely to enter Feed.

### 7.3 Surface projections

- `FeedCardProjection`: ordered card fields and ranking explanation class;
- `MapLeafProjection`: safe point/geometry summary, cluster key and card ref;
- `MapClusterProjection`: count/bounds/category summary, never a content object;
- `SearchDocumentProjection`: normalized searchable text/facets/languages;
- `DetailsProjection`: typed/family projection, not authoring entity;
- `AvailabilityProjection`: source/status/freshness/confidence/handoff;
- `CatalogTombstone`: source revision, reason class and effective time.

Details families and exact ten-type mapping require BCK08-OD-04. A type without
an accepted public projection remains disabled rather than being forced into a
point-oriented generic model.

## 8. Catalog build and lifecycle

```text
BCK-07 published/visibility/provenance fact
  -> validate source revision and public allowlist
  -> build immutable type/surface projections
  -> verify references, geo, language, media and availability inputs
  -> write inactive projection set/revision
  -> parity/completeness/privacy checks
  -> atomically activate compatible set pointer
  -> serve Feed/Map/Search/Details
```

Hide/delete/source-removal facts take priority and create tombstones/purge
tasks. Catalog lag never re-authorizes hidden content. Unlisted/private drafts
never enter the pipeline.

Rebuild is double-buffered or equivalently isolated. Partial projection sets
are not queryable. Activation and rollback are explicit pointer changes with
audit; source Content remains authoritative throughout.

## 9. Queries and internal commands

### 9.1 Public/read queries

| Query | Result |
|---|---|
| `discover.queryFeed` | stable ordered page + parity metadata |
| `discover.queryMap` | leaf/cluster page + parity metadata |
| `discover.search` | text-matched ordered page + parity metadata |
| `discover.getDetails` | exact typed projection/current-revision state |
| `discover.getAvailability` | composed source/freshness projection |
| `discover.getZeroResultSuggestions` | explicit deterministic relaxation candidates |

### 9.2 Trusted/internal commands

| Command | Result |
|---|---|
| `catalog.consumeContentFact` | applied/deduped/deferred/poison receipt |
| `catalog.buildProjectionSet` | inactive revision/build report |
| `catalog.activateProjectionSet` | active pointer result |
| `catalog.rollbackProjectionSet` | previous compatible pointer result |
| `catalog.applyTombstone` | hidden/deleted purge receipt |
| `catalog.reconcileProjection` | repair proposal/result under owned rules |

Clients cannot invoke projection build/activation or write ranking/availability.

## 10. Filtering, ranking and pagination

### 10.1 Filtering

All filters have declared server candidate plan, exact evaluator, supported
type matrix, reference revision, maximum candidate/page cost and typed
unsupported behavior. Geo-index candidates are exact-distance filtered before
membership. Time/opening/recurrence evaluation uses UTC plus IANA semantics.

User-visible unlimited radius means no explicit small-radius filter within an
approved service area; it never means an unbounded global scan. Market/service
area, candidate and page limits remain enforced.

`onlyAvailable` includes only an honestly `available` state meeting requested
group/time semantics. Unknown, stale beyond threshold, unsupported and provider
unavailable are excluded with explanation, never treated as available.

### 10.2 Ranking

Baseline is deterministic geo + ranking freshness under ADR 0013. The ranking
signal is named `contentTemporalRelevance` (for example occurrence proximity or
published-content recency under the Accepted policy) and is strictly separate
from `projectionDataFreshness`/availability source age. Exact features,
normalization, weights, temporal meaning, tie-break and evaluation thresholds
are BCK08-OD-05. Stale data never becomes fresh or available because its content
is temporally relevant. Stable final tie-break includes immutable object ref.

No undisclosed paid placement, popularity feedback loop, protected attribute or
personal profiling enters ranking. Future personalization requires an explicit
privacy/data decision and does not silently change baseline results.

### 10.3 Pagination

Cursor is opaque and binds query fingerprint, projection-set revision, ranking
policy revision, last stable sort key and expiry. A cursor cannot be reused with
a different query/snapshot. Within one snapshot, pagination has no silent
duplicate/skip; an expired/superseded cursor returns typed restart/stale state.

## 11. Availability composition and failures

### 11.1 Source model

| Source | Writer | Meaning |
|---|---|---|
| Content schedule/opening summary | BCK-07/type source | Planned/opening configuration, not inventory confirmation |
| Internal availability | BCK-09 | Ledger-derived authoritative internal inventory read |
| Provider availability | BCK-16 | External source with provenance/freshness/live-check policy |
| Public composed availability | BCK-08 | Display/filter projection only |

Projection carries source type, source revision, observed/generated time,
fresh-until, status, confidence and required live-check/handoff. Status is typed:
`available`, `limited`, `soldOut`, `closed`, `unavailable`, `unknown`, `stale`,
`unsupported`.

BCK-08 never turns cached availability into Booking confirmation. Booking
mutation rechecks BCK-09 authority; external handoff follows BCK-16.

### 11.2 Failures

```text
invalidQuery
unsupportedQueryVersion
unsupportedFilter
unsupportedContentType
marketDisabled
serviceAreaUnavailable
projectionUnavailable
inconsistentProjection
staleProjection
cursorInvalid
cursorExpired
referenceRevisionUnsupported
availabilityUnknown
searchUnavailable
rateLimited
permissionDenied
notFound
temporarilyUnavailable
cancelled
```

## 12. Contract versions and compatibility

- query, catalog item, each surface and availability have explicit versions;
- DTOs/search documents/provider SDK types are not domain entities;
- newer unsupported versions fail closed and remain locally preservable;
- additive fields default only when semantic absence is safe;
- generated artifacts are never manually edited;
- non-Booking Discover schemas/codegen need BCK08-OD-03/API approval;
- active projection manifest declares compatible surface versions;
- minimum client/deprecation window precedes removal;
- unknown enum/type never maps to Activity/Event/none success.

## 13. Authorization, visibility and revocation

Public query reads only published public projections. Authentication alone does
not expose private/unlisted/protected fields. Explicit-ID unlisted resolution,
if enabled, validates BCK-07 visibility/authorization and uses a separate
non-indexed path.

Find People and age-sensitive projection/query paths remain disabled until
applicable OD-11/Legal/Privacy policy is Accepted and enforced upstream and in
projection allowlists. Exact/private/live user location is never catalog data.

Hide/delete/restriction/consent withdrawal/source removal blocks new public
serving at authority and propagates tombstone/cache invalidation. Stale cache
cannot grant visibility. App Check is an abuse signal, not access authority.

## 14. Persistence, indexes and atomicity

Logical stores:

- inactive/active projection-set manifests;
- immutable catalog items and surface projections;
- search documents/index adapter state;
- availability projections;
- tombstones and source checkpoints;
- idempotency/dedupe/outbox-consumer state;
- build/parity/reconciliation reports.

Physical engine/schema/indexes wait for OD-01. A versioned query catalog lists
every supported query shape, required index, candidate/page bound, exact
post-filter, sort/cursor shape, measured cost and fallback.

Projection-set activation atomically changes one compatible manifest pointer.
If multiple physical systems cannot share a transaction, readiness manifest
and verification prevent partial serving. Tombstone safety may bypass normal
batch cadence to stop serving promptly, then reconcile all surfaces.

## 15. IDs, time, geo, Money and reference data

- catalog identity is `{contentTypeId, contentId}` plus source revision;
- relation IDs are immutable ULID/UUID; display names are never identity;
- authoritative times are UTC; local evaluation retains IANA timezone;
- query time uses server/current request semantics, not device clock as truth;
- geo uses validated latitude/longitude/geometry with accuracy/source policy;
- no fake coordinate is created for non-mappable content;
- exact distance follows candidate retrieval;
- Money uses integer minor units + ISO currency; M2 precedes remote filtering;
- category/market/language/currency pin BCK-20 revisions;
- OD-10 fallback/localized indexing is not assumed Accepted.

## 16. Idempotency, concurrency and rebuild safety

Read queries are side-effect free. Retry may use a fresh request ID; cursor
retains its original snapshot semantics. A new query after stale/expired cursor
gets a new fingerprint/snapshot.

Content fact consumption dedupes by stable event ID/source revision. Older
facts cannot overwrite newer projection/tombstone. Same idempotency key with a
different payload hash creates no build/activation mutation.

Only one build lease per target projection revision may activate. Competing
builds remain inactive. Activation checks expected active revision and complete
parity report. Rollback never changes BCK-07 source truth.

## 17. Cache, freshness and degraded states

Data freshness is per projection/source and visible where material. It is never
the ranking temporal-relevance score:

- catalog source revision and projection generated time;
- availability source observed/fresh-until;
- reference/ranking policy revision;
- query snapshot generated time and lag.

States include fresh, refreshing-with-cache, stale-usable, stale-blocking,
unknown, inconsistent, unsupported and unavailable. Exact thresholds are
BCK08-OD-08. `onlyAvailable` and safety/visibility gates fail closed.

Mobile cache is scoped by environment, market, query fingerprint, projection
set, account/visibility and schema. Public cached data may render with an honest
stale/offline label where policy permits. Tombstone/revocation wins. Map, Feed
and Search never silently combine different projection sets.

## 18. Migration and compatibility

Migration phases:

1. inventory mock/local items, queries, saved views, route sinks and details;
2. classify exact source authority, type, revision, provenance, media,
   reference, geo/time/Money and visibility;
3. never upload generated mock rows as production authority;
4. never map unknown kind to Activity or newer query to v2;
5. map only BCK-07 published IDs/revisions through explicit checkpoints;
6. introduce typed projection consumers behind BCK-18 flags;
7. run shadow read/parity without user-visible authority;
8. cut over query surfaces together or return typed mixed/inconsistent state;
9. preserve rollback to last compatible local/remote consumer without
   restoring mock authority in production.

Saved searches and Smart Search history remain local in this baseline. A future
sync decision must define privacy, retention, account deletion and encryption.

## 19. Outbox, replay and reconciliation

BCK-08 consumes BCK-07 publication/visibility/provenance facts through the
Accepted BCK-03/OD-09 envelope when available. It checkpoints, dedupes and
replays into inactive projections. Poison items do not block tombstones or make
partial sets active.

Reconciliation verifies:

- active catalog item matches BCK-07 current public revision;
- hidden/deleted/unlisted sources are absent from discovery;
- Feed/Map/Search/Details versions share compatible manifest;
- Map leaf IDs are Feed-eligible for the same query/snapshot;
- Media/reference/availability refs are compatible and fresh enough;
- index document count/hash and projection manifest agree;
- source/projection lag and purge tasks meet policy.

Repair rebuilds the owned projection from source; it never edits Content,
Booking or provider state.

## 20. Privacy, retention and Legal

Catalog is sanitized public/authorized derived data only. Projection allowlists
exclude private organizer contact, exact private meeting/location, identity
evidence, draft/moderation notes, access grants, raw provider payload and
private Media originals.

Query logs minimize literal text and precise location. Where telemetry is
needed, use bounded/rounded or classified values under consent/purpose policy;
do not retain raw free text/exact device origin by default. Search suggestions
must not leak private/unlisted/deleted titles.

Retention is separate for active/inactive projections, tombstones, query cache,
search index, availability, build reports, dedupe/checkpoints and logs. Derived
data does not gain indefinite retention. Source deletion/restriction propagates
to live, cache, index and backup/rebuild inputs; restore replays newer
tombstones before access.

## 21. Abuse, query safety and zero-result behavior

Controls:

- query shape allowlist and bounded text/filter length;
- per actor/device-risk/IP/market rate limits where lawful;
- service-area/candidate/page/geohash fan-out limits;
- expensive combination rejection or typed degradation;
- index/parser escaping and injection-safe rendering;
- no wildcard/global export query;
- App Check under BCK-04, never AuthZ;
- market/type/query/search/index kill switches.

Zero-result behavior returns explicit deterministic relaxation proposals such
as wider radius, budget or time. It never silently changes the applied query,
age/privacy filter or availability semantics. User action creates a new query
fingerprint.

## 22. Observability, SLO, quality and cost

Metrics:

- ingestion/build/activation/rebuild lag and failures;
- active item/type/market counts and tombstone purge lag;
- query latency, candidate/read/page count and cache outcome;
- text relevance/zero-result/relaxation outcome;
- geo fan-out/false positives/exact-filter count;
- Feed/Map/Search parity/inconsistency;
- availability source/status/staleness;
- index/storage/read/write/egress/worker cost;
- unsupported version/type/filter/client rates.

Quality evaluation uses versioned golden queries by market/language/type,
relevance judgments, geo/time/filter correctness and predeclared thresholds.
Numeric SLO/cost/read limits and rollout cohorts are BCK08-OD-10. Current local
UI checkpoints are not production backend SLO evidence.

Logs exclude raw private payload, exact device location, signed Media URL,
tokens and unnecessary literal query text. Degradation never exposes private/
unreviewed data or labels unknown availability as available.

## 23. Flags, rollout and rollback

Server flags are independent by environment, market, surface, type and query:

- catalog ingestion/build/activation;
- literal Search and each filter family;
- Feed/Map/Details projections;
- availability composition/source;
- age-sensitive types;
- shadow reads and remote cutover.

Rollout: documentation → contract/golden fixtures → unit → emulator → stage
synthetic → shadow parity → staff cohort → bounded Latvia cohort → owner
expansion. EE/LT activate independently with their datasets/languages.

Rollback switches to the previous compatible projection manifest or disables a
surface, preserves tombstones/privacy, stops new ingestion as scoped and never
restores mock authority, hidden data or an incompatible index. Mobile fallback
must be honest local/demo/non-production state, not silent production truth.

## 24. Dependency and delivery gates

Before Approval:

- BCK-03/04/07/20 dependency compatibility and owner review;
- OD-01 and OD-03 Accepted with evidence;
- applicable OD-10/OD-11 disposition for enabled language/age scope;
- all ten BCK08 decisions resolved or formally deferred with controls;
- typed public projection contract for every enabled type;
- Booking/Provider/Media/Rating source handoffs reconciled where enabled;
- Security/Privacy/Legal, Product quality and Operations verdicts.

Before executable work:

- separate Approved bounded R3/G3 slice and exact files/resources;
- accepted API/schema workflow and golden fixtures;
- BCK-07 runtime source and BCK-18 mobile adapter gates;
- M2 Money before price/budget remote query;
- G1/R1/R2 prerequisites and no production mock authority;
- no new boundary suppression or an approved debt change.

Before production:

- projection/index/query catalog, security and privacy evidence;
- relevance/geo/filter/parity/load/cost thresholds pass;
- availability/stale wording and source fallbacks tested;
- deletion/tombstone/restore and rollback drills pass;
- Latvia market/legal/owner activation verdict; EE/LT separate.

## 25. Conditional exact file map

No file below is authorized by this Review. A future Approved slice may create:

```text
packages/api_contracts/discover/               # after BCK08-OD-03
  schemas/
  fixtures/

apps/backend/src/discover/
  domain/
    discover_query.*
    catalog_object_ref.*
    catalog_projection.*
    availability_projection.*
    projection_manifest.*
    ranking_policy.*
  application/
    query_feed.*
    query_map.*
    search_catalog.*
    get_details.*
    build_projection_set.*
    activate_projection_set.*
    apply_catalog_tombstone.*
    reconcile_catalog.*
  infrastructure/
    catalog_repository.*
    search_index_gateway.*
    content_source_gateway.*
    availability_source_gateways.*
    reference_data_gateway.*
  presentation/
    discover_handlers.*
  workers/
    catalog_projector.*
    catalog_rebuilder.*
    catalog_reconciler.*

apps/backend/test/discover/
  unit/
  contract/
  integration/
  security/
  relevance/
  load/
  recovery/

apps/mobile/lib/features/discover/data/remote/ # after BCK-18/R3 approval
apps/mobile/test/features/discover/**
```

Physical index/infra files wait for OD-01 and BCK-05 exact resource plan.
Generated files follow the accepted workflow and are never hand-edited.

## 26. Test and evidence matrix

| Layer | Required evidence |
|---|---|
| Domain/unit | query normalization/fingerprint, type/map eligibility, ranking/ties, availability states |
| Contract | versions, cursors, typed errors, unknown/newer fail-closed |
| Projection | ten-type allowlists, source revision, immutable build/manifest/tombstone |
| Feed/Map/Search | same query/snapshot membership, cluster/viewport/page reconciliation |
| Details | exact object/revision, family schema, no draft/private leakage |
| Geo/time | bounds, exact distance, timezone/DST, unlimited service-area cap |
| Search/relevance | LV/RU/EN golden queries, typos/languages per accepted policy, zero results |
| Availability | Booking/provider/content precedence, stale/unknown/onlyAvailable behavior |
| Security/privacy | private/unlisted/deleted denial, precise location/query-log minimization |
| Migration | unknown kind/query, mock exclusion, route sink, shadow parity/rollback |
| Load/cost | fan-out, reads/pages/index/worker/egress and predeclared guardrails |
| Recovery | rebuild from BCK-07, tombstone replay, previous manifest rollback |

Documentation validation is not emulator/stage/production evidence. Emulator
does not prove provider limits, relevance, cost, latency or Legal compliance.

## 27. Definition of Ready

For Approval review:

1. 22/22 coverage remains current;
2. OD-01/03 have dated Accepted verdicts;
3. ten BCK08 decisions have evidence;
4. BCK-07 source and BCK-20 reference contracts are reconciled;
5. enabled types have typed surface projection and golden fixtures;
6. dependency owners sign parity/availability/privacy boundaries.

For executable slice:

1. BCK-08 Approved;
2. exact market/surface/type/query/file/resource scope approved;
3. API/query/projection/cursor/failure fixtures frozen;
4. G/R prerequisites and mock exclusion satisfied;
5. quality, cost, rollback and kill-switch thresholds predeclared;
6. no unresolved provider/policy is implemented by assumption.

## 28. Definition of Done

Runtime is Done only when:

- catalog ingestion, immutable projection sets, queries and rebuild exist in
  owned layers;
- every enabled type/surface/query passes contract and source parity;
- Feed/Map/Search/Details consistency and typed degraded states are measured;
- availability, privacy, security, migration, recovery and load gates pass;
- observability, runbooks, on-call and cost controls are active;
- status/evidence distinguishes built, deployed and Enabled.

Production Enabled additionally requires owner-approved market cohort,
Legal/Privacy, relevance/cost and incident/recovery verdicts.

## 29. Acceptance criteria

1. **BCK-08-AC-01:** BCK-07 remains published Content/current-revision source.
2. **BCK-08-AC-02:** BCK-08 is sole writer of catalog/search surface projections.
3. **BCK-08-AC-03:** Source domains never write index/catalog directly.
4. **BCK-08-AC-04:** Catalog identity is type plus immutable content ID.
5. **BCK-08-AC-05:** Quick Plan never enters catalog/discovery.
6. **BCK-08-AC-06:** Unknown type never defaults to Activity/Event.
7. **BCK-08-AC-07:** Missing type projection disables that type.
8. **BCK-08-AC-08:** Universal point-card is not the ten-type contract.
9. **BCK-08-AC-09:** Fake geo/time/price/capacity is never synthesized.
10. **BCK-08-AC-10:** Query normalization produces deterministic fingerprint.
11. **BCK-08-AC-11:** Draft map camera does not change applied query.
12. **BCK-08-AC-12:** Search-this-area creates a new applied query.
13. **BCK-08-AC-13:** Newer unsupported query fails closed.
14. **BCK-08-AC-14:** Feed/Map/Search carry compatible projection-set revision.
15. **BCK-08-AC-15:** Surfaces carry query/ranking/reference/freshness metadata.
16. **BCK-08-AC-16:** Every Map leaf is Feed-eligible under same query/snapshot.
17. **BCK-08-AC-17:** Viewport/clustering/pagination differences are explicit.
18. **BCK-08-AC-18:** Cluster is never treated as a content object.
19. **BCK-08-AC-19:** Feed-only non-mappable item has typed exclusion reason.
20. **BCK-08-AC-20:** Projection mismatch is typed stale/inconsistent, not success.
21. **BCK-08-AC-21:** Search text adds a criterion, not an independent source.
22. **BCK-08-AC-22:** Details resolves exact object and published revision.
23. **BCK-08-AC-23:** Unlisted/private content never enters discovery indexes.
24. **BCK-08-AC-24:** Hidden/deleted/source-removed tombstone wins over cache/replay.
25. **BCK-08-AC-25:** Partial projection set is never queryable.
26. **BCK-08-AC-26:** Activation checks complete compatible manifest atomically.
27. **BCK-08-AC-27:** Rollback never changes BCK-07 source truth.
28. **BCK-08-AC-28:** Cursor binds query/snapshot/ranking and stable sort key.
29. **BCK-08-AC-29:** Cursor cannot be reused with different query/snapshot.
30. **BCK-08-AC-30:** Snapshot pagination has no silent duplicate/skip.
31. **BCK-08-AC-31:** Geo candidates receive exact distance filtering.
32. **BCK-08-AC-32:** Unlimited UI radius remains service-area/query bounded.
33. **BCK-08-AC-33:** Time evaluation preserves UTC/IANA semantics.
34. **BCK-08-AC-34:** Money remote filtering waits for M2 minor units.
35. **BCK-08-AC-35:** Ranking policy is versioned and deterministic.
36. **BCK-08-AC-36:** Stable tie-break uses immutable object identity.
37. **BCK-08-AC-37:** Undisclosed paid/personal/protected ranking is forbidden.
38. **BCK-08-AC-38:** Internal availability remains BCK-09-owned.
39. **BCK-08-AC-39:** Provider availability remains BCK-16-owned.
40. **BCK-08-AC-40:** Public availability is read-only, sourced and freshness-labelled.
41. **BCK-08-AC-41:** Cached public availability never confirms Booking.
42. **BCK-08-AC-42:** `onlyAvailable` excludes unknown/stale/unsupported results.
43. **BCK-08-AC-43:** Zero-result relaxation never silently changes query.
44. **BCK-08-AC-44:** OD-01 blocks engine/index runtime.
45. **BCK-08-AC-45:** OD-03 blocks production mock/seed population.
46. **BCK-08-AC-46:** Proposed Firebase layout never becomes Accepted implicitly.
47. **BCK-08-AC-47:** Public projection uses explicit privacy allowlist.
48. **BCK-08-AC-48:** Exact private/live user location is never catalog data.
49. **BCK-08-AC-49:** Query logs minimize free text and precise location.
50. **BCK-08-AC-50:** Restore/rebuild replays newer tombstones before access.
51. **BCK-08-AC-51:** Mobile cache is scope/revision/freshness aware.
52. **BCK-08-AC-52:** Map/Feed/Search never silently mix projection sets.
53. **BCK-08-AC-53:** Numeric SLO/quality/cost claims require measured evidence.
54. **BCK-08-AC-54:** Degradation never exposes private or labels unknown available.
55. **BCK-08-AC-55:** Risky surface/type/query has server kill switch.
56. **BCK-08-AC-56:** Rollback preserves tombstones and honest client state.
57. **BCK-08-AC-57:** No new boundary suppression is introduced by this revision.
58. **BCK-08-AC-58:** Documentation/emulator/stage/production evidence stay distinct.
59. **BCK-08-AC-59:** Executable files require a separate Approved slice.
60. **BCK-08-AC-60:** Runtime stays Absent until measured evidence exists.

## 30. Explicit unimplemented list

- Discover/query/catalog/search schemas, fixtures and generated clients;
- authoritative catalog/projection manifests and persistence;
- search/geo engine, indexes, query catalog and physical schema;
- catalog ingestion/rebuild/activation/tombstone workers;
- ten-type typed Feed/Map/Search/Details projections;
- BCK-07 Content runtime source;
- BCK-09 internal and BCK-16 provider availability runtime;
- BCK-14 Media and BCK-12 rating integration;
- accepted OD-01/03 and applicable OD-10/11 decisions;
- mobile remote adapters, cursor/cache/cutover and migration;
- Money minor-unit price/budget query;
- relevance golden datasets, numeric SLO/cost/read budgets;
- Firebase/GCP resources, deployment, production data or traffic.

## 31. Final statement

BCK-08 v0.2 is a production-grade Review design for one coherent Discover
catalog. It makes projection consistency and availability honesty testable
while keeping every unapproved engine, source and runtime surface disabled.
