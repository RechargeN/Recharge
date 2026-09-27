# Recharge Backend — Content Publication Specification

- ID: **BCK-07**
- Version: **0.7**
- Date: **2026-09-27**
- Spec status: **Review — BCK07-LOCAL-01 approved as next local/test-only slice; production approval pending**
- Runtime status: **Content aggregate Absent; bounded Event outbox→Booking delivery/lifecycle handoff Present locally/Emulator-only**
- Accountable owner: **Content Platform owner**
- Review owners: **Identity, API, Security/Privacy, Mobile, Reference Data,
  Media, Discover, Event, Planning, Route, Trust & Safety, Operations and Legal**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.98](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-07-PRE v0.2](BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

### v0.7 — 2026-09-27

- reserves additive delegated-import command inputs for a future governed Event
  Ingestion module without granting it Content collection write authority;
- keeps `ownerImport` provenance, exact origin binding, change classification
  and non-session actor idempotency inside ordinary validation/moderation;
- authorizes no Event Ingestion schema, fetcher, worker, callable, resource,
  network access, cloud deployment or publication bypass.

### v0.6 — 2026-09-25

- adds the immutable local Event Booking outbox and idempotent Booking delivery
  checkpoint with bounded retry/dead-letter evidence;
- adds Booking-owned occurrence cancellation and material-reschedule effects
  without giving Booking write authority over Event publication state.
- records exact Node 22.23.2/Java 21 focused delivery/lifecycle evidence while
  retaining the bounded 100-way contention caveat in BCK-09.

### v0.5 — 2026-09-25

- adds the bounded BCK-07/BCK-09 `EventRevisionPublished` handoff without
  starting BCK07-LOCAL-01 or creating a second Content aggregate;
- keeps Event as publication-state writer and gives the BCK-09 consumer sole
  write ownership of the minimal operational `bookingEventProjections` view;
- verifies duplicate/out-of-order delivery, unpublish, occurrence cancellation,
  material reschedule and deterministic rebuild in the local Emulator; that
  v0.5 evidence used Java 21 and Node 24 compatibility mode and is superseded
  for the v0.6 delivery/lifecycle paths by the exact-toolchain focused rerun.

### v0.4 — 2026-09-23

- defines BCK07-LOCAL-01 as the first item-6 product slice with exact local
  paths, dependencies, tests, migration and rollback boundaries;
- authorizes only a disabled framework-neutral Content foundation with
  canonical schemas, in-memory repositories and local evidence;
- retains mobile/UI, callable exports, Firestore/Firebase product runtime,
  Media, Catalog workers, cloud, deployment and activation as later gates.

### v0.3 — 2026-09-20

- completed the Stage 3 ten-type publication adapter matrix and exact
  Identity→draft→submission→immutable revision→Catalog handoff;
- fixed PublisherRef pinning, moderation disposition consumption, publication
  transaction/outbox semantics and typed rollback/withdrawal behavior;
- preserved missing source contracts, OD-03/10/11, Money, Media, T&S,
  Firebase and execution dependencies as independent fail-closed gates.

### v0.2.1 — 2026-09-20

- added the Stage 2 normalized Content entity inventory;
- separated Content publication authority from Media blobs, Discover
  projections, T&S enforcement and BCK-18 import orchestration;
- aligned publisher, lifecycle, transaction and evidence semantics.

### v0.2 — 2026-08-25

- completed the 22/22 BCK-02 design contract and promoted it to Review;
- established exactly ten publishable Create types with Scenario replacing the
  legacy Quick Plan taxonomy slot;
- separated publication manifest/current public revision from source-domain,
  Media, Identity, Catalog, Booking and moderation authority;
- recorded 60 AC and ten owner decisions without authorizing contracts,
  Firebase, migration, runtime, deployment or production data.

### v0.1 — 2026-08-25

- created the documentation-only target from canonical docs and current
  local/mock Create runtime audit;
- recorded unknown-type, pending-review timestamp, PublisherRef, Money, media,
  provenance and parallel-publication migration debt.

## 1. Verdict and status semantics

BCK-07 defines the target authoritative publication lifecycle for the ten
accepted Create Hub content types. It is complete enough for cross-owner Review,
not Approved or implemented. Runtime is Absent.

This specification does not treat OD-10 technical acceptance as source,
content, Legal, fixture or runtime approval. Missing source-domain contracts make their type disabled, not
implicitly generic. Document Review creates no Firebase, backend handlers,
mobile adapter, import, public catalog item or production permission.

## 2. Parents, priority and compatibility

Priority:

1. Accepted ADR;
2. Approved owning product/domain specification;
3. Approved BCK coordination and architecture decisions;
4. this BCK-07 publication contract;
5. Draft/Proposed documents and current runtime evidence.

Inputs:

- [ADR 0013](../adr/0013-domain-policy-baseline.md): lifecycle, ownership,
  capability, IDs, moderation, privacy, audit and media separation;
- [ADR 0015](../adr/0015-authenticated-viewer-verified-creator-professional-page.md):
  authenticated User drafting and verified Creator/PublisherRef authority;
- [BCK-03](BACKEND_API_CONTRACT_STANDARD.md): typed wire and idempotency;
- [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md): privacy/security/age gates;
- [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md): account/access/publisher truth;
- [BCK-14](MEDIA_STORAGE_BACKEND_SPEC.md): ready media generations;
- [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md): mobile/import seam;
- [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md): stable reference revisions
  and Proposed, not Accepted, LocalizedText contract;
- [Event Classification v2.2.3](EVENT_CLASSIFICATION_SPEC.md): canonical Event
  axes and aggregate boundaries;
- [Vision](VISION.md): ten-type Create Hub and product boundaries.

An existing local/mock behavior is compatibility evidence, not authority. A
type-specific Draft/Ready-for-approval spec cannot be silently promoted here.

## 3. Outcome and non-goals

### 3.1 Outcome

One provider-neutral publication service that:

- persists actor-owned revisioned drafts where a domain permits cloud drafts;
- validates a typed source revision through the owning domain;
- records persistent PublisherRef and immutable provenance;
- submits, reviews, activates, revises, hides, archives and deletes through
  trusted state transitions;
- emits catalog-consumable facts without writing Catalog projections;
- coordinates Media readiness and moderation/DSR effects without stealing
  their ownership;
- supports migration, compatibility, rollback and Baltic market gates.

### 3.2 Non-goals

BCK-07 does not own:

- account/session/Creator/Page/capability decisions;
- category, locale, market or currency datasets;
- Scenario, Quick Plan, Route/GPX or Booking source aggregates;
- Media bytes, object generations or transforms;
- search/feed/map/details projections or ranking;
- report cases, sanctions, appeals or staff case management;
- payments, provider availability, notification delivery or analytics datasets;
- Firebase provisioning, UI/form composition or direct SDK access.

## 4. Canonical scope and type registry

Exactly these stable type IDs may be registered for publication:

```text
event
activity
route
place
session
scenario
find_people
class_workshop
rental
collection
```

The registry entry includes type ID, schema family/version, owning validator,
source-revision resolver, publication policy revision, required capability,
allowed visibility, moderation profile, market/age gates and projection mapper
version. It is server-controlled and fail-closed.

`quick_plan` is a BCK-10 private/invited utility and legacy read discriminator.
It cannot be submitted, activated or projected by BCK-07. Unknown/newer IDs
return typed unsupported state; they never default to Event.

Each type is enabled independently. A generic shared form or base draft does
not authorize publication if the type validator/contract is missing.

## 5. Ownership and single writers

| Record/decision | Single writer | BCK-07 boundary |
|---|---|---|
| `PublicationRecord`/current public revision | BCK-07 | Full lifecycle truth |
| Generic draft envelope/revision | BCK-07 where cloud draft is enabled | Actor/publisher/type/revision, not foreign aggregate mutation |
| Event content source/config | Event domain through BCK-07 adapter | Validate and pin accepted revision |
| Scenario source aggregate | BCK-10 | BCK-07 stores distribution snapshot ref only |
| Quick Plan | BCK-10 | Never publish |
| Route/GPX source aggregate | BCK-11 | BCK-07 stores publication snapshot ref only |
| Booking/inventory ledger | BCK-09 | BCK-07 exposes pinned Event config only |
| Media asset/object generation | BCK-14 | Consume ready receipt |
| Access/PublisherRef eligibility | BCK-06 | Consume current access result |
| Catalog/search/map/feed/details projection | BCK-08 | Consume published/revoked facts |
| Moderation case/sanction | BCK-22 | Apply typed authorized effect to Content |
| Reference/localization datasets | BCK-20 | Pin stable IDs/revisions |

Publication is an owning command, not a database copy performed by a consumer.
Discover, Media, Mobile, Admin and moderation workers never directly edit the
Content source record.

## 6. Actors and authorization boundary

Actors:

- authenticated personal author;
- verified Creator acting as personal PublisherRef;
- verified Creator with active exact-page membership;
- trusted review/moderation effect principal;
- privacy deletion/restriction orchestrator;
- migration worker using BCK-18 checkpoint and explicit mappings.

An authenticated User may create/save a permitted personal or
pre-verification draft. Under the current Accepted baseline, generic
pre-verification authoring is local-only; this BCK does not silently promote it
to remote unverified storage. Submit/publish requires backend-time verified
Creator, required capability, exact personal/page PublisherRef eligibility,
current membership, market/type policy and expected revision.

Personal Scenario authoring/distribution semantics remain BCK-10: ordinary User
may keep a private personal Scenario; public/unlisted distribution invokes the
applicable BCK-07/BCK-10 contract and capability. No manual User/Creator role
switch grants authority.

Workspace switching supplies a default only for a **new** draft. It never
rewrites a saved draft's PublisherRef. Cached access and client booleans never
authorize a mutation.

## 7. Domain model

### 7.1 ContentDraftEnvelope

```text
ContentDraftEnvelope {
  draftId: ULID
  ownerSubjectId: UserId
  publisherRef: PublisherRef?
  contentTypeId: canonical type ID
  sourceRef: {aggregateId, revision, schemaVersion}
  basePublishedRevisionId: ULID?
  state: draft | submitted | superseded | deleted
  visibilityIntent: private | unlisted | public
  marketRefs: MarketId[]
  referenceDatasetRevision
  contentLanguageRefs
  provenanceRef
  revision
  createdAt/updatedAt: UTC
}
```

PublisherRef may be absent only in an owning-domain private aggregate that
explicitly permits it, such as personal Scenario semantics delegated to BCK-10.
A generic local pre-verification draft is not uploaded merely because this
envelope exists. PublisherRef is mandatory and eligible before Content submit/
distribution. Draft payload is typed by the source domain; unbounded
`sectionData` is not wire authority.

### 7.2 PublicationRecord

```text
PublicationRecord {
  publicationId: ULID
  contentTypeId
  sourceRef + immutable sourceSnapshotHash
  publisherRef
  ownerSubjectId
  lifecycle: pendingReview | published | archived | hidden | deleted
  currentPublicRevisionId: ULID?
  candidateRevisionId: ULID?
  moderationProfileRevision
  provenanceRef
  marketRefs + visibility
  revision
  submittedAt/publishedAt/updatedAt/deletedAt: UTC?
}
```

`publishedAt` is non-null only after successful public/unlisted activation. A
record in `pendingReview` is not published and has no public catalog effect.
The lifecycle field is the sole publication state authority. Legacy
`draftStatus`, `publishStatus` and `moderationStatus` values are migration
inputs, not independently writable backend state. Review and sanction outcomes
are immutable typed references rather than parallel lifecycle enums.

### 7.3 ContentRevision

An immutable revision pins source schema/version/hash, publisher, market,
reference/localization revisions, generation-pinned Media refs, age/restriction
classification, provenance and policy versions. Material edit produces a new
candidate revision; it never mutates the current public revision in place.

### 7.4 Provenance

```text
ContentProvenance {
  kind: creatorSubmission | ownerImport | licensedSeed | officialSource |
        derivedMigration
  sourceId + sourceRevision + snapshotHash?
  sourceUrlRef?
  licensePolicyRef?
  attributionRef?
  acquiredAt + checkedAt?
  correctionRemovalPolicyRef
  importer/actorRef
  originBinding {
    kind: directAuthoring | delegatedImport
    delegatedActorRef?
    externalBindingRef?
  }
}
```

Raw URLs and UI seed labels are not sufficient. A licensed/official seed does
not impersonate a user/page. Until OD-03 defines eligible publisher/attribution,
seeded public activation is disabled.

`delegatedImport` is an additive command origin, not a PublisherRef and not a
staff impersonation mechanism. Its actor reference identifies the approved
server module and operation; the requested PublisherRef is revalidated by
BCK-06 and bound only by BCK-07. Imported Event submissions carry a typed
change class through the same validation and moderation path as manual
content. For a non-session server actor, semantic idempotency binds module
actor, source/binding, logical operation, normalized payload hash and expected
revision; absence of a mobile Session never weakens authorization or audit.

## 8. State machines and revision semantics

### 8.1 Draft/candidate

```text
draft -> submitted -> pendingReview
draft -> deleted
submitted -> draft (typed remediation only)
submitted -> superseded
```

### 8.2 Publication

```text
pendingReview -> published | archived | deleted
published -> archived | hidden | deleted
archived -> pendingReview | published | deleted
hidden -> published | archived | deleted
```

`hidden` is moderation/system visibility restriction. It is not an author
archive and cannot be cleared by ordinary author edit. `deleted` is terminal
for that revision/record identity; restore, where policy permits, is a trusted
explicit command and never automatic backup resurrection.

### 8.3 Material revision

For an already published item:

1. current public revision remains immutable and readable unless separately
   hidden/archived/deleted;
2. edit creates a candidate based on exact public revision;
3. review policy decides whether the candidate needs pending review;
4. activation atomically switches the current revision pointer;
5. catalog consumers receive one ordered/revisioned change fact.

If activation fails, the prior public revision remains authoritative. A
candidate is never partially visible.

### 8.4 Direct publish

Default is pending review. Direct publish exists only for an Accepted
type/market/publisher policy with trusted server flag, exact capability,
current access snapshot, validated source and revision, ready media and audit.
One type-specific local shortcut never becomes a global backend rule.

## 9. Commands

| Command | Result | Key controls |
|---|---|---|
| `content.createDraft` | draft envelope | actor/type/market policy; permanent ID |
| `content.saveDraftRevision` | saved/replayed/conflict | owner, expected revision, typed validator |
| `content.bindPublisher` | new draft revision | exact eligible PublisherRef; no workspace rewrite |
| `content.submitForReview` | pending-review receipt | readiness, source/media/ref revisions, capability |
| `content.activateRevision` | published revision | trusted review/direct policy, expected publication revision |
| `content.rejectCandidate` | remediation/rejected receipt | trusted review decision/ref |
| `content.archive` | archived receipt | owner/capability/revision |
| `content.hide` | hidden receipt | trusted moderation/safety command |
| `content.restoreVisibility` | published/archived receipt | trusted effect; sanction resolved |
| `content.delete` | deletion receipt | owner/privacy/admin authority, retention/holds |
| `content.correctProvenance` | new candidate/effect | OD-03 policy and audit |
| `content.removeSeededSource` | revoked/deleted effect | source removal policy |

No command takes a client-provided `isAuthorized`, `isVerifiedCreator`,
`approved`, `publishedAt` or moderation verdict as truth.

## 10. Queries and public handoff

| Query | Projection |
|---|---|
| `content.getDraft` | owner-scoped typed draft envelope/revision |
| `content.listDrafts` | owner/workspace/type cursor page |
| `content.getPublicationStatus` | lifecycle, candidate/current revisions, actions/failures |
| `content.getPublishedRevision` | authorized immutable source snapshot |
| `content.listPublisherContent` | publisher-scoped management projection |
| `content.getProvenanceDisclosure` | visibility-appropriate attribution/freshness/removal info |

BCK-08 receives minimal `content.publishedRevisionChanged` and
`content.visibilityChanged` facts and builds feed/map/search/details
projections. It never reads mutable drafts as catalog truth. BCK-07 does not
write search indexes or promise Discover query freshness; BCK-08 owns revision
and projection parity.

Booking/provider consumers receive only explicit Event/config revision refs and
never infer availability from Content lifecycle alone.

## 11. Events and typed failures

### 11.1 Events

- `content.draftSaved`
- `content.submitted`
- `content.revisionActivated`
- `content.candidateRejected`
- `content.archived`
- `content.visibilityRestricted`
- `content.visibilityRestored`
- `content.deleted`
- `content.provenanceCorrected`
- `content.sourceRemoved`

Events are semantic until the BCK-03 OD-09 envelope is Accepted. Consumers
dedupe and tolerate replay/out-of-order delivery. Events never grant authority
or carry raw private drafts.

### 11.2 Failure vocabulary

```text
unauthenticated
permissionDenied
creatorVerificationRequired
publisherUnavailable
membershipInactive
unsupportedContentType
unsupportedContractVersion
typeDisabled
marketDisabled
agePolicyUnavailable
referenceRevisionUnsupported
sourceRevisionUnavailable
sourceValidationFailed
mediaNotReady
rightsEvidenceRequired
provenanceRequired
reviewRequired
moderationRestricted
staleRevision
conflict
notFound
alreadyDeleted
rateLimited
temporarilyUnavailable
unknownOutcome
cancelled
```

Unsupported/unknown type is not reinterpreted. Cancellation before send is
neutral; cancellation after possible commit is unknown outcome unless the
server proves no commit.

## 12. Contract versions and evolution

- wire DTO, generic envelope and typed domain payload remain separate;
- each content type has a registered schema family/version and validator;
- newer unsupported type/schema/reference/policy revision fails closed;
- unknown fields may round-trip only under an explicit compatibility contract;
- generated files are never manually edited;
- non-Booking Content schema/codegen requires BCK07-OD-01/API approval;
- material breaking change uses parallel versions/migration, not silent cast;
- minimum supported client and deprecation window precede removal;
- stable AC identifiers are not renumbered within accepted review history.

The generic layer does not normalize an unknown typed payload into Event or a
loosely typed map. Schema version and source revision are both pinned.

## 13. Authorization, revocation and policy

Every mutation re-evaluates backend session, revocation, verified Creator where
required, capability, exact PublisherRef, active page membership, owner,
market/type/age policy, source/media/reference revision and expected content
revision.

Draft read/write is owner/workspace scoped. A personal draft cannot be read by
a page member merely because the same user manages the page. A page draft
requires exact active membership and capability. Account/workspace/environment
caches never mix.

Revoked verification/membership/capability stops submit/activation immediately.
It does not silently rewrite already published ownership. Subsequent visibility,
transfer, remediation or archive follows an explicit policy/command and audit.

App Check is defense in depth only. Direct authoritative client Firestore
writes, client moderation state and cached authorization are forbidden.

## 14. Persistence, indexes and transactions

Logical stores:

- draft envelopes and immutable draft revisions;
- publication records and immutable content revisions;
- provenance/source records;
- idempotency/command result records;
- moderation/visibility effect references;
- deletion/retention task records;
- audit and outbox.

Indexes support owner/workspace/type/state/updated time, publisher/type/state,
and source/provenance removal lookup. Query shape, cardinality, document size
and cost are measured before implementation; no unbounded arrays/history live
inside one mutable document.

Atomic publication transaction validates expected record/candidate/source/
media/reference revisions, records the immutable revision, switches the current
pointer, writes audit/idempotency result and outbox. Source aggregates and
Media objects are not assumed to share that database transaction; their
generation-pinned receipts make the check deterministic. Reconciliation
detects partial effects without inventing success.

## 15. IDs, time, Money and reference data

- permanent content/draft/revision/source IDs are ULID/UUID;
- `loc_*` never crosses authoritative command boundary;
- server-authoritative timestamps are UTC;
- local occurrence/place semantics retain IANA timezone;
- category/subcategory/market/currency/language use stable BCK-20 IDs/revisions;
- relations are ID-based, never display-name-based;
- Money is integer minor units plus ISO currency and scale semantics;
- M2 normalized Money migration must complete before price-bearing remote writes;
- OD-10 LocalizedText/fallback remains disabled until its retained
  source/content/Legal/fixture/runtime gates pass;
- public `publishedAt` is backend activation time, never submit time.

## 16. Idempotency, concurrency, retry and failure

Every logical command uses stable idempotency key and normalized payload hash;
each attempt uses a fresh request ID. Same key/same hash returns recorded result;
same key/different hash performs no mutation.

Draft save, submit, activation, archive/hide/restore/delete and provenance
correction use expected revisions. Last-write-wins is not authoritative remote
policy. Conflicts return current revision and safe remediation without exposing
another actor's data.

Unknown outcome is reconciled by command result/idempotency lookup before a new
logical operation. A repeated already-completed transition may be idempotent
only when actor, target, requested outcome and revision lineage match.

## 17. Offline, cache and freshness

Offline local drafts remain supported through BCK-18/mobile repositories.
Offline clients may queue explicit draft intent but cannot claim submit,
review, publish, hide or delete success. Public/cached projection never
authorizes edit or activation.

Client state distinguishes local-only, queued, syncing, saved-fresh,
saved-cached, conflict, pending review, published, stale, hidden, archived,
deleted, unsupported and unknown outcome. Entries pin account/workspace,
environment, type/schema, draft/publication/source/reference revision and
freshness metadata.

A deletion/hide/revocation tombstone wins over stale public cache. Switching
workspace does not rewrite existing draft PublisherRef or migrate ownership.

## 18. Migration, import and compatibility

Migration uses BCK-18 sessions/checkpoints and BCK-06 identity mappings. Each
item routes through a BCK-07 command and its owning type validator.

Required phases:

1. inventory local records without remote mutation;
2. classify exact type, schema, owner, PublisherRef, ID/revision, Money, media,
   provenance and visibility gaps;
3. keep unknown/newer/legacy types opaque;
4. map `quick_plan` only to BCK-10 legacy/private handling, never Scenario or
   public Content by inference;
5. replace `loc_*` using explicit durable mapping;
6. never import mock verification, capability, moderation or approval as truth;
7. validate Media URLs through BCK-14 and Money after M2;
8. dry-run, disclose conflicts/skips, checkpoint and support rollback;
9. preserve public source until a replacement revision is safely activated.

Legacy unknown type default-to-Event and pendingReview-with-publishedAt are read
debt only. They are normalized by explicit migration rules, not trusted.

## 19. Outbox, moderation and reconciliation

Publication and visibility changes record audit/outbox in the authoritative
transaction. BCK-08, Notifications and other consumers process idempotently;
replay cannot republish deleted/hidden content or grant access.

BCK-22 owns reports, sanctions and appeals. It issues a typed, authorized effect
reference; BCK-07 conditionally applies `hidden`/restore/delete as Content
writer. A report count, client request or scanner result is not itself a final
sanction.

Reconciliation detects:

- publication current pointer to absent/incompatible revision;
- published revision with non-ready Media generation;
- invalid/revoked publisher eligibility requiring policy action;
- catalog projection lag (reported to BCK-08, not directly repaired there);
- source/license removal affecting published revisions;
- incomplete outbox/visibility/deletion task;
- parallel legacy publication record.

## 20. Privacy, minors, retention and Legal

Drafts are private by default. Public revisions contain only allowlisted fields
for the content type/market/visibility. Private organizer contact, exact private
meeting data, unpublished coordinates, identity evidence, internal moderation
notes and raw source documents never enter public projections.

`PublisherRef` identifies the publishing subject/context; it is not a public
contact card. Legacy organizer ID/name/phone/email fields are reconciled into
typed private contact and explicitly allowlisted public attribution projections
rather than copied wholesale.

Find People, age-restricted content and any minor/guardian-dependent path remain
server-disabled until OD-11 is Accepted for the market and qualified
Legal/Privacy evidence exists. No age is invented here.

Retention is separate for drafts, superseded revisions, published/archived/
hidden/deleted content, provenance/license evidence, moderation refs,
idempotency/outbox/audit and backups. No numeric term is Accepted by inheritance
from a generic class or provider default. Exact policy is BCK07-OD-07.

DSR/export/restriction/delete delegates scoped tasks to source domains, Media,
Catalog and backups and records privacy-safe completion evidence. Deletion first
blocks live access. Restore replays newer deletion/restriction/sanction facts
before any user/public access. Legal/security hold is explicit, scoped,
time-bound and never creates visibility.

## 21. Abuse, eligibility and App Check

Controls include:

- per actor/publisher/type/market draft/submit/publish limits;
- duplicate/source/hash similarity signals without cross-owner disclosure;
- category/tag/reference allowlists;
- URL/contact/markup normalization and injection-safe rendering;
- server-side readiness and capability validation;
- suspicious seeded provenance/license checks;
- OD-11 age/eligibility enforcement where applicable;
- App Check monitor/enforce under BCK-04, never as AuthZ;
- type/market/submit/direct-publish/import kill switches.

ADR 0013 numeric baselines remain applicable only in their accepted scope and
do not silently become full production quotas. Exact quotas/sanctions need
owner evidence. Abuse checks cannot silently rewrite content or become a
moderation verdict.

## 22. Observability, SLO, analytics and cost

Metrics:

- draft create/save/conflict and sync outcomes;
- submit/readiness failures by safe typed code;
- pending-review queue age and activation latency;
- published/candidate/hidden/archived/deleted counts;
- publisher/type/market policy denials;
- source/provenance freshness/correction/removal lag;
- Media/source/reference mismatch;
- outbox/catalog projection lag;
- storage/read/write/task cost by environment/type/market.

Logs exclude raw draft bodies, personal contact/location, media URLs/tokens,
identity evidence and free-text moderation content. Analytics receives governed
event IDs/minimized dimensions, never Content authority.

Numeric availability, latency, review, deletion, cost and quota targets remain
BCK07-OD-10. Degradation may disable submit/activation/type/market and retain
safe drafts; it never bypasses validation or exposes a candidate.

## 23. Flags, rollout and rollback

Server flags are independent by environment, market, type and command:

- cloud draft read/write;
- submit/review/activation;
- direct publish policy;
- unlisted/public visibility;
- seeded source/import;
- catalog event emission;
- age-sensitive surface.

Rollout: documentation → contract fixtures → unit → emulator → synthetic stage
→ staff cohort → bounded market cohort → owner-approved expansion. Status at
one stage does not prove the next.

Rollback disables new risky commands, preserves local/remote drafts and last
safe public revision, drains/quarantines effects and keeps deletion/restriction
duties. It never restores mock grants, old unsafe schema, hidden content or a
candidate as public. Public rollback is an explicit pointer transition with
audit, not an object overwrite.

## 24. Dependency and delivery gates

Before Approval:

- BCK-03/04/05/06/18/20 compatibility disposition and owner review;
- OD-03 Accepted and OD-10 retained source/content/Legal/fixture gates passed;
- OD-11 Accepted for enabled age-sensitive scope, otherwise that scope is
  explicitly disabled with tests;
- ten BCK07 decisions resolved or formally deferred with controls;
- canonical source contract/test fixtures for each enabled type;
- BCK-10/11/14/22 handoffs reconciled where their types/effects are enabled;
- qualified Security/Privacy/Legal and Operations verdicts.

Before executable work:

- separate Approved bounded R3 slice and exact file/resource map;
- M2 Money complete for price-bearing writes;
- BCK-18 adapter/import gates and no mock authority;
- G1/R1/R2 prerequisites appropriate to environment;
- no new boundary suppression or explicit approved debt change.

Before production:

- contracts, handlers, persistence, Rules/IAM and negative AuthZ evidence;
- type parity, migration, source/provenance and rollback evidence;
- Media/Catalog/moderation/DSR integration and recovery drills;
- load/SLO/cost, incident and owner sign-off;
- market-specific Legal/Privacy and feature activation decision.

## 25. Conditional exact file map

The earlier pre-R1 placeholder roots are superseded. Content never uses
`packages/api_contracts/content/`, `apps/backend/src/content/` or
`apps/backend/test/content/`; those paths would create a parallel layout.

The only approved BCK07-LOCAL-01 path map is §34.2:

```text
packages/api_contracts/schema/content/v1/
apps/backend/functions/src/contracts/          # three exact files in §34.2
apps/backend/functions/src/modules/content/{domain,application,infrastructure}/
apps/backend/functions/test/{contract,unit/content,integration}/
```

Later transport, persistence, workers, migration/recovery or mobile adapter
paths require their own BCK-02/BCK-07/BCK-18 amendment and executable slice.
Scenario, Route, Media, Booking, Catalog and Trust & Safety implementations
stay in their owning modules. Generated artifacts follow the accepted workflow
and are never manually edited.

## 26. Test and evidence matrix

| Layer | Required evidence |
|---|---|
| Domain/unit | ten-type allowlist, Quick Plan denial, lifecycle/revisions, direct-publish policy |
| Contract | typed schemas/fixtures/errors, unknown/newer fail-closed, split idempotency |
| Source adapters | exact source revision and validator parity per enabled type |
| Security | unauthenticated, unverified, cross-user/page, revoked membership, client state injection |
| Media/reference | non-ready generation, stale taxonomy/locale/market and Money rejection |
| Publication | candidate/current atomic switch, between-step failure, prior revision preserved |
| Moderation | typed effect only, report count cannot hide, restore requires resolved sanction |
| Catalog | ordered revision facts, replay/dedupe, no draft leakage, tombstone propagation |
| Privacy/Legal | public allowlists, OD-11 gates, DSR/delete/restore no resurrection |
| Migration | unknown→not Event, Quick Plan non-public, `loc_*`, PublisherRef, provenance, dry run/rollback |
| Load/cost | draft/submit/review/publish throughput, queue/lag, storage/task/read/write forecast |
| Rollout | flags, disabled type/market, previous client, rollback to last safe revision |

Documentation checks prove structure and reconciliation only. Emulator does not
prove production IAM, service limits, latency, Legal review or recovery.

## 27. Definition of Ready

For Approval review:

1. 22/22 coverage remains current;
2. exactly ten registered types and all missing type contracts are dispositioned;
3. OD-03/10 and applicable OD-11 have owner verdicts;
4. ten BCK07 decisions have dated evidence;
5. dependency owners sign the single-writer/handoff matrix;
6. runtime remains absent unless separately authorized.

For executable slice:

1. BCK-07 Approved;
2. exact type/market/command/file/resource scope approved;
3. contracts/fixtures/readiness and failure vocabulary frozen;
4. G/R prerequisites and production mock exclusion satisfied;
5. rollback, kill-switch, cost and migration thresholds predeclared;
6. no unresolved policy is implemented by assumption.

## 28. Definition of Done

Runtime is Done only when:

- authoritative drafts/revisions/publication records and commands exist in
  owned layers;
- every enabled type passes validator/source/contract parity;
- Identity, Media, Reference, Catalog and moderation handoffs preserve writers;
- security, integration, privacy, migration, recovery and load gates pass;
- observability/runbooks/on-call/cost controls are active;
- runtime evidence/status is updated without conflating Done and Enabled.

Production Enabled additionally requires owner-approved market cohort,
Legal/Privacy, recovery and incident readiness. Review, Approved, Done,
deployed and Enabled are distinct.

## 29. Acceptance criteria

1. **BCK-07-AC-01:** Exactly ten canonical content types may be registered.
2. **BCK-07-AC-02:** Scenario occupies the planning Create slot.
3. **BCK-07-AC-03:** Quick Plan is never submitted or catalog-published.
4. **BCK-07-AC-04:** Unknown/newer type never defaults to Event.
5. **BCK-07-AC-05:** Missing type validator disables that type.
6. **BCK-07-AC-06:** One lifecycle writer replaces parallel draft/publish/moderation status authority.
7. **BCK-07-AC-07:** Scenario/Route/Booking source aggregates retain their writers.
8. **BCK-07-AC-08:** Catalog/Search remains BCK-08 projection authority.
9. **BCK-07-AC-09:** Media ready receipt never publishes Content itself.
10. **BCK-07-AC-10:** Identity snapshot never becomes Content ownership data.
11. **BCK-07-AC-11:** Authenticated User draft does not grant Submit/Publish.
12. **BCK-07-AC-12:** Submit rechecks verified Creator and exact capability.
13. **BCK-07-AC-13:** Page publish requires active exact-page membership.
14. **BCK-07-AC-14:** Workspace switch never rewrites saved PublisherRef.
15. **BCK-07-AC-15:** Cached/client authorization never grants mutation.
16. **BCK-07-AC-16:** Pending review is not public/published.
17. **BCK-07-AC-17:** `publishedAt` is assigned only on activation.
18. **BCK-07-AC-18:** Material edit creates an immutable candidate revision.
19. **BCK-07-AC-19:** Current public revision remains until atomic activation.
20. **BCK-07-AC-20:** Failed candidate activation preserves prior public truth.
21. **BCK-07-AC-21:** Direct publish is explicit per type/market/publisher policy.
22. **BCK-07-AC-22:** One local type shortcut never becomes a global rule.
23. **BCK-07-AC-23:** Hidden is trusted moderation/system state, not author archive.
24. **BCK-07-AC-24:** Report count/client request cannot directly hide Content.
25. **BCK-07-AC-25:** Restore requires typed resolved effect and current revision.
26. **BCK-07-AC-26:** Deleted/restricted tombstone wins over cache/replay.
27. **BCK-07-AC-27:** Content wire never uses unbounded section map as authority.
28. **BCK-07-AC-28:** Source schema, revision and snapshot hash are pinned.
29. **BCK-07-AC-29:** Media refs pin ready asset generation.
30. **BCK-07-AC-30:** Reference/market/localization revisions are explicit.
31. **BCK-07-AC-31:** Money remote writes wait for M2 minor units.
32. **BCK-07-AC-32:** `loc_*` never crosses authoritative boundary.
33. **BCK-07-AC-33:** Published relations use IDs, never display names.
34. **BCK-07-AC-34:** Same idempotency key/different hash creates no mutation.
35. **BCK-07-AC-35:** Retry uses fresh request ID and stable logical key.
36. **BCK-07-AC-36:** Unknown outcome is reconciled before new logical command.
37. **BCK-07-AC-37:** Stale revision cannot overwrite newer lifecycle state.
38. **BCK-07-AC-38:** Offline client never claims submit/publish/delete success.
39. **BCK-07-AC-39:** Draft/public caches are account/workspace/environment scoped.
40. **BCK-07-AC-40:** Newer unsupported contract fails closed.
41. **BCK-07-AC-41:** Migration never imports mock grants/approval/moderation.
42. **BCK-07-AC-42:** Legacy Quick Plan is not inferred as Scenario/public Content.
43. **BCK-07-AC-43:** Legacy unknown type is not inferred as Event.
44. **BCK-07-AC-44:** Seeded source never impersonates a user/page PublisherRef.
45. **BCK-07-AC-45:** OD-03 blocks seeded catalog activation.
46. **BCK-07-AC-46:** OD-10 technical acceptance is not treated as
    source/content/Legal/fixture/runtime approval.
47. **BCK-07-AC-47:** OD-11 blocks age-sensitive publication where unresolved.
48. **BCK-07-AC-48:** Public projection excludes private contact/location/evidence.
49. **BCK-07-AC-49:** Retention is per family/state/purpose with owner evidence.
50. **BCK-07-AC-50:** Restore replays newer deletion/restriction/sanction facts.
51. **BCK-07-AC-51:** Outbox replay cannot republish hidden/deleted Content.
52. **BCK-07-AC-52:** Logs contain no raw private draft or sensitive payload.
53. **BCK-07-AC-53:** Numeric SLO/quota/cost claims require evidence.
54. **BCK-07-AC-54:** Degradation never exposes unreviewed candidate.
55. **BCK-07-AC-55:** Every risky type/command/market has a server kill switch.
56. **BCK-07-AC-56:** Rollback preserves last safe revision and privacy duties.
57. **BCK-07-AC-57:** No new boundary suppression is introduced by this revision.
58. **BCK-07-AC-58:** Documentation/emulator/stage/production evidence remain distinct.
59. **BCK-07-AC-59:** Executable files require a separate Approved slice.
60. **BCK-07-AC-60:** Runtime stays Absent until measured evidence exists.

## 30. Explicit unimplemented list

- Content API schemas, fixtures, generated clients and typed DTOs;
- authoritative draft/revision/publication/provenance persistence;
- Firebase/GCP handlers, Rules, IAM, indexes, tasks or deployment;
- ten type source adapters and complete canonical type specs;
- BCK-10 Scenario/Quick Plan and BCK-11 Route/GPX backend handoffs;
- BCK-14 Media runtime and BCK-08 Catalog runtime;
- BCK-22 moderation/report/sanction integration;
- OD-03 seeded source/licence/provenance/removal decision;
- OD-10 source/content/Legal/fixture gates for production LocalizedText and
  content-language use;
- Accepted OD-11 age/minors policy for sensitive scope;
- mobile remote adapters, import and mock-authority removal;
- Money minor-unit migration for price-bearing records;
- legacy type/ID/publisher/media/provenance migration;
- exact retention, Legal/Privacy, SLO, quota and cost evidence;
- production cloud resources, data, traffic, deployment or enablement.

## 31. Final statement

BCK-07 v0.3 is a production-grade Review design for one Content publication
authority. It closes semantic ownership gaps while deliberately leaving every
unapproved type, policy and runtime surface disabled.

## 32. Stage 2 normalized Content entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| ContentDraft | Content Publication / draft handler | owner workspace and BCK-18 import orchestration | draftId; `loc_*` only before authoritative create; publisherRef immutable unless explicit command |
| PublicationSubmission | Content Publication / submit-review handler | moderation/T&S review projection and owner status | submissionId + draftId + expected draft revision |
| PublishedRevision | Content Publication / publish handler | Discover, Media links, Booking config reader and Mobile | contentId + immutable publishedRevisionId; references by IDs only |
| PublicationPointer | Content Publication / activate-withdraw handler | Discover projection workers and Details | contentId → one visible compatible revision |
| SeedProvenance | Content Publication / governed import handler | Admin, Discover and audit | provenanceId + source/license/revision; seed never bypasses ownership/policy |
| ModerationDispositionRef | Trust & Safety / BCK-22 decision handler; Content writes only its separate publication transition | owner/public status projections | decisionId + policy revision; not duplicated moderation evidence |

Drafts move editing → ready/submitted → revision-required or publishable;
published revisions are immutable and pointers may activate, replace or
withdraw them. Direct draft-to-public, publisher rewrite, partial publish and
projection-as-authority are forbidden. Save/submit/publish commands use stable
idempotency keys and expected revision; draft update, immutable revision create
and pointer activation have explicit atomic boundaries. Authorization resolves
current User/Creator/Admin and PublisherRef through BCK-06. Classification,
retention, deletion/holds and audit follow BCK-04; telemetry excludes content
body. Migration is per type with dry-run and permanent-ID mapping from BCK-18;
rollback selects a prior compatible revision or disables visibility. Type,
market and publication flags are server-owned. Evidence covers all 10 types,
publisher isolation, concurrency, moderation handoff, projection rebuild,
migration and rollback.

## 33. Stage 3 complete Create-to-Publication contract

This section defines one publication mechanism for the accepted ten Create
types. It does not make incomplete type source contracts executable and never
turns Quick Plan into catalog Content.

### 33.1 Ten-type source adapter registry

| Stable type ID | Source authority and pinned input | Publication adapter obligation | Discover family |
|---|---|---|---|
| `event` | Accepted Event classification/source revision | validate Event/config revision; never copy Booking inventory | Event |
| `activity` | typed Activity source/draft revision | validate activity-specific schedule/participation fields | Activity |
| `route` | BCK-11 immutable RouteRevision | pin privacy-trimmed publication revision and ready Media refs | Route |
| `place` | typed Place source/draft revision | validate place profile, geo visibility, hours and publisher authority | Place |
| `session` | typed Session source/draft revision | validate session schedule/instructor/participation semantics | Session |
| `scenario` | BCK-10 immutable ScenarioRevision | pin publishable Scenario snapshot; never embed Quick Plan | Scenario |
| `find_people` | BCK-06 purpose-limited consented profile revision | publish only policy-allowed fields while consent/OD-11 gates pass | Find People |
| `class_workshop` | typed Class/Workshop experience revision | validate host, schedule, participation and market policy | Class/Workshop |
| `rental` | typed Rental source/draft revision | validate offer terms, Money minor units and availability-source declaration | Rental |
| `collection` | typed Collection revision containing stable published object IDs | validate membership/order and forbid embedding unpublished objects | Collection |

Each registry entry pins type schema major, validator revision, source resolver,
required BCK-06 capability, PublisherRef scopes, moderation profile,
visibility/market policy, localized-text policy and BCK-08 mapper revision.
Missing/newer/incompatible entry returns `content_type_unsupported`; it never
falls back to a generic schema or Event.

### 33.2 Draft and publisher binding

Authoritative draft creation returns permanent `draftId` and initial revision.
An imported `loc_*` remains only an import source key recorded by BCK-18. Every
draft stores one immutable publisher-binding origin and current PublisherRef
revision. Changing active workspace does not rewrite the draft. A separately
authorized `changeDraftPublisher` command may create a new revision only before
submission, after validating both old and new scopes; published revisions are
never reassigned.

BCK-07 consumes `identity.getPublisherEligibility` for the exact
`{PublisherRef,typeId,action,market}` immediately before submit and publish.
Cached/mobile AccessSnapshot may pre-shape UI but is not transaction authority.
Loss of authority blocks later commands and may request restriction/withdrawal
according to accepted policy; it does not rewrite historical authorship.

### 33.3 Publication lifecycle

```text
draft.editing
  -> draft.ready
  -> submitted
  -> under_review | revision_requested | rejected
  -> approved_for_publication
  -> published(revision N)
  -> superseded(revision N+1) | withdrawn | restricted | deleted
```

Types whose policy permits no pre-publication moderation may move from
submitted to approved_for_publication through a recorded policy decision, not
by skipping the state. Rejection/revision request never mutates an earlier
published revision. Update creates a new immutable candidate; the current
pointer changes only after the candidate is fully validated and approved.

Forbidden transitions include direct local draft→published, partial revision
activation, publisher rewrite, reactivation of deleted content, publication
with pending Media, unknown type/default Event, stale eligibility and
projection-driven publication.

### 33.4 Moderation handoff

BCK-07 creates a `PublicationSubmission` and emits a minimized review request
containing submission/content/draft revision IDs, PublisherRef, type, market,
moderation profile and policy revisions. BCK-22 owns case, evidence, decision,
sanction and appeal. BCK-07 consumes only a verified typed disposition:

| Disposition | BCK-07 effect |
|---|---|
| `approve` | mark exact candidate approved; publication still rechecks Identity/type/market/media |
| `request_revision` | return draft workflow to revision-required with safe reason category |
| `reject` | close exact submission; do not delete draft/history automatically |
| `restrict` | restrict current pointer/surface scope according to exact decision |
| `withdraw` | atomically withdraw current public pointer and emit event |
| `restore` | create a new audited activation decision; never erase prior restriction history |

Disposition replay is idempotent by decision ID and target revision. Unknown,
stale, foreign or unsigned disposition creates no Content mutation.

### 33.5 Publication transaction and Catalog handoff

The authoritative publish transaction atomically:

1. revalidates current Identity/Creator/page capability and PublisherRef;
2. validates exact type/source/schema, MarketConfig, localization and Media
   readiness revisions;
3. creates one immutable `PublishedRevision`;
4. advances the `PublicationPointer` from expected previous revision;
5. stores audit and idempotency result;
6. appends `ContentPublished` or `ContentRevisionActivated` to the outbox.

BCK-08 writes Catalog projections only after consuming the committed event.
Catalog failure cannot roll back committed Content; replay/rebuild is required.
Events include contentId, publishedRevisionId, typeId, PublisherRef, visibility,
market/service-area references, mapper/reference/policy revisions and occurred
UTC instant—never draft body, private evidence or raw moderation notes.

Withdrawal/restriction/deletion uses the same transaction/outbox boundary and
must propagate a tombstone/effect that BCK-08 and BCK-18 treat as stronger than
stale cache.

### 33.6 Typed commands and outcomes

Stage 3 requires typed contracts for `createDraft`, `updateDraft`,
`changeDraftPublisher`, `submitForPublication`, `publishApprovedRevision`,
`withdrawPublication`, `applyModerationDisposition`, `getDraft`,
`getPublicationStatus` and `getPublishedRevision`.

Required failures include `unauthenticated`, `capability_denied`,
`publisher_not_eligible`, `creator_verification_required`,
`membership_inactive`, `type_disabled`, `source_revision_stale`,
`validation_failed`, `media_not_ready`, `moderation_required`,
`moderation_decision_stale`, `market_disabled`, `policy_unavailable`,
`revision_conflict`, `idempotency_conflict`, `unsupported_version` and
`unknown_outcome`.

### 33.7 Rollback

Publication rollback never mutates an immutable revision. It may atomically
select a previously compatible revision, withdraw visibility, disable a type or
market, stop new commands, and replay Catalog tombstones/events. Mobile may
return to local-only authoring through BCK-18, but local/mock state cannot claim
server publication, preserve invalid visibility or overwrite the current
server pointer.

### 33.8 Stage 3 acceptance addendum

61. **BCK-07-AC-61:** all ten stable Create type IDs have one registered typed
    source adapter and fail closed when its contract is unavailable.
62. **BCK-07-AC-62:** Quick Plan is never publishable Content or Scenario input.
63. **BCK-07-AC-63:** draft permanent ID and PublisherRef are server-validated;
    `loc_*` remains import provenance only.
64. **BCK-07-AC-64:** workspace switching cannot rewrite draft or published
    publisher authority.
65. **BCK-07-AC-65:** submit and publish re-evaluate exact current BCK-06
    capability, verification and page membership.
66. **BCK-07-AC-66:** moderation case/decision remains BCK-22 authority and is
    consumed through typed idempotent disposition.
67. **BCK-07-AC-67:** published revisions are immutable and pointer activation
    is expected-revision guarded.
68. **BCK-07-AC-68:** publish commits revision, pointer, audit, idempotency and
    outbox atomically.
69. **BCK-07-AC-69:** BCK-08 cannot publish, withdraw or repair Content.
70. **BCK-07-AC-70:** Catalog failure is replay/rebuild work and never causes
    silent Content rollback.
71. **BCK-07-AC-71:** withdrawal/restriction/deletion emits a versioned effect
    that defeats stale projections/cache.
72. **BCK-07-AC-72:** Event publication never copies or mutates Booking
    inventory/availability authority.
73. **BCK-07-AC-73:** imported mock moderation, grants and publication status
    cannot become authority.
74. **BCK-07-AC-74:** rollback selects compatible revision or withdraws; it
    never edits revision history.
75. **BCK-07-AC-75:** v0.3 grants no contracts/runtime/Firebase/deployment or
    type activation authority and retains every named gate.

## 34. BCK07-LOCAL-01 — disabled local Content Publication foundation

### 34.1 Decision and exact scope

`BCK07-LOCAL-01` is the approved next bounded item-6 slice. It may implement
only framework-neutral contracts, domain/application code, in-memory adapters
and local tests. Runtime status remains Absent until those files are created
and all gates pass; this v0.4 decision is not implementation evidence.

The slice covers:

- the exact ten-type registry from §33.1;
- `ContentDraft`, `PublicationSubmission`, immutable `PublishedRevision` and
  expected-revision `PublicationPointer`;
- typed create/update/submit/publish/withdraw/query commands and outcomes;
- server-current BCK-06 PublisherRef eligibility revalidation;
- BCK-20 MarketConfig/taxonomy/localization revision pinning;
- semantic idempotency, optimistic concurrency and compatible rollback;
- deterministic in-memory repositories and synthetic valid/invalid/forward
  fixtures.

Moderation is represented only by a typed disposition port. Media readiness,
Catalog projection and event delivery are ports/fakes; BCK-22, BCK-14 and
BCK-08 remain their authorities and no worker is created.

### 34.2 Exact implementation map

Only these new path families are allowed in the later implementation turn:

```text
packages/api_contracts/schema/content/v1/
  content_common.schema.json
  content_draft.schema.json
  publication_submission.schema.json
  published_revision.schema.json
  publication_pointer.schema.json
  content_command.schema.json
  content_query.schema.json
  content_result.schema.json
  fixtures/valid.json
  fixtures/invalid.json
  fixtures/forward.json

apps/backend/functions/src/contracts/
  content_v1.ts
  content_schema_registry.ts
  validate_content_contract.ts

apps/backend/functions/src/modules/content/
  domain/content_type_registry.ts
  domain/content_draft.ts
  domain/publication_submission.ts
  domain/published_revision.ts
  domain/publication_pointer.ts
  domain/failures.ts
  domain/repositories.ts
  application/content_publication_service.ts
  application/ports/publisher_eligibility_port.ts
  application/ports/reference_data_port.ts
  application/ports/moderation_disposition_port.ts
  application/ports/media_readiness_port.ts
  application/ports/publication_effect_sink.ts
  infrastructure/in_memory_content_repository.ts

apps/backend/functions/test/
  contract/content_fixture_parity.test.ts
  unit/content/content_domain.test.ts
  integration/content_publication_service.test.ts
  integration/content_publication_security.test.ts
```

No existing export registry, Firebase config, Rules, indexes, mobile file or
product collection may be changed by this slice. If implementation needs a
path outside this map, the slice stops and BCK-07/BCK-02 must be amended first.

### 34.3 Dependency and authority rules

Content may import shared/contracts/security interfaces and the published
BCK-06/BCK-20 ports. It cannot import Firebase Admin, transport handlers,
Booking, Catalog, Media implementations, mobile code or test fixtures from
another domain. The only Content writer is its application service through
the Content repository transaction boundary. Admin and moderation consumers
must issue typed commands; neither writes Content records directly.

All ten types remain disabled. A type with missing source validator,
PublisherRef eligibility, reference revision, policy or fake readiness result
fails closed. No mock capability, local publication status or fixture becomes
server authority.

### 34.4 Tests, migration and rollback

Required local evidence covers schema/TypeScript parity; all ten registry
entries; unknown/newer type/schema rejection; idempotency conflict; stale
revision; cross-user/page/market denial; revoked PublisherRef; immutable
revision enforcement; pointer contention; withdrawal; compatible rollback;
and confirmation that no endpoint, worker, Firebase import or cloud context
was introduced.

Migration is initially empty-state plus synthetic fixtures. Existing mobile
drafts are not imported in this slice; later BCK-18 import must dry-run,
revalidate owner/PublisherRef, map permanent IDs and remain idempotent.
Rollback reverts the exact slice commit and discards in-memory test state;
there is no production data or Firestore rollback.

### 34.5 Explicit exclusions

BCK07-LOCAL-01 does not authorize mobile/UI changes, callable/HTTP exports,
Firestore/Storage collections, Rules/index changes, outbox workers, schedules,
Media processing, Catalog indexing, moderation runtime, network/provider use,
Firebase/GCP resources, credentials, deployment, activation, push or merge.

### 34.6 Acceptance addendum

76. **BCK-07-AC-76:** BCK07-LOCAL-01 uses only the exact §34.2 path families
    and introduces no export, worker, Firebase import or mobile change.
77. **BCK-07-AC-77:** all ten Content type entries are explicit and an unknown
    or unavailable type fails closed without generic fallback.
78. **BCK-07-AC-78:** publish revalidates exact BCK-06 PublisherRef authority
    and pins exact BCK-20 revisions at command time.
79. **BCK-07-AC-79:** draft/submission/revision/pointer lifecycles enforce
    semantic idempotency, expected revision and immutable published history.
80. **BCK-07-AC-80:** in-memory adapters and synthetic fixtures provide no
    production, mock-capability or external-source authority.
81. **BCK-07-AC-81:** Media, moderation, Catalog and delivery stay behind
    typed ports and remain owned by BCK-14/22/08/03 respectively.
82. **BCK-07-AC-82:** implementation evidence, product activation, cloud,
    deployment, push and merge remain separate decisions after v0.4.

## 35. Bounded Event to Booking projection handoff

BCK-07 emits immutable, revisioned `EventRevisionPublished`, `EventUnpublished`,
`EventOccurrenceCancelled` and `EventMateriallyRescheduled` facts. It never
writes Booking storage. BCK-09 alone consumes these facts into
`bookingEventProjections/{occurrenceId}`. The projection contains only the
operational fields required to authorize free internal Booking; drafts,
moderation evidence, private copy and general Content state are excluded.

The consumer is idempotent, ignores lower `materialRevision`, rejects an exact
revision with conflicting meaning and preserves a typed non-bookable tombstone
for unpublish/cancellation. Rebuild replays immutable facts in deterministic
revision order. This local/Emulator seam is separate from BCK07-LOCAL-01 and
does not authorize Content persistence, workers, cloud or market activation.

83. **BCK-07-AC-83:** Event is the sole writer of publication state and BCK-09
    is the sole writer of `bookingEventProjections`.
84. **BCK-07-AC-84:** Projection identity is the exact `occurrenceId`; stale,
    duplicate and conflicting revisions have typed deterministic outcomes.
85. **BCK-07-AC-85:** Unpublish, occurrence cancellation and material
    reschedule are explicit immutable events, never inferred from missing data.
86. **BCK-07-AC-86:** The implemented handoff remains local/Emulator-only and
    does not start the broader Content aggregate slice.

87. **BCK-07-AC-87:** Event remains the sole writer of immutable
    `eventBookingOutbox` source records; Booking writes only its projection,
    delivery checkpoint and Booking-owned effects.
88. **BCK-07-AC-88:** duplicate delivery is replay-safe, older material
    revisions cannot win and malformed/conflicting facts enter explicit
    dead-letter state.
89. **BCK-07-AC-89:** occurrence cancellation creates a non-bookable tombstone
    and cancels active Booking while atomically releasing active key, finite
    ledger and user usage.
90. **BCK-07-AC-90:** material reschedule marks affected active Booking as
    requiring reconfirmation and records a suppressed pre-activation effect.
91. **BCK-07-AC-91:** local delivery services add no cloud trigger, worker,
    Content aggregate, market activation or deployment permission.
92. **BCK-07-AC-92:** delegated import invokes only BCK-07 commands and never
    writes Content, Booking, projection or outbox collections directly.
93. **BCK-07-AC-93:** `ownerImport` provenance preserves exact source/binding,
    importer actor and logical operation without fabricating missing fields.
94. **BCK-07-AC-94:** imported content passes the same domain validation,
    moderation and publisher eligibility checks as manual content.
95. **BCK-07-AC-95:** staff review cannot submit or publish an Event while
    impersonating the owning Page.
96. **BCK-07-AC-96:** non-session actor idempotency is stable across retry and
    restart and rejects the same key with a different semantic payload.
97. **BCK-07-AC-97:** this additive boundary creates no Event Ingestion
    runtime, network permission, callable export, resource or activation.
