# Recharge Backend — Content Publication Specification

- ID: **BCK-07**
- Version: **0.2**
- Date: **2026-08-25**
- Spec status: **Review — documentation only; approval pending**
- Runtime status: **Absent**
- Accountable owner: **Content Platform owner**
- Review owners: **Identity, API, Security/Privacy, Mobile, Reference Data,
  Media, Discover, Event, Planning, Route, Trust & Safety, Operations and Legal**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.36](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-07-PRE v0.2](BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

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

This specification does not promote Draft product documents or Proposed OD-10
to Accepted. Missing source-domain contracts make their type disabled, not
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
  authenticated Viewer drafting and verified Creator/PublisherRef authority;
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

An authenticated Viewer may create/save a permitted personal or
pre-verification draft. Under the current Accepted baseline, generic
pre-verification authoring is local-only; this BCK does not silently promote it
to remote unverified storage. Submit/publish requires backend-time verified
Creator, required capability, exact personal/page PublisherRef eligibility,
current membership, market/type policy and expected revision.

Personal Scenario authoring/distribution semantics remain BCK-10: ordinary User
may keep a private personal Scenario; public/unlisted distribution invokes the
applicable BCK-07/BCK-10 contract and capability. No manual Viewer/Creator role
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
}
```

Raw URLs and UI seed labels are not sufficient. A licensed/official seed does
not impersonate a user/page. Until OD-03 defines eligible publisher/attribution,
seeded public activation is disabled.

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
- OD-10 LocalizedText/fallback remains disabled until Accepted;
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
- OD-03 and OD-10 Accepted;
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

No file below is authorized by this Review. A future Approved slice may create:

```text
packages/api_contracts/content/                # after BCK07-OD-01
  schemas/
  fixtures/

apps/backend/src/content/
  domain/
    content_draft.*
    publication_record.*
    content_revision.*
    content_provenance.*
    content_type_registry.*
  application/
    create_draft.*
    save_draft_revision.*
    submit_for_review.*
    activate_revision.*
    apply_visibility_effect.*
    archive_content.*
    delete_content.*
    reconcile_content.*
  infrastructure/
    content_repository.*
    source_resolver_registry.*
    identity_access_gateway.*
    media_readiness_gateway.*
    reference_data_gateway.*
    outbox_repository.*
  presentation/
    content_handlers.*
  workers/
    content_reconciler.*
    provenance_rechecker.*
    content_deletion_worker.*

apps/backend/test/content/
  unit/
  contract/
  integration/
  security/
  migration/
  recovery/

apps/mobile/lib/features/create/data/remote/    # after BCK-18/R3 approval
apps/mobile/test/features/create/**
```

Scenario, Route, Media, Booking, Catalog and Trust & Safety implementations stay
in their owning modules. Generated artifacts follow the accepted workflow and
are never manually edited.

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
11. **BCK-07-AC-11:** Authenticated Viewer draft does not grant Submit/Publish.
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
46. **BCK-07-AC-46:** OD-10 proposal is not treated as Accepted.
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
- Accepted OD-10 LocalizedText/content-language contract;
- Accepted OD-11 age/minors policy for sensitive scope;
- mobile remote adapters, import and mock-authority removal;
- Money minor-unit migration for price-bearing records;
- legacy type/ID/publisher/media/provenance migration;
- exact retention, Legal/Privacy, SLO, quota and cost evidence;
- production cloud resources, data, traffic, deployment or enablement.

## 31. Final statement

BCK-07 v0.2 is a production-grade Review design for one Content publication
authority. It closes semantic ownership gaps while deliberately leaving every
unapproved type, policy and runtime surface disabled.
