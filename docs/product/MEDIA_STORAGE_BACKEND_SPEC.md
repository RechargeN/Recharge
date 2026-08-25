# Recharge Backend — Media Storage Specification

- ID: **BCK-14**
- Version: **0.2.1**
- Date: **2026-08-25**
- Spec status: **Review — documentation only; approval pending**
- Runtime status: **Absent**
- Accountable owner: **Media Platform owner**
- Review owners: **Security/Privacy, Platform Operations, Content, Identity,
  Mobile, Trust & Safety, Route and Legal/Privacy**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.36](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-14-PRE v0.2.1](BACKEND_MEDIA_STORAGE_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/MEDIA_STORAGE_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

### v0.2.1 — 2026-08-25

- reconciled the new BCK-07 v0.2 Review dependency without changing Media
  ownership, AC numbering or runtime status;
- replaced the former physical-absence blocker with BCK-07 Approval/runtime
  and handoff-evidence blockers.

### v0.2 — 2026-08-25

- completed a 22/22 BCK-02 design contract and promoted it to Review;
- established a single-writer split between Media blob/metadata authority and
  BCK-07 content lifecycle authority;
- defined fail-closed two-phase upload, validation/quarantine, immutable
  variants, protected delivery, deletion/orphan and recovery semantics;
- recorded 60 acceptance criteria and ten owner decisions without authorizing
  Storage, Firebase, runtime code, migration, deployment or production data.

### v0.1 — 2026-08-25

- created the documentation-only BCK-14 draft from the repository audit;
- reconciled ADR 0013, BCK-03/04/05/06/18, Proposed Firebase input and current
  local/mobile media debt.

## 1. Verdict and status semantics

BCK-14 defines the target Media authority for Recharge. The design is ready for
cross-owner Review, not Approval or implementation. Runtime is Absent.

BCK-07 v0.2 is now Present in Review. Media may own upload sessions, bytes,
technical validation, variants and cleanup, but **cannot attach an asset to
published content, publish/restore/archive content or decide its visibility**.
Those effects remain disabled until BCK-07 is Approved, implemented and its
integration command is contract-tested.

Document status, emulator evidence, staged deployment and production readiness
are independent. Nothing here provisions Firebase/GCP, creates credentials,
adds a mobile SDK, writes data or permits a push/merge.

## 2. Parents, priority and reconciliation

Priority is:

1. Accepted ADR;
2. Approved owning-domain specification;
3. BCK-02 coordination and BCK-01 architecture;
4. this BCK-14 contract;
5. Proposed architecture and implementation notes.

Normative inputs:

- [ADR 0013](../adr/0013-domain-policy-baseline.md): preprocessing, retry,
  orphan cleanup and decoupled draft/media finalization;
- [ADR 0015](../adr/0015-authenticated-viewer-verified-creator-professional-page.md):
  capability-based identity and persistent `PublisherRef`;
- [BCK-03](BACKEND_API_CONTRACT_STANDARD.md): typed API, split request and
  idempotency keys, error/version semantics; ordinary envelope excludes bytes;
- [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md): bounded session, signature
  validation, private-original protection, Rules/AuthZ and privacy invariants;
- [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md): regional topology, CI/CD,
  observability, recovery, cost and rollout gates;
- [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md): account/session/capability,
  page membership and PublisherRef eligibility;
- [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md): typed mobile integration,
  compatibility, cache and cutover boundaries.

[Firebase Architecture](../architecture/FIREBASE_ARCHITECTURE.md) is a
**Proposed input**. Its staging flow informs this design but gains no Accepted
status by citation. BCK-14 uses opaque logical object keys; exact buckets,
prefixes and Rules are an owner decision and executable slice.

## 3. Outcome and non-goals

### 3.1 Outcome

Provide one provider-neutral contract that:

- accepts only authorized, bounded upload intents;
- stores immutable object generations with verified technical metadata;
- quarantines until required checks finish;
- produces bounded immutable variants;
- exposes only visibility-appropriate delivery handles;
- supplies a readiness receipt to the owning domain;
- deletes abandoned/orphaned/revoked data safely;
- supports DSR, retention, audit, recovery and cost controls.

### 3.2 Non-goals

BCK-14 does not own:

- content draft/publish/archive/delete lifecycle or attachment ordering;
- user/page membership, capability or PublisherRef eligibility;
- final trust-and-safety/moderation sanction;
- Route geometry, GPX domain validation or location-sharing policy;
- UI composition, image picker or mobile state implementation;
- CDN/vendor selection, Firebase provisioning or deployment;
- payments, AI generation, analytics profiling or provider ingestion;
- legal advice or an Accepted retention/right-to-publish policy.

## 4. Scope

### 4.1 In scope

- upload intent/session and bounded upload grant;
- source object receipt, hash, signature and metadata verification;
- quarantine and processing lifecycle;
- image variants and future explicitly enabled media-family processors;
- protected/public/private delivery handles and revocation;
- ownership/subject/publisher/entity binding;
- attachment readiness receipts to owning domains;
- replace, detach, delete, orphan cleanup and recovery reconciliation;
- audit, abuse, quotas, observability, SLO/cost hooks;
- migration boundary for current URL strings and local GPX references.

### 4.2 Initially disabled families

Video, audio, arbitrary documents, identity evidence and GPX remote storage are
disabled until their family profile and owner dependencies are Approved.
Identity verification evidence is not ordinary BCK-14 product media. GPX
requires BCK-11 classification and privacy rules.

## 5. Ownership and single writers

| Aggregate/decision | Single writer | BCK-14 boundary |
|---|---|---|
| `MediaAsset` and `MediaObjectGeneration` | BCK-14 | Full lifecycle and technical truth |
| `UploadSession` | BCK-14 | Grant, expiry, byte budget and completion |
| `MediaVariant` | BCK-14 | Immutable transform output |
| Content lifecycle/attachments | BCK-07/owning content domain | Consumes readiness receipt; Media cannot publish |
| User/session/capability/page membership | BCK-06 | Media evaluates authoritative access snapshot |
| Moderation case/verdict | BCK-22/BCK-07 handoff | Media produces technical/safety finding only |
| Route/GPX meaning and public eligibility | BCK-11 | Media stores opaque protected object after authorization |
| Retention/legal basis | BCK-04 + approved family policy | Media enforces, does not invent |
| Deployment/resource/recovery control | BCK-05 | Media declares requirements and consumes evidence |

An object path, URL, checksum, filename, Auth UID or client-provided publisher
does not establish ownership. Ownership comes from the accepted command,
authoritative actor snapshot and server-stored binding.

## 6. Actor and boundary model

Actors:

- subject user;
- authorized personal/page publisher actor;
- owning domain service;
- trusted media processor;
- cleanup/retention worker;
- privacy deletion/restriction worker;
- narrowly authorized support/security responder.

Every mutation validates authenticated account, session/revocation, market,
capability, exact `PublisherRef`, entity scope, command version and session
state at backend time. App Check is an abuse signal, never authority.

Service identities are least-privilege and separated: the upload issuer cannot
publish variants; the processor cannot grant actor rights; the delivery signer
cannot mutate ownership; cleanup cannot restore content.

## 7. Domain model

### 7.1 MediaAsset

```text
MediaAsset {
  assetId: ULID
  ownerSubjectId: UserId
  publisherRef: PublisherRef?
  entityBinding: {domain, entityId, purpose}?
  family: image | video | audio | document | gpx
  visibilityClass: private | protected | publicDerived
  lifecycle: reserved | uploading | uploaded | validating | quarantined |
             processing | ready | blocked | deleting | deleted
  sourceGenerationRef: MediaObjectGenerationRef?
  variantRefs: MediaVariantRef[]
  rightsRecordRef: RightsRecordRef?
  moderationFindingRef: FindingRef?
  policyRevision: string
  revision: integer
  createdAt/updatedAt: UTC instant
  deletedAt: UTC instant?
}
```

`publisherRef` is persistent attribution/context, not authorization evidence.
`entityBinding` is optional during draft upload and immutable once consumed by
an owning-domain attach command unless an explicit rebind policy permits it.

### 7.2 UploadSession

```text
UploadSession {
  uploadSessionId: ULID
  assetId: ULID
  actorId + publisherRef + entityIntent
  allowedFamily/signatures
  maxBytes + maxObjects
  expiresAt
  nonce/revision/state
  objectKeyHandle
  createdAt + completedAt?
}
```

The grant is single-asset, short-lived, non-transferable and environment-bound.
The backend selects the canonical key; the client cannot choose another owner,
public prefix, bucket, project or generation.

### 7.3 Object generation and variant

Every accepted object record pins environment, logical bucket handle, opaque
object key, immutable provider generation/version, byte length, verified media
type, cryptographic content hash, validation profile revision and timestamps.

A variant additionally pins source generation, transform profile revision,
format, dimensions/duration and its own generation/hash. Reprocessing creates a
new variant generation; it never overwrites an immutable public artifact.

### 7.4 Rights and safety findings

Rights/attribution and technical/safety findings are typed references with
their own policy revision. A checked client box is evidence input, not a legal
or moderation verdict. Inconclusive checks remain quarantined.

## 8. State machines and invariants

### 8.1 Upload/asset lifecycle

```text
reserved -> uploading -> uploaded -> validating
validating -> processing -> ready
validating|processing -> quarantined|blocked
reserved|uploading -> deleted (expiry/abort)
ready|quarantined|blocked -> deleting -> deleted
```

No transition skips trusted validation. Only a trusted processor can produce
`ready`. Bytes existing in Storage do not mean a ready asset.

### 8.2 Attachment lifecycle

```text
Media ready receipt
  -> owning domain validates entity revision, purpose, publisher and ordering
  -> owning domain records generation-pinned attachment
  -> publication readiness is evaluated by owning domain
```

Media never edits the Content aggregate. A content command may reject an
otherwise ready asset without deleting it immediately; orphan policy then
applies.

### 8.3 Core invariants

- public delivery contains derived, approved output only;
- protected/private originals never resolve through public handles;
- one asset belongs to one subject and at most one persistent publisher/entity
  binding under the accepted policy;
- same asset ID never changes bytes in place;
- ready requires verified source generation and all mandatory checks;
- delete/revoke wins over cached delivery and stale finalize;
- restoration never recreates public visibility automatically.

## 9. Commands

| Command | Result | Required controls |
|---|---|---|
| `media.createUploadSession` | bounded session/grant | actor, capability, publisher/entity intent, limits, quota |
| `media.confirmUpload` | accepted source receipt or typed rejection | session state, generation, size, signature/hash |
| `media.finalizeAsset` | processing receipt / ready result | idempotency, verified source, policy revision |
| `media.retryProcessing` | new attempt receipt | retryable state, same source generation |
| `media.requestDelivery` | expiring delivery handle | current AuthZ, visibility, restriction/revocation |
| `media.replaceAsset` | new asset/attachment proposal | owning-domain cooperation; no in-place overwrite |
| `media.detachAsset` | detach receipt | owning-domain command/ref revision |
| `media.deleteAsset` | deletion receipt | owner/admin/privacy authority, references/holds |
| `media.applyRestriction` | delivery disabled | authoritative privacy/moderation/security input |
| `media.reconcileOrphan` | keep/delete/quarantine result | policy revision and reference evidence |

`finalizeAsset` makes Media ready; it does not finalize Content. Command bytes
use the upload channel, never base64 inside an ordinary API envelope.

## 10. Queries and delivery

| Query | Projection |
|---|---|
| `media.getAssetStatus` | owner-safe state, progress, actionable failure |
| `media.listEntityMedia` | generation-pinned metadata authorized by owning domain |
| `media.getDeliveryHandle` | short-lived/opaque visibility-appropriate handle |
| `media.getProcessingReceipt` | attempt/check/result without sensitive internals |
| `media.getDeletionStatus` | privacy-safe task status |

Delivery handles carry or resolve asset ID, variant/profile revision,
generation, expiry and authorization scope without leaking bucket internals.
Protected access is re-evaluated at issuance and bounded by short expiry.
Revocation invalidates future issuance and purges/rejects caches according to
the Accepted delivery policy.

Public projections may expose a stable media projection ID and public variant
metadata. They do not expose owner-private source paths, upload sessions,
hash-based dedupe existence or moderation diagnostics.

## 11. Events and typed failures

### 11.1 Events

- `media.uploadReceived`
- `media.assetReady`
- `media.assetQuarantined`
- `media.assetBlocked`
- `media.deliveryRevoked`
- `media.assetDeletionRequested`
- `media.assetDeleted`
- `media.orphanDetected`
- `media.variantFailed`

Events use the BCK-03 event/outbox decision once Accepted. Until then they are
semantic contracts only. Consumers dedupe by event ID and tolerate replay and
out-of-order delivery; no event grants authorization.

### 11.2 Failure vocabulary

```text
unauthenticated
permissionDenied
publisherUnavailable
entityUnavailable
unsupportedMediaFamily
unsupportedMediaType
invalidSignature
fileTooLarge
dimensionOrDurationInvalid
uploadSessionExpired
uploadIncomplete
generationMismatch
hashMismatch
quotaExceeded
validationFailed
scanInconclusive
mediaQuarantined
mediaBlocked
processingFailedRetryable
processingFailedPermanent
rightsEvidenceRequired
staleRevision
conflict
notFound
rateLimited
temporarilyUnavailable
unknownOutcome
cancelled
unsupportedContractVersion
```

Cancellation before send is neutral `cancelled`. After bytes or finalize may
have committed, the outcome is `unknownOutcome` unless the server proves no
commit; retry follows split-key idempotency rules.

## 12. Contract versioning and client compatibility

- wire DTOs are separate from domain entities and provider SDK models;
- contract families are versioned; unsupported newer versions fail closed;
- the client never parses bucket/path conventions as business meaning;
- additive fields have safe defaults only when absence is semantically safe;
- breaking changes require parallel read/write or explicit migration window;
- generated artifacts are never manually edited;
- a non-Booking Media schema/codegen source needs `BCK14-OD-01` Acceptance;
- minimum supported client and kill-switch policy precede production use.

Changing variant bytes under the same generation/profile identity is breaking.
Changing a delivery URL alone is not a domain change when the opaque handle
contract is preserved.

## 13. Authorization, revocation and isolation

Authorization checks use backend state, not cached mobile state. Each mutation
checks subject, session, capability, publisher membership, entity intent,
market/environment, resource revision and relevant restriction.

Rules/IAM are default-deny and defense in depth. Direct client write is limited
to the exact bounded staging object/session if the Approved runtime design
allows it. Clients cannot write metadata truth, ready state, variants, public
objects, another owner path or deletion completion.

Revoked sessions, removed page membership, content restriction, consent
withdrawal or account deletion stop new grants immediately at authority.
Existing protected handles remain bounded by the accepted short expiry and
revocation/cache policy. Environment and market namespaces never mix.

## 14. Persistence, indexes and atomicity

Logical stores:

- media asset metadata authority;
- upload session/dedupe/idempotency records;
- source originals;
- quarantine objects;
- derived variants;
- attachment readiness receipts;
- deletion/orphan/recovery task records;
- audit and outbox records.

The provider layout is declared in a versioned resource/path manifest and
selected by BCK-05/BCK14-OD-02. Product code stores logical handles, never a
hardcoded bucket name as domain truth.

Atomic boundaries:

1. session reservation commits asset ID, actor binding and byte policy;
2. upload receipt pins one immutable object generation/hash;
3. finalize transaction conditionally advances metadata and records outbox;
4. owning-domain attach transaction consumes the ready receipt and expected
   entity revision;
5. deletion first revokes delivery, then reconciles references, objects,
   variants, backup/DSR tasks and completion evidence.

Firestore metadata and object storage cannot be assumed to share one database
transaction. Reconciliation workers must be idempotent and make incomplete
states visible, never silently declare success.

## 15. IDs, time and reference semantics

- IDs are server-accepted ULID/UUID; `loc_*` never enters authority;
- timestamps are UTC and server-authored for authority decisions;
- TTL/expiry uses backend time; device clock is advisory;
- each blob ref pins provider generation/version and verified hash;
- `PublisherRef`, entity ID, subject ID and policy/profile revisions are stable
  IDs, never display names;
- media dimensions are integer pixels, byte sizes are integer bytes;
- duration is an integer bounded unit defined by the family contract;
- locale/market labels do not enter object identity.

## 16. Idempotency, concurrency, retry and failure

Each logical command has a stable idempotency key and normalized payload hash;
each network attempt has a fresh request ID. Same key/same hash returns the
recorded result; same key/different hash performs no mutation.

Upload chunks may use a provider resumable protocol, but completion is accepted
only once for the reserved session and expected object generation. Multiple
completion notifications reconcile to one receipt.

Finalize uses expected asset revision and source generation. Stale processors
cannot overwrite a newer restriction, delete or replacement. Retry reuses the
same logical identity for the same source generation and creates a new
processing attempt ID. Permanent invalid input is not retried automatically.

## 17. Offline, cache and freshness

Offline clients may retain local draft selections/previews and an explicit
pending upload intent. They cannot claim a server asset ID is ready, public or
attached. A local path is never a server media reference.

Client state distinguishes local-only, queued, uploading, uploaded-unconfirmed,
processing, ready-fresh, ready-cached, stale, quarantined, blocked, deleted,
unsupported and unknown outcome. Cache entries pin asset/variant generation,
visibility scope, owner/workspace/environment, expiry and source revision.

A deleted/restricted tombstone wins over cached imagery. Protected content is
not served offline beyond the Accepted access/cache policy. Public variants may
use bounded cache semantics, but a changed generation yields a new immutable
identity.

## 18. Migration, import and compatibility

Current cover/gallery values are often arbitrary URL strings. Migration must:

1. inventory without upload or authority change;
2. classify local file, approved remote source, public demo URL, broken URL and
   unknown source;
3. create no ownership from URL/filename/hash similarity;
4. require explicit publisher/entity mapping through BCK-06/BCK-07/BCK-18;
5. copy only when rights, source access and policy permit;
6. validate copied bytes through the normal quarantine/finalize path;
7. preserve disclosure, checkpoint, conflict and rollback evidence;
8. leave unsupported records local/legacy with typed state.

Cross-owner hash matches never disclose another asset's existence. Physical
dedupe, if enabled, remains below authorization and lifecycle isolation.

GPX migration is disabled until BCK-11 defines sensitivity, precision,
publication and deletion behavior. Identity verification evidence is excluded.

## 19. Outbox, workers, replay and reconciliation

Trusted effects include validation, malware/safety inspection, transform,
metadata extraction, orphan cleanup, delivery revocation and deletion. Every
worker is idempotent, revision-aware, bounded in retries and poison-safe.

Outbox records contain opaque IDs and minimum routing metadata, not raw media,
signed URLs, secrets, exact private location or unnecessary user text. Replay
cannot restore a deleted/restricted asset or publish content. Dead-letter
records remain quarantined and observable with an owner action.

Periodic reconciliation detects:

- session without object;
- object without accepted receipt;
- metadata without generation;
- ready asset without required variants;
- variant/source hash mismatch;
- content ref to non-ready/deleted asset;
- unreferenced asset past policy threshold;
- deletion task incomplete across stores/backups.

## 20. Privacy, retention, rights and Legal

Media metadata and bytes are classified per family, purpose and visibility.
Exact personal/sensitive/location/child/identity-evidence classification is not
inferred from file type. EXIF and other metadata are minimized; unnecessary
location/device identifiers are stripped before public derivation. Originals
remain private/protected unless a separate policy expressly permits otherwise.

Retention is specified separately for:

- unused/reserved sessions;
- incomplete staging objects;
- quarantined/blocked evidence;
- attached originals;
- derived variants;
- detached/orphan assets;
- deleted asset tombstones/completion ledgers;
- audit/idempotency/outbox records;
- backups and recovery copies.

No numeric duration is called Accepted until BCK14-OD-07 and qualified
Privacy/Legal evidence exist. ADR 0013's generic 30-day soft-delete baseline
does not silently define every byte, quarantine or backup term. Provider soft
delete/default retention is an operational control, not lawful product
retention.

DSR/restriction/delete first blocks live delivery, then executes scoped domain,
object, variant, cache and backup propagation. Restore replays newer deletion,
restriction and moderation evidence before access. Legal/security holds are
explicit, scoped, time-bound, audited and do not create public availability.

Rights/attribution/consent evidence and disclosure wording require
BCK14-OD-06. User confirmation alone does not prove rights.

## 21. Abuse, validation and App Check

Defense in depth:

- bounded session lifetime, bytes, count, family and actor/publisher/entity;
- server-side signature sniffing and decodability validation;
- decompression-bomb, malformed container, pixel/duration and parser limits;
- malware/unsafe-content scanning where the family policy requires it;
- filename and user metadata normalization;
- per-subject/publisher/device-risk/IP rate controls where lawful;
- storage and transform quotas with server enforcement;
- no cross-owner dedupe oracle;
- App Check monitor-then-enforce only under BCK-04 policy;
- emergency family/market/upload/finalize/delivery kill switches.

Failed or inconclusive validation never falls back to ready/public. Scanner
vendor, timeout, human-review handoff and false-positive path are
BCK14-OD-05.

## 22. Observability, SLO, analytics and cost

Metrics:

- sessions created/expired/abandoned;
- accepted/rejected bytes by family and reason;
- validation/transform latency and queue age;
- ready/quarantine/block/failure counts;
- orphan/reference mismatch and cleanup lag;
- protected handle issuance/denial/revocation;
- deletion and privacy-task completion lag;
- original/variant/quarantine storage, operations, egress and compute cost;
- processor version/profile distribution.

Logs exclude bytes, signed URLs, tokens, raw filenames/free text, exact private
locations and full hashes where correlation is unnecessary. Diagnostic IDs are
opaque and access-controlled.

Numeric SLOs, availability, processing latency, deletion completion, quotas,
cost and egress guardrails are BCK14-OD-10. Until Accepted, no production or
scale claim exists. Degradation may pause uploads/transforms or return typed
unavailable state; it never skips checks or exposes originals.

## 23. Flags, rollout and rollback

Flags are server-governed by environment, market, family, command and delivery
class:

- upload session creation;
- upload confirmation/finalize;
- each media family;
- each transform profile;
- public/protected delivery;
- legacy import;
- cleanup/deletion workers.

Rollout proceeds documentation → contract fixtures → unit → emulator → stage
synthetic → bounded non-production → production owner decision. Each stage has
separate evidence and cannot inherit the previous status.

Rollback disables new sessions/finalize/delivery as scoped, drains or safely
quarantines work, preserves committed media truth and completes deletion/
restriction duties. It never re-enables stale public URLs, mock authority or a
superseded unsafe processor.

## 24. Dependency and delivery gates

Before Approval:

- BCK-03/04/05 Approval or explicit accepted compatibility disposition;
- BCK-06 Approval for access/PublisherRef integration;
- BCK-07 Approved attachment/content lifecycle contract;
- all ten BCK14 decisions Accepted or explicitly deferred with controls;
- qualified Security/Privacy/Legal and Operations verdicts.

Before executable work:

- separately Approved R4 slice and exact file/resource map;
- accepted Media contract workflow and fixtures;
- BCK-18 client boundary where mobile is included;
- no new boundary suppression or an explicitly approved debt change;
- no Firebase/cloud mutation before G1/R1 prerequisites and authorization.

Before production:

- Storage/Rules/IAM, workers and recovery evidence;
- negative AuthZ and cross-publisher isolation tests;
- load, cost/egress, quota and SLO evidence;
- DSR/deletion/restore privacy-resurrection drill;
- incident/rollback rehearsal and signed owner verdict.

## 25. Conditional exact file map

No file below is authorized by this Review. A future Approved slice may create:

```text
packages/api_contracts/media/                 # only after OD-01
  schemas/
  fixtures/

apps/backend/src/media/
  domain/
    media_asset.*
    upload_session.*
    media_policy.*
  application/
    create_upload_session.*
    confirm_upload.*
    finalize_asset.*
    request_delivery.*
    delete_asset.*
    reconcile_orphan.*
  infrastructure/
    metadata_repository.*
    object_store.*
    transform_gateway.*
    scanner_gateway.*
    delivery_signer.*
  presentation/
    media_handlers.*
  workers/
    validate_media.*
    transform_media.*
    cleanup_media.*
    delete_media.*

apps/backend/test/media/
  unit/
  contract/
  integration/
  security/
  recovery/

infra/firebase/
  storage.rules                         # exact path subject to OD-02
  storage.rules.test.*
  media-resource-manifest.*

apps/mobile/lib/features/*/data/media/  # only owning feature adapters
apps/mobile/test/**/media_*_test.dart
```

Content attachment code remains in the owning domain, not under Media. Shared
mobile transport belongs to the BCK-18-approved seam. Generated files follow
the accepted workflow and are never hand-edited.

## 26. Test and evidence matrix

| Layer | Required evidence |
|---|---|
| Domain/unit | state transitions, invariants, expiry, visibility, generation/hash, retry |
| Contract | request/result/error fixtures, version compatibility, split idempotency keys |
| Object integration | resumable receipt, signature mismatch, generation race, incomplete upload |
| Security/Rules | unauthenticated, cross-user/page, guessed ID/path, public-original denial, revoked membership |
| Processing | malformed/decompression bomb, deterministic profile, scanner fail/timeout, poison/replay |
| Content integration | ready receipt only, stale entity revision, detach/delete race, no Media publish |
| Privacy | EXIF minimization, protected delivery, deletion/restriction propagation, no resurrection |
| Recovery | exact generation/hash restore, quarantined unsafe data remains non-public |
| Mobile | offline/unknown outcome/retry, account/workspace isolation, unsupported version |
| Load/cost | upload concurrency, queue lag, storage/egress/transform forecast and guardrail |
| Rollout | flags, disable/drain/quarantine, previous compatible client, rollback evidence |

Documentation validation proves only links, structure, numbering and repository
consistency. Emulator cannot prove production IAM, limits, latency or recovery.

## 27. Definition of Ready

For Approval review:

1. 22/22 coverage remains reconciled;
2. BCK-07 exists and resolves content attachment/lifecycle ownership;
3. ten owner decisions have dated verdicts;
4. BCK-03/04/05/06 dependency status is explicitly accepted;
5. contract, privacy, security, operations, mobile and domain owners sign;
6. all runtime files remain absent unless separately authorized.

For an executable slice:

1. BCK-14 Approved;
2. exact bounded scope/file/resource list approved;
3. test fixtures and failure vocabulary frozen;
4. G1/R1 and environment prerequisites satisfied;
5. rollback/kill-switch and cost limit predeclared;
6. no unresolved choice is implemented by assumption.

## 28. Definition of Done

BCK-14 runtime is Done only when:

- approved contracts, metadata authority, object storage, processing and
  delivery are implemented in their owned layers;
- security/Rules, unit, contract, integration, privacy, recovery and load gates
  pass in required environments;
- content/identity/mobile integrations preserve single writers;
- migration is measured, reversible and reports conflict/orphan outcomes;
- observability, runbooks, on-call and cost controls are active;
- runtime status/evidence is updated without conflating deployment and enablement.

Production Enabled additionally requires market activation, Legal/Privacy,
recovery and owner sign-off. `Approved`, `Done` and `Enabled` are not synonyms.

## 29. Acceptance criteria

1. **BCK-14-AC-01:** Media owns asset/session/object/variant technical truth only.
2. **BCK-14-AC-02:** BCK-07 remains content lifecycle and attachment writer.
3. **BCK-14-AC-03:** BCK-06 remains actor/capability/PublisherRef authority.
4. **BCK-14-AC-04:** BCK-22/Content owns final moderation verdict and sanction.
5. **BCK-14-AC-05:** BCK-11 owns GPX meaning and location publication policy.
6. **BCK-14-AC-06:** Upload and content finalization are separate state machines.
7. **BCK-14-AC-07:** Client cannot choose canonical public/foreign-owner path.
8. **BCK-14-AC-08:** Path, URL, filename and checksum never establish ownership.
9. **BCK-14-AC-09:** Every grant is bounded by actor, asset, policy and expiry.
10. **BCK-14-AC-10:** App Check never substitutes for AuthZ.
11. **BCK-14-AC-11:** Declared MIME/extension alone never passes validation.
12. **BCK-14-AC-12:** Ready pins verified immutable source generation and hash.
13. **BCK-14-AC-13:** Variant pins source generation and transform profile revision.
14. **BCK-14-AC-14:** Reprocessing creates a new immutable variant generation.
15. **BCK-14-AC-15:** Public delivery never exposes private/protected original.
16. **BCK-14-AC-16:** Inconclusive/failed required scan remains quarantined.
17. **BCK-14-AC-17:** Scanner finding is not silently a final moderation verdict.
18. **BCK-14-AC-18:** A client cannot write ready/variant/public metadata truth.
19. **BCK-14-AC-19:** Owning domain consumes a generation-pinned readiness receipt.
20. **BCK-14-AC-20:** Media never publishes, archives or restores Content.
21. **BCK-14-AC-21:** Protected delivery revalidates current authorization.
22. **BCK-14-AC-22:** Delivery handles are opaque, scoped and expiring.
23. **BCK-14-AC-23:** Revocation/deletion blocks new delivery immediately at authority.
24. **BCK-14-AC-24:** Deleted/restricted tombstone wins over stale cache/finalize.
25. **BCK-14-AC-25:** Same asset ID never changes source bytes in place.
26. **BCK-14-AC-26:** Replace creates a new asset/generation-pinned proposal.
27. **BCK-14-AC-27:** Same idempotency key/different payload hash creates no mutation.
28. **BCK-14-AC-28:** Each retry attempt has fresh request ID and stable logical key.
29. **BCK-14-AC-29:** Unknown outcome is reconciled before a new logical operation.
30. **BCK-14-AC-30:** Stale worker cannot overwrite delete/restrict/replace state.
31. **BCK-14-AC-31:** Storage/metadata partial completion is explicitly reconciled.
32. **BCK-14-AC-32:** Worker replay cannot duplicate effects or restore visibility.
33. **BCK-14-AC-33:** Poison work remains quarantined and observable.
34. **BCK-14-AC-34:** Orphan cleanup requires authoritative reference evidence.
35. **BCK-14-AC-35:** Physical dedupe exposes no cross-owner existence or access.
36. **BCK-14-AC-36:** Environment, market, subject and publisher data never mix.
37. **BCK-14-AC-37:** Offline/local path never becomes server-ready authority.
38. **BCK-14-AC-38:** Cache pins generation, visibility, scope, expiry and revision.
39. **BCK-14-AC-39:** Newer unsupported contract fails closed.
40. **BCK-14-AC-40:** Generated contract files are never manually edited.
41. **BCK-14-AC-41:** Legacy URL import never infers ownership.
42. **BCK-14-AC-42:** Imported bytes pass the normal quarantine/finalize path.
43. **BCK-14-AC-43:** Remote GPX remains disabled before BCK-11 approval.
44. **BCK-14-AC-44:** Identity evidence is not treated as ordinary product media.
45. **BCK-14-AC-45:** Public derivation removes unnecessary sensitive metadata.
46. **BCK-14-AC-46:** Rights confirmation alone is not a final legal verdict.
47. **BCK-14-AC-47:** Retention is per family/state/purpose, not provider default.
48. **BCK-14-AC-48:** Backup never silently extends lawful retention.
49. **BCK-14-AC-49:** Restore replays newer deletion/restriction/moderation evidence.
50. **BCK-14-AC-50:** Legal/security hold is scoped, timed and audited.
51. **BCK-14-AC-51:** Logs contain no bytes, signed URLs, tokens or unnecessary raw metadata.
52. **BCK-14-AC-52:** Numeric SLO/quota/cost claims require owner evidence.
53. **BCK-14-AC-53:** Degradation never skips validation or exposes originals.
54. **BCK-14-AC-54:** Every risky family/command/delivery surface has a kill switch.
55. **BCK-14-AC-55:** Rollback preserves committed truth and privacy duties.
56. **BCK-14-AC-56:** Proposed Firebase layout is not silently Accepted.
57. **BCK-14-AC-57:** No new boundary suppression is introduced by this revision.
58. **BCK-14-AC-58:** Documentation/emulator/stage/production evidence remain distinct.
59. **BCK-14-AC-59:** Executable files require a separate Approved slice.
60. **BCK-14-AC-60:** Runtime remains Absent until measured implementation evidence exists.

## 30. Explicit unimplemented list

- Media API schemas, fixtures, clients and generated DTOs;
- Firebase/GCP Storage buckets, Rules, IAM or App Check enforcement;
- upload session, confirmation and finalize handlers;
- metadata database, object store and signed delivery implementation;
- malware/safety scanners and media processors;
- image/video/audio/document/GPX production family profiles;
- content attachment integration and BCK-07 runtime;
- BCK-06 production access integration;
- mobile picker/uploader/cache/cutover adapters;
- legacy URL or GPX migration;
- deletion/orphan/DSR/recovery workers and runbooks;
- accepted numeric limits, retention, SLO, quotas and cost guardrails;
- production Legal/Privacy, Security, Operations or owner approval;
- cloud provisioning, deployment, production traffic or data processing.

## 31. Final statement

BCK-14 v0.2.1 is a complete Review contract for a production-grade Media
subsystem design. It is intentionally fail-closed where ownership, policy or
runtime evidence is absent. It neither claims nor authorizes implementation.
